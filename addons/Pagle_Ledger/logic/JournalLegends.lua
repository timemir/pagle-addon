if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Legends spread (LED-R147): the index of every Legend in the world, the chosen Legend's page, and
-- its plate, which fills both pages and is drawn by the Journal, never as an Announcement. Pure logic, everything read
-- from the spread's context (CORE-R7); the book draws it (adapter/Journal.lua, adapter/JournalLegends.lua). An
-- uncaught Legend is never named and never shows its own icon (LED-R124).

-- The spread is ns.JOURNAL_LEGENDS, its place ns.JournalPlace.legends (logic/Journal.lua).

-- The plain fish an uncaught Legend's page shows as a silhouette (LED-R147): the same for every Legend, never its
-- own icon (LED-R124). An in-client texture.
local PLAIN_FISH = "Interface\\Icons\\INV_Misc_Fish_02"

-- Lore (LED-R160): a Legend's blurb and title, and the shared uncaught line; nil without text (LED-R161).
---@param context LedgerSpreadContext
---@param itemID integer
---@param field "blurb"|"title"
---@return string?
local function legendLore(context, itemID, field)
	return context.text:Lore(("legend.%d.%s"):format(itemID, field))
end

-- "Title: {title}" for a Legend, nil while its title has no text (LED-R161).
---@param context LedgerSpreadContext
---@param itemID integer
---@return string?
local function titleLine(context, itemID)
	local title = legendLore(context, itemID, "title")
	return title and ns.L.TITLE_LINE:format(title)
end

-- A first Catch as "{date}, {zone}, {character}" (LED-R147), the zone left out for zone 0 (LED-R6).
---@param context LedgerSpreadContext
---@param entry LedgerFirst
---@return string
local function firstCatch(context, entry)
	return context.text:FirstCatch(entry, ns.L.LEGENDS_FIRST, ns.L.LEGENDS_FIRST_NO_ZONE)
end

-- The left page (LED-R147): its title, the Legends caught of the world's (removed ones out of both sides, LED-R12),
-- and the index in item ID order, each line naming a caught Legend, "an unwritten legend" an uncaught one, opening
-- it on the right page; the chosen one is marked.
---@param context LedgerSpreadContext
---@param legends integer[]
---@param chosen integer?
---@return LedgerBlock[]
local function index(context, legends, chosen)
	local L = ns.L
	local format = context.formatNumber
	local count = ns.LedgerCompletion(context.world, context.state).legends
	local caught = context.state.items
	local blocks = {
		{ kind = "kicker", text = L.LEGENDS_KICKER },
		{ kind = "title", text = L.LEGENDS_TITLE },
		{ kind = "text", text = L.LEGENDS_COUNT:format(format(count.done), format(count.total)) },
		{ kind = "kicker", text = L.LEGENDS_INDEX },
	}
	for _, itemID in ipairs(legends) do
		local got = caught[itemID] ~= nil
		blocks[#blocks + 1] = {
			kind = "row",
			-- an uncaught Legend's medallion is the unknown fish's, never its icon (LED-R124)
			icon = itemID,
			look = got and "sepia" or "silhouette",
			text = got and context.text:Item(itemID) or L.LEGENDS_UNWRITTEN,
			color = not got and "faded" or nil,
			value = got and L.LEGENDS_CAUGHT_MARK or nil,
			selected = itemID == chosen,
			place = ns.JournalPlace.legends(itemID),
		}
	end
	return blocks
end

-- The right page, the chosen Legend (LED-R147). Caught: its icon in sepia, its name, its first Catch, its blurb, its
-- title, the plate's button, and the removed line (LED-R12). Uncaught, never named (LED-R124): a plain fish's
-- silhouette and the shared lore line.
---@param context LedgerSpreadContext
---@param itemID integer
---@return LedgerBlock[]
local function legendPage(context, itemID)
	local L = ns.L
	local entry = context.state.items[itemID]
	if not entry then
		---@type LedgerBlock[]
		local blocks = {
			{ kind = "kicker", text = L.LEGEND_TITLE },
			{ kind = "icon", icon = PLAIN_FISH, look = "silhouette", large = true, style = "legend" },
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
		{ kind = "kicker", text = L.LEGEND_TITLE },
		{ kind = "icon", icon = itemID, look = "sepia", large = true, style = "legend" },
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
		style = "button",
		text = L.LEGENDS_OPEN_PLATE,
		place = ns.JournalPlace.legends(itemID, true),
	}
	return ns.AddJournalRemovedLine(blocks, context, itemID)
end

-- A caught Legend's plate (LED-R147), one page across the spread: its icon and name, its first Catch, its record's
-- size text (left out without a size, LED-R80) and its title by the Title seal (left out without text, LED-R161). A
-- click anywhere on it returns to the Legend's page.
---@param context LedgerSpreadContext
---@param itemID integer
---@return LedgerSpreadPages
local function plate(context, itemID)
	local entry = context.state.items[itemID]
	local back = ns.JournalPlace.legends(itemID)
	local lines = { firstCatch(context, entry) }
	local size = context.sizeText(entry.record)
	if size then
		lines[#lines + 1] = size
	end
	return {
		left = {
			{
				kind = "plate",
				icon = itemID,
				text = context.text:Item(itemID),
				lines = lines,
				seal = legendLore(context, itemID, "title"),
				value = ns.L.LEGENDS_PLATE_RETURN,
				place = back,
			},
		},
		right = {},
	}
end

ns.RegisterJournalSpread(ns.JOURNAL_LEGENDS, {
	-- Home ❧ Legends (LED-R125).
	crumbs = function()
		return { { label = ns.L.LEGENDS_TITLE, place = ns.JournalPlace.legends() } }
	end,
	-- The index on the left, the Legend `args.legend` on the right (the first when it names none of the world's), or
	-- its plate across both pages with `args.plate` once it is caught.
	draw = function(args, context)
		local legends = ns.CollectionWorlds(context.world, context.state).legends
		local chosen = legends[1]
		for _, itemID in ipairs(legends) do
			if itemID == args.legend then
				chosen = itemID
			end
		end
		if chosen and args.plate and context.state.items[chosen] then
			return plate(context, chosen)
		end
		return { left = index(context, legends, chosen), right = chosen and legendPage(context, chosen) or {} }
	end,
	-- The index is the spread's; the right page, the Legend chosen. Choosing another Legend keeps the index's scroll;
	-- the plate fills both pages, so opening or leaving it starts both at the top (LED-R129).
	subjects = { left = { "plate" }, right = { "legend", "plate" } },
})
