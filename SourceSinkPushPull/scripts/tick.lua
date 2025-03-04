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

--------------------------------------------------------------------------------

local function prepare_for_tick_poll()
    for _, network in pairs(storage.networks) do
        network.push_tickets = {}
        network.provide_tickets = {}
        network.pull_tickets = {}
        network.request_tickets = {}
        network.provide_done_tickets = {}
        network.request_done_tickets = {}
        network.bufferless_tickets = {}
    end

    storage.disabled_items = {}

    local list, length = {}, 0 ---@type StationId[]
    storage.poll_stations = list

    for station_id, station in pairs(storage.stations) do
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

---@param network_items {[ItemKey]: NetworkItem}
---@param station_items {[ItemKey]: ProvideItem|RequestItem}?
---@param station_deliveries {[ItemKey]: HaulerId[]}?
---@param subtract boolean
---@return {[ItemKey]: integer}? counts
local function poll_item_counts_bufferless(network_items, station_items, station_deliveries, subtract)
    if not station_items then return nil end
    ---@cast station_deliveries {[ItemKey]: HaulerId[]}

    local haulers = storage.haulers
    local item_counts = {} ---@type {[ItemKey]: integer}

    -- NOTE: bufferless stations will have only one item, we just use a loop for consistency
    for item_key, station_item in pairs(station_items) do
        local network_item = network_items[item_key]
        if network_item then
            local deliveries = station_deliveries[item_key]
            local name, quality = network_item.name, network_item.quality
            local count = 0
            if deliveries then
                for _, hauler_id in pairs(deliveries) do
                    count = count + get_train_item_count(haulers[hauler_id].train, name, quality)
                end
            end
            if subtract then
                count = compute_storage_needed(network_item, station_item) - count
            end
            item_counts[item_key] = count
        end
    end

    return item_counts
end

---@param network_items {[ItemKey]: NetworkItem}
---@param station_items {[ItemKey]: ProvideItem|RequestItem}?
---@param general_io LuaEntity
---@param subtract boolean
---@return {[ItemKey]: integer}? counts
local function poll_item_counts_buffered(network_items, station_items, general_io, subtract)
    if not station_items then return nil end

    local item_counts = {} ---@type {[ItemKey]: integer}

    for item_key, station_item in pairs(station_items) do
        local network_item = network_items[item_key]
        if network_item then
            local name, quality = network_item.name, network_item.quality
            local signal ---@type SignalID
            if quality then
                signal = { type = "item", name = name, quality = quality }
            else
                signal = { type = "fluid", name = name }
            end
            local count = general_io.get_signal(signal, defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)
            if subtract then
                count = compute_storage_needed(network_item, station_item) - count
            end
            item_counts[item_key] = count
        end
    end

    return item_counts
end

---@param network_items {[ItemKey]: NetworkItem}
---@param station_items {[ItemKey]: ProvideItem|RequestItem}?
---@param comb LuaEntity
---@return {[ItemKey]: ItemMode}? modes
local function poll_item_modes(network_items, station_items, comb)
    if not station_items then return nil end

    local item_modes = {} ---@type {[ItemKey]: ItemMode}
    local dynamic_index = -1 -- zero based

    for item_key, item in pairs(station_items) do
        if network_items[item_key] then
            local mode = item.mode
            if mode == 7 then
                dynamic_index = dynamic_index + 1
                mode = comb.get_signal({ type = "virtual", name = "sspp-signal-" .. tostring(dynamic_index) }, defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)
            end
            item_modes[item_key] = mode
        end
    end

    return item_modes
end

local function tick_poll()
    local station_id ---@type StationId
    do
        local list = storage.poll_stations
        local length = #list

        if length == 0 then return true end

        local index = math.random(length)
        station_id = list[index]

        list[index] = list[length]
        list[length] = nil
    end

    local station = storage.stations[station_id]
    local network = storage.networks[station.network]

    local enabled = not read_stop_flag(station.stop, e_stop_flags.disable)
    local buffered = not read_stop_flag(station.stop, e_stop_flags.bufferless)

    -- handle the active hauler finishing being loaded or unloaded

    local hauler_provide_item_key, hauler_request_item_key ---@type ItemKey?, ItemKey?

    local hauler_id = station.hauler
    if hauler_id then
        local hauler = storage.haulers[hauler_id]
        if hauler.to_provide then
            if hauler.to_provide.phase == "DONE" then
                list_append_or_create(network.provide_done_tickets, hauler.to_provide.item, station_id)
                if buffered then
                    hauler_provide_item_key = hauler.to_provide.item
                end
            elseif hauler.to_provide.phase == "PENDING" then
                hauler_provide_item_key = hauler.to_provide.item
            end
        else
            if hauler.to_request.phase == "DONE" then
                list_append_or_create(network.request_done_tickets, hauler.to_request.item, station_id)
                hauler_request_item_key = hauler.to_request.item
            end
        end
    end

    -- read dynamic item information from signals and trains

    local provide_counts, request_counts ---@type {[ItemKey]: integer}?, {[ItemKey]: integer}?

    if buffered then
        provide_counts = poll_item_counts_buffered(network.items, station.provide_items, station.general_io, false)
        request_counts = poll_item_counts_buffered(network.items, station.request_items, station.general_io, true)
    else
        provide_counts = poll_item_counts_bufferless(network.items, station.provide_items, station.provide_deliveries, false)
        request_counts = poll_item_counts_bufferless(network.items, station.request_items, station.request_deliveries, true)
    end

    local provide_modes = poll_item_modes(network.items, station.provide_items, station.provide_io)
    local request_modes = poll_item_modes(network.items, station.request_items, station.request_io)

    station.provide_counts, station.request_counts = provide_counts, request_counts
    station.provide_modes, station.request_modes = provide_modes, request_modes

    -- create tickets for any new deliveries that we could accommodate

    if station.provide_items then
        ---@cast provide_counts {[ItemKey]: integer}
        ---@cast provide_modes {[ItemKey]: ItemMode}

        for item_key, provide_item in pairs(station.provide_items) do
            local network_item = network.items[item_key]
            if network_item then
                local count, mode = provide_counts[item_key], provide_modes[item_key]

                if hauler_provide_item_key == item_key then
                    if buffered then
                        local minimum_count = station.provide_minimum_active_count ---@type integer
                        if minimum_count > count then
                            count = minimum_count
                        elseif minimum_count < count then
                            station.provide_minimum_active_count = count
                        end
                    elseif mode > 3 then
                        list_extend_or_create(network.push_tickets, item_key, station_id, 1)
                    else
                        list_extend_or_create(network.provide_tickets, item_key, station_id, 1)
                    end
                    hauler_provide_item_key = nil
                end

                if enabled and mode > 0 and mode < 7 then
                    if buffered then
                        local deliveries = len_or_zero(station.provide_deliveries[item_key])
                        local want_deliveries = math.floor(count / network_item.delivery_size) - deliveries
                        if want_deliveries > 0 then
                            if mode > 3 then
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
                    else
                        -- TODO: throughput for bufferless providers should be calculated automatically from the station train limit
                        local ethereal_count = compute_storage_needed(network_item, provide_item)
                        local deliveries = len_or_zero(station.provide_deliveries[item_key])
                        local want_deliveries = math.floor(ethereal_count / network_item.delivery_size) - deliveries
                        if want_deliveries > 0 then
                            list_extend_or_create(network.bufferless_tickets, item_key, station_id, want_deliveries)
                        end
                    end
                end
            end
        end
    end

    if station.request_items then
        ---@cast request_counts {[ItemKey]: integer}
        ---@cast request_modes {[ItemKey]: ItemMode}

        for item_key, request_item in pairs(station.request_items) do
            local network_item = network.items[item_key]
            if network_item then
                local count, mode = request_counts[item_key], request_modes[item_key]

                if hauler_request_item_key == item_key then
                    local minimum_count = station.request_minimum_active_count ---@type integer
                    if minimum_count > count then
                        count = minimum_count
                    elseif minimum_count < count then
                        station.request_minimum_active_count = count
                    end
                    hauler_request_item_key = nil
                end

                if enabled and mode > 0 and mode < 7 then
                    local deliveries = len_or_zero(station.request_deliveries[item_key])
                    local want_deliveries = math.floor(count / network_item.delivery_size) - deliveries
                    if want_deliveries > 0 then
                        if mode > 3 then
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
    end

    if hauler_provide_item_key or hauler_request_item_key then
        error("station assigned to incorrect hauler")
    end

    return false
end

--------------------------------------------------------------------------------

---@param list NetworkItemKey[]
---@return NetworkItemKey?
local function pop_network_item_key_if_any(list)
    local length = #list

    while length > 0 do
        local index = math.random(length)
        local network_item_key = list[index]

        list[index] = list[length]
        list[length] = nil

        if not storage.disabled_items[network_item_key] then
            return network_item_key
        end

        length = length - 1
    end

    return nil
end

---@param network Network
---@param first_dict_name "at_depot_haulers"|"at_depot_liquidate_haulers"
---@param second_dict_name "to_depot_haulers"|"to_depot_liquidate_haulers"
---@param class_name ClassName
---@param liquidate_item_key ItemKey?
---@return HaulerId?
local function pop_best_hauler_if_any(network, first_dict_name, second_dict_name, class_name, liquidate_item_key)
    local key_or_name = liquidate_item_key or class_name

    local dict = network[first_dict_name] ---@type {[ItemKey]: StationId[]}
    if not dict[key_or_name] then
        dict = network[second_dict_name]
        if not dict[key_or_name] then return nil end
        if not network.classes[class_name].bypass_depot then return nil end
    end

    local list = dict[key_or_name]
    local length = #list

    if length > 0 then
        local index = math.random(length)
        local hauler_id = list[index]

        if length == 1 then
            dict[key_or_name] = nil
        else
            list[index] = list[length]
            list[length] = nil
        end

        return hauler_id
    end

    return nil
end

---@param network Network
---@param first_dict_name "push_tickets"|"pull_tickets"|"bufferless_tickets"
---@param second_dict_name "provide_tickets"|"request_tickets"|"bufferless_tickets"
---@param mode_dict_name "provide_modes"|"request_modes"
---@param item_key ItemKey
---@return StationId?
local function pop_best_target_station_if_any(network, first_dict_name, second_dict_name, mode_dict_name, item_key)
    local stations = storage.stations

    local dict = network[first_dict_name] ---@type {[ItemKey]: StationId[]}
    if not dict[item_key] then
        dict = network[second_dict_name]
    end

    local list = dict[item_key]
    local length = #list

    local index_list, index_length ---@type integer[], integer
    local best_item_mode, best_under_limit = 0, -10

    for index, station_id in pairs(list) do
        local station = stations[station_id]
        local item_mode = station[mode_dict_name][item_key]
        if item_mode >= best_item_mode then
            local under_limit = station.stop.trains_limit - station.total_deliveries
            if item_mode > best_item_mode or under_limit > best_under_limit then
                index_list, index_length = {}, 0
                best_item_mode, best_under_limit = item_mode, under_limit
            end
            if under_limit > 0 then
                index_length = index_length + 1
                index_list[index_length] = index
            end
        end
    end

    if index_length > 0 then
        local index = index_list[math.random(index_length)]
        local station_id = list[index]

        if length == 1 then
            dict[item_key] = nil
        else
            list[index] = list[length]
            list[length] = nil
        end

        return station_id
    end

    return nil
end

---@param dict {[ItemKey]: StationId[]}
---@param item_key ItemKey
---@return StationId
local function pop_best_origin_station(dict, item_key)
    local stations = storage.stations

    local list = dict[item_key]
    local length = #list

    local index_list, index_length ---@type integer[], integer
    local best_over_limit = -10

    for index, station_id in pairs(list) do
        local station = stations[station_id]
        local over_limit = station.total_deliveries - station.stop.trains_limit
        if over_limit > best_over_limit then
            index_list, index_length = {}, 0
            best_over_limit = over_limit
        end
        index_length = index_length + 1
        index_list[index_length] = index
    end

    local index = index_list[math.random(index_length)]
    local station_id = list[index]

    if length == 1 then
        dict[item_key] = nil
    else
        list[index] = list[length]
        list[length] = nil
    end

    return station_id
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
    local network_item_key = pop_network_item_key_if_any(storage.request_done_items)
    if not network_item_key then return true end

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_origin_station(network.request_done_tickets, item_key)
    local request_station = storage.stations[request_station_id]

    local hauler_id = request_station.hauler ---@type HaulerId
    local hauler = storage.haulers[hauler_id]

    list_remove_value_or_destroy(network.request_haulers, item_key, hauler_id)
    list_remove_value_or_destroy(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = nil
    request_station.request_minimum_active_count = nil
    request_station.hauler = nil
    request_station.total_deliveries = request_station.total_deliveries - 1

    local class = network.classes[hauler.class]
    if class then
        if check_if_hauler_needs_fuel(hauler, class) then
            list_append_or_create(network.fuel_haulers, hauler.class, hauler_id)
            hauler.to_fuel = "TRAVEL"
            set_hauler_status(hauler, { "sspp-alert.getting-fuel" })
            set_hauler_color(hauler, e_train_colors.fuel)
            send_hauler_to_named_stop(hauler, class.fueler_name)
        else
            list_append_or_create(network.to_depot_haulers, hauler.class, hauler_id)
            hauler.to_depot = ""
            set_hauler_status(hauler, { class.bypass_depot and "sspp-alert.ready-for-dispatch" or "sspp-alert.going-to-depot" })
            set_hauler_color(hauler, e_train_colors.depot)
            send_hauler_to_named_stop(hauler, class.depot_name)
        end
    else
        set_hauler_status(hauler, { "sspp-alert.class-not-in-network" })
        send_alert_for_train(hauler.train, hauler.status)
        hauler.train.manual_mode = true
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
        local items = network.items
        local classes = network.classes

        local tickets_remaining = {} ---@type {[ItemKey]: integer}

        for item_key, hauler_ids in pairs(network.at_depot_liquidate_haulers) do
            local tickets = len_or_zero(pull_tickets[item_key]) + len_or_zero(request_tickets[item_key])
            local haulers_to_send = math.min(#hauler_ids, tickets)

            tickets_remaining[item_key] = tickets - haulers_to_send
            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end

        for item_key, hauler_ids in pairs(network.to_depot_liquidate_haulers) do
            if classes[items[item_key].class].bypass_depot then
                local tickets = tickets_remaining[item_key] or (len_or_zero(pull_tickets[item_key]) + len_or_zero(request_tickets[item_key]))
                local haulers_to_send = math.min(#hauler_ids, tickets)

                length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
            end
        end
    end

    storage.tick_state = "LIQUIDATE"
end

local function tick_liquidate()
    local network_item_key = pop_network_item_key_if_any(storage.liquidate_items)
    if not network_item_key then return true end

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_target_station_if_any(network, "pull_tickets", "request_tickets", "request_modes", item_key)
    if not request_station_id then
        list_remove_value_all(storage.liquidate_items, network_item_key)
        return false
    end

    local class_name = network.items[item_key].class

    local hauler_id = pop_best_hauler_if_any(network, "at_depot_liquidate_haulers", "to_depot_liquidate_haulers", class_name, item_key)
    if not hauler_id then
        list_remove_value_all(storage.liquidate_items, network_item_key)
        return false
    end

    local request_station = storage.stations[request_station_id]
    local hauler = storage.haulers[hauler_id]

    hauler.to_depot = nil
    hauler.at_depot = nil

    list_append_or_create(network.request_haulers, item_key, hauler_id)
    list_append_or_create(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = { item = item_key, station = request_station_id, phase = "TRAVEL" }
    request_station.total_deliveries = request_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.dropping-off-cargo" }, item_key, request_station.stop)
    set_hauler_color(hauler, e_train_colors.request)
    send_hauler_to_station(hauler, request_station.stop)

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

local function tick_provide_done()
    local network_item_key = pop_network_item_key_if_any(storage.provide_done_items)
    if not network_item_key then return true end

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_target_station_if_any(network, "pull_tickets", "request_tickets", "request_modes", item_key)
    if not request_station_id then
        list_remove_value_all(storage.provide_done_items, network_item_key)
        return false
    end
    local request_station = storage.stations[request_station_id]

    local provide_station_id = pop_best_origin_station(network.provide_done_tickets, item_key)
    local provide_station = storage.stations[provide_station_id]

    local hauler_id = provide_station.hauler ---@type HaulerId
    local hauler = storage.haulers[hauler_id]

    list_remove_value_or_destroy(network.provide_haulers, item_key, hauler_id)
    list_remove_value_or_destroy(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = nil
    provide_station.provide_minimum_active_count = nil
    provide_station.hauler = nil
    provide_station.total_deliveries = provide_station.total_deliveries - 1

    list_append_or_create(network.request_haulers, item_key, hauler_id)
    list_append_or_create(request_station.request_deliveries, item_key, hauler_id)
    hauler.to_request = { item = item_key, station = request_station_id, phase = "TRAVEL" }
    request_station.total_deliveries = request_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.dropping-off-cargo" }, item_key, request_station.stop)
    set_hauler_color(hauler, e_train_colors.request)
    send_hauler_to_station(hauler, request_station.stop)

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
                local provide_hauler_count = len_or_zero(provide_haulers[item_key])
                haulers_to_send = math.max(haulers_to_send, math.min(push_count, request_total - provide_hauler_count))
            end

            if pull_count > 0 then
                local provide_total = push_count + len_or_zero(provide_tickets[item_key])
                local provide_hauler_count = len_or_zero(provide_haulers[item_key])
                haulers_to_send = math.max(haulers_to_send, math.min(provide_total, pull_count - provide_hauler_count))
            end

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "DISPATCH"
end

local function tick_dispatch()
    local network_item_key = pop_network_item_key_if_any(storage.dispatch_items)
    if not network_item_key then return true end

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local provide_station_id = pop_best_target_station_if_any(network, "push_tickets", "provide_tickets", "provide_modes", item_key)
    if not provide_station_id then
        list_remove_value_all(storage.dispatch_items, network_item_key)
        return false
    end
    local provide_station = storage.stations[provide_station_id]

    if read_stop_flag(provide_station.stop, e_stop_flags.bufferless) then
        -- will be sent to a requester in the next cycle
        local hauler_id = provide_station.hauler --[[@as HaulerId]]
        storage.haulers[hauler_id].to_provide.phase = "DONE"
        list_remove_value_or_destroy(network.bufferless_haulers, item_key, hauler_id)
        list_append_or_create(network.provide_haulers, item_key, hauler_id)
        return false
    end

    local class_name = network.items[item_key].class

    local hauler_id = pop_best_hauler_if_any(network, "at_depot_haulers", "to_depot_haulers", class_name)
    if not hauler_id then
        list_remove_value_all(storage.dispatch_items, network_item_key)
        return false
    end
    local hauler = storage.haulers[hauler_id]

    hauler.to_depot = nil
    hauler.at_depot = nil

    list_append_or_create(network.provide_haulers, item_key, hauler_id)
    list_append_or_create(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = { item = item_key, station = provide_station_id, phase = "TRAVEL" }
    provide_station.total_deliveries = provide_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.picking-up-cargo" }, item_key, provide_station.stop)
    set_hauler_color(hauler, e_train_colors.provide)
    send_hauler_to_station(hauler, provide_station.stop)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_bufferless_dispatch()
    local list, length = {}, 0 ---@type NetworkItemKey[]
    storage.bufferless_dispatch_items = list

    for network_name, network in pairs(storage.networks) do
        for item_key, station_ids in pairs(network.bufferless_tickets) do
            local haulers_to_send = #station_ids
            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "BUFFERLESS_DISPATCH"
end

local function tick_bufferless_dispatch()
    local network_item_key = pop_network_item_key_if_any(storage.bufferless_dispatch_items)
    if not network_item_key then return true end

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    -- TODO: passing bufferless_tickets twice is weird, the function needs a better signature
    local provide_station_id = pop_best_target_station_if_any(network, "bufferless_tickets", "bufferless_tickets", "provide_modes", item_key)
    if not provide_station_id then
        list_remove_value_all(storage.bufferless_dispatch_items, network_item_key)
        return false
    end

    local class_name = network.items[item_key].class

    local hauler_id = pop_best_hauler_if_any(network, "at_depot_haulers", "to_depot_haulers", class_name)
    if not hauler_id then
        list_remove_value_all(storage.bufferless_dispatch_items, network_item_key)
        return false
    end

    local provide_station = storage.stations[provide_station_id]
    local hauler = storage.haulers[hauler_id]

    hauler.to_depot = nil
    hauler.at_depot = nil

    list_append_or_create(network.bufferless_haulers, item_key, hauler_id)
    list_append_or_create(provide_station.provide_deliveries, item_key, hauler_id)
    hauler.to_provide = { item = item_key, station = provide_station_id, phase = "TRAVEL" }
    provide_station.total_deliveries = provide_station.total_deliveries + 1

    set_hauler_status(hauler, { "sspp-alert.picking-up-cargo" }, item_key, provide_station.stop)
    set_hauler_color(hauler, e_train_colors.provide)
    send_hauler_to_station(hauler, provide_station.stop)

    return false
end

-------------------------------------------------------------------------------

function on_tick()
    local tick_state = storage.tick_state

    if tick_state == "POLL" then
        for _ = 1, mod_settings.stations_per_tick do
            if tick_poll() then
                gui.on_poll_finished()
                prepare_for_tick_request_done()
                break
            end
        end
    elseif tick_state == "REQUEST_DONE" then
        if tick_request_done() then
            prepare_for_tick_liquidate()
        end
    elseif tick_state == "LIQUIDATE" then
        if tick_liquidate() then
            prepare_for_tick_provide_done()
        end
    elseif tick_state == "PROVIDE_DONE" then
        if tick_provide_done() then
            prepare_for_tick_dispatch()
        end
    elseif tick_state == "DISPATCH" then
        if tick_dispatch() then
            prepare_for_tick_bufferless_dispatch()
        end
    elseif tick_state == "BUFFERLESS_DISPATCH" then
        if tick_bufferless_dispatch() then
            prepare_for_tick_poll()
        end
    elseif tick_state == "INITIAL" then
        prepare_for_tick_poll()
    end
end
