if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What the Tackle Board tells Core, and the celebrated set it keeps (logic/Seams.lua): the moments, Write-up and
-- summary line logic/Moments.lua builds (TKB-R83–R87), the Coins logic/Projection.lua reports (TKB-R63), each through
-- the Module handle (CORE-R12), and the celebrated set in PagleTackleBoardDB (TKB-R83). An inert Module (no handle,
-- no DB, CORE-R13) tells Core nothing.

-- How long a goal's moment waits for its Species name (TKB-R36) before it is raised with "…".
local NAME_WAIT_SECONDS = 1

local held = {} -- the remakes of goal moments waiting for a Species name, in the order raised

-- Whether a moment's text still shows a name the client didn't have (TKB-R36).
---@param moment PagleMoment
---@return boolean
local function waitsForName(moment)
	return type(moment.text) == "string" and moment.text:find(ns.L.NAME_UNKNOWN, 1, true) ~= nil
end

-- Raises each held moment, made again, whose name has arrived; every one when `all` (its wait is over).
---@param all boolean
local function release(all)
	local module, waiting = ns.Module, {}
	for _, remake in ipairs(held) do
		local moment = remake()
		if all or not waitsForName(moment) then
			if module then
				module:RaiseMoment(moment)
			end
		else
			waiting[#waiting + 1] = remake
		end
	end
	held = waiting
end

--- Raises a moment for the Tackle Board (ANN-R60–R63), with a Module handle. A goal's moment whose text still reads
--- "…" for a Species name (TKB-R36) and that comes with `remake` waits, made again when a name arrives ("names"
--- redraw), and raised as it stands after NAME_WAIT_SECONDS, so it never keeps "…" when the client loads the name.
---@param moment PagleMoment
---@param remake (fun(): PagleMoment)?
function ns.RaiseMoment(moment, remake)
	local module = ns.Module
	if not module then
		return
	end
	if remake and waitsForName(moment) then
		held[#held + 1] = remake
		if #held == 1 then
			-- A one-shot ticker, as the reset timer (adapter/LiveStep.lua).
			C_Timer.NewTicker(NAME_WAIT_SECONDS, function(ticker)
				ticker:Cancel()
				release(true)
			end, 1)
		end
		return
	end
	module:RaiseMoment(moment)
end

ns.OnRedraw(function(reason)
	if reason == "names" and #held > 0 then
		release(false)
	end
end)

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

--- Reports lifetime Coins to Core (TKB-R63, SHOP-R2): the projection's `coins` with M:ReportCoinsEarned, 0 before
--- Start, so a new dev log's unstarted board (TKB-R197) replaces the last log's total; that shows nowhere (TKB-R2).
--- Nothing without a Module handle (an inert Module, CORE-R13).
function ns.ReportCoins()
	local module = ns.Module
	if module then
		module:ReportCoinsEarned(ns.State().coins)
	end
end

--- Reports lifetime Activity XP to Core (TKB-R65, AXP-R2): the projection's `xp` with M:ReportXPEarned, on
--- ns.ReportCoins' timing, so a new dev log's unstarted board reports 0 too. No moment shows it; a level it brings is
--- the Ledger's (LED-R39). Nothing without a Module handle (an inert Module, CORE-R13).
function ns.ReportXP()
	local module = ns.Module
	if module then
		module:ReportXPEarned(ns.State().xp)
	end
end
