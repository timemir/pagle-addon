if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Where a Hunt bites (HNT-R6, HNT-R7, HNT-R30–R34): pure logic over the catalogue calls passed in (CORE-R7). The
-- adapter builds it once, at OnInitialize, as `ns.where[huntID]`; nothing here is worked out per Cast (HNT-R137).

--- The catalogue calls where-it-bites reads (LOG-R55): Core's own, as Pagle publishes them.
---@class HuntsWaterLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field GetZones fun(): integer[]
---@field GetZoneCatches fun(zoneAreaID: integer): PagleZoneCatchEntry[]?

--- Where one Hunt bites, worked out at load.
---@class HuntWhere
---@field waters integer[]      -- areaIDs, ascending (HNT-R30); empty when it has none
---@field isWater table<integer, true>   -- the same areaIDs as a set, for ns.InWaters

---@class PagleHuntsNS
---@field where table<string, HuntWhere>   -- by Hunt ID, built at OnInitialize (HNT-R137)

-- The areaIDs of a set, ascending.
---@param set table<integer, true>
---@return integer[]
local function sorted(set)
	local list = {}
	for areaID in pairs(set) do
		list[#list + 1] = areaID
	end
	table.sort(list)
	return list
end

-- Which catch entries make a Hunt's waters (HNT-R30), or nil for a Hunt that has none by rule: one with `areas`,
-- or a generated class target (only `fixed.*` classes are walked).
---@param hunt HuntDef
---@param list HuntList
---@param getItem fun(itemID: integer): PagleItem?
---@return (fun(entry: PagleZoneCatchEntry): boolean)?
local function watersTest(hunt, list, getItem)
	local function ofSpecies(entry)
		local item = getItem(entry.itemID)
		return item ~= nil and item.species == hunt.species
	end
	if hunt.kind == "natural" then
		-- Its Species, by its own window: a natural Hunt targets a Species (DATA-R86).
		return function(entry)
			return entry.window == hunt.window and ofSpecies(entry)
		end
	end
	if hunt.conditions and hunt.conditions.areas then
		return nil
	end
	if hunt.species then
		return ofSpecies
	end
	if hunt.class and hunt.class:sub(1, 6) == "fixed." then
		local members = list:Class(hunt.class) or {}
		return function(entry)
			return members[entry.itemID] == true
		end
	end
	return nil
end

--- Where every Hunt of `list` bites, by Hunt ID, Retired Hunts and Hunts not yet out included (HNT-R30).
---@param list HuntList
---@param lookups HuntsWaterLookups
---@return table<string, HuntWhere>
function ns.NewWhere(list, lookups)
	-- Every catch entry of the catalogue, walked once (HNT-R30).
	local entries = {}
	for _, zone in ipairs(lookups.GetZones()) do
		for _, entry in ipairs(lookups.GetZoneCatches(zone) or {}) do
			entries[#entries + 1] = entry
		end
	end

	local where = {}
	for _, hunt in ipairs(list:Hunts()) do
		local waters = {}
		local test = watersTest(hunt, list, lookups.GetItem)
		if test then
			for _, entry in ipairs(entries) do
				if test(entry) then
					waters[entry.areaID] = true
				end
			end
		end
		where[hunt.id] = { waters = sorted(waters), isWater = waters }
	end
	return where
end

--- Whether a Cast was fished in the Hunt's waters (HNT-R25, HNT-R30): its subzone or zone is one of them. A Hunt
--- without waters holds everywhere (its `areas`, if any, constrain it through MatchesConditions), except a natural
--- Hunt, whose waters the data left empty: it has no effort Casts. Reads `ns.where`, built at load.
---@param hunt HuntDef
---@param cast { conditions: { zone: integer?, subzone: integer? } }
---@return boolean
function ns.InWaters(hunt, cast)
	local where = ns.where[hunt.id]
	if #where.waters == 0 then
		return hunt.kind ~= "natural"
	end
	local conditions = cast.conditions
	return where.isWater[conditions.subzone] == true or where.isWater[conditions.zone] == true
end
