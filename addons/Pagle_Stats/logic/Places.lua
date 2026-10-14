if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The vocabulary every Stats number is counted in (stats.md › Places, skill sides and windows): a Cast's places, its
-- effective skill and skill side against its zone's no-junk line, an item's window in a zone and a zone's windows.
-- Pure logic: a snapshot, or Core's catalogue lookups, come in as arguments (CORE-R7), so the exit reader can load
-- this file outside the client. Secret values reach here as unknowns (nil, or 0 for an area), and nothing raises on
-- one (STA-R93).

--- The places a Cast counts toward (STA-R10): its zone, then its subzone when that isn't 0. None when its zone is 0,
--- whatever its subzone (STA-R93), so the Cast adds nothing to any place.
---@param conditions ConditionsSnapshot a Cast's snapshot (LOG-R20)
---@return integer[] places zone first, then subzone; empty for none
function ns.PlacesOf(conditions)
	local zone, subzone = conditions.zone or 0, conditions.subzone or 0
	if zone == 0 then
		return {}
	end
	if subzone == 0 then
		return { zone }
	end
	return { zone, subzone }
end

--- The current place (STA-R10): the live subzone, or the zone when the subzone is 0; none with zone 0.
---@param conditions ConditionsSnapshot the live snapshot, `Pagle.GetConditions()` (LOG-R45)
---@return integer? areaID
function ns.CurrentPlace(conditions)
	local places = ns.PlacesOf(conditions)
	return places[#places]
end

--- Effective skill (STA-R11): `skillRank + (skillMod or 0)`, or unknown (nil) when `skillRank` is nil, as it is while
--- secret (STA-R93). A Cast's snapshot and the live one read the same fields.
---@param conditions ConditionsSnapshot
---@return integer?
function ns.EffectiveSkill(conditions)
	local rank = conditions.skillRank
	if rank == nil then
		return nil
	end
	return rank + (conditions.skillMod or 0)
end

--- What the catalogue rules read from Core (stats.md › Contracts): Core's own calls and fingerprint, under their
--- names on Pagle, so the adapter passes `Pagle` itself and the exit reader a table of its own (CORE-R7).
---@class StatsLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field GetArea fun(areaID: integer): PagleArea?
---@field GetZoneOf fun(areaID: integer): integer?
---@field GetZoneCatches fun(zoneAreaID: integer): PagleZoneCatchEntry[]?
---@field GetWindowSpec fun(windowID: string): PagleWindowSpec?
---@field MatchesConditions fun(spec: table, snapshot: table): boolean
---@field CONTENT_FINGERPRINT string

--- The no-junk margin above a zone's skillBase (stats.md › Tunables, STA-R12).
ns.NO_JUNK_MARGIN = 95

--- A place's no-junk line (STA-R12): its zone's `skillBase` plus the no-junk margin, and whether that skillBase is
--- confirmed (`skillBaseConfirmed`, for STA-R46). A subzone uses its zone's line and its own `skillBase` is ignored,
--- so a Cast has one side in both of its places. None for an unknown area or a zone without a `skillBase`.
---@param area integer a zone or subzone areaID
---@param lookups StatsLookups
---@return integer? line
---@return boolean confirmed false with no line
function ns.NoJunkLine(area, lookups)
	local zone = lookups.GetZoneOf(area)
	local record = zone and lookups.GetArea(zone)
	if not record or record.skillBase == nil then
		return nil, false
	end
	return record.skillBase + ns.NO_JUNK_MARGIN, record.skillBaseConfirmed == true
end

--- A skill side (STA-R13): "hi" at or above the line, "lo" below it, "na" with no line or an unknown skill.
---@param skill integer? effective skill (STA-R11)
---@param line integer? the zone's no-junk line (STA-R12)
---@return StatsSide
function ns.SkillSide(skill, line)
	if skill == nil or line == nil then
		return "na"
	end
	return skill >= line and "hi" or "lo"
end

--- An item's window in a zone (STA-R14), from its entries in `GetZoneCatches(zone)`: the one window ID they all
--- carry; none if none carries one, if they differ (some gated and some not included), or if the item is on none of
--- the zone's lists. Window IDs are compared, never condition specs (LOG-R55). Also whether any entry behind that
--- window has an unconfirmed gate (`gateConfirmed = false`), for STA-R47.
---@param zone integer a zone areaID; any other area has no lists, so no window
---@param itemID integer
---@param lookups StatsLookups
---@return string? windowID
---@return boolean unconfirmed false with no window
function ns.ItemWindow(zone, itemID, lookups)
	local seen, window, mixed, unconfirmed = false, nil, false, false
	for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
		if entry.itemID == itemID then
			if not seen then
				seen, window = true, entry.window
			elseif entry.window ~= window then
				mixed = true
			end
			unconfirmed = unconfirmed or entry.gateConfirmed == false
		end
	end
	if mixed or window == nil then
		return nil, false
	end
	return window, unconfirmed
end

--- A zone's windows (STA-R16): the distinct window IDs on the entries of `GetZoneCatches(zone)`, its subzones' and
--- Noise and removed items' included, sorted by ID so they come in a stable order.
---@param zone integer a zone areaID; any other area has none
---@param lookups StatsLookups
---@return string[]
function ns.ZoneWindows(zone, lookups)
	local seen, windows = {}, {}
	for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
		local window = entry.window
		if window ~= nil and not seen[window] then
			seen[window] = true
			windows[#windows + 1] = window
		end
	end
	table.sort(windows)
	return windows
end

--- Whether a Cast is in a window (STA-R15): `MatchesConditions(GetWindowSpec(windowID), conditions)`. A window the
--- catalogue lacks matches nothing.
---@param windowID string
---@param conditions ConditionsSnapshot a Cast's snapshot, or the live one
---@param lookups StatsLookups
---@return boolean
function ns.InWindow(windowID, conditions, lookups)
	local spec = lookups.GetWindowSpec(windowID)
	return spec ~= nil and lookups.MatchesConditions(spec, conditions) == true
end

--- What a zone's entries give, built in one pass over `GetZoneCatches(zone)`: its windows (STA-R16) and each item's
--- window with its unconfirmed flag (STA-R14), for items that have one.
---@param zone integer
---@param lookups StatsLookups
---@return { windows: string[], items: table<integer, { [1]: string, [2]: boolean }> }
local function zoneTable(zone, lookups)
	local windows, seen = {}, {}
	-- By item: its first entry's window (false for none), whether a later entry's differs, whether any gate is
	-- unconfirmed.
	local first, mixed, unconfirmed = {}, {}, {}
	for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
		local itemID, window = entry.itemID, entry.window or false
		if first[itemID] == nil then
			first[itemID] = window
		elseif first[itemID] ~= window then
			mixed[itemID] = true
		end
		if entry.gateConfirmed == false then
			unconfirmed[itemID] = true
		end
		if window and not seen[window] then
			seen[window] = true
			windows[#windows + 1] = window
		end
	end
	table.sort(windows)
	local items = {}
	for itemID, window in pairs(first) do
		if window and not mixed[itemID] then
			items[itemID] = { window, unconfirmed[itemID] == true }
		end
	end
	return { windows = windows, items = items }
end

--- The places rules over one set of lookups, with what doesn't change while the catalogue is the same (each zone's
--- windows and its items' windows, each place's line) kept in tables built lazily, at a place's first use, and dropped
--- whenever `lookups.CONTENT_FINGERPRINT` changes (LOG-R72). Each method gives the same answers as the rule it is
--- named after (ns.NoJunkLine, ns.ItemWindow, ...) with these lookups. Lists it returns are shared: read them, never
--- change them.
---@param lookups StatsLookups
---@return StatsPlaceTables
function ns.NewPlaceTables(lookups)
	local fingerprint, lines, zones

	-- Drops the tables when the catalogue has changed since they were built.
	local function current()
		if lookups.CONTENT_FINGERPRINT ~= fingerprint or not lines then
			fingerprint, lines, zones = lookups.CONTENT_FINGERPRINT, {}, {}
		end
	end

	---@param zone integer
	local function builtZone(zone)
		current()
		local built = zones[zone]
		if not built then
			built = zoneTable(zone, lookups)
			zones[zone] = built
		end
		return built
	end

	---@class StatsPlaceTables
	local tables = {}

	--- ns.NoJunkLine (STA-R12), kept per place.
	---@param area integer
	---@return integer? line
	---@return boolean confirmed
	function tables.NoJunkLine(_, area)
		current()
		local line = lines[area]
		if not line then
			line = { ns.NoJunkLine(area, lookups) }
			lines[area] = line
		end
		return line[1], line[2]
	end

	--- A skill's side of a place's line (STA-R13): ns.SkillSide against the place's ns.NoJunkLine.
	---@param area integer
	---@param skill integer? effective skill (STA-R11)
	---@return StatsSide
	function tables:Side(area, skill)
		return ns.SkillSide(skill, (self:NoJunkLine(area)))
	end

	--- ns.ItemWindow (STA-R14), from the zone's table.
	---@param zone integer
	---@param itemID integer
	---@return string? windowID
	---@return boolean unconfirmed
	function tables.ItemWindow(_, zone, itemID)
		local window = builtZone(zone).items[itemID]
		if not window then
			return nil, false
		end
		return window[1], window[2]
	end

	--- ns.ZoneWindows (STA-R16), from the zone's table: shared, so read it and never change it.
	---@param zone integer
	---@return string[]
	function tables.ZoneWindows(_, zone)
		return builtZone(zone).windows
	end

	--- ns.InWindow (STA-R15).
	---@param windowID string
	---@param conditions ConditionsSnapshot
	---@return boolean
	function tables.InWindow(_, windowID, conditions)
		return ns.InWindow(windowID, conditions, lookups)
	end

	--- ns.Rows (STA-R17): the rows read the projection's state too, so they are made afresh each call.
	---@param state { places: table<integer, StatsPlace> }
	---@param area integer
	---@return StatsRow[]
	function tables.Rows(_, state, area)
		return ns.Rows(state, area, lookups)
	end

	return tables
end
