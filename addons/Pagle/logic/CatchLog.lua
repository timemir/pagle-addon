---@class PagleNS
local ns = select(2, ...)

-- The Catch log (LOG-R10–R16, LOG-R18) and its codec: pure logic over the PagleLog table, everything passed in
-- (CORE-R7). Each entry is one tagged string (ADR 0003); catch-log.md › Entry formats is the canonical layout.

--- A slot or good ID's shape (SHOP-R21): letters, digits, _ and . only. A purchase entry's good ID has it (LOG-R39),
--- and the goods registry refuses any other (logic/Goods.lua).
ns.GOOD_ID_PATTERN = "^[%w_.]+$"

--- A record Core hands out for one Catch log entry (LOG-R42). Records are shared and immutable (CORE-R18).
---@class PagleRecord
---@field seq integer            -- index in PagleLog.entries (LOG-R14)
---@field id string              -- entry ID: <character GUID>-<time>-<tie> (LOG-R13)
---@field kind "cast"|"skill"|"prestige"|"build"|"purchase"|"module"
---@field char integer           -- index into Angler.characters
---@field time integer           -- server time

--- A Cast (`C1`). A Species item carries its Simulated Size as `size` (LOG-R65).
---@class PagleCast : PagleRecord
---@field outcome "caught"|"gotAway"
---@field session string         -- its Session's ID (LOG-R98)
---@field conditions ConditionsSnapshot
---@field items { n: integer, itemID: integer, quantity: integer, catchId: string, size: PagleSize? }[]

--- A Skill Reading (`S1`, LOG-R31).
---@class PagleSkillReading : PagleRecord
---@field rank integer
---@field max integer
---@field mod integer
---@field session? string        -- the Session open when it was appended, if any (LOG-R98)

--- A build entry (`B1`, LOG-R36).
---@class PagleBuild : PagleRecord
---@field build integer          -- the GetBuildInfo() build number
---@field version string         -- e.g. "1.60.1"

--- A Prestige (`P1`, LOG-R38): the Angler's new prestige rank, one more than the Prestiges before it.
---@class PaglePrestige : PagleRecord
---@field rank integer

--- A purchase in the Curio Shop (`U1`, LOG-R39, SHOP-R10): the good bought and the price paid, in Coins.
---@class PaglePurchase : PagleRecord
---@field good string            -- the good's ID, [%w_.]+
---@field price integer          -- a whole number of Coins

--- A Module record (`A1`, LOG-R40, ADR 0008): opaque to Core, replayed only to the Module that wrote it (LOG-R41).
---@class PagleModuleRecord : PagleRecord
---@field module string          -- the writing Module's def.name
---@field recordKind string      -- the Module's own kind, [%w_.]+
---@field payload string         -- the Module's string, verbatim: no newline, at most 200 bytes when appended

--- The PagleLog layout version (LOG-R18). Before 1.0 it changes with any entry format change.
ns.LOG_FORMAT = 1

--- The most bytes a Module record's payload may hold (LOG-R40, Tunables).
ns.MODULE_RECORD_PAYLOAD_LIMIT = 200

--- Why a Module record of `kind` with `payload` can't be appended, or nil if it can (LOG-R40): `kind` must match
--- [%w_.]+ and `payload` be a string with no newline, at most MODULE_RECORD_PAYLOAD_LIMIT bytes.
---@param kind any
---@param payload any
---@return string?
function ns.ModuleRecordProblem(kind, payload)
	if type(kind) ~= "string" or not string.find(kind, "^[%w_.]+$") then
		return ("a Module record's kind must match [%%w_.]+, got %s"):format(tostring(kind))
	end
	if type(payload) ~= "string" then
		return "a Module record's payload must be a string, got " .. type(payload)
	end
	if string.find(payload, "\n", 1, true) then
		return "a Module record's payload can't hold a newline"
	end
	if #payload > ns.MODULE_RECORD_PAYLOAD_LIMIT then
		return ("a Module record's payload is at most %d bytes, got %d"):format(
			ns.MODULE_RECORD_PAYLOAD_LIMIT,
			#payload
		)
	end
	return nil
end

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

-- A whole number field, 0 or more (a rank, a price), or nil if the field isn't one.
---@param field string
---@return integer?
local function wholeNumber(field)
	if string.find(field, "^%d+$") then
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
-- (`encode`) and how to decode them into a record (`decode`, false if they don't fit the kind). With `rest`, the last
-- field is everything after the ones before it, `|` and all.
---@class PagleEntryCodec
---@field kind string
---@field count integer
---@field rest? boolean
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

	P1 = {
		kind = "prestige",
		count = 1,
		encode = function(record)
			return { integerField(record.rank) }
		end,
		decode = function(record, f)
			record.rank = wholeNumber(f[1])
			return record.rank ~= nil and record.rank >= 1
		end,
	},

	U1 = {
		kind = "purchase",
		count = 2,
		encode = function(record)
			if type(record.good) ~= "string" then
				error("not a good ID: " .. tostring(record.good))
			end
			return { record.good, integerField(record.price) }
		end,
		decode = function(record, f)
			record.good, record.price = f[1], wholeNumber(f[2])
			return string.find(f[1], ns.GOOD_ID_PATTERN) ~= nil and record.price ~= nil
		end,
	},

	A1 = {
		kind = "module",
		count = 3,
		rest = true, -- the payload is everything after the 6th |, verbatim (Entry formats)
		encode = function(record)
			local problem = ns.ModuleRecordProblem(record.recordKind, record.payload)
			if problem then
				error(problem)
			end
			if type(record.module) ~= "string" or not string.find(record.module, "^[%w_.]+$") then
				error("not a Module name: " .. tostring(record.module))
			end
			return { record.module, record.recordKind, record.payload }
		end,
		decode = function(record, f)
			record.module, record.recordKind, record.payload = f[1], f[2], f[3]
			return string.find(f[1], "^[%w_.]+$") ~= nil and string.find(f[2], "^[%w_.]+$") ~= nil
		end,
	},
}

-- The tag each record kind is written with: the newest one for that kind.
---@type table<string, string>
local TAGS = { cast = "C1", skill = "S1", build = "B1", prestige = "P1", purchase = "U1", module = "A1" }

-- Decodes one entry string into a typed record, or nil if the codec can't read it (LOG-R16). With `getItem`, each
-- item of a Cast carries its Simulated Size, from its Catch ID and the catalogue now (LOG-R65); item 0 is never
-- looked up.
---@param entry any
---@param seq integer
---@param characters table[]
---@param getItem (fun(itemID: integer): PagleItem?)?
---@return PagleRecord?
local function decode(entry, seq, characters, getItem)
	if type(entry) ~= "string" then
		return nil
	end
	local f = splitFields(entry)
	local codec = kinds[f[1]]
	local char, time, tie = integer(f[2] or ""), integer(f[3] or ""), integer(f[4] or "")
	if not codec or not char or not time or not tie then
		return nil
	end
	local last = 4 + codec.count
	if codec.rest and #f > last then
		f[last] = table.concat(f, "|", last)
		for i = #f, last + 1, -1 do
			f[i] = nil
		end
	end
	if #f ~= last then
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
	if getItem and record.kind == "cast" then
		for _, item in ipairs(record.items) do
			if item.itemID ~= 0 then
				item.size = ns.SizeOf(item.catchId, getItem(item.itemID))
			end
		end
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
---@field package cutters table<integer, PagleSessionCutter> a cutter fed up to each seq a read started or ended at
---@field package tail PagleSessionCutter? fed every entry up to the log's end, once something needs it (Append)
---@field package prestiges integer? the Prestiges in the log, once something needs them (Prestiges)
---@field package getItem (fun(itemID: integer): PagleItem?)? the catalogue the Casts it hands out are sized by (LOG-R65)
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

-- A Session cutter fed every record up to `afterSeq` that the tags after it depend on: from the first Cast of the
-- Session in progress at `afterSeq` (LOG-R98). That look-back decodes the open Session, so the cutter at each seq is
-- kept for the login: the log only grows, so the entries up to a seq never change. Each caller gets its own copy.
---@param catchLog PagleCatchLog
---@param afterSeq integer
---@return PagleSessionCutter
local function cutterAt(catchLog, afterSeq)
	local known = catchLog.cutters[afterSeq]
	if known then
		return known:Copy()
	end
	local cutter = ns.NewSessionCutter()
	local first = ns.SessionStartSeq(catchLog:Reverse("cast", afterSeq) --[[@as fun(): PagleCast?]])
	if first then
		local entries, characters = catchLog.data.entries, catchLog.data.characters
		for seq = first, afterSeq do
			local record = decode(entries[seq], seq, characters)
			if record then
				cutter:Add(record)
			end
		end
	end
	catchLog.cutters[afterSeq] = cutter:Copy()
	return cutter
end

--- Walks the entries with `seq > afterSeq`, up to the log's length now, in order, decoding each as it goes
--- (LOG-R42). Casts and Skill Readings carry their Session's ID, the same whether the log is read whole or from a
--- later `afterSeq` (LOG-R98). An entry the codec can't read is skipped and counted in `PagleDB.global.decodeErrors`,
--- once per entry for this login however many readers meet it (LOG-R16). Module records are yielded only to the
--- Module named by `module`, its own (LOG-R41, LOG-R42): without one, as Pagle.IterateCatches reads, none is; another
--- Module's are skipped, never counted as undecodable.
---@param afterSeq integer?
---@param module string? the reading Module's def.name (M:IterateCatches)
---@return fun(): PagleRecord?
function CatchLog:Iterate(afterSeq, module)
	local entries, characters = self.data.entries, self.data.characters
	local last = #entries
	local seq = math.min(afterSeq or 0, last)
	local cutter = cutterAt(self, seq)
	return function()
		while seq < last do
			seq = seq + 1
			local record = decode(entries[seq], seq, characters, self.getItem)
			if not record then
				countUndecodable(self, seq)
			else
				local owner = record.kind == "module" and (record --[[@as PagleModuleRecord]]).module or nil
				if owner == nil or owner == module then
					cutter:Add(record)
					return record
				end
			end
		end
		-- Read to its end: a later read from there needs no look-back.
		if not self.cutters[last] then
			self.cutters[last] = cutter:Copy()
		end
		return nil
	end
end

--- Walks the entries of one record kind from the newest back to the oldest, decoding only those: how Core finds
--- the last build entry (LOG-R36) and each character's last Skill Reading (LOG-R31) without decoding every Cast.
--- It starts at `fromSeq` when given, else at the log's end. Records it yields carry no session tag. An entry of
--- that kind the codec can't read is skipped and counted as `Iterate` does (LOG-R16).
---@param kind "cast"|"skill"|"prestige"|"build"|"purchase"
---@param fromSeq integer?
---@return fun(): PagleRecord?
function CatchLog:Reverse(kind, fromSeq)
	local entries, characters = self.data.entries, self.data.characters
	local seq = (fromSeq or #entries) + 1
	return function()
		while seq > 1 do
			seq = seq - 1
			local entry = entries[seq]
			local codec = type(entry) == "string" and kinds[string.match(entry, "^[^|]*")]
			if codec and codec.kind == kind then
				local record = decode(entry, seq, characters, self.getItem)
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
--- conditions, items = { { itemID, quantity } } }`, `{ kind = "skill", char, time, rank, max, mod }`,
--- `{ kind = "build", char, time, build, version }`, `{ kind = "prestige", char, time, rank }` or
--- `{ kind = "purchase", char, time, good, price }`), and returns the record as every reader will see it.
--- A Cast or Skill Reading carries its Session's ID (LOG-R98). Raises an error in the caller, appending nothing, for a
--- record the codec can't write and read back.
---@param record table
---@return PagleRecord
function CatchLog:Append(record)
	local entries = self.data.entries
	local seq = #entries + 1
	local tail = self:tailCutter()
	local tag = TAGS[record.kind]
	local ok, entry = pcall(function()
		local fields = kinds[tag].encode(record)
		local tie = nextTie(entries, record.char, record.time)
		local header = { tag, integerField(record.char), integerField(record.time), integerField(tie) }
		return table.concat(header, "|") .. "|" .. table.concat(fields, "|")
	end)
	local appended = ok and decode(entry, seq, self.data.characters, self.getItem)
	if not appended then
		error(("the Catch log can't write this %s record"):format(tostring(record.kind)), 2)
	end
	ensureLogId(self.data, record.time)
	entries[seq] = entry
	tail:Add(appended)
	if appended.kind == "prestige" and self.prestiges then
		self.prestiges = self.prestiges + 1
	end
	return appended
end

--- The number of Prestiges in the log (LOG-R38): its `P1` entries the codec can read, as every reader sees them.
--- Found once a login by walking the log for `P1` entries, decoding only those, then kept by Append. A login opens
--- the log once, so the count always belongs to this logId.
---@return integer
function CatchLog:Prestiges()
	if not self.prestiges then
		local count = 0
		for _ in self:Reverse("prestige") do
			count = count + 1
		end
		self.prestiges = count
	end
	return self.prestiges
end

-- The cutter fed every entry up to the log's end, made from the log the first time it's needed and fed each entry
-- appended since.
---@package
---@return PagleSessionCutter
function CatchLog:tailCutter()
	if not self.tail then
		self.tail = cutterAt(self, #self.data.entries)
	end
	return self.tail
end

--- The log's latest Session (LOG-R60), open or ended, or nil before its first Cast: the cutter's own table, which
--- changes as Casts are appended to it. Copy it (ns.SessionPayload) before handing it out.
---@return PagleSession?
function CatchLog:Session()
	return self:tailCutter():Session()
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
--- (LOG-R15). Every Cast it hands out sizes its Species items through `getItem`, the catalogue's GetItem, asked at
--- each decode, so a released catalogue sizes them from then on (LOG-R65, LOG-R96); without it, no item has a size.
---@param saved table?
---@param global table PagleDB.global, where undecodable entries are counted (LOG-R16)
---@param now integer server time
---@param getItem (fun(itemID: integer): PagleItem?)?
---@return PagleCatchLog catchLog
---@return boolean started true when a log in another format was set aside for a new one
function ns.OpenCatchLog(saved, global, now, getItem)
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
	local catchLog = { data = data, global = global, undecodable = {}, cutters = {}, getItem = getItem }
	return setmetatable(catchLog, CatchLog), started
end
