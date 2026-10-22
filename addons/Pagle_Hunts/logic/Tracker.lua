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
---@field time integer         -- ns.ViewNow(): labels count down from now, or from the grouping's time while it is
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
---@field name string          -- the two parts as the tracker sets them: the name at the left…
---@field label string         -- …and the tracker label at the right
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
		name = input.list:HuntName(row.id),
		label = label,
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

-- The Pagle Wagers block (HNT-R175–R177) ----------------------------------------------------------------------------

--- Tunables (hunts.md): the runs on the tracker's Pagle Wagers block lists before its "+{n} more wagers on the table"
--- line (HNT-R175).
ns.TRACKER_RUNS = 3

--- What the Pagle Wagers block's lines are made from: logic/Wagers.lua's WagersInput (ns.BoardWagersInput(), the
--- board's own), of which it reads these.
---@class HuntsTrackerWagersInput
---@field runs HuntsShownRun[]   -- ns.RunsShown at `now`: the runs on, then the runs ahead (HNT-R160)
---@field now integer            -- ns.ViewNow(): countdowns freeze with the board's while restricted (HNT-R43)
---@field updating boolean       -- ns.IsUpdating() (HNT-R78)
---@field hint CompanionHint?    -- the companion hint while it applies (HNT-R170, HNT-R176)

--- One run's two lines on the block (HNT-R175).
---@class HuntsTrackerRun
---@field key string           -- its run key: clicking its lines opens the board on it (HNT-R164)
---@field name string          -- the event's name, at the left of the first line…
---@field label string         -- …and at the right "settled", or "ends in 1d 4h" (HNT-R51's tracker wording)
---@field second string        -- "1 of 4 first marks · {Hunt}: 1 / 2", or "updating…" (HNT-R78)

--- The Pagle Wagers block's lines.
---@class HuntsTrackerWagers
---@field runs HuntsTrackerRun[]   -- at most ns.TRACKER_RUNS
---@field more integer             -- the runs on past those, for "+{n} more wagers on the table"; 0 for no such line
---@field hint string?             -- with no run on, the companion hint's one line (HNT-R176), with "why?"

--- One run on's two lines (HNT-R175): its event's name and "settled" once completed, else "ends in {duration}"
--- counted from `now`; then "{done} of {n} first marks" and its closest unfinished Hunt as "{Hunt}: {count} / {next
--- threshold}", ns.RunProgress's (the Hunt without its first mark nearest it, ties in definition order), none once
--- every first mark is landed. While the projection updates, progress reads "updating…" and the label counts down.
---@param shown HuntsShownRun
---@param input HuntsTrackerWagersInput
---@param state HuntsState
---@return HuntsTrackerRun
local function runLines(shown, input, state)
	local L, run = ns.L, shown.run
	local line = { key = shown.key, name = ns.events:EventName(shown.event) }
	if run.completedAt and not input.updating then
		line.label = L.TRACKER_SETTLED
	else
		line.label = L.TRACKER_ENDS_IN:format(ns.FormatDuration(run.end_ - input.now))
	end
	if input.updating then
		line.second = L.TRACKER_UPDATING
		return line
	end
	local progress = ns.RunProgress(run, state)
	local second = { L.TRACKER_FIRST_MARKS:format(progress.done, progress.total) }
	if progress.closest then
		second[2] = L.TRACKER_CLOSEST:format(ns.events:HuntName(progress.closest), progress.count, progress.of)
	end
	line.second = table.concat(second, L.TRACKER_JOIN)
	return line
end

--- The Pagle Wagers block's lines (HNT-R175): the runs on, as ns.RunsShown orders them, at most ns.TRACKER_RUNS, then
--- how many more are on. With no run on, the companion hint's one line while it applies (HNT-R176), else nil, when
--- the block is gone (the runs ahead show on the board alone).
---@param input HuntsTrackerWagersInput
---@param state HuntsState ns.State(), for each run's progress
---@return HuntsTrackerWagers?
function ns.TrackerWagerLines(input, state)
	local lines, on = { runs = {}, more = 0 }, 0
	for _, shown in ipairs(input.runs) do
		if shown.on then
			on = on + 1
			if on <= ns.TRACKER_RUNS then
				lines.runs[on] = runLines(shown, input, state)
			end
		end
	end
	if on == 0 then
		return input.hint and { runs = {}, more = 0, hint = input.hint.tracker } or nil
	end
	lines.more = on - #lines.runs
	return lines
end

--- The block's "+{n} more wagers on the table" line (HNT-R175).
---@param more integer
---@return string
function ns.TrackerWagersMore(more)
	return ns.L.TRACKER_WAGERS_MORE:format(more)
end
