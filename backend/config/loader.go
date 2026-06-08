package config

import (
	"fmt"
	"os"

	"gopkg.in/yaml.v3"
)

// LoadConfig loads configuration from a YAML file
func LoadConfig(path string) (*Config, error) {
	// Read file
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file: %w", err)
	}

	// Parse YAML
	var cfg Config
	if err := yaml.Unmarshal(data, &cfg); err != nil {
		return nil, fmt.Errorf("failed to parse config YAML: %w", err)
	}

	// Expand environment variables
	cfg.ExpandEnvVars()

	return &cfg, nil
}

// Validate validates the configuration
func (c *Config) Validate() error {
	if len(c.Notifications) == 0 {
		return fmt.Errorf("no notification channels configured")
	}

	enabledCount := 0
	for i, notif := range c.Notifications {
		if !notif.Enabled {
			continue
		}
		enabledCount++

		if notif.Type == "" {
			return fmt.Errorf("notification[%d]: type is required", i)
		}

		// Type-specific validation
		switch notif.Type {
		case "email":
			if notif.GetString("smtp_host") == "" {
				return fmt.Errorf("notification[%d]: email requires smtp_host", i)
			}
			if notif.GetInt("smtp_port") == 0 {
				return fmt.Errorf("notification[%d]: email requires smtp_port", i)
			}
			if notif.GetString("sender_email") == "" {
				return fmt.Errorf("notification[%d]: email requires sender_email", i)
			}
			if len(notif.GetStringSlice("recipients")) == 0 {
				return fmt.Errorf("notification[%d]: email requires at least one recipient", i)
			}

		case "webhook":
			if notif.GetString("url") == "" {
				return fmt.Errorf("notification[%d]: webhook requires url", i)
			}

		case "sms":
			if notif.GetString("provider") == "" {
				return fmt.Errorf("notification[%d]: sms requires provider", i)
			}
			if notif.GetString("phone_from") == "" {
				return fmt.Errorf("notification[%d]: sms requires phone_from", i)
			}
			if len(notif.GetStringSlice("phone_to")) == 0 {
				return fmt.Errorf("notification[%d]: sms requires at least one phone_to", i)
			}
		}
	}

	if enabledCount == 0 {
		return fmt.Errorf("no enabled notification channels")
	}

	return nil
}
