-- SSPP by jagoly

local lib = require("scripts.lib")

local list_create_or_append, list_destroy_or_remove = lib.list_create_or_append, lib.list_destroy_or_remove
local compute_load_target, get_train_item_count = lib.compute_load_target, lib.get_train_item_count
local set_control_behavior, enumerate_spoil_results = lib.set_control_behavior, lib.enumerate_spoil_results
local clear_control_behavior, clear_hidden_control_behaviors = lib.clear_control_behavior, lib.clear_hidden_control_behaviors
local set_hauler_status, send_train_to_named_stop = lib.set_hauler_status, lib.send_train_to_named_stop
local assign_network_hauler_job = lib.assign_network_hauler_job

--------------------------------------------------------------------------------

--- This function also takes hauler_id as hauler.train can be invalid.
---@param hauler_id HaulerId
---@param hauler Hauler
function main.hauler_disabled_or_destroyed(hauler_id, hauler)
    local network = assert(storage.networks[hauler.network])

    if hauler.to_provide then
        local station = assert(storage.stations[hauler.to_provide.station])
        local item_key = hauler.to_provide.item
        storage.disabled_items[hauler.network .. ":" .. item_key] = true
        if station.hauler == hauler_id then
            clear_control_behavior(station.provide_io)
            clear_hidden_control_behaviors(station.provide_hidden_combs)
            station.provide_minimum_active_count = nil
            station.hauler = nil
        end
        if hauler.to_provide.buffer then
            list_destroy_or_remove(network.buffer_haulers, item_key, hauler_id)
        else
            list_destroy_or_remove(network.provide_haulers, item_key, hauler_id)
        end
        list_destroy_or_remove(station.provide_deliveries, item_key, hauler_id)
        station.total_deliveries = station.total_deliveries - 1
    end

    if hauler.to_request then
        local station = assert(storage.stations[hauler.to_request.station])
        local item_key = hauler.to_request.item
        storage.disabled_items[hauler.network .. ":" .. item_key] = true
        if station.hauler == hauler_id then
            clear_control_behavior(station.request_io)
            clear_hidden_control_behaviors(station.request_hidden_combs)
            station.request_minimum_active_count = nil
            station.hauler = nil
        end
        list_destroy_or_remove(network.request_haulers, item_key, hauler_id)
        list_destroy_or_remove(station.request_deliveries, item_key, hauler_id)
        station.total_deliveries = station.total_deliveries - 1
    end

    if hauler.to_fuel then
        list_destroy_or_remove(network.fuel_haulers, hauler.class, hauler_id)
    end

    if hauler.to_depot then
        if hauler.to_depot ~= "" then
            list_destroy_or_remove(network.to_depot_liquidate_haulers, hauler.to_depot, hauler_id)
            storage.disabled_items[hauler.network .. ":" .. hauler.to_depot] = true
        else
            list_destroy_or_remove(network.to_depot_haulers, hauler.class, hauler_id)
        end
    end

    if hauler.at_depot then
        if hauler.at_depot ~= "" then
            list_destroy_or_remove(network.at_depot_liquidate_haulers, hauler.at_depot, hauler_id)
            storage.disabled_items[hauler.network .. ":" .. hauler.at_depot] = true
        else
            list_destroy_or_remove(network.at_depot_haulers, hauler.class, hauler_id)
        end
    end

    local job_index = hauler.job
    if job_index then
        network.jobs[job_index].abort_tick = game.tick
        hauler.job = nil
        gui.on_job_updated(hauler.network, job_index)
    end
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_set_to_manual(hauler)
    main.hauler_disabled_or_destroyed(hauler.train.id, hauler)

    hauler.to_provide = nil
    hauler.to_request = nil
    hauler.to_fuel = nil
    hauler.to_depot = nil
    hauler.at_depot = nil

    hauler.train.schedule = nil
end

---@param hauler Hauler
function main.hauler_set_to_automatic(hauler)
    local network = storage.networks[hauler.network]

    if not network.classes[hauler.class] then
        local train = hauler.train
        set_hauler_status(hauler, { "sspp-alert.class-not-in-network" })
        lib.show_train_alert(train, hauler.status)
        train.manual_mode = true
        return
    end

    main.hauler_send_to_fuel_or_depot(hauler, true, true)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_arrived_at_provide_station(hauler)
    local train = hauler.train
    local station = storage.stations[hauler.to_provide.station]
    local stop = station.stop

    if train.station ~= stop then
        set_hauler_status(hauler, { "sspp-alert.arrived-at-wrong-stop" }, hauler.status_item, station.stop)
        lib.show_train_alert(train, hauler.status)
        train.manual_mode = true
        return
    end

    local network_name, item_key = hauler.network, hauler.to_provide.item
    local network = storage.networks[network_name]
    local network_item = network.items[item_key]
    local name, quality = network_item.name, network_item.quality

    local provide_item = station.provide_items[item_key]
    local constant = compute_load_target(network_item, provide_item)

    local signal, wait_conditions ---@type SignalID, WaitCondition[]
    if quality then
        signal = { name = name, quality = quality, type = "item" }
        wait_conditions = { { type = "item_count", condition = { first_signal = signal, comparator = ">=", constant = constant } } }
        for i, spoil_result in enumerate_spoil_results(prototypes.item[name]) do
            local spoil_signal = { name = spoil_result.name, quality = quality, type = "item" }
            wait_conditions[i * 2] = { compare_type = "or", type = "item_count", condition = { first_signal = spoil_signal, comparator = ">", constant = 0 } }
            wait_conditions[i * 2 + 1] = { compare_type = "and", type = "inactivity", ticks = 120 }
            set_control_behavior(station.provide_hidden_combs[i], 0, "-", spoil_signal, signal)
        end
    else
        signal = { name = name, type = "fluid" }
        wait_conditions = { { type = "fluid_count", condition = { first_signal = signal, comparator = ">=", constant = constant } } }
        if provide_item.granularity > 1 then
            wait_conditions[2] = { compare_type = "and", type = "inactivity", ticks = 60 }
        end
    end

    station.provide_minimum_active_count = station.provide_counts[item_key]
    station.hauler = train.id

    hauler.to_provide.phase = "TRANSFER"
    set_control_behavior(station.provide_io, constant, "-", signal)
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }

    local job_index = hauler.job --[[@as JobIndex]]
    local job = network.jobs[job_index]
    job.target_count = network_item.delivery_size
    job.provide_arrive_tick = game.tick
    gui.on_job_updated(network_name, job_index)
end

---@param hauler Hauler
function main.hauler_arrived_at_request_station(hauler)
    local train = hauler.train
    local station = storage.stations[hauler.to_request.station]
    local stop = station.stop

    if train.station ~= stop then
        set_hauler_status(hauler, { "sspp-alert.arrived-at-wrong-stop" }, hauler.status_item, stop)
        lib.show_train_alert(train, hauler.status)
        train.manual_mode = true
        return
    end

    local network_name, item_key = hauler.network, hauler.to_request.item
    local network = storage.networks[network_name]
    local network_item = network.items[item_key]
    local name, quality = network_item.name, network_item.quality

    local signal, wait_conditions ---@type SignalID, WaitCondition[]
    if quality then
        signal = { name = name, quality = quality, type = "item" }
        wait_conditions = { { type = "item_count", condition = { first_signal = signal, comparator = "=", constant = 0 } } }
        for i, spoil_result in enumerate_spoil_results(prototypes.item[name]) do
            local spoil_signal = { name = spoil_result.name, quality = quality, type = "item" }
            wait_conditions[i + 1] = { compare_type = "and", type = "item_count", condition = { first_signal = spoil_signal, comparator = "=", constant = 0 } }
            set_control_behavior(station.request_hidden_combs[i], 0, "+", spoil_signal)
        end
    else
        signal = { name = name, type = "fluid" }
        wait_conditions = { { type = "fluid_count", condition = { first_signal = signal, comparator = "=", constant = 0 } } }
    end

    station.request_minimum_active_count = station.request_counts[item_key]
    station.hauler = train.id

    hauler.to_request.phase = "TRANSFER"
    set_control_behavior(station.request_io, 0, "+", signal)
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }

    local job_index = hauler.job --[[@as JobIndex]]
    local job = network.jobs[job_index]
    job.loaded_count = get_train_item_count(train, name, quality)
    job.request_arrive_tick = game.tick
    gui.on_job_updated(network_name, job_index)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_done_at_provide_station(hauler)
    local network_name, station = hauler.network, storage.stations[hauler.to_provide.station]

    clear_control_behavior(station.provide_io)
    clear_hidden_control_behaviors(station.provide_hidden_combs)

    hauler.to_provide.phase = "DONE"
    set_hauler_status(hauler, { "sspp-alert.waiting-for-request" }, hauler.status_item, hauler.status_stop)
    hauler.train.schedule = { current = 1, records = { { rail = station.stop.connected_rail } } }

    local job_index = hauler.job --[[@as JobIndex]]
    storage.networks[network_name].jobs[job_index].provide_done_tick = game.tick
    gui.on_job_updated(network_name, job_index)
end

---@param hauler Hauler
function main.hauler_done_at_request_station(hauler)
    local network_name, station = hauler.network, storage.stations[hauler.to_request.station]

    clear_control_behavior(station.request_io)
    clear_hidden_control_behaviors(station.request_hidden_combs)

    hauler.to_request.phase = "DONE"
    -- no special status needed, won't be in this state for long
    hauler.train.schedule = { current = 1, records = { { rail = station.stop.connected_rail } } }

    local job_index = hauler.job --[[@as JobIndex]]
    storage.networks[network_name].jobs[job_index].finish_tick = game.tick
    gui.on_job_updated(network_name, job_index)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
---@param check_fuel boolean
---@param check_cargo boolean
function main.hauler_send_to_fuel_or_depot(hauler, check_fuel, check_cargo)
    local network_name = hauler.network
    local class_name = hauler.class
    local train = hauler.train
    local network = storage.networks[network_name]
    local class = network.classes[class_name]

    if check_fuel then
        local maximum_delivery_time = 150.0 -- TODO: calculate properly
        local energy_per_second = 5000000.0 / 3.0 -- TODO: calculate properly

        -- TODO: could be less, this assumes constant burning
        local energy_threshold = energy_per_second * maximum_delivery_time

        local loco_dict = train.locomotives ---@type {string: LuaEntity[]}
        for _, loco_list in pairs(loco_dict) do
            for _, loco in pairs(loco_list) do
                local burner = assert(loco.burner, "TODO: electric trains")
                local energy = burner.remaining_burning_fuel
                for _, item_with_count in pairs(burner.inventory.get_contents()) do
                    energy = energy + prototypes.item[item_with_count.name].fuel_value * item_with_count.count
                end
                if energy < energy_threshold then
                    list_create_or_append(network.fuel_haulers, class_name, train.id)
                    hauler.to_fuel = "TRAVEL"
                    set_hauler_status(hauler, { "sspp-alert.getting-fuel" })
                    send_train_to_named_stop(train, e_train_colors.fuel, class.fueler_name)
                    assign_network_hauler_job(network, hauler, { hauler = train.id, type = "FUEL", start_tick = game.tick })
                    gui.on_job_created(network_name, network.job_index_counter)
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
                set_hauler_status(hauler, { "sspp-alert.multiple-items-or-fluids" })
                lib.show_train_alert(train, hauler.status)
                train.manual_mode = true
            elseif not network.items[item_key] then
                set_hauler_status(hauler, { "sspp-alert.cargo-not-in-network" }, item_key)
                lib.show_train_alert(train, hauler.status)
                train.manual_mode = true
            else
                list_create_or_append(network.to_depot_liquidate_haulers, item_key, train.id)
                hauler.to_depot = item_key
                set_hauler_status(hauler, { class.bypass_depot and "sspp-alert.waiting-for-request" or "sspp-alert.going-to-depot" }, item_key)
                send_train_to_named_stop(train, e_train_colors.liquidate, class.depot_name)
            end
            return
        end
    end

    list_create_or_append(network.to_depot_haulers, class_name, train.id)
    hauler.to_depot = ""
    set_hauler_status(hauler, { class.bypass_depot and "sspp-alert.ready-for-dispatch" or "sspp-alert.going-to-depot" })
    send_train_to_named_stop(train, e_train_colors.depot, class.depot_name)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_arrived_at_fuel_stop(hauler)
    local network_name, train = hauler.network, hauler.train
    local stop = train.station --[[@as LuaEntity]]

    local wait_conditions = { { type = "fuel_full" } }

    hauler.to_fuel = "TRANSFER"
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }

    local job_index = hauler.job --[[@as JobIndex]]
    local job = storage.networks[network_name].jobs[job_index]
    job.fuel_stop = stop
    job.fuel_arrive_tick = game.tick
    gui.on_job_updated(network_name, job_index)
end

---@param hauler Hauler
function main.hauler_done_at_fuel_stop(hauler)
    local network_name = hauler.network
    local network = storage.networks[network_name]

    list_destroy_or_remove(network.fuel_haulers, hauler.class, hauler.train.id)
    hauler.to_fuel = nil

    local job_index = hauler.job --[[@as JobIndex]]
    network.jobs[job_index].finish_tick = game.tick
    gui.on_job_updated(network_name, job_index)

    hauler.job = nil

    main.hauler_send_to_fuel_or_depot(hauler, false, true)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_arrived_at_depot_stop(hauler)
    local item_key, hauler_id = hauler.to_depot, hauler.train.id
    local network = storage.networks[hauler.network]

    if item_key == "" then
        local class_name = hauler.class
        list_destroy_or_remove(network.to_depot_haulers, class_name, hauler_id)
        list_create_or_append(network.at_depot_haulers, class_name, hauler_id)
        set_hauler_status(hauler, { "sspp-alert.ready-for-dispatch" })
    else
        ---@cast item_key ItemKey
        list_destroy_or_remove(network.to_depot_liquidate_haulers, item_key, hauler_id)
        list_create_or_append(network.at_depot_liquidate_haulers, item_key, hauler_id)
        set_hauler_status(hauler, { "sspp-alert.waiting-for-request" }, item_key)
    end

    hauler.to_depot = nil
    hauler.at_depot = item_key
end

--------------------------------------------------------------------------------

---@param old_train_id uint
---@param new_train LuaTrain?
function main.train_broken(old_train_id, new_train)
    local hauler = storage.haulers[old_train_id]
    if hauler then
        main.hauler_disabled_or_destroyed(old_train_id, hauler)
        storage.haulers[old_train_id] = nil
        if new_train then
            storage.haulers[new_train.id] = {
                train = new_train,
                network = new_train.front_stock.surface.name,
                class = hauler.class,
                status = { "sspp-gui.not-configured" },
            }
        end
    end
    for player_id, player_gui in pairs(storage.player_guis) do
        if player_gui.train_id then
            ---@cast player_gui PlayerHaulerGui
            if player_gui.train_id == old_train_id then
                if new_train then
                    player_gui.train_id, player_gui.train = new_train.id, new_train
                else
                    gui.hauler_closed(player_id)
                end
            end
        end
    end
end
