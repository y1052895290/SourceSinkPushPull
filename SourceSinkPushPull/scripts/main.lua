-- SSPP by jagoly

local lib = require("__SourceSinkPushPull__.scripts.lib")
local gui = require("__SourceSinkPushPull__.scripts.gui")
local enums = require("__SourceSinkPushPull__.scripts.enums")

local main_station = require("__SourceSinkPushPull__.scripts.main.station")
local main_hauler = require("__SourceSinkPushPull__.scripts.main.hauler")

local main = { station = main_station, hauler = main_hauler }

--------------------------------------------------------------------------------

local function on_entity_built(event)
    local entity = event.entity or event.created_entity ---@type LuaEntity

    if entity.type == "straight-rail" then
        main_station.on_rail_built(entity, defines.rail_direction.front)
        main_station.on_rail_built(entity, defines.rail_direction.back)
        return
    end

    local name, ghost_unit_number = entity.name, nil
    if name == "entity-ghost" then
        local tags = entity.tags or {}
        tags.ghost_unit_number = entity.unit_number
        entity.tags = tags
        name = entity.ghost_name
    else
        -- this unit number may be incorrect due to https://forums.factorio.com/viewtopic.php?p=666167#p666167
        -- we are just using it here to detect if we built over a ghost at all
        -- UPDATE: we can't even rely on this, because the user can paste a non ghost and wipe the tags completely...
        -- if event.tags and event.tags.ghost_unit_number then
            main_station.destory_invalid_ghosts()
        -- end
        -- ghost_unit_number = event.tags and event.tags.ghost_unit_number
    end

    if name == "sspp-stop" then
        main_station.on_stop_built(entity, ghost_unit_number)
    elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
        main_station.on_comb_built(entity, ghost_unit_number)
    end
end

local function on_entity_broken(event)
    local entity = event.entity or event.ghost ---@type LuaEntity

    if entity.type == "straight-rail" then
        main_station.on_rail_broken(entity, defines.rail_direction.front)
        main_station.on_rail_broken(entity, defines.rail_direction.back)
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
local function init_network_for_surface(surface)
    storage.networks[surface.name] = {
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

---@param event EventData.on_surface_created|EventData.on_surface_imported
local function on_surface_created(event)
    local surface = assert(game.get_surface(event.surface_index))
    init_network_for_surface(surface)
end

---@param event EventData.on_pre_surface_cleared|EventData.on_pre_surface_deleted
local function on_surface_cleared(event)
    local surface = assert(game.get_surface(event.surface_index))

    for _, entity in pairs(surface.find_entities()) do
        local name = entity.name
        if name == "entity-ghost" then name = entity.ghost_name end

        if name == "sspp-stop" then
            main_station.on_stop_broken(entity.unit_number, entity)
        elseif name == "sspp-general-io" or name == "sspp-provide-io" or name == "sspp-request-io" then
            main_station.on_comb_broken(entity.unit_number, entity)
        end
    end

    storage.networks[surface.name] = nil
end

---@param event EventData.on_surface_renamed
local function on_surface_renamed(event)
    assert(false, "TODO: rename surface")
end

--------------------------------------------------------------------------------

---@param name string
---@return Color
local function get_rgb_setting(name)
    local rgba = settings.global[name].value --[[@as Color]]
    local a = rgba.a
    return { r = rgba.r * a, g = rgba.g * a, b = rgba.b * a, a = 1.0 }
end

function main.populate_mod_settings()
    mod_settings.auto_paint_trains = settings.global["sspp-auto-paint-trains"].value --[[@as boolean]]
    mod_settings.train_colors = {
        [enums.train_colors.depot] = get_rgb_setting("sspp-depot-color"),
        [enums.train_colors.fuel] = get_rgb_setting("sspp-fuel-color"),
        [enums.train_colors.provide] = get_rgb_setting("sspp-provide-color"),
        [enums.train_colors.request] = get_rgb_setting("sspp-request-color"),
        [enums.train_colors.liquidate] = get_rgb_setting("sspp-liquidate-color"),
    }
    mod_settings.default_train_limit = settings.global["sspp-default-train-limit"].value --[[@as integer]]
    mod_settings.item_inactivity_ticks = settings.global["sspp-item-inactivity-ticks"].value --[[@as integer]]
    mod_settings.fluid_inactivity_ticks = settings.global["sspp-fluid-inactivity-ticks"].value --[[@as integer]]
    mod_settings.stations_per_tick = settings.global["sspp-stations-per-tick"].value --[[@as integer]]
end

---@param event EventData.on_runtime_mod_setting_changed
local function on_runtime_mod_setting_changed(event)
    main.populate_mod_settings()
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
    for _, surface in pairs(game.surfaces) do init_network_for_surface(surface) end
end

local function on_load()
    --- TODO: setup mod compatibility
end

--------------------------------------------------------------------------------

function main.register_event_handlers()
    local filter_built = {
        { filter = "name", name = "sspp-stop" },
        { filter = "name", name = "sspp-general-io" },
        { filter = "name", name = "sspp-provide-io" },
        { filter = "name", name = "sspp-request-io" },
        { filter = "ghost_name", name = "sspp-stop" },
        { filter = "ghost_name", name = "sspp-general-io" },
        { filter = "ghost_name", name = "sspp-provide-io" },
        { filter = "ghost_name", name = "sspp-request-io" },
        { filter = "type", type = "straight-rail" },
    }
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
    script.on_event(defines.events.on_pre_surface_deleted, on_surface_cleared)
    script.on_event(defines.events.on_surface_renamed, on_surface_renamed)

    script.on_event(defines.events.on_runtime_mod_setting_changed, on_runtime_mod_setting_changed)

    script.on_init(on_init)
    script.on_load(on_load)
end

--------------------------------------------------------------------------------

return main
