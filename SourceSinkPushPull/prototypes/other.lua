-- SSPP by jagoly

local protos = {}

--------------------------------------------------------------------------------

---@type data.TechnologyPrototype
protos.technology = {
    type = "technology",
    name = "sspp-train-system",
    effects = {
        { type = "unlock-recipe", recipe = "sspp-stop" },
        { type = "unlock-recipe", recipe = "sspp-general-io" },
        { type = "unlock-recipe", recipe = "sspp-provide-io" },
        { type = "unlock-recipe", recipe = "sspp-request-io" },
    },
    prerequisites = { "automated-rail-transportation", "circuit-network" },
    unit = {
        count = 200,
        ingredients = {
            { "automation-science-pack", 1 },
            { "logistic-science-pack", 1 },
        },
        time = 30,
    },
    icon = "__SourceSinkPushPull__/graphics/technology.png",
    icon_size = 256,
}

if mods["pypostprocessing"] then
    protos.technology.unit.ingredients[2][1] = "py-science-pack-1"
end

--------------------------------------------------------------------------------

---@type data.ShortcutPrototype
protos.shortcut = {
    type = "shortcut",
    name = "sspp",
    action = "lua",
    order = "f[sspp]",
    technology_to_unlock = "sspp-train-system",
    unavailable_until_unlocked = true,
    icon = "__SourceSinkPushPull__/graphics/shortcut-x56.png",
    icon_size = 56,
    small_icon = "__SourceSinkPushPull__/graphics/shortcut-x24.png",
    small_icon_size = 24,
}

--------------------------------------------------------------------------------

return protos
