-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local glib = require("__SourceSinkPushPull__.scripts.glib")
local enums = require("__SourceSinkPushPull__.scripts.enums")

local gui_network = require("__SourceSinkPushPull__.scripts.gui.network")

local events = defines.events

local split_item_key, make_item_icon, get_train_item_count = lib.split_item_key, lib.make_item_icon, lib.get_train_item_count

local cwi, extract_elem_value_fields, acquire_next_minimap = glib.caption_with_info, glib.extract_elem_value_fields, glib.acquire_next_minimap

local gui_station = {}

--------------------------------------------------------------------------------

--- Find all of the entities that make up a station, works with ghosts.
---@param entity LuaEntity
---@return StationParts?
local function get_station_parts(entity)
    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    local stop ---@type LuaEntity
    if name == "sspp-stop" then
        stop = entity
    else
        local stop_ids = storage.comb_stop_ids[entity.unit_number]
        if #stop_ids ~= 1 then return nil end
        stop = storage.entities[stop_ids[1]]
    end

    local comb_ids = storage.stop_comb_ids[stop.unit_number]

    local combs_by_name = {} ---@type {[string]: LuaEntity?}

    for _, comb_id in pairs(comb_ids) do
        if #storage.comb_stop_ids[comb_id] ~= 1 then return nil end

        local comb = storage.entities[comb_id]
        name = comb.name
        if name == "entity-ghost" then name = comb.ghost_name end
        if combs_by_name[name] then return nil end

        combs_by_name[name] = comb
    end

    local general_io = combs_by_name["sspp-general-io"]
    if not general_io then return nil end

    local provide_io = combs_by_name["sspp-provide-io"]
    local request_io = combs_by_name["sspp-request-io"]
    if not (provide_io or request_io) then return nil end

    local ids = {}

    ids[stop.unit_number] = true
    ids[general_io.unit_number] = true
    if provide_io then ids[provide_io.unit_number] = true end
    if request_io then ids[request_io.unit_number] = true end

    return { ids = ids, stop = stop, general_io = general_io, provide_io = provide_io, request_io = request_io }
end

--------------------------------------------------------------------------------

---@param flow LuaGuiElement
---@return ItemMode mode
local function get_active_mode_button(flow)
    for index, button in pairs(flow.children) do
        if button.toggled then return index end
    end
    error()
end

---@param flow LuaGuiElement
---@param mode ItemMode
local function set_active_mode_button(flow, mode)
    for index, button in pairs(flow.children) do
        button.toggled = index == mode
    end
end

---@param elements {[string]: LuaGuiElement}
---@return integer rows
local function get_total_rows(elements)
    local provide_table, request_table = elements.provide_table, elements.request_table
    local rows = 0
    rows = rows + #provide_table.children / provide_table.column_count
    rows = rows + #request_table.children / request_table.column_count
    return rows
end

---@param table LuaGuiElement
---@param enabled boolean
function set_buffer_settings_enabled(table, enabled)
    local table_children = table.children
    for i = 0, #table_children - 1, table.column_count do
        table_children[i + 4].children[2].children[3].enabled = enabled
        table_children[i + 4].children[3].children[3].enabled = enabled
        table_children[i + 5].children[1].children[3].enabled = enabled
        if not enabled then
            -- these values don't matter for bufferless stations, but they still need to be valid
            if not tonumber(table_children[i + 4].children[2].children[3].text) then table_children[i + 4].children[2].children[3].text = "0" end
            if not tonumber(table_children[i + 4].children[3].children[3].text) then table_children[i + 4].children[3].children[3].text = "30" end
        end
    end
end

---@param deliveries {[ItemKey]: HaulerId[]}
---@param old_stop_name string
---@param new_stop_name string
local function rename_schedules_stop(deliveries, old_stop_name, new_stop_name)
    for _, hauler_ids in pairs(deliveries) do
        for i = #hauler_ids, 1, -1 do
            local train = storage.haulers[hauler_ids[i]].train
            local schedule = train.schedule --[[@as TrainSchedule]]
            for _, record in pairs(schedule.records) do
                if record.station == old_stop_name then record.station = new_stop_name end
            end
            train.schedule = schedule
        end
    end
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
local function provide_to_row_network(table_children, i, network_item)
    local quality = network_item.quality
    local fmt_items_or_units = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"

    table_children[i + 3].children[1].children[3].caption = network_item.class
    table_children[i + 3].children[2].children[3].caption = { fmt_items_or_units, network_item.delivery_size }
    table_children[i + 3].children[3].children[3].caption = { "sspp-gui.fmt-seconds", network_item.delivery_time }
end

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
---@param item ProvideItem
local function provide_to_row_statistics(table_children, i, network_item, item)
    local name, quality = network_item.name, network_item.quality
    local fmt_slots_or_units = quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units"
    local stack_size = quality and prototypes.item[name].stack_size or 1

    table_children[i + 5].children[1].children[3].caption = { fmt_slots_or_units, lib.compute_storage_needed(network_item, item) / stack_size }
end

---@param table_children LuaGuiElement[]
---@param i integer
---@return ItemKey?, ProvideItem?
local function provide_from_row(table_children, i)
    local elem_value = table_children[i + 2].elem_value --[[@as (table|string)?]]
    if not elem_value then return end

    local _, _, item_key = extract_elem_value_fields(elem_value)

    local throughput = tonumber(table_children[i + 4].children[2].children[3].text)
    if not throughput then return item_key end

    local latency = tonumber(table_children[i + 4].children[3].children[3].text)
    if not latency then return item_key end

    local granularity = tonumber(table_children[i + 4].children[4].children[3].text)
    if not granularity or granularity < 1 then return item_key end

    return item_key, {
        mode = get_active_mode_button(table_children[i + 4].children[1].children[3]),
        throughput = throughput,
        latency = latency,
        granularity = granularity,
    } --[[@as ProvideItem]]
end

---@param player_gui PlayerGui.Station
---@param table_children LuaGuiElement[]
---@param i integer
---@param item_key ItemKey?
---@param item ProvideItem?
local function provide_to_row(player_gui, table_children, i, item_key, item)
    local network_item = item_key and storage.networks[player_gui.network].items[item_key]

    if network_item then
        provide_to_row_network(table_children, i, network_item)
    else
        table_children[i + 3].children[1].children[3].caption = ""
        table_children[i + 3].children[2].children[3].caption = ""
        table_children[i + 3].children[3].children[3].caption = ""
    end

    if network_item and item then
        provide_to_row_statistics(table_children, i, network_item, item)
    else
        table_children[i + 5].children[1].children[3].caption = ""
        table_children[i + 5].children[2].children[3].caption = ""
    end

    if item then
        table_children[i + 1].children[2].sprite = ""
        table_children[i + 1].children[2].tooltip = nil
    else
        table_children[i + 1].children[2].sprite = "utility/achievement_warning"
        table_children[i + 1].children[2].tooltip = { "sspp-gui.invalid-values-tooltip" }
    end
end

---@param player_gui PlayerGui.Station
---@param item_key ItemKey
local function provide_remove_key(player_gui, item_key)
    local station = storage.stations[player_gui.parts.stop.unit_number] --[[@as Station]]
    local network = storage.networks[player_gui.network]

    lib.set_haulers_to_manual(station.provide.deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop)
    storage.disabled_items[network.surface.name .. ":" .. item_key] = true
end

--------------------------------------------------------------------------------

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
local function request_to_row_network(table_children, i, network_item)
    local quality = network_item.quality
    local fmt_items_or_units = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"

    table_children[i + 3].children[1].children[3].caption = network_item.class
    table_children[i + 3].children[2].children[3].caption = { fmt_items_or_units, network_item.delivery_size }
    table_children[i + 3].children[3].children[3].caption = { "sspp-gui.fmt-seconds", network_item.delivery_time }
end

---@param table_children LuaGuiElement[]
---@param i integer
---@param network_item NetworkItem
---@param item RequestItem
local function request_to_row_statistics(table_children, i, network_item, item)
    local name, quality = network_item.name, network_item.quality
    local fmt_slots_or_units = quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units"
    local stack_size = quality and prototypes.item[name].stack_size or 1

    table_children[i + 5].children[1].children[3].caption = { fmt_slots_or_units, lib.compute_storage_needed(network_item, item) / stack_size }
end

---@param table_children LuaGuiElement[]
---@param i integer
---@return ItemKey?, RequestItem?
local function request_from_row(table_children, i)
    local elem_value = table_children[i + 2].elem_value --[[@as (table|string)?]]
    if not elem_value then return end

    local _, _, item_key = extract_elem_value_fields(elem_value)

    local throughput = tonumber(table_children[i + 4].children[2].children[3].text)
    if not throughput then return item_key end

    local latency = tonumber(table_children[i + 4].children[3].children[3].text)
    if not latency then return item_key end

    return item_key, {
        mode = get_active_mode_button(table_children[i + 4].children[1].children[3]),
        throughput = throughput,
        latency = latency,
    } --[[@as RequestItem]]
end

---@param player_gui PlayerGui.Station
---@param table_children LuaGuiElement[]
---@param i integer
---@param item_key ItemKey?
---@param item RequestItem?
local function request_to_row(player_gui, table_children, i, item_key, item)
    local network_item = item_key and storage.networks[player_gui.network].items[item_key]

    if network_item then
        request_to_row_network(table_children, i, network_item)
    else
        table_children[i + 3].children[1].children[3].caption = ""
        table_children[i + 3].children[2].children[3].caption = ""
        table_children[i + 3].children[3].children[3].caption = ""
    end

    if network_item and item then
        request_to_row_statistics(table_children, i, network_item, item)
    else
        table_children[i + 5].children[1].children[3].caption = ""
        table_children[i + 5].children[2].children[3].caption = ""
    end

    if item then
        table_children[i + 1].children[2].sprite = ""
        table_children[i + 1].children[2].tooltip = nil
    else
        table_children[i + 1].children[2].sprite = "utility/achievement_warning"
        table_children[i + 1].children[2].tooltip = { "sspp-gui.invalid-values-tooltip" }
    end
end

---@param player_gui PlayerGui.Station
---@param item_key ItemKey
local function request_remove_key(player_gui, item_key)
    local station = storage.stations[player_gui.parts.stop.unit_number] --[[@as Station]]
    local network = storage.networks[player_gui.network]

    lib.set_haulers_to_manual(station.request.deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop)
    storage.disabled_items[network.surface.name .. ":" .. item_key] = true
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
local function update_station_after_change(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Station]]
    local parts = player_gui.parts --[[@as StationParts]]
    local stop, provide_io, request_io = parts.stop, parts.provide_io, parts.request_io
    local station = storage.stations[stop.unit_number] --[[@as Station?]]

    if provide_io then
        local items = glib.refresh_table(
            player_gui.elements.provide_table,
            provide_from_row,
            function(b, c, d, e) return provide_to_row(player_gui, b, c, d, e) end,
            station and station.provide.items,
            station and function(b) return provide_remove_key(player_gui, b) end
        )
        if station then
            station.provide.items = items
            lib.ensure_hidden_combs(station.provide.comb, station.provide.hidden_combs, items)
        end
        provide_io.combinator_description = lib.provide_items_to_combinator_description(items)
    end

    if request_io then
        local items = glib.refresh_table(
            player_gui.elements.request_table,
            request_from_row,
            function(b, c, d, e) return request_to_row(player_gui, b, c, d, e) end,
            station and station.request.items,
            station and function(b) return request_remove_key(player_gui, b) end
        )
        if station then
            station.request.items = items
            lib.ensure_hidden_combs(station.request.comb, station.request.hidden_combs, items)
        end
        request_io.combinator_description = lib.request_items_to_combinator_description(items)
    end

    if station and not lib.read_stop_flag(stop, enums.stop_flags.custom_name) then
        local provide, request = station.provide, station.request
        local old_stop_name = stop.backer_name --[[@as string]]
        local new_stop_name = lib.generate_stop_name(provide and provide.items, request and request.items)
        if old_stop_name ~= new_stop_name then
            if provide then rename_schedules_stop(provide.deliveries, old_stop_name, new_stop_name) end
            if request then rename_schedules_stop(request.deliveries, old_stop_name, new_stop_name) end
            stop.backer_name = new_stop_name
            player_gui.elements.stop_name_label.caption = new_stop_name
        end
    end
end

---@type GuiHandler
local handle_item_move = { [events.on_gui_click] = function(event)
    local flow = event.element.parent.parent --[[@as LuaGuiElement]]
    glib.move_row(flow.parent, flow.get_index_in_parent(), event.element.get_index_in_parent())
    update_station_after_change(event.player_index)
end }

---@type GuiHandler
local handle_provide_copy = {} -- defined later

---@type GuiHandler
local handle_request_copy = {} -- defined later

---@type GuiHandler
local handle_item_elem_changed = { [events.on_gui_elem_changed] = function(event)
    if not event.element.elem_value then
        glib.delete_row(event.element.parent, event.element.get_index_in_parent() - 1)
    end
    update_station_after_change(event.player_index)
end }

---@type GuiHandler
local handle_item_text_changed = { [events.on_gui_text_changed] = function(event)
    update_station_after_change(event.player_index)
end }

---@type GuiHandler
local handle_item_mode_click = { [events.on_gui_click] = function(event)
    set_active_mode_button(event.element.parent, event.element.get_index_in_parent())
    update_station_after_change(event.player_index)
end }

--------------------------------------------------------------------------------

---@param provide_table LuaGuiElement
---@param elem_type string
local function add_new_provide_row(provide_table, elem_type)
    glib.add_widgets(provide_table, nil, {
        { type = "flow", style = "vertical_flow", direction = "vertical", children = {
            { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = handle_item_move },
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = handle_item_move },
            } },
            { type = "sprite", style = "sspp_vertical_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = handle_provide_copy },
        } },
        { type = "choose-elem-button", style = "big_slot_button", elem_type = elem_type, handler = handle_item_elem_changed },
        { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.class" }), tooltip = { "sspp-gui.item-class-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-size" }), tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-time" }), tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
        } },
        { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.mode" }), tooltip = { "sspp-gui.provide-mode-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-1", tooltip = { "sspp-gui.provide-mode-tooltip-1" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-2", tooltip = { "sspp-gui.provide-mode-tooltip-2" }, toggled = true, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-3", tooltip = { "sspp-gui.provide-mode-tooltip-3" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-4", tooltip = { "sspp-gui.provide-mode-tooltip-4" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-5", tooltip = { "sspp-gui.provide-mode-tooltip-5" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-6", tooltip = { "sspp-gui.provide-mode-tooltip-6" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "sspp-signal-icon", tooltip = { "sspp-gui.provide-mode-tooltip-dynamic" }, handler = handle_item_mode_click },
                } },
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.throughput" }), tooltip = { "sspp-gui.provide-throughput-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "", handler = handle_item_text_changed },
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.latency" }), tooltip = { "sspp-gui.provide-latency-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "30", handler = handle_item_text_changed },
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.granularity" }), tooltip = { "sspp-gui.provide-granularity-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", style = "sspp_number_textbox", numeric = true, text = "1", handler = handle_item_text_changed },
            } },
        } },
        { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.storage-needed" }), tooltip = { "sspp-gui.provide-storage-needed-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.current-surplus" }), tooltip = { "sspp-gui.provide-current-surplus-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
        } },
    })
end

---@param request_table LuaGuiElement
---@param elem_type string
local function add_new_request_row(request_table, elem_type)
    glib.add_widgets(request_table, nil, {
        { type = "flow", style = "vertical_flow", direction = "vertical", children = {
            { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = handle_item_move },
                { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = handle_item_move },
            } },
            { type = "sprite", style = "sspp_vertical_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
            { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = handle_request_copy },
        } },
        { type = "choose-elem-button", style = "big_slot_button", elem_type = elem_type, handler = handle_item_elem_changed },
        { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.class" }), tooltip = { "sspp-gui.item-class-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-size" }), tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-time" }), tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
        } },
        { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.mode" }), tooltip = { "sspp-gui.request-mode-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-1", tooltip = { "sspp-gui.request-mode-tooltip-1" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-2", tooltip = { "sspp-gui.request-mode-tooltip-2" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-3", tooltip = { "sspp-gui.request-mode-tooltip-3" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-4", tooltip = { "sspp-gui.request-mode-tooltip-4" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-5", tooltip = { "sspp-gui.request-mode-tooltip-5" }, toggled = true, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-6", tooltip = { "sspp-gui.request-mode-tooltip-6" }, handler = handle_item_mode_click },
                    { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "sspp-signal-icon", tooltip = { "sspp-gui.request-mode-tooltip-dynamic" }, handler = handle_item_mode_click },
                } },
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.throughput" }), tooltip = { "sspp-gui.request-throughput-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "", handler = handle_item_text_changed },
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.latency" }), tooltip = { "sspp-gui.request-latency-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "30", handler = handle_item_text_changed },
            } },
        } },
        { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.storage-needed" }), tooltip = { "sspp-gui.request-storage-needed-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
            { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.current-deficit" }), tooltip = { "sspp-gui.request-current-surplus-tooltip" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "label", style = "label" }
            } },
        } },
    })
end

---@param player_id PlayerId
---@param table_name string
---@param inner function
---@param elem_type string
---@return boolean success
local function try_add_item_or_fluid(player_id, table_name, inner, elem_type)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]
    local table = player_gui.elements[table_name]

    if lib.read_stop_flag(stop, enums.stop_flags.bufferless) then
        if get_total_rows(player_gui.elements) == 0 then
            inner(table, elem_type)
            set_buffer_settings_enabled(table, false)
            update_station_after_change(player_id)
            return true
        end
    elseif #table.children < table.column_count * 10 then
        inner(table, elem_type)
        return true
    end

    game.get_player(player_id).play_sound({ path = "utility/cannot_build" })
    return false
end

--------------------------------------------------------------------------------

handle_provide_copy[events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    local table = flow.parent --[[@as LuaGuiElement]]

    local i = flow.get_index_in_parent() - 1
    local elem_type = table.children[i + 2].elem_type
    if not try_add_item_or_fluid(event.player_index, "provide_table", add_new_provide_row, elem_type) then return end

    local j = i + table.column_count
    glib.insert_newly_added_row(table, j)

    local table_children = table.children
    set_active_mode_button(table_children[j + 4].children[1].children[3], get_active_mode_button(table_children[i + 4].children[1].children[3]))
    table_children[j + 4].children[2].children[3].text = table_children[i + 4].children[2].children[3].text
    table_children[j + 4].children[3].children[3].text = table_children[i + 4].children[3].children[3].text
    table_children[j + 4].children[4].children[3].text = table_children[i + 4].children[4].children[3].text
end

handle_request_copy[events.on_gui_click] = function(event)
    local flow = event.element.parent --[[@as LuaGuiElement]]
    local table = flow.parent --[[@as LuaGuiElement]]

    local i = flow.get_index_in_parent() - 1
    local elem_type = table.children[i + 2].elem_type
    if not try_add_item_or_fluid(event.player_index, "request_table", add_new_request_row, elem_type) then return end

    local j = i + table.column_count
    glib.insert_newly_added_row(table, j)

    local table_children = table.children
    set_active_mode_button(table_children[j + 4].children[1].children[3], get_active_mode_button(table_children[i + 4].children[1].children[3]))
    table_children[j + 4].children[2].children[3].text = table_children[i + 4].children[2].children[3].text
    table_children[j + 4].children[3].children[3].text = table_children[i + 4].children[3].children[3].text
end

--------------------------------------------------------------------------------

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

    set_active_mode_button(table_children[i + 4].children[1].children[3], item.mode)
    table_children[i + 4].children[2].children[3].text = tostring(item.throughput)
    table_children[i + 4].children[3].children[3].text = tostring(item.latency)
    table_children[i + 4].children[4].children[3].text = tostring(item.granularity)

    table_children[i + 1].children[2].sprite = ""
    table_children[i + 1].children[2].tooltip = nil
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

    set_active_mode_button(table_children[i + 4].children[1].children[3], item.mode)
    table_children[i + 4].children[2].children[3].text = tostring(item.throughput)
    table_children[i + 4].children[3].children[3].text = tostring(item.latency)

    table_children[i + 1].children[2].sprite = ""
    table_children[i + 1].children[2].tooltip = nil
end

--------------------------------------------------------------------------------

---@param player_gui PlayerGui.Station
function gui_station.on_poll_finished(player_gui)
    local parts = player_gui.parts
    if not parts then return end
    local station = storage.stations[parts.stop.unit_number] --[[@as Station?]]
    if not station then return end
    local provide, request = station.provide, station.request

    local elements = player_gui.elements

    local grid_table = elements.grid_table
    local grid_children = grid_table.children

    -- minimap reuse doesn't really matter for stations, but the code already exists for networks
    local old_length, new_length = #grid_children, 0

    if provide then
        local table_children = elements.provide_table.children
        local dynamic_index = -1 -- zero based

        for i = 0, #table_children - 1, elements.provide_table.column_count do
            if table_children[i + 1].children[2].sprite == "" then
                local _, quality, item_key = extract_elem_value_fields(table_children[i + 2].elem_value)
                local dynamic_button = table_children[i + 4].children[1].children[3].children[7]

                local dynamic_sprite, dynamic_tooltip = "sspp-signal-icon", { "sspp-gui.provide-mode-tooltip-dynamic" }
                if dynamic_button.toggled then
                    dynamic_index = dynamic_index + 1
                    dynamic_sprite = "virtual-signal/sspp-signal-" .. tostring(dynamic_index)
                    local provide_mode = provide.modes[item_key]
                    if provide_mode then
                        dynamic_tooltip = { "sspp-gui.fmt-dynamic-mode-active-tooltip", dynamic_tooltip, provide_mode }
                    end
                end
                dynamic_button.sprite, dynamic_button.tooltip = dynamic_sprite, dynamic_tooltip

                local provide_count = provide.counts[item_key]
                if provide_count then
                    table_children[i + 5].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", provide_count }
                end
            end
        end

        for item_key, hauler_ids in pairs(provide.deliveries) do
            local name, quality = split_item_key(item_key)
            local icon = make_item_icon(name, quality)

            for _, hauler_id in pairs(hauler_ids) do
                new_length = new_length + 1
                local minimap, top, bottom = acquire_next_minimap(grid_table, grid_children, old_length, new_length)
                local train = storage.haulers[hauler_id].train
                minimap.entity = train.front_stock
                top.caption = "[img=virtual-signal/up-arrow]"
                bottom.caption = tostring(get_train_item_count(train, name, quality)) .. icon
            end
        end
    end

    if request then
        local table_children = elements.request_table.children
        local dynamic_index = -1 -- zero based

        for i = 0, #table_children - 1, elements.request_table.column_count do
            if table_children[i + 1].children[2].sprite == "" then
                local _, quality, item_key = extract_elem_value_fields(table_children[i + 2].elem_value)
                local dynamic_button = table_children[i + 4].children[1].children[3].children[7]

                local dynamic_sprite, dynamic_tooltip = "sspp-signal-icon", { "sspp-gui.request-mode-tooltip-dynamic" }
                if dynamic_button.toggled then
                    dynamic_index = dynamic_index + 1
                    dynamic_sprite = "virtual-signal/sspp-signal-" .. tostring(dynamic_index)
                    local request_mode = request.modes[item_key]
                    if request_mode then
                        dynamic_tooltip = { "sspp-gui.fmt-dynamic-mode-active-tooltip", dynamic_tooltip, request_mode }
                    end
                end
                dynamic_button.sprite, dynamic_button.tooltip = dynamic_sprite, dynamic_tooltip

                local request_count = request.counts[item_key]
                if request_count then
                    table_children[i + 5].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", request_count }
                end
            end
        end

        for item_key, hauler_ids in pairs(request.deliveries) do
            local name, quality = split_item_key(item_key)
            local icon = make_item_icon(name, quality)

            for _, hauler_id in pairs(hauler_ids) do
                new_length = new_length + 1
                local minimap, top, bottom = acquire_next_minimap(grid_table, grid_children, old_length, new_length)
                local train = storage.haulers[hauler_id].train
                minimap.entity = train.front_stock
                top.caption = "[img=virtual-signal/down-arrow]"
                bottom.caption = tostring(get_train_item_count(train, name, quality)) .. icon
            end
        end
    end

    for i = old_length, new_length + 1, -1 do
        grid_children[i].destroy()
    end
end

--------------------------------------------------------------------------------

---@type GuiHandler
local handle_open_network = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local network_name = storage.player_guis[player_id].network

    gui_network.open(player_id, network_name, 2)
end }

---@type GuiHandler
local handle_edit_name_toggled = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    if event.element.toggled then
        if not player_gui.elements.stop_name_clear_button.enabled then
            player_gui.elements.stop_name_input.text = stop.backer_name
        end
        player_gui.elements.stop_name_label.visible = false
        player_gui.elements.stop_name_input.visible = true
        player_gui.elements.stop_name_input.focus()
    else
        player_gui.elements.stop_name_label.caption = stop.backer_name
        player_gui.elements.stop_name_input.visible = false
        player_gui.elements.stop_name_label.visible = true
    end
end }

---@type GuiHandler
local handle_clear_name = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    lib.write_stop_flag(stop, enums.stop_flags.custom_name, false)

    local station = storage.stations[stop.unit_number] --[[@as Station?]]
    local new_stop_name ---@type string
    if station then
        local provide, request = station.provide, station.request
        local old_stop_name = stop.backer_name --[[@as string]]
        new_stop_name = lib.generate_stop_name(provide and provide.items, request and request.items)
        if provide then rename_schedules_stop(provide.deliveries, old_stop_name, new_stop_name) end
        if request then rename_schedules_stop(request.deliveries, old_stop_name, new_stop_name) end
    else
        new_stop_name = "[virtual-signal=signal-ghost]"
    end
    stop.backer_name = new_stop_name
    player_gui.elements.stop_name_label.caption = new_stop_name

    player_gui.elements.stop_name_input.visible = false
    player_gui.elements.stop_name_label.visible = true

    player_gui.elements.stop_name_edit_toggle.toggled = false
    player_gui.elements.stop_name_clear_button.enabled = false
end }

---@type GuiHandler
local handle_name_changed_or_confirmed = {}

handle_name_changed_or_confirmed[events.on_gui_text_changed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    local new_stop_name = glib.truncate_input(event.element, 199)
    local has_custom_name = new_stop_name ~= ""
    player_gui.elements.stop_name_clear_button.enabled = has_custom_name
    lib.write_stop_flag(stop, enums.stop_flags.custom_name, has_custom_name)

    local station = storage.stations[stop.unit_number] --[[@as Station?]]
    if station then
        local provide, request = station.provide, station.request
        local old_stop_name = stop.backer_name --[[@as string]]
        if not has_custom_name then
            new_stop_name = lib.generate_stop_name(provide and provide.items, request and request.items)
        end
        if provide then rename_schedules_stop(provide.deliveries, old_stop_name, new_stop_name) end
        if request then rename_schedules_stop(request.deliveries, old_stop_name, new_stop_name) end
    elseif not has_custom_name then
        new_stop_name = "[virtual-signal=signal-ghost]"
    end
    stop.backer_name = new_stop_name
end

handle_name_changed_or_confirmed[events.on_gui_confirmed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    player_gui.elements.stop_name_label.caption = stop.backer_name
    player_gui.elements.stop_name_input.visible = false
    player_gui.elements.stop_name_label.visible = true

    player_gui.elements.stop_name_edit_toggle.toggled = false
end

---@type GuiHandler
local handle_disable_toggled = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    local toggled = event.element.toggled
    event.element.tooltip = { toggled and "sspp-gui.station-disabled-tooltip" or "sspp-gui.station-enabled-tooltip" }
    lib.write_stop_flag(stop, enums.stop_flags.disable, toggled)
end }

---@type GuiHandler
local handle_limit_changed = { [events.on_gui_value_changed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    stop.trains_limit = event.element.slider_value
    player_gui.elements.limit_value.caption = tostring(event.element.slider_value)
end }

---@type GuiHandler
local handle_bufferless_toggled = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    local toggled = event.element.toggled
    local total_rows = get_total_rows(player_gui.elements)

    if toggled and total_rows > 1 then
        event.element.toggled = false
        game.get_player(event.player_index).play_sound({ path = "utility/cannot_build" })
        return
    end

    event.element.tooltip = { toggled and "sspp-gui.station-bufferless-tooltip" or "sspp-gui.station-buffered-tooltip" }
    lib.write_stop_flag(stop, enums.stop_flags.bufferless, toggled)

    if total_rows > 0 then
        local provide_table, request_table = player_gui.elements.provide_table, player_gui.elements.request_table
        if provide_table then set_buffer_settings_enabled(provide_table, not toggled) end
        if request_table then set_buffer_settings_enabled(request_table, not toggled) end

        local station = storage.stations[stop.unit_number] --[[@as Station?]]
        if station and station.provide then
            for item_key, hauler_ids in pairs(station.provide.deliveries) do
                for _, hauler_id in pairs(hauler_ids) do
                    local network, hauler = storage.networks[station.network], storage.haulers[hauler_id]
                    local job = network.jobs[hauler.job] --[[@as NetworkJob]]
                    if toggled then
                        lib.list_destroy_or_remove(network.provide_haulers, item_key, hauler_id)
                        lib.list_create_or_append(network.buffer_haulers, item_key, hauler_id)
                        job.type = "PICKUP"
                        job.finish_tick = job.provide_done_tick
                        job.provide_done_tick = nil
                    else
                        station.bufferless_dispatch = nil
                        lib.list_destroy_or_remove(network.buffer_haulers, item_key, hauler_id)
                        lib.list_create_or_append(network.provide_haulers, item_key, hauler_id)
                        job.type = "COMBINED"
                        job.provide_done_tick = job.finish_tick
                        job.finish_tick = nil
                    end
                end
            end
        end

        update_station_after_change(event.player_index)
    end
end }

---@type GuiHandler
local handle_inactivity_toggled = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Station]]
    local stop = player_gui.parts.stop --[[@as LuaEntity]]

    local toggled = event.element.toggled

    event.element.tooltip = { toggled and "sspp-gui.station-wait-for-inactivity-tooltip" or "sspp-gui.station-depart-immediately-tooltip" }
    lib.write_stop_flag(stop, enums.stop_flags.inactivity, toggled)
end }

---@type GuiHandler
local handle_add_provide_item = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "provide_table", add_new_provide_row, "item-with-quality")
end }

---@type GuiHandler
local handle_add_provide_fluid = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "provide_table", add_new_provide_row, "fluid")
end }

---@type GuiHandler
local handle_add_request_item = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "request_table", add_new_request_row, "item-with-quality")
end }

---@type GuiHandler
local handle_add_request_fluid = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid(event.player_index, "request_table", add_new_request_row, "fluid")
end }

---@type GuiHandler
local handle_view_on_map = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local stop = storage.player_guis[event.player_index].parts.stop --[[@as LuaEntity]]

    player.opened = nil
    player.centered_on = stop
end }

---@type GuiHandler
local handle_close_window = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    assert(player.opened.name == "sspp-station")

    player.opened = nil
end }

--------------------------------------------------------------------------------

---@param player LuaPlayer
---@param parts StationParts
---@return LuaGuiElement window, {[string]: LuaGuiElement} elements
local function add_gui_complete(player, parts)
    local custom_name = lib.read_stop_flag(parts.stop, enums.stop_flags.custom_name)
    local disable = lib.read_stop_flag(parts.stop, enums.stop_flags.disable)
    local bufferless = lib.read_stop_flag(parts.stop, enums.stop_flags.bufferless)
    local inactivity = lib.read_stop_flag(parts.stop, enums.stop_flags.inactivity)

    local disable_tooltip = { disable and "sspp-gui.station-disabled-tooltip" or "sspp-gui.station-enabled-tooltip" }
    local bufferless_tooltip = { bufferless and "sspp-gui.station-bufferless-tooltip" or "sspp-gui.station-buffered-tooltip" }
    local inactivity_tooltip = { inactivity and "sspp-gui.station-wait-for-inactivity-tooltip" or "sspp-gui.station-depart-immediately-tooltip" }

    local name = parts.stop.backer_name
    local limit = parts.stop.trains_limit
    local provide = parts.provide_io ~= nil
    local request = parts.request_io ~= nil

    local window, elements = glib.add_widget(player.gui.screen, {},
        { type = "frame", name = "sspp-station", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", direction = "horizontal", drag_target = "sspp-station", children = {
                { type = "label", style = "frame_title", caption = { "entity-name.sspp-stop" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "sprite-button", style = "frame_action_button", sprite = "sspp-disable-icon", tooltip = disable_tooltip, mouse_button_filter = { "left" }, auto_toggle = true, toggled = disable, handler = handle_disable_toggled },
                { type = "sprite-button", style = "frame_action_button", sprite = "sspp-map-icon", tooltip = { "sspp-gui.view-on-map" }, mouse_button_filter = { "left" }, handler = handle_view_on_map },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, tooltip = { "shortcut-name.sspp" }, mouse_button_filter = { "left" }, handler = handle_open_network },
                { type = "empty-widget", style = "empty_widget" },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", mouse_button_filter = { "left" }, handler = handle_close_window },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", direction = "horizontal", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", name = "stop_name_label", style = "subheader_caption_label", caption = name },
                        { type = "textfield", name = "stop_name_input", style = "sspp_subheader_caption_textbox", icon_selector = true, text = name, visible = false, handler = handle_name_changed_or_confirmed },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        { type = "sprite-button", name = "stop_name_edit_toggle", style = "control_settings_section_button", sprite = "sspp-name-icon", tooltip = { "sspp-gui.edit-custom-name" }, auto_toggle = true, handler = handle_edit_name_toggled },
                        { type = "sprite-button", name = "stop_name_clear_button", style = "control_settings_section_button", sprite = "sspp-reset-icon", tooltip = { "sspp-gui.clear-custom-name" }, enabled = custom_name, handler = handle_clear_name },
                    } },
                    { type = "tabbed-pane", name = "tabbed_pane", style = "tabbed_pane", children = {
                        { type = "tab", style = "tab", caption = { "sspp-gui.provide" }, visible = provide, children = {
                            { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
                                { type = "table", style = "sspp_station_item_header", column_count = 5, children = {
                                    { type = "empty-widget" },
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.network-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.station-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.statistics" } },
                                } },
                                { type = "scroll-pane", style = "sspp_station_scroll_pane", direction = "vertical", children = {
                                    { type = "table", name = "provide_table", style = "sspp_station_item_table", column_count = 5 },
                                    { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, handler = handle_add_provide_item },
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, handler = handle_add_provide_fluid },
                                    } },
                                } },
                            } },
                        } },
                        { type = "tab", style = "tab", caption = { "sspp-gui.request" }, visible = request, children = {
                            { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
                                { type = "table", style = "sspp_station_item_header", column_count = 5, children = {
                                    { type = "empty-widget" },
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.network-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.station-settings" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.statistics" } },
                                } },
                                { type = "scroll-pane", style = "sspp_station_scroll_pane", direction = "vertical", children = {
                                    { type = "table", name = "request_table", style = "sspp_station_item_table", column_count = 5 },
                                    { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, mouse_button_filter = { "left" }, handler = handle_add_request_item },
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, mouse_button_filter = { "left" }, handler = handle_add_request_fluid },
                                    } },
                                } },
                            } },
                        } },
                    } },
                } },
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", style = "subheader_caption_label", caption = { "sspp-gui.deliveries" } },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.limit" }), tooltip = { "sspp-gui.station-limit-tooltip" } },
                        { type = "slider", style = "notched_slider", minimum_value = 1, maximum_value = 10, value = limit, handler = handle_limit_changed },
                        { type = "label", name = "limit_value", style = "sspp_station_limit_value", caption = tostring(limit) },
                        { type = "sprite-button", name = "bufferless_toggle", style = "control_settings_section_button", sprite = "sspp-bufferless-icon", tooltip = bufferless_tooltip, auto_toggle = true, toggled = bufferless, handler = handle_bufferless_toggled },
                        { type = "sprite-button", name = "inactivity_toggle", style = "control_settings_section_button", sprite = "sspp-inactivity-icon", tooltip = inactivity_tooltip, auto_toggle = true, toggled = inactivity, visible = provide, handler = handle_inactivity_toggled },
                    } },
                    { type = "frame", style = "shallow_frame", direction = "horizontal", children = {
                        { type = "scroll-pane", style = "sspp_right_grid_scroll_pane", direction = "vertical", children = {
                            { type = "table", name = "grid_table", style = "sspp_grid_table", column_count = 3 },
                        } },
                    } },
                } },
            } },
        } }
    ) ---@cast elements -nil

    elements.tabbed_pane.selected_tab_index = provide and 1 or 2

    return window, elements
end

---@param player LuaPlayer
---@return LuaGuiElement window, {[string]: LuaGuiElement} elements
local function add_gui_incomplete(player)
    local window, elements = glib.add_widget(player.gui.screen, {},
        { type = "frame", name = "sspp-station", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", direction = "horizontal", drag_target = "sspp-station", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.incomplete-station" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = handle_close_window },
            } },
            { type = "label", style = "info_label", caption = { "sspp-gui.incomplete-station-message" } },
        } }
    ) ---@cast elements -nil

    return window, elements
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param entity LuaEntity
function gui_station.open(player_id, entity)
    local player = assert(game.get_player(player_id))
    local unit_number = entity.unit_number --[[@as uint]]
    local parts = get_station_parts(entity)
    local network_name = entity.surface.name

    player.opened = nil

    local window, elements ---@type LuaGuiElement, {[string]: LuaGuiElement}
    if parts then
        window, elements = add_gui_complete(player, parts)
    else
        window, elements = add_gui_incomplete(player)
    end

    window.force_auto_center()
    storage.player_guis[player_id] = { type = "STATION", network = network_name, elements = elements, unit_number = unit_number, parts = parts }

    if parts then
        local provide_io, request_io = parts.provide_io, parts.request_io
        local network_items = storage.networks[network_name].items
        local buffered = not lib.read_stop_flag(parts.stop, enums.stop_flags.bufferless)
        if provide_io then
            local provide_table = elements.provide_table
            for item_key, item in pairs(lib.combinator_description_to_provide_items(provide_io)) do
                provide_init_row(network_items, provide_table, item_key, item)
            end
            set_buffer_settings_enabled(provide_table, buffered)
        end
        if request_io then
            local request_table = elements.request_table
            for item_key, item in pairs(lib.combinator_description_to_request_items(request_io)) do
                request_init_row(network_items, request_table, item_key, item)
            end
            set_buffer_settings_enabled(request_table, buffered)
        end
    end

    player.opened = window
end

---@param player_id PlayerId
function gui_station.close(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Station]]
    player_gui.elements["sspp-station"].destroy()

    local entity = storage.entities[player_gui.unit_number]

    if entity.valid and entity.name ~= "entity-ghost" then
        local player = game.get_player(player_id) --[[@as LuaPlayer]]
        player.play_sound({ path = "entity-close/sspp-stop" })
    end

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

function gui_station.initialise()
    glib.register_functions({
        ["station_item_move"] = handle_item_move[events.on_gui_click],
        ["station_provide_copy"] = handle_provide_copy[events.on_gui_click],
        ["station_request_copy"] = handle_request_copy[events.on_gui_click],
        ["station_item_elem_changed"] = handle_item_elem_changed[events.on_gui_elem_changed],
        ["station_item_text_changed"] = handle_item_text_changed[events.on_gui_text_changed],
        ["station_item_mode_click"] = handle_item_mode_click[events.on_gui_click],
        ["station_open_network"] = handle_open_network[events.on_gui_click],
        ["station_edit_name_toggled"] = handle_edit_name_toggled[events.on_gui_click],
        ["station_clear_name"] = handle_clear_name[events.on_gui_click],
        ["station_name_changed"] = handle_name_changed_or_confirmed[events.on_gui_text_changed],
        ["station_name_confirmed"] = handle_name_changed_or_confirmed[events.on_gui_confirmed],
        ["station_disable_toggled"] = handle_disable_toggled[events.on_gui_click],
        ["station_bufferless_toggled"] = handle_bufferless_toggled[events.on_gui_click],
        ["station_inactivity_toggled"] = handle_inactivity_toggled[events.on_gui_click],
        ["station_limit_changed"] = handle_limit_changed[events.on_gui_value_changed],
        ["station_add_provide_item"] = handle_add_provide_item[events.on_gui_click],
        ["station_add_provide_fluid"] = handle_add_provide_fluid[events.on_gui_click],
        ["station_add_request_item"] = handle_add_request_item[events.on_gui_click],
        ["station_add_request_fluid"] = handle_add_request_fluid[events.on_gui_click],
        ["station_view_on_map"] = handle_view_on_map[events.on_gui_click],
        ["station_close_window"] = handle_close_window[events.on_gui_click],
    })
end

--------------------------------------------------------------------------------

return gui_station
