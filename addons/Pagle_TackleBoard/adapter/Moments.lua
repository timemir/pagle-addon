if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What the Tackle Board tells Core, and the celebrated set it keeps (logic/Seams.lua): the moments, Write-up and
-- summary line logic/Moments.lua builds (TKB-R83–R87), the Coins logic/Projection.lua reports (TKB-R63), each through
-- the Module handle (CORE-R12), and the celebrated set in PagleTackleBoardDB (TKB-R83). An inert Module (no handle,
-- no DB, CORE-R13) tells Core nothing.

--- Raises a moment for the Tackle Board (ANN-R60–R63), with a Module handle.
---@param moment PagleMoment
function ns.RaiseMoment(moment)
	local module = ns.Module
	if module then
		module:RaiseMoment(moment)
	end
end

--- Raises a Write-up section (ANN-R60), with a Module handle.
---@param section { heading: string, lines: string[] }
function ns.RaiseWriteUp(section)
	local module = ns.Module
	if module then
		module:RaiseWriteUp(section)
	end
end

--- Sets the board's line on the Session summary (TKB-R87), with a Module handle.
---@param line string
function ns.SetSummaryLine(line)
	local module = ns.Module
	if module then
		module:SetSummaryLine("board", line)
	end
end

--- The celebrated set (TKB-R83): PagleTackleBoardDB.global.celebrated, which only grows; nil while the Module is
--- inert (no handle or no DB).
---@return { goals: table<string, true>, titles: table<string, true> }?
function ns.Celebrated()
	local db = ns.db
	return ns.Module and db and db.global.celebrated or nil
end

--- Reports lifetime Coins to Core (TKB-R63, SHOP-R2): the projection's `coins` with M:ReportCoinsEarned. Nothing
--- before Start (TKB-R2: silent until started) or without a Module handle (an inert Module, CORE-R13).
function ns.ReportCoins()
	local module = ns.Module
	if module and ns.IsStarted() then
		module:ReportCoinsEarned(ns.State().coins)
	end
end
