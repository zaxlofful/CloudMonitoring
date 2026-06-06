local Config = {}

local DEFAULT_PROPERTY = "item_production_statistics"

local function is_table(value)
  return type(value) == "table"
end

local function shallow_copy_keys(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    out[k] = v
  end
  return out
end

function Config.get_force_property_names()
  local sample_force
  for _, force in pairs(game.forces) do
    sample_force = force
    break
  end
  if not sample_force then
    return {}
  end

  local names = {}
  for key, value in pairs(sample_force) do
    if type(key) == "string" then
      if key ~= "__self" and not key:find("^__") and type(value) ~= "function" then
        names[#names + 1] = key
      end
    end
  end
  table.sort(names)
  return names
end

function Config.ensure_global_tables()
  global.cloudmonitoring_config = global.cloudmonitoring_config or {}
  global.cloudmonitoring_config.enabled_properties = global.cloudmonitoring_config.enabled_properties or {}
  global.cloudmonitoring_config.item_filter = global.cloudmonitoring_config.item_filter or { enabled = false, items = {} }
  global.cloudmonitoring_client_filters = global.cloudmonitoring_client_filters or {}
end

function Config.sanitize_enabled_properties(property_names)
  Config.ensure_global_tables()

  local enabled = global.cloudmonitoring_config.enabled_properties
  if not is_table(enabled) then
    enabled = {}
    global.cloudmonitoring_config.enabled_properties = enabled
  end

  local known = {}
  for _, name in ipairs(property_names) do
    known[name] = true
    if type(enabled[name]) ~= "boolean" then
      enabled[name] = (name == DEFAULT_PROPERTY)
    end
  end

  for key, value in pairs(shallow_copy_keys(enabled)) do
    if not known[key] or type(value) ~= "boolean" then
      enabled[key] = nil
    end
  end
end

local function sanitize_item_filter_table(filter_tbl)
  if not is_table(filter_tbl) then
    return { enabled = false, items = {} }
  end
  if type(filter_tbl.enabled) ~= "boolean" then
    filter_tbl.enabled = false
  end
  if not is_table(filter_tbl.items) then
    filter_tbl.items = {}
  end
  for key, value in pairs(shallow_copy_keys(filter_tbl.items)) do
    if type(key) ~= "string" or type(value) ~= "boolean" then
      filter_tbl.items[key] = nil
    end
  end
  return filter_tbl
end

function Config.get_player_filter(player_index)
  Config.ensure_global_tables()
  local filter_tbl = global.cloudmonitoring_client_filters[player_index]
  filter_tbl = sanitize_item_filter_table(filter_tbl)
  if type(filter_tbl.search_text) ~= "string" then
    filter_tbl.search_text = ""
  end
  global.cloudmonitoring_client_filters[player_index] = filter_tbl
  return filter_tbl
end

function Config.set_player_filter(player_index, filter_tbl)
  Config.ensure_global_tables()
  global.cloudmonitoring_client_filters[player_index] = sanitize_item_filter_table(filter_tbl)
  if type(global.cloudmonitoring_client_filters[player_index].search_text) ~= "string" then
    global.cloudmonitoring_client_filters[player_index].search_text = ""
  end
end

function Config.reset_player_filter(player_index)
  Config.ensure_global_tables()
  global.cloudmonitoring_client_filters[player_index] = { enabled = false, items = {}, search_text = "" }
  if not game.is_multiplayer() then
    global.cloudmonitoring_config.item_filter = { enabled = false, items = {} }
  end
end

function Config.sanitize_all()
  local property_names = Config.get_force_property_names()
  Config.sanitize_enabled_properties(property_names)

  Config.ensure_global_tables()
  global.cloudmonitoring_config.item_filter = sanitize_item_filter_table(global.cloudmonitoring_config.item_filter)
  if type(global.cloudmonitoring_client_filters) ~= "table" then
    global.cloudmonitoring_client_filters = {}
  end

  if not game.is_multiplayer() then
    local player = game.players[1]
    if player then
      local filter_tbl = Config.get_player_filter(player.index)
      global.cloudmonitoring_config.item_filter = { enabled = filter_tbl.enabled, items = shallow_copy_keys(filter_tbl.items) }
    end
  end
end

function Config.set_property_enabled(property_name, enabled)
  Config.ensure_global_tables()
  if type(property_name) ~= "string" then
    return
  end
  if type(enabled) ~= "boolean" then
    return
  end
  global.cloudmonitoring_config.enabled_properties[property_name] = enabled
end

function Config.is_property_enabled(property_name)
  Config.ensure_global_tables()
  return global.cloudmonitoring_config.enabled_properties[property_name] == true
end

function Config.apply_preset_enabled_properties(enabled_map)
  local property_names = Config.get_force_property_names()
  Config.ensure_global_tables()
  local enabled = global.cloudmonitoring_config.enabled_properties
  for _, name in ipairs(property_names) do
    enabled[name] = enabled_map[name] == true
  end
end

function Config.default_property_name()
  return DEFAULT_PROPERTY
end

return Config
