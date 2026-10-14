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

-- The keys of a set, sorted.
---@generic K
---@param set table<K, any>
---@return K[]
local function sortedKeys(set)
	local keys = {}
	for key in pairs(set or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

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
	return sortedKeys(listing and listing.elements)
end

--- The plain hint (DATA-R112, LED-R141), generated from the world index, not lore: the Species' element window labels
--- joined with ", " (or "Any time"), " · pools" when any of its listed items is pool-associated, then " · " and its
--- first two listed zones by skill base (" +{n}" for the rest), then " · skill ~{lowest skill base of those two}"
--- when either has one. With no listed zones, the window part alone.
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
		parts[#parts + 1] = L.HINT_SKILL:format(skill)
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
	local state, world = context.state --[[@as LedgerState]], context.world --[[@as LedgerWorld]]
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

ns.RegisterJournalSpread(ns.JOURNAL_FISH, {
	-- Home ❧ {fish} (LED-R125).
	crumbs = function(args, context)
		return { { label = fishLabel(args.species, context), place = ns.JournalFishPlace(args.species) } }
	end,
	draw = function(args, context)
		local id = args.species
		local hint = { open = args.hint, place = { id = ns.JOURNAL_FISH, args = { species = id, hint = true } } }
		return { left = ns.JournalSpeciesEntry(id, context, hint), right = {} }
	end,
})
