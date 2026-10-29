---@class PagleNS
local ns = select(2, ...)

-- The Catch log (LOG-R10–R16, LOG-R18) and its codec: pure logic over the PagleLog table, everything passed in
-- (CORE-R7). Each entry is one tagged string (ADR 0003); catch-log.md › Entry formats is the canonical layout.

--- A slot or good ID's shape (SHOP-R21): letters, digits, _ and . only. A purchase entry's good ID has it (LOG-R39),
--- and the goods registry refuses any other (logic/Goods.lua).
ns.GOOD_ID_PATTERN = "^[%w_.]+$"

--- A record Core hands out for one Catch log entry (LOG-R42). Records are shared and immutable (CORE-R18).
---@class PagleRecord
---@field seq integer            -- the entry's 1-based place in the log (LOG-R14, LOG-R103)
---@field id string              -- entry ID: <character GUID>-<time>-<tie> (LOG-R13)
---@field kind "cast"|"skill"|"prestige"|"build"|"purchase"|"module"|"companion"
---@field char integer           -- index into Angler.characters
---@field time integer           -- server time

--- A Cast (`C1`). A Species item carries its Simulated Size as `size` (LOG-R65), and its variety as `variety`
--- (VAR-R4).
---@class PagleCast : PagleRecord
---@field outcome "caught"|"gotAway"
---@field session string         -- its Session's ID (LOG-R98)
---@field conditions ConditionsSnapshot
---@field items { n: integer, itemID: integer, quantity: integer, catchId: string, size: PagleSize?, variety: PagleVariety? }[]

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
---@field rules string           -- shipped immutable backend rule-set ID

--- A Prestige (`P1`, LOG-R38): the Angler's new prestige rank, one more than the Prestiges before it, and Core's
--- Activity XP total when it was recorded (AXP-R5), 0 for a pre-1.0 dev log's P1, which has none.
---@class PaglePrestige : PagleRecord
---@field rank integer
---@field activityXP integer

--- A purchase in the Curio Shop (`U1`, LOG-R39, SHOP-R10): the good bought and the price paid, in Coins.
---@class PaglePurchase : PagleRecord
---@field good string            -- the good's ID, [%w_.]+
---@field price integer          -- a whole number of Coins

--- A Companion entry (`K1`, LOG-R37): the companion's data addon passed Core's check once, with that file's keyId and
--- seq. Core's own: only Core's projections are handed it (the wallet's reads it, SHOP-R29), never Pagle.IterateCatches
--- or a Module.
---@class PagleCompanion : PagleRecord
---@field keyId string           -- the accepted file's keyId, [%w_.-]+
---@field pushedSeq integer      -- the accepted file's seq (PUSH-R13)

--- Who reads a Companion entry (LOG-R37): Core's projections, which read the log as this reader (CatchLog:Iterate).
ns.COMPANION_READER = "Core"

--- A Module record (`A1`, LOG-R40, ADR 0008): opaque to Core, replayed only to the Module that wrote it (LOG-R41).
---@class PagleModuleRecord : PagleRecord
---@field module string          -- the writing Module's def.name
---@field recordKind string      -- the Module's own kind, [%w_.]+
---@field payload string         -- the Module's string, verbatim: no line feed, at most 200 bytes when appended

--- The PagleLog layout version (LOG-R18). 1.0 ships format 4, frozen from then on (LOG-R17); every beta or dev log
--- is another format, so it starts over at the first 1.0 login.
ns.LOG_FORMAT = 4
ns.RULE_SET_ID = "pagle-2026c"

--- The entries a new log packs into each block (LOG-R103). A log records its own `blockSize`, so a later Pagle may
--- choose another for new logs without breaking old ones.
ns.LOG_BLOCK_SIZE = 256

-- The block store (LOG-R103–R105): format 4 keeps the entries in `PagleLog.blocks`, each block `blockSize` entries
-- joined by a line feed, so a log of any length holds only about count / blockSize strings, far below the client's
-- limit of 262,143 constants in the one chunk that loads Pagle.lua. Every reader of the entries goes through
-- `ns.LogBlocks`: nothing is ever unpacked wholesale, so `_G.PagleLog` always holds the block form, which the client
-- can write at any moment, after a crash included, and load again.
---@class PagleLogBlocks
local LogBlocks = {}
ns.LogBlocks = LogBlocks

local floor = math.floor
local find, match, byte, sub = string.find, string.match, string.byte, string.sub

-- Blocks decoded to their lines, by log (weak, so a log let go takes its cache with it): the open block in its own
-- slot, and the others in a few slots by block number. A slot is only used while it holds the very string the log
-- holds for that block, so a block replaced by anything (Recovery, a spec) is never read stale.
local CACHE_SLOTS = 8
---@type table<table, table>
local caches = setmetatable({}, { __mode = "k" })
-- The logs LogBlocks.Problem has passed, by log (weak), with what it passed: the blocks table, a shallow copy of its
-- array (strings are interned, so comparing it is a pointer compare per block), and the counts. The check reads every
-- block's text, so it is done once a login: a log still exactly as it passed is trusted without another look, and
-- Append keeps the record up to date only for a log that still matched it. Anything else (a block replaced in place,
-- a key that isn't an array index, a different count) is checked in full.
---@type table<table, table>
local verified = setmetatable({}, { __mode = "k" })

-- Whether `data` is still exactly the log `seen` records.
---@param seen table?
---@param data table
---@return boolean
local function stillVerified(seen, data)
	local blocks = data.blocks
	if not seen or seen.blocks ~= blocks or seen.size ~= data.blockSize or seen.count ~= data.count then
		return false
	end
	local copy, n, keys = seen.copy, seen.n, 0
	if #blocks ~= n then
		return false
	end
	for i = 1, n do
		if copy[i] ~= blocks[i] then
			return false
		end
	end
	for _ in pairs(blocks) do
		keys = keys + 1
	end
	return keys == n
end

-- The lines of block `b` of `data`, split once and kept, or nil if the log has no such block.
---@param data table PagleLog
---@param b integer
---@return string[]?
local function linesOf(data, b)
	local blocks = data.blocks
	local text = type(blocks) == "table" and blocks[b]
	if type(text) ~= "string" then
		return nil
	end
	local cache = caches[data]
	if not cache then
		cache = {}
		caches[data] = cache
	end
	local open = cache.open
	if open and open.index == b and open.text == text then
		return open.lines
	end
	local slot = cache[b % CACHE_SLOTS]
	if slot and slot.index == b and slot.text == text then
		return slot.lines
	end
	local lines, n, at = {}, 0, 1
	while true do
		local stop = find(text, "\n", at, true)
		n = n + 1
		if not stop then
			lines[n] = sub(text, at)
			break
		end
		lines[n] = sub(text, at, stop - 1)
		at = stop + 1
	end
	slot = { index = b, text = text, lines = lines }
	if b == #blocks then
		cache.open = slot
	else
		cache[b % CACHE_SLOTS] = slot
	end
	return lines
end

--- The number of entries in the log (`PagleLog.count`), trusted once the log has been opened (LogBlocks.Problem).
---@param data table PagleLog
---@return integer
function LogBlocks.Count(data)
	return data.count
end

--- Entry `seq` (1-based), or nil if the log has none. Entry `seq` is line `((seq - 1) % blockSize) + 1` of block
--- `floor((seq - 1) / blockSize) + 1`.
---@param data table PagleLog
---@param seq integer
---@return string?
function LogBlocks.Get(data, seq)
	local size = data.blockSize
	if
		type(seq) ~= "number"
		or type(size) ~= "number"
		or type(data.count) ~= "number"
		or seq < 1
		or seq > data.count
		or seq % 1 ~= 0
	then
		return nil
	end
	local lines = linesOf(data, floor((seq - 1) / size) + 1)
	return lines and lines[(seq - 1) % size + 1]
end

--- Walks the entries from seq `fromSeq` (1 if nil) to `toSeq` (the log's end when the walk began, if nil), yielding each
--- as `seq, entry`. It splits one block at a time, so a walk of the whole log holds one block's lines at once.
---@param data table PagleLog
---@param fromSeq integer?
---@param toSeq integer?
---@return fun(): integer?, string?
function LogBlocks.Iterate(data, fromSeq, toSeq)
	local seq = math.max(fromSeq or 1, 1) - 1
	local last = math.min(toSeq or data.count, data.count)
	local size = data.blockSize
	local lines
	return function()
		if seq >= last then
			return nil
		end
		seq = seq + 1
		local at = (seq - 1) % size + 1
		if not lines or at == 1 then
			lines = linesOf(data, floor((seq - 1) / size) + 1)
		end
		return seq, lines and lines[at]
	end
end

-- Why `entry` can't be stored, or nil: it isn't a string, it holds a line feed (LOG-R101), which would add a line to
-- its block, or it is empty or starts with a byte below 0x20, which would make its block unreadable at the next login
-- (LOG-R104). Every tag starts with an uppercase letter, so no entry the codec writes is refused.
---@param entry any
---@return string?
local function entryProblem(entry)
	if type(entry) ~= "string" then
		return "a Catch log entry must be a string"
	elseif find(entry, "\n", 1, true) then
		return "a Catch log entry can't hold a line feed"
	elseif entry == "" or byte(entry, 1) < 0x20 then
		return "a Catch log entry can't be empty or start with a byte below 0x20"
	end
	return nil
end

-- The entries of block `b` that start with `prefix` ("P1|"), as { seq, entry } in order, found by searching the
-- block's text for "\n" .. prefix, which runs in C, and not by looking at every entry: the lines before a hit are
-- counted only to give its seq, so a block with no hit costs one search.
---@param data table PagleLog
---@param b integer
---@param prefix string
---@return { [1]: integer, [2]: string }[]
local function blockHits(data, b, prefix)
	local blocks = data.blocks
	local text = type(blocks) == "table" and blocks[b]
	local hits = {}
	if type(text) ~= "string" then
		return hits
	end
	local before = (b - 1) * data.blockSize
	local pos = sub(text, 1, #prefix) == prefix and 1 or nil
	if not pos then
		local at = find(text, "\n" .. prefix, 1, true)
		pos = at and at + 1
	end
	local from, line = 1, 1 -- `line` is the line `from` is on
	while pos do
		if pos > from then
			line = line + select(2, string.gsub(sub(text, from, pos - 1), "\n", "\n"))
			from = pos
		end
		local stop = find(text, "\n", pos, true)
		hits[#hits + 1] = { before + line, sub(text, pos, (stop or #text + 1) - 1) }
		local at = find(text, "\n" .. prefix, pos, true)
		pos = at and at + 1
	end
	return hits
end

--- Walks the entries whose tag is `tag` (they start with `tag .. "|"`) from seq `fromSeq` (1 if nil) to `toSeq` (the
--- log's end if nil), yielding each as `seq, entry`: how Core finds the few Skill Readings, builds, Prestiges and other
--- rare kinds in a log of any length without looking at every entry (LOG-R105).
---@param data table PagleLog
---@param tag string
---@param fromSeq integer?
---@param toSeq integer?
---@return fun(): integer?, string?
function LogBlocks.Tagged(data, tag, fromSeq, toSeq)
	local size, prefix = data.blockSize, tag .. "|"
	local from = math.max(fromSeq or 1, 1)
	local last = math.min(toSeq or data.count, data.count)
	local b, hits, at = floor((from - 1) / size), {}, 1
	return function()
		while true do
			local hit = hits[at]
			if hit then
				at = at + 1
				if hit[1] >= from and hit[1] <= last then
					return hit[1], hit[2]
				end
			else
				b = b + 1
				if b * size - size >= last then
					return nil
				end
				hits, at = blockHits(data, b, prefix), 1
			end
		end
	end
end

--- Walks the entries whose tag is `tag` from seq `fromSeq` (the log's end if nil) back to the first, newest first,
--- yielding each as `seq, entry`.
---@param data table PagleLog
---@param tag string
---@param fromSeq integer?
---@return fun(): integer?, string?
function LogBlocks.TaggedBack(data, tag, fromSeq)
	local size, prefix = data.blockSize, tag .. "|"
	local from = math.min(fromSeq or data.count, data.count)
	local b = from < 1 and 0 or floor((from - 1) / size) + 1
	local hits, at = {}, 0
	return function()
		while true do
			local hit = hits[at]
			if hit then
				at = at - 1
				if hit[1] <= from then
					return hit[1], hit[2]
				end
			elseif b < 1 then
				return nil
			else
				hits = blockHits(data, b, prefix)
				at, b = #hits, b - 1
			end
		end
	end
end

--- Appends `entry` as the log's next entry: into the open block, or a new block when that one is full. Only the open
--- block is ever rewritten (LOG-R14). Raises an error in the caller, appending nothing, for an entry that isn't a
--- string, holds a line feed (LOG-R101), or is empty or starts with a byte below 0x20 (LOG-R104): the next login
--- would not read the block.
---@param data table PagleLog
---@param entry string
function LogBlocks.Append(data, entry)
	local refused = entryProblem(entry)
	if refused then
		error(refused, 2)
	end
	local blocks, count = data.blocks, data.count
	local last = #blocks
	local seen = verified[data]
	local intact = stillVerified(seen, data) -- before it changes
	local cache = caches[data]
	if not cache then
		cache = {}
		caches[data] = cache
	end
	if last == 0 or count == last * data.blockSize then
		blocks[last + 1] = entry
		cache.open = { index = last + 1, text = entry, lines = { entry } }
	else
		local lines = linesOf(data, last) --[[@as string[] ]]
		local text = blocks[last] .. "\n" .. entry
		blocks[last] = text
		lines[#lines + 1] = entry
		cache.open = { index = last, text = text, lines = lines }
	end
	data.count = count + 1
	-- A log that was exactly as the check passed it is, with this one entry more; any other is checked again.
	if intact then
		local n = #blocks
		seen.copy[last], seen.copy[n] = blocks[last], blocks[n]
		seen.count, seen.n = data.count, n
	else
		verified[data] = nil
	end
end

--- The blocks that hold `entries`, `blockSize` to a block (the last may hold fewer), and their count: how a log is
--- built whole (Recovery, the test-log tooling). Raises an error in the caller for an entry Append refuses.
---@param entries string[]
---@param blockSize integer? ns.LOG_BLOCK_SIZE if nil
---@return string[] blocks
---@return integer count
function LogBlocks.Pack(entries, blockSize)
	blockSize = blockSize or ns.LOG_BLOCK_SIZE
	local blocks, count = {}, #entries
	for first = 1, count, blockSize do
		local last = math.min(first + blockSize - 1, count)
		for seq = first, last do
			local entry = entries[seq]
			local refused = entryProblem(entry)
			if refused then
				error(("Catch log entry %d: %s"):format(seq, refused), 2)
			end
		end
		blocks[#blocks + 1] = table.concat(entries, "\n", first, last)
	end
	return blocks, count
end

--- Why the block store in `data` can't be read, or nil if it can (LOG-R104): `blockSize` a whole number of 1 or more,
--- `count` a whole number of 0 or more, `blocks` an array of non-empty strings, none whose first byte is below 0x20
--- (reserved for a later block encoding), every block but the last holding `blockSize` lines, the last 1 to
--- `blockSize`, and `count` the lines they hold in all. Core checks it when it opens the log and never rewrites a log
--- it fails; it only reads, so a failure leaves `data` as it was.
---@param data table PagleLog
---@return string?
function LogBlocks.Problem(data)
	local size, count, blocks = data.blockSize, data.count, data.blocks
	if stillVerified(verified[data], data) then
		return nil
	end
	if type(size) ~= "number" or size < 1 or size % 1 ~= 0 then
		return "blockSize is not a whole number of 1 or more"
	end
	if type(count) ~= "number" or count < 0 or count % 1 ~= 0 then
		return "count is not a whole number"
	end
	if type(blocks) ~= "table" then
		return "blocks is not a table"
	end
	local held = 0
	for key in pairs(blocks) do
		if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #blocks then
			return "blocks is not an array"
		end
	end
	for b = 1, #blocks do
		local text = blocks[b]
		if type(text) ~= "string" or text == "" then
			return ("block %d is not a string"):format(b)
		end
		if byte(text, 1) < 0x20 then
			return ("block %d starts with a reserved byte"):format(b)
		end
		local lines, at = 1, 1
		while true do
			local stop = find(text, "\n", at, true)
			if not stop then
				break
			end
			lines, at = lines + 1, stop + 1
			if lines > size then
				return ("block %d holds more than blockSize lines"):format(b)
			end
		end
		if lines ~= size and b < #blocks then
			return ("block %d is sealed but holds %d of %d lines"):format(b, lines, size)
		end
		held = held + lines
	end
	if held ~= count then
		return ("count is %d but the blocks hold %d entries"):format(count, held)
	end
	local copy = {}
	for b = 1, #blocks do
		copy[b] = blocks[b]
	end
	verified[data] = { blocks = blocks, copy = copy, size = size, count = count, n = #blocks }
	return nil
end

--- The most bytes a Module record's payload may hold (LOG-R40, Tunables).
ns.MODULE_RECORD_PAYLOAD_LIMIT = 200

--- Why a Module record of `kind` with `payload` can't be appended, or nil if it can (LOG-R40): `kind` must match
--- [%w_.]+ and `payload` be a string with no line feed (LOG-R101), at most MODULE_RECORD_PAYLOAD_LIMIT bytes.
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
		return "a Module record's payload can't hold a line feed"
	end
	if #payload > ns.MODULE_RECORD_PAYLOAD_LIMIT then
		return ("a Module record's payload is at most %d bytes, got %d"):format(
			ns.MODULE_RECORD_PAYLOAD_LIMIT,
			#payload
		)
	end
	return nil
end

-- A decimal integer field, or nil if the field isn't one.
---@param field string
---@return integer?
local function integer(field)
	if field ~= "0" and not string.find(field, "^%-?[1-9]%d*$") then
		return nil
	end
	local value = tonumber(field)
	return value and math.abs(value) <= 9007199254740991 and value or nil
end

-- A whole number field, 0 or more (a rank, a price), or nil if the field isn't one.
---@param field string
---@return integer?
local function wholeNumber(field)
	local value = integer(field)
	return value and value >= 0 and value or nil
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
		count = 3,
		encode = function(record)
			assert(type(record.rules) == "string", "missing build rule-set ID")
			return { integerField(record.build), record.version, record.rules }
		end,
		decode = function(record, f)
			record.build, record.version, record.rules = integer(f[1]), f[2], f[3]
			return record.build ~= nil and f[2] ~= "" and f[3] ~= nil
		end,
	},

	P1 = {
		kind = "prestige",
		count = 2,
		encode = function(record)
			return { integerField(record.rank), integerField(record.activityXP or 0) }
		end,
		decode = function(record, f)
			record.rank = wholeNumber(f[1])
			record.activityXP = wholeNumber(f[2])
			return record.rank ~= nil and record.rank >= 1 and record.activityXP ~= nil
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

	-- LOG-R37: an additive kind, so PagleLog.format stays (LOG-R18); a Core from before it skips it (LOG-R16).
	K1 = {
		kind = "companion",
		count = 2,
		encode = function(record)
			if type(record.keyId) ~= "string" or not string.find(record.keyId, "^[%w_.%-]+$") then
				error("not a keyId: " .. tostring(record.keyId))
			end
			return { record.keyId, integerField(record.pushedSeq) }
		end,
		decode = function(record, f)
			record.keyId, record.pushedSeq = f[1], wholeNumber(f[2])
			return string.find(f[1], "^[%w_.%-]+$") ~= nil and record.pushedSeq ~= nil
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
local TAGS = {
	cast = "C1",
	skill = "S1",
	build = "B1",
	prestige = "P1",
	purchase = "U1",
	module = "A1",
	companion = "K1",
}

-- Who a record is for, when not every reader: a Module record's Module (LOG-R41), Core for a Companion entry
-- (LOG-R37); nil for a record every reader gets.
---@param record PagleRecord
---@return string?
function ns.RecordReader(record)
	if record.kind == "module" then
		return (record --[[@as PagleModuleRecord]]).module
	elseif record.kind == "companion" then
		return ns.COMPANION_READER
	end
	return nil
end

-- Decodes one entry string into a typed record, or nil if the codec can't read it (LOG-R16). Its Cast items carry no
-- size or variety yet: a reader that sizes them does so with the counts at its seq (sizeCast).
---@param entry any
---@param seq integer
---@param characters table[]
---@return PagleRecord?
local function decode(entry, seq, characters)
	local problem, f = ns.CanonicalRecordProblem(entry)
	if problem or not f then
		return nil
	end
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
	return record
end

-- The earlier Catch counts (LOG-R100): read from the raw entries, never decoded, so counting stays cheap and owes
-- nothing to the catalogue. A `C1` entry counts when its last field, the items, reads as decode reads it; its other
-- fields aren't looked at.
local COMMA = 44

--- The Angler's Catches of each item ID in the entries up to some seq (LOG-R100): one per slot, whatever its
--- quantity, on any character. Item 0 is never counted.
---@alias PagleCatchCounts table<integer, integer>

-- Counts each slot of an items field (`<itemID>x<quantity>`, comma-separated) into `counts`, `step` at a time, and
-- returns true; or, for a field that doesn't read, counts nothing and returns false.
---@param counts PagleCatchCounts
---@param field string
---@param step integer 1, or -1 to take the slots back out
---@return boolean
local function countItems(counts, field, step)
	local at, length = 1, #field
	while true do
		local _, last, itemID = find(field, "^(%d+)x%d+", at)
		if not last or (last < length and byte(field, last + 1) ~= COMMA) then
			if at > 1 then
				countItems(counts, sub(field, 1, at - 2), -step) -- the slots before, counted back out
			end
			return false
		end
		itemID = tonumber(itemID)
		if itemID ~= 0 then
			counts[itemID] = (counts[itemID] or 0) + step
		end
		if last == length then
			return true
		end
		at = last + 2
	end
end

-- Counts the slots of `entry`, if it is a `C1` entry whose items read, into `counts`, or (`step` -1) takes them back
-- out.
---@param counts PagleCatchCounts
---@param entry any
---@param step integer 1 or -1
local function countEntry(counts, entry, step)
	local field = type(entry) == "string" and match(entry, "^C1|.*|([^|]*)$")
	if field and field ~= "" then
		countItems(counts, field, step)
	end
end

-- The earlier Catch counts PagleDB.global.catchCounts keeps from the last login (LOG-R100), and the seq they end at,
-- if they are this log's: the same logId and size rules, ending at an entry this log holds at that seq. The log only
-- grows, so they still count its entries up to there.
---@param stored any PagleDB.global.catchCounts
---@param data table PagleLog
---@return integer? seq
---@return PagleCatchCounts? counts
local function storedCounts(stored, data)
	if type(stored) ~= "table" or data.logId == nil or stored.logId ~= data.logId then
		return nil
	end
	local seq = stored.seq
	if stored.rulesVersion ~= ns.SIZE_RULES_VERSION or type(seq) ~= "number" or type(stored.counts) ~= "table" then
		return nil
	end
	if seq < 1 or LogBlocks.Get(data, seq) ~= stored.entry then
		return nil
	end
	local counts = {}
	for itemID, n in pairs(stored.counts) do
		if type(itemID) ~= "number" or type(n) ~= "number" then
			return nil
		end
		counts[itemID] = n
	end
	return seq, counts
end

-- Keeps `counts`, over the entries up to `seq`, in PagleDB.global.catchCounts for the next login, if `seq` is the
-- log's end (LOG-R100). The tail's own table is kept as it is, so the counts Append feeds it go with it.
---@param catchLog PagleCatchLog
---@param seq integer
---@param counts PagleCatchCounts
local function storeCounts(catchLog, seq, counts)
	local data = catchLog.data
	if seq >= 1 and seq == data.count and data.logId ~= nil then
		catchLog.global.catchCounts = {
			logId = data.logId,
			rulesVersion = ns.SIZE_RULES_VERSION,
			seq = seq,
			entry = LogBlocks.Get(data, seq),
			counts = counts,
		}
	end
end

-- A copy of `counts`.
---@param counts PagleCatchCounts
---@return PagleCatchCounts
local function copyCounts(counts)
	local copy = {}
	for itemID, n in pairs(counts) do
		copy[itemID] = n
	end
	return copy
end

-- The tie for a new entry (LOG-R12): 0, or one more than the highest tie of an entry with the same character and
-- time. Entries are appended in time order, so only the tail from that second on is read; an entry whose header
-- doesn't parse is passed over.
---@param data table PagleLog
---@param char integer
---@param time integer
---@return integer
local function nextTie(data, char, time)
	local tie = 0
	for seq = data.count, 1, -1 do
		local entry = LogBlocks.Get(data, seq)
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
---@field package breaks PagleSessionBreaks where Sessions ended early: PagleDB.global.sessionBreaks (LOG-R99)
---@field package tail PagleSessionCutter? fed every entry up to the log's end, once something needs it (Append)
---@field package prestiges integer? the Prestiges in the log, once something needs them (Prestiges)
---@field package getItem (fun(itemID: integer): PagleItem?)? the catalogue the Casts it hands out are sized by (LOG-R65)
---@field package counts table<integer, PagleCatchCounts> the earlier Catch counts at each seq a read started or ended at
---@field package tailCounts PagleCatchCounts? the counts up to the log's end, once something needs them (Append)
---@field package skills { scanned: integer, [integer]: { seqs: integer[], ranks: integer[] } } each character's Skill
--- Readings in the entries up to `scanned`, by seq, once a Cast without a skill rank needs them
---@field package recentSeqs table<integer, integer> the seq of the record in each slot of `recent` (RECENT_RECORDS)
---@field package recent table<integer, PagleRecord|false> the records read forwards last, each in slot
--- seq % RECENT_RECORDS; false for an entry the codec can't read
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

-- The earlier Catch counts over the entries up to `seq` (LOG-R100), as the caller's own copy. Counted from the raw
-- entries, on or back from the nearest seq with counts known: seq 0, the counts the last login kept, a seq a read
-- started or ended at, or the tail at the log's end. The log only grows, so the counts at each seq are kept for the
-- login.
---@param catchLog PagleCatchLog
---@param seq integer
---@return PagleCatchCounts
local function countsAt(catchLog, seq)
	local data, kept, tail = catchLog.data, catchLog.counts, catchLog.tailCounts
	local last = data.count
	if tail and seq == last then
		return copyCounts(tail)
	end
	if kept[seq] then
		return copyCounts(kept[seq])
	end
	local from, known = 0, kept[0]
	for at, counts in pairs(kept) do
		if math.abs(at - seq) < math.abs(from - seq) then
			from, known = at, counts
		end
	end
	if tail and last - seq < math.abs(from - seq) then
		from, known = last, tail
	end
	local counts = copyCounts(known)
	for _, entry in LogBlocks.Iterate(data, from + 1, seq) do
		countEntry(counts, entry, 1)
	end
	for at = from, seq + 1, -1 do
		countEntry(counts, LogBlocks.Get(data, at), -1)
	end
	kept[seq] = copyCounts(counts)
	return counts
end

-- The rank of `char`'s latest Skill Reading before `seq`, or nil if it has none (LOG-R65). The Skill Readings are
-- found once a login, as far as a Cast needs them, by tag, decoding only those.
---@param catchLog PagleCatchLog
---@param char integer
---@param seq integer
---@return integer?
local function skillBefore(catchLog, char, seq)
	local skills, data = catchLog.skills, catchLog.data
	local function note(at, entry)
		local reading = decode(entry, at, data.characters) --[[@as PagleSkillReading?]]
		if reading then
			local own = skills[reading.char] or { seqs = {}, ranks = {} }
			own.seqs[#own.seqs + 1], own.ranks[#own.ranks + 1] = at, reading.rank
			skills[reading.char] = own
		end
	end
	if seq - 1 - skills.scanned < data.blockSize then
		-- A rebuild asks Cast after Cast, a few entries apart: looking at those is cheaper than searching a block.
		for at, entry in LogBlocks.Iterate(data, skills.scanned + 1, seq - 1) do
			if sub(entry, 1, 3) == "S1|" then
				note(at, entry)
			end
		end
	else
		for at, entry in LogBlocks.Tagged(data, "S1", skills.scanned + 1, seq - 1) do
			note(at, entry)
		end
	end
	skills.scanned = math.max(skills.scanned, math.min(seq - 1, data.count))
	local own = skills[char]
	if not own then
		return nil
	end
	-- The last of its readings before `seq`: a binary search, as a Cast read back may be far from the log's end.
	local low, high = 0, #own.seqs
	while low < high do
		local middle = math.ceil((low + high) / 2)
		if own.seqs[middle] < seq then
			low = middle
		else
			high = middle - 1
		end
	end
	return own.ranks[low]
end

-- Puts its Simulated Size and its variety on each Species item of `cast` (LOG-R65, LOG-R67, VAR-R4), `counts` being
-- the earlier Catch counts over the entries before it: an item's earlier Catches are those plus its earlier slots in
-- this Cast. The skill is the Cast's rank, else the character's latest Skill Reading's, else 1. The variety owes
-- nothing to the counts or the skill (VAR-R5). Item 0 is never looked up.
---@param catchLog PagleCatchLog
---@param cast PagleCast
---@param counts PagleCatchCounts
local function sizeCast(catchLog, cast, counts)
	local getItem = catchLog.getItem --[[@as fun(itemID: integer): PagleItem?]]
	local skillRank = cast.conditions.skillRank
	local inCast = {}
	for _, item in ipairs(cast.items) do
		local itemID = item.itemID
		if itemID ~= 0 then
			local before = inCast[itemID] or 0
			inCast[itemID] = before + 1
			local known = getItem(itemID)
			if known then
				skillRank = skillRank or skillBefore(catchLog, cast.char, cast.seq) or 1
				item.size = ns.SizeOf(item.catchId, known, skillRank, (counts[itemID] or 0) + before)
				item.variety = ns.VarietyOf(item.catchId, known)
			end
		end
	end
end

-- Steps `counts` past one entry read forwards: sizes it by the counts before it when it is a Cast (LOG-R67), then
-- counts its items in (LOG-R100).
---@param catchLog PagleCatchLog
---@param counts PagleCatchCounts
---@param record PagleRecord?
---@param entry any
local function stepCounts(catchLog, counts, record, entry)
	if record and record.kind == "cast" then
		sizeCast(catchLog, record --[[@as PagleCast]], counts)
	end
	countEntry(counts, entry, 1)
end

-- CatchLog:Reverse's walk; Casts carry their sizes when `sized` and the log has a catalogue. Walking back, the
-- counts start at `fromSeq` and each entry passed is taken back out, so they always cover the entries before the next.
---@param catchLog PagleCatchLog
---@param kind "cast"|"skill"|"prestige"|"build"|"purchase"|"companion"
---@param fromSeq integer?
---@param sized boolean
---@param byTag boolean? look at the entries of the kind's tag only, even for a Cast (never sized)
---@return fun(): PagleRecord?
local function reverse(catchLog, kind, fromSeq, sized, byTag)
	local data = catchLog.data
	local characters = data.characters
	if kind ~= "cast" or byTag then
		-- Only the entries of its tag are looked at (LogBlocks.TaggedBack), however long the log.
		local walk = LogBlocks.TaggedBack(data, TAGS[kind], fromSeq)
		return function()
			while true do
				local seq, entry = walk()
				if not seq then
					return nil
				end
				local record = decode(entry --[[@as string]], seq, characters)
				if record then
					return record
				end
				countUndecodable(catchLog, seq)
			end
		end
	end
	local seq = math.min(fromSeq or data.count, data.count) + 1 -- past the end there is nothing to walk, nor to count
	local counts -- the earlier Catch counts over the entries before `seq`, once the first Cast is asked for
	sized = sized and kind == "cast" and catchLog.getItem ~= nil
	return function()
		if sized and not counts then
			counts = countsAt(catchLog, seq - 1)
		end
		while seq > 1 do
			seq = seq - 1
			local entry = LogBlocks.Get(data, seq)
			if counts then
				countEntry(counts, entry, -1)
			end
			local codec = type(entry) == "string" and kinds[string.match(entry, "^[^|]*")]
			if codec and codec.kind == kind then
				local record = decode(entry, seq, characters)
				if record then
					if counts then
						sizeCast(catchLog, record --[[@as PagleCast]], counts)
					end
					return record
				end
				countUndecodable(catchLog, seq)
			end
		end
		return nil
	end
end

-- The Session cutter PagleDB.global.tailSession kept from the last login, brought on to `afterSeq`, if it is this
-- log's: the same logId and Session rules, ending at an entry this log holds at that seq, no later than `afterSeq`.
-- The log only grows, so it still holds the Session it was cut with; the entries after it are fed as a read would.
-- Nil when there is none to use, and the look-back finds the Session instead.
---@param catchLog PagleCatchLog
---@param afterSeq integer
---@return PagleSessionCutter?
local function storedCutter(catchLog, afterSeq)
	local stored, data = catchLog.global.tailSession, catchLog.data
	if
		type(stored) ~= "table"
		or data.logId == nil
		or stored.logId ~= data.logId
		or stored.rulesVersion ~= ns.SESSION_RULES_VERSION
		or type(stored.seq) ~= "number"
		or stored.seq % 1 ~= 0
		or stored.seq < 0
		or stored.seq > afterSeq
		or (stored.seq == 0) ~= (stored.entry == nil)
		or (stored.seq > 0 and LogBlocks.Get(data, stored.seq) ~= stored.entry)
	then
		return nil
	end
	local cutter = ns.NewSessionCutter(catchLog.breaks)
	-- `false` is a log with no Cast yet; anything else must read as a cutter's own Session.
	if stored.session ~= false and not ns.RestoreSessionCut(cutter, stored.session) then
		return nil
	end
	for seq, entry in LogBlocks.Iterate(data, stored.seq + 1, afterSeq) do
		local record = decode(entry, seq, data.characters)
		if record then
			cutter:Add(record)
		end
	end
	return cutter
end

-- Keeps the log's tail cutter in PagleDB.global.tailSession for the next login: its Session as it is (the cutter's own
-- table, so the Casts Append feeds it go with it), the seq it ends at and the entry there. A cache of the log, never a
-- source: losing it changes nothing.
---@param catchLog PagleCatchLog
local function storeCutter(catchLog)
	local data, tail = catchLog.data, catchLog.tail
	if tail and data.logId ~= nil then
		local seq = data.count
		catchLog.global.tailSession = {
			logId = data.logId,
			rulesVersion = ns.SESSION_RULES_VERSION,
			seq = seq,
			entry = seq > 0 and LogBlocks.Get(data, seq) or nil,
			session = tail:Session() or false,
		}
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
	local cutter = storedCutter(catchLog, afterSeq)
	if not cutter then
		cutter = ns.NewSessionCutter(catchLog.breaks)
		-- The Casts of the Session in progress are decoded once, on the way back, and fed from its first: only Casts
		-- change what a cutter holds (a Skill Reading is tagged, never counted).
		local casts = {}
		ns.SessionStartSeq(
			reverse(catchLog, "cast", afterSeq, false) --[[@as fun(): PagleCast?]],
			catchLog.breaks,
			casts
		)
		for i = #casts, 1, -1 do
			cutter:Add(casts[i])
		end
	end
	catchLog.cutters[afterSeq] = cutter:Copy()
	return cutter
end

-- How many of the records read forwards last the log keeps, by seq. The projections catching up or
-- rebuilding take turns an entry at a time (logic/Projections.lua), so the next to read an entry finds its record here:
-- each entry is decoded and sized once between them instead of once each. Records are shared (CORE-R18), and the one
-- at a seq is the same for every forward reader this login (LOG-R98, LOG-R100), as the log only grows.
local RECENT_RECORDS = 64

-- Keeps `record` (false for an entry the codec can't read) as the one read last at `seq`.
---@param catchLog PagleCatchLog
---@param seq integer
---@param record PagleRecord|false
local function keepRecent(catchLog, seq, record)
	local slot = seq % RECENT_RECORDS
	catchLog.recentSeqs[slot], catchLog.recent[slot] = seq, record
end

--- Walks the entries with `seq > afterSeq`, up to the log's length now, in order, decoding each as it goes
--- (LOG-R42). Casts and Skill Readings carry their Session's ID, and Casts their Simulated Sizes, the same whether the
--- log is read whole or from a later `afterSeq` (LOG-R98, LOG-R100). An entry the codec can't read is skipped and
--- counted in `PagleDB.global.decodeErrors`, once per entry for this login however many readers meet it (LOG-R16). Module records are yielded only to the
--- Module named by `module`, its own (LOG-R41, LOG-R42): without one, as Pagle.IterateCatches reads, none is; another
--- Module's are skipped, never counted as undecodable. A Companion entry is yielded only to ns.COMPANION_READER, Core's
--- projections (LOG-R37). An entry read forwards last is handed out as the record already made for it
--- (RECENT_RECORDS), its sizes and Session already on it.
---@param afterSeq integer?
---@param module string? the reading Module's def.name (M:IterateCatches)
---@return fun(): PagleRecord?
function CatchLog:Iterate(afterSeq, module)
	local data = self.data
	local characters = data.characters
	local recentSeqs, recent = self.recentSeqs, self.recent
	local last = data.count
	local seq = math.min(afterSeq or 0, last)
	local lines = LogBlocks.Iterate(data, seq + 1, last) -- one block split at a time (LOG-R105)
	local cutter = cutterAt(self, seq)
	local counts = self.getItem and countsAt(self, seq) -- over the entries before the next
	return function()
		while seq < last do
			local at, entry = lines()
			seq = at --[[@as integer]]
			local record
			if recentSeqs[seq % RECENT_RECORDS] == seq then
				record = recent[seq % RECENT_RECORDS] or nil
				if counts then
					countEntry(counts, entry, 1)
				end
			else
				record = decode(entry, seq, characters)
				if counts then
					stepCounts(self, counts, record, entry)
				end
			end
			if not record then
				countUndecodable(self, seq)
				keepRecent(self, seq, false)
			else
				-- Only Casts and Skill Readings get a Session, and they are every reader's (LOG-R98).
				cutter:Add(record)
				keepRecent(self, seq, record)
				local owner = ns.RecordReader(record)
				if owner == nil or owner == module then
					return record
				end
			end
		end
		-- Read to its end: a later read from there needs no look-back.
		if not self.cutters[last] then
			self.cutters[last] = cutter:Copy()
		end
		if counts and not self.counts[last] and not (self.tailCounts and last == data.count) then
			self.counts[last] = copyCounts(counts)
			storeCounts(self, last, self.counts[last])
		end
		return nil
	end
end

--- Walks the entries of one record kind from the newest back to the oldest, decoding only those: how Core finds
--- the last build entry (LOG-R36) and each character's last Skill Reading (LOG-R31) without decoding every Cast.
--- It starts at `fromSeq` when given, else at the log's end. Records it yields carry no session tag; Casts carry
--- the Simulated Sizes every other read gives them (LOG-R100). An entry of that kind the codec can't read is skipped
--- and counted as `Iterate` does (LOG-R16).
---@param kind "cast"|"skill"|"prestige"|"build"|"purchase"|"companion"
---@param fromSeq integer?
---@return fun(): PagleRecord?
function CatchLog:Reverse(kind, fromSeq)
	return reverse(self, kind, fromSeq, true)
end

--- The number of entries in the log (LOG-R105).
---@return integer
function CatchLog:Count()
	return self.data.count
end

--- Whether the log holds a record of `kind` the codec can read, found by its tag, newest first, without sizing or
--- counting anything: how Core asks whether there is a Cast at all (ONB-R2). Entries of the kind it can't read are
--- counted as Reverse counts them (LOG-R16).
---@param kind "cast"|"skill"|"prestige"|"build"|"purchase"|"companion"
---@return boolean
function CatchLog:Has(kind)
	return reverse(self, kind, nil, false, true)() ~= nil
end

--- Entry `seq` as it is stored, the raw string, or nil if the log has none (LOG-R105). Records come from `Iterate`
--- and `Reverse`; this is for what reads the stored text itself.
---@param seq integer
---@return string?
function CatchLog:Get(seq)
	return LogBlocks.Get(self.data, seq)
end

--- Appends an entry for `record`, a typed record without `seq` and `id` (`{ kind = "cast", char, time, outcome,
--- conditions, items = { { itemID, quantity } } }`, `{ kind = "skill", char, time, rank, max, mod }`,
--- `{ kind = "build", char, time, build, version }`, `{ kind = "prestige", char, time, rank, activityXP }` (0 without
--- activityXP), `{ kind = "purchase", char, time, good, price }` or
--- `{ kind = "companion", char, time, keyId, pushedSeq }`), and returns the record as every reader will see it.
--- A Cast or Skill Reading carries its Session's ID (LOG-R98), and a Cast its Simulated Sizes, counted over the log
--- before it (LOG-R100). Raises an error in the caller, appending nothing, for a record the codec can't write and read
--- back, and for one whose entry would hold a line feed (LOG-R101).
---@param record table
---@return PagleRecord
function CatchLog:Append(record)
	local data = self.data
	local seq = data.count + 1
	local tail = self:tailCutter()
	-- Counted on from the log's end only for a Cast, whose size needs the earlier Catches; any other entry leaves the
	-- counts as they are, so a log that has none yet is not counted whole to append a Skill Reading or a build (LOG-R100).
	local counts = self.getItem and (record.kind == "cast" and self:tailCatchCounts() or self.tailCounts)
	local tag = TAGS[record.kind]
	local ok, entry = pcall(function()
		local fields = kinds[tag].encode(record)
		local tie = nextTie(data, record.char, record.time)
		local header = { tag, integerField(record.char), integerField(record.time), integerField(tie) }
		return table.concat(header, "|") .. "|" .. table.concat(fields, "|")
	end)
	-- No entry ever holds a line feed (LOG-R101), whoever writes it and whatever its fields say.
	local appended = ok and not find(entry, "\n", 1, true) and decode(entry, seq, data.characters)
	if not appended then
		error(("the Catch log can't write this %s record"):format(tostring(record.kind)), 2)
	end
	ensureLogId(data, record.time)
	LogBlocks.Append(data, entry)
	if counts then
		stepCounts(self, counts, appended, entry)
		storeCounts(self, seq, counts)
	end
	tail:Add(appended)
	storeCutter(self)
	if appended.kind == "prestige" and self.prestiges then
		self.prestiges = self.prestiges + 1
	end
	if appended.kind == "companion" then
		self.companion = true
	end
	return appended
end

--- Whether the log holds a Companion entry (LOG-R37), as every reader sees it: found once a login by walking the log
--- for `K1` entries, decoding only those, then kept by Append.
---@return boolean
function CatchLog:HasCompanion()
	if self.companion == nil then
		self.companion = self:Reverse("companion")() ~= nil
	end
	return self.companion
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
		self.tail = cutterAt(self, self.data.count)
		storeCutter(self)
	end
	return self.tail
end

-- The earlier Catch counts over every entry up to the log's end, counted from the log the first time they're needed
-- and fed each entry appended since (LOG-R100).
---@package
---@return PagleCatchCounts
function CatchLog:tailCatchCounts()
	if not self.tailCounts then
		self.tailCounts = countsAt(self, self.data.count)
		storeCounts(self, self.data.count, self.tailCounts)
	end
	return self.tailCounts
end

--- The log's latest Session (LOG-R60), open or ended, or nil before its first Cast: the cutter's own table, which
--- changes as Casts are appended to it. Copy it (ns.SessionPayload) before handing it out.
---@return PagleSession?
function CatchLog:Session()
	return self:tailCutter():Session()
end

--- `/pagle dev endsession` (#258): notes in PagleDB.global.sessionBreaks that the log's latest Session ended early
--- after its last Cast (LOG-R99), so the next Cast opens a new Session, however soon, now and in every later read.
function CatchLog:BreakSession()
	local session = self:tailCutter():Session()
	if session then
		local breaks = self.global.sessionBreaks or {}
		breaks[session.lastID] = true
		self.global.sessionBreaks = breaks
	end
end

--- Creates the log's logId if it has none yet and has a first character (LOG-R15). Core calls it once the
--- logged-in character is in the table, so the logId exists before the first append.
---@param now integer server time
function CatchLog:EnsureLogId(now)
	ensureLogId(self.data, now)
end

--- Why the Catch log stored in `saved` can't be opened, or nil if it can (LOG-R104). It can't when it is in the codec's
--- format and its block store fails LogBlocks.Problem, or when its format is newer than the codec's or not a number: a
--- Pagle from the future wrote it, or something else did, and nothing here may empty it. A fresh install, and a log
--- in an older format (which starts over, LOG-R18), have no such problem. It reads `saved` and changes nothing; the
--- block check is done once for a log still as it was (LogBlocks.Problem).
---@param saved any
---@return string?
function ns.CatchLogProblem(saved)
	if type(saved) ~= "table" then
		return nil
	end
	local format = saved.format
	if type(format) ~= "number" then
		return "its format is not a number"
	elseif format > ns.LOG_FORMAT then
		return ("it is format %s, newer than the %d this Pagle reads"):format(tostring(format), ns.LOG_FORMAT)
	elseif format == ns.LOG_FORMAT then
		return LogBlocks.Problem(saved)
	end
	return nil
end

--- Opens the Catch log stored in `saved`, the PagleLog SavedVariable (LOG-R10), the one way in for Core, the
--- backend's driver and the tooling alike. A fresh install (`saved` nil) starts an empty log. A log in another format
--- than the codec's, an older one, starts a new one, keeping its characters (LOG-R18); `started` says so, for the chat
--- line. A log that ns.CatchLogProblem finds unreadable (LOG-R104: a format-4 block store that fails its check, a format
--- newer than the codec's, a format that isn't a number) is not opened: it raises an error, and leaves `saved` exactly
--- as it was, since nothing may rewrite it; check first with ns.CatchLogProblem, which is cheap after the first call. The
--- logId is created once
--- the log has a first character (LOG-R15). Every Cast it hands out sizes its Species items, and gives them their
--- varieties, through `getItem`, the catalogue's GetItem, asked at each decode, so a released catalogue sizes them from
--- then on (LOG-R65, LOG-R96, VAR-R4); without it, no item has a size or a variety.
---
--- The table it expects: `format = 4`, `logId` (a string, once the log has a first character), `characters`
--- (an array of tables), `blockSize` (a whole number, 1 or more), `count` (the entries held) and `blocks` (an array of
--- strings, each `blockSize` entries joined by a line feed, the last holding 1 to `blockSize`). It needs no client API.
---@param saved table?
---@param global table PagleDB.global, where undecodable entries are counted (LOG-R16) and Session breaks kept (LOG-R99)
---@param now integer server time
---@param getItem (fun(itemID: integer): PagleItem?)?
---@return PagleCatchLog catchLog
---@return boolean started true when a log in another format was set aside for a new one
function ns.OpenCatchLog(saved, global, now, getItem)
	local started = false
	local data = saved
	if type(data) ~= "table" then
		data = { format = ns.LOG_FORMAT, characters = {}, blockSize = ns.LOG_BLOCK_SIZE, count = 0, blocks = {} }
	elseif ns.CatchLogProblem(data) then
		error("the Catch log can't be read: " .. ns.CatchLogProblem(data), 2)
	elseif data.format ~= ns.LOG_FORMAT then
		local characters = data.characters or {}
		for key in pairs(data) do
			data[key] = nil
		end
		data.format, data.characters = ns.LOG_FORMAT, characters
		data.blockSize, data.count, data.blocks = ns.LOG_BLOCK_SIZE, 0, {}
		started = true
	end
	ensureLogId(data, now)
	local catchLog = {
		data = data,
		global = global,
		undecodable = {},
		cutters = {},
		getItem = getItem,
		counts = { [0] = {} },
		skills = { scanned = 0 },
		recentSeqs = {},
		recent = {},
	}
	local storedSeq, stored = storedCounts(global.catchCounts, data)
	if storedSeq then
		catchLog.counts[storedSeq] = stored
	end
	-- Asked as each Cast is fed, so the cutters kept for the login see a break noted after they were made.
	function catchLog.breaks(castID)
		local breaks = global.sessionBreaks
		return type(breaks) == "table" and breaks[castID] == true
	end
	return setmetatable(catchLog, CatchLog), started
end
