-- SSPP by jagoly

local glib = require("__SourceSinkPushPull__.scripts.glib")

local gui_network = require("__SourceSinkPushPull__.scripts.gui.network")
local gui_station = require("__SourceSinkPushPull__.scripts.gui.station")
local gui_hauler = require("__SourceSinkPushPull__.scripts.gui.hauler")

local gui = {}

--------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
local function on_gui_opened(event)
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity ---@type LuaEntity
        local name = entity.name
        if name == "entity-ghost" then name = entity.ghost_name end
        if name == "sspp-stop" or name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
            gui_station.open(event.player_index, entity)
        elseif entity.type == "locomotive" then
            gui_hauler.open(event.player_index, entity.train)
        end
    end
end

---@param event EventData.on_gui_closed
local function on_gui_closed(event)
    if event.gui_type == defines.gui_type.custom then
        if event.element.name == "sspp-network" then
            gui_network.close(event.player_index)
        elseif event.element.name == "sspp-station" then
            gui_station.close(event.player_index)
        end
    elseif event.gui_type == defines.gui_type.entity then
        if event.entity.type == "locomotive" then
            gui_hauler.close(event.player_index)
        end
    end
end

---@param event EventData.on_lua_shortcut
local function on_lua_shortcut(event)
    if event.prototype_name == "sspp" then
        local player_id = event.player_index
        local player = game.get_player(player_id) --[[@as LuaPlayer]]

        if player.opened and player.opened.name == "sspp-network" then
            player.opened = nil
        else
            -- TODO: remember some previous state
            gui_network.open(player_id, player.surface.name, 1)
        end
    end
end

--------------------------------------------------------------------------------

function gui.on_poll_finished()
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "NETWORK" then
            gui_network.on_poll_finished(player_gui)
        elseif player_gui.type == "STATION" then
            gui_station.on_poll_finished(player_gui)
        end
    end
end

---@param network_name NetworkName
function gui.on_job_created(network_name)
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "NETWORK" then
            if player_gui.network == network_name then
                gui_network.on_job_created(player_gui)
            end
        end
    end
end

---@param network_name NetworkName
---@param job_index JobIndex
function gui.on_job_removed(network_name, job_index)
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "NETWORK" then
            if player_gui.network == network_name then
                gui_network.on_job_removed(player_gui, job_index)
            end
        end
    end
end

---@param network_name NetworkName
---@param job_index JobIndex
function gui.on_job_updated(network_name, job_index)
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "NETWORK" then
            if player_gui.network == network_name then
                gui_network.on_job_updated(player_gui, job_index)
            end
        end
    end
end

---@param hauler_id HaulerId
function gui.on_manual_mode_changed(hauler_id)
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "HAULER" then
            if player_gui.train_id == hauler_id then
                gui_hauler.on_manual_mode_changed(player_gui)
            end
        end
    end
end

---@param hauler_id HaulerId
function gui.on_status_changed(hauler_id)
    for _, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "HAULER" then
            if player_gui.train_id == hauler_id then
                gui_hauler.on_status_changed(player_gui)
            end
        end
    end
end

--------------------------------------------------------------------------------

---@param unit_number uint
function gui.on_part_broken(unit_number)
    for player_id, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "STATION" then
            if player_gui.unit_number == unit_number or player_gui.parts and player_gui.parts.ids[unit_number] then
                gui_station.close(player_id)
            end
        end
    end
end

---@param old_train_id uint
---@param new_train LuaTrain?
function gui.on_train_broken(old_train_id, new_train)
    for player_id, player_gui in pairs(storage.player_guis) do
        if player_gui.type == "HAULER" then
            if player_gui.train_id == old_train_id then
                if new_train then
                    player_gui.train_id, player_gui.train = new_train.id, new_train
                else
                    gui_hauler.close(player_id)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------

function gui.register_event_handlers()
    script.on_event(defines.events.on_gui_opened, on_gui_opened)
    script.on_event(defines.events.on_gui_closed, on_gui_closed)
    script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)

    glib.initialise()

    gui_network.initialise()
    gui_station.initialise()
    gui_hauler.initialise()
end

--------------------------------------------------------------------------------

return gui
