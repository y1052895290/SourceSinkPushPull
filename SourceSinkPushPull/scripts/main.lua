-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param stop LuaEntity
---@return uint[], LuaEntity[]
local function find_nearby_combs(stop)
    local entities, x, y = storage.entities, stop.position.x, stop.position.y
    local i, comb_ids, combs = 0, {}, {}
    for _, entity in pairs(stop.surface.find_entities({ { x - 2.6, y - 2.6 }, { x + 2.6, y + 2.6 } })) do
        local unit_number = entity.unit_number
        if entities[unit_number] then
            local name = entity.name
            if name == "entity-ghost" then name = entity.ghost_name end
            if name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
                i = i + 1
                comb_ids[i], combs[i] = unit_number, entity
            end
        end
    end
    return comb_ids, combs
end

---@param comb LuaEntity
---@return uint[], LuaEntity[]
local function find_nearby_stops(comb)
    local entities, x, y = storage.entities, comb.position.x, comb.position.y
    local i, stop_ids, stops = 0, {}, {}
    for _, entity in pairs(comb.surface.find_entities({ { x - 2.1, y - 2.1 }, { x + 2.1, y + 2.1 } })) do
        local unit_number = entity.unit_number
        if entities[unit_number] then
            local name = entity.name
            if name == "entity-ghost" then name = entity.ghost_name end
            if name == "sspp-stop" then
                i = i + 1
                stop_ids[i], stops[i] = unit_number, entity
            end
        end
    end
    return stop_ids, stops
end

--------------------------------------------------------------------------------

---@param entity_id uint
local function try_close_entity_guis(entity_id)
    for player_id, player_state in pairs(storage.player_states) do
        local parts = player_state.parts
        if parts and parts.ids[entity_id] then
            gui.station_closed(player_id, player_state.elements["sspp-station"])
        end
    end
end

---@param stop LuaEntity
---@param combs LuaEntity[]
local function try_create_station(stop, combs)
    if stop.name == "entity-ghost" then return end

    local station_id = stop.unit_number ---@type StationId
    assert(storage.stations[station_id] == nil)

    local combs_by_name = {} ---@type {[string]: LuaEntity?}

    for _, comb in pairs(combs) do
        if #storage.comb_stop_ids[comb.unit_number] ~= 1 then return end

        local name = comb.name
        if name == "entity-ghost" or combs_by_name[name] then return end

        combs_by_name[name] = comb
    end

    local general_io = combs_by_name["sspp-general-io"]
    if not general_io then return end

    local provide_io = combs_by_name["sspp-provide-io"]
    local request_io = combs_by_name["sspp-request-io"]
    if not (provide_io or request_io) then return end

    local station = { stop = stop, general_io = general_io, total_deliveries = 0 } ---@type Station

    if provide_io then
        local stop_connector = stop.get_wire_connector(defines.wire_connector_id.circuit_red, true)
        local io_connector = provide_io.get_wire_connector(defines.wire_connector_id.combinator_input_red, true)
        stop_connector.connect_to(io_connector, true)

        station.provide_io = provide_io
        station.provide_items = combinator_description_to_provide_items(provide_io)
        station.provide_deliveries = {}
        station.provide_hidden_combs = {}

        ensure_hidden_combs(station.provide_io, station.provide_hidden_combs, station.provide_items)
    end

    if request_io then
        local stop_connector = stop.get_wire_connector(defines.wire_connector_id.circuit_green, true)
        local io_connector = request_io.get_wire_connector(defines.wire_connector_id.combinator_input_green, true)
        stop_connector.connect_to(io_connector, true)

        station.request_io = request_io
        station.request_items = combinator_description_to_request_items(request_io)
        station.request_deliveries = {}
        station.request_hidden_combs = {}

        ensure_hidden_combs(station.request_io, station.request_hidden_combs, station.request_items)
    end

    stop.backer_name = compute_stop_name(station.provide_items, station.request_items)

    storage.stations[station_id] = station
end

---@param stop LuaEntity
local function try_destroy_station(stop)
    if stop.name == "entity-ghost" then return end

    local station_id = stop.unit_number ---@type StationId
    local station = storage.stations[station_id]
    if station then
        set_haulers_to_manual(station.provide_deliveries, { "sspp-alert.station-broken" })
        set_haulers_to_manual(station.request_deliveries, { "sspp-alert.station-broken" })

        destroy_hidden_combs(station.provide_hidden_combs)
        destroy_hidden_combs(station.request_hidden_combs)

        storage.stations[station_id] = nil
    end

    stop.backer_name = "[virtual-signal=signal-ghost]"
end

--------------------------------------------------------------------------------

---@param hauler_id HaulerId
local function on_hauler_disabled_or_destroyed(hauler_id)
    local hauler = assert(storage.haulers[hauler_id])
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
        list_remove_value_or_destroy(network.depot_haulers, hauler.class, hauler_id)
    end

    if hauler.to_liquidate then
        storage.disabled_items[hauler.network .. ":" .. hauler.to_liquidate] = true
        list_remove_value_or_destroy(network.liquidate_haulers, hauler.to_liquidate, hauler_id)
    end
end

--------------------------------------------------------------------------------

---@param stop LuaEntity
---@param ghost_unit_number uint?
function on_stop_built(stop, ghost_unit_number)
    if ghost_unit_number then
        on_stop_broken(ghost_unit_number, nil)
    end

    local stop_cb = stop.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
    stop_cb.read_from_train = true
    stop.trains_limit = 0
    stop.backer_name = "[virtual-signal=signal-ghost]"

    storage.entities[stop.unit_number] = stop

    local comb_ids, combs = find_nearby_combs(stop)
    storage.stop_comb_ids[stop.unit_number] = comb_ids

    for _, comb in pairs(combs) do
        local stop_ids, stops = find_nearby_stops(comb)
        storage.comb_stop_ids[comb.unit_number] = stop_ids

        for _, other_stop in pairs(stops) do
            try_close_entity_guis(other_stop.unit_number)
            try_destroy_station(other_stop)
        end
    end

    try_create_station(stop, combs)
end

---@param comb LuaEntity
---@param ghost_unit_number uint?
function on_comb_built(comb, ghost_unit_number)
    if ghost_unit_number then
        on_comb_broken(ghost_unit_number, nil)
    end

    local name = comb.name
    if comb.name == "entity-ghost" then name = comb.ghost_name end

    if name == "sspp-general-io" then
        comb.combinator_description = "{}" -- TODO
    elseif name == "sspp-provide-io" then
        comb.combinator_description = helpers.table_to_json(combinator_description_to_provide_items(comb))
    elseif name == "sspp-request-io" then
        comb.combinator_description = helpers.table_to_json(combinator_description_to_request_items(comb))
    end

    storage.entities[comb.unit_number] = comb

    local stop_ids, stops = find_nearby_stops(comb)
    storage.comb_stop_ids[comb.unit_number] = stop_ids

    for _, stop in pairs(stops) do
        try_close_entity_guis(stop.unit_number)
        try_destroy_station(stop)

        local comb_ids, combs = find_nearby_combs(stop)
        storage.stop_comb_ids[stop.unit_number] = comb_ids

        try_create_station(stop, combs)
    end
end

local function on_entity_built(event)
    local entity = event.entity or event.created_entity

    local name, ghost_unit_number = entity.name, nil
    if name == "entity-ghost" then
        local tags = entity.tags or {}
        tags.ghost_unit_number = entity.unit_number
        entity.tags = tags
        name = entity.ghost_name
    else
        ghost_unit_number = event.tags and event.tags.ghost_unit_number
    end

    if name == "sspp-stop" then
        on_stop_built(entity, ghost_unit_number)
    elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        on_comb_built(entity, ghost_unit_number)
    end
end

--------------------------------------------------------------------------------

---@param stop_id uint
---@param stop LuaEntity?
function on_stop_broken(stop_id, stop)
    local comb_ids = storage.stop_comb_ids[stop_id]

    if stop then
        try_destroy_station(stop)
    end

    storage.entities[stop_id] = nil

    for _, comb_id in pairs(comb_ids) do
        local stop_ids = storage.comb_stop_ids[comb_id]
        list_remove_value(stop_ids, stop_id)

        for _, other_stop_id in pairs(stop_ids) do
            local other_comb_ids = storage.stop_comb_ids[other_stop_id]
            local other_combs = {}
            for _, other_comb_id in pairs(other_comb_ids) do
                other_combs[#other_combs+1] = storage.entities[other_comb_id] -- might be nil
            end
            try_create_station(storage.entities[other_stop_id], other_combs)
        end
    end

    storage.stop_comb_ids[stop_id] = nil
end

---@param comb_id uint
---@param comb LuaEntity?
function on_comb_broken(comb_id, comb)
    local stop_ids = storage.comb_stop_ids[comb_id]

    if comb then
        for _, stop_id in pairs(stop_ids) do
            try_destroy_station(storage.entities[stop_id])
        end
    end

    storage.entities[comb_id] = nil

    for _, stop_id in pairs(stop_ids) do
        local comb_ids = storage.stop_comb_ids[stop_id]
        list_remove_value(comb_ids, comb_id)

        local other_combs = {}
        for _, other_comb_id in pairs(comb_ids) do
            other_combs[#other_combs+1] = storage.entities[other_comb_id] -- might be nil
        end
        try_create_station(storage.entities[stop_id], other_combs)
    end

    storage.comb_stop_ids[comb_id] = nil
end

local function on_entity_broken(event)
    local entity = event.entity or event.ghost ---@type LuaEntity

    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    if name == "sspp-stop" then
        on_stop_broken(entity.unit_number, entity)
    elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        on_comb_broken(entity.unit_number, entity)
    else
        local hauler_id = assert(entity.train).id
        if storage.haulers[hauler_id] then
            on_hauler_disabled_or_destroyed(hauler_id)
            storage.haulers[hauler_id] = nil
        end
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_player_rotated_entity
local function on_entity_rotated(event)
    local entity = event.entity

    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    if name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        -- TODO: find a way to do reverse rotate
        entity.direction = (entity.direction - 4) % 16
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_surface_created|EventData.on_surface_imported
local function on_surface_created(event)
    local surface = assert(game.get_surface(event.surface_index))
    init_network(surface)
end

---@param event EventData.on_pre_surface_cleared|EventData.on_pre_surface_deleted
local function on_surface_cleared(event)
    local surface = assert(game.get_surface(event.surface_index))

    for _, entity in pairs(surface.find_entities()) do
        local name = entity.name
        if name == "entity-ghost" then name = entity.ghost_name end

        if name == "sspp-stop" then
            on_stop_broken(entity.unit_number, entity)
        elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
            on_comb_broken(entity.unit_number, entity)
        end
    end

    storage.networks[surface.name] = nil
end

---@param event EventData.on_surface_renamed
local function on_surface_renamed(event)
    assert(false, "TODO: rename surface")
end

--------------------------------------------------------------------------------

---@param hauler Hauler
local function on_hauler_set_to_manual(hauler)
    on_hauler_disabled_or_destroyed(hauler.train.id)

    hauler.to_provide = nil
    hauler.to_request = nil
    hauler.to_fuel = nil
    hauler.to_depot = nil
    hauler.to_liquidate = nil

    hauler.train.schedule = nil
end

---@param hauler Hauler
local function on_hauler_set_to_automatic(hauler)
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
            list_append_or_create(network.liquidate_haulers, item_key, train.id)
            hauler.to_liquidate = item_key
            set_hauler_status(hauler, { "sspp-alert.holding-cargo" }, item_key)
            send_hauler_to_named_stop(hauler, class.depot_name)
        else
            set_hauler_status(hauler, { "sspp-alert.cargo-not-in-network" }, item_key)
            send_alert_for_train(train, hauler.status)
            train.manual_mode = true
        end
        return
    end

    list_append_or_create(network.depot_haulers, hauler.class, train.id)
    hauler.to_depot = true
    set_hauler_status(hauler, { "sspp-alert.ready-for-dispatch" })
    send_hauler_to_named_stop(hauler, class.depot_name)
end

---@param hauler Hauler
local function on_hauler_arrived_at_provide_station(hauler)
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
local function on_hauler_arrived_at_request_station(hauler)
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

---@param hauler Hauler
local function on_hauler_done_at_provide_station(hauler)
    local station = storage.stations[hauler.to_provide.station]
    hauler.to_provide.phase = "DONE"
    clear_arithmetic_control_behavior(station.provide_io)
    clear_hidden_comb_control_behaviors(station.provide_hidden_combs)
    hauler.train.schedule = { current = 1, records = { { rail = station.stop.connected_rail } } }
end

---@param hauler Hauler
local function on_hauler_done_at_request_station(hauler)
    local station = storage.stations[hauler.to_request.station]
    hauler.to_request.phase = "DONE"
    clear_arithmetic_control_behavior(station.request_io)
    clear_hidden_comb_control_behaviors(station.request_hidden_combs)
    hauler.train.schedule = { current = 1, records = { { rail = station.stop.connected_rail } } }
end

---@param hauler Hauler
local function on_hauler_arrived_at_fuel_stop(hauler)
    local train = hauler.train
    local stop = train.station --[[@as LuaEntity]]

    local wait_conditions = { { type = "fuel_full" } }

    hauler.to_fuel = "TRANSFER"
    train.schedule = { current = 1, records = { { station = stop.backer_name, wait_conditions = wait_conditions }, { rail = stop.connected_rail } } }
end

---@param hauler Hauler
local function on_hauler_done_at_fuel_stop(hauler)
    local train = hauler.train
    local network = storage.networks[hauler.network]
    local class = network.classes[hauler.class]

    list_remove_value_or_destroy(network.fuel_haulers, hauler.class, train.id)
    hauler.to_fuel = nil

    list_append_or_create(network.depot_haulers, hauler.class, train.id)
    hauler.to_depot = true
    set_hauler_status(hauler, { "sspp-alert.ready-for-dispatch" })
    send_hauler_to_named_stop(hauler, class.depot_name)
end

---@param event EventData.on_train_changed_state
local function on_train_changed_state(event)
    local train = event.train

    local state, old_state = train.state, event.old_state
    local is_manual = state == defines.train_state.manual_control or state == defines.train_state.manual_control_stop
    local was_manual = old_state == defines.train_state.manual_control or old_state == defines.train_state.manual_control_stop
    if is_manual and was_manual then return end

    if is_manual then
        gui.hauler_set_widget_enabled(train.id, true)
    elseif was_manual then
        gui.hauler_set_widget_enabled(train.id, false)
    end

    local hauler = storage.haulers[train.id]
    if not hauler then return end

    if is_manual then
        on_hauler_set_to_manual(hauler)
        return
    end

    if was_manual then
        on_hauler_set_to_automatic(hauler)
        return
    end

    if hauler.to_provide then
        if hauler.to_provide.phase == "TRAVEL" then
            if state == defines.train_state.wait_station then
                on_hauler_arrived_at_provide_station(hauler)
            end
        elseif hauler.to_provide.phase == "TRANSFER" then
            if state == defines.train_state.arrive_station then
                on_hauler_done_at_provide_station(hauler)
            end
        end
        return
    end

    if hauler.to_request then
        if hauler.to_request.phase == "TRAVEL" then
            if state == defines.train_state.wait_station then
                on_hauler_arrived_at_request_station(hauler)
            end
        elseif hauler.to_request.phase == "TRANSFER" then
            if state == defines.train_state.arrive_station then
                on_hauler_done_at_request_station(hauler)
            end
        end
        return
    end

    if hauler.to_fuel then
        if hauler.to_fuel == "TRAVEL" then
            if state == defines.train_state.wait_station then
                on_hauler_arrived_at_fuel_stop(hauler)
            end
        elseif hauler.to_fuel == "TRANSFER" then
            if state == defines.train_state.arrive_station then
                on_hauler_done_at_fuel_stop(hauler)
            end
        end
        return
    end

    if state == defines.train_state.no_path or state == defines.train_state.destination_full then
        set_hauler_status(hauler, { "sspp-alert.path-broken" })
        send_alert_for_train(train, hauler.status)
        train.manual_mode = true
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_train_created
local function on_train_created(event)
    local old_hauler_id_1 = event.old_train_id_1
    if old_hauler_id_1 and storage.haulers[old_hauler_id_1] then
        on_hauler_disabled_or_destroyed(old_hauler_id_1)
        storage.haulers[old_hauler_id_1] = nil
    end
    local old_hauler_id_2 = event.old_train_id_2
    if old_hauler_id_2 and storage.haulers[old_hauler_id_2] then
        on_hauler_disabled_or_destroyed(old_hauler_id_2)
        storage.haulers[old_hauler_id_2] = nil
    end
end

---@param event EventData.on_train_schedule_changed
local function on_train_schedule_changed(event)
    if not event.player_index then return end

    local train = event.train
    if train.manual_mode then return end

    local hauler = storage.haulers[train.id]
    if not hauler then return end

    set_hauler_status(hauler, { "sspp-alert.schedule-modified" })
    send_alert_for_train(train, hauler.status)
    train.manual_mode = true
end

--------------------------------------------------------------------------------

---@param event EventData.on_runtime_mod_setting_changed
local function on_mod_setting_changed(event)
    populate_mod_settings()
end

--------------------------------------------------------------------------------

local function on_init()
    init_storage()
    for _, surface in pairs(game.surfaces) do
        init_network(surface)
    end
end

local function on_load()
    --- TODO: setup mod compatibility
end

--------------------------------------------------------------------------------

local filter_built = {
    { filter = "name", name = "sspp-stop" },
    { filter = "name", name = "sspp-general-io" },
    { filter = "name", name = "sspp-provide-io" },
    { filter = "name", name = "sspp-request-io" },
    { filter = "ghost_name", name = "sspp-stop" },
    { filter = "ghost_name", name = "sspp-general-io" },
    { filter = "ghost_name", name = "sspp-provide-io" },
    { filter = "ghost_name", name = "sspp-request-io" },
}
local filter_broken = {
    { filter = "name", name = "sspp-stop" },
    { filter = "name", name = "sspp-general-io" },
    { filter = "name", name = "sspp-provide-io" },
    { filter = "name", name = "sspp-request-io" },
    { filter = "ghost_name", name = "sspp-stop" },
    { filter = "ghost_name", name = "sspp-general-io" },
    { filter = "ghost_name", name = "sspp-provide-io" },
    { filter = "ghost_name", name = "sspp-request-io" },
    { filter = "rolling-stock" },
}
local filter_ghost_broken = {
    { filter = "name", name = "sspp-stop" },
    { filter = "name", name = "sspp-general-io" },
    { filter = "name", name = "sspp-provide-io" },
    { filter = "name", name = "sspp-request-io" },
}

--------------------------------------------------------------------------------

populate_mod_settings()

script.on_event(defines.events.on_built_entity, on_entity_built, filter_built)
script.on_event(defines.events.on_entity_cloned, on_entity_built, filter_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built, filter_built)
script.on_event(defines.events.script_raised_built, on_entity_built, filter_built)
script.on_event(defines.events.script_raised_revive, on_entity_built, filter_built)

script.on_event(defines.events.on_entity_died, on_entity_broken, filter_broken)
script.on_event(defines.events.on_pre_player_mined_item, on_entity_broken, filter_broken)
script.on_event(defines.events.on_robot_pre_mined, on_entity_broken, filter_broken)
script.on_event(defines.events.script_raised_destroy, on_entity_broken, filter_broken)
script.on_event(defines.events.on_pre_ghost_deconstructed, on_entity_broken, filter_ghost_broken)

script.on_event(defines.events.on_player_rotated_entity, on_entity_rotated)

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_train_created, on_train_created)
script.on_event(defines.events.on_train_schedule_changed, on_train_schedule_changed)

script.on_event(defines.events.on_surface_created, on_surface_created)
script.on_event(defines.events.on_surface_imported, on_surface_created)
script.on_event(defines.events.on_pre_surface_cleared, on_surface_cleared)
script.on_event(defines.events.on_pre_surface_deleted, on_surface_cleared)
script.on_event(defines.events.on_surface_renamed, on_surface_renamed)

script.on_event(defines.events.on_runtime_mod_setting_changed, on_mod_setting_changed)

script.on_event(defines.events.on_tick, on_tick)

gui.register_event_handlers()

script.on_init(on_init)
script.on_load(on_load)

script.on_configuration_changed(on_config_changed)
