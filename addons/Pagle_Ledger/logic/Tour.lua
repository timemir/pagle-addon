if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's tour stops for `/pagle dev tour` (CORE-R65, CORE-R68): each spread, opened on the Ledger's own
-- state at the moment it shows, so a screenshot shows what the player has (the most-fished zone, the most-caught
-- Species, a landed trophy family, a caught Legend). Pure logic over the Journal's context (CORE-R7);
-- adapter/Tour.lua registers them with Core and puts the book back after each.

--- One of the Journal's tour stops: where the book opens, and with `search`, the text typed into its search box.
---@class LedgerTourStop
---@field id string     -- the stop's ID under "ledger.": "journal.home"
---@field label string
---@field place fun(context: LedgerSpreadContext): LedgerJournalPlace
---@field search? fun(context: LedgerSpreadContext): string

-- Home, on the tab it opens on (LED-R130).
---@return LedgerJournalPlace
local function home()
	return ns.JournalPlace.home()
end

-- The key of `map` that `score` rates highest, ties to the lowest key; nil for an empty map.
---@param map table<integer, any>
---@param score fun(key: integer, value: any): number
---@return integer?
local function best(map, score)
	local found, top
	for key, value in pairs(map) do
		local s = score(key, value)
		if not found or s > top or (s == top and key < found) then
			found, top = key, s
		end
	end
	return found
end

-- How many entries `set` has.
---@param set table
---@return integer
local function size(set)
	local n = 0
	for _ in pairs(set) do
		n = n + 1
	end
	return n
end

-- The fished zone with the most Species caught (LED-R6), ties to the lowest areaID; nil before any.
---@param state LedgerState
---@return integer?
local function mostFishedZone(state)
	return best(state.zones, function(_, zone)
		return size(zone.species)
	end)
end

-- Of the Species IDs in `set` (keys), the one caught most often (LED-R5), ties to the lowest ID.
---@param state LedgerState
---@param set table<integer, any>
---@return integer?
local function mostCaught(state, set)
	return best(set, function(id)
		local species = state.species[id]
		return species and species.n or 0
	end)
end

-- The lowest trophy family landed (LED-R50), or nil.
---@param context LedgerSpreadContext
---@return integer?
local function landedFamily(context)
	local family
	for itemID in pairs(context.state.items) do
		local item = context.getItem(itemID)
		local landed = item and ns.ClassifyCatch(itemID, item) == "trophy" and item.family
		if landed and (not family or landed < family) then
			family = landed
		end
	end
	return family
end

-- The lowest caught Legend's item ID (LED-R4), or nil.
---@param context LedgerSpreadContext
---@return integer?
local function caughtLegend(context)
	local legend
	for itemID in pairs(context.state.items) do
		local item = context.getItem(itemID)
		if item and item.legend and (not legend or itemID < legend) then
			legend = itemID
		end
	end
	return legend
end

-- The most-fished zone, with its most-caught Species open (LED-R136); Home before any Catch.
---@param context LedgerSpreadContext
---@return LedgerJournalPlace
local function zonePlace(context)
	local state = context.state
	local zone = mostFishedZone(state)
	if not zone then
		return ns.JournalPlace.home()
	end
	return ns.JournalPlace.zone(zone, mostCaught(state, state.zones[zone].species))
end

-- The most-caught Species' fish spread (LED-R142); Home before any.
---@param context LedgerSpreadContext
---@return LedgerJournalPlace
local function fishPlace(context)
	local species = mostCaught(context.state, context.state.species)
	return species and ns.JournalPlace.fish(species) or ns.JournalPlace.home()
end

-- What the search stop types (LED-R148): the first three letters of the most-caught Species' name, lowercased, which
-- matches it and often others; "a" while its name isn't loaded, or before any Catch.
---@param context LedgerSpreadContext
---@return string
local function searchText(context)
	local species = mostCaught(context.state, context.state.species)
	local name = species and context.text:Item(species) or ""
	local start = name:match("^%a%a%a")
	return start and start:lower() or "a"
end

--- The Journal's tour stops, in tour order (CORE-R68).
---@type LedgerTourStop[]
ns.JOURNAL_TOUR = {
	{ id = "journal.home", label = ns.L.TOUR_HOME, place = home },
	{ id = "journal.zone", label = ns.L.TOUR_ZONE, place = zonePlace },
	{ id = "journal.fish", label = ns.L.TOUR_FISH, place = fishPlace },
	{
		id = "journal.trophy",
		label = ns.L.TOUR_TROPHY,
		place = function(context)
			return ns.JournalPlace.trophyRoom(landedFamily(context))
		end,
	},
	{ id = "journal.curios", label = ns.L.TOUR_CURIOS, place = ns.JournalPlace.curios },
	{
		id = "journal.legends",
		label = ns.L.TOUR_LEGENDS,
		place = function(context)
			return ns.JournalPlace.legends(caughtLegend(context))
		end,
	},
	{ id = "journal.angler", label = ns.L.TOUR_ANGLER, place = ns.JournalPlace.angler },
	{ id = "journal.search", label = ns.L.TOUR_SEARCH, place = home, search = searchText },
}
