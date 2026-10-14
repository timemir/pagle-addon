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

--- Zones in tile order (LED-R131): by skill base, zones without one last, then by areaID. Sorts `zones` in place.
---@param zones integer[]
---@param skillBase { [integer]: integer }
---@return integer[]
function ns.SortZonesBySkill(zones, skillBase)
	table.sort(zones, function(a, b)
		local sa, sb = skillBase[a], skillBase[b]
		if sa ~= sb then
			if sa == nil or sb == nil then
				return sb == nil
			end
			return sa < sb
		end
		return a < b
	end)
	return zones
end

-- A Species' element window IDs (LED-R10), ascending; empty when it has none.
---@param listing LedgerWorldSpecies?
---@return string[]
local function elementWindows(listing)
	local windows = {}
	for window in pairs(listing and listing.elements or {}) do
		windows[#windows + 1] = window
	end
	table.sort(windows)
	return windows
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
	local zones = {}
	local pool = false
	for i, zone in ipairs(listing and listing.zones or {}) do
		zones[i] = zone
		local zoneIndex = world.zones[zone]
		local inZone = zoneIndex and zoneIndex.species[id]
		pool = pool or (inZone ~= nil and inZone.pool)
	end
	if pool then
		parts[#parts + 1] = L.HINT_POOLS
	end
	if #zones == 0 then
		return table.concat(parts, L.HINT_SEPARATOR)
	end
	ns.SortZonesBySkill(zones, world.skillBase)
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

--- A list as prose (LED-R140): "A", "A and B", "A, B and C".
---@param items string[]
---@return string
function ns.JoinAnd(items)
	local L = ns.L
	if #items <= 1 then
		return items[1] or ""
	end
	return table.concat(items, L.LIST_SEPARATOR, 1, #items - 1) .. L.LIST_LAST .. items[#items]
end

-- The three stamps of a caught Species (LED-R140), inked when shown (LED-R48, LED-R92).
---@param stars LedgerStars
---@return { text: string, inked: boolean }[]
local function stamps(stars)
	local list = {}
	for star, text in ipairs(ns.L.ENTRY_STAMPS) do
		list[star] = { text = text, inked = stars[star] == true }
	end
	return list
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
--- out for zone 0); its blurb (left out while missing, LED-R161); "Found in …" with " Only by …"; and the removed
--- line (LED-R12). Uncaught, and never named (LED-R124): a silhouette, "An unknown fish", its riddle in quotes and
--- the plain hint's link, or the plain hint itself once opened (DATA-R112).
---@param id integer the Species ID
---@param context LedgerJournalContext
---@param hint LedgerHintState
---@return LedgerBlock[]
function ns.JournalSpeciesEntry(id, context, hint)
	local L, text = ns.L, context.text
	local state = context.state --[[@as LedgerState]]
	local world = context.world --[[@as LedgerWorld]]
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
	local date, who, count = text:Date(species.date), text:Character(species.char), context.formatNumber(species.n)
	local first = species.zone ~= 0 and L.ENTRY_FIRST:format(date, text:Zone(species.zone), who, count)
		or L.ENTRY_FIRST_NO_ZONE:format(date, who, count)
	---@type LedgerBlock[]
	local blocks = {
		{ kind = "icon", icon = id, look = "sepia", large = true },
		{ kind = "title", text = text:Item(id) },
		{ kind = "stamps", stamps = stamps(ns.ShownSpeciesStars(world, state, context.celebrated or {}, id)) },
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
	local item = context.getItem and context.getItem(id)
	if item and item.removed then
		blocks[#blocks + 1] = { kind = "text", text = L.ENTRY_REMOVED }
	end
	return blocks
end

--- The fish spread's ID (LED-R142); its args are `{ species = id, hint = true? }`.
ns.JOURNAL_FISH = "fish"

--- The fish spread's place for Species `id` (LED-R142): what search and notes open.
---@param id integer
---@return LedgerJournalPlace
function ns.JournalFishPlace(id)
	return { id = ns.JOURNAL_FISH, args = { species = id } }
end

-- A Species' label in the crumbs (LED-R125): its name once caught, never before (LED-R124).
---@param id integer
---@param context LedgerJournalContext
---@return string
local function fishLabel(id, context)
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

--- Search (LED-R148, zones and Species; Legends come in M4): a case-insensitive substring of the names of the zones
--- with a tile (LED-R131: charted, or fished) and of the caught Species, by their representative item's name (LED-R5),
--- never anything uncaught (LED-R124). At most 4 zones then 6 fish, each part sorted by name. A name the client
--- hasn't loaded yet doesn't match. Nil for an empty box (no dropdown); an empty list for no match.
---@param query string
---@param context LedgerJournalContext
---@return LedgerSearchResult[]?
function ns.JournalSearch(query, context)
	if query == "" then
		return nil
	end
	query = query:lower()
	local text = context.text
	local world = context.world --[[@as LedgerWorld]]
	local state = context.state --[[@as LedgerState]]
	local zones, fish = {}, {}
	for _, zone in ipairs(world.charted) do
		zones[zone] = text:Zone(zone)
	end
	for zone in pairs(state.zones) do
		zones[zone] = text:Zone(zone)
	end
	for id in pairs(state.species) do
		fish[id] = text:Item(id)
	end
	local results = {}
	addMatches(zones, query, SEARCH_ZONES, function(zone)
		return ns.JournalZonePlace(zone)
	end, results)
	addMatches(fish, query, SEARCH_FISH, ns.JournalFishPlace, results)
	return results
end

-- The fish spread's right page (LED-R142): "Where to find it", "Its waters", its listed zones as tiles in tile order
-- (LED-R131) with "caught ✓" where caught, each opening the zone's spread with the fish selected; "When" with each
-- element window's line, its state forecast now (LED-R127); and for a caught Species its ★★ and ★★★ checklist.
---@param id integer
---@param context LedgerJournalContext
---@return LedgerBlock[]
local function waters(id, context)
	local L, text = ns.L, context.text
	local state = context.state --[[@as LedgerState]]
	local world = context.world --[[@as LedgerWorld]]
	local listing, species = world.species[id], state.species[id]
	---@type LedgerBlock[]
	local blocks = { { kind = "kicker", text = L.FISH_KICKER }, { kind = "title", text = L.FISH_TITLE } }
	local zones = {}
	for i, zone in ipairs(listing and listing.zones or {}) do
		zones[i] = zone
	end
	local tiles = {}
	for i, zone in ipairs(ns.SortZonesBySkill(zones, world.skillBase)) do
		local tile = ns.JournalZoneTile(zone, context)
		tile.place = ns.JournalZonePlace(zone, id)
		if species and species.zones[zone] then
			tile.line2 = L.FISH_CAUGHT_HERE
		end
		tiles[i] = tile
	end
	if #tiles > 0 then
		blocks[#blocks + 1] = { kind = "tiles", tiles = tiles }
	end
	local windows = elementWindows(listing)
	if #windows > 0 then
		blocks[#blocks + 1] = { kind = "kicker", text = L.FISH_WHEN }
		for _, window in ipairs(windows) do
			blocks[#blocks + 1] = { kind = "text", hand = true, text = text:WindowLine(window) }
		end
	end
	if species then
		local stars = ns.ShownSpeciesStars(world, state, context.celebrated or {}, id)
		local function box(star)
			return stars[star] and L.CHECK_ON or L.CHECK_OFF
		end
		local have, need = ns.ElementProgress(listing, species)
		blocks[#blocks + 1] = { kind = "text", text = L.FISH_ELEMENT:format(box(2), have, need) }
		blocks[#blocks + 1] = {
			kind = "text",
			text = L.FISH_REGULAR:format(box(3), math.min(species.n, ns.REGULAR_CATCHES), ns.REGULAR_CATCHES),
		}
	end
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_FISH, {
	-- Home ❧ {fish} (LED-R125).
	crumbs = function(args, context)
		return { { label = fishLabel(args.species, context), place = ns.JournalFishPlace(args.species) } }
	end,
	draw = function(args, context)
		local id = args.species
		local hint = { open = args.hint, place = { id = ns.JOURNAL_FISH, args = { species = id, hint = true } } }
		return { left = ns.JournalSpeciesEntry(id, context, hint), right = waters(id, context) }
	end,
})
