-- SSPP by jagoly

--------------------------------------------------------------------------------

---@type data.TechnologyPrototype
technology = flib.copy_prototype(data.raw["technology"]["automated-rail-transportation"], "sspp-train-system")

technology.icon = "__SourceSinkPushPull__/graphics/technology.png"
technology.prerequisites = { "automated-rail-transportation", "circuit-network" }
technology.effects = {
    { type = "unlock-recipe", recipe = "sspp-stop" },
    { type = "unlock-recipe", recipe = "sspp-general-io" },
    { type = "unlock-recipe", recipe = "sspp-provide-io" },
    { type = "unlock-recipe", recipe = "sspp-request-io" },
}
technology.unit.ingredients = {
    { "automation-science-pack", 1 },
    { "logistic-science-pack", 1 },
}
technology.unit.count = 200
technology.order = "c-g-c"

if mods["pypostprocessing"] then
    technology.unit.ingredients[2][1] = "py-science-pack-1"
end
