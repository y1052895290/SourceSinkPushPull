-- SSPP by jagoly

---@meta

--------------------------------------------------------------------------------

---@alias GuiStyleMods LuaStyle|{[string]: nil}
---@alias GuiElemMods LuaGuiElement|{[string]: nil}
---@alias GuiElementDef LuaGuiElement.add_param|LuaGuiElement.add_param.extra

---@class (exact) GuiHandler
---@field public [defines.events.on_gui_checked_state_changed] fun(event: EventData.on_gui_checked_state_changed)?
---@field public [defines.events.on_gui_click] fun(event: EventData.on_gui_click)?
---@field public [defines.events.on_gui_closed] fun(event: EventData.on_gui_closed)?
---@field public [defines.events.on_gui_confirmed] fun(event: EventData.on_gui_confirmed)?
---@field public [defines.events.on_gui_elem_changed] fun(event: EventData.on_gui_elem_changed)?
---@field public [defines.events.on_gui_location_changed] fun(event: EventData.on_gui_location_changed)?
---@field public [defines.events.on_gui_opened] fun(event: EventData.on_gui_opened)?
---@field public [defines.events.on_gui_selected_tab_changed] fun(event: EventData.on_gui_selected_tab_changed)?
---@field public [defines.events.on_gui_selection_state_changed] fun(event: EventData.on_gui_selection_state_changed)?
---@field public [defines.events.on_gui_switch_state_changed] fun(event: EventData.on_gui_switch_state_changed)?
---@field public [defines.events.on_gui_text_changed] fun(event: EventData.on_gui_text_changed)?
---@field public [defines.events.on_gui_value_changed] fun(event: EventData.on_gui_value_changed)?

---@class (exact) LuaGuiElement.add_param.extra
---@field public drag_target string?
---@field public elem_mods GuiElemMods?
---@field public style_mods GuiStyleMods?
---@field public handler string?
---@field public children GuiElementDef[]?

--------------------------------------------------------------------------------

---@class GuiTableMethods
GuiTableMethods = {}

--- Called whenever a new row needs to be inserted, then initialised with default values.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param row_offset integer?
---@param args AnyBasic?
---@return LuaGuiElement[] cells
function GuiTableMethods.insert_row_blank(context, row_offset, args) end

--- Called whenever a new row needs to be inserted, then initialised with values from an object.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param row_offset integer?
---@param key Key
---@param object Object
---@return LuaGuiElement[] cells
function GuiTableMethods.insert_row_complete(context, row_offset, key, object) end

--- Called whenever a new row needs to be inserted, then initialised with values from another row.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param row_offset integer?
---@param src_cells LuaGuiElement[]
---@return LuaGuiElement[] cells
function GuiTableMethods.insert_row_copy(context, row_offset, src_cells) end

--- Called whenever a row needs to be converted to a key and an object.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param cells LuaGuiElement[]
---@return Key? key, Object? object
function GuiTableMethods.make_object(context, cells) end

--- Called whenever an object needs to be checked against filters.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param key Key
---@param object Object
---@return boolean match
function GuiTableMethods.filter_object(context, key, object) end

--- Called whenever some part of the row has been or should be updated.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param cells LuaGuiElement[]
---@param key Key?
---@param object Object?
function GuiTableMethods.on_row_changed(context, cells, key, object) end

--- Called whenever an object with a unique key is created, modified, or destroyed.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
---@param key Key
---@param object Object?
function GuiTableMethods.on_object_changed(context, key, object) end

--- Called after one or more objects have been changed.
---@generic Root, Key, Object
---@param context GuiTableContext<Root, Key, Object>
function GuiTableMethods.on_mutation_finished(context) end
