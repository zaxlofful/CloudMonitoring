package main

import (
	"context"
	"flag"
	"log"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/zaxlofful/CloudMonitoring/backend/config"
	"github.com/zaxlofful/CloudMonitoring/backend/file"
	alertlog "github.com/zaxlofful/CloudMonitoring/backend/log"
	"github.com/zaxlofful/CloudMonitoring/backend/notifiers"
	"github.com/zaxlofful/CloudMonitoring/backend/state"
)

var (
	configPath  = flag.String("config", "cloudmonitoring-config.yaml", "Path to config file")
	gamedataDir = flag.String("gamedata", "/app/gamedata", "Path to game data directory")
	logPath     = flag.String("logfile", "", "Path to alert log file (default: {gamedata}/cloudmonitoring-alerts.log)")
)

func main() {
	flag.Parse()

	log.Println("CloudMonitoring Backend starting...")

	// Load configuration
	cfg, err := config.LoadConfig(*configPath)
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	if err := cfg.Validate(); err != nil {
		log.Fatalf("Invalid configuration: %v", err)
	}

	log.Printf("Loaded configuration with %d notification channels", len(cfg.Notifications))

	// Initialize notifiers
	var enabledNotifiers []notifiers.Notifier
	for i, notifCfg := range cfg.Notifications {
		if !notifCfg.Enabled {
			log.Printf("Notifier %d (%s) is disabled, skipping", i, notifCfg.Type)
			continue
		}

		notifier, err := notifiers.CreateNotifier(&notifCfg)
		if err != nil {
			log.Printf("Failed to create notifier %d (%s): %v", i, notifCfg.Type, err)
			continue
		}

		if notifier == nil {
			log.Printf("Unknown notifier type: %s", notifCfg.Type)
			continue
		}

		if err := notifier.Validate(); err != nil {
			log.Printf("Notifier %s validation failed: %v", notifier.Type(), err)
			continue
		}

		enabledNotifiers = append(enabledNotifiers, notifier)
		log.Printf("Enabled notifier: %s", notifier.Type())
	}

	if len(enabledNotifiers) == 0 {
		log.Fatal("No valid notifiers configured")
	}

	// Determine script-output directory
	scriptOutputDir := filepath.Join(*gamedataDir, "script-output")

	// Determine log file path
	logFilePath := *logPath
	if logFilePath == "" {
		logFilePath = filepath.Join(*gamedataDir, "cloudmonitoring-alerts.log")
	}

	// Initialize alert logger
	alertLogger, err := alertlog.NewAlertLogger(logFilePath)
	if err != nil {
		log.Fatalf("Failed to create alert logger: %v", err)
	}
	defer alertLogger.Close()
	log.Printf("Alert logging to: %s", logFilePath)

	// Initialize state manager
	stateManager := state.NewStateManager()

	// Create context for graceful shutdown
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Setup signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)

	// Start data pruning goroutine
	go stateManager.StartPruning(ctx, 1*time.Minute, 100*time.Hour)

	// Initialize file watcher
	watcher := file.NewWatcher(scriptOutputDir, 5*time.Second, stateManager)

	// Load recent files to rebuild state
	log.Println("Loading recent files to rebuild state...")
	if err := watcher.LoadRecentFiles(100 * time.Hour); err != nil {
		log.Printf("Warning: Failed to load recent files: %v", err)
	}

	// Set up callback for new data
	watcher.SetNewDataCallback(func(data *state.ProductionData) {
		// Process production data and get transitions
		transitions := stateManager.ProcessProductionData(data)

		// Handle each transition
		for _, trans := range transitions {
			// Skip items not in monitor list (if configured)
			if !cfg.ShouldMonitorItem(trans.ItemName) {
				continue
			}

			// Determine event type
			event := "unknown"
			if trans.ToState == "alerted" {
				event = "production_stopped"
			} else if trans.ToState == "recovering" {
				event = "production_resumed"
			}

			log.Printf("ALERT: %s - %s (rate: %.2f)", trans.ItemName, event, trans.ProductionRate)

			// Send notifications concurrently
			var triggered []string
			var failed []string

			for _, notifier := range enabledNotifiers {
				notifierType := notifier.Type()
				go func(n notifiers.Notifier, nType string) {
					notifCtx, notifCancel := context.WithTimeout(ctx, 30*time.Second)
					defer notifCancel()

					if err := n.Notify(notifCtx, trans.ItemName, event, trans.ProductionRate); err != nil {
						log.Printf("Notifier %s failed for %s: %v", nType, trans.ItemName, err)
						failed = append(failed, nType)
					} else {
						log.Printf("Notifier %s succeeded for %s", nType, trans.ItemName)
						triggered = append(triggered, nType)
					}
				}(notifier, notifierType)
			}

			// Give notifications a moment to complete before logging
			// This is a simple approach; in production you'd use sync primitives
			time.Sleep(100 * time.Millisecond)

			// Log the alert
			if err := alertLogger.Log(trans.ItemName, event, trans.ProductionRate, triggered, failed); err != nil {
				log.Printf("Failed to log alert: %v", err)
			}
		}
	})

	// Start file watcher in background
	go watcher.Start(ctx)

	log.Println("CloudMonitoring Backend is running. Press Ctrl+C to stop.")

	// Wait for shutdown signal
	<-sigChan
	log.Println("Shutdown signal received, stopping...")
	cancel()

	// Give goroutines time to finish
	time.Sleep(1 * time.Second)

	log.Println("CloudMonitoring Backend stopped.")
}
