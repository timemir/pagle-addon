if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's Species (LED-R124, LED-R140–R142, LED-R148, DATA-R112): a Species' entry, caught or not, the plain
-- hint, the fish spread and search, as page data. Pure logic over the spread context (CORE-R7); adapter/Journal.lua
-- draws it and adapter/JournalSearch.lua runs the search box.

-- Tunables: plain hint zones (LED-R141).
local HINT_ZONES = 2

-- A Species' element window IDs (LED-R10), ascending; empty when it has none.
---@param listing LedgerWorldSpecies?
---@return string[]
local function elementWindows(listing)
	return ns.SortedKeys(listing and listing.elements or {})
end

--- The plain hint (DATA-R112, LED-R141), generated from the world index, not lore: the Species' element window labels
--- joined with ", " (or "Any time"), " · pools" when any of its listed items is pool-associated, then " · " and its
--- first two listed zones by skill base (" +{n}" for the rest), then " · skill ~{lowest skill base of those two}"
--- when either has one (" · any skill" when it is 0 or below, DATA-R30). With no listed zones, the window part alone.
---@param world LedgerWorld
---@param id integer the Species ID
---@param text LedgerJournalText
---@return string
function ns.PlainHint(world, id, text)
	local L = ns.L
	local listing = world.species[id]
	local labels = {}
	for i, window in ipairs(elementWindows(listing)) do
		labels[i] = text:WindowLabel(window)
	end
	local parts = { #labels > 0 and table.concat(labels, L.HINT_WINDOW_SEPARATOR) or L.HINT_ANY_TIME }
	local listed = listing and listing.zones or {}
	local pool = false
	for _, zone in ipairs(listed) do
		local zoneIndex = world.zones[zone]
		local inZone = zoneIndex and zoneIndex.species[id]
		pool = pool or (inZone ~= nil and inZone.pool)
	end
	if pool then
		parts[#parts + 1] = L.POOLS
	end
	if #listed == 0 then
		return table.concat(parts, L.HINT_SEPARATOR)
	end
	local zones = ns.SortZonesBySkill(listed, world.skillBase)
	local skill
	for i = 1, math.min(HINT_ZONES, #zones) do
		local name = text:Zone(zones[i])
		if i == HINT_ZONES and #zones > HINT_ZONES then
			name = L.HINT_MORE:format(name, #zones - HINT_ZONES)
		end
		parts[#parts + 1] = name
		local base = world.skillBase[zones[i]]
		if base and (skill == nil or base < skill) then
			skill = base
		end
	end
	if skill then
		parts[#parts + 1] = skill > 0 and L.HINT_SKILL:format(skill) or L.HINT_ANY_SKILL
	end
	return table.concat(parts, L.HINT_SEPARATOR)
end

-- "Found in {zones}." with " Only by {element windows}." (LED-R140), nil with neither.
---@param listing LedgerWorldSpecies?
---@param text LedgerJournalText
---@return string?
local function foundIn(listing, text)
	local L = ns.L
	local zones, labels = {}, {}
	for i, zone in ipairs(listing and listing.zones or {}) do
		zones[i] = text:Zone(zone)
	end
	for i, window in ipairs(elementWindows(listing)) do
		labels[i] = text:WindowLabel(window)
	end
	local line = #zones > 0 and L.ENTRY_FOUND_IN:format(ns.JoinAnd(zones)) or ""
	if #labels > 0 then
		line = line .. L.ENTRY_ONLY_BY:format(ns.JoinAnd(labels))
	end
	if line == "" then
		return nil
	end
	return (line:gsub("^ ", ""))
end

--- Where an uncaught Species' "Read the plain hint ▸" link goes, and whether the hint is open (LED-R141): the spread
--- showing the entry passes its own place with the hint open, and keeps it open until the spread changes.
---@class LedgerHintState
---@field open boolean?
---@field place LedgerJournalPlace

--- A Species' entry (LED-R140, LED-R141): the fish spread's left page, and the zone spread's right page with a fish
--- selected. Caught: its icon in sepia, large; its name; the stamps (LED-R48); "First landed …" (the zone part left
--- out for zone 0); its blurb (left out while missing, LED-R161); "Found in …" with " Only by …"; its size line
--- once it has a record (LED-R80, by Pagle's measure, in the Angler's unit, LED-R85); and the removed line (LED-R12). Uncaught, and never named (LED-R124): a silhouette, "An unknown fish", its riddle in quotes and
--- the plain hint's link, or the plain hint itself once opened (DATA-R112).
---@param id integer the Species ID
---@param context LedgerSpreadContext
---@param hint LedgerHintState
---@return LedgerBlock[]
function ns.JournalSpeciesEntry(id, context, hint)
	local L, text = ns.L, context.text
	local state, world = context.state, context.world
	local species = state.species[id]
	if not species then
		---@type LedgerBlock[]
		local blocks = {
			{ kind = "icon", icon = id, look = "silhouette", large = true },
			{ kind = "title", text = L.ENTRY_UNKNOWN },
		}
		local riddle = text:Lore(("species.%d.riddle"):format(id))
		if riddle then
			blocks[#blocks + 1] = { kind = "text", text = L.ENTRY_RIDDLE:format(riddle) }
		end
		if hint.open then
			blocks[#blocks + 1] = { kind = "text", hand = true, text = ns.PlainHint(world, id, text) }
		else
			blocks[#blocks + 1] = { kind = "link", text = L.ENTRY_HINT_LINK, place = hint.place }
		end
		return blocks
	end
	local first = text:FirstCatch(species, L.ENTRY_FIRST, L.ENTRY_FIRST_NO_ZONE, context.formatNumber(species.n))
	---@type LedgerBlock[]
	local blocks = {
		{ kind = "icon", icon = id, look = "sepia", large = true },
		{ kind = "title", text = text:Item(id) },
		{
			kind = "stamps",
			stamps = ns.JournalStamps(ns.ShownSpeciesStars(world, state, context.celebrated, id), L.ENTRY_STAMPS),
		},
		{ kind = "text", hand = true, text = first },
	}
	local blurb = text:Lore(("species.%d.blurb"):format(id))
	if blurb then
		blocks[#blocks + 1] = { kind = "text", text = blurb }
	end
	local found = foundIn(world.species[id], text)
	if found then
		blocks[#blocks + 1] = { kind = "text", text = found }
	end
	local size = context.sizeText(species.record)
	if size then
		blocks[#blocks + 1] = { kind = "text", text = L.ENTRY_LARGEST:format(size) }
	end
	return ns.AddJournalRemovedLine(blocks, context, id)
end

--- A Species' label in the crumbs (LED-R125), on the fish and the zone spread: its name once caught, never before
--- (LED-R124).
---@param id integer
---@param context LedgerSpreadContext
---@return string
function ns.JournalFishLabel(id, context)
	return context.state.species[id] and context.text:Item(id) or ns.L.ENTRY_UNKNOWN
end

-- Tunables: search results (LED-R148), 4 zones then 6 fish.
local SEARCH_ZONES, SEARCH_FISH = 4, 6

--- One search result (LED-R148): a zone's or a caught Species' name, and the spread it opens.
---@class LedgerSearchResult
---@field label string
---@field place LedgerJournalPlace

-- The names in `names` (ID -> name) containing `query` (lowercase, plain), sorted by name then ID, at most `limit`,
-- each opening `placeOf(id)`.
---@param names { [integer]: string }
---@param query string
---@param limit integer
---@param placeOf fun(id: integer): LedgerJournalPlace
---@param results LedgerSearchResult[]
local function addMatches(names, query, limit, placeOf, results)
	local found = {}
	for id, name in pairs(names) do
		if name ~= ns.L.NAME_UNKNOWN and name:lower():find(query, 1, true) then
			found[#found + 1] = id
		end
	end
	table.sort(found, function(a, b)
		if names[a] ~= names[b] then
			return names[a] < names[b]
		end
		return a < b
	end)
	for i = 1, math.min(limit, #found) do
		results[#results + 1] = { label = names[found[i]], place = placeOf(found[i]) }
	end
end

--- Search (LED-R148): a case-insensitive substring of the names of the zones with a tile (LED-R131: charted, or
--- fished), of the caught Species, by their representative item's name (LED-R5), and of the caught Legends, never
--- anything uncaught (LED-R124). At most 4 zones then 6 fish (Species and Legends together), each part sorted by name;
--- a Legend opens the Legends spread with it chosen. A name the client hasn't loaded yet doesn't match. Nil for an
--- empty box (no dropdown); an empty list for no match.
---@param query string
---@param context LedgerSpreadContext
---@return LedgerSearchResult[]?
function ns.JournalSearch(query, context)
	if query == "" then
		return nil
	end
	query = query:lower()
	local text = context.text
	local zones, fish = {}, {}
	for _, zone in ipairs(ns.HomeZones(context)) do
		zones[zone] = text:Zone(zone)
	end
	for id in pairs(context.state.species) do
		fish[id] = text:Item(id)
	end
	-- Caught Legends, kept in `items` and never as Species (LED-R5), so their IDs never meet a Species'.
	local legends = {}
	for itemID in pairs(context.state.items) do
		if ns.ClassifyCatch(itemID, context.getItem(itemID)) == "legend" then
			legends[itemID] = true
			fish[itemID] = text:Item(itemID)
		end
	end
	local results = {}
	addMatches(zones, query, SEARCH_ZONES, function(zone)
		return ns.JournalPlace.zone(zone)
	end, results)
	addMatches(fish, query, SEARCH_FISH, function(id)
		return legends[id] and ns.JournalPlace.legends(id) or ns.JournalPlace.fish(id)
	end, results)
	return results
end

-- The fish spread's right page (LED-R142): "Where to find it", "Its waters", its listed zones as tiles in tile order
-- (LED-R131) with "caught ✓" where caught, each opening the zone's spread with the fish selected; "When" with each
-- element window's line, its state forecast now (LED-R127); and for a caught Species its ★, ★★ and ★★★ checklist,
-- then its varieties (VAR-R23).
---@param id integer
---@param context LedgerSpreadContext
---@return LedgerBlock[]
local function waters(id, context)
	local L, text = ns.L, context.text
	local state, world = context.state, context.world
	local listing, species = world.species[id], state.species[id]
	---@type LedgerBlock[]
	local blocks = { { kind = "kicker", text = L.FISH_KICKER }, { kind = "title", text = L.FISH_TITLE } }
	local tiles = {}
	for i, zone in ipairs(ns.SortZonesBySkill(listing and listing.zones or {}, world.skillBase)) do
		local tile = ns.JournalZoneTile(zone, context)
		tile.place = ns.JournalPlace.zone(zone, id)
		if species and species.zones[zone] then
			tile.line2 = L.FISH_CAUGHT_HERE
		end
		tiles[i] = tile
	end
	if #tiles > 0 then
		blocks[#blocks + 1] = { kind = "tiles", tiles = tiles, columns = 2 }
	end
	local windows = elementWindows(listing)
	if #windows > 0 then
		blocks[#blocks + 1] = { kind = "kicker", text = L.FISH_WHEN }
		for _, window in ipairs(windows) do
			blocks[#blocks + 1] = { kind = "text", hand = true, text = text:WindowLine(window) }
		end
	end
	if species then
		local stars = ns.ShownSpeciesStars(world, state, context.celebrated, id)
		local function box(star)
			return stars[star] and L.CHECK_ON or L.CHECK_OFF
		end
		local caught = ns.CAUGHT_STAR_CATCHES
		blocks[#blocks + 1] = {
			kind = "text",
			text = L.FISH_CAUGHT:format(box(1), math.min(species.n, caught), caught),
		}
		local have, need = ns.ElementProgress(listing, species)
		blocks[#blocks + 1] = { kind = "text", text = L.FISH_ELEMENT:format(box(2), have, need) }
		blocks[#blocks + 1] = {
			kind = "text",
			text = L.FISH_REGULAR:format(box(3), math.min(species.n, ns.REGULAR_CATCHES), ns.REGULAR_CATCHES),
		}
	end
	-- under the checklist, its varieties and the link to them (VAR-R23, logic/JournalVarieties.lua)
	for _, block in ipairs(ns.JournalFishVarieties(id, context)) do
		blocks[#blocks + 1] = block
	end
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_FISH, {
	-- Home ❧ {fish} (LED-R125).
	crumbs = function(args, context)
		return { { label = ns.JournalFishLabel(args.species, context), place = ns.JournalPlace.fish(args.species) } }
	end,
	draw = function(args, context)
		local id = args.species
		local hint = { open = args.hint, place = ns.JournalPlace.fish(id, true) }
		return { left = ns.JournalSpeciesEntry(id, context, hint), right = waters(id, context) }
	end,
	-- Both pages are the Species': opening its hint keeps their scroll (LED-R129).
	subjects = { left = { "species" }, right = { "species" } },
})
