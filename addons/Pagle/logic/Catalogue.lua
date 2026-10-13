---@class PagleNS
local ns = select(2, ...)

-- Core's read-only view of the generated catalogue (LOG-R55–R57): pure logic over the table passed in (CORE-R7).
-- Everything it hands out is the catalogue's own tables, or tables built once here, shared and never copied per
-- call (CORE-R18). Nothing here writes to the catalogue, and none of it goes into SavedVariables (DATA-R80).

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

--- Core's accessors over one catalogue. The public ones are published on Pagle as they are (LOG-R55); the rest are
--- Core-internal (LOG-R56).
---@class PagleCatalogue
---@field CONTENT_FINGERPRINT string
---@field GetItem fun(itemID: integer): table?
---@field GetZones fun(): integer[]
---@field GetArea fun(areaID: integer): PagleArea?
---@field GetZoneOf fun(areaID: integer): integer?
---@field GetZoneCatches fun(zoneAreaID: integer): PagleZoneCatchEntry[]?
---@field GetWindowSpec fun(windowID: string): table?, boolean?
---@field IsFishingSpell fun(spellID: integer): boolean
---@field GetFishingAuras fun(): integer[]
---@field GetEventIDs fun(): integer[]
---@field GetEventRule fun(eventID: integer): PagleWeeklyRule?
---@field Unalias fun(areaID: integer): integer

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

	---@type PagleCatalogue
	local catalogue = {
		CONTENT_FINGERPRINT = data.fingerprint,
	}

	--- The item record, or nil for an Uncharted item (LOG-R55). Before M2 no item is charted (LOG-R57).
	function catalogue.GetItem(itemID)
		return data.items[itemID]
	end

	--- Every zone areaID (`parent = 0`) in the AreaTable slice, ascending (LOG-R55).
	function catalogue.GetZones()
		return zones
	end

	--- The area's record, or nil for an area outside the slice (LOG-R55).
	function catalogue.GetArea(areaID)
		return areas[areaID]
	end

	--- The zone areaID a subzone belongs to, itself for a zone, nil outside the slice (LOG-R55).
	function catalogue.GetZoneOf(areaID)
		return zoneOf(areaID)
	end

	--- Every catch entry of a zone and its subzones, each with the `areaID` it came from; nil for an areaID that
	--- isn't a zone (LOG-R55).
	function catalogue.GetZoneCatches(zoneAreaID)
		return zoneCatches[zoneAreaID]
	end

	--- A named window's condition spec and its `confirmed`, or nil for a window the catalogue lacks (LOG-R55).
	--- Before M2 there are none (DATA-R79).
	function catalogue.GetWindowSpec(windowID)
		local window = data.windows[windowID]
		if window then
			return window.spec, window.confirmed
		end
		return nil
	end

	--- Whether a spell is on the fishing-spell list (LOG-R2).
	function catalogue.IsFishingSpell(spellID)
		return fishingSpells[spellID] == true
	end

	--- The fishing-aura list (LOG-R20), ascending.
	function catalogue.GetFishingAuras()
		return data.auras
	end

	--- The event list's calendar event IDs (LOG-R46), ascending.
	function catalogue.GetEventIDs()
		return eventIDs
	end

	--- An event's weekly rule, or nil when it has none or isn't listed (LOG-R56).
	function catalogue.GetEventRule(eventID)
		local rule = data.events[eventID]
		if rule and next(rule) ~= nil then
			return rule
		end
		return nil
	end

	--- The baseline area an alias source stands for, or the area itself (LOG-R22).
	function catalogue.Unalias(areaID)
		return aliases[areaID] or areaID
	end

	return catalogue
end
