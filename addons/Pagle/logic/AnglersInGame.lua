---@class PagleNS
local ns = select(2, ...)

-- Core's reads of the Companion's two data addons (core/anglers-in-game.md, ADR 0001): Pagle_Following sets
-- PagleFollowingData, the Followed Anglers with their full cards, and Pagle_Anglers, load-on-demand, sets
-- PagleAnglersData, every Published Angler in the player's regions with the tooltip card. Their formats, and what
-- makes one absent or expired, are pagle-backend's (in-game-views.md: IGV-R40–R47, Contracts › The addon folders);
-- this file reads them as those say (VIEW-R1, VIEW-R2), says when Pagle_Anglers loads (VIEW-R3), looks a unit up in
-- them (VIEW-R10), writes the Pagle block from a card (VIEW-R21) and hands out the Followed Anglers (VIEW-R11); from
-- 1.6 it reads Pagle_Following's news block, hands out the news, keeps what was seen and the floor, and words an item
-- (VIEW-R40–R46). Pure logic over what it's handed (CORE-R7): logic/Wiring.lua's ns.WireAnglerViews hands it the
-- client's seams, or FakePagle's. Nothing flows back (VIEW-R4): Core never writes either file, and never logs, stores
-- or prints what they hold, but for `/pagle dev views`' states and counts (VIEW-R12), the block on the tooltip
-- (VIEW-R20) and, from 1.6, the ids and times of news items marked seen, and the floor (VIEW-R44).

local floor = math.floor

--- The file formats Core reads (VIEW-R1, Tunables): IGV Contracts defines 1.
ns.VIEW_FILE_VERSIONS = { [1] = true }
--- How old, in seconds by GetServerTime(), a data file is when it expires (VIEW-R1, IGV's Tunables): 24 h.
ns.VIEW_EXPIRY_AGE = 24 * 3600

--- The news kinds Core reads (VIEW-R41): SIGN-R10's eight followed kinds in their rank, then the region headline. A
--- line of any other kind is skipped, so a kind a later server sends is ignored (IGV Contracts).
ns.NEWS_KINDS = { "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster", "region" }
--- How old, in seconds by GetServerTime(), a seen item's time is when it is dropped from PagleDB.global.news.seen
--- (VIEW-R44, Tunables): 31 days, the news age (SIGN-R15) and a day, so an entry is kept while its item can still be
--- due and the table holds at most what the block held over that time.
ns.NEWS_SEEN_AGE = 31 * 24 * 3600

-- Pagle_Anglers' widths (IGV Contracts, Tunables): a key is a 13-character search key and a 6-digit card number; a card
-- is 16 characters.
local KEY_WIDTH, SEARCH_WIDTH, CARD_WIDTH = 19, 13, 16

-- The data addons, by folder name, and their globals (IGV Contracts › The addon folders).
ns.FOLLOWING_ADDON, ns.ANGLERS_ADDON = "Pagle_Following", "Pagle_Anglers"
local FOLLOWING_ADDON, ANGLERS_ADDON = ns.FOLLOWING_ADDON, ns.ANGLERS_ADDON
local FOLLOWING_GLOBAL, ANGLERS_GLOBAL = "PagleFollowingData", "PagleAnglersData"

---@alias PagleViewFileState "live"|"absent"|"expired"

--- A data file as Core read it (VIEW-R1): absent with the first reason IGV-R44 found, or the parts Core uses, each read
--- once, so what's checked is what's used whatever writes to the global later. Expiry isn't in it: ns.ViewFileState
--- tells it at each use (VIEW-R2).
---@class PagleViewFile
---@field reason string? why the file is absent (IGV-R44); nil for a file that isn't
---@field generatedAt any its generatedAt as read, for `/pagle dev views` (Unix seconds in a file that isn't absent)
---@field count any its count as read, for `/pagle dev views`
---@field anglers PagleFollowedAngler[]? Pagle_Following's Anglers, copied, in the file's order
---@field guids table<string, integer>? Pagle_Following's lookup: each GUID's Angler, by index into `anglers`
---@field blocks PagleViewBlock[]? Pagle_Anglers' blocks, in the file's order
---@field news PagleNewsBlock? from 1.6, Pagle_Following's news block as read (VIEW-R40); nil when the file has none

--- A news item (VIEW-R41, VIEW-R42): a line of the news block, its fields as IGV Contracts' `news-line` names them, and
--- their meanings by kind IGV Contracts'. `new` is set only on the items Pagle.GetNews hands out.
---@class PagleNewsItem
---@field id string 16 lowercase hexadecimal digits, opaque (IGV-R63)
---@field kind string one of ns.NEWS_KINDS
---@field time integer Unix seconds (IGV-R63)
---@field angler integer the Angler's 1-based place in `anglers`; 0 for a headline's Angler not followed
---@field name string the Angler's name (IGV-R13), every `|` doubled (VIEW-R13)
---@field region string "us", "eu", "kr" or "tw" for `first` and `region`; "" otherwise
---@field item integer
---@field rank integer
---@field key string
---@field text string every `|` doubled (VIEW-R13)
---@field zone integer
---@field length integer millimetres
---@field new boolean? unseen and at or after the floor at the session's first read (VIEW-R42)

--- Pagle_Following's news block as read once (VIEW-R40, VIEW-R41): the lines used, in the file's order, and how many
--- were used and skipped, for `/pagle dev views` (VIEW-R12, VIEW-R98).
---@class PagleNewsBlock
---@field items PagleNewsItem[]
---@field used integer
---@field skipped integer

--- A Followed Angler with its full card (VIEW-R11, IGV-R11), its fields as Pagle_Following's grammar names them.
---@class PagleFollowedAngler
---@field name string
---@field more integer the number of its other visible characters
---@field hardcore boolean a Hardcore Angler
---@field title string "" when none (IGV-R14)
---@field level integer Angler Level
---@field prestige integer prestige rank
---@field ledger integer Ledger completion %
---@field legends integer Legends caught
---@field legendsTotal integer N (LED-R63)
---@field waters integer waters mastered
---@field catches integer lifetime Catches
---@field asOf integer the as-of UTC date, YYYYMMDD (IGV-R15)
---@field guids string[] the GUIDs of its visible characters

--- One region block of Pagle_Anglers (IGV Contracts), read once.
---@class PagleViewBlock
---@field cardCount integer
---@field keyCount integer
---@field titles any[] the block's titles, copied: strings in a file the Companion wrote
---@field cards string cardCount cards of 16 characters
---@field keys string keyCount keys of 19 characters, ascending

-- A value as `/pagle dev views` and the reasons print it: a number in plain digits, "none" for nil.
---@param value any
---@return string
local function shown(value)
	if value == nil then
		return ns.L.DEV_VIEWS_NONE
	elseif type(value) == "number" and value == floor(value) then
		return ("%.0f"):format(value)
	end
	return tostring(value)
end

-- IGV-R44's conditions common to both files, in its order, over `data` and its list `listName` ("anglers" or
-- "blocks"): the first that holds, as a reason, or nil when none does.
---@param data any
---@param global string the global's name, for the first condition
---@param listName string
---@return string?
local function absentReason(data, global, listName)
	local L = ns.L
	if type(data) ~= "table" then
		return ns.RenderText(L.VIEWS_NOT_TABLE, { global = global })
	elseif data.ok ~= true then
		return L.VIEWS_NOT_OK
	elseif not ns.VIEW_FILE_VERSIONS[data.v] then
		return ns.RenderText(L.VIEWS_UNKNOWN_VERSION, { views_unknown_version = shown(data.v) })
	end
	for _, field in ipairs({ "generatedAt", "count" }) do
		if type(data[field]) ~= "number" then
			return ns.RenderText(L.VIEWS_NOT_NUMBER, { field = field })
		end
	end
	-- `count` is the number of elements of the list, which a list that isn't a table can't hold.
	local list = data[listName]
	if type(list) ~= "table" then
		return ns.RenderText(L.VIEWS_NOT_TABLE, { global = listName })
	elseif data.count ~= #list then
		return ns.RenderText(
			L.VIEWS_WRONG_COUNT,
			{ views_wrong_count_1 = shown(data.count), listName = listName, list = #list }
		)
	end
	return nil
end

-- An absent file with `reason`, keeping what `/pagle dev views` prints of `data` (VIEW-R12).
---@param reason string
---@param data any
---@return PagleViewFile
local function absentFile(reason, data)
	if type(data) ~= "table" then
		return { reason = reason }
	end
	return { reason = reason, generatedAt = data.generatedAt, count = data.count }
end

-- A name or title from the files as the client draws it as written: every `|` doubled, so none starts an escape
-- sequence (VIEW-R13). Anything that isn't a string is left as it is.
---@param text any
---@return any
local function drawable(text)
	return type(text) == "string" and (text:gsub("|", "||")) or text
end

-- A copy of a Followed Angler's line, its full card's fields only (VIEW-R11), its guids a fresh array. The Ledger
-- percent is whole (Lua 5.1's `%d` truncated a pushed 99.6 to 99, and the text helper's `{ledger:0}` would round it to
-- 100), so a fractional one is floored here, where it comes in; a value that is not a number is left for the caller's
-- check of the card.
---@param line any
---@return PagleFollowedAngler
local function copyAngler(line)
	line = type(line) == "table" and line or {}
	local guids = {}
	if type(line.guids) == "table" then
		for i, guid in ipairs(line.guids) do
			guids[i] = guid
		end
	end
	return {
		name = line.name,
		more = line.more,
		hardcore = line.hardcore,
		title = line.title,
		level = line.level,
		prestige = line.prestige,
		ledger = type(line.ledger) == "number" and floor(line.ledger) or line.ledger,
		legends = line.legends,
		legendsTotal = line.legendsTotal,
		waters = line.waters,
		catches = line.catches,
		asOf = line.asOf,
		guids = guids,
	}
end

-- The news kinds as a set (VIEW-R41).
local NEWS_KIND = {}
for _, kind in ipairs(ns.NEWS_KINDS) do
	NEWS_KIND[kind] = true
end

-- A news-line's fields that are whole numbers from 0, and that are strings (IGV Contracts, VIEW-R41); `id` and
-- `kind` are checked on their own.
local NEWS_NUMBERS = { "time", "angler", "item", "rank", "zone", "length" }
local NEWS_STRINGS = { "name", "region", "key", "text" }

-- Whether `value` is a whole number from 0: not a fraction, NaN or infinity.
---@param value any
---@return boolean
local function whole(value)
	return type(value) == "number" and value >= 0 and value < math.huge and value == floor(value)
end

-- A news line as an item (VIEW-R41): a copy of news-line's fields, `name` and `text` drawn as written (VIEW-R13), or
-- nil for a line Core can't use: one missing a field or holding one of the wrong type, a kind Core doesn't know, or
-- an `angler` past the file's `anglerCount` Anglers.
---@param line any
---@param anglerCount integer
---@return PagleNewsItem?
local function newsItem(line, anglerCount)
	if type(line) ~= "table" then
		return nil
	end
	local id = line.id
	if type(id) ~= "string" or #id ~= 16 or id:find("[^0-9a-f]") or not NEWS_KIND[line.kind] then
		return nil
	end
	local item = { id = id, kind = line.kind }
	for _, field in ipairs(NEWS_NUMBERS) do
		if not whole(line[field]) then
			return nil
		end
		item[field] = line[field]
	end
	for _, field in ipairs(NEWS_STRINGS) do
		if type(line[field]) ~= "string" then
			return nil
		end
		item[field] = line[field]
	end
	if item.angler > anglerCount then
		return nil
	end
	item.name, item.text = drawable(item.name), drawable(item.text)
	return item
end

--- Reads Pagle_Following's news block (VIEW-R40, VIEW-R41) in a file of `anglerCount` Anglers: nil when `news` isn't a
--- table, the file of a Companion that predates the news (IGV-R65); otherwise every line Core can use, copied, in the
--- file's order, each other line skipped on its own and counted, a line repeating an earlier line's `id` among them.
---@param news any PagleFollowingData.news
---@param anglerCount integer
---@return PagleNewsBlock?
function ns.ReadNewsBlock(news, anglerCount)
	if type(news) ~= "table" then
		return nil
	end
	local items, ids, skipped = {}, {}, 0
	for _, line in ipairs(news) do
		local item = newsItem(line, anglerCount)
		if item and not ids[item.id] then
			ids[item.id] = true
			items[#items + 1] = item
		else
			skipped = skipped + 1
		end
	end
	return { items = items, used = #items, skipped = skipped }
end

--- Reads Pagle_Following's PagleFollowingData (VIEW-R1): absent with the first of IGV-R44's conditions that holds, or
--- its Anglers copied in the file's order with each GUID's Angler for the lookup (VIEW-R10). `missing` is the reason
--- for no global at all, when the client says why (Pagle_Following isn't installed, didn't load, …).
---@param data any PagleFollowingData
---@param missing string?
---@return PagleViewFile
function ns.ReadFollowingFile(data, missing)
	if data == nil and missing then
		return { reason = missing }
	end
	local reason = absentReason(data, FOLLOWING_GLOBAL, "anglers")
	if reason then
		return absentFile(reason, data)
	end
	local anglers, guids = {}, {}
	for i, line in ipairs(data.anglers) do
		local angler = copyAngler(line)
		angler.name, angler.title = drawable(angler.name), drawable(angler.title)
		anglers[i] = angler
		for _, guid in ipairs(angler.guids) do
			if type(guid) == "string" and not guids[guid] then
				guids[guid] = i
			end
		end
	end
	return {
		generatedAt = data.generatedAt,
		count = data.count,
		anglers = anglers,
		guids = guids,
		news = ns.ReadNewsBlock(data.news, #anglers),
	}
end

-- IGV-R44's block conditions over block `i`: the first that holds, as a reason, or nil when none does.
---@param block any
---@param i integer
---@return string?
local function blockReason(block, i)
	local L = ns.L
	if type(block) ~= "table" then
		return ns.RenderText(L.VIEWS_BLOCK_NOT_TABLE, { views_block_not_table = i })
	end
	for _, field in ipairs({ "cardCount", "keyCount" }) do
		if type(block[field]) ~= "number" then
			return ns.RenderText(L.VIEWS_BLOCK_NOT_NUMBER, { views_block_not_number_1 = i, field = field })
		end
	end
	if type(block.titles) ~= "table" then
		return ns.RenderText(L.VIEWS_BLOCK_NOT_TITLES, { views_block_not_titles = i })
	end
	for _, packed in ipairs({ { "cards", CARD_WIDTH * block.cardCount }, { "keys", KEY_WIDTH * block.keyCount } }) do
		local value = block[packed[1]]
		if type(value) ~= "string" or #value ~= packed[2] then
			return ns.RenderText(
				L.VIEWS_BLOCK_LENGTH,
				{ views_block_length_1 = i, packed = packed[1], views_block_length_3 = shown(packed[2]) }
			)
		end
	end
	return nil
end

--- Reads Pagle_Anglers' PagleAnglersData once it has loaded (VIEW-R1, VIEW-R3): absent with the first of IGV-R44's
--- conditions that holds, its blocks' last, or its blocks, each part read once. `missing` is the reason for no global
--- at all, when Core knows why (not loaded yet, the load failed, …).
---@param data any PagleAnglersData
---@param missing string?
---@return PagleViewFile
function ns.ReadAnglersFile(data, missing)
	if data == nil and missing then
		return { reason = missing }
	end
	local reason = absentReason(data, ANGLERS_GLOBAL, "blocks")
	if not reason then
		for i, block in ipairs(data.blocks) do
			reason = blockReason(block, i)
			if reason then
				break
			end
		end
	end
	if reason then
		return absentFile(reason, data)
	end
	local blocks = {}
	for i, block in ipairs(data.blocks) do
		local titles = {}
		for t, title in ipairs(block.titles) do
			titles[t] = title
		end
		blocks[i] = {
			cardCount = block.cardCount,
			keyCount = block.keyCount,
			titles = titles,
			cards = block.cards,
			keys = block.keys,
		}
	end
	return { generatedAt = data.generatedAt, count = data.count, blocks = blocks }
end

--- A read file's state at server time `now` (VIEW-R1, VIEW-R2): "absent" as read; "expired" once `now` minus its
--- generatedAt is the expiry age or more (IGV-R45); "live" otherwise. Told afresh at each use, so a file that passes
--- the expiry age mid-session is used no more from then on. The age comes second, for a file that isn't absent.
---@param file PagleViewFile
---@param now integer GetServerTime()
---@return PagleViewFileState state
---@return integer? age
function ns.ViewFileState(file, now)
	if file.reason then
		return "absent", nil
	end
	local age = now - file.generatedAt
	return age >= ns.VIEW_EXPIRY_AGE and "expired" or "live", age
end

--- A unit's card as the lookup finds it (VIEW-R10): a Followed Angler's full card from Pagle_Following
--- (PagleFollowedAngler's fields, `followed` true), or a tooltip card from Pagle_Anglers (IGV-R10: these fields only,
--- `followed` false).
---@class PagleAnglerCard
---@field followed boolean found in Pagle_Following
---@field title string "" when none (IGV-R14, IGV-R46)
---@field level integer Angler Level
---@field prestige integer prestige rank
---@field ledger integer Ledger completion %
---@field legends integer Legends caught
---@field legendsTotal integer N (LED-R63)
---@field hardcore boolean a Hardcore Angler
---@field name string? a Followed Angler's
---@field more integer?
---@field waters integer?
---@field catches integer?
---@field asOf integer?
---@field guids string[]?

-- `text` left-padded with "0" to `width` characters; longer text as it is.
---@param text string
---@param width integer
---@return string
local function padded(text, width)
	return #text < width and ("0"):rep(width - #text) .. text or text
end

--- The search key Pagle_Anglers is searched by (IGV Contracts), from a GUID `Player-<serverID>-<UID>` as text: the
--- serverID left-padded with "0" to 5 characters, then the UID upper-cased and left-padded to 8. Nil for anything
--- else, and for a key that isn't 13 characters, which is never found.
---@param guid any
---@return string?
function ns.AnglerSearchKey(guid)
	if type(guid) ~= "string" then
		return nil
	end
	local server, uid = guid:match("^Player%-([^%-]*)%-([^%-]*)$")
	if not server then
		return nil
	end
	local key = padded(server, 5) .. padded(uid:upper(), 8)
	return #key == SEARCH_WIDTH and key or nil
end

-- The card number of the key in `block` whose search key is `search`, by binary search over its ascending keys; nil
-- when there's none.
---@param block PagleViewBlock
---@param search string
---@return integer?
local function findKey(block, search)
	local keys, low, high = block.keys, 1, block.keyCount
	while low <= high do
		local middle = floor((low + high) / 2)
		local at = KEY_WIDTH * (middle - 1) + 1
		local found = keys:sub(at, at + SEARCH_WIDTH - 1)
		if found == search then
			-- A card number that isn't digits is card 0, which no block has: the first match still ends the search.
			return tonumber(keys:sub(at + SEARCH_WIDTH, at + KEY_WIDTH - 1)) or 0
		elseif found < search then
			low = middle + 1
		else
			high = middle - 1
		end
	end
	return nil
end

-- Card `n` of `block` as a tooltip card (IGV Contracts, IGV-R46): its title by index, 0 or one above the titles
-- being none. Nil for a card number the block hasn't, or a card that isn't digits.
---@param block PagleViewBlock
---@param n integer
---@return PagleAnglerCard?
local function readCard(block, n)
	if n < 1 or n > block.cardCount then
		return nil
	end
	local card = block.cards:sub(CARD_WIDTH * (n - 1) + 1, CARD_WIDTH * n)
	local title, level, prestige, ledger, legends, total, hardcore =
		card:match("^(%d%d%d)(%d%d)(%d%d%d)(%d%d%d)(%d%d)(%d%d)([01])$")
	if not title then
		return nil
	end
	local text = block.titles[tonumber(title)]
	return {
		followed = false,
		title = type(text) == "string" and drawable(text) or "",
		level = tonumber(level),
		prestige = tonumber(prestige),
		ledger = tonumber(ledger),
		legends = tonumber(legends),
		legendsTotal = tonumber(total),
		hardcore = hardcore == "1",
	}
end

--- Looks a unit up by its GUID (VIEW-R10, IGV-R46) at server time `now`: in Pagle_Following first, the GUID one of an
--- Angler's guids, compared as strings, for a Followed Angler's full card; then in Pagle_Anglers by the search key,
--- binary-searched in each block's keys, the first block with a match winning, for a tooltip card. Each file only
--- while it's live (VIEW-R2). Nil for no match, a GUID that isn't a string, or neither file live. The card is fresh,
--- the caller's to keep. A secret GUID is the caller's to keep out (CORE-R31).
---@param following PagleViewFile
---@param anglers PagleViewFile
---@param guid any
---@param now integer GetServerTime()
---@return PagleAnglerCard?
function ns.LookUpAngler(following, anglers, guid, now)
	if type(guid) ~= "string" then
		return nil
	end
	if ns.ViewFileState(following, now) == "live" then
		local index = following.guids[guid]
		if index then
			local card = copyAngler(following.anglers[index]) --[[@as PagleAnglerCard]]
			card.followed = true
			return card
		end
	end
	local search = ns.AnglerSearchKey(guid)
	if search and ns.ViewFileState(anglers, now) == "live" then
		for _, block in ipairs(anglers.blocks) do
			local n = findKey(block, search)
			if n then
				return readCard(block, n)
			end
		end
	end
	return nil
end

--- The Pagle block's colours (VIEW-R21), each a hex RRGGBB by its key: variant A's (IGV-R81), Pagle teal for the
--- header, green for "Following", the game's tooltip gold for a title, parchment for the stat names, white for their
--- values, red for a Hardcore Angler. No Core colour matches them: ns.ANNOUNCE_COLORS are inks for paper.
---@type table<PagleTooltipColor, string>
ns.ANGLER_TIP_COLORS = {
	teal = "5FD3C4",
	green = "1EFF00",
	gold = "FFD100",
	parchment = "E9D8AE",
	white = "FFFFFF",
	red = "FF4B3A",
}

---@alias PagleTooltipColor "teal"|"green"|"gold"|"parchment"|"white"|"red"

--- One line of the Pagle block (VIEW-R21): its left text and colour, and for a double line its right text and colour.
--- The gap is a line of one space, with no colour.
---@class PagleTooltipLine
---@field left string
---@field leftColor PagleTooltipColor?
---@field right string?
---@field rightColor PagleTooltipColor?

-- The card's fields the block writes as numbers.
local NUMBERS = { "level", "prestige", "ledger", "legends", "legendsTotal" }

-- The Prestige emblem's size in the block, as in every list and tooltip (LED-R152).
local EMBLEM_SIZE = 22

-- The Angler Level line's right text (VIEW-R21, LED-R34): the level, then " · Prestige {I…X}" at ranks 1 to 10, or
-- " · Master Prestige {rank − 10}" from rank 11, each with the rank's emblem before its words (LED-R152, the
-- Master's from rank 11); the level alone at rank 0, with no emblem.
---@param level integer
---@param rank integer
---@return string
local function levelText(level, rank)
	local L = ns.L
	if rank > #L.PRESTIGE_NUMERALS then
		local emblem = ns.PrestigeEmblemMarkup(rank, EMBLEM_SIZE)
		return ns.RenderText(
			L.ANGLER_TIP_MASTER_PRESTIGE,
			{ level = level, emblem = emblem, angler_tip_master_prestige_3 = rank - #L.PRESTIGE_NUMERALS }
		)
	elseif rank >= 1 then
		local emblem = ns.PrestigeEmblemMarkup(rank, EMBLEM_SIZE)
		return ns.RenderText(
			L.ANGLER_TIP_PRESTIGE,
			{ level = level, emblem = emblem, prestigeNumerals = L.PRESTIGE_NUMERALS[floor(rank)] }
		)
	end
	return ("%d"):format(level)
end

--- The Pagle block for a unit's card (VIEW-R21), in its order: a gap; the Pagle favicon and "Pagle Angler", with
--- "Following" at the right for a Followed Angler; the title, left out when there's none; Angler Level, Ledger and
--- Legends; and "Hardcore Angler" for a Hardcore Angler. It names no region (IGV-R6). Nil for a card with a number
--- that isn't one, which a file only IGV-R44 checks can hold: no block, as for no card (VIEW-R20). The favicon is
--- the minimap icon's (ns.PAGLE_ICON), at the line's height.
---@param card PagleAnglerCard
---@return PagleTooltipLine[]?
function ns.AnglerTooltipLines(card)
	for _, field in ipairs(NUMBERS) do
		if type(card[field]) ~= "number" then
			return nil
		end
	end
	local L = ns.L
	local header = { left = ("|T%s:0|t %s"):format(ns.PAGLE_ICON, L.ANGLER_TIP_HEADER), leftColor = "teal" }
	if card.followed then
		header.right, header.rightColor = L.ANGLER_TIP_FOLLOWING, "green"
	end
	local lines = { { left = " " }, header }
	if type(card.title) == "string" and card.title ~= "" then
		lines[#lines + 1] = { left = card.title, leftColor = "gold" }
	end
	local function stat(name, value)
		lines[#lines + 1] = { left = name, leftColor = "parchment", right = value, rightColor = "white" }
	end
	stat(L.ANGLER_TIP_LEVEL, levelText(card.level, card.prestige))
	stat(L.ANGLER_TIP_LEDGER, ns.RenderText(L.ANGLER_TIP_LEDGER_VALUE, { ledger = card.ledger }))
	stat(
		L.ANGLER_TIP_LEGENDS,
		ns.RenderText(L.ANGLER_TIP_LEGENDS_VALUE, { legends = card.legends, legendsTotal = card.legendsTotal })
	)
	if card.hardcore == true then
		lines[#lines + 1] = { left = L.ANGLER_TIP_HARDCORE, leftColor = "red" }
	end
	return lines
end

---@alias PagleFollowedState "ok"|"none"|"expired"|"absent"

--- What Pagle.GetFollowedAnglers() returns (VIEW-R11).
---@class PagleFollowedAnglers
---@field state PagleFollowedState
---@field anglers PagleFollowedAngler[] empty unless the state is "ok"

--- The Followed Anglers at server time `now` (VIEW-R11): "absent" or "expired" as Pagle_Following is (VIEW-R1, told
--- at the call, VIEW-R2), "none" when it's live with no Anglers, and "ok" with every Angler in the file's order. The
--- array and each Angler are fresh copies, the caller's to keep.
---@param following PagleViewFile
---@param now integer GetServerTime()
---@return PagleFollowedAnglers
function ns.FollowedAnglers(following, now)
	local state = ns.ViewFileState(following, now)
	if state ~= "live" then
		return { state = state, anglers = {} }
	elseif #following.anglers == 0 then
		return { state = "none", anglers = {} }
	end
	local anglers = {}
	for i, angler in ipairs(following.anglers) do
		anglers[i] = copyAngler(angler)
	end
	return { state = "ok", anglers = anglers }
end

--- What Core's reads are fed. Every function is called when needed, never stored.
---@class PagleAnglerViewsOptions
---@field following fun(): any                 -- PagleFollowingData, read once at Start (VIEW-R1)
---@field presence fun(): PaglePushedPresence  -- Pagle_Following's install and load state, read only with no global
---@field load fun(): boolean, string?         -- C_AddOns.LoadAddOn("Pagle_Anglers"): whether it loaded, and why not
---@field anglers fun(): any                   -- PagleAnglersData, read once, right after a load that succeeded
---@field serverTime fun(): integer            -- GetServerTime()
---@field isRestricted fun(): boolean          -- Pagle.IsRestricted() (CORE-R30)
---@field tooltips fun(): boolean              -- the tooltip setting is on (PagleDB.profile.anglerTooltips, VIEW-R30)
---@field isSecret fun(value: any): boolean    -- issecretvalue (CORE-R31)
---@field global fun(): table                  -- PagleDB.global, where the news seen and the floor are kept (VIEW-R44)

--- Core's reads of the Companion's data files this login.
---@class PagleAnglerViews
---@field package options PagleAnglerViewsOptions
---@field package following PagleViewFile Pagle_Following as read at Start
---@field package anglers PagleViewFile Pagle_Anglers as read once it has loaded
---@field package started boolean
---@field package tried boolean Core tried to load Pagle_Anglers this login (VIEW-R3)
---@field package loaded boolean and Pagle_Anglers loaded
---@field package fresh table<string, true>? the ids new this session, from its first read of ok news (VIEW-R42)
local AnglerViews = {}
AnglerViews.__index = AnglerViews

---@param options PagleAnglerViewsOptions
---@return PagleAnglerViews
function ns.NewAnglerViews(options)
	return setmetatable({
		options = options,
		following = { reason = ns.L.VIEWS_NOT_READ },
		anglers = { reason = ns.L.VIEWS_NOT_LOADED_YET },
		started = false,
		tried = false,
		loaded = false,
	}, AnglerViews)
end

-- Why there's no global from data addon `name`, as the client tells it (IGV-R44: a file that failed to load, or that
-- the AddOns list has disabled, is absent).
---@param name string
---@param global string
---@param presence PaglePushedPresence
---@return string
local function noFile(name, global, presence)
	local L = ns.L
	if not presence.installed then
		return ns.RenderText(L.VIEWS_NOT_INSTALLED, { name = name })
	elseif presence.loaded then
		return ns.RenderText(L.VIEWS_NO_DATA, { name = name, global = global })
	end
	return ns.RenderText(L.VIEWS_DID_NOT_LOAD, { name = name, reason = presence.reason or "?" })
end

--- Login step 2 (VIEW-R1): reads PagleFollowingData once; Pagle_Following loaded before Core's PLAYER_LOGIN, after
--- Pagle (IGV-R42). Only the first call counts.
function AnglerViews:Start()
	if self.started then
		return
	end
	self.started = true
	local options = self.options
	local data = options.following()
	self.following =
		ns.ReadFollowingFile(data, data == nil and noFile(FOLLOWING_ADDON, FOLLOWING_GLOBAL, options.presence()) or nil)
end

-- VIEW-R3: loads Pagle_Anglers once per login, at the first player hover outside restriction with the tooltip setting
-- on, and reads PagleAnglersData then. A load that fails leaves the file absent for the login, never tried again.
---@param views PagleAnglerViews
local function loadAnglers(views)
	local options = views.options
	if views.tried or not options.tooltips() or options.isRestricted() then
		return
	end
	views.tried = true
	local loaded, why = options.load()
	views.loaded = loaded == true
	if views.loaded then
		local data = options.anglers()
		views.anglers = ns.ReadAnglersFile(
			data,
			data == nil and noFile(ANGLERS_ADDON, ANGLERS_GLOBAL, { installed = true, loaded = true }) or nil
		)
	else
		local presence = { installed = why ~= "MISSING", loaded = false, reason = why }
		views.anglers = { reason = noFile(ANGLERS_ADDON, ANGLERS_GLOBAL, presence) }
	end
end

--- A player unit's tooltip is showing (VIEW-R3, VIEW-R10): what the tooltip block calls for each player unit it
--- shows, with the unit's GUID (UnitGUID). The first such call outside restriction with the tooltip setting on loads
--- Pagle_Anglers; while restricted the lookup uses Pagle_Following alone, and a later call loads it. Returns the unit's
--- card, fresh (ns.LookUpAngler), or nil for none, or for a secret or nil GUID, which is never looked up (CORE-R31).
---@param guid any
---@return PagleAnglerCard?
function AnglerViews:HoverPlayer(guid)
	loadAnglers(self)
	local options = self.options
	if options.isSecret(guid) or guid == nil then
		return nil
	end
	return ns.LookUpAngler(self.following, self.anglers, guid, options.serverTime())
end

--- Pagle.GetFollowedAnglers() (VIEW-R11): ns.FollowedAnglers over Pagle_Following at the server time now. Absent
--- before Start.
---@return PagleFollowedAnglers
function AnglerViews:FollowedAnglers()
	return ns.FollowedAnglers(self.following, self.options.serverTime())
end

---@alias PagleNewsState "ok"|"none"|"expired"|"absent"

--- What Pagle.GetNews() returns (VIEW-R42).
---@class PagleNews
---@field state PagleNewsState
---@field items PagleNewsItem[] empty unless the state is "ok"

--- The news state of a read Pagle_Following at server time `now` (VIEW-R42): "absent" or "expired" as the file is
--- (VIEW-R1, VIEW-R2), "none" for a live file with no news block (VIEW-R40), "ok" otherwise.
---@param following PagleViewFile
---@param now integer GetServerTime()
---@return PagleNewsState
function ns.NewsState(following, now)
	local state = ns.ViewFileState(following, now)
	if state ~= "live" then
		return state --[[@as PagleNewsState]]
	end
	return following.news and "ok" or "none"
end

-- PagleDB.global.news (VIEW-R44), made when first needed: `since`, the floor, and `seen`, `{ [id] = time }`. A value
-- of the wrong type is read as none.
---@param views PagleAnglerViews
---@return { since: integer?, seen: table<string, integer> }
local function newsKept(views)
	local global = views.options.global()
	local kept = global.news
	if type(kept) ~= "table" then
		kept = {}
		global.news = kept
	end
	if type(kept.seen) ~= "table" then
		kept.seen = {}
	end
	if type(kept.since) ~= "number" then
		kept.since = nil
	end
	return kept
end

-- The session's first read of ok news (VIEW-R42, VIEW-R44), once: with no floor yet it calls nothing new (the first
-- login with news, whose decision sets the floor, SIGN-R18); otherwise an item is new when its id wasn't seen and its
-- time is at or after the floor. Then drops from `seen` every entry older than the seen age, and any that isn't a
-- time. Reading never sets the floor: the sign's decision does (SIGN-R14), and the switch (ns.SetNewsFloor, SET-R37).
---@param views PagleAnglerViews
---@param items PagleNewsItem[]
---@param now integer
local function firstRead(views, items, now)
	if views.fresh then
		return
	end
	local kept, fresh = newsKept(views), {}
	if kept.since ~= nil then
		for _, item in ipairs(items) do
			if kept.seen[item.id] == nil and item.time >= kept.since then
				fresh[item.id] = true
			end
		end
	end
	views.fresh = fresh
	local oldest = now - ns.NEWS_SEEN_AGE
	for id, time in pairs(kept.seen) do
		if type(time) ~= "number" or time < oldest then
			kept.seen[id] = nil
		end
	end
end

--- Pagle.GetNews() (VIEW-R42) at the server time now: the news state, and while it's "ok" a fresh copy of every item
--- used, in the file's order, each with `new`. The session's first call that finds "ok" news decides `new` for the
--- session and prunes what was seen (VIEW-R44); it never sets the floor. Absent before Start.
---@return PagleNews
function AnglerViews:News()
	local now = self.options.serverTime()
	local state = ns.NewsState(self.following, now)
	if state ~= "ok" then
		return { state = state, items = {} }
	end
	local block = self.following.news --[[@as PagleNewsBlock]]
	firstRead(self, block.items, now)
	local items = {}
	for i, item in ipairs(block.items) do
		local copy = {}
		for field, value in pairs(item) do
			copy[field] = value
		end
		copy.new = self.fresh[item.id] == true
		items[i] = copy
	end
	return { state = "ok", items = items }
end

--- Pagle.MarkNewsSeen(ids) (VIEW-R43): marks each id in `ids` seen with its item's time, or with no `ids` every item
--- of the news, whatever its kind or switch (SIGN-R17). An id that isn't an item of the news now is passed over. Does
--- nothing while the news isn't "ok". It never changes `new` this session (VIEW-R42).
---@param ids string[]?
function AnglerViews:MarkNewsSeen(ids)
	local news = self:News()
	if news.state ~= "ok" then
		return
	end
	local seen = newsKept(self).seen
	if ids == nil then
		for _, item in ipairs(news.items) do
			seen[item.id] = item.time
		end
		return
	end
	local times = {}
	for _, item in ipairs(news.items) do
		times[item.id] = item.time
	end
	for _, id in ipairs(ids) do
		if times[id] then
			seen[id] = times[id]
		end
	end
end

--- Whether news item `id` is marked seen now (VIEW-R44), for the sign's decision (SIGN-R15).
---@param id string
---@return boolean
function AnglerViews:NewsSeen(id)
	local kept = self.options.global().news
	return type(kept) == "table" and type(kept.seen) == "table" and kept.seen[id] ~= nil
end

--- Sets the floor to the server time now (SIGN-R18, VIEW-R44), whatever the news: what turning "Show news at login"
--- on does (SET-R37), and the sign's Defaults that turn it back on. Items timed before it are never due.
function AnglerViews:SetNewsFloor()
	newsKept(self).since = self.options.serverTime()
end

-- A data file's state line for `/pagle dev views`: live, absent with its reason, or expired with its age.
---@param name string
---@param file PagleViewFile
---@param now integer
---@return string
local function stateLine(name, file, now)
	local L = ns.L
	local state, age = ns.ViewFileState(file, now)
	if state == "absent" then
		return ns.RenderText(L.DEV_VIEWS_ABSENT, { name = name, reason = file.reason })
	elseif state == "expired" then
		return ns.RenderText(
			L.DEV_VIEWS_EXPIRED,
			{ name = name, age = shown(age), viewExpiryAge = shown(ns.VIEW_EXPIRY_AGE) }
		)
	end
	return ns.RenderText(L.DEV_VIEWS_LIVE, { name = name })
end

-- The news line of `/pagle dev views` (VIEW-R12): the news state, the lines used and skipped, how many items are seen
-- and the floor. It reads, never sets: it neither sets the floor nor prunes.
---@param views PagleAnglerViews
---@param now integer
---@return string
local function newsLine(views, now)
	local block = ns.ViewFileState(views.following, now) ~= "absent" and views.following.news or nil
	local kept = views.options.global().news
	kept = type(kept) == "table" and kept or {}
	local seen = 0
	for _ in pairs(type(kept.seen) == "table" and kept.seen or {}) do
		seen = seen + 1
	end
	return ns.RenderText(ns.L.DEV_VIEWS_NEWS, {
		state = ns.NewsState(views.following, now),
		used = shown(block and block.used),
		skipped = shown(block and block.skipped),
		seen = shown(seen),
		floor = shown(type(kept.since) == "number" and kept.since or nil),
	})
end

--- `/pagle dev views` (VIEW-R12): each file's state now (live, absent with the first reason IGV-R44 found, or expired
--- with its age), its generatedAt and its Angler or block count as read, and whether Pagle_Anglers has loaded this
--- login, and from 1.6 the news line (VIEW-R12, VIEW-R42, VIEW-R44). No GUID, name or card (VIEW-R4).
---@return string[]
function AnglerViews:Report()
	local L, now = ns.L, self.options.serverTime()
	local following, anglers = self.following, self.anglers
	return {
		stateLine(FOLLOWING_ADDON, following, now),
		ns.RenderText(
			L.DEV_VIEWS_FOLLOWING,
			{ generatedAt = shown(following.generatedAt), dev_views_following_2 = shown(following.count) }
		),
		stateLine(ANGLERS_ADDON, anglers, now),
		ns.RenderText(
			L.DEV_VIEWS_ANGLERS,
			{ generatedAt = shown(anglers.generatedAt), dev_views_anglers_2 = shown(anglers.count) }
		),
		self.loaded and L.DEV_VIEWS_LOADED or L.DEV_VIEWS_NOT_LOADED,
		newsLine(self, now),
	}
end

--- What Pagle.NewsWords reads from the client and from Core, each when asked (VIEW-R45, SIGN-R19).
---@class PagleNewsLookups
---@field itemName fun(itemID: integer): string?          -- the client's name, nil until it has loaded it
---@field dropPrefix string|false|nil                     -- the prefix a fish's name drops: "Raw " on an enUS client
---@field varieties fun(species: integer): PagleVarietyEntry[]? -- Pagle.GetVarieties (VAR-R11)
---@field caught fun(species: integer): table<integer, true>? -- Pagle.GetVarietiesCaught (VAR-R11)
---@field areaName fun(areaID: integer): string?           -- C_Map.GetAreaInfo, nil when the client has none
---@field formatLength fun(mm: integer): string            -- Pagle.FormatLength in the player's unit (LOG-R69)
---@field ledgerOn fun(): boolean                          -- the Ledger is On, so its zone crests are there
---@field fishCrest fun(species: integer): boolean          -- Core has a fish crest for the Species (VAR-R12)

-- The emblems' art (SIGN-R13): the Ledger's book, the zone crests (the Ledger's) and the fish crests (Core's), and the
-- share of the slot each fills, as the dev command's samples draw them.
local LEDGER_BOOK = "Interface\\AddOns\\Pagle\\media\\minimap\\Ledger-Book"
local ZONE_CRESTS = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\"
local FISH_CRESTS = "Interface\\AddOns\\Pagle\\media\\crests\\fish\\"
local BOOK_FILL, CREST_FILL = 1.25, 0.92

-- An item's or a Species' name as the sign words it (SIGN-R19): the client's, less a leading "Raw " on an enUS client
-- (VAR-R12), or SIGN_ITEM_UNKNOWN ("a fish") while the client hasn't loaded it.
---@param lookups PagleNewsLookups
---@param itemID integer
---@return string
local function fishName(lookups, itemID)
	local name, prefix = lookups.itemName(itemID), lookups.dropPrefix
	if type(name) ~= "string" or name == "" then
		return ns.L.SIGN_ITEM_UNKNOWN
	elseif prefix and prefix ~= "" and #name > #prefix and name:sub(1, #prefix) == prefix then
		return name:sub(#prefix + 1)
	end
	return name
end

-- The rarity's place in ns.VARIETY_RARITIES of the variety at `position` in its Species' ten, or of rarity `key`.
---@param key string?
---@param position integer
---@return integer?
local function rarityIndex(key, position)
	key = key or (ns.VarietyRarity(position) or {}).key
	for i, rarity in ipairs(ns.VARIETY_RARITIES) do
		if rarity.key == key then
			return i
		end
	end
	return nil
end

-- A colour's detail and emblem (SIGN-R12, SIGN-R13, SIGN-R19): Pagle.GetVarieties' entry whose key is the line's,
-- named once the player has caught it ("All-gold Spotted Yellowtail") and drawn in its colours; otherwise, or for a
-- key the client doesn't know, its rarity and Species ("Epic Spotted Yellowtail") on its silhouette (VAR-R27). A key
-- the client doesn't know takes the line's `rank`, the variety's position (IGV Contracts).
---@param item PagleNewsItem
---@param lookups PagleNewsLookups
---@return string detail
---@return table emblem
local function colourWords(item, lookups)
	local L = ns.L
	local species = fishName(lookups, item.item)
	local entry
	for _, variety in ipairs(lookups.varieties(item.item) or {}) do
		if variety.key == item.key then
			entry = variety
			break
		end
	end
	local position = entry and entry.index or item.rank
	local caught = entry and (lookups.caught(item.item) or {})[position] == true and type(entry.name) == "string"
	if caught then
		return ns.RenderText(L.SIGN_DETAIL_COLOUR, { variety = entry.name, species = species }),
			{ variety = { species = item.item, position = position } }
	end
	local rarity = rarityIndex(entry and entry.rarity, position)
	return ns.RenderText(L.SIGN_DETAIL_COLOUR_HIDDEN, {
		rarity = rarity and ns.VarietyRarityName(rarity) or "",
		species = species,
	}),
		{ variety = { species = item.item, position = position, silhouette = true } }
end

--- An item's words and emblem as the sign draws them (VIEW-R45, SIGN-R12, SIGN-R13, SIGN-R19): `{ kind, kicker, head,
--- detail, emblem }`, a PagleNewsSignNews without its more line, for the sign and the Fish Journal's news list alike.
--- The Angler is the line's `name` (SIGN-R11), never a character's; a region is its code in capitals ("EU"). An item the
--- client hasn't loaded yet reads SIGN_ITEM_UNKNOWN at the call, so a caller that draws again once the client has it
--- gets its name.
---@param item PagleNewsItem
---@param lookups PagleNewsLookups
---@return PagleNewsSignNews
function ns.NewsWords(item, lookups)
	local L, kind = ns.L, item.kind
	local values = { name = item.name, region = drawable(item.region:upper()) }
	local detail, emblem
	if kind == "first" or kind == "region" then
		values.fish = fishName(lookups, item.item)
		detail, emblem = item.name, { sign = "laurel" }
	elseif kind == "legend" then
		local crests = ns.LEGEND_CRESTS or {}
		detail, emblem = fishName(lookups, item.item), { legend = crests[item.item] or "unwritten", item = item.item }
	elseif kind == "prestige" then
		local sprite = ns.PrestigeEmblemSprite(item.rank)
		emblem = sprite and { atlas = "PrestigeEmblems", sprite = sprite } or { sign = "laurel" }
		if item.rank > #L.PRESTIGE_NUMERALS then
			return {
				kind = kind,
				kicker = ns.RenderText(L.SIGN_KICKER[kind], values),
				head = ns.RenderText(
					L.SIGN_HEAD_MASTER_PRESTIGE,
					{ name = item.name, master = item.rank - #L.PRESTIGE_NUMERALS }
				),
				emblem = emblem,
			}
		end
		values.rank = L.PRESTIGE_NUMERALS[item.rank] or tostring(item.rank)
	elseif kind == "ledger" then
		emblem = { file = LEDGER_BOOK, fill = BOOK_FILL }
	elseif kind == "colour" then
		detail, emblem = colourWords(item, lookups)
	elseif kind == "hunt" then
		detail, emblem = item.text, { sign = "medal" }
	elseif kind == "zone" then
		values.zone = lookups.areaName(item.zone)
			or ns.RenderText(L.SIGN_ZONE_UNKNOWN, { zone = ("%d"):format(item.zone) })
		if item.key ~= "" and lookups.ledgerOn() then
			emblem = { file = ZONE_CRESTS .. item.key, fill = CREST_FILL }
		else
			emblem = { sign = "laurel" }
		end
	elseif kind == "monster" then
		detail = ns.RenderText(
			L.SIGN_DETAIL_MONSTER,
			{ species = fishName(lookups, item.item), length = lookups.formatLength(item.length) }
		)
		if lookups.fishCrest(item.item) then
			emblem = { file = FISH_CRESTS .. item.item, fill = CREST_FILL, tape = true }
		else
			emblem = { sign = "laurel", tape = true }
		end
	end
	return {
		kind = kind,
		kicker = ns.RenderText(L.SIGN_KICKER[kind], values),
		head = ns.RenderText(L.SIGN_HEAD[kind], values),
		detail = detail,
		emblem = emblem,
	}
end
