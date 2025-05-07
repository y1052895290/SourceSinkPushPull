-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local main = require("__SourceSinkPushPull__.scripts.main")

---@class sspp.cmds
local cmds = {}

--------------------------------------------------------------------------------

---@param command CustomCommandData
function cmds.sspp_reboot(command)
    local player_or_game = command.player_index and game.get_player(command.player_index) or game

    if command.parameter then
        player_or_game.print({ "sspp-console.invalid-arguments" })
        return
    end

    for _, network in pairs(storage.networks) do
        network.job_index_counter = 0
        network.jobs = {}
        network.buffer_haulers = {}
        network.provide_haulers = {}
        network.request_haulers = {}
        network.fuel_haulers = {}
        network.to_depot_haulers = {}
        network.at_depot_haulers = {}
        network.to_depot_liquidate_haulers = {}
        network.at_depot_liquidate_haulers = {}
    end

    for hauler_id, hauler in pairs(storage.haulers) do
        if hauler.train.valid then
            hauler.job = nil
            hauler.to_depot = nil
            hauler.at_depot = nil
            hauler.train.manual_mode = true
        else
            storage.haulers[hauler_id] = nil
        end
    end

    for _, station in pairs(storage.stations) do
        if station.provide then lib.destroy_hidden_combs(station.provide.hidden_combs) end
        if station.request then lib.destroy_hidden_combs(station.request.hidden_combs) end
    end

    storage.entities = {}
    storage.stop_comb_ids = {}
    storage.comb_stop_ids = {}
    storage.stations = {}

    for _, surface in pairs(game.surfaces) do
        for _, entity in pairs(surface.find_entities()) do
            local name = entity.name
            if name == "entity-ghost" then name = entity.ghost_name end

            if name == "sspp-stop" then
                main.station.on_stop_built(entity)
            elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
                main.station.on_comb_built(entity)
            end
        end
    end

    for _, hauler in pairs(storage.haulers) do
        hauler.train.manual_mode = false
    end

    storage.tick_state = "INITIAL"

    player_or_game.print({ "sspp-console.reboot-message", table_size(storage.haulers), table_size(storage.entities), table_size(storage.stations) })
end

--------------------------------------------------------------------------------

---@param command CustomCommandData
function cmds.sspp_update_granularity(command)
    local player_or_game = command.player_index and game.get_player(command.player_index) or game

    local old_value_str, new_value_str = string.match(command.parameter or "", "([%d]+) +([%d]+)")
    local old_value, new_value = tonumber(old_value_str), tonumber(new_value_str)

    if not (old_value and old_value >= 1 and new_value and new_value >= 1) then
        player_or_game.print({ "sspp-console.invalid-arguments" })
        return
    end

    local updated_item_count, updated_station_count = 0, 0

    for _, station in pairs(storage.stations) do
        if station.provide then
            local station_updated = false
            for _, provide_item in pairs(station.provide.items) do
                if provide_item.granularity == old_value then
                    station_updated = true
                    updated_item_count = updated_item_count + 1
                    provide_item.granularity = new_value
                end
            end
            if station_updated then
                updated_station_count = updated_station_count + 1
                station.provide.comb.combinator_description = lib.provide_items_to_combinator_description(station.provide.items)
            end
        end
    end

    player_or_game.print({ "sspp-console.update-granularity-message", updated_item_count, updated_station_count })
end

--------------------------------------------------------------------------------

function cmds.register_commands()
    commands.add_command("sspp-reboot", { "sspp-console.reboot-help" }, cmds.sspp_reboot)
    commands.add_command("sspp-update-granularity", { "sspp-console.update-granularity-help" }, cmds.sspp_update_granularity)
end

--------------------------------------------------------------------------------

return cmds
