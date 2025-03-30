-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local gui = require("__SourceSinkPushPull__.scripts.gui")
local main = require("__SourceSinkPushPull__.scripts.main")
local enums = require("__SourceSinkPushPull__.scripts.enums")

local e_train_colors, e_stop_flags = enums.train_colors, enums.stop_flags

local s_match = string.match
local m_random, m_min, m_max, m_floor = math.random, math.min, math.max, math.floor

local len_or_zero, enumerate_spoil_results = lib.len_or_zero, lib.enumerate_spoil_results
local list_create_or_append, list_create_or_extend = lib.list_create_or_append, lib.list_create_or_extend
local list_destroy_or_remove, list_remove_all = lib.list_destroy_or_remove, lib.list_remove_all
local compute_storage_needed, compute_buffer = lib.compute_storage_needed, lib.compute_buffer
local read_stop_flag, get_train_item_count = lib.read_stop_flag, lib.get_train_item_count
local send_train_to_station, assign_job_index = lib.send_train_to_station, lib.assign_job_index

local send_hauler_to_fuel_or_depot = main.hauler.send_to_fuel_or_depot

--------------------------------------------------------------------------------

--- Append zero or more copies of a network item key to a list.
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

--- Extract a random usable entry from a list of network item keys.
---@param list NetworkItemKey[]
---@return NetworkItemKey?
local function pop_network_item_key_if_any(list)
    local length = #list

    while length > 0 do
        local index = m_random(length)
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

--------------------------------------------------------------------------------

local function prepare_for_tick_poll()
    for _, network in pairs(storage.networks) do
        network.push_tickets = {}
        network.provide_tickets = {}
        network.pull_tickets = {}
        network.request_tickets = {}
        network.provide_done_tickets = {}
        network.request_done_tickets = {}
        network.buffer_tickets = {}
    end

    storage.disabled_items = {}

    local list, length = {}, 0 ---@type StationId[]
    storage.poll_stations = list

    for station_id, station in pairs(storage.stations) do
        local provide = station.provide
        if not (provide and next(provide.items)) then
            local request = station.request
            if not (request and next(request.items)) then
                goto continue
            end
        end
        length = length + 1
        list[length] = station_id
        ::continue::
    end

    storage.tick_state = "POLL"
end

---@param train LuaTrain
---@param name string
---@param quality string?
---@return boolean
local function check_if_loaded_wrong_cargo(train, name, quality)
    for _, item in pairs(train.get_contents()) do
        if (item.quality or "normal") == quality then
            local item_name = item.name
            if item_name == name then goto continue end
            for _, result_name in enumerate_spoil_results(name) do
                if item_name == result_name then goto continue end
            end
        end
        do return true end
        ::continue::
    end

    for fluid_name, _ in pairs(train.get_fluid_contents()) do
        if quality or (fluid_name ~= name) then return true end
    end

    return false
end

---@param network_items {[ItemKey]: NetworkItem}
---@param station_items {[ItemKey]: StationItem}
---@param station_deliveries {[ItemKey]: HaulerId[]}
---@param trains_limit_for_subtract integer?
---@return {[ItemKey]: integer} counts
local function poll_item_counts_bufferless(network_items, station_items, station_deliveries, trains_limit_for_subtract)
    local haulers = storage.haulers
    local item_counts = {} ---@type {[ItemKey]: integer}

    -- bufferless stations will have only one item, we just use a loop for consistency
    for item_key, _ in pairs(station_items) do
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
            if trains_limit_for_subtract then
                count = network_item.delivery_size * trains_limit_for_subtract - count
            end
            item_counts[item_key] = count
        end
    end

    return item_counts
end

---@param network_items {[ItemKey]: NetworkItem}
---@param station_items {[ItemKey]: StationItem}
---@param general_io LuaEntity
---@param subtract true?
---@return {[ItemKey]: integer} counts
local function poll_item_counts_buffered(network_items, station_items, general_io, subtract)
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
---@param station_items {[ItemKey]: StationItem}
---@param comb LuaEntity
---@return {[ItemKey]: ItemMode} modes
local function poll_item_modes(network_items, station_items, comb)
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

        local index = m_random(length)
        station_id = list[index]

        list[index] = list[length]
        list[length] = nil
    end

    local station = storage.stations[station_id]
    local network = storage.networks[station.network]

    local network_items, network_classes = network.items, network.classes

    local stop = station.stop
    local enabled = not read_stop_flag(stop, e_stop_flags.disable)
    local buffered = not read_stop_flag(stop, e_stop_flags.bufferless)

    -- check the active hauler if we have one, then create a done ticket

    local hauler_buffer_item_key, hauler_provide_item_key, hauler_request_item_key ---@type ItemKey?, ItemKey?, ItemKey?

    local hauler_id = station.hauler
    if hauler_id then
        local hauler = storage.haulers[hauler_id]
        local train = hauler.train
        local job = network.jobs[hauler.job] --[[@as NetworkJob.Pickup|NetworkJob.Dropoff|NetworkJob.Combined]]
        local item_key = job.item
        local network_item = network_items[item_key]

        if check_if_loaded_wrong_cargo(train, network_item.name, network_item.quality) then
            hauler.status = { message = { "sspp-alert.loaded-wrong-cargo" } }
            lib.show_train_alert(train, hauler.status.message)
            train.manual_mode = true
        elseif job.finish_tick then
            if job.type ~= "PICKUP" then -- combined or dropoff job done at requester
                hauler_request_item_key = item_key
                list_create_or_append(network.request_done_tickets, item_key, station_id)
            elseif station.bufferless_dispatch then -- pickup job with a request
                hauler_provide_item_key = item_key
                list_create_or_append(network.provide_done_tickets, item_key, station_id)
            else -- pickup job still waiting for a request
                hauler_buffer_item_key = item_key
            end
        elseif job.provide_done_tick and not job.request_arrive_tick then -- combined job done at provider
            hauler_provide_item_key = item_key
            list_create_or_append(network.provide_done_tickets, item_key, station_id)
        end
    end

    --- poll counts and modes, then create supply (provide/request) and demand (push/pull) tickets

    local provide, request = station.provide, station.request

    if provide then
        local provide_items, provide_deliveries = provide.items, provide.deliveries

        local provide_counts ---@type {[ItemKey]: integer}
        if buffered then
            provide_counts = poll_item_counts_buffered(network_items, provide_items, station.general_io)
        else
            provide_counts = poll_item_counts_bufferless(network_items, provide_items, provide_deliveries)
        end
        local provide_modes = poll_item_modes(network_items, provide_items, provide.comb)

        for item_key, provide_item in pairs(provide_items) do
            local network_item = network_items[item_key]
            if network_item then
                local count, mode = provide_counts[item_key], provide_modes[item_key]

                if hauler_provide_item_key == item_key then
                    local minimum_count = station.minimum_active_count ---@type integer
                    if minimum_count > count then
                        count = minimum_count
                    elseif minimum_count < count then
                        station.minimum_active_count = count
                    end
                    hauler_provide_item_key = nil
                elseif hauler_buffer_item_key == item_key then
                    if mode > 3 then
                        list_create_or_append(network.push_tickets, item_key, station_id)
                    else
                        list_create_or_append(network.provide_tickets, item_key, station_id)
                    end
                    hauler_buffer_item_key = nil
                end

                if enabled and mode > 0 and mode < 7 and network_classes[network_item.class] then
                    if buffered then
                        local deliveries = len_or_zero(provide_deliveries[item_key])
                        local want_deliveries = m_floor(count / network_item.delivery_size) - deliveries
                        if want_deliveries > 0 then
                            if mode > 3 then
                                local push_count = count - compute_buffer(network_item, provide_item)
                                local push_want_deliveries = m_floor(push_count / network_item.delivery_size) - deliveries
                                if push_want_deliveries > 0 then
                                    list_create_or_extend(network.push_tickets, item_key, station_id, push_want_deliveries)
                                    want_deliveries = want_deliveries - push_want_deliveries
                                end
                            end
                            if want_deliveries > 0 then
                                list_create_or_extend(network.provide_tickets, item_key, station_id, want_deliveries)
                            end
                        end
                    else
                        local want_deliveries = stop.trains_limit - station.total_deliveries
                        if want_deliveries > 0 then
                            list_create_or_extend(network.buffer_tickets, item_key, station_id, want_deliveries)
                        end
                    end
                end
            end
        end

        provide.counts, provide.modes = provide_counts, provide_modes
    end

    if request then
        local request_items, request_deliveries = request.items, request.deliveries

        local request_counts ---@type {[ItemKey]: integer}
        if buffered then
            request_counts = poll_item_counts_buffered(network_items, request_items, station.general_io, true)
        else
            request_counts = poll_item_counts_bufferless(network_items, request_items, request_deliveries, stop.trains_limit)
        end
        local request_modes = poll_item_modes(network_items, request_items, request.comb)

        for item_key, request_item in pairs(request_items) do
            local network_item = network_items[item_key]
            if network_item then
                local count, mode = request_counts[item_key], request_modes[item_key]

                if hauler_request_item_key == item_key then
                    local minimum_count = station.minimum_active_count ---@type integer
                    if minimum_count > count then
                        count = minimum_count
                    elseif minimum_count < count then
                        station.minimum_active_count = count
                    end
                    hauler_request_item_key = nil
                end

                if enabled and mode > 0 and mode < 7 and network_classes[network_item.class] then
                    if buffered then
                        local deliveries = len_or_zero(request_deliveries[item_key])
                        local want_deliveries = m_floor(count / network_item.delivery_size) - deliveries
                        if want_deliveries > 0 then
                            if mode > 3 then
                                local pull_count = count - compute_buffer(network_item, request_item)
                                local pull_want_deliveries = m_floor(pull_count / network_item.delivery_size) - deliveries
                                if pull_want_deliveries > 0 then
                                    list_create_or_extend(network.pull_tickets, item_key, station_id, pull_want_deliveries)
                                    want_deliveries = want_deliveries - pull_want_deliveries
                                end
                            end
                            if want_deliveries > 0 then
                                list_create_or_extend(network.request_tickets, item_key, station_id, want_deliveries)
                            end
                        end
                    else
                        local want_deliveries = stop.trains_limit - station.total_deliveries
                        if want_deliveries > 0 then
                            if mode > 3 then
                                list_create_or_extend(network.pull_tickets, item_key, station_id, want_deliveries)
                            else
                                list_create_or_extend(network.request_tickets, item_key, station_id, want_deliveries)
                            end
                        end
                    end
                end
            end
        end

        request.counts, request.modes = request_counts, request_modes
    end

    if hauler_buffer_item_key or hauler_provide_item_key or hauler_request_item_key then
        error("station assigned to incorrect hauler")
    end

    return false
end

--------------------------------------------------------------------------------

---@param dict {[string]: uint[]}
---@param key string
---@param list uint[]
---@param index integer
---@return uint
local function extract_id(dict, key, list, index)
    local length, id = #list, list[index]
    if length == 1 then
        dict[key] = nil
    else
        list[index] = list[length]
        list[length] = nil
    end
    return id
end

---@param network Network
---@param item_key ItemKey
---@return HaulerId?
local function pop_best_liquidate_hauler_if_any(network, item_key)
    local dict = network.at_depot_liquidate_haulers
    local list = dict[item_key]
    if not list then
        if network.classes[network.items[item_key].class].bypass_depot then
            dict = network.to_depot_liquidate_haulers
            list = dict[item_key]
        end
        if not list then return nil end
    end

    return extract_id(dict, item_key, list, m_random(#list))
end

---@param network Network
---@param item_key ItemKey
---@return HaulerId?
local function pop_best_dispatch_hauler_if_any(network, item_key)
    local class_name = network.items[item_key].class

    local dict = network.at_depot_haulers
    local list = dict[class_name]
    if not list then
        if network.classes[class_name].bypass_depot then
            dict = network.to_depot_haulers
            list = dict[class_name]
        end
        if not list then return nil end
    end

    return extract_id(dict, class_name, list, m_random(#list))
end

---@param first_dict {[ItemKey]: StationId[]}
---@param second_dict {[ItemKey]: StationId[]}
---@param item_key ItemKey
---@param get_mode_and_score fun(station: Station, item_key: ItemKey): mode: ItemMode, score: number
---@return StationId?
local function pop_best_station_if_any(first_dict, second_dict, item_key, get_mode_and_score)
    local dict, list = first_dict, first_dict[item_key]
    if not list then dict, list = second_dict, second_dict[item_key] end

    local stations = storage.stations

    local index_list, index_length ---@type integer[], integer
    local best_mode, best_score = 0, -10.0

    -- TODO: optimise case where a station generates multiple tickets (if same as previous only need to check if previous passed)

    for index, station_id in pairs(list) do
        local mode, score = get_mode_and_score(stations[station_id], item_key)
        if mode >= best_mode then
            if mode > best_mode or score > best_score then
                index_list, index_length = {}, 0
                best_mode, best_score = mode, score
            end
            if score >= best_score and score > 0.0 then
                index_length = index_length + 1
                index_list[index_length] = index
            end
        end
    end

    if index_length > 0 then
        return extract_id(dict, item_key, list, index_list[m_random(index_length)])
    end

    return nil
end

---@param dict {[ItemKey]: StationId[]}
---@param item_key ItemKey
---@param get_mode_and_score fun(station: Station, item_key: ItemKey): mode: ItemMode, score: number
---@return StationId
local function pop_best_station(dict, item_key, get_mode_and_score)
    local stations, list = storage.stations, dict[item_key]

    local index_list, index_length ---@type integer[], integer
    local best_mode, best_score = 0, -10.0

    for index, station_id in pairs(list) do
        local mode, score = get_mode_and_score(stations[station_id], item_key)
        if mode >= best_mode then
            if mode > best_mode or score > best_score then
                index_list, index_length = {}, 0
                best_mode, best_score = mode, score
            end
            if score >= best_score then
                index_length = index_length + 1
                index_list[index_length] = index
            end
        end
    end

    return extract_id(dict, item_key, list, index_list[m_random(index_length)])
end

--------------------------------------------------------------------------------

---@param station Station
---@param item_key ItemKey
---@return ItemMode, number
local function get_done_mode_and_score(station, item_key)
    local limit = station.stop.trains_limit
    local score = 1.0 - (limit - station.total_deliveries) / limit -- fullness
    return 1, score -- mode is not relevant here
end

---@param station Station
---@param item_key ItemKey
---@return ItemMode, number
local function get_request_mode_and_score(station, item_key)
    local limit = station.stop.trains_limit
    local score = (limit - station.total_deliveries) / limit -- emptyness
    return station.request.modes[item_key], score
end

---@param station Station
---@param item_key ItemKey
---@return ItemMode, number
local function get_provide_mode_and_score(station, item_key)
    local stop = station.stop
    local limit = stop.trains_limit
    local score = (limit - station.total_deliveries) / limit -- emptyness
    if read_stop_flag(stop, e_stop_flags.bufferless) then score = 1.0 - score end -- fullness
    return station.provide.modes[item_key], score
end

---@param station Station
---@param item_key ItemKey
---@return ItemMode, number
local function get_buffer_mode_and_score(station, item_key)
    local limit = station.stop.trains_limit
    local score = (limit - station.total_deliveries) / limit -- emptyness
    return station.provide.modes[item_key], score
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

    local network_name, item_key = s_match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_station(network.request_done_tickets, item_key, get_done_mode_and_score)
    local request_station = storage.stations[request_station_id]

    local hauler_id = request_station.hauler --[[@as HaulerId]]
    local hauler = storage.haulers[hauler_id]

    list_destroy_or_remove(network.request_haulers, item_key, hauler_id)
    list_destroy_or_remove(request_station.request.deliveries, item_key, hauler_id)
    request_station.total_deliveries = request_station.total_deliveries - 1
    request_station.hauler = nil
    request_station.minimum_active_count = nil

    hauler.job = nil

    send_hauler_to_fuel_or_depot(hauler, true, false)

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
            local haulers_to_send = m_min(#hauler_ids, tickets)

            tickets_remaining[item_key] = tickets - haulers_to_send
            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end

        for item_key, hauler_ids in pairs(network.to_depot_liquidate_haulers) do
            if classes[items[item_key].class].bypass_depot then
                local tickets = tickets_remaining[item_key] or (len_or_zero(pull_tickets[item_key]) + len_or_zero(request_tickets[item_key]))
                local haulers_to_send = m_min(#hauler_ids, tickets)

                length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
            end
        end
    end

    storage.tick_state = "LIQUIDATE"
end

local function tick_liquidate()
    local network_item_key = pop_network_item_key_if_any(storage.liquidate_items)
    if not network_item_key then return true end

    local network_name, item_key = s_match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_station_if_any(network.pull_tickets, network.request_tickets, item_key, get_request_mode_and_score)
    if not request_station_id then
        list_remove_all(storage.liquidate_items, network_item_key)
        return false
    end

    local hauler_id = pop_best_liquidate_hauler_if_any(network, item_key)
    if not hauler_id then
        list_remove_all(storage.liquidate_items, network_item_key)
        return false
    end

    local request_station = storage.stations[request_station_id]
    local hauler = storage.haulers[hauler_id]

    hauler.to_depot = nil
    hauler.at_depot = nil

    list_create_or_append(network.request_haulers, item_key, hauler_id)
    list_create_or_append(request_station.request.deliveries, item_key, hauler_id)
    request_station.total_deliveries = request_station.total_deliveries + 1

    local request_stop = request_station.stop
    send_train_to_station(hauler.train, e_train_colors.request, request_stop)

    assign_job_index(network, hauler, { type = "DROPOFF", hauler = hauler_id, start_tick = game.tick, item = item_key, request_stop = request_stop })
    gui.on_job_created(network_name)
    hauler.status = { message = { "sspp-alert.dropping-off-cargo" }, item = item_key, stop = request_stop }
    gui.on_status_changed(hauler_id)

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
            local haulers_to_send = m_min(#station_ids, pull_count + request_count)

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "PROVIDE_DONE"
end

local function tick_provide_done()
    local network_item_key = pop_network_item_key_if_any(storage.provide_done_items)
    if not network_item_key then return true end

    local network_name, item_key = s_match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local request_station_id = pop_best_station_if_any(network.pull_tickets, network.request_tickets, item_key, get_request_mode_and_score)
    if not request_station_id then
        list_remove_all(storage.provide_done_items, network_item_key)
        return false
    end
    local request_station = storage.stations[request_station_id]

    local provide_station_id = pop_best_station(network.provide_done_tickets, item_key, get_done_mode_and_score)
    local provide_station = storage.stations[provide_station_id]

    local hauler_id = provide_station.hauler --[[@as HaulerId]]
    local hauler = storage.haulers[hauler_id]

    local bufferless = read_stop_flag(provide_station.stop, e_stop_flags.bufferless)

    if bufferless then
        list_destroy_or_remove(network.buffer_haulers, item_key, hauler_id)
    else
        list_destroy_or_remove(network.provide_haulers, item_key, hauler_id)
    end
    list_destroy_or_remove(provide_station.provide.deliveries, item_key, hauler_id)
    provide_station.total_deliveries = provide_station.total_deliveries - 1
    provide_station.hauler = nil
    provide_station.minimum_active_count = nil

    list_create_or_append(network.request_haulers, item_key, hauler_id)
    list_create_or_append(request_station.request.deliveries, item_key, hauler_id)
    request_station.total_deliveries = request_station.total_deliveries + 1

    local request_stop = request_station.stop
    send_train_to_station(hauler.train, e_train_colors.request, request_stop)

    if bufferless then
        assign_job_index(network, hauler, { type = "DROPOFF", hauler = hauler_id, start_tick = game.tick, item = item_key, request_stop = request_stop })
        gui.on_job_created(network_name)
    else
        local job_index = hauler.job --[[@as JobIndex]]
        network.jobs[job_index].request_stop = request_stop
        gui.on_job_updated(network_name, job_index)
    end
    hauler.status = { message = { "sspp-alert.dropping-off-cargo" }, item = item_key, stop = request_stop }
    gui.on_status_changed(hauler_id)

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
                haulers_to_send = m_max(haulers_to_send, m_min(push_count, request_total - provide_hauler_count))
            end

            if pull_count > 0 then
                local provide_total = push_count + len_or_zero(provide_tickets[item_key])
                local provide_hauler_count = len_or_zero(provide_haulers[item_key])
                haulers_to_send = m_max(haulers_to_send, m_min(provide_total, pull_count - provide_hauler_count))
            end

            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "DISPATCH"
end

local function tick_dispatch()
    local network_item_key = pop_network_item_key_if_any(storage.dispatch_items)
    if not network_item_key then return true end

    local network_name, item_key = s_match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local provide_station_id = pop_best_station_if_any(network.push_tickets, network.provide_tickets, item_key, get_provide_mode_and_score)
    if not provide_station_id then
        list_remove_all(storage.dispatch_items, network_item_key)
        return false
    end
    local provide_station = storage.stations[provide_station_id]

    if read_stop_flag(provide_station.stop, e_stop_flags.bufferless) then
        provide_station.bufferless_dispatch = true -- create a provide_done ticket in the next cycle
        return false
    end

    local hauler_id = pop_best_dispatch_hauler_if_any(network, item_key)
    if not hauler_id then
        list_remove_all(storage.dispatch_items, network_item_key)
        return false
    end
    local hauler = storage.haulers[hauler_id]

    hauler.to_depot = nil
    hauler.at_depot = nil

    list_create_or_append(network.provide_haulers, item_key, hauler_id)
    list_create_or_append(provide_station.provide.deliveries, item_key, hauler_id)
    provide_station.total_deliveries = provide_station.total_deliveries + 1

    local provide_stop = provide_station.stop
    send_train_to_station(hauler.train, e_train_colors.provide, provide_stop)

    assign_job_index(network, hauler, { type = "COMBINED", hauler = hauler_id, start_tick = game.tick, item = item_key, provide_stop = provide_stop })
    gui.on_job_created(network_name)
    hauler.status = { message = { "sspp-alert.picking-up-cargo" }, item = item_key, stop = provide_stop }
    gui.on_status_changed(hauler_id)

    return false
end

--------------------------------------------------------------------------------

local function prepare_for_tick_buffer()
    local list, length = {}, 0 ---@type NetworkItemKey[]
    storage.buffer_items = list

    for network_name, network in pairs(storage.networks) do
        for item_key, station_ids in pairs(network.buffer_tickets) do
            local haulers_to_send = #station_ids
            length = extend_network_item_key_list(list, length, network_name, item_key, haulers_to_send)
        end
    end

    storage.tick_state = "BUFFER"
end

local function tick_buffer()
    local network_item_key = pop_network_item_key_if_any(storage.buffer_items)
    if not network_item_key then return true end

    local network_name, item_key = s_match(network_item_key, "(.-):(.+)")
    local network = storage.networks[network_name]

    local provide_station_id = pop_best_station(network.buffer_tickets, item_key, get_buffer_mode_and_score)
    local provide_station = storage.stations[provide_station_id]

    local hauler_id = pop_best_dispatch_hauler_if_any(network, item_key)
    if not hauler_id then
        list_remove_all(storage.buffer_items, network_item_key)
        return false
    end
    local hauler = storage.haulers[hauler_id]

    hauler.to_depot = nil
    hauler.at_depot = nil

    list_create_or_append(network.buffer_haulers, item_key, hauler_id)
    list_create_or_append(provide_station.provide.deliveries, item_key, hauler_id)
    provide_station.total_deliveries = provide_station.total_deliveries + 1

    local provide_stop = provide_station.stop
    send_train_to_station(hauler.train, e_train_colors.provide, provide_stop)

    assign_job_index(network, hauler, { type = "PICKUP", hauler = hauler_id, start_tick = game.tick, item = item_key, provide_stop = provide_stop })
    gui.on_job_created(network_name)
    hauler.status = { message = { "sspp-alert.picking-up-cargo" }, item = item_key, stop = provide_stop }
    gui.on_status_changed(hauler_id)

    return false
end

-------------------------------------------------------------------------------

local function purge_old_inactive_jobs()
    local haulers = storage.haulers
    local tick = game.tick

    for network_name, network in pairs(storage.networks) do
        local jobs = network.jobs

        for job_index, job in pairs(jobs) do
            -- TODO: make this a mod setting
            if tick - job.start_tick < 108000 then -- 30 mins
                break -- keep this job and all newer jobs
            end
            local hauler = haulers[job.hauler]
            if job_index ~= (hauler and hauler.job) then
                jobs[job_index] = nil
                gui.on_job_removed(network_name, job_index)
            end
        end
    end
end

-------------------------------------------------------------------------------

local function on_tick()
    local tick_state = storage.tick_state

    if tick_state == "POLL" then
        for _ = 1, mod_settings.stations_per_tick do
            if tick_poll() then
                -- TODO: profile to work out if this should be split over 3 ticks or more
                purge_old_inactive_jobs()
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
            prepare_for_tick_buffer()
        end
    elseif tick_state == "BUFFER" then
        if tick_buffer() then
            prepare_for_tick_poll()
        end
    elseif tick_state == "INITIAL" then
        prepare_for_tick_poll()
    end
end

script.on_event(defines.events.on_tick, on_tick)
