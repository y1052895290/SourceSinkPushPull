-- SSPP by jagoly

local flib_gui = require("__flib__.gui")
local events = defines.events

gui = {}

--------------------------------------------------------------------------------

---@param caption LocalisedString
---@return LocalisedString
function gui.caption_with_info(caption)
    return { "", caption, " [img=info]" }
end

---@param path LuaRailPath?
---@return LocalisedString
function gui.format_distance(path)
    if path then
        return { "sspp-gui.fmt-metres", math.floor(path.total_distance - path.travelled_distance + 0.5) }
    end
    return { "sspp-gui.no-path" }
end

---@param start_tick MapTick
---@param finish_tick_or_in_progress (MapTick|true)?
---@return LocalisedString
function gui.format_duration(start_tick, finish_tick_or_in_progress)
    if finish_tick_or_in_progress then
        if finish_tick_or_in_progress ~= true then
            return { "sspp-gui.fmt-seconds", math.floor((finish_tick_or_in_progress - start_tick) / 60.0 + 0.5) }
        end
        return { "sspp-gui.active" }
    end
    return { "sspp-gui.aborted" }
end

---@param tick MapTick
---@return LocalisedString
function gui.format_time(tick)
    local total_seconds = math.floor(tick / 60)
    local seconds = total_seconds % 60
    local minutes = math.floor(total_seconds / 60) % 60
    local hours = math.floor(total_seconds / 3600)
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

--- The entity passed to this function can be invalid.
---@param stop LuaEntity?
---@return string
function gui.get_stop_name(stop)
    if stop and stop.valid then
        return stop.backer_name --[[@as string]]
    end
    return "[virtual-signal=signal-ghost]"
end

---@param input LuaGuiElement
---@param max_length integer
---@return string
function gui.truncate_input(input, max_length)
    local text = input.text
    local length = #text
    if length > max_length then
        length = max_length
        for i = max_length, 1, -1 do
            local byte = string.byte(text, i)
            if bit32.extract(byte, 4, 4) == 15 then
                if i + 3 > max_length then length = i - 1 end
                break
            end
            if bit32.extract(byte, 5, 3) == 7 then
                if i + 2 > max_length then length = i - 1 end
                break
            end
            if bit32.extract(byte, 6, 2) == 3 then
                if i + 1 > max_length then length = i - 1 end
                break
            end
            if bit32.extract(byte, 7, 1) == 0 then
                break
            end
        end
        text = string.sub(text, 1, length)
        input.text = text
    end
    return text
end

---@param table LuaGuiElement
---@param flow_index integer
---@param button_index integer
function gui.move_row(table, flow_index, button_index)
    local columns = table.column_count
    local i = flow_index - 1
    local j = i + (button_index * 2 - 3) * columns
    if j >= 0 and j + columns <= #table.children then
        for c = 1, columns do
            table.swap_children(i + c, j + c)
        end
    end
end

---@param table LuaGuiElement
---@param flow_index integer
function gui.delete_row(table, flow_index)
    local children = table.children
    for i = flow_index - 1 + table.column_count, flow_index, -1 do
        children[i].destroy()
    end
end

---@param table LuaGuiElement
---@param destination_i integer
function gui.insert_newly_added_row(table, destination_i)
    local columns = table.column_count
    for i = #table.children - columns, destination_i + columns, -columns do
        for c = 1, columns do
            table.swap_children(i + c, i + c - columns)
        end
    end
end

---@param elem_value table|string
---@return string name, string? quality, ItemKey item_key
function gui.extract_elem_value_fields(elem_value)
    local name, quality, item_key ---@type string, string?, ItemKey
    if type(elem_value) == "table" then
        name = elem_value.name
        quality = elem_value.quality or "normal"
        item_key = name .. ":" .. quality
    else
        name = elem_value --[[@as string]]
        item_key = name
    end
    return name, quality, item_key
end

---@param table LuaGuiElement
---@param from_row fun(table_children: LuaGuiElement[], i: integer): key: string?, value: any
---@param to_row fun(table_children: LuaGuiElement[], i: integer, key: string?, value: any)
---@param old_dict {[string]: any}?
---@param key_remove fun(key: string)?
---@return {[string]: any}
function gui.refresh_table(table, from_row, to_row, old_dict, key_remove)
    local columns = table.column_count
    local table_children = table.children

    local new_dict = {}

    for i = 0, #table_children - 1, columns do
        local key, value = from_row(table_children, i)
        if key then
            if new_dict[key] then
                key, value = nil, nil
            else
                new_dict[key] = value
            end
        end
        to_row(table_children, i, key, value)
    end

    if old_dict then
        ---@cast key_remove fun(key: string)
        for key, _ in pairs(old_dict) do
            if not new_dict[key] then key_remove(key) end
        end
    end

    return new_dict
end

---@param event EventData.on_gui_click
gui.handle_open_minimap_entity = { [events.on_gui_click] = function(event)
    local entity = event.element.parent.entity
    if entity and entity.valid then
        game.get_player(event.player_index).opened = entity
    end
end }

---@param grid_table LuaGuiElement
---@param grid_children LuaGuiElement[]
---@param old_length integer
---@param new_length integer
---@return LuaGuiElement minimap, LuaGuiElement top, LuaGuiElement bottom
function gui.next_minimap(grid_table, grid_children, old_length, new_length)
    if new_length > old_length then
        local outer_frame = grid_table.add({ type = "frame", style = "sspp_thin_shallow_frame" })
        local inner_frame = outer_frame.add({ type = "frame", style = "deep_frame_in_shallow_frame" })
        local minimap = inner_frame.add({ type = "minimap", style = "sspp_minimap", zoom = 1.0 })

        minimap.add({ type = "button", style = "sspp_minimap_button", tags = flib_gui.format_handlers(gui.handle_open_minimap_entity) })
        local top = minimap.add({ type = "label", style = "sspp_minimap_top_label", ignored_by_interaction = true })
        local bottom = minimap.add({ type = "label", style = "sspp_minimap_bottom_label", ignored_by_interaction = true })

        return minimap, top, bottom
    end

    local minimap = grid_children[new_length].children[1].children[1]
    local minimap_children = minimap.children

    return minimap, minimap_children[2], minimap_children[3]
end

--------------------------------------------------------------------------------

require("gui.network")
require("gui.station")
require("gui.hauler")

--------------------------------------------------------------------------------

function gui.on_poll_finished()
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.unit_number then
            gui.station_poll_finished(player_gui --[[@as PlayerStationGui]])
        elseif player_gui.train_id then
            -- gui.hauler_poll_finished(player_gui --[[@as PlayerHaulerGui]])
        else
            gui.network_poll_finished(player_gui --[[@as PlayerNetworkGui]])
        end
    end
end

---@param network_name NetworkName
---@param job_index JobIndex
function gui.on_job_created(network_name, job_index)
    for _, player_gui in pairs(storage.player_guis) do
        if not (player_gui.unit_number or player_gui.train_id) then
            if player_gui.network == network_name then
                gui.network_job_created(player_gui --[[@as PlayerNetworkGui]], job_index)
            end
        end
    end
end

---@param network_name NetworkName
---@param job_index JobIndex
function gui.on_job_removed(network_name, job_index)
    for _, player_gui in pairs(storage.player_guis) do
        if not (player_gui.unit_number or player_gui.train_id) then
            if player_gui.network == network_name then
                gui.network_job_removed(player_gui --[[@as PlayerNetworkGui]], job_index)
            end
        end
    end
end

---@param network_name NetworkName
---@param job_index JobIndex
function gui.on_job_updated(network_name, job_index)
    for _, player_gui in pairs(storage.player_guis) do
        if not (player_gui.unit_number or player_gui.train_id) then
            if player_gui.network == network_name then
                gui.network_job_updated(player_gui --[[@as PlayerNetworkGui]], job_index)
            end
        end
    end
end

---@param hauler_id HaulerId
function gui.on_manual_mode_changed(hauler_id)
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.train_id then
            if player_gui.train_id == hauler_id then
                gui.hauler_manual_mode_changed(player_gui --[[@as PlayerHaulerGui]])
            end
        end
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
local function on_gui_opened(event)
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity ---@type LuaEntity
        local name = entity.name
        if name == "entity-ghost" then name = entity.ghost_name end
        if name == "sspp-stop" or name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
            gui.station_open(event.player_index, entity)
        elseif entity.type == "locomotive" then
            gui.hauler_opened(event.player_index, entity.train)
        end
    end
end

---@param event EventData.on_gui_closed
local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.custom then
        if event.element.name == "sspp-network" then
            gui.network_closed(event.player_index)
        elseif event.element.name == "sspp-station" then
            gui.station_closed(event.player_index)
        end
    elseif event.gui_type == defines.gui_type.entity then
        if event.entity.type == "locomotive" then
            gui.hauler_closed(event.player_index)
        end
    end
end

--------------------------------------------------------------------------------

function gui.register_event_handlers()
    flib_gui.add_handlers({
        ["gui_open_minimap_entity"] = gui.handle_open_minimap_entity[events.on_gui_click],
    })

    gui.network_add_flib_handlers()
    gui.station_add_flib_handlers()
    gui.hauler_add_flib_handlers()

    script.on_event(events.on_gui_opened, on_gui_opened)
    script.on_event(events.on_gui_closed, on_gui_closed)

    flib_gui.handle_events()
end
