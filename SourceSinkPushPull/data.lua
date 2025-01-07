-- SSPP by jagoly

flib = require('__flib__.data-util')

require('prototypes.entity')
require('prototypes.item')
require('prototypes.technology')

data:extend({
    stop_entity,
    general_io_entity,
    provide_io_entity,
    request_io_entity,
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

require('prototypes.style')