-- SSPP by jagoly

require("__SourceSinkPushPull__.scripts.config")
require("__SourceSinkPushPull__.scripts.glib")
require("__SourceSinkPushPull__.scripts.gui")
require("__SourceSinkPushPull__.scripts.main")

require("__SourceSinkPushPull__.scripts.tick")
require("__SourceSinkPushPull__.scripts.cmds")
require("__SourceSinkPushPull__.scripts.migrations")

local flib_dictionary = require("__flib__.dictionary")

script.on_event(defines.events.on_player_joined_game, flib_dictionary.on_player_joined_game)
script.on_event(defines.events.on_player_locale_changed, flib_dictionary.on_player_locale_changed)
script.on_event(defines.events.on_string_translated, flib_dictionary.on_string_translated)
