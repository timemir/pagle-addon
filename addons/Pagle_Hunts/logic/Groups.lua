if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Grouping Hunts into Now, Soon, Later and On demand (HNT-R40–R44), pins (HNT-R80, HNT-R81) and the "show
-- completed" filter (HNT-R82): pure logic, everything passed in (CORE-R7). The adapter (adapter/Groups.lua) reads
-- NextWindow, the live conditions and the clock, runs the timers and events, and keeps the grouping in `ns.groups`.

--- Tunables (hunts.md): how far ahead an opening counts as Soon (HNT-R40), and how often the groups refresh while
--- the board or the tracker is visible (HNT-R42), both in seconds.
ns.SOON_HORIZON = 3 * 60 * 60
ns.REFRESH_INTERVAL = 60

---@alias HuntGroup "now"|"soon"|"later"|"onDemand"

-- Whether any of `spec`'s auras is in `auras`, the live snapshot's (nil while secret: none up).
---@param spec { auras: integer[]? }
---@param auras integer[]?
---@return boolean
local function auraUp(spec, auras)
	for _, wanted in ipairs(spec.auras or {}) do
		for _, live in ipairs(auras or {}) do
			if live == wanted then
				return true
			end
		end
	end
	return false
end

--- The group of one current Hunt (HNT-R40), in the rule's order, and whether it is Now with its aura up.
---@param spec table? its board spec (HNT-R6); nil when it has none (HNT-R7)
---@param window Window? Pagle.NextWindow(spec, now); nil for none
---@param short boolean short of skill (HNT-R33)
---@param auras integer[]? the live snapshot's auras
---@param now integer server time
---@return HuntGroup group
---@return boolean auraUp
function ns.GroupOf(spec, window, short, auras, now)
	if not spec or short or not window then
		return "later", false
	end
	if window.onDemand then
		if auraUp(spec, auras) then
			return "now", true
		end
		return "onDemand", false
	end
	if window.always then
		return "now", false
	end
	if window.openNow then
		if not spec.auras then
			return "now", false
		end
		if auraUp(spec, auras) then
			return "now", true
		end
		return "onDemand", false
	end
	if window.opensAt and window.opensAt - now <= ns.SOON_HORIZON then
		return "soon", false
	end
	return "later", false
end

--- The groups in board order (HNT-R62, HNT-R76).
---@type HuntGroup[]
ns.GROUP_ORDER = { "now", "soon", "later", "onDemand" }

local rank = {}
for i, group in ipairs(ns.GROUP_ORDER) do
	rank[group] = i
end

-- The time a row sorts by within its group (HNT-R44), or nil to go last: Now by closesAt, Soon and Later by opensAt,
-- On demand by none.
---@param row { group: HuntGroup, window: Window? }
---@return integer?
local function sortTime(row)
	local window = row.window
	if not window or row.group == "onDemand" then
		return nil
	end
	if row.group == "now" then
		return window.closesAt
	end
	return window.opensAt
end

-- Whether row `a` comes before row `b`: groups in board order, then HNT-R44.
local function before(a, b)
	if a.group ~= b.group then
		return rank[a.group] < rank[b.group]
	end
	if a.pinned ~= b.pinned then
		return a.pinned
	end
	if not a.pinned and a.short ~= b.short then
		return b.short
	end
	local ta, tb = sortTime(a), sortTime(b)
	if ta ~= tb then
		if ta == nil or tb == nil then
			return tb == nil
		end
		return ta < tb
	end
	return a.order < b.order
end

--- Sorts rows in place, and returns them: by group in board order, then within a group pinned first; among the
--- unpinned, short of skill last; then Now by `closesAt` ascending and Soon and Later by `opensAt` ascending, none
--- last; then Hunt list order (HNT-R44).
---@generic R: { group: HuntGroup, window: Window?, pinned: boolean, short: boolean, order: integer }
---@param rows R[]
---@return R[]
function ns.SortRows(rows)
	table.sort(rows, before)
	return rows
end

-- The earlier of `best` and `t`, counting `t` only when it is after `now`.
---@param best integer?
---@param t integer?
---@param now integer
---@return integer?
local function earliestAhead(best, t, now)
	if t and t > now and (not best or t < best) then
		return t
	end
	return best
end

--- When the groups next change by time alone (HNT-R42): the earliest `opensAt`, `closesAt` or Soon-horizon crossing
--- (`opensAt` less the horizon) after `now` among the current Hunts' NextWindow results, or nil with none ahead.
---@param windows (Window|false)[] each current Hunt's NextWindow result (false or a hole for none)
---@param now integer
---@return integer?
function ns.NextEdge(windows, now)
	local best
	for _, window in pairs(windows) do
		if window then
			best = earliestAhead(best, window.closesAt, now)
			if window.opensAt then
				best = earliestAhead(best, window.opensAt, now)
				best = earliestAhead(best, window.opensAt - ns.SOON_HORIZON, now)
			end
		end
	end
	return best
end

--- When the Hunt list next changes (HNT-R2, HNT-R3, HNT-R42): the earliest `since` or `retired` after `now` among
--- every Hunt, or nil with none ahead.
---@param list HuntDef[] every Hunt, Retired ones and ones not yet out included
---@param now integer
---@return integer?
function ns.NextListChange(list, now)
	local best
	for _, hunt in ipairs(list) do
		best = earliestAhead(best, hunt.since, now)
		best = earliestAhead(best, hunt.retired, now)
	end
	return best
end

--- Whether the board's groups show a Hunt under the "show completed" filter (HNT-R82): with it off, a finished Hunt
--- (every tier reached, HNT-R17) only while pinned; a Hunt with tiers left always. While the projection is updating
--- the filter hides nothing (HNT-R69).
---@param hunt HuntDef
---@param progress HuntProgress? the Hunt's progress in ns.State(); nil for a Hunt nothing has touched
---@param pinned boolean
---@param showCompleted boolean the saved filter, profile.showCompleted
---@param updating boolean ns.IsUpdating()
---@return boolean
function ns.ShownByFilter(hunt, progress, pinned, showCompleted, updating)
	return updating or showCompleted or pinned or not ns.HuntFinished(progress, hunt)
end

--- The pins to remove (HNT-R81, HNT-R3): those on a Hunt that isn't current now (Retired, or not yet out) or isn't
--- in the Hunt list at all, in ID order.
---@param pins table<string, true> profile.pins
---@param list HuntList
---@param now integer
---@return string[]
function ns.StalePins(pins, list, now)
	local stale = {}
	for huntID in pairs(pins) do
		local hunt = list:Hunt(huntID)
		if not hunt or not ns.IsCurrent(hunt, now) then
			stale[#stale + 1] = huntID
		end
	end
	table.sort(stale)
	return stale
end

--- One current Hunt in a grouping (HNT-R40). The rows a grouping keeps carry `pinned = false`; the rows
--- ns.groups hands out carry the pin as it is when read (HNT-R80).
---@class HuntRow
---@field id string
---@field hunt HuntDef
---@field group HuntGroup
---@field window Window?      -- Pagle.NextWindow(boardSpec, time); nil with no board spec or no forecast
---@field auraUp boolean      -- Now through one of its auras (HNT-R40)
---@field short boolean       -- short of skill (HNT-R33)
---@field lureGetsThere boolean   -- short by at most the lure reach (HNT-R33)
---@field pinned boolean
---@field order integer       -- its place in the Hunt list

--- What one regroup found (HNT-R42): every current Hunt then, in Hunt list order. ns.OnRegroup's listeners get the
--- previous and the new one.
---@class HuntsGrouping
---@field time integer        -- the server time it was made at; views draw from it, so they freeze with it (HNT-R43)
---@field rows HuntRow[]
---@field byId table<string, HuntRow>

--- What ns.groups reads besides the grouping, at each call: the adapter passes PagleHuntsDB's profile and the seams.
---@class HuntsGroupsReads
---@field pins fun(): table<string, true>     -- profile.pins (HNT-R81)
---@field showCompleted fun(): boolean        -- profile.showCompleted (HNT-R82)
---@field state fun(): HuntsState             -- ns.State()
---@field updating fun(): boolean             -- ns.IsUpdating() (HNT-R69)

--- Which rows ns.groups:Rows hands out. With none, every current Hunt.
---@class HuntsRowsFilter
---@field filtered boolean?   -- as the board's groups: the saved "show completed" filter applied (HNT-R82)
---@field set string?         -- only this set's Hunts (a set's page, HNT-R66)
---@field pinnedOnly boolean? -- only pinned Hunts (the tracker, HNT-R76)

--- The groups the board and the tracker draw (HNT-R40–R44): the latest grouping, whether it is paused, and its rows
--- with today's pins and filter.
---@class HuntsGroups
---@field reads HuntsGroupsReads
---@field grouping HuntsGrouping?
---@field paused boolean
local Groups = {}
Groups.__index = Groups

--- The groups, with no grouping yet.
---@param reads HuntsGroupsReads
---@return HuntsGroups
function ns.NewGroups(reads)
	return setmetatable({ reads = reads, grouping = nil, paused = false }, Groups)
end

--- Keeps a new grouping, paused or not (HNT-R43).
---@param grouping HuntsGrouping
---@param paused boolean
function Groups:Set(grouping, paused)
	self.grouping, self.paused = grouping, paused
end

--- Marks the grouping paused, or not (HNT-R43).
---@param paused boolean
function Groups:SetPaused(paused)
	self.paused = paused
end

--- Whether the grouping is paused: made or kept while restricted, not redone since (HNT-R43). The board's clock then
--- reads "(paused in combat)".
---@return boolean
function Groups:IsPaused()
	return self.paused
end

--- The latest grouping, or nil before the first.
---@return HuntsGrouping?
function Groups:Grouping()
	return self.grouping
end

--- The server time the latest grouping was made at, or nil before the first: what views count down from, so they
--- freeze with the grouping (HNT-R43).
---@return integer?
function Groups:Time()
	return self.grouping and self.grouping.time
end

-- A copy of a grouping's row, with its pin as it is now.
---@param row HuntRow
---@param pins table<string, true>
---@return HuntRow
local function handOut(row, pins)
	local copy = {}
	for key, value in pairs(row) do
		copy[key] = value
	end
	copy.pinned = pins[row.id] == true
	return copy
end

--- One current Hunt's row, with its pin, or nil for a Hunt the grouping doesn't hold.
---@param huntID string
---@return HuntRow?
function Groups:Row(huntID)
	local row = self.grouping and self.grouping.byId[huntID]
	return row and handOut(row, self.reads.pins())
end

--- The rows, new tables each call, sorted (HNT-R44): every current Hunt of the latest grouping, with its pin, or
--- those `filter` keeps. None before the first grouping. Retired Hunts and Hunts not yet out are never in it.
---@param filter HuntsRowsFilter?
---@return HuntRow[]
function Groups:Rows(filter)
	filter = filter or {}
	local rows = {}
	if not self.grouping then
		return rows
	end
	local pins = self.reads.pins()
	-- The "show completed" filter's inputs, read once: with no filter asked for, it shows everything.
	local progress, showCompleted, updating = {}, true, false
	if filter.filtered then
		progress, showCompleted, updating =
			self.reads.state().hunts, self.reads.showCompleted(), self.reads.updating()
	end
	for _, row in ipairs(self.grouping.rows) do
		local out = handOut(row, pins)
		local keep = (not filter.set or row.hunt.set == filter.set)
			and (not filter.pinnedOnly or out.pinned)
			and ns.ShownByFilter(row.hunt, progress[row.id], out.pinned, showCompleted, updating)
		if keep then
			rows[#rows + 1] = out
		end
	end
	return ns.SortRows(rows)
end
