---@class PagleNS
local ns = select(2, ...)

-- The Paste string (paste-string.md): upload documents built from PagleLog, cut into parts, and each part's Paste
-- string. pagle-backend's upload.md is canonical for what they hold (UPL-R50–R52, UPL Contracts › The Paste string and
-- › The upload document); this is Core's side of that contract. Pure logic, everything passed in (CORE-R7): the log
-- as a PagleLog table, and LibDeflate as the codec PasteString is handed (adapter/PasteExport.lua hands it the
-- vendored copy). It loads in the backend's driver too (#223), which hosts `bit`; nothing there builds a Paste string.

--- The upload document's version, in the header and the Paste string's prefix (PST-R10, PST-R30).
ns.PASTE_DOCUMENT_VERSION = 2
--- What every Paste string starts with (UPL-R50, PST-R30).
ns.PASTE_PREFIX = "!PGL" .. ns.PASTE_DOCUMENT_VERSION .. "!"
--- The most entries one part holds: the Paste part cap of UPL Tunables, which it must never exceed (PST-R22, PST-R23).
ns.PASTE_PART_ENTRIES = 5000
--- The most character lines one document may hold: the characters cap of UPL Tunables (PST-R15).
ns.PASTE_CHARACTERS_CAP = 100
--- The website's Paste upload page (PST-R51).
ns.PASTE_URL = "https://pagle.app/me/paste"
--- The test string's sizes, in KB of 1,024 characters (PST-R60).
ns.PASTE_TEST_MIN_KB, ns.PASTE_TEST_MAX_KB = 1, 2048

local bxor, rshift = bit.bxor, bit.rshift
local byte, concat, find, floor, format, match, sub =
	string.byte, table.concat, string.find, math.floor, string.format, string.match, string.sub

local TWO_32 = 4294967296

-- The CRC-32 table (UPL Contracts: zlib / ISO-HDLC, the polynomial 0x04C11DB7 reflected, 0xEDB88320), one entry per
-- byte value. LuaBitOp's results are signed 32-bit numbers: `% 2` and `% 256` read their low bits all the same, and
-- rshift shifts them as unsigned. Only bxor and rshift are used, the two the client's `bit` is checked for (LOG-R66).
---@type integer[]
local CRC_TABLE = {}
for n = 0, 255 do
	local c = n
	for _ = 1, 8 do
		if c % 2 == 1 then
			c = bxor(rshift(c, 1), 0xEDB88320)
		else
			c = rshift(c, 1)
		end
	end
	CRC_TABLE[n] = c
end

--- The CRC-32 of `bytes` as 8 lowercase hex digits (PST-R11, UPL Contracts): "cbf43926" for "123456789".
---@param bytes string
---@return string
function ns.Crc32(bytes)
	local crc = -1 -- every bit set: the initial 0xFFFFFFFF
	local i, n = 1, #bytes
	-- Four bytes a call to string.byte, then the rest one at a time.
	while i + 3 <= n do
		local b1, b2, b3, b4 = byte(bytes, i, i + 3)
		crc = bxor(rshift(crc, 8), CRC_TABLE[bxor(crc, b1) % 256])
		crc = bxor(rshift(crc, 8), CRC_TABLE[bxor(crc, b2) % 256])
		crc = bxor(rshift(crc, 8), CRC_TABLE[bxor(crc, b3) % 256])
		crc = bxor(rshift(crc, 8), CRC_TABLE[bxor(crc, b4) % 256])
		i = i + 4
	end
	while i <= n do
		crc = bxor(rshift(crc, 8), CRC_TABLE[bxor(crc, byte(bytes, i)) % 256])
		i = i + 1
	end
	crc = bxor(crc, -1) % TWO_32
	-- Two halves of 16 bits: %x of a number past 2^31 isn't safe where a C long has 32 bits.
	return format("%04x%04x", floor(crc / 65536), crc % 65536)
end

-- A whole number from 0 as the grammar's `nat` (UPL Contracts: decimal, no sign or leading zeros, at most 2^53 − 1),
-- or nil for anything else.
---@param value any
---@return string?
local function nat(value)
	if type(value) == "number" and value >= 0 and value == floor(value) and value <= 2 ^ 53 - 1 then
		return format("%.0f", value)
	end
	return nil
end

-- How many bytes the UTF-8 sequence led by byte `b` takes, and the range its second byte must be in (Unicode's
-- well-formed sequences: no overlong form, no surrogate, nothing past U+10FFFF); nil for a byte that can't lead one.
---@param b integer
---@return integer? size
---@return integer? low
---@return integer? high
local function utf8Lead(b)
	if b >= 0xC2 and b <= 0xDF then
		return 2, 0x80, 0xBF
	elseif b == 0xE0 then
		return 3, 0xA0, 0xBF
	elseif b == 0xED then
		return 3, 0x80, 0x9F
	elseif b >= 0xE1 and b <= 0xEF then
		return 3, 0x80, 0xBF
	elseif b == 0xF0 then
		return 4, 0x90, 0xBF
	elseif b >= 0xF1 and b <= 0xF3 then
		return 4, 0x80, 0xBF
	elseif b == 0xF4 then
		return 4, 0x80, 0x8F
	end
	return nil
end

--- `value` as field bytes (PST-R13, UPL Contracts' `field-byte`): only the bytes 0x20 to 0x7E but `|`, and whole
--- well-formed UTF-8 sequences, so it is valid UTF-8 with no LF, CR, control character or `|`. Anything else is left
--- out, as is a value that isn't a string.
---@param value any
---@return string
function ns.PasteFieldText(value)
	if type(value) ~= "string" then
		return ""
	end
	if not find(value, "[^\32-\123\125\126]") then
		return value -- plain printable ASCII without `|`, as nearly every name is
	end
	local kept, i, n = {}, 1, #value
	while i <= n do
		local b = byte(value, i)
		if b >= 0x20 and b <= 0x7E and b ~= 0x7C then
			kept[#kept + 1] = sub(value, i, i)
			i = i + 1
		else
			local size, low, high = utf8Lead(b)
			local whole = size ~= nil and i + size - 1 <= n
			if whole then
				---@cast size integer
				local second = byte(value, i + 1)
				whole = second >= low and second <= high
				for k = i + 2, i + size - 1 do
					local following = byte(value, k)
					whole = whole and following >= 0x80 and following <= 0xBF
				end
			end
			if whole then
				---@cast size integer
				kept[#kept + 1] = sub(value, i, i + size - 1)
				i = i + size
			else
				i = i + 1
			end
		end
	end
	return concat(kept)
end

--- A player GUID as the grammar has it: `Player-<digits>-<upper-case hex>` (UPL Contracts' `guid`).
---@param guid any
---@return boolean
local function isGUID(guid)
	return type(guid) == "string" and match(guid, "^Player%-%d+%-[0-9A-F]+$") ~= nil
end

--- `character`'s line in an upload document (PST-R12, PST-R13): guid, name, surname, classID, raceID, faction, realmID,
--- hardcore, firstSeen and lastSeen, `|`-separated, with no selfFound. Nil when its GUID isn't a player GUID (PST-R15).
---@param character PagleCharacter
---@return string?
function ns.PasteCharacterLine(character)
	if type(character) ~= "table" or not isGUID(character.guid) then
		return nil
	end
	local name = ns.PasteFieldText(character.name)
	local faction = character.faction
	if type(faction) ~= "string" or not match(faction, "^%a+$") then
		faction = "Unknown"
	end
	local hardcore = ""
	if character.hardcore == true then
		hardcore = "1"
	elseif character.hardcore == false then
		hardcore = "0"
	end
	return concat({
		character.guid,
		name ~= "" and name or "?",
		ns.PasteFieldText(character.surname),
		nat(character.classID) or "0",
		nat(character.raceID) or "0",
		faction,
		nat(character.realmID) or "0",
		hardcore,
		nat(character.firstSeen) or "0",
		nat(character.lastSeen) or "0",
	}, "|")
end

--- One part of an export (PST-R22): its entries are `from` to `from + count − 1`.
---@class PaglePastePart
---@field from integer
---@field count integer
---@field anchor string content checkpoint at from − 1, including the initial digest at from 1

--- An export (PST-R20): what its parts share, and the parts.
---@class PaglePasteExport
---@field logId string
---@field format integer
---@field asOf integer      GetServerTime() when the export was made
---@field total integer     the log's length then
---@field characters string[] the character lines (PST-R12)
---@field log table        the PagleLog itself, read through ns.LogBlocks: entries up to `total` never change (LOG-R14)
---@field parts PaglePastePart[]

-- The resolved character GUID of `entry`; nil when its header can't be read or
-- its character isn't in the table (PST-R15).
---@param entry any
---@param guids string[]
---@return string?
local function entryGUID(entry, guids)
	if type(entry) ~= "string" then
		return nil
	end
	local char = match(entry, "^%w+|([1-9]%d*)|%d+|%d+|")
	local guid = char and guids[tonumber(char)]
	if not guid then
		return nil
	end
	return guid
end

-- The cached checkpoint to start hashing from for an anchor at `need` (PST-R42): the highest kept seq at or below it
-- whose entry is still the one hashed there, and its digest; 0 and nil with none. A kept entry that differs (the log
-- replaced under the same logId) drops every kept checkpoint.
---@param cache table PagleDB.global.pasteCheckpoints, already for this log
---@param log table PagleLog
---@param need integer
---@param stride integer
---@return integer
---@return string?
local function cachedCheckpoint(cache, log, need, stride)
	for seq = need - need % stride, stride, -stride do
		local kept = cache.at[seq]
		if type(kept) == "table" then
			if kept.entry == ns.LogBlocks.Get(log, seq) and type(kept.digest) == "string" then
				return seq, kept.digest
			end
			cache.at = {}
			return 0, nil
		end
	end
	return 0, nil
end

--- The export of `log` (a PagleLog table) from `seq` `from` (PST-R20–R22): every entry from `from` to the log's
--- length now, in parts of at most `partSize` entries (PASTE_PART_ENTRIES by default). `from` may be one past the
--- log's end, for a single part with no entries. Nil when Core can't export the log (PST-R15).
---@param log table PagleLog
---@param from integer
---@param asOf integer GetServerTime() now
---@param partSize integer?
---@param pause fun()? lets the client yield between records while preparing a captured export
---@param checkpoints table? PagleDB.global.pasteCheckpoints, read and kept (PST-R42)
---@return PaglePasteExport?
function ns.PasteExport(log, from, asOf, partSize, pause, checkpoints)
	partSize = partSize or ns.PASTE_PART_ENTRIES
	local logId, characters = log.logId, log.characters
	local LogBlocks = ns.LogBlocks
	if
		type(logId) ~= "string"
		or not match(logId, "^[0-9a-f]+$")
		or #logId ~= 16
		or not (nat(log.format) and log.format >= 1)
		or type(characters) ~= "table"
		or type(log.blocks) ~= "table"
		or not nat(log.count)
		or LogBlocks.Problem(log) ~= nil -- a log Core can't read exports nothing (LOG-R104); an LF in an entry is one
		or #characters > ns.PASTE_CHARACTERS_CAP
	then
		return nil
	end
	local total = log.count
	if not nat(from) or from < 1 or from > total + 1 or not nat(asOf) or not nat(partSize) or partSize < 1 then
		return nil
	end
	local lines, guids = {}, {}
	for i, character in ipairs(characters) do
		local line = ns.PasteCharacterLine(character)
		if not line then
			return nil
		end
		lines[i], guids[i] = line, character.guid
	end
	-- The entries exported are checked before any hashing; the prefix is checked as it is hashed.
	for _, entry in LogBlocks.Iterate(log, from, total) do
		if not entryGUID(entry, guids) then
			return nil
		end
		if pause then
			pause()
		end
	end
	-- Another log's or format's checkpoints are read as none, and replaced only once one is kept.
	local stride, cache = ns.PASTE_PART_ENTRIES, checkpoints
	local current = cache ~= nil and cache.logId == logId and cache.format == log.format and type(cache.at) == "table"
	local seq, digest = 0, nil
	if cache and current then
		seq, digest = cachedCheckpoint(cache, log, from - 1, stride)
	end
	local walk = LogBlocks.Iterate(log, seq + 1, total) -- the prefix, one block split at a time
	digest = digest or ns.CheckpointInitial(logId, log.format)
	local parts = {}
	local start = from
	repeat
		while seq < start - 1 do
			local at, entry = walk()
			seq, entry = assert(at), assert(entry)
			local guid = entryGUID(entry, guids)
			if not guid then
				return nil
			end
			digest = ns.CheckpointNext(digest, seq, guid, entry)
			if cache and seq % stride == 0 then
				if not current then
					cache.logId, cache.format, cache.at, current = logId, log.format, {}, true
				end
				cache.at[seq] = { digest = digest, entry = entry }
			end
			if pause then
				pause()
			end
		end
		local count = math.min(partSize, total - start + 1)
		parts[#parts + 1] = { from = start, count = count, anchor = digest }
		start = start + count
	until start > total
	return {
		logId = logId,
		format = log.format,
		asOf = asOf,
		total = total,
		characters = lines,
		log = log,
		parts = parts,
	}
end

--- Part `n`'s upload document (PST-R10, PST-R11, PST-R14): the header, the character lines and its entries, each
--- line ending in one LF. Entries are the exact bytes captured by the export.
---@param export PaglePasteExport
---@param n integer
---@return string
function ns.PasteDocument(export, n)
	local part = export.parts[n]
	local lines = {}
	for i, line in ipairs(export.characters) do
		lines[i] = line
	end
	for _, entry in ns.LogBlocks.Iterate(export.log, part.from, part.from + part.count - 1) do
		lines[#lines + 1] = entry
	end
	local body = ""
	if #lines > 0 then
		lines[#lines + 1] = "" -- so the last line ends in its LF too
		body = concat(lines, "\n")
	end
	local header = concat({
		"PGL",
		ns.PASTE_DOCUMENT_VERSION,
		export.logId,
		nat(export.format),
		nat(export.asOf),
		nat(export.total),
		#export.characters,
		part.from,
		part.anchor,
		part.count,
		#body,
		ns.Crc32(body),
	}, "|")
	return header .. "\n" .. body
end

--- What compresses and print-encodes a document: LibDeflate 1.0.2, or anything with its two methods.
---@class PaglePasteCodec
---@field CompressDeflate fun(self: PaglePasteCodec, text: string): string
---@field EncodeForPrint fun(self: PaglePasteCodec, text: string): string

--- `document`'s Paste string (PST-R30, UPL-R50): the prefix, then the print encoding of its raw DEFLATE.
---@param document string
---@param codec PaglePasteCodec LibDeflate
---@return string
function ns.PasteString(document, codec)
	return ns.PASTE_PREFIX .. codec:EncodeForPrint(codec:CompressDeflate(document))
end

--- Where "New since last export" starts for `logId` (PST-R21): one after its last exported seq in `marks`
--- (PagleDB.global.pasteExports, PST-R40), or 1 with none.
---@param marks table?
---@param logId string
---@return integer
function ns.PasteNewFrom(marks, logId)
	local mark = type(marks) == "table" and nat(marks[logId]) and marks[logId] or 0
	return mark + 1
end

--- Notes in `marks` (PagleDB.global.pasteExports) that the Player copied `part` of `logId`'s export (PST-R40): the
--- mark rises to its last seq, and never falls. A part with no entries marks nothing.
---@param marks table
---@param logId string
---@param part PaglePastePart
function ns.MarkPasteCopied(marks, logId, part)
	if part.count < 1 then
		return
	end
	local last = part.from + part.count - 1
	if last >= ns.PasteNewFrom(marks, logId) then
		marks[logId] = last
	end
end

--- The copy test's string of `kb` KB (PST-R60): runs of 16 characters, each "(", its offset as 8 digits and
--- "PGLtest", all in the print alphabet. Nil for a size out of range.
---@param kb any
---@return string?
function ns.PasteTestString(kb)
	if not nat(kb) or kb < ns.PASTE_TEST_MIN_KB or kb > ns.PASTE_TEST_MAX_KB then
		return nil
	end
	local runs = {}
	for run = 0, kb * 64 - 1 do
		runs[run + 1] = format("(%08dPGLtest", run * 16)
	end
	return concat(runs)
end
