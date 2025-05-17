-- SSPP by jagoly

local flib_dictionary = require("__flib__.dictionary")

local enums = require("__SourceSinkPushPull__.scripts.enums")

local e_stop_flags = enums.stop_flags

local m_max, m_ceil, m_floor = math.max, math.ceil, math.floor
local b_test = bit32.btest
local s_match, s_gmatch, s_format = string.match, string.gmatch, string.format

---@class sspp.lib
local lib = {}

--------------------------------------------------------------------------------

--- Get the length of a list, or zero if the argument is nil.
---@generic T
---@param list T[]?
function lib.len_or_zero(list)
    if list then
        return #list
    end
    return 0
end

--- Create a list if needed, then append a value.
---@generic T
---@param object {[string]: T[]}
---@param list_name string
---@param value T
function lib.list_create_or_append(object, list_name, value)
    local list = object[list_name]
    if not list then
        object[list_name] = { value }
    else
        list[#list+1] = value
    end
end

--- Create a list if needed, then append one or more copies of a value.
---@generic T
---@param object {[string]: T[]}
---@param list_name string
---@param value T
---@param copies integer
function lib.list_create_or_extend(object, list_name, value, copies)
    local list = object[list_name]
    if not list then
        list = {}
        object[list_name] = list
    end
    local length = #list
    for i = length + 1, length + copies do
        list[i] = value
    end
end

--- Remove a known value from a list, then delete the list if it became empty.
---@generic T
---@param object {[string]: T[]}
---@param list_name string
---@param value T
function lib.list_destroy_or_remove(object, list_name, value)
    local list = object[list_name]
    local length = #list

    for index = 1, length do
        if list[index] == value then
            if length > 1 then
                list[index] = list[length]
                list[length] = nil
            else
                object[list_name] = nil
            end
            return
        end
    end

    error("value not found")
end

--- Remove a known value from a list.
---@generic T
---@param list T[]
---@param value T
function lib.list_remove(list, value)
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

--- Remove a value from a list if it exists.
---@generic T
---@param list T[]
---@param value T
function lib.list_remove_if_exists(list, value)
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
function lib.list_remove_all(list, value)
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

--------------------------------------------------------------------------------

---@param item_key string
---@return string name, string? quality
local function split_item_key(item_key)
    local name, quality = s_match(item_key, "(.-):(.+)")
    if name then
        return name, quality
    end
    return item_key, nil
end
lib.split_item_key = split_item_key

---@param item_key ItemKey
---@return boolean
local function is_item_key_invalid(item_key)
    local name, quality = split_item_key(item_key)
    if quality then
        return not (prototypes.item[name] and prototypes.quality[quality])
    end
    return not prototypes.fluid[name]
end
lib.is_item_key_invalid = is_item_key_invalid

---@param name string
---@param quality string?
---@return string
local function make_item_icon(name, quality)
    if quality then
        if quality == "normal" then
            return "[item=" .. name .. "]"
        end
        return "[item=" .. name .. ",quality=" .. quality .. "]"
    end
    return "[fluid=" .. name .. "]"
end
lib.make_item_icon = make_item_icon

local spoil_results_cache = {} ---@type {[string]: string[]}

---@param item_name string
local function enumerate_spoil_results(item_name)
    local spoil_results = spoil_results_cache[item_name]
    if not spoil_results then
        spoil_results = {}
        local proto = prototypes.item[item_name]
        repeat
            proto = proto.spoil_result
            if not proto then break end
            spoil_results[#spoil_results+1] = proto.name
        until false
        spoil_results_cache[item_name] = spoil_results
    end
    return pairs(spoil_results)
end
lib.enumerate_spoil_results = enumerate_spoil_results

--------------------------------------------------------------------------------

---@param network_item NetworkItem
---@param station_item StationItem
---@return integer
function lib.compute_storage_needed(network_item, station_item)
    local delivery_size, delivery_time = network_item.delivery_size, network_item.delivery_time
    local throughput, latency = station_item.throughput, station_item.latency
    local round = 100.0 -- for fluids
    if network_item.quality then round = prototypes.item[network_item.name].stack_size end
    local result = m_max(delivery_size, throughput * delivery_time)
    local buffer = m_max(round, throughput * latency)
    result = m_ceil(result / round) * round
    buffer = m_ceil(buffer / round) * round
    -- double the buffer if using any push or pull mode (dynamic counts as push or pull here)
    if station_item.mode > 3 then buffer = buffer + buffer end
    return result + buffer
end

---@param network_item NetworkItem
---@param station_item StationItem
---@return integer
function lib.compute_buffer(network_item, station_item)
    local throughput, latency = station_item.throughput, station_item.latency
    local round = 100.0 -- for fluids
    if network_item.quality then round = prototypes.item[network_item.name].stack_size end
    local buffer = m_max(round, throughput * latency)
    buffer = m_ceil(buffer / round) * round
    return buffer
end

--------------------------------------------------------------------------------

--- The entity passed to this function can be invalid.
---@param stop LuaEntity?
---@return string
function lib.get_stop_name(stop)
    if stop and stop.valid then
        return stop.backer_name --[[@as string]]
    end
    return "[virtual-signal=signal-ghost]"
end

---@param provide_items {[ItemKey]: ProvideItem}?
---@param request_items {[ItemKey]: RequestItem}?
---@return string
function lib.generate_stop_name(provide_items, request_items)
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

---@param comb LuaEntity
---@param constant integer
---@param operation "-"|"+"
---@param input SignalID
---@param output SignalID?
function lib.set_control_behavior(comb, constant, operation, input, output)
    local cb = comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    cb.parameters = { first_constant = constant, operation = operation, second_signal = input, output_signal = output or input }
end

---@param comb LuaEntity
function lib.clear_control_behavior(comb)
    local cb = comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
    cb.parameters = nil
end

---@param hidden_combs LuaEntity[]
function lib.clear_hidden_control_behaviors(hidden_combs)
    for _, hidden_comb in pairs(hidden_combs) do
        local cb = hidden_comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
        cb.parameters = nil
    end
end

--------------------------------------------------------------------------------

---@param entity LuaEntity
---@return GhostStationStop
function lib.read_station_stop_settings(entity)
    local cb = entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    local constant = cb.logistic_condition.constant or 0

    ---@type GhostStationStop
    return {
        entity = entity,
        custom_name = b_test(constant, e_stop_flags.custom_name),
        disabled = b_test(constant, e_stop_flags.disabled),
        bufferless = b_test(constant, e_stop_flags.bufferless),
        inactivity = b_test(constant, e_stop_flags.inactivity),
    }
end

---@param comb LuaEntity
---@return GhostStationGeneral
function lib.read_station_general_settings(comb)
    local description = comb.combinator_description

    local version, lines = s_match(description, "G([%d]+)(.*)")
    local custom_network_name = nil

    if version == "1" then
        local network_name = s_match(lines, "\n([^\n]*)")

        local network = storage.networks[network_name]
        if network and not network.surface then custom_network_name = network_name end
    end

    ---@type GhostStationGeneral
    return {
        comb = comb,
        network = custom_network_name or comb.surface.name, -- may be an unsupported surface
    }
end

---@param comb LuaEntity
---@return GhostStationProvide
function lib.read_station_provide_settings(comb)
    local description = comb.combinator_description

    local version, lines = s_match(description, "P([%d]+)(.*)")
    local items = {} ---@type {[ItemKey]: ProvideItem}

    if version == "1" then
        for item_key, mode, throughput, latency, granularity in s_gmatch(lines, "\n(%g+) ([1234567]) ([%d%.]+) ([%d%.]+) (%d+)") do
            if not is_item_key_invalid(item_key) then
                mode, throughput, latency, granularity = tonumber(mode), tonumber(throughput), tonumber(latency), tonumber(granularity)
                if mode and throughput and latency and granularity then
                    items[item_key] = { mode = mode, throughput = throughput, latency = latency, granularity = granularity }
                end
            end
        end
    end

    ---@type GhostStationProvide
    return { comb = comb, items = items }
end

---@param comb LuaEntity
---@return GhostStationRequest
function lib.read_station_request_settings(comb)
    local description = comb.combinator_description

    local version, lines = s_match(description, "R([%d]+)(.*)")
    local items = {} ---@type {[ItemKey]: RequestItem}

    if version == "1" then
        for item_key, mode, throughput, latency in s_gmatch(lines, "\n(%g+) ([1234567]) ([%d%.]+) ([%d%.]+)") do
            if not is_item_key_invalid(item_key) then
                mode, throughput, latency = tonumber(mode), tonumber(throughput), tonumber(latency)
                if mode and throughput and latency then
                    items[item_key] = { mode = mode, throughput = throughput, latency = latency }
                end
            end
        end
    end

    ---@type GhostStationRequest
    return { comb = comb, items = items }
end

--------------------------------------------------------------------------------

---@param stop GhostStationStop
function lib.write_station_stop_settings(stop)
    local constant = 0
    if stop.custom_name then constant = constant + e_stop_flags.custom_name end
    if stop.disabled then constant = constant + e_stop_flags.disabled end
    if stop.bufferless then constant = constant + e_stop_flags.bufferless end
    if stop.inactivity then constant = constant + e_stop_flags.inactivity end
    local cb = stop.entity.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    cb.logistic_condition = { constant = constant } ---@diagnostic disable-line: missing-fields
end

---@param general GhostStationGeneral
function lib.write_station_general_settings(general)
    general.comb.combinator_description = s_format("G1\n%s", general.network)
end

---@param provide GhostStationProvide
function lib.write_station_provide_settings(provide)
    local description = "P1"
    for item_key, item in pairs(provide.items) do
        description = description .. s_format(
            "\n%s %u %s %s %u",
            item_key, item.mode, tostring(item.throughput), tostring(item.latency), item.granularity
        )
    end
    provide.comb.combinator_description = description
end

---@param request GhostStationRequest
function lib.write_station_request_settings(request)
    local description = "R1"
    for item_key, item in pairs(request.items) do
        description = description .. s_format(
            "\n%s %u %s %s",
            item_key, item.mode, tostring(item.throughput), tostring(item.latency)
        )
    end
    request.comb.combinator_description = description
end

--------------------------------------------------------------------------------

---@param train LuaTrain
---@param name string
---@param quality string?
---@return integer
function lib.get_train_item_count(train, name, quality)
    if quality then
        return train.get_item_count({ name = name, quality = quality })
    end
    return m_ceil(train.get_fluid_count(name))
end

---@param train LuaTrain
---@param color_id TrainColor
local function set_train_color(train, color_id)
    if mod_settings.auto_paint_trains then
        local color = mod_settings.train_colors[color_id]
        for _, carriage in pairs(train.carriages) do
            if carriage.type == "locomotive" then
                carriage.copy_color_from_train_stop = false
                carriage.color = color
            end
        end
    end
end

---@param train LuaTrain
---@param color_id TrainColor
---@param stop LuaEntity
function lib.send_train_to_station(train, color_id, stop)
    set_train_color(train, color_id)
    train.schedule = { current = 1, records = { { rail = stop.connected_rail, rail_direction = stop.connected_rail_direction }, { station = stop.backer_name } } }
end

---@param train LuaTrain
---@param color_id TrainColor
---@param stop_name string
function lib.send_train_to_named_stop(train, color_id, stop_name)
    set_train_color(train, color_id)
    train.schedule = { current = 1, records = { { station = stop_name } } }
end

---@param train LuaTrain
---@param message LocalisedString
function lib.show_train_alert(train, message)
    local entity = assert(train.front_stock or train.back_stock)

    local icon = { name = "locomotive", type = "item" }
    local sound = { path = "utility/console_message" }

    for _, player in pairs(entity.force.players) do
        player.add_custom_alert(entity, icon, message, true)
        player.play_sound(sound)
    end
end

---@param network Network
---@param hauler Hauler
---@param job NetworkJob
function lib.assign_job_index(network, hauler, job)
    local job_index = network.job_index_counter + 1

    network.job_index_counter = job_index
    hauler.job = job_index

    network.jobs[job_index] = job
end

---@param hauler_ids HaulerId[]?
---@param message LocalisedString
---@param item ItemKey?
---@param stop LuaEntity?
function lib.set_haulers_to_manual(hauler_ids, message, item, stop)
    if hauler_ids then
        for i = #hauler_ids, 1, -1 do
            local hauler = storage.haulers[hauler_ids[i]]
            local train = hauler.train
            hauler.status = { message = message, item = item, stop = stop }
            lib.show_train_alert(train, message)
            train.manual_mode = true
        end
    end
end

--------------------------------------------------------------------------------

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
---@param items {[ItemKey]: StationItem}
function lib.ensure_hidden_combs(comb, hidden_combs, items)
    local old_spoil_depth = #hidden_combs
    local new_spoil_depth = 0
    for item_key, _ in pairs(items) do
        local name, quality = split_item_key(item_key)
        if quality then
            for i, _ in enumerate_spoil_results(name) do
                if i > new_spoil_depth then new_spoil_depth = i end
            end
        end
    end
    if old_spoil_depth < new_spoil_depth then
        for i = old_spoil_depth + 1, new_spoil_depth do
            local hidden_comb = comb.surface.create_entity({ name = "sspp-hidden-io", position = comb.position, force = comb.force }) --[[@as LuaEntity]]
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
function lib.destroy_hidden_combs(hidden_combs)
    if hidden_combs then
        for _, hidden_comb in pairs(hidden_combs) do
            hidden_comb.destroy({})
        end
    end
end

--------------------------------------------------------------------------------

---@param surface LuaSurface
---@return NetworkName?
function lib.get_network_name_for_surface(surface)
    local name = surface.name
    if surface.planet then return name end
    if name == "__sspp_test" then return name end
    -- TODO: mod surfaces which lack associated planets will have to be allowed individually
    return nil
end

--------------------------------------------------------------------------------

---@param path LuaRailPath?
---@return LocalisedString
function lib.format_distance(path)
    if path then
        return { "sspp-gui.fmt-metres", m_floor(path.total_distance - path.travelled_distance + 0.5) }
    end
    return { "sspp-gui.no-path" }
end

---@param start_tick MapTick
---@param finish_tick_or_in_progress (MapTick|true)?
---@return LocalisedString
function lib.format_duration(start_tick, finish_tick_or_in_progress)
    if finish_tick_or_in_progress then
        if finish_tick_or_in_progress ~= true then
            return { "sspp-gui.fmt-seconds", m_floor((finish_tick_or_in_progress - start_tick) / 60.0 + 0.5) }
        end
        return { "sspp-gui.active" }
    end
    return { "sspp-gui.aborted" }
end

---@param tick MapTick
---@return LocalisedString
function lib.format_time(tick)
    local total_seconds = m_floor(tick / 60)
    local seconds = total_seconds % 60
    local minutes = m_floor(total_seconds / 60) % 60
    local hours = m_floor(total_seconds / 3600)
    return s_format("%02d:%02d:%02d", hours, minutes, seconds)
end

--------------------------------------------------------------------------------

function lib.refresh_dictionaries()
    flib_dictionary.on_init()

    local item_dict = {}
    for name, proto in pairs(prototypes.item) do
        item_dict[name] = { "?", proto.localised_name, "item/" .. name }
    end
    flib_dictionary.new("item", item_dict)

    local fluid_dict = {}
    for name, proto in pairs(prototypes.fluid) do
        fluid_dict[name] = { "?", proto.localised_name, "fluid/" .. name }
    end
    flib_dictionary.new("fluid", fluid_dict)

    local misc_dict = {}
    misc_dict["fuel"] = { "sspp-query.fuel" }
    misc_dict["item"] = { "sspp-query.item" }
    misc_dict["fluid"] = { "sspp-query.fluid" }
    flib_dictionary.new("misc", misc_dict)
end

--------------------------------------------------------------------------------

return lib
