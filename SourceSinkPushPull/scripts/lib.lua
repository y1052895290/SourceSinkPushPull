-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param object {[string]: table}
---@param key string
---@return table
function get_or_create_table(object, key)
    local table = object[key]
    if not table then
        table = {}
        object[key] = table
    end
    return table
end

---@generic T
---@param list T[]?
function len_or_zero(list)
    if list then
        return #list
    end
    return 0
end

--------------------------------------------------------------------------------

--- Create a list if needed, then append a value.
---@generic T
---@param object {[string]: T[]}
---@param key string
---@param value T
function list_append_or_create(object, key, value)
    local list = object[key]
    if not list then
        object[key] = { value }
    else
        list[#list+1] = value
    end
end

--- Create a list if needed, then append one or more copies of a value.
---@generic T
---@param object {[string]: T[]}
---@param key string
---@param value T
---@param copies integer
function list_extend_or_create(object, key, value, copies)
    local list = object[key]
    if not list then
        list = {}
        object[key] = list
    end
    local length = #list
    for i = length + 1, length + copies do
        list[i] = value
    end
end

--- Remove a known value from a list.
---@generic T
---@param list T[]
---@param value T
function list_remove_value(list, value)
    local length = #list

    for index = 1, length do
        if list[index] == value then
            if length > 1 then
                list[index] = list[length]
            end
            list[length] = nil
            return
        end
    end

    error("value not found")
end

--- Remove a known value from a list, then delete the list if it became empty.
---@generic T
---@param object {[string]: T[]}
---@param key string
---@param value T
function list_remove_value_or_destroy(object, key, value)
    local list = object[key]
    local length = #list

    for index = 1, length do
        if list[index] == value then
            if length > 1 then
                list[index] = list[length]
                list[length] = nil
            else
                object[key] = nil
            end
            return
        end
    end

    error("value not found")
end

--- Pop a random item or return nil if the list is empty.
---@generic T
---@param list T[]
---@return T?
function list_pop_random_if_any(list)
    local length = #list

    if length > 1 then
        local index = math.random(length)
        local result = list[index]
        list[index] = list[length]
        list[length] = nil
        return result
    end

    if length > 0 then
        local result = list[1]
        list[1] = nil
        return result
    end

    return nil
end

--- Pop a random item from a list, then delete the list if it became empty.
---@generic T
---@param object {[string]: T[]}
---@param key string
---@return T
function list_pop_random_or_destroy(object, key)
    local list = object[key]
    local length = #list

    if length > 1 then
        local index = math.random(length)
        local result = list[index]
        list[index] = list[length]
        list[length] = nil
        return result
    end

    if length > 0 then
        local result = list[1]
        object[key] = nil
        return result
    end

    error("empty list")
end

--------------------------------------------------------------------------------

---@generic A, B, C, D, E, F
---@param inner fun(a: A, b: B, c: C, d: D, e: E, f: F)
---@param a A
---@return fun(b: B, c: C, d: D, e: E, f: F)
function bind_1_of_6(inner, a)
    return function(b, c, d, e, f) inner(a, b, c, d, e, f) end
end

--------------------------------------------------------------------------------

---@param item_key string
---@return string name, string? quality
function split_item_key(item_key)
    local name, quality = string.match(item_key, "(.-):(.+)")
    if name then
        return name, quality
    end
    return item_key, nil
end

---@param network_item NetworkItem
---@param station_item ProvideItem|RequestItem
---@return integer
function compute_storage_needed(network_item, station_item)
    local delivery_size, delivery_time = network_item.delivery_size, network_item.delivery_time
    local throughput, latency = station_item.throughput, station_item.latency
    local round = 100.0 -- for fluids
    if network_item.quality then round = prototypes.item[network_item.name].stack_size end
    local result = math.max(delivery_size, throughput * delivery_time)
    local buffer = math.max(round, throughput * latency)
    result = math.ceil(result / round) * round
    buffer = math.ceil(buffer / round) * round
    if station_item.push or station_item.pull then buffer = buffer + buffer end
    return result + buffer
end

---@param network_item NetworkItem
---@param station_item ProvideItem|RequestItem
---@return integer
function compute_buffer(network_item, station_item)
    local throughput, latency = station_item.throughput, station_item.latency
    local round = 100.0 -- for fluids
    if network_item.quality then round = prototypes.item[network_item.name].stack_size end
    local buffer = math.max(round, throughput * latency)
    buffer = math.ceil(buffer / round) * round
    return buffer
end

---@param network_item NetworkItem
---@param provide_item ProvideItem
---@return integer
function compute_load_target(network_item, provide_item)
    local delivery_size, granularity = network_item.delivery_size, provide_item.granularity
    if network_item.quality then
        -- for items, granularity is exact, so round down to the nearest multiple of granularity
        return math.floor(delivery_size / granularity) * granularity
    end
    -- for fluids, loading exact amounts is not possible, so just subtract granularity
    return delivery_size - granularity
end

---@param provide_items {[ItemKey]: ProvideItem}?
---@param request_items {[ItemKey]: RequestItem}?
function compute_stop_name(provide_items, request_items)
    local provide_icons ---@type string[]?
    if provide_items and next(provide_items) then
        provide_icons = {}
        for item_key, item in pairs(provide_items) do
            local name, quality = split_item_key(item_key)
            if quality then
                provide_icons[item.list_index] = "[item=" .. name .. ",quality=" .. quality .. "]"
            else
                provide_icons[item.list_index] = "[fluid=" .. name .. "]"
            end
        end
        assert(#provide_icons == table_size(provide_items))
    end

    local request_icons ---@type string[]?
    if request_items and next(request_items) then
        request_icons = {}
        for item_key, item in pairs(request_items) do
            local name, quality = split_item_key(item_key)
            if quality then
                request_icons[item.list_index] = "[item=" .. name .. ",quality=" .. quality .. "]"
            else
                request_icons[item.list_index] = "[fluid=" .. name .. "]"
            end
        end
        assert(#request_icons == table_size(request_items))
    end

    if provide_icons and request_icons then
        return "[virtual-signal=up-arrow]" .. table.concat(provide_icons) .. " / " .. "[virtual-signal=down-arrow]" .. table.concat(request_icons)
    elseif provide_icons then
        return "[virtual-signal=up-arrow]" .. table.concat(provide_icons)
    elseif request_icons then
        return "[virtual-signal=down-arrow]" .. table.concat(request_icons)
    end

    return "[virtual-signal=signal-ghost]"
end

--------------------------------------------------------------------------------

---@param comb LuaEntity
---@param constant integer
---@param operation "-"|"+"
---@param input SignalID
---@param output SignalID?
function set_arithmetic_control_behavior(comb, constant, operation, input, output)
    local cb = comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    cb.parameters = { first_constant = constant, operation = operation, second_signal = input, output_signal = output or input }
end

---@param comb LuaEntity
function clear_arithmetic_control_behavior(comb)
    local cb = comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    cb.parameters = nil
end

---@param provide_io LuaEntity
---@return {[ItemKey]: ProvideItem}
function combinator_description_to_provide_items(provide_io)
    local json_string = provide_io.combinator_description
    if json_string == "" then return {} end

    local json = helpers.json_to_table(json_string) --[[@as table]]

    local items = {} ---@type {[ItemKey]: ProvideItem}
    local indices = {} ---@type {[integer]: true?}

    for item_key, json_item in pairs(json) do
        local name, quality = split_item_key(item_key)
        if quality then
            if not prototypes.item[name] then goto continue end
        else
            if not prototypes.fluid[name] then goto continue end
        end

        local list_index = json_item.list_index
        if type(list_index) ~= "number" then list_index = 0 end

        local push = json_item.push
        if type(push) ~= "boolean" then push = false end

        local throughput = json_item.throughput
        if type(throughput) ~= "number" then throughput = 0.0 end

        local latency = json_item.latency
        if type(latency) ~= "number" then latency = 30 end

        local granularity = json_item.granularity
        if type(granularity) ~= "number" then granularity = 1 end

        items[item_key] = { list_index = list_index, push = push, throughput = throughput, latency = latency, granularity = granularity }
        indices[list_index] = true

        ::continue::
    end

    local indices_length = #indices
    if table_size(items) ~= indices_length or table_size(indices) ~= indices_length then
        local index = 0
        for _, item in pairs(items) do
            index = index + 1
            item.list_index = index
        end
    end

    return items
end

---@param request_io LuaEntity
---@return {[ItemKey]: RequestItem}
function combinator_description_to_request_items(request_io)
    local json_string = request_io.combinator_description
    if json_string == "" then return {} end

    local json = helpers.json_to_table(json_string) --[[@as table]]

    local items = {} ---@type {[ItemKey]: RequestItem}
    local indices = {} ---@type {[integer]: true?}

    for item_key, json_item in pairs(json) do
        local name, quality = split_item_key(item_key)
        if quality then
            if not prototypes.item[name] then goto continue end
        else
            if not prototypes.fluid[name] then goto continue end
        end

        local list_index = json_item.list_index
        if type(list_index) ~= "number" then list_index = 0 end

        local pull = json_item.pull
        if type(pull) ~= "boolean" then pull = false end

        local throughput = json_item.throughput
        if type(throughput) ~= "number" then throughput = 0.0 end

        local latency = json_item.latency
        if type(latency) ~= "number" then latency = 30 end

        items[item_key] = { list_index = list_index, pull = pull, throughput = throughput, latency = latency }
        indices[list_index] = true

        ::continue::
    end

    local indices_length = #indices
    if table_size(items) ~= indices_length or table_size(indices) ~= indices_length then
        local index = 0
        for _, item in pairs(items) do
            index = index + 1
            item.list_index = index
        end
    end

    return items
end

--------------------------------------------------------------------------------

---@param hauler Hauler
---@param message LocalisedString
---@param item ItemKey?
---@param stop LuaEntity?
function set_hauler_status(hauler, message, item, stop)
    hauler.status = message
    hauler.status_item = item
    hauler.status_stop = stop
    for _, player_state in pairs(storage.player_states) do
        local train = player_state.train
        if train and train.id == hauler.train.id then
            gui.hauler_status_changed(player_state)
        end
    end
end

---@param train LuaTrain
---@param message LocalisedString
function send_alert_for_train(train, message)
    local entity = assert(train.front_stock or train.back_stock)

    local icon = { name = "locomotive", type = "item" }
    local sound = { path = "utility/console_message" }

    for _, player in pairs(entity.force.players) do
        player.add_custom_alert(entity, icon, message, true)
        player.play_sound(sound)
    end
end

---@param hauler_ids HaulerId[]?
---@param message LocalisedString
---@param item ItemKey?
---@param stop LuaEntity?
function set_haulers_to_manual(hauler_ids, message, item, stop)
    if hauler_ids then
        for i = #hauler_ids, 1, -1 do
            local hauler = storage.haulers[hauler_ids[i]]
            set_hauler_status(hauler, message, item, stop)
            send_alert_for_train(hauler.train, message)
            hauler.train.manual_mode = true
        end
    end
end

---@param hauler Hauler
---@param station Station
function send_hauler_to_station(hauler, station)
    local train = hauler.train
    local stop = station.stop

    stop.trains_limit = nil
    train.schedule = { current = 1, records = { { station = stop.backer_name } } }
    train.recalculate_path()
    stop.trains_limit = 0

    local state = train.state
    if state == defines.train_state.no_path then
        set_hauler_status(hauler, { "sspp-alert.no-path-to-station" }, hauler.status_item, stop)
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
    end
end

---@param hauler Hauler
---@param stop_name string
function send_hauler_to_named_stop(hauler, stop_name)
    local train = hauler.train

    train.schedule = { current = 1, records = { { station = stop_name } } }
    train.recalculate_path()

    local state = train.state
    if state == defines.train_state.no_path or state == defines.train_state.destination_full then
        set_hauler_status(hauler, { "sspp-alert.no-path-to-named-stop", stop_name }, hauler.status_item)
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
    end
end

---@param hauler Hauler
---@param class Class
---@return boolean
function check_if_hauler_needs_fuel(hauler, class)
    assert(class)
    local maximum_delivery_time = 120.0 -- TODO: calculate properly
    local energy_per_second = 5000000.0 / 3.0 -- TODO: calculate properly

    -- TODO: could be less, this assumes constant burning
    local energy_threshold = energy_per_second * maximum_delivery_time

    local loco_dict = hauler.train.locomotives ---@type {string: LuaEntity[]}
    for _, loco_list in pairs(loco_dict) do
        for _, loco in pairs(loco_list) do
            local burner = assert(loco.burner, "TODO: electric trains")
            local energy = burner.remaining_burning_fuel
            for _, item_with_count in pairs(burner.inventory.get_contents()) do
                energy = energy + prototypes.item[item_with_count.name].fuel_value * item_with_count.count
            end
            if energy < energy_threshold then
                return true
            end
        end
    end

    return false
end

--------------------------------------------------------------------------------

---@param entity LuaEntity
---@return StationParts?
function get_station_parts(entity)
    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    local stop ---@type LuaEntity
    if name == "sspp-stop" then
        stop = entity
    else
        local stop_ids = storage.comb_stop_ids[entity.unit_number]
        if #stop_ids ~= 1 then return nil end
        stop = storage.entities[stop_ids[1]]
    end

    local comb_ids = storage.stop_comb_ids[stop.unit_number]

    local combs_by_name = {} ---@type {[string]: LuaEntity?}

    for _, comb_id in pairs(comb_ids) do
        if #storage.comb_stop_ids[comb_id] ~= 1 then return nil end

        local comb = storage.entities[comb_id]
        name = comb.name
        if name == "entity-ghost" then name = comb.ghost_name end
        if combs_by_name[name] then return nil end

        combs_by_name[name] = comb
    end

    local general_io = combs_by_name["sspp-general-io"]
    if not general_io then return nil end

    local provide_io = combs_by_name["sspp-provide-io"]
    local request_io = combs_by_name["sspp-request-io"]
    if not (provide_io or request_io) then return nil end

    local ids = {}

    ids[stop.unit_number] = true
    ids[general_io.unit_number] = true
    if provide_io then ids[provide_io.unit_number] = true end
    if request_io then ids[request_io.unit_number] = true end

    return { ids = ids, stop = stop, general_io = general_io, provide_io = provide_io, request_io = request_io }
end

---@param comb LuaEntity
---@param hidden_comb LuaEntity
---@param wire defines.wire_connector_id
local function connect_hidden_comb_wire(comb, hidden_comb, wire)
    local connector = comb.get_wire_connector(wire, true)
    local hidden_connector = hidden_comb.get_wire_connector(wire, true)
    connector.connect_to(hidden_connector, false, defines.wire_origin.script)
end

---@param comb LuaEntity
---@param hidden_combs LuaEntity[]
---@param items {[ItemKey]: ProvideItem|RequestItem}
function ensure_hidden_combs(comb, hidden_combs, items)
    local old_spoil_depth = #hidden_combs
    local new_spoil_depth = 0
    for item_key, _ in pairs(items) do
        local name, quality = split_item_key(item_key)
        if quality then
            local spoil_depth = 0
            for i, _ in enumerate_spoil_results(prototypes.item[name]) do
                spoil_depth = i
            end
            if spoil_depth > new_spoil_depth then
                new_spoil_depth = spoil_depth
            end
        end
    end
    if old_spoil_depth < new_spoil_depth then
        for i = old_spoil_depth + 1, new_spoil_depth do
            local hidden_comb = assert(comb.surface.create_entity({ name = "sspp-hidden-io", position = comb.position, force = comb.force }))
            connect_hidden_comb_wire(comb, hidden_comb, defines.wire_connector_id.combinator_input_red)
            connect_hidden_comb_wire(comb, hidden_comb, defines.wire_connector_id.combinator_input_green)
            connect_hidden_comb_wire(comb, hidden_comb, defines.wire_connector_id.combinator_output_red)
            connect_hidden_comb_wire(comb, hidden_comb, defines.wire_connector_id.combinator_output_green)
            hidden_combs[i] = hidden_comb
        end
    elseif old_spoil_depth > new_spoil_depth then
        for i = old_spoil_depth, new_spoil_depth + 1, -1 do
            hidden_combs[i].destroy({})
            hidden_combs[i] = nil
        end
    end
end

---@param hidden_combs LuaEntity[]?
function destroy_hidden_combs(hidden_combs)
    if hidden_combs then
        for _, hidden_comb in pairs(hidden_combs) do
            hidden_comb.destroy({})
        end
    end
end

---@param hidden_combs LuaEntity[]?
function clear_hidden_comb_control_behaviors(hidden_combs)
    if hidden_combs then
        for _, hidden_comb in pairs(hidden_combs) do
            local cb = hidden_comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
            cb.parameters = nil
        end
    end
end

--------------------------------------------------------------------------------

---@param proto LuaItemPrototype
function enumerate_spoil_results(proto)
    local i = 0
    return function()
        proto = proto.spoil_result
        if proto then
            i = i + 1
            return i, proto
        end
        return nil, nil
    end
end
