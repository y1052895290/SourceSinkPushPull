-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local glib = require("__SourceSinkPushPull__.scripts.glib")
local enums = require("__SourceSinkPushPull__.scripts.enums")

local gui_network = require("__SourceSinkPushPull__.scripts.gui.network")

local events = defines.events

local split_item_key, make_item_icon, get_train_item_count = lib.split_item_key, lib.make_item_icon, lib.get_train_item_count

local cwi, acquire_next_minimap = glib.caption_with_info, glib.acquire_next_minimap

---@class sspp.gui.station
local gui_station = {}

--------------------------------------------------------------------------------

--- Find all of the entities that would make up a station, even if they are ghosts.
---@param entity LuaEntity
---@return GhostStation?, Station?
local function get_station_ghost(entity)
    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    local stop ---@type LuaEntity
    if name == "sspp-stop" then
        stop = entity
    else
        local stop_ids = storage.comb_stop_ids[entity.unit_number]
        if #stop_ids ~= 1 then return end
        stop = storage.entities[stop_ids[1]]
    end

    local station = storage.stations[stop.unit_number]
    if station then return station, station end

    local comb_ids = storage.stop_comb_ids[stop.unit_number]

    local combs_by_name = {} ---@type {[string]: LuaEntity?}

    for _, comb_id in pairs(comb_ids) do
        if #storage.comb_stop_ids[comb_id] ~= 1 then return end

        local comb = storage.entities[comb_id]
        name = comb.name
        if name == "entity-ghost" then name = comb.ghost_name end
        if combs_by_name[name] then return end

        combs_by_name[name] = comb
    end

    local general_io = combs_by_name["sspp-general-io"]
    if not general_io then return end

    local provide_io = combs_by_name["sspp-provide-io"]
    local request_io = combs_by_name["sspp-request-io"]
    if not (provide_io or request_io) then return end

    local unit_numbers = { [stop.unit_number] = true, [general_io.unit_number] = true }

    if provide_io then unit_numbers[provide_io.unit_number] = true end
    if request_io then unit_numbers[request_io.unit_number] = true end

    ---@type GhostStation
    return {
        stop = lib.read_station_stop_settings(stop),
        general = lib.read_station_general_settings(general_io),
        provide = provide_io and lib.read_station_provide_settings(provide_io),
        request = request_io and lib.read_station_request_settings(request_io),
        unit_numbers = unit_numbers,
    }
end

--------------------------------------------------------------------------------

---@param deliveries {[ItemKey]: HaulerId[]}
---@param old_stop_name string
---@param new_stop_name string
local function update_station_name_in_schedules(deliveries, old_stop_name, new_stop_name)
    for _, hauler_ids in pairs(deliveries) do
        for _, hauler_id in pairs(hauler_ids) do
            local train = storage.haulers[hauler_id].train
            local schedule = train.schedule --[[@as TrainSchedule]]
            for _, record in pairs(schedule.records) do
                if record.station == old_stop_name then record.station = new_stop_name end
            end
            train.schedule = schedule
        end
    end
end

---@param root GuiRoot.Station
---@param new_stop_name string?
local function update_station_name(root, new_stop_name)
    local old_stop_name = root.ghost.stop.entity.backer_name ---@cast old_stop_name -nil

    if not new_stop_name then
        if root.station then
            local provide, request = root.station.provide, root.station.request
            new_stop_name = lib.generate_stop_name(provide and provide.items, request and request.items)
        else
            new_stop_name = "[virtual-signal=signal-ghost]"
        end
    end

    if old_stop_name ~= new_stop_name then
        root.ghost.stop.entity.backer_name = new_stop_name
        if root.station then
            local provide, request = root.station.provide, root.station.request
            if provide then update_station_name_in_schedules(provide.deliveries, old_stop_name, new_stop_name) end
            if request then update_station_name_in_schedules(request.deliveries, old_stop_name, new_stop_name) end
        end
        root.elements.stop_name_label.caption = new_stop_name
    end
end

--------------------------------------------------------------------------------

---@type GuiTableMethods
local provide_methods = {} ---@diagnostic disable-line: missing-fields

---@type GuiTableMethods
local request_methods = {} ---@diagnostic disable-line: missing-fields

--------------------------------------------------------------------------------

---@param flow LuaGuiElement
---@return ItemMode mode
local function get_active_mode_button(flow)
    for index, button in pairs(flow.children) do
        if button.toggled then
            return index
        end
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

---@generic Object
---@param methods GuiTableMethods
---@param context GuiTableContext<GuiRoot.Station, ItemKey, Object>
---@param player_id PlayerId
---@param button LuaGuiElement
local function try_copy_item_or_fluid_row(methods, context, player_id, button)
    if not context.root.ghost.stop.bufferless and #context.rows < 10 then
        glib.table_copy_row(methods, context, button)
    else
        game.get_player(player_id).play_sound({ path = "utility/cannot_build" })
    end
end

glib.handlers["station_provide_move"] = { [events.on_gui_click] = function(event)
    glib.table_move_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.element)
end }

glib.handlers["station_request_move"] = { [events.on_gui_click] = function(event)
    glib.table_move_row(request_methods, storage.player_guis[event.player_index].request_context, event.element)
end }

glib.handlers["station_provide_copy"] = { [events.on_gui_click] = function(event)
    try_copy_item_or_fluid_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.player_index, event.element)
end }

glib.handlers["station_request_copy"] = { [events.on_gui_click] = function(event)
    try_copy_item_or_fluid_row(request_methods, storage.player_guis[event.player_index].request_context, event.player_index, event.element)
end }

glib.handlers["station_provide_elem_changed"] = { [events.on_gui_elem_changed] = function(event)
    if event.element.elem_value then
        glib.table_modify_mutable_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.element)
    else
        glib.table_remove_mutable_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.element)
    end
end }

glib.handlers["station_request_elem_changed"] = { [events.on_gui_elem_changed] = function(event)
    if event.element.elem_value then
        glib.table_modify_mutable_row(request_methods, storage.player_guis[event.player_index].request_context, event.element)
    else
        glib.table_remove_mutable_row(request_methods, storage.player_guis[event.player_index].request_context, event.element)
    end
end }

glib.handlers["station_provide_text_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.table_modify_mutable_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.element)
end }

glib.handlers["station_request_text_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.table_modify_mutable_row(request_methods, storage.player_guis[event.player_index].request_context, event.element)
end }

glib.handlers["station_provide_mode_click"] = { [events.on_gui_click] = function(event)
    set_active_mode_button(event.element.parent, event.element.get_index_in_parent())
    glib.table_modify_mutable_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.element)
end }

glib.handlers["station_request_mode_click"] = { [events.on_gui_click] = function(event)
    set_active_mode_button(event.element.parent, event.element.get_index_in_parent())
    glib.table_modify_mutable_row(request_methods, storage.player_guis[event.player_index].request_context, event.element)
end }

--------------------------------------------------------------------------------

---@type GuiElementDef[]
local provide_blank_row_defs = {
    { type = "flow", style = "vertical_flow", direction = "vertical", children = {
        { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = "station_provide_move" },
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = "station_provide_move" },
        } },
        { type = "sprite", style = "sspp_vertical_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = "station_provide_copy" },
    } },
    { type = "choose-elem-button", style = "big_slot_button", handler = "station_provide_elem_changed" }, -- [2].elem_type
    { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.class" }), tooltip = { "sspp-gui.item-class-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-size" }), tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-time" }), tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
    } },
    { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.mode" }), tooltip = { "sspp-gui.provide-mode-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-1", tooltip = { "sspp-gui.provide-mode-tooltip-1" }, handler = "station_provide_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-2", tooltip = { "sspp-gui.provide-mode-tooltip-2" }, toggled = true, handler = "station_provide_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-3", tooltip = { "sspp-gui.provide-mode-tooltip-3" }, handler = "station_provide_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-4", tooltip = { "sspp-gui.provide-mode-tooltip-4" }, handler = "station_provide_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-5", tooltip = { "sspp-gui.provide-mode-tooltip-5" }, handler = "station_provide_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-provide-mode-6", tooltip = { "sspp-gui.provide-mode-tooltip-6" }, handler = "station_provide_mode_click" },
                { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "sspp-signal-icon", tooltip = { "sspp-gui.provide-mode-tooltip-dynamic" }, handler = "station_provide_mode_click" },
            } },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.throughput" }), tooltip = { "sspp-gui.provide-throughput-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "", handler = "station_provide_text_changed" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.latency" }), tooltip = { "sspp-gui.provide-latency-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "30", handler = "station_provide_text_changed" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.granularity" }), tooltip = { "sspp-gui.provide-granularity-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "textfield", style = "sspp_number_textbox", numeric = true, text = "1", handler = "station_provide_text_changed" },
        } },
    } },
    { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.storage-needed" }), tooltip = { "sspp-gui.provide-storage-needed-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.current-surplus" }), tooltip = { "sspp-gui.provide-current-surplus-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
    } },
}

function provide_methods.insert_row_blank(context, row_offset, elem_type)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>
    ---@cast elem_type string

    provide_blank_row_defs[2].elem_type = elem_type

    return glib.add_elements(context.table, nil, row_offset, provide_blank_row_defs)
end

function provide_methods.insert_row_complete(context, row_offset, item_key, provide_item)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>
    ---@cast item_key ItemKey
    ---@cast provide_item ProvideItem

    local name, quality = split_item_key(item_key)
    local cells = provide_methods.insert_row_blank(context, row_offset, quality and "item-with-quality" or "fluid")

    cells[2].elem_value = quality and { name = name, quality = quality } or name

    set_active_mode_button(cells[4].children[1].children[3], provide_item.mode)
    cells[4].children[2].children[3].text = tostring(provide_item.throughput)
    cells[4].children[3].children[3].text = tostring(provide_item.latency)
    cells[4].children[4].children[3].text = tostring(provide_item.granularity)

    cells[1].children[2].sprite = ""
    cells[1].children[2].tooltip = nil

    local network_item = storage.networks[context.root.ghost.general.network].items[item_key]
    if network_item then
        cells[3].children[1].children[3].caption = network_item.class
        cells[3].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", network_item.delivery_size }
        cells[3].children[3].children[3].caption = { "sspp-gui.fmt-seconds", network_item.delivery_time }

        cells[5].children[1].children[3].caption = { quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units", lib.compute_storage_needed(network_item, provide_item) / (quality and prototypes.item[name].stack_size or 1) }
    end

    return cells
end

function provide_methods.insert_row_copy(context, row_offset, src_cells)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>

    local cells = provide_methods.insert_row_blank(context, row_offset, src_cells[2].elem_type)

    set_active_mode_button(cells[4].children[1].children[3], get_active_mode_button(src_cells[4].children[1].children[3]))
    cells[4].children[2].children[3].text = src_cells[4].children[2].children[3].text
    cells[4].children[3].children[3].text = src_cells[4].children[3].children[3].text
    cells[4].children[4].children[3].text = src_cells[4].children[4].children[3].text

    return cells
end

function provide_methods.make_object(context, cells)
    local elem_value = cells[2].elem_value --[[@as (table|string)?]]
    if not elem_value then return end

    local throughput = tonumber(cells[4].children[2].children[3].text)
    if not throughput then return end

    local latency = tonumber(cells[4].children[3].children[3].text)
    if not latency then return end

    local granularity = tonumber(cells[4].children[4].children[3].text)
    if not granularity or granularity < 1 then return end

    local _, _, item_key = glib.extract_elem_value_fields(elem_value)

    return item_key, {
        mode = get_active_mode_button(cells[4].children[1].children[3]),
        throughput = throughput,
        latency = latency,
        granularity = granularity,
    } --[[@as ProvideItem]]
end

function provide_methods.filter_object(context, item_key, provide_item)
    return true
end

function provide_methods.on_row_changed(context, cells, item_key, provide_item)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>
    ---@cast item_key ItemKey?
    ---@cast provide_item ProvideItem?

    local name, quality = nil, nil
    if item_key then
        name, quality = split_item_key(item_key)
    else
        local elem_value = cells[2].elem_value
        if elem_value then
            name, quality, item_key = glib.extract_elem_value_fields(elem_value)
        end
    end

    local network_item = item_key and storage.networks[context.root.ghost.general.network].items[item_key]
    if network_item then
        cells[3].children[1].children[3].caption = network_item.class
        cells[3].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", network_item.delivery_size }
        cells[3].children[3].children[3].caption = { "sspp-gui.fmt-seconds", network_item.delivery_time }
    else
        cells[3].children[1].children[3].caption = ""
        cells[3].children[2].children[3].caption = ""
        cells[3].children[3].children[3].caption = ""
    end

    if provide_item then
        cells[1].children[2].sprite = ""
        cells[1].children[2].tooltip = nil
    else
        cells[1].children[2].sprite = "utility/achievement_warning"
        cells[1].children[2].tooltip = { "sspp-gui.invalid-values-tooltip" }
    end

    if network_item and provide_item then
        cells[5].children[1].children[3].caption = { quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units", lib.compute_storage_needed(network_item, provide_item) / (quality and prototypes.item[name].stack_size or 1) }
    else
        cells[5].children[1].children[3].caption = ""
        cells[5].children[2].children[3].caption = ""
    end
end

function provide_methods.on_object_changed(context, item_key, provide_item)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>
    ---@cast item_key ItemKey
    ---@cast provide_item ProvideItem?

    if not provide_item then
        local station = context.root.station
        if station then
            lib.set_haulers_to_manual(station.provide.deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop.entity)
            storage.disabled_items[station.general.network .. ":" .. item_key] = true
        end
    end
end

function provide_methods.on_mutation_finished(context)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>

    context.root.ghost.provide.items = context.objects
    lib.write_station_provide_settings(context.root.ghost.provide)

    local station = context.root.station
    if station then
        lib.ensure_hidden_combs(station.provide.comb, station.provide.hidden_combs, context.objects)
        if not station.stop.custom_name then update_station_name(context.root, nil) end
    end
end

--------------------------------------------------------------------------------

---@type GuiElementDef[]
local request_blank_row_defs = {
    { type = "flow", style = "vertical_flow", direction = "vertical", children = {
        { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = "station_request_move" },
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = "station_request_move" },
        } },
        { type = "sprite", style = "sspp_vertical_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = "station_request_copy" },
    } },
    { type = "choose-elem-button", style = "big_slot_button", handler = "station_request_elem_changed" }, -- [2].elem_type
    { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.class" }), tooltip = { "sspp-gui.item-class-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-size" }), tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-time" }), tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
    } },
    { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.mode" }), tooltip = { "sspp-gui.request-mode-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-1", tooltip = { "sspp-gui.request-mode-tooltip-1" }, handler = "station_request_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-2", tooltip = { "sspp-gui.request-mode-tooltip-2" }, handler = "station_request_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-3", tooltip = { "sspp-gui.request-mode-tooltip-3" }, handler = "station_request_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-4", tooltip = { "sspp-gui.request-mode-tooltip-4" }, handler = "station_request_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-5", tooltip = { "sspp-gui.request-mode-tooltip-5" }, toggled = true, handler = "station_request_mode_click" },
                { type = "sprite-button", style = "sspp_item_mode_sprite_button", sprite = "sspp-request-mode-6", tooltip = { "sspp-gui.request-mode-tooltip-6" }, handler = "station_request_mode_click" },
                { type = "sprite-button", style = "sspp_compact_slot_button", sprite = "sspp-signal-icon", tooltip = { "sspp-gui.request-mode-tooltip-dynamic" }, handler = "station_request_mode_click" },
            } },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.throughput" }), tooltip = { "sspp-gui.request-throughput-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "", handler = "station_request_text_changed" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.latency" }), tooltip = { "sspp-gui.request-latency-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "textfield", style = "sspp_number_textbox", numeric = true, allow_decimal = true, text = "30", handler = "station_request_text_changed" },
        } },
    } },
    { type = "flow", style = "sspp_station_cell_flow", direction = "vertical", children = {
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.storage-needed" }), tooltip = { "sspp-gui.request-storage-needed-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
        { type = "flow", style = "sspp_station_property_flow", direction = "horizontal", children = {
            { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.current-deficit" }), tooltip = { "sspp-gui.request-current-deficit-tooltip" } },
            { type = "empty-widget", style = "flib_horizontal_pusher" },
            { type = "label", style = "label" },
        } },
    } },
}

function request_methods.insert_row_blank(context, row_offset, elem_type)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>
    ---@cast elem_type string

    request_blank_row_defs[2].elem_type = elem_type

    return glib.add_elements(context.table, nil, row_offset, request_blank_row_defs)
end

function request_methods.insert_row_complete(context, row_offset, item_key, request_item)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>
    ---@cast item_key ItemKey
    ---@cast request_item RequestItem

    local name, quality = split_item_key(item_key)
    local cells = request_methods.insert_row_blank(context, row_offset, quality and "item-with-quality" or "fluid")

    cells[2].elem_value = quality and { name = name, quality = quality } or name

    set_active_mode_button(cells[4].children[1].children[3], request_item.mode)
    cells[4].children[2].children[3].text = tostring(request_item.throughput)
    cells[4].children[3].children[3].text = tostring(request_item.latency)

    cells[1].children[2].sprite = ""
    cells[1].children[2].tooltip = nil

    local network_item = storage.networks[context.root.ghost.general.network].items[item_key]
    if network_item then
        cells[3].children[1].children[3].caption = network_item.class
        cells[3].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", network_item.delivery_size }
        cells[3].children[3].children[3].caption = { "sspp-gui.fmt-seconds", network_item.delivery_time }

        cells[5].children[1].children[3].caption = { quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units", lib.compute_storage_needed(network_item, request_item) / (quality and prototypes.item[name].stack_size or 1) }
    end

    return cells
end

function request_methods.insert_row_copy(context, row_offset, src_cells)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>

    local cells = request_methods.insert_row_blank(context, row_offset, src_cells[2].elem_type)

    set_active_mode_button(cells[4].children[1].children[3], get_active_mode_button(src_cells[4].children[1].children[3]))
    cells[4].children[2].children[3].text = src_cells[4].children[2].children[3].text
    cells[4].children[3].children[3].text = src_cells[4].children[3].children[3].text

    return cells
end

function request_methods.make_object(context, cells)
    local elem_value = cells[2].elem_value --[[@as (table|string)?]]
    if not elem_value then return end

    local throughput = tonumber(cells[4].children[2].children[3].text)
    if not throughput then return end

    local latency = tonumber(cells[4].children[3].children[3].text)
    if not latency then return end

    local _, _, item_key = glib.extract_elem_value_fields(elem_value)

    return item_key, {
        mode = get_active_mode_button(cells[4].children[1].children[3]),
        throughput = throughput,
        latency = latency,
    } --[[@as RequestItem]]
end

function request_methods.filter_object(context, item_key, request_item)
    return true
end

function request_methods.on_row_changed(context, cells, item_key, request_item)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>
    ---@cast item_key ItemKey?
    ---@cast request_item RequestItem?

    local name, quality = nil, nil
    if item_key then
        name, quality = split_item_key(item_key)
    else
        local elem_value = cells[2].elem_value
        if elem_value then
            name, quality, item_key = glib.extract_elem_value_fields(elem_value)
        end
    end

    local network_item = item_key and storage.networks[context.root.ghost.general.network].items[item_key]
    if network_item then
        cells[3].children[1].children[3].caption = network_item.class
        cells[3].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", network_item.delivery_size }
        cells[3].children[3].children[3].caption = { "sspp-gui.fmt-seconds", network_item.delivery_time }
    else
        cells[3].children[1].children[3].caption = ""
        cells[3].children[2].children[3].caption = ""
        cells[3].children[3].children[3].caption = ""
    end

    if request_item then
        cells[1].children[2].sprite = ""
        cells[1].children[2].tooltip = nil
    else
        cells[1].children[2].sprite = "utility/achievement_warning"
        cells[1].children[2].tooltip = { "sspp-gui.invalid-values-tooltip" }
    end

    if network_item and request_item then
        cells[5].children[1].children[3].caption = { quality and "sspp-gui.fmt-slots" or "sspp-gui.fmt-units", lib.compute_storage_needed(network_item, request_item) / (quality and prototypes.item[name].stack_size or 1) }
    else
        cells[5].children[1].children[3].caption = ""
        cells[5].children[2].children[3].caption = ""
    end
end

function request_methods.on_object_changed(context, item_key, request_item)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>
    ---@cast item_key ItemKey
    ---@cast request_item RequestItem?

    if not request_item then
        local station = context.root.station
        if station then
            lib.set_haulers_to_manual(station.request.deliveries[item_key], { "sspp-alert.cargo-removed-from-station" }, item_key, station.stop.entity)
            storage.disabled_items[station.general.network .. ":" .. item_key] = true
        end
    end
end

function request_methods.on_mutation_finished(context)
    ---@cast context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>

    context.root.ghost.request.items = context.objects
    lib.write_station_request_settings(context.root.ghost.request)

    local station = context.root.station
    if station then
        lib.ensure_hidden_combs(station.request.comb, station.request.hidden_combs, context.objects)
        if not station.stop.custom_name then update_station_name(context.root, nil) end
    end
end

--------------------------------------------------------------------------------

---@generic Object
---@param methods GuiTableMethods
---@param context GuiTableContext<GuiRoot.Station, ItemKey, Object>
---@param enabled boolean
local function set_buffer_settings_enabled(methods, context, enabled)
    for _, row in pairs(context.rows) do
        local cells = row.cells ---@cast cells -nil

        if not enabled then
            -- these values don't matter for bufferless stations, but they still need to be valid
            if not tonumber(cells[4].children[2].children[3].text) then cells[4].children[2].children[3].text = "0" end
            if not tonumber(cells[4].children[3].children[3].text) then cells[4].children[3].children[3].text = "30" end
        end

        cells[4].children[2].children[3].enabled = enabled
        cells[4].children[3].children[3].enabled = enabled
        cells[5].children[1].children[3].enabled = enabled

        glib.table_modify_mutable_row(methods, context, cells[1])
    end
end

---@generic Object
---@param methods GuiTableMethods
---@param context GuiTableContext<GuiRoot.Station, ItemKey, Object>
---@param player_id PlayerId
---@param elem_type string
local function try_add_item_or_fluid_row(methods, context, player_id, elem_type)
    if context.root.ghost.stop.bufferless then
        if not context.root.provide_context or #context.root.provide_context.rows == 0 then
            if not context.root.request_context or #context.root.request_context.rows == 0 then
                glib.table_append_blank_row(methods, context, elem_type)
                set_buffer_settings_enabled(methods, context, false)
                return
            end
        end
    elseif #context.rows < 10 then
        glib.table_append_blank_row(methods, context, elem_type)
        return
    end
    game.get_player(player_id).play_sound({ path = "utility/cannot_build" })
end

glib.handlers["station_provide_add_item"] = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.player_index, "item-with-quality")
end }

glib.handlers["station_provide_add_fluid"] = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid_row(provide_methods, storage.player_guis[event.player_index].provide_context, event.player_index, "fluid")
end }

glib.handlers["station_request_add_item"] = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid_row(request_methods, storage.player_guis[event.player_index].request_context, event.player_index, "item-with-quality")
end }

glib.handlers["station_request_add_fluid"] = { [events.on_gui_click] = function(event)
    try_add_item_or_fluid_row(request_methods, storage.player_guis[event.player_index].request_context, event.player_index, "fluid")
end }

--------------------------------------------------------------------------------

---@param root GuiRoot.Station
function gui_station.on_poll_finished(root)
    local station = root.station
    if not station then return end
    local provide, request = station.provide, station.request

    local elements = root.elements

    local grid_table = elements.grid_table
    local grid_children = grid_table.children

    -- minimap reuse doesn't really matter for stations, but the code already exists for networks
    local old_length, new_length = #grid_children, 0

    if provide then
        local context = root.provide_context ---@cast context -nil
        local dynamic_index = -1 -- zero based

        for item_key, index in pairs(context.indices) do
            local cells = context.rows[index].cells ---@cast cells -nil
            local dynamic_button = cells[4].children[1].children[3].children[7]

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
                local _, quality = split_item_key(item_key)
                cells[5].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", provide_count }
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
        local context = root.request_context ---@cast context -nil
        local dynamic_index = -1 -- zero based

        for item_key, index in pairs(context.indices) do
            local cells = context.rows[index].cells ---@cast cells -nil
            local dynamic_button = cells[4].children[1].children[3].children[7]

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
                local _, quality = split_item_key(item_key)
                cells[5].children[2].children[3].caption = { quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units", request_count }
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

glib.handlers["station_edit_name_toggled"] = { [events.on_gui_click] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    if event.element.toggled then
        root.elements.stop_name_label.visible = false
        root.elements.stop_name_input.text = root.ghost.stop.entity.backer_name
        root.elements.stop_name_input.visible = true
        root.elements.stop_name_input.focus()
    else
        root.elements.stop_name_label.caption = root.ghost.stop.entity.backer_name
        root.elements.stop_name_label.visible = true
        root.elements.stop_name_input.visible = false
    end
end }

glib.handlers["station_clear_name"] = { [events.on_gui_click] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    root.ghost.stop.custom_name = false
    lib.write_station_stop_settings(root.ghost.stop)

    root.elements.stop_name_label.visible = true
    root.elements.stop_name_input.visible = false

    root.elements.stop_name_edit_toggle.toggled = false
    root.elements.stop_name_clear_button.enabled = false

    update_station_name(root, nil)
end }

glib.handlers["station_name_changed_or_confirmed"] = {}

glib.handlers["station_name_changed_or_confirmed"][events.on_gui_text_changed] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    local new_stop_name = glib.truncate_input(event.element, 199)
    local has_custom_name = new_stop_name ~= ""

    root.ghost.stop.custom_name = has_custom_name
    lib.write_station_stop_settings(root.ghost.stop)

    root.elements.stop_name_clear_button.enabled = has_custom_name

    update_station_name(root, has_custom_name and new_stop_name or nil)
end

glib.handlers["station_name_changed_or_confirmed"][events.on_gui_confirmed] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    root.elements.stop_name_label.visible = true
    root.elements.stop_name_input.visible = false

    root.elements.stop_name_edit_toggle.toggled = false
end

--------------------------------------------------------------------------------

glib.handlers["station_limit_changed"] = { [events.on_gui_value_changed] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    root.elements.limit_value.caption = tostring(event.element.slider_value)
    root.ghost.stop.entity.trains_limit = event.element.slider_value
end }

glib.handlers["station_bufferless_toggled"] = { [events.on_gui_click] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    local provide_row_count = root.provide_context and #root.provide_context.rows or 0
    local request_row_count = root.request_context and #root.request_context.rows or 0

    if event.element.toggled and provide_row_count + request_row_count > 1 then
        event.element.toggled = false
        game.get_player(event.player_index).play_sound({ path = "utility/cannot_build" })
        return
    end

    event.element.tooltip = { event.element.toggled and "sspp-gui.station-bufferless-tooltip" or "sspp-gui.station-buffered-tooltip" }
    root.ghost.stop.bufferless = event.element.toggled
    lib.write_station_stop_settings(root.ghost.stop)

    if provide_row_count > 0 then
        local station = root.station
        if station then
            for item_key, hauler_ids in pairs(station.provide.deliveries) do
                for _, hauler_id in pairs(hauler_ids) do
                    local network = storage.networks[station.general.network]
                    local hauler = storage.haulers[hauler_id]
                    local job = network.jobs[hauler.job] --[[@as NetworkJob]]
                    if event.element.toggled then
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
        set_buffer_settings_enabled(provide_methods, root.provide_context, not event.element.toggled)
    end

    if request_row_count > 0 then
        set_buffer_settings_enabled(request_methods, root.request_context, not event.element.toggled)
    end
end }

glib.handlers["station_inactivity_toggled"] = { [events.on_gui_click] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    event.element.tooltip = { event.element.toggled and "sspp-gui.station-wait-for-inactivity-tooltip" or "sspp-gui.station-depart-immediately-tooltip" }
    root.ghost.stop.inactivity = event.element.toggled
    lib.write_station_stop_settings(root.ghost.stop)
end }

glib.handlers["station_disable_toggled"] = { [events.on_gui_click] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    event.element.tooltip = { event.element.toggled and "sspp-gui.station-disabled-tooltip" or "sspp-gui.station-enabled-tooltip" }
    root.ghost.stop.disabled = event.element.toggled
    lib.write_station_stop_settings(root.ghost.stop)
end }

--------------------------------------------------------------------------------

glib.handlers["station_network_selection_changed"] = { [events.on_gui_selection_state_changed] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Station]]

    local station = root.station
    if station then
        if station.provide then
            for item_key, _ in pairs(station.provide.items) do
                lib.set_haulers_to_manual(station.provide.deliveries[item_key], { "sspp-alert.station-network-changed" }, item_key, station.stop.entity)
                storage.disabled_items[station.general.network .. ":" .. item_key] = true
            end
        end
        if station.request then
            for item_key, _ in pairs(station.request.items) do
                lib.set_haulers_to_manual(station.request.deliveries[item_key], { "sspp-alert.station-network-changed" }, item_key, station.stop.entity)
                storage.disabled_items[station.general.network .. ":" .. item_key] = true
            end
        end
    end

    root.ghost.general.network = glib.get_network_name(event.element.selected_index, root.ghost.stop.entity.surface)
    lib.write_station_general_settings(root.ghost.general)

    if root.provide_context then
        glib.table_initialise(provide_methods, root.provide_context, root.provide_context.objects, nil, nil)
        if root.ghost.stop.bufferless then set_buffer_settings_enabled(provide_methods, root.provide_context, false) end
    end
    if root.request_context then
        glib.table_initialise(request_methods, root.request_context, root.request_context.objects, nil, nil)
        if root.ghost.stop.bufferless then set_buffer_settings_enabled(request_methods, root.request_context, false) end
    end
end }

--------------------------------------------------------------------------------

glib.handlers["station_open_network"] = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local network_name = storage.player_guis[player_id].ghost.general.network

    gui_network.open(player_id, network_name, 2)
end }

glib.handlers["station_view_on_map"] = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    local entity = storage.player_guis[event.player_index].ghost.stop.entity

    player.opened = nil
    player.centered_on = entity
end }

glib.handlers["station_close_window"] = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    assert(player.opened.name == "sspp-station")

    player.opened = nil
end }

--------------------------------------------------------------------------------

---@param player LuaPlayer
---@param ghost GhostStation
---@return LuaGuiElement window, {[string]: LuaGuiElement} elements
local function add_gui_complete(player, ghost)
    local custom_name = ghost.stop.custom_name
    local disabled = ghost.stop.disabled
    local bufferless = ghost.stop.bufferless
    local inactivity = ghost.stop.inactivity

    local disabled_tooltip = { disabled and "sspp-gui.station-disabled-tooltip" or "sspp-gui.station-enabled-tooltip" }
    local bufferless_tooltip = { bufferless and "sspp-gui.station-bufferless-tooltip" or "sspp-gui.station-buffered-tooltip" }
    local inactivity_tooltip = { inactivity and "sspp-gui.station-wait-for-inactivity-tooltip" or "sspp-gui.station-depart-immediately-tooltip" }

    local name = ghost.stop.entity.backer_name
    local limit = ghost.stop.entity.trains_limit
    local provide = ghost.provide ~= nil
    local request = ghost.request ~= nil

    local localised_network_names, network_index = glib.get_localised_network_names(ghost.general.network, ghost.stop.entity.surface)

    local window, elements = glib.add_element(player.gui.screen, {},
        { type = "frame", name = "sspp-station", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", direction = "horizontal", drag_target = "sspp-station", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.sspp-station" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "drop-down", name = "network_selector", style = "sspp_wide_dropdown", items = localised_network_names, selected_index = network_index, handler = "station_network_selection_changed" },
                { type = "sprite-button", style = "frame_action_button", sprite = "sspp-network-icon", tooltip = { "sspp-gui.open-network" }, mouse_button_filter = { "left" }, handler = "station_open_network" },
                { type = "empty-widget", style = "empty_widget", ignored_by_interaction = true },
                { type = "sprite-button", style = "frame_action_button", sprite = "sspp-map-icon", tooltip = { "sspp-gui.view-on-map" }, mouse_button_filter = { "left" }, handler = "station_view_on_map" },
                { type = "sprite-button", style = "frame_action_button", sprite = "sspp-disable-icon", tooltip = disabled_tooltip, mouse_button_filter = { "left" }, auto_toggle = true, toggled = disabled, handler = "station_disable_toggled" },
                { type = "empty-widget", style = "empty_widget", ignored_by_interaction = true },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", mouse_button_filter = { "left" }, handler = "station_close_window" },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", direction = "horizontal", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", name = "stop_name_label", style = "subheader_caption_label", caption = name },
                        { type = "textfield", name = "stop_name_input", style = "sspp_subheader_caption_textbox", icon_selector = true, text = name, visible = false, handler = "station_name_changed_or_confirmed" },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        { type = "sprite-button", name = "stop_name_edit_toggle", style = "control_settings_section_button", sprite = "sspp-name-icon", tooltip = { "sspp-gui.edit-custom-name" }, auto_toggle = true, handler = "station_edit_name_toggled" },
                        { type = "sprite-button", name = "stop_name_clear_button", style = "control_settings_section_button", sprite = "sspp-reset-icon", tooltip = { "sspp-gui.clear-custom-name" }, enabled = custom_name, handler = "station_clear_name" },
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
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, handler = "station_provide_add_item" },
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, handler = "station_provide_add_fluid" },
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
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, mouse_button_filter = { "left" }, handler = "station_request_add_item" },
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, mouse_button_filter = { "left" }, handler = "station_request_add_fluid" },
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
                        { type = "slider", style = "notched_slider", minimum_value = 1, maximum_value = 10, value = limit, handler = "station_limit_changed" },
                        { type = "label", name = "limit_value", style = "sspp_station_limit_value", caption = tostring(limit) },
                        { type = "sprite-button", name = "bufferless_toggle", style = "control_settings_section_button", sprite = "sspp-bufferless-icon", tooltip = bufferless_tooltip, auto_toggle = true, toggled = bufferless, handler = "station_bufferless_toggled" },
                        { type = "sprite-button", name = "inactivity_toggle", style = "control_settings_section_button", sprite = "sspp-inactivity-icon", tooltip = inactivity_tooltip, auto_toggle = true, toggled = inactivity, visible = provide, handler = "station_inactivity_toggled" },
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
    local window, elements = glib.add_element(player.gui.screen, {},
        { type = "frame", name = "sspp-station", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", direction = "horizontal", drag_target = "sspp-station", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.incomplete-station" }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", hovered_sprite = "utility/close_black", mouse_button_filter = { "left" }, handler = "station_close_window" },
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
    local player = game.get_player(player_id) --[[@as LuaPlayer]]
    local ghost, station = get_station_ghost(entity)

    player.opened = nil

    local window, elements, root ---@type LuaGuiElement, {[string]: LuaGuiElement}, GuiRoot.Station
    if ghost then
        window, elements = add_gui_complete(player, ghost)
        root = { type = "STATION", elements = elements, unit_number = entity.unit_number, ghost = ghost, station = station }

        if ghost.provide then
            root.provide_context = { root = root, table = elements.provide_table }
            glib.table_initialise(provide_methods, root.provide_context, ghost.provide.items, nil, nil)
            if ghost.stop.bufferless then set_buffer_settings_enabled(provide_methods, root.provide_context, false) end
        end

        if ghost.request then
            root.request_context = { root = root, table = elements.request_table }
            glib.table_initialise(request_methods, root.request_context, ghost.request.items, nil, nil)
            if ghost.stop.bufferless then set_buffer_settings_enabled(request_methods, root.request_context, false) end
        end
    else
        window, elements = add_gui_incomplete(player)
        root = { type = "STATION", elements = elements, unit_number = entity.unit_number }
    end

    window.force_auto_center()

    storage.player_guis[player_id] = root
    player.opened = window
end

---@param player_id PlayerId
function gui_station.close(player_id)
    local root = storage.player_guis[player_id] --[[@as GuiRoot.Station]]
    root.elements["sspp-station"].destroy()

    local entity = storage.entities[root.unit_number]

    if entity.valid and entity.name ~= "entity-ghost" then
        local player = game.get_player(player_id) --[[@as LuaPlayer]]
        player.play_sound({ path = "entity-close/sspp-stop" })
    end

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

return gui_station
