-- SSPP by jagoly

flib = require("__flib__.data-util")

require("prototypes.entity")
require("prototypes.item")
require("prototypes.technology")

data:extend({
    stop_entity,
    general_io_entity,
    provide_io_entity,
    request_io_entity,
    hidden_io_entity,
    stop_item,
    general_io_item,
    provide_io_item,
    request_io_item,
    stop_recipe,
    general_io_recipe,
    provide_io_recipe,
    request_io_recipe,
    technology,
})

require("prototypes.sprite")
require("prototypes.style")
require("prototypes.signal")

data.extend({
    {
        type = "shortcut",
        name = "sspp",
        action = "lua",
        order = "f[sspp]",
        technology_to_unlock = "sspp-train-system",
        unavailable_until_unlocked = true,
        icon = "__SourceSinkPushPull__/graphics/shortcut-x56.png",
        icon_size = 56,
        small_icon = "__SourceSinkPushPull__/graphics/shortcut-x24.png",
        small_icon_size = 24
    }
})
