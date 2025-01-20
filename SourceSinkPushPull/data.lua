-- SSPP by jagoly

flib = require("__flib__.data-util")

require("prototypes.entity")
require("prototypes.item")
require("prototypes.technology")
require("prototypes.sprite")

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
    sspp_fuel_icon,
    sspp_depot_icon,
})

require("prototypes.style")
