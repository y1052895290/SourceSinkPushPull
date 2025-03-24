-- SSPP by jagoly

local flib_gui = require("__flib__.gui")
local events = defines.events

local cwi = gui.caption_with_info
local format_disatnce = gui.format_distance
local format_duration = gui.format_duration
local format_time = gui.format_time
local get_stop_name = gui.get_stop_name

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
    elements.right_scroll_pane.style = "sspp_right_grid_scroll_pane"

    elements.grid_table.clear()
    elements.info_flow.clear()

    player_gui.haulers_class = nil
    player_gui.haulers_item = nil
    player_gui.stations_item = nil
    player_gui.expanded_job = nil
end

---@param event EventData.on_gui_click
local handle_expand_class_haulers = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local class_name = elements.class_table.children[event.element.get_index_in_parent() - 4].text
    if class_name ~= "" then
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
    end

    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_click
local handle_expand_item_haulers = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local elem_value = elements.item_table.children[event.element.get_index_in_parent() - 6].children[3].elem_value
    if elem_value then
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
    end

    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_click
local handle_expand_item_stations = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local elem_value = elements.item_table.children[event.element.get_index_in_parent() - 4].children[3].elem_value
    if elem_value then
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
    end

    gui.update_network_after_change(event.player_index)
end }

---@param event EventData.on_gui_click
local handle_expand_job = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements

    clear_grid_and_header(player_gui)

    local job_index = player_gui.history_indices[event.element.get_index_in_parent() / 5]
    local job = storage.networks[player_gui.network].jobs[job_index]
    local job_type = job.type

    if job_type == "FUEL" then
        elements.grid_title.caption = { "sspp-gui.fmt-job-title", "[virtual-signal=signal-fuel]", job_index }
    else
        local name, quality = split_item_key(job_type)
        elements.grid_title.caption = { "sspp-gui.fmt-job-title", make_item_icon(name, quality), job_index }
    end
    elements.right_scroll_pane.style = "sspp_right_flat_scroll_pane"

    player_gui.expanded_job = job_index

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
        { type = "textfield", style = "sspp_wide_number_textbox", numeric = true, text = "", handler = handle_item_delivery_size_changed },
        { type = "textfield", style = "sspp_wide_number_textbox", numeric = true, text = "", handler = handle_item_delivery_time_changed },
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

---@param player_gui PlayerNetworkGui
---@param message LocalisedString
---@param item_key ItemKey
local function item_remove_key_inner(player_gui, message, item_key)
    local network = storage.networks[player_gui.network]

    set_haulers_to_manual(network.buffer_haulers[item_key], message, item_key)
    set_haulers_to_manual(network.provide_haulers[item_key], message, item_key)
    set_haulers_to_manual(network.request_haulers[item_key], message, item_key)
    set_haulers_to_manual(network.to_depot_liquidate_haulers[item_key], message, item_key)
    set_haulers_to_manual(network.at_depot_liquidate_haulers[item_key], message, item_key)

    storage.disabled_items[network.surface.name .. ":" .. item_key] = true

    if player_gui.haulers_item == item_key then clear_grid_and_header(player_gui) end
    if player_gui.stations_item == item_key then clear_grid_and_header(player_gui) end
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

    for item_key, item in pairs(network.items) do
        if item.class == class_name then
            item_remove_key_inner(player_gui, { "sspp-alert.class-not-in-network" }, item_key)
        end
    end
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
    item_remove_key_inner(player_gui, { "sspp-alert.cargo-not-in-network" }, item_key)
end

--------------------------------------------------------------------------------

---@param history_table LuaGuiElement
---@param row_index integer
---@param job_index JobIndex
---@param job Job
local function insert_history_row(history_table, row_index, job_index, job)
    local hauler = storage.haulers[job.hauler] --[[@as Hauler?]]
    local job_type = job.type
    local in_progress = hauler and hauler.job == job_index or nil

    local signal ---@type SignalID
    if job_type == "FUEL" then
        signal = { name = "signal-fuel", type = "virtual" }
    else
        local name, quality = split_item_key(job_type)
        signal = { name = name, quality = quality, type = quality and "item" or "fluid" }
    end

    local elem_button = history_table.add({ index = row_index * 5 - 4, type = "choose-elem-button", style = "slot_button", elem_type = "signal", signal = signal })
    elem_button.locked = true -- https://forums.factorio.com/viewtopic.php?t=127562
    local actions_flow = history_table.add({ index = row_index * 5 - 3, type = "flow", style = "sspp_history_cell_flow", direction = "vertical" })
    local durations_flow = history_table.add({ index = row_index * 5 - 2, type = "flow", style = "sspp_history_cell_flow", direction = "vertical" })
    local summary_flow = history_table.add({ index = row_index * 5 - 1, type = "flow", style = "sspp_history_cell_flow", direction = "vertical" })
    history_table.add({ index = row_index * 5 - 0, type = "sprite-button", style = "sspp_compact_sprite_button", sprite = "sspp-grid-icon", tags = flib_gui.format_handlers(handle_expand_job) })

    if job_type == "FUEL" then
        local fuel_stop = job.fuel_stop or (in_progress and hauler--[[@as Hauler]].train.path_end_stop)

        local depart_tick, arrive_tick, done_tick = job.start_tick, job.fuel_arrive_tick, job.finish_tick
        actions_flow.add({ type = "label", style = "sspp_history_action_label", caption = { "sspp-gui.fmt-travel-to-fuel", get_stop_name(fuel_stop) } })
        durations_flow.add({ type = "label", style = "label", caption = format_duration(depart_tick, arrive_tick or in_progress) })
        if arrive_tick then
            actions_flow.add({ type = "label", style = "sspp_history_action_label", caption = { "sspp-gui.transfer-fuel-to-hauler" } })
            durations_flow.add({ type = "label", style = "label", caption = format_duration(arrive_tick, done_tick or in_progress) })
        end
    else
        local provide_stop, request_stop = job.provide_stop, job.request_stop

        if provide_stop then
            local depart_tick, arrive_tick, done_tick = job.start_tick, job.provide_arrive_tick, job.provide_done_tick
            actions_flow.add({ type = "label", style = "sspp_history_action_label", caption = { "sspp-gui.fmt-travel-to-pick-up", get_stop_name(provide_stop) } })
            durations_flow.add({ type = "label", style = "label", caption = format_duration(depart_tick, arrive_tick or in_progress) })
            if arrive_tick then
                actions_flow.add({ type = "label", style = "sspp_history_action_label", caption = { "sspp-gui.fmt-transfer-cargo-to-hauler", job.target_count } })
                durations_flow.add({ type = "label", style = "label", caption = format_duration(arrive_tick, done_tick or in_progress) })
            end
        end

        if request_stop then
            local depart_tick, arrive_tick, done_tick = job.provide_done_tick or job.start_tick, job.request_arrive_tick, job.finish_tick
            actions_flow.add({ type = "label", style = "sspp_history_action_label", caption = { "sspp-gui.fmt-travel-to-drop-off", get_stop_name(request_stop) } })
            durations_flow.add({ type = "label", style = "label", caption = format_duration(depart_tick, arrive_tick or in_progress) })
            if arrive_tick then
                actions_flow.add({ type = "label", style = "sspp_history_action_label", caption = { "sspp-gui.fmt-transfer-cargo-to-station", job.loaded_count } })
                durations_flow.add({ type = "label", style = "label", caption = format_duration(arrive_tick, done_tick or in_progress) })
            end
        end
    end

    local start_tick, finish_tick, abort_tick = job.start_tick, job.finish_tick, job.abort_tick
    summary_flow.add({ type = "label", style = "label", caption = { "", { "sspp-gui.job-started" }, format_time(start_tick) } })
    if finish_tick then
        summary_flow.add({ type = "label", style = "label", caption = { "", { "sspp-gui.job-finished" }, format_time(finish_tick) } })
        summary_flow.add({ type = "label", style = "label", caption = { "", { "sspp-gui.total-duration" }, format_duration(start_tick, finish_tick) } })
    elseif abort_tick then
        summary_flow.add({ type = "label", style = "label", caption = { "", { "sspp-gui.job-aborted" }, format_time(abort_tick) } })
    end
end

--------------------------------------------------------------------------------

---@param player_gui PlayerNetworkGui
function gui.network_job_created(player_gui, job_index)
    local history_table = player_gui.elements.history_table

    if history_table.style.name == "sspp_network_history_inverted_table" then
        history_table.style = "sspp_network_history_table"
    else
        history_table.style = "sspp_network_history_inverted_table"
    end

    insert_history_row(history_table, 1, job_index, storage.networks[player_gui.network].jobs[job_index])
    table.insert(player_gui.history_indices, 1, job_index)
end

---@param player_gui PlayerNetworkGui
function gui.network_job_removed(player_gui, job_index)
    local history_indices = player_gui.history_indices

    for row_index, row_job_index in pairs(history_indices) do
        if row_job_index == job_index then
            gui.delete_row(player_gui.elements.history_table, row_index * 5 - 4)
            table.remove(history_indices, row_index)
            if player_gui.expanded_job == job_index then clear_grid_and_header(player_gui) end
            return
        end
    end
end

---@param player_gui PlayerNetworkGui
function gui.network_job_updated(player_gui, job_index)
    local history_table = player_gui.elements.history_table

    for row_index, row_job_index in pairs(player_gui.history_indices) do
        if row_job_index == job_index then
            local toggled = history_table.children[row_index * 5].toggled
            gui.delete_row(history_table, row_index * 5 - 4)
            insert_history_row(history_table, row_index, job_index, storage.networks[player_gui.network].jobs[job_index])
            history_table.children[row_index * 5].toggled = toggled
            return
        end
    end
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
function gui.update_network_after_change(player_id)
    local player_gui = storage.player_guis[player_id] --[[@as PlayerNetworkGui]]
    local elements = player_gui.elements
    local network = storage.networks[player_gui.network]

    network.classes = gui.refresh_table(
        elements.class_table,
        class_from_row,
        function(b, c, d, e) return class_to_row(player_gui, b, c, d, e) end,
        network.classes,
        function(b) return class_remove_key(player_gui, b) end
    )

    network.items = gui.refresh_table(
        elements.item_table,
        item_from_row,
        function(b, c, d, e) return item_to_row(player_gui, b, c, d, e) end,
        network.items,
        function(b) return item_remove_key(player_gui, b) end
    )

    local history_children = elements.history_table.children
    local expanded_job_index = player_gui.expanded_job

    for row_index, job_index in pairs(player_gui.history_indices) do
        history_children[row_index * 5].toggled = (expanded_job_index == job_index)
    end
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
        minimap.add({ type = "button", style = "sspp_minimap_button", tags = flib_gui.format_handlers(gui.handle_open_minimap_entity) })
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
    add_job_label_pusher_label(info_flow, "info_label", { "sspp-gui.distance-to-travel" }, format_disatnce(train.path) )
end

---@param info_flow LuaGuiElement
---@param train LuaTrain
local function add_job_fuel_transfer_progress_footer(info_flow, train)
    info_flow.add({ type = "empty-widget", style = "flib_vertical_pusher" })
    info_flow.add({ type = "line" })
    local min_fullness = 1.0
    for _, loco_list in pairs(train.locomotives--[=[@as {string: LuaEntity[]}]=]) do
        for _, loco in pairs(loco_list) do
            local inventory = assert(loco.burner, "TODO: electric trains").inventory
            local total_slots, total_filled_slots = inventory.count_empty_stacks(), 0.0
            for _, item in pairs(inventory.get_contents()) do
                local filled_slots = item.count / prototypes.item[item.name].stack_size
                total_slots, total_filled_slots = (total_slots + math.ceil(filled_slots)), (total_filled_slots + filled_slots)
            end
            min_fullness = math.min(min_fullness, total_filled_slots / total_slots)
        end
    end
    add_job_label_pusher_label(info_flow, "info_label", { "sspp-gui.fuel-to-transfer" }, string.format("%.0f%%", (1.0 - min_fullness) * 100.0) )
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
    add_job_label_pusher_label(info_flow, "info_label", { "sspp-gui.cargo-to-transfer" }, { format, count } )
end

--------------------------------------------------------------------------------

---@param player_gui PlayerNetworkGui
function gui.network_poll_finished(player_gui)
    local network_name = player_gui.network
    local network = storage.networks[network_name]
    local elements = player_gui.elements

    local class_hauler_totals = {} ---@type {[ClassName]: integer}

    -- update dynamic parts of item rows, and sum totals of active haulers
    do
        local push_tickets = network.push_tickets
        local pull_tickets = network.pull_tickets

        local buffer_haulers = network.buffer_haulers
        local provide_haulers = network.provide_haulers
        local request_haulers = network.request_haulers
        local to_depot_liquidate_haulers = network.to_depot_liquidate_haulers
        local at_depot_liquidate_haulers = network.at_depot_liquidate_haulers

        local table_children = elements.item_table.children

        for i = 0, #table_children - 1, elements.item_table.column_count do
            if table_children[i + 1].children[4].sprite == "" then
                local _, _, item_key = gui.extract_elem_value_fields(table_children[i + 1].children[3].elem_value)
                local class_name = table_children[i + 2].text

                local provide_total = len_or_zero(provide_haulers[item_key])
                local request_total = len_or_zero(request_haulers[item_key])
                local liquidate_total = len_or_zero(to_depot_liquidate_haulers[item_key]) + len_or_zero(at_depot_liquidate_haulers[item_key])

                local push_demand = len_or_zero(push_tickets[item_key])
                local pull_demand = math.max(0, len_or_zero(pull_tickets[item_key]) - provide_total)

                -- haulers being used as buffers are not subtracted from pull demand, but they are included in totals
                provide_total = provide_total + len_or_zero(buffer_haulers[item_key])

                table_children[i + 6].caption = { "sspp-gui.fmt-item-demand", push_demand, pull_demand }
                table_children[i + 8].caption = { "sspp-gui.fmt-item-haulers", provide_total, request_total, liquidate_total }

                class_hauler_totals[class_name] = (class_hauler_totals[class_name] or 0) + provide_total + request_total + liquidate_total
            else
                table_children[i + 6].caption = ""
                table_children[i + 8].caption = ""
            end
        end
    end

    -- update dynamic parts of class rows, making use of the totals from above
    do
        local fuel_haulers = network.fuel_haulers
        local to_depot_haulers = network.to_depot_haulers
        local at_depot_haulers = network.at_depot_haulers

        local table_children = elements.class_table.children

        for i = 0, #table_children - 1, elements.class_table.column_count do
            if table_children[i + 1].children[4].sprite == "" then
                local class_name = table_children[i + 2].text

                local available = len_or_zero(at_depot_haulers[class_name])
                local occupied = (class_hauler_totals[class_name] or 0) + len_or_zero(fuel_haulers[class_name])

                if table_children[i + 5].state then
                    available = available + len_or_zero(to_depot_haulers[class_name])
                else
                    occupied = occupied + len_or_zero(to_depot_haulers[class_name])
                end

                table_children[i + 7].caption = { "sspp-gui.fmt-class-available", available, available + occupied }
            else
                table_children[i + 7].caption = ""
            end
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
                local depart_tick, arrive_tick, done_tick = job.start_tick, job.provide_arrive_tick, job.provide_done_tick
                add_job_minimap_widgets(grid_table, { "", "[img=item/sspp-provide-io] ", { "sspp-gui.provide" } }, provide_stop)
                add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-travel-to-pick-up", get_stop_name(provide_stop) }, format_duration(depart_tick, arrive_tick or in_progress_tick))
                if arrive_tick then
                    add_job_label_pusher_label(info_flow, "label", { "sspp-gui.fmt-transfer-cargo-to-hauler", job.target_count }, format_duration(arrive_tick, done_tick or in_progress_tick))
                    if in_progress_train and not request_stop then
                        add_job_cargo_transfer_progress_footer(info_flow, in_progress_train, job_type, job.target_count)
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
                        add_job_cargo_transfer_progress_footer(info_flow, in_progress_train, job_type, nil)
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
                    local minimap, top, bottom = gui.next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = hauler.train.front_stock
                    top.caption = state_icon
                    if name then
                        bottom.caption = tostring(get_train_item_count(hauler.train, name, quality)) .. make_item_icon(name, quality)
                    else
                        bottom.caption = ""
                    end
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
                if liquidate_enabled and (hauler.to_depot or hauler.at_depot) == haulers_item_key then
                    state_icon = "[img=virtual-signal/signal-skull]"
                end
                if state_icon then
                    new_length = new_length + 1
                    local minimap, top, bottom = gui.next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = hauler.train.front_stock
                    top.caption = state_icon
                    bottom.caption = tostring(get_train_item_count(hauler.train, name, quality)) .. item_icon
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
                    local minimap, top, bottom = gui.next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = station.stop
                    top.caption = station.stop.backer_name
                    if item_icon then
                        bottom.caption = "+" .. tostring(station.provide_counts[stations_item_key]) .. item_icon
                    else
                        bottom.caption = tostring(len_or_zero(station.provide_deliveries[stations_item_key])) .. "[img=virtual-signal/up-arrow]"
                    end
                end
                if request_enabled and station.request_items and station.request_items[stations_item_key] then
                    new_length = new_length + 1
                    local minimap, top, bottom = gui.next_minimap(grid_table, grid_children, old_length, new_length)
                    minimap.entity = station.stop
                    top.caption = station.stop.backer_name
                    if item_icon then
                        bottom.caption = "-" .. tostring(station.request_counts[stations_item_key]) .. item_icon
                    else
                        bottom.caption = tostring(len_or_zero(station.request_deliveries[stations_item_key])) .. "[img=virtual-signal/down-arrow]"
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
        for i = #class_children, 1, -1 do class_children[i].destroy() end
        network.classes = classes
        for class_name, class in pairs(classes) do class_init_row(class_table, class_name, class) end

        for item_key, _ in pairs(network.items) do
            if not items[item_key] then item_remove_key(player_gui, item_key) end
        end
        local item_table = player_gui.elements.item_table
        local item_children = item_table.children
        for i = #item_children, 1, -1 do item_children[i].destroy() end
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
                { type = "empty-widget", style = "empty_widget" },
                { type = "sprite-button", style = "close_button", sprite = "utility/close", mouse_button_filter = { "left" }, handler = handle_close_window },
            } },
            { type = "flow", style = "inset_frame_container_horizontal_flow", direction = "horizontal", children = {
                { type = "frame", style = "inside_deep_frame", direction = "vertical", children = {
                    { type = "tabbed-pane", name = "tabbed_pane", style = "tabbed_pane", children = {
                        ---@diagnostic disable-next-line: missing-fields
                        {
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.classes" } },
                            content = { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
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
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-class" }, mouse_button_filter = { "left" }, handler = handle_add_class },
                                    } },
                                } },
                            } },
                        },
                        ---@diagnostic disable-next-line: missing-fields
                        {
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.items-fluids" } },
                            content = { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
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
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-item" }, mouse_button_filter = { "left" }, handler = handle_add_item },
                                        { type = "button", style = "train_schedule_add_station_button", caption = { "sspp-gui.add-fluid" }, mouse_button_filter = { "left" }, handler = handle_add_fluid },
                                    } },
                                } },
                            } },
                        },
                        ---@diagnostic disable-next-line: missing-fields
                        {
                            tab = { type = "tab", style = "tab", caption = { "sspp-gui.history" } },
                            content = { type = "flow", style = "sspp_tab_content_flow", direction = "vertical", children = {
                                { type = "table", style = "sspp_network_history_header", column_count = 5, children = {
                                    { type = "empty-widget" },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.action" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.duration" } },
                                    { type = "label", style = "bold_label", caption = { "sspp-gui.summary" } },
                                    { type = "empty-widget" },
                                } },
                                { type = "scroll-pane", style = "sspp_network_scroll_pane", direction = "vertical", children = {
                                    { type = "table", name = "history_table", style = "sspp_network_history_table", column_count = 5 },
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
                    { type = "frame", style = "shallow_frame", direction = "horizontal", children = {
                        { type = "scroll-pane", name = "right_scroll_pane", style = "sspp_right_grid_scroll_pane", direction = "vertical", children = {
                            { type = "table", name = "grid_table", style = "sspp_grid_table", column_count = 3 },
                            { type = "flow", name = "info_flow", style = "vertical_flow", direction = "vertical" },
                        } },
                    } },
                } },
            } },
        } },
    })

    elements.tabbed_pane.selected_tab_index = tab_index
    window.force_auto_center()

    local history_indices = {} ---@type JobIndex[]
    local player_gui = { network = network_name, elements = elements, history_indices = history_indices }
    storage.player_guis[player_id] = player_gui

    local class_table = elements.class_table
    for class_name, class in pairs(network.classes) do class_init_row(class_table, class_name, class) end

    local item_table = elements.item_table
    for item_key, item in pairs(network.items) do item_init_row(item_table, item_key, item) end

    local history_table = elements.history_table
    for job_index, job in pairs(network.jobs) do
        insert_history_row(history_table, 1, job_index, job)
        table.insert(history_indices, 1, job_index)
    end

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
        ["network_expand_job"] = handle_expand_job[events.on_gui_click],
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
