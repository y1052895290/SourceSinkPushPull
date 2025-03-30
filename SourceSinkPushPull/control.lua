-- SSPP by jagoly

require("__SourceSinkPushPull__.scripts.storage")

local gui = require("__SourceSinkPushPull__.scripts.gui")
local main = require("__SourceSinkPushPull__.scripts.main")
local cmds = require("__SourceSinkPushPull__.scripts.cmds")

main.populate_mod_settings()

main.register_event_handlers()
gui.register_event_handlers()

cmds.register_commands()

require("__SourceSinkPushPull__.scripts.tick")
require("__SourceSinkPushPull__.scripts.migrations")
