-- SSPP by jagoly

--------------------------------------------------------------------------------

---@alias NetworkName string
---@alias ClassName string
---@alias ItemKey string
---@alias NetworkItemKey string
---@alias StationId uint
---@alias HaulerId uint
---@alias PlayerId uint
---@alias TickState "INITIAL"|"POLL"|"LIQUIDATE"|"DISPATCH"|"PROVIDE_DONE"|"REQUEST_DONE"

---@class (exact) SourceSinkPushPull.Storage
---@field public tick_state TickState
---@field public entities {[uint]: LuaEntity}
---@field public stop_comb_ids {[uint]: uint[]}
---@field public comb_stop_ids {[uint]: uint[]}
---@field public networks {[NetworkName]: Network}
---@field public stations {[StationId]: Station}
---@field public haulers {[HaulerId]: Hauler}
---@field public player_states {[PlayerId]: PlayerState}
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
---@field public depot_haulers {[ClassName]: HaulerId[]}
---@field public liquidate_haulers {[ItemKey]: HaulerId[]}
---@field public push_tickets {[ItemKey]: StationId[]}
---@field public provide_tickets {[ItemKey]: StationId[]}
---@field public pull_tickets {[ItemKey]: StationId[]}
---@field public request_tickets {[ItemKey]: StationId[]}
---@field public provide_done_tickets {[ItemKey]: StationId[]}
---@field public request_done_tickets {[ItemKey]: StationId[]}

---@class (exact) Class
---@field public list_index integer
---@field public item_slot_capacity integer?
---@field public fluid_capacity integer?
---@field public depot_name string
---@field public fueler_name string

---@class (exact) NetworkItem
---@field public list_index integer
---@field public name string
---@field public quality string?
---@field public class ClassName
---@field public delivery_size integer
---@field public delivery_time number

--------------------------------------------------------------------------------

---@class (exact) Station
---@field public stop LuaEntity
---@field public general_io LuaEntity
---@field public provide_io LuaEntity?
---@field public request_io LuaEntity?
---@field public provide_items {[ItemKey]: ProvideItem}?
---@field public request_items {[ItemKey]: RequestItem}?
---@field public provide_deliveries {[ItemKey]: HaulerId[]}?
---@field public request_deliveries {[ItemKey]: HaulerId[]}?
---@field public provide_hidden_combs LuaEntity[]?
---@field public request_hidden_combs LuaEntity[]?
---@field public total_deliveries integer
---@field public hauler HaulerId?

---@class (exact) ProvideItem
---@field public list_index integer
---@field public push boolean
---@field public throughput number
---@field public latency number
---@field public granularity integer

---@class (exact) RequestItem
---@field public list_index integer
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
---@field public to_fuel true?
---@field public to_depot true?
---@field public to_liquidate ItemKey?
---@field public status LocalisedString
---@field public status_item ItemKey?
---@field public status_stop LuaEntity?

---@class (exact) HaulerToStation
---@field public item ItemKey
---@field public station StationId

--------------------------------------------------------------------------------

---@class (exact) StationParts
---@field public ids {[uint]: true?}
---@field public stop LuaEntity
---@field public general_io LuaEntity
---@field public provide_io LuaEntity?
---@field public request_io LuaEntity?

---@class (exact) PlayerState
---@field public network NetworkName
---@field public entity LuaEntity?
---@field public parts StationParts?
---@field public train LuaTrain?
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
    storage.player_states = {}
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
        depot_haulers = {},
        liquidate_haulers = {},
        push_tickets = {},
        provide_tickets = {},
        pull_tickets = {},
        request_tickets = {},
        provide_done_tickets = {},
        request_done_tickets = {},
    }

    -- storage.networks[surface.name].classes = {
    --     ["20 slots"] = { list_index = 1, name = "20 slots", item_slot_capacity = 20, depot_name = "Depot", fueler_name = "Fuel" },
    --     ["25k units"] = { list_index = 2, name = "25k units", fluid_capacity = 25000, depot_name = "Depot", fueler_name = "Fuel" },
    -- }
    -- storage.networks[surface.name].items = {
    --     ["iron-plate:normal"] = { list_index = 1, name = "iron-plate", quality = "normal", delivery_size = 2000, delivery_time = 60, class = "20 slots" },
    --     ["coal:normal"] = { list_index = 2, name = "coal", quality = "normal", delivery_size = 1000, delivery_time = 60, class = "20 slots" },
    --     ["stone:normal"] = { list_index = 3, name = "stone", quality = "normal", delivery_size = 1000, delivery_time = 80, class = "20 slots" },
    --     ["water"] = { list_index = 4, name = "water", delivery_size = 25000, delivery_time = 60, class = "25k units" },
    -- }
end

function populate_mod_settings()
    mod_settings.stations_per_tick = settings.global["sspp-stations-per-tick"].value --[[@as boolean]]
end
