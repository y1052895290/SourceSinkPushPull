-- SSPP by jagoly

--------------------------------------------------------------------------------

---@param stop LuaEntity
---@return LuaEntity[]
local function refresh_nearby_combs(stop)
	local x, y, combs = stop.position.x, stop.position.y, {}
	for _, entity in pairs(stop.surface.find_entities({ { x - 2.6, y - 2.6 }, { x + 2.6, y + 2.6 } })) do
		local name = entity.name
		if name == "entity-ghost" then
			name = entity.ghost_name
		end
		if name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
			combs[#combs+1] = entity
		end
	end
	storage.stop_combs[stop.unit_number] = combs
	return combs
end

---@param comb LuaEntity
---@return LuaEntity[]
local function refresh_nearby_stops(comb)
	local x, y, stops = comb.position.x, comb.position.y, {}
	for _, entity in pairs(comb.surface.find_entities({ { x - 2.1, y - 2.1 }, { x + 2.1, y + 2.1 } })) do
		local name = entity.name
		if name == "entity-ghost" then
			name = entity.ghost_name
		end
		if name == "sspp-stop" then
			stops[#stops+1] = entity
		end
	end
	storage.comb_stops[comb.unit_number] = stops
	return stops
end

---@param comb LuaEntity
---@param stop LuaEntity
---@return LuaEntity[]
local function remove_from_nearby_stops(comb, stop)
	local stops = storage.comb_stops[comb.unit_number]
	for i = 1, #stops do
		if stops[i] == stop then
			table.remove(stops, i)
			break
		end
	end
	return stops
end

---@param stop LuaEntity
---@param comb LuaEntity
---@return LuaEntity[]
local function remove_from_nearby_combs(stop, comb)
	local combs = storage.stop_combs[stop.unit_number]
	for i = 1, #combs do
		if combs[i] == comb then
			table.remove(combs, i)
			break
		end
	end
	return combs
end

---@param comb LuaEntity
---@return LuaEntity[]
local function get_nearby_stops(comb)
	return storage.comb_stops[comb.unit_number] or {}
end

---@param stop LuaEntity
---@return LuaEntity[]
local function get_nearby_combs(stop)
	return storage.stop_combs[stop.unit_number] or {}
end

--------------------------------------------------------------------------------

---@param stop LuaEntity
---@param combs_list LuaEntity[]
local function try_create_station(stop, combs_list)
	if stop.name == "entity-ghost" then return end

	local station_id = stop.unit_number --[[@as StationId]]
	assert(storage.stations[station_id] == nil)

	local combs = {} ---@type {[string]: LuaEntity?}

	for _, comb in pairs(combs_list) do
		local name = comb.name
		if name == "entity-ghost" then return end
		if combs[name] then return end

		local comb_id = comb.unit_number ---@type uint
		if #storage.comb_stops[comb_id] ~= 1 then return end

		combs[name] = comb
	end

	local general_io = combs["sspp-general-io"]
	if not general_io then return end

	local provide_io = combs["sspp-provide-io"]
	local request_io = combs["sspp-request-io"]
	if not (provide_io or request_io) then return end

	if provide_io then
		local connector_a = stop.get_wire_connector(defines.wire_connector_id.circuit_red, true)
		local connector_b = provide_io.get_wire_connector(defines.wire_connector_id.combinator_input_red, true)
		connector_a.connect_to(connector_b)
	end
	if request_io then
		local connector_a = stop.get_wire_connector(defines.wire_connector_id.circuit_green, true)
		local connector_b = request_io.get_wire_connector(defines.wire_connector_id.combinator_input_green, true)
		connector_a.connect_to(connector_b)
	end

	local station = { stop = stop, general_io = general_io, total_deliveries = 0 } ---@type Station

	if provide_io then
		local properties = helpers.json_to_table(provide_io.combinator_description) --[[@as table]]
		station.provide_io = provide_io
		station.provide_items = properties.provide_items or {}
		station.provide_deliveries = {}
	end

	if request_io then
		local properties = helpers.json_to_table(request_io.combinator_description) --[[@as table]]
		station.request_io = request_io
		station.request_items = properties.request_items or {}
		station.request_deliveries = {}
	end

	stop.backer_name = compute_stop_name(station.provide_items, station.request_items)

	storage.stations[station_id] = station
end

---@param stop LuaEntity
local function try_destroy_station(stop)
	for player_id, player_state in pairs(storage.player_states) do
		local parts = player_state.parts
		if parts and parts.stop.unit_number == stop.unit_number then
			gui.station_closed(player_id, player_state.elements["sspp-station"])
		end
	end

	if stop.name == "entity-ghost" then return end

	local station_id = stop.unit_number ---@type StationId
	local station = storage.stations[station_id]
	if station then
		local provide_deliveries = station.provide_deliveries
		if provide_deliveries then
			for _, hauler_ids in pairs(provide_deliveries) do
				for i = #hauler_ids, 1, -1 do
					local hauler = storage.haulers[hauler_ids[i]]
					send_alert_for_train(hauler.train, { "sspp-alert.destroyed-station" })
					hauler.train.manual_mode = true
				end
			end
		end
		local request_deliveries = station.request_deliveries
		if request_deliveries then
			for _, hauler_ids in pairs(request_deliveries) do
				for i = #hauler_ids, 1, -1 do
					local hauler = storage.haulers[hauler_ids[i]]
					send_alert_for_train(hauler.train, { "sspp-alert.destroyed-station" })
					hauler.train.manual_mode = true
				end
			end
		end
		storage.stations[station_id] = nil
	end

	stop.backer_name = "[img=virtual-signal.signal-ghost]"
end

--------------------------------------------------------------------------------

---@param hauler_id HaulerId
local function on_hauler_disabled_or_destroyed(hauler_id)
	local hauler = assert(storage.haulers[hauler_id])
	local network_name = hauler.network
	local network = assert(storage.networks[network_name])

	local to_provide = hauler.to_provide
	if to_provide then
		local station = assert(storage.stations[to_provide.station])
		local item_key = to_provide.item
		storage.disabled_items[network_name .. ":" .. item_key] = true
		if station.hauler == hauler_id then
			clear_arithmetic_control_behavior(station.provide_io)
			station.hauler = nil
		end
		list_remove_value_or_destroy(network.provide_haulers, item_key, hauler_id)
		list_remove_value_or_destroy(station.provide_deliveries, item_key, hauler_id)
		station.total_deliveries = station.total_deliveries - 1
	end

	local to_request = hauler.to_request
	if to_request then
		local station = assert(storage.stations[to_request.station])
		local item_key = to_request.item
		storage.disabled_items[hauler.network .. ":" .. item_key] = true
		if station.hauler == hauler_id then
			clear_arithmetic_control_behavior(station.request_io)
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
		list_remove_value_or_destroy(network.liquidate_haulers, hauler.to_liquidate, hauler_id)
	end
end

--------------------------------------------------------------------------------

---@param stop LuaEntity
function on_stop_built(stop)
	assert(stop.valid)

	local stop_cb = stop.get_or_create_control_behavior() --[[@as LuaTrainStopControlBehavior]]
	stop_cb.read_from_train = true
	stop.trains_limit = 0
	stop.backer_name = "[img=virtual-signal.signal-ghost]"

	local combs_list = refresh_nearby_combs(stop)

	for _, comb in pairs(combs_list) do
		local stops_list = get_nearby_stops(comb)

		for _, other_stop in pairs(stops_list) do
			try_destroy_station(other_stop)
		end

		refresh_nearby_stops(comb)
	end

	try_create_station(stop, combs_list)
end

---@param comb LuaEntity
function on_comb_built(comb)
	assert(comb.valid)

	if comb.combinator_description == "" then
		local properties = {}
		if comb.name == "sspp-general-io" then
			-- TODO
		elseif comb.name == "sspp-provide-io" then
			properties.provide_items = {}
		elseif comb.name == "sspp-request-io" then
			properties.request_items = {}
		end
		comb.combinator_description = helpers.table_to_json(properties)
	end

	local stops_list = refresh_nearby_stops(comb)

	for _, stop in pairs(stops_list) do
		try_destroy_station(stop)

		local combs_list = refresh_nearby_combs(stop)

		if #stops_list == 1 then
			try_create_station(stop, combs_list)
		end
	end
end

local function on_entity_built(event)
	local entity = event.entity or event.created_entity
	assert(entity.valid)

	local name = entity.name
	if name == "entity-ghost" then name = entity.ghost_name end

	if name == "sspp-stop" then
		on_stop_built(entity)
	elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
		on_comb_built(entity)
	end
end

--------------------------------------------------------------------------------

---@paramstop LuaEntity
function on_stop_broken(stop)
	assert(stop.valid)

	try_destroy_station(stop)

	local combs_list = get_nearby_combs(stop)

	for _, comb in pairs(combs_list) do
		local stops_list = remove_from_nearby_stops(comb, stop)

		for _, other_stop in pairs(stops_list) do
			local other_combs_list = get_nearby_combs(other_stop)

			try_create_station(other_stop, other_combs_list)
		end
	end

	storage.stop_combs[stop.unit_number] = nil
end

---@param comb LuaEntity
function on_comb_broken(comb)
	assert(comb.valid)

	local stops_list = get_nearby_stops(comb)

	if #stops_list == 1 then
		try_destroy_station(stops_list[1])
	end

	for _, stop in pairs(stops_list) do
		local combs_list = remove_from_nearby_combs(stop, comb)

		try_create_station(stop, combs_list)
	end

	storage.comb_stops[comb.unit_number] = nil
end

local function on_entity_broken(event)
	local entity = event.entity or event.ghost ---@type LuaEntity
	assert(entity.valid)

	local name = entity.name
	if name == "entity-ghost" then name = entity.ghost_name end

	if name == "sspp-stop" then
		on_stop_broken(entity)
	elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
		on_comb_broken(entity)
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
	assert(entity.valid)

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
	local surface = game.surfaces[event.surface_index]
	assert(surface)

	local entities = surface.find_entities_filtered({ name = "sspp-stop" })
	for _, entity in pairs(entities) do
		if entity.valid then
			on_stop_broken(entity)
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
		send_alert_for_train(train, { "sspp-alert.class-not-in-network", hauler.class })
		train.manual_mode = true
		return
	end

	if check_if_hauler_needs_fuel(hauler, class) then
		list_append_or_create(network.fuel_haulers, class.name, train.id)
		hauler.to_fuel = true
		send_hauler_to_named_stop(hauler, class.fueler_name)
		return
	end

	local train_items = train.get_contents()
	local train_fluids = train.get_fluid_contents()

	if #train_items + table_size(train_fluids) > 1 then
		send_alert_for_train(train, { "sspp-alert.multiple-items-or-fluids" })
		train.manual_mode = true
		return
	end

	local train_item = train_items[1]
	if train_item then
		local item_name, item_quality = train_item.name, train_item.quality or "normal"
		local item_key = item_name .. ":" .. item_quality
		if network.items[item_key] then
			list_append_or_create(network.liquidate_haulers, item_key, train.id)
			hauler.to_liquidate = item_key
			send_hauler_to_named_stop(hauler, class.depot_name)
		else
			send_alert_for_train(train, { "sspp-alert.item-not-in-network", item_name, item_quality })
			train.manual_mode = true
		end
		return
	end

	local train_fluid = next(train_fluids)
	if train_fluid then
		if network.items[train_fluid] then
			list_append_or_create(network.liquidate_haulers, train_fluid, train.id)
			hauler.to_liquidate = train_fluid
			send_hauler_to_named_stop(hauler, class.depot_name)
		else
			send_alert_for_train(train, { "sspp-alert.fluid-not-in-network", train_fluid })
			train.manual_mode = true
		end
		return
	end

	list_append_or_create(network.depot_haulers, class.name, train.id)
	hauler.to_depot = true
	send_hauler_to_named_stop(hauler, class.depot_name)
end

---@param hauler Hauler
local function on_hauler_arrived_at_provide_station(hauler)
	local train = hauler.train
	local to_provide = hauler.to_provide ---@type HaulerToStation

	local station = storage.stations[to_provide.station]
	if station.stop ~= train.station then
		send_alert_for_train(train, { "sspp-alert.arrived-at-wrong-provide-stop" })
		hauler.train.manual_mode = true
		return
	end

	local item_key = to_provide.item
	local provide_item = station.provide_items[item_key]

	local network_item = storage.networks[hauler.network].items[item_key]
	local constant = compute_load_target(network_item, provide_item)

	set_arithmetic_control_behavior(station.provide_io, constant, "-", provide_item)
	station.hauler = train.id
end

---@param hauler Hauler
local function on_hauler_arrived_at_request_station(hauler)
	local train = hauler.train
	local to_request = hauler.to_request ---@type HaulerToStation

	local station = storage.stations[to_request.station]
	if station.stop ~= train.station then
		send_alert_for_train(train, { "sspp-alert.arrived-at-wrong-request-stop" })
		hauler.train.manual_mode = true
		return
	end

	local item_key = to_request.item
	local request_item = station.request_items[item_key]

	set_arithmetic_control_behavior(station.request_io, 0, "+", request_item)
	station.hauler = train.id
end

---@param hauler Hauler
local function on_hauler_arrived_at_fuel_stop(hauler)
	--- TODO
end

---@param hauler Hauler
local function on_hauler_arrived_at_depot_stop(hauler)
	--- if the name of the stop has changed, then we can try to re-path
	-- local correct_name = storage.networks[hauler.network].classes[hauler.class].depot_name
	-- if hauler.train.station.backer_name ~= correct_name then
	-- 	send_hauler_to_named_stop(hauler, correct_name)
	-- end
end

---@param event EventData.on_train_changed_state
local function on_train_changed_state(event)
	local train = event.train
	assert(train.valid)

	local new_state, old_state = train.state, event.old_state
	local is_manual = new_state == defines.train_state.manual_control or new_state == defines.train_state.manual_control_stop
	local was_manual = old_state == defines.train_state.manual_control or old_state == defines.train_state.manual_control_stop

	if is_manual and not was_manual then
		gui.hauler_set_widget_enabled(train.id, true)
	end

	if not is_manual and was_manual then
		gui.hauler_set_widget_enabled(train.id, false)
	end

	local hauler_id = train.id
	local hauler = storage.haulers[hauler_id]
	if not hauler then return end

	if is_manual and not was_manual then
		on_hauler_set_to_manual(hauler)
		return
	end

	if not is_manual and was_manual then
		on_hauler_set_to_automatic(hauler)
		return
	end

	if new_state == defines.train_state.no_path or new_state == defines.train_state.destination_full then
		send_alert_for_train(train, { "sspp-alert.path-broken" })
		train.manual_mode = true
		return
	end

	if new_state == defines.train_state.wait_station then
		if hauler.to_provide then
			on_hauler_arrived_at_provide_station(hauler)
			return
		end

		if hauler.to_request then
			on_hauler_arrived_at_request_station(hauler)
			return
		end

		if hauler.to_fuel then
			on_hauler_arrived_at_fuel_stop(hauler)
			return
		end

		if hauler.to_depot then
			on_hauler_arrived_at_depot_stop(hauler)
			return
		end
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

script.on_event(defines.events.on_train_created, on_train_created)
script.on_event(defines.events.on_train_changed_state, on_train_changed_state)

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
