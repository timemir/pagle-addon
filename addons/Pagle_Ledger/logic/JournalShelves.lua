if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Collection (LED-R166–R170): its own spread, with a row per shelf, what is within reach and what was
-- added lately, and a spread per shelf, its cards on the left and the chosen look on the right. Pure logic, everything
-- read from the spread's context (CORE-R7) through ns.CollectionModel (logic/Collection.lua); the book draws it
-- (adapter/Journal.lua, adapter/JournalShelves.lua). The spreads are ns.JOURNAL_COLLECTION and ns.JOURNAL_SHELF, their
-- places ns.JournalPlace.collection and ns.JournalPlace.shelf (logic/Journal.lua).

-- "{have} of {need} {unit}" (LED-R168, LED-R170): the unit is the Ledger's own goods' (LED-R118), any other good's
-- count with none.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return string?
local function countLine(context, look)
	local L, progress = ns.L, look.progress
	if not (progress and progress.have and progress.need) then
		return nil
	end
	local format = context.formatNumber
	local counted = ns.CountedGood(look.id)
	local unit = counted and L.EARNED_UNIT[counted.earn]
	if unit then
		return L.COLLECTION_COUNT_UNIT:format(format(progress.have), format(progress.need), unit)
	end
	return L.COLLECTION_COUNT:format(format(progress.have), format(progress.need))
end

-- The earning line of an owned good, as "Earned {date}: {line}." says it (LED-R170): the Ledger's own goods' (LED-R111,
-- LED-R114, LED-R116–R118, LED-R164); nil for any other Module's, whose earning only that Module knows.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return string?
local function earnedLine(context, look)
	local L = ns.L
	local counted = ns.CountedGood(look.id)
	if counted then
		return L.EARNED_TEXT[counted.earn]
	end
	for _, good in ipairs(ns.LEDGER_CORE_SLOT_GOODS) do
		if good.id == look.id then
			return L.EARNED_TEXT[good.earn]
		end
	end
	local binding = ns.LedgerBinding(look.id)
	if binding then
		return ns.BindingEarnedText(binding)
	end
	for _, crest in ipairs(ns.ZONE_CRESTS) do
		if ns.ZoneCrestID(crest) == look.id then
			return L.COLLECTION_EARN_MASTER:format(context.text:Zone(crest.areaID))
		end
	end
	return nil
end

-- How a look came, in the hand's line under its button or seal (LED-R170): "Bought {date} for {price} Coins.", "From a
-- Curio crate, {date}.", "Earned {date}: {earning line}." and "Free, and always yours."; a title's has no date, as the
-- board's has none, and Automatic's none at all.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return string?
local function howCame(context, look)
	local L = ns.L
	if look.title then
		return look.id ~= ns.COLLECTION_AUTOMATIC and L.COLLECTION_HOW_EARNED_LINE:format(look.earnLine) or nil
	end
	local source = ns.CollectionSource(look)
	local time = ns.CollectionLookTime(look, context.collection)
	local date = time and context.text:DateAt(time)
	local info = look.info --[[@as PagleGoodInfo]]
	if source == "default" then
		return L.COLLECTION_HOW_DEFAULT
	elseif source == "crate" then
		return date and L.COLLECTION_HOW_CRATE:format(date) or nil
	elseif source == "bought" then
		local price = info.price or info.fallbackPrice
		if not date then
			return nil
		end
		return price and L.COLLECTION_HOW_BOUGHT:format(date, context.formatNumber(price))
			or L.COLLECTION_HOW_BOUGHT_FREE:format(date)
	end
	local line = earnedLine(context, look)
	if date and line then
		return L.COLLECTION_HOW_EARNED:format(date, line)
	elseif date then
		return L.COLLECTION_HOW_EARNED_DATE:format(date)
	end
	return line and L.COLLECTION_HOW_EARNED_LINE:format(line) or nil
end

-- What a look in use does (LED-R170), by its slot.
---@param look LedgerLook
---@return string?
local function effect(look)
	local L = ns.L
	if look.title then
		return L.COLLECTION_EFFECT_TITLE
	end
	local slot = look.slot --[[@as string]]
	if L.COLLECTION_EFFECTS[slot] then
		return L.COLLECTION_EFFECTS[slot]
	elseif slot:find("%.trackerframe$") then
		return L.COLLECTION_EFFECT_TRACKER:format(ns.CollectionModuleName(look.module --[[@as string]]))
	end
	return nil
end

-- A look's source in the right page's kicker (LED-R170): the default; the Curio Shop; a {Module} reward; Curio crate only;
-- a zone crest's zone; a title's group.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return string
local function source(context, look)
	local L = ns.L
	if look.title then
		return L.COLLECTION_TITLE_GROUPS[
			look.group --[[@as string]]
		]
	end
	local info = look.info --[[@as PagleGoodInfo]]
	if look.default then
		return L.COLLECTION_SOURCE_DEFAULT
	elseif info.kind == "crate" then
		return L.COLLECTION_SOURCE_CRATE
	end
	for _, crest in ipairs(ns.ZONE_CRESTS) do
		if ns.ZoneCrestID(crest) == look.id then
			return context.text:Zone(crest.areaID)
		end
	end
	if info.kind == "sale" then
		return L.COLLECTION_SOURCE_SHOP
	end
	return L.COLLECTION_SOURCE_REWARD:format(ns.CollectionModuleName(look.module --[[@as string]]))
end

-- What "Use it" does (LED-R170, LED-R173): a title sets the active title (nil for Automatic, LED-R77), any other look
-- equips it (SHOP-R32).
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return fun()
local function useAction(context, look)
	if look.title then
		return function()
			context.pickTitle(look.id ~= ns.COLLECTION_AUTOMATIC and look.id or nil)
		end
	end
	return function()
		context.goods.setEquipped(look.slot --[[@as string]], look.id)
	end
end

-- The words on the button of an owned look (LED-R170).
---@param look LedgerLook
---@return string
local function useWords(look)
	local L = ns.L
	if look.title then
		return L.COLLECTION_SIGN
	end
	return look.slot == ns.BINDING_SLOT and L.COLLECTION_WEAR or L.COLLECTION_USE
end

-- ---------------------------------------------------------------- the Collection's spread (LED-R168)

-- A shelf's row on the left page: the look in use drawn small, the shelf's name, "{n} new" in red hand, what it wears in
-- the hand under it, and at the right "{owned} of {total}" over a small ink bar; it opens the shelf.
---@param shelf LedgerShelf
---@param format fun(n: integer): string
---@return LedgerBlock
local function shelfRow(shelf, format)
	local L = ns.L
	return {
		kind = "shelfRow",
		lookArt = shelf.worn and ns.CollectionArt(shelf.worn) or nil,
		text = shelf.label,
		note = shelf.new > 0 and L.COLLECTION_NEW_COUNT:format(format(shelf.new)) or nil,
		sub = shelf.wearing,
		value = L.COLLECTION_OF:format(format(shelf.owned), format(#shelf.looks)),
		fill = #shelf.looks > 0 and shelf.owned / #shelf.looks or 0,
		place = ns.JournalPlace.shelf(shelf.key),
	}
end

-- The left page (LED-R168): kicker, title, the line, the wax seal "{owned} of {total}" and a row per shelf.
---@param context LedgerSpreadContext
---@param model LedgerCollection
---@return LedgerBlock[]
local function collectionLeft(context, model)
	local L = ns.L
	local format = context.formatNumber
	local blocks = {
		{ kind = "kicker", text = L.HOME_CONTENTS },
		{ kind = "title", text = L.COLLECTION_TITLE },
		{ kind = "seal", text = L.COLLECTION_SEAL:format(format(model.owned), format(model.total)), inked = true },
		{ kind = "text", text = L.COLLECTION_LINE },
	}
	for _, shelf in ipairs(model.shelves) do
		blocks[#blocks + 1] = shelfRow(shelf, format)
	end
	return blocks
end

-- The right page (LED-R168): "Within reach" and "Lately added", each only with something to show, and at the foot the
-- looks for sale and the way to the Curio Shop.
---@param context LedgerSpreadContext
---@param model LedgerCollection
---@return LedgerBlock[]
local function collectionRight(context, model)
	local L = ns.L
	local blocks = {}
	local reach = ns.CollectionReach(model)
	if #reach > 0 then
		blocks[#blocks + 1] = { kind = "kicker", text = L.COLLECTION_REACH }
		for _, found in ipairs(reach) do
			local look = found.look
			blocks[#blocks + 1] = {
				kind = "reachRow",
				lookArt = ns.CollectionArt(look),
				text = look.name,
				value = look.slotName,
				fill = found.share,
				note = countLine(context, look),
				place = ns.JournalPlace.shelf(look.shelf, look.id),
			}
		end
	end
	local lately = ns.CollectionLately(model, context.collection)
	if #lately > 0 then
		blocks[#blocks + 1] = { kind = "kicker", text = L.COLLECTION_LATELY, value = L.COLLECTION_NEWEST_FIRST }
		local words = { bought = L.COLLECTION_ADDED_BOUGHT, crate = L.COLLECTION_ADDED_CRATE }
		for _, found in ipairs(lately) do
			local look = found.look
			blocks[#blocks + 1] = {
				kind = "latelyRow",
				lookArt = ns.CollectionArt(look),
				text = look.name,
				sub = L.COLLECTION_ADDED:format(
					words[ns.CollectionSource(look)] or L.COLLECTION_ADDED_EARNED,
					context.text:DateAt(found.time)
				),
				value = look.slotName,
				note = look.new and L.COLLECTION_NEW_MARK or nil,
				place = ns.JournalPlace.shelf(look.shelf, look.id),
			}
		end
	end
	local goods = context.goods
	blocks[#blocks + 1] = {
		kind = "shopFoot",
		foot = true,
		text = ns.CountText(
			model.forSale,
			L.COLLECTION_FOR_SALE_ONE,
			L.COLLECTION_FOR_SALE_OTHER,
			context.formatNumber
		),
		value = L.COLLECTION_OPEN_SHOP,
		action = function()
			goods.openShop()
		end,
	}
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_COLLECTION, {
	-- Home ❧ The Collection (LED-R168).
	crumbs = function()
		return { { label = ns.L.COLLECTION_CRUMB, place = ns.JournalPlace.collection() } }
	end,
	draw = function(_, context)
		local model = ns.CollectionModel(context)
		return { left = collectionLeft(context, model), right = collectionRight(context, model) }
	end,
})

-- ---------------------------------------------------------------- a shelf's spread (LED-R169)

-- A card's tag and the ink bar under it (LED-R169): "In use" after a wax dot, "Yours", "The default"; to earn, the earned
-- text with its bar when it has a count; in the shop its price or "Curio crate"; a title its earning line ("signed as"
-- while it is the one signed with); put away, "Put away".
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return string kind
---@return string? tag
---@return number? fill
local function cardTag(context, look)
	local L = ns.L
	if look.title then
		if look.state == "inUse" then
			return "signed", L.COLLECTION_TAG_SIGNED
		end
		return "line", look.earnLine
	elseif look.state == "inUse" then
		return "inUse", L.COLLECTION_TAG_IN_USE
	elseif look.state == "putAway" then
		return "putAway", L.COLLECTION_TAG_PUT_AWAY
	elseif look.state == "owned" then
		return look.default and "default" or "yours",
			look.default and L.COLLECTION_TAG_DEFAULT or L.COLLECTION_TAG_YOURS
	elseif look.state == "earn" then
		local progress = look.progress
		local count = progress and progress.have and progress.need and progress.have / progress.need
		return "earn", progress and progress.tag, count and math.min(1, count) or nil
	elseif look.crateOnly then
		return "crate", L.COLLECTION_TAG_CRATE
	end
	local price = look.info and look.info.price
	return "price", price and context.formatNumber(price) or nil
end

---@class LedgerCard
---@field id string
---@field name string
---@field art LedgerLookArt
---@field owned boolean          -- in ink; not owned, or put away, in pencil (LED-R170)
---@field putAway boolean
---@field new boolean
---@field chosen boolean
---@field tagKind "inUse"|"signed"|"yours"|"default"|"earn"|"crate"|"price"|"putAway"|"line"
---@field tag string?
---@field fill number?
---@field place LedgerJournalPlace

-- One look as a card on its shelf's page (LED-R169), opening the shelf with it chosen.
---@param context LedgerSpreadContext
---@param shelf LedgerShelf
---@param look LedgerLook
---@param chosen string?
---@param tab string
---@return LedgerCard
local function card(context, shelf, look, chosen, tab)
	local kind, tag, fill = cardTag(context, look)
	return {
		id = look.id,
		name = look.name,
		art = ns.CollectionArt(look),
		owned = look.owned and look.state ~= "putAway",
		putAway = look.state == "putAway",
		new = look.new,
		chosen = look.id == chosen,
		tagKind = kind --[[@as "inUse"]],
		tag = tag,
		fill = fill,
		place = ns.JournalPlace.shelf(shelf.key, look.id, tab ~= "all" and tab or nil),
	}
end

-- The shelf's left page (LED-R169): kicker, the shelf's name with "{owned} of {total} yours" in the hand at its right,
-- the filter tabs with their counts, then the cards under their groups' headers, each with "{owned} of {n}".
---@param context LedgerSpreadContext
---@param shelf LedgerShelf
---@param chosen LedgerLook?
---@param tab string
---@return LedgerBlock[]
local function shelfLeft(context, shelf, chosen, tab)
	local L = ns.L
	local format = context.formatNumber
	local labels = {
		all = L.COLLECTION_TAB_ALL,
		yours = L.COLLECTION_TAB_YOURS,
		earn = L.COLLECTION_TAB_EARN,
		shop = L.COLLECTION_TAB_SHOP,
	}
	local tabs = {}
	for i, found in ipairs(ns.CollectionTabs(shelf.looks, tab)) do
		tabs[i] = {
			text = labels[found.key],
			count = format(found.count),
			on = found.on,
			place = ns.JournalPlace.shelf(shelf.key, chosen and chosen.id, found.key ~= "all" and found.key or nil),
		}
	end
	local blocks = {
		{ kind = "kicker", text = L.COLLECTION_SHELF_KICKER },
		{
			kind = "title",
			text = shelf.label,
			value = L.COLLECTION_YOURS_COUNT:format(format(shelf.owned), format(#shelf.looks)),
		},
		{ kind = "tabs", tabs = tabs },
	}
	local layout = ns.CollectionLayout(shelf)
	for _, group in ipairs(shelf.groups) do
		local cards = {}
		for _, look in ipairs(ns.CollectionFilter(group.looks, tab)) do
			cards[#cards + 1] = card(context, shelf, look, chosen and chosen.id, tab)
		end
		if #cards > 0 then
			if group.name then
				blocks[#blocks + 1] = {
					kind = "kicker",
					text = group.name,
					value = L.COLLECTION_OF:format(format(group.owned), format(#group.looks)),
				}
			end
			blocks[#blocks + 1] = { kind = "cards", cards = cards, layout = layout }
		end
	end
	return blocks
end

-- The Automatic title's words on the stage: the highest level title earned (LED-R77), whatever is stored.
---@param context LedgerSpreadContext
---@return string?
local function automaticName(context)
	local _, name =
		ns.ActiveTitle(setmetatable({ activeTitle = false }, { __index = context }) --[[@as LedgerTitleView]])
	return name
end

-- The stage (LED-R170): the chosen look drawn on a dark stage in its colours whatever its state, "A look before you have
-- it" at its foot while it isn't owned; a title is the words "Signed as", the title in the hand and the Angler's name and
-- level.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return LedgerBlock
local function stage(context, look)
	local L = ns.L
	local note = not look.owned and L.COLLECTION_BEFORE or nil
	if look.title then
		local name = look.id == ns.COLLECTION_AUTOMATIC and automaticName(context) or look.name
		local angler = context.angler
		return {
			kind = "stage",
			sub = L.COLLECTION_SIGNED_AS,
			text = name,
			lines = {
				L.COLLECTION_STAGE_LINE:format(
					context.text:Character(angler.current or 1),
					ns.ShownLevel(context.state, context.celebrated)
				),
			},
			note = note,
		}
	end
	return { kind = "stage", lookArt = { kind = "preview", good = look.id }, note = note }
end

-- The state's blocks (LED-R170): in use, owned, to earn, in the shop, crate only or put away.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@param blocks LedgerBlock[]
local function state(context, look, blocks)
	local L = ns.L
	local format = context.formatNumber
	local goods = context.goods
	local info = look.info
	if look.state == "inUse" then
		blocks[#blocks + 1] =
			{ kind = "useRow", seal = L.COLLECTION_IN_USE, text = effect(look), sub = howCame(context, look) }
	elseif look.state == "owned" then
		blocks[#blocks + 1] = {
			kind = "useRow",
			button = useWords(look),
			action = useAction(context, look),
			sub = howCame(context, look),
		}
	elseif look.state == "earn" then
		blocks[#blocks + 1] = { kind = "text", style = "kicker", text = L.COLLECTION_HOW_TO_EARN }
		local note = look.title and look.earnLine or (look.progress and look.progress.note)
		if note then
			blocks[#blocks + 1] = { kind = "text", style = "italic", text = note }
		end
		local progress = look.progress
		if progress and progress.have and progress.need then
			blocks[#blocks + 1] =
				{ kind = "count", fill = math.min(1, progress.have / progress.need), text = countLine(context, look) }
		end
		-- with a fallback (SHOP-R28): the date it goes on sale, then its price and the way to buy it
		if info and info.fallbackFrom and info.fallbackPrice then
			if info.price then
				blocks[#blocks + 1] = { kind = "price", value = format(info.price) }
				blocks[#blocks + 1] = {
					kind = "useRow",
					button = L.COLLECTION_BUY,
					action = function()
						goods.openShop(look.id)
					end,
				}
			else
				blocks[#blocks + 1] = {
					kind = "text",
					color = "faded",
					text = L.COLLECTION_FALLBACK:format(
						context.text:DateAt(info.fallbackFrom),
						format(info.fallbackPrice)
					),
				}
			end
		end
	elseif look.state == "shop" and look.crateOnly then
		blocks[#blocks + 1] = { kind = "text", hand = true, text = L.COLLECTION_CRATE_ONLY }
		blocks[#blocks + 1] = {
			kind = "useRow",
			button = L.COLLECTION_OPEN_CRATE,
			action = function()
				goods.openShop("core.crate")
			end,
		}
		blocks[#blocks + 1] = { kind = "text", color = "faded", text = L.COLLECTION_CRATE_NOTE }
	elseif look.state == "shop" then
		local price = info and info.price or 0
		blocks[#blocks + 1] = { kind = "price", value = format(price) }
		blocks[#blocks + 1] = {
			kind = "useRow",
			button = L.COLLECTION_BUY,
			action = function()
				goods.openShop(look.id)
			end,
		}
		local balance = goods.balance()
		blocks[#blocks + 1] = {
			kind = "text",
			color = "faded",
			text = balance >= price and L.COLLECTION_ENOUGH:format(format(balance))
				or L.COLLECTION_SHORT:format(format(balance), format(price - balance)),
		}
	else
		blocks[#blocks + 1] = {
			kind = "text",
			color = "faded",
			text = L.COLLECTION_PUT_AWAY:format(ns.CollectionModuleName(look.module --[[@as string]])),
		}
	end
end

-- The shelf's right page (LED-R170): the chosen look's stage, its name ("new!" beside it while new), its kicker, its
-- description in italic and its state.
---@param context LedgerSpreadContext
---@param look LedgerLook
---@return LedgerBlock[]
local function shelfRight(context, look)
	local L = ns.L
	local description = look.title
			and (look.id == ns.COLLECTION_AUTOMATIC and L.COLLECTION_AUTOMATIC_NOTE or L.COLLECTION_TITLE_DESCRIPTION)
		or (look.info and look.info.description)
	local blocks = {
		stage(context, look),
		{ kind = "title", text = look.name, value = look.new and L.COLLECTION_NEW_MARK or nil, color = "red" },
		{ kind = "text", style = "kicker", text = L.COLLECTION_KICKER:format(look.slotName, source(context, look)) },
	}
	if description then
		blocks[#blocks + 1] = { kind = "text", style = "italic", text = description }
	end
	state(context, look, blocks)
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_SHELF, {
	-- Home ❧ The Collection ❧ {shelf} (LED-R169).
	crumbs = function(args, context)
		local shelf = ns.CollectionModel(context).byKey[args.shelf]
		local crumbs = { { label = ns.L.COLLECTION_CRUMB, place = ns.JournalPlace.collection() } }
		if shelf then
			crumbs[2] = { label = shelf.label, place = ns.JournalPlace.shelf(shelf.key) }
		end
		return crumbs
	end,
	draw = function(args, context)
		local model = ns.CollectionModel(context)
		local shelf = model.byKey[args.shelf]
		-- a shelf that is gone (its Module turned off): the Collection's own pages
		if not shelf then
			return { left = collectionLeft(context, model), right = collectionRight(context, model) }
		end
		local tab = ns.CollectionTabOf(args.tab)
		local chosen = ns.CollectionChosen(shelf, args.look)
		return {
			left = shelfLeft(context, shelf, chosen, tab),
			right = chosen and shelfRight(context, chosen) or {},
		}
	end,
	-- The left page is the shelf's under its filter; the right page the look chosen (LED-R129): picking a card keeps the
	-- shelf's scroll, a tab starts it again.
	subjects = { left = { "shelf", "tab" }, right = { "shelf", "look" } },
})
