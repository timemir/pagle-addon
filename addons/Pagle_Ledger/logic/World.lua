if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's world (LED-R10–R12): what it knows about the waters before anything is caught, built in memory from
-- the catalogue and never stored. Pure logic over Core's lookups, passed in (CORE-R7).

--- The catalogue lookups the world index reads (LOG-R55).
---@class LedgerWorldLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field GetZones fun(): integer[]
---@field GetArea fun(areaID: integer): PagleArea?
---@field GetZoneCatches fun(zoneAreaID: integer): PagleZoneCatchEntry[]?

--- One entry of a zone list (LED-R10): a GetZoneCatches entry without its `confirmed` flags (LED-R128).
---@class LedgerWorldEntry
---@field itemID integer
---@field areaID integer   -- the zone or subzone whose list has it
---@field window? string   -- the gate's window ID (LOG-R55)
---@field gate? table      -- the window's spec (DATA-R78)

--- A Species on one charted zone's list (LED-R10).
---@class LedgerWorldListing
---@field gated boolean                  -- every entry of its items in the zone has a `window`
---@field windows { [string]: table }    -- its windows in the zone: window ID -> spec (any entry's `gate`, DATA-R78)
---@field pool boolean                   -- pool-associated here: `pool` true for any of its items on the list (LED-R135)

--- A charted zone in the world index (LED-R10).
---@class LedgerWorldZone
---@field list LedgerWorldEntry[]                   -- the zone list, in GetZoneCatches order
---@field species { [integer]: LedgerWorldListing } -- by Species ID: the Species on the list
---@field families { [integer]: true }              -- the trophy families on the list
---@field junk boolean                              -- its junk requirement: a `junk` item on the list
---@field treasure boolean                          -- its treasure requirement: a `container` or `treasure` item

--- A Species on any zone list (LED-R10).
---@class LedgerWorldSpecies
---@field zones integer[]                -- its listed zones, ascending
---@field elements? { [string]: table }  -- its element windows: window ID -> spec; nil when it has none

--- The world index (LED-R10).
---@class LedgerWorld
---@field zones { [integer]: LedgerWorldZone }      -- by charted zone areaID
---@field charted integer[]                         -- the charted zones, ascending
---@field legends { [integer]: true }               -- the listed Legends: Legend items in any zone's catches
---@field species { [integer]: LedgerWorldSpecies } -- by Species ID, every Species on a zone list
---@field items { [integer]: true }                 -- every trophy and curio item on a zone list
---@field families { [integer]: LedgerWorldFamily } -- by family ID, every family with a weight on a zone list
---@field skillBase { [integer]: integer }          -- each zone's skill base, charted or not, when it has one
---@field getItem fun(itemID: integer): PagleItem?  -- the GetItem it was built over, for what reads it with a state

--- A trophy family's listed weights (LED-R10).
---@class LedgerWorldFamily
---@field weights integer[] -- its trophy items on any zone list, ascending item ID (each one weight)
---@field heaviest integer  -- the one with the greatest `weight`, the lowest item ID on a tie

--- Whether a listed item belongs on a zone list (LED-R10): a Species, trophy or curio item under LED-R5. Legends,
--- Noise, `other` and items GetItem doesn't know are left out.
---@param itemID integer
---@param item PagleItem?
---@return boolean
local function onList(itemID, item)
	local class = ns.ClassifyCatch(itemID, item)
	return class == "species" or class == "trophy" or class == "curio"
end

-- Notes one Species entry of a charted zone's list (LED-R10): gated only while every entry so far has a window.
---@param zoneIndex LedgerWorldZone
---@param id integer the Species ID
---@param item PagleItem
---@param catch PagleZoneCatchEntry
local function noteSpecies(zoneIndex, id, item, catch)
	local listing = zoneIndex.species[id]
	if not listing then
		listing = { gated = true, windows = {}, pool = false }
		zoneIndex.species[id] = listing
	end
	if catch.window then
		listing.windows[catch.window] = catch.gate
	else
		listing.gated = false
	end
	listing.pool = listing.pool or item.pool
end

-- Each Species' listed zones and element windows (LED-R10), from the charted zones' listings.
---@param world LedgerWorld
local function indexSpecies(world)
	-- Whether every entry of the Species in every charted zone is gated so far.
	local allGated = {}
	for _, zone in ipairs(world.charted) do
		for id, listing in pairs(world.zones[zone].species) do
			local species = world.species[id]
			if not species then
				species = { zones = {}, elements = {} }
				world.species[id] = species
				allGated[id] = true
			end
			species.zones[#species.zones + 1] = zone
			allGated[id] = allGated[id] and listing.gated
			for window, spec in pairs(listing.windows) do
				species.elements[window] = spec
			end
		end
	end
	for id, species in pairs(world.species) do
		if not allGated[id] then
			species.elements = nil
		end
	end
end

-- Each family's listed weights and its heaviest (LED-R10), from the trophy items on the charted zones' lists.
---@param world LedgerWorld
---@param getItem fun(itemID: integer): PagleItem?
local function indexFamilies(world, getItem)
	local ids = {}
	for itemID in pairs(world.items) do
		ids[#ids + 1] = itemID
	end
	table.sort(ids)
	for _, itemID in ipairs(ids) do
		local item = getItem(itemID) --[[@as PagleItem]]
		if item.category == "trophy" then
			local family = world.families[item.family]
			if not family then
				world.families[item.family] = { weights = { itemID }, heaviest = itemID }
			else
				family.weights[#family.weights + 1] = itemID
				-- Ascending item IDs, so only a strictly greater weight takes over (lowest ID on a tie).
				if (item.weight or 0) > (getItem(family.heaviest).weight or 0) then
					family.heaviest = itemID
				end
			end
		end
	end
end

--- The collection an item belongs to (LED-R5, LED-R60, LED-R63), or nil for none: the one place an item's category
--- decides its collection.
---@param item PagleItem?
---@return "junk"|"treasure"|"trophy"|"legends"?
function ns.CollectionOf(item)
	if item == nil or item.noise then
		return nil
	elseif item.legend then
		return "legends"
	end
	local category = item.category
	if category == "trophy" then
		return "trophy"
	elseif category == "junk" then
		return "junk"
	elseif category == "container" or category == "treasure" then
		return "treasure"
	end
	return nil
end

-- One zone's list and what it says (LED-R10): its Species, families and requirements. Legend items it finds go to
-- the listed Legends.
---@param world LedgerWorld
---@param catches PagleZoneCatchEntry[]
---@param getItem fun(itemID: integer): PagleItem?
---@return LedgerWorldZone
local function indexZone(world, catches, getItem)
	---@type LedgerWorldZone
	local zoneIndex = { list = {}, species = {}, families = {}, junk = false, treasure = false }
	local list = zoneIndex.list
	for _, catch in ipairs(catches) do
		local itemID = catch.itemID
		local item = itemID ~= 0 and getItem(itemID) or nil
		if onList(itemID, item) then
			---@cast item PagleItem
			-- What the Ledger reads of the entry; its `confirmed` flags change nothing (LED-R128).
			list[#list + 1] = { itemID = itemID, areaID = catch.areaID, window = catch.window, gate = catch.gate }
			if ns.ClassifyCatch(itemID, item) == "species" then
				noteSpecies(zoneIndex, item.species, item, catch)
			else
				-- A trophy or curio item (LED-R5): what it adds to the zone is its collection's.
				local collection = ns.CollectionOf(item)
				if collection == "trophy" then
					zoneIndex.families[item.family] = true
				elseif collection == "junk" then
					zoneIndex.junk = true
				else
					zoneIndex.treasure = true
				end
			end
		elseif ns.CollectionOf(item) == "legends" then
			world.legends[itemID] = true
		end
	end
	return zoneIndex
end

--- Builds the world index from the catalogue (LED-R10), at OnInitialize, when the catalogue is ready (CORE-R10).
---@param lookups LedgerWorldLookups
---@return LedgerWorld
function ns.NewWorld(lookups)
	local getItem = lookups.GetItem
	---@type LedgerWorld
	local world = {
		zones = {},
		charted = {},
		legends = {},
		species = {},
		items = {},
		families = {},
		skillBase = {},
		getItem = getItem,
	}
	for _, zone in ipairs(lookups.GetZones()) do
		local zoneIndex = indexZone(world, lookups.GetZoneCatches(zone) or {}, getItem)
		local areaRecord = lookups.GetArea(zone)
		if areaRecord and areaRecord.skillBase then
			world.skillBase[zone] = areaRecord.skillBase
		end
		if areaRecord and areaRecord.hasData and #zoneIndex.list > 0 then
			world.zones[zone] = zoneIndex
			world.charted[#world.charted + 1] = zone
			for _, catch in ipairs(zoneIndex.list) do
				local item = getItem(catch.itemID) --[[@as PagleItem]]
				if ns.ClassifyCatch(catch.itemID, item) ~= "species" then
					world.items[catch.itemID] = true
				end
			end
		end
	end
	indexSpecies(world)
	indexFamilies(world, getItem)
	return world
end

--- Each collection's world (LED-R11), each list ascending by ID (LED-R123). A removed item stays in only when caught,
--- for its page (LED-R12); counts leave it out.
---@class LedgerCollectionWorlds
---@field species integer[]  -- Species IDs
---@field junk integer[]     -- the Junk Museum: `junk` items
---@field treasure integer[] -- Treasures: `container` and `treasure` items
---@field trophy integer[]   -- the Trophy Room: trophy items, each a weight
---@field legends integer[]  -- Legend items

-- The keys of a set, ascending.
---@param set { [integer]: any }
---@return integer[]
local function sorted(set)
	local list = {}
	for id in pairs(set) do
		list[#list + 1] = id
	end
	table.sort(list)
	return list
end

--- Each collection's world (LED-R11): what is listed plus what was caught. The Species on any zone list and every
--- Species with a Catch; the trophy and curio items on any list and every one caught; the listed Legends and every
--- one caught. An uncaught item on no list appears nowhere, and neither does an uncaught removed one (LED-R12): a
--- caught one keeps its page.
---@param world LedgerWorld
---@param state LedgerState its `species` and `items`
---@return LedgerCollectionWorlds
function ns.CollectionWorlds(world, state)
	local getItem = world.getItem
	local caughtSpecies, caughtItems = state.species or {}, state.items or {}
	local sets = { species = {}, junk = {}, treasure = {}, trophy = {}, legends = {} }
	-- Whether a listed `id` stays: anything caught, or anything not removed. A Species' ID is its representative
	-- item's, so a Species counts as removed when that item is (LED-R5).
	local function kept(id, caught)
		if caught[id] then
			return true
		end
		local item = getItem(id)
		return not (item and item.removed)
	end
	for id in pairs(world.species) do
		if kept(id, caughtSpecies) then
			sets.species[id] = true
		end
	end
	for id in pairs(caughtSpecies) do
		sets.species[id] = true
	end
	for itemID in pairs(world.legends) do
		if kept(itemID, caughtItems) then
			sets.legends[itemID] = true
		end
	end
	-- Listed trophy and curio items, then every item the state holds (trophy, curio and Legend items, ledger.md › Data).
	for _, held in ipairs({ world.items, caughtItems }) do
		for itemID in pairs(held) do
			local collection = ns.CollectionOf(getItem(itemID))
			if collection and kept(itemID, caughtItems) then
				sets[collection][itemID] = true
			end
		end
	end
	return {
		species = sorted(sets.species),
		junk = sorted(sets.junk),
		treasure = sorted(sets.treasure),
		trophy = sorted(sets.trophy),
		legends = sorted(sets.legends),
	}
end

--- One "x of N" count (LED-R71).
---@class LedgerCount
---@field done integer
---@field total integer

--- Ledger completion and its parts (LED-R70, LED-R71).
---@class LedgerCompletion
---@field percent integer      -- floor(100 × done / total); 0 with nothing in total
---@field done integer
---@field total integer
---@field species LedgerCount  -- Species caught
---@field junk LedgerCount     -- Junk Museum items caught
---@field treasure LedgerCount -- Treasures caught
---@field trophy LedgerCount   -- Trophy Room weights landed
---@field zones LedgerCount    -- charted zones whose computed rank is Master
---@field legends LedgerCount  -- Legends caught: outside the percent (LED-R63)

--- The parts that make up Ledger completion (LED-R70), in the Angler page's order (LED-R71, LED-R146): each a field of
--- LedgerCompletion.
ns.COMPLETION_PARTS = { "species", "junk", "treasure", "trophy", "zones" }

-- An "x of N" over `ids`, removed ones left out of both sides (LED-R12). A Species' ID is its representative item's,
-- so a Species counts as removed when that item is (LED-R5).
---@param ids integer[]
---@param caught { [integer]: any }
---@param getItem fun(itemID: integer): PagleItem?
---@return LedgerCount
local function countOf(ids, caught, getItem)
	local count = { done = 0, total = 0 }
	for _, id in ipairs(ids) do
		local item = getItem(id)
		if not (item and item.removed) then
			count.total = count.total + 1
			if caught[id] then
				count.done = count.done + 1
			end
		end
	end
	return count
end

--- Ledger completion (LED-R70) and each of its parts (LED-R71), over each collection's world minus removed items:
--- every Species (done: caught), every Junk Museum, Treasures and Trophy Room item (done: caught) and every charted
--- zone (done: computed rank Master, `state.zones[zone].rank`, LED-R50). Legends, Noise, `other`, Uncharted and item 0
--- are outside it; the Legends' own count (LED-R63) is returned beside it.
---@param world LedgerWorld
---@param state LedgerState its `species`, `items` and `zones`
---@return LedgerCompletion
function ns.LedgerCompletion(world, state)
	local getItem = world.getItem
	local worlds = ns.CollectionWorlds(world, state)
	local caughtItems = state.items or {}
	local mastered = { done = 0, total = #world.charted }
	for _, zone in ipairs(world.charted) do
		local zoneState = state.zones and state.zones[zone]
		if zoneState and zoneState.rank == ns.ZONE_MASTER then
			mastered.done = mastered.done + 1
		end
	end
	---@type LedgerCompletion
	local completion = {
		percent = 0,
		done = 0,
		total = 0,
		species = countOf(worlds.species, state.species or {}, getItem),
		junk = countOf(worlds.junk, caughtItems, getItem),
		treasure = countOf(worlds.treasure, caughtItems, getItem),
		trophy = countOf(worlds.trophy, caughtItems, getItem),
		zones = mastered,
		legends = countOf(worlds.legends, caughtItems, getItem),
	}
	for _, part in ipairs(ns.COMPLETION_PARTS) do
		completion.done = completion.done + completion[part].done
		completion.total = completion.total + completion[part].total
	end
	if completion.total > 0 then
		completion.percent = math.floor(100 * completion.done / completion.total)
	end
	return completion
end
