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
---@field public handler GuiHandler?
---@field public children GuiElementDef[]?
