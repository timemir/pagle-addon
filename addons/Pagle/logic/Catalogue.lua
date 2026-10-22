---@class PagleNS
local ns = select(2, ...)

-- Core's read-only view of the generated catalogue (LOG-R55–R57): pure logic over the table passed in (CORE-R7).
-- Everything it hands out is the catalogue's own tables, or tables built once here, shared and never copied per
-- call (CORE-R18). Nothing here writes to the catalogue, and none of it goes into SavedVariables (DATA-R80).

--- An item record, as `Pagle.GetItem` returns it (LOG-R55, DATA-R77).
---@class PagleItem
---@field category "fish"|"questFish"|"trophy"|"container"|"treasure"|"junk"|"other"
---@field species? integer       -- Species ID (fish and quest fish); equal for the items of one Species
---@field family? integer        -- trophy family ID
---@field weight? number         -- a trophy's real weight, in pounds
---@field typicalLength? integer -- fish and quest fish: the Species' typical length in mm (LOG-R67)
---@field varieties? string[]    -- a sized, non-Legend Species' ten variety keys, in frozen order (VAR-R4)
---@field quality? integer       -- DB2 item quality, 0 poor ... 5 legendary; nil when unknown (LOG-R55)
---@field legend boolean         -- a Legend (CONTEXT.md)
---@field noise boolean          -- Noise (CONTEXT.md)
---@field removed boolean        -- proven gone from Forever; left out of every list
---@field pool boolean           -- in any pool type's catches (LOG-R56)

--- One element of `PagleArea.catches` (keyed, not positional).
---@class PagleCatchEntry
---@field itemID integer
---@field confirmed boolean
---@field window? string         -- the gate's window ID (LOG-R55); present when gate is
---@field gate? table            -- condition spec (LOG-R48), the spec of that window
---@field gateConfirmed? boolean -- present when gate is

--- An area record of the AreaTable slice, as `Pagle.GetArea` returns it (LOG-R55).
---@class PagleArea
---@field parent integer         -- 0 for a zone
---@field continent integer
---@field skillBase? integer
---@field skillBaseConfirmed boolean
---@field hasData boolean        -- false for areas without catch data (e.g. the new Forever zones)
---@field catches PagleCatchEntry[]

--- A catch entry of `Pagle.GetZoneCatches`: an area's entry with the area it came from (LOG-R55).
---@class PagleZoneCatchEntry : PagleCatchEntry
---@field areaID integer

--- A calendar event's weekly rule (LOG-R56).
---@class PagleWeeklyRule
---@field weekday integer        -- 1 = Sunday
---@field start integer          -- realm minute
---@field duration integer       -- minutes
---@field confirmed boolean

-- The keys of a table, ascending.
---@param map table<integer, any>
---@return integer[]
local function sortedKeys(map)
	local keys = {}
	for key in pairs(map) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

--- Builds the accessors over a catalogue in the shape of DATA-R76 (`ns.catalogue`).
---@param data table
---@return PagleCatalogue
function ns.NewCatalogue(data)
	local areas, aliases = data.areas, data.aliases

	-- The zone an area belongs to: up its parents to the one with parent 0. nil for an area outside the slice, or a
	-- parent chain that leaves it.
	---@param areaID integer
	---@return integer?
	local function zoneOf(areaID)
		local area = areas[areaID]
		-- A bound on the walk, so a parent cycle in bad data can't hang the client.
		for _ = 1, 16 do
			if not area then
				return nil
			end
			if area.parent == 0 then
				return areaID
			end
			areaID = area.parent
			area = areas[areaID]
		end
		return nil
	end

	local zones = {}
	---@type table<integer, PagleZoneCatchEntry[]>
	local zoneCatches = {}
	for _, areaID in ipairs(sortedKeys(areas)) do
		if areas[areaID].parent == 0 then
			zones[#zones + 1] = areaID
			zoneCatches[areaID] = zoneCatches[areaID] or {}
		end
	end
	-- Zone first, then its subzones, each by ascending areaID; entries in the area's order.
	for _, areaID in ipairs(sortedKeys(areas)) do
		local zone = zoneOf(areaID)
		if zone then
			local list = zoneCatches[zone]
			for _, entry in ipairs(areas[areaID].catches) do
				local copy = { areaID = areaID }
				for key, value in pairs(entry) do
					copy[key] = value
				end
				list[#list + 1] = copy
			end
		end
	end

	local fishingSpells = {}
	for _, spellID in ipairs(data.fishingSpells) do
		fishingSpells[spellID] = true
	end
	local eventIDs = sortedKeys(data.events)

	--- Core's accessors over one catalogue. The public ones are published on Pagle as they are (LOG-R55); the rest
	--- are Core-internal (LOG-R56).
	---@class PagleCatalogue
	---@field CONTENT_FINGERPRINT string The generator's hash of the catalogue, lowercase hex (DATA-R70).
	local catalogue = {
		CONTENT_FINGERPRINT = data.fingerprint,
	}

	--- The item record, or nil for an Uncharted item (LOG-R55): one outside the item universe, or kept out on
	--- purpose (DATA-R15, DATA-R18).
	---@param itemID integer
	---@return PagleItem?
	function catalogue.GetItem(itemID)
		return data.items[itemID]
	end

	-- Each Species' ten variety keys (VAR-R4), from the first of its items, by item ID, that lists them; and each
	-- Species' ten as GetVarieties hands them out, built the first time it's asked for and shared from then on.
	---@type table<integer, string[]>
	local varietyKeys = {}
	for _, itemID in ipairs(sortedKeys(data.items)) do
		local item = data.items[itemID]
		if item.species and item.varieties and not varietyKeys[item.species] then
			varietyKeys[item.species] = item.varieties
		end
	end
	---@type table<integer, PagleVarietyEntry[]>
	local varietyLists = {}

	--- A Species' ten varieties in order (VAR-R11), each `{ id, key, index, rarity, name, description, art }`
	--- (ns.VarietyList), or nil for a Species without varieties. The static list: it never says which were caught.
	---@param speciesID integer
	---@return PagleVarietyEntry[]?
	function catalogue.GetVarieties(speciesID)
		local keys = varietyKeys[speciesID]
		if not keys then
			return nil
		end
		varietyLists[speciesID] = varietyLists[speciesID] or ns.VarietyList(speciesID, keys)
		return varietyLists[speciesID]
	end

	--- Every zone areaID (`parent = 0`) in the AreaTable slice, ascending (LOG-R55).
	---@return integer[]
	function catalogue.GetZones()
		return zones
	end

	--- The area's record, or nil for an area outside the slice (LOG-R55).
	---@param areaID integer
	---@return PagleArea?
	function catalogue.GetArea(areaID)
		return areas[areaID]
	end

	--- The zone areaID a subzone belongs to, itself for a zone, nil outside the slice (LOG-R55).
	---@param areaID integer
	---@return integer?
	function catalogue.GetZoneOf(areaID)
		return zoneOf(areaID)
	end

	--- Every catch entry of a zone and its subzones, each with the `areaID` it came from; nil for an areaID that
	--- isn't a zone (LOG-R55).
	---@param zoneAreaID integer
	---@return PagleZoneCatchEntry[]?
	function catalogue.GetZoneCatches(zoneAreaID)
		return zoneCatches[zoneAreaID]
	end

	-- Each window's condition spec with its `confirmed` (LOG-R55), made once. A copy, since the generator's spec is
	-- shared with the gates that use it.
	local windowSpecs = {}
	for windowID, window in pairs(data.windows) do
		local spec = { confirmed = window.confirmed }
		for field, values in pairs(window.spec) do
			spec[field] = values
		end
		windowSpecs[windowID] = spec
	end

	--- A named window's condition spec, carrying its `confirmed`, or nil for a window the catalogue lacks (LOG-R55).
	--- Before M2 there are none (DATA-R79).
	---@param windowID string
	---@return PagleWindowSpec?
	function catalogue.GetWindowSpec(windowID)
		return windowSpecs[windowID]
	end

	--- Whether a spell is on the fishing-spell list (LOG-R2).
	---@param spellID integer
	---@return boolean
	function catalogue.IsFishingSpell(spellID)
		return fishingSpells[spellID] == true
	end

	--- The fishing-spell list (DATA-R39), in the catalogue's order, for `/pagle dev probe` (#261). Core-internal.
	---@return integer[]
	function catalogue.GetFishingSpells()
		return data.fishingSpells
	end

	--- The fishing-aura list (LOG-R20), ascending.
	---@return integer[]
	function catalogue.GetFishingAuras()
		return data.auras
	end

	--- The event list's calendar event IDs (LOG-R46), ascending.
	---@return integer[]
	function catalogue.GetEventIDs()
		return eventIDs
	end

	--- An event's weekly rule, or nil when it has none or isn't listed (LOG-R56).
	---@param eventID integer
	---@return PagleWeeklyRule?
	function catalogue.GetEventRule(eventID)
		local rule = data.events[eventID]
		if rule and next(rule) ~= nil then
			return rule
		end
		return nil
	end

	--- The baseline area an alias source stands for, or the area itself (LOG-R22).
	---@param areaID integer
	---@return integer
	function catalogue.Unalias(areaID)
		return aliases[areaID] or areaID
	end

	return catalogue
end

--- Whether a channel's spell is Fishing (LOG-R2): on the fishing-spell list of `ns.Catalogue`, the catalogue Core
--- built at login step 1 (LOG-R1). False for a nil (secret) spell and before the catalogue is built. Core's adapter
--- and FakePagle both hand it to ns.NewFishing.
---@param spellID integer?
---@return boolean
function ns.IsFishingChannel(spellID)
	return spellID ~= nil and ns.Catalogue ~= nil and ns.Catalogue.IsFishingSpell(spellID)
end

--- An item's record in `ns.Catalogue`, the catalogue Core built at login step 1 (LOG-R1), or nil before it's built
--- and for an Uncharted item (LOG-R55). The Catch log sizes every Cast it decodes by it (LOG-R65); Core's adapter and
--- FakePagle both hand it to ns.OpenCatchLog.
---@param itemID integer
---@return PagleItem?
function ns.CatalogueItem(itemID)
	return ns.Catalogue and ns.Catalogue.GetItem(itemID)
end
