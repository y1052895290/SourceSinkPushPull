-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local glib = require("__SourceSinkPushPull__.scripts.glib")

local gui_network = require("__SourceSinkPushPull__.scripts.gui.network")

local events = defines.events

---@class sspp.gui.hauler
local gui_hauler = {}

--------------------------------------------------------------------------------

---@param network Network
---@param active_class_index integer
---@return ClassName class_name
local function get_class_name(network, active_class_index)
    local class_count = 0

    for class_name, class in pairs(network.classes) do
        class_count = class_count + 1
        if class_count == active_class_index then return class_name end
    end

    error()
end

---@param network Network
---@param active_class_name ClassName
---@return ClassName[] class_names, integer active_class_index
local function get_class_names(network, active_class_name)
    local class_names = {} ---@type ClassName[]
    local class_count, class_index = 0, 0

    for class_name, class in pairs(network.classes) do
        class_count = class_count + 1
        class_names[class_count] = class_name
        if class_name == active_class_name then class_index = class_count end
    end

    return class_names, class_index
end

--------------------------------------------------------------------------------

---@param root GuiRoot.Hauler
local function clear_status_widgets(root)
    local elements = root.elements
    elements.status_message_label.caption = { "sspp-gui.not-configured" }
    elements.status_stop_button.visible = false
    elements.status_item_button.elem_value = nil
end

---@param root GuiRoot.Hauler
function gui_hauler.on_status_changed(root)
    local elements = root.elements
    local status = storage.haulers[root.train_id].status

    elements.status_message_label.caption = status.message
    elements.status_stop_button.visible = status.stop ~= nil
    if status.item then
        local name, quality = lib.split_item_key(status.item)
        if quality then
            elements.status_item_button.elem_value = { name = name, quality = quality, type = "item" }
        else
            elements.status_item_button.elem_value = { name = name, type = "fluid" }
        end
    else
        elements.status_item_button.elem_value = nil
    end
end

---@param root GuiRoot.Hauler
function gui_hauler.on_manual_mode_changed(root)
    root.elements.network_selector.enabled = root.train.manual_mode
    root.elements.class_selector.enabled = root.train.manual_mode
    root.elements.class_clear_button.enabled = root.train.manual_mode and root.elements.class_selector.selected_index > 0
end

--------------------------------------------------------------------------------

glib.handlers["hauler_network_selection_changed"] = { [events.on_gui_selection_state_changed] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Hauler]]

    local network_name = glib.get_network_name(event.element.selected_index, root.train.front_stock.surface)
    local network = storage.networks[network_name]

    local class_names, class_index = get_class_names(network, "")
    root.elements.class_selector.items = class_names
    root.elements.class_selector.selected_index = class_index

    if storage.haulers[root.train_id] then
        clear_status_widgets(root)
        storage.haulers[root.train_id] = nil
    end

    root.elements.open_network_button.enabled = true
end }

glib.handlers["hauler_class_selection_changed"] = { [events.on_gui_selection_state_changed] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Hauler]]

    local network_name = glib.get_network_name(root.elements.network_selector.selected_index, root.train.front_stock.surface)
    local network = storage.networks[network_name]

    local class_name = get_class_name(network, root.elements.class_selector.selected_index)

    local hauler = storage.haulers[root.train_id]
    if hauler then
        hauler.class = class_name
        hauler.status = { message = { "sspp-gui.not-configured" } }
    else
        storage.haulers[root.train_id] = { train = root.train, network = network_name, class = class_name, status = { message = { "sspp-gui.not-configured" } } }
        root.elements.class_clear_button.enabled = true
    end

    gui_hauler.on_status_changed(root)
end }

glib.handlers["hauler_class_clear"] = { [events.on_gui_click] = function(event)
    local root = storage.player_guis[event.player_index] --[[@as GuiRoot.Hauler]]

    root.elements.class_selector.selected_index = 0
    root.elements.class_clear_button.enabled = false

    clear_status_widgets(root)
    storage.haulers[root.train_id] = nil
end }

glib.handlers["hauler_open_network"] = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local root = storage.player_guis[player_id] --[[@as GuiRoot.Hauler]]

    local network_name = glib.get_network_name(root.elements.network_selector.selected_index, root.train.front_stock.surface)
    gui_network.open(player_id, network_name, 1)
end }

glib.handlers["hauler_view_on_map"] = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local root = storage.player_guis[player_id] --[[@as GuiRoot.Hauler]]

    local hauler = storage.haulers[root.train_id]
    if hauler and hauler.status.stop and hauler.status.stop.valid then game.get_player(player_id).centered_on = hauler.status.stop end
end }

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param train LuaTrain
function gui_hauler.open(player_id, train)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]

    -- mods assigning player.opened to another locomotive won't generate a close event
    if player.gui.screen["sspp-hauler"] then gui_hauler.close(player_id) end

    local hauler = storage.haulers[train.id]
    local surface = train.front_stock.surface
    local manual_mode = train.manual_mode

    local network_name = hauler and hauler.network or lib.get_network_name_for_surface(surface)
    local localised_network_names, network_index = glib.get_localised_network_names(network_name or "", surface)

    local class_names, class_index
    if network_name then
        class_names, class_index = get_class_names(storage.networks[network_name], hauler and hauler.class or "")
    else
        class_names, class_index = {}, 0
    end

    local window, elements = glib.add_element(player.gui.screen, {},
        { type = "frame", name = "sspp-hauler", style = "sspp_hauler_frame", direction = "vertical", children = {
            { type = "flow", style = "flib_indicator_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = { "sspp-gui.network" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "drop-down", name = "network_selector", style = "sspp_wide_dropdown", items = localised_network_names, selected_index = network_index, enabled = manual_mode, handler = "hauler_network_selection_changed" },
                { type = "sprite-button", name = "open_network_button", style = "sspp_compact_sprite_button", sprite = "sspp-network-icon", tooltip = { "sspp-gui.open-network" }, mouse_button_filter = { "left" }, enabled = network_name ~= nil, handler = "hauler_open_network" },
            } },
            { type = "flow", style = "flib_indicator_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = { "sspp-gui.class" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "drop-down", name = "class_selector", style = "sspp_wide_dropdown", items = class_names, selected_index = class_index, enabled = manual_mode, handler = "hauler_class_selection_changed" },
                { type = "sprite-button", name = "class_clear_button", style = "sspp_compact_sprite_button", sprite = "sspp-reset-icon", tooltip = { "sspp-gui.remove-from-class" }, mouse_button_filter = { "left" }, enabled = manual_mode and class_index > 0, handler = "hauler_class_clear" },
            } },
            { type = "flow", style = "flib_indicator_flow", direction = "horizontal", children = {
                { type = "label", name = "status_message_label", style = "label" },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "sprite-button", name = "status_stop_button", style = "sspp_compact_slot_button", sprite = "item/sspp-stop", tooltip = { "sspp-gui.view-on-map" }, mouse_button_filter = { "left" }, handler = "hauler_view_on_map" },
                { type = "choose-elem-button", name = "status_item_button", style = "sspp_compact_slot_button", elem_type = "signal", elem_mods = { locked = true } },
            } },
        } }
    ) ---@cast elements -nil

    local resolution, scale = player.display_resolution, player.display_scale
    window.location = { x = resolution.width - (244 + 12) * scale, y = resolution.height - (108 + 12) * scale }

    ---@type GuiRoot.Hauler
    local root = { type = "HAULER", elements = elements, train_id = train.id, train = train }

    if hauler then
        gui_hauler.on_status_changed(root)
    else
        clear_status_widgets(root)
    end

    storage.player_guis[player_id] = root
end

---@param player_id PlayerId
function gui_hauler.close(player_id)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]

    player.gui.screen["sspp-hauler"].destroy()

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

return gui_hauler
