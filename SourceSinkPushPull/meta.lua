-- SSPP by jagoly

---@meta

--------------------------------------------------------------------------------

---@alias GuiStyleMods LuaStyle|{[string]: nil}
---@alias GuiElemMods LuaGuiElement|{[string]: nil}

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

---@class (exact) GuiElementDef.base
---@field public drag_target string?
---@field public elem_mods GuiElemMods?
---@field public style_mods GuiStyleMods?
---@field public handler string?
---@field public children GuiElementDef[]?

---@class (exact) GuiElementDef.button : GuiElementDef.base, LuaGuiElement.add_param.button
---@class (exact) GuiElementDef.camera : GuiElementDef.base, LuaGuiElement.add_param.camera
---@class (exact) GuiElementDef.checkbox : GuiElementDef.base, LuaGuiElement.add_param.checkbox
---@class (exact) GuiElementDef.choose_elem_button : GuiElementDef.base, LuaGuiElement.add_param.choose_elem_button
---@class (exact) GuiElementDef.drop_down : GuiElementDef.base, LuaGuiElement.add_param.drop_down
---@class (exact) GuiElementDef.flow : GuiElementDef.base, LuaGuiElement.add_param.flow
---@class (exact) GuiElementDef.frame : GuiElementDef.base, LuaGuiElement.add_param.frame
---@class (exact) GuiElementDef.line : GuiElementDef.base, LuaGuiElement.add_param.line
---@class (exact) GuiElementDef.list_box : GuiElementDef.base, LuaGuiElement.add_param.list_box
---@class (exact) GuiElementDef.minimap : GuiElementDef.base, LuaGuiElement.add_param.minimap
---@class (exact) GuiElementDef.progressbar : GuiElementDef.base, LuaGuiElement.add_param.progressbar
---@class (exact) GuiElementDef.radiobutton : GuiElementDef.base, LuaGuiElement.add_param.radiobutton
---@class (exact) GuiElementDef.scroll_pane : GuiElementDef.base, LuaGuiElement.add_param.scroll_pane
---@class (exact) GuiElementDef.slider : GuiElementDef.base, LuaGuiElement.add_param.slider
---@class (exact) GuiElementDef.sprite : GuiElementDef.base, LuaGuiElement.add_param.sprite
---@class (exact) GuiElementDef.sprite_button : GuiElementDef.base, LuaGuiElement.add_param.sprite_button
---@class (exact) GuiElementDef.switch : GuiElementDef.base, LuaGuiElement.add_param.switch
---@class (exact) GuiElementDef.tab : GuiElementDef.base, LuaGuiElement.add_param.tab
---@class (exact) GuiElementDef.table : GuiElementDef.base, LuaGuiElement.add_param.table
---@class (exact) GuiElementDef.text_box : GuiElementDef.base, LuaGuiElement.add_param.text_box
---@class (exact) GuiElementDef.textfield : GuiElementDef.base, LuaGuiElement.add_param.textfield

---@alias GuiElementDef GuiElementDef.button|GuiElementDef.camera|GuiElementDef.checkbox|GuiElementDef.choose_elem_button|GuiElementDef.drop_down|GuiElementDef.flow|GuiElementDef.frame|GuiElementDef.line|GuiElementDef.list_box|GuiElementDef.minimap|GuiElementDef.progressbar|GuiElementDef.radiobutton|GuiElementDef.scroll_pane|GuiElementDef.slider|GuiElementDef.sprite|GuiElementDef.sprite_button|GuiElementDef.switch|GuiElementDef.tab|GuiElementDef.table|GuiElementDef.text_box|GuiElementDef.textfield

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
