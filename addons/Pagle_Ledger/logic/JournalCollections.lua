if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's collection spreads (LED-R143, LED-R144): the Trophy Room, with its families and measuring
-- boards, and Curios, with the Junk Museum's plinths, Treasures and the loose pages of Uncharted catches. Pure logic,
-- everything read from the spread's context (CORE-R7); the book draws it (adapter/Journal.lua,
-- adapter/JournalCollections.lua). Each "x of N" is World's count, removed items out of both sides (LED-R12).

--- The Trophy Room's ID (LED-R125); its args may name a `family` to open on (LED-R137's "Trophies landed here").
ns.JOURNAL_TROPHY_ROOM = "trophy"

--- Curios' ID (LED-R125): the Junk Museum, Treasures and the loose pages of Uncharted catches.
ns.JOURNAL_CURIOS = "curios"

--- A set of stars as the Journal prints it (LED-R48): three marks, ★ for each star shown and ☆ for each blank, so
--- ★★★ without ★★ reads "★☆★".
---@param stars LedgerStars
---@return string
function ns.JournalStars(stars)
	local L = ns.L
	local marks = {}
	for star = 1, 3 do
		marks[star] = stars[star] and L.STAR_ON or L.STAR_OFF
	end
	return table.concat(marks)
end

--- A trophy family as the Trophy Room shows it (LED-R143): its weights in the Trophy Room's world (LED-R11), and the
--- "x / N" of those not removed (LED-R12).
---@class LedgerTrophyFamily
---@field id integer
---@field weights integer[] -- its trophy items in the world, ascending item ID
---@field count LedgerCount

-- The Trophy Room's families (LED-R60, LED-R143): the trophy items of the world grouped by family, ascending family
-- ID (LED-R123).
---@param context LedgerJournalContext
---@return LedgerTrophyFamily[]
local function trophyFamilies(context)
	local state = context.state --[[@as LedgerState]]
	local getItem = context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	local worlds = ns.CollectionWorlds(context.world --[[@as LedgerWorld]], state, getItem)
	local byID, families = {}, {}
	for _, itemID in ipairs(worlds.trophy) do
		local item = getItem(itemID) --[[@as PagleItem]]
		local family = byID[item.family]
		if not family then
			family = { id = item.family, weights = {}, count = { done = 0, total = 0 } }
			byID[item.family] = family
			families[#families + 1] = family
		end
		family.weights[#family.weights + 1] = itemID
		if not item.removed then
			family.count.total = family.count.total + 1
			if state.items[itemID] then
				family.count.done = family.count.done + 1
			end
		end
	end
	table.sort(families, function(a, b)
		return a.id < b.id
	end)
	return families
end

-- A family's name: its lore name (`family.<id>.name`, LED-R160), "…" while it has none (LED-R126).
---@param context LedgerJournalContext
---@param family integer
---@return string
local function familyName(context, family)
	return context.text:Lore(("family.%d.name"):format(family)) or ns.L.NAME_UNKNOWN
end

-- The Trophy Room's left page (LED-R143): its title, the weights landed of the room's, and the family index, each
-- line the family's name and shown stars (LED-R48), its "x / N", opening it on the right page.
---@param context LedgerJournalContext
---@param families LedgerTrophyFamily[]
---@return LedgerBlock[]
local function trophyIndex(context, families)
	local L = ns.L
	local format = context.formatNumber
	local count = ns.LedgerCompletion(
		context.world --[[@as LedgerWorld]],
		context.state --[[@as LedgerState]],
		context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	).trophy
	local blocks = {
		{ kind = "title", text = L.TROPHY_TITLE },
		{ kind = "text", text = L.TROPHY_WEIGHTS:format(format(count.done), format(count.total)) },
	}
	for _, family in ipairs(families) do
		local stars = ns.ShownFamilyStars(
			context.world --[[@as LedgerWorld]],
			context.state --[[@as LedgerState]],
			context.celebrated --[[@as LedgerCelebrated]],
			family.id,
			context.getItem --[[@as fun(itemID: integer): PagleItem?]]
		)
		blocks[#blocks + 1] = {
			kind = "leader",
			text = L.TROPHY_INDEX_LINE:format(familyName(context, family.id), ns.JournalStars(stars)),
			value = L.TROPHY_INDEX_COUNT:format(format(family.count.done), format(family.count.total)),
			place = { id = ns.JOURNAL_TROPHY_ROOM, args = { family = family.id } },
		}
	end
	return blocks
end

-- A family's measuring board (LED-R143, LED-R62): a tick per weight not removed, by its real weight in pounds,
-- placed from the lightest (0) to the heaviest (1), the middle for one alone, and inked where landed.
---@param context LedgerJournalContext
---@param family LedgerTrophyFamily
---@return LedgerBoardTick[]
local function board(context, family)
	local getItem = context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	local landed = (context.state --[[@as LedgerState]]).items
	local weights = {}
	for _, itemID in ipairs(family.weights) do
		local item = getItem(itemID) --[[@as PagleItem]]
		if not item.removed then
			weights[#weights + 1] = { itemID = itemID, weight = item.weight or 0 }
		end
	end
	table.sort(weights, function(a, b)
		if a.weight ~= b.weight then
			return a.weight < b.weight
		end
		return a.itemID < b.itemID
	end)
	local ticks = {}
	local lightest, heaviest = weights[1] and weights[1].weight, weights[#weights] and weights[#weights].weight
	for i, weight in ipairs(weights) do
		local span = heaviest - lightest
		ticks[i] = {
			text = tostring(weight.weight),
			at = span > 0 and (weight.weight - lightest) / span or 0.5,
			inked = landed[weight.itemID] ~= nil,
		}
	end
	return ticks
end

-- The heaviest weight of a family landed, removed or not (its Catches keep their records, LED-R12); nil for none.
---@param context LedgerJournalContext
---@param family LedgerTrophyFamily
---@return integer?
local function heaviestLanded(context, family)
	local getItem = context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	local landed = (context.state --[[@as LedgerState]]).items
	local heaviest
	for _, itemID in ipairs(family.weights) do
		local weight = (getItem(itemID) --[[@as PagleItem]]).weight or 0
		if landed[itemID] and (heaviest == nil or weight > heaviest) then
			heaviest = weight
		end
	end
	return heaviest
end

-- The Trophy Room's right page (LED-R143): the chosen family's name, its three stamps (its shown stars, LED-R48), its
-- measuring board in real pounds (LED-R62), what is landed of it, and the charted zones whose list has it.
---@param context LedgerJournalContext
---@param family LedgerTrophyFamily
---@return LedgerBlock[]
local function familyPage(context, family)
	local L = ns.L
	local format = context.formatNumber
	local world = context.world --[[@as LedgerWorld]]
	local stars = ns.ShownFamilyStars(
		world,
		context.state --[[@as LedgerState]],
		context.celebrated --[[@as LedgerCelebrated]],
		family.id,
		context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	)
	local stamps = {}
	for star, text in ipairs(L.TROPHY_STAMPS) do
		stamps[star] = { text = text, inked = stars[star] == true }
	end
	local heaviest = heaviestLanded(context, family)
	local landed = heaviest
			and L.TROPHY_LANDED:format(format(family.count.done), format(family.count.total), format(heaviest))
		or L.TROPHY_NONE_LANDED
	local blocks = {
		{ kind = "title", text = familyName(context, family.id) },
		{ kind = "stamps", stamps = stamps },
		{ kind = "board", ticks = board(context, family) },
		{ kind = "text", text = L.TROPHY_POUNDS, color = "faded" },
		{ kind = "text", text = landed, hand = true },
	}
	local zones = {}
	for _, zone in ipairs(world.charted) do
		if world.zones[zone].families[family.id] then
			zones[#zones + 1] = context.text:Zone(zone)
		end
	end
	if #zones > 0 then
		blocks[#blocks + 1] = { kind = "text", text = L.ENTRY_FOUND_IN:format(ns.JoinAnd(zones)) }
	end
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_TROPHY_ROOM, {
	-- Home ❧ The Trophy Room (LED-R125).
	crumbs = function()
		return { { label = ns.L.TROPHY_TITLE, place = { id = ns.JOURNAL_TROPHY_ROOM } } }
	end,
	-- The family index on the left, the family `args.family` on the right: the first when it names none in the room.
	draw = function(args, context)
		local families = trophyFamilies(context)
		local chosen = families[1]
		for _, family in ipairs(families) do
			if family.id == args.family then
				chosen = family
			end
		end
		return { left = trophyIndex(context, families), right = chosen and familyPage(context, chosen) or {} }
	end,
})

-- A curio's plaque (lore, `sub.<itemID>.plaque`, LED-R160); nil without text, so its line is left out (LED-R161).
---@param context LedgerJournalContext
---@param itemID integer
---@return string?
local function plaque(context, itemID)
	return context.text:Lore(("sub.%d.plaque"):format(itemID))
end

-- The Junk Museum, Curios' left page (LED-R144): its title, the exhibits caught of its world's (removed out of both
-- sides, LED-R12), and a plinth per junk item of the world, ascending item ID (LED-R123): caught, its icon, name and
-- plaque; uncaught, never named (LED-R124): a silhouette, "An empty plinth" and the shared lore line.
---@param context LedgerJournalContext
---@param worlds LedgerCollectionWorlds
---@param completion LedgerCompletion
---@return LedgerBlock[]
local function junkMuseum(context, worlds, completion)
	local L = ns.L
	local format = context.formatNumber
	local caught = (context.state --[[@as LedgerState]]).items
	local blocks = {
		{ kind = "title", text = L.CURIOS_JUNK_TITLE },
		{ kind = "text", text = L.CURIOS_EXHIBITS:format(format(completion.junk.done), format(completion.junk.total)) },
	}
	for _, itemID in ipairs(worlds.junk) do
		if caught[itemID] then
			blocks[#blocks + 1] = {
				kind = "plinth",
				icon = itemID,
				look = "sepia",
				text = context.text:Item(itemID),
				value = plaque(context, itemID),
			}
		else
			blocks[#blocks + 1] = {
				kind = "plinth",
				icon = itemID,
				look = "silhouette",
				text = L.CURIOS_EMPTY_PLINTH,
				value = context.text:Lore("line.uncaughtjunk.text"),
			}
		end
	end
	return blocks
end

-- Treasures, at the top of Curios' right page (LED-R144): its title, the items opened of its world's, and a line per
-- container or treasure item, ascending item ID: caught, its name and plaque; uncaught, only the shared lore line.
---@param context LedgerJournalContext
---@param worlds LedgerCollectionWorlds
---@param completion LedgerCompletion
---@param blocks LedgerBlock[]
local function treasures(context, worlds, completion, blocks)
	local L = ns.L
	local format = context.formatNumber
	local caught = (context.state --[[@as LedgerState]]).items
	local count = completion.treasure
	blocks[#blocks + 1] = { kind = "title", text = L.CURIOS_TREASURES_TITLE }
	blocks[#blocks + 1] = { kind = "text", text = L.CURIOS_OPENED:format(format(count.done), format(count.total)) }
	for _, itemID in ipairs(worlds.treasure) do
		if caught[itemID] then
			blocks[#blocks + 1] = { kind = "text", text = context.text:Item(itemID) }
			local words = plaque(context, itemID)
			if words then
				blocks[#blocks + 1] = { kind = "text", text = words, color = "faded" }
			end
		else
			local words = context.text:Lore("line.uncaughttreasure.text")
			if words then
				blocks[#blocks + 1] = { kind = "text", text = words, color = "faded" }
			end
		end
	end
end

-- "Loose pages: Uncharted" (LED-R144, LED-R64): one handwritten line per Uncharted item, by first Catch (item ID on
-- a tie), "Item {id}" until the client has its name (LED-R126), at its zones by areaID or "unknown waters"; then the
-- "Help chart the waters" link, which opens the Field report (REP-R43).
---@param context LedgerJournalContext
---@param blocks LedgerBlock[]
local function loosePages(context, blocks)
	local L = ns.L
	local format = context.formatNumber
	local uncharted = (context.state --[[@as LedgerState]]).uncharted
	local ids = {}
	for itemID in pairs(uncharted) do
		ids[#ids + 1] = itemID
	end
	table.sort(ids, function(a, b)
		local timeA, timeB = uncharted[a].time, uncharted[b].time
		if timeA ~= timeB then
			return timeA < timeB
		end
		return a < b
	end)
	blocks[#blocks + 1] = { kind = "kicker", text = L.CURIOS_LOOSE_PAGES }
	for _, itemID in ipairs(ids) do
		local entry = uncharted[itemID]
		local zones = {}
		for zone in pairs(entry.zones or {}) do
			zones[#zones + 1] = zone
		end
		table.sort(zones)
		for i, zone in ipairs(zones) do
			zones[i] = context.text:Zone(zone)
		end
		local where = #zones > 0 and table.concat(zones, L.LIST_SEPARATOR) or L.CURIOS_UNKNOWN_WATERS
		blocks[#blocks + 1] = {
			kind = "text",
			hand = true,
			text = L.CURIOS_LOOSE_PAGE:format(
				context.text:Item(itemID, true),
				format(entry.n),
				where,
				context.text:Date(entry.date)
			),
		}
	end
	if #ids == 0 then
		blocks[#blocks + 1] = { kind = "text", text = L.CURIOS_NONE_UNCHARTED, color = "faded" }
	end
	blocks[#blocks + 1] = { kind = "link", text = L.CURIOS_HELP_CHART, action = context.openFieldReport }
end

ns.RegisterJournalSpread(ns.JOURNAL_CURIOS, {
	-- Home ❧ Curios (LED-R125).
	crumbs = function()
		return { { label = ns.L.CURIOS_CRUMB, place = { id = ns.JOURNAL_CURIOS } } }
	end,
	draw = function(_, context)
		local world = context.world --[[@as LedgerWorld]]
		local state = context.state --[[@as LedgerState]]
		local getItem = context.getItem --[[@as fun(itemID: integer): PagleItem?]]
		local worlds = ns.CollectionWorlds(world, state, getItem)
		local completion = ns.LedgerCompletion(world, state, getItem)
		local right = {}
		treasures(context, worlds, completion, right)
		loosePages(context, right)
		return { left = junkMuseum(context, worlds, completion), right = right }
	end,
})
