-- SSPP by jagoly

local flib_gui = require("__flib__.gui")
local events = defines.events
local cwi = gui.caption_with_info

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_class_move = { [events.on_gui_click] = function(event)
    local flow = event.element.parent.parent --[[@as LuaGuiElement]]
    gui.move_row(flow.parent, flow.get_index_in_parent(), event.element.get_index_in_parent())
    gui.update_network_after_change(event.player_index)
end }

local handle_class_copy = {} -- defined later

---@param event EventData.on_gui_click
local handle_class_delete = { [events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    gui.delete_row(flow.parent, flow.get_index_in_parent())
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_class_name_changed = { [events.on_gui_text_changed] = function(event)
    gui.truncate_input(event.element, 199)
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_click
local handle_class_bypass_depot_changed = { [events.on_gui_click] = function(event)
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_class_depot_name_changed = { [events.on_gui_text_changed] = function(event)
    gui.truncate_input(event.element, 199)
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_class_fueler_name_changed = { [events.on_gui_text_changed] = function(event)
    gui.truncate_input(event.element, 199)
    gui.update_network_after_change(event.player_index)
end }

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_item_move = { [events.on_gui_click] = function(event)
    local flow = event.element.parent.parent --[[@as LuaGuiElement]]
    gui.move_row(flow.parent, flow.get_index_in_parent(), event.element.get_index_in_parent())
    gui.update_network_after_change(event.player_index)
end }

local handle_item_copy = {} -- defined later

---@param event EventData.on_gui_elem_changed
local handle_item_resource_changed = { [events.on_gui_elem_changed] = function(event)
    if not event.element.elem_value then
        local flow = event.element.parent --[[@as LuaGuiElement]]
        gui.delete_row(flow.parent, flow.get_index_in_parent())
    end
    -- TODO: check for recursive spoilage
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_item_class_changed = { [events.on_gui_text_changed] = function(event)
    gui.truncate_input(event.element, 199)
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_item_delivery_size_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_item_delivery_time_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_network_after_change(event.player_index)
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
    local class_name = element.parent.children[element.get_index_in_parent() - 4].text
    if class_name == "" then
        gui.update_network_after_change(event.player_index)
        return
    end

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
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_click
local handle_expand_item_haulers = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local element = event.element
    local elem_value = element.parent.children[element.get_index_in_parent() - 6].children[3].elem_value
    if not elem_value then
        gui.update_network_after_change(event.player_index)
        return
    end

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
    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_click
local handle_expand_item_stations = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local element = event.element
    local elem_value = element.parent.children[element.get_index_in_parent() - 4].children[3].elem_value
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
    gui.update_network_after_change(event.player_index)
end }

--------------------------------------------------------------------------------

---@param class_table LuaGuiElement
local function add_new_class_row(class_table)
    flib_gui.add(class_table, {
        { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
            { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = handle_class_move },
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = handle_class_move },
            } },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = handle_class_copy },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-delete-icon", handler = handle_class_delete },
            { type = "sprite", style = "sspp_compact_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
        } },
        { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = handle_class_name_changed },
        { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = handle_class_depot_name_changed },
        { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = handle_class_fueler_name_changed },
        { type = "checkbox", style = "checkbox", state = true, handler = handle_class_bypass_depot_changed },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = handle_expand_class_haulers },
        { type = "label", style = "label" },
    })
end

---@param item_table LuaGuiElement
---@param elem_type string
local function add_new_item_row(item_table, elem_type)
    flib_gui.add(item_table, {
        { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
            { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = handle_item_move },
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = handle_item_move },
            } },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = handle_item_copy },
            { type = "choose-elem-button", style = "sspp_compact_slot_button", elem_type = elem_type, handler = handle_item_resource_changed },
            { type = "sprite", style = "sspp_compact_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
        } },
        { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = handle_item_class_changed },
        { type = "textfield", style = "sspp_wide_number_textbox", numeric = true, text = "1", handler = handle_item_delivery_size_changed },
        { type = "textfield", style = "sspp_wide_number_textbox", numeric = true, text = "1", handler = handle_item_delivery_time_changed },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = handle_expand_item_stations },
        { type = "label", style = "label" },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = handle_expand_item_haulers },
        { type = "label", style = "label" },
    })
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
handle_class_copy[events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    local table = flow.parent --[[@as LuaGuiElement]]

    add_new_class_row(table)
    local i = flow.get_index_in_parent() - 1
    local j = i + table.column_count
    gui.insert_newly_added_row(table, j)

    local table_children = table.children
    table_children[j + 3].text = table_children[i + 3].text
    table_children[j + 4].text = table_children[i + 4].text
    table_children[j + 5].state = table_children[i + 5].state
end

---@param event EventData.on_gui_click
handle_item_copy[events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    local table = flow.parent --[[@as LuaGuiElement]]

    add_new_item_row(table, flow.children[3].elem_type)
    local i = flow.get_index_in_parent() - 1
    local j = i + table.column_count
    gui.insert_newly_added_row(table, j)

    local table_children = table.children
    table_children[j + 2].text = table_children[i + 2].text
    table_children[j + 3].text = table_children[i + 3].text
    table_children[j + 4].text = table_children[i + 4].text
end

--------------------------------------------------------------------------------

---@param class_table LuaGuiElement
---@param class_name ClassName
---@param class Class
local function class_init_row(class_table, class_name, class)
    add_new_class_row(class_table)

    local table_children = class_table.children
    local i = #table_children - class_table.column_count

    table_children[i + 1].children[4].sprite = ""
    table_children[i + 1].children[4].tooltip = nil
    table_children[i + 2].text = class_name
    table_children[i + 3].text = class.depot_name
    table_children[i + 4].text = class.fueler_name
    table_children[i + 5].state = class.bypass_depot
end

---@param table_children LuaGuiElement[]
---@param i integer
---@return ClassName?, Class?
local function class_from_row(table_children, i)
    local class_name = table_children[i + 2].text
    if class_name == "" then return end

    local depot_name = table_children[i + 3].text
    if depot_name == "" then return end

    local fueler_name = table_children[i + 4].text
    if fueler_name == "" then return end

    return class_name, {
        depot_name = depot_name,
        fueler_name = fueler_name,
        bypass_depot = table_children[i + 5].state,
    } --[[@as Class]]
end

---@param player_gui PlayerNetworkGui
---@param table_children LuaGuiElement[]
---@param i integer
---@param class_name ClassName?
---@param class Class?
local function class_to_row(player_gui, table_children, i, class_name, class)
    if class_name then
        table_children[i + 1].children[4].sprite = ""
        table_children[i + 1].children[4].tooltip = nil
        table_children[i + 6].toggled = class_name == player_gui.haulers_class
    else
        table_children[i + 1].children[4].sprite = "utility/achievement_warning"
        table_children[i + 1].children[4].tooltip = { "sspp-gui.invalid-values-tooltip" }
        table_children[i + 6].toggled = false
    end
end

---@param player_gui PlayerNetworkGui
---@param class_name ClassName
local function class_remove_key(player_gui, class_name)
    local network = storage.networks[player_gui.network]

    set_haulers_to_manual(network.fuel_haulers[class_name], { "sspp-alert.class-not-in-network" })
    set_haulers_to_manual(network.to_depot_haulers[class_name], { "sspp-alert.class-not-in-network" })
    set_haulers_to_manual(network.at_depot_haulers[class_name], { "sspp-alert.class-not-in-network" })

    if player_gui.haulers_class == class_name then clear_grid_and_header(player_gui) end
end

--------------------------------------------------------------------------------

---@param item_table LuaGuiElement
---@param item_key ItemKey
---@param item NetworkItem
local function item_init_row(item_table, item_key, item)
    local name, quality = item.name, item.quality
    add_new_item_row(item_table, quality and "item-with-quality" or "fluid")

    local table_children = item_table.children
    local i = #table_children - item_table.column_count

    table_children[i + 1].children[3].elem_value = quality and { name = name, quality = quality } or name
    table_children[i + 1].children[4].sprite = ""
    table_children[i + 1].children[4].tooltip = nil
    table_children[i + 2].text = item.class
    table_children[i + 3].text = tostring(item.delivery_size)
    table_children[i + 4].text = tostring(item.delivery_time)
end

---@param table_children LuaGuiElement[]
---@param i integer
---@return ItemKey?, NetworkItem?
local function item_from_row(table_children, i)
    local elem_value = table_children[i + 1].children[3].elem_value ---@type (table|string)?
    if not elem_value then return end

    local class = table_children[i + 2].text
    if class == "" then return end -- NOTE: class does not need to actually exist yet

    local delivery_size = tonumber(table_children[i + 3].text)
    if not delivery_size then return end

    local delivery_time = tonumber(table_children[i + 4].text)
    if not delivery_time then return end

    if delivery_size < 1 or delivery_time < 1.0 then return end

    local name, quality, item_key = gui.extract_elem_value_fields(elem_value)
    return item_key, {
        name = name,
        quality = quality,
        class = class,
        delivery_size = delivery_size,
        delivery_time = delivery_time,
    } --[[@as NetworkItem]]
end

---@param player_gui PlayerNetworkGui
---@param table_children LuaGuiElement[]
---@param i integer
---@param item_key ItemKey?
---@param item NetworkItem?
local function item_to_row(player_gui, table_children, i, item_key, item)
    if item_key then
        table_children[i + 1].children[4].sprite = ""
        table_children[i + 1].children[4].tooltip = nil
        table_children[i + 5].toggled = item_key == player_gui.stations_item
        table_children[i + 7].toggled = item_key == player_gui.haulers_item
    else
        table_children[i + 1].children[4].sprite = "utility/achievement_warning"
        table_children[i + 1].children[4].tooltip = { "sspp-gui.invalid-values-tooltip" }
        table_children[i + 5].toggled = false
        table_children[i + 7].toggled = false
    end
end

---@param player_gui PlayerNetworkGui
---@param item_key ItemKey
local function item_remove_key(player_gui, item_key)
    local network = storage.networks[player_gui.network]

    set_haulers_to_manual(network.provide_haulers[item_key], { "sspp-alert.cargo-not-in-network" }, item_key)
    set_haulers_to_manual(network.request_haulers[item_key], { "sspp-alert.cargo-not-in-network" }, item_key)

    if item_key == player_gui.haulers_item then clear_grid_and_header(player_gui) end
    if item_key == player_gui.stations_item then clear_grid_and_header(player_gui) end
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
function gui.update_network_after_change(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]

    local network = storage.networks[player_gui.network]

    network.classes = gui.refresh_table(
        player_gui.elements.class_table,
        class_from_row,
        function(b, c, d, e) return class_to_row(player_gui, b, c, d, e) end,
        network.classes,
        function(b) return class_remove_key(player_gui, b) end
    )

    network.items = gui.refresh_table(
        player_gui.elements.item_table,
        item_from_row,
        function(b, c, d, e) return item_to_row(player_gui, b, c, d, e) end,
        network.items,
        function(b) return item_remove_key(player_gui, b) end
    )
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
        local to_depot_liquidate_haulers = network.to_depot_liquidate_haulers
        local at_depot_liquidate_haulers = network.at_depot_liquidate_haulers

        local item_table = elements.item_table
        local columns = item_table.column_count
        local table_children = item_table.children

        for i = columns, #table_children - 1, columns do
            if table_children[i + 1].children[4].sprite == "" then
                local _, _, item_key = gui.extract_elem_value_fields(table_children[i + 1].children[3].elem_value)

                local provide_total = len_or_zero(provide_haulers[item_key])
                local request_total = len_or_zero(request_haulers[item_key])
                local liquidate_total = len_or_zero(to_depot_liquidate_haulers[item_key]) + len_or_zero(at_depot_liquidate_haulers[item_key])

                table_children[i + 6].caption = { "sspp-gui.fmt-item-demand", len_or_zero(push_tickets[item_key]), len_or_zero(pull_tickets[item_key]) }
                table_children[i + 8].caption = { "sspp-gui.fmt-item-haulers", provide_total, request_total, liquidate_total }

                local class_name = table_children[i + 2].text
                class_hauler_totals[class_name] = (class_hauler_totals[class_name] or 0) + provide_total + request_total + liquidate_total
            else
                table_children[i + 6].caption = ""
                table_children[i + 8].caption = ""
            end
        end
    end

    do
        local fuel_haulers = network.fuel_haulers
        local to_depot_haulers = network.to_depot_haulers
        local at_depot_haulers = network.at_depot_haulers
        local classes = network.classes

        local class_table = elements.class_table
        local columns = class_table.column_count
        local table_children = class_table.children

        for i = columns, #table_children - 1, columns do
            if table_children[i + 1].children[4].sprite == "" then
                local class_name = table_children[i + 2].text
                local class = classes[class_name]

                local available = len_or_zero(at_depot_haulers[class_name])
                local total = (class_hauler_totals[class_name] or 0) + len_or_zero(fuel_haulers[class_name])
                if class.bypass_depot then
                    available = available + len_or_zero(to_depot_haulers[class_name])
                else
                    total = total + len_or_zero(to_depot_haulers[class_name])
                end
                total = total + available

                table_children[i + 7].caption = { "sspp-gui.fmt-class-available", available, total }
            else
                table_children[i + 7].caption = ""
            end
        end
    end

    local provide_enabled = elements.grid_provide_toggle.toggled
    local request_enabled = elements.grid_request_toggle.toggled
    local liquidate_enabled = elements.grid_liquidate_toggle.toggled
    local fuel_enabled = elements.grid_fuel_toggle.toggled
    local depot_enabled = elements.grid_depot_toggle.toggled

    local grid_table = elements.grid_table
    local grid_children = grid_table.children
    local old_length = #grid_children
    local new_length = 0

    local haulers_class_name = player_gui.haulers_class
    if haulers_class_name then
        for _, hauler in pairs(storage.haulers) do
            if hauler.network == network_name and hauler.class == haulers_class_name then
                local name, quality ---@type string?, string?
                local state_icon ---@type string?
                if provide_enabled and hauler.to_provide then
                    name, quality = split_item_key(hauler.to_provide.item)
                    state_icon = "[img=virtual-signal/up-arrow]"
                end
                if request_enabled and hauler.to_request then
                    name, quality = split_item_key(hauler.to_request.item)
                    state_icon = "[img=virtual-signal/down-arrow]"
                end
                if liquidate_enabled then
                    local item_key = hauler.to_depot or hauler.at_depot
                    if item_key and item_key ~= "" then
                        name, quality = split_item_key(item_key)
                        state_icon = "[img=virtual-signal/signal-skull]"
                    end
                end
                if fuel_enabled and hauler.to_fuel then
                    state_icon = "[img=sspp-fuel-icon]"
                end
                if depot_enabled and (hauler.to_depot or hauler.at_depot) == "" then
                    state_icon = "[img=sspp-depot-icon]"
                end
                if state_icon then
                    new_length = new_length + 1
                    local minimap = gui.next_minimap(grid_table, grid_children, old_length, new_length, 1.0, handle_open_hauler)
                    minimap.children[2].caption = state_icon
                    if name then
                        minimap.children[3].caption = tostring(get_train_item_count(hauler.train, name, quality)) .. make_item_icon(name, quality)
                    else
                        minimap.children[3].caption = ""
                    end
                    minimap.entity = hauler.train.front_stock
                end
            end
        end
    end

    local haulers_item_key = player_gui.haulers_item
    if haulers_item_key then
        local name, quality = split_item_key(haulers_item_key)
        local item_icon = make_item_icon(name, quality)
        for _, hauler in pairs(storage.haulers) do
            if hauler.network == network_name then
                local state_icon ---@type string?
                if provide_enabled and hauler.to_provide and hauler.to_provide.item == haulers_item_key then
                    state_icon = "[img=virtual-signal/up-arrow]"
                end
                if request_enabled and hauler.to_request and hauler.to_request.item == haulers_item_key then
                    state_icon = "[img=virtual-signal/down-arrow]"
                end
                if liquidate_enabled then
                    local item_key = hauler.to_depot or hauler.at_depot
                    if item_key and item_key ~= "" then
                        state_icon = "[img=virtual-signal/signal-skull]"
                    end
                end
                if state_icon then
                    new_length = new_length + 1
                    local minimap = gui.next_minimap(grid_table, grid_children, old_length, new_length, 1.0, handle_open_hauler)
                    minimap.children[2].caption = state_icon
                    minimap.children[3].caption = tostring(get_train_item_count(hauler.train, name, quality)) .. item_icon
                    minimap.entity = hauler.train.front_stock
                end
            end
        end
    end

    local stations_item_key = player_gui.stations_item
    if stations_item_key then
        local item_icon ---@type string?
        if elements.grid_stations_mode_switch.switch_state == "right" then
            local name, quality = split_item_key(stations_item_key)
            item_icon = make_item_icon(name, quality)
        end
        for _, station in pairs(storage.stations) do
            if station.network == network_name then
                if provide_enabled and station.provide_items and station.provide_items[stations_item_key] then
                    new_length = new_length + 1
                    local minimap = gui.next_minimap(grid_table, grid_children, old_length, new_length, 1.0, handle_open_station)
                    minimap.children[2].caption = station.stop.backer_name
                    if item_icon then
                        minimap.children[3].caption = "+" .. tostring(station.provide_counts[stations_item_key]) .. item_icon
                    else
                        minimap.children[3].caption = tostring(len_or_zero(station.provide_deliveries[stations_item_key])) .. "[img=virtual-signal/up-arrow]"
                    end
                    minimap.entity = station.stop
                end
                if request_enabled and station.request_items and station.request_items[stations_item_key] then
                    new_length = new_length + 1
                    local minimap = gui.next_minimap(grid_table, grid_children, old_length, new_length, 1.0, handle_open_station)
                    minimap.children[2].caption = station.stop.backer_name
                    if item_icon then
                        minimap.children[3].caption = "-" .. tostring(station.request_counts[stations_item_key]) .. item_icon
                    else
                        minimap.children[3].caption = tostring(len_or_zero(station.request_deliveries[stations_item_key])) .. "[img=virtual-signal/down-arrow]"
                    end
                    minimap.entity = station.stop
                end
            end
        end
    end

    for i = old_length, new_length + 1, -1 do
        grid_children[i].destroy()
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

---@param event EventData.on_gui_click
local handle_import_import = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]

    do
        local network = storage.networks[player_gui.network]

        local json = helpers.json_to_table(player_gui.popup_elements.textbox.text) --[[@as table]]
        if type(json) ~= "table" then goto failure end

        local version = json.sspp_network_version
        if version ~= 1 then goto failure end

        local classes = json.classes ---@type {[ClassName]: Class}
        if type(classes) ~= "table" then goto failure end

        local items = json.items ---@type {[ItemKey]: NetworkItem}
        if type(items) ~= "table" then goto failure end

        for class_name, class in pairs(classes) do
            if type(class_name) ~= "string" or class_name == "" or #class_name > 199 then goto failure end
            if type(class) ~= "table" then goto failure end

            local depot_name = class[1]
            if type(depot_name) ~= "string" or depot_name == "" or #depot_name > 199 then goto failure end

            local fueler_name = class[2]
            if type(fueler_name) ~= "string" or fueler_name == "" or #fueler_name > 199 then goto failure end

            local bypass_depot = class[3]
            if type(bypass_depot) ~= "boolean" then goto failure end

            classes[class_name] = { depot_name = depot_name, fueler_name = fueler_name, bypass_depot = bypass_depot }
        end

        for item_key, item in pairs(items) do
            if type(item_key) ~= "string" then goto failure end

            if is_item_key_invalid(item_key) then
                items[item_key] = nil -- not an error, just skip this item
            else
                if type(item) ~= "table" then goto failure end

                local class = item[1]
                if type(class) ~= "string" or class == "" or #class > 199 then goto failure end

                local delivery_size = item[2]
                if type(delivery_size) ~= "number" or delivery_size < 1 then goto failure end

                local delivery_time = item[3]
                if type(delivery_time) ~= "number" or delivery_time < 1.0 then goto failure end

                local name, quality = split_item_key(item_key)
                items[item_key] = { name = name, quality = quality, class = class, delivery_size = delivery_size, delivery_time = delivery_time }
            end
        end

        if next(classes) == nil and next(items) == nil then goto failure end

        for class_name, _ in pairs(network.classes) do
            if not classes[class_name] then class_remove_key(player_gui, class_name) end
        end
        local class_table = player_gui.elements.class_table
        local class_children = class_table.children
        for i = #class_children, class_table.column_count + 1, -1 do class_children[i].destroy() end
        network.classes = classes
        for class_name, class in pairs(classes) do class_init_row(class_table, class_name, class) end

        for item_key, _ in pairs(network.items) do
            if not items[item_key] then item_remove_key(player_gui, item_key) end
        end
        local item_table = player_gui.elements.item_table
        local item_children = item_table.children
        for i = #item_children, item_table.column_count + 1, -1 do item_children[i].destroy() end
        network.items = items
        for item_key, item in pairs(items) do item_init_row(item_table, item_key, item) end

        return
    end

    ::failure::
    game.get_player(player_id).play_sound({ path = "utility/cannot_build" })
    player_gui.popup_elements.textbox.focus()
    player_gui.popup_elements.textbox.select_all()
end }

---@param event EventData.on_gui_click
local handle_export_export = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]
    local network = storage.networks[player_gui.network]

    local classes = {}
    for class_name, class in pairs(network.classes) do
        classes[class_name] = { class.depot_name, class.fueler_name, class.bypass_depot }
    end
    local items = {}
    for item_key, item in pairs(network.items) do
        items[item_key] = { item.class, item.delivery_size, item.delivery_time }
    end
    local json = { sspp_network_version = 1, classes = classes, items = items }

    player_gui.popup_elements.textbox.text = helpers.table_to_json(json)
    player_gui.popup_elements.textbox.focus()
    player_gui.popup_elements.textbox.select_all()
end }

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param toggle LuaGuiElement
---@param caption string
---@param handler table
local function import_or_export_toggled(player_id, toggle, caption, handler)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]

    if player_gui.popup_elements then
        player_gui.popup_elements["sspp-popup"].destroy()
        player_gui.popup_elements = nil
        if not toggle.toggled then return end
    end

    local elements, window = flib_gui.add(game.get_player(player_id).gui.screen, {
        { type = "frame", name = "sspp-popup", style = "frame", direction = "vertical", children = {
            { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                { type = "textfield", name = "textbox", style = "sspp_json_textbox" },
            } },
            { type = "flow", style = "dialog_buttons_horizontal_flow", direction = "horizontal", children = {
                { type = "button", style = "dialog_button", caption = { caption }, mouse_button_filter = { "left" }, handler = handler },
                { type = "empty-widget", style = "flib_dialog_footer_drag_handle_no_right", drag_target = "sspp-popup" },
            } },
        } },
    })

    window.bring_to_front()
    window.force_auto_center()

    player_gui.popup_elements = elements
end

---@param event EventData.on_gui_click
local handle_import_toggled = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]
    player_gui.elements.export_toggle.toggled = false
    import_or_export_toggled(player_id, event.element, "sspp-gui.import-from-string", handle_import_import)
    if player_gui.popup_elements then player_gui.popup_elements.textbox.focus() end
end }

---@param event EventData.on_gui_click
local handle_export_toggled = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]
    player_gui.elements.import_toggle.toggled = false
    import_or_export_toggled(player_id, event.element, "sspp-gui.export-to-string", handle_export_export)
end }

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param network_name NetworkName
---@param tab_index integer
function gui.network_open(player_id, network_name, tab_index)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]
    local network = storage.networks[network_name]

    player.opened = nil

    local localised_name = network_name ---@type string|LocalisedString
    if network.surface.planet then
        localised_name = network.surface.planet.prototype.localised_name
    elseif network.surface.localised_name then
        localised_name = network.surface.localised_name
    end

    local elements, window = flib_gui.add(player.gui.screen, {
        { type = "frame", name = "sspp-network", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", direction = "horizontal", drag_target = "sspp-network", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.network-for-surface", localised_name }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "sprite-button", name = "import_toggle", style = "frame_action_button", sprite = "sspp-import-icon", tooltip = { "sspp-gui.import-from-string" }, mouse_button_filter = { "left" }, auto_toggle = true, handler = handle_import_toggled },
                { type = "sprite-button", name = "export_toggle", style = "frame_action_button", sprite = "sspp-export-icon", tooltip = { "sspp-gui.export-to-string" }, mouse_button_filter = { "left" }, auto_toggle = true, handler = handle_export_toggled },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", mouse_button_filter = { "left" }, handler = handle_close_window },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", direction = "horizontal", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "tabbed-pane", name = "tabbed_pane", style = "tabbed_pane", children = {
                        ---@diagnostic disable-next-line: missing-fields
                        {
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.classes" } },
                            content = { type = "scroll-pane", style = "sspp_network_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "class_table", style = "sspp_network_class_table", column_count = 7, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.name" }), tooltip = { "sspp-gui.class-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.depot-name" }), tooltip = { "sspp-gui.class-depot-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.fueler-name" }), tooltip = { "sspp-gui.class-fueler-name-tooltip" } },
                                    { type = "label", caption = "[img=sspp-bypass-icon]", tooltip = { "sspp-gui.class-bypass-depot-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=locomotive]" },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.available" }), tooltip = { "sspp-gui.class-available-tooltip" } },
                                } },
                                { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
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
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.class" }), tooltip = { "sspp-gui.item-class-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-size" }), tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-time" }), tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=sspp-stop]" },
                                    { type = "label", style = "bold_label", caption = "[virtual-signal=up-arrow][virtual-signal=down-arrow]", tooltip = { "sspp-gui.item-demand-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=locomotive]" },
                                    { type = "label", style = "bold_label", caption = "[virtual-signal=up-arrow][virtual-signal=down-arrow][virtual-signal=signal-skull]", tooltip = { "sspp-gui.item-haulers-tooltip" } },
                                } },
                                { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
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
                    { type = "scroll-pane", style = "sspp_grid_scroll_pane", direction = "vertical", vertical_scroll_policy = "always", children = {
                        { type = "table", name = "grid_table", style = "sspp_grid_table", column_count = 3 },
                    } },
                } },
            } },
        } },
    })

    elements.tabbed_pane.selected_tab_index = tab_index
    window.force_auto_center()

    local player_gui = { network = network_name, elements = elements }
    storage.player_guis[player_id] = player_gui

    local class_table = elements.class_table
    for class_name, class in pairs(network.classes) do class_init_row(class_table, class_name, class) end

    local item_table = elements.item_table
    for item_key, item in pairs(network.items) do item_init_row(item_table, item_key, item) end

    player.opened = window
end

---@param player_id PlayerId
function gui.network_closed(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]

    player_gui.elements["sspp-network"].destroy()
    if player_gui.popup_elements then player_gui.popup_elements["sspp-popup"].destroy() end

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.network_add_flib_handlers()
    flib_gui.add_handlers({
        ["network_class_move"] = handle_class_move[events.on_gui_click],
        ["network_class_copy"] = handle_class_copy[events.on_gui_click],
        ["network_class_delete"] = handle_class_delete[events.on_gui_click],
        ["network_class_name_changed"] = handle_class_name_changed[events.on_gui_text_changed],
        ["network_class_bypass_depot_changed"] = handle_class_bypass_depot_changed[events.on_gui_click],
        ["network_class_depot_name_changed"] = handle_class_depot_name_changed[events.on_gui_text_changed],
        ["network_class_fueler_name_changed"] = handle_class_fueler_name_changed[events.on_gui_text_changed],
        ["network_item_move"] = handle_item_move[events.on_gui_click],
        ["network_item_copy"] = handle_item_copy[events.on_gui_click],
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
        ["network_import_toggled"] = handle_import_toggled[events.on_gui_click],
        ["network_export_toggled"] = handle_export_toggled[events.on_gui_click],
        ["network_import_import"] = handle_import_import[events.on_gui_click],
        ["network_export_export"] = handle_export_export[events.on_gui_click],
        ["network_close_window"] = handle_close_window[events.on_gui_click],
    })
end
