---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The catalogue's accessors, built at ADDON_LOADED (LOG-R1 step 1), and the runtime area index, built at
-- PLAYER_LOGIN (LOG-R1 step 2). adapter/Login.lua calls each in its place.

-- Tunables: the runtime area index range (LOG-R23).
local LAST_AREA_ID = 40000

---@type PagleAreaIndex
local areaIndex = {}

--- The current zone and subzone areaIDs (LOG-R22), and their texts when either didn't resolve (LOG-R81). Before
--- PLAYER_LOGIN the index is empty, so every name is unresolved.
---@return integer zone
---@return integer subzone
---@return PagleUnresolvedAreas? unresolved
function ns.ReadAreas()
	local continent = ns.UnlessSecret(issecretvalue, (select(8, GetInstanceInfo())))
	return ns.ResolveAreas(
		areaIndex,
		ns.Catalogue,
		ns.UnlessSecret(issecretvalue, GetRealZoneText()),
		ns.UnlessSecret(issecretvalue, GetSubZoneText()),
		continent
	)
end

--- Login step 1 (LOG-R1): builds the catalogue's accessors over the generated data and publishes them on Pagle.
function ns.BuildCatalogue()
	-- Read-only from here on, and never copied into SavedVariables (DATA-R80).
	local catalogue = ns.NewCatalogue(ns.catalogue)
	ns.Catalogue = catalogue

	--- The generator's hash of everything in the catalogue, as lowercase hex (LOG-R55).
	Pagle.CONTENT_FINGERPRINT = catalogue.CONTENT_FINGERPRINT
	--- An item's catalogue record, or nil for an Uncharted item (LOG-R55).
	Pagle.GetItem = catalogue.GetItem
	--- A Species' ten varieties in order, `{ id, key, index, rarity, name, description, art }`, or nil (VAR-R11).
	Pagle.GetVarieties = catalogue.GetVarieties
	--- Every zone areaID in the AreaTable slice, ascending (LOG-R55).
	Pagle.GetZones = catalogue.GetZones
	--- An area's catalogue record, or nil for an unknown area (LOG-R55).
	Pagle.GetArea = catalogue.GetArea
	--- The zone areaID a subzone belongs to, itself for a zone (LOG-R55).
	Pagle.GetZoneOf = catalogue.GetZoneOf
	--- Every catch entry of a zone and its subzones, each with the areaID it came from (LOG-R55).
	Pagle.GetZoneCatches = catalogue.GetZoneCatches
	--- A named window's condition spec and its confirmed (LOG-R55).
	Pagle.GetWindowSpec = catalogue.GetWindowSpec
end

--- Login step 2 (LOG-R1): builds the runtime area index (LOG-R23), once per login.
function ns.BuildAreaIndex()
	areaIndex = ns.NewAreaIndex(function(areaID)
		return ns.UnlessSecret(issecretvalue, C_Map.GetAreaInfo(areaID))
	end, LAST_AREA_ID)
end
