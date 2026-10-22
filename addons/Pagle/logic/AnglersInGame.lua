---@class PagleNS
local ns = select(2, ...)

-- Core's reads of the Companion's two data addons (core/anglers-in-game.md, ADR 0001): Pagle_Following sets
-- PagleFollowingData, the Followed Anglers with their full cards, and Pagle_Anglers, load-on-demand, sets
-- PagleAnglersData, every Published Angler in the player's regions with the tooltip card. Their formats, and what
-- makes one absent or expired, are pagle-backend's (in-game-views.md: IGV-R40–R47, Contracts › The addon folders);
-- this file reads them as those say (VIEW-R1, VIEW-R2), says when Pagle_Anglers loads (VIEW-R3), looks a unit up in
-- them (VIEW-R10), writes the Pagle block from a card (VIEW-R21) and hands out the Followed Anglers (VIEW-R11). Pure
-- logic over what it's handed (CORE-R7): logic/Wiring.lua's ns.WireAnglerViews hands it the client's seams, or
-- FakePagle's. Nothing flows back (VIEW-R4): Core never writes either file, and never logs, stores or prints what they
-- hold, but for `/pagle dev views`' states and counts (VIEW-R12) and the block on the tooltip (VIEW-R20).

local floor = math.floor

--- The file formats Core reads (VIEW-R1, Tunables): IGV Contracts defines 1.
ns.VIEW_FILE_VERSIONS = { [1] = true }
--- How old, in seconds by GetServerTime(), a data file is when it expires (VIEW-R1, IGV's Tunables): 24 h.
ns.VIEW_EXPIRY_AGE = 24 * 3600

-- Pagle_Anglers' widths (IGV Contracts, Tunables): a key is a 13-character search key and a 6-digit card number; a card
-- is 16 characters.
local KEY_WIDTH, SEARCH_WIDTH, CARD_WIDTH = 19, 13, 16

-- The data addons, by folder name, and their globals (IGV Contracts › The addon folders).
local FOLLOWING_ADDON, ANGLERS_ADDON = "Pagle_Following", "Pagle_Anglers"
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
	local reason = absentReason(data, FOLLOWING_GLOBAL, "anglers")
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

-- The Angler Level line's right text (VIEW-R21, LED-R34): the level, then " · Prestige {I…X}" at ranks 1 to 10, or
-- " · Master Prestige {rank − 10}" from rank 11.
---@param level integer
---@param rank integer
---@return string
local function levelText(level, rank)
	local L = ns.L
	if rank > #L.PRESTIGE_NUMERALS then
		return L.ANGLER_TIP_MASTER_PRESTIGE:format(level, rank - #L.PRESTIGE_NUMERALS)
	elseif rank >= 1 then
		return L.ANGLER_TIP_PRESTIGE:format(level, L.PRESTIGE_NUMERALS[floor(rank)])
	end
	return ("%d"):format(level)
end

--- The Pagle block for a unit's card (VIEW-R21), in its order: a gap; the fish icon and "Pagle Angler", with
--- "Following" at the right for a Followed Angler; the title, left out when there's none; Angler Level, Ledger and
--- Legends; and "Hardcore Angler" for a Hardcore Angler. It names no region (IGV-R6). Nil for a card with a number
--- that isn't one, which a file only IGV-R44 checks can hold: no block, as for no card (VIEW-R20). The fish is
--- Trade_Fishing (ns.DEFAULT_ICON), at the line's height.
---@param card PagleAnglerCard
---@return PagleTooltipLine[]?
function ns.AnglerTooltipLines(card)
	for _, field in ipairs(NUMBERS) do
		if type(card[field]) ~= "number" then
			return nil
		end
	end
	local L = ns.L
	local header = { left = ("|T%d:0|t %s"):format(ns.DEFAULT_ICON, L.ANGLER_TIP_HEADER), leftColor = "teal" }
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
	stat(L.ANGLER_TIP_LEDGER, L.ANGLER_TIP_LEDGER_VALUE:format(card.ledger))
	stat(L.ANGLER_TIP_LEGENDS, L.ANGLER_TIP_LEGENDS_VALUE:format(card.legends, card.legendsTotal))
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

--- Core's reads of the Companion's data files this login.
---@class PagleAnglerViews
---@field package options PagleAnglerViewsOptions
---@field package following PagleViewFile Pagle_Following as read at Start
---@field package anglers PagleViewFile Pagle_Anglers as read once it has loaded
---@field package started boolean
---@field package tried boolean Core tried to load Pagle_Anglers this login (VIEW-R3)
---@field package loaded boolean and Pagle_Anglers loaded
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
		return L.VIEWS_NOT_INSTALLED:format(name)
	elseif presence.loaded then
		return L.VIEWS_NO_DATA:format(name, global)
	end
	return L.VIEWS_DID_NOT_LOAD:format(name, presence.reason or "?")
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

-- A data file's state line for `/pagle dev views`: live, absent with its reason, or expired with its age.
---@param name string
---@param file PagleViewFile
---@param now integer
---@return string
local function stateLine(name, file, now)
	local L = ns.L
	local state, age = ns.ViewFileState(file, now)
	if state == "absent" then
		return L.DEV_VIEWS_ABSENT:format(name, file.reason)
	elseif state == "expired" then
		return L.DEV_VIEWS_EXPIRED:format(name, shown(age), shown(ns.VIEW_EXPIRY_AGE))
	end
	return L.DEV_VIEWS_LIVE:format(name)
end

--- `/pagle dev views` (VIEW-R12): each file's state now (live, absent with the first reason IGV-R44 found, or expired
--- with its age), its generatedAt and its Angler or block count as read, and whether Pagle_Anglers has loaded this
--- login. No GUID, name or card (VIEW-R4).
---@return string[]
function AnglerViews:Report()
	local L, now = ns.L, self.options.serverTime()
	local following, anglers = self.following, self.anglers
	return {
		stateLine(FOLLOWING_ADDON, following, now),
		L.DEV_VIEWS_FOLLOWING:format(shown(following.generatedAt), shown(following.count)),
		stateLine(ANGLERS_ADDON, anglers, now),
		L.DEV_VIEWS_ANGLERS:format(shown(anglers.generatedAt), shown(anglers.count)),
		self.loaded and L.DEV_VIEWS_LOADED or L.DEV_VIEWS_NOT_LOADED,
	}
end
