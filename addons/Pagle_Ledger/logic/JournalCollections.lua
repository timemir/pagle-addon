if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's collection spreads (LED-R143, LED-R144): the Trophy Room, with its families and measuring
-- boards, and Curios, with the Junk Museum's plinths, Treasures and the loose pages of Uncharted catches. Pure logic,
-- everything read from the spread's context (CORE-R7); the book draws it (adapter/Journal.lua,
-- adapter/JournalCollections.lua). Each "x of N" is World's count, removed items out of both sides (LED-R12).

-- The Trophy Room is ns.JOURNAL_TROPHY_ROOM and Curios ns.JOURNAL_CURIOS, their places ns.JournalPlace.trophyRoom and
-- .curios (logic/Journal.lua).

--- A trophy family as the Trophy Room shows it (LED-R143): its weights in the Trophy Room's world (LED-R11), and the
--- "x / N" of those not removed (LED-R12).
---@class LedgerTrophyFamily
---@field id integer
---@field weights integer[] -- its trophy items in the world, ascending item ID
---@field count LedgerCount

--- The Trophy Room's families (LED-R60, LED-R143): the trophy items of its world grouped by family, ascending family
--- ID (LED-R123). The zone spread reads each family's "x / N" from it too (LED-R137).
---@param world LedgerWorld
---@param state LedgerState
---@return LedgerTrophyFamily[]
function ns.TrophyFamilies(world, state)
	local getItem = world.getItem
	local byID, families = {}, {}
	for _, itemID in ipairs(ns.CollectionWorlds(world, state).trophy) do
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

-- The Trophy Room's left page (LED-R143): its title, the weights landed of the room's, and the family index, each
-- line the family's lore name and shown stars (LED-R48), its "x / N", opening it on the right page; a family whose
-- name has no text has no line (LED-R161).
---@param context LedgerSpreadContext
---@param families LedgerTrophyFamily[]
---@return LedgerBlock[]
local function trophyIndex(context, families)
	local L = ns.L
	local format = context.formatNumber
	local count = ns.LedgerCompletion(context.world, context.state).trophy
	local blocks = {
		{ kind = "title", text = L.TROPHY_TITLE },
		{ kind = "text", text = L.TROPHY_WEIGHTS:format(format(count.done), format(count.total)) },
	}
	for _, family in ipairs(families) do
		local name = context.text:FamilyName(family.id)
		if name then
			local stars = ns.ShownFamilyStars(context.world, context.state, context.celebrated, family.id)
			blocks[#blocks + 1] = {
				kind = "leader",
				text = L.TROPHY_INDEX_LINE:format(name, ns.JournalStars(stars)),
				value = L.COUNT_OF:format(format(family.count.done), format(family.count.total)),
				place = ns.JournalPlace.trophyRoom(family.id),
			}
		end
	end
	return blocks
end

-- A family's measuring board (LED-R143, LED-R62): a tick per weight not removed, by its real weight in pounds,
-- placed from the lightest (0) to the heaviest (1), the middle for one alone, and inked where landed.
---@param context LedgerSpreadContext
---@param family LedgerTrophyFamily
---@return LedgerBoardTick[]
local function board(context, family)
	local getItem = context.getItem
	local landed = context.state.items
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

-- The heaviest weight of a family landed, as "Landed {x} of {N}" counts them: a removed weight is left out (LED-R12),
-- though its Catches keep their records. nil for none.
---@param context LedgerSpreadContext
---@param family LedgerTrophyFamily
---@return integer?
local function heaviestLanded(context, family)
	local getItem = context.getItem
	local landed = context.state.items
	local heaviest
	for _, itemID in ipairs(family.weights) do
		local item = getItem(itemID) --[[@as PagleItem]]
		local weight = item.weight or 0
		if landed[itemID] and not item.removed and (heaviest == nil or weight > heaviest) then
			heaviest = weight
		end
	end
	return heaviest
end

-- The Trophy Room's right page (LED-R143): the chosen family's name (left out while it has no text, LED-R161), its
-- three stamps (its shown stars, LED-R48), its
-- measuring board in real pounds (LED-R62), what is landed of it, and the charted zones whose list has it.
---@param context LedgerSpreadContext
---@param family LedgerTrophyFamily
---@return LedgerBlock[]
local function familyPage(context, family)
	local L = ns.L
	local format = context.formatNumber
	local world = context.world
	local stars = ns.ShownFamilyStars(world, context.state, context.celebrated, family.id)
	local heaviest = heaviestLanded(context, family)
	local landed = heaviest
			and L.TROPHY_LANDED:format(format(family.count.done), format(family.count.total), format(heaviest))
		or L.TROPHY_NONE_LANDED
	---@type LedgerBlock[]
	local blocks = {}
	local name = context.text:FamilyName(family.id)
	if name then
		blocks[1] = { kind = "title", text = name }
	end
	blocks[#blocks + 1] = { kind = "stamps", stamps = ns.JournalStamps(stars, L.TROPHY_STAMPS) }
	blocks[#blocks + 1] = { kind = "board", ticks = board(context, family) }
	blocks[#blocks + 1] = { kind = "text", text = L.TROPHY_POUNDS, color = "faded" }
	blocks[#blocks + 1] = { kind = "text", text = landed, hand = true }
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
		return { { label = ns.L.TROPHY_TITLE, place = ns.JournalPlace.trophyRoom() } }
	end,
	-- The family index on the left, the family `args.family` on the right: the first when it names none in the room.
	draw = function(args, context)
		local families = ns.TrophyFamilies(context.world, context.state)
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
---@param context LedgerSpreadContext
---@param itemID integer
---@return string?
local function plaque(context, itemID)
	return context.text:Lore(("sub.%d.plaque"):format(itemID))
end

-- The Junk Museum, Curios' left page (LED-R144): its title, the exhibits caught of its world's (removed out of both
-- sides, LED-R12), and a plinth per junk item of the world, ascending item ID (LED-R123): caught, its icon, name and
-- plaque; uncaught, never named (LED-R124): a silhouette, "An empty plinth" and the shared lore line.
---@param context LedgerSpreadContext
---@param worlds LedgerCollectionWorlds
---@param completion LedgerCompletion
---@return LedgerBlock[]
local function junkMuseum(context, worlds, completion)
	local L = ns.L
	local format = context.formatNumber
	local caught = context.state.items
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
---@param context LedgerSpreadContext
---@param worlds LedgerCollectionWorlds
---@param completion LedgerCompletion
---@param blocks LedgerBlock[]
local function treasures(context, worlds, completion, blocks)
	local L = ns.L
	local format = context.formatNumber
	local caught = context.state.items
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
---@param context LedgerSpreadContext
---@param blocks LedgerBlock[]
local function loosePages(context, blocks)
	local L = ns.L
	local format = context.formatNumber
	local uncharted = context.state.uncharted
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
		for i, zone in ipairs(ns.SortedKeys(entry.zones or {})) do
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
	blocks[#blocks + 1] = ns.JournalHelpChartLink(context)
end

ns.RegisterJournalSpread(ns.JOURNAL_CURIOS, {
	-- Home ❧ Curios (LED-R125).
	crumbs = function()
		return { { label = ns.L.CURIOS_CRUMB, place = ns.JournalPlace.curios() } }
	end,
	draw = function(_, context)
		local world, state = context.world, context.state
		local worlds = ns.CollectionWorlds(world, state)
		local completion = ns.LedgerCompletion(world, state)
		local right = {}
		treasures(context, worlds, completion, right)
		loosePages(context, right)
		return { left = junkMuseum(context, worlds, completion), right = right }
	end,
})
