-- SSPP by jagoly

local protos = {}

--------------------------------------------------------------------------------

local subgroup = data.raw["item"]["train-stop"].subgroup
local order = data.raw["item"]["train-stop"].order

protos.item_stop = flib.copy_prototype(data.raw["item"]["train-stop"], "sspp-stop", true) --[[@as data.ItemPrototype]]
protos.item_stop.icon = "__SourceSinkPushPull__/graphics/icons/sspp-stop.png"
protos.item_stop.order = order .. "-sspp"

protos.item_general_io = flib.copy_prototype(data.raw["item"]["decider-combinator"], "sspp-general-io", true) --[[@as data.ItemPrototype]]
protos.item_general_io.icon = "__SourceSinkPushPull__/graphics/icons/sspp-general-io.png"
protos.item_general_io.subgroup = subgroup
protos.item_general_io.order = order .. "-sspp-a"

protos.item_provide_io = flib.copy_prototype(data.raw["item"]["arithmetic-combinator"], "sspp-provide-io", true) --[[@as data.ItemPrototype]]
protos.item_provide_io.icon = "__SourceSinkPushPull__/graphics/icons/sspp-provide-io.png"
protos.item_provide_io.subgroup = subgroup
protos.item_provide_io.order = order .. "-sspp-b"

protos.item_request_io = flib.copy_prototype(data.raw["item"]["arithmetic-combinator"], "sspp-request-io", true) --[[@as data.ItemPrototype]]
protos.item_request_io.icon = "__SourceSinkPushPull__/graphics/icons/sspp-request-io.png"
protos.item_request_io.subgroup = subgroup
protos.item_request_io.order = order .. "-sspp-c"

--------------------------------------------------------------------------------

protos.recipe_stop = flib.copy_prototype(data.raw["recipe"]["train-stop"], "sspp-stop") --[[@as data.RecipePrototype]]
protos.recipe_stop.ingredients = {
    { type = "item", name = "train-stop", amount = 1 },
    { type = "item", name = "electronic-circuit", amount = 1 },
}
protos.recipe_stop.enabled = false

protos.recipe_general_io = flib.copy_prototype(data.raw["recipe"]["arithmetic-combinator"], "sspp-general-io") --[[@as data.RecipePrototype]]
protos.recipe_general_io.ingredients = {
    { type = "item", name = "arithmetic-combinator", amount = 1 },
    { type = "item", name = "decider-combinator", amount = 1 },
}
protos.recipe_general_io.enabled = false

protos.recipe_provide_io = flib.copy_prototype(data.raw["recipe"]["decider-combinator"], "sspp-provide-io") --[[@as data.RecipePrototype]]
protos.recipe_provide_io.ingredients = {
    { type = "item", name = "arithmetic-combinator", amount = 1 },
    { type = "item", name = "decider-combinator", amount = 1 },
}
protos.recipe_provide_io.enabled = false

protos.recipe_request_io = flib.copy_prototype(data.raw["recipe"]["decider-combinator"], "sspp-request-io") --[[@as data.RecipePrototype]]
protos.recipe_request_io.ingredients = {
    { type = "item", name = "arithmetic-combinator", amount = 1 },
    { type = "item", name = "decider-combinator", amount = 1 },
}
protos.recipe_request_io.enabled = false

--------------------------------------------------------------------------------

return protos
