-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local gui = require("__SourceSinkPushPull__.scripts.gui")
local enums = require("__SourceSinkPushPull__.scripts.enums")

local e_train_colors = enums.train_colors

local list_create_or_append, list_destroy_or_remove = lib.list_create_or_append, lib.list_destroy_or_remove
local set_control_behavior, enumerate_spoil_results = lib.set_control_behavior, lib.enumerate_spoil_results
local clear_control_behavior, clear_hidden_control_behaviors = lib.clear_control_behavior, lib.clear_hidden_control_behaviors
local get_train_item_count, send_train_to_named_stop, assign_job_index = lib.get_train_item_count, lib.send_train_to_named_stop, lib.assign_job_index

local on_status_changed, on_job_created, on_job_updated = gui.on_status_changed, gui.on_job_created, gui.on_job_updated

---@class sspp.main.hauler
local main_hauler = {}

--------------------------------------------------------------------------------

--- This function also takes hauler_id as hauler.train can be invalid.
---@param hauler_id HaulerId
---@param hauler Hauler
function main_hauler.on_disabled_or_destroyed(hauler_id, hauler)
    local network = storage.networks[hauler.network]

    local job_index = hauler.job
    if job_index then
        local job = network.jobs[job_index]

        if job.type == "FUEL" then
            list_destroy_or_remove(network.fuel_haulers, hauler.class, hauler_id)
        else
            if job.request_stop then
                if job.request_stop.valid then
                    local station = storage.stations[job.request_stop.unit_number] --[[@as Station]]
                    local request = station.request --[[@as StationRequest]]
                    if station.hauler == hauler_id then
                        clear_control_behavior(request.comb)
                        clear_hidden_control_behaviors(request.hidden_combs)
                        station.hauler = nil
                        station.minimum_active_count = nil
                    end
                    list_destroy_or_remove(request.deliveries, job.item, hauler_id)
                    station.total_deliveries = station.total_deliveries - 1
                end
                list_destroy_or_remove(network.request_haulers, job.item, hauler_id)
            else
                if job.provide_stop.valid then
                    local station = storage.stations[job.provide_stop.unit_number] --[[@as Station]]
                    local provide = station.provide --[[@as StationProvide]]
                    if station.hauler == hauler_id then
                        clear_control_behavior(provide.comb)
                        clear_hidden_control_behaviors(provide.hidden_combs)
                        station.hauler = nil
                        station.minimum_active_count = nil
                        station.bufferless_dispatch = nil
                    end
                    list_destroy_or_remove(provide.deliveries, job.item, hauler_id)
                    station.total_deliveries = station.total_deliveries - 1
                end
                if job.type == "COMBINED" then
                    list_destroy_or_remove(network.provide_haulers, job.item, hauler_id)
                else
                    list_destroy_or_remove(network.buffer_haulers, job.item, hauler_id)
                end
            end

            storage.disabled_items[hauler.network .. ":" .. job.item] = true
        end

        job.abort_tick = game.tick
        hauler.job = nil
        on_job_updated(hauler.network, job_index)

        return
    end

    if hauler.to_depot then
        if hauler.to_depot ~= "" then
            list_destroy_or_remove(network.to_depot_liquidate_haulers, hauler.to_depot, hauler_id)
            storage.disabled_items[hauler.network .. ":" .. hauler.to_depot] = true
        else
            list_destroy_or_remove(network.to_depot_haulers, hauler.class, hauler_id)
        end
        return
    end

    if hauler.at_depot then
        if hauler.at_depot ~= "" then
            list_destroy_or_remove(network.at_depot_liquidate_haulers, hauler.at_depot, hauler_id)
            storage.disabled_items[hauler.network .. ":" .. hauler.at_depot] = true
        else
            list_destroy_or_remove(network.at_depot_haulers, hauler.class, hauler_id)
        end
        return
    end
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main_hauler.on_set_to_manual(hauler)
    main_hauler.on_disabled_or_destroyed(hauler.train.id, hauler)

    hauler.to_depot = nil
    hauler.at_depot = nil

    hauler.train.schedule = nil

    on_status_changed(hauler.train.id)
end

---@param hauler Hauler
function main_hauler.on_set_to_automatic(hauler)
    local network = storage.networks[hauler.network]

    if not network.classes[hauler.class] then
        local train = hauler.train
        hauler.status = { message = { "sspp-alert.class-not-in-network" } }
        lib.show_train_alert(train, hauler.status.message)
        train.manual_mode = true
        return
    end

    main_hauler.send_to_fuel_or_depot(hauler, true, true)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
---@param job NetworkJob.Pickup|NetworkJob.Combined
function main_hauler.on_arrived_at_provide_station(hauler, job)
    local train = hauler.train
    local stop = job.provide_stop --[[@as LuaEntity]]

    if train.station ~= stop then
        hauler.status = { message = { "sspp-alert.arrived-at-wrong-stop" }, item = job.item, stop }
        lib.show_train_alert(train, hauler.status.message)
        train.manual_mode = true
        return
    end

    local station = storage.stations[stop.unit_number] --[[@as Station]]
    local provide = station.provide --[[@as StationProvide]]

    local network_name, item_key = hauler.network, job.item
    local network = storage.networks[network_name]
    local network_item = network.items[item_key]
    local name, quality = network_item.name, network_item.quality

    local provide_item = provide.items[item_key]
    local constant = network_item.delivery_size - provide_item.granularity + 1

    local signal, wait_conditions ---@type SignalID, WaitCondition[]
    if quality then
        signal = { name = name, quality = quality, type = "item" }
        wait_conditions = { { type = "item_count", condition = { first_signal = signal, comparator = ">=", constant = constant } } }
        if station.stop.inactivity then
            wait_conditions[2] = { compare_type = "and", type = "inactivity", ticks = mod_settings.item_inactivity_ticks }
        end
        for i, result_name in enumerate_spoil_results(name) do
            local spoil_signal = { name = result_name, quality = quality, type = "item" }
            local length = #wait_conditions
            wait_conditions[length + 1] = { compare_type = "or", type = "item_count", condition = { first_signal = spoil_signal, comparator = ">", constant = 0 } }
            wait_conditions[length + 2] = { compare_type = "and", type = "inactivity", ticks = mod_settings.item_inactivity_ticks }
            set_control_behavior(provide.hidden_combs[i], 0, "-", spoil_signal, signal)
        end
    else
        signal = { name = name, type = "fluid" }
        wait_conditions = { { type = "fluid_count", condition = { first_signal = signal, comparator = ">=", constant = constant } } }
        if station.stop.inactivity then
            wait_conditions[2] = { compare_type = "and", type = "inactivity", ticks = mod_settings.fluid_inactivity_ticks }
        end
    end
    set_control_behavior(provide.comb, constant, "-", signal)

    station.hauler = train.id
    station.minimum_active_count = provide.counts[item_key]

    job.target_count = network_item.delivery_size
    job.provide_arrive_tick = game.tick
    on_job_updated(network_name, hauler.job)

    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }
end

---@param hauler Hauler
---@param job NetworkJob.Dropoff|NetworkJob.Combined
function main_hauler.on_arrived_at_request_station(hauler, job)
    local train = hauler.train
    local stop = job.request_stop --[[@as LuaEntity]]

    if train.station ~= stop then
        hauler.status = { message = { "sspp-alert.arrived-at-wrong-stop" }, item = job.item, stop }
        lib.show_train_alert(train, hauler.status.message)
        train.manual_mode = true
        return
    end

    local station = storage.stations[stop.unit_number] --[[@as Station]]
    local request = station.request --[[@as StationRequest]]

    local network_name, item_key = hauler.network, job.item
    local network = storage.networks[network_name]
    local network_item = network.items[item_key]
    local name, quality = network_item.name, network_item.quality

    local signal, wait_conditions ---@type SignalID, WaitCondition[]
    if quality then
        signal = { name = name, quality = quality, type = "item" }
        wait_conditions = { { type = "item_count", condition = { first_signal = signal, comparator = "=", constant = 0 } } }
        for i, result_name in enumerate_spoil_results(name) do
            local spoil_signal = { name = result_name, quality = quality, type = "item" }
            wait_conditions[i + 1] = { compare_type = "and", type = "item_count", condition = { first_signal = spoil_signal, comparator = "=", constant = 0 } }
            set_control_behavior(request.hidden_combs[i], 0, "+", spoil_signal)
        end
    else
        signal = { name = name, type = "fluid" }
        wait_conditions = { { type = "fluid_count", condition = { first_signal = signal, comparator = "=", constant = 0 } } }
    end
    set_control_behavior(request.comb, 0, "+", signal)

    station.hauler = train.id
    station.minimum_active_count = request.counts[item_key]

    job.loaded_count = get_train_item_count(train, name, quality)
    job.request_arrive_tick = game.tick
    on_job_updated(network_name, hauler.job)

    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }
end

--------------------------------------------------------------------------------

---@param hauler Hauler
---@param job NetworkJob.Pickup|NetworkJob.Combined
function main_hauler.on_done_at_provide_station(hauler, job)
    local train = hauler.train
    local stop = job.provide_stop --[[@as LuaEntity]]
    local provide = storage.stations[stop.unit_number].provide --[[@as StationProvide]]

    clear_control_behavior(provide.comb)
    clear_hidden_control_behaviors(provide.hidden_combs)

    -- TODO: wait in exit block
    train.schedule = { current = 1, records = { { rail = stop.connected_rail } } }

    if job.type == "COMBINED" then job.provide_done_tick = game.tick else job.finish_tick = game.tick end
    on_job_updated(hauler.network, hauler.job)
    hauler.status = { message = { "sspp-alert.waiting-for-request" }, item = job.item }
    on_status_changed(train.id)
end

---@param hauler Hauler
---@param job NetworkJob.Dropoff|NetworkJob.Combined
function main_hauler.on_done_at_request_station(hauler, job)
    local train = hauler.train
    local stop = job.request_stop --[[@as LuaEntity]]
    local request = storage.stations[stop.unit_number].request --[[@as StationRequest]]

    clear_control_behavior(request.comb)
    clear_hidden_control_behaviors(request.hidden_combs)

    -- TODO: wait in exit block
    train.schedule = { current = 1, records = { { rail = stop.connected_rail } } }

    job.finish_tick = game.tick
    on_job_updated(hauler.network, hauler.job)
    hauler.status = { message = { "sspp-alert.going-to-depot" } }
    on_status_changed(train.id)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
---@param check_fuel boolean
---@param check_cargo boolean
function main_hauler.send_to_fuel_or_depot(hauler, check_fuel, check_cargo)
    local network_name = hauler.network
    local class_name = hauler.class
    local train = hauler.train
    local network = storage.networks[network_name]
    local class = network.classes[class_name]
    local hauler_id = train.id

    if check_fuel then
        local maximum_burn_ticks = 150.0 * 60.0 -- TODO: should be some fraction of the maximum delivery time of items in this class
        for _, loco in pairs(train.carriages) do
            local burner = loco.burner
            if burner then
                local energy = burner.remaining_burning_fuel
                for _, item_with_count in pairs(burner.inventory.get_contents()) do
                    energy = energy + prototypes.item[item_with_count.name].fuel_value * item_with_count.count
                end
                local prototype = loco.prototype
                if prototype.burner_prototype.effectivity * energy < prototype.get_max_energy_usage(loco.quality) * maximum_burn_ticks then
                    list_create_or_append(network.fuel_haulers, class_name, hauler_id)
                    send_train_to_named_stop(train, e_train_colors.fuel, class.fueler_name)
                    assign_job_index(network, hauler, { type = "FUEL", hauler = hauler_id, start_tick = game.tick })
                    on_job_created(network_name)
                    hauler.status = { message = { "sspp-alert.getting-fuel" } }
                    on_status_changed(hauler_id)
                    return
                end
            end
        end
    end

    if check_cargo then
        local train_items, train_fluids = train.get_contents(), train.get_fluid_contents()
        local train_item, train_fluid = train_items[1], next(train_fluids)
        local item_key = train_fluid or (train_item and (train_item.name .. ":" .. (train_item.quality or "normal")))
        if item_key then
            if train_items[2] or next(train_fluids, train_fluid) or (train_item and train_fluid) then
                hauler.status = { message = { "sspp-alert.multiple-items-or-fluids" } }
                lib.show_train_alert(train, hauler.status.message)
                train.manual_mode = true
            elseif not network.items[item_key] then
                hauler.status = { message = { "sspp-alert.cargo-not-in-network" }, item = item_key }
                lib.show_train_alert(train, hauler.status.message)
                train.manual_mode = true
            else
                list_create_or_append(network.to_depot_liquidate_haulers, item_key, hauler_id)
                send_train_to_named_stop(train, e_train_colors.liquidate, class.depot_name)
                hauler.to_depot = item_key
                hauler.status = { message = { class.bypass_depot and "sspp-alert.waiting-for-request" or "sspp-alert.going-to-depot" }, item = item_key }
                on_status_changed(hauler_id)
            end
            return
        end
    end

    list_create_or_append(network.to_depot_haulers, class_name, hauler_id)
    send_train_to_named_stop(train, e_train_colors.depot, class.depot_name)
    hauler.to_depot = ""
    hauler.status = { message = { class.bypass_depot and "sspp-alert.ready-for-dispatch" or "sspp-alert.going-to-depot" } }
    on_status_changed(hauler_id)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
---@param job NetworkJob.Fuel
function main_hauler.on_arrived_at_fuel_stop(hauler, job)
    local train = hauler.train
    local stop = train.station --[[@as LuaEntity]]

    local wait_conditions = { { type = "fuel_full" } }
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }

    job.fuel_stop = stop
    job.fuel_arrive_tick = game.tick
    on_job_updated(hauler.network, hauler.job)
end

---@param hauler Hauler
---@param job NetworkJob.Fuel
function main_hauler.on_done_at_fuel_stop(hauler, job)
    local network_name = hauler.network
    local network = storage.networks[network_name]

    list_destroy_or_remove(network.fuel_haulers, hauler.class, hauler.train.id)

    job.finish_tick = game.tick
    on_job_updated(network_name, hauler.job)

    hauler.job = nil

    main_hauler.send_to_fuel_or_depot(hauler, false, true)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main_hauler.on_arrived_at_depot_stop(hauler)
    local item_key, hauler_id = hauler.to_depot, hauler.train.id
    local network = storage.networks[hauler.network]

    if item_key == "" then
        local class_name = hauler.class
        list_destroy_or_remove(network.to_depot_haulers, class_name, hauler_id)
        list_create_or_append(network.at_depot_haulers, class_name, hauler_id)
        hauler.status = { message = { "sspp-alert.ready-for-dispatch" } }
        on_status_changed(hauler_id)
    else
        ---@cast item_key ItemKey
        list_destroy_or_remove(network.to_depot_liquidate_haulers, item_key, hauler_id)
        list_create_or_append(network.at_depot_liquidate_haulers, item_key, hauler_id)
        hauler.status = { message = { "sspp-alert.waiting-for-request" }, item = item_key }
        on_status_changed(hauler_id)
    end

    hauler.to_depot = nil
    hauler.at_depot = item_key
end

--------------------------------------------------------------------------------

---@param old_train_id uint
---@param new_train LuaTrain?
function main_hauler.on_broken(old_train_id, new_train)
    local hauler = storage.haulers[old_train_id]
    if hauler then
        main_hauler.on_disabled_or_destroyed(old_train_id, hauler)
        storage.haulers[old_train_id] = nil
        if new_train then
            storage.haulers[new_train.id] = {
                train = new_train,
                network = hauler.network,
                class = hauler.class,
                status = { message = { "sspp-gui.not-configured" } },
            }
        end
    end
    gui.on_train_broken(old_train_id, new_train)
end

--------------------------------------------------------------------------------

return main_hauler
