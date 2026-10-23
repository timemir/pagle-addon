-- The Paste string's logic (paste-string.md PST-R10–R33, PST-R40, PST-R60), checked against pagle-backend's upload.md:
-- its grammar (UPL Contracts › The upload document), its CRC-32 and its example, and LibDeflate 1.0.2 decoding what
-- Core encodes (UPL Contracts › The Paste string). The grammar is written out below from upload.md, apart from Core's
-- code, and so is a CRC-32 that uses no `bit`.

local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
local ns = loaded.ns
local LibDeflate = loaded.env.LibStub:GetLibrary("LibDeflate")

local LOG_ID = "3f9a2c1e7b0d4a65"
local ADA = "Player-4618-0A1B2C3D"
local BEA = "Player-4618-0B2C3D4E"
local AS_OF = 1791735100

-- The CRC-32 of UPL Contracts (zlib / ISO-HDLC) a bit at a time, in plain arithmetic: the spec's own, slow, check.
---@param bytes string
---@return string
local function referenceCrc(bytes)
	local function xor(a, b)
		local result, bitValue = 0, 1
		while a > 0 or b > 0 do
			if a % 2 ~= b % 2 then
				result = result + bitValue
			end
			a, b, bitValue = math.floor(a / 2), math.floor(b / 2), bitValue * 2
		end
		return result
	end
	local crc = 0xFFFFFFFF
	for i = 1, #bytes do
		crc = xor(crc, bytes:byte(i))
		for _ = 1, 8 do
			if crc % 2 == 1 then
				crc = xor(math.floor(crc / 2), 0xEDB88320)
			else
				crc = math.floor(crc / 2)
			end
		end
	end
	return ("%08x"):format(xor(crc, 0xFFFFFFFF))
end

-- A field the log lacks, in `character`'s fields: a table can't hold nil.
local NONE = {}

-- A character of PagleLog (catch-log.md › Data) with `fields` over Ada's; NONE removes one.
local function character(fields)
	local made = {
		guid = ADA,
		name = "Ada",
		surname = "Brook",
		classID = 1,
		raceID = 1,
		faction = "Alliance",
		realmID = 4618,
		hardcore = false,
		firstSeen = 1791731680,
		lastSeen = 1791735090,
	}
	for key, value in pairs(fields or {}) do
		if value == NONE then
			made[key] = nil
		else
			made[key] = value
		end
	end
	return made
end

-- A PagleLog table holding `entries`, with Ada, or `characters`.
local function log(entries, characters)
	return { format = 1, logId = LOG_ID, characters = characters or { character() }, entries = entries }
end

-- `n` Skill Readings of character `char` (1), one a second from `first`, as entries: enough for parts.
local function readings(n, first, char)
	local entries = {}
	for i = 1, n do
		entries[i] = ("S1|%d|%d|0|%d|150|0"):format(char or 1, first + i, i)
	end
	return entries
end

-- The fields of `line`, split on `|`, empty ones kept.
local function fields(line)
	local found = {}
	for field in (line .. "|"):gmatch("([^|]*)|") do
		found[#found + 1] = field
	end
	return found
end

local NAT = function(text)
	return text == "0" or (text:match("^[1-9]%d*$") ~= nil and #text <= 16)
end
local NAT1 = function(text)
	return text:match("^[1-9]%d*$") ~= nil and #text <= 16
end
local GUID = "^Player%-%d+%-[0-9A-F]+$"
local ENTRY_ID = "^Player%-%d+%-[0-9A-F]+%-(%d+)%-(%d+)$"

-- Parses `document` by upload.md's grammar (UPL Contracts › The upload document) and UPL-R10's steps 4 to 8, failing
-- the spec at the first rule it breaks, and returns what it holds.
local function parse(document)
	local headerEnd = assert(document:find("\n", 1, true), "the document has an LF")
	local header = fields(document:sub(1, headerEnd - 1))
	assert.are.equal(12, #header, "the header has 12 fields")
	assert.are.equal("PGL", header[1])
	assert.are.equal("1", header[2], "doc-version")
	assert(header[3]:match("^[0-9a-f]+$") and #header[3] == 16, "log-id is 16hexlc")
	assert(NAT1(header[4]), "format is nat1")
	for i, name in pairs({ [5] = "as-of", [6] = "total", [7] = "chars", [10] = "count", [11] = "body-bytes" }) do
		assert(NAT(header[i]), name .. " is nat")
	end
	assert(NAT1(header[8]), "from is nat1")
	local from, count, total, chars =
		tonumber(header[8]), tonumber(header[10]), tonumber(header[6]), tonumber(header[7])
	if header[9] == "" then
		assert.are.equal(1, from, "anchor is empty only when from = 1")
	else
		local time, tie = header[9]:match(ENTRY_ID)
		assert(time and NAT(time) and NAT(tie), "anchor is an entry ID")
		assert(from > 1, "anchor is present only when from > 1")
	end
	assert(header[12]:match("^[0-9a-f]+$") and #header[12] == 8, "body-crc is 8hexlc")
	assert(chars <= 100, "chars is at most the characters cap")

	local body = document:sub(headerEnd + 1)
	assert.are.equal(tonumber(header[11]), #body, "body-bytes")
	assert.are.equal(referenceCrc(body), header[12], "body-crc")
	assert(body == "" or body:sub(-1) == "\n", "nothing follows the last LF")

	local lines = {}
	for line in body:gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	assert.are.equal(chars + count, #lines, "chars + count lines follow the header")
	assert(from + count - 1 <= total, "from + count - 1 <= total")

	local characters, guids = {}, {}
	for i = 1, chars do
		local line = fields(lines[i])
		assert.are.equal(10, #line, "a character line has 10 fields")
		assert(line[1]:match(GUID), "guid")
		assert(guids[line[1]] == nil, "no two character lines share a GUID")
		guids[line[1]] = true
		assert(line[2] ~= "" and not line[2]:find("[%c|\127]"), "name is 1*field-byte")
		assert(not (line[3]:find("[%c|\127]")), "surname is field bytes")
		assert(NAT(line[4]) and NAT(line[5]), "classID and raceID")
		assert(line[6]:match("^%a+$"), "faction is 1*ALPHA")
		assert(NAT(line[7]), "realmID")
		assert(line[8] == "" or line[8] == "0" or line[8] == "1", "hardcore")
		assert(NAT(line[9]) and NAT(line[10]), "firstSeen and lastSeen")
		characters[i] = lines[i]
	end
	local entries = {}
	for j = 1, count do
		local line = lines[chars + j]
		local char, time, tie = line:match("^%w+|([^|]*)|([^|]*)|([^|]*)")
		assert(char and NAT1(char) and NAT(time) and NAT(tie), "an entry header is tag|nat1|nat|nat")
		assert(tonumber(char) <= chars, "an entry's char names a character line")
		entries[j] = line
	end
	return {
		logId = header[3],
		format = tonumber(header[4]),
		asOf = tonumber(header[5]),
		total = total,
		from = from,
		anchor = header[9],
		count = count,
		characters = characters,
		entries = entries,
	}
end

-- What upload.md's Paste string decodes to (UPL-R50): the prefix, the print body checked, then LibDeflate 1.0.2's
-- DecodeForPrint and DecompressDeflate.
local function unpaste(paste)
	assert.are.equal("!PGL1!", paste:sub(1, 6))
	local body = paste:sub(7)
	assert(body:match("^[a-zA-Z0-9()]*$"), "the print body holds the print alphabet only, no whitespace")
	assert.are_not.equal(1, #body % 4, "the print body's length isn't 4k + 1")
	local deflated = assert(LibDeflate:DecodeForPrint(body))
	return assert(LibDeflate:DecompressDeflate(deflated))
end

describe("ns.Crc32 (PST-R11)", function()
	it("gives upload.md's check value, cbf43926 for 123456789, and zlib's for other bytes", function()
		assert.are.equal("cbf43926", ns.Crc32("123456789"))
		assert.are.equal("00000000", ns.Crc32(""))
		assert.are.equal("e8b7be43", ns.Crc32("a"))
		assert.are.equal("414fa339", ns.Crc32("The quick brown fox jumps over the lazy dog"))
		local every = {}
		for b = 0, 255 do
			every[#every + 1] = string.char(b)
		end
		assert.are.equal("29058c73", ns.Crc32(table.concat(every)))
	end)

	it("agrees with a bit-by-bit CRC-32 at every length a 4-byte step leaves a rest of", function()
		local bytes = {}
		for n = 0, 40 do
			local text = table.concat(bytes)
			assert.are.equal(referenceCrc(text), ns.Crc32(text), "length " .. n)
			bytes[#bytes + 1] = string.char((n * 97 + 13) % 256)
		end
	end)
end)

describe("ns.PasteCharacterLine (PST-R12, PST-R13)", function()
	it("writes LOG-R26's fields in upload.md's order, as its example has Ada", function()
		assert.are.equal(
			"Player-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090",
			ns.PasteCharacterLine(character())
		)
	end)

	it("never writes selfFound, which LOG-R26 dropped, even from an older log that holds one", function()
		local line = assert(ns.PasteCharacterLine(character({ selfFound = true })))
		assert.are.equal(10, #fields(line))
		assert.are.equal(ns.PasteCharacterLine(character()), line)
	end)

	it("writes hardcore as 1 or 0, and empty when the log holds nil, and an empty surname for none", function()
		assert.are.equal("1", fields(ns.PasteCharacterLine(character({ hardcore = true })))[8])
		assert.are.equal("0", fields(ns.PasteCharacterLine(character({ hardcore = false })))[8])
		local line = ns.PasteCharacterLine(character({ hardcore = NONE, surname = NONE }))
		assert.are.equal("Player-4618-0A1B2C3D|Ada||1|1|Alliance|4618||1791731680|1791735090", line)
	end)

	it("leaves out LF, CR, control bytes, DEL and | from a name and a surname", function()
		local line = assert(ns.PasteCharacterLine(character({ name = "A\nd|a\r", surname = "Br\0o\127o\tk" })))
		assert.are.equal("Ada", fields(line)[2])
		assert.are.equal("Brook", fields(line)[3])
		assert.falsy(line:find("[\r\n]"))
	end)

	it("keeps whole UTF-8 sequences and leaves out bytes that aren't valid UTF-8", function()
		local zoe, hat, fish = "Zo\195\171", "\197\156", "\240\159\144\159"
		assert.are.equal(zoe, ns.PasteFieldText(zoe))
		assert.are.equal(hat .. fish, ns.PasteFieldText(hat .. fish))
		-- A lone continuation byte, an overlong "/", a surrogate, a byte past U+10FFFF and a cut-off sequence.
		assert.are.equal("ab", ns.PasteFieldText("a\128b"))
		assert.are.equal("ab", ns.PasteFieldText("a\192\175b"))
		assert.are.equal("ab", ns.PasteFieldText("a\237\160\128b"))
		assert.are.equal("ab", ns.PasteFieldText("a\245\128\128\128b"))
		assert.are.equal("ab", ns.PasteFieldText("ab\226\130"))
	end)

	it(
		"writes ? for a name left empty, 0 for a number the log lacks, and Unknown for a faction off the grammar",
		function()
			local line = assert(ns.PasteCharacterLine(character({
				name = "\n",
				surname = "|",
				classID = NONE,
				raceID = 1.5,
				faction = "Al liance",
				realmID = -1,
			})))
			assert.are.equal("Player-4618-0A1B2C3D|?||0|0|Unknown|0|0|1791731680|1791735090", line)
		end
	)

	it("can't write a character whose GUID isn't a player GUID (PST-R15)", function()
		assert.is_nil(ns.PasteCharacterLine(character({ guid = "Creature-0-1" })))
		assert.is_nil(ns.PasteCharacterLine(character({ guid = "Player-4618-0a1b2c3d" })))
		assert.is_nil(ns.PasteCharacterLine(character({ guid = NONE })))
	end)
end)

describe("ns.PasteExport (PST-R20–R22)", function()
	it(
		"cuts the entries from `from` into parts of at most the part size, each anchored at the entry before it",
		function()
			local entries = readings(7, 1791735000)
			local export = assert(ns.PasteExport(log(entries), 1, AS_OF, 3))

			assert.are.equal(7, export.total)
			assert.are.equal(AS_OF, export.asOf)
			assert.are.same({
				{ from = 1, count = 3, anchor = "" },
				{ from = 4, count = 3, anchor = ADA .. "-1791735003-0" },
				{ from = 7, count = 1, anchor = ADA .. "-1791735006-0" },
			}, export.parts)

			local since = assert(ns.PasteExport(log(entries), 5, AS_OF, 3))
			assert.are.same({ { from = 5, count = 3, anchor = ADA .. "-1791735004-0" } }, since.parts)
		end
	)

	it("cuts at 5,000 entries by default, the Paste part cap (PST-R22, PST-R23, UPL-R51)", function()
		assert.are.equal(5000, ns.PASTE_PART_ENTRIES)
		local export = assert(ns.PasteExport(log(readings(12345, 1791000000)), 1, AS_OF))

		assert.are.equal(3, #export.parts)
		assert.are.same({ 5000, 5000, 2345 }, {
			export.parts[1].count,
			export.parts[2].count,
			export.parts[3].count,
		})
		assert.are.equal(10001, export.parts[3].from)
	end)

	it("forms an anchor from the entry's own character, time and tie (LOG-R13)", function()
		local entries = { "S1|2|1791735001|3|1|150|0", "C1|1|1791735002|0|g|494|1439|1|148|453|86|25|263|||" }
		local export = assert(ns.PasteExport(log(entries, { character(), character({ guid = BEA }) }), 2, AS_OF))

		assert.are.equal(BEA .. "-1791735001-3", export.parts[1].anchor)
	end)

	it("makes one part with no entries for an empty log, and for an export from one past the end", function()
		assert.are.same({ { from = 1, count = 0, anchor = "" } }, assert(ns.PasteExport(log({}), 1, AS_OF)).parts)
		local entries = readings(2, 1791735000)
		assert.are.same(
			{ { from = 3, count = 0, anchor = ADA .. "-1791735002-0" } },
			assert(ns.PasteExport(log(entries), 3, AS_OF)).parts
		)
		assert.is_nil(ns.PasteExport(log(entries), 4, AS_OF))
	end)

	it(
		"can't export a log without a logId, past the characters cap, or with a GUID or anchor off the grammar (PST-R15)",
		function()
			local entries = readings(2, 1791735000)
			local noId = log(entries)
			noId.logId = nil
			assert.is_nil(ns.PasteExport(noId, 1, AS_OF))
			local upper = log(entries)
			upper.logId = "3F9A2C1E7B0D4A65"
			assert.is_nil(ns.PasteExport(upper, 1, AS_OF))

			local many = {}
			for i = 1, 101 do
				many[i] = character({ guid = ("Player-4618-%08X"):format(i) })
			end
			assert.is_nil(ns.PasteExport(log(entries, many), 1, AS_OF))
			table.remove(many)
			assert(type(ns.PasteExport(log(entries, many), 1, AS_OF)) == "table", "100 characters is the cap")

			assert.is_nil(ns.PasteExport(log(entries, { character({ guid = "Player-4618-xyz" }) }), 1, AS_OF))
			assert.is_nil(ns.PasteExport(log({ "S1|2|1791735001|0|1|150|0", "S1|1|1791735002|0|1|150|0" }), 2, AS_OF))
			assert.is_nil(ns.PasteExport(log({ "garbage", "S1|1|1791735002|0|1|150|0" }), 2, AS_OF))
		end
	)
end)

describe("ns.PasteDocument (PST-R10, PST-R11, PST-R14)", function()
	it("writes upload.md's example part byte for byte, with its body-bytes and body-crc", function()
		-- upload.md's example: entries 11 and 12 of a 12-entry log, after Ada's entry at 1791735000.
		local entries = readings(9, 1791734000)
		entries[10] = "S1|1|1791735000|0|86|150|25"
		entries[11] = "C1|1|1791735050|0|c|494|1439|1|148|453|86|25|263|||6358x1"
		entries[12] = "S1|1|1791735090|0|87|150|25"
		local export = assert(ns.PasteExport(log(entries), 11, AS_OF))

		assert.are.equal(
			"PGL|1|3f9a2c1e7b0d4a65|1|1791735100|12|1|11|Player-4618-0A1B2C3D-1791735000-0|2|159|d28fda68\n"
				.. "Player-4618-0A1B2C3D|Ada|Brook|1|1|Alliance|4618|0|1791731680|1791735090\n"
				.. "C1|1|1791735050|0|c|494|1439|1|148|453|86|25|263|||6358x1\n"
				.. "S1|1|1791735090|0|87|150|25\n",
			ns.PasteDocument(export, 1)
		)
	end)

	it("holds every character line, then the part's entries verbatim, each ending in one LF", function()
		local entries = readings(5, 1791735000)
		entries[3] = "A1|2|1791735003|0|Ledger|title|line\rwith CR|and bars"
		local characters = { character(), character({ guid = BEA, name = "Bea", surname = NONE, hardcore = NONE }) }
		local export = assert(ns.PasteExport(log(entries, characters), 1, AS_OF, 2))

		for n, part in ipairs(export.parts) do
			local parsed = parse(ns.PasteDocument(export, n))
			assert.are.equal(LOG_ID, parsed.logId)
			assert.are.equal(1, parsed.format)
			assert.are.equal(AS_OF, parsed.asOf)
			assert.are.equal(5, parsed.total)
			assert.are.equal(part.from, parsed.from)
			assert.are.equal(part.anchor, parsed.anchor)
			assert.are.same(
				{ ns.PasteCharacterLine(characters[1]), ns.PasteCharacterLine(characters[2]) },
				parsed.characters
			)
			for j, line in ipairs(parsed.entries) do
				assert.are.equal(entries[part.from + j - 1], line)
			end
		end
	end)

	it("writes an empty body, 0 and 00000000, for a part with no characters and no entries", function()
		local export = assert(ns.PasteExport(log({}, {}), 1, AS_OF))
		assert.are.equal("PGL|1|3f9a2c1e7b0d4a65|1|1791735100|0|0|1||0|0|00000000\n", ns.PasteDocument(export, 1))
	end)

	it("leaves out an LF a damaged entry holds, which LOG-R101 keeps out of the log, so it stays one line", function()
		local export = assert(ns.PasteExport(log({ "S1|1|1791735001|0|1|150|0\nS1|1|2|0|1|1|1" }), 1, AS_OF))
		local parsed = parse(ns.PasteDocument(export, 1))
		assert.are.same({ "S1|1|1791735001|0|1|150|0S1|1|2|0|1|1|1" }, parsed.entries)
	end)
end)

describe("ns.PasteString (PST-R30–R32)", function()
	it(
		"is !PGL1! and the print encoding of the raw DEFLATE of the document, which LibDeflate 1.0.2 reads back",
		function()
			local entries = readings(5, 1791735000)
			local export = assert(ns.PasteExport(log(entries), 1, AS_OF, 2))

			for n in ipairs(export.parts) do
				local document = ns.PasteDocument(export, n)
				local paste = ns.PasteString(document, LibDeflate)
				assert.are.equal(document, unpaste(paste))
				assert(not paste:find("%s"), "no whitespace anywhere")
			end
		end
	)

	it("round-trips a whole log through its parts: each part decodes and parses to its own slice of the log", function()
		local entries = readings(23, 1791730000)
		entries[7] = "A1|1|1791730007|0|Hunts|run|\195\169t\195\169 payload"
		local source = log(entries, { character({ name = "Zo\195\171" }) })
		local export = assert(ns.PasteExport(source, 1, AS_OF, 5))
		assert.are.equal(5, #export.parts)

		local rebuilt = {}
		for n in ipairs(export.parts) do
			local parsed = parse(unpaste(ns.PasteString(ns.PasteDocument(export, n), LibDeflate)))
			assert.are.equal(AS_OF, parsed.asOf, "every part shares the as-of")
			assert.are.equal(23, parsed.total, "and the total")
			assert.are.equal(#rebuilt + 1, parsed.from, "each part starts where the one before ended")
			if parsed.from > 1 then
				assert.are.equal(ADA .. "-" .. (1791730000 + parsed.from - 1) .. "-0", parsed.anchor)
			end
			for _, entry in ipairs(parsed.entries) do
				rebuilt[#rebuilt + 1] = entry
			end
		end
		assert.are.same(entries, rebuilt)
	end)

	it("compresses a full part of 5,000 entries well under the website's caps", function()
		local entries = {}
		for i = 1, 5000 do
			entries[i] = castEntry(1791000000 + i * 37, 6358 + i % 7, 453 + i % 3)
		end
		local export = assert(ns.PasteExport(log(entries), 1, AS_OF))
		local document = ns.PasteDocument(export, 1)
		local paste = ns.PasteString(document, LibDeflate)

		assert.are.equal(document, unpaste(paste))
		assert(#paste < 2796203, "the longest accepted Paste string body (UPL Tunables)")
		assert(#paste < #document, "smaller than the document it holds")
	end)
end)

describe("The Paste string test vector (paste-string.md › Contracts)", function()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	local vector = dofile("spec/Pagle/fixtures/PasteString.lua")

	it(
		"is what Core builds, byte for byte, for every part: the documents and the Paste strings pagle-backend decoded",
		function()
			local export = assert(ns.PasteExport(vector.log, 1, vector.asOf, vector.partSize))

			assert.are.equal(#vector.parts, #export.parts)
			for n, part in ipairs(vector.parts) do
				local document = ns.PasteDocument(export, n)
				assert.are.equal(part.document, document, "part " .. n .. "'s document")
				assert.are.equal(part.paste, ns.PasteString(document, LibDeflate), "part " .. n .. "'s Paste string")
				assert.are.equal(part.document, unpaste(part.paste))
				parse(part.document)
			end
		end
	)
end)

describe("The last exported seq (PST-R21, PST-R40)", function()
	it("starts New since last export at 1 with no mark, and one after the mark otherwise", function()
		assert.are.equal(1, ns.PasteNewFrom({}, LOG_ID))
		assert.are.equal(1, ns.PasteNewFrom(nil, LOG_ID))
		assert.are.equal(1, ns.PasteNewFrom({ [LOG_ID] = "12" }, LOG_ID), "a mark that isn't a number is none")
		assert.are.equal(13, ns.PasteNewFrom({ [LOG_ID] = 12 }, LOG_ID))
		assert.are.equal(1, ns.PasteNewFrom({ ["0123456789abcdef"] = 12 }, LOG_ID))
	end)

	it(
		"rises to a copied part's last seq, never falls, ignores a part with no entries and keeps other logs' marks",
		function()
			local marks = { ["0123456789abcdef"] = 40 }

			ns.MarkPasteCopied(marks, LOG_ID, { from = 1, count = 5000, anchor = "" })
			assert.are.equal(5000, marks[LOG_ID])
			ns.MarkPasteCopied(marks, LOG_ID, { from = 1, count = 3, anchor = "" })
			assert.are.equal(5000, marks[LOG_ID], "a part copied again doesn't lower it")
			ns.MarkPasteCopied(marks, LOG_ID, { from = 5001, count = 0, anchor = "x" })
			assert.are.equal(5000, marks[LOG_ID])
			ns.MarkPasteCopied(marks, LOG_ID, { from = 5001, count = 12, anchor = "x" })
			assert.are.equal(5012, marks[LOG_ID])
			assert.are.equal(40, marks["0123456789abcdef"])
		end
	)
end)

describe("ns.PasteTestString (PST-R60)", function()
	it("is exactly that many KB of 16-character runs, each naming its own offset, in the print alphabet", function()
		for _, kb in ipairs({ 1, 64, 512 }) do
			local test = assert(ns.PasteTestString(kb))
			assert.are.equal(kb * 1024, #test)
			assert.truthy(test:match("^[a-zA-Z0-9()]+$"))
			assert.are.equal("(00000000PGLtest", test:sub(1, 16))
			assert.are.equal(("(%08dPGLtest"):format(kb * 1024 - 16), test:sub(-16))
		end
	end)

	it("takes 1 to 2,048 KB only", function()
		assert.are.equal(2048 * 1024, #assert(ns.PasteTestString(2048)))
		for _, kb in ipairs({ 0, 2049, 1.5, -1 }) do
			assert.is_nil(ns.PasteTestString(kb))
		end
		assert.is_nil(ns.PasteTestString("64"))
	end)
end)
