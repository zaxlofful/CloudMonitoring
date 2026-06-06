package file

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strconv"

	"github.com/zaxlofful/CloudMonitoring/backend/state"
)

var fileNamePattern = regexp.MustCompile(`^cloudmonitoring-data-(\d+)\.json$`)

// ParseJSONFile parses a production data JSON file
func ParseJSONFile(path string) (*state.ProductionData, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("failed to read file: %w", err)
	}

	var prodData state.ProductionData
	if err := json.Unmarshal(data, &prodData); err != nil {
		return nil, fmt.Errorf("failed to parse JSON: %w", err)
	}

	return &prodData, nil
}

// ExtractTimestampFromFilename extracts timestamp from filename
func ExtractTimestampFromFilename(filename string) (int64, error) {
	matches := fileNamePattern.FindStringSubmatch(filename)
	if len(matches) < 2 {
		return 0, fmt.Errorf("filename does not match pattern")
	}

	timestamp, err := strconv.ParseInt(matches[1], 10, 64)
	if err != nil {
		return 0, fmt.Errorf("failed to parse timestamp: %w", err)
	}

	return timestamp, nil
}

// IsDataFile checks if a filename is a valid data file
func IsDataFile(filename string) bool {
	return fileNamePattern.MatchString(filename)
}

// ScanDirectory scans a directory for data files
func ScanDirectory(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		if os.IsPermission(err) {
			return nil, fmt.Errorf("permission denied: %w", err)
		}
		return nil, fmt.Errorf("failed to read directory: %w", err)
	}

	var files []string
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		if IsDataFile(entry.Name()) {
			files = append(files, filepath.Join(dir, entry.Name()))
		}
	}

	return files, nil
}
