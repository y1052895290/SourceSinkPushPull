-- SSPP by jagoly

local flib_gui = require("__flib__.gui")
local events = defines.events

--------------------------------------------------------------------------------

---@param player_gui PlayerHaulerGui
function gui.hauler_status_changed(player_gui)
    local elements = player_gui.elements
    local train = player_gui.train
    local hauler = storage.haulers[train.id]

    elements.status_label.caption = hauler.status
    elements.class_textbox.caption = hauler.class
    if hauler.status_item then
        local name, quality = split_item_key(hauler.status_item)
        if quality then
            elements.item_button.elem_value = { name = name, quality = quality, type = "item" }
        else
            elements.item_button.elem_value = { name = name, type = "fluid" }
        end
    else
        elements.item_button.elem_value = nil
    end
    elements.stop_button.enabled = hauler.status_stop ~= nil
end

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local handle_open_network = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local network_name = storage.player_guis[player_id].network

    gui.network_open(player_id, network_name)
end }

---@param event EventData.on_gui_click
local handle_stop_clicked = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player_gui = storage.player_guis[player_id] --[[@as PlayerHaulerGui]]

    local hauler = storage.haulers[player_gui.train.id]
    if hauler and hauler.status_stop and hauler.status_stop.valid then
        game.get_player(player_id).centered_on = hauler.status_stop
    end
end }

---@param event EventData.on_gui_text_changed
local handle_class_changed = { [events.on_gui_text_changed] = function(event)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerHaulerGui]]
    local train = player_gui.train

    -- disabling textboxes doesn't disable the icon selector, so hope that the user doesn't do that
    -- assert(train.manual_mode, "class name changed when not manual")
    -- update: a user did this, guess I should handle it properly until the api bug gets fixed
    if not train.manual_mode then
        local hauler = storage.haulers[train.id]
        event.element.text = hauler and hauler.class or ""
        return
    end

    local class_name = event.element.text
    -- TODO: validate class name

    local hauler = storage.haulers[train.id]
    if hauler then
        if class_name ~= "" then
            hauler.class = class_name
        else
            storage.haulers[train.id] = nil
        end
    elseif class_name ~= "" then
        storage.haulers[train.id] = {
            train = train,
            network = player_gui.network,
            class = class_name,
        }
    end
end }

---@param item_slots number
---@param fluid_capacity number
---@return Class
function generate_network_class(item_slots, fluid_capacity)
    ---@type Class
    local class = {
        bypass_depot = false,
        depot_name = "",
        fluid_capacity = fluid_capacity,
        fueler_name = "",
        item_slot_capacity = item_slots,
    }
    return class
end

---@param event EventData.on_gui_click
local handle_auto_train_class = { [events.on_gui_click] = function(event)
    local player_id = event.player_index
    local player = game.get_player(player_id)
    local player_gui = storage.player_guis[event.player_index] --[[@as PlayerHaulerGui]]
    local train = player_gui.train

    local train_name = ""
    local item_slots = 0
    local fluid_capacity = 0
    for _, carriage in pairs(train.carriages) do
        train_name = train_name .. string.format("[item=%s]", carriage.name)
        if carriage.type == "cargo-wagon" then
            local inv = carriage.get_inventory(defines.inventory.cargo_wagon)
            item_slots = item_slots + #inv
        elseif carriage.type == "fluid-wagon" then
            fluid_capacity = fluid_capacity + carriage.prototype.fluid_capacity
        end
    end

    local network = storage.networks[player_gui.network]
    local class = nil
    for class_name, network_class in pairs(network.classes) do
        if class_name == train_name then
            class = network_class
            break
        end
    end

    if class == nil then
        class = generate_network_class(item_slots, fluid_capacity)
        network.classes[train_name] = class
    end

    storage.haulers[train.id] = {
        train = train,
        network = player_gui.network,
        class = train_name,
    }
    train.manual_mode = false
    gui.hauler_status_changed(player_gui)
end }

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param hauler_id HaulerId
function gui.hauler_opened(player_id, hauler_id)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]
    local train = game.train_manager.get_train_by_id(hauler_id) --[[@as LuaTrain]]

    local network_name = train.front_stock.surface.name

    -- mods assigning player.opened to another locomotive won't generate a close event
    if player.gui.screen["sspp-hauler"] then
        gui.hauler_closed(player_id)
    end

    local elements, window = flib_gui.add(player.gui.screen, {
        { type = "frame", name = "sspp-hauler", style = "sspp_hauler_frame", direction = "vertical", children = {
            { type = "flow", style = "flib_indicator_flow", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.sspp" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "button", name = "auto_train_class", style = "sspp_frame_tool_button", caption = { "sspp-gui.auto-train-class-btn" }, mouse_button_filter = { "left" }, handler = handle_auto_train_class, enabled = false },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, mouse_button_filter = { "left" }, handler = handle_open_network },
            } },
            { type = "flow", style = "flib_indicator_flow", children = {
                { type = "label", name = "status_label", style = "label" },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "choose-elem-button", name = "item_button", style = "sspp_compact_slot_button", elem_type = "signal", enabled = false },
                { type = "sprite-button", name = "stop_button", style = "sspp_compact_slot_button", sprite = "item/train-stop", mouse_button_filter = { "left" }, handler = handle_stop_clicked },
            } },
            { type = "flow", style = "flib_indicator_flow", children = {
                { type = "label", style = "bold_label", caption = { "sspp-gui.class" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "textfield", name = "class_textbox", style = "sspp_name_textbox", icon_selector = true, handler = handle_class_changed },
            } },
        } },
    })

    local resolution, scale = player.display_resolution, player.display_scale
    window.location = { x = resolution.width - (224 + 12) * scale, y = resolution.height - (108 + 12) * scale }

    local player_gui = { network = network_name, train = train, elements = elements }
    storage.player_guis[player_id] = player_gui

    local hauler = storage.haulers[hauler_id]
    if hauler then
        elements.class_textbox.text = hauler.class
        gui.hauler_status_changed(player_gui)
    else
        elements.status_label.caption = { "sspp-gui.not-configured" }
        elements.stop_button.enabled = false
    end

    elements.class_textbox.enabled = train.manual_mode

    if train.manual_mode then
        elements.auto_train_class.enabled = true
    end
end

---@param player_id PlayerId
function gui.hauler_closed(player_id)
    local player = game.get_player(player_id) --[[@as LuaPlayer]]

    player.gui.screen["sspp-hauler"].destroy()

    storage.player_guis[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.hauler_add_flib_handlers()
    flib_gui.add_handlers({
        ["hauler_open_network"] = handle_open_network[events.on_gui_click],
        ["handle_auto_train_class"] = handle_auto_train_class[events.on_gui_click],
        ["hauler_stop_clicked"] = handle_stop_clicked[events.on_gui_click],
        ["hauler_class_changed"] = handle_class_changed[events.on_gui_text_changed],
    })
end
