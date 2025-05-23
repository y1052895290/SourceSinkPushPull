-- SSPP by jagoly

---@alias TrainColorId "DEPOT"|"FUEL"|"PROVIDE"|"REQUEST"|"LIQUIDATE"

---@class (exact) sspp.config
---@field public auto_paint_trains boolean
---@field public train_colors {[TrainColorId]: Color}
---@field public round_to_stack_size boolean
---@field public default_train_limit integer
---@field public item_inactivity_ticks integer
---@field public fluid_inactivity_ticks integer
---@field public stations_per_tick integer

---@type sspp.config
local config = {} ---@diagnostic disable-line: missing-fields

--------------------------------------------------------------------------------

---@param name string
---@return Color
local function get_rgb_setting(name)
    local rgba = settings.global[name].value --[[@as Color]]
    local a = rgba.a
    return { r = rgba.r * a, g = rgba.g * a, b = rgba.b * a, a = 1.0 }
end

local function populate_settings()
    config.auto_paint_trains = settings.global["sspp-auto-paint-trains"].value --[[@as boolean]]
    config.train_colors = config.train_colors or {}
    config.train_colors.DEPOT = get_rgb_setting("sspp-depot-color")
    config.train_colors.FUEL = get_rgb_setting("sspp-fuel-color")
    config.train_colors.PROVIDE = get_rgb_setting("sspp-provide-color")
    config.train_colors.REQUEST = get_rgb_setting("sspp-request-color")
    config.train_colors.LIQUIDATE = get_rgb_setting("sspp-liquidate-color")
    config.round_to_stack_size = settings.global["sspp-round-to-stack-size"].value --[[@as boolean]]
    config.default_train_limit = settings.global["sspp-default-train-limit"].value --[[@as integer]]
    config.item_inactivity_ticks = settings.global["sspp-item-inactivity-ticks"].value --[[@as integer]]
    config.fluid_inactivity_ticks = settings.global["sspp-fluid-inactivity-ticks"].value --[[@as integer]]
    config.stations_per_tick = settings.global["sspp-stations-per-tick"].value --[[@as integer]]
end

---@param event EventData.on_runtime_mod_setting_changed
local function on_runtime_mod_setting_changed(event)
    populate_settings()
end

--------------------------------------------------------------------------------

populate_settings()

script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

--------------------------------------------------------------------------------

return config