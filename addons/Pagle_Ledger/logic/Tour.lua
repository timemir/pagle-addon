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
---@field label string -- its label's key in ns.L, read when the stop registers (scripts load logic/ without locale)
---@field place fun(context: LedgerSpreadContext): LedgerJournalPlace
---@field search? fun(context: LedgerSpreadContext): string
---@field news? fun(now: integer): PagleNews -- the news the book shows while the stop does, in place of Core's

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
-- matches it and often others; "a" while its name isn't loaded, or before any Catch. A letter is an ASCII letter or any
-- one UTF-8 character past ASCII, so a name that opens with "É" or a Cyrillic letter gives its first three as well.
---@param context LedgerSpreadContext
---@return string
local function searchText(context)
	local species = mostCaught(context.state, context.state.species)
	local name = species and context.text:Item(species) or ""
	local start = name:match("^[%a\194-\244][\128-\191]*[%a\194-\244][\128-\191]*[%a\194-\244][\128-\191]*")
	return start and ns.Lower(start) or "a"
end

-- A news line (IGV Contracts' `news-line`, VIEW-R41) of the news list stop's sample, `hours` before `now`, about the
-- sample's followed Angler unless `fields` say otherwise.
---@param now integer
---@param n integer
---@param kind string
---@param hours number
---@param fields table?
---@return PagleNewsItem
local function sampleLine(now, n, kind, hours, fields)
	local line = {
		id = ("%016x"):format(n),
		kind = kind,
		time = now - math.floor(hours * 3600),
		angler = 1,
		name = "Kukli Emnabi",
		region = "",
		item = 0,
		rank = 0,
		key = "",
		text = "",
		zone = 0,
		length = 0,
		new = n <= 3,
	}
	for key, value in pairs(fields or {}) do
		line[key] = value
	end
	return line
end

--- The news list stop's sample news (LED-R176): an item of every kind, the region headline last, the first three new,
--- so every row and the chosen item's page are measured with words in them (CORE-R65's representative state). The
--- names are the dev's sample text, as the sign's dev samples are (SIGN-R60); the words are Core's (Pagle.NewsWords).
---@param now integer
---@return PagleNews
function ns.TourNewsSample(now)
	return {
		state = "ok",
		items = {
			sampleLine(now, 1, "first", 1, { region = "eu", item = 6358 }),
			sampleLine(now, 2, "legend", 3, { item = 19805 }),
			sampleLine(now, 3, "prestige", 5, { rank = 3 }),
			sampleLine(now, 4, "ledger", 9),
			sampleLine(now, 5, "colour", 20, { item = 4603, key = "all-gold" }),
			sampleLine(now, 6, "hunt", 30, { key = "long_haul", text = "The Long Haul" }),
			sampleLine(now, 7, "zone", 50, { zone = 12 }),
			sampleLine(now, 8, "monster", 80, { item = 13422, length = 1626 }),
			sampleLine(now, 9, "region", 120, { angler = 0, name = "Grimtusk", region = "eu", item = 6358 }),
		},
	}
end

--- The Journal's tour stops, in tour order (CORE-R68).
---@type LedgerTourStop[]
ns.JOURNAL_TOUR = {
	{ id = "journal.home", label = "TOUR_HOME", place = home },
	{ id = "journal.zone", label = "TOUR_ZONE", place = zonePlace },
	{ id = "journal.fish", label = "TOUR_FISH", place = fishPlace },
	{
		id = "journal.trophy",
		label = "TOUR_TROPHY",
		place = function(context)
			return ns.JournalPlace.trophyRoom(landedFamily(context))
		end,
	},
	{ id = "journal.curios", label = "TOUR_CURIOS", place = ns.JournalPlace.curios },
	{
		id = "journal.legends",
		label = "TOUR_LEGENDS",
		place = function(context)
			return ns.JournalPlace.legends(caughtLegend(context))
		end,
	},
	{ id = "journal.angler", label = "TOUR_ANGLER", place = ns.JournalPlace.angler },
	-- the news list on its sample, the newest chosen (LED-R176)
	{
		id = "journal.news",
		label = "TOUR_NEWS",
		place = function()
			return ns.JournalPlace.news()
		end,
		news = ns.TourNewsSample,
	},
	{ id = "journal.search", label = "TOUR_SEARCH", place = home, search = searchText },
}
