---@class PagleNS
local ns = select(2, ...)

-- The runtime area index (LOG-R23) and zone and subzone resolution (LOG-R22): pure logic, with the names, the
-- AreaTable slice, the index and the texts passed in (CORE-R7).

--- Area names as the client gives them, each mapped to every areaID with that name, ascending (LOG-R23).
---@alias PagleAreaIndex table<string, integer[]>

--- The texts of a Cast whose zone or subzone didn't resolve, for the diagnostics buffer (LOG-R22, LOG-R81).
---@class PagleUnresolvedAreas
---@field zone? string
---@field subzone? string

--- Builds the runtime area index from the name of each areaID from 1 to `lastID` (LOG-R23).
---@param getName fun(areaID: integer): string? The area's name in the client's language; nil (or "") for none.
---@param lastID integer
---@return PagleAreaIndex
function ns.NewAreaIndex(getName, lastID)
	local index = {}
	for areaID = 1, lastID do
		local name = getName(areaID)
		if name and name ~= "" then
			local ids = index[name]
			if ids then
				ids[#ids + 1] = areaID
			else
				index[name] = { areaID }
			end
		end
	end
	return index
end

-- Of a name's IDs, the one to use (LOG-R22): the single one in the slice that `fits`; with none in the slice, the
-- name's only ID; otherwise 0.
---@param ids integer[]?
---@param catalogue PagleCatalogue
---@param fits fun(area: PagleArea, areaID: integer): boolean
---@return integer
local function pick(ids, catalogue, fits)
	if not ids then
		return 0
	end
	local inSlice, found, fitting = false, 0, 0
	for _, areaID in ipairs(ids) do
		local area = catalogue.GetArea(areaID)
		if area then
			inSlice = true
			if fits(area, areaID) then
				found, fitting = areaID, fitting + 1
			end
		end
	end
	if fitting == 1 then
		return found
	end
	if not inSlice and #ids == 1 then
		return ids[1]
	end
	return 0
end

--- Resolves `GetRealZoneText()` and `GetSubZoneText()` to areaIDs (LOG-R22). Each is 0 when unresolved, and the
--- subzone is 0 for one equal to the zone's. An empty text, or a secret one passed in as nil, gives 0 too, and isn't
--- unresolved.
---@param index PagleAreaIndex
---@param catalogue PagleCatalogue
---@param zoneText string?
---@param subzoneText string?
---@param continent integer? The current instance's map ID (8th return of `GetInstanceInfo()`).
---@return integer zone
---@return integer subzone
---@return PagleUnresolvedAreas? unresolved Both texts, when a non-empty one (other than a subzone equal to the zone)
--- didn't resolve; nil otherwise.
function ns.ResolveAreas(index, catalogue, zoneText, subzoneText, continent)
	local zone, zoneUnresolved = 0, false
	if zoneText and zoneText ~= "" then
		zone = pick(index[zoneText], catalogue, function(area)
			return area.parent == 0 and continent ~= nil and area.continent == continent
		end)
		zoneUnresolved = zone == 0
	end

	local subzone, subzoneUnresolved = 0, false
	if subzoneText and subzoneText ~= "" and subzoneText ~= zoneText then
		-- GetZoneOf walks up the parents to the zone; a missing parent or a cycle gives nil, so the ID doesn't fit.
		subzone = pick(index[subzoneText], catalogue, function(_, areaID)
			return zone ~= 0 and catalogue.GetZoneOf(areaID) == zone
		end)
		subzoneUnresolved = subzone == 0
	end

	local unresolved
	if zoneUnresolved or subzoneUnresolved then
		unresolved = { zone = zoneText, subzone = subzoneText }
	end
	return catalogue.Unalias(zone), catalogue.Unalias(subzone), unresolved
end
