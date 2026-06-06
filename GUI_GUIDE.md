# CloudMonitoring - In-Game Configuration GUI

## Overview

CloudMonitoring is a Factorio mod that provides an in-game GUI for configuring what game data is logged and exported. The mod allows you to selectively choose which `game.forces` properties to track and which items to monitor, with full support for both single-player and multiplayer scenarios.

## Features

### 1. **Comprehensive Data Selection**
- Toggle any `game.forces` property for logging
- Properties include:
  - Production statistics (items and fluids)
  - Kill count statistics
  - Build count statistics
  - Evolution factor
  - Technology modifiers
  - Character bonuses
  - And many more...

### 2. **Item Filtering**
- **Text Search**: Quickly filter items by typing names (supports comma or space separation)
- **Checklist**: Browse and select items from a scrollable list
- **Select All / Clear All**: Bulk operations for convenience
- **Real-time Updates**: Item list updates as you type

### 3. **Configuration Persistence**
- Config saves automatically to your game save file
- Survives game restarts and mod updates
- Handles missing items and new properties gracefully

### 4. **Multiplayer Support**
- **Server Config**: Property selections are shared across all players
- **Client Config**: Item filters are personal to each player
- **Auto-sync**: New players joining receive current server config

### 5. **Quick Presets**
Three built-in presets for common scenarios:
- **Items Only**: Track only item production (default behavior)
- **All Data**: Enable all available properties
- **Production Only**: Track items and fluids with common production items pre-selected

## How to Use

### Opening the Configuration GUI

You can open the configuration GUI in three ways:

1. **Hotkey**: Press `Ctrl+M` (default, customizable in Controls settings)
2. **Command**: Type `/cloudmonitoring` or `/cm` in the console
3. **Mod Menu**: (If implemented by game version)

### Configuring Properties

1. Open the GUI using any method above
2. Scroll through the "Data to Log" section
3. Check/uncheck properties you want to enable/disable
4. Changes save automatically

### Filtering Items

1. Check "Enable item filtering" to activate item filtering
   - When **unchecked**: All items are logged (default)
   - When **checked**: Only selected items are logged

2. Use the text filter to search for items:
   - Type item names or partial names
   - Separate multiple terms with commas or spaces
   - Example: `iron, copper` or `iron copper`

3. Select items from the filtered list
4. Use "Select All" to select all currently visible (filtered) items
5. Use "Clear All" to deselect all items

### Using Presets

Click any preset button to quickly configure common scenarios:
- **Items Only**: Resets to track only item production
- **All Data**: Enables all tracking properties
- **Production Only**: Focuses on production with key items pre-selected

### Resetting Configuration

Click "Reset to Defaults" to restore the original configuration:
- Only `item_production_statistics` enabled
- No item filtering active

## Configuration Structure

The mod stores configuration in `global.cloudmonitoring_config`:

```lua
global.cloudmonitoring_config = {
  version = 1,
  enabled_properties = {
    item_production_statistics = true,
    fluid_production_statistics = false,
    -- ... all other properties
  },
  item_filter = {
    enabled = false,
    items = {}
  }
}
```

Per-player item filters are stored in `global.cloudmonitoring_client_filters[player_index]`.

## Multiplayer Behavior

### Property Changes (Server-Wide)
- When any player changes a property checkbox, the change broadcasts to all players
- All players will log the same `game.forces` properties
- Ensures consistent data collection across the server

### Item Filters (Per-Player)
- Each player can set their own item filter without affecting others
- Allows players to focus on different aspects of production
- Item filters are stored per-player and persist across sessions

### Joining Mid-Game
- New players automatically receive the current server property configuration
- They start with default (empty) item filters

## Edge Cases & Robustness

The mod handles several edge cases gracefully:

1. **New Items**: If items are added by other mods, they appear in the item list automatically
2. **New Properties**: On mod updates, new `game.forces` properties are added to config with default values
3. **Corrupted Config**: Invalid data is sanitized on load; severe corruption triggers a reset to defaults
4. **Mod Removal/Re-add**: Config reconstructs from defaults if missing

## Technical Details

### Default Configuration
On first use, only `item_production_statistics` is enabled by default, matching the original mod behavior.

### Performance
- Item list only rebuilds when filter text changes (not every frame)
- Uses Factorio's native GUI system for optimal performance
- Minimal overhead on game performance

### Data Output Integration
The configuration system is designed to work with a separate data output component:
- This GUI mod handles configuration storage
- A data output mod (separate) reads `global.cloudmonitoring_config` to filter exported data
- Clean separation of concerns

## Troubleshooting

### GUI won't open
- Verify the mod is installed and enabled
- Check that you're using the correct hotkey (default: `Ctrl+M`)
- Try using the `/cloudmonitoring` command instead

### Config not persisting
- Ensure you're saving the game after making changes
- Check for other mods that might interfere with the `global` table
- Try resetting to defaults and reconfiguring

### Multiplayer sync issues
- All players should have the same mod version installed
- If properties aren't syncing, try having each player close and reopen the GUI
- Check server logs for warnings or errors

## Version History

### 0.1.0
- Initial release with in-game configuration GUI
- Property selection with all `game.forces` properties
- Item filtering with text search and checklist
- Three built-in presets
- Full multiplayer support with server/client config separation
- Config persistence and edge case handling

## Credits

**Author**: Zax Lofful
**Factorio Version**: 0.17+
**License**: See LICENSE file

## Support

For bug reports, feature requests, or questions, please visit the mod's repository or forum thread.
