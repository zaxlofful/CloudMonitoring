package notifiers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/zaxlofful/CloudMonitoring/backend/config"
)

// SMSNotifier sends SMS notifications
type SMSNotifier struct {
	config *config.NotificationConfig
	client *http.Client
}

// NewSMSNotifier creates a new SMS notifier
func NewSMSNotifier(cfg *config.NotificationConfig) *SMSNotifier {
	return &SMSNotifier{
		config: cfg,
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// Type returns the notifier type
func (s *SMSNotifier) Type() string {
	return "sms"
}

// Validate validates SMS configuration
func (s *SMSNotifier) Validate() error {
	if s.config.GetString("provider") == "" {
		return fmt.Errorf("provider is required")
	}
	if s.config.GetString("phone_from") == "" {
		return fmt.Errorf("phone_from is required")
	}
	if len(s.config.GetStringSlice("phone_to")) == 0 {
		return fmt.Errorf("at least one phone_to is required")
	}
	return nil
}

// Notify sends an SMS notification
func (s *SMSNotifier) Notify(ctx context.Context, itemName string, event string, productionRate float64) error {
	provider := s.config.GetString("provider")

	switch strings.ToLower(provider) {
	case "twilio":
		return s.sendTwilioSMS(ctx, itemName, event, productionRate)
	default:
		return fmt.Errorf("unsupported SMS provider: %s", provider)
	}
}

func (s *SMSNotifier) sendTwilioSMS(ctx context.Context, itemName string, event string, productionRate float64) error {
	accountSID := s.config.GetString("account_sid")
	authToken := s.config.GetString("auth_token")
	phoneFrom := s.config.GetString("phone_from")
	phoneTo := s.config.GetStringSlice("phone_to")

	if accountSID == "" || authToken == "" {
		return fmt.Errorf("twilio requires account_sid and auth_token")
	}

	message := fmt.Sprintf("[CloudMonitoring] %s: %s (%.2f/min)", itemName, event, productionRate)

	// Send SMS to each recipient
	for _, recipient := range phoneTo {
		apiURL := fmt.Sprintf("https://api.twilio.com/2010-04-01/Accounts/%s/Messages.json", accountSID)

		data := url.Values{}
		data.Set("From", phoneFrom)
		data.Set("To", recipient)
		data.Set("Body", message)

		req, err := http.NewRequestWithContext(ctx, "POST", apiURL, strings.NewReader(data.Encode()))
		if err != nil {
			return fmt.Errorf("failed to create Twilio request: %w", err)
		}

		req.SetBasicAuth(accountSID, authToken)
		req.Header.Set("Content-Type", "application/x-www-form-urlencoded")

		resp, err := s.client.Do(req)
		if err != nil {
			return fmt.Errorf("failed to send Twilio SMS to %s: %w", recipient, err)
		}
		defer resp.Body.Close()

		if resp.StatusCode < 200 || resp.StatusCode >= 300 {
			var errorResp map[string]interface{}
			json.NewDecoder(resp.Body).Decode(&errorResp)
			return fmt.Errorf("twilio returned error for %s: %d - %v", recipient, resp.StatusCode, errorResp)
		}
	}

	return nil
}
