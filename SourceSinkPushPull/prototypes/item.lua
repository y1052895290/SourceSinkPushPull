-- SSPP by jagoly

--------------------------------------------------------------------------------

local subgroup = data.raw["item"]["train-stop"].subgroup
local order = data.raw["item"]["train-stop"].order

stop_item = flib.copy_prototype(data.raw["item"]["train-stop"], "sspp-stop", true) --[[@as data.ItemPrototype]]
stop_item.icon = "__SourceSinkPushPull__/graphics/icons/sspp-stop.png"
stop_item.order = order .. "-a"

general_io_item = flib.copy_prototype(data.raw["item"]["decider-combinator"], "sspp-general-io", true) --[[@as data.ItemPrototype]]
general_io_item.icon = "__SourceSinkPushPull__/graphics/icons/sspp-general-io.png"
general_io_item.subgroup = subgroup
general_io_item.order = order .. "-sspp-a"

provide_io_item = flib.copy_prototype(data.raw["item"]["arithmetic-combinator"], "sspp-provide-io", true) --[[@as data.ItemPrototype]]
provide_io_item.icon = "__SourceSinkPushPull__/graphics/icons/sspp-provide-io.png"
provide_io_item.subgroup = subgroup
provide_io_item.order = order .. "-sspp-b"

request_io_item = flib.copy_prototype(data.raw["item"]["arithmetic-combinator"], "sspp-request-io", true) --[[@as data.ItemPrototype]]
request_io_item.icon = "__SourceSinkPushPull__/graphics/icons/sspp-request-io.png"
request_io_item.subgroup = subgroup
request_io_item.order = order .. "-sspp-c"

--------------------------------------------------------------------------------

stop_recipe = flib.copy_prototype(data.raw["recipe"]["train-stop"], "sspp-stop") ---@type data.RecipePrototype
stop_recipe.ingredients = {
	{ type = "item", name = "train-stop", amount = 1 },
	{ type = "item", name = "electronic-circuit", amount = 1 },
}
stop_recipe.enabled = false

general_io_recipe = flib.copy_prototype(data.raw["recipe"]["arithmetic-combinator"], "sspp-general-io") ---@type data.RecipePrototype
general_io_recipe.ingredients = {
	{ type = "item", name = "arithmetic-combinator", amount = 1 },
	{ type = "item", name = "decider-combinator", amount = 1 },
}
general_io_recipe.enabled = false

provide_io_recipe = flib.copy_prototype(data.raw["recipe"]["decider-combinator"], "sspp-provide-io") ---@type data.RecipePrototype
provide_io_recipe.ingredients = {
	{ type = "item", name = "arithmetic-combinator", amount = 1 },
	{ type = "item", name = "decider-combinator", amount = 1 },
}
provide_io_recipe.enabled = false

request_io_recipe = flib.copy_prototype(data.raw["recipe"]["decider-combinator"], "sspp-request-io") ---@type data.RecipePrototype
request_io_recipe.ingredients = {
	{ type = "item", name = "arithmetic-combinator", amount = 1 },
	{ type = "item", name = "decider-combinator", amount = 1 },
}
request_io_recipe.enabled = false
