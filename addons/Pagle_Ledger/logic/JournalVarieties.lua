if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's fish varieties (VAR-R23, VAR-R24, VAR-R27; core/varieties.md › In the Ledger): the fish spread's
-- Varieties lines and the varieties spread, as page data, from the Ledger's own record of the varieties caught
-- (state.varieties, VAR-R20) over Core's static list of a Species' ten (Pagle.GetVarieties, VAR-R11). Discovery
-- (VAR-R27): an uncaught variety's name and words are never read here, so no page, crumb or note can name it; its
-- art goes out only as a silhouette. Pure logic over the spread context (CORE-R7); adapter/JournalVarieties.lua draws
-- the rows, the art and the fish crest.

--- A variety odds' "one Catch in N" (VAR-R24): 10,000 over its rarity's weight, rounded.
---@param weight integer
---@return integer
local function oneIn(weight)
	return math.floor(10000 / weight + 0.5)
end

-- The rarity named `key` in `rarities`, as a pill draws it.
---@param rarities PagleVarietyRarity[]
---@param key string
---@return PagleVarietyRarity?
local function rarityOf(rarities, key)
	for _, rarity in ipairs(rarities) do
		if rarity.key == key then
			return rarity
		end
	end
	return nil
end

-- How many entries a list Core handed out holds: counted with ipairs, as Core's records may be read-only proxies that
-- `#` can't see through (CORE-R18).
---@param list table
---@return integer
local function sizeOf(list)
	local n = 0
	for _ in ipairs(list) do
		n = n + 1
	end
	return n
end

-- A Species' ten as Core lists them (VAR-R11), and the Ledger's record of those caught; nil without varieties.
---@param id integer
---@param context LedgerSpreadContext
---@return PagleVarietyEntry[]? list
---@return { [integer]: LedgerVariety } caught
local function varietiesOf(id, context)
	local list = context.getVarieties(id)
	local caught = context.state.varieties and context.state.varieties[id] or {}
	if not list or sizeOf(list) == 0 then
		return nil, caught
	end
	return list, caught
end

-- The variety selected (VAR-R24): `requested` when it is one of the ten, else the first caught, else position 1.
---@param list PagleVarietyEntry[]
---@param caught { [integer]: LedgerVariety }
---@param requested integer?
---@return integer
local function selectedOf(list, caught, requested)
	if requested and list[requested] then
		return requested
	end
	for index in ipairs(list) do
		if caught[index] then
			return index
		end
	end
	return 1
end

-- How many of `list` are caught.
---@param list PagleVarietyEntry[]
---@param caught { [integer]: LedgerVariety }
---@return integer
local function caughtCount(list, caught)
	local n = 0
	for index in ipairs(list) do
		if caught[index] then
			n = n + 1
		end
	end
	return n
end

-- A variety's rarity as its pill shows it (VAR-R24): its name, colour and ink.
---@param rarity PagleVarietyRarity?
---@return LedgerVarietyRarity
local function pill(rarity)
	if not rarity then
		return { name = ns.L.NAME_UNKNOWN, color = { 1, 1, 1 }, ink = { 0, 0, 0 } }
	end
	return { name = rarity.name or rarity.key, color = rarity.color, ink = rarity.ink }
end

-- The left page (VAR-R24): the Species' name (the unknown fish's while it is uncaught, LED-R124), "Its colours", "{n}
-- of 10 caught" in the hand, then a row per variety in order. A caught row: its art, its name, its pill filled and
-- "{count} caught"; an uncaught one (VAR-R27): its art as a silhouette, "Undiscovered", its pill outlined, no count.
-- Each opens itself on the right; the selected one is banded.
---@param id integer
---@param context LedgerSpreadContext
---@param list PagleVarietyEntry[]?
---@param caught { [integer]: LedgerVariety }
---@param selected integer
---@return LedgerBlock[]
local function leftPage(id, context, list, caught, selected)
	local L = ns.L
	---@type LedgerBlock[]
	local blocks = {
		{ kind = "kicker", text = ns.JournalFishLabel(id, context) },
		{ kind = "title", text = L.VARIETIES_TITLE },
	}
	if not list then
		return blocks
	end
	blocks[#blocks + 1] =
		{ kind = "text", hand = true, text = L.VARIETIES_CAUGHT:format(caughtCount(list, caught), sizeOf(list)) }
	for index, entry in ipairs(list) do
		local record = caught[index]
		---@type LedgerBlock
		local row = {
			kind = "variety",
			art = entry.art,
			rarity = pill(rarityOf(context.rarities, entry.rarity)),
			inked = record ~= nil,
			selected = index == selected,
			place = ns.JournalPlace.varieties(id, index),
		}
		if record then
			row.text = entry.name or L.NAME_UNKNOWN
			row.value = L.VARIETY_COUNT:format(context.formatNumber(record.count))
		else
			-- never its name (VAR-R27)
			row.look = "silhouette"
			row.text = L.VARIETY_UNDISCOVERED
		end
		blocks[#blocks + 1] = row
	end
	return blocks
end

-- The right page (VAR-R24): the selected variety. Its rarity's kicker in its ink; caught, its name, its art large, its
-- words in italic (left out while lore lacks them, LED-R161) and "First landed {date} in {zone}, by {character}.
-- {count} caught." (the zone part left out for zone 0, as LED-R140); uncaught (VAR-R27), "Not yet discovered", its
-- silhouette large and "Not landed yet. About one Catch in {N}."; then at the foot the fish crest small with its
-- name, and "All ten." or "{10 − n} to go." in the hand.
---@param id integer
---@param context LedgerSpreadContext
---@param list PagleVarietyEntry[]?
---@param caught { [integer]: LedgerVariety }
---@param selected integer
---@return LedgerBlock[]
local function rightPage(id, context, list, caught, selected)
	local L = ns.L
	local entry = list and list[selected]
	if not list or not entry then
		return {}
	end
	local rarity = rarityOf(context.rarities, entry.rarity)
	local record = caught[selected]
	---@type LedgerBlock[]
	local blocks = {
		{ kind = "kicker", text = L.VARIETY_KICKER[entry.rarity] or L.NAME_UNKNOWN, ink = rarity and rarity.ink },
	}
	if record then
		blocks[#blocks + 1] = { kind = "title", text = entry.name or L.NAME_UNKNOWN }
		blocks[#blocks + 1] = { kind = "varietyArt", art = entry.art }
		if entry.description then
			blocks[#blocks + 1] = { kind = "text", style = "italic", text = entry.description }
		end
		local count = context.formatNumber(record.count)
		blocks[#blocks + 1] = {
			kind = "text",
			text = context.text:FirstCatch(record.first, L.ENTRY_FIRST, L.ENTRY_FIRST_NO_ZONE, count),
		}
	else
		-- never its name, words or colours (VAR-R27)
		blocks[#blocks + 1] = { kind = "title", text = L.VARIETY_NOT_DISCOVERED }
		blocks[#blocks + 1] = { kind = "varietyArt", art = entry.art, look = "silhouette" }
		if rarity then
			blocks[#blocks + 1] =
				{ kind = "text", text = L.VARIETY_ODDS:format(context.formatNumber(oneIn(rarity.weight))) }
		end
	end
	local crest = context.fishCrest(id)
	local left = sizeOf(list) - caughtCount(list, caught)
	blocks[#blocks + 1] = {
		kind = "fishCrest",
		icon = crest.icon,
		text = crest.name,
		value = left == 0 and L.VARIETY_ALL_TEN or L.VARIETY_TO_GO:format(left),
		foot = true,
	}
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_VARIETIES, {
	-- Home ❧ {fish} ❧ Its colours (LED-R125): « back opens the fish spread.
	crumbs = function(args, context)
		local id = args.species
		return {
			{ label = ns.JournalFishLabel(id, context), place = ns.JournalPlace.fish(id) },
			{ label = ns.L.VARIETIES_TITLE, place = ns.JournalPlace.varieties(id) },
		}
	end,
	draw = function(args, context)
		local id = args.species
		local list, caught = varietiesOf(id, context)
		local selected = list and selectedOf(list, caught, args.variety) or 1
		return {
			left = leftPage(id, context, list, caught, selected),
			right = rightPage(id, context, list, caught, selected),
		}
	end,
	-- Picking a variety keeps the left page's scroll; the right page is the variety's (LED-R129).
	subjects = { left = { "species" }, right = { "species", "variety" } },
})
