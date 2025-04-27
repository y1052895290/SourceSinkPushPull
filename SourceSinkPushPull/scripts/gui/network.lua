-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local glib = require("__SourceSinkPushPull__.scripts.glib")

local events = defines.events

local len_or_zero, split_item_key, make_item_icon = lib.len_or_zero, lib.split_item_key, lib.make_item_icon
local get_stop_name, get_train_item_count = lib.get_stop_name, lib.get_train_item_count
local format_distance, format_duration, format_time = lib.format_distance, lib.format_duration, lib.format_time

local cwi, acquire_next_minimap = glib.caption_with_info, glib.acquire_next_minimap

local gui_network = {}

--------------------------------------------------------------------------------

---@type GuiTableMethods
local class_methods = {} ---@diagnostic disable-line: missing-fields

---@type GuiTableMethods
local item_methods = {} ---@diagnostic disable-line: missing-fields

---@type GuiTableMethods
local job_methods = {} ---@diagnostic disable-line: missing-fields

--------------------------------------------------------------------------------

glib.handlers["network_class_move"] = { [events.on_gui_click] = function(event)
    glib.table_move_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

glib.handlers["network_item_move"] = { [events.on_gui_click] = function(event)
    glib.table_move_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
end }

glib.handlers["network_class_copy"] = { [events.on_gui_click] = function(event)
    glib.table_copy_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

glib.handlers["network_item_copy"] = { [events.on_gui_click] = function(event)
    glib.table_copy_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
end }

--------------------------------------------------------------------------------

glib.handlers["network_class_delete"] = { [events.on_gui_click] = function(event)
    glib.table_remove_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

glib.handlers["network_class_name_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.truncate_input(event.element, 199)
    glib.table_modify_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

glib.handlers["network_class_depot_name_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.truncate_input(event.element, 199)
    glib.table_modify_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

glib.handlers["network_class_fueler_name_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.truncate_input(event.element, 199)
    glib.table_modify_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

glib.handlers["network_class_bypass_depot_changed"] = { [events.on_gui_click] = function(event)
    glib.table_modify_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, event.element)
end }

--------------------------------------------------------------------------------

glib.handlers["network_item_elem_changed"] = { [events.on_gui_elem_changed] = function(event)
    if event.element.elem_value then
        -- TODO: check for recursive spoilage
        glib.table_modify_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
    else
        glib.table_remove_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
    end
end }

glib.handlers["network_item_class_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.truncate_input(event.element, 199)
    glib.table_modify_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
end }

glib.handlers["network_item_delivery_size_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.table_modify_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
end }

glib.handlers["network_item_delivery_time_changed"] = { [events.on_gui_text_changed] = function(event)
    glib.table_modify_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.element)
end }

--------------------------------------------------------------------------------

---@param player_gui PlayerGui.Network
local function clear_expanded_object(player_gui)
    if player_gui.expanded_class then
        local row = player_gui.class_context.key_to_row[player_gui.expanded_class]
        player_gui.class_context.row_to_cells[row][6].toggled = false
        player_gui.expanded_class = nil
    elseif player_gui.expanded_stations_item then
        local row = player_gui.item_context.key_to_row[player_gui.expanded_stations_item]
        player_gui.item_context.row_to_cells[row][5].toggled = false
        player_gui.expanded_stations_item = nil
    elseif player_gui.expanded_haulers_item then
        local row = player_gui.item_context.key_to_row[player_gui.expanded_haulers_item]
        player_gui.item_context.row_to_cells[row][7].toggled = false
        player_gui.expanded_haulers_item = nil
    elseif player_gui.expanded_job then
        local row = player_gui.job_context.key_to_row[player_gui.expanded_job]
        player_gui.job_context.row_to_cells[row][5].toggled = false
        player_gui.expanded_job = nil
    else
        return -- nothing to clear
    end

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
    elements.right_scroll_pane.style = "sspp_right_grid_scroll_pane"

    elements.grid_table.clear()
    elements.info_flow.clear()
end

glib.handlers["network_class_expand"] = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Network]]

    clear_expanded_object(player_gui)

    local context = player_gui.class_context
    local class_name = context.row_to_key[glib.get_row_for_child(context.table, event.element)]

    if class_name then
        local elements = player_gui.elements

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

        event.element.toggled = true
        player_gui.expanded_class = class_name
    else
        game.get_player(event.player_index).play_sound({ path = "utility/cannot_build" })
    end
end }

glib.handlers["network_item_expand_stations"] = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Network]]

    clear_expanded_object(player_gui)

    local context = player_gui.item_context
    local item_key = context.row_to_key[glib.get_row_for_child(context.table, event.element)]

    if item_key then
        local elements = player_gui.elements
        local name, quality = split_item_key(item_key)

        elements.grid_title.caption = { quality and "sspp-gui.fmt-item-stations-title" or "sspp-gui.fmt-fluid-stations-title", name, quality }
        elements.grid_stations_mode_switch.visible = true
        elements.grid_provide_toggle.enabled = true
        elements.grid_provide_toggle.tooltip = { "sspp-gui.grid-stations-provide-tooltip" }
        elements.grid_request_toggle.enabled = true
        elements.grid_request_toggle.tooltip = { "sspp-gui.grid-stations-request-tooltip" }

        event.element.toggled = true
        player_gui.expanded_stations_item = item_key
    else
        game.get_player(event.player_index).play_sound({ path = "utility/cannot_build" })
    end
end }

glib.handlers["network_item_expand_haulers"] = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Network]]

    clear_expanded_object(player_gui)

    local context = player_gui.item_context
    local item_key = context.row_to_key[glib.get_row_for_child(context.table, event.element)]

    if item_key then
        local elements = player_gui.elements
        local name, quality = split_item_key(item_key)

        elements.grid_title.caption = { quality and "sspp-gui.fmt-item-haulers-title" or "sspp-gui.fmt-fluid-haulers-title", name, quality }
        elements.grid_provide_toggle.enabled = true
        elements.grid_provide_toggle.tooltip = { "sspp-gui.grid-haulers-provide-tooltip" }
        elements.grid_request_toggle.enabled = true
        elements.grid_request_toggle.tooltip = { "sspp-gui.grid-haulers-request-tooltip" }
        elements.grid_liquidate_toggle.enabled = true
        elements.grid_liquidate_toggle.tooltip = { "sspp-gui.grid-haulers-liquidate-tooltip" }

        event.element.toggled = true
        player_gui.expanded_haulers_item = item_key
    else
        game.get_player(event.player_index).play_sound({ path = "utility/cannot_build" })
    end
end }

glib.handlers["network_job_expand"] = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Network]]

    clear_expanded_object(player_gui)

    local context = player_gui.job_context
    local job_index = context.row_to_key[glib.get_row_for_child(context.table, event.element)]
    ---@cast job_index -false

    local elements = player_gui.elements
    local job = context.key_to_object[job_index]

    if job.type == "FUEL" then
        elements.grid_title.caption = { "sspp-gui.fmt-job-title", "[virtual-signal=signal-fuel]", job_index }
    else
        local name, quality = split_item_key(job.item)
        elements.grid_title.caption = { "sspp-gui.fmt-job-title", make_item_icon(name, quality), job_index }
    end
    elements.right_scroll_pane.style = "sspp_right_flat_scroll_pane"

    event.element.toggled = true
    player_gui.expanded_job = job_index
end }

--------------------------------------------------------------------------------

---@type GuiElementDef[]
local class_blank_row_defs = {
    { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
        { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = "network_class_move" },
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = "network_class_move" },
        } },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = "network_class_copy" },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-delete-icon", handler = "network_class_delete" },
        { type = "sprite", style = "sspp_compact_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
    } },
    { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = "network_class_name_changed" },
    { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = "network_class_depot_name_changed" },
    { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = "network_class_fueler_name_changed" },
    { type = "checkbox", style = "checkbox", state = true, handler = "network_class_bypass_depot_changed" },
    { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = "network_class_expand" },
    { type = "label", style = "label" },
}

function class_methods.insert_row_blank(context, row_offset, args)
    ---@cast context GuiTableContext<PlayerGui.Network, ClassName, NetworkClass>

    return glib.add_elements(context.table, nil, row_offset, class_blank_row_defs)
end

function class_methods.insert_row_complete(context, row_offset, class_name, class)
    ---@cast context GuiTableContext<PlayerGui.Network, ClassName, NetworkClass>
    ---@cast class_name ClassName
    ---@cast class NetworkClass

    local cells = class_methods.insert_row_blank(context, row_offset, nil)

    cells[1].children[4].sprite = ""
    cells[1].children[4].tooltip = nil

    cells[2].text = class_name

    cells[3].text = class.depot_name
    cells[4].text = class.fueler_name
    cells[5].state = class.bypass_depot

    return cells
end

function class_methods.insert_row_copy(context, row_offset, src_cells)
    ---@cast context GuiTableContext<PlayerGui.Network, ClassName, NetworkClass>

    local cells = class_methods.insert_row_blank(context, row_offset, nil)

    cells[2].text = src_cells[2].text
    cells[2].focus()
    cells[2].select_all()

    cells[3].text = src_cells[3].text
    cells[4].text = src_cells[4].text
    cells[5].state = src_cells[5].state

    return cells
end

function class_methods.make_object(context, cells)
    local class_name = cells[2].text
    if class_name == "" then return end

    local depot_name = cells[3].text
    if depot_name == "" then return end

    local fueler_name = cells[4].text
    if fueler_name == "" then return end

    return class_name, {
        depot_name = depot_name,
        fueler_name = fueler_name,
        bypass_depot = cells[5].state,
    } --[[@as NetworkClass]]
end

function class_methods.on_row_changed(context, cells, class_name, class)
    ---@cast class NetworkClass?

    if not class then
        cells[7].caption = ""
    end
end

function class_methods.on_object_changed(context, class_name, class)
    ---@cast context GuiTableContext<PlayerGui.Network, ClassName, NetworkClass>
    ---@cast class_name ClassName
    ---@cast class NetworkClass?

    if not class then
        local player_gui = context.root
        local network_name = player_gui.network
        local network = storage.networks[network_name]

        local message = { "sspp-alert.class-not-in-network" }

        for item_key, item in pairs(network.items) do
            if item.class == class_name then
                lib.set_haulers_to_manual(network.buffer_haulers[item_key], message, item_key)
                lib.set_haulers_to_manual(network.provide_haulers[item_key], message, item_key)
                lib.set_haulers_to_manual(network.request_haulers[item_key], message, item_key)
                lib.set_haulers_to_manual(network.to_depot_liquidate_haulers[item_key], message, item_key)
                lib.set_haulers_to_manual(network.at_depot_liquidate_haulers[item_key], message, item_key)

                storage.disabled_items[network_name .. ":" .. item_key] = true

                if player_gui.expanded_stations_item == item_key then clear_expanded_object(player_gui) end
                if player_gui.expanded_haulers_item == item_key then clear_expanded_object(player_gui) end
            end
        end

        lib.set_haulers_to_manual(network.fuel_haulers[class_name], message)
        lib.set_haulers_to_manual(network.to_depot_haulers[class_name], message)
        lib.set_haulers_to_manual(network.at_depot_haulers[class_name], message)

        if player_gui.expanded_class == class_name then clear_expanded_object(player_gui) end
    end
end

function class_methods.on_mutation_finished(context)
    ---@cast context GuiTableContext<PlayerGui.Network, ClassName, NetworkClass>

    local network = storage.networks[context.root.network]

    network.classes = context.key_to_object
end

--------------------------------------------------------------------------------

---@type GuiElementDef[]
local item_blank_row_defs = {
    { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
        { type = "flow", style = "packed_vertical_flow", direction = "vertical", children = {
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-up-icon", handler = "network_item_move" },
            { type = "sprite-button", style = "sspp_move_sprite_button", sprite = "sspp-move-down-icon", handler = "network_item_move" },
        } },
        { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-copy-icon", handler = "network_item_copy" },
        { type = "choose-elem-button", style = "sspp_compact_slot_button", handler = "network_item_elem_changed" }, -- elem_type
        { type = "sprite", style = "sspp_compact_warning_image", sprite = "utility/achievement_warning", tooltip = { "sspp-gui.invalid-values-tooltip" } },
    } },
    { type = "textfield", style = "sspp_wide_name_textbox", icon_selector = true, text = "", handler = "network_item_class_changed" },
    { type = "textfield", style = "sspp_wide_number_textbox", numeric = true, text = "", handler = "network_item_delivery_size_changed" },
    { type = "textfield", style = "sspp_wide_number_textbox", numeric = true, text = "", handler = "network_item_delivery_time_changed" },
    { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = "network_item_expand_stations" },
    { type = "label", style = "label" },
    { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = "network_item_expand_haulers" },
    { type = "label", style = "label" },
}

function item_methods.insert_row_blank(context, row_offset, elem_type)
    ---@cast context GuiTableContext<PlayerGui.Network, ItemKey, NetworkItem>
    ---@cast elem_type string

    item_blank_row_defs[1].children[3].elem_type = elem_type

    return glib.add_elements(context.table, nil, row_offset, item_blank_row_defs)
end

function item_methods.insert_row_complete(context, row_offset, item_key, item)
    ---@cast context GuiTableContext<PlayerGui.Network, ItemKey, NetworkItem>
    ---@cast item_key ItemKey
    ---@cast item NetworkItem

    local name, quality = split_item_key(item_key)
    local cells = item_methods.insert_row_blank(context, row_offset, quality and "item-with-quality" or "fluid")

    cells[1].children[3].elem_value = quality and { name = name, quality = quality } or name
    cells[1].children[4].sprite = ""
    cells[1].children[4].tooltip = nil

    cells[2].text = item.class
    cells[3].text = tostring(item.delivery_size)
    cells[4].text = tostring(item.delivery_time)

    return cells
end

function item_methods.insert_row_copy(context, row_offset, src_cells)
    ---@cast context GuiTableContext<PlayerGui.Network, ItemKey, NetworkItem>

    local cells = item_methods.insert_row_blank(context, row_offset, src_cells[1].children[3].elem_type)

    cells[2].text = src_cells[2].text
    cells[3].text = src_cells[3].text
    cells[4].text = src_cells[4].text

    return cells
end

function item_methods.make_object(context, cells)
    local elem_value = cells[1].children[3].elem_value --[[@as (table|string)?]]
    if not elem_value then return end

    local class = cells[2].text
    if class == "" then return end -- class does not need to actually exist yet

    local delivery_size = tonumber(cells[3].text)
    if not delivery_size or delivery_size < 1 then return end

    local delivery_time = tonumber(cells[4].text)
    if not delivery_time or delivery_time < 1.0 then return end

    local name, quality, item_key = glib.extract_elem_value_fields(elem_value)

    return item_key, {
        name = name,
        quality = quality,
        class = class,
        delivery_size = delivery_size,
        delivery_time = delivery_time,
    } --[[@as NetworkItem]]
end

function item_methods.on_row_changed(context, cells, item_key, item)
    ---@cast item NetworkItem

    if not item then
        cells[6].caption = ""
        cells[8].caption = ""
    end
end

function item_methods.on_object_changed(context, item_key, item)
    ---@cast context GuiTableContext<PlayerGui.Network, ItemKey, NetworkItem>
    ---@cast item_key ItemKey
    ---@cast item NetworkItem

    if not item then
        local player_gui = context.root
        local network_name = player_gui.network
        local network = storage.networks[network_name]

        local message = { "sspp-alert.cargo-not-in-network" }

        lib.set_haulers_to_manual(network.buffer_haulers[item_key], message, item_key)
        lib.set_haulers_to_manual(network.provide_haulers[item_key], message, item_key)
        lib.set_haulers_to_manual(network.request_haulers[item_key], message, item_key)
        lib.set_haulers_to_manual(network.to_depot_liquidate_haulers[item_key], message, item_key)
        lib.set_haulers_to_manual(network.at_depot_liquidate_haulers[item_key], message, item_key)

        storage.disabled_items[network_name .. ":" .. item_key] = true

        if player_gui.expanded_stations_item == item_key then clear_expanded_object(player_gui) end
        if player_gui.expanded_haulers_item == item_key then clear_expanded_object(player_gui) end
    end
end

function item_methods.on_mutation_finished(context)
    ---@cast context GuiTableContext<PlayerGui.Network, ItemKey, NetworkItem>

    local network = storage.networks[context.root.network]

    network.items = context.key_to_object
end

--------------------------------------------------------------------------------

---@type GuiElementDef[]
local job_row_defs = {
    { type = "choose-elem-button", style = "slot_button", elem_type = "signal", elem_mods = { locked = true } }, -- signal
    { type = "flow", style = "sspp_history_cell_flow", direction = "vertical", children = {
        { type = "label", style = "sspp_history_action_label" }, -- caption, visible
        { type = "label", style = "sspp_history_action_label" }, -- caption, visible
        { type = "label", style = "sspp_history_action_label" }, -- caption, visible
        { type = "label", style = "sspp_history_action_label" }, -- caption, visible
    } },
    { type = "flow", style = "sspp_history_cell_flow", direction = "vertical", children = {
        { type = "label", style = "label" }, -- caption, visible
        { type = "label", style = "label" }, -- caption, visible
        { type = "label", style = "label" }, -- caption, visible
        { type = "label", style = "label" }, -- caption, visible
    } },
    { type = "flow", style = "sspp_history_cell_flow", direction = "vertical", children = {
        { type = "label", style = "label" }, -- caption, visible
        { type = "label", style = "label" }, -- caption, visible
        { type = "label", style = "label" }, -- caption, visible
    } },
    { type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", handler = "network_job_expand" },
}

---@param defs_or_cells GuiElementDef[]|LuaGuiElement[]
---@param job_index JobIndex
---@param job NetworkJob
local function job_update_row_captions(defs_or_cells, job_index, job)
    local hauler = storage.haulers[job.hauler] --[[@as Hauler?]]
    local in_progress = hauler and hauler.job == job_index or nil

    local action_captions, duration_captions, summary_captions = {}, {}, {}

    if job.type == "FUEL" then
        local fuel_stop = job.fuel_stop or (in_progress and hauler--[[@as Hauler]].train.path_end_stop)

        local depart_tick, arrive_tick, done_tick = job.start_tick, job.fuel_arrive_tick, job.finish_tick
        action_captions[1] = { "sspp-gui.fmt-travel-to-fuel", get_stop_name(fuel_stop) }
        duration_captions[1] = format_duration(depart_tick, arrive_tick or in_progress)
        if arrive_tick then
            action_captions[2] = { "sspp-gui.transfer-fuel-to-hauler" }
            duration_captions[2] = format_duration(arrive_tick, done_tick or in_progress)
        end
    else
        local provide_stop, request_stop = job.provide_stop, job.request_stop

        if provide_stop then
            local depart_tick, arrive_tick, done_tick = job.start_tick, job.provide_arrive_tick, job.provide_done_tick or job.finish_tick
            action_captions[1] = { "sspp-gui.fmt-travel-to-pick-up", get_stop_name(provide_stop) }
            duration_captions[1] = format_duration(depart_tick, arrive_tick or in_progress)
            if arrive_tick then
                action_captions[2] = { "sspp-gui.fmt-transfer-cargo-to-hauler", job.target_count }
                duration_captions[2] = format_duration(arrive_tick, done_tick or in_progress)
            end
        end

        if request_stop then
            local depart_tick, arrive_tick, done_tick = job.provide_done_tick or job.start_tick, job.request_arrive_tick, job.finish_tick
            action_captions[3] = { "sspp-gui.fmt-travel-to-drop-off", get_stop_name(request_stop) }
            duration_captions[3] = format_duration(depart_tick, arrive_tick or in_progress)
            if arrive_tick then
                action_captions[4] = { "sspp-gui.fmt-transfer-cargo-to-station", job.loaded_count }
                duration_captions[4] = format_duration(arrive_tick, done_tick or in_progress)
            end
        end
    end

    local start_tick, finish_tick, abort_tick = job.start_tick, job.finish_tick, job.abort_tick

    summary_captions[1] = { "", { "sspp-gui.job-started" }, format_time(start_tick) }
    if finish_tick then
        summary_captions[2] = { "", { "sspp-gui.job-finished" }, format_time(finish_tick) }
        summary_captions[3] = { "", { "sspp-gui.total-duration" }, format_duration(start_tick, finish_tick) }
    elseif abort_tick then
        summary_captions[2] = { "", { "sspp-gui.job-aborted" }, format_time(abort_tick) }
    end

    local action_children = defs_or_cells[2].children ---@cast action_children -nil
    for i = 1, 4 do
        local child, caption = action_children[i], action_captions[i]
        child.caption = caption or ""
        child.visible = caption ~= nil
    end

    local duration_children = defs_or_cells[3].children ---@cast duration_children -nil
    for i = 1, 4 do
        local child, caption = duration_children[i], duration_captions[i]
        child.caption = caption or ""
        child.visible = caption ~= nil
    end

    local summary_children = defs_or_cells[4].children ---@cast summary_children -nil
    for i = 1, 3 do
        local child, caption = summary_children[i], summary_captions[i]
        child.caption = caption or ""
        child.visible = caption ~= nil
    end
end

function job_methods.insert_row_complete(context, row_offset, job_index, job)
    ---@cast context GuiTableContext<PlayerGui.Network, JobIndex, NetworkJob>
    ---@cast job_index JobIndex
    ---@cast job NetworkJob

    local signal ---@type SignalID
    if job.type == "FUEL" then
        signal = { name = "signal-fuel", type = "virtual" }
    else
        local name, quality = split_item_key(job.item)
        if quality then
            signal = { name = name, quality = quality, type = "item" }
        else
            signal = { name = name, type = "fluid" }
        end
    end
    job_row_defs[1].signal = signal

    job_update_row_captions(job_row_defs, job_index, job)

    return glib.add_elements(context.table, nil, row_offset, job_row_defs)
end

function job_methods.on_row_changed(context, cells, job_index, job)
    ---@cast job_index JobIndex
    ---@cast job NetworkJob

    job_update_row_captions(cells, job_index, job)
end

--------------------------------------------------------------------------------

---@param player_gui PlayerGui.Network
function gui_network.on_job_created(player_gui)
    local context = player_gui.job_context
    local table = context.table
    local network = storage.networks[player_gui.network]
    local job_index = network.job_index_counter

    if table.style.name == "sspp_network_history_inverted_table" then
        table.style = "sspp_network_history_table"
    else
        table.style = "sspp_network_history_inverted_table"
    end

    glib.table_insert_complete_row(job_methods, context, 1, job_index, network.jobs[job_index])
end

---@param player_gui PlayerGui.Network
---@param job_index JobIndex
function gui_network.on_job_removed(player_gui, job_index)
    if player_gui.expanded_job == job_index then
        clear_expanded_object(player_gui)
    end

    glib.table_remove_immutable_row(job_methods, player_gui.job_context, job_index)
end

---@param player_gui PlayerGui.Network
---@param job_index JobIndex
function gui_network.on_job_updated(player_gui, job_index)
    glib.table_modify_immutable_row(job_methods, player_gui.job_context, job_index)
end

--------------------------------------------------------------------------------

---@param grid_table LuaGuiElement
---@param subtitle LocalisedString
---@param entity LuaEntity?
local function add_job_minimap_widgets(grid_table, subtitle, entity)
    local outer_frame = grid_table.add({ type = "frame", style = "sspp_thin_shallow_frame", direction = "vertical" })
    local minimap_frame = outer_frame.add({ type = "frame", style = "deep_frame_in_shallow_frame" })
    local camera_frame = outer_frame.add({ type = "frame", style = "deep_frame_in_shallow_frame" })
    if entity and entity.valid then
        local minimap = minimap_frame.add({ type = "minimap", style = "sspp_minimap", zoom = 1.0 })
        minimap.entity = entity
        minimap.add({ type = "button", style = "sspp_minimap_button", tags = glib.format_handler("lib_open_parent_entity") })
        local camera = camera_frame.add({ type = "camera", style = "sspp_camera", zoom = 0.25, position = entity.position })
        camera.entity = entity
    else
        minimap_frame.add({ type = "sprite", style = "sspp_dead_entity_image", sprite = "utility/not_available" })
        camera_frame.add({ type = "sprite", style = "sspp_dead_entity_image", sprite = "utility/not_available" })
    end
    local title_frame = outer_frame.add({ type = "frame", style = "deep_frame_in_shallow_frame" })
    title_frame.add({ type = "label", style = "sspp_minimap_subtitle_label", caption = subtitle })
end

---@param info_flow LuaGuiElement
---@param left_caption LocalisedString
---@param right_caption LocalisedString
local function add_job_label_pusher_label(info_flow, style, left_caption, right_caption)
    local flow = info_flow.add({ type = "flow", style = "sspp_job_action_flow", direction = "horizontal" })
    flow.add({ type = "label", style = style, caption = left_caption })
    flow.add({ type = "empty-widget", style = "flib_horizontal_pusher" })
    flow.add({ type = "label", style = style, caption = right_caption })
end

---@param info_flow LuaGuiElement
---@param train LuaTrain
local function add_job_travel_progress_footer(info_flow, train)
    info_flow.add({ type = "empty-widget", style = "flib_vertical_pusher" })
    info_flow.add({ type = "line" })
    add_job_label_pusher_label(info_flow, "info_label", { "sspp-gui.distance-to-travel" }, format_distance(train.path))
end

---@param info_flow LuaGuiElement
---@param train LuaTrain
local function add_job_fuel_transfer_progress_footer(info_flow, train)
    info_flow.add({ type = "empty-widget", style = "flib_vertical_pusher" })
    info_flow.add({ type = "line" })
    local min_fullness = 1.0
    for _, locos in pairs(train.locomotives) do
        for _, loco in pairs(locos) do
            ---@cast loco LuaEntity
            local inventory = assert(loco.burner, "TODO: electric trains").inventory
            local total_slots, total_filled_slots = inventory.count_empty_stacks(), 0.0
            for _, item in pairs(inventory.get_contents()) do
                local filled_slots = item.count / prototypes.item[item.name].stack_size
                total_slots, total_filled_slots = (total_slots + math.ceil(filled_slots)), (total_filled_slots + filled_slots)
            end
            min_fullness = math.min(min_fullness, total_filled_slots / total_slots)
        end
    end
    add_job_label_pusher_label(info_flow, "info_label", { "sspp-gui.fuel-to-transfer" }, string.format("%.0f%%", (1.0 - min_fullness) * 100.0))
end

---@param info_flow LuaGuiElement
---@param train LuaTrain
---@param item_key ItemKey
---@param target_count integer?
local function add_job_cargo_transfer_progress_footer(info_flow, train, item_key, target_count)
    info_flow.add({ type = "empty-widget", style = "flib_vertical_pusher" })
    info_flow.add({ type = "line" })
    local name, quality = split_item_key(item_key)
    local format = quality and "sspp-gui.fmt-items" or "sspp-gui.fmt-units"
    local count = get_train_item_count(train, name, quality)
    if target_count then count = target_count - count end
    add_job_label_pusher_label(info_flow, "info_label", { "sspp-gui.cargo-to-transfer" }, { format, count })
end

--------------------------------------------------------------------------------

---@param player_gui PlayerGui.Network
function gui_network.on_poll_finished(player_gui)
    local network_name = player_gui.network
    local network = storage.networks[network_name]
    local jobs = network.jobs
    local elements = player_gui.elements

    local class_hauler_totals = {} ---@type {[ClassName]: integer}

    -- update dynamic parts of item rows, and sum totals of active haulers
    do
        local context = player_gui.item_context
        local row_to_cells = context.row_to_cells

        local push_tickets = network.push_tickets
        local pull_tickets = network.pull_tickets

        local buffer_haulers = network.buffer_haulers
        local provide_haulers = network.provide_haulers
        local request_haulers = network.request_haulers
        local to_depot_liquidate_haulers = network.to_depot_liquidate_haulers
        local at_depot_liquidate_haulers = network.at_depot_liquidate_haulers

        for item_key, row in pairs(context.key_to_row) do
            local cells = row_to_cells[row]
            local class_name = cells[2].text

            local provide_total = len_or_zero(provide_haulers[item_key])
            local request_total = len_or_zero(request_haulers[item_key])
            local liquidate_total = len_or_zero(to_depot_liquidate_haulers[item_key]) + len_or_zero(at_depot_liquidate_haulers[item_key])

            local push_demand = len_or_zero(push_tickets[item_key])
            local pull_demand = math.max(0, len_or_zero(pull_tickets[item_key]) - provide_total)

            -- haulers being used as buffers are not subtracted from pull demand, but they are included in totals
            provide_total = provide_total + len_or_zero(buffer_haulers[item_key])

            cells[6].caption = { "sspp-gui.fmt-item-demand", push_demand, pull_demand }
            cells[8].caption = { "sspp-gui.fmt-item-haulers", provide_total, request_total, liquidate_total }

            class_hauler_totals[class_name] = (class_hauler_totals[class_name] or 0) + provide_total + request_total + liquidate_total
        end
    end

    -- update dynamic parts of class rows, making use of the totals from above
    do
        local context = player_gui.class_context
        local row_to_cells = context.row_to_cells

        local fuel_haulers = network.fuel_haulers
        local to_depot_haulers = network.to_depot_haulers
        local at_depot_haulers = network.at_depot_haulers

        for class_name, row in pairs(context.key_to_row) do
            local cells = row_to_cells[row]

            local available = len_or_zero(at_depot_haulers[class_name])
            local occupied = (class_hauler_totals[class_name] or 0) + len_or_zero(fuel_haulers[class_name])

            if cells[5].state then
                available = available + len_or_zero(to_depot_haulers[class_name])
            else
                occupied = occupied + len_or_zero(to_depot_haulers[class_name])
            end

            cells[7].caption = { "sspp-gui.fmt-class-available", available, available + occupied }
        end
    end

    local expanded_job_index = player_gui.expanded_job
    if expanded_job_index then
        local grid_table, info_flow = elements.grid_table, elements.info_flow

        local job = network.jobs[expanded_job_index]
        local hauler = storage.haulers[job.hauler] --[[@as Hauler?]]
        local job_type = job.type
        local in_progress_tick = hauler and hauler.job == expanded_job_index and game.tick or nil
        local in_progress_train = in_progress_tick and hauler--[[@as Hauler]].train

        grid_table.clear()
        info_flow.clear()

        add_job_minimap_widgets(grid_table, { "", "[img=item/locomotive] ", { "sspp-gui.hauler" } }, hauler and hauler.train.front_stock)
        info_flow.add({ type = "line" })
        add_job_label_pusher_label(info_flow, "caption_label", { "sspp-gui.job-started" }, format_time(job.start_tick))
        info_flow.add({ type = "line" })

        if job_type == "FUEL" then
            local fuel_stop = job.fuel_stop or (in_progress_train and in_progress_train.path_end_stop)

            local depart_tick, arrive_tick, done_tick = job.start_tick, job.fuel_arrive_tick, job.finish_tick
            add_job_minimap_widgets(grid_table, { "", "[img=item/train-stop] ", { "sspp-gui.fuel" } }, fuel_stop)
            add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-travel-to-fuel", get_stop_name(fuel_stop) }, format_duration(depart_tick, arrive_tick or in_progress_tick))
            if arrive_tick then
                add_job_label_pusher_label(info_flow, "label", { "sspp-gui.transfer-fuel-to-hauler" }, format_duration(arrive_tick, done_tick or in_progress_tick))
                if in_progress_train then
                    add_job_fuel_transfer_progress_footer(info_flow, in_progress_train)
                end
            elseif in_progress_train then
                add_job_travel_progress_footer(info_flow, in_progress_train)
            end
        else
            local provide_stop, request_stop = job.provide_stop, job.request_stop

            if provide_stop then
                local depart_tick, arrive_tick, done_tick = job.start_tick, job.provide_arrive_tick, job.provide_done_tick or job.finish_tick
                add_job_minimap_widgets(grid_table, { "", "[img=item/sspp-provide-io] ", { "sspp-gui.provide" } }, provide_stop)
                add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-travel-to-pick-up", get_stop_name(provide_stop) }, format_duration(depart_tick, arrive_tick or in_progress_tick))
                if arrive_tick then
                    add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-transfer-cargo-to-hauler", job.target_count }, format_duration(arrive_tick, done_tick or in_progress_tick))
                    if in_progress_train and not request_stop then
                        add_job_cargo_transfer_progress_footer(info_flow, in_progress_train, job.item, job.target_count)
                    end
                elseif in_progress_train then
                    add_job_travel_progress_footer(info_flow, in_progress_train)
                end
            end

            if request_stop then
                local depart_tick, arrive_tick, done_tick = job.provide_done_tick or job.start_tick, job.request_arrive_tick, job.finish_tick
                add_job_minimap_widgets(grid_table, { "", "[img=item/sspp-request-io] ", { "sspp-gui.request" } }, request_stop)
                add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-travel-to-drop-off", get_stop_name(request_stop) }, format_duration(depart_tick, arrive_tick or in_progress_tick))
                if arrive_tick then
                    add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-transfer-cargo-to-station", job.loaded_count }, format_duration(arrive_tick, done_tick or in_progress_tick))
                    if in_progress_train then
                        add_job_cargo_transfer_progress_footer(info_flow, in_progress_train, job.item, nil)
                    end
                elseif in_progress_train then
                    add_job_travel_progress_footer(info_flow, in_progress_train)
                end
            end
        end

        if not in_progress_tick then
            info_flow.add({ type = "empty-widget", style = "flib_vertical_pusher" })
            info_flow.add({ type = "line" })
            if job.finish_tick then
                add_job_label_pusher_label(info_flow, "caption_label", { "sspp-gui.job-finished" }, format_time(job.finish_tick))
            else
                add_job_label_pusher_label(info_flow, "caption_label", { "sspp-gui.job-aborted" }, format_time(job.abort_tick))
            end
        end
        info_flow.add({ type = "line" })

        return -- the rest of this function is only relevant to hauler and station grids
    end

    local provide_enabled = elements.grid_provide_toggle.toggled
    local request_enabled = elements.grid_request_toggle.toggled
    local liquidate_enabled = elements.grid_liquidate_toggle.toggled
    local fuel_enabled = elements.grid_fuel_toggle.toggled
    local depot_enabled = elements.grid_depot_toggle.toggled

    local grid_table = elements.grid_table
    local grid_children = grid_table.children

    -- to prevent having create hundreds of new minimaps every time, we reuse them between polls
    local old_length, new_length = #grid_children, 0

    local expanded_class_name = player_gui.expanded_class
    if expanded_class_name then
        for _, hauler in pairs(storage.haulers) do
            if hauler.network == network_name and hauler.class == expanded_class_name then
                local state_icon, item_key ---@type string?, ItemKey?
                local job_index = hauler.job
                if job_index then
                    local job = jobs[job_index]
                    if job.type == "FUEL" then
                        if fuel_enabled then state_icon = "[img=virtual-signal/signal-fuel]" end
                    else
                        if job.request_stop then
                            if request_enabled then item_key, state_icon = job.item, "[img=virtual-signal/down-arrow]" end
                        else
                            if provide_enabled then item_key, state_icon = job.item, "[img=virtual-signal/up-arrow]" end
                        end
                    end
                else
                    local depot_key = hauler.to_depot or hauler.at_depot
                    if depot_key == "" then
                        if depot_enabled then state_icon = "[img=virtual-signal/signal-white-flag]" end
                    elseif depot_key then
                        if liquidate_enabled then item_key, state_icon = depot_key, "[img=virtual-signal/signal-skull]" end
                    end
                    -- TODO: show disabled haulers
                end
                if state_icon then
                    new_length = new_length + 1
                    local minimap, top, bottom = acquire_next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = hauler.train.front_stock
                    top.caption = state_icon
                    if item_key then
                        local name, quality = split_item_key(item_key)
                        bottom.caption = tostring(get_train_item_count(hauler.train, name, quality)) .. make_item_icon(name, quality)
                    else
                        bottom.caption = ""
                    end
                end
            end
        end
    end

    local expanded_haulers_item_key = player_gui.expanded_haulers_item
    if expanded_haulers_item_key then
        local name, quality = split_item_key(expanded_haulers_item_key)
        local item_icon = make_item_icon(name, quality)
        for _, hauler in pairs(storage.haulers) do
            if hauler.network == network_name then
                local state_icon ---@type string?
                local job_index = hauler.job
                if job_index then
                    local job = jobs[job_index]
                    if job.item == expanded_haulers_item_key then
                        if job.request_stop then
                            if request_enabled then state_icon = "[img=virtual-signal/down-arrow]" end
                        else
                            if provide_enabled then state_icon = "[img=virtual-signal/up-arrow]" end
                        end
                    end
                else
                    local depot_key = hauler.to_depot or hauler.at_depot
                    if depot_key == expanded_haulers_item_key then
                        if liquidate_enabled then state_icon = "[img=virtual-signal/signal-skull]" end
                    end
                end
                if state_icon then
                    new_length = new_length + 1
                    local minimap, top, bottom = acquire_next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = hauler.train.front_stock
                    top.caption = state_icon
                    bottom.caption = tostring(get_train_item_count(hauler.train, name, quality)) .. item_icon
                end
            end
        end
    end

    local expanded_stations_item_key = player_gui.expanded_stations_item
    if expanded_stations_item_key then
        local item_icon ---@type string?
        if elements.grid_stations_mode_switch.switch_state == "left" then
            local name, quality = split_item_key(expanded_stations_item_key)
            item_icon = make_item_icon(name, quality)
        end
        for _, station in pairs(storage.stations) do
            if station.network == network_name then
                local provide = station.provide
                if provide and provide_enabled and provide.items[expanded_stations_item_key] then
                    new_length = new_length + 1
                    local minimap, top, bottom = acquire_next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = station.stop
                    top.caption = station.stop.backer_name
                    if item_icon then
                        bottom.caption = "+" .. tostring(provide.counts[expanded_stations_item_key]) .. item_icon
                    else
                        bottom.caption = tostring(len_or_zero(provide.deliveries[expanded_stations_item_key])) .. "[img=virtual-signal/up-arrow]"
                    end
                end
                local request = station.request
                if request and request_enabled and request.items[expanded_stations_item_key] then
                    new_length = new_length + 1
                    local minimap, top, bottom = acquire_next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = station.stop
                    top.caption = station.stop.backer_name
                    if item_icon then
                        bottom.caption = "-" .. tostring(request.counts[expanded_stations_item_key]) .. item_icon
                    else
                        bottom.caption = tostring(len_or_zero(request.deliveries[expanded_stations_item_key])) .. "[img=virtual-signal/down-arrow]"
                    end
                end
            end
        end
    end

    for i = old_length, new_length + 1, -1 do
        grid_children[i].destroy()
    end
end

--------------------------------------------------------------------------------

glib.handlers["network_add_class"] = { [events.on_gui_click] = function(event)
    glib.table_insert_blank_mutable_row(class_methods, storage.player_guis[event.player_index].class_context, nil, nil)
end }

glib.handlers["network_add_item"] = { [events.on_gui_click] = function(event)
    glib.table_insert_blank_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.player_index, "item-with-quality")
end }

glib.handlers["network_add_fluid"] = { [events.on_gui_click] = function(event)
    glib.table_insert_blank_mutable_row(item_methods, storage.player_guis[event.player_index].item_context, event.player_index, "fluid")
end }

glib.handlers["network_close_window"] = { [events.on_gui_click] = function(event)
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    assert(player.opened.name == "sspp-network")

    player.opened = nil
end }

--------------------------------------------------------------------------------

glib.handlers["network_import_import"] = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Network]]

    do
        local network = storage.networks[player_gui.network]

        local json = helpers.json_to_table(player_gui.popup_elements.textbox.text) --[[@as table]]
        if type(json) ~= "table" then goto failure end

        local version = json.sspp_network_version
        if version ~= 1 then goto failure end

        local classes = json.classes ---@type {[ClassName]: NetworkClass}
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

            if lib.is_item_key_invalid(item_key) then
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

        clear_expanded_object(player_gui)

        for class_name, _ in pairs(network.classes) do
            glib.table_remove_immutable_row(class_methods, player_gui.class_context, class_name)
            if classes[class_name] then
                network.classes[class_name] = classes[class_name]
                classes[class_name] = nil
            end
        end

        for item_key, _ in pairs(network.items) do
            glib.table_remove_immutable_row(item_methods, player_gui.item_context, item_key)
            if items[item_key] then
                network.items[item_key] = items[item_key]
                items[item_key] = nil
            end
        end

        for class_name, class in pairs(classes) do network.classes[class_name] = class end
        for item_key, item in pairs(items) do network.items[item_key] = item end

        glib.table_populate_from_objects(class_methods, player_gui.class_context, false)
        glib.table_populate_from_objects(item_methods, player_gui.item_context, false)

        return
    end

    ::failure::
    game.get_player(event.player_index).play_sound({ path = "utility/cannot_build" })
    player_gui.popup_elements.textbox.focus()
    player_gui.popup_elements.textbox.select_all()
end }

glib.handlers["network_export_export"] = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Network]]
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
---@param handler string
local function import_or_export_toggled(player_id, toggle, caption, handler)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Network]]

    if player_gui.popup_elements then
        player_gui.popup_elements["sspp-popup"].destroy()
        player_gui.popup_elements = nil
        if not toggle.toggled then return end
    end

    local window, elements = glib.add_element(game.get_player(player_id).gui.screen, {},
        { type = "frame", name = "sspp-popup", style = "frame", direction = "vertical", children = {
            { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                { type = "textfield", name = "textbox", style = "sspp_json_textbox" },
            } },
            { type = "flow", style = "dialog_buttons_horizontal_flow", direction = "horizontal", children = {
                { type = "button", style = "dialog_button", caption = { caption }, mouse_button_filter = { "left" }, handler = handler },
                { type = "empty-widget", style = "flib_dialog_footer_drag_handle_no_right", drag_target = "sspp-popup" },
            } },
        } }
    ) ---@cast elements -nil

    window.bring_to_front()
    window.force_auto_center()

    player_gui.popup_elements = elements
end

glib.handlers["network_import_toggled"] = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Network]]
    player_gui.elements.export_toggle.toggled = false
    import_or_export_toggled(player_id, event.element, "sspp-gui.import-from-string", "network_import_import")
    if player_gui.popup_elements then player_gui.popup_elements.textbox.focus() end
end }

glib.handlers["network_export_toggled"] = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Network]]
    player_gui.elements.import_toggle.toggled = false
    import_or_export_toggled(player_id, event.element, "sspp-gui.export-to-string", "network_export_export")
end }

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param network_name NetworkName
---@param tab_index integer
function gui_network.open(player_id, network_name, tab_index)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]
    local network = storage.networks[network_name]

    player.opened = nil

    local localised_name = network_name ---@type LocalisedString
    if network.surface.planet then
        localised_name = network.surface.planet.prototype.localised_name
    elseif network.surface.localised_name then
        localised_name = network.surface.localised_name
    end

    local window, elements = glib.add_element(player.gui.screen, {}, (
        { type = "frame", name = "sspp-network", style = "frame", direction = "vertical", children = {
            { type = "flow", style = "frame_header_flow", direction = "horizontal", drag_target = "sspp-network", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.network-for-surface", localised_name }, ignored_by_interaction = true },
                { type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true },
                { type = "sprite-button", name = "import_toggle", style = "frame_action_button", sprite = "sspp-import-icon", tooltip = { "sspp-gui.import-from-string" }, mouse_button_filter = { "left" }, auto_toggle = true, handler = "network_import_toggled" },
                { type = "sprite-button", name = "export_toggle", style = "frame_action_button", sprite = "sspp-export-icon", tooltip = { "sspp-gui.export-to-string" }, mouse_button_filter = { "left" }, auto_toggle = true, handler = "network_export_toggled" },
                { type = "empty-widget", style = "empty_widget" },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", mouse_button_filter = { "left" }, handler = "network_close_window" },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", direction = "horizontal", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "tabbed-pane", name = "tabbed_pane", style = "tabbed_pane", children = {
                        { type = "tab", style = "tab", caption = { "sspp-gui.classes" }, children = {
                            { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
                                { type = "table", style = "sspp_network_class_header", column_count = 7, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.name" }), tooltip = { "sspp-gui.class-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.depot-name" }), tooltip = { "sspp-gui.class-depot-name-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.fueler-name" }), tooltip = { "sspp-gui.class-fueler-name-tooltip" } },
                                    { type = "label", caption = "[img=sspp-bypass-icon]", tooltip = { "sspp-gui.class-bypass-depot-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=locomotive]" },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.available" }), tooltip = { "sspp-gui.class-available-tooltip" } },
                                } },
                                { type = "scroll-pane", style = "sspp_network_scroll_pane", direction = "vertical", children = {
                                    { type = "table", name = "class_table", style = "sspp_network_class_table", column_count = 7 },
                                    { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-class" }, mouse_button_filter = { "left" }, handler = "network_add_class" },
                                    } },
                                } },
                            } },
                        } },
                        { type = "tab", style = "tab", caption = { "sspp-gui.items-fluids" }, children = {
                            { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
                                { type = "table", style = "sspp_network_item_header", column_count = 8, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.class" }), tooltip = { "sspp-gui.item-class-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-size" }), tooltip = { "sspp-gui.item-delivery-size-tooltip" } },
                                    { type = "label", style = "bold_label", caption = cwi({ "sspp-gui.delivery-time" }), tooltip = { "sspp-gui.item-delivery-time-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=sspp-stop]" },
                                    { type = "label", style = "bold_label", caption = "[virtual-signal=up-arrow][virtual-signal=down-arrow]", tooltip = { "sspp-gui.item-demand-tooltip" } },
                                    { type = "label", style = "bold_label", caption = " [item=locomotive]" },
                                    { type = "label", style = "bold_label", caption = "[virtual-signal=up-arrow][virtual-signal=down-arrow][virtual-signal=signal-skull]", tooltip = { "sspp-gui.item-haulers-tooltip" } },
                                } },
                                { type = "scroll-pane", style = "sspp_network_scroll_pane", direction = "vertical", children = {
                                    { type = "table", name = "item_table", style = "sspp_network_item_table", column_count = 8 },
                                    { type = "flow", style = "horizontal_flow", direction = "horizontal", children = {
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, mouse_button_filter = { "left" }, handler = "network_add_item" },
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, mouse_button_filter = { "left" }, handler = "network_add_fluid" },
                                    } },
                                } },
                            } },
                        } },
                        { type = "tab", style = "tab", caption = { "sspp-gui.history" }, children = {
                            { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
                                { type = "table", style = "sspp_network_history_header", column_count = 5, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.action" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.duration" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.summary" } },
                                    { type = "empty-widget" },
                                } },
                                { type = "scroll-pane", style = "sspp_network_scroll_pane", direction = "vertical", children = {
                                    { type = "table", name = "job_table", style = "sspp_network_history_table", column_count = 5 },
                                } },
                            } },
                        } },
                    } },
                } },
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "frame", style = "sspp_stretchable_subheader_frame", direction = "horizontal", children = {
                        { type = "label", name = "grid_title", style = "subheader_caption_label" },
                        { type = "empty-widget", style = "flib_horizontal_pusher" },
                        { type = "switch", name = "grid_stations_mode_switch", style = "switch", left_label_caption = "[item=sspp-stop]", right_label_caption = "[item=locomotive]", left_label_tooltip = { "sspp-gui.grid-stations-station-tooltip" }, right_label_tooltip = { "sspp-gui.grid-stations-hauler-tooltip" }, visible = false },
                        { type = "sprite-button", name = "grid_provide_toggle", style = "control_settings_section_button", sprite = "virtual-signal/up-arrow", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_request_toggle", style = "control_settings_section_button", sprite = "virtual-signal/down-arrow", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_liquidate_toggle", style = "control_settings_section_button", sprite = "virtual-signal/signal-skull", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_fuel_toggle", style = "control_settings_section_button", sprite = "virtual-signal/signal-fuel", enabled = false, auto_toggle = true, toggled = true },
                        { type = "sprite-button", name = "grid_depot_toggle", style = "control_settings_section_button", sprite = "virtual-signal/signal-white-flag", enabled = false, auto_toggle = true, toggled = true },
                    } },
                    { type = "frame", style = "shallow_frame", direction = "horizontal", children = {
                        { type = "scroll-pane", name = "right_scroll_pane", style = "sspp_right_grid_scroll_pane", direction = "vertical", children = {
                            { type = "table", name = "grid_table", style = "sspp_grid_table", column_count = 3 },
                            { type = "flow", name = "info_flow", style = "vertical_flow", direction = "vertical" },
                        } },
                    } },
                } },
            } },
        } }
    )) ---@cast elements -nil

    elements.tabbed_pane.selected_tab_index = tab_index
    window.force_auto_center()

    ---@type PlayerGui.Network
    local player_gui = {
        type = "NETWORK", network = network_name, elements = elements,
        class_context = nil, item_context = nil, job_context = nil, ---@diagnostic disable-line: assign-type-mismatch
    }

    player_gui.class_context = { root = player_gui, table = elements.class_table, row_to_cells = {}, row_to_key = {}, key_to_row = {}, key_to_object = network.classes }
    player_gui.item_context = { root = player_gui, table = elements.item_table, row_to_cells = {}, row_to_key = {}, key_to_row = {}, key_to_object = network.items }
    player_gui.job_context = { root = player_gui, table = elements.job_table, row_to_cells = {}, row_to_key = {}, key_to_row = {}, key_to_object = network.jobs }

    storage.player_guis[player_id] = player_gui

    glib.table_populate_from_objects(class_methods, player_gui.class_context, false)
    glib.table_populate_from_objects(item_methods, player_gui.item_context, false)
    glib.table_populate_from_objects(job_methods, player_gui.job_context, true)

    player.opened = window
end

---@param player_id PlayerId
function gui_network.close(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Network]]

    player_gui.elements["sspp-network"].destroy()
    if player_gui.popup_elements then player_gui.popup_elements["sspp-popup"].destroy() end

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

return gui_network
