-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local gui = require("__SourceSinkPushPull__.scripts.gui")

local main_station = require("__SourceSinkPushPull__.scripts.main.station")
local main_hauler = require("__SourceSinkPushPull__.scripts.main.hauler")

---@class sspp.main
local main = { station = main_station, hauler = main_hauler }

--------------------------------------------------------------------------------

local function on_entity_built(event)
    local entity = event.entity or event.destination ---@type LuaEntity

    if entity.type == "straight-rail" then
        main_station.on_rail_built(entity)
        return
    end

    local name = entity.name
    if name == "entity-ghost" then
        name = entity.ghost_name
    else
        -- reliably detecting which ghost was built over is a pain, so check all of them
        main_station.destory_invalid_entities()
    end

    if name == "sspp-stop" then
        main_station.on_stop_built(entity)
    elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        main_station.on_comb_built(entity)
    end

    if not lib.get_network_name_for_surface(entity.surface) then
        local player_id = event.player_index
        local player = player_id and game.get_player(player_id)
        if player then
            player.play_sound({ path = "utility/cannot_build" })
            player.create_local_flying_text({ create_at_cursor = true, text = { "sspp-gui.unsupported-surface" }})
        end
        if player then
            player.mine_entity(entity, true)
        else
            entity.destroy({ raise_destroy = true })
        end
    end
end

local function on_entity_broken(event)
    local entity = event.entity or event.ghost ---@type LuaEntity

    if entity.type == "straight-rail" then
        main_station.on_rail_broken(entity)
        return
    end

    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    if name == "sspp-stop" then
        main_station.on_stop_broken(entity.unit_number, entity)
    elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        main_station.on_comb_broken(entity.unit_number, entity)
    elseif entity.train then
        if #entity.train.carriages == 1 then
            main_hauler.on_broken(entity.train.id, nil)
        end
    end
end

---@param event EventData.on_player_rotated_entity
local function on_entity_rotated(event)
    local entity = event.entity

    local name = entity.name
    if name == "entity-ghost" then name = entity.ghost_name end

    if name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        -- TODO: find a way to do reverse rotate
        entity.direction = (entity.direction - 4) % 16
    end
end

--------------------------------------------------------------------------------

---@param event EventData.on_train_changed_state
local function on_train_changed_state(event)
    local train = event.train

    local state, old_state = train.state, event.old_state
    local is_manual = state == defines.train_state.manual_control or state == defines.train_state.manual_control_stop
    local was_manual = old_state == defines.train_state.manual_control or old_state == defines.train_state.manual_control_stop
    if is_manual and was_manual then return end

    if is_manual or was_manual then
        gui.on_manual_mode_changed(train.id)
    end

    local hauler = storage.haulers[train.id]
    if not hauler then return end

    if is_manual then
        main_hauler.on_set_to_manual(hauler)
        return
    end

    if was_manual then
        main_hauler.on_set_to_automatic(hauler)
        return
    end

    local job_index = hauler.job
    if job_index then
        local job = storage.networks[hauler.network].jobs[job_index]
        local job_type = job.type

        if job_type == "FUEL" then
            if job.fuel_arrive_tick then
                if state == defines.train_state.arrive_station then
                    main_hauler.on_done_at_fuel_stop(hauler, job --[[@as NetworkJob.Fuel]])
                end
            else
                if state == defines.train_state.wait_station then
                    main_hauler.on_arrived_at_fuel_stop(hauler, job --[[@as NetworkJob.Fuel]])
                end
            end
        else
            if job.request_arrive_tick then
                if state == defines.train_state.arrive_station then
                    main_hauler.on_done_at_request_station(hauler, job --[[@as NetworkJob.Combined|NetworkJob.Dropoff]])
                end
            elseif job.request_stop then
                if state == defines.train_state.wait_station and train.station then
                    main_hauler.on_arrived_at_request_station(hauler, job --[[@as NetworkJob.Combined|NetworkJob.Dropoff]])
                end
            elseif job.provide_arrive_tick then
                if state == defines.train_state.arrive_station then
                    main_hauler.on_done_at_provide_station(hauler, job --[[@as NetworkJob.Combined|NetworkJob.Pickup]])
                end
            else -- job.provide_stop
                if state == defines.train_state.wait_station and train.station then
                    main_hauler.on_arrived_at_provide_station(hauler, job --[[@as NetworkJob.Combined|NetworkJob.Pickup]])
                end
            end
        end

        return
    end

    if hauler.to_depot then
        if state == defines.train_state.wait_station then
            main_hauler.on_arrived_at_depot_stop(hauler)
        end
        return
    end
end

---@param event EventData.on_train_created
local function on_train_created(event)
    if event.old_train_id_1 then
        main_hauler.on_broken(event.old_train_id_1, event.train)
    end
    if event.old_train_id_2 then
        main_hauler.on_broken(event.old_train_id_2, event.train)
    end
end

---@param event EventData.on_train_schedule_changed
local function on_train_schedule_changed(event)
    if not event.player_index then return end

    local train = event.train
    if train.manual_mode then return end

    local hauler = storage.haulers[train.id]
    if not hauler then return end

    hauler.status = { message = { "sspp-alert.schedule-modified" } }
    lib.show_train_alert(train, hauler.status.message)
    train.manual_mode = true
end

--------------------------------------------------------------------------------

---@param surface LuaSurface
function main.surface_init_network(surface)
    local network_name = lib.get_network_name_for_surface(surface)
    if not network_name then return end
    if storage.networks[network_name] then return end

    storage.networks[network_name] = {
        surface = surface,
        classes = {},
        items = {},
        job_index_counter = 0,
        jobs = {},
        buffer_haulers = {},
        provide_haulers = {},
        request_haulers = {},
        fuel_haulers = {},
        to_depot_haulers = {},
        at_depot_haulers = {},
        to_depot_liquidate_haulers = {},
        at_depot_liquidate_haulers = {},
        push_tickets = {},
        provide_tickets = {},
        pull_tickets = {},
        request_tickets = {},
        provide_done_tickets = {},
        request_done_tickets = {},
        buffer_tickets = {},
    }
end

---@param surface LuaSurface
function main.surface_break_all_entities(surface)
    for _, entity in pairs(surface.find_entities()) do
        if entity.valid then
            local name = entity.name
            if name == "entity-ghost" then name = entity.ghost_name end

            if name == "sspp-stop" then
                main_station.on_stop_broken(entity.unit_number, entity)
            elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
                main_station.on_comb_broken(entity.unit_number, entity)
            else
                local train = entity.train
                if train then main_hauler.on_broken(train.id, nil) end
            end
        end
    end
end

---@param event EventData.on_surface_created|EventData.on_surface_imported
local function on_surface_created(event)
    local surface = assert(game.get_surface(event.surface_index))
    main.surface_init_network(surface)
end

---@param event EventData.on_pre_surface_cleared
local function on_surface_cleared(event)
    local surface = assert(game.get_surface(event.surface_index))
    main.surface_break_all_entities(surface)
end

---@param event EventData.on_pre_surface_deleted
local function on_surface_deleted(event)
    local surface = assert(game.get_surface(event.surface_index))
    main.surface_break_all_entities(surface)

    local network_name = lib.get_network_name_for_surface(surface)
    if network_name then
        storage.networks[network_name] = nil
    end
end

---@param event EventData.on_surface_renamed
local function on_surface_renamed(event)
    assert(false, "TODO: rename surface")
end

--------------------------------------------------------------------------------

local function on_init()
    storage.tick_state = "INITIAL"
    storage.entities = {}
    storage.stop_comb_ids = {}
    storage.comb_stop_ids = {}
    storage.networks = {}
    storage.stations = {}
    storage.haulers = {}
    storage.player_guis = {}
    storage.poll_stations = {}
    storage.request_done_items = {}
    storage.liquidate_items = {}
    storage.provide_done_items = {}
    storage.dispatch_items = {}
    storage.buffer_items = {}
    storage.disabled_items = {}
    for _, surface in pairs(game.surfaces) do main.surface_init_network(surface) end

    lib.refresh_dictionaries()
end

local function on_load()
    --- TODO: setup mod compatibility
end

--------------------------------------------------------------------------------

---@type LuaScriptRaisedBuiltEventFilter[]
local filter_built = {
    { filter = "name", name = "sspp-stop" },
    { filter = "name", name = "sspp-general-io" },
    { filter = "name", name = "sspp-provide-io" },
    { filter = "name", name = "sspp-request-io" },
    { filter = "ghost_name", name = "sspp-stop",  },
    { filter = "ghost_name", name = "sspp-general-io" },
    { filter = "ghost_name", name = "sspp-provide-io" },
    { filter = "ghost_name", name = "sspp-request-io" },
    { filter = "type", type = "straight-rail" },
}

---@type LuaScriptRaisedDestroyEventFilter[]
local filter_broken = {
    { filter = "name", name = "sspp-stop" },
    { filter = "name", name = "sspp-general-io" },
    { filter = "name", name = "sspp-provide-io" },
    { filter = "name", name = "sspp-request-io" },
    { filter = "ghost_name", name = "sspp-stop" },
    { filter = "ghost_name", name = "sspp-general-io" },
    { filter = "ghost_name", name = "sspp-provide-io" },
    { filter = "ghost_name", name = "sspp-request-io" },
    { filter = "type", type = "straight-rail" },
    { filter = "rolling-stock" },
}

---@type LuaScriptRaisedDestroyEventFilter[]
local filter_ghost_broken = {
    { filter = "name", name = "sspp-stop" },
    { filter = "name", name = "sspp-general-io" },
    { filter = "name", name = "sspp-provide-io" },
    { filter = "name", name = "sspp-request-io" },
}

script.on_event(defines.events.on_built_entity, on_entity_built, filter_built)
script.on_event(defines.events.on_entity_cloned, on_entity_built, filter_built)
script.on_event(defines.events.on_robot_built_entity, on_entity_built, filter_built)
script.on_event(defines.events.script_raised_built, on_entity_built, filter_built)
script.on_event(defines.events.script_raised_revive, on_entity_built, filter_built)

script.on_event(defines.events.on_entity_died, on_entity_broken, filter_broken)
script.on_event(defines.events.on_pre_player_mined_item, on_entity_broken, filter_broken)
script.on_event(defines.events.on_robot_mined_entity, on_entity_broken, filter_broken)
script.on_event(defines.events.script_raised_destroy, on_entity_broken, filter_broken)
script.on_event(defines.events.on_pre_ghost_deconstructed, on_entity_broken, filter_ghost_broken)

script.on_event(defines.events.on_player_rotated_entity, on_entity_rotated)

script.on_event(defines.events.on_train_changed_state, on_train_changed_state)
script.on_event(defines.events.on_train_created, on_train_created)
script.on_event(defines.events.on_train_schedule_changed, on_train_schedule_changed)

script.on_event(defines.events.on_surface_created, on_surface_created)
script.on_event(defines.events.on_surface_imported, on_surface_created)
script.on_event(defines.events.on_pre_surface_cleared, on_surface_cleared)
script.on_event(defines.events.on_pre_surface_deleted, on_surface_deleted)
script.on_event(defines.events.on_surface_renamed, on_surface_renamed)

script.on_init(on_init)
script.on_load(on_load)

--------------------------------------------------------------------------------

return main
