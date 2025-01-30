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
    local network = storage.networks[station.network]

    local hauler_provide_item_key, hauler_request_item_key ---@type ItemKey?, ItemKey?

    local hauler_id = station.hauler
    if hauler_id then
        local hauler = storage.haulers[hauler_id]
        if hauler.to_provide then
            if hauler.to_provide.phase == "DONE" then
                hauler_provide_item_key = hauler.to_provide.item
                list_append_or_create(network.provide_done_tickets, hauler_provide_item_key, station_id)
            end
        else
            if hauler.to_request.phase == "DONE" then
                hauler_request_item_key = hauler.to_request.item
                list_append_or_create(network.request_done_tickets, hauler_request_item_key, station_id)
            end
        end
    end

    local storage_counts = {} ---@type {[ItemKey]: integer}

    local storage_signals = station.general_io.get_signals(defines.wire_connector_id.combinator_input_red, defines.wire_connector_id.combinator_input_green)
    if storage_signals then
        for _, signal in pairs(storage_signals) do
            local id = signal.signal
            local type = id.type or "item"
            if type == "item" then
                storage_counts[id.name .. ":" .. (id.quality or "normal")] = signal.count
            elseif type == "fluid" then
                storage_counts[id.name] = signal.count
            end
        end
    end

    if station.provide_items then
        local provide_counts = {} ---@type {[ItemKey]: integer}
        station.provide_counts = provide_counts

        for item_key, provide_item in pairs(station.provide_items) do
            local network_item = network.items[item_key]
            if network_item then
                -- for provide items, count is the number of items in storage
                local count = storage_counts[item_key] or 0
                provide_counts[item_key] = count

                if hauler_provide_item_key == item_key then
                    local minimum_count = station.provide_minimum_active_count ---@type integer
                    if minimum_count > count then
                        count = minimum_count
                    elseif minimum_count < count then
                        station.provide_minimum_active_count = count
                    end
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
        local request_counts = {} ---@type {[ItemKey]: integer}
        station.request_counts = request_counts

        for item_key, request_item in pairs(station.request_items) do
            local network_item = network.items[item_key]
            if network_item then
                -- for request items, count is the number of items missing from storage
                local count = compute_storage_needed(network_item, request_item) - (storage_counts[item_key] or 0)
                request_counts[item_key] = count

                if hauler_request_item_key == item_key then
                    local minimum_count = station.request_minimum_active_count ---@type integer
                    if minimum_count > count then
                        count = minimum_count
                    elseif minimum_count < count then
                        station.request_minimum_active_count = count
                    end
                    hauler_request_item_key = nil
                end

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

    if length > 1 then
        local index = math.random(length)
        local hauler_id = list[index]
        list[index] = list[length]
        list[length] = nil
        return hauler_id
    end

    if length > 0 then
        local hauler_id = list[1]
        dict[key_or_name] = nil
        return hauler_id
    end

    return nil
end

---@param network Network
---@param first_dict_name "push_tickets"|"pull_tickets"
---@param second_dict_name "provide_tickets"|"request_tickets"
---@param item_key ItemKey
---@return StationId?
local function pop_best_station_if_any(network, first_dict_name, second_dict_name, item_key)
    local dict = network[first_dict_name] ---@type {[ItemKey]: StationId[]}
    if not dict[item_key] then
        dict = network[second_dict_name]
    end

    local list = dict[item_key]
    local length = #list

    if length > 1 then
        local stations = storage.stations

        local best_score = -10
        for _, station_id in pairs(list) do
            local station = stations[station_id]
            local score = station.stop.trains_limit - station.total_deliveries
            if score > best_score then best_score = score end
        end

        if best_score <= 0 then
            return nil
        end

        local index_list = {}
        for index, station_id in pairs(list) do
            local station = stations[station_id]
            local score = station.stop.trains_limit - station.total_deliveries
            if score == best_score then index_list[#index_list+1] = index end
        end

        local index = index_list[math.random(#index_list)]

        local station_id = list[index]
        list[index] = list[length]
        list[length] = nil

        return station_id
    end

    local station_id = list[1]
    local station = storage.stations[station_id]

    if station.stop.trains_limit <= station.total_deliveries then
        return nil
    end

    dict[item_key] = nil

    return station_id
end

---@param dict {[ItemKey]: StationId[]}
---@param item_key ItemKey
---@return StationId
local function pop_worst_station(dict, item_key)
    local list = dict[item_key]
    local length = #list

    if length > 1 then
        local stations = storage.stations

        local worst_score = 10
        for _, station_id in pairs(list) do
            local station = stations[station_id]
            local score = station.stop.trains_limit - station.total_deliveries
            if score < worst_score then worst_score = score end
        end

        local index_list = {}
        for index, station_id in pairs(list) do
            local station = stations[station_id]
            local score = station.stop.trains_limit - station.total_deliveries
            if score == worst_score then index_list[#index_list+1] = index end
        end

        local index = index_list[math.random(#index_list)]

        local station_id = list[index]
        list[index] = list[length]
        list[length] = nil

        return station_id
    end

    local station_id = list[1]

    dict[item_key] = nil

    return station_id
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
    local network_item_key ---@type NetworkItemKey
    repeat
        network_item_key = list_pop_random_if_any(storage.liquidate_items)
        if not network_item_key then return true end
        if not storage.disabled_items[network_item_key] then break end
    until false

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_station_if_any(network, "pull_tickets", "request_tickets", item_key)
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
    local network_item_key ---@type NetworkItemKey
    repeat
        network_item_key = list_pop_random_if_any(storage.dispatch_items)
        if not network_item_key then return true end
        if not storage.disabled_items[network_item_key] then break end
    until false

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local provide_station_id = pop_best_station_if_any(network, "push_tickets", "provide_tickets", item_key)
    if not provide_station_id then
        list_remove_value_all(storage.dispatch_items, network_item_key)
        return false
    end

    local class_name = network.items[item_key].class

    local hauler_id = pop_best_hauler_if_any(network, "at_depot_haulers", "to_depot_haulers", class_name)
    if not hauler_id then
        list_remove_value_all(storage.dispatch_items, network_item_key)
        return false
    end

    local provide_station = storage.stations[provide_station_id]
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
    local network_item_key ---@type NetworkItemKey
    repeat
        network_item_key = list_pop_random_if_any(storage.provide_done_items)
        if not network_item_key then return true end
        if not storage.disabled_items[network_item_key] then break end
    until false

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_station_if_any(network, "pull_tickets", "request_tickets", item_key)
    if not request_station_id then
        list_remove_value_all(storage.provide_done_items, network_item_key)
        return false
    end
    local request_station = storage.stations[request_station_id]

    local provide_station_id = pop_worst_station(network.provide_done_tickets, item_key)
    local provide_station = storage.stations[provide_station_id]

    local hauler_id = assert(provide_station.hauler)
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
    local network_item_key ---@type NetworkItemKey
    repeat
        network_item_key = list_pop_random_if_any(storage.request_done_items)
        if not network_item_key then return true end
        if not storage.disabled_items[network_item_key] then break end
    until false

    local network_name, item_key = string.match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_worst_station(network.request_done_tickets, item_key)
    local request_station = storage.stations[request_station_id]

    local hauler_id = assert(request_station.hauler)
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
            prepare_for_tick_poll()
        end
    elseif tick_state == "INITIAL" then
        prepare_for_tick_poll()
    end
end
