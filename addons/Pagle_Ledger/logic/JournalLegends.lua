if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Legends spread (LED-R147): the index of every Legend in the world, the chosen Legend's page, and
-- its plate, which fills both pages and is drawn by the Journal, never as an Announcement. Pure logic, everything read
-- from the spread's context (CORE-R7); the book draws it (adapter/Journal.lua, adapter/JournalLegends.lua). An
-- uncaught Legend is never named and never shows its own icon (LED-R124).

--- The Legends spread's ID (LED-R125); its args may name a `legend` (item ID) to choose, and `plate` to show its
--- plate (LED-R147).
ns.JOURNAL_LEGENDS = "legends"

--- The Legends spread's place with Legend `itemID` chosen (LED-R147): what search and the index open.
---@param itemID integer
---@return LedgerJournalPlace
function ns.JournalLegendPlace(itemID)
	return { id = ns.JOURNAL_LEGENDS, args = { legend = itemID } }
end

-- The plain fish an uncaught Legend's page shows as a silhouette (LED-R147): the same for every Legend, never its
-- own icon (LED-R124). An in-client texture.
local PLAIN_FISH = "Interface\\Icons\\INV_Misc_Fish_02"

-- Lore (LED-R160): a Legend's blurb and title, and the shared uncaught line; nil without text (LED-R161).
---@param context LedgerJournalContext
---@param itemID integer
---@param field "blurb"|"title"
---@return string?
local function legendLore(context, itemID, field)
	return context.text:Lore(("legend.%d.%s"):format(itemID, field))
end

-- "Title: {title}" for a Legend, nil while its title has no text (LED-R161).
---@param context LedgerJournalContext
---@param itemID integer
---@return string?
local function titleLine(context, itemID)
	local title = legendLore(context, itemID, "title")
	return title and ns.L.LEGENDS_TITLE_LINE:format(title)
end

-- A first Catch as "{date}, {zone}, {character}" (LED-R147), the zone left out for zone 0 (LED-R6).
---@param context LedgerJournalContext
---@param entry LedgerFirst
---@return string
local function firstCatch(context, entry)
	local L, text = ns.L, context.text
	local date, who = text:Date(entry.date), text:Character(entry.char)
	if entry.zone ~= 0 then
		return L.LEGENDS_FIRST:format(date, text:Zone(entry.zone), who)
	end
	return L.LEGENDS_FIRST_NO_ZONE:format(date, who)
end

-- The left page (LED-R147): its title, the Legends caught of the world's (removed ones out of both sides, LED-R12),
-- and the index in item ID order, each line naming a caught Legend, "an unwritten legend" an uncaught one, opening
-- it on the right page; the chosen one is marked.
---@param context LedgerJournalContext
---@param legends integer[]
---@param chosen integer?
---@return LedgerBlock[]
local function index(context, legends, chosen)
	local L = ns.L
	local format = context.formatNumber
	local count = ns.LedgerCompletion(
		context.world --[[@as LedgerWorld]],
		context.state --[[@as LedgerState]],
		context.getItem --[[@as fun(itemID: integer): PagleItem?]]
	).legends
	local caught = (context.state --[[@as LedgerState]]).items
	local blocks = {
		{ kind = "title", text = L.LEGENDS_TITLE },
		{ kind = "text", text = L.LEGENDS_COUNT:format(format(count.done), format(count.total)) },
	}
	for _, itemID in ipairs(legends) do
		local got = caught[itemID] ~= nil
		blocks[#blocks + 1] = {
			kind = "row",
			text = got and context.text:Item(itemID) or L.LEGENDS_UNWRITTEN,
			color = not got and "faded" or nil,
			value = got and L.LEGENDS_CAUGHT_MARK or nil,
			selected = itemID == chosen,
			place = ns.JournalLegendPlace(itemID),
		}
	end
	return blocks
end

-- The right page, the chosen Legend (LED-R147). Caught: its icon in sepia, its name, its first Catch, its blurb, its
-- title, the plate's button, and the removed line (LED-R12). Uncaught, never named (LED-R124): a plain fish's
-- silhouette and the shared lore line.
---@param context LedgerJournalContext
---@param itemID integer
---@return LedgerBlock[]
local function legendPage(context, itemID)
	local L = ns.L
	local entry = (context.state --[[@as LedgerState]]).items[itemID]
	if not entry then
		---@type LedgerBlock[]
		local blocks = {
			{ kind = "kicker", text = L.LEGENDS_KICKER },
			{ kind = "icon", icon = PLAIN_FISH, look = "silhouette", large = true },
			{ kind = "title", text = L.LEGENDS_UNWRITTEN_TITLE },
		}
		local line = context.text:Lore("line.uncaughtlegend.text")
		if line then
			blocks[#blocks + 1] = { kind = "text", text = line, color = "faded" }
		end
		return blocks
	end
	---@type LedgerBlock[]
	local blocks = {
		{ kind = "kicker", text = L.LEGENDS_KICKER },
		{ kind = "icon", icon = itemID, look = "sepia", large = true },
		{ kind = "title", text = context.text:Item(itemID) },
		{ kind = "text", hand = true, text = firstCatch(context, entry) },
	}
	local blurb = legendLore(context, itemID, "blurb")
	if blurb then
		blocks[#blocks + 1] = { kind = "text", text = blurb }
	end
	local title = titleLine(context, itemID)
	if title then
		blocks[#blocks + 1] = { kind = "text", text = title }
	end
	blocks[#blocks + 1] = {
		kind = "link",
		text = L.LEGENDS_OPEN_PLATE,
		place = { id = ns.JOURNAL_LEGENDS, args = { legend = itemID, plate = true } },
	}
	local item = context.getItem and context.getItem(itemID)
	if item and item.removed then
		blocks[#blocks + 1] = { kind = "text", text = L.ENTRY_REMOVED }
	end
	return blocks
end

-- A caught Legend's plate (LED-R147), filling both pages: on the left its icon and name, on the right its first
-- Catch, its record's size text (left out without a size, LED-R80) and its title (left out without text, LED-R161).
-- A click anywhere on it returns to the Legend's page.
---@param context LedgerJournalContext
---@param itemID integer
---@return LedgerSpreadPages
local function plate(context, itemID)
	local entry = (context.state --[[@as LedgerState]]).items[itemID]
	local back = ns.JournalLegendPlace(itemID)
	local lines = { firstCatch(context, entry) }
	local size = context.sizeText and context.sizeText(entry.record)
	if size then
		lines[#lines + 1] = size
	end
	lines[#lines + 1] = titleLine(context, itemID)
	return {
		left = { { kind = "plate", icon = itemID, text = context.text:Item(itemID), place = back } },
		right = { { kind = "plate", lines = lines, value = ns.L.LEGENDS_PLATE_RETURN, place = back } },
	}
end

ns.RegisterJournalSpread(ns.JOURNAL_LEGENDS, {
	-- Home ❧ Legends (LED-R125).
	crumbs = function()
		return { { label = ns.L.LEGENDS_TITLE, place = { id = ns.JOURNAL_LEGENDS } } }
	end,
	-- The index on the left, the Legend `args.legend` on the right (the first when it names none of the world's), or
	-- its plate across both pages with `args.plate` once it is caught.
	draw = function(args, context)
		local legends = ns.CollectionWorlds(
			context.world --[[@as LedgerWorld]],
			context.state --[[@as LedgerState]],
			context.getItem --[[@as fun(itemID: integer): PagleItem?]]
		).legends
		local chosen = legends[1]
		for _, itemID in ipairs(legends) do
			if itemID == args.legend then
				chosen = itemID
			end
		end
		if
			chosen
			and args.plate
			and (context.state --[[@as LedgerState]]).items[chosen]
		then
			return plate(context, chosen)
		end
		return { left = index(context, legends, chosen), right = chosen and legendPage(context, chosen) or {} }
	end,
})
