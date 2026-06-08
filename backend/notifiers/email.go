package notifiers

import (
	"context"
	"fmt"
	"net/smtp"
	"strings"

	"github.com/zaxlofful/CloudMonitoring/backend/config"
)

// EmailNotifier sends email notifications
type EmailNotifier struct {
	config *config.NotificationConfig
}

// NewEmailNotifier creates a new email notifier
func NewEmailNotifier(cfg *config.NotificationConfig) *EmailNotifier {
	return &EmailNotifier{config: cfg}
}

// Type returns the notifier type
func (e *EmailNotifier) Type() string {
	return "email"
}

// Validate validates email configuration
func (e *EmailNotifier) Validate() error {
	if e.config.GetString("smtp_host") == "" {
		return fmt.Errorf("smtp_host is required")
	}
	if e.config.GetInt("smtp_port") == 0 {
		return fmt.Errorf("smtp_port is required")
	}
	if e.config.GetString("sender_email") == "" {
		return fmt.Errorf("sender_email is required")
	}
	if len(e.config.GetStringSlice("recipients")) == 0 {
		return fmt.Errorf("at least one recipient is required")
	}
	return nil
}

// Notify sends an email notification
func (e *EmailNotifier) Notify(ctx context.Context, itemName string, event string, productionRate float64) error {
	smtpHost := e.config.GetString("smtp_host")
	smtpPort := e.config.GetInt("smtp_port")
	senderEmail := e.config.GetString("sender_email")
	senderPassword := e.config.GetString("sender_password")
	recipients := e.config.GetStringSlice("recipients")

	// Build email message
	subject := fmt.Sprintf("[CloudMonitoring] Alert: %s - %s", itemName, event)
	body := fmt.Sprintf("Item: %s\nEvent: %s\nProduction Rate: %.2f items/minute\n", itemName, event, productionRate)

	message := fmt.Sprintf("From: %s\r\n", senderEmail)
	message += fmt.Sprintf("To: %s\r\n", strings.Join(recipients, ", "))
	message += fmt.Sprintf("Subject: %s\r\n", subject)
	message += "\r\n" + body

	// Setup authentication
	addr := fmt.Sprintf("%s:%d", smtpHost, smtpPort)
	var auth smtp.Auth
	if senderPassword != "" {
		auth = smtp.PlainAuth("", senderEmail, senderPassword, smtpHost)
	}

	// Send email
	err := smtp.SendMail(addr, auth, senderEmail, recipients, []byte(message))
	if err != nil {
		return fmt.Errorf("failed to send email: %w", err)
	}

	return nil
}
