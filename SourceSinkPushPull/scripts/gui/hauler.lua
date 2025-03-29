-- SSPP by jagoly

local flib_gui = require("__flib__.gui")

local lib = require("__SourceSinkPushPull__.scripts.lib")
local glib = require("__SourceSinkPushPull__.scripts.glib")

local gui_network = require("__SourceSinkPushPull__.scripts.gui.network")

local events = defines.events

local gui_hauler = {}

--------------------------------------------------------------------------------

---@param player_gui PlayerGui.Hauler
function gui_hauler.on_status_changed(player_gui)
    local elements = player_gui.elements
    local status = storage.haulers[player_gui.train_id].status

    elements.status_label.caption = status.message
    if status.item then
        local name, quality = lib.split_item_key(status.item)
        if quality then
            elements.item_button.elem_value = { name = name, quality = quality, type = "item" }
        else
            elements.item_button.elem_value = { name = name, type = "fluid" }
        end
    else
        elements.item_button.elem_value = nil
    end
    elements.stop_button.enabled = status.stop ~= nil
end

---@param player_gui PlayerGui.Hauler
function gui_hauler.on_manual_mode_changed(player_gui)
    player_gui.elements.class_textbox.enabled = player_gui.train.manual_mode
    player_gui.elements.class_auto_assign_button.enabled = player_gui.train.manual_mode
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_open_network = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local network_name = storage.player_guis[player_id].network

    gui_network.open(player_id, network_name, 1)
end }

---@param event EventData.on_gui_click
local handle_view_on_map = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerGui.Hauler]]

    local hauler = storage.haulers[player_gui.train_id]
    if hauler and hauler.status.stop and hauler.status.stop.valid then
        game.get_player(player_id).centered_on = hauler.status.stop
    end
end }

---@param event EventData.on_gui_text_changed
local handle_class_changed = { [events.on_gui_text_changed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Hauler]]
    local train_id, train = player_gui.train_id, player_gui.train

    -- disabling textboxes doesn't disable the icon selector, so hope that the user doesn't do that
    -- assert(train.manual_mode, "class name changed when not manual")
    -- update: a user did this, guess I should handle it properly until the api bug gets fixed
    if not train.manual_mode then
        local hauler = storage.haulers[train_id]
        event.element.text = hauler and hauler.class or ""
        return
    end

    local class_name = glib.truncate_input(event.element, 199)

    local hauler = storage.haulers[train_id]
    if hauler then
        if class_name ~= "" then
            hauler.class = class_name
        else
            storage.haulers[train_id] = nil
        end
    elseif class_name ~= "" then
        storage.haulers[train_id] = {
            train = train,
            network = player_gui.network,
            class = class_name,
            status = { message = { "sspp-gui.not-configured" } },
        }
    end
end }

---@param carriage LuaEntity
local function map_carriage_name(carriage)
    -- TODO: Adjust names of carriages that should be treated as identical. For example, the
    -- locomotives from Multiple Unit Train Control should map to the same strings as the
    -- entities that they are derived from.
    return carriage.name
end

---@param event EventData.on_gui_click
local handle_class_auto_assign = { [events.on_gui_click] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerGui.Hauler]]
    local network_name = player_gui.network
    local train_id, train = player_gui.train_id, player_gui.train

    local train_carriage_names, train_length = {}, 0 ---@type string[], integer
    for _, carriage in pairs(train.carriages) do
        train_length = train_length + 1
        train_carriage_names[train_length] = map_carriage_name(carriage)
    end

    local matching_class ---@type ClassName?
    local classes_with_haulers = {} ---@type {[ClassName]: true?}

    -- first, try to find a class that already has an identical train
    for hauler_id, hauler in pairs(storage.haulers) do
        if hauler.network == network_name and hauler_id ~= train_id then
            local class_name = hauler.class
            if class_name == matching_class then goto continue end

            local carriages = hauler.train.carriages
            local length = #carriages

            if length == train_length then
                for i = 1, length do
                    if map_carriage_name(carriages[i]) ~= train_carriage_names[i] then goto continue end
                end
                if matching_class then
                    lib.show_train_alert(train, { "sspp-alert.auto-assign-multiple-classes" })
                    return
                end
                matching_class = class_name
            end

            classes_with_haulers[class_name] = true
        end

        ::continue::
    end

    -- second, try to find a newly added class with no trains
    if not matching_class then
        for class_name, _ in pairs(storage.networks[network_name].classes) do
            if not classes_with_haulers[class_name] then
                if matching_class then
                    lib.show_train_alert(train, { "sspp-alert.auto-assign-multiple-classes" })
                    return
                end
                matching_class = class_name
            end
        end
    end

    if not matching_class then
        lib.show_train_alert(train, { "sspp-alert.auto-assign-no-class" })
        return
    end

    storage.haulers[train_id] = {
        train = train,
        network = network_name,
        class = matching_class,
        status = { message = { "sspp-gui.not-configured" } },
    }
    player_gui.elements.class_textbox.text = matching_class

    train.manual_mode = false
end }

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param train LuaTrain
function gui_hauler.open(player_id, train)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]

    local network_name = train.front_stock.surface.name
    local manual_mode = train.manual_mode

    -- mods assigning player.opened to another locomotive won't generate a close event
    if player.gui.screen["sspp-hauler"] then
        gui_hauler.close(player_id)
    end

    local elements, window = flib_gui.add(player.gui.screen, {
        { type = "frame", name = "sspp-hauler", style = "sspp_hauler_frame", direction = "vertical", children = {
            { type = "flow", style = "flib_indicator_flow", direction = "horizontal", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.sspp" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, tooltip = { "shortcut-name.sspp" }, mouse_button_filter = { "left" }, handler = handle_open_network },
            } },
            { type = "flow", style = "flib_indicator_flow", direction = "horizontal", children = {
                { type = "label", name = "status_label", style = "label" },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "choose-elem-button", name = "item_button", style = "sspp_compact_slot_button", elem_type = "signal" },
                { type = "sprite-button", name = "stop_button", style = "sspp_compact_slot_button", sprite = "item/sspp-stop", tooltip = { "sspp-gui.view-on-map" }, mouse_button_filter = { "left" }, handler = handle_view_on_map },
            } },
            { type = "flow", style = "flib_indicator_flow", direction = "horizontal", children = {
                { type = "label", style = "bold_label", caption = { "sspp-gui.class" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", name = "class_textbox", style = "sspp_wide_name_textbox", icon_selector = true, enabled = manual_mode, handler = handle_class_changed },
                { type = "sprite-button", name = "class_auto_assign_button", style = "sspp_compact_slot_button", sprite = "sspp-refresh-icon", tooltip = { "sspp-gui.hauler-auto-assign-tooltip" }, mouse_button_filter = { "left" }, enabled = manual_mode, handler = handle_class_auto_assign },
            } },
        } },
    })
    elements.item_button.locked = true -- https://forums.factorio.com/viewtopic.php?t=127562

    local resolution, scale = player.display_resolution, player.display_scale
    window.location = { x = resolution.width - (244 + 12) * scale, y = resolution.height - (108 + 12) * scale }

    local player_gui = { type = "HAULER", network = network_name, elements = elements, train_id = train.id, train = train } ---@type PlayerGui.Hauler
    storage.player_guis[player_id] = player_gui

    local hauler = storage.haulers[train.id]
    if hauler then
        elements.class_textbox.text = hauler.class
        gui_hauler.on_status_changed(player_gui)
    else
        elements.status_label.caption = { "sspp-gui.not-configured" }
        elements.stop_button.enabled = false
    end
end

---@param player_id PlayerId
function gui_hauler.close(player_id)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]

    player.gui.screen["sspp-hauler"].destroy()

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

function gui_hauler.add_flib_handlers()
    flib_gui.add_handlers({
        ["hauler_open_network"] = handle_open_network[events.on_gui_click],
        ["hauler_view_on_map"] = handle_view_on_map[events.on_gui_click],
        ["hauler_class_changed"] = handle_class_changed[events.on_gui_text_changed],
        ["hauler_class_auto_assign"] = handle_class_auto_assign[events.on_gui_click],
    })
end

--------------------------------------------------------------------------------

return gui_hauler
