-- SSPP by jagoly

flib = require("__flib__.data-util")

for _, proto in pairs(require("prototypes.entity")) do data:extend({ proto }) end
for _, proto in pairs(require("prototypes.item")) do data:extend({ proto }) end
for _, proto in pairs(require("prototypes.other")) do data:extend({ proto }) end

data:extend(require("prototypes.signal"))
data:extend(require("prototypes.sprite"))

require("prototypes.style")
