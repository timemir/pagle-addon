if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- A place's page in logic (STA-R18, STA-R42, STA-R96; stats.md › UI › Place spread): its rows (STA-R17) as readings,
-- grouped and sorted by Your odds, whether any of them reads across its zone, a zone's waters, and the no-junk
-- sentence. adapter/Place.lua draws them. Pure logic: the state, the live skill and the place tables come in as
-- arguments (CORE-R7).

---@alias StatsGroupID "any"|"pools"|"window"|"added"

--- One group of a place's rows (STA-R18): its readings in their order, with its heading and small note.
---@class StatsGroup
---@field id StatsGroupID
---@field heading string
---@field note string
---@field readings StatsReading[]

-- The groups in their order on the page (STA-R18).
---@type StatsGroupID[]
local ORDER = { "any", "pools", "window", "added" }

-- Your odds' states in STA-R18's order: known, then unseen, then learning.
local RANK = { known = 1, unseen = 2, learning = 3 }

--- Whether reading `a` comes before reading `b` in a group (STA-R18): known odds by `k/n` descending, then unseen,
--- then learning; ties by item ID ascending (names may not be loaded yet).
---@param a StatsReading
---@param b StatsReading
---@return boolean
local function before(a, b)
	local rankA, rankB = RANK[a.state], RANK[b.state]
	if rankA ~= rankB then
		return rankA < rankB
	end
	if a.state == "known" then
		-- k/n compared without dividing: a.k/a.n > b.k/b.n.
		local left, right = a.k * b.n, b.k * a.n
		if left ~= right then
			return left > right
		end
	end
	return a.item < b.item
end

--- A place's rows as readings, grouped (STA-R18): *Any time* (on the list, no window, not pool-associated), *Pools*
--- (on the list, no window, `PagleItem.pool`), *In their window* (on the list, with a window in the zone) and *Also
--- caught here* (added by STA-R17 because the list lacks them, Uncharted Catches among them, STA-R96), in that order,
--- an empty group left out; each sorted by Your odds.
---@param state StatsState the projection's state (ns.State())
---@param area integer the page's place, a zone or subzone
---@param live integer? the live effective skill (STA-R11), nil when unknown
---@param places StatsPlaceTables? `ns.places` if nil
---@return StatsGroup[]
function ns.Groups(state, area, live, places)
	places = places or ns.places
	local lookups = places.lookups
	local byID = {} ---@type table<StatsGroupID, StatsReading[]>
	for _, id in ipairs(ORDER) do
		byID[id] = {}
	end
	for _, row in ipairs(places:Rows(state, area)) do
		local reading = ns.Reading(state, row.item, area, live, places)
		local id ---@type StatsGroupID
		if row.added then
			id = "added"
		elseif reading.window then
			id = "window"
		else
			local record = lookups.GetItem(row.item)
			id = (record and record.pool) and "pools" or "any"
		end
		local readings = byID[id]
		readings[#readings + 1] = reading
	end
	local groups, words = {}, ns.L.GROUPS
	for _, id in ipairs(ORDER) do
		local readings = byID[id]
		if #readings > 0 then
			table.sort(readings, before)
			groups[#groups + 1] = { id = id, heading = words[id].heading, note = words[id].note, readings = readings }
		end
	end
	return groups
end

--- Whether any row reads across its zone (STA-R42): a subzone's reading that uses its zone's scope until its own holds
--- the Cast threshold. The page then says "Fish with fewer than 100 Casts in {subzone} use all of {zone} until then."
---@param groups StatsGroup[]
---@return boolean
function ns.ReadsAcrossZone(groups)
	for _, group in ipairs(groups) do
		for _, reading in ipairs(group.readings) do
			if reading.viaZone then
				return true
			end
		end
	end
	return false
end

--- One of a zone's waters (stats.md › UI › Place spread, *Its waters*).
---@class StatsWater
---@field area integer
---@field name string
---@field casts integer?   -- my Casts there; nil for none ("—")

--- A zone's waters (*Its waters*): every subzone of the zone with its own catch list in `GetZoneCatches(zone)` or a
--- `places` record whose `zone` is this zone, alphabetical by name (ns.AreaName), then by areaID.
---@param state StatsState
---@param zone integer
---@param lookups StatsLookups
---@return StatsWater[]
function ns.PlaceWaters(state, zone, lookups)
	local seen, waters = {}, {}
	local function add(area)
		if area ~= zone and not seen[area] then
			seen[area] = true
			local place = state.places[area]
			waters[#waters + 1] = { area = area, name = ns.AreaName(area), casts = place and place.casts or nil }
		end
	end
	for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
		add(entry.areaID)
	end
	for area, place in pairs(state.places) do
		if place.zone == zone then
			add(area)
		end
	end
	table.sort(waters, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.area < b.area
	end)
	return waters
end

--- The no-junk sentence on a place's page (stats.md › UI › Place spread), when its zone has a line: "No junk from
--- {line}; at {skill} I'm past it, so only those Casts count." on side `hi`, "No junk from {line}; at {skill} I'm
--- below it, so only my Casts below it count." on `lo`, and "No junk from {line}." with the live skill unknown. None
--- with no line.
---@param area integer the page's place, a zone or subzone
---@param live integer? the live effective skill (STA-R11)
---@param places StatsPlaceTables? `ns.places` if nil
---@return string?
function ns.NoJunkSentence(area, live, places)
	places = places or ns.places
	local line = places:NoJunkLine(area)
	if line == nil then
		return nil
	end
	local L = ns.L
	if live == nil then
		return L.PLACE_NO_JUNK:format(line)
	end
	local side = ns.SkillSide(live, line)
	return (side == "hi" and L.PLACE_NO_JUNK_PAST or L.PLACE_NO_JUNK_BELOW):format(line, live)
end
