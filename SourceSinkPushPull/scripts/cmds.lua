-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local main = require("__SourceSinkPushPull__.scripts.main")

local cmds = {}

--------------------------------------------------------------------------------

function cmds.sspp_reboot()
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

    storage.stations = {}
    storage.stop_comb_ids = {}
    storage.comb_stop_ids = {}
    storage.entities = {}

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
end

--------------------------------------------------------------------------------

function cmds.register_commands()
    commands.add_command("sspp-reboot", { "sspp-console.reboot-command-help" }, cmds.sspp_reboot)
end

--------------------------------------------------------------------------------

return cmds
