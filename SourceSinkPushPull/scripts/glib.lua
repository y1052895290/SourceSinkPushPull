-- SSPP by jagoly

local glib = {}

local t_insert, t_remove = table.insert, table.remove

--------------------------------------------------------------------------------

---@type {[string]: GuiHandler}
local handlers = {}

glib.handlers = handlers

local function on_element_event(event)
    local name = event.element.tags["__SourceSinkPushPull_handler"]
    if name then
        local handler = handlers[name]
        if handler then
            local func = handler[event.name]
            if func then
                func(event)
            end
        end
    end
end

--------------------------------------------------------------------------------

---@param handler string
---@param tags Tags?
---@return Tags
local function format_handler(handler, tags)
    assert(handlers[handler])

    tags = tags or {}
    tags["__SourceSinkPushPull_handler"] = handler

    return tags
end
glib.format_handler = format_handler

---@param parent LuaGuiElement
---@param named_elements {[string]: LuaGuiElement}?
---@param def GuiElementDef
---@return LuaGuiElement element, {[string]: LuaGuiElement}? named_elements
local function add_element(parent, named_elements, def)
    local drag_target = def.drag_target
    local elem_mods = def.elem_mods
    local style_mods = def.style_mods
    local handler = def.handler
    local children = def.children

    def.drag_target = nil
    def.elem_mods = nil
    def.style_mods = nil
    def.handler = nil
    def.children = nil

    ---@cast def -LuaGuiElement.add_param.extra

    local element = parent.add(def)

    if named_elements then
        local name = def.name
        if name then
            named_elements[name] = element
        end
        if drag_target then
            element.drag_target = assert(named_elements[drag_target])
        end
    end
    if elem_mods then
        for key, value in pairs(elem_mods) do
            element[key] = value
        end
    end
    if style_mods then
        for key, value in pairs(style_mods) do
            element.style[key] = value
        end
    end
    if handler then
        element.tags = format_handler(handler, element.tags)
    end
    if children then
        if def.type == "tab" then
            local content = add_element(parent, named_elements, children[1])
            parent.add_tab(element, content)
        else
            for _, child in pairs(children) do
                add_element(element, named_elements, child)
            end
        end
    end

    ---@cast def +LuaGuiElement.add_param.extra

    def.drag_target = drag_target
    def.elem_mods = elem_mods
    def.style_mods = style_mods
    def.handler = handler
    def.children = children

    return element, named_elements
end
glib.add_element = add_element

---@param parent LuaGuiElement
---@param named_elements {[string]: LuaGuiElement}?
---@param offset integer?
---@param defs GuiElementDef[]
---@return LuaGuiElement[] elements, {[string]: LuaGuiElement}? named_elements
function glib.add_elements(parent, named_elements, offset, defs)
    local elements = {}

    for index, def in pairs(defs) do
        if offset then
            def.index = offset + index
        end
        elements[index] = add_element(parent, named_elements, def)
        if offset then
            def.index = nil
        end
    end

    return elements, named_elements
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

---@param table LuaGuiElement
---@param child LuaGuiElement
---@return integer row
local function get_row_for_child(table, child)
    repeat
        local parent = child.parent
        if parent == table then break end
        child = parent --[[@as LuaGuiElement]]
    until false

    return math.ceil((child.get_index_in_parent()) / table.column_count)
end
glib.get_row_for_child = get_row_for_child

--------------------------------------------------------------------------------

---@generic Key
---@param row_to_key (Key|false)[]
---@param key Key
---@return integer? row
local function find_row_for_key(row_to_key, key)
    for row, other_key in pairs(row_to_key) do
        if other_key == key then
            return row
        end
    end
    return nil
end

---@generic Key
---@param key_to_row {[Key]: integer}
---@param row integer
---@param key Key|false
---@param insert true?
---@return {[Key]: integer} key_to_row
local function assign_key_to_row(key_to_row, row, key, insert)
    local key_to_row_new = {}

    for k1, r1 in next, key_to_row do
        if r1 < row then
            key_to_row_new[k1] = r1
        else
            if key then
                key_to_row_new[key] = row
            end
            if insert then
                key_to_row_new[k1] = r1 + 1
                for k2, r2 in next, key_to_row, k1 do
                    key_to_row_new[k2] = r2 + 1
                end
            else
                key_to_row_new[k1] = r1
                for k2, r2 in next, key_to_row, k1 do
                    key_to_row_new[k2] = r2
                end
            end
            return key_to_row_new
        end
    end

    if key then
        key_to_row_new[key] = row
    end

    return key_to_row_new
end

---@generic Key, Object
---@param key_to_row {[Key]: integer}
---@param key_to_object {[Key]: Object}
---@param key Key
---@param object Object
---@return {[Key]: Object} key_to_object
local function assign_key_to_object(key_to_row, key_to_object, key, object)
    local key_to_object_new = {}

    for k, _ in pairs(key_to_row) do
        if k == key then
            key_to_object_new[k] = object
        else
            key_to_object_new[k] = key_to_object[k]
        end
    end

    return key_to_object_new
end

---@generic Key
---@param row_to_cells LuaGuiElement[][]
---@param row_to_key (Key|false)[]
---@param key_to_row {[Key]: integer}
---@param row integer?
---@param key Key|false
---@param cells LuaGuiElement[]
---@return {[Key]: integer} key_to_row
local function insert_row(row_to_cells, row_to_key, key_to_row, row, key, cells)
    if row then
        t_insert(row_to_cells, row, cells)
        t_insert(row_to_key, row, key)

        return assign_key_to_row(key_to_row, row, key, true)
    else
        row = #row_to_cells + 1

        row_to_cells[row] = cells
        row_to_key[row] = key

        if key then
            key_to_row[key] = row
        end

        return key_to_row
    end
end

---@generic Key
---@param row_to_cells LuaGuiElement[][]
---@param row_to_key (Key|false)[]
---@param key_to_row {[Key]: integer}
---@param row integer
local function remove_row(row_to_cells, row_to_key, key_to_row, row)
    local cells = row_to_cells[row]

    t_remove(row_to_cells, row)
    t_remove(row_to_key, row)

    for k, r in pairs(key_to_row) do
        if r > row then
            key_to_row[k] = r - 1
        end
    end

    for _, cell in pairs(cells) do
        cell.destroy()
    end
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param row integer?
---@param args AnyBasic?
function glib.table_insert_blank_mutable_row(methods, context, row, args)
    local row_to_cells, row_to_key = context.row_to_cells, context.row_to_key

    local row_offset = row and (row - 1) * context.table.column_count
    local cells = methods.insert_row_blank(context, row_offset, args)

    context.key_to_row = insert_row(row_to_cells, row_to_key, context.key_to_row, row, false, cells)
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param row integer?
---@param key Key
---@param object Object
function glib.table_insert_complete_row(methods, context, row, key, object)
    local row_to_cells, row_to_key = context.row_to_cells, context.row_to_key

    local row_offset = row and (row - 1) * context.table.column_count
    local cells = methods.insert_row_complete(context, row_offset, key, object)

    context.key_to_row = insert_row(row_to_cells, row_to_key, context.key_to_row, row, key, cells)
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param child LuaGuiElement
function glib.table_copy_mutable_row(methods, context, child)
    local row_to_cells, row_to_key = context.row_to_cells, context.row_to_key

    local src_row = get_row_for_child(context.table, child)
    local src_cells = row_to_cells[src_row]

    local row = src_row + 1
    local row_offset = src_row * context.table.column_count
    local cells = methods.insert_row_copy(context, row_offset, src_cells)

    context.key_to_row = insert_row(row_to_cells, row_to_key, context.key_to_row, row, false, cells)
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param key Key
function glib.table_remove_immutable_row(methods, context, key)
    local key_to_row = context.key_to_row
    local row = key_to_row[key]

    key_to_row[key] = nil

    remove_row(context.row_to_cells, context.row_to_key, key_to_row, row)
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param child LuaGuiElement
function glib.table_remove_mutable_row(methods, context, child)
    local row_to_cells, row_to_key = context.row_to_cells, context.row_to_key

    local row = get_row_for_child(context.table, child)
    local old_key = row_to_key[row]

    if old_key and context.key_to_row[old_key] == row then
        row_to_key[row] = false

        local other_row = find_row_for_key(row_to_key, old_key)
        if other_row then
            local other_cells = row_to_cells[other_row]
            local other_key, other_object = methods.make_object(context, other_cells)
            assert(other_key == old_key)

            methods.on_row_changed(context, other_cells, other_key, other_object)
            context.key_to_row = assign_key_to_row(context.key_to_row, other_row, other_key)
            methods.on_object_changed(context, other_key, other_object)
            context.key_to_object = assign_key_to_object(context.key_to_row, context.key_to_object, other_key, other_object)
        else
            context.key_to_row[old_key] = nil
            methods.on_object_changed(context, old_key, nil)
            context.key_to_object[old_key] = nil
        end
    end

    remove_row(row_to_cells, row_to_key, context.key_to_row, row)

    methods.on_mutation_finished(context)
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param key Key
function glib.table_modify_immutable_row(methods, context, key)
    local row = context.key_to_row[key]

    methods.on_row_changed(context, context.row_to_cells[row], key, context.key_to_object[key])
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param child LuaGuiElement
function glib.table_modify_mutable_row(methods, context, child)
    local row_to_cells, row_to_key = context.row_to_cells, context.row_to_key

    local row = get_row_for_child(context.table, child)
    local cells, old_key = row_to_cells[row], row_to_key[row]

    local new_key, new_object = methods.make_object(context, cells)

    row_to_key[row] = new_key

    old_key = old_key and context.key_to_row[old_key] == row and old_key or nil
    new_key = new_key and (context.key_to_row[new_key] or row) == row and new_key or nil

    if old_key and old_key ~= new_key then
        local other_row = find_row_for_key(row_to_key, old_key)
        if other_row then
            local other_cells = row_to_cells[other_row]
            local other_key, other_object = methods.make_object(context, other_cells)
            assert(other_key == old_key)

            methods.on_row_changed(context, other_cells, other_key, other_object)
            context.key_to_row = assign_key_to_row(context.key_to_row, other_row, other_key)
            methods.on_object_changed(context, other_key, other_object)
            context.key_to_object = assign_key_to_object(context.key_to_row, context.key_to_object, other_key, other_object)
        else
            context.key_to_row[old_key] = nil
            methods.on_object_changed(context, old_key, nil)
            context.key_to_object[old_key] = nil
        end
    end

    if new_key then
        if old_key ~= new_key then
            methods.on_row_changed(context, cells, new_key, new_object)
            context.key_to_row = assign_key_to_row(context.key_to_row, row, new_key)
            methods.on_object_changed(context, new_key, new_object)
            context.key_to_object = assign_key_to_object(context.key_to_row, context.key_to_object, new_key, new_object)
        else
            methods.on_row_changed(context, cells, new_key, new_object)
            methods.on_object_changed(context, new_key, new_object)
            context.key_to_object[new_key] = new_object
        end
    else
        methods.on_row_changed(context, cells, nil, nil)
    end

    methods.on_mutation_finished(context)
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param button LuaGuiElement
function glib.table_move_mutable_row(methods, context, button)
    local table = context.table
    local direction = (button.get_index_in_parent() * 2 - 3)

    local src_row = get_row_for_child(table, button)
    local dst_row = src_row + direction

    local dst_cells = context.row_to_cells[dst_row]
    if dst_cells then
        local src_cells = context.row_to_cells[src_row]

        local column_count = table.column_count
        for c = 1, column_count do
            src_cells[c], dst_cells[c] = dst_cells[c], src_cells[c]
            table.swap_children((src_row - 1) * column_count + c, (dst_row - 1) * column_count + c)
        end

        local row_to_key, key_to_row = context.row_to_key, context.key_to_row

        local src_key = row_to_key[src_row]
        local dst_key = row_to_key[dst_row]

        local src_has_object = src_key and (key_to_row[src_key] == src_row)
        local dst_has_object = dst_key and (key_to_row[dst_key] == dst_row)

        if src_has_object or dst_has_object then
            row_to_key[src_row] = dst_key
            row_to_key[dst_row] = src_key

            if src_has_object then --[[@cast src_key -false]] key_to_row[src_key] = dst_row end
            if dst_has_object then --[[@cast dst_key -false]] key_to_row[dst_key] = src_row end

            local key_to_row_new = {}

            for r, k in pairs(row_to_key) do
                if k and r == key_to_row[k] then
                    key_to_row_new[k] = r
                end
            end

            context.key_to_row = key_to_row_new

            if src_has_object and dst_has_object then
                local key_to_object = context.key_to_object
                local key_to_object_new = {}

                for k, _ in pairs(key_to_row_new) do
                    key_to_object_new[k] = key_to_object[k]
                end

                context.key_to_object = key_to_object_new
            end

            methods.on_mutation_finished(context)
        end
    end
end

---@generic Base, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Base, Key, Object>
---@param reversed boolean
function glib.table_populate_from_objects(methods, context, reversed)
    local row_to_cells, row_to_key, key_to_row, key_to_object = context.row_to_cells, context.row_to_key, context.key_to_row, context.key_to_object

    local insert_row_complete = methods.insert_row_complete

    if reversed then
        local length, key_list = 0, {}

        for key, _ in pairs(key_to_object) do
            length = length + 1
            key_list[length] = key
        end

        for i = length, 1, -1 do
            local key, row = key_list[i], length - i + 1
            row_to_cells[row] = insert_row_complete(context, nil, key, key_to_object[key])
            row_to_key[row] = key
            key_to_row[key] = row
        end
    else
        local row = 0

        for key, object in pairs(context.key_to_object) do
            row = row + 1
            row_to_cells[row] = insert_row_complete(context, nil, key, object)
            row_to_key[row] = key
            key_to_row[key] = row
        end
    end
end

--------------------------------------------------------------------------------

glib.handlers["lib_open_parent_entity"] = { [defines.events.on_gui_click] = function(event)
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

        minimap.add({ type = "button", style = "sspp_minimap_button", tags = format_handler("lib_open_parent_entity") })
        local top = minimap.add({ type = "label", style = "sspp_minimap_top_label", ignored_by_interaction = true })
        local bottom = minimap.add({ type = "label", style = "sspp_minimap_bottom_label", ignored_by_interaction = true })

        return minimap, top, bottom
    end

    local minimap = grid_children[new_length].children[1].children[1]
    local minimap_children = minimap.children

    return minimap, minimap_children[2], minimap_children[3]
end

--------------------------------------------------------------------------------

function glib.register_event_handlers()
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
end

--------------------------------------------------------------------------------

return glib
