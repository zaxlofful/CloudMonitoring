# CloudMonitoring
A Factorio mod which facilitates monitoring of the game from the cloud. This will open up extra avenues of data sourcing and allow notifications to the user outside of the game; in the real world.

This code is the mod code, there is also a NodeJS server which accompanies this mod which sends out the Internet connections.

The intent is to be a mod that will show a WEBGUI to the end-user. Using in-game mod tools, the data about how much is being made within certain production networks across planets will be output to a file. That file will be what the WebGUI analyzes to show the end user. It should take a copy of it into RAM to process every 5 seconds.

## Features

### In-Game Configuration GUI
- **Customizable Data Collection**: Select which `game.forces` properties to monitor via an intuitive GUI
- **Item Filtering**: Choose specific items to track with real-time search and filtering
- **Quick Presets**: Apply common configurations instantly (Items Only, All Data, Production Only)
- **Multiplayer Ready**: Server-wide property settings with per-player item filters
- **Persistent Config**: Settings save automatically to your game file

### Access the Configuration
Open the CloudMonitoring configuration GUI using any of these methods:
- Press `Ctrl+M` (customizable hotkey)
- Type `/cloudmonitoring` or `/cm` in the console
- Use the mod menu button (if available)

### Data Output
The mod exports selected game data to files in the Factorio script-output directory:
- Configurable production statistics (items and fluids)
- Force properties (evolution, kill counts, build counts, etc.)
- Real-time updates every 15 seconds

## Usage

1. **Configure what to monitor**: Open the GUI and select properties and items to track
2. **Data is exported**: Selected data writes to `factorio.[tick]` files in script-output
3. **External monitoring**: The Node.js server component processes exported data for web display and alerts

See [GUI_GUIDE.md](GUI_GUIDE.md) for detailed configuration instructions.

## Installation

1. Download or clone this repository
2. Place the mod folder in your Factorio mods directory
3. Enable the mod in Factorio's mod menu
4. Start or load a game and press `Ctrl+M` to configure

## Server Component

A companion Node.js server processes the exported game data and provides:
- Web-based monitoring dashboard
- Real-time alerts and notifications
- Data analysis and visualization

Server setup and configuration details are available in the `server/` directory (if present).

## Technical Details

- **Factorio Version**: 0.17+
- **Config Storage**: `global.cloudmonitoring_config` (persists in save files)
- **Multiplayer**: Full support with shared property config and per-player item filters
- **Performance**: Minimal impact; configurable export frequency

## License

See LICENSE file for details.

## Author

Zax Lofful
