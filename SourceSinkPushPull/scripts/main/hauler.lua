-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param hauler_id HaulerId
---@param hauler Hauler
function main.hauler_disabled_or_destroyed(hauler_id, hauler)
    local network = assert(storage.networks[hauler.network])

    if hauler.to_provide then
        local station = assert(storage.stations[hauler.to_provide.station])
        local item_key = hauler.to_provide.item
        storage.disabled_items[hauler.network .. ":" .. item_key] = true
        if station.hauler == hauler_id then
            clear_arithmetic_control_behavior(station.provide_io)
            clear_hidden_comb_control_behaviors(station.provide_hidden_combs)
            station.provide_minimum_active_count = nil
            station.hauler = nil
        end
        list_remove_value_or_destroy(network.provide_haulers, item_key, hauler_id)
        list_remove_value_or_destroy(station.provide_deliveries, item_key, hauler_id)
        station.total_deliveries = station.total_deliveries - 1
    end

    if hauler.to_request then
        local station = assert(storage.stations[hauler.to_request.station])
        local item_key = hauler.to_request.item
        storage.disabled_items[hauler.network .. ":" .. item_key] = true
        if station.hauler == hauler_id then
            clear_arithmetic_control_behavior(station.request_io)
            clear_hidden_comb_control_behaviors(station.request_hidden_combs)
            station.request_minimum_active_count = nil
            station.hauler = nil
        end
        list_remove_value_or_destroy(network.request_haulers, item_key, hauler_id)
        list_remove_value_or_destroy(station.request_deliveries, item_key, hauler_id)
        station.total_deliveries = station.total_deliveries - 1
    end

    if hauler.to_fuel then
        list_remove_value_or_destroy(network.fuel_haulers, hauler.class, hauler_id)
    end

    if hauler.to_depot then
        if hauler.to_depot ~= "" then
            list_remove_value_or_destroy(network.to_depot_liquidate_haulers, hauler.to_depot, hauler_id)
            storage.disabled_items[hauler.network .. ":" .. hauler.to_depot] = true
        else
            list_remove_value_or_destroy(network.to_depot_haulers, hauler.class, hauler_id)
        end
    end

    if hauler.at_depot then
        if hauler.at_depot ~= "" then
            list_remove_value_or_destroy(network.at_depot_liquidate_haulers, hauler.at_depot, hauler_id)
            storage.disabled_items[hauler.network .. ":" .. hauler.at_depot] = true
        else
            list_remove_value_or_destroy(network.at_depot_haulers, hauler.class, hauler_id)
        end
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
    local train = hauler.train
    local network = storage.networks[hauler.network]

    local class = network.classes[hauler.class]
    if not class then
        set_hauler_status(hauler, { "sspp-alert.class-not-in-network" })
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
        return
    end

    if check_if_hauler_needs_fuel(hauler, class) then
        list_append_or_create(network.fuel_haulers, hauler.class, train.id)
        hauler.to_fuel = "TRAVEL"
        set_hauler_status(hauler, { "sspp-alert.getting-fuel" })
        set_hauler_color(hauler, e_train_colors.fuel)
        send_hauler_to_named_stop(hauler, class.fueler_name)
        return
    end

    local train_items, train_fluids = train.get_contents(), train.get_fluid_contents()
    local train_item, train_fluid = train_items[1], next(train_fluids)

    if train_items[2] or next(train_fluids, train_fluid) or (train_item and train_fluid) then
        set_hauler_status(hauler, { "sspp-alert.multiple-items-or-fluids" })
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
        return
    end

    local item_key = train_fluid or train_item and (train_item.name .. ":" .. (train_item.quality or "normal"))
    if item_key then
        if network.items[item_key] then
            list_append_or_create(network.to_depot_liquidate_haulers, item_key, train.id)
            hauler.to_depot = item_key
            set_hauler_status(hauler, { class.bypass_depot and "sspp-alert.waiting-for-request" or "sspp-alert.going-to-depot" }, item_key)
            set_hauler_color(hauler, e_train_colors.liquidate)
            send_hauler_to_named_stop(hauler, class.depot_name)
        else
            set_hauler_status(hauler, { "sspp-alert.cargo-not-in-network" }, item_key)
            send_alert_for_train(train, hauler.status)
            train.manual_mode = true
        end
        return
    end

    list_append_or_create(network.to_depot_haulers, hauler.class, train.id)
    hauler.to_depot = ""
    set_hauler_status(hauler, { class.bypass_depot and "sspp-alert.ready-for-dispatch" or "sspp-alert.going-to-depot" })
    set_hauler_color(hauler, e_train_colors.depot)
    send_hauler_to_named_stop(hauler, class.depot_name)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_arrived_at_provide_station(hauler)
    local train = hauler.train
    local station = storage.stations[hauler.to_provide.station]
    local stop = station.stop

    if train.station ~= stop then
        set_hauler_status(hauler, { "sspp-alert.arrived-at-wrong-stop" }, hauler.status_item, station.stop)
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
        return
    end

    local item_key = hauler.to_provide.item
    local network_item = storage.networks[hauler.network].items[item_key]
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
            set_arithmetic_control_behavior(station.provide_hidden_combs[i], 0, "-", spoil_signal, signal)
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
    set_arithmetic_control_behavior(station.provide_io, constant, "-", signal)
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }
end

---@param hauler Hauler
function main.hauler_arrived_at_request_station(hauler)
    local train = hauler.train
    local station = storage.stations[hauler.to_request.station]
    local stop = station.stop

    if train.station ~= stop then
        set_hauler_status(hauler, { "sspp-alert.arrived-at-wrong-stop" }, hauler.status_item, stop)
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
        return
    end

    local item_key = hauler.to_request.item
    local network_item = storage.networks[hauler.network].items[item_key]
    local name, quality = network_item.name, network_item.quality

    local signal, wait_conditions ---@type SignalID, WaitCondition[]
    if quality then
        signal = { name = name, quality = quality, type = "item" }
        wait_conditions = { { type = "item_count", condition = { first_signal = signal, comparator = "=", constant = 0 } } }
        for i, spoil_result in enumerate_spoil_results(prototypes.item[name]) do
            local spoil_signal = { name = spoil_result.name, quality = quality, type = "item" }
            wait_conditions[i + 1] = { compare_type = "and", type = "item_count", condition = { first_signal = spoil_signal, comparator = "=", constant = 0 } }
            set_arithmetic_control_behavior(station.request_hidden_combs[i], 0, "+", spoil_signal)
        end
    else
        signal = { name = name, type = "fluid" }
        wait_conditions = { { type = "fluid_count", condition = { first_signal = signal, comparator = "=", constant = 0 } } }
    end

    station.request_minimum_active_count = station.request_counts[item_key]
    station.hauler = train.id

    hauler.to_request.phase = "TRANSFER"
    set_arithmetic_control_behavior(station.request_io, 0, "+", signal)
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_done_at_provide_station(hauler)
    local station = storage.stations[hauler.to_provide.station]
    hauler.to_provide.phase = "DONE"
    clear_arithmetic_control_behavior(station.provide_io)
    clear_hidden_comb_control_behaviors(station.provide_hidden_combs)
    set_hauler_status(hauler, { "sspp-alert.waiting-for-request" }, hauler.status_item, hauler.status_stop)
    hauler.train.schedule = { current = 1, records = { { rail = station.stop.connected_rail } } }
end

---@param hauler Hauler
function main.hauler_done_at_request_station(hauler)
    local station = storage.stations[hauler.to_request.station]
    hauler.to_request.phase = "DONE"
    clear_arithmetic_control_behavior(station.request_io)
    clear_hidden_comb_control_behaviors(station.request_hidden_combs)
    hauler.train.schedule = { current = 1, records = { { rail = station.stop.connected_rail } } }
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_arrived_at_fuel_stop(hauler)
    local train = hauler.train
    local stop = train.station --[[@as LuaEntity]]

    local wait_conditions = { { type = "fuel_full" } }

    hauler.to_fuel = "TRANSFER"
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }
end

---@param hauler Hauler
function main.hauler_done_at_fuel_stop(hauler)
    local train = hauler.train
    local network = storage.networks[hauler.network]
    local class = network.classes[hauler.class]

    list_remove_value_or_destroy(network.fuel_haulers, hauler.class, train.id)
    hauler.to_fuel = nil

    list_append_or_create(network.to_depot_haulers, hauler.class, train.id)
    hauler.to_depot = ""
    set_hauler_status(hauler, { class.bypass_depot and "sspp-alert.ready-for-dispatch" or "sspp-alert.going-to-depot" })
    set_hauler_color(hauler, e_train_colors.depot)
    send_hauler_to_named_stop(hauler, class.depot_name)
end

--------------------------------------------------------------------------------

---@param hauler Hauler
function main.hauler_arrived_at_depot_stop(hauler)
    local hauler_id = hauler.train.id
    local class_name = hauler.class
    local network = storage.networks[hauler.network]
    local item_key = hauler.to_depot

    if item_key == "" then
        list_remove_value_or_destroy(network.to_depot_haulers, class_name, hauler_id)
        list_append_or_create(network.at_depot_haulers, class_name, hauler_id)
        set_hauler_status(hauler, { "sspp-alert.ready-for-dispatch" })
    else
        ---@cast item_key ItemKey
        list_remove_value_or_destroy(network.to_depot_liquidate_haulers, item_key, hauler_id)
        list_append_or_create(network.at_depot_liquidate_haulers, item_key, hauler_id)
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
