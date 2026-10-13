local addonName = ...
---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The catalogue's accessors, built at ADDON_LOADED (LOG-R1 step 1), and the runtime area index, built at
-- PLAYER_LOGIN (LOG-R1 step 2). Their own owners, so no other Core file's registration replaces these.
local CATALOGUE_OWNER, AREA_INDEX_OWNER = "Pagle catalogue", "Pagle area index"

-- Tunables: the runtime area index range (LOG-R23).
local LAST_AREA_ID = 40000

---@type PagleAreaIndex
local areaIndex = {}

-- A value the client gave, or nil if it's secret (CORE-R31): a secret is never a name or a table key.
---@generic T
---@param value T
---@return T?
local function unlessSecret(value)
	if issecretvalue(value) then
		return nil
	end
	return value
end

--- The current zone and subzone areaIDs (LOG-R22), and their texts when either didn't resolve (LOG-R81). Before
--- PLAYER_LOGIN the index is empty, so every name is unresolved.
---@return integer zone
---@return integer subzone
---@return PagleUnresolvedAreas? unresolved
function ns.ReadAreas()
	local continent = unlessSecret((select(8, GetInstanceInfo())))
	return ns.ResolveAreas(
		areaIndex,
		ns.Catalogue,
		unlessSecret(GetRealZoneText()),
		unlessSecret(GetSubZoneText()),
		continent
	)
end

Pagle.RegisterEvent(CATALOGUE_OWNER, "ADDON_LOADED", function(_, loadedName)
	if loadedName ~= addonName then
		return
	end
	Pagle.UnregisterEvent(CATALOGUE_OWNER, "ADDON_LOADED")

	-- Read-only from here on, and never copied into SavedVariables (DATA-R80).
	local catalogue = ns.NewCatalogue(ns.catalogue)
	ns.Catalogue = catalogue

	--- The generator's hash of everything in the catalogue, as lowercase hex (LOG-R55).
	Pagle.CONTENT_FINGERPRINT = catalogue.CONTENT_FINGERPRINT
	--- An item's catalogue record, or nil for an Uncharted item (LOG-R55).
	Pagle.GetItem = catalogue.GetItem
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
end)

Pagle.RegisterEvent(AREA_INDEX_OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(AREA_INDEX_OWNER, "PLAYER_LOGIN")
	areaIndex = ns.NewAreaIndex(function(areaID)
		return unlessSecret(C_Map.GetAreaInfo(areaID))
	end, LAST_AREA_ID)
end)
