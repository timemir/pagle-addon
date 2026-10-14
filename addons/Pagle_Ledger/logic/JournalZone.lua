if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's zone spread (LED-R135–R138), as far as M3 goes (LED-R4): a charted zone's seal, rank ladder,
-- next requirement and catches in groups on the left, "About these waters" or the selected fish's entry on the
-- right; a zone that isn't charted, its loose pages. Pure logic, everything read from the spread's context
-- (CORE-R7); the book draws it (adapter/Journal.lua). Window states are read afresh at each draw, never kept
-- (LED-R127). M4 adds the zonemaster line of LED-R137.

-- The zone spread is ns.JOURNAL_ZONE, its places ns.JournalPlace.zone (logic/Journal.lua): the zone, the Species
-- selected (LED-R136, LED-R142) and whether its entry's plain hint is open (LED-R141); it ignores any other args.

-- The groups of a charted zone's catches, in their order (LED-R135).
local SPECIES_GROUPS = { "anyTime", "pools", "dayNight", "seasonal", "events" }

-- The label of the continent tab a zone sits under (LED-R126, LED-R130, logic/Home.lua).
---@param context LedgerSpreadContext
---@param zone integer
---@return string
local function tabLabel(context, zone)
	return context.text:Continent(ns.HomeTabOf(context.getArea, zone))
end

-- Which group a listed Species sits in (LED-R135): ungated, Any time or Pools; gated, by its windows here, so a
-- gated pool-associated Species sits in its window's group.
---@param listing LedgerWorldListing
---@return string
local function groupOf(listing)
	if not listing.gated then
		return listing.pool and "pools" or "anyTime"
	end
	local onlyEvents = true
	for window in pairs(listing.windows) do
		if window == "day" or window == "night" then
			return "dayNight"
		end
		onlyEvents = onlyEvents and window:find("^event%.") ~= nil
	end
	return onlyEvents and "events" or "seasonal"
end

-- A Species row (LED-R136): its icon (a silhouette if never caught, LED-R124); its name if caught anywhere, with
-- "(caught elsewhere)" when not caught here, else "— unknown —"; in the margin each of its windows here as
-- "{label}, {state}" read now (LED-R127) and "pools" when pool-associated (none for `listing` nil, a Species not on
-- the list); its shown stars when caught here (LED-R48); and the place that selects it.
---@param context LedgerSpreadContext
---@param zone integer
---@param id integer the Species ID
---@param listing LedgerWorldListing?
---@param selected integer? the Species selected
---@return LedgerBlock
local function speciesRow(context, zone, id, listing, selected)
	local L = ns.L
	local state = context.state
	local caught = state.species[id] ~= nil
	local zoneState = state.zones[zone]
	local here = zoneState ~= nil and zoneState.species[id] ~= nil
	---@type LedgerBlock
	local row = {
		kind = "row",
		icon = id,
		look = caught and "sepia" or "silhouette",
		place = ns.JournalPlace.zone(zone, id),
		selected = id == selected or nil,
	}
	if not caught then
		row.text, row.color = L.ZONE_UNKNOWN_FISH, "faded"
	elseif here then
		row.text = context.text:Item(id)
	else
		row.text = L.ZONE_CAUGHT_ELSEWHERE:format(context.text:Item(id))
	end
	if listing then
		local margin = {}
		for _, window in ipairs(ns.SortedKeys(listing.windows)) do
			margin[#margin + 1] = context.text:WindowLine(window)
		end
		if listing.pool then
			margin[#margin + 1] = L.ZONE_POOLS_MARGIN
		end
		row.margin = #margin > 0 and margin or nil
	end
	if here then
		row.stars = ns.ShownSpeciesStars(context.world, state, context.celebrated, id)
	end
	return row
end

-- A group's header (LED-R135): "{group} · {caught here} / {total}".
---@param group string
---@param done integer
---@param total integer
---@return LedgerBlock
local function header(group, done, total)
	return { kind = "kicker", text = ns.L.ZONE_GROUP_HEADER:format(ns.L.ZONE_GROUPS[group], done, total) }
end

-- A requirement's line, ticked when met (LED-R135).
---@param text string
---@param met boolean
---@return LedgerBlock
local function ticked(text, met)
	local L = ns.L
	return { kind = "text", text = L.ZONE_REQUIREMENT:format(met and L.CHECK_ON or L.CHECK_OFF, text) }
end

-- The seal, the rank ladder, the next requirement and new to find (LED-R135, LED-R52, LED-R134).
---@param context LedgerSpreadContext
---@param zone integer
---@param blocks LedgerBlock[]
local function standing(context, zone, blocks)
	local L = ns.L
	local world, state, celebrated = context.world, context.state, context.celebrated
	local shown = ns.ShownZoneRank(world, state, celebrated, zone)
	blocks[#blocks + 1] = { kind = "seal", text = L.ZONE_RANKS[shown] or L.ZONE_UNFISHED }
	local rungs = {}
	for rank, name in ipairs(L.ZONE_RANKS) do
		rungs[rank] = { text = name, inked = rank <= shown, circled = rank == shown }
	end
	blocks[#blocks + 1] = { kind = "ladder", rungs = rungs }
	local next = ns.NextRequirement(world, state, celebrated, zone) --[[@as string]]
	blocks[#blocks + 1] = { kind = "text", text = L.ZONE_NEXT:format(next) }
	local newToFind = ns.NewToFind(world, state, celebrated, zone)
	if newToFind > 0 then
		blocks[#blocks + 1] = {
			kind = "text",
			hand = true,
			color = "red",
			text = ns.CountText(newToFind, L.ZONE_NEW_HERE_ONE, L.ZONE_NEW_HERE_OTHER),
		}
	end
end

-- The catches in groups (LED-R135): the Species groups, Trophies, Curios and Also caught here, each left out when
-- empty, rows by Species ID (families by ID).
---@param context LedgerSpreadContext
---@param zone integer
---@param selected integer?
---@param blocks LedgerBlock[]
local function catches(context, zone, selected, blocks)
	local L = ns.L
	local zoneIndex = context.world.zones[zone]
	local zoneState = context.state.zones[zone] or ns.NewZoneState()
	local groups = {}
	for _, id in ipairs(ns.SortedKeys(zoneIndex.species)) do
		local group = groupOf(zoneIndex.species[id])
		groups[group] = groups[group] or {}
		table.insert(groups[group], id)
	end
	for _, group in ipairs(SPECIES_GROUPS) do
		local ids = groups[group]
		if ids then
			local done = 0
			for _, id in ipairs(ids) do
				done = done + (zoneState.species[id] and 1 or 0)
			end
			blocks[#blocks + 1] = header(group, done, #ids)
			if group == "pools" then
				blocks[#blocks + 1] = { kind = "text", color = "faded", text = L.ZONE_POOLS_NOTE }
			end
			for _, id in ipairs(ids) do
				blocks[#blocks + 1] = speciesRow(context, zone, id, zoneIndex.species[id], selected)
			end
		end
	end

	local families = ns.SortedKeys(zoneIndex.families)
	if #families > 0 then
		local counts = ns.ZoneCounts(context.world, context.state, zone) --[[@as LedgerZoneCounts]]
		blocks[#blocks + 1] = header("trophies", counts.landed, counts.families)
		-- A family whose lore name has no text has no line, though the header counts it (LED-R161).
		for _, family in ipairs(families) do
			local name = context.text:FamilyName(family)
			if name then
				blocks[#blocks + 1] = ticked(L.ZONE_TROPHY:format(name), zoneState.families[family] == true)
			end
		end
	end

	local requirements = {}
	if zoneIndex.junk then
		requirements[#requirements + 1] = { L.ZONE_NEXT_JUNK, zoneState.junk }
	end
	if zoneIndex.treasure then
		requirements[#requirements + 1] = { L.ZONE_NEXT_TREASURE, zoneState.treasure }
	end
	if #requirements > 0 then
		local met = 0
		for _, requirement in ipairs(requirements) do
			met = met + (requirement[2] and 1 or 0)
		end
		blocks[#blocks + 1] = header("curios", met, #requirements)
		for _, requirement in ipairs(requirements) do
			blocks[#blocks + 1] = ticked(requirement[1], requirement[2])
		end
	end

	local also = {}
	for _, id in ipairs(ns.SortedKeys(zoneState.species)) do
		if not zoneIndex.species[id] then
			also[#also + 1] = id
		end
	end
	if #also > 0 then
		blocks[#blocks + 1] = { kind = "kicker", text = L.ZONE_ALSO_CAUGHT:format(#also) }
		for _, id in ipairs(also) do
			blocks[#blocks + 1] = speciesRow(context, zone, id, nil, selected)
		end
		blocks[#blocks + 1] = { kind = "text", color = "faded", text = L.ZONE_ALSO_NOTE }
		blocks[#blocks + 1] = ns.JournalHelpChartLink(context)
	end
end

-- A charted zone's left page (LED-R135).
---@param context LedgerSpreadContext
---@param zone integer
---@param selected integer?
---@return LedgerBlock[]
local function chartedLeft(context, zone, selected)
	local blocks = {
		{ kind = "kicker", text = tabLabel(context, zone) },
		{ kind = "title", text = context.text:Zone(zone) },
	}
	standing(context, zone, blocks)
	catches(context, zone, selected, blocks)
	return blocks
end

-- Each family's weights landed, of its weights in the Trophy Room's world (LED-R11, LED-R60), removed ones left out
-- of both sides (LED-R12), as the Trophy Room counts them: "x / N" by family.
---@param context LedgerSpreadContext
---@return { [integer]: string }
local function weightsByFamily(context)
	local weights = {}
	for _, family in ipairs(ns.TrophyFamilies(context.world, context.state)) do
		weights[family.id] = ns.L.ZONE_WEIGHTS:format(family.count.done, family.count.total)
	end
	return weights
end

-- "About these waters" (LED-R137, without M4's zonemaster line, LED-R4): the skill base, the zone's completion
-- (LED-R53) with its fish and families known, each family on the list with its shown stars and overall weights,
-- opening it in the Trophy Room, the reward, and the nudge to pick a fish.
---@param context LedgerSpreadContext
---@param zone integer
---@return LedgerBlock[]
local function about(context, zone)
	local L = ns.L
	local world, state = context.world, context.state
	local blocks = { { kind = "kicker", text = L.ZONE_ABOUT } }
	local skill = world.skillBase[zone]
	if skill then
		blocks[#blocks + 1] = { kind = "text", text = skill > 0 and L.ZONE_SKILL:format(skill) or L.ZONE_ANY_SKILL }
	end
	local counts = ns.ZoneCounts(world, state, zone) --[[@as LedgerZoneCounts]]
	local completion = ns.ZoneCompletion(world, state, zone) --[[@as integer]]
	blocks[#blocks + 1] = {
		kind = "text",
		text = L.ZONE_KNOWN:format(completion, counts.fishKnown, counts.fish, counts.landed, counts.families),
	}
	local families = ns.SortedKeys(world.zones[zone].families)
	if #families > 0 then
		local weights = weightsByFamily(context)
		blocks[#blocks + 1] = { kind = "kicker", text = L.ZONE_TROPHIES_HERE }
		for _, family in ipairs(families) do
			local name = context.text:FamilyName(family)
			if name then
				blocks[#blocks + 1] = {
					kind = "row",
					text = name,
					stars = ns.ShownFamilyStars(world, state, context.celebrated, family),
					value = weights[family],
					place = ns.JournalPlace.trophyRoom(family),
				}
			end
		end
	end
	blocks[#blocks + 1] = { kind = "text", text = L.ZONE_REWARD }
	blocks[#blocks + 1] = { kind = "text", hand = true, text = L.ZONE_PICK }
	return blocks
end

-- An uncharted zone's left page (LED-R138): its name, the uncharted waters lore line (left out while it has no
-- text, LED-R161) and the note that its catches still count.
---@param context LedgerSpreadContext
---@param zone integer
---@return LedgerBlock[]
local function unchartedLeft(context, zone)
	local blocks = { { kind = "title", text = context.text:Zone(zone) } }
	local lore = context.text:Lore("line.unchartedwaters.text", zone)
	if lore then
		blocks[#blocks + 1] = { kind = "text", hand = true, text = lore }
	end
	blocks[#blocks + 1] = { kind = "text", text = ns.L.ZONE_UNCHARTED_NOTE }
	return blocks
end

-- An uncharted zone's right page (LED-R138): "Loose pages", its Uncharted items caught here with their count here
-- (LED-R64); "Also caught here", each Species caught here (rows, no margin) and each trophy and curio item caught
-- here by name, or "Nothing caught here yet."; and the "Help chart the waters" link.
---@param context LedgerSpreadContext
---@param zone integer
---@return LedgerBlock[]
local function loosePages(context, zone)
	local L = ns.L
	local state = context.state
	local blocks = { { kind = "kicker", text = L.ZONE_LOOSE_PAGES } }
	for _, itemID in ipairs(ns.SortedKeys(state.uncharted)) do
		local count = state.uncharted[itemID].zones and state.uncharted[itemID].zones[zone]
		if count then
			blocks[#blocks + 1] =
				{ kind = "text", hand = true, text = L.ZONE_LOOSE_ITEM:format(context.text:Item(itemID, true), count) }
		end
	end
	blocks[#blocks + 1] = { kind = "kicker", text = L.ZONE_ALSO_CAUGHT_TITLE }
	local zoneState = state.zones[zone] or ns.NewZoneState()
	local species, items = ns.SortedKeys(zoneState.species), ns.SortedKeys(zoneState.items)
	for _, id in ipairs(species) do
		blocks[#blocks + 1] = speciesRow(context, zone, id, nil, nil)
	end
	for _, itemID in ipairs(items) do
		blocks[#blocks + 1] = { kind = "text", text = context.text:Item(itemID) }
	end
	if #species + #items == 0 then
		blocks[#blocks + 1] = { kind = "text", color = "faded", text = L.ZONE_NOTHING_YET }
	end
	blocks[#blocks + 1] = ns.JournalHelpChartLink(context)
	return blocks
end

-- The selected fish's entry (LED-R136, LED-R140, LED-R141), logic/JournalSpecies.lua's, its plain hint opening on
-- this spread.
---@param context LedgerSpreadContext
---@param zone integer
---@param species integer
---@param hint boolean?
---@return LedgerBlock[]
local function entry(context, zone, species, hint)
	local place = ns.JournalPlace.zone(zone, species, true)
	return ns.JournalSpeciesEntry(species, context, { open = hint, place = place })
end

ns.RegisterJournalSpread(ns.JOURNAL_ZONE, {
	-- Home ❧ {continent tab label} ❧ {zone}, and ❧ {fish} with one selected: its name once caught, never before
	-- (LED-R125, LED-R124). The continent crumb opens Home on that tab.
	crumbs = function(args, context)
		local zone, species = args.zone, args.species
		local crumbs = {
			{
				label = tabLabel(context, zone),
				place = ns.JournalPlace.home(ns.HomeTabOf(context.getArea, zone)),
			},
			{ label = context.text:Zone(zone), place = ns.JournalPlace.zone(zone) },
		}
		if species then
			crumbs[3] = { label = ns.JournalFishLabel(species, context), place = ns.JournalPlace.zone(zone, species) }
		end
		return crumbs
	end,
	draw = function(args, context)
		local zone, species = args.zone, args.species
		local selected = species and entry(context, zone, species, args.hint)
		if not context.world.zones[zone] then
			return { left = unchartedLeft(context, zone), right = selected or loosePages(context, zone) }
		end
		return { left = chartedLeft(context, zone, species), right = selected or about(context, zone) }
	end,
})
