---@meta _
-- The tooltip data hooks, as far as Core uses them (LOG-R80), which Ketho's vscode-wow-api annotations
-- (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never loaded by the game, and
-- excluded from luacheck. Source: Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua.

TooltipDataProcessor = {}

--- Every tooltip type, as a key for the Add* calls.
TooltipDataProcessor.AllTypes = "ALL"

--- Adds `func` to run after a tooltip of `tooltipType` is filled from its data, with the tooltip and that data. An
--- addon's call runs insecurely, through securecallfunction.
---@param tooltipType Enum.TooltipDataType|"ALL"
---@param func fun(tooltip: table, data: TooltipData): boolean?
function TooltipDataProcessor.AddTooltipPostCall(tooltipType, func) end
