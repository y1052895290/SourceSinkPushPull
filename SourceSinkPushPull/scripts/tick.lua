-- SSPP by jagoly

--------------------------------------------------------------------------------

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
        network.economy = {
            push_stations = {},
            provide_stations = {},
            pull_stations = {},
            request_stations = {},
            provide_done_stations = {},
            request_done_stations = {},
        }
    end

    storage.disabled_items = {}

    local stations = {} ---@type StationId[]
    local stations_length = 0

    storage.all_stations = stations

    for station_id, station in pairs(storage.stations) do
        -- TODO: add on/off switch to station, check it here
        local provide_items = station.provide_items
        if not (provide_items and next(provide_items)) then
            local request_items = station.request_items
            if not (request_items and next(request_items)) then
                goto continue
            end
        end
        stations_length = stations_length + 1
        stations[stations_length] = station_id
        ::continue::
    end

    storage.tick_state = "POLL"
end

local function tick_poll()
    local station_id, station ---@type StationId, Station
    repeat
        station_id = list_pop_random_if_any(storage.all_stations)
        if not station_id then return true end

        station = storage.stations[station_id]

        ::continue::
        break
    until false

    ---@param comb LuaEntity
    ---@param item ProvideItem|RequestItem
    ---@return integer storage_count, integer red_count, integer green_count
    local function get_item_counts(comb, item)
        local signal = make_item_signal(item)
        local storage_count = station.general_io.get_signal(signal, defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)
        local red_count = comb.get_signal(signal, defines.wire_connector_id.combinator_input_red)
        local green_count = comb.get_signal(signal, defines.wire_connector_id.combinator_input_green)
        return storage_count, red_count, green_count
    end

    local hauler_provide_item_key, hauler_request_item_key = nil, nil
    local hauler_id = station.hauler
    if hauler_id then
        local hauler = storage.haulers[hauler_id]
        local to_provide = hauler.to_provide
        if to_provide then hauler_provide_item_key = to_provide.item end
        local to_request = hauler.to_request
        if to_request then hauler_request_item_key = to_request.item end
    end

    local network = storage.networks[station.stop.surface.name]
    local economy = network.economy

    if station.provide_items then
        for item_key, provide_item in pairs(station.provide_items) do
            local network_item = network.items[item_key]
            if network_item then
                local storage_count, train_count, loading_count = get_item_counts(station.provide_io, provide_item)
                local count = storage_count + loading_count

                if hauler_provide_item_key == item_key then
                    if loading_count == 0 then
                        if train_count >= compute_load_target(network_item, provide_item) then
                            list_append_or_create(economy.provide_done_stations, item_key, station_id)
                        end
                    end
                    count = count + train_count
                    hauler_provide_item_key = nil
                end

                local deliveries = len_or_zero(station.provide_deliveries[item_key])
                local want_deliveries = math.floor(count / network_item.delivery_size) - deliveries
                if want_deliveries > 0 then
                    if provide_item.push then
                        local push_count = count - network_item.delivery_size * 0.5
                        local push_want_deliveries = math.floor(push_count / network_item.delivery_size) - deliveries
                        if push_want_deliveries > 0 then
                            list_extend_or_create(economy.push_stations, item_key, station_id, push_want_deliveries)
                            want_deliveries = want_deliveries - push_want_deliveries
                        end
                    end
                    if want_deliveries > 0 then
                        list_extend_or_create(economy.provide_stations, item_key, station_id, want_deliveries)
                    end
                end
            end
        end
    end

    if station.request_items then
        for item_key, request_item in pairs(station.request_items) do
            local network_item = network.items[item_key]
            if network_item then
                local storage_count, unloading_count, train_count = get_item_counts(station.request_io, request_item)
                local count = storage_count + unloading_count

                if hauler_request_item_key == item_key then
                    if train_count == 0 then
                        list_append_or_create(economy.request_done_stations, item_key, station_id)
                    end
                    count = count + train_count
                    hauler_request_item_key = nil
                end

                --- for requests, count is the number of items missing
                count = compute_storage_needed(network_item, request_item) - count

                local deliveries = len_or_zero(station.request_deliveries[item_key])
                local want_deliveries = math.floor(count / network_item.delivery_size) - deliveries
                if want_deliveries > 0 then
                    if request_item.pull then
                        local pull_count = count - network_item.delivery_size * 0.5
                        local pull_want_deliveries = math.floor(pull_count / network_item.delivery_size) - deliveries
                        if pull_want_deliveries > 0 then
                            list_extend_or_create(economy.pull_stations, item_key, station_id, pull_want_deliveries)
                            want_deliveries = want_deliveries - pull_want_deliveries
                        end
                    end
                    if want_deliveries > 0 then
                        list_extend_or_create(economy.request_stations, item_key, station_id, want_deliveries)
                    end
                end
            end
        end
    end

    if hauler_provide_item_key or hauler_request_item_key then
        error("hauler at wrong station")
    end

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_liquidate()
    local list = {} ---@type NetworkItemKey[]
    local length = 0

    storage.all_liquidate_items = list

    for network_name, network in pairs(storage.networks) do
        local economy = network.economy

        local pull_stations = economy.pull_stations
        local request_stations = economy.request_stations

        for item_key, hauler_ids in pairs(network.liquidate_haulers) do
            local pull_count = len_or_zero(pull_stations[item_key])
            local request_count = len_or_zero(request_stations[item_key])
            local haulers_to_send = math.min(#hauler_ids, pull_count + request_count)

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "LIQUIDATE"
end

function tick_liquidate()
    local network_name, item_key ---@type NetworkName, ItemKey

    repeat
        local network_item_key = list_pop_random_if_any(storage.all_liquidate_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")

        break
        ::continue::
    until false

    local network = storage.networks[network_name]

    local hauler_id = list_pop_random_or_destroy(network.liquidate_haulers, item_key)
    local hauler = storage.haulers[hauler_id]
    hauler.to_liquidate = nil

    local economy = network.economy

    local request_station_id ---@type StationId
    if economy.pull_stations[item_key] then
        request_station_id = pop_random_station_from_partition_or_destroy(economy.pull_stations, item_key)
    else
        request_station_id = pop_random_station_from_partition_or_destroy(economy.request_stations, item_key)
    end
    local request_station = storage.stations[request_station_id]

    list_append_or_create(network.request_haulers, item_key, hauler_id)
    list_append_or_create(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = { item = item_key, station = request_station_id }
    request_station.total_deliveries = request_station.total_deliveries + 1

    send_hauler_to_station(hauler, request_station)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_dispatch()
    local list = {} ---@type NetworkItemKey[]
    local length = 0

    storage.all_dispatch_items = list

    for network_name, network in pairs(storage.networks) do
        local economy = network.economy
        local provide_haulers = network.provide_haulers

        local push_stations = economy.push_stations
        local provide_stations = economy.provide_stations
        local pull_stations = economy.pull_stations
        local request_stations = economy.request_stations

        for item_key, _ in pairs(network.items) do
            local haulers_to_send = 0
            local push_count = len_or_zero(push_stations[item_key])
            local pull_count = len_or_zero(pull_stations[item_key])

            if push_count > 0 then
                local request_total = pull_count + len_or_zero(request_stations[item_key])
                haulers_to_send = math.min(push_count, request_total)
            end

            if pull_count > 0 then
                local real_pull_count = pull_count - len_or_zero(provide_haulers[item_key])
                local provide_total = push_count + len_or_zero(provide_stations[item_key])
                haulers_to_send = math.max(haulers_to_send, math.min(real_pull_count, provide_total))
            end

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "DISPATCH"
end

local function tick_dispatch()
    local network_name, item_key ---@type NetworkName, ItemKey
    local network ---@type Network
    local class_name ---@type ClassName

    repeat
        local network_item_key = list_pop_random_if_any(storage.all_dispatch_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")
        network = storage.networks[network_name]
        class_name = network.items[item_key].class

        if not network.depot_haulers[class_name] then goto continue end

        break
        ::continue::
    until false

    local hauler_id = list_pop_random_or_destroy(network.depot_haulers, class_name)
    local hauler = storage.haulers[hauler_id]
    hauler.to_depot = nil

    local economy = network.economy

    local provide_station_id ---@type StationId
    if economy.push_stations[item_key] then
        provide_station_id = pop_random_station_from_partition_or_destroy(economy.push_stations, item_key)
    else
        provide_station_id = pop_random_station_from_partition_or_destroy(economy.provide_stations, item_key)
    end
    local provide_station = storage.stations[provide_station_id]

    list_append_or_create(network.provide_haulers, item_key, hauler_id)
    list_append_or_create(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = { item = item_key, station = provide_station_id }
    provide_station.total_deliveries = provide_station.total_deliveries + 1

    send_hauler_to_station(hauler, provide_station)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_provide_done()
    local list = {} ---@type NetworkItemKey[]
    local length = 0

    storage.all_provide_done_items = list

    for network_name, network in pairs(storage.networks) do
        local economy = network.economy

        local pull_stations = economy.pull_stations
        local request_stations = economy.request_stations

        for item_key, station_ids in pairs(economy.provide_done_stations) do
            local pull_count = len_or_zero(pull_stations[item_key])
            local request_count = len_or_zero(request_stations[item_key])
            local haulers_to_send = math.min(#station_ids, pull_count + request_count)

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "PROVIDE_DONE"
end

function tick_provide_done()
    local network_name, item_key ---@type NetworkName, ItemKey

    repeat
        local network_item_key = list_pop_random_if_any(storage.all_provide_done_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")

        break
        ::continue::
    until false

    local network = storage.networks[network_name]

    local provide_station_id = list_pop_random_or_destroy(network.economy.provide_done_stations, item_key)
    local provide_station = storage.stations[provide_station_id]

    local hauler_id = assert(provide_station.hauler)
    local hauler = storage.haulers[hauler_id]

    clear_arithmetic_control_behavior(provide_station.provide_io)
    list_remove_value_or_destroy(network.provide_haulers, item_key, hauler_id)
    list_remove_value_or_destroy(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = nil
    provide_station.hauler = nil
    provide_station.total_deliveries = provide_station.total_deliveries - 1

    local economy = network.economy

    local request_station_id ---@type StationId
    if economy.pull_stations[item_key] then
        request_station_id = pop_random_station_from_partition_or_destroy(economy.pull_stations, item_key)
    else
        request_station_id = pop_random_station_from_partition_or_destroy(economy.request_stations, item_key)
    end
    local request_station = storage.stations[request_station_id]

    list_append_or_create(network.request_haulers, item_key, hauler_id)
    list_append_or_create(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = { item = item_key, station = request_station_id }
    request_station.total_deliveries = request_station.total_deliveries + 1

    send_hauler_to_station(hauler, request_station)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_request_done()
    local list = {} ---@type NetworkItemKey[]
    local length = 0

    storage.all_request_done_items = list

    for network_name, network in pairs(storage.networks) do
        local economy = network.economy

        for item_key, station_ids in pairs(economy.request_done_stations) do
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
        local network_item_key = list_pop_random_if_any(storage.all_request_done_items)
        if not network_item_key then return true end

        if storage.disabled_items[network_item_key] then goto continue end

        network_name, item_key = string.match(network_item_key, "(.-):(.+)")

        break
        ::continue::
    until false

    local network = storage.networks[network_name]

    local request_station_id = list_pop_random_or_destroy(network.economy.request_done_stations, item_key)
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
            list_append_or_create(network.fuel_haulers, class.name, hauler_id)
            hauler.to_fuel = true
            send_hauler_to_named_stop(hauler, class.fueler_name)
        else
            list_append_or_create(network.depot_haulers, class.name, hauler_id)
            hauler.to_depot = true
            send_hauler_to_named_stop(hauler, class.depot_name)
        end
    else
        send_alert_for_train(hauler.train, { "sspp-alert.class-not-in-network", hauler.class })
        hauler.train.manual_mode = true
    end

    return false
end

-------------------------------------------------------------------------------

function on_tick()
    for _, station in pairs(storage.stations) do
        if not station.total_deliveries then
            station.total_deliveries = 0
            if station.provide_deliveries then
                for _, hauler_ids in pairs(station.provide_deliveries) do
                    station.total_deliveries = station.total_deliveries + #hauler_ids
                end
            end
            if station.request_deliveries then
                for _, hauler_ids in pairs(station.request_deliveries) do
                    station.total_deliveries = station.total_deliveries + #hauler_ids
                end
            end
        end
    end

    for _, network in pairs(storage.networks) do
        if not network.liquidate_haulers then
            network.liquidate_haulers = {}
        end
    end

    local tick_state = storage.tick_state

    if tick_state == "POLL" then
        for _ = 1, mod_settings.stations_per_tick do
            if tick_poll() then
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
