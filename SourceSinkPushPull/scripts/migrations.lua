-- SSPP by jagoly

local flib_migration = require("__flib__.migration")

local migrations_table = {
    ["0.0.1"] = function()
        -- do stuff
    end,
}

---@param data ConfigurationChangedData
function on_config_changed(data)
    storage.tick_state = "INITIAL"

    flib_migration.on_config_changed(data, migrations_table)
end
