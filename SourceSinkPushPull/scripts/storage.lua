-- SSPP by jagoly

--------------------------------------------------------------------------------

---@enum StopFlag
e_stop_flags = { custom_name = 1 }

--------------------------------------------------------------------------------

---@alias NetworkName string
---@alias ClassName string
---@alias ItemKey string
---@alias NetworkItemKey string
---@alias StationId uint
---@alias HaulerId uint
---@alias PlayerId uint
---@alias TickState "INITIAL"|"POLL"|"LIQUIDATE"|"DISPATCH"|"PROVIDE_DONE"|"REQUEST_DONE"
---@alias HaulerPhase "TRAVEL"|"TRANSFER"|"DONE"
---@alias PlayerGui PlayerNetworkGui|PlayerStationGui|PlayerHaulerGui

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
---@field public liquidate_items NetworkItemKey[]
---@field public dispatch_items NetworkItemKey[]
---@field public provide_done_items NetworkItemKey[]
---@field public request_done_items NetworkItemKey[]
---@field public disabled_items {[NetworkItemKey]: true?}

---@class (exact) SourceSinkPushPull.ModSettings
---@field public stations_per_tick integer?

--------------------------------------------------------------------------------

---@class (exact) Network
---@field public surface LuaSurface
---@field public classes {[ClassName]: Class}
---@field public items {[ItemKey]: NetworkItem}
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

---@class (exact) Class
---@field public item_slot_capacity integer?
---@field public fluid_capacity integer?
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
---@field public provide_minimum_active_count integer?
---@field public request_minimum_active_count integer?
---@field public provide_deliveries {[ItemKey]: HaulerId[]}?
---@field public request_deliveries {[ItemKey]: HaulerId[]}?
---@field public provide_hidden_combs LuaEntity[]?
---@field public request_hidden_combs LuaEntity[]?
---@field public total_deliveries integer
---@field public hauler HaulerId?

---@class (exact) ProvideItem
---@field public push boolean
---@field public throughput number
---@field public latency number
---@field public granularity integer

---@class (exact) RequestItem
---@field public pull boolean
---@field public throughput number
---@field public latency number

--------------------------------------------------------------------------------

---@class (exact) Hauler
---@field public train LuaTrain
---@field public network NetworkName
---@field public class ClassName
---@field public to_provide HaulerToStation?
---@field public to_request HaulerToStation?
---@field public to_fuel HaulerPhase?
---@field public to_depot (""|ItemKey)?
---@field public at_depot (""|ItemKey)?
---@field public status LocalisedString
---@field public status_item ItemKey?
---@field public status_stop LuaEntity?

---@class (exact) HaulerToStation
---@field public item ItemKey
---@field public station StationId
---@field public phase HaulerPhase

--------------------------------------------------------------------------------

---@class (exact) StationParts
---@field public ids {[uint]: true?}
---@field public stop LuaEntity
---@field public general_io LuaEntity
---@field public provide_io LuaEntity?
---@field public request_io LuaEntity?

---@class (exact) PlayerNetworkGui
---@field public network NetworkName
---@field public elements {[string]: LuaGuiElement}
---@field public haulers_class ClassName?
---@field public haulers_item ItemKey?
---@field public stations_item ItemKey?

---@class (exact) PlayerStationGui
---@field public network NetworkName
---@field public unit_number uint
---@field public parts StationParts?
---@field public elements {[string]: LuaGuiElement}

---@class (exact) PlayerHaulerGui
---@field public network NetworkName
---@field public train LuaTrain
---@field public elements {[string]: LuaGuiElement}

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
    storage.liquidate_items = {}
    storage.dispatch_items = {}
    storage.provide_done_items = {}
    storage.request_done_items = {}
    storage.disabled_items = {}
end

---@param surface LuaSurface
function init_network(surface)
    storage.networks[surface.name] = {
        surface = surface,
        classes = {},
        items = {},
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
    }
end

function populate_mod_settings()
    mod_settings.stations_per_tick = settings.global["sspp-stations-per-tick"].value --[[@as boolean]]
end
