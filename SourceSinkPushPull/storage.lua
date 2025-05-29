-- SSPP by jagoly

---@meta

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
---@alias NetworkJob NetworkJob.Fuel|NetworkJob.Pickup|NetworkJob.Dropoff|NetworkJob.Combined
---@alias GuiRoot GuiRoot.Network|GuiRoot.Station|GuiRoot.Hauler

---@class (exact) SourceSinkPushPull.Storage
---@field public tick_state TickState
---@field public entities {[uint]: LuaEntity}
---@field public stop_comb_ids {[uint]: uint[]}
---@field public comb_stop_ids {[uint]: uint[]}
---@field public networks {[NetworkName]: Network}
---@field public stations {[StationId]: Station}
---@field public haulers {[HaulerId]: Hauler}
---@field public player_guis {[PlayerId]: GuiRoot}
---@field public poll_stations StationId[]
---@field public request_done_items NetworkItemKey[]
---@field public liquidate_items NetworkItemKey[]
---@field public provide_done_items NetworkItemKey[]
---@field public dispatch_items NetworkItemKey[]
---@field public buffer_items NetworkItemKey[]
---@field public disabled_items {[NetworkItemKey]: true?}

--------------------------------------------------------------------------------

---@class (exact) Network
---@field public surface LuaSurface?
---@field public classes {[ClassName]: NetworkClass}
---@field public items {[ItemKey]: NetworkItem}
---@field public job_index_counter JobIndex
---@field public jobs {[JobIndex]: NetworkJob}
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

---@class (exact) NetworkClass
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

---@class (exact) NetworkJob.Abstract
---@field public hauler HaulerId
---@field public start_tick MapTick
---@field public finish_tick MapTick?
---@field public abort_tick MapTick?

---@class (exact) NetworkJob.Fuel : NetworkJob.Abstract
---@field public type "FUEL"
---@field public fuel_stop LuaEntity?
---@field public fuel_arrive_tick MapTick?

---@class (exact) NetworkJob.Pickup : NetworkJob.Abstract
---@field public type "PICKUP"
---@field public item ItemKey
---@field public provide_stop LuaEntity?
---@field public target_count integer?
---@field public provide_arrive_tick MapTick?

---@class (exact) NetworkJob.Dropoff : NetworkJob.Abstract
---@field public type "DROPOFF"
---@field public item ItemKey
---@field public request_stop LuaEntity?
---@field public loaded_count integer?
---@field public request_arrive_tick MapTick?

---@class (exact) NetworkJob.Combined : NetworkJob.Abstract
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

---@class (exact) GhostStation
---@field public stop GhostStationStop
---@field public general GhostStationGeneral
---@field public provide GhostStationProvide?
---@field public request GhostStationRequest?
---@field public unit_numbers {[uint]: true?}

---@class (exact) GhostStationStop
---@field public entity LuaEntity
---@field public custom_name boolean
---@field public disabled boolean
---@field public bufferless boolean
---@field public inactivity boolean

---@class (exact) GhostStationGeneral
---@field public comb LuaEntity
---@field public network NetworkName

---@class (exact) GhostStationProvide
---@field public comb LuaEntity
---@field public items {[ItemKey]: ProvideItem}

---@class (exact) GhostStationRequest
---@field public comb LuaEntity
---@field public items {[ItemKey]: RequestItem}

---@class (exact) Station : GhostStation
---@field public provide StationProvide?
---@field public request StationRequest?
---@field public total_deliveries integer
---@field public hauler HaulerId?
---@field public minimum_active_count integer?
---@field public bufferless_dispatch true?

---@class (exact) StationProvide : GhostStationProvide
---@field public deliveries {[ItemKey]: HaulerId[]}
---@field public hidden_combs LuaEntity[]
---@field public counts {[ItemKey]: integer}
---@field public modes {[ItemKey]: ItemMode}

---@class (exact) StationRequest : GhostStationRequest
---@field public deliveries {[ItemKey]: HaulerId[]}
---@field public hidden_combs LuaEntity[]
---@field public counts {[ItemKey]: integer}
---@field public modes {[ItemKey]: ItemMode}

---@class (exact) StationItem
---@field public mode ItemMode
---@field public throughput number
---@field public latency number

---@class (exact) ProvideItem : StationItem
---@field public granularity integer

---@class (exact) RequestItem : StationItem

--------------------------------------------------------------------------------

---@class (exact) Hauler
---@field public train LuaTrain
---@field public network NetworkName
---@field public class ClassName
---@field public job JobIndex?
---@field public to_depot (""|ItemKey)?
---@field public at_depot (""|ItemKey)?
---@field public status HaulerStatus

---@class (exact) HaulerStatus
---@field public message LocalisedString
---@field public item ItemKey?
---@field public stop LuaEntity?

--------------------------------------------------------------------------------

---@class (exact) GuiChild
---@field public dimmer LuaGuiElement
---@field public elements {[string]: LuaGuiElement}
---@field public child GuiChild?

---@class (exact) GuiRoot.Abstract
---@field public elements {[string]: LuaGuiElement}
---@field public child GuiChild?

---@class (exact) GuiRoot.Network : GuiRoot.Abstract
---@field public type "NETWORK"
---@field public default_network_name NetworkName
---@field public network_name NetworkName
---@field public network Network
---@field public class_context GuiTableContext<GuiRoot.Network, ClassName, NetworkClass>
---@field public item_context GuiTableContext<GuiRoot.Network, ItemKey, NetworkItem>
---@field public job_context GuiTableContext<GuiRoot.Network, JobIndex, NetworkJob>
---@field public expanded_class ClassName?
---@field public expanded_stations_item ItemKey?
---@field public expanded_haulers_item ItemKey?
---@field public expanded_job JobIndex?

---@class (exact) GuiRoot.Station : GuiRoot.Abstract
---@field public type "STATION"
---@field public unit_number uint
---@field public ghost GhostStation?
---@field public station Station?
---@field public provide_context GuiTableContext<GuiRoot.Station, ItemKey, ProvideItem>?
---@field public request_context GuiTableContext<GuiRoot.Station, ItemKey, RequestItem>?

---@class (exact) GuiRoot.Hauler : GuiRoot.Abstract
---@field public type "HAULER"
---@field public train_id uint
---@field public train LuaTrain?

--------------------------------------------------------------------------------

-- yes, this really needs to be this ugly

---@class (exact) GuiTableContext<Root, Key, Object> : {
--- root: Root,
--- rows: { key: Key?, match: boolean?, cells: LuaGuiElement[]? }[],
--- indices: {[Key]: integer},
--- objects: {[Key]: Object},
---}
---@field table LuaGuiElement
---@field reverse true?
---@field row_limit integer?
---@field query table?

--------------------------------------------------------------------------------

---@type SourceSinkPushPull.Storage
storage = storage
