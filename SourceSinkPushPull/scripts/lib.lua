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
		list = { value } -- assume copies > 0
		object[key] = list
	end
	if copies > 1 then
		local length = #list
		for i = length + 2, length + copies do
			list[i] = value
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

---@param network_item NetworkItem
---@param station_item ProvideItem|RequestItem
---@return integer
function compute_storage_needed(network_item, station_item)
	local rounding = 100.0 -- for fluids
	if network_item.quality then
		rounding = prototypes.item[network_item.name].stack_size
	end
	local delivery_size = network_item.delivery_size
	local buffer = delivery_size
	if not (station_item.push or station_item.pull) then
		buffer = math.ceil(buffer * 0.5)
	end
	return math.ceil(math.max(station_item.throughput * network_item.delivery_time, delivery_size) / rounding) * rounding + buffer
end

---@param network_item NetworkItem
---@param provide_item ProvideItem
---@return integer
function compute_load_target(network_item, provide_item)
	local granularity = provide_item.granularity
	if network_item.quality then
		granularity = math.min(prototypes.item[network_item.name].stack_size, granularity)
	end
	return math.floor(network_item.delivery_size / granularity) * granularity
end

---@param provide_items {[ItemKey]: ProvideItem}?
---@param request_items {[ItemKey]: RequestItem}?
function compute_stop_name(provide_items, request_items)
	local provide_icons ---@type string[]?
	if provide_items and next(provide_items) then
		provide_icons = {}
		for item_key, item in pairs(provide_items) do
			if item.quality then
				provide_icons[item.list_index] = "[img=item." .. item.name .. "]"
			else
				provide_icons[item.list_index] = "[img=fluid." .. item.name .. "]"
			end
		end
		assert(#provide_icons == table_size(provide_items))
	end

	local request_icons ---@type string[]?
	if request_items and next(request_items) then
		request_icons = {}
		for item_key, item in pairs(request_items) do
			if item.quality then
				request_icons[item.list_index] = "[img=item." .. item.name .. "]"
			else
				request_icons[item.list_index] = "[img=fluid." .. item.name .. "]"
			end
		end
		assert(#request_icons == table_size(request_items))
	end

	if provide_icons and request_icons then
		return "[img=virtual-signal.up-arrow]" .. table.concat(provide_icons) .. " / " .. "[img=virtual-signal.down-arrow]" .. table.concat(request_icons)
	elseif provide_icons then
		return "[img=virtual-signal.up-arrow]" .. table.concat(provide_icons)
	elseif request_icons then
		return "[img=virtual-signal.down-arrow]" .. table.concat(request_icons)
	end

	return "[img=virtual-signal.signal-ghost]"
end

--------------------------------------------------------------------------------

---@param item NetworkItem|ProvideItem|RequestItem
---@return SignalID
function make_item_signal(item)
	local name, quality = item.name, item.quality
	if quality then
		return { name = name, quality = quality, type = "item" }
	end
	return { name = name, type = "fluid" }
end

---@param comb LuaEntity
---@param constant integer
---@param operation "-"|"+"
---@param item ProvideItem|RequestItem
function set_arithmetic_control_behavior(comb, constant, operation, item)
	local cb = comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
	local signal = make_item_signal(item)
	cb.parameters = { first_constant = constant, operation = operation, second_signal = signal, output_signal = signal }
end

---@param comb LuaEntity
function clear_arithmetic_control_behavior(comb)
	local cb = comb.get_or_create_control_behavior() --[[@as LuaArithmeticCombinatorControlBehavior]]
	cb.parameters = nil
end

--------------------------------------------------------------------------------

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
		send_alert_for_train(train, { "sspp-alert.no-path-to-station", stop.unit_number })
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
		send_alert_for_train(train, { "sspp-alert.no-path-to-named-stop", stop_name })
		train.manual_mode = true
	end
end

---@param hauler Hauler
---@param class Class
---@return boolean
function check_if_hauler_needs_fuel(hauler, class)
	assert(class)
	local maximum_delivery_time = 120.0    -- TODO: calculate properly
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
	local name, ghost = entity.name, nil ---@type string, true?
	if name == "entity-ghost" then name, ghost = entity.ghost_name, true end

	local stop ---@type LuaEntity
	if name == "sspp-stop" then
		stop = entity
	else
		local stops_list = storage.comb_stops[entity.unit_number]
		if stops_list == nil or #stops_list ~= 1 then return nil end
		stop = stops_list[1]
	end

	local combs_list = storage.stop_combs[stop.unit_number]
	if combs_list == nil then return nil end

	local combs = {} ---@type {[string]: LuaEntity?}
	for _, comb in pairs(combs_list) do
		name = comb.name
		if name == "entity-ghost" then name, ghost = comb.ghost_name, true end
		if combs[name] then return nil end

		if #storage.comb_stops[comb.unit_number] ~= 1 then return nil end

		combs[name] = comb
	end

	local general_io = combs["sspp-general-io"]
	if not general_io then return nil end

	local provide_io = combs["sspp-provide-io"]
	local request_io = combs["sspp-request-io"]
	if not (provide_io or request_io) then return nil end

	return { stop = stop, general_io = general_io, provide_io = provide_io, request_io = request_io, ghost = ghost }
end
