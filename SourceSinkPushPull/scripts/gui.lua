-- SSPP by jagoly

local flib_gui = require("__flib__.gui")

gui = {}

require("gui.network")
require("gui.station")
require("gui.hauler")

--------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
local function on_gui_opened(event)
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity ---@type LuaEntity
        local name = entity.name
        if name == "entity-ghost" then name = entity.ghost_name end
        -- if name == "sspp-stop" or name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        if name == "sspp-stop" then
            gui.station_open(event.player_index, entity)
        elseif entity.type == "locomotive" then
            gui.hauler_opened(event.player_index, entity.train.id)
        end
    end
end

---@param event EventData.on_gui_closed
local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.custom then
        if event.element.name == "sspp-network" then
            gui.network_closed(event.player_index, event.element)
        elseif event.element.name == "sspp-station" then
            gui.station_closed(event.player_index, event.element)
        end
    elseif event.gui_type == defines.gui_type.entity then
        if event.entity.type == "locomotive" then
            gui.hauler_closed(event.player_index)
        end
    end
end

function gui.on_poll_finished()
    for _, player_state in pairs(storage.player_states) do
        if player_state.elements["sspp-network"] then
            gui.network_poll_finished(player_state)
        elseif player_state.elements["sspp-station"] then
            gui.station_poll_finished(player_state)
        end
    end
end

--------------------------------------------------------------------------------

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

---@param from_nothing boolean
---@param table LuaGuiElement
---@param dict {[string]: any}
---@param inner fun(from_nothing: boolean, table: LuaGuiElement, dict: {[string]: any}, key: string, i: integer)
function gui.populate_table_from_dict(from_nothing, table, dict, inner)
    local keys = {}
    for key, entry in pairs(dict) do keys[entry.list_index] = key end
    assert(#keys == table_size(dict))

    local columns = table.column_count

    if from_nothing then
        local table_children = table.children
        for i = #table_children, columns + 1, -1 do table_children[i].destroy() end
    end

    for list_index = 1, #keys do
        local i = list_index * columns
        local key = keys[list_index]

        inner(from_nothing, table, dict, key, i)
    end
end

---@param table LuaGuiElement
---@param inner fun(table_children: LuaGuiElement[], list_index: integer, i: integer): key: string, value: any
---@return {[string]: any}
function gui.generate_dict_from_table(table, inner)
    local columns = table.column_count
    local table_children = table.children

    local dict = {}
    local list_index = 0

    for i = columns, #table_children - 1, columns do
        local key, value = inner(table_children, list_index + 1, i)
        if key then
            list_index = list_index + 1
            dict[key] = value
        end
    end

    return dict
end

---@param hauler_id HaulerId
---@param enabled boolean
function gui.hauler_set_widget_enabled(hauler_id, enabled)
    for _, player_state in pairs(storage.player_states) do
        if player_state.train and player_state.train.id == hauler_id then
            player_state.elements.class_textbox.enabled = enabled
        end
    end
end

--------------------------------------------------------------------------------

function gui.register_event_handlers()
    gui.network_add_flib_handlers()
    gui.station_add_flib_handlers()
    gui.hauler_add_flib_handlers()

    script.on_event(defines.events.on_gui_opened, on_gui_opened)
    script.on_event(defines.events.on_gui_closed, on_gui_closed)

    flib_gui.handle_events()
end
