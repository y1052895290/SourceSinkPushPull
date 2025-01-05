-- SSPP by jagoly

--------------------------------------------------------------------------------

local function reboot_command()
    for _, network in pairs(storage.networks) do
        network.provide_haulers = {}
        network.request_haulers = {}
        network.fuel_haulers = {}
        network.depot_haulers = {}
        network.liquidate_haulers = {}
    end

    local invalid_haulers = {}
    for hauler_id, hauler in pairs(storage.haulers) do
        local train = hauler.train
        if train.valid then
            hauler.to_provide = nil
            hauler.to_request = nil
            hauler.to_fuel = nil
            hauler.to_depot = nil
            hauler.to_liquidate = nil
            train.manual_mode = true
        else
            invalid_haulers[#invalid_haulers+1] = hauler_id
        end
    end
    for _, hauler_id in pairs(invalid_haulers) do
        storage.haulers[hauler_id] = nil
    end

    storage.stations = {}
    storage.stop_combs = {}
    storage.comb_stops = {}

    for _, surface in pairs(game.surfaces) do
        for _, stop in pairs(surface.find_entities_filtered({ ghost_name = "sspp-stop" })) do
            on_stop_built(stop)
        end
        for _, stop in pairs(surface.find_entities_filtered({ name = "sspp-stop" })) do
            on_stop_built(stop)
        end
    end

    for _, hauler in pairs(storage.haulers) do
        hauler.train.manual_mode = false
    end

    storage.tick_state = "INITIAL"
end

commands.add_command("sspp-reboot", { "sspp-console.reboot-command-help" }, reboot_command)
