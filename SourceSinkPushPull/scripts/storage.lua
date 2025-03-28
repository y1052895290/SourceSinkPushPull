-- SSPP by jagoly

--------------------------------------------------------------------------------

---@enum StopFlag
e_stop_flags = { custom_name = 1, disable = 2, bufferless = 4 }

---@enum TrainColor
e_train_colors = { depot = 1, fuel = 2, provide = 3, request = 4, liquidate = 5 }

--------------------------------------------------------------------------------

---@alias NetworkName string
---@alias ClassName string
---@alias ItemKey string
---@alias NetworkItemKey string
---@alias ItemMode 1|2|3|4|5|6|7
---@alias StationId uint
---@alias HaulerId uint
---@alias PlayerId uint
---@alias JobIndex integer
---@alias TickState "INITIAL"|"POLL"|"REQUEST_DONE"|"LIQUIDATE"|"PROVIDE_DONE"|"DISPATCH"|"BUFFER"
---@alias Job Job.Fuel|Job.Pickup|Job.Dropoff|Job.Combined
---@alias PlayerGui PlayerGui.Network|PlayerGui.Station|PlayerGui.Hauler

---@class (exact) SourceSinkPushPull.Storage
---@field public tick_state TickState
---@field public entities {[uint]: LuaEntity}
---@field public stop_comb_ids {[uint]: uint[]}
---@field public comb_stop_ids {[uint]: uint[]}
---@field public networks {[NetworkName]: Network}
---@field public stations {[StationId]: Station}
---@field public haulers {[HaulerId]: Hauler}
---@field public player_guis {[PlayerId]: PlayerGui}
---@field public poll_stations StationId[]
---@field public request_done_items NetworkItemKey[]
---@field public liquidate_items NetworkItemKey[]
---@field public provide_done_items NetworkItemKey[]
---@field public dispatch_items NetworkItemKey[]
---@field public buffer_items NetworkItemKey[]
---@field public disabled_items {[NetworkItemKey]: true?}

---@class (exact) SourceSinkPushPull.ModSettings
---@field public auto_paint_trains boolean?
---@field public train_colors {[TrainColor]: Color}?
---@field public default_train_limit integer?
---@field public stations_per_tick integer?

--------------------------------------------------------------------------------

---@class (exact) Network
---@field public surface LuaSurface
---@field public classes {[ClassName]: Class}
---@field public items {[ItemKey]: NetworkItem}
---@field public job_index_counter JobIndex
---@field public jobs {[JobIndex]: Job}
---@field public buffer_haulers {[ItemKey]: HaulerId[]}
---@field public provide_haulers {[ItemKey]: HaulerId[]}
---@field public request_haulers {[ItemKey]: HaulerId[]}
---@field public fuel_haulers {[ClassName]: HaulerId[]}
---@field public to_depot_haulers {[ClassName]: HaulerId[]}
---@field public at_depot_haulers {[ClassName]: HaulerId[]}
---@field public to_depot_liquidate_haulers {[ItemKey]: HaulerId[]}
---@field public at_depot_liquidate_haulers {[ItemKey]: HaulerId[]}
---@field public push_tickets {[ItemKey]: StationId[]}
---@field public provide_tickets {[ItemKey]: StationId[]}
---@field public pull_tickets {[ItemKey]: StationId[]}
---@field public request_tickets {[ItemKey]: StationId[]}
---@field public provide_done_tickets {[ItemKey]: StationId[]}
---@field public request_done_tickets {[ItemKey]: StationId[]}
---@field public buffer_tickets {[ItemKey]: StationId[]}

---@class (exact) Class
---@field public depot_name string
---@field public fueler_name string
---@field public bypass_depot boolean

---@class (exact) NetworkItem
---@field public name string
---@field public quality string?
---@field public class ClassName
---@field public delivery_size integer
---@field public delivery_time number

--------------------------------------------------------------------------------

---@class (exact) Job.Abstract
---@field public hauler HaulerId
---@field public start_tick MapTick
---@field public finish_tick MapTick?
---@field public abort_tick MapTick?

---@class (exact) Job.Fuel : Job.Abstract
---@field public type "FUEL"
---@field public fuel_stop LuaEntity?
---@field public fuel_arrive_tick MapTick?

---@class (exact) Job.Pickup : Job.Abstract
---@field public type "PICKUP"
---@field public item ItemKey
---@field public provide_stop LuaEntity?
---@field public target_count integer?
---@field public provide_arrive_tick MapTick?

---@class (exact) Job.Dropoff : Job.Abstract
---@field public type "DROPOFF"
---@field public item ItemKey
---@field public request_stop LuaEntity?
---@field public loaded_count integer?
---@field public request_arrive_tick MapTick?

---@class (exact) Job.Combined : Job.Abstract
---@field public type "COMBINED"
---@field public item ItemKey
---@field public provide_stop LuaEntity?
---@field public target_count integer?
---@field public provide_arrive_tick MapTick?
---@field public provide_done_tick MapTick?
---@field public request_stop LuaEntity?
---@field public loaded_count integer?
---@field public request_arrive_tick MapTick?

--------------------------------------------------------------------------------

---@class (exact) Station
---@field public network NetworkName
---@field public stop LuaEntity
---@field public general_io LuaEntity
---@field public provide_io LuaEntity?
---@field public request_io LuaEntity?
---@field public provide_items {[ItemKey]: ProvideItem}?
---@field public request_items {[ItemKey]: RequestItem}?
---@field public provide_counts {[ItemKey]: integer}?
---@field public request_counts {[ItemKey]: integer}?
---@field public provide_modes {[ItemKey]: ItemMode}?
---@field public request_modes {[ItemKey]: ItemMode}?
---@field public provide_deliveries {[ItemKey]: HaulerId[]}?
---@field public request_deliveries {[ItemKey]: HaulerId[]}?
---@field public provide_hidden_combs LuaEntity[]?
---@field public request_hidden_combs LuaEntity[]?
---@field public total_deliveries integer
---@field public hauler HaulerId?
---@field public minimum_active_count integer?
---@field public bufferless_dispatch true?

---@class (exact) ProvideItem
---@field public mode ItemMode
---@field public throughput number
---@field public latency number
---@field public granularity integer

---@class (exact) RequestItem
---@field public mode ItemMode
---@field public throughput number
---@field public latency number

--------------------------------------------------------------------------------

---@class (exact) Hauler
---@field public train LuaTrain
---@field public network NetworkName
---@field public class ClassName
---@field public to_depot (""|ItemKey)?
---@field public at_depot (""|ItemKey)?
---@field public job JobIndex?
---@field public status HaulerStatus

---@class (exact) HaulerStatus
---@field public message LocalisedString
---@field public item ItemKey?
---@field public stop LuaEntity?

--------------------------------------------------------------------------------

---@class (exact) StationParts
---@field public ids {[uint]: true?}
---@field public stop LuaEntity
---@field public general_io LuaEntity
---@field public provide_io LuaEntity?
---@field public request_io LuaEntity?

---@class (exact) PlayerGui.Abstract
---@field public network NetworkName
---@field public elements {[string]: LuaGuiElement}

---@class (exact) PlayerGui.Network : PlayerGui.Abstract
---@field public type "NETWORK"
---@field public history_indices JobIndex[]
---@field public haulers_class ClassName?
---@field public haulers_item ItemKey?
---@field public stations_item ItemKey?
---@field public expanded_job JobIndex?
---@field public popup_elements {[string]: LuaGuiElement}?

---@class (exact) PlayerGui.Station : PlayerGui.Abstract
---@field public type "STATION"
---@field public unit_number uint
---@field public parts StationParts?

---@class (exact) PlayerGui.Hauler : PlayerGui.Abstract
---@field public type "HAULER"
---@field public train_id uint
---@field public train LuaTrain

--------------------------------------------------------------------------------

---@type SourceSinkPushPull.Storage
storage = storage

---@type SourceSinkPushPull.ModSettings
mod_settings = {}

--------------------------------------------------------------------------------

function init_storage()
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
end

---@param surface LuaSurface
function init_network(surface)
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

---@param name string
---@return Color
local function get_rgb_setting(name)
    local rgba = settings.global[name].value --[[@as Color]]
    local a = rgba.a
    return { r = rgba.r * a, g = rgba.g * a, b = rgba.b * a, a = 1.0 }
end

function populate_mod_settings()
    mod_settings.auto_paint_trains = settings.global["sspp-auto-paint-trains"].value --[[@as boolean]]
    mod_settings.train_colors = {
        [e_train_colors.depot] = get_rgb_setting("sspp-depot-color"),
        [e_train_colors.fuel] = get_rgb_setting("sspp-fuel-color"),
        [e_train_colors.provide] = get_rgb_setting("sspp-provide-color"),
        [e_train_colors.request] = get_rgb_setting("sspp-request-color"),
        [e_train_colors.liquidate] = get_rgb_setting("sspp-liquidate-color"),
    }
    mod_settings.default_train_limit = settings.global["sspp-default-train-limit"].value --[[@as integer]]
    mod_settings.stations_per_tick = settings.global["sspp-stations-per-tick"].value --[[@as integer]]
end
