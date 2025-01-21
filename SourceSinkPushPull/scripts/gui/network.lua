-- SSPP by jagoly

local flib_gui = require("__flib__.gui")
local events = defines.events

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_class_delete = { [events.on_gui_click] = function(event)
    local element = event.element
    element.parent.children[element.get_index_in_parent() + 1].text = ""
    gui.update_network_after_change(event.player_index, true)
end }

---@param event EventData.on_gui_text_changed
local handle_class_name_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_text_changed
local handle_class_item_capacity_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_text_changed
local handle_class_fluid_capacity_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_text_changed
local handle_class_depot_name_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_text_changed
local handle_class_fueler_name_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_elem_changed
local handle_item_resource_changed = { [events.on_gui_elem_changed] = function(event)
    local clear = event.element.elem_value == nil
    -- TODO: check for recursive spoilage
    gui.update_network_after_change(event.player_index, clear)
end }

---@param event EventData.on_gui_text_changed
local handle_item_class_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_text_changed
local handle_item_delivery_size_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_text_changed
local handle_item_delivery_time_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index, false)
end }

--------------------------------------------------------------------------------

---@param player_gui PlayerNetworkGui
local function clear_grid_and_header(player_gui)
    local elements = player_gui.elements

    elements.grid_title.caption = ""
    elements.grid_stations_mode_switch.visible = false
    elements.grid_provide_toggle.enabled = false
    elements.grid_provide_toggle.tooltip = ""
    elements.grid_request_toggle.enabled = false
    elements.grid_request_toggle.tooltip = ""
    elements.grid_liquidate_toggle.enabled = false
    elements.grid_liquidate_toggle.tooltip = ""
    elements.grid_fuel_toggle.enabled = false
    elements.grid_fuel_toggle.tooltip = ""
    elements.grid_depot_toggle.enabled = false
    elements.grid_depot_toggle.tooltip = ""

    elements.grid_table.clear()

    player_gui.haulers_class = nil
    player_gui.haulers_item = nil
    player_gui.stations_item = nil
end

---@param event EventData.on_gui_click
local handle_expand_class_haulers = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local element = event.element
    local class_name = element.parent.children[element.get_index_in_parent() - 5].text
    if class_name == "" then return end

    elements.grid_title.caption = { "sspp-gui.fmt-class-haulers-title", class_name }
    elements.grid_provide_toggle.enabled = true
    elements.grid_provide_toggle.tooltip = { "sspp-gui.grid-haulers-provide-tooltip" }
    elements.grid_request_toggle.enabled = true
    elements.grid_request_toggle.tooltip = { "sspp-gui.grid-haulers-request-tooltip" }
    elements.grid_liquidate_toggle.enabled = true
    elements.grid_liquidate_toggle.tooltip = { "sspp-gui.grid-haulers-liquidate-tooltip" }
    elements.grid_fuel_toggle.enabled = true
    elements.grid_fuel_toggle.tooltip = { "sspp-gui.grid-haulers-fuel-tooltip" }
    elements.grid_depot_toggle.enabled = true
    elements.grid_depot_toggle.tooltip = { "sspp-gui.grid-haulers-depot-tooltip" }

    player_gui.haulers_class = class_name
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_click
local handle_expand_item_haulers = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local element = event.element
    local elem_value = element.parent.children[element.get_index_in_parent() - 6].elem_value
    if not elem_value then return end

    local name, quality, item_key = gui.extract_elem_value_fields(elem_value)
    if quality then
        elements.grid_title.caption = { "sspp-gui.fmt-item-haulers-title", name, quality }
    else
        elements.grid_title.caption = { "sspp-gui.fmt-fluid-haulers-title", name }
    end
    elements.grid_provide_toggle.enabled = true
    elements.grid_provide_toggle.tooltip = { "sspp-gui.grid-haulers-provide-tooltip" }
    elements.grid_request_toggle.enabled = true
    elements.grid_request_toggle.tooltip = { "sspp-gui.grid-haulers-request-tooltip" }
    elements.grid_liquidate_toggle.enabled = true
    elements.grid_liquidate_toggle.tooltip = { "sspp-gui.grid-haulers-liquidate-tooltip" }

    player_gui.haulers_item = item_key
    gui.update_network_after_change(event.player_index, false)
end }

---@param event EventData.on_gui_click
local handle_expand_item_stations = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local element = event.element
    local elem_value = element.parent.children[element.get_index_in_parent() - 4].elem_value
    if not elem_value then return end

    local name, quality, item_key = gui.extract_elem_value_fields(elem_value)
    if quality then
        elements.grid_title.caption = { "sspp-gui.fmt-item-stations-title", name, quality }
    else
        elements.grid_title.caption = { "sspp-gui.fmt-fluid-stations-title", name }
    end
    elements.grid_stations_mode_switch.visible = true
    elements.grid_provide_toggle.enabled = true
    elements.grid_provide_toggle.tooltip = { "sspp-gui.grid-stations-provide-tooltip" }
    elements.grid_request_toggle.enabled = true
    elements.grid_request_toggle.tooltip = { "sspp-gui.grid-stations-request-tooltip" }

    player_gui.stations_item = item_key
    gui.update_network_after_change(event.player_index, false)
end }

--------------------------------------------------------------------------------

---@param class_table LuaGuiElement
local function add_new_class_row(class_table)
    flib_gui.add(class_table, {
        { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/close", handler = handle_class_delete },
        { type = "textfield", style = "sspp_name_textbox", icon_selector = true, text = "", handler = handle_class_name_changed },
        { type = "textfield", style = "sspp_number_textbox", numeric = true, text = "0", handler = handle_class_item_capacity_changed },
        { type = "textfield", style = "sspp_number_textbox", numeric = true, text = "0", handler = handle_class_fluid_capacity_changed },
        { type = "textfield", style = "sspp_name_textbox", icon_selector = true, text = "", handler = handle_class_depot_name_changed },
        { type = "textfield", style = "sspp_name_textbox", icon_selector = true, text = "", handler = handle_class_fueler_name_changed },
        { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search", handler = handle_expand_class_haulers },
        { type = "label", style = "label" },
    })
end

---@param item_table LuaGuiElement
---@param elem_type "item-with-quality"|"fluid"
local function add_new_item_row(item_table, elem_type)
    flib_gui.add(item_table, {
        { type = "choose-elem-button", style = "sspp_compact_slot_button", elem_type = elem_type, handler = handle_item_resource_changed },
        { type = "textfield", style = "sspp_name_textbox", icon_selector = true, text = "", handler = handle_item_class_changed },
        { type = "textfield", style = "sspp_number_textbox", numeric = true, text = "1", handler = handle_item_delivery_size_changed },
        { type = "textfield", style = "sspp_number_textbox", numeric = true, text = "1", handler = handle_item_delivery_time_changed },
        { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search", handler = handle_expand_item_stations },
        { type = "label", style = "label" },
        { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "utility/search", handler = handle_expand_item_haulers },
        { type = "label", style = "label" },
    })
end

--------------------------------------------------------------------------------

---@param player_gui PlayerNetworkGui
---@param from_nothing boolean
---@param class_table LuaGuiElement
---@param classes {[ClassName]: Class}
---@param class_name ClassName
---@param i integer
local function populate_row_from_class(player_gui, from_nothing, class_table, classes, class_name, i)
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

    local table_children = class_table.children
    table_children[i + 7].toggled = class_name == player_gui.haulers_class
end

---@param player_gui PlayerNetworkGui
---@param from_nothing boolean
---@param item_table LuaGuiElement
---@param items {[ItemKey]: NetworkItem}
---@param item_key ItemKey
---@param i integer
local function populate_row_from_item(player_gui, from_nothing, item_table, items, item_key, i)
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

    local table_children = item_table.children
    table_children[i + 5].toggled = item_key == player_gui.stations_item
    table_children[i + 7].toggled = item_key == player_gui.haulers_item
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

    local delivery_size = tonumber(table_children[i + 3].text) or 1
    if delivery_size < 1 then delivery_size = 1 end

    local delivery_time = tonumber(table_children[i + 4].text) or 1.0
    if delivery_time < 1.0 then delivery_time = 1.0 end

    local name, quality, item_key = gui.extract_elem_value_fields(elem_value)
    return item_key, {
        list_index = list_index,
        name = name,
        quality = quality,
        class = table_children[i + 2].text,
        delivery_size = delivery_size,
        delivery_time = delivery_time,
    } --[[@as NetworkItem]]
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param from_nothing boolean
function gui.update_network_after_change(player_id, from_nothing)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]

    local network = storage.networks[player_gui.network]

    local class_table = player_gui.elements.class_table
    local classes = gui.generate_dict_from_table(class_table, generate_class_from_row)

    for class_name, _ in pairs(network.classes) do
        if not classes[class_name] then
            set_haulers_to_manual(network.fuel_haulers[class_name], { "sspp-alert.class-not-in-network" })
            set_haulers_to_manual(network.depot_haulers[class_name], { "sspp-alert.class-not-in-network" })
            if player_gui.haulers_class == class_name then
                clear_grid_and_header(player_gui)
            end
        end
    end
    network.classes = classes

    gui.populate_table_from_dict(from_nothing, class_table, classes, bind_1_of_6(populate_row_from_class, player_gui))

    local item_table = player_gui.elements.item_table
    local items = gui.generate_dict_from_table(item_table, generate_item_from_row)

    for item_key, _ in pairs(network.items) do
        if not items[item_key] then
            set_haulers_to_manual(network.provide_haulers[item_key], { "sspp-alert.cargo-not-in-network" }, item_key)
            set_haulers_to_manual(network.request_haulers[item_key], { "sspp-alert.cargo-not-in-network" }, item_key)
            if item_key == player_gui.haulers_item or item_key == player_gui.stations_item then
                clear_grid_and_header(player_gui)
            end
        end
    end
    network.items = items

    gui.populate_table_from_dict(from_nothing, item_table, items, bind_1_of_6(populate_row_from_item, player_gui))
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_open_hauler = { [events.on_gui_click] = function(event)
    game.get_player(event.player_index).opened = event.element.parent.entity
end }

---@param event EventData.on_gui_click
local handle_open_station = { [events.on_gui_click] = function(event)
    game.get_player(event.player_index).opened = event.element.parent.entity
end }

--------------------------------------------------------------------------------

---@param grid_table LuaGuiElement
---@param table_children LuaGuiElement[]
---@param old_length integer
---@param new_length integer
---@param for_station boolean
---@return LuaGuiElement
local function get_or_add_next_minimap(grid_table, table_children, old_length, new_length, for_station)
    if new_length > old_length then
        local zoom, open_handler
        if for_station then
            zoom, open_handler = 2.0, handle_open_station
        else
            zoom, open_handler = 1.0, handle_open_hauler
        end

        local outer_frame = grid_table.add({ type = "frame", style = "train_with_minimap_frame" })
        local inner_frame = outer_frame.add({ type = "frame", style = "deep_frame_in_shallow_frame" })
        local minimap = inner_frame.add({ type = "minimap", style = "sspp_minimap", zoom = zoom })

        minimap.add({ type = "button", style = "sspp_minimap_button", tags = flib_gui.format_handlers(open_handler) })
        if for_station then
            minimap.add({ type = "label", style = "sspp_minimap_top_label", ignored_by_interaction = true })
        end
        minimap.add({ type = "label", style = "sspp_minimap_bottom_label", ignored_by_interaction = true })

        return minimap
    end

    return table_children[new_length].children[1].children[1]
end

--------------------------------------------------------------------------------

---@param player_gui PlayerNetworkGui
function gui.network_poll_finished(player_gui)
    local network_name = player_gui.network
    local network = storage.networks[network_name]
    local elements = player_gui.elements

    local class_hauler_totals = {} ---@type {[ClassName]: integer}
    do
        local push_tickets = network.push_tickets
        local pull_tickets = network.pull_tickets

        local provide_haulers = network.provide_haulers
        local request_haulers = network.request_haulers
        local liquidate_haulers = network.liquidate_haulers

        local item_table = elements.item_table
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

        local class_table = elements.class_table
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

    local provide_enabled = elements.grid_provide_toggle.toggled or nil
    local request_enabled = elements.grid_request_toggle.toggled or nil
    local liquidate_enabled = elements.grid_liquidate_toggle.toggled or nil
    local fuel_enabled = elements.grid_fuel_toggle.toggled or nil
    local depot_enabled = elements.grid_depot_toggle.toggled or nil

    local grid_table = elements.grid_table
    local table_children = grid_table.children
    local old_length = #table_children
    local new_length = 0

    local haulers_class_name = player_gui.haulers_class
    if haulers_class_name then
        for _, hauler in pairs(storage.haulers) do
            if hauler.network == network_name and hauler.class == haulers_class_name then
                local name, quality, icon ---@type string?, string?, string?
                if provide_enabled and hauler.to_provide then
                    name, quality = split_item_key(hauler.to_provide.item)
                    icon = "[img=virtual-signal/up-arrow]"
                end
                if request_enabled and hauler.to_request then
                    name, quality = split_item_key(hauler.to_request.item)
                    icon = "[img=virtual-signal/down-arrow]"
                end
                if liquidate_enabled and hauler.to_liquidate then
                    name, quality = split_item_key(hauler.to_liquidate)
                    icon = "[img=virtual-signal/signal-skull]"
                end
                if fuel_enabled and hauler.to_fuel then
                    icon = "[img=sspp-fuel-icon]"
                end
                if depot_enabled and hauler.to_depot then
                    icon = "[img=sspp-depot-icon]"
                end
                if icon then
                    new_length = new_length + 1
                    local minimap = get_or_add_next_minimap(grid_table, table_children, old_length, new_length, false)
                    local minimap_children = minimap.children
                    if quality then
                        minimap_children[2].caption = "[item=" .. name .. ",quality=" .. quality .. "]" .. icon
                    elseif name then
                        minimap_children[2].caption = "[fluid=" .. name .. "]" .. icon
                    else
                        minimap_children[2].caption = icon
                    end
                    minimap.entity = hauler.train.front_stock
                end
            end
        end
    end

    local haulers_item_key = player_gui.haulers_item
    if haulers_item_key then
        for _, hauler in pairs(storage.haulers) do
            if hauler.network == network_name then
                local icon ---@type string?
                if provide_enabled and hauler.to_provide and hauler.to_provide.item == haulers_item_key then
                    icon = "[img=virtual-signal/up-arrow]"
                end
                if request_enabled and hauler.to_request and hauler.to_request.item == haulers_item_key then
                    icon = "[img=virtual-signal/down-arrow]"
                end
                if liquidate_enabled and hauler.to_liquidate == haulers_item_key then
                    icon = "[img=virtual-signal/signal-skull]"
                end
                if icon then
                    new_length = new_length + 1
                    local minimap = get_or_add_next_minimap(grid_table, table_children, old_length, new_length, false)
                    local minimap_children = minimap.children
                    minimap_children[2].caption = icon
                    minimap.entity = hauler.train.front_stock
                end
            end
        end
    end

    local stations_item_key = player_gui.stations_item
    if stations_item_key then
        local count_mode_enabled = elements.grid_stations_mode_switch.switch_state == "right" or nil
        for _, station in pairs(storage.stations) do
            if station.network == network_name then
                local value, icon ---@type integer?, string?
                if provide_enabled and station.provide_items and station.provide_items[stations_item_key] then
                    if count_mode_enabled then
                        value = station.provide_counts[stations_item_key]
                    else
                        value = len_or_zero(station.provide_deliveries[stations_item_key])
                    end
                    icon = "[img=virtual-signal/up-arrow]"
                end
                if request_enabled and station.request_items and station.request_items[stations_item_key] then
                    if count_mode_enabled then
                        value = station.request_counts[stations_item_key]
                    else
                        value = len_or_zero(station.request_deliveries[stations_item_key])
                    end
                    icon = "[img=virtual-signal/down-arrow]"
                end
                if value then
                    new_length = new_length + 1
                    local minimap = get_or_add_next_minimap(grid_table, table_children, old_length, new_length, true)
                    local minimap_children = minimap.children
                    minimap_children[2].caption = station.stop.backer_name
                    minimap_children[3].caption = tostring(value) .. icon
                    minimap.entity = station.stop
                end
            end
        end
    end

    for i = old_length, new_length + 1, -1 do
        table_children[i].destroy()
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_add_class = { [events.on_gui_click] = function(event)
    local class_table = storage.player_guis[event.player_index].elements.class_table
    add_new_class_row(class_table)
end }

---@param event EventData.on_gui_click
local handle_add_item = { [events.on_gui_click] = function(event)
    local item_table = storage.player_guis[event.player_index].elements.item_table
    add_new_item_row(item_table, "item-with-quality")
end }

---@param event EventData.on_gui_click
local handle_add_fluid = { [events.on_gui_click] = function(event)
    local item_table = storage.player_guis[event.player_index].elements.item_table
    add_new_item_row(item_table, "fluid")
end }

---@param event EventData.on_gui_click
local handle_close_window = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    assert(player.opened.name == "sspp-network")

    player.opened = nil
end }

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
            { type = "flow", style = "frame_header_flow", drag_target = "sspp-network", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.network-for-surface", localised_name }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = handle_close_window },
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
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-class" }, mouse_button_filter = { "left" }, handler = handle_add_class },
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
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, mouse_button_filter = { "left" }, handler = handle_add_item },
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, mouse_button_filter = { "left" }, handler = handle_add_fluid },
                                } },
                            } },
                        },
                    } },
                } },
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", name = "grid_title", style = "subheader_caption_label" },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        { type = "switch", name = "grid_stations_mode_switch", style = "switch", left_label_caption = "[item=locomotive]", right_label_caption = "[item=sspp-stop]", left_label_tooltip = { "sspp-gui.grid-stations-hauler-tooltip" }, right_label_tooltip = { "sspp-gui.grid-stations-station-tooltip" }, visible = false },
                        { type = "sprite-button", name = "grid_provide_toggle", style = "control_settings_section_button", sprite = "virtual-signal/up-arrow", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_request_toggle", style = "control_settings_section_button", sprite = "virtual-signal/down-arrow", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_liquidate_toggle", style = "control_settings_section_button", sprite = "virtual-signal/signal-skull", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_fuel_toggle", style = "control_settings_section_button", sprite = "sspp-fuel-icon", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_depot_toggle", style = "control_settings_section_button", sprite = "sspp-depot-icon", enabled = false, auto_toggle = true, toggled = true },
                    } },
                    { type = "scroll-pane", style = "sspp_network_grid_scroll_pane", direction = "vertical", vertical_scroll_policy = "always", children = {
                        { type = "table", name = "grid_table", style = "sspp_network_grid_table", column_count = 3 },
                    } },
                } },
            } },
        } },
    })

    window.force_auto_center()

    local player_gui = { network = network_name, elements = elements }
    storage.player_guis[player_id] = player_gui

    gui.populate_table_from_dict(true, elements.class_table, network.classes, bind_1_of_6(populate_row_from_class, player_gui))
    gui.populate_table_from_dict(true, elements.item_table, network.items, bind_1_of_6(populate_row_from_item, player_gui))

    player.opened = window
end

---@param player_id PlayerId
---@param window LuaGuiElement
function gui.network_closed(player_id, window)
    assert(window.name == "sspp-network")
    window.destroy()

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.network_add_flib_handlers()
    flib_gui.add_handlers({
        ["network_class_delete"] = handle_class_delete[events.on_gui_click],
        ["network_class_name_changed"] = handle_class_name_changed[events.on_gui_text_changed],
        ["network_class_item_capacity_changed"] = handle_class_item_capacity_changed[events.on_gui_text_changed],
        ["network_class_fluid_capacity_changed"] = handle_class_fluid_capacity_changed[events.on_gui_text_changed],
        ["network_class_depot_name_changed"] = handle_class_depot_name_changed[events.on_gui_text_changed],
        ["network_class_fueler_name_changed"] = handle_class_fueler_name_changed[events.on_gui_text_changed],
        ["network_item_resource_changed"] = handle_item_resource_changed[events.on_gui_elem_changed],
        ["network_item_class_changed"] = handle_item_class_changed[events.on_gui_text_changed],
        ["network_item_delivery_size_changed"] = handle_item_delivery_size_changed[events.on_gui_text_changed],
        ["network_item_delivery_time_changed"] = handle_item_delivery_time_changed[events.on_gui_text_changed],
        ["network_expand_class_haulers"] = handle_expand_class_haulers[events.on_gui_click],
        ["network_expand_item_haulers"] = handle_expand_item_haulers[events.on_gui_click],
        ["network_expand_item_stations"] = handle_expand_item_stations[events.on_gui_click],
        ["network_open_hauler"] = handle_open_hauler[events.on_gui_click],
        ["network_open_station"] = handle_open_station[events.on_gui_click],
        ["network_add_class"] = handle_add_class[events.on_gui_click],
        ["network_add_item"] = handle_add_item[events.on_gui_click],
        ["network_add_fluid"] = handle_add_fluid[events.on_gui_click],
        ["network_close_window"] = handle_close_window[events.on_gui_click],
    })
end
