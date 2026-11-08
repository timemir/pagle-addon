---@class PagleNS
local ns = select(2, ...)

-- Party toasts and cheers' messages (announcements.md › Party toasts and cheers, › Contracts › Party messages;
-- ANN-R103–R105, ANN-R108; from 1.5.x, #640): their format, the strict reading of what arrives, the limits on what
-- is taken, a marked moment as it is shared, and the lines a party toast and a cheer's Nod read. Pure Lua over what
-- it is handed, reading no client API: it would sit in logic/, but every file there is hashed, and a 1.5.x patch
-- adds none (a new file changes the hashed list). adapter/Party.lua runs it on the client. Loaded by
-- adapter/Settings.xml, as the TOC's file list is hashed too.

--- The field a Module sets on a moment it lets its player share (announcements.md › Contracts, ANN-R104): the kind
--- Core shares it as. Declared here, beside logic/Moments.lua's PagleMoment, which a 1.5.x patch can't change.
---@class PagleMoment
---@field party? "legend"|"colour"|"monster"|"gold"|"zone"|"prestige"|"ledger"

--- What marks Core's own party Announcements' headlines (ANN-R106, ANN-R108), for the display: a party toast's
--- groupmate, moment and mug, or a cheer's Nod. Never stored: neither reaches the Session summary.
---@class PagleRaisedMoment
---@field partyToast? { id: string, sender: string, kind: string, dev: boolean?, raised: boolean? }
---@field partyCheer? true

--- The add-on message prefix (ANN-R103), registered at each load.
ns.PARTY_PREFIX = "Pagle"
--- The protocol version, every message's first field (ANN-R103).
ns.PARTY_VERSION = "1"
--- A message's most bytes (ANN-R105; Tunables).
ns.PARTY_MAX_BYTES = 64
--- The kinds a moment may be shared as (ANN-R104), in the order Settings lists their switches (SET-R35).
ns.PARTY_KINDS = { "legend", "colour", "monster", "gold", "zone", "prestige", "ledger" }

-- Each kind's arguments after its id, in order (Contracts › Party messages).
local ARGS = {
	legend = { "item" },
	colour = { "item", "rarity", "place" },
	monster = { "item", "length" },
	gold = { "item0" },
	zone = {},
	prestige = { "rank" },
	ledger = {},
}

-- What a field is called in a read message.
local KEY = { item = "item", item0 = "item", rarity = "rarity", place = "place", length = "length", rank = "rank" }

-- Each number field's range.
local RANGE = {
	item = { 1, 999999999 },
	item0 = { 0, 999999999 },
	place = { 0, 10 },
	length = { 1, 99999 },
	rank = { 1, 999 },
}

-- A colour's rarity as written and as read.
local RARITY_CODE = { rare = "r", epic = "e" }
local RARITY_OF = { r = "rare", e = "epic" }

-- Whether `id` is a moment id: 4 to 12 of 0-9 and a-z (ANN-R104).
---@param id any
---@return boolean
local function isId(id)
	return type(id) == "string" and #id >= 4 and #id <= 12 and id:find("^[0-9a-z]+$") ~= nil
end

-- A field written from `value`, or nil when it is out of the field's range.
---@param name string
---@param value any
---@return string?
local function write(name, value)
	if name == "rarity" then
		return RARITY_CODE[value]
	end
	local range = RANGE[name]
	if type(value) ~= "number" or value ~= math.floor(value) or value < range[1] or value > range[2] then
		return nil
	end
	return ("%d"):format(value)
end

-- A field read from `text`, or nil when it isn't one: whole numbers of 1 to 9 digits in range, a known rarity.
---@param name string
---@param text string
---@return (integer|string)?
local function read(name, text)
	if name == "rarity" then
		return RARITY_OF[text]
	end
	if not text:find("^%d%d?%d?%d?%d?%d?%d?%d?%d?$") then
		return nil
	end
	local value = tonumber(text) --[[@as integer]]
	local range = RANGE[name]
	if value < range[1] or value > range[2] then
		return nil
	end
	return value
end

--- A hello (ANN-R103): `1:H:1` asks for an answer, `1:H:0` is one.
---@param ask boolean
---@return string
function ns.PartyHelloText(ask)
	return ns.PARTY_VERSION .. ":H:" .. (ask and "1" or "0")
end

--- A cheer for moment `id` (ANN-R108).
---@param id string
---@return string
function ns.PartyCheerText(id)
	return ns.PARTY_VERSION .. ":C:" .. id
end

--- What a shared moment carries (ANN-R104): its kind and the arguments the kind has.
---@class PagleSharedMoment
---@field kind string
---@field item integer?
---@field rarity ("rare"|"epic")?
---@field place integer?
---@field length integer?
---@field rank integer?

--- A shared moment `share` as moment `id` (ANN-R104), or nil when its id, kind or an argument can't be written.
---@param id string
---@param share PagleSharedMoment
---@return string?
function ns.PartyMomentText(id, share)
	local args = ARGS[share.kind]
	if not isId(id) or not args then
		return nil
	end
	local fields = { ns.PARTY_VERSION, "M", id, share.kind }
	for _, name in ipairs(args) do
		local value = share[KEY[name]]
		if name == "item0" and value == nil then
			value = 0
		end
		local text = write(name, value)
		if not text then
			return nil
		end
		fields[#fields + 1] = text
	end
	return table.concat(fields, ":")
end

--- A message read (ANN-R105): a hello, a moment with its id and kind's arguments, or a cheer.
---@class PaglePartyMessage: PagleSharedMoment
---@field type "hello"|"moment"|"cheer"
---@field ask boolean?
---@field id string?

--- `text` read as a party message, or nil for anything that isn't exactly one (ANN-R105): at most PARTY_MAX_BYTES of
--- letters, digits and colons, this version, a known type with exactly its fields, a known kind, numbers whole and in
--- range. Nothing else gets through, so no escape sequence can reach the screen.
---@param text any
---@return PaglePartyMessage?
function ns.ParsePartyText(text)
	if type(text) ~= "string" or text == "" or #text > ns.PARTY_MAX_BYTES or text:find("[^0-9A-Za-z:]") then
		return nil
	end
	local fields = {}
	for field in (text .. ":"):gmatch("([^:]*):") do
		fields[#fields + 1] = field
	end
	if fields[1] ~= ns.PARTY_VERSION then
		return nil
	end
	local kind = fields[2]
	if kind == "H" then
		if #fields == 3 and (fields[3] == "0" or fields[3] == "1") then
			return { type = "hello", ask = fields[3] == "1" }
		end
		return nil
	elseif kind == "C" then
		if #fields == 3 and isId(fields[3]) then
			return { type = "cheer", id = fields[3] }
		end
		return nil
	elseif kind ~= "M" or #fields < 4 then
		return nil
	end
	local id, momentKind = fields[3], fields[4]
	local args = ARGS[momentKind]
	if not isId(id) or not args or #fields ~= 4 + #args then
		return nil
	end
	local message = { type = "moment", id = id, kind = momentKind }
	for i, name in ipairs(args) do
		local value = read(name, fields[4 + i])
		if value == nil then
			return nil
		end
		message[KEY[name]] = value
	end
	return message
end

--- A raised moment a Module marked with `party` (announcements.md › Contracts), as it is shared (ANN-R104): its kind
--- and what that kind reads from the moment, and never a place. `varieties` is Pagle.GetVarieties, where a colour
--- finds its variety's place by name (0 when it can't). Nil for an unmarked moment, an unknown kind, or a colour that
--- isn't Rare or Epic.
---@param moment table
---@param varieties (fun(species: integer): table[]?)?
---@return PagleSharedMoment?
function ns.PartyShareOf(moment, varieties)
	local kind = moment.party
	if not ARGS[kind] then
		return nil
	end
	local item = type(moment.icon) == "number" and moment.icon or nil
	if kind == "legend" then
		return { kind = kind, item = item }
	elseif kind == "colour" then
		local variety = moment.variety
		local rarity = type(variety) == "table" and variety.rarity
		if not RARITY_CODE[rarity] then
			return nil
		end
		local place = 0
		local list = item and varieties and varieties(item)
		for i = 1, 10 do
			local entry = list and list[i]
			if entry and entry.name == variety.name then
				place = i
				break
			end
		end
		return { kind = kind, item = item, rarity = rarity, place = place }
	elseif kind == "monster" then
		local ruler = moment.ruler
		local length = type(ruler) == "table" and type(ruler.new) == "number" and math.floor(ruler.new + 0.5) or nil
		return { kind = kind, item = item, length = length }
	elseif kind == "gold" then
		return { kind = kind, item = item or 0 }
	elseif kind == "prestige" then
		return { kind = kind, rank = moment.frameRank }
	end
	return { kind = kind }
end

--- A sender's name as Core matches it against the party (ANN-R105): its first word, before any `-realm` or space
--- (Forever's names have a surname), or nil for none.
---@param sender any
---@return string?
function ns.PartySenderName(sender)
	if type(sender) ~= "string" then
		return nil
	end
	return sender:match("^[^%-%s]+")
end

--- A limit on messages (ANN-R103, ANN-R105): `burst` at once, then one more each `every` seconds.
---@class PaglePartyLimit
---@field package burst number
---@field package every number
---@field package tokens number
---@field package at number?
local Limit = {}
Limit.__index = Limit

---@param burst number
---@param every number
---@return PaglePartyLimit
function ns.NewPartyLimit(burst, every)
	return setmetatable({ burst = burst, every = every, tokens = burst }, Limit)
end

--- Takes one message at `now` (seconds): true while the limit allows it, which spends it.
---@param now number
---@return boolean
function Limit:Take(now)
	if self.at then
		self.tokens = math.min(self.burst, self.tokens + (now - self.at) / self.every)
	end
	self.at = now
	if self.tokens >= 1 then
		self.tokens = self.tokens - 1
		return true
	end
	return false
end

local DIGITS = "0123456789abcdefghijklmnopqrstuvwxyz"

-- `n` (a whole number from 0) in base 36.
---@param n integer
---@return string
local function base36(n)
	local out = ""
	repeat
		local digit = n % 36
		out = DIGITS:sub(digit + 1, digit + 1) .. out
		n = (n - digit) / 36
	until n == 0
	return out
end

--- The ids of the moments this login shares (ANN-R104): the nonce, then a counter from 1, in base 36.
---@class PaglePartyIds
---@field package nonce string
---@field package count integer
local Ids = {}
Ids.__index = Ids

---@param nonce string
---@return PaglePartyIds
function ns.NewPartyIds(nonce)
	return setmetatable({ nonce = nonce, count = 0 }, Ids)
end

--- The next id.
---@return string
function Ids:Next()
	self.count = self.count + 1
	return self.nonce .. base36(self.count)
end

--- A nonce for this login's ids (ANN-R104): 4 base-36 digits, each `random(0, 35)` (math.random on the client).
---@param random fun(low: integer, high: integer): integer
---@return string
function ns.PartyNonce(random)
	local out = ""
	for _ = 1, 4 do
		local digit = random(0, 35)
		out = out .. DIGITS:sub(digit + 1, digit + 1)
	end
	return out
end

--- What a party toast's line looks things up with: the client's item names, Pagle.GetVarieties and the length in the
--- Angler's unit.
---@class PaglePartyLookups
---@field itemName fun(itemID: integer): string?
---@field varieties fun(species: integer): table[]?
---@field formatLength fun(mm: number): string

--- A party toast's line for a moment read (UI › Party toast): what the groupmate did, then " · " and what it was
--- about where Core can name it; an item the client hasn't cached is left off with its " · ".
---@param message PaglePartyMessage
---@param lookups PaglePartyLookups
---@return string
function ns.PartyMomentLine(message, lookups)
	local L = ns.L
	local kind = message.kind
	local item = message.item and message.item > 0 and lookups.itemName(message.item) or nil
	local what, detail
	if kind == "prestige" then
		return ns.RenderText(L.PARTY_PRESTIGE, { rank = message.rank })
	elseif kind == "colour" then
		what = L.PARTY_LINES[message.rarity]
		local list = message.place and message.place > 0 and lookups.varieties(message.item --[[@as integer]])
		local entry = list and list[message.place]
		detail = entry and entry.name or item
	elseif kind == "monster" then
		what = L.PARTY_LINES.monster
		local length = lookups.formatLength(message.length --[[@as integer]])
		detail = item and ns.RenderText(L.PARTY_RECORD, { item = item, length = length }) or length
	elseif kind == "legend" then
		what, detail = L.PARTY_LINES.legend, item
	else
		what = L.PARTY_LINES[kind]
	end
	if detail then
		return ns.RenderText(L.PARTY_DETAIL, { what = what, detail = detail })
	end
	return what
end

--- A cheer's Nod's title (ANN-R108): "{name} raised a mug", "{name} and {other} raised a mug", or from three on
--- "{count} raised a mug", for the groupmates who cheered, in the order they did.
---@param names string[]
---@return string
function ns.PartyCheerTitle(names)
	local L = ns.L
	if #names == 1 then
		return ns.RenderText(L.PARTY_CHEER_NAME, { name = names[1] })
	elseif #names == 2 then
		return ns.RenderText(L.PARTY_CHEER_NAMES, { name = names[1], other = names[2] })
	end
	return ns.RenderText(L.PARTY_CHEER_COUNT, { count = #names })
end
