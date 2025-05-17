-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")

---@class sspp.glib
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

--------------------------------------------------------------------------------

---@param table LuaGuiElement
---@param child LuaGuiElement
---@return integer offset
local function get_offset_for_child(table, child)
    repeat
        local parent = child.parent
        if parent == table then break end
        child = parent --[[@as LuaGuiElement]]
    until false

    local columns = table.column_count
    local actual_row = math.ceil((child.get_index_in_parent()) / columns)

    return (actual_row - 1) * columns
end

---@param table LuaGuiElement
---@param rows { cells: any }[]
---@param offset integer
---@param reverse boolean
---@return integer index
local function get_index_for_offset(table, rows, offset, reverse)
    local columns = table.column_count

    local first, last, increment
    if reverse then
        first, last, increment = #rows, 1, -1
    else
        first, last, increment = 1, #rows, 1
    end

    for index = first, last, increment do
        local row = rows[index]
        if row.cells then
            if offset == 0 then return index end
            offset = offset - columns
        end
    end

    error()
end

---@param table LuaGuiElement
---@param rows { cells: any }[]
---@param child LuaGuiElement
---@return integer row
local function get_index_for_child(table, rows, child, reverse)
    return get_index_for_offset(table, rows, get_offset_for_child(table, child), reverse)
end

---@generic Key
---@param rows { key: Key? }[]
---@param key Key
---@return integer? index
local function find_index_for_key(rows, key)
    for index, row in pairs(rows) do
        if row.key == key then
            return index
        end
    end
end

---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param key Key?
---@param index integer
---@param insert true?
local function assign_index_for_key(context, key, index, insert)
    local indices, indices_new = context.indices, {}

    for k1, i1 in next, indices do
        if i1 < index then
            indices_new[k1] = i1
        else
            if key then
                indices_new[key] = index
            end
            if insert then
                indices_new[k1] = i1 + 1
                for k2, i2 in next, indices, k1 do
                    indices_new[k2] = i2 + 1
                end
            else
                if k1 ~= key then
                    indices_new[k1] = i1
                end
                for k2, i2 in next, indices, k1 do
                    if k2 ~= key then
                        indices_new[k2] = i2
                    end
                end
            end
            goto skip_assign
        end
    end

    if key then
        indices_new[key] = index
    end

    ::skip_assign::
    context.indices = indices_new
end

---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param key Key
---@param object Object
local function assign_object_for_key(context, key, object)
    local objects, objects_new = context.objects, {}

    for k, _ in pairs(context.indices) do
        if k ~= key then
            objects_new[k] = objects[k]
        else
            objects_new[k] = object
        end
    end

    context.objects = objects_new
end

---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param index integer?
---@param key Key?
local function insert_row(context, index, key)
    local rows, row = context.rows, { key = key }

    if index then
        t_insert(rows, index, row)
        assign_index_for_key(context, key, index, true)
    else
        index = #rows + 1
        rows[index] = row

        if key then
            local indices = context.indices
            indices[key] = index
            context.indices = indices
        end
    end

    return row
end

---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param index integer
---@return LuaGuiElement[]? cells
local function remove_row(context, index)
    local rows, indices = context.rows, context.indices
    local cells = rows[index].cells

    t_remove(rows, index)

    for k, i in pairs(indices) do
        if i > index then
            indices[k] = i - 1
        end
    end

    return cells
end

--------------------------------------------------------------------------------

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param child LuaGuiElement
---@return Key? key
function glib.table_get_key_for_child(methods, context, child)
    local table, rows = context.table, context.rows
    local index = get_index_for_offset(table, rows, get_offset_for_child(table, child), context.reverse)
    local row = rows[index]
    if row.match then return row.key end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param args AnyBasic?
function glib.table_append_blank_row(methods, context, args)
    local row = insert_row(context, nil, nil)

    row.cells = methods.insert_row_blank(context, nil, args)
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param key Key
---@param object Object
function glib.table_append_immutable_row(methods, context, key, object)
    local row = insert_row(context, nil, key)
    local match = methods.filter_object(context, key, object)

    row.match = match

    if match then
        glib.table_apply_filter(methods, context)
    end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param child LuaGuiElement
function glib.table_copy_row(methods, context, child)
    local table, rows = context.table, context.rows

    local src_offset = get_offset_for_child(table, child)
    local src_index = get_index_for_offset(table, rows, src_offset, false)
    local src_cells = rows[src_index].cells ---@cast src_cells -nil

    local offset, index = src_offset + table.column_count, src_index + 1
    local row = insert_row(context, index, nil)

    row.cells = methods.insert_row_copy(context, offset, src_cells)
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param key Key
function glib.table_remove_immutable_row(methods, context, key)
    local indices = context.indices
    local index = indices[key]

    indices[key] = nil

    local cells = remove_row(context, index)

    if cells then
        for _, cell in pairs(cells) do cell.destroy() end

        -- can unhide another row if below the row limit
        glib.table_apply_filter(methods, context)
    end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param child LuaGuiElement
function glib.table_remove_mutable_row(methods, context, child)
    local index = get_index_for_child(context.table, context.rows, child)
    local row = context.rows[index]
    local key = row.key

    if key then
        if context.indices[key] ~= index then key = nil end
        row.key = nil
    end

    local need_apply_filter = false

    if key then
        local other_index = find_index_for_key(context.rows, key)
        if other_index then
            -- invalid rows are never hidden
            local other_row = context.rows[other_index] ---@cast other_row -nil
            local other_cells = other_row.cells ---@cast other_cells -nil

            local other_key, other_object = methods.make_object(context, other_cells)
            assert(other_key == key)

            methods.on_row_changed(context, other_cells, other_key, other_object)
            assign_index_for_key(context, other_key, other_index)
            methods.on_object_changed(context, other_key, other_object)
            assign_object_for_key(context, other_key, other_object)

            local other_match = methods.filter_object(context, other_key, other_object)
            other_row.match = other_match
            if not other_match then need_apply_filter = true end
        else
            context.indices[key] = nil
            methods.on_object_changed(context, key, nil)
            context.objects[key] = nil
        end
    end

    -- mutable rows must not be hidden to be removed
    local cells = remove_row(context, index) ---@cast cells -nil

    for _, cell in pairs(cells) do cell.destroy() end

    if key then
        if need_apply_filter then
            glib.table_apply_filter(methods, context)
        end

        methods.on_mutation_finished(context)
    end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param key Key
function glib.table_modify_immutable_row(methods, context, key)
    local index = context.indices[key]
    local object = context.objects[key]
    local row = context.rows[index]

    local match = methods.filter_object(context, key, object)

    if row.match ~= match then
        row.match = match
        glib.table_apply_filter(methods, context)
    else
        local cells = row.cells
        if cells then
            methods.on_row_changed(context, cells, key, object)
        end
    end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param child LuaGuiElement
function glib.table_modify_mutable_row(methods, context, child)
    local index = get_index_for_child(context.table, context.rows, child)
    local row = context.rows[index]
    local old_key = row.key

    -- mutable rows must not be hidden to be modified
    local cells = row.cells ---@cast cells -nil

    local new_key, new_object = methods.make_object(context, cells)

    row.key = new_key

    if old_key and context.indices[old_key] ~= index then old_key = nil end
    if new_key and (context.indices[new_key] or index) ~= index then new_key = nil end

    local need_apply_filter = false

    if old_key and old_key ~= new_key then
        local other_index = find_index_for_key(context.rows, old_key)
        if other_index then
            -- invalid rows are never hidden
            local other_row = context.rows[other_index] ---@cast other_row -nil
            local other_cells = other_row.cells ---@cast other_cells -nil

            local other_key, other_object = methods.make_object(context, other_cells)
            assert(other_key == old_key)

            methods.on_row_changed(context, other_cells, other_key, other_object)
            assign_index_for_key(context, other_key, other_index)
            methods.on_object_changed(context, other_key, other_object)
            assign_object_for_key(context, other_key, other_object)

            local other_match = methods.filter_object(context, other_key, other_object)
            other_row.match = other_match
            if not other_match then need_apply_filter = true end
        else
            context.indices[old_key] = nil
            methods.on_object_changed(context, old_key, nil)
            context.objects[old_key] = nil
        end
    end

    if new_key then
        methods.on_row_changed(context, cells, new_key, new_object)

        if old_key ~= new_key then
            methods.on_row_changed(context, cells, new_key, new_object)
            assign_index_for_key(context, new_key, index)
            methods.on_object_changed(context, new_key, new_object)
            assign_object_for_key(context, new_key, new_object)
        else
            methods.on_row_changed(context, cells, new_key, new_object)
            methods.on_object_changed(context, new_key, new_object)
            context.objects[new_key] = new_object
        end

        local match = methods.filter_object(context, new_key, new_object)
        row.match = match
        if not match then need_apply_filter = true end
    else
        methods.on_row_changed(context, cells, nil, nil)
        row.match = nil
    end

    if need_apply_filter then
        glib.table_apply_filter(methods, context)
    end

    methods.on_mutation_finished(context)
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param button LuaGuiElement
function glib.table_move_row(methods, context, button)
    local table, rows = context.table, context.rows

    local src_offset = get_offset_for_child(table, button)
    local src_index = get_index_for_offset(table, rows, src_offset, false)
    local direction = button.get_index_in_parent() * 2 - 3
    local dst_index = src_index + direction

    if dst_index >= 1 and dst_index <= #rows then
        local src_row = rows[src_index]
        local dst_row = rows[dst_index]

        local src_key = src_row.match ~= nil and src_row.key
        local dst_key = dst_row.match ~= nil and dst_row.key

        local dst_cells = dst_row.cells

        rows[src_index] = dst_row
        rows[dst_index] = src_row

        if dst_cells then
            local dst_offset = src_offset + direction * table.column_count
            for c = 1, table.column_count do
                table.swap_children(src_offset + c, dst_offset + c)
            end
        end

        if src_key or dst_key then
            local indices = context.indices

            if src_key then indices[src_key] = dst_index end
            if dst_key then indices[dst_key] = src_index end

            local indices_new = {}
            for index, row in pairs(rows) do
                local key = row.key
                if key and row.match ~= nil then indices_new[key] = index end
            end
            context.indices = indices_new

            if src_key and dst_key then
                local objects = context.objects
                local objects_new = {}
                for k, _ in pairs(indices_new) do objects_new[k] = objects[k] end
                context.objects = objects_new
            end

            methods.on_mutation_finished(context)
        end
    end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
---@param objects {[Key]: Object}
---@param reverse true?
---@param row_limit integer?
function glib.table_initialise(methods, context, objects, reverse, row_limit)
    local filter_object = methods.filter_object

    local rows, indices = {}, {}

    context.rows = rows
    context.indices = indices
    context.objects = objects
    context.reverse = reverse
    context.row_limit = row_limit

    local index = 0

    for key, object in pairs(objects) do
        index = index + 1
        rows[index] = { key = key, match = filter_object(context, key, object) }
        indices[key] = index
    end

    context.table.clear()

    glib.table_apply_filter(methods, context)
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
function glib.table_update_matches(methods, context)
    local indices, objects = context.indices, context.objects

    local filter_object = methods.filter_object

    for index, row in pairs(context.rows) do
        local key = row.key
        if key and indices[key] == index then
            row.match = filter_object(context, key, objects[key])
        end
    end
end

---@generic Root, Key, Object
---@param methods GuiTableMethods
---@param context GuiTableContext<Root, Key, Object>
function glib.table_apply_filter(methods, context)
    local rows, objects = context.rows, context.objects

    local columns = context.table.column_count
    local row_count, row_limit = 0, context.row_limit or 10000

    local insert_row_complete = methods.insert_row_complete

    local first, last, increment
    if context.reverse then
        first, last, increment = #rows, 1, -1
    else
        first, last, increment = 1, #rows, 1
    end

    for index = first, last, increment do
        local row = rows[index]
        local match = row.match

        if match ~= nil then
            local cells = row.cells

            if match and row_count < row_limit then
                if not cells then
                    local key = row.key ---@cast key -nil
                    row.cells = insert_row_complete(context, row_count * columns, key, objects[key])
                end
                row_count = row_count + 1
            else
                if cells then
                    for _, cell in pairs(cells) do cell.destroy() end
                    row.cells = nil
                end
            end
        else
            row_count = row_count + 1
        end
    end
end

--------------------------------------------------------------------------------

---@param parent GuiRoot|GuiChild
---@param parent_size int[]
---@param dimmer_handler string
---@param def GuiElementDef
function glib.create_child_window(parent, parent_size, dimmer_handler, def)
    assert(not parent.child)

    local _, parent_window = next(parent.elements) ---@cast parent_window -nil
    local screen = parent_window.gui.screen

    local dimmer = screen.add({type = "frame", style = "sspp_dimmer_frame", tags = format_handler(dimmer_handler)})
    dimmer.style.size = parent_size
    dimmer.location = parent_window.location
    dimmer.bring_to_front()

    local window, elements = add_element(screen, {}, def) ---@cast elements -nil
    window.force_auto_center()
    window.bring_to_front()

    parent.child = { dimmer = dimmer, elements = elements }
end

---@param parent GuiRoot|GuiChild
function glib.destroy_child_window(parent)
    local child = parent.child ---@cast child -nil
    assert(not child.child)

    local _, window = next(child.elements) ---@cast window -nil
    window.destroy()
    child.dimmer.destroy()

    parent.child = nil
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

---@param active_network_name NetworkName
---@param surface LuaSurface?
---@return LocalisedString[] localised_network_names, integer active_network_index
function glib.get_localised_network_names(active_network_name, surface)
    local localised_network_names = {} ---@type LocalisedString[]
    local network_count, network_index = 0, 0

    if surface then
        local network_name = lib.get_network_name_for_surface(surface)
        if network_name then
            network_count = network_count + 1
            if surface.planet then
                localised_network_names[network_count] = surface.planet.prototype.localised_name
            else
                localised_network_names[network_count] = surface.localised_name or network_name
            end
            if network_name == active_network_name then network_index = network_count end
        end
    else
        for network_name, network in pairs(storage.networks) do
            local network_surface = network.surface
            if network_surface then
                network_count = network_count + 1
                if network_surface.planet then
                    localised_network_names[network_count] = network_surface.planet.prototype.localised_name
                else
                    localised_network_names[network_count] = network_surface.localised_name or network_name
                end
                if network_name == active_network_name then network_index = network_count end
            end
        end
    end

    for network_name, network in pairs(storage.networks) do
        if not network.surface then
            network_count = network_count + 1
            localised_network_names[network_count] = network_name
            if network_name == active_network_name then network_index = network_count end
        end
    end

    return localised_network_names, network_index
end

---@param active_network_index integer
---@param surface LuaSurface?
---@return NetworkName network_name
function glib.get_network_name(active_network_index, surface)
    local network_count = 0

    if surface then
        local network_name = lib.get_network_name_for_surface(surface)
        if network_name then
            network_count = network_count + 1
            if network_count == active_network_index then return network_name end
        end
    else
        for network_name, network in pairs(storage.networks) do
            if network.surface then
                network_count = network_count + 1
                if network_count == active_network_index then return network_name end
            end
        end
    end

    for network_name, network in pairs(storage.networks) do
        if not network.surface then
            network_count = network_count + 1
            if network_count == active_network_index then return network_name end
        end
    end

    error()
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
