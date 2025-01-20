-- SSPP by jagoly

local flib_migration = require("__flib__.migration")

local migrations_table = {
    ["0.2.0"] = function()
        if storage.player_states then
            storage.player_guis = storage.player_states
            storage.player_states = nil
        end
        for _, station in pairs(storage.stations) do
            station.network = station.stop.surface.name
        end
        for _, entity in pairs(storage.entities) do
            if entity.name == "sspp-provide-io" then
                local json = helpers.json_to_table(entity.combinator_description) --[[@as table]]
                local provide_items = {} ---@type {[ItemKey]: ProvideItem}
                for item_key, item in pairs(json) do
                    if item[1] then goto next_entity end
                    provide_items[item_key] = { list_index = item.list_index, push = item.push, throughput = item.throughput, latency = item.latency, granularity = item.granularity }
                end
                entity.combinator_description = provide_items_to_combinator_description(provide_items)
            end
            if entity.name == "sspp-request-io" then
                local json = helpers.json_to_table(entity.combinator_description) --[[@as table]]
                local request_items = {} ---@type {[ItemKey]: RequestItem}
                for item_key, item in pairs(json) do
                    if item[1] then goto next_entity end
                    request_items[item_key] = { list_index = item.list_index, pull = item.pull, throughput = item.throughput, latency = item.latency }
                end
                entity.combinator_description = request_items_to_combinator_description(request_items)
            end
            ::next_entity::
        end
    end,
}

---@param data ConfigurationChangedData
function on_config_changed(data)
    storage.tick_state = "INITIAL"

    flib_migration.on_config_changed(data, migrations_table)
end
