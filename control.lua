-- CloudMonitoring Config GUI
-- Provides in-game configuration interface for selecting game.forces properties and item filters

-- ============================================================================
-- CONSTANTS AND DEFAULTS
-- ============================================================================

local GUI_NAME = "cloudmonitoring_config_gui"
local CONFIG_VERSION = 1

-- Default configuration
local DEFAULT_CONFIG = {
  version = CONFIG_VERSION,
  enabled_properties = {
    item_production_statistics = true,
    fluid_production_statistics = false,
    kill_count_statistics = false,
    entity_build_count_statistics = false,
    ammo_damage_modifier = false,
    turret_attack_modifier = false,
    gun_speed_modifier = false,
    technologies = false,
    recipes = false,
    manual_mining_speed_modifier = false,
    manual_crafting_speed_modifier = false,
    laboratory_speed_modifier = false,
    laboratory_productivity_bonus = false,
    worker_robots_speed_modifier = false,
    worker_robots_battery_modifier = false,
    worker_robots_storage_bonus = false,
    character_trash_slot_count = false,
    max_successful_attempts_per_tick_per_construction_queue = false,
    max_failed_attempts_per_tick_per_construction_queue = false,
    inserter_stack_size_bonus = false,
    stack_inserter_capacity_bonus = false,
    character_health_bonus = false,
    character_build_distance_bonus = false,
    character_item_drop_distance_bonus = false,
    character_reach_distance_bonus = false,
    character_resource_reach_distance_bonus = false,
    character_item_pickup_distance_bonus = false,
    character_loot_pickup_distance_bonus = false,
    character_inventory_slots_bonus = false,
    character_logistic_trash_slots = false,
    character_running_speed_modifier = false,
    evolution_factor = false,
    friendly_fire = false,
    share_chart = false,
    research_queue_enabled = false
  },
  item_filter = {
    enabled = false,
    items = {}
  }
}

-- Presets
local PRESETS = {
  items_only = {
    name = "Items Only",
    config = function()
      local config = table.deepcopy(DEFAULT_CONFIG)
      config.enabled_properties.item_production_statistics = true
      config.enabled_properties.fluid_production_statistics = false
      config.item_filter.enabled = false
      config.item_filter.items = {}
      return config
    end
  },
  all_data = {
    name = "All Data",
    config = function()
      local config = table.deepcopy(DEFAULT_CONFIG)
      for property, _ in pairs(config.enabled_properties) do
        config.enabled_properties[property] = true
      end
      config.item_filter.enabled = false
      config.item_filter.items = {}
      return config
    end
  },
  production_only = {
    name = "Production Only",
    config = function()
      local config = table.deepcopy(DEFAULT_CONFIG)
      config.enabled_properties.item_production_statistics = true
      config.enabled_properties.fluid_production_statistics = true
      config.item_filter.enabled = true
      -- Add common production items
      config.item_filter.items = {
        ["iron-plate"] = true,
        ["copper-plate"] = true,
        ["steel-plate"] = true,
        ["iron-gear-wheel"] = true,
        ["copper-cable"] = true,
        ["electronic-circuit"] = true,
        ["advanced-circuit"] = true,
        ["processing-unit"] = true
      }
      return config
    end
  }
}

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Deep copy table
function table.deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == 'table' then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[table.deepcopy(orig_key)] = table.deepcopy(orig_value)
    end
    setmetatable(copy, table.deepcopy(getmetatable(orig)))
  else
    copy = orig
  end
  return copy
end

-- ============================================================================
-- CONFIG MANAGEMENT
-- ============================================================================

-- Initialize global config
local function init_config()
  if not global.cloudmonitoring_config then
    global.cloudmonitoring_config = table.deepcopy(DEFAULT_CONFIG)
  end

  if not global.cloudmonitoring_client_filters then
    global.cloudmonitoring_client_filters = {}
  end

  -- Validate and update config version
  if not global.cloudmonitoring_config.version or global.cloudmonitoring_config.version < CONFIG_VERSION then
    -- Merge with defaults for any missing properties
    for key, value in pairs(DEFAULT_CONFIG) do
      if global.cloudmonitoring_config[key] == nil then
        global.cloudmonitoring_config[key] = table.deepcopy(value)
      end
    end
    global.cloudmonitoring_config.version = CONFIG_VERSION
  end
end

-- Get player-specific filter config
local function get_player_filter_config(player_index)
  if not global.cloudmonitoring_client_filters[player_index] then
    global.cloudmonitoring_client_filters[player_index] = {
      enabled = false,
      items = {},
      filter_text = ""
    }
  end
  return global.cloudmonitoring_client_filters[player_index]
end

-- Save property change (broadcast in multiplayer)
local function save_property_change(property_name, enabled)
  global.cloudmonitoring_config.enabled_properties[property_name] = enabled

  -- In multiplayer, broadcast to all players
  if game.is_multiplayer() then
    for _, player in pairs(game.players) do
      if player.gui.screen[GUI_NAME] then
        update_gui(player)
      end
    end
  end
end

-- Save item filter change (per-player)
local function save_item_filter_change(player_index, item_name, enabled)
  local filter_config = get_player_filter_config(player_index)
  if enabled then
    filter_config.items[item_name] = true
  else
    filter_config.items[item_name] = nil
  end
end

-- ============================================================================
-- GUI CREATION
-- ============================================================================

-- Get all game items sorted alphabetically
local function get_all_items()
  local items = {}
  for name, prototype in pairs(game.item_prototypes) do
    table.insert(items, {name = name, localised_name = prototype.localised_name})
  end
  table.sort(items, function(a, b) return a.name < b.name end)
  return items
end

-- Filter items based on search text
local function filter_items(items, filter_text)
  if not filter_text or filter_text == "" then
    return items
  end

  -- Support comma or space separated search terms
  local search_terms = {}
  for term in string.gmatch(filter_text:lower(), "[^,%s]+") do
    table.insert(search_terms, term)
  end

  local filtered = {}
  for _, item in ipairs(items) do
    local item_name_lower = item.name:lower()
    for _, term in ipairs(search_terms) do
      if string.find(item_name_lower, term, 1, true) then
        table.insert(filtered, item)
        break
      end
    end
  end
  return filtered
end

-- Create the main GUI
local function create_gui(player)
  -- Destroy existing GUI if present
  if player.gui.screen[GUI_NAME] then
    player.gui.screen[GUI_NAME].destroy()
  end

  local filter_config = get_player_filter_config(player.index)

  -- Main frame
  local main_frame = player.gui.screen.add{
    type = "frame",
    name = GUI_NAME,
    direction = "vertical",
    caption = "CloudMonitoring Configuration"
  }
  main_frame.auto_center = true
  main_frame.style.minimal_width = 600
  main_frame.style.minimal_height = 400

  -- Presets section
  local presets_flow = main_frame.add{
    type = "flow",
    direction = "horizontal"
  }
  presets_flow.add{type = "label", caption = "Presets:"}
  presets_flow.add{
    type = "button",
    name = "cloudmonitoring_preset_items_only",
    caption = PRESETS.items_only.name
  }
  presets_flow.add{
    type = "button",
    name = "cloudmonitoring_preset_all_data",
    caption = PRESETS.all_data.name
  }
  presets_flow.add{
    type = "button",
    name = "cloudmonitoring_preset_production_only",
    caption = PRESETS.production_only.name
  }

  -- Separator
  main_frame.add{type = "line"}

  -- Properties section
  main_frame.add{
    type = "label",
    caption = "Data to Log:",
    style = "heading_2_label"
  }

  local properties_scroll = main_frame.add{
    type = "scroll-pane",
    direction = "vertical",
    vertical_scroll_policy = "auto-and-reserve-space"
  }
  properties_scroll.style.maximal_height = 200
  properties_scroll.style.minimal_width = 550

  -- Add checkboxes for each property
  local sorted_properties = {}
  for property, _ in pairs(global.cloudmonitoring_config.enabled_properties) do
    table.insert(sorted_properties, property)
  end
  table.sort(sorted_properties)

  for _, property in ipairs(sorted_properties) do
    local checkbox = properties_scroll.add{
      type = "checkbox",
      name = "cloudmonitoring_property_" .. property,
      caption = property,
      state = global.cloudmonitoring_config.enabled_properties[property] or false
    }
  end

  -- Separator
  main_frame.add{type = "line"}

  -- Item filter section
  main_frame.add{
    type = "label",
    caption = "Item Filter:",
    style = "heading_2_label"
  }

  local filter_enabled_checkbox = main_frame.add{
    type = "checkbox",
    name = "cloudmonitoring_filter_enabled",
    caption = "Enable item filtering (unchecked = log all items)",
    state = filter_config.enabled
  }

  local filter_textfield = main_frame.add{
    type = "textfield",
    name = "cloudmonitoring_filter_text",
    text = filter_config.filter_text or ""
  }
  filter_textfield.style.minimal_width = 550
  filter_textfield.enabled = filter_config.enabled

  -- Select All / Clear All buttons
  local filter_buttons_flow = main_frame.add{
    type = "flow",
    direction = "horizontal"
  }
  local select_all_btn = filter_buttons_flow.add{
    type = "button",
    name = "cloudmonitoring_select_all_items",
    caption = "Select All"
  }
  select_all_btn.enabled = filter_config.enabled

  local clear_all_btn = filter_buttons_flow.add{
    type = "button",
    name = "cloudmonitoring_clear_all_items",
    caption = "Clear All"
  }
  clear_all_btn.enabled = filter_config.enabled

  -- Item list
  local items_scroll = main_frame.add{
    type = "scroll-pane",
    name = "cloudmonitoring_items_scroll",
    direction = "vertical",
    vertical_scroll_policy = "auto-and-reserve-space"
  }
  items_scroll.style.maximal_height = 200
  items_scroll.style.minimal_width = 550

  -- Populate item list
  update_item_list(player)

  -- Separator
  main_frame.add{type = "line"}

  -- Bottom buttons
  local bottom_flow = main_frame.add{
    type = "flow",
    direction = "horizontal"
  }
  bottom_flow.add{
    type = "button",
    name = "cloudmonitoring_reset",
    caption = "Reset to Defaults"
  }

  local spacer = bottom_flow.add{
    type = "empty-widget"
  }
  spacer.style.horizontally_stretchable = true

  bottom_flow.add{
    type = "button",
    name = "cloudmonitoring_close",
    caption = "Close"
  }

  player.opened = main_frame
end

-- Update item list based on filter
local function update_item_list(player)
  local gui = player.gui.screen[GUI_NAME]
  if not gui then return end

  local items_scroll = gui.cloudmonitoring_items_scroll
  if not items_scroll then return end

  local filter_config = get_player_filter_config(player.index)
  local filter_text_elem = gui.cloudmonitoring_filter_text
  local filter_text = filter_text_elem and filter_text_elem.text or ""

  -- Clear existing items
  items_scroll.clear()

  if not filter_config.enabled then
    items_scroll.add{
      type = "label",
      caption = "Item filtering is disabled. All items will be logged."
    }
    return
  end

  -- Get and filter items
  local all_items = get_all_items()
  local filtered_items = filter_items(all_items, filter_text)

  -- Add checkboxes for filtered items
  for _, item in ipairs(filtered_items) do
    local checkbox = items_scroll.add{
      type = "checkbox",
      name = "cloudmonitoring_item_" .. item.name,
      caption = item.name,
      state = filter_config.items[item.name] or false
    }
  end

  if #filtered_items == 0 then
    items_scroll.add{
      type = "label",
      caption = "No items match the filter."
    }
  end
end

-- Update GUI state (called when config changes)
local function update_gui(player)
  local gui = player.gui.screen[GUI_NAME]
  if not gui then return end

  -- Update property checkboxes
  for property, enabled in pairs(global.cloudmonitoring_config.enabled_properties) do
    local checkbox = gui["cloudmonitoring_property_" .. property]
    if checkbox then
      checkbox.state = enabled
    end
  end

  -- Update item list
  update_item_list(player)
end

-- Toggle GUI visibility
local function toggle_gui(player)
  if player.gui.screen[GUI_NAME] then
    player.gui.screen[GUI_NAME].destroy()
  else
    create_gui(player)
  end
end

-- ============================================================================
-- PRESET FUNCTIONS
-- ============================================================================

local function apply_preset(player, preset_key)
  local preset = PRESETS[preset_key]
  if not preset then return end

  local new_config = preset.config()

  -- Apply property settings (server-wide)
  global.cloudmonitoring_config.enabled_properties = new_config.enabled_properties

  -- Apply item filter settings (per-player)
  local filter_config = get_player_filter_config(player.index)
  filter_config.enabled = new_config.item_filter.enabled
  filter_config.items = new_config.item_filter.items
  filter_config.filter_text = ""

  -- Update all player GUIs in multiplayer
  if game.is_multiplayer() then
    for _, p in pairs(game.players) do
      if p.gui.screen[GUI_NAME] then
        update_gui(p)
      end
    end
  else
    update_gui(player)
  end
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Initialize on mod load
script.on_init(function()
  init_config()
end)

script.on_configuration_changed(function()
  init_config()
end)

-- Handle hotkey press
script.on_event("cloudmonitoring-toggle-gui", function(event)
  local player = game.players[event.player_index]
  toggle_gui(player)
end)

-- Handle command
commands.add_command("cloudmonitoring", "Open CloudMonitoring configuration", function(cmd)
  local player = game.players[cmd.player_index]
  if player.gui.screen[GUI_NAME] then
    player.gui.screen[GUI_NAME].destroy()
  else
    create_gui(player)
  end
end)

commands.add_command("cm", "Open CloudMonitoring configuration", function(cmd)
  local player = game.players[cmd.player_index]
  if player.gui.screen[GUI_NAME] then
    player.gui.screen[GUI_NAME].destroy()
  else
    create_gui(player)
  end
end)

-- Handle GUI clicks
script.on_event(defines.events.on_gui_click, function(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Close button
  if element.name == "cloudmonitoring_close" then
    if player.gui.screen[GUI_NAME] then
      player.gui.screen[GUI_NAME].destroy()
    end

  -- Reset button
  elseif element.name == "cloudmonitoring_reset" then
    global.cloudmonitoring_config = table.deepcopy(DEFAULT_CONFIG)
    local filter_config = get_player_filter_config(player.index)
    filter_config.enabled = false
    filter_config.items = {}
    filter_config.filter_text = ""

    if game.is_multiplayer() then
      for _, p in pairs(game.players) do
        if p.gui.screen[GUI_NAME] then
          update_gui(p)
        end
      end
    else
      update_gui(player)
    end

  -- Preset buttons
  elseif element.name == "cloudmonitoring_preset_items_only" then
    apply_preset(player, "items_only")
  elseif element.name == "cloudmonitoring_preset_all_data" then
    apply_preset(player, "all_data")
  elseif element.name == "cloudmonitoring_preset_production_only" then
    apply_preset(player, "production_only")

  -- Select All / Clear All
  elseif element.name == "cloudmonitoring_select_all_items" then
    local filter_config = get_player_filter_config(player.index)
    local all_items = get_all_items()
    local filter_text = player.gui.screen[GUI_NAME].cloudmonitoring_filter_text.text
    local filtered_items = filter_items(all_items, filter_text)

    for _, item in ipairs(filtered_items) do
      filter_config.items[item.name] = true
    end
    update_item_list(player)

  elseif element.name == "cloudmonitoring_clear_all_items" then
    local filter_config = get_player_filter_config(player.index)
    filter_config.items = {}
    update_item_list(player)
  end
end)

-- Handle checkbox state changes
script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Property checkboxes
  if string.match(element.name, "^cloudmonitoring_property_") then
    local property = string.sub(element.name, 27) -- Remove "cloudmonitoring_property_" prefix
    save_property_change(property, element.state)

  -- Item checkboxes
  elseif string.match(element.name, "^cloudmonitoring_item_") then
    local item_name = string.sub(element.name, 23) -- Remove "cloudmonitoring_item_" prefix
    save_item_filter_change(player.index, item_name, element.state)

  -- Filter enabled checkbox
  elseif element.name == "cloudmonitoring_filter_enabled" then
    local filter_config = get_player_filter_config(player.index)
    filter_config.enabled = element.state

    -- Enable/disable filter controls
    local gui = player.gui.screen[GUI_NAME]
    if gui then
      gui.cloudmonitoring_filter_text.enabled = element.state
      gui.cloudmonitoring_select_all_items.enabled = element.state
      gui.cloudmonitoring_clear_all_items.enabled = element.state
      update_item_list(player)
    end
  end
end)

-- Handle text field changes
script.on_event(defines.events.on_gui_text_changed, function(event)
  local player = game.players[event.player_index]
  local element = event.element

  if not element or not element.valid then return end

  -- Filter text field
  if element.name == "cloudmonitoring_filter_text" then
    local filter_config = get_player_filter_config(player.index)
    filter_config.filter_text = element.text
    update_item_list(player)
  end
end)

-- Handle GUI close
script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.name == GUI_NAME then
    event.element.destroy()
  end
end)

-- Sync config to newly joined players (multiplayer)
script.on_event(defines.events.on_player_joined_game, function(event)
  local player = game.players[event.player_index]
  -- Initialize player-specific filter config
  get_player_filter_config(player.index)
end)

-- ============================================================================
-- DATA OUTPUT (Original functionality preserved)
-- ============================================================================

function instrumental_output(line)
  game.write_file("factorio." .. game.tick, line .. "\n", true)
end

script.on_nth_tick(900, -- every 15 seconds
  function(event)
    -- Use the config to determine what to output
    local config = global.cloudmonitoring_config
    if not config then
      config = table.deepcopy(DEFAULT_CONFIG)
    end

    for k, force in pairs(game.forces) do
      -- Item production statistics
      if config.enabled_properties.item_production_statistics then
        for item, amount in pairs(force.item_production_statistics.input_counts) do
          -- Check per-player filters (output from all players, or first player, or aggregate)
          -- For now, we'll output all items unless a global filter is set
          instrumental_output("item_production." .. item .. " " .. amount)
        end
        for item, amount in pairs(force.item_production_statistics.output_counts) do
          instrumental_output("item_consumption." .. item .. " " .. amount)
        end
      end

      -- Fluid production statistics
      if config.enabled_properties.fluid_production_statistics then
        for item, amount in pairs(force.fluid_production_statistics.input_counts) do
          instrumental_output("fluid_production." .. item .. " " .. amount)
        end
        for item, amount in pairs(force.fluid_production_statistics.output_counts) do
          instrumental_output("fluid_consumption." .. item .. " " .. amount)
        end
      end

      -- Add more property outputs as needed
      if config.enabled_properties.evolution_factor then
        instrumental_output("evolution_factor " .. force.evolution_factor)
      end
    end
  end
)
