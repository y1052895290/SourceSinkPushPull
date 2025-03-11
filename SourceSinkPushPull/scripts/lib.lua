-- SSPP by jagoly

--------------------------------------------------------------------------------

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

--- Remove a value from a list if it exists.
---@generic T
---@param list T[]
---@param value T
function list_remove_value_if_exists(list, value)
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
end

--- Remove all instances of a value from a list.
---@generic T
---@param list T[]
---@param value T
function list_remove_value_all(list, value)
    local index, length = 1, #list

    while index <= length do
        if list[index] == value then
            list[index] = list[length]
            list[length] = nil
            length = length - 1
        else
            index = index + 1
        end
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

---@param item_key ItemKey
---@return boolean
function is_item_key_invalid(item_key)
    local name, quality = split_item_key(item_key)
    if quality then
        return not (prototypes.item[name] and prototypes.quality[quality])
    end
    return not prototypes.fluid[name]
end

---@param name string
---@param quality string?
function make_item_icon(name, quality)
    if quality then
        return "[item=" .. name .. ",quality=" .. quality .. "]"
    end
    return "[fluid=" .. name .. "]"
end

---@param train LuaTrain
---@param name string
---@param quality string?
---@return integer
function get_train_item_count(train, name, quality)
    if quality then
        return train.get_item_count({ name = name, quality = quality })
    end
    return math.ceil(train.get_fluid_count(name))
end

--------------------------------------------------------------------------------

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
    -- double the buffer if using any push or pull mode (dynamic counts as push or pull here)
    if station_item.mode > 3 then buffer = buffer + buffer end
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
    local provide_icons, p_len = {}, 0 ---@type string[], integer
    local request_icons, r_len = {}, 0 ---@type string[], integer

    if provide_items then
        for item_key, _ in pairs(provide_items) do
            local name, quality = split_item_key(item_key)
            p_len = p_len + 1
            provide_icons[p_len] = make_item_icon(name, quality)
        end
    end

    if request_items then
        for item_key, _ in pairs(request_items) do
            local name, quality = split_item_key(item_key)
            r_len = r_len + 1
            request_icons[r_len] = make_item_icon(name, quality)
        end
    end

    if p_len > 0 and r_len > 0 then
        local provide_string, request_string, total_length = "", "", 0
        local max_length = 199 - #"[color=green]⬆…[/color] [color=red]⬇…[/color]"
        local p, r = 0, 0
        repeat
            if p < p_len then
                p = p + 1
                local icon = provide_icons[p]
                total_length = total_length + #icon
                if total_length > max_length then
                    p, icon = p_len, "…"
                end
                provide_string = provide_string .. icon
            end
            if r < r_len then
                r = r + 1
                local icon = request_icons[r]
                total_length = total_length + #icon
                if total_length > max_length then
                    r, icon = r_len, "…"
                end
                request_string = request_string .. icon
            end
        until p == p_len and r == r_len
        return "[color=green]⬆" .. provide_string .. "[/color] [color=red]⬇" .. request_string .. "[/color]"
    elseif p_len > 0 then
        local max_length = 199 - #"[color=green]⬆…[/color]"
        local provide_string, length = "", 0
        for _, icon in pairs(provide_icons) do
            length = length + #icon
            if length > max_length then
                provide_string = provide_string .. "…"
                break
            end
            provide_string = provide_string .. icon
        end
        return "[color=green]⬆" .. provide_string .. "[/color]"
    elseif r_len > 0 then
        local max_length = 199 - #"[color=red]⬇…[/color]"
        local request_string, length = "", 0
        for _, icon in pairs(request_icons) do
            length = length + #icon
            if length > max_length then
                request_string = request_string .. "…"
                break
            end
            request_string = request_string .. icon
        end
        return "[color=red]⬇" .. request_string .. "[/color]"
    end

    return "[virtual-signal=signal-ghost]"
end

--------------------------------------------------------------------------------

---@param stop LuaEntity
---@param flag StopFlag
---@return boolean value
function read_stop_flag(stop, flag)
    local cb = stop.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local condition = cb.logistic_condition --[[@as CircuitCondition]]
    return bit32.btest(condition.constant or 0, flag)
end

---@param stop LuaEntity
---@param flag StopFlag
---@param value boolean
function write_stop_flag(stop, flag, value)
    local cb = stop.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local condition = cb.logistic_condition --[[@as CircuitCondition]]
    if value then
        condition.constant = bit32.bor(condition.constant or 0, flag)
    else
        condition.constant = bit32.band(condition.constant or 0, bit32.bnot(flag))
    end
    cb.logistic_condition = condition --[[@as CircuitConditionDefinition]]
end

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

--------------------------------------------------------------------------------

---@param provide_io LuaEntity
---@return {[ItemKey]: ProvideItem}
function combinator_description_to_provide_items(provide_io)
    local description = provide_io.combinator_description

    local version, lines = string.match(description, "P([%d]+)(.*)")
    local items = {} ---@type {[ItemKey]: ProvideItem}

    if version == "1" then
        for item_key, mode, throughput, latency, granularity in string.gmatch(lines, "\n(%g+) ([1234567]) ([%d%.]+) ([%d%.]+) (%d+)") do
            if not is_item_key_invalid(item_key) then
                mode, throughput, latency, granularity = tonumber(mode), tonumber(throughput), tonumber(latency), tonumber(granularity)
                if mode and throughput and latency and granularity then
                    items[item_key] = { mode = mode, throughput = throughput, latency = latency, granularity = granularity }
                end
            end
        end
        return items
    end

    local json = helpers.json_to_table(description) --[[@as table?]]
    if json then
        for item_key, json_item in pairs(json) do
            if is_item_key_invalid(item_key) then goto continue end

            local mode = json_item[1]
            if type(mode) ~= "number" then
                -- changed from boolean to integer in 0.3.12
                mode = (mode == true) and 5 or 2
            end

            local throughput = json_item[2]
            if type(throughput) ~= "number" then throughput = 0.0 end

            local latency = json_item[3]
            if type(latency) ~= "number" then latency = 30.0 end

            local granularity = json_item[4]
            if type(granularity) ~= "number" then granularity = 1 end

            items[item_key] = { mode = mode, throughput = throughput, latency = latency, granularity = granularity }

            ::continue::
        end
    end

    return items
end

---@param provide_items {[ItemKey]: ProvideItem}
---@return string
function provide_items_to_combinator_description(provide_items)
    local result = "P1"
    for item_key, item in pairs(provide_items) do
        result = result .. string.format(
            "\n%s %u %s %s %u",
            item_key, item.mode, tostring(item.throughput), tostring(item.latency), item.granularity
        )
    end
    return result
end

---@param request_io LuaEntity
---@return {[ItemKey]: RequestItem}
function combinator_description_to_request_items(request_io)
    local description = request_io.combinator_description

    local version, lines = string.match(description, "R([%d]+)(.*)")
    local items = {} ---@type {[ItemKey]: RequestItem}

    if version == "1" then
        for item_key, mode, throughput, latency in string.gmatch(lines, "\n(%g+) ([1234567]) ([%d%.]+) ([%d%.]+)") do
            if not is_item_key_invalid(item_key) then
                mode, throughput, latency = tonumber(mode), tonumber(throughput), tonumber(latency)
                if mode and throughput and latency then
                    items[item_key] = { mode = mode, throughput = throughput, latency = latency }
                end
            end
        end
        return items
    end

    local json = helpers.json_to_table(description) --[[@as table?]]
    if json then
        for item_key, json_item in pairs(json) do
            if is_item_key_invalid(item_key) then goto continue end

            local mode = json_item[1]
            if type(mode) ~= "number" then
                -- changed from boolean to integer in 0.3.12
                mode = (mode == true) and 5 or 2
            end

            local throughput = json_item[2]
            if type(throughput) ~= "number" then throughput = 0.0 end

            local latency = json_item[3]
            if type(latency) ~= "number" then latency = 30.0 end

            items[item_key] = { mode = mode, throughput = throughput, latency = latency }

            ::continue::
        end
    end

    return items
end

---@param request_items {[ItemKey]: RequestItem}
---@return string
function request_items_to_combinator_description(request_items)
    local result = "R1"
    for item_key, item in pairs(request_items) do
        result = result .. string.format(
            "\n%s %u %s %s",
            item_key, item.mode, tostring(item.throughput), tostring(item.latency)
        )
    end
    return result
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
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.train_id then
            ---@cast player_gui PlayerHaulerGui
            if player_gui.train_id == hauler.train.id then
                gui.hauler_status_changed(player_gui)
            end
        end
    end
end

---@param hauler Hauler
---@param color_id TrainColor
function set_hauler_color(hauler, color_id)
    if mod_settings.auto_paint_trains then
        for _, locos in pairs(hauler.train.locomotives) do
            for _, loco in pairs(locos) do
                loco.copy_color_from_train_stop = false
                loco.color = mod_settings.train_colors[color_id]
            end
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
---@param stop LuaEntity
function send_hauler_to_station(hauler, stop)
    hauler.train.schedule = { current = 1, records = {
        { rail = stop.connected_rail, rail_direction = stop.connected_rail_direction },
        { station = stop.backer_name },
    } }
end

---@param hauler Hauler
---@param stop_name string
function send_hauler_to_named_stop(hauler, stop_name)
    hauler.train.schedule = { current = 1, records = {
        { station = stop_name },
    } }
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

---@param hauler Hauler
---@param hauler_to_station HaulerToStation
---@return boolean
function check_if_hauler_loaded_wrong_cargo(hauler, hauler_to_station)
    local train = hauler.train

    for _, item in pairs(train.get_contents()) do
        if item.name .. ":" .. (item.quality or "normal") ~= hauler_to_station.item then return true end
    end

    for fluid, _ in pairs(train.get_fluid_contents()) do
        if fluid ~= hauler_to_station.item then return true end
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
