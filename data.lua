data:extend({
  {
    type = "custom-input",
    name = "cloudmonitoring-toggle-gui",
    key_sequence = "CONTROL + M",
    consuming = "none"
  },
  {
    type = "shortcut",
    name = "cloudmonitoring-toggle-gui",
    action = "lua",
    associated_control_input = "cloudmonitoring-toggle-gui",
    toggleable = true,
    icon = {
      filename = "__base__/graphics/icons/radar.png",
      priority = "extra-high-no-scale",
      size = 64,
      mipmap_count = 4,
      flags = { "icon" }
    },
    small_icon = {
      filename = "__base__/graphics/icons/radar.png",
      priority = "extra-high-no-scale",
      size = 64,
      mipmap_count = 4,
      flags = { "icon" },
      scale = 0.5
    }
  }
})
