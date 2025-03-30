-- SSPP by jagoly

local flib_migration = require("__flib__.migration")

local lib = require("__SourceSinkPushPull__.scripts.lib")
local cmds = require("__SourceSinkPushPull__.scripts.cmds")

--------------------------------------------------------------------------------

local migrations = {
    ["0.3.2"] = function()
        for _, network in pairs(storage.networks) do
            for _, class in pairs(network.classes) do
                class.list_index = nil
            end
            for _, item in pairs(network.items) do
                item.list_index = nil
            end
        end
    end,
    ["0.3.4"] = function()
        for _, station in pairs(storage.stations) do
            if station.stop.valid then
                station.stop.trains_limit = 4294967295
            end
        end
    end,
    ["0.3.5"] = function()
        for _, station in pairs(storage.stations) do
            if station.stop.valid then
                if station.provide_items then
                    for _, item in pairs(station.provide_items) do
                        item.list_index = nil
                    end
                end
                if station.request_items then
                    for _, item in pairs(station.request_items) do
                        item.list_index = nil
                    end
                end
            end
        end
        for _, network in pairs(storage.networks) do
            for _, class in pairs(network.classes) do
                class.item_slot_capacity = nil
                class.fluid_capacity = nil
            end
        end
    end,
    ["0.3.9"] = function()
        for _, station in pairs(storage.stations) do
            if station.stop.valid then
                if station.stop.trains_limit == 4294967295 then
                    station.stop.trains_limit = 10
                end
            end
        end
    end,
    ["0.3.12"] = function()
        for _, station in pairs(storage.stations) do
            if station.provide_items then
                for _, item in pairs(station.provide_items) do
                    if item.mode == nil then
                        item.mode = item.push and 5 or 2
                        item.push = nil
                    end
                end
            end
            if station.request_items then
                for _, item in pairs(station.request_items) do
                    if item.mode == nil then
                        item.mode = item.pull and 5 or 2
                        item.pull = nil
                    end
                end
            end
        end
    end,
    ["0.3.18"] = function()
        for _, network in pairs(storage.networks) do
            if not network.buffer_haulers then
                network.buffer_haulers = {}
            end
        end
    end,
    ["0.3.23"] = function()
        local function try_init_job(network, hauler_id, job_type)
            local hauler = storage.haulers[hauler_id]
            if not hauler.train.valid then return nil, nil end
            local job = { hauler = hauler_id, type = job_type, start_tick = game.tick } ---@type Job
            local job_index = network.job_index_counter + 1
            hauler.job = job_index
            network.job_index_counter = job_index
            network.jobs[job_index] = job
            return job, hauler
        end
        for _, network in pairs(storage.networks) do
            if not network.job_index_counter then
                network.job_index_counter = 0
                network.jobs = {}
                for item_key, hauler_ids in pairs(network.buffer_haulers) do
                    for _, hauler_id in pairs(hauler_ids) do
                        local job, hauler = try_init_job(network, hauler_id, item_key)
                        if job then ---@cast hauler -nil
                            job.provide_stop = storage.entities[hauler.to_provide.station]
                            if hauler.to_provide.phase ~= "TRAVEL" then
                                job.target_count = network.items[item_key].delivery_size
                                job.provide_arrive_tick = game.tick
                                if hauler.to_provide.phase == "DONE" then job.provide_done_tick = game.tick end
                            end
                        end
                    end
                end
                for item_key, hauler_ids in pairs(network.provide_haulers) do
                    for _, hauler_id in pairs(hauler_ids) do
                        local job, hauler = try_init_job(network, hauler_id, item_key)
                        if job then ---@cast hauler -nil
                            job.provide_stop = storage.entities[hauler.to_provide.station]
                            if hauler.to_provide.phase ~= "TRAVEL" then
                                job.target_count = network.items[item_key].delivery_size
                                job.provide_arrive_tick = game.tick
                                if hauler.to_provide.phase == "DONE" then job.provide_done_tick = game.tick end
                            end
                        end
                    end
                end
                for item_key, hauler_ids in pairs(network.request_haulers) do
                    for _, hauler_id in pairs(hauler_ids) do
                        local job, hauler = try_init_job(network, hauler_id, item_key)
                        if job then ---@cast hauler -nil
                            job.request_stop = storage.entities[hauler.to_request.station]
                            if hauler.to_request.phase ~= "TRAVEL" then
                                job.loaded_count = lib.get_train_item_count(hauler.train, network.items[item_key].name, network.items[item_key].quality)
                                job.request_arrive_tick = game.tick
                                if hauler.to_request.phase == "DONE" then job.finish_tick = game.tick end
                            end
                        end
                    end
                end
                for _, hauler_ids in pairs(network.fuel_haulers) do
                    for _, hauler_id in pairs(hauler_ids) do
                        local job, hauler = try_init_job(network, hauler_id, "FUEL")
                        if job then ---@cast hauler -nil
                            if hauler.to_fuel == "TRANSFER" then
                                job.fuel_stop = hauler.train.station
                                job.fuel_arrive_tick = game.tick
                            end
                        end
                    end
                end
            end
        end
    end,
    ["0.4.0"] = function()
        -- because the job changes in this version would be annoying to migrate properly, we just force a reboot if there are any active jobs
        for _, network in pairs(storage.networks) do
            network.jobs = {}
            network.job_index_counter = 0
        end
        for _, station in pairs(storage.stations) do
            if station.provide_minimum_active_count or station.request_minimum_active_count then
                station.minimum_active_count = station.provide_minimum_active_count or station.request_minimum_active_count
                station.provide_minimum_active_count, station.request_minimum_active_count = nil, nil
            end
            if station.provide_io then
                station.provide = {
                    comb = station.provide_io, items = station.provide_items, deliveries = station.provide_deliveries, hidden_combs = station.provide_hidden_combs,
                    counts = {}, modes = {},
                }
                station.provide_io, station.provide_items, station.provide_deliveries, station.provide_hidden_combs = nil, nil, nil, nil
                station.provide_counts, station.provide_modes = nil, nil
            end
            if station.request_io then
                station.request = {
                    comb = station.request_io, items = station.request_items, deliveries = station.request_deliveries, hidden_combs = station.request_hidden_combs,
                    counts = {}, modes = {},
                }
                station.request_io, station.request_items, station.request_deliveries, station.request_hidden_combs = nil, nil, nil, nil
                station.request_counts, station.request_modes = nil, nil
            end
        end
        for _, hauler in pairs(storage.haulers) do
            if hauler.status[1] then
                hauler.status = { message = hauler.status[1], item = hauler.status_item, stop = hauler.status_stop }
                hauler.status_item, hauler.status_stop = nil, nil
            end
            if hauler.job or hauler.to_fuel or hauler.to_provide or hauler.to_request then
                hauler.job = -1 -- force reboot
                hauler.to_fuel, hauler.to_provide, hauler.to_request = nil, nil, nil
            end
        end
    end,
}

--------------------------------------------------------------------------------

---@param data ConfigurationChangedData
local function on_configuration_changed(data)
    flib_migration.on_config_changed(data, migrations)

    local is_item_key_invalid = lib.is_item_key_invalid

    -- remove all invalid items and jobs from networks
    for _, network in pairs(storage.networks) do
        for item_key, _ in pairs(network.items) do
            if is_item_key_invalid(item_key) then network.items[item_key] = nil end
        end
        for job_index, job in pairs(network.jobs) do
            if job.type ~= "FUEL" and is_item_key_invalid(job.item) then network.jobs[job_index] = nil end
        end
    end

    -- check entities
    for _, entity in pairs(storage.entities) do
        if not entity.valid then goto reboot end
    end
    -- check station items
    for _, station in pairs(storage.stations) do
        if station.provide then
            for item_key, _ in pairs(station.provide.items) do
                if is_item_key_invalid(item_key) then goto reboot end
            end
        end
        if station.request then
            for item_key, _ in pairs(station.request.items) do
                if is_item_key_invalid(item_key) then goto reboot end
            end
        end
    end
    -- check hauler trains / items / jobs
    for _, hauler in pairs(storage.haulers) do
        if not hauler.train.valid then goto reboot end
        if hauler.status.item and is_item_key_invalid(hauler.status.item) then goto reboot end
        if hauler.to_depot and hauler.to_depot ~= "" and is_item_key_invalid(hauler.to_depot) then goto reboot end
        if hauler.at_depot and hauler.at_depot ~= "" and is_item_key_invalid(hauler.at_depot) then goto reboot end
        if hauler.job and not storage.networks[hauler.network].jobs[hauler.job] then goto reboot end
    end
    goto skip_reboot

    ::reboot::
    cmds.sspp_reboot()
    ::skip_reboot::

    storage.tick_state = "INITIAL"
end

script.on_configuration_changed(on_configuration_changed)
