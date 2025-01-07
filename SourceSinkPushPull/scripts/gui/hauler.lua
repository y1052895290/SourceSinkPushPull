-- SSPP by jagoly

local flib_gui = require("__flib__.gui")

--------------------------------------------------------------------------------

---@param event EventData.on_gui_click
local function handle_open_network(event)
    local player_id = event.player_index
    local network_name = storage.player_states[player_id].network

    gui.network_open(player_id, network_name)
end

---@param event EventData.on_gui_text_changed
local function handle_class_changed(event)
    local player_state = assert(storage.player_states[event.player_index])
    local train = assert(player_state.train)

    assert(train.manual_mode, "class name changed when not manual")

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
            network = player_state.network,
            class = class_name,
        }
    end
end

--------------------------------------------------------------------------------

---@param player_id PlayerId
---@param hauler_id HaulerId
function gui.hauler_opened(player_id, hauler_id)
    local player = assert(game.get_player(player_id))
    local train = assert(game.train_manager.get_train_by_id(hauler_id))

    local network_name = train.front_stock.surface.name

    local elements, window = flib_gui.add(player.gui.screen, {
        { type = "frame", name = "sspp-hauler", style = "sspp_hauler_frame", direction = "vertical", children = {
            { type = "flow", style = "horizontal_flow", children = {
                { type = "label", style = "frame_title", caption = { "sspp-gui.sspp-class" } },
                { type = "empty-widget", style = "flib_horizontal_pusher" },
                { type = "button", style = "sspp_frame_tool_button", caption = { "sspp-gui.network" }, mouse_button_filter = { "left" }, handler = handle_open_network },
            } },
            {
                type = "textfield", name = "class_textbox", style = "sspp_hauler_textbox", icon_selector = true,
                handler = { [defines.events.on_gui_text_changed] = handle_class_changed },
            },
        } },
    })

    local resolution, scale = player.display_resolution, player.display_scale
    window.location = { x = resolution.width - (200 + 12) * scale, y = resolution.height - (76 + 12) * scale }

    local hauler = storage.haulers[hauler_id]
    if hauler then
        elements.class_textbox.text = hauler.class
    end

    elements.class_textbox.enabled = train.manual_mode

    storage.player_states[player_id] = { network = network_name, train = train, elements = elements }
end

---@param player_id PlayerId
function gui.hauler_closed(player_id)
    local player = assert(game.get_player(player_id))

    local window = assert(player.gui.screen["sspp-hauler"])
    window.destroy()

    storage.player_states[player_id] = nil
end

--------------------------------------------------------------------------------

function gui.hauler_add_flib_handlers()
    flib_gui.add_handlers({
        ["hauler_open_network"] = handle_open_network,
        ["hauler_class_changed"] = handle_class_changed,
    })
end
