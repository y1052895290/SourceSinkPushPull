-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param short_name string
local function generate_icon_sprite(short_name)
    ---@type data.SpritePrototype
    return {
        type = "sprite", name = "sspp-" .. short_name .. "-icon",
        filename = "__SourceSinkPushPull__/graphics/gui/sspp-" .. short_name .. "-icon.png",
        size = 32, scale = 0.5, flags = { "gui-icon" },
    }
end

---@param what string
---@param number string
local function generate_mode_sprite(what, number)
    ---@type data.SpritePrototype
    return {
        type = "sprite", name = "sspp-" .. what .. "-mode-" .. number,
        filename = "__SourceSinkPushPull__/graphics/gui/" .. what .. "-mode/" .. number .. ".png",
        size = { 20, 32 }, scale = 0.5, flags = { "gui-icon" },
    }
end

--------------------------------------------------------------------------------

return {
    generate_icon_sprite("bufferless"),
    generate_icon_sprite("bypass"),
    generate_icon_sprite("copy"),
    generate_icon_sprite("create"),
    generate_icon_sprite("delete"),
    generate_icon_sprite("disable"),
    generate_icon_sprite("export"),
    generate_icon_sprite("grid"),
    generate_icon_sprite("import"),
    generate_icon_sprite("inactivity"),
    generate_icon_sprite("map"),
    generate_icon_sprite("move-down"),
    generate_icon_sprite("move-up"),
    generate_icon_sprite("name"),
    generate_icon_sprite("network"),
    -- generate_icon_sprite("refresh"),
    generate_icon_sprite("reset"),
    generate_icon_sprite("signal"),

    generate_mode_sprite("provide", "1"),
    generate_mode_sprite("provide", "2"),
    generate_mode_sprite("provide", "3"),
    generate_mode_sprite("provide", "4"),
    generate_mode_sprite("provide", "5"),
    generate_mode_sprite("provide", "6"),

    generate_mode_sprite("request", "1"),
    generate_mode_sprite("request", "2"),
    generate_mode_sprite("request", "3"),
    generate_mode_sprite("request", "4"),
    generate_mode_sprite("request", "5"),
    generate_mode_sprite("request", "6"),
}
