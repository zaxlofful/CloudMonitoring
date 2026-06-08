package log

import (
	"encoding/json"
	"fmt"
	"os"
	"sync"
	"time"
)

// AlertEntry represents a single alert log entry
type AlertEntry struct {
	Timestamp          int64    `json:"timestamp"`
	Item               string   `json:"item"`
	Event              string   `json:"event"`
	ProductionRate     float64  `json:"production_rate"`
	NotifiersTriggered []string `json:"notifiers_triggered"`
	NotifiersFailed    []string `json:"notifiers_failed"`
}

// AlertLogger logs alerts to a JSON lines file
type AlertLogger struct {
	mu       sync.Mutex
	filePath string
	file     *os.File
}

// NewAlertLogger creates a new alert logger
func NewAlertLogger(filePath string) (*AlertLogger, error) {
	// Open file in append mode, create if doesn't exist
	file, err := os.OpenFile(filePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}

	return &AlertLogger{
		filePath: filePath,
		file:     file,
	}, nil
}

// LogAlert logs an alert entry
func (al *AlertLogger) LogAlert(entry *AlertEntry) error {
	al.mu.Lock()
	defer al.mu.Unlock()

	// Marshal to JSON
	jsonData, err := json.Marshal(entry)
	if err != nil {
		return fmt.Errorf("failed to marshal alert entry: %w", err)
	}

	// Write JSON line
	if _, err := al.file.Write(append(jsonData, '\n')); err != nil {
		return fmt.Errorf("failed to write log entry: %w", err)
	}

	// Sync to disk
	if err := al.file.Sync(); err != nil {
		return fmt.Errorf("failed to sync log file: %w", err)
	}

	return nil
}

// Log is a convenience method for logging with individual parameters
func (al *AlertLogger) Log(item string, event string, productionRate float64, triggered []string, failed []string) error {
	entry := &AlertEntry{
		Timestamp:          time.Now().Unix(),
		Item:               item,
		Event:              event,
		ProductionRate:     productionRate,
		NotifiersTriggered: triggered,
		NotifiersFailed:    failed,
	}
	return al.LogAlert(entry)
}

// Close closes the log file
func (al *AlertLogger) Close() error {
	al.mu.Lock()
	defer al.mu.Unlock()

	if al.file != nil {
		return al.file.Close()
	}
	return nil
}
