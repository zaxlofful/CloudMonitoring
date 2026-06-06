local mod_gui = require("mod-gui")

local Constants = require("cloudmonitoring.constants")
local Config = require("cloudmonitoring.config")
local Items = require("cloudmonitoring.items")
local Presets = require("cloudmonitoring.presets")

local Gui = {}

local function shallow_copy_keys(tbl)
  local out = {}
  for k, v in pairs(tbl) do
    out[k] = v
  end
  return out
end

local function get_frame(player)
  return player.gui.screen[Constants.gui.frame_name]
end

local function destroy_if_valid(element)
  if element and element.valid then
    element.destroy()
  end
end

local function set_filter_visible(frame, visible)
  local container = frame[Constants.gui.item_filter_container_name]
  if container and container.valid then
    container.visible = visible
  end
end

local function build_titlebar(frame)
  local titlebar = frame.add({ type = "flow", direction = "horizontal" })
  titlebar.drag_target = frame

  titlebar.add({ type = "label", caption = "CloudMonitoring Config", style = "frame_title" })

  local draggable_space = titlebar.add({ type = "empty-widget", style = "draggable_space_header" })
  draggable_space.style.horizontally_stretchable = true
  draggable_space.style.height = 24
  draggable_space.drag_target = frame

  titlebar.add({
    type = "sprite-button",
    name = Constants.gui.close_name,
    sprite = "utility/close",
    style = "frame_action_button",
    tooltip = "Close",
  })
end

local function build_presets(frame)
  local outer = frame.add({ type = "flow", direction = "vertical" })
  outer.style.bottom_padding = 8

  outer.add({ type = "label", caption = "Presets:" })

  local row1 = outer.add({ type = "flow", direction = "horizontal" })
  row1.add({ type = "button", name = Constants.gui.preset_items_only_name, caption = "Items Only" })
  row1.add({ type = "button", name = Constants.gui.preset_all_data_name, caption = "All Data" })

  local row2 = outer.add({ type = "flow", direction = "horizontal" })
  row2.add({ type = "button", name = Constants.gui.preset_production_only_name, caption = "Production Only" })
end

local function build_properties_section(frame, player)
  frame.add({ type = "label", caption = "Data to Log" })

  local scroll = frame.add({
    type = "scroll-pane",
    name = Constants.gui.properties_scroll_name,
    direction = "vertical",
    vertical_scroll_policy = "auto-and-reserve-space",
    horizontal_scroll_policy = "never",
  })
  scroll.style.maximal_height = 320
  scroll.style.minimal_width = 560

  local property_names = Config.get_force_property_names()
  for _, prop in ipairs(property_names) do
    scroll.add({
      type = "checkbox",
      caption = prop,
      state = Config.is_property_enabled(prop),
      tags = { cloudmonitoring_kind = "property", key = prop },
    })
  end
end

local function rebuild_items_list(frame, player)
  local filter_tbl = Config.get_player_filter(player.index)

  local items_scroll = frame[Constants.gui.item_filter_container_name][Constants.gui.items_scroll_name]
  if not (items_scroll and items_scroll.valid) then
    return
  end

  items_scroll.clear()

  local all_names = Items.get_all_names()
  local visible_names = Items.filter_names(all_names, filter_tbl.search_text)

  for _, name in ipairs(visible_names) do
    items_scroll.add({
      type = "checkbox",
      caption = name,
      state = filter_tbl.items[name] == true,
      tags = { cloudmonitoring_kind = "item", key = name },
    })
  end
end

local function build_item_filter_section(frame, player)
  local container = frame.add({ type = "flow", name = Constants.gui.item_filter_container_name, direction = "vertical" })
  container.style.top_padding = 8

  container.add({ type = "label", caption = "Item Filter" })

  local filter_tbl = Config.get_player_filter(player.index)

  container.add({
    type = "checkbox",
    name = Constants.gui.item_filter_enabled_name,
    caption = "Enable item filter (log only selected items)",
    state = filter_tbl.enabled == true,
    tooltip = "When disabled, item production statistics will include all items.",
  })

  local search_row = container.add({ type = "flow", direction = "horizontal" })
  search_row.add({ type = "label", caption = "Filter items:" })
  search_row.add({
    type = "textfield",
    name = Constants.gui.item_search_name,
    text = filter_tbl.search_text or "",
    tooltip = "Comma- or space-separated. Matches partial names.",
  })
  search_row[Constants.gui.item_search_name].style.horizontally_stretchable = true

  local buttons = container.add({ type = "flow", name = Constants.gui.item_buttons_flow_name, direction = "horizontal" })
  buttons.add({ type = "button", name = Constants.gui.item_select_all_name, caption = "Select All" })
  buttons.add({ type = "button", name = Constants.gui.item_clear_all_name, caption = "Clear All" })

  local scroll = container.add({
    type = "scroll-pane",
    name = Constants.gui.items_scroll_name,
    direction = "vertical",
    vertical_scroll_policy = "auto-and-reserve-space",
    horizontal_scroll_policy = "never",
  })
  scroll.style.maximal_height = 320
  scroll.style.minimal_width = 560

  rebuild_items_list(frame, player)
end

local function build_footer(frame)
  local footer = frame.add({ type = "flow", direction = "horizontal" })
  footer.style.top_padding = 8

  footer.add({ type = "button", name = Constants.gui.reset_defaults_name, caption = "Reset to Defaults" })
  footer.add({ type = "empty-widget" }).style.horizontally_stretchable = true
  footer.add({ type = "button", name = Constants.gui.close_name .. "_bottom", caption = "Close" })
end

function Gui.ensure_top_button(player)
  local flow = mod_gui.get_button_flow(player)
  if flow[Constants.gui.toggle_button_name] then
    return
  end
  flow.add({
    type = "sprite-button",
    name = Constants.gui.toggle_button_name,
    sprite = "utility/settings",
    style = mod_gui.button_style,
    tooltip = "CloudMonitoring Config",
  })
end

function Gui.open(player)
  Config.sanitize_all()

  local existing = get_frame(player)
  if existing then
    existing.bring_to_front()
    return
  end

  local frame = player.gui.screen.add({ type = "frame", name = Constants.gui.frame_name, direction = "vertical" })
  frame.auto_center = true
  frame.style.width = 600

  build_titlebar(frame)
  build_presets(frame)
  build_properties_section(frame, player)
  build_item_filter_section(frame, player)
  build_footer(frame)

  set_filter_visible(frame, Config.is_property_enabled(Config.default_property_name()))
  frame.force_auto_center()
end

function Gui.close(player)
  destroy_if_valid(get_frame(player))
end

function Gui.toggle(player)
  local frame = get_frame(player)
  if frame and frame.valid then
    Gui.close(player)
  else
    Gui.open(player)
  end
end

function Gui.refresh_properties_for_player(player)
  local frame = get_frame(player)
  if not (frame and frame.valid) then
    return
  end

  local scroll = frame[Constants.gui.properties_scroll_name]
  if not (scroll and scroll.valid) then
    return
  end

  for _, child in ipairs(scroll.children) do
    if child and child.valid and child.type == "checkbox" then
      local tags = child.tags or {}
      if tags.cloudmonitoring_kind == "property" and type(tags.key) == "string" then
        child.state = Config.is_property_enabled(tags.key)
      end
    end
  end

  set_filter_visible(frame, Config.is_property_enabled(Config.default_property_name()))
end

function Gui.refresh_properties_for_all_players()
  for _, player in pairs(game.connected_players) do
    pcall(Gui.refresh_properties_for_player, player)
  end
end

function Gui.refresh_items_for_player(player)
  local frame = get_frame(player)
  if not (frame and frame.valid) then
    return
  end
  rebuild_items_list(frame, player)
end

function Gui.apply_preset(player, preset_name)
  if preset_name == "items_only" then
    Presets.apply_items_only(player.index)
  elseif preset_name == "all_data" then
    Presets.apply_all_data(player.index)
  elseif preset_name == "production_only" then
    Presets.apply_production_only(player.index)
  end

  Gui.refresh_properties_for_all_players()
  Gui.refresh_items_for_player(player)
end

function Gui.on_gui_click(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local name = element.name
  if name == Constants.gui.toggle_button_name then
    Gui.toggle(player)
    return
  end

  if name == Constants.gui.close_name or name == (Constants.gui.close_name .. "_bottom") then
    Gui.close(player)
    return
  end

  if name == Constants.gui.reset_defaults_name then
    Presets.apply_items_only(player.index)
    Gui.refresh_properties_for_all_players()
    Gui.refresh_items_for_player(player)
    return
  end

  if name == Constants.gui.preset_items_only_name then
    Gui.apply_preset(player, "items_only")
    return
  end

  if name == Constants.gui.preset_all_data_name then
    Gui.apply_preset(player, "all_data")
    return
  end

  if name == Constants.gui.preset_production_only_name then
    Gui.apply_preset(player, "production_only")
    return
  end

  if name == Constants.gui.item_select_all_name then
    local filter_tbl = Config.get_player_filter(player.index)
    local visible = Items.filter_names(Items.get_all_names(), filter_tbl.search_text)
    for _, item_name in ipairs(visible) do
      filter_tbl.items[item_name] = true
    end
    Config.set_player_filter(player.index, filter_tbl)
    if not game.is_multiplayer() then
      global.cloudmonitoring_config.item_filter = { enabled = filter_tbl.enabled, items = shallow_copy_keys(filter_tbl.items) }
    end
    Gui.refresh_items_for_player(player)
    return
  end

  if name == Constants.gui.item_clear_all_name then
    local filter_tbl = Config.get_player_filter(player.index)
    local visible = Items.filter_names(Items.get_all_names(), filter_tbl.search_text)
    for _, item_name in ipairs(visible) do
      filter_tbl.items[item_name] = nil
    end
    Config.set_player_filter(player.index, filter_tbl)
    if not game.is_multiplayer() then
      global.cloudmonitoring_config.item_filter = { enabled = filter_tbl.enabled, items = shallow_copy_keys(filter_tbl.items) }
    end
    Gui.refresh_items_for_player(player)
    return
  end
end

function Gui.on_gui_checked_state_changed(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  if element.name == Constants.gui.item_filter_enabled_name then
    local filter_tbl = Config.get_player_filter(player.index)
    filter_tbl.enabled = element.state == true
    Config.set_player_filter(player.index, filter_tbl)
    if not game.is_multiplayer() then
      global.cloudmonitoring_config.item_filter = { enabled = filter_tbl.enabled, items = shallow_copy_keys(filter_tbl.items) }
    end
    Gui.refresh_items_for_player(player)
    return
  end

  local tags = element.tags or {}
  if tags.cloudmonitoring_kind == "property" and type(tags.key) == "string" then
    Config.set_property_enabled(tags.key, element.state == true)
    Gui.refresh_properties_for_all_players()
    return
  end

  if tags.cloudmonitoring_kind == "item" and type(tags.key) == "string" then
    local filter_tbl = Config.get_player_filter(player.index)
    if element.state == true then
      filter_tbl.items[tags.key] = true
    else
      filter_tbl.items[tags.key] = nil
    end
    Config.set_player_filter(player.index, filter_tbl)
    if not game.is_multiplayer() then
      global.cloudmonitoring_config.item_filter = { enabled = filter_tbl.enabled, items = shallow_copy_keys(filter_tbl.items) }
    end
    return
  end
end

function Gui.on_gui_text_changed(event)
  local element = event.element
  if not (element and element.valid) then
    return
  end
  if element.name ~= Constants.gui.item_search_name then
    return
  end

  local player = game.get_player(event.player_index)
  if not player then
    return
  end

  local filter_tbl = Config.get_player_filter(player.index)
  filter_tbl.search_text = element.text or ""
  Config.set_player_filter(player.index, filter_tbl)
  Gui.refresh_items_for_player(player)
end

return Gui
