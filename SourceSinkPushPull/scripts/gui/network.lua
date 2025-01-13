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
local function handle_class_haulers_expand(event)
    -- TODO
end

---@param event EventData.on_gui_elem_changed
local function handle_item_resource_changed(event)
    local clear = event.element.elem_value == nil
    -- TODO: check for recursive spoilage
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
local function handle_item_stations_expand(event)
    -- TODO
end

---@param event EventData.on_gui_click
local function handle_item_haulers_expand(event)
    -- TODO
end

--------------------------------------------------------------------------------

---@param class_table LuaGuiElement
local function add_new_class_row(class_table)
    flib_gui.add(class_table, {
        {
            type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/close",
            handler = { [defines.events.on_gui_click] = handle_class_delete },
        },
        {
            type = "textfield", style = "sspp_name_textbox", icon_selector = true,
            text = "",
            handler = { [defines.events.on_gui_text_changed] = handle_class_name_changed },
        },
        {
            type = "textfield", style = "sspp_number_textbox", numeric = true,
            text = "0",
            handler = { [defines.events.on_gui_text_changed] = handle_class_item_capacity_changed },
        },
        {
            type = "textfield", style = "sspp_number_textbox", numeric = true,
            text = "0",
            handler = { [defines.events.on_gui_text_changed] = handle_class_fluid_capacity_changed },
        },
        {
            type = "textfield", style = "sspp_name_textbox", icon_selector = true,
            text = "",
            handler = { [defines.events.on_gui_text_changed] = handle_class_depot_name_changed },
        },
        {
            type = "textfield", style = "sspp_name_textbox", icon_selector = true,
            text = "",
            handler = { [defines.events.on_gui_text_changed] = handle_class_fueler_name_changed },
        },
        {
            type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search",
            handler = { [defines.events.on_gui_click] = handle_class_haulers_expand },
        },
        { type = "label", style = "label" },
    })
end

---@param item_table LuaGuiElement
---@param elem_type "item-with-quality"|"fluid"
local function add_new_item_row(item_table, elem_type)
    flib_gui.add(item_table, {
        {
            type = "choose-elem-button", style = "sspp_compact_slot_button",
            elem_type = elem_type,
            handler = { [defines.events.on_gui_elem_changed] = handle_item_resource_changed },
        },
        {
            type = "textfield", style = "sspp_name_textbox", icon_selector = true,
            text = "",
            handler = { [defines.events.on_gui_text_changed] = handle_item_class_changed },
        },
        {
            type = "textfield", style = "sspp_number_textbox", numeric = true,
            text = "1",
            handler = { [defines.events.on_gui_text_changed] = handle_item_delivery_size_changed },
        },
        {
            type = "textfield", style = "sspp_number_textbox", numeric = true,
            text = "1",
            handler = { [defines.events.on_gui_text_changed] = handle_item_delivery_time_changed },
        },
        {
            type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search",
            handler = { [defines.events.on_gui_click] = handle_item_stations_expand },
        },
        { type = "label", style = "label" },
        {
            type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search",
            handler = { [defines.events.on_gui_click] = handle_item_haulers_expand },
        },
        { type = "label", style = "label" },
    })
end

--------------------------------------------------------------------------------

---@param from_nothing boolean
---@param class_table LuaGuiElement
---@param classes {[ClassName]: Class}
---@param class_name ClassName
---@param i integer
local function populate_row_from_class(from_nothing, class_table, classes, class_name, i)
    if from_nothing then
        local class = classes[class_name]

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
---@param item_table LuaGuiElement
---@param items {[ItemKey]: NetworkItem}
---@param item_key ItemKey
---@param i integer
local function populate_row_from_item(from_nothing, item_table, items, item_key, i)
    if from_nothing then
        local item = items[item_key]
        local name, quality = item.name, item.quality

        add_new_item_row(item_table, quality and "item-with-quality" or "fluid")
        local table_children = item_table.children

        table_children[i + 1].elem_value = quality and { name = name, quality = quality } or name
        table_children[i + 2].text = item.class
        table_children[i + 3].text = tostring(item.delivery_size)
        table_children[i + 4].text = tostring(item.delivery_time)
    end
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param list_index integer
---@param i integer
---@return ClassName?, Class?
local function generate_class_from_row(table_children, list_index, i)
    local class_name = table_children[i + 2].text
    if class_name == "" then return end

    return class_name, {
        list_index = list_index,
        item_slot_capacity = tonumber(table_children[i + 3].text) or 0,
        fluid_capacity = tonumber(table_children[i + 4].text) or 0,
        depot_name = table_children[i + 5].text,
        fueler_name = table_children[i + 6].text,
    } --[[@as Class]]
end

---@param table_children LuaGuiElement[]
---@param list_index integer
---@param i integer
---@return ItemKey?, NetworkItem?
local function generate_item_from_row(table_children, list_index, i)
    local elem_value = table_children[i + 1].elem_value ---@type (table|string)?
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

    local network = assert(storage.networks[player_state.network])

    local class_table = player_state.elements.class_table
    local classes = gui.generate_dict_from_table(class_table, generate_class_from_row)

    for class_name, _ in pairs(network.classes) do
        if not classes[class_name] then
            set_haulers_to_manual(network.fuel_haulers[class_name], { "sspp-alert.class-not-in-network" })
            set_haulers_to_manual(network.depot_haulers[class_name], { "sspp-alert.class-not-in-network" })
        end
    end
    network.classes = classes

    gui.populate_table_from_dict(from_nothing, class_table, classes, populate_row_from_class)

    local item_table = player_state.elements.item_table
    local items = gui.generate_dict_from_table(item_table, generate_item_from_row)

    for item_key, _ in pairs(network.items) do
        if not items[item_key] then
            set_haulers_to_manual(network.provide_haulers[item_key], { "sspp-alert.cargo-not-in-network" }, item_key)
            set_haulers_to_manual(network.request_haulers[item_key], { "sspp-alert.cargo-not-in-network" }, item_key)
        end
    end
    network.items = items

    gui.populate_table_from_dict(from_nothing, item_table, items, populate_row_from_item)
end

--------------------------------------------------------------------------------

---@param player_state PlayerState
function gui.network_poll_finished(player_state)
    local network = storage.networks[player_state.network]

    local class_hauler_totals = {} ---@type {[ClassName]: integer}
    do
        local push_tickets = network.push_tickets
        local pull_tickets = network.pull_tickets

        local provide_haulers = network.provide_haulers
        local request_haulers = network.request_haulers
        local liquidate_haulers = network.liquidate_haulers

        local item_table = player_state.elements.item_table
        local columns = item_table.column_count
        local table_children = item_table.children

        for i = columns, #table_children - 1, columns do
            local elem_value = table_children[i + 1].elem_value ---@type (table|string)?
            if elem_value then
                local _, _, item_key = gui.extract_elem_value_fields(elem_value)

                local provide_total = len_or_zero(provide_haulers[item_key])
                local request_total = len_or_zero(request_haulers[item_key])
                local liquidate_total = len_or_zero(liquidate_haulers[item_key])

                table_children[i + 6].caption = { "sspp-gui.fmt-item-demand", len_or_zero(push_tickets[item_key]), len_or_zero(pull_tickets[item_key]) }
                table_children[i + 8].caption = { "sspp-gui.fmt-item-haulers", provide_total, request_total, liquidate_total }

                local class_name = table_children[i + 2].text
                class_hauler_totals[class_name] = (class_hauler_totals[class_name] or 0) + provide_total + request_total + liquidate_total
            end
        end
    end

    do
        local depot_haulers = network.depot_haulers
        local fuel_haulers = network.fuel_haulers

        local class_table = player_state.elements.class_table
        local columns = class_table.column_count
        local table_children = class_table.children

        for i = columns, #table_children - 1, columns do
            local class_name = table_children[i + 2].text
            if class_name ~= "" then
                local available = len_or_zero(depot_haulers[class_name])
                local total = available + (class_hauler_totals[class_name] or 0) + len_or_zero(fuel_haulers[class_name])

                table_children[i + 8].caption = { "sspp-gui.fmt-class-available", available, total }
            end
        end
    end
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
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "tabbed-pane", style = "tabbed_pane", selected_tab_index = 1, children = {
                        ---@diagnostic disable-next-line: missing-fields
                        {
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.classes" } },
                            content = { type = "scroll-pane", style = "sspp_network_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "class_table", style = "sspp_network_class_table", column_count = 8, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.name" }, tooltip = { "sspp-gui.class-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.item-capacity" }, tooltip = { "sspp-gui.class-item-capacity-tooltip" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.fluid-capacity" }, tooltip = { "sspp-gui.class-fluid-capacity-tooltip" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.depot-name" }, tooltip = { "sspp-gui.class-depot-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.fueler-name" }, tooltip = { "sspp-gui.class-fueler-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=locomotive]" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.available" }, tooltip = { "sspp-gui.class-available-tooltip" } },
                                } },
                                { type = "flow", style = "horizontal_flow", children = {
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-class" }, handler = handle_add_class },
                                } },
                            } },
                        },
                        ---@diagnostic disable-next-line: missing-fields
                        {
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.items-fluids" } },
                            content = { type = "scroll-pane", style = "sspp_network_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "item_table", style = "sspp_network_item_table", column_count = 8, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.class" }, tooltip = { "sspp-gui.item-class-tooltip" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.delivery-size" }, tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.delivery-time" }, tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=sspp-stop]" },
                                    { type = "label", style = "bold_label", caption = "[virtual-signal=up-arrow][virtual-signal=down-arrow]", tooltip = { "sspp-gui.item-demand-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=locomotive]" },
                                    { type = "label", style = "bold_label", caption = "[virtual-signal=up-arrow][virtual-signal=down-arrow][virtual-signal=signal-skull]", tooltip = { "sspp-gui.item-haulers-tooltip" } },
                                } },
                                { type = "flow", style = "horizontal_flow", children = {
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, handler = handle_add_item },
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, handler = handle_add_fluid },
                                } },
                            } },
                        },
                    } },
                } },
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", style = "subheader_caption_label", caption = { "sspp-gui.deliveries" } },
                    } },
                } },
            } },
        } },
    })

    window.titlebar.drag_target = window
    window.force_auto_center()

    storage.player_states[player_id] = { network = network_name, elements = elements }

    gui.populate_table_from_dict(true, elements.class_table, network.classes, populate_row_from_class)
    gui.populate_table_from_dict(true, elements.item_table, network.items, populate_row_from_item)

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
        ["network_class_haulers_expand"] = handle_class_haulers_expand,
        ["network_item_resource_changed"] = handle_item_resource_changed,
        ["network_item_class_changed"] = handle_item_class_changed,
        ["network_item_delivery_size_changed"] = handle_item_delivery_size_changed,
        ["network_item_delivery_time_changed"] = handle_item_delivery_time_changed,
        ["network_item_stations_expand"] = handle_item_stations_expand,
        ["network_item_haulers_expand"] = handle_item_haulers_expand,
        ["network_add_class"] = handle_add_class,
        ["network_add_item"] = handle_add_item,
        ["network_add_fluid"] = handle_add_fluid,
        ["network_close"] = handle_close,
    })
end
