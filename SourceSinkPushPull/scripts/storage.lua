-- SSPP by jagoly

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
---@field public item_inactivity_ticks integer?
---@field public fluid_inactivity_ticks integer?
---@field public stations_per_tick integer?

--------------------------------------------------------------------------------

---@class (exact) Network
---@field public surface LuaSurface
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

---@class (exact) Station
---@field public network NetworkName
---@field public stop LuaEntity
---@field public general_io LuaEntity
---@field public total_deliveries integer
---@field public hauler HaulerId?
---@field public minimum_active_count integer?
---@field public bufferless_dispatch true?
---@field public provide StationProvide?
---@field public request StationRequest?

---@class (exact) StationProvide
---@field public comb LuaEntity
---@field public items {[ItemKey]: ProvideItem}
---@field public deliveries {[ItemKey]: HaulerId[]}
---@field public hidden_combs LuaEntity[]
---@field public counts {[ItemKey]: integer}
---@field public modes {[ItemKey]: ItemMode}

---@class (exact) StationRequest
---@field public comb LuaEntity
---@field public items {[ItemKey]: RequestItem}
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

---@alias GuiStyleMods LuaStyle|{[string]: nil}
---@alias GuiElemMods LuaGuiElement|{[string]: nil}

---@class (exact) GuiHandler
---@field public [defines.events.on_gui_checked_state_changed] fun(event: EventData.on_gui_checked_state_changed)?
---@field public [defines.events.on_gui_click] fun(event: EventData.on_gui_click)?
---@field public [defines.events.on_gui_closed] fun(event: EventData.on_gui_closed)?
---@field public [defines.events.on_gui_confirmed] fun(event: EventData.on_gui_confirmed)?
---@field public [defines.events.on_gui_elem_changed] fun(event: EventData.on_gui_elem_changed)?
---@field public [defines.events.on_gui_location_changed] fun(event: EventData.on_gui_location_changed)?
---@field public [defines.events.on_gui_opened] fun(event: EventData.on_gui_opened)?
---@field public [defines.events.on_gui_selected_tab_changed] fun(event: EventData.on_gui_selected_tab_changed)?
---@field public [defines.events.on_gui_selection_state_changed] fun(event: EventData.on_gui_selection_state_changed)?
---@field public [defines.events.on_gui_switch_state_changed] fun(event: EventData.on_gui_switch_state_changed)?
---@field public [defines.events.on_gui_text_changed] fun(event: EventData.on_gui_text_changed)?
---@field public [defines.events.on_gui_value_changed] fun(event: EventData.on_gui_value_changed)?

---@class (exact) GuiElemDef : LuaGuiElement.add_param.button|LuaGuiElement.add_param.camera|LuaGuiElement.add_param.checkbox|LuaGuiElement.add_param.choose_elem_button|LuaGuiElement.add_param.drop_down|LuaGuiElement.add_param.flow|LuaGuiElement.add_param.frame|LuaGuiElement.add_param.line|LuaGuiElement.add_param.list_box|LuaGuiElement.add_param.minimap|LuaGuiElement.add_param.progressbar|LuaGuiElement.add_param.radiobutton|LuaGuiElement.add_param.scroll_pane|LuaGuiElement.add_param.slider|LuaGuiElement.add_param.sprite|LuaGuiElement.add_param.sprite_button|LuaGuiElement.add_param.switch|LuaGuiElement.add_param.tab|LuaGuiElement.add_param.table|LuaGuiElement.add_param.text_box|LuaGuiElement.add_param.textfield
---@field public elem_mods GuiElemMods?
---@field public style_mods GuiStyleMods?
---@field public drag_target string?
---@field public handler GuiHandler?
---@field public children GuiElemDef[]?

--------------------------------------------------------------------------------

---@type SourceSinkPushPull.Storage
storage = storage

---@type SourceSinkPushPull.ModSettings
mod_settings = {}
