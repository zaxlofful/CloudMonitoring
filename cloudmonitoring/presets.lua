local Config = require("cloudmonitoring.config")
local Items = require("cloudmonitoring.items")

local Presets = {}

local function map_all_properties(value)
  local property_names = Config.get_force_property_names()
  local out = {}
  for _, name in ipairs(property_names) do
    out[name] = value
  end
  return out
end

function Presets.apply_items_only(player_index)
  local enabled = map_all_properties(false)
  enabled[Config.default_property_name()] = true
  Config.apply_preset_enabled_properties(enabled)
  Config.reset_player_filter(player_index)
end

function Presets.apply_all_data(player_index)
  Config.apply_preset_enabled_properties(map_all_properties(true))
  Config.reset_player_filter(player_index)
end

function Presets.apply_production_only(player_index)
  local enabled = map_all_properties(false)
  enabled[Config.default_property_name()] = true
  Config.apply_preset_enabled_properties(enabled)

  local filter_tbl = Config.get_player_filter(player_index)
  filter_tbl.enabled = true
  filter_tbl.items = {}
  for _, name in ipairs(Items.production_preset_items()) do
    filter_tbl.items[name] = true
  end
  Config.set_player_filter(player_index, filter_tbl)
end

return Presets
