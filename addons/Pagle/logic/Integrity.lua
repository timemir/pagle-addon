---@class PagleNS
local ns = select(2, ...)

local MAX = 9007199254740991

local function number(text, minimum, signed)
	if type(text) ~= "string" then
		return nil
	end
	if text ~= "0" and not text:find(signed and "^%-?[1-9]%d*$" or "^[1-9]%d*$") then
		return nil
	end
	local value = tonumber(text)
	if not value or math.abs(value) > MAX or value < minimum then
		return nil
	end
	return value
end

local function fields(text, separator)
	local out, from = {}, 1
	while true do
		local at = text:find(separator, from, true)
		if not at then
			out[#out + 1] = text:sub(from)
			return out
		end
		out[#out + 1] = text:sub(from, at - 1)
		from = at + #separator
	end
end

local function optional(text, signed)
	return text == "" or number(text, signed and -MAX or 0, signed) ~= nil
end

local function ids(text)
	if text == "" then
		return true
	end
	local previous = -1
	for _, field in ipairs(fields(text, ",")) do
		local value = number(field, 0)
		if not value or value <= previous then
			return false
		end
		previous = value
	end
	return true
end

local function items(text)
	if text == "" then
		return true
	end
	for _, item in ipairs(fields(text, ",")) do
		local id, quantity = item:match("^([^x]+)x([^x]+)$")
		if not number(id, 0) or not number(quantity, 1) then
			return false
		end
	end
	return true
end

local function entryId(text)
	local guid, time, tie = text:match("^(Player%-%d+%-[0-9A-F]+)%-([^%-]+)%-([^%-]+)$")
	return guid ~= nil and number(time, 0) ~= nil and number(tie, 0) ~= nil
end

local function varietyTarget(text)
	local zone, list = text:match("^([^:]+):([^:]+)$")
	if not number(zone, 1) then
		return false
	end
	local previous = 0
	for _, item in ipairs(fields(list, ",")) do
		local value = number(item, 1)
		if not value or value <= previous then
			return false
		end
		previous = value
	end
	return true
end

local function boardPayload(kind, payload)
	local f = fields(payload, ";")
	if kind == "start" or kind == "day" then
		return #f == 2 and number(f[1], 0) ~= nil and number(f[2], 0) ~= nil
	end
	local at = (kind == "issue" or kind == "post") and 1 or kind == "reroll" and 2 or nil
	if not at or #f ~= at + 5 or (at == 2 and not entryId(f[1])) then
		return false
	end
	local goalType, goal, target = f[at], f[at + 1], f[at + 5]
	local tier = number(f[at + 2], 0)
	if
		(goalType ~= "n" and goalType ~= "e")
		or not tier
		or tier > 3
		or not number(f[at + 3], 0)
		or not number(f[at + 4], 1)
	then
		return false
	end
	if goal == "haul" or goal == "quality" or goal == "rarity" then
		return number(target, 1) ~= nil
	elseif goal == "species" then
		return goalType == "n" and number(target, 1) ~= nil
	elseif goal == "lure" then
		return goalType == "n" and target == ""
	elseif goal == "collector" then
		return target == ""
	elseif goal == "wanderer" then
		return (goalType == "n" and target == "") or (goalType == "e" and number(target, 0) ~= nil)
	elseif goal == "variety" then
		return (goalType == "n" and number(target, 1) ~= nil) or (goalType == "e" and varietyTarget(target))
	end
	return false
end

local function huntPayload(kind, payload)
	local f = fields(payload, "|")
	if kind == "run" then
		return #f == 4
			and f[1]:find("^[%w_]+$") ~= nil
			and number(f[2], 0) ~= nil
			and number(f[3], 0) ~= nil
			and (f[4] == "r" or f[4] == "p")
	elseif kind == "def" and #f >= 3 and f[1]:find("^p_[%w_]+$") then
		local part, total = f[2]:match("^([^/]+)/([^/]+)$")
		local n, count = number(part, 1), number(total, 1)
		return n ~= nil and count ~= nil and n <= count and table.concat(f, "|", 3) ~= ""
	end
	return false
end

local function modulePayload(module, kind, payload)
	if module == "Ledger" then
		if kind == "title" then
			return payload == "" or payload:find("^[%w_.:]+$") ~= nil
		elseif kind == "crest" then
			return payload == "" or payload:find("^[%w_.]+$") ~= nil
		end
	elseif module == "TackleBoard" then
		return boardPayload(kind, payload)
	elseif module == "Hunts" then
		return huntPayload(kind, payload)
	end
	return false
end

--- Checks a record's envelope and payload against the canonical grammar, the backend's own. Core holds the payload
--- grammar of every shipped Module's record kinds too: Recovery checks a replacement before any Module loads, and the
--- backend refuses a kind it doesn't know, so a new kind is added here and there together (ADR 0008). Also returns the
--- entry's fields, split at every `|`, for a reader that goes on to decode it.
---@param entry any
---@return string? problem
---@return string[]? fields
function ns.CanonicalRecordProblem(entry)
	if type(entry) ~= "string" or entry:find("\n", 1, true) then
		return "record must be one line without LF"
	end
	local f = fields(entry, "|")
	if #f < 4 or not number(f[2], 1) or not number(f[3], 0) or not number(f[4], 0) then
		return "invalid canonical record header"
	end
	local tag, valid = f[1], false
	if tag == "C1" and #f == 16 then
		valid = (f[5] == "c" or f[5] == "g")
			and optional(f[6])
			and (f[6] == "" or tonumber(f[6]) < 1440)
			and optional(f[7])
			and optional(f[8])
			and number(f[9], 0) ~= nil
			and number(f[10], 0) ~= nil
			and optional(f[11])
			and optional(f[12], true)
			and optional(f[13])
			and ids(f[14])
			and ids(f[15])
			and items(f[16])
			and (f[5] ~= "g" or f[16] == "")
	elseif tag == "S1" and #f == 7 then
		valid = number(f[5], 0) ~= nil and number(f[6], 0) ~= nil and number(f[7], -MAX, true) ~= nil
	elseif tag == "P1" and #f == 6 then
		valid = number(f[5], 1) ~= nil and number(f[6], 0) ~= nil
	elseif tag == "B1" and #f == 7 then
		valid = number(f[5], 0) ~= nil and f[6] ~= "" and #f[7] <= 64 and f[7]:find("^[%w][%w_.%-]*$") ~= nil
	elseif tag == "U1" and #f == 6 then
		valid = f[5]:find("^[%w_.]+$") ~= nil and number(f[6], 0) ~= nil
	elseif tag == "K1" and #f == 6 then
		valid = f[5]:find("^[%w_.%-]+$") ~= nil and number(f[6], 0) ~= nil
	elseif tag == "A1" and #f >= 7 then
		local payload = table.concat(f, "|", 7)
		valid = f[5]:find("^[%w_.]+$") ~= nil
			and f[6]:find("^[%w_.]+$") ~= nil
			and #payload <= 200
			and modulePayload(f[5], f[6], payload)
	end
	if not valid then
		return "invalid or unsupported canonical record payload"
	end
	return nil, f
end

local function hex(bytes)
	return (bytes:gsub(".", function(byte)
		return ("%02x"):format(byte:byte())
	end))
end

local function natural(value, minimum)
	assert(
		type(value) == "number" and value >= minimum and value <= MAX and value == math.floor(value),
		"checkpoint integer out of range"
	)
	return ("%.0f"):format(value)
end

--- The initial checkpoint for a log, including a held empty log.
---@param logId string
---@param format integer
---@return string
function ns.CheckpointInitial(logId, format)
	assert(type(logId) == "string" and #logId == 16 and logId:find("^[0-9a-f]+$"), "invalid log ID")
	return hex(ns.Sha256("PGL-CHECKPOINT|1|" .. logId .. "|" .. natural(format, 1) .. "\n"))
end

--- Advances one exact entry. Hashing does not imply canonical or semantic acceptance of the record.
---@param previous string
---@param seq integer
---@param guid string
---@param entry string
---@return string
function ns.CheckpointNext(previous, seq, guid, entry)
	assert(type(previous) == "string" and #previous == 64 and previous:find("^[0-9a-f]+$"), "invalid digest")
	assert(type(guid) == "string" and guid:find("^Player%-%d+%-[0-9A-F]+$"), "invalid character GUID")
	assert(type(entry) == "string" and not entry:find("\n", 1, true), "invalid entry bytes")
	local frame = "PGL-ENTRY|1|"
		.. previous
		.. "|"
		.. natural(seq, 1)
		.. "|"
		.. #guid
		.. "|"
		.. guid
		.. "|"
		.. #entry
		.. "|"
		.. entry
		.. "\n"
	return hex(ns.Sha256(frame))
end
