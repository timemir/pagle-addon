if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts tracker's lines as data (HNT-R76, HNT-R78): pure logic, everything passed in (CORE-R7). The block that
-- shows them, its clicks, its setting and its frame are adapter/Tracker.lua's.

--- Tunables (hunts.md): the Hunts the tracker lists before its "+N more" line (HNT-R76).
ns.TRACKER_SHOWN = 6

--- What the tracker's lines are made from, read by the adapter at each draw.
---@class HuntsTrackerInput
---@field rows HuntRow[]?      -- the pinned rows, sorted as on the board (ns.groups:Rows{ pinnedOnly = true }); nil
--- before the first grouping
---@field anyPinned boolean    -- whether profile.pins holds any Hunt, for the empty line before the first grouping
---@field time integer         -- ns.TimelineNow(): labels count down from now, or from the grouping's time while it is
--- paused, so they freeze with it while restricted (HNT-R43, HNT-R78)
---@field snapshot table       -- one live `Pagle.GetConditions()` (HNT-R50)
---@field zone integer?        -- the live zone's areaID (the snapshot's `zone`)
---@field updating boolean     -- ns.IsUpdating() (HNT-R78)
---@field state HuntsState     -- ns.State()
---@field list HuntList        -- ns.hunts, for names and fixed classes' members
---@field where table<string, HuntWhere>   -- ns.where
---@field sources HuntNameSources          -- ns.names

--- One pinned Hunt's two lines (HNT-R76).
---@class HuntsTrackerHunt
---@field id string
---@field dot HuntGroup                      -- its group, for its dot
---@field first string         -- "{name} · {tracker label}"
---@field second string        -- "{target line} · you're here · {progress}", "you're here" only in its zones

--- The tracker's lines: before the first grouping none, not even the empty line.
---@class HuntsTrackerLines
---@field hunts HuntsTrackerHunt[]   -- at most ns.TRACKER_SHOWN
---@field more integer               -- the pinned Hunts past those, for "+N more"; 0 for no such line
---@field empty boolean              -- nothing pinned: "Pin a Hunt to keep it here."

--- A Hunt's tier progress (HNT-R76, HNT-R78): "{count} / {next unreached threshold}" ("0 / 1" before completion),
--- "all tiers" once every tier is reached, and "updating…" while the projection is updating.
---@param hunt HuntDef
---@param progress HuntProgress? its progress in ns.State(); nil for a Hunt nothing has touched
---@param updating boolean
---@return string
function ns.TrackerProgress(hunt, progress, updating)
	local L = ns.L
	if updating then
		return L.TRACKER_UPDATING
	elseif ns.HuntFinished(progress, hunt) then
		return L.TRACKER_ALL_TIERS
	end
	local reached = progress and #progress.reached or 0
	return L.TRACKER_PROGRESS:format(progress and progress.count or 0, hunt.tiers[reached + 1])
end

-- Whether `zone` is one of `zones` (HNT-R31's zones, ascending).
---@param zones integer[]
---@param zone integer?
---@return boolean
local function among(zones, zone)
	for _, z in ipairs(zones) do
		if z == zone then
			return true
		end
	end
	return false
end

-- One pinned row's two lines (HNT-R76).
---@param row HuntRow
---@param input HuntsTrackerInput
---@return HuntsTrackerHunt
local function huntLines(row, input)
	local L = ns.L
	local hunt, where = row.hunt, input.where[row.id]
	-- The tracker label (HNT-R51) of the row as grouped, counted down from input.time.
	local _, label = ns.HuntLabels(ns.LabelCase(row, where, input.time, input.snapshot))
	local second = { ns.HuntTargetLine(hunt, input.list, input.sources) }
	if among(where.zones, input.zone) then
		second[#second + 1] = L.TRACKER_HERE
	end
	second[#second + 1] = ns.TrackerProgress(hunt, input.state.hunts[row.id], input.updating)
	return {
		id = row.id,
		dot = row.group,
		first = L.TRACKER_FIRST:format(input.list:HuntName(row.id), label),
		second = table.concat(second, L.TRACKER_JOIN),
	}
end

--- The tracker's lines (HNT-R76, HNT-R78): the pinned current Hunts as the board sorts them, at most
--- ns.TRACKER_SHOWN, then how many more are pinned; with nothing pinned, the empty line. Before the first grouping
--- there are no rows yet: the empty line alone when nothing is pinned.
---@param input HuntsTrackerInput
---@return HuntsTrackerLines
function ns.TrackerLines(input)
	local lines = { hunts = {}, more = 0, empty = false }
	local rows = input.rows
	if not rows then
		lines.empty = not input.anyPinned
		return lines
	end
	for i, row in ipairs(rows) do
		if i > ns.TRACKER_SHOWN then
			lines.more = #rows - ns.TRACKER_SHOWN
			break
		end
		lines.hunts[i] = huntLines(row, input)
	end
	lines.empty = #rows == 0
	return lines
end
