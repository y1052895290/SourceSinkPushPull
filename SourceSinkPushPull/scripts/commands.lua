-- SSPP by jagoly

local lib = require("scripts.lib")

--------------------------------------------------------------------------------

function main.reboot()
    for _, network in pairs(storage.networks) do
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
        local train = hauler.train
        if train.valid then
            hauler.to_provide = nil
            hauler.to_request = nil
            hauler.to_fuel = nil
            hauler.to_depot = nil
            hauler.at_depot = nil
            train.manual_mode = true
        else
            storage.haulers[hauler_id] = nil
        end
    end

    for _, station in pairs(storage.stations) do
        lib.destroy_hidden_combs(station.provide_hidden_combs)
        lib.destroy_hidden_combs(station.request_hidden_combs)
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
                main.stop_built(entity, nil)
            elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
                main.comb_built(entity, nil)
            end
        end
    end

    for _, hauler in pairs(storage.haulers) do
        hauler.train.manual_mode = false
    end

    storage.tick_state = "INITIAL"
end

commands.add_command("sspp-reboot", { "sspp-console.reboot-command-help" }, main.reboot)
