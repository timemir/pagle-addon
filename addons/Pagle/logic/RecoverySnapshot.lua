---@class PagleNS
local ns = select(2, ...)

-- Recovery v1's full local snapshot, distinct from paged Upload documents. Unknown SavedVariables fields
-- stay outside these bytes and survive in the archived original branch.

local MAX = 9007199254740991
ns.RECOVERY_SNAPSHOT_CAP = 16 * 1024 * 1024
ns.RECOVERY_DATA_CAP = 24 * 1024 * 1024
local HEADER = "PGL-SNAPSHOT|1\n"
-- The Catch log format a snapshot and a Recovery plan name (LOG-R17): 1.0's, 4. The snapshot's records are the same
-- whatever the log's storage, so its bytes owe nothing to the blocks (LOG-R103).
local FORMAT = 4
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function natural(value)
	assert(type(value) == "number" and value >= 0 and value <= MAX and value % 1 == 0, "invalid snapshot integer")
	return ("%.0f"):format(value)
end

local function nullable(value)
	if value == nil then
		return "n"
	end
	assert(type(value) == "boolean", "invalid snapshot boolean")
	return value and "t" or "f"
end

local function text(value)
	assert(type(value) == "string", "missing snapshot string")
	local at = 1
	while at <= #value do
		local first = value:byte(at)
		local count, low, high = 0, 128, 191
		if first >= 194 and first <= 223 then
			count = 1
		elseif first >= 224 and first <= 239 then
			count = 2
			if first == 224 then
				low = 160
			elseif first == 237 then
				high = 159
			end
		elseif first >= 240 and first <= 244 then
			count = 3
			if first == 240 then
				low = 144
			elseif first == 244 then
				high = 143
			end
		else
			assert(first < 128, "invalid UTF-8 snapshot text")
		end
		for nextByte = 1, count do
			local byte = value:byte(at + nextByte)
			assert(byte and byte >= low and byte <= high, "invalid UTF-8 snapshot text")
			low, high = 128, 191
		end
		at = at + count + 1
	end
	return value
end

local function frame(value)
	return #value .. ":" .. value .. ","
end

---@param bytes string
---@return string
function ns.RecoveryHex(bytes)
	return (bytes:gsub(".", function(c)
		return ("%02x"):format(c:byte())
	end))
end

---@param bytes string
---@return string
function ns.RecoveryDigest(bytes)
	return ns.RecoveryHex(ns.Sha256(bytes))
end

---@param value string
---@return integer
function ns.RecoveryNatural(value)
	assert(
		type(value) == "string" and (value == "0" or value:find("^[1-9][0-9]*$")) and #value <= 16,
		"invalid Recovery number"
	)
	local number = assert(tonumber(value))
	assert(number <= MAX, "Recovery number out of range")
	return number --[[@as integer]]
end

---@param bytes string
---@param header string
---@return fun(): string
---@return fun()
function ns.RecoveryReader(bytes, header)
	assert(type(bytes) == "string" and #bytes <= ns.RECOVERY_DATA_CAP, "Recovery data too large")
	assert(bytes:sub(1, #header) == header, "invalid Recovery domain")
	local at = #header + 1
	local function read()
		local colon = bytes:find(":", at, true)
		assert(colon and colon - at <= 16, "missing Recovery field")
		local size = ns.RecoveryNatural(bytes:sub(at, colon - 1))
		local finish = colon + size
		assert(finish < #bytes and bytes:sub(finish + 1, finish + 1) == ",", "truncated Recovery field")
		local value = bytes:sub(colon + 1, finish)
		at = finish + 2
		return value
	end
	return read, function()
		assert(at == #bytes + 1, "trailing Recovery data")
	end
end

local function boolean(value)
	assert(value == "n" or value == "f" or value == "t", "invalid Recovery boolean")
	if value ~= "n" then
		return value == "t"
	end
end

local function dense(value, maximum)
	assert(type(value) == "table" and #value <= maximum, "invalid snapshot array")
	local count = 0
	for key in pairs(value) do
		assert(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= #value, "invalid snapshot array index")
		count = count + 1
	end
	assert(count == #value, "sparse snapshot array")
	return #value
end

---@param log table
---@return string
function ns.RecoverySnapshot(log)
	assert(type(log) == "table" and log.format == FORMAT, "Recovery requires Catch log format " .. FORMAT)
	assert(not ns.CatchLogProblem(log), "Recovery requires a readable Catch log")
	assert(
		type(log.logId) == "string" and #log.logId == 16 and log.logId:find("^[0-9a-f]+$"),
		"invalid snapshot log ID"
	)
	local out = { HEADER }
	local size = #HEADER
	local function add(value)
		local framed = frame(value)
		size = size + #framed
		assert(size <= ns.RECOVERY_SNAPSHOT_CAP, "snapshot too large")
		out[#out + 1] = framed
	end
	add(log.logId)
	add(tostring(FORMAT))
	add(nullable(log.test))
	add(natural(dense(log.characters, 100)))
	for _, c in ipairs(log.characters) do
		add(text(c.guid))
		add(text(c.name))
		add(c.surname == nil and "n" or "s" .. text(c.surname))
		add(natural(c.classID))
		add(natural(c.raceID))
		add(text(c.faction))
		add(natural(c.realmID))
		add(nullable(c.hardcore))
		add(natural(c.firstSeen))
		add(natural(c.lastSeen))
		add(nullable(c.selfFound))
	end
	assert(log.count <= 100000, "invalid snapshot array")
	add(natural(log.count))
	for _, entry in ns.LogBlocks.Iterate(log) do
		assert(type(entry) == "string", "missing snapshot entry")
		add(entry)
	end
	return table.concat(out)
end

---@param bytes string
---@return table
function ns.RecoveryReadSnapshot(bytes)
	assert(#bytes <= ns.RECOVERY_SNAPSHOT_CAP, "snapshot too large")
	local read, finish = ns.RecoveryReader(bytes, HEADER)
	local log = { logId = read(), format = ns.RecoveryNatural(read()), test = boolean(read()), characters = {} }
	local count = ns.RecoveryNatural(read())
	assert(count <= 100, "too many Recovery characters")
	for i = 1, count do
		local c = { guid = read(), name = read() }
		local surname = read()
		assert(surname == "n" or surname:sub(1, 1) == "s", "invalid nullable string")
		if surname ~= "n" then
			c.surname = surname:sub(2)
		end
		c.classID = ns.RecoveryNatural(read())
		c.raceID = ns.RecoveryNatural(read())
		c.faction = read()
		c.realmID = ns.RecoveryNatural(read())
		c.hardcore = boolean(read())
		c.firstSeen = ns.RecoveryNatural(read())
		c.lastSeen = ns.RecoveryNatural(read())
		c.selfFound = boolean(read())
		log.characters[i] = c
	end
	count = ns.RecoveryNatural(read())
	assert(count <= 100000, "too many Recovery entries")
	local entries = {}
	for i = 1, count do
		entries[i] = read()
	end
	finish()
	-- The restored log is written whole in blocks, the layout every log has (LOG-R103).
	log.blockSize = ns.LOG_BLOCK_SIZE
	log.blocks, log.count = ns.LogBlocks.Pack(entries, log.blockSize)
	assert(ns.RecoverySnapshot(log) == bytes, "noncanonical Recovery snapshot")
	return log
end

local function encode(bytes)
	local pieces, out = {}, {}
	for i = 1, #bytes, 3 do
		local a, b, c = bytes:byte(i, i + 2)
		local value = a * 65536 + (b or 0) * 256 + (c or 0)
		local w = math.floor(value / 262144) % 64
		local x = math.floor(value / 4096) % 64
		local y = math.floor(value / 64) % 64
		local z = value % 64
		out[#out + 1] = ALPHABET:sub(w + 1, w + 1)
			.. ALPHABET:sub(x + 1, x + 1)
			.. (b and ALPHABET:sub(y + 1, y + 1) or "=")
			.. (c and ALPHABET:sub(z + 1, z + 1) or "=")
		if #out == 2048 then
			pieces[#pieces + 1], out = table.concat(out), {}
		end
	end
	pieces[#pieces + 1] = table.concat(out)
	return table.concat(pieces)
end

---@param log table
---@return string
function ns.RecoveryExport(log)
	local bytes = encode(ns.RecoverySnapshot(log))
	local total = math.ceil(#bytes / 65536)
	local lines = {}
	for part = 1, total do
		lines[part] = "PGLR1|" .. part .. "|" .. total .. "|" .. bytes:sub((part - 1) * 65536 + 1, part * 65536)
	end
	return table.concat(lines, "\n")
end
