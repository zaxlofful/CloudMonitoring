package config

import (
	"os"
	"strings"
)

// Config represents the application configuration
type Config struct {
	Notifications []NotificationConfig `yaml:"notifications"`
	MonitorItems  []string             `yaml:"monitor_items,omitempty"`
}

// NotificationConfig represents a single notification channel
type NotificationConfig struct {
	Type     string                 `yaml:"type"`
	Enabled  bool                   `yaml:"enabled"`
	Settings map[string]interface{} `yaml:"settings"`
}

// ExpandEnvVars expands environment variables in the config
func (c *Config) ExpandEnvVars() {
	for i := range c.Notifications {
		c.Notifications[i].expandEnvVars()
	}
}

func (nc *NotificationConfig) expandEnvVars() {
	for key, value := range nc.Settings {
		if strVal, ok := value.(string); ok {
			nc.Settings[key] = os.ExpandEnv(strVal)
		} else if arrVal, ok := value.([]interface{}); ok {
			for j, item := range arrVal {
				if strItem, ok := item.(string); ok {
					arrVal[j] = os.ExpandEnv(strItem)
				}
			}
		}
	}
}

// GetString safely gets a string value from settings
func (nc *NotificationConfig) GetString(key string) string {
	if val, ok := nc.Settings[key]; ok {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

// GetInt safely gets an int value from settings
func (nc *NotificationConfig) GetInt(key string) int {
	if val, ok := nc.Settings[key]; ok {
		if intVal, ok := val.(int); ok {
			return intVal
		}
	}
	return 0
}

// GetStringSlice safely gets a string slice from settings
func (nc *NotificationConfig) GetStringSlice(key string) []string {
	if val, ok := nc.Settings[key]; ok {
		if arr, ok := val.([]interface{}); ok {
			result := make([]string, 0, len(arr))
			for _, item := range arr {
				if str, ok := item.(string); ok {
					result = append(result, str)
				}
			}
			return result
		}
	}
	return nil
}

// ShouldMonitorItem checks if an item should be monitored
func (c *Config) ShouldMonitorItem(itemName string) bool {
	// If monitor_items is empty, monitor all items
	if len(c.MonitorItems) == 0 {
		return true
	}

	// Check if item is in the monitor list
	for _, item := range c.MonitorItems {
		if strings.EqualFold(item, itemName) {
			return true
		}
	}
	return false
}
