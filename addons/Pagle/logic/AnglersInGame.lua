---@class PagleNS
local ns = select(2, ...)

-- Core's reads of the Companion's two data addons (core/anglers-in-game.md, ADR 0001): Pagle_Following sets
-- PagleFollowingData, the Followed Anglers with their full cards, and Pagle_Anglers, load-on-demand, sets
-- PagleAnglersData, every Published Angler in the player's regions with the tooltip card. Their formats, and what
-- makes one absent or expired, are pagle-backend's (in-game-views.md: IGV-R40–R47, Contracts › The addon folders);
-- this file reads them as those say (VIEW-R1, VIEW-R2), looks a unit up in them (VIEW-R10) and hands out the Followed
-- Anglers (VIEW-R11). Pure logic over what it's handed (CORE-R7): logic/Wiring.lua's ns.WireAnglerViews hands it the
-- client's seams, or FakePagle's. Nothing flows back (VIEW-R4): Core never writes either file, and never logs, stores
-- or prints what they hold, but for `/pagle dev views`' states and counts (VIEW-R12).

local floor = math.floor

--- The file formats Core reads (VIEW-R1, Tunables): IGV Contracts defines 1.
ns.VIEW_FILE_VERSIONS = { [1] = true }
--- How old, in seconds by GetServerTime(), a data file is when it expires (VIEW-R1, IGV's Tunables): 24 h.
ns.VIEW_EXPIRY_AGE = 24 * 3600

-- Pagle_Anglers' widths (IGV Contracts, Tunables): a key is a 13-character search key and a 6-digit card number; a card
-- is 16 characters.
local KEY_WIDTH, SEARCH_WIDTH, CARD_WIDTH = 19, 13, 16

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
		return L.VIEWS_NOT_TABLE:format(global)
	elseif data.ok ~= true then
		return L.VIEWS_NOT_OK
	elseif not ns.VIEW_FILE_VERSIONS[data.v] then
		return L.VIEWS_UNKNOWN_VERSION:format(shown(data.v))
	end
	for _, field in ipairs({ "generatedAt", "count" }) do
		if type(data[field]) ~= "number" then
			return L.VIEWS_NOT_NUMBER:format(field)
		end
	end
	-- `count` is the number of elements of the list, which a list that isn't a table can't hold.
	local list = data[listName]
	if type(list) ~= "table" then
		return L.VIEWS_NOT_TABLE:format(listName)
	elseif data.count ~= #list then
		return L.VIEWS_WRONG_COUNT:format(shown(data.count), listName, #list)
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

-- A copy of a Followed Angler's line, its full card's fields only (VIEW-R11), its guids a fresh array.
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
		ledger = line.ledger,
		legends = line.legends,
		legendsTotal = line.legendsTotal,
		waters = line.waters,
		catches = line.catches,
		asOf = line.asOf,
		guids = guids,
	}
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
	local reason = absentReason(data, "PagleFollowingData", "anglers")
	if reason then
		return absentFile(reason, data)
	end
	local anglers, guids = {}, {}
	for i, line in ipairs(data.anglers) do
		local angler = copyAngler(line)
		anglers[i] = angler
		for _, guid in ipairs(angler.guids) do
			if type(guid) == "string" and not guids[guid] then
				guids[guid] = i
			end
		end
	end
	return { generatedAt = data.generatedAt, count = data.count, anglers = anglers, guids = guids }
end

-- IGV-R44's block conditions over block `i`: the first that holds, as a reason, or nil when none does.
---@param block any
---@param i integer
---@return string?
local function blockReason(block, i)
	local L = ns.L
	if type(block) ~= "table" then
		return L.VIEWS_BLOCK_NOT_TABLE:format(i)
	end
	for _, field in ipairs({ "cardCount", "keyCount" }) do
		if type(block[field]) ~= "number" then
			return L.VIEWS_BLOCK_NOT_NUMBER:format(i, field)
		end
	end
	if type(block.titles) ~= "table" then
		return L.VIEWS_BLOCK_NOT_TITLES:format(i)
	end
	for _, packed in ipairs({ { "cards", CARD_WIDTH * block.cardCount }, { "keys", KEY_WIDTH * block.keyCount } }) do
		local value = block[packed[1]]
		if type(value) ~= "string" or #value ~= packed[2] then
			return L.VIEWS_BLOCK_LENGTH:format(i, packed[1], shown(packed[2]))
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
	local reason = absentReason(data, "PagleAnglersData", "blocks")
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
			return tonumber(keys:sub(at + SEARCH_WIDTH, at + KEY_WIDTH - 1))
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
		title = type(text) == "string" and text or "",
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
