local mod_gui = require("__core__/lualib/mod-gui")

local FRAME_NAME = "cloudmonitoring_config_frame"
local MAIN_BUTTON_NAME = "cloudmonitoring_mod_button"
local CLOSE_BUTTON_NAME = "cloudmonitoring_close"
local RESET_BUTTON_NAME = "cloudmonitoring_reset_defaults"
local FILTER_TEXT_NAME = "cloudmonitoring_filter_text"
local PROPERTY_SCROLL_NAME = "cloudmonitoring_property_scroll"
local ITEM_SCROLL_NAME = "cloudmonitoring_item_scroll"
local PRESET_ITEMS_ONLY = "cloudmonitoring_preset_items_only"
local PRESET_ALL_DATA = "cloudmonitoring_preset_all_data"
local PRESET_PRODUCTION_ONLY = "cloudmonitoring_preset_production_only"
local SELECT_ALL_BUTTON = "cloudmonitoring_select_all_items"
local CLEAR_ALL_BUTTON = "cloudmonitoring_clear_all_items"
local CLOSE_FOOTER_BUTTON = "cloudmonitoring_close_footer"
local PROPERTY_PREFIX = "cloudmonitoring_property_"
local ITEM_PREFIX = "cloudmonitoring_item_"
local PROPERTY_SYNC_EVENT = script.generate_event_name()

local PRODUCTION_PRESET_ITEMS = {
  "iron-plate",
  "copper-plate",
  "steel-plate",
  "stone-brick",
  "electronic-circuit",
  "advanced-circuit",
  "processing-unit"
}

local function copy_items(items)
  local copied = {}
  for item_name, enabled in pairs(items or {}) do
    if enabled then
      copied[item_name] = true
    end
  end
  return copied
end

local function sorted_keys(map)
  local keys = {}
  for key in pairs(map or {}) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

local function get_sample_force()
  for _, force in pairs(game.forces) do
    return force
  end
  return nil
end

local function detect_force_properties()
  local properties = {}
  local force = get_sample_force()
  if force then
    for key in pairs(force) do
      if type(key) == "string" and string.sub(key, 1, 2) ~= "__" then
        properties[key] = true
      end
    end
  end

  properties.item_production_statistics = true

  return sorted_keys(properties)
end

local function sanitize_enabled_properties(existing_properties, is_new_config)
  local sanitized = {}
  local property_names = detect_force_properties()

  for _, property_name in ipairs(property_names) do
    local existing_value = existing_properties and existing_properties[property_name]
    if type(existing_value) == "boolean" then
      sanitized[property_name] = existing_value
    else
      sanitized[property_name] = false
    end
  end

  if is_new_config then
    for property_name in pairs(sanitized) do
      sanitized[property_name] = false
    end
    sanitized.item_production_statistics = true
  end

  return sanitized
end

local function sanitize_item_filter(filter)
  local sanitized = {
    enabled = false,
    items = {}
  }

  if type(filter) ~= "table" then
    return sanitized
  end

  if type(filter.items) == "table" then
    for item_name, enabled in pairs(filter.items) do
      if enabled and game.item_prototypes[item_name] then
        sanitized.items[item_name] = true
      end
    end
  end

  sanitized.enabled = next(sanitized.items) ~= nil
  if type(filter.enabled) == "boolean" then
    sanitized.enabled = filter.enabled and next(sanitized.items) ~= nil
  end

  return sanitized
end

local function ensure_runtime_state()
  if type(global.cloudmonitoring_config) ~= "table" then
    global.cloudmonitoring_config = {}
  end

  local had_existing_properties = type(global.cloudmonitoring_config.enabled_properties) == "table"
  global.cloudmonitoring_config.enabled_properties = sanitize_enabled_properties(global.cloudmonitoring_config.enabled_properties, not had_existing_properties)
  global.cloudmonitoring_config.item_filter = sanitize_item_filter(global.cloudmonitoring_config.item_filter)

  if type(global.cloudmonitoring_client_filters) ~= "table" then
    global.cloudmonitoring_client_filters = {}
  end

  if type(global.cloudmonitoring_ui_state) ~= "table" then
    global.cloudmonitoring_ui_state = {}
  end

  for player_index, player in pairs(game.players) do
    local sanitized_filter = sanitize_item_filter(global.cloudmonitoring_client_filters[player_index])
    global.cloudmonitoring_client_filters[player_index] = sanitized_filter

    if not global.cloudmonitoring_ui_state[player_index] then
      global.cloudmonitoring_ui_state[player_index] = { item_search = "" }
    else
      local state = global.cloudmonitoring_ui_state[player_index]
      if type(state.item_search) ~= "string" then
        state.item_search = ""
      end
    end

    if not player or not player.valid then
      global.cloudmonitoring_client_filters[player_index] = nil
      global.cloudmonitoring_ui_state[player_index] = nil
    end
  end
end

local function get_player_ui_state(player_index)
  ensure_runtime_state()
  local state = global.cloudmonitoring_ui_state[player_index]
  if not state then
    state = { item_search = "" }
    global.cloudmonitoring_ui_state[player_index] = state
  end
  return state
end

local function get_player_filter(player_index)
  ensure_runtime_state()
  local filter = global.cloudmonitoring_client_filters[player_index]
  if not filter then
    filter = { enabled = false, items = {} }
    global.cloudmonitoring_client_filters[player_index] = filter
  end
  return filter
end

local function mirror_player_filter_to_shared_config(player_index)
  local filter = get_player_filter(player_index)
  global.cloudmonitoring_config.item_filter = {
    enabled = filter.enabled,
    items = copy_items(filter.items)
  }
end

local function parse_filter_tokens(text)
  local tokens = {}
  local seen = {}

  for token in string.gmatch(string.lower(text or ""), "[^,%s]+") do
    if not seen[token] then
      seen[token] = true
      tokens[#tokens + 1] = token
    end
  end

  return tokens
end

local function item_matches_tokens(item_name, tokens)
  if #tokens == 0 then
    return true
  end

  local lower_name = string.lower(item_name)
  for _, token in ipairs(tokens) do
    if string.find(lower_name, token, 1, true) then
      return true
    end
  end

  return false
end

local function get_filtered_items(search_text)
  local filtered = {}
  local tokens = parse_filter_tokens(search_text)

  for item_name in pairs(game.item_prototypes) do
    if item_matches_tokens(item_name, tokens) then
      filtered[#filtered + 1] = item_name
    end
  end

  table.sort(filtered)
  return filtered, tokens
end

local function create_mod_button(player)
  local button_flow = mod_gui.get_button_flow(player)
  local existing = button_flow[MAIN_BUTTON_NAME]
  if existing and existing.valid then
    return
  end

  button_flow.add {
    type = "sprite-button",
    name = MAIN_BUTTON_NAME,
    caption = "CM",
    tooltip = "Open CloudMonitoring configuration",
    style = mod_gui.button_style,
    sprite = "utility/search_icon"
  }
end

local function update_property_checkboxes(frame)
  local property_scroll = frame[PROPERTY_SCROLL_NAME]
  if not property_scroll then
    return
  end

  property_scroll.clear()
  local property_names = sorted_keys(global.cloudmonitoring_config.enabled_properties)
  for _, property_name in ipairs(property_names) do
    property_scroll.add {
      type = "checkbox",
      name = PROPERTY_PREFIX .. property_name,
      state = global.cloudmonitoring_config.enabled_properties[property_name],
      caption = property_name,
      tooltip = "Include game.forces." .. property_name .. " in CloudMonitoring output"
    }
  end
end

local function update_item_checkboxes(player, frame)
  local item_scroll = frame[ITEM_SCROLL_NAME]
  if not item_scroll then
    return
  end

  item_scroll.clear()
  local filter_state = get_player_filter(player.index)
  local ui_state = get_player_ui_state(player.index)
  local filtered_items = get_filtered_items(ui_state.item_search)

  if #filtered_items == 0 then
    item_scroll.add {
      type = "label",
      caption = "No items match this filter."
    }
    return
  end

  for _, item_name in ipairs(filtered_items) do
    item_scroll.add {
      type = "checkbox",
      name = ITEM_PREFIX .. item_name,
      state = filter_state.items[item_name] == true,
      caption = item_name
    }
  end
end

local function refresh_player_gui(player)
  if not player or not player.valid then
    return
  end

  local frame = player.gui.screen[FRAME_NAME]
  if not frame then
    return
  end

  update_property_checkboxes(frame)

  local search_text = get_player_ui_state(player.index).item_search
  local filter_textfield = frame[FILTER_TEXT_NAME]
  if filter_textfield and filter_textfield.valid then
    filter_textfield.text = search_text
  end

  update_item_checkboxes(player, frame)
end

local function refresh_all_open_guis()
  for _, player in pairs(game.players) do
    if player.valid and player.gui.screen[FRAME_NAME] then
      refresh_player_gui(player)
    end
  end
end

local function build_gui(player)
  ensure_runtime_state()

  local existing = player.gui.screen[FRAME_NAME]
  if existing and existing.valid then
    existing.destroy()
  end

  local frame = player.gui.screen.add {
    type = "frame",
    name = FRAME_NAME,
    direction = "vertical",
    style = "frame",
    caption = "CloudMonitoring Config"
  }

  frame.auto_center = true
  frame.style.minimal_width = 700
  frame.style.minimal_height = 500
  frame.style.maximal_height = 900
  frame.style.horizontally_stretchable = true
  frame.style.vertically_stretchable = true

  local title_bar = frame.add {
    type = "flow",
    direction = "horizontal"
  }
  title_bar.drag_target = frame

  title_bar.add {
    type = "label",
    caption = "CloudMonitoring Config",
    style = "frame_title"
  }

  local drag_handle = title_bar.add {
    type = "empty-widget",
    style = "draggable_space_header"
  }
  drag_handle.style.horizontally_stretchable = true
  drag_handle.style.height = 24

  title_bar.add {
    type = "sprite-button",
    name = CLOSE_BUTTON_NAME,
    style = "frame_action_button",
    sprite = "utility/close_white",
    hovered_sprite = "utility/close_black",
    clicked_sprite = "utility/close_black",
    tooltip = "Close"
  }

  frame.add { type = "line", direction = "horizontal" }

  local preset_frame = frame.add {
    type = "frame",
    direction = "horizontal",
    caption = "Presets"
  }
  preset_frame.style.horizontally_stretchable = true
  preset_frame.add { type = "button", name = PRESET_ITEMS_ONLY, caption = "Items Only" }
  preset_frame.add { type = "button", name = PRESET_ALL_DATA, caption = "All Data" }
  preset_frame.add { type = "button", name = PRESET_PRODUCTION_ONLY, caption = "Production Only" }

  local content_flow = frame.add {
    type = "flow",
    direction = "horizontal"
  }
  content_flow.style.horizontally_stretchable = true
  content_flow.style.vertically_stretchable = true

  local property_frame = content_flow.add {
    type = "frame",
    direction = "vertical",
    caption = "Data to Log"
  }
  property_frame.style.horizontally_stretchable = true
  property_frame.style.vertically_stretchable = true
  property_frame.style.minimal_width = 320

  local property_scroll = property_frame.add {
    type = "scroll-pane",
    name = PROPERTY_SCROLL_NAME,
    direction = "vertical",
    vertical_scroll_policy = "auto",
    horizontal_scroll_policy = "never"
  }
  property_scroll.style.vertically_stretchable = true
  property_scroll.style.horizontally_stretchable = true
  property_scroll.style.maximal_height = 500

  local item_frame = content_flow.add {
    type = "frame",
    direction = "vertical",
    caption = "Item Filter"
  }
  item_frame.style.horizontally_stretchable = true
  item_frame.style.vertically_stretchable = true
  item_frame.style.minimal_width = 320

  item_frame.add {
    type = "label",
    caption = "Filter items (comma or space separated):"
  }

  item_frame.add {
    type = "textfield",
    name = FILTER_TEXT_NAME,
    text = get_player_ui_state(player.index).item_search,
    clear_and_focus_on_right_click = true
  }

  local item_button_row = item_frame.add {
    type = "flow",
    direction = "horizontal"
  }
  item_button_row.style.horizontally_stretchable = true
  item_button_row.add { type = "button", name = SELECT_ALL_BUTTON, caption = "Select All" }
  item_button_row.add { type = "button", name = CLEAR_ALL_BUTTON, caption = "Clear All" }

  local item_scroll = item_frame.add {
    type = "scroll-pane",
    name = ITEM_SCROLL_NAME,
    direction = "vertical",
    vertical_scroll_policy = "auto",
    horizontal_scroll_policy = "never"
  }
  item_scroll.style.vertically_stretchable = true
  item_scroll.style.horizontally_stretchable = true
  item_scroll.style.maximal_height = 500

  frame.add { type = "line", direction = "horizontal" }
  local footer = frame.add { type = "flow", direction = "horizontal" }
  footer.style.horizontally_stretchable = true
  footer.add { type = "button", name = RESET_BUTTON_NAME, caption = "Reset to Defaults" }

  local spacer = footer.add { type = "empty-widget" }
  spacer.style.horizontally_stretchable = true

  footer.add { type = "button", name = CLOSE_FOOTER_BUTTON, caption = "Close" }

  player.opened = frame
  refresh_player_gui(player)
end

local function close_gui(player)
  local frame = player.gui.screen[FRAME_NAME]
  if frame and frame.valid then
    frame.destroy()
  end
end

local function toggle_gui(player)
  if player.gui.screen[FRAME_NAME] then
    close_gui(player)
  else
    build_gui(player)
  end
end

local function apply_property_change(property_name, enabled, source_player_index)
  ensure_runtime_state()

  if type(property_name) ~= "string" then
    log("[CloudMonitoring] Invalid property change payload: property name is not a string")
    return false
  end

  if global.cloudmonitoring_config.enabled_properties[property_name] == nil then
    log("[CloudMonitoring] Ignoring unknown property: " .. property_name)
    return false
  end

  global.cloudmonitoring_config.enabled_properties[property_name] = enabled and true or false
  refresh_all_open_guis()

  if source_player_index and game.players[source_player_index] then
    local source_name = game.players[source_player_index].name
    game.print("[CloudMonitoring] " .. source_name .. " updated " .. property_name .. " = " .. tostring(enabled and true or false))
  end

  return true
end

local function sync_property_change(property_name, enabled, source_player_index)
  local ok, result = pcall(script.raise_event, PROPERTY_SYNC_EVENT, {
    property_name = property_name,
    enabled = enabled,
    source_player_index = source_player_index
  })
  if not ok then
    log("[CloudMonitoring] Property broadcast failed: " .. tostring(result))
    return false
  end
  return true
end

local function update_filter_enabled_state(filter_state)
  filter_state.enabled = next(filter_state.items) ~= nil
end

local function apply_item_selection_for_visible_items(player, enabled)
  local ui_state = get_player_ui_state(player.index)
  local visible_items = get_filtered_items(ui_state.item_search)
  local filter_state = get_player_filter(player.index)

  for _, item_name in ipairs(visible_items) do
    if enabled then
      filter_state.items[item_name] = true
    else
      filter_state.items[item_name] = nil
    end
  end

  update_filter_enabled_state(filter_state)
  mirror_player_filter_to_shared_config(player.index)
  refresh_player_gui(player)
end

local function apply_defaults_for_player(player)
  ensure_runtime_state()
  global.cloudmonitoring_config.enabled_properties = sanitize_enabled_properties(nil, true)
  global.cloudmonitoring_client_filters[player.index] = { enabled = false, items = {} }
  global.cloudmonitoring_ui_state[player.index] = { item_search = "" }
  mirror_player_filter_to_shared_config(player.index)
  refresh_all_open_guis()
end

local function apply_preset(player, preset_name)
  ensure_runtime_state()

  local enabled_properties = sanitize_enabled_properties(global.cloudmonitoring_config.enabled_properties, false)
  for property_name in pairs(enabled_properties) do
    enabled_properties[property_name] = false
  end

  local player_filter = { enabled = false, items = {} }

  if preset_name == PRESET_ALL_DATA then
    for property_name in pairs(enabled_properties) do
      enabled_properties[property_name] = true
    end
  else
    enabled_properties.item_production_statistics = true

    if preset_name == PRESET_PRODUCTION_ONLY then
      for _, item_name in ipairs(PRODUCTION_PRESET_ITEMS) do
        if game.item_prototypes[item_name] then
          player_filter.items[item_name] = true
        end
      end
      player_filter.enabled = next(player_filter.items) ~= nil
    end
  end

  global.cloudmonitoring_config.enabled_properties = enabled_properties
  global.cloudmonitoring_client_filters[player.index] = player_filter
  global.cloudmonitoring_ui_state[player.index] = { item_search = "" }
  mirror_player_filter_to_shared_config(player.index)
  refresh_all_open_guis()
end

local function on_gui_click(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local element_name = element.name

  if element_name == MAIN_BUTTON_NAME then
    toggle_gui(player)
    return
  end

  if element_name == CLOSE_BUTTON_NAME or element_name == CLOSE_FOOTER_BUTTON then
    close_gui(player)
    return
  end

  if element_name == RESET_BUTTON_NAME then
    apply_defaults_for_player(player)
    return
  end

  if element_name == PRESET_ITEMS_ONLY or element_name == PRESET_ALL_DATA or element_name == PRESET_PRODUCTION_ONLY then
    apply_preset(player, element_name)
    return
  end

  if element_name == SELECT_ALL_BUTTON then
    apply_item_selection_for_visible_items(player, true)
    return
  end

  if element_name == CLEAR_ALL_BUTTON then
    apply_item_selection_for_visible_items(player, false)
    return
  end
end

local function on_gui_checked_state_changed(event)
  local element = event.element
  if not (element and element.valid and element.type == "checkbox") then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local element_name = element.name

  if string.sub(element_name, 1, #PROPERTY_PREFIX) == PROPERTY_PREFIX then
    local property_name = string.sub(element_name, #PROPERTY_PREFIX + 1)
    sync_property_change(property_name, element.state, player.index)
    return
  end

  if string.sub(element_name, 1, #ITEM_PREFIX) == ITEM_PREFIX then
    local item_name = string.sub(element_name, #ITEM_PREFIX + 1)
    if game.item_prototypes[item_name] then
      local player_filter = get_player_filter(player.index)
      if element.state then
        player_filter.items[item_name] = true
      else
        player_filter.items[item_name] = nil
      end
      update_filter_enabled_state(player_filter)
      mirror_player_filter_to_shared_config(player.index)
    end
  end
end

local function on_gui_text_changed(event)
  local element = event.element
  if not (element and element.valid and element.name == FILTER_TEXT_NAME and element.type == "textfield") then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local state = get_player_ui_state(player.index)
  state.item_search = element.text or ""
  refresh_player_gui(player)
end

local function on_lua_shortcut(event)
  if event.prototype_name ~= "cloudmonitoring-toggle-gui" then
    return
  end

  local player = game.get_player(event.player_index)
  if player then
    toggle_gui(player)
  end
end

local function on_hotkey(event)
  local player = game.get_player(event.player_index)
  if player then
    toggle_gui(player)
  end
end

local function initialize_player(player)
  if not player or not player.valid then
    return
  end

  ensure_runtime_state()
  create_mod_button(player)
  get_player_filter(player.index)
  get_player_ui_state(player.index)
end

local function on_player_joined(event)
  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  initialize_player(player)
  if player.gui.screen[FRAME_NAME] then
    refresh_player_gui(player)
  end
end

local function on_init()
  ensure_runtime_state()

  for _, player in pairs(game.players) do
    initialize_player(player)
  end
end

local function on_configuration_changed()
  ensure_runtime_state()
  for _, player in pairs(game.players) do
    initialize_player(player)
  end
  refresh_all_open_guis()
end

remote.add_interface("cloudmonitoring", {
  sync_property_change = function(property_name, enabled, source_player_index)
    return apply_property_change(property_name, enabled, source_player_index)
  end,
  get_enabled_properties = function()
    ensure_runtime_state()
    return global.cloudmonitoring_config.enabled_properties
  end
})

commands.add_command("cloudmonitoring", "Open CloudMonitoring config GUI", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  if player then
    build_gui(player)
  end
end)

commands.add_command("cm", "Open CloudMonitoring config GUI", function(command)
  local player = command.player_index and game.get_player(command.player_index)
  if player then
    build_gui(player)
  end
end)

script.on_init(on_init)
script.on_configuration_changed(on_configuration_changed)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  initialize_player(player)
end)
script.on_event(defines.events.on_player_joined_game, on_player_joined)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_checked_state_changed, on_gui_checked_state_changed)
script.on_event(defines.events.on_gui_text_changed, on_gui_text_changed)
script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)
script.on_event(PROPERTY_SYNC_EVENT, function(event)
  apply_property_change(event.property_name, event.enabled, event.source_player_index)
end)
script.on_event("cloudmonitoring-toggle-gui", on_hotkey)
