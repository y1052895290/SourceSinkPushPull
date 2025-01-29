-- SSPP by jagoly

local flib_gui = require("__flib__.gui")
local events = defines.events

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_item_move = { [events.on_gui_click] = function(event)
    local flow = event.element.parent.parent --[[@as LuaGuiElement]]
    gui.move_row(flow.parent, flow.get_index_in_parent(), event.element.get_index_in_parent())
    gui.update_station_after_change(event.player_index)
end }

local handle_provide_copy = {} -- defined later

local handle_request_copy = {} -- defined later

---@param event EventData.on_gui_elem_changed
local handle_item_elem_changed = { [events.on_gui_elem_changed] = function(event)
    if not event.element.elem_value then
        gui.delete_row(event.element.parent, event.element.get_index_in_parent() - 1)
    end
    gui.update_station_after_change(event.player_index)
end }

---@param event EventData.on_gui_text_changed
local handle_item_text_changed = { [events.on_gui_text_changed] = function(event)
    gui.update_station_after_change(event.player_index)
end }

---@param event EventData.on_gui_switch_state_changed
local handle_item_switch_state_changed = { [events.on_gui_switch_state_changed] = function(event)
    gui.update_station_after_change(event.player_index)
end }

--------------------------------------------------------------------------------

---@param caption string
---@param tooltip string?
---@param def flib.GuiElemDef
---@return flib.GuiElemDef
local function make_property_flow(caption, tooltip, def)
    return {
        type = "flow", style = "sspp_station_item_property_flow",
        children = {
            { type = "label", style = "sspp_station_item_key", caption = { caption }, tooltip = tooltip and { tooltip } },
            def,
        },
    } --[[@as flib.GuiElemDef]]
end

---@param def flib.GuiElemDef
---@return flib.GuiElemDef
local function make_center_flow(def)
    return {
        type = "flow", style = "sspp_station_item_property_flow",
        children = {
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            def,
            { type = "empty-widget", style = "flib_horizontal_pusher" },
        },
    } --[[@as flib.GuiElemDef]]
end

---@param provide_table LuaGuiElement
---@param elem_type string
local function add_new_provide_row(provide_table, elem_type)
    flib_gui.add(provide_table, {
        { type = "flow", direction = "vertical", children = {
            { type = "flow", direction = "vertical", style = "packed_vertical_flow", children = {
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = handle_item_move },
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = handle_item_move },
            } },
            { type = "sprite", style = "sspp_compact_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = handle_provide_copy },
        } },
        { type = "choose-elem-button", style = "big_slot_button", elem_type = elem_type, handler = handle_item_elem_changed },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_property_flow("sspp-gui.class", nil, {
                type = "label", style = "sspp_station_item_value",
            }),
            make_property_flow("sspp-gui.delivery-size", nil, {
                type = "label", style = "sspp_station_item_value",
            }),
            make_property_flow("sspp-gui.delivery-time", nil, {
                type = "label", style = "sspp_station_item_value",
            }),
        } },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_center_flow({
                type = "switch", style = "sspp_aligned_switch",
                left_label_caption = { "sspp-gui.source" }, right_label_caption = { "sspp-gui.push" }, tooltip = { "sspp-gui.provide-mode-tooltip" },
                switch_state = "left", handler = handle_item_switch_state_changed,
            }),
            make_property_flow("sspp-gui.throughput", "sspp-gui.provide-throughput-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "", handler = handle_item_text_changed,
            }),
            make_property_flow("sspp-gui.latency", "sspp-gui.provide-latency-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "30", handler = handle_item_text_changed,
            }),
            make_property_flow("sspp-gui.granularity", "sspp-gui.provide-granularity-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true,
                text = "1", handler = handle_item_text_changed,
            }),
        } },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_property_flow("sspp-gui.storage-needed", "sspp-gui.provide-storage-needed-tooltip", {
                type = "label", style = "sspp_station_item_value",
            }),
            make_property_flow("sspp-gui.current-surplus", "sspp-gui.provide-current-surplus-tooltip", {
                type = "label", style = "sspp_station_item_value",
            }),
        } },
    })
end

---@param request_table LuaGuiElement
---@param elem_type string
local function add_new_request_row(request_table, elem_type)
    flib_gui.add(request_table, {
        { type = "flow", direction = "vertical", children = {
            { type = "flow", direction = "vertical", style = "packed_vertical_flow", children = {
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = handle_item_move },
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = handle_item_move },
            } },
            { type = "sprite", style = "sspp_compact_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = handle_request_copy },
        } },
        { type = "choose-elem-button", style = "big_slot_button", elem_type = elem_type, handler = handle_item_elem_changed },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_property_flow("sspp-gui.class", nil, {
                type = "label", style = "sspp_station_item_value",
            }),
            make_property_flow("sspp-gui.delivery-size", nil, {
                type = "label", style = "sspp_station_item_value",
            }),
            make_property_flow("sspp-gui.delivery-time", nil, {
                type = "label", style = "sspp_station_item_value",
            }),
        } },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_center_flow({
                type = "switch", style = "sspp_aligned_switch",
                left_label_caption = { "sspp-gui.sink" }, right_label_caption = { "sspp-gui.pull" }, tooltip = { "sspp-gui.request-mode-tooltip" },
                switch_state = "left", handler = handle_item_switch_state_changed,
            }),
            make_property_flow("sspp-gui.throughput", "sspp-gui.request-throughput-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "", handler = handle_item_text_changed,
            }),
            make_property_flow("sspp-gui.latency", "sspp-gui.request-latency-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "30", handler = handle_item_text_changed,
            }),
        } },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_property_flow("sspp-gui.storage-needed", "sspp-gui.request-storage-needed-tooltip", {
                type = "label", style = "sspp_station_item_value",
            }),
            make_property_flow("sspp-gui.current-deficit", "sspp-gui.provide-current-deficit-tooltip", {
                type = "label", style = "sspp_station_item_value",
            }),
        } },
    })
end

---@param player_id PlayerId
---@param table_name string
---@param inner function
---@param elem_type string
---@return boolean success
local function try_add_item_or_fluid(player_id, table_name, inner, elem_type)
    local table = storage.player_guis[player_id].elements[table_name]
    if #table.children <= table.column_count * 10 then
        inner(table, elem_type)
        return true
    else
        local player = game.get_player(player_id) --[[@as LuaPlayer]]
        player.play_sound({ path = "utility/cannot_build" })
        return false
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
handle_provide_copy[events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    local table = flow.parent --[[@as LuaGuiElement]]

    local i = flow.get_index_in_parent() - 1
    local elem_type = table.children[i + 2].elem_type
    if not try_add_item_or_fluid(event.player_index, "provide_table", add_new_provide_row, elem_type) then return end

    local j = i + table.column_count
    gui.insert_newly_added_row(table, j)

    local table_children = table.children
    table_children[j + 4].children[1].children[2].switch_state = table_children[i + 4].children[1].children[2].switch_state
    table_children[j + 4].children[2].children[2].text = table_children[i + 4].children[2].children[2].text
    table_children[j + 4].children[3].children[2].text = table_children[i + 4].children[3].children[2].text
    table_children[j + 4].children[4].children[2].text = table_children[i + 4].children[4].children[2].text
end

---@param event EventData.on_gui_click
handle_request_copy[events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    local table = flow.parent --[[@as LuaGuiElement]]

    local i = flow.get_index_in_parent() - 1
    local elem_type = table.children[i + 2].elem_type
    if not try_add_item_or_fluid(event.player_index, "request_table", add_new_request_row, elem_type) then return end

    local j = i + table.column_count
    gui.insert_newly_added_row(table, j)

    local table_children = table.children
    table_children[j + 4].children[1].children[2].switch_state = table_children[i + 4].children[1].children[2].switch_state
    table_children[j + 4].children[2].children[2].text = table_children[i + 4].children[2].children[2].text
    table_children[j + 4].children[3].children[2].text = table_children[i + 4].children[3].children[2].text
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
local function provide_to_row_network(table_children, i, network_item)
    local quality = network_item.quality
    local fmt_items_or_units = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"

    table_children[i + 3].children[1].children[2].caption = network_item.class
    table_children[i + 3].children[2].children[2].caption = { fmt_items_or_units, network_item.delivery_size }
    table_children[i + 3].children[3].children[2].caption = { "sspp-gui.fmt-duration", network_item.delivery_time }
end

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
---@param item ProvideItem
local function provide_to_row_statistics(table_children, i, network_item, item)
    local name, quality = network_item.name, network_item.quality
    local fmt_slots_or_units = quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units"
    local stack_size = quality and prototypes.item[name].stack_size or 1

    table_children[i + 5].children[1].children[2].caption = { fmt_slots_or_units, compute_storage_needed(network_item, item) / stack_size }
end

---@param network_items {[ItemKey]: NetworkItem}
---@param provide_table LuaGuiElement
---@param item_key ItemKey
---@param item ProvideItem
local function provide_init_row(network_items, provide_table, item_key, item)
    local name, quality = split_item_key(item_key)
    add_new_provide_row(provide_table, quality and "item-with-quality" or "fluid")

    local table_children = provide_table.children
    local i = #table_children - provide_table.column_count

    table_children[i + 2].elem_value = quality and { name = name, quality = quality } or name

    local network_item = network_items[item_key]
    if network_item then
        provide_to_row_network(table_children, i, network_item)
        provide_to_row_statistics(table_children, i, network_item, item)
    end

    table_children[i + 4].children[1].children[2].switch_state = item.push and "right" or "left"
    table_children[i + 4].children[2].children[2].text = tostring(item.throughput)
    table_children[i + 4].children[3].children[2].text = tostring(item.latency)
    table_children[i + 4].children[4].children[2].text = tostring(item.granularity)

    table_children[i + 1].children[2].sprite = ""
    table_children[i + 1].children[2].tooltip = nil
end

---@param table_children LuaGuiElement[]
---@param i integer
---@return ItemKey?, ProvideItem?
local function provide_from_row(table_children, i)
    local elem_value = table_children[i + 2].elem_value ---@type (table|string)?
    if not elem_value then return end

    local _, _, item_key = gui.extract_elem_value_fields(elem_value)

    local throughput = tonumber(table_children[i + 4].children[2].children[2].text)
    if not throughput then return item_key end

    local latency = tonumber(table_children[i + 4].children[3].children[2].text)
    if not latency then return item_key end

    local granularity = tonumber(table_children[i + 4].children[4].children[2].text)
    if not granularity or granularity < 1 then return item_key end

    return item_key, {
        push = table_children[i + 4].children[1].children[2].switch_state == "right",
        throughput = throughput,
        latency = latency,
        granularity = granularity,
    } --[[@as ProvideItem]]
end

---@param player_gui PlayerStationGui
---@param table_children LuaGuiElement[]
---@param i integer
---@param item_key ItemKey?
---@param item ProvideItem?
local function provide_to_row(player_gui, table_children, i, item_key, item)
    local network_item = item_key and storage.networks[player_gui.network].items[item_key]

    if network_item then
        provide_to_row_network(table_children, i, network_item)
    else
        table_children[i + 3].children[1].children[2].caption = ""
        table_children[i + 3].children[2].children[2].caption = ""
        table_children[i + 3].children[3].children[2].caption = ""
    end

    if network_item and item then
        provide_to_row_statistics(table_children, i, network_item, item)
    else
        table_children[i + 5].children[1].children[2].caption = ""
        table_children[i + 5].children[2].children[2].caption = ""
    end

    if item then
        table_children[i + 1].children[2].sprite = ""
        table_children[i + 1].children[2].tooltip = nil
    else
        table_children[i + 1].children[2].sprite = "utility/achievement_warning"
        table_children[i + 1].children[2].tooltip = { "sspp-gui.invalid-values-tooltip" }
    end
end

---@param player_gui PlayerStationGui
---@param item_key ItemKey
local function provide_remove_key(player_gui, item_key)
    local station = storage.stations[player_gui.parts.stop.unit_number] --[[@as Station]]

    set_haulers_to_manual(station.provide_deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop)

    -- if item_key == player_gui.haulers_item then clear_grid_and_header(player_gui) end
    -- if item_key == player_gui.stations_item then clear_grid_and_header(player_gui) end
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
local function request_to_row_network(table_children, i, network_item)
    local quality = network_item.quality
    local fmt_items_or_units = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"

    table_children[i + 3].children[1].children[2].caption = network_item.class
    table_children[i + 3].children[2].children[2].caption = { fmt_items_or_units, network_item.delivery_size }
    table_children[i + 3].children[3].children[2].caption = { "sspp-gui.fmt-duration", network_item.delivery_time }
end

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
---@param item RequestItem
local function request_to_row_statistics(table_children, i, network_item, item)
    local name, quality = network_item.name, network_item.quality
    local fmt_slots_or_units = quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units"
    local stack_size = quality and prototypes.item[name].stack_size or 1

    table_children[i + 5].children[1].children[2].caption = { fmt_slots_or_units, compute_storage_needed(network_item, item) / stack_size }
end

---@param network_items {[ItemKey]: NetworkItem}
---@param request_table LuaGuiElement
---@param item_key ItemKey
---@param item RequestItem
local function request_init_row(network_items, request_table, item_key, item)
    local name, quality = split_item_key(item_key)
    add_new_request_row(request_table, quality and "item-with-quality" or "fluid")

    local table_children = request_table.children
    local i = #table_children - request_table.column_count

    table_children[i + 2].elem_value = quality and { name = name, quality = quality } or name

    local network_item = network_items[item_key]
    if network_item then
        request_to_row_network(table_children, i, network_item)
        request_to_row_statistics(table_children, i, network_item, item)
    end

    table_children[i + 4].children[1].children[2].switch_state = item.pull and "right" or "left"
    table_children[i + 4].children[2].children[2].text = tostring(item.throughput)
    table_children[i + 4].children[3].children[2].text = tostring(item.latency)

    table_children[i + 1].children[2].sprite = ""
    table_children[i + 1].children[2].tooltip = nil
end

---@param table_children LuaGuiElement[]
---@param i integer
---@return ItemKey?, RequestItem?
local function request_from_row(table_children, i)
    local elem_value = table_children[i + 2].elem_value ---@type (table|string)?
    if not elem_value then return end

    local _, _, item_key = gui.extract_elem_value_fields(elem_value)

    local throughput = tonumber(table_children[i + 4].children[2].children[2].text)
    if not throughput then return item_key end

    local latency = tonumber(table_children[i + 4].children[3].children[2].text)
    if not latency then return item_key end

    return item_key, {
        pull = table_children[i + 4].children[1].children[2].switch_state == "right",
        throughput = throughput,
        latency = latency,
    } --[[@as RequestItem]]
end

---@param player_gui PlayerStationGui
---@param table_children LuaGuiElement[]
---@param i integer
---@param item_key ItemKey?
---@param item RequestItem?
local function request_to_row(player_gui, table_children, i, item_key, item)
    local network_item = item_key and storage.networks[player_gui.network].items[item_key]

    if network_item then
        request_to_row_network(table_children, i, network_item)
    else
        table_children[i + 3].children[1].children[2].caption = ""
        table_children[i + 3].children[2].children[2].caption = ""
        table_children[i + 3].children[3].children[2].caption = ""
    end

    if network_item and item then
        request_to_row_statistics(table_children, i, network_item, item)
    else
        table_children[i + 5].children[1].children[2].caption = ""
        table_children[i + 5].children[2].children[2].caption = ""
    end

    if item then
        table_children[i + 1].children[2].sprite = ""
        table_children[i + 1].children[2].tooltip = nil
    else
        table_children[i + 1].children[2].sprite = "utility/achievement_warning"
        table_children[i + 1].children[2].tooltip = { "sspp-gui.invalid-values-tooltip" }
    end
end

---@param player_gui PlayerStationGui
---@param item_key ItemKey
local function request_remove_key(player_gui, item_key)
    local station = storage.stations[player_gui.parts.stop.unit_number] --[[@as Station]]

    set_haulers_to_manual(station.request_deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop)

    -- if item_key == player_gui.haulers_item then clear_grid_and_header(player_gui) end
    -- if item_key == player_gui.stations_item then clear_grid_and_header(player_gui) end
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
function gui.update_station_after_change(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerStationGui]]
    local parts = player_gui.parts --[[@as StationParts]]
    local station = storage.stations[parts.stop.unit_number] --[[@as Station?]]

    if parts.provide_io then
        local provide_items = gui.refresh_table(
            player_gui.elements.provide_table,
            provide_from_row,
            function(b, c, d, e) return provide_to_row(player_gui, b, c, d, e) end,
            station and station.provide_items,
            station and function(b) return provide_remove_key(player_gui, b) end
        )
        if station then
            station.provide_items = provide_items
            ensure_hidden_combs(station.provide_io, station.provide_hidden_combs, provide_items)
        end
    end

    if parts.request_io then
        local items = gui.refresh_table(
            player_gui.elements.request_table,
            request_from_row,
            function(b, c, d, e) return request_to_row(player_gui, b, c, d, e) end,
            station and station.request_items,
            station and function(b) return request_remove_key(player_gui, b) end
        )
        if station then
            station.request_items = items
            ensure_hidden_combs(station.request_io, station.request_hidden_combs, items)
        end
    end

    if station and not read_stop_flag(station.stop, e_stop_flags.custom_name) then
        local new_stop_name = compute_stop_name(station.provide_items, station.request_items)
        station.stop.backer_name = new_stop_name
        player_gui.elements.stop_name_label.caption = new_stop_name
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_open_hauler = { [events.on_gui_click] = function(event)
    game.get_player(event.player_index).opened = event.element.parent.entity
end }

--------------------------------------------------------------------------------

---@param player_gui PlayerStationGui
function gui.station_poll_finished(player_gui)
    local parts = player_gui.parts
    if not parts then return end
    local station = storage.stations[parts.stop.unit_number] --[[@as Station?]]
    if not station then return end

    local elements = player_gui.elements
    local network_items = storage.networks[player_gui.network].items

    local grid_table = elements.grid_table
    local grid_children = grid_table.children
    local old_length = #grid_children
    local new_length = 0

    if station.provide_counts then
        local provide_table = elements.provide_table
        local columns, table_children = provide_table.column_count, provide_table.children

        for i = columns, #table_children - 1, columns do
            if table_children[i + 1].children[2].sprite == "" then
                local _, quality, item_key = gui.extract_elem_value_fields(table_children[i + 2].elem_value)

                local network_item = network_items[item_key]
                if network_item then
                    local fmt_items_or_units = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"

                    table_children[i + 5].children[2].children[2].caption = { fmt_items_or_units, station.provide_counts[item_key] }
                end
            end
        end

        if elements.grid_provide_toggle.toggled then
            for item_key, hauler_ids in pairs(station.provide_deliveries) do
                local name, quality = split_item_key(item_key)
                local icon = make_item_icon(name, quality)

                for _, hauler_id in pairs(hauler_ids) do
                    new_length = new_length + 1
                    local minimap = gui.next_minimap(grid_table, grid_children, old_length, new_length, 1.0, handle_open_hauler)
                    local train = storage.haulers[hauler_id].train
                    minimap.children[2].caption = "[img=virtual-signal/up-arrow]"
                    minimap.children[3].caption = tostring(get_train_item_count(train, name, quality)) .. icon
                    minimap.entity = train.front_stock
                end
            end
        end
    end

    if station.request_counts then
        local request_table = elements.request_table
        local columns, table_children = request_table.column_count, request_table.children

        for i = columns, #table_children - 1, columns do
            if table_children[i + 1].children[2].sprite == "" then
                local _, quality, item_key = gui.extract_elem_value_fields(table_children[i + 2].elem_value)

                local network_item = network_items[item_key]
                if network_item then
                    local fmt_items_or_units = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"

                    table_children[i + 5].children[2].children[2].caption = { fmt_items_or_units, station.request_counts[item_key] }
                end
            end
        end

        if elements.grid_request_toggle.toggled then
            for item_key, hauler_ids in pairs(station.request_deliveries) do
                local name, quality = split_item_key(item_key)
                local icon = make_item_icon(name, quality)

                for _, hauler_id in pairs(hauler_ids) do
                    new_length = new_length + 1
                    local minimap = gui.next_minimap(grid_table, grid_children, old_length, new_length, 1.0, handle_open_hauler)
                    local train = storage.haulers[hauler_id].train
                    minimap.children[2].caption = "[img=virtual-signal/down-arrow]"
                    minimap.children[3].caption = tostring(get_train_item_count(train, name, quality)) .. icon
                    minimap.entity = train.front_stock
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
local handle_open_network = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local network_name = storage.player_guis[player_id].network

    gui.network_open(player_id, network_name, 2)
end }

---@param event EventData.on_gui_click
local handle_toggle_name = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerStationGui]]
    local parts = player_gui.parts --[[@as StationParts]]

    if event.element.toggled then
        if not player_gui.elements.stop_name_clear_button.enabled then
            player_gui.elements.stop_name_input.text = parts.stop.backer_name
        end
        player_gui.elements.stop_name_label.visible = false
        player_gui.elements.stop_name_input.visible = true
        player_gui.elements.stop_name_input.focus()
    else
        player_gui.elements.stop_name_label.caption = parts.stop.backer_name
        player_gui.elements.stop_name_input.visible = false
        player_gui.elements.stop_name_label.visible = true
    end
end }

---@param event EventData.on_gui_click
local handle_clear_name = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerStationGui]]
    local parts = player_gui.parts --[[@as StationParts]]

    write_stop_flag(parts.stop, e_stop_flags.custom_name, false)

    local station = storage.stations[parts.stop.unit_number] --[[@as Station?]]
    local stop_name ---@type string
    if station then
        stop_name = compute_stop_name(station.provide_items, station.request_items)
    else
        stop_name = "[virtual-signal=signal-ghost]"
    end
    parts.stop.backer_name = stop_name
    player_gui.elements.stop_name_label.caption = stop_name

    player_gui.elements.stop_name_input.visible = false
    player_gui.elements.stop_name_label.visible = true

    player_gui.elements.stop_name_edit_toggle.toggled = false
    player_gui.elements.stop_name_clear_button.enabled = false
end }

local handle_name_changed_or_confirmed = {}

---@param event EventData.on_gui_text_changed
handle_name_changed_or_confirmed[events.on_gui_text_changed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerStationGui]]
    local parts = player_gui.parts --[[@as StationParts]]

    local stop_name = string.sub(event.element.text, 1, 199)
    if event.element.text ~= stop_name then event.element.text = stop_name end

    local has_custom_name = stop_name ~= ""
    player_gui.elements.stop_name_clear_button.enabled = has_custom_name
    write_stop_flag(parts.stop, e_stop_flags.custom_name, has_custom_name)

    if not has_custom_name then
        local station = storage.stations[parts.stop.unit_number] --[[@as Station?]]
        if station then
            stop_name = compute_stop_name(station.provide_items, station.request_items)
        else
            stop_name = "[virtual-signal=signal-ghost]"
        end
    end
    parts.stop.backer_name = stop_name
end

---@param event EventData.on_gui_confirmed
handle_name_changed_or_confirmed[events.on_gui_confirmed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerStationGui]]
    local parts = player_gui.parts --[[@as StationParts]]

    player_gui.elements.stop_name_label.caption = parts.stop.backer_name
    player_gui.elements.stop_name_input.visible = false
    player_gui.elements.stop_name_label.visible = true

    player_gui.elements.stop_name_edit_toggle.toggled = false
end

---@param event EventData.on_gui_click
local handle_add_provide_item = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "provide_table", add_new_provide_row, "item-with-quality")
end }

---@param event EventData.on_gui_click
local handle_add_provide_fluid = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "provide_table", add_new_provide_row, "fluid")
end }

---@param event EventData.on_gui_click
local handle_add_request_item = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "request_table", add_new_request_row, "item-with-quality")
end }

---@param event EventData.on_gui_click
local handle_add_request_fluid = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "request_table", add_new_request_row, "fluid")
end }

---@param event EventData.on_gui_click
local handle_close_window = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    assert(player.opened.name == "sspp-station")

    player.opened = nil
end }

--------------------------------------------------------------------------------

---@param player LuaPlayer
---@param parts StationParts
---@return {[string]: LuaGuiElement} elements, LuaGuiElement window
local function add_gui_complete(player, parts)
    local name = parts.stop.backer_name
    local has_custom_name = read_stop_flag(parts.stop, e_stop_flags.custom_name)
    local no_provide = not parts.provide_io and {}
    local no_request = not parts.request_io and {}
    return flib_gui.add(player.gui.screen, {
        { type = "frame", name = "sspp-station", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", drag_target = "sspp-station", children = {
                { type = "label", style = "frame_title", caption = { "entity-name.sspp-stop" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, mouse_button_filter = { "left" }, handler = handle_open_network },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", mouse_button_filter = { "left" }, handler = handle_close_window },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", name = "stop_name_label", style = "subheader_caption_label", caption = name },
                        { type = "textfield", name = "stop_name_input", style = "sspp_subheader_caption_textbox", icon_selector = true, text = name, visible = false, handler = handle_name_changed_or_confirmed },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        { type = "sprite-button", name = "stop_name_edit_toggle", style = "control_settings_section_button", sprite = "sspp-name-icon", tooltip = { "sspp-gui.edit-custom-name" }, auto_toggle = true, handler = handle_toggle_name },
                        { type = "sprite-button", name = "stop_name_clear_button", style = "control_settings_section_button", sprite = "sspp-reset-icon", tooltip = { "sspp-gui.clear-custom-name" }, enabled = has_custom_name, handler = handle_clear_name },
                    } },
                    { type = "tabbed-pane", style = "tabbed_pane", children = {
                        no_provide or {
                            ---@type flib.GuiElemDef
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.provide" } },
                            ---@type flib.GuiElemDef
                            content = { type = "scroll-pane", style = "sspp_station_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "provide_table", style = "sspp_station_item_table", column_count = 5, children = {
                                    { type = "empty-widget" },
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.network-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.station-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.statistics" } },
                                } },
                                { type = "flow", style = "horizontal_flow", children = {
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, handler = handle_add_provide_item },
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, handler = handle_add_provide_fluid },
                                } },
                            } },
                        },
                        no_request or {
                            ---@type flib.GuiElemDef
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.request" } },
                            ---@type flib.GuiElemDef
                            content = { type = "scroll-pane", style = "sspp_station_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "request_table", style = "sspp_station_item_table", column_count = 5, children = {
                                    { type = "empty-widget" },
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.network-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.station-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.statistics" } },
                                } },
                                { type = "flow", style = "horizontal_flow", children = {
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, mouse_button_filter = { "left" }, handler = handle_add_request_item },
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, mouse_button_filter = { "left" }, handler = handle_add_request_fluid },
                                } },
                            } },
                        },
                    } },
                } },
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", style = "subheader_caption_label", caption = { "sspp-gui.deliveries" } },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        no_provide or { type = "sprite-button", name = "grid_provide_toggle", style = "control_settings_section_button", sprite = "virtual-signal/up-arrow", tooltip = { "sspp-gui.grid-haulers-provide-tooltip" }, auto_toggle = true, toggled = true },
                        no_request or { type = "sprite-button", name = "grid_request_toggle", style = "control_settings_section_button", sprite = "virtual-signal/down-arrow", tooltip = { "sspp-gui.grid-haulers-request-tooltip" }, auto_toggle = true, toggled = true },
                    } },
                    { type = "scroll-pane", style = "sspp_grid_scroll_pane", direction = "vertical", vertical_scroll_policy = "always", children = {
                        { type = "table", name = "grid_table", style = "sspp_grid_table", column_count = 3 },
                    } },
                } },
            } },
        } },
    })
end

---@param player LuaPlayer
---@return {[string]: LuaGuiElement} elements, LuaGuiElement window
local function add_gui_incomplete(player)
    return flib_gui.add(player.gui.screen, {
        { type = "frame", name = "sspp-station", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", drag_target = "sspp-station", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.incomplete-station" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, mouse_button_filter = { "left" }, handler = handle_open_network },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = handle_close_window },
            } },
            { type = "label", style = "info_label", caption = { "sspp-gui.incomplete-station-message" } },
        } },
    })
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param entity LuaEntity
function gui.station_open(player_id, entity)
    local player = assert(game.get_player(player_id))
    local unit_number = entity.unit_number --[[@as uint]]
    local parts = get_station_parts(entity)
    local network_name = entity.surface.name

    player.opened = nil

    local elements, window ---@type {[string]: LuaGuiElement}, LuaGuiElement
    if parts then
        elements, window = add_gui_complete(player, parts)
    else
        elements, window = add_gui_incomplete(player)
    end

    window.force_auto_center()
    storage.player_guis[player_id] = { network = network_name, unit_number = unit_number, parts = parts, elements = elements }

    if parts then
        local network_items = storage.networks[network_name].items
        if parts.provide_io then
            local provide_table = elements.provide_table
            for item_key, item in pairs(combinator_description_to_provide_items(parts.provide_io)) do
                provide_init_row(network_items, provide_table, item_key, item)
            end
        end
        if parts.request_io then
            local request_table = elements.request_table
            for item_key, item in pairs(combinator_description_to_request_items(parts.request_io)) do
                request_init_row(network_items, request_table, item_key, item)
            end
        end
    end

    player.opened = window
end

---@param player_id PlayerId
---@param window LuaGuiElement
function gui.station_closed(player_id, window)
    assert(window.name == "sspp-station")
    window.destroy()

    local player_gui = storage.player_guis[player_id] --[[@as PlayerStationGui]]
    local entity = storage.entities[player_gui.unit_number]

    if entity.valid and entity.name ~= "entity-ghost" then
        local player = game.get_player(player_id) --[[@as LuaPlayer]]
        player.play_sound({ path = "entity-close/sspp-stop" })
    end

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.station_add_flib_handlers()
    flib_gui.add_handlers({
        ["station_item_move"] = handle_item_move[events.on_gui_click],
        ["station_provide_copy"] = handle_provide_copy[events.on_gui_click],
        ["station_request_copy"] = handle_request_copy[events.on_gui_click],
        ["station_item_elem_changed"] = handle_item_elem_changed[events.on_gui_elem_changed],
        ["station_item_switch_state_changed"] = handle_item_switch_state_changed[events.on_gui_switch_state_changed],
        ["station_item_text_changed"] = handle_item_text_changed[events.on_gui_text_changed],
        ["station_open_network"] = handle_open_network[events.on_gui_click],
        ["station_toggle_name"] = handle_toggle_name[events.on_gui_click],
        ["station_clear_name"] = handle_clear_name[events.on_gui_click],
        ["station_name_changed"] = handle_name_changed_or_confirmed[events.on_gui_text_changed],
        ["station_name_confirmed"] = handle_name_changed_or_confirmed[events.on_gui_confirmed],
        ["station_open_hauler"] = handle_open_hauler[events.on_gui_click],
        ["station_add_provide_item"] = handle_add_provide_item[events.on_gui_click],
        ["station_add_provide_fluid"] = handle_add_provide_fluid[events.on_gui_click],
        ["station_add_request_item"] = handle_add_request_item[events.on_gui_click],
        ["station_add_request_fluid"] = handle_add_request_fluid[events.on_gui_click],
        ["station_close_window"] = handle_close_window[events.on_gui_click],
    })
end
