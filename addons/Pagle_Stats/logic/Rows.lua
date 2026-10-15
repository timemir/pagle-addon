if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- A place's rows (STA-R17): the items its page lists. The place page groups them (STA-R18); the item page and search
-- reuse them. Pure logic over the projection's `places` and Core's catalogue lookups (CORE-R7).

--- One row of a place's page (STA-R17).
---@class StatsRow
---@field item integer        -- the item ID, never 0
---@field added boolean       -- caught here but not on the place's list: STA-R18's *Also caught here*

--- Whether an item may be a row: not item 0, and not Noise or removed (STA-R17). An Uncharted item, with no record,
--- may.
---@param itemID integer
---@param lookups StatsLookups
---@return boolean
local function listable(itemID, lookups)
	if itemID == 0 then
		return false
	end
	local record = lookups.GetItem(itemID)
	return not (record and (record.noise or record.removed))
end

-- A zone's own `catches` in the catalogue, none when it lacks the zone.
---@param zone integer?
---@param lookups StatsLookups
---@return PagleCatchEntry[]
local function zoneOwn(zone, lookups)
	local zoneRecord = zone and lookups.GetArea(zone)
	return zoneRecord and zoneRecord.catches or {}
end

--- The catalogue's list for a place (STA-R17): a subzone's own `catches` if non-empty, else its zone's own; a zone's
--- every entry in `GetZoneCatches`. A subzone the catalogue lacks still has its zone's own list, through `zone`, the
--- zone the projection's place record holds (STA-R22: Stats never needs the catalogue to tell them apart). None for a
--- zone outside the catalogue. Your odds reads it for the entries behind a row (STA-R46).
---@param area integer
---@param lookups StatsLookups
---@param zone integer? the place's zone, `state.places[area].zone`, when the projection has the place
---@return PagleCatchEntry[]
function ns.PlaceList(area, lookups, zone)
	local record = lookups.GetArea(area)
	if record and record.parent ~= 0 then
		if next(record.catches) ~= nil then
			return record.catches
		end
		return zoneOwn(lookups.GetZoneOf(area), lookups)
	elseif not record and zone and zone ~= area then
		return zoneOwn(zone, lookups)
	end
	return lookups.GetZoneCatches(area) or {}
end

--- A place's rows (STA-R17), in list order: the catalogue's list for the place (a subzone's own `catches` if
--- non-empty, else its zone's own; a zone's every `GetZoneCatches` item), once each, without Noise or removed items;
--- then every item caught there (`state.places[area].items`, STA-R22) that the list lacks, except Noise and removed
--- ones, marked `added`, by item ID. Item 0 is never a row.
---@param state { places: table<integer, StatsPlace> } the projection's state (only `places` is read)
---@param area integer a zone or subzone areaID
---@param lookups StatsLookups
---@return StatsRow[]
function ns.Rows(state, area, lookups)
	local rows, listed = {}, {}
	local place = state.places[area]
	for _, entry in ipairs(ns.PlaceList(area, lookups, place and place.zone)) do
		local itemID = entry.itemID
		if not listed[itemID] and listable(itemID, lookups) then
			listed[itemID] = true
			rows[#rows + 1] = { item = itemID, added = false }
		end
	end
	local caught = {}
	for itemID in pairs(place and place.items or {}) do
		if not listed[itemID] and listable(itemID, lookups) then
			caught[#caught + 1] = itemID
		end
	end
	table.sort(caught)
	for _, itemID in ipairs(caught) do
		rows[#rows + 1] = { item = itemID, added = true }
	end
	return rows
end
