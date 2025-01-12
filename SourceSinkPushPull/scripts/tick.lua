-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param comb LuaEntity
---@param wire_a defines.wire_connector_id
---@param wire_b defines.wire_connector_id?
---@return {[ItemKey]: integer}
local function make_dict_from_signals(comb, wire_a, wire_b)
    local dict = {} ---@type {[ItemKey]: integer}
    --- TODO: this is a silly workaround to a silly api bug
    local signals ---@type Signal[]?
    if wire_b then
        signals = comb.get_signals(wire_a, wire_b)
    else
        signals = comb.get_signals(wire_a)
    end
    if signals then
        for _, signal in pairs(signals) do
            local id = signal.signal
            local type = id.type or "item"
            if type == "item" then
                dict[id.name .. ":" .. (id.quality or "normal")] = signal.count
            elseif type == "fluid" then
                dict[id.name] = signal.count
            end
        end
    end
    return dict
end

---@param list NetworkItemKey[]
---@param length integer
---@param network_name NetworkName
---@param item_key ItemKey
---@param copies integer
---@return integer new_length
local function extend_network_item_key_list(list, length, network_name, item_key, copies)
    if copies > 0 then
        local network_item_key = network_name .. ":" .. item_key
        for i = length + 1, length + copies do
            list[i] = network_item_key
        end
        length = length + copies
    end
    return length
end

---@param dict {[ItemKey]: StationId[]}
---@param key ItemKey
---@return StationId
local function pop_random_station_from_partition_or_destroy(dict, key)
    local list = dict[key]
    local length = #list

    if length > 1 then
        local stations = storage.stations

        local best_total = math.huge
        for _, station_id in pairs(list) do
            local total = stations[station_id].total_deliveries
            if total < best_total then best_total = total end
        end

        local best_index_list = {}
        for index, station_id in pairs(list) do
            local total = stations[station_id].total_deliveries
            if total == best_total then best_index_list[#best_index_list+1] = index end
        end

        local index = best_index_list[math.random(#best_index_list)]

        local result = list[index]
        list[index] = list[length]
        list[length] = nil

        return result
    end

    if length > 0 then
        local result = list[1]
        dict[key] = nil

        return result
    end

    error("empty list")
end

--------------------------------------------------------------------------------

local function prepare_for_tick_poll()
    for _, network in pairs(storage.networks) do
        network.push_tickets = {}
        network.provide_tickets = {}
        network.pull_tickets = {}
        network.request_tickets = {}
        network.provide_done_tickets = {}
        network.request_done_tickets = {}
    end

    storage.disabled_items = {}

    local list, length = {}, 0 ---@type StationId[]
    storage.poll_stations = list

    for station_id, station in pairs(storage.stations) do
        -- TODO: add on/off switch to station, check it here
        local provide_items = station.provide_items
        if not (provide_items and next(provide_items)) then
            local request_items = station.request_items
            if not (request_items and next(request_items)) then
                goto continue
            end
        end
        length = length + 1
        list[length] = station_id
        ::continue::
    end

    storage.tick_state = "POLL"
end

local function tick_poll()
    local station_id = list_pop_random_if_any(storage.poll_stations)
    if not station_id then return true end

    local station = storage.stations[station_id]

    local hauler_provide_item_key, hauler_request_item_key ---@type ItemKey?, ItemKey?
    if station.hauler then
        local hauler = storage.haulers[station.hauler]
        if hauler.to_provide then hauler_provide_item_key = hauler.to_provide.item end
        if hauler.to_request then hauler_request_item_key = hauler.to_request.item end
    end

    local network = storage.networks[station.stop.surface.name]

    local storage_counts = make_dict_from_signals(station.general_io, defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)

    if station.provide_items then
        local transfer_counts = make_dict_from_signals(station.provide_io, defines.wire_connector_id.combinator_input_green)
        local train_counts = make_dict_from_signals(station.provide_io, defines.wire_connector_id.combinator_input_red)

        for item_key, provide_item in pairs(station.provide_items) do
            local network_item = network.items[item_key]
            if network_item then
                local storage_count = storage_counts[item_key] or 0
                local transfer_count = transfer_counts[item_key] or 0
                local train_count = train_counts[item_key] or 0

                if network_item.quality then
                    for spoil_result in next_spoil_result, prototypes.item[network_item.name] do
                        local spoil_result_item_key = spoil_result.name .. ":" .. network_item.quality
                        transfer_count = transfer_count + (transfer_counts[spoil_result_item_key] or 0)
                        train_count = train_count + (train_counts[spoil_result_item_key] or 0)
                    end
                end

                local count = storage_count + transfer_count

                if hauler_provide_item_key == item_key then
                    if transfer_count == 0 and train_count >= compute_load_target(network_item, provide_item) then
                        list_append_or_create(network.provide_done_tickets, item_key, station_id)
                    end
                    count = count + train_count -- only include train count if it's the expected item
                    hauler_provide_item_key = nil
                end

                local deliveries = len_or_zero(station.provide_deliveries[item_key])
                local want_deliveries = math.floor(count / network_item.delivery_size) - deliveries
                if want_deliveries > 0 then
                    if provide_item.push then
                        local push_count = count - compute_buffer(network_item, provide_item)
                        local push_want_deliveries = math.floor(push_count / network_item.delivery_size) - deliveries
                        if push_want_deliveries > 0 then
                            list_extend_or_create(network.push_tickets, item_key, station_id, push_want_deliveries)
                            want_deliveries = want_deliveries - push_want_deliveries
                        end
                    end
                    if want_deliveries > 0 then
                        list_extend_or_create(network.provide_tickets, item_key, station_id, want_deliveries)
                    end
                end
            end
        end
    end

    if station.request_items then
        local transfer_counts = make_dict_from_signals(station.request_io, defines.wire_connector_id.combinator_input_red)
        local train_counts = make_dict_from_signals(station.request_io, defines.wire_connector_id.combinator_input_green)

        for item_key, request_item in pairs(station.request_items) do
            local network_item = network.items[item_key]
            if network_item then
                local storage_count = storage_counts[item_key] or 0
                local transfer_count = transfer_counts[item_key] or 0
                local train_count = train_counts[item_key] or 0

                if network_item.quality then
                    for spoil_result in next_spoil_result, prototypes.item[network_item.name] do
                        local spoil_result_item_key = spoil_result.name .. ":" .. network_item.quality
                        transfer_count = transfer_count + (transfer_counts[spoil_result_item_key] or 0)
                        train_count = train_count + (train_counts[spoil_result_item_key] or 0)
                    end
                end

                local count = storage_count + transfer_count

                if hauler_request_item_key == item_key then
                    if train_count == 0 then
                        list_append_or_create(network.request_done_tickets, item_key, station_id)
                    end
                    count = count + train_count -- only include train count if it's the expected item
                    hauler_request_item_key = nil
                end

                --- for requests, count is the number of items missing
                count = compute_storage_needed(network_item, request_item) - count

                local deliveries = len_or_zero(station.request_deliveries[item_key])
                local want_deliveries = math.floor(count / network_item.delivery_size) - deliveries
                if want_deliveries > 0 then
                    if request_item.pull then
                        local pull_count = count - compute_buffer(network_item, request_item)
                        local pull_want_deliveries = math.floor(pull_count / network_item.delivery_size) - deliveries
                        if pull_want_deliveries > 0 then
                            list_extend_or_create(network.pull_tickets, item_key, station_id, pull_want_deliveries)
                            want_deliveries = want_deliveries - pull_want_deliveries
                        end
                    end
                    if want_deliveries > 0 then
                        list_extend_or_create(network.request_tickets, item_key, station_id, want_deliveries)
                    end
                end
            end
        end
    end

    if hauler_provide_item_key or hauler_request_item_key then
        error("station assigned to incorrect hauler")
    end

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_liquidate()
    local list, length = {}, 0 ---@type NetworkItemKey[]
    storage.liquidate_items = list

    for network_name, network in pairs(storage.networks) do
        local pull_tickets = network.pull_tickets
        local request_tickets = network.request_tickets

        for item_key, hauler_ids in pairs(network.liquidate_haulers) do
            local pull_count = len_or_zero(pull_tickets[item_key])
            local request_count = len_or_zero(request_tickets[item_key])
            local haulers_to_send = math.min(#hauler_ids, pull_count + request_count)

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "LIQUIDATE"
end

function tick_liquidate()
    local network_name, item_key ---@type NetworkName, ItemKey

    repeat
        local network_item_key = list_pop_random_if_any(storage.liquidate_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")

        break; ::continue::
    until false

    local network = storage.networks[network_name]

    local hauler_id = list_pop_random_or_destroy(network.liquidate_haulers, item_key)
    local hauler = storage.haulers[hauler_id]
    hauler.to_liquidate = nil

    local request_station_id ---@type StationId
    if network.pull_tickets[item_key] then
        request_station_id = pop_random_station_from_partition_or_destroy(network.pull_tickets, item_key)
    else
        request_station_id = pop_random_station_from_partition_or_destroy(network.request_tickets, item_key)
    end
    local request_station = storage.stations[request_station_id]

    list_append_or_create(network.request_haulers, item_key, hauler_id)
    list_append_or_create(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = { item = item_key, station = request_station_id }
    request_station.total_deliveries = request_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.dropping-off-cargo" }, item_key, request_station.stop)
    send_hauler_to_station(hauler, request_station)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_dispatch()
    local list, length = {}, 0 ---@type NetworkItemKey[]
    storage.dispatch_items = list

    for network_name, network in pairs(storage.networks) do
        local provide_haulers = network.provide_haulers

        local push_tickets = network.push_tickets
        local provide_tickets = network.provide_tickets
        local pull_tickets = network.pull_tickets
        local request_tickets = network.request_tickets

        for item_key, _ in pairs(network.items) do
            local haulers_to_send = 0
            local push_count = len_or_zero(push_tickets[item_key])
            local pull_count = len_or_zero(pull_tickets[item_key])

            if push_count > 0 then
                local request_total = pull_count + len_or_zero(request_tickets[item_key])
                haulers_to_send = math.min(push_count, request_total)
            end

            if pull_count > 0 then
                local real_pull_count = pull_count - len_or_zero(provide_haulers[item_key])
                local provide_total = push_count + len_or_zero(provide_tickets[item_key])
                haulers_to_send = math.max(haulers_to_send, math.min(real_pull_count, provide_total))
            end

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "DISPATCH"
end

local function tick_dispatch()
    local network_name, item_key ---@type NetworkName, ItemKey
    local network, class_name ---@type Network, ClassName

    repeat
        local network_item_key = list_pop_random_if_any(storage.dispatch_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")
        network = storage.networks[network_name]
        class_name = network.items[item_key].class

        if not network.depot_haulers[class_name] then goto continue end

        break; ::continue::
    until false

    local hauler_id = list_pop_random_or_destroy(network.depot_haulers, class_name)
    local hauler = storage.haulers[hauler_id]
    hauler.to_depot = nil

    local provide_station_id ---@type StationId
    if network.push_tickets[item_key] then
        provide_station_id = pop_random_station_from_partition_or_destroy(network.push_tickets, item_key)
    else
        provide_station_id = pop_random_station_from_partition_or_destroy(network.provide_tickets, item_key)
    end
    local provide_station = storage.stations[provide_station_id]

    list_append_or_create(network.provide_haulers, item_key, hauler_id)
    list_append_or_create(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = { item = item_key, station = provide_station_id }
    provide_station.total_deliveries = provide_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.picking-up-cargo" }, item_key, provide_station.stop)
    send_hauler_to_station(hauler, provide_station)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_provide_done()
    local list, length = {}, 0 ---@type NetworkItemKey[]
    storage.provide_done_items = list

    for network_name, network in pairs(storage.networks) do
        local pull_tickets = network.pull_tickets
        local request_tickets = network.request_tickets

        for item_key, station_ids in pairs(network.provide_done_tickets) do
            local pull_count = len_or_zero(pull_tickets[item_key])
            local request_count = len_or_zero(request_tickets[item_key])
            local haulers_to_send = math.min(#station_ids, pull_count + request_count)

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "PROVIDE_DONE"
end

function tick_provide_done()
    local network_name, item_key ---@type NetworkName, ItemKey

    repeat
        local network_item_key = list_pop_random_if_any(storage.provide_done_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")

        break; ::continue::
    until false

    local network = storage.networks[network_name]

    local provide_station_id = list_pop_random_or_destroy(network.provide_done_tickets, item_key)
    local provide_station = storage.stations[provide_station_id]

    local hauler_id = assert(provide_station.hauler)
    local hauler = storage.haulers[hauler_id]

    clear_arithmetic_control_behavior(provide_station.provide_io)
    list_remove_value_or_destroy(network.provide_haulers, item_key, hauler_id)
    list_remove_value_or_destroy(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = nil
    provide_station.hauler = nil
    provide_station.total_deliveries = provide_station.total_deliveries - 1

    local request_station_id ---@type StationId
    if network.pull_tickets[item_key] then
        request_station_id = pop_random_station_from_partition_or_destroy(network.pull_tickets, item_key)
    else
        request_station_id = pop_random_station_from_partition_or_destroy(network.request_tickets, item_key)
    end
    local request_station = storage.stations[request_station_id]

    list_append_or_create(network.request_haulers, item_key, hauler_id)
    list_append_or_create(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = { item = item_key, station = request_station_id }
    request_station.total_deliveries = request_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.dropping-off-cargo" }, item_key, request_station.stop)
    send_hauler_to_station(hauler, request_station)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_request_done()
    local list, length = {}, 0 ---@type NetworkItemKey[]
    storage.request_done_items = list

    for network_name, network in pairs(storage.networks) do
        for item_key, station_ids in pairs(network.request_done_tickets) do
            -- assume there are always enough depots available
            local haulers_to_send = #station_ids
            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "REQUEST_DONE"
end

local function tick_request_done()
    local network_name, item_key ---@type NetworkName, ItemKey

    repeat
        local network_item_key = list_pop_random_if_any(storage.request_done_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")

        break; ::continue::
    until false

    local network = storage.networks[network_name]

    local request_station_id = list_pop_random_or_destroy(network.request_done_tickets, item_key)
    local request_station = storage.stations[request_station_id]

    local hauler_id = assert(request_station.hauler)
    local hauler = storage.haulers[hauler_id]

    clear_arithmetic_control_behavior(request_station.request_io)
    list_remove_value_or_destroy(network.request_haulers, item_key, hauler_id)
    list_remove_value_or_destroy(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = nil
    request_station.hauler = nil
    request_station.total_deliveries = request_station.total_deliveries - 1

    local class = network.classes[hauler.class]
    if class then
        if check_if_hauler_needs_fuel(hauler, class) then
            list_append_or_create(network.fuel_haulers, hauler.class, hauler_id)
            hauler.to_fuel = true
            set_hauler_status(hauler, { "sspp-alert.getting-fuel" })
            send_hauler_to_fueler(hauler, class)
        else
            list_append_or_create(network.depot_haulers, hauler.class, hauler_id)
            hauler.to_depot = true
            set_hauler_status(hauler, { "sspp-alert.ready-for-dispatch" })
            send_hauler_to_depot(hauler, class)
        end
    else
        set_hauler_status(hauler, { "sspp-alert.class-not-in-network" })
        send_alert_for_train(hauler.train, hauler.status)
        hauler.train.manual_mode = true
    end

    return false
end

-------------------------------------------------------------------------------

function on_tick()

    for _, station in pairs(storage.stations) do
        if station.provide_items then
            for _, provide_item in pairs(station.provide_items) do
                if not provide_item.latency then
                    provide_item.latency = 30.0
                end
            end
        end
        if station.request_items then
            for _, request_item in pairs(station.request_items) do
                if not request_item.latency then
                    request_item.latency = 30.0
                end
            end
        end
    end

    local tick_state = storage.tick_state

    if tick_state == "POLL" then
        for _ = 1, mod_settings.stations_per_tick do
            if tick_poll() then
                gui.on_poll_finished()
                prepare_for_tick_liquidate()
                break
            end
        end
    elseif tick_state == "LIQUIDATE" then
        if tick_liquidate() then
            prepare_for_tick_dispatch()
        end
    elseif tick_state == "DISPATCH" then
        if tick_dispatch() then
            prepare_for_tick_provide_done()
        end
    elseif tick_state == "PROVIDE_DONE" then
        if tick_provide_done() then
            prepare_for_tick_request_done()
        end
    elseif tick_state == "REQUEST_DONE" then
        if tick_request_done() then
            prepare_for_tick_poll()
        end
    elseif tick_state == "INITIAL" then
        prepare_for_tick_poll()
    end
end
