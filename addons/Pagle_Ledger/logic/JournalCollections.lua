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

-- Names joined as prose: "A", "A and B", "A, B and C".
---@param names string[]
---@return string
local function joinAnd(names)
	local L = ns.L
	if #names <= 1 then
		return names[1] or ""
	end
	return table.concat(names, L.LIST_COMMA, 1, #names - 1) .. L.LIST_AND .. names[#names]
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
		blocks[#blocks + 1] = { kind = "text", text = L.TROPHY_FOUND_IN:format(joinAnd(zones)) }
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
