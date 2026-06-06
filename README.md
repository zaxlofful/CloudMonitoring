# CloudMonitoring
A Factorio mod which facilitates monitoring of the game from the cloud. This will open up extra avenues of data sourcing and allow notifications to the user outside of the game; in the real world.

This code is the mod code, there is also a NodeJS server which accompanies this mod which sends out the Internet connections.

The intent is to be a mode that will show a WEBGUI to the end-user. Using in-game mod tools, the gdata about how much is being made within certain production networks across planets will be output to a file. That file will be what the WebGUI anaylyzeses to show the end user. It should take a copy of it into RAM to process even 5 seconds.

## In-game configuration GUI

This mod provides an in-game configuration GUI for selecting which `game.forces` properties are logged and (when `item_production_statistics` is enabled) filtering which items are included.

Open/close the GUI via:

- Hotkey: `Ctrl + M` (customizable in Factorio controls)
- Command: `/cloudmonitoring` or `/cm`
- Mod GUI button: click the settings icon in the top-left mod GUI bar
