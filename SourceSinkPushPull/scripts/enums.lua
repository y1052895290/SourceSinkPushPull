-- SSPP by jagoly

local enums = {}

--------------------------------------------------------------------------------

---@enum StopFlag
enums.stop_flags = { custom_name = 1, disabled = 2, bufferless = 4, inactivity = 8 }

---@enum TrainColor
enums.train_colors = { depot = 1, fuel = 2, provide = 3, request = 4, liquidate = 5 }

--------------------------------------------------------------------------------

return enums
