package state

import "sync"

// ItemState represents the production state of a single item
type ItemState struct {
	State    string  // "producing", "alerted", "recovering"
	LastRate float64 // Last observed production rate (items/minute)
}

// ProductionData represents parsed data from a JSON file
type ProductionData struct {
	Timestamp int64      `json:"timestamp"`
	Tick      int64      `json:"tick"`
	Items     []ItemData `json:"items"`
}

// ItemData represents production/consumption data for a single item
type ItemData struct {
	Name             string `json:"name"`
	ProductionCount  int64  `json:"production_count"`
	ConsumptionCount int64  `json:"consumption_count"`
}

// StateManager manages alert state for all items
type StateManager struct {
	mu    sync.RWMutex
	items map[string]*ItemState
	data  map[int64]*ProductionData // keyed by timestamp
}

// NewStateManager creates a new StateManager
func NewStateManager() *StateManager {
	return &StateManager{
		items: make(map[string]*ItemState),
		data:  make(map[int64]*ProductionData),
	}
}

// GetState returns the current state of an item (thread-safe)
func (sm *StateManager) GetState(itemName string) *ItemState {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return sm.items[itemName]
}

// SetState updates the state of an item (thread-safe)
func (sm *StateManager) SetState(itemName string, state *ItemState) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.items[itemName] = state
}

// AddData adds production data to the rolling window
func (sm *StateManager) AddData(data *ProductionData) {
	sm.mu.Lock()
	defer sm.mu.Unlock()
	sm.data[data.Timestamp] = data
}

// GetAllItems returns all tracked item names
func (sm *StateManager) GetAllItems() []string {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	items := make([]string, 0, len(sm.items))
	for item := range sm.items {
		items = append(items, item)
	}
	return items
}

// PruneOldData removes data older than the cutoff time
func (sm *StateManager) PruneOldData(cutoffTimestamp int64) int {
	sm.mu.Lock()
	defer sm.mu.Unlock()

	pruned := 0
	for ts := range sm.data {
		if ts < cutoffTimestamp {
			delete(sm.data, ts)
			pruned++
		}
	}
	return pruned
}

// GetDataCount returns the number of data entries in memory
func (sm *StateManager) GetDataCount() int {
	sm.mu.RLock()
	defer sm.mu.RUnlock()
	return len(sm.data)
}
