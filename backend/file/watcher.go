package file

import (
	"context"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/zaxlofful/CloudMonitoring/backend/state"
)

// Watcher watches a directory for new data files
type Watcher struct {
	dir           string
	interval      time.Duration
	stateManager  *state.StateManager
	seenFiles     map[string]bool
	onNewData     func(*state.ProductionData)
}

// NewWatcher creates a new file watcher
func NewWatcher(dir string, interval time.Duration, sm *state.StateManager) *Watcher {
	return &Watcher{
		dir:          dir,
		interval:     interval,
		stateManager: sm,
		seenFiles:    make(map[string]bool),
	}
}

// SetNewDataCallback sets the callback for when new data is found
func (w *Watcher) SetNewDataCallback(callback func(*state.ProductionData)) {
	w.onNewData = callback
}

// Start starts the file watcher
func (w *Watcher) Start(ctx context.Context) {
	log.Printf("Starting file watcher on directory: %s (interval: %v)", w.dir, w.interval)

	// Initial scan to populate seen files
	w.initialScan()

	ticker := time.NewTicker(w.interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("Stopping file watcher")
			return
		case <-ticker.C:
			w.scan()
		}
	}
}

func (w *Watcher) initialScan() {
	files, err := ScanDirectory(w.dir)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("Directory does not exist yet: %s", w.dir)
			return
		}
		log.Printf("Error during initial scan: %v", err)
		return
	}

	log.Printf("Initial scan found %d existing files", len(files))

	// Mark all existing files as seen but don't process them
	// This prevents alerts on startup for already-existing data
	for _, file := range files {
		w.seenFiles[filepath.Base(file)] = true
	}
}

func (w *Watcher) scan() {
	files, err := ScanDirectory(w.dir)
	if err != nil {
		if os.IsNotExist(err) {
			// Directory doesn't exist yet, skip silently
			return
		}
		log.Printf("Error scanning directory: %v", err)
		return
	}

	// Process new files
	for _, file := range files {
		basename := filepath.Base(file)
		if w.seenFiles[basename] {
			continue
		}

		// Mark as seen immediately to avoid reprocessing
		w.seenFiles[basename] = true

		// Parse and process the file
		data, err := ParseJSONFile(file)
		if err != nil {
			log.Printf("Failed to parse file %s: %v", file, err)
			continue
		}

		log.Printf("Processed new file: %s (timestamp: %d, items: %d)", basename, data.Timestamp, len(data.Items))

		// Call the callback if set
		if w.onNewData != nil {
			w.onNewData(data)
		}
	}
}

// LoadRecentFiles loads recent files on startup to rebuild state
func (w *Watcher) LoadRecentFiles(maxAge time.Duration) error {
	files, err := ScanDirectory(w.dir)
	if err != nil {
		if os.IsNotExist(err) {
			log.Printf("Directory does not exist yet: %s", w.dir)
			return nil
		}
		return err
	}

	cutoff := time.Now().Add(-maxAge).Unix()
	loaded := 0

	for _, file := range files {
		basename := filepath.Base(file)
		timestamp, err := ExtractTimestampFromFilename(basename)
		if err != nil {
			continue
		}

		if timestamp < cutoff {
			continue
		}

		data, err := ParseJSONFile(file)
		if err != nil {
			log.Printf("Failed to parse file %s: %v", file, err)
			continue
		}

		w.stateManager.AddData(data)
		w.seenFiles[basename] = true
		loaded++
	}

	log.Printf("Loaded %d recent files into memory", loaded)
	return nil
}
