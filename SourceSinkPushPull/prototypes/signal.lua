-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param number string
local function generate_number_signal(number)
    ---@type data.VirtualSignalPrototype
    return {
        type = "virtual-signal", name = "sspp-signal-" .. number,
        icon = "__SourceSinkPushPull__/graphics/icons/sspp-signal-" .. number .. ".png",
        icon_size = 64, subgroup = "sspp-signals",
    }
end

---@type data.ItemSubGroup
local subgroup_signals = { type = "item-subgroup", name = "sspp-signals", group = "signals", order = "f" }

--------------------------------------------------------------------------------

return {
    subgroup_signals,

    generate_number_signal("0"),
    generate_number_signal("1"),
    generate_number_signal("2"),
    generate_number_signal("3"),
    generate_number_signal("4"),
    generate_number_signal("5"),
    generate_number_signal("6"),
    generate_number_signal("7"),
    generate_number_signal("8"),
    generate_number_signal("9"),
}
