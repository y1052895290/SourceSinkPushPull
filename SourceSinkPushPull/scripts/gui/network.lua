-- SSPP by jagoly

local flib_gui = require("__flib__.gui")

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local function handle_class_delete(event)
	gui.update_network_after_change(event.player_index, true)
end

---@param event EventData.on_gui_text_changed
local function handle_class_name_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_class_item_capacity_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_class_fluid_capacity_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_class_depot_name_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_class_fueler_name_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_click
local function handle_class_expand(event)
	-- TODO
end

---@param event EventData.on_gui_elem_changed
local function handle_item_resource_changed(event)
	local clear = event.element.elem_value == nil
	gui.update_network_after_change(event.player_index, clear)
end

---@param event EventData.on_gui_text_changed
local function handle_item_class_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_item_delivery_size_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_item_delivery_time_changed(event)
	gui.update_network_after_change(event.player_index, false)
end

---@param event EventData.on_gui_click
local function handle_item_expand(event)
	-- TODO
end

--------------------------------------------------------------------------------

---@param def flib.GuiElemDef
---@return flib.GuiElemDef
local function make_right_flow(def)
	return {
		type = "flow", style = "horizontal_flow", children = {
			{ type = "empty-widget", style = "flib_horizontal_pusher" },
			def,
		}
	}
end

---@param class_table LuaGuiElement
local function add_new_class_row(class_table)
	flib_gui.add(class_table, {
		{
			type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/close",
			handler = { [defines.events.on_gui_click] = handle_class_delete }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox",
			text = "",
			handler = { [defines.events.on_gui_confirmed] = handle_class_name_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox", numeric = true,
			text = "0",
			handler = { [defines.events.on_gui_text_changed] = handle_class_item_capacity_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox", numeric = true,
			text = "0",
			handler = { [defines.events.on_gui_text_changed] = handle_class_fluid_capacity_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox",
			text = "",
			handler = { [defines.events.on_gui_text_changed] = handle_class_depot_name_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox",
			text = "",
			handler = { [defines.events.on_gui_text_changed] = handle_class_fueler_name_changed }
		},
		make_right_flow({
			type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search",
			handler = { [defines.events.on_gui_click] = handle_class_expand }
		}),
	})
end

---@param item_table LuaGuiElement
---@param elem_type "item-with-quality"|"fluid"
local function add_new_item_row(item_table, elem_type)
	flib_gui.add(item_table, {
		{
			type = "choose-elem-button", style = "sspp_compact_slot_button",
			elem_type = elem_type,
			handler = { [defines.events.on_gui_elem_changed] = handle_item_resource_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox",
			text = "",
			handler = { [defines.events.on_gui_text_changed] = handle_item_class_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox", numeric = true,
			text = "1",
			handler = { [defines.events.on_gui_text_changed] = handle_item_delivery_size_changed }
		},
		{
			type = "textfield", style = "sspp_station_item_textbox", numeric = true,
			text = "1",
			handler = { [defines.events.on_gui_text_changed] = handle_item_delivery_time_changed }
		},
		make_right_flow({
			type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search",
			handler = { [defines.events.on_gui_click] = handle_item_expand }
		}),
	})
end

--------------------------------------------------------------------------------

---@param from_nothing boolean
---@param network Network
---@param class_table LuaGuiElement
---@param class_name ClassName
---@param class Class
---@param i integer
local function populate_row_from_class(from_nothing, network, class_table, class_name, class, i)
	if from_nothing then
		add_new_class_row(class_table)
		local table_children = class_table.children

		table_children[i + 2].text = class_name
		table_children[i + 3].text = tostring(class.item_slot_capacity)
		table_children[i + 4].text = tostring(class.fluid_capacity)
		table_children[i + 5].text = class.depot_name
		table_children[i + 6].text = class.fueler_name
	end
end

---@param from_nothing boolean
---@param network Network
---@param item_table LuaGuiElement
---@param item_key ItemKey
---@param item NetworkItem
---@param i integer
local function populate_row_from_item(from_nothing, network, item_table, item_key, item, i)
	local is_fluid = not item.quality

	if from_nothing then
		add_new_item_row(item_table, is_fluid and "fluid" or "item-with-quality")
		local table_children = item_table.children

		table_children[i + 1].elem_value = is_fluid and item.name or { name = item.name, quality = item.quality }
		table_children[i + 2].text = item.class
		table_children[i + 3].text = tostring(item.delivery_size)
		table_children[i + 4].text = tostring(item.delivery_time)
	end
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param list_index integer
---@param i integer
---@return ClassName? class_name, Class? class
local function generate_class_from_row(table_children, list_index, i)
	local class_name = table_children[i + 2].text
	if class_name == "" then return end

	return class_name, {
		list_index = list_index,
		name = class_name,
		item_slot_capacity = tonumber(table_children[i + 3].text) or 0,
		fluid_capacity = tonumber(table_children[i + 4].text) or 0,
		depot_name = table_children[i + 5].text,
		fueler_name = table_children[i + 6].text,
	} --[[@as Class]]
end

---@param table_children LuaGuiElement[]
---@param list_index integer
---@param i integer
---@return ItemKey? key, NetworkItem? item
local function generate_item_from_row(table_children, list_index, i)
	local elem_value = table_children[i + 1].elem_value --[[@as (table|string)?]]
	if elem_value == nil then return end

	local name, quality, item_key = gui.extract_elem_value_fields(elem_value)
	return item_key, {
		list_index = list_index,
		name = name,
		quality = quality,
		class = table_children[i + 2].text,
		delivery_size = tonumber(table_children[i + 3].text) or 0,
		delivery_time = tonumber(table_children[i + 4].text) or 0.0,
	} --[[@as NetworkItem]]
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param from_nothing boolean
function gui.update_network_after_change(player_id, from_nothing)
	local player_state = storage.player_states[player_id]

	---@param hauler_ids HaulerId[]
	---@param message LocalisedString
	local function disable_haulers(hauler_ids, message)
		if hauler_ids then
			for i = #hauler_ids, 1, -1 do
				local train = storage.haulers[hauler_ids[i]].train
				send_alert_for_train(train, message)
				train.manual_mode = true
			end
		end
	end

	local network = assert(storage.networks[player_state.network])

	local class_table = player_state.elements.class_table
	local classes = gui.generate_dict_from_table(class_table, generate_class_from_row)

	for class_name, _ in pairs(network.classes) do
		if not classes[class_name] then
			local message = { "sspp-alert.class-not-in-network", class_name }
			disable_haulers(network.fuel_haulers[class_name], message)
			disable_haulers(network.depot_haulers[class_name], message)
		end
	end
	network.classes = classes

	gui.populate_table_from_dict(from_nothing, network, class_table, classes, populate_row_from_class)

	local item_table = player_state.elements.item_table
	local items = gui.generate_dict_from_table(item_table, generate_item_from_row)

	for item_key, item in pairs(network.items) do
		if not items[item_key] then
			local message ---@type LocalisedString
			if item.quality then
				message = { "sspp-alert.item-not-in-network", item.name, item.quality }
			else
				message = { "sspp-alert.fluid-not-in-network", item.name }
			end
			disable_haulers(network.provide_haulers[item_key], message)
			disable_haulers(network.request_haulers[item_key], message)
		end
	end
	network.items = items

	gui.populate_table_from_dict(from_nothing, network, item_table, items, populate_row_from_item)
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local function handle_add_class(event)
	local class_table = storage.player_states[event.player_index].elements.class_table
	add_new_class_row(class_table)
end

---@param event EventData.on_gui_click
local function handle_add_item(event)
	local item_table = storage.player_states[event.player_index].elements.item_table
	add_new_item_row(item_table, "item-with-quality")
end

---@param event EventData.on_gui_click
local function handle_add_fluid(event)
	local item_table = storage.player_states[event.player_index].elements.item_table
	add_new_item_row(item_table, "fluid")
end

---@param event EventData.on_gui_click
local function handle_close(event)
	local player = assert(game.get_player(event.player_index))
	assert(player.opened.name == "sspp-network")

	player.opened = nil
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param network_name NetworkName
function gui.network_open(player_id, network_name)
	local player = assert(game.get_player(player_id))
	local network = assert(storage.networks[network_name])

	player.opened = nil

	local localised_name = network_name ---@type string|LocalisedString
	if network.surface.planet then
		localised_name = network.surface.planet.prototype.localised_name
	elseif network.surface.localised_name then
		localised_name = network.surface.localised_name
	end

	local elements, window = flib_gui.add(player.gui.screen, {
		{ type = "frame", style = "frame", direction = "vertical", name = "sspp-network", children = {
			{ type = "flow", name = "titlebar", style = "frame_header_flow", children = {
				{ type = "label", style = "frame_title", caption = { "sspp-gui.network-for-surface", localised_name }, ignored_by_interaction = true },
				{ type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
				{ type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = handle_close },
			}},
			{ type = "flow", style = "inset_frame_container_horizontal_flow", children = {
				{ type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
					{ type = "tabbed-pane", style = "tabbed_pane", selected_tab_index = 1, children = {
						---@diagnostic disable-next-line: missing-fields
						{
							tab = { type = "tab", style = "tab", caption = { "sspp-gui.classes" } },
							content = { type = "scroll-pane", style = "sspp_network_left_scroll_pane", direction = "vertical", children = {
								{ type = "table", name = "class_table", style = "sspp_network_class_table", column_count = 7, children = {
									{ type = "empty-widget" },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.name" }, tooltip = { "sspp-gui.class-name-tooltip" } },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.item-capacity" }, tooltip = { "sspp-gui.class-item-capacity-tooltip" } },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.fluid-capacity" }, tooltip = { "sspp-gui.class-fluid-capacity-tooltip" } },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.depot-name" }, tooltip = { "sspp-gui.class-depot-name-tooltip" } },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.fueler-name" }, tooltip = { "sspp-gui.class-fueler-name-tooltip" } },
									{ type = "empty-widget" },
								}},
								{ type = "flow", style = "horizontal_flow", children = {
									{ type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-class" }, handler = handle_add_class },
								}},
							}},
						},
						---@diagnostic disable-next-line: missing-fields
						{
							tab = { type = "tab", style = "tab", caption = { "sspp-gui.items-fluids" } },
							content = { type = "scroll-pane", style = "sspp_network_left_scroll_pane", direction = "vertical", children = {
								{ type = "table", name = "item_table", style = "sspp_network_item_table", column_count = 5, children = {
									{ type = "empty-widget" },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.class" }, tooltip = { "sspp-gui.item-class-tooltip" } },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.delivery-size" }, tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
									{ type = "label", style = "bold_label", caption = { "sspp-gui.delivery-time" }, tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
									{ type = "empty-widget" },
								}},
								{ type = "flow", style = "horizontal_flow", children = {
									{ type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, handler = handle_add_item },
									{ type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, handler = handle_add_fluid },
								}},
							}},
						},
					}},
				}},
				{ type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
					{ type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
						{ type = "label", style = "subheader_caption_label", caption = { "sspp-gui.deliveries" } },
					}},
				}},
			}},
		}},
	})

	window.titlebar.drag_target = window
	window.force_auto_center()

	storage.player_states[player_id] = { network = network_name, elements = elements }

	gui.populate_table_from_dict(true, network, elements.class_table, network.classes, populate_row_from_class)
	gui.populate_table_from_dict(true, network, elements.item_table, network.items, populate_row_from_item)

	player.opened = window
end

---@param player_id PlayerId
---@param window LuaGuiElement
function gui.network_closed(player_id, window)
	local player = assert(game.get_player(player_id))

	assert(window.name == "sspp-network")
	window.destroy()

	storage.player_states[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.network_add_flib_handlers()
	flib_gui.add_handlers({
		["network_class_delete"] = handle_class_delete,
		["network_class_name_changed"] = handle_class_name_changed,
		["network_class_item_capacity_changed"] = handle_class_item_capacity_changed,
		["network_class_fluid_capacity_changed"] = handle_class_fluid_capacity_changed,
		["network_class_depot_name_changed"] = handle_class_depot_name_changed,
		["network_class_fueler_name_changed"] = handle_class_fueler_name_changed,
		["network_class_expand"] = handle_class_expand,
		["network_item_resource_changed"] = handle_item_resource_changed,
		["network_item_class_changed"] = handle_item_class_changed,
		["network_item_delivery_size_changed"] = handle_item_delivery_size_changed,
		["network_item_delivery_time_changed"] = handle_item_delivery_time_changed,
		["network_item_expand"] = handle_item_expand,
		["network_add_class"] = handle_add_class,
		["network_add_item"] = handle_add_item,
		["network_add_fluid"] = handle_add_item,
		["network_close"] = handle_close,
	})
end
