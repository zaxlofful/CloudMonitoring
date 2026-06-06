local M = {}

M.gui = {
  frame_name = "cloudmonitoring_config_frame",
  toggle_button_name = "cloudmonitoring_toggle_button",
  properties_scroll_name = "cloudmonitoring_properties_scroll",
  item_filter_container_name = "cloudmonitoring_item_filter_container",
  item_filter_enabled_name = "cloudmonitoring_item_filter_enabled",
  item_search_name = "cloudmonitoring_item_search",
  item_buttons_flow_name = "cloudmonitoring_item_buttons_flow",
  item_select_all_name = "cloudmonitoring_item_select_all",
  item_clear_all_name = "cloudmonitoring_item_clear_all",
  items_scroll_name = "cloudmonitoring_items_scroll",
  reset_defaults_name = "cloudmonitoring_reset_defaults",
  close_name = "cloudmonitoring_close",
  preset_items_only_name = "cloudmonitoring_preset_items_only",
  preset_all_data_name = "cloudmonitoring_preset_all_data",
  preset_production_only_name = "cloudmonitoring_preset_production_only",
}

M.events = {
  hotkey_toggle_gui = "cloudmonitoring-toggle-gui",
}

return M
