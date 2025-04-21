-- SSPP by jagoly

local glib = {}

--------------------------------------------------------------------------------

local handler_name_to_func = {} ---@type {[string]: function}
local handler_func_to_name = {} ---@type {[function]: string}

local function on_element_event(event)
    local handler = event.element.tags["__SourceSinkPushPull_handler"]
    if handler then
        local name = handler[tostring(event.name)]
        if name then
            local func = handler_name_to_func[name]
            if func then
                func(event)
            end
        end
    end
end

--------------------------------------------------------------------------------

---@param handler GuiHandler
---@param tags Tags?
---@return Tags
local function format_handler(handler, tags)
    local formatted = {}
    for id, func in pairs(handler) do
        formatted[tostring(id)] = handler_func_to_name[func]
    end

    tags = tags or {}
    tags["__SourceSinkPushPull_handler"] = formatted

    return tags
end
glib.format_handler = format_handler

---@param parent LuaGuiElement
---@param elems {[string]: LuaGuiElement}?
---@param def GuiElemDef
---@return LuaGuiElement elem, {[string]: LuaGuiElement}? elems
local function add_widget(parent, elems, def)
    local elem_mods = def.elem_mods
    local style_mods = def.style_mods
    local drag_target = def.drag_target
    local handler = def.handler
    local children = def.children

    def.elem_mods = nil
    def.style_mods = nil
    def.drag_target = nil
    def.handler = nil
    def.children = nil

    local elem = parent.add(def)

    if elems then
        local name = def.name
        if name then elems[name] = elem end
    end
    if elem_mods then
        for key, value in pairs(elem_mods) do
            elem[key] = value
        end
    end
    if style_mods then
        for key, value in pairs(style_mods) do
            elem.style[key] = value
        end
    end
    if drag_target then
        ---@cast elems -nil
        elem.drag_target = assert(elems[drag_target])
    end
    if handler then
        elem.tags = format_handler(handler, elem.tags)
    end
    if children then
        if def.type == "tab" then
            local content = add_widget(parent, elems, children[1])
            parent.add_tab(elem, content)
        else
            for _, child in pairs(children) do
                add_widget(elem, elems, child)
            end
        end
    end

    def.elem_mods = elem_mods
    def.style_mods = style_mods
    def.drag_target = drag_target
    def.handler = handler
    def.children = children

    return elem, elems
end
glib.add_widget = add_widget

---@param parent LuaGuiElement
---@param elems {[string]: LuaGuiElement}?
---@param defs GuiElemDef[]
---@return {[string]: LuaGuiElement}? elems
function glib.add_widgets(parent, elems, defs)
    for _, def in pairs(defs) do
        add_widget(parent, elems, def)
    end

    return elems
end

---@param functions {[string]: function}
function glib.register_functions(functions)
    for name, func in pairs(functions) do
        assert(handler_name_to_func[name] == nil)
        handler_name_to_func[name] = func
        handler_func_to_name[func] = name
    end
end

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

---@type GuiHandler
glib.handle_open_parent_entity = { [defines.events.on_gui_click] = function(event)
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

        minimap.add({ type = "button", style = "sspp_minimap_button", tags = format_handler(glib.handle_open_parent_entity) })
        local top = minimap.add({ type = "label", style = "sspp_minimap_top_label", ignored_by_interaction = true })
        local bottom = minimap.add({ type = "label", style = "sspp_minimap_bottom_label", ignored_by_interaction = true })

        return minimap, top, bottom
    end

    local minimap = grid_children[new_length].children[1].children[1]
    local minimap_children = minimap.children

    return minimap, minimap_children[2], minimap_children[3]
end

--------------------------------------------------------------------------------

function glib.initialise()
    script.on_event(defines.events.on_gui_checked_state_changed, on_element_event)
    script.on_event(defines.events.on_gui_click, on_element_event)
    script.on_event(defines.events.on_gui_confirmed, on_element_event)
    script.on_event(defines.events.on_gui_elem_changed, on_element_event)
    script.on_event(defines.events.on_gui_hover, on_element_event)
    script.on_event(defines.events.on_gui_leave, on_element_event)
    script.on_event(defines.events.on_gui_location_changed, on_element_event)
    script.on_event(defines.events.on_gui_selected_tab_changed, on_element_event)
    script.on_event(defines.events.on_gui_selection_state_changed, on_element_event)
    script.on_event(defines.events.on_gui_switch_state_changed, on_element_event)
    script.on_event(defines.events.on_gui_text_changed, on_element_event)
    script.on_event(defines.events.on_gui_value_changed, on_element_event)

    glib.register_functions({
        ["lib_open_parent_entity"] = glib.handle_open_parent_entity[defines.events.on_gui_click],
    })
end

--------------------------------------------------------------------------------

return glib
