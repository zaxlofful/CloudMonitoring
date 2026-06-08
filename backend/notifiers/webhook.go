package notifiers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/zaxlofful/CloudMonitoring/backend/config"
)

// WebhookNotifier sends webhook notifications
type WebhookNotifier struct {
	config *config.NotificationConfig
	client *http.Client
}

// NewWebhookNotifier creates a new webhook notifier
func NewWebhookNotifier(cfg *config.NotificationConfig) *WebhookNotifier {
	return &WebhookNotifier{
		config: cfg,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// Type returns the notifier type
func (w *WebhookNotifier) Type() string {
	return "webhook"
}

// Validate validates webhook configuration
func (w *WebhookNotifier) Validate() error {
	if w.config.GetString("url") == "" {
		return fmt.Errorf("url is required")
	}
	return nil
}

// Notify sends a webhook notification
func (w *WebhookNotifier) Notify(ctx context.Context, itemName string, event string, productionRate float64) error {
	url := w.config.GetString("url")
	method := w.config.GetString("method")
	if method == "" {
		method = "POST"
	}

	// Build payload
	payload := map[string]interface{}{
		"item":            itemName,
		"event":           event,
		"production_rate": productionRate,
		"timestamp":       time.Now().Unix(),
	}

	jsonData, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("failed to marshal webhook payload: %w", err)
	}

	// Create request
	req, err := http.NewRequestWithContext(ctx, method, url, bytes.NewBuffer(jsonData))
	if err != nil {
		return fmt.Errorf("failed to create webhook request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	// Send request
	resp, err := w.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to send webhook: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("webhook returned non-2xx status: %d", resp.StatusCode)
	}

	return nil
}
