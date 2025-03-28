-- SSPP by jagoly

local flib_gui = require("__flib__.gui")

local glib = {}

--------------------------------------------------------------------------------

---@param caption LocalisedString
---@return LocalisedString
function glib.caption_with_info(caption)
    return { "", caption, " [img=info]" }
end

---@param input LuaGuiElement
---@param max_length integer
---@return string
function glib.truncate_input(input, max_length)
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

---@param elem_value table|string
---@return string name, string? quality, ItemKey item_key
function glib.extract_elem_value_fields(elem_value)
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

--------------------------------------------------------------------------------

---@param table LuaGuiElement
---@param flow_index integer
---@param button_index integer
function glib.move_row(table, flow_index, button_index)
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
function glib.delete_row(table, flow_index)
    local children = table.children
    for i = flow_index - 1 + table.column_count, flow_index, -1 do
        children[i].destroy()
    end
end

---@param table LuaGuiElement
---@param destination_i integer
function glib.insert_newly_added_row(table, destination_i)
    local columns = table.column_count
    for i = #table.children - columns, destination_i + columns, -columns do
        for c = 1, columns do
            table.swap_children(i + c, i + c - columns)
        end
    end
end

---@param table LuaGuiElement
---@param from_row fun(table_children: LuaGuiElement[], i: integer): key: string?, value: any
---@param to_row fun(table_children: LuaGuiElement[], i: integer, key: string?, value: any)
---@param old_dict {[string]: any}?
---@param key_remove fun(key: string)?
---@return {[string]: any}
function glib.refresh_table(table, from_row, to_row, old_dict, key_remove)
    local table_children = table.children

    local new_dict = {}

    for i = 0, #table_children - 1, table.column_count do
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
        ---@cast key_remove -nil
        for key, _ in pairs(old_dict) do
            if not new_dict[key] then key_remove(key) end
        end
    end

    return new_dict
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
glib.handle_open_minimap_entity = { [defines.events.on_gui_click] = function(event)
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
function glib.acquire_next_minimap(grid_table, grid_children, old_length, new_length)
    if new_length > old_length then
        local outer_frame = grid_table.add({ type = "frame", style = "sspp_thin_shallow_frame" })
        local inner_frame = outer_frame.add({ type = "frame", style = "deep_frame_in_shallow_frame" })
        local minimap = inner_frame.add({ type = "minimap", style = "sspp_minimap", zoom = 1.0 })

        minimap.add({ type = "button", style = "sspp_minimap_button", tags = flib_gui.format_handlers(glib.handle_open_minimap_entity) })
        local top = minimap.add({ type = "label", style = "sspp_minimap_top_label", ignored_by_interaction = true })
        local bottom = minimap.add({ type = "label", style = "sspp_minimap_bottom_label", ignored_by_interaction = true })

        return minimap, top, bottom
    end

    local minimap = grid_children[new_length].children[1].children[1]
    local minimap_children = minimap.children

    return minimap, minimap_children[2], minimap_children[3]
end

--------------------------------------------------------------------------------

function glib.add_flib_handlers()
    flib_gui.add_handlers({
        ["lib_open_minimap_entity"] = glib.handle_open_minimap_entity[defines.events.on_gui_click],
    })
end

--------------------------------------------------------------------------------

return glib
