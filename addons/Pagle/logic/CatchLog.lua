---@class PagleNS
local ns = select(2, ...)

-- The Catch log (LOG-R10–R16, LOG-R18) and its codec: pure logic over the PagleLog table, everything passed in
-- (CORE-R7). Each entry is one tagged string (ADR 0003); catch-log.md › Entry formats is the canonical layout.

--- A record Core hands out for one Catch log entry (LOG-R42). Records are shared and immutable (CORE-R18).
---@class PagleRecord
---@field seq integer            -- index in PagleLog.entries (LOG-R14)
---@field id string              -- entry ID: <character GUID>-<time>-<tie> (LOG-R13)
---@field kind "cast"|"skill"|"prestige"|"build"|"purchase"|"module"
---@field char integer           -- index into Angler.characters
---@field time integer           -- server time

--- A Cast (`C1`). Records carry `session` from M2 (LOG-R98) and `size` from M4 (LOG-R65).
---@class PagleCast : PagleRecord
---@field outcome "caught"|"gotAway"
---@field conditions ConditionsSnapshot
---@field items { n: integer, itemID: integer, quantity: integer, catchId: string }[]

--- A Skill Reading (`S1`, LOG-R31). Carries `session?` from M2 (LOG-R98).
---@class PagleSkillReading : PagleRecord
---@field rank integer
---@field max integer
---@field mod integer

--- A build entry (`B1`, LOG-R36).
---@class PagleBuild : PagleRecord
---@field build integer          -- the GetBuildInfo() build number
---@field version string         -- e.g. "1.60.1"

--- The PagleLog layout version (LOG-R18). Before 1.0 it changes with any entry format change.
ns.LOG_FORMAT = 1

-- The fields of an entry string, split at every `|`. "a||b" is { "a", "", "b" }.
---@param entry string
---@return string[]
local function splitFields(entry)
	local fields = {}
	local start = 1
	while true do
		local bar = string.find(entry, "|", start, true)
		if not bar then
			fields[#fields + 1] = string.sub(entry, start)
			return fields
		end
		fields[#fields + 1] = string.sub(entry, start, bar - 1)
		start = bar + 1
	end
end

-- A decimal integer field, or nil if the field isn't one.
---@param field string
---@return integer?
local function integer(field)
	if string.find(field, "^%-?%d+$") then
		return tonumber(field)
	end
	return nil
end

-- A field that may be empty: false if it holds something that isn't an integer, else the integer or nil.
---@param field string
---@return integer|false|nil
local function optionalInteger(field)
	if field == "" then
		return nil
	end
	return integer(field) or false
end

-- A comma-separated list of IDs, or nil if the field isn't one. An empty field is an empty list.
---@param field string
---@return integer[]?
local function idList(field)
	local ids = {}
	if field == "" then
		return ids
	end
	for id in string.gmatch(field .. ",", "([^,]*),") do
		if not string.find(id, "^%d+$") then
			return nil
		end
		ids[#ids + 1] = tonumber(id)
	end
	return ids
end

-- An integer as its decimal field; nil as an empty one. Raises an error for anything else. %.0f keeps every
-- integer below 2^53 exact, where %d would go through a C long.
---@param value integer?
---@return string
local function integerField(value)
	if value == nil then
		return ""
	end
	if type(value) ~= "number" or value ~= math.floor(value) then
		error("not an integer: " .. tostring(value))
	end
	return ("%.0f"):format(value)
end

-- A list of IDs as its field: ascending, without duplicates, comma-separated (Entry formats).
---@param ids integer[]?
---@return string
local function idListField(ids)
	local sorted, seen = {}, {}
	for _, id in ipairs(ids or {}) do
		if not seen[id] then
			seen[id] = true
			sorted[#sorted + 1] = id
		end
	end
	table.sort(sorted)
	for i, id in ipairs(sorted) do
		sorted[i] = integerField(id)
	end
	return table.concat(sorted, ",")
end

local OUTCOMES = { c = "caught", g = "gotAway" }
local OUTCOME_FIELDS = { caught = "c", gotAway = "g" }

-- One codec per tag: the record kind it holds, how many fields follow the header, how to encode a record's fields
-- (`encode`) and how to decode them into a record (`decode`, false if they don't fit the kind).
---@class PagleEntryCodec
---@field kind string
---@field count integer
---@field encode fun(record: table): string[]
---@field decode fun(record: table, f: string[]): boolean

---@type table<string, PagleEntryCodec>
local kinds = {
	C1 = {
		kind = "cast",
		count = 12,
		encode = function(record)
			local c = record.conditions
			local items = {}
			for n, item in ipairs(record.items) do
				items[n] = integerField(item.itemID) .. "x" .. integerField(item.quantity)
			end
			return {
				OUTCOME_FIELDS[record.outcome],
				integerField(c.minute),
				integerField(c.uiMap),
				integerField(c.instance),
				integerField(c.zone or 0), -- nil is secret, stored as 0 (LOG-R93)
				integerField(c.subzone or 0),
				integerField(c.skillRank),
				integerField(c.skillMod),
				integerField(c.lure),
				idListField(c.events),
				idListField(c.auras),
				table.concat(items, ","),
			}
		end,
		decode = function(record, f)
			local outcome = OUTCOMES[f[1]]
			local minute, uiMap, instance = optionalInteger(f[2]), optionalInteger(f[3]), optionalInteger(f[4])
			local zone, subzone = integer(f[5]), integer(f[6])
			local rank, mod, lure = optionalInteger(f[7]), optionalInteger(f[8]), optionalInteger(f[9])
			local events, auras = idList(f[10]), idList(f[11])
			if not outcome or minute == false or uiMap == false or instance == false or not zone or not subzone then
				return false
			end
			if rank == false or mod == false or lure == false or not events or not auras then
				return false
			end
			local items = {}
			if f[12] ~= "" then
				for item in string.gmatch(f[12] .. ",", "([^,]*),") do
					local itemID, quantity = string.match(item, "^(%d+)x(%d+)$")
					if not itemID then
						return false
					end
					local n = #items + 1
					items[n] = {
						n = n,
						itemID = tonumber(itemID),
						quantity = tonumber(quantity),
						catchId = record.id .. ":" .. n,
					}
				end
			end
			record.outcome = outcome
			record.conditions = {
				time = record.time,
				minute = minute,
				date = minute and ns.RealmDate(record.time, minute) or nil,
				uiMap = uiMap,
				instance = instance,
				zone = zone,
				subzone = subzone,
				skillRank = rank,
				skillMod = mod,
				lure = lure,
				events = events,
				auras = auras,
			}
			record.items = items
			return true
		end,
	},

	S1 = {
		kind = "skill",
		count = 3,
		encode = function(record)
			return { integerField(record.rank), integerField(record.max), integerField(record.mod) }
		end,
		decode = function(record, f)
			record.rank, record.max, record.mod = integer(f[1]), integer(f[2]), integer(f[3])
			return record.rank ~= nil and record.max ~= nil and record.mod ~= nil
		end,
	},

	B1 = {
		kind = "build",
		count = 2,
		encode = function(record)
			return { integerField(record.build), record.version }
		end,
		decode = function(record, f)
			record.build, record.version = integer(f[1]), f[2]
			return record.build ~= nil and f[2] ~= ""
		end,
	},
}

-- The tag each record kind is written with: the newest one for that kind.
---@type table<string, string>
local TAGS = { cast = "C1", skill = "S1", build = "B1" }

-- Decodes one entry string into a typed record, or nil if the codec can't read it (LOG-R16).
---@param entry any
---@param seq integer
---@param characters table[]
---@return PagleRecord?
local function decode(entry, seq, characters)
	if type(entry) ~= "string" then
		return nil
	end
	local f = splitFields(entry)
	local codec = kinds[f[1]]
	local char, time, tie = integer(f[2] or ""), integer(f[3] or ""), integer(f[4] or "")
	if not codec or #f ~= 4 + codec.count or not char or not time or not tie then
		return nil
	end
	local character = characters[char]
	if type(character) ~= "table" or type(character.guid) ~= "string" then
		return nil
	end
	local record = {
		seq = seq,
		id = character.guid .. "-" .. integerField(time) .. "-" .. integerField(tie),
		kind = codec.kind,
		char = char,
		time = time,
	}
	if not codec.decode(record, { unpack(f, 5) }) then
		return nil
	end
	return record
end

-- The tie for a new entry (LOG-R12): 0, or one more than the highest tie of an entry with the same character and
-- time. Entries are appended in time order, so only the tail from that second on is read; an entry whose header
-- doesn't parse is passed over.
---@param entries string[]
---@param char integer
---@param time integer
---@return integer
local function nextTie(entries, char, time)
	local tie = 0
	for seq = #entries, 1, -1 do
		local entry = entries[seq]
		local entryChar, entryTime, entryTie
		if type(entry) == "string" then
			entryChar, entryTime, entryTie = string.match(entry, "^[^|]*|(%d+)|(%d+)|(%d+)|")
		end
		entryTime = tonumber(entryTime)
		if entryTime and entryTime < time then
			break
		end
		if tonumber(entryChar) == char and entryTime == time then
			tie = math.max(tie, tonumber(entryTie) + 1)
		end
	end
	return tie
end

-- 32 bits of a string, as 8 hex digits: djb2, kept exact below 2^53.
---@param text string
---@return string
local function hash32(text)
	local h = 5381
	for i = 1, #text do
		h = (h * 33 + string.byte(text, i)) % 4294967296
	end
	return ("%04x%04x"):format(math.floor(h / 65536), h % 65536)
end

-- Creates the log's logId if it has none yet and has a first character (LOG-R15): 16 lowercase hex digits, half
-- from that character's GUID and the server time, half from math.random, so two logs a character starts in the
-- same second still differ (LOG-R97).
---@param data table PagleLog
---@param time integer server time
local function ensureLogId(data, time)
	local first = data.characters[1]
	if data.logId == nil and type(first) == "table" and type(first.guid) == "string" then
		data.logId = hash32(first.guid .. "-" .. integerField(time))
			.. ("%04x%04x"):format(math.random(0, 65535), math.random(0, 65535))
	end
end

--- The Catch log over one PagleLog table, for one login.
---@class PagleCatchLog
---@field data table the PagleLog table, to store back as the SavedVariable
---@field global table PagleDB.global
---@field undecodable table<integer, true> the seqs counted in decodeErrors this login
local CatchLog = {}
CatchLog.__index = CatchLog

-- Counts an entry the codec can't read in PagleDB.global.decodeErrors, once per entry for this login (LOG-R16).
---@param catchLog PagleCatchLog
---@param seq integer
local function countUndecodable(catchLog, seq)
	if not catchLog.undecodable[seq] then
		catchLog.undecodable[seq] = true
		catchLog.global.decodeErrors = (catchLog.global.decodeErrors or 0) + 1
	end
end

--- Walks the entries with `seq > afterSeq`, up to the log's length now, in order, decoding each as it goes
--- (LOG-R42). An entry the codec can't read is skipped and counted in `PagleDB.global.decodeErrors`, once per
--- entry for this login however many readers meet it (LOG-R16).
---@param afterSeq integer?
---@return fun(): PagleRecord?
function CatchLog:Iterate(afterSeq)
	local entries, characters = self.data.entries, self.data.characters
	local last = #entries
	local seq = afterSeq or 0
	return function()
		while seq < last do
			seq = seq + 1
			local record = decode(entries[seq], seq, characters)
			if record then
				return record
			end
			countUndecodable(self, seq)
		end
		return nil
	end
end

--- Walks the entries of one record kind from the newest back to the oldest, decoding only those: how Core finds
--- the last build entry (LOG-R36) and each character's last Skill Reading (LOG-R31) without decoding every Cast.
--- An entry of that kind the codec can't read is skipped and counted as `Iterate` does (LOG-R16).
---@param kind "cast"|"skill"|"build"
---@return fun(): PagleRecord?
function CatchLog:Reverse(kind)
	local entries, characters = self.data.entries, self.data.characters
	local seq = #entries + 1
	return function()
		while seq > 1 do
			seq = seq - 1
			local entry = entries[seq]
			local codec = type(entry) == "string" and kinds[string.match(entry, "^[^|]*")]
			if codec and codec.kind == kind then
				local record = decode(entry, seq, characters)
				if record then
					return record
				end
				countUndecodable(self, seq)
			end
		end
		return nil
	end
end

--- Appends an entry for `record`, a typed record without `seq` and `id` (`{ kind = "cast", char, time, outcome,
--- conditions, items = { { itemID, quantity } } }`, `{ kind = "skill", char, time, rank, max, mod }` or
--- `{ kind = "build", char, time, build, version }`), and returns the record as every reader will see it.
--- Raises an error in the caller, appending nothing, for a record the codec can't write and read back.
---@param record table
---@return PagleRecord
function CatchLog:Append(record)
	local entries = self.data.entries
	local seq = #entries + 1
	local tag = TAGS[record.kind]
	local ok, entry = pcall(function()
		local fields = kinds[tag].encode(record)
		local tie = nextTie(entries, record.char, record.time)
		local header = { tag, integerField(record.char), integerField(record.time), integerField(tie) }
		return table.concat(header, "|") .. "|" .. table.concat(fields, "|")
	end)
	local appended = ok and decode(entry, seq, self.data.characters)
	if not appended then
		error(("the Catch log can't write this %s record"):format(tostring(record.kind)), 2)
	end
	ensureLogId(self.data, record.time)
	entries[seq] = entry
	return appended
end

--- Creates the log's logId if it has none yet and has a first character (LOG-R15). Core calls it once the
--- logged-in character is in the table, so the logId exists before the first append.
---@param now integer server time
function CatchLog:EnsureLogId(now)
	ensureLogId(self.data, now)
end

--- Opens the Catch log stored in `saved`, the PagleLog SavedVariable (LOG-R10). A fresh install (`saved` nil)
--- starts an empty log. A log in another format than the codec's starts a new one, keeping its characters
--- (LOG-R18); `started` says so, for the chat line. The logId is created once the log has a first character
--- (LOG-R15).
---@param saved table?
---@param global table PagleDB.global, where undecodable entries are counted (LOG-R16)
---@param now integer server time
---@return PagleCatchLog catchLog
---@return boolean started true when a log in another format was set aside for a new one
function ns.OpenCatchLog(saved, global, now)
	local started = false
	local data = saved
	if type(data) ~= "table" then
		data = { format = ns.LOG_FORMAT, characters = {}, entries = {} }
	elseif data.format ~= ns.LOG_FORMAT then
		local characters = data.characters or {}
		for key in pairs(data) do
			data[key] = nil
		end
		data.format, data.characters, data.entries = ns.LOG_FORMAT, characters, {}
		started = true
	end
	ensureLogId(data, now)
	return setmetatable({ data = data, global = global, undecodable = {} }, CatchLog), started
end
