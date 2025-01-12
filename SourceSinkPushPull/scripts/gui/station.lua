-- SSPP by jagoly

local flib_gui = require("__flib__.gui")

--------------------------------------------------------------------------------

---@param event EventData.on_gui_elem_changed
local function handle_resource_changed(event)
    local clear = event.element.elem_value == nil
    gui.update_station_after_change(event.player_index, clear)
end

---@param event EventData.on_gui_switch_state_changed
local function handle_mode_changed(event)
    gui.update_station_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_throughput_changed(event)
    gui.update_station_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_granularity_changed(event)
    gui.update_station_after_change(event.player_index, false)
end

---@param event EventData.on_gui_text_changed
local function handle_latency_changed(event)
    gui.update_station_after_change(event.player_index, false)
end

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
---@param elem_type "item-with-quality"|"fluid"
local function add_new_provide_row(provide_table, elem_type)
    flib_gui.add(provide_table, {
        {
            type = "choose-elem-button", style = "big_slot_button",
            elem_type = elem_type,
            handler = { [defines.events.on_gui_elem_changed] = handle_resource_changed },
        },
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
                left_label_caption = { "sspp-gui.source" }, right_label_caption = { "sspp-gui.push" },
                tooltip = { "sspp-gui.provide-mode-tooltip" },
                switch_state = "left",
                handler = { [defines.events.on_gui_switch_state_changed] = handle_mode_changed },
            }),
            make_property_flow("sspp-gui.throughput", "sspp-gui.provide-throughput-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "0",
                handler = { [defines.events.on_gui_text_changed] = handle_throughput_changed },
            }),
            make_property_flow("sspp-gui.latency", "sspp-gui.provide-latency-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "30",
                handler = { [defines.events.on_gui_text_changed] = handle_latency_changed },
            }),
            make_property_flow("sspp-gui.granularity", "sspp-gui.provide-granularity-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true,
                text = "1",
                handler = { [defines.events.on_gui_text_changed] = handle_granularity_changed },
            }),
        } },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_property_flow("sspp-gui.storage-needed", "sspp-gui.provide-storage-needed-tooltip", {
                type = "label", style = "sspp_station_item_value",
            }),
        } },
    })
end

---@param request_table LuaGuiElement
---@param elem_type "item-with-quality"|"fluid"
local function add_new_request_row(request_table, elem_type)
    flib_gui.add(request_table, {
        {
            type = "choose-elem-button", style = "big_slot_button",
            elem_type = elem_type,
            handler = { [defines.events.on_gui_elem_changed] = handle_resource_changed },
        },
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
                left_label_caption = { "sspp-gui.sink" }, right_label_caption = { "sspp-gui.pull" },
                tooltip = { "sspp-gui.request-mode-tooltip" },
                switch_state = "left",
                handler = { [defines.events.on_gui_switch_state_changed] = handle_mode_changed },
            }),
            make_property_flow("sspp-gui.throughput", "sspp-gui.request-throughput-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "0",
                handler = { [defines.events.on_gui_text_changed] = handle_throughput_changed },
            }),
            make_property_flow("sspp-gui.latency", "sspp-gui.request-latency-tooltip", {
                type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true,
                text = "30",
                handler = { [defines.events.on_gui_text_changed] = handle_latency_changed },
            }),
        } },
        { type = "frame", style = "sspp_station_item_frame", direction = "vertical", children = {
            make_property_flow("sspp-gui.storage-needed", "sspp-gui.request-storage-needed-tooltip", {
                type = "label", style = "sspp_station_item_value",
            }),
        } },
    })
end

--------------------------------------------------------------------------------

---@param network_items {[ItemKey]: NetworkItem}
---@param from_nothing boolean
---@param provide_table LuaGuiElement
---@param provide_items {[ItemKey]: ProvideItem}
---@param item_key ItemKey
---@param i integer
local function populate_row_from_provide_item(network_items, from_nothing, provide_table, provide_items, item_key, i)
    local item = provide_items[item_key]
    local name, quality = split_item_key(item_key)

    if from_nothing then
        add_new_provide_row(provide_table, quality and "item-with-quality" or "fluid")
        local table_children = provide_table.children

        table_children[i + 1].elem_value = quality and { name = name, quality = quality } or name

        local station_children = table_children[i + 3].children
        station_children[1].children[2].switch_state = item.push and "right" or "left"
        station_children[2].children[2].text = tostring(item.throughput)
        station_children[3].children[2].text = tostring(item.latency)
        station_children[4].children[2].text = tostring(item.granularity)
    end

    local network_item = network_items[item_key]
    if network_item then
        local table_children = provide_table.children

        local fmt_delivery_size = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"
        local fmt_storage_needed = quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units"
        local stack_size = quality and prototypes.item[name].stack_size or 1

        local network_children = table_children[i + 2].children
        network_children[1].children[2].caption = network_item.class
        network_children[2].children[2].caption = { fmt_delivery_size, network_item.delivery_size }
        network_children[3].children[2].caption = { "sspp-gui.fmt-duration", network_item.delivery_time }

        local statistics_children = table_children[i + 4].children
        statistics_children[1].children[2].caption = { fmt_storage_needed, compute_storage_needed(network_item, item) / stack_size }
    end
end

---@param network_items {[ItemKey]: NetworkItem}
---@param from_nothing boolean
---@param request_table LuaGuiElement
---@param request_items {[ItemKey]: RequestItem}
---@param item_key ItemKey
---@param i integer
local function populate_row_from_request_item(network_items, from_nothing, request_table, request_items, item_key, i)
    local item = request_items[item_key]
    local name, quality = split_item_key(item_key)

    if from_nothing then
        add_new_request_row(request_table, quality and "item-with-quality" or "fluid")
        local table_children = request_table.children

        table_children[i + 1].elem_value = quality and { name = name, quality = quality } or name

        local station_children = table_children[i + 3].children
        station_children[1].children[2].switch_state = item.pull and "right" or "left"
        station_children[2].children[2].text = tostring(item.throughput)
        station_children[3].children[2].text = tostring(item.latency)
    end

    local network_item = network_items[item_key]
    if network_item then
        local table_children = request_table.children

        local fmt_delivery_size = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"
        local fmt_storage_needed = quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units"
        local stack_size = quality and prototypes.item[name].stack_size or 1

        local network_children = table_children[i + 2].children
        network_children[1].children[2].caption = network_item.class
        network_children[2].children[2].caption = { fmt_delivery_size, network_item.delivery_size }
        network_children[3].children[2].caption = { "sspp-gui.fmt-duration", network_item.delivery_time }

        local statistics_children = table_children[i + 4].children
        statistics_children[1].children[2].caption = { fmt_storage_needed, compute_storage_needed(network_item, item) / stack_size }
    end
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param list_index integer
---@param i integer
---@return ItemKey?, ProvideItem?
local function generate_provide_item_from_row(table_children, list_index, i)
    local elem_value = table_children[i + 1].elem_value ---@type (table|string)?
    if elem_value == nil then return end

    local station_children = table_children[i + 3].children

    local _, _, item_key = gui.extract_elem_value_fields(elem_value)
    return item_key, {
        list_index = list_index,
        push = station_children[1].children[2].switch_state == "right",
        throughput = tonumber(station_children[2].children[2].text) or 0.0,
        latency = tonumber(station_children[3].children[2].text) or 30.0,
        granularity = tonumber(station_children[4].children[2].text) or 1,
    } --[[@as ProvideItem]]
end

---@param table_children LuaGuiElement[]
---@param list_index integer
---@param i integer
---@return ItemKey?, RequestItem?
local function generate_request_item_from_row(table_children, list_index, i)
    local elem_value = table_children[i + 1].elem_value ---@type (table|string)?
    if elem_value == nil then return end

    local station_children = table_children[i + 3].children

    local _, _, item_key = gui.extract_elem_value_fields(elem_value)
    return item_key, {
        list_index = list_index,
        pull = station_children[1].children[2].switch_state == "right",
        throughput = tonumber(station_children[2].children[2].text) or 0.0,
        latency = tonumber(station_children[3].children[2].text) or 30.0,
    } --[[@as RequestItem]]
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param from_nothing boolean
function gui.update_station_after_change(player_id, from_nothing)
    local player_state = storage.player_states[player_id]

    local parts = assert(player_state.parts)

    local station = storage.stations[parts.stop.unit_number] --[[@as Station?]]
    local network_items = storage.networks[player_state.network].items

    if parts.provide_io then
        local provide_table = player_state.elements.provide_table
        local provide_items = gui.generate_dict_from_table(provide_table, generate_provide_item_from_row)

        parts.provide_io.combinator_description = helpers.table_to_json(provide_items)

        if station then
            for item_key, _ in pairs(station.provide_items) do
                if not provide_items[item_key] then
                    set_haulers_to_manual(station.provide_deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop)
                end
            end
            station.provide_items = provide_items
            ensure_hidden_combs(station.provide_io, station.provide_hidden_combs, provide_items)
        end

        gui.populate_table_from_dict(from_nothing, provide_table, provide_items, bind_1_of_6(populate_row_from_provide_item, network_items))
    end

    if parts.request_io then
        local request_table = player_state.elements.request_table
        local request_items = gui.generate_dict_from_table(request_table, generate_request_item_from_row)

        parts.request_io.combinator_description = helpers.table_to_json(request_items)

        if station then
            for item_key, _ in pairs(station.request_items) do
                if not request_items[item_key] then
                    set_haulers_to_manual(station.request_deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop)
                end
            end
            station.request_items = request_items
            ensure_hidden_combs(station.request_io, station.request_hidden_combs, request_items)
        end

        gui.populate_table_from_dict(from_nothing, request_table, request_items, bind_1_of_6(populate_row_from_request_item, network_items))
    end

    if from_nothing and station then
        --- note that we don't need to update schedules, the game will do that for us
        local new_stop_name = compute_stop_name(station.provide_items, station.request_items)
        station.stop.backer_name = new_stop_name
        player_state.elements.stop_name.caption = new_stop_name
    end
end

--------------------------------------------------------------------------------

---@param player_state PlayerState
function gui.station_poll_finished(player_state)
    -- TODO
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local function handle_open_network(event)
    local player_id = event.player_index
    local network_name = storage.player_states[player_id].network

    gui.network_open(player_id, network_name)
end

---@param event EventData.on_gui_click
local function handle_add_provide_item(event)
    local provide_table = storage.player_states[event.player_index].elements.provide_table
    add_new_provide_row(provide_table, "item-with-quality")
end

---@param event EventData.on_gui_click
local function handle_add_provide_fluid(event)
    local provide_table = storage.player_states[event.player_index].elements.provide_table
    add_new_provide_row(provide_table, "fluid")
end

---@param event EventData.on_gui_click
local function handle_add_request_item(event)
    local request_table = storage.player_states[event.player_index].elements.request_table
    add_new_request_row(request_table, "item-with-quality")
end

---@param event EventData.on_gui_click
local function handle_add_request_fluid(event)
    local request_table = storage.player_states[event.player_index].elements.request_table
    add_new_request_row(request_table, "fluid")
end

---@param event EventData.on_gui_click
local function handle_close(event)
    local player = assert(game.get_player(event.player_index))
    assert(player.opened.name == "sspp-station")

    player.opened = nil
end

--------------------------------------------------------------------------------

---@param player LuaPlayer
---@param provide any?
---@param request any?
---@return {[string]: LuaGuiElement} elements, LuaGuiElement window
local function add_gui_complete(player, provide, request)
    return flib_gui.add(player.gui.screen, {
        { type = "frame", style = "frame", direction = "vertical", name = "sspp-station", children = {
            { type = "flow", name = "titlebar", style = "frame_header_flow", children = {
                { type = "label", style = "frame_title", caption = { "entity-name.sspp-stop" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, mouse_button_filter = { "left" }, handler = handle_open_network },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = handle_close },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", style = "subheader_caption_label", name = "stop_name" },
                    } },
                    { type = "tabbed-pane", style = "tabbed_pane", children = {
                        provide and {
                            ---@type flib.GuiElemDef
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.provide" } },
                            ---@type flib.GuiElemDef
                            content = { type = "scroll-pane", style = "sspp_station_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "provide_table", style = "sspp_station_item_table", column_count = 4, children = {
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
                        } or {},
                        request and {
                            ---@type flib.GuiElemDef
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.request" } },
                            ---@type flib.GuiElemDef
                            content = { type = "scroll-pane", style = "sspp_station_left_scroll_pane", direction = "vertical", children = {
                                { type = "table", name = "request_table", style = "sspp_station_item_table", column_count = 4, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.network-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.station-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.statistics" } },
                                } },
                                { type = "flow", style = "horizontal_flow", children = {
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, handler = handle_add_request_item },
                                    { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, handler = handle_add_request_fluid },
                                } },
                            } },
                        } or {},
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
end

---@param player LuaPlayer
---@return {[string]: LuaGuiElement} elements, LuaGuiElement window
local function add_gui_incomplete(player)
    return flib_gui.add(player.gui.screen, {
        { type = "frame", style = "frame", direction = "vertical", name = "sspp-station", children = {
            { type = "flow", name = "titlebar", style = "frame_header_flow", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.incomplete-station" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, mouse_button_filter = { "left" }, handler = handle_open_network },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = handle_close },
            } },
            { type = "label", style = "label", caption = { "sspp-gui.incomplete-station-message" } },
        } },
    })
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param entity LuaEntity
function gui.station_open(player_id, entity)
    local player = assert(game.get_player(player_id))
    local parts = get_station_parts(entity)
    local network_name = entity.surface.name

    player.opened = nil

    local elements, window ---@type {[string]: LuaGuiElement}, LuaGuiElement
    if parts then
        elements, window = add_gui_complete(player, parts.provide_io, parts.request_io)
        storage.player_states[player_id] = { network = network_name, entity = entity, parts = parts, elements = elements }
    else
        elements, window = add_gui_incomplete(player)
        storage.player_states[player_id] = { network = network_name, entity = entity, elements = elements }
    end

    window.titlebar.drag_target = window
    window.force_auto_center()

    if parts then
        local network_items = storage.networks[network_name].items

        if parts.provide_io then
            local provide_items = combinator_description_to_provide_items(parts.provide_io)
            gui.populate_table_from_dict(true, elements.provide_table, provide_items, bind_1_of_6(populate_row_from_provide_item, network_items))
        end

        if parts.request_io then
            local request_items = combinator_description_to_request_items(parts.request_io)
            gui.populate_table_from_dict(true, elements.request_table, request_items, bind_1_of_6(populate_row_from_request_item, network_items))
        end

        elements.stop_name.caption = parts.stop.backer_name
    end

    player.opened = window
end

---@param player_id PlayerId
---@param window LuaGuiElement
function gui.station_closed(player_id, window)
    local player = assert(game.get_player(player_id))

    assert(window.name == "sspp-station")
    window.destroy()

    local entity = storage.player_states[player_id].entity --[[@as LuaEntity]]

    if entity.valid and entity.name ~= "entity-ghost" then
        player.play_sound({ path = "entity-close/sspp-stop" })
    end

    storage.player_states[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.station_add_flib_handlers()
    flib_gui.add_handlers({
        ["station_resource_changed"] = handle_resource_changed,
        ["station_mode_changed"] = handle_mode_changed,
        ["station_throughput_changed"] = handle_throughput_changed,
        ["station_granularity_changed"] = handle_granularity_changed,
        ["station_latency_changed"] = handle_latency_changed,
        ["station_open_network"] = handle_open_network,
        ["station_add_provide_item"] = handle_add_provide_item,
        ["station_add_provide_fluid"] = handle_add_provide_fluid,
        ["station_add_request_item"] = handle_add_request_item,
        ["station_add_request_fluid"] = handle_add_request_fluid,
        ["station_close"] = handle_close,
    })
end
