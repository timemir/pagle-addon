if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's Home (LED-R130–R133, LED-R149): the spread the Journal opens on. The left page has every charted
-- and every fished zone as a tile under its continent's tab; the right page the bookplate summary, Notes to self and
-- the contents; the brass plate sits on the cover. Pure logic over the Journal's context (CORE-R7); its M3 stage
-- left out titles, Prestige and Legends, and M4 brings them back (LED-R4).

--- The tab of every continent but the Eastern Kingdoms (0) and Kalimdor (1): Home's args `{ tab = ns.OTHER_TAB }`.
ns.OTHER_TAB = "other"

-- The tabs, in their order (LED-R130).
local TAB_ORDER = { 0, 1, ns.OTHER_TAB }

-- At most this many Notes to self (LED-R133, Tunables).
local MAX_NOTES = 3

--- The continent tab a zone's tile sits under (LED-R130): its `continent` from GetArea when 0 or 1, else "Other
--- waters" (any other ContinentID, or a zone GetArea doesn't know). Home's args take it as `tab`; its label is
--- `context.text:Continent(tab)`.
---@param getArea fun(areaID: integer): PagleArea?
---@param zone integer
---@return integer|string
function ns.HomeTabOf(getArea, zone)
	local area = getArea(zone)
	local continent = area and area.continent
	if continent == 0 or continent == 1 then
		return continent
	end
	return ns.OTHER_TAB
end

-- The left page (LED-R130): kicker, title, the tabs that have a tile, and the chosen tab's tiles. `chosen` is the
-- tab asked for; when it has no tile, the first tab shown.
---@param context LedgerSpreadContext
---@param chosen integer|string?
---@return LedgerBlock[] left
---@return integer|string? tab the tab shown
local function leftPage(context, chosen)
	local L = ns.L
	local byTab = {}
	for _, zone in ipairs(ns.HomeZones(context)) do
		local tab = ns.HomeTabOf(context.getArea, zone)
		byTab[tab] = byTab[tab] or {}
		table.insert(byTab[tab], ns.JournalZoneTile(zone, context))
	end
	local shown = {}
	for _, tab in ipairs(TAB_ORDER) do
		if byTab[tab] then
			shown[#shown + 1] = tab
		end
	end
	if not byTab[chosen] then
		chosen = shown[1]
	end
	local tabs = {}
	for i, tab in ipairs(shown) do
		tabs[i] = {
			text = context.text:Continent(tab),
			on = tab == chosen,
			place = ns.JournalPlace.home(tab),
		}
	end
	return {
		{ kind = "kicker", text = L.HOME_KICKER },
		{ kind = "title", text = L.HOME_TITLE },
		{ kind = "tabs", tabs = tabs },
		{ kind = "tiles", tiles = chosen and byTab[chosen] or {} },
	},
		chosen
end

-- Note 1, the next rank (LED-R133): of the fished charted zones shown Visitor to Expert with no new to find, the one
-- with the highest completion (ties: higher rank, lower skill base, lower areaID).
---@param context LedgerSpreadContext
---@param zones integer[] the zones with a tile, in tile order
---@return LedgerBlock?
local function nextRankNote(context, zones)
	local world, state, celebrated = context.world, context.state, context.celebrated
	local best, bestRank, bestCompletion
	-- Tile order is skill base then areaID, so the first of equals in it wins the last two ties.
	for _, zone in ipairs(zones) do
		if world.zones[zone] and state.zones[zone] then
			local rank = ns.ShownZoneRank(world, state, celebrated, zone)
			local completion = ns.ZoneCompletion(world, state, zone) --[[@as integer]]
			local applies = rank >= 1 and rank < ns.ZONE_MASTER and ns.NewToFind(world, state, celebrated, zone) == 0
			if
				applies
				and (not best or completion > bestCompletion or (completion == bestCompletion and rank > bestRank))
			then
				best, bestRank, bestCompletion = zone, rank, completion
			end
		end
	end
	if not best then
		return nil
	end
	local line = ns.L.HOME_NOTE_RANK:format(
		context.text:Zone(best),
		ns.L.ZONE_RANKS[bestRank],
		ns.NextRequirement(world, state, celebrated, best)
	)
	return { kind = "link", text = line, hand = true, place = ns.JournalPlace.zone(best) }
end

-- Note 2, new to find (LED-R133): the first zone in tile order with new to find.
---@param context LedgerSpreadContext
---@param zones integer[] the zones with a tile, in tile order
---@return LedgerBlock?
local function newToFindNote(context, zones)
	for _, zone in ipairs(zones) do
		local count = ns.NewToFind(context.world, context.state, context.celebrated, zone)
		if count > 0 then
			local line = ns.L.HOME_NOTE_NEW:format(context.text:Zone(zone), count)
			return { kind = "link", text = line, hand = true, place = ns.JournalPlace.zone(zone) }
		end
	end
	return nil
end

-- Note 3, the next star (LED-R133): the caught, not removed Species without a shown ★★★ with the most Catches (ties:
-- lower Species ID). Only a caught Species is ever named (LED-R124).
---@param context LedgerSpreadContext
---@return LedgerBlock?
local function nextStarNote(context)
	local world, state, celebrated = context.world, context.state, context.celebrated
	local best, bestN
	for id, species in pairs(state.species) do
		local item = context.getItem(id)
		local removed = item and item.removed
		if not removed and not ns.ShownSpeciesStars(world, state, celebrated, id)[3] then
			if not best or species.n > bestN or (species.n == bestN and id < best) then
				best, bestN = id, species.n
			end
		end
	end
	if not best then
		return nil
	end
	local line = ns.L.HOME_NOTE_STAR:format(context.text:Item(best), ns.REGULAR_CATCHES - bestN)
	return { kind = "link", text = line, hand = true, place = ns.JournalPlace.fish(best) }
end

--- Notes to self (LED-R133): at most three progress nudges, in order, each only if it applies and each opening the
--- spread it names: the next rank, new to find and the next star; "Go fishing!" with none. None says what is
--- catchable now. Each is a handwritten link (or text, for "Go fishing!").
---@param context LedgerSpreadContext
---@return LedgerBlock[]
function ns.NotesToSelf(context)
	local zones = ns.HomeZones(context)
	local notes = {}
	local candidates = {
		nextRankNote(context, zones) or false,
		newToFindNote(context, zones) or false,
		nextStarNote(context) or false,
	}
	for _, note in ipairs(candidates) do
		if note and #notes < MAX_NOTES then
			notes[#notes + 1] = note
		end
	end
	if #notes == 0 then
		notes[1] = { kind = "text", text = ns.L.HOME_NOTE_NONE, hand = true }
	end
	return notes
end

-- "x / N" over counts summed, in the client's number format.
---@param format fun(n: integer): string
---@param ... LedgerCount
---@return string
local function countText(format, ...)
	local done, total = 0, 0
	for _, count in ipairs({ ... }) do
		done, total = done + count.done, total + count.total
	end
	return ns.L.COUNT_OF:format(format(done), format(total))
end

-- The right page (LED-R132): the bookplate summary (the shown level in large numerals with the Prestige emblem and
-- stars beside them, the active title in handwriting, Ledger completion's seal), the ink XP bar, Notes to self, and
-- In this Ledger's contents with M4's Legends line, each line opening its spread (LED-R4).
---@param context LedgerSpreadContext
---@return LedgerBlock[]
local function rightPage(context)
	local L = ns.L
	local state, celebrated = context.state, context.celebrated
	local completion = ns.LedgerCompletion(context.world, state)
	local _, title = ns.ActiveTitle(context --[[@as LedgerTitleView]])
	local right = {
		{
			kind = "bookplate",
			text = tostring(ns.ShownLevel(state, celebrated)),
			value = L.HOME_LEVEL,
			seal = L.HOME_PERCENT:format(completion.percent),
			mark = ns.PrestigeMark(state.prestige),
			signature = title,
		},
		{ kind = "xpBar", bar = ns.InkXpBar(state, celebrated, context.now, context.formatNumber) },
		{ kind = "kicker", text = L.HOME_NOTES },
	}
	for _, note in ipairs(ns.NotesToSelf(context)) do
		right[#right + 1] = note
	end
	right[#right + 1] = { kind = "kicker", text = L.HOME_CONTENTS }
	right[#right + 1] = {
		kind = "leader",
		text = L.TROPHY_TITLE,
		value = countText(context.formatNumber, completion.trophy),
		place = ns.JournalPlace.trophyRoom(),
	}
	right[#right + 1] = {
		kind = "leader",
		text = L.HOME_CURIOS,
		value = countText(context.formatNumber, completion.junk, completion.treasure),
		place = ns.JournalPlace.curios(),
	}
	right[#right + 1] = {
		kind = "leader",
		text = L.LEGENDS_TITLE,
		value = countText(context.formatNumber, completion.legends),
		place = ns.JournalPlace.legends(),
	}
	right[#right + 1] = { kind = "leader", text = L.HOME_ANGLER, place = ns.JournalPlace.angler() }
	return right
end

--- The brass plate on the cover (LED-R149): "Lv {shown level} · {active title} · Ledger {p}%", the title and its
--- separator left out while the active title has no lore text (LED-R161).
---@param context LedgerSpreadContext
---@return string
function ns.BrassPlate(context)
	local state = context.state
	local level = ns.ShownLevel(state, context.celebrated)
	local percent = ns.LedgerCompletion(context.world, state).percent
	local _, title = ns.ActiveTitle(context --[[@as LedgerTitleView]])
	if title then
		return ns.L.BRASS_PLATE_TITLE:format(level, title, percent)
	end
	return ns.L.BRASS_PLATE:format(level, percent)
end

--- Home as a spread (LED-R130–R133): no crumbs of its own; its args' `tab` chooses a continent tab. The tab last
--- shown is kept for the next drawing without one (the Home crumb, back), so the first tab shown is chosen only at
--- the first opening.
---@return LedgerSpread
function ns.NewHomeSpread()
	---@type integer|string?
	local lastTab
	return {
		crumbs = function()
			return {}
		end,
		draw = function(args, context)
			local left, tab = leftPage(context, args.tab == nil and lastTab or args.tab)
			lastTab = tab
			return { left = left, right = rightPage(context) }
		end,
		-- The left page is the tab's; the right page is Home's alone, so another tab keeps its scroll (LED-R129).
		subjects = { left = { "tab" }, right = {} },
	}
end

ns.RegisterJournalSpread(ns.JOURNAL_HOME, ns.NewHomeSpread())
