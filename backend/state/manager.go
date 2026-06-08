package state

import (
	"context"
	"log"
	"time"
)

// AlertTransition represents a state transition that triggers an alert
type AlertTransition struct {
	ItemName     string
	FromState    string
	ToState      string
	ProductionRate float64
	Timestamp    time.Time
}

// CalculateProductionRate calculates items/minute from production counts
// Factorio statistics are cumulative, so we need to calculate delta over time
func CalculateProductionRate(currentCount, previousCount int64, timeDeltaSeconds float64) float64 {
	if timeDeltaSeconds <= 0 {
		return 0
	}
	delta := float64(currentCount - previousCount)
	ratePerSecond := delta / timeDeltaSeconds
	return ratePerSecond * 60.0 // Convert to per-minute
}

// ProcessProductionData processes new production data and returns alert transitions
func (sm *StateManager) ProcessProductionData(data *ProductionData) []AlertTransition {
	var transitions []AlertTransition

	// Add data to rolling window
	sm.AddData(data)

	// Process each item in the new data
	for _, item := range data.Items {
		itemName := item.Name

		// For simplicity, we'll use production_count directly
		// In a real implementation, we'd calculate rate from deltas
		// For now, treat 0 production_count as zero production rate
		currentRate := float64(item.ProductionCount)

		sm.mu.Lock()
		currentState := sm.items[itemName]
		if currentState == nil {
			// New item - initialize as producing
			sm.items[itemName] = &ItemState{
				State:    "producing",
				LastRate: currentRate,
			}
			sm.mu.Unlock()
			continue
		}

		// Check for state transitions
		var newState string
		var shouldAlert bool

		switch currentState.State {
		case "producing":
			if currentRate == 0 {
				newState = "alerted"
				shouldAlert = true
			} else {
				newState = "producing"
			}

		case "alerted":
			if currentRate > 0 {
				newState = "recovering"
			} else {
				newState = "alerted"
			}

		case "recovering":
			if currentRate == 0 {
				newState = "alerted"
				shouldAlert = true
			} else {
				newState = "producing"
			}
		}

		// Update state
		if newState != currentState.State {
			transitions = append(transitions, AlertTransition{
				ItemName:       itemName,
				FromState:      currentState.State,
				ToState:        newState,
				ProductionRate: currentRate,
				Timestamp:      time.Unix(data.Timestamp, 0),
			})

			sm.items[itemName] = &ItemState{
				State:    newState,
				LastRate: currentRate,
			}
		} else {
			sm.items[itemName].LastRate = currentRate
		}
		sm.mu.Unlock()

		// Only alert on specific transitions
		if !shouldAlert {
			transitions = transitions[:len(transitions)-1] // Remove last transition
		}
	}

	return transitions
}

// StartPruning starts a background goroutine to prune old data
func (sm *StateManager) StartPruning(ctx context.Context, interval time.Duration, maxAge time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			log.Println("Stopping data pruning")
			return
		case <-ticker.C:
			cutoff := time.Now().Add(-maxAge).Unix()
			pruned := sm.PruneOldData(cutoff)
			if pruned > 0 {
				log.Printf("Pruned %d old data entries (total: %d)", pruned, sm.GetDataCount())
			}
		}
	}
}
