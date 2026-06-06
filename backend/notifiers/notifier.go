package notifiers

import (
	"context"

	"github.com/zaxlofful/CloudMonitoring/backend/config"
)

// Notifier is the interface for all notification plugins
type Notifier interface {
	// Notify sends a notification for an item alert
	Notify(ctx context.Context, itemName string, event string, productionRate float64) error

	// Validate validates the notifier configuration
	Validate() error

	// Type returns the notifier type name
	Type() string
}

// CreateNotifier creates a notifier from a configuration
func CreateNotifier(cfg *config.NotificationConfig) (Notifier, error) {
	switch cfg.Type {
	case "email":
		return NewEmailNotifier(cfg), nil
	case "webhook":
		return NewWebhookNotifier(cfg), nil
	case "sms":
		return NewSMSNotifier(cfg), nil
	default:
		return nil, nil // Unknown type, skip
	}
}
