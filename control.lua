local Constants = require("cloudmonitoring.constants")
local Config = require("cloudmonitoring.config")
local Gui = require("cloudmonitoring.gui")
local Items = require("cloudmonitoring.items")

local function init_all()
  Config.sanitize_all()
  Items.rebuild_cache()
  for _, player in pairs(game.players) do
    Gui.ensure_top_button(player)
  end
end

script.on_init(init_all)
script.on_configuration_changed(init_all)

script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then
    Gui.ensure_top_button(player)
  end
end)

script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.get_player(event.player_index)
  if player then
    Config.sanitize_all()
    Gui.ensure_top_button(player)
    Gui.refresh_properties_for_player(player)
  end
end)

script.on_event(Constants.events.hotkey_toggle_gui, function(event)
  local player = game.get_player(event.player_index)
  if player then
    Gui.toggle(player)
  end
end)

commands.add_command("cloudmonitoring", "Open the CloudMonitoring config GUI", function(cmd)
  local player = game.get_player(cmd.player_index)
  if player then
    Gui.open(player)
  end
end)

commands.add_command("cm", "Open the CloudMonitoring config GUI", function(cmd)
  local player = game.get_player(cmd.player_index)
  if player then
    Gui.open(player)
  end
end)

script.on_event(defines.events.on_gui_click, Gui.on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, Gui.on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_text_changed, Gui.on_gui_text_changed)

remote.add_interface("cloudmonitoring", {
  sync_property_change = function(property_name, enabled)
    local property_names = Config.get_force_property_names()
    Config.sanitize_enabled_properties(property_names)
    if type(property_name) ~= "string" or type(enabled) ~= "boolean" then
      log("CloudMonitoring: sync_property_change received invalid arguments")
      return
    end
    if global.cloudmonitoring_config.enabled_properties[property_name] == nil then
      log("CloudMonitoring: sync_property_change received unknown property: " .. property_name)
      return
    end
    Config.set_property_enabled(property_name, enabled)
    Gui.refresh_properties_for_all_players()
  end,
})
