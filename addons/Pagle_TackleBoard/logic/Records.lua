if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's Module record payloads (TKB-R80, tackle-board.md › Data › Module records): pure logic (CORE-R7).
-- Fields are `;`-separated, numbers decimal, lists comma-separated and ascending:
--
--   start, day   dayStart;weekStart
--   issue        type;kind;tier;pay;need;target
--   reroll       oldGoalID;type;kind;tier;pay;need;target
--
-- A record kind it doesn't know, or a payload it can't parse or whose values are out of range, decodes to nil and is
-- skipped (TKB-R80). A changed shape gets a new kind (`issue2`), never an edit (ADR 0008).

--- A decoded Module record of the Tackle Board's.
---@class TackleRecord
---@field kind "start"|"day"|"issue"|"reroll"
---@field dayStart? integer           -- start, day
---@field weekStart? integer          -- start, day
---@field goal? TackleGoalDef         -- issue, reroll: the (new) goal's definition
---@field old? string                 -- reroll: the entry ID of the goal it takes down (TKB-R23)

-- How each kind's target is written (Data): "zone" an integer, "none" empty, "items" a Variety Expedition's
-- `zoneAreaID:itemID,…`. Every kind but `variety` writes the same for both types.
local TARGETS = {
	haul = "integer",
	variety = "integer", -- a Notice; an Expedition's is "items"
	wanderer = "none", -- a Notice; an Expedition's is its continent, an integer
	quality = "integer",
	size = "integer",
	collector = "none",
	lure = "none",
	species = "integer",
}

local TYPES = { n = true, e = true }

-- How a goal of `goalType` and `kind` writes its target: "integer", "none" or "items".
---@param goalType TackleGoalType
---@param kind TackleGoalKind
---@return string
local function targetForm(goalType, kind)
	if goalType == "e" and kind == "variety" then
		return "items"
	end
	if goalType == "e" and kind == "wanderer" then
		return "integer"
	end
	return TARGETS[kind]
end

-- `text` split at every `;`, empty fields kept: "a;;b;" is { "a", "", "b", "" }.
---@param text string
---@return string[]
local function fields(text)
	local out, from = {}, 1
	while true do
		local at = string.find(text, ";", from, true)
		if not at then
			out[#out + 1] = string.sub(text, from)
			return out
		end
		out[#out + 1] = string.sub(text, from, at - 1)
		from = at + 1
	end
end

-- A decimal integer ≥ 0, or nil.
---@param text string?
---@return integer?
local function integer(text)
	if text and string.find(text, "^%d+$") then
		return tonumber(text)
	end
	return nil
end

-- `list` ascending, as a new table.
---@param list integer[]
---@return integer[]
local function ascending(list)
	local out = {}
	for i, value in ipairs(list) do
		out[i] = value
	end
	table.sort(out)
	return out
end

-- A goal definition's `type;kind;tier;pay;need;target` (Data).
---@param def TackleGoalDef
---@return string
local function encodeGoal(def)
	local target = ""
	local form = targetForm(def.type, def.kind)
	if form == "items" then
		target = def.target .. ":" .. table.concat(ascending(def.items), ",")
	elseif form == "integer" then
		target = tostring(def.target)
	end
	return table.concat({ def.type, def.kind, def.tier, def.pay, def.need, target }, ";")
end

-- The goal definition in six fields starting at `parts[at]`, or nil when they can't be parsed or are out of range
-- (TKB-R80): an unknown type or kind, a tier outside 0–3, a need below 1, a target not in its kind's form.
---@param parts string[]
---@param at integer
---@return TackleGoalDef?
local function decodeGoal(parts, at)
	local goalType, kind = parts[at], parts[at + 1]
	local tier, pay, need = integer(parts[at + 2]), integer(parts[at + 3]), integer(parts[at + 4])
	local target = parts[at + 5]
	if not TYPES[goalType] or not TARGETS[kind] or not tier or not pay or not need or tier > 3 or need < 1 then
		return nil
	end
	---@type TackleGoalDef
	local def = { type = goalType, kind = kind, tier = tier, pay = pay, need = need }
	local form = targetForm(goalType, kind)
	if form == "none" then
		return target == "" and def or nil
	elseif form == "integer" then
		def.target = integer(target)
		return def.target and def or nil
	end
	local zone, list = string.match(target, "^(%d+):(.+)$")
	if not zone then
		return nil
	end
	local items = {}
	for _, item in ipairs(fields((string.gsub(list, ",", ";")))) do
		local itemID = integer(item)
		if not itemID then
			return nil
		end
		items[#items + 1] = itemID
	end
	def.target, def.items = tonumber(zone), ascending(items)
	return def
end

--- A `start` or `day` record's payload: the board day's and week's start (TKB-R10, TKB-R11).
---@param dayStart integer
---@param weekStart integer
---@return string
function ns.EncodeBoundary(dayStart, weekStart)
	return dayStart .. ";" .. weekStart
end

--- An `issue` record's payload: the goal's definition (TKB-R21).
---@param def TackleGoalDef
---@return string
function ns.EncodeIssue(def)
	return encodeGoal(def)
end

--- A `reroll` record's payload: the taken-down goal's ID, then the new goal's definition (TKB-R55).
---@param oldGoalID string the entry ID of the record that issued the old goal (TKB-R23)
---@param def TackleGoalDef
---@return string
function ns.EncodeReroll(oldGoalID, def)
	return oldGoalID .. ";" .. encodeGoal(def)
end

--- A Tackle Board Module record read back, or nil when it is to be skipped (TKB-R80): a kind it doesn't know, or a
--- payload it can't parse or whose values are out of range.
---@param recordKind string the record's kind (PagleModuleRecord.recordKind)
---@param payload string
---@return TackleRecord?
function ns.DecodeRecord(recordKind, payload)
	local parts = fields(payload)
	if recordKind == "start" or recordKind == "day" then
		local dayStart, weekStart = integer(parts[1]), integer(parts[2])
		if #parts ~= 2 or not dayStart or not weekStart then
			return nil
		end
		return { kind = recordKind, dayStart = dayStart, weekStart = weekStart }
	elseif recordKind == "issue" then
		local goal = #parts == 6 and decodeGoal(parts, 1) or nil
		return goal and { kind = "issue", goal = goal } or nil
	elseif recordKind == "reroll" then
		local goal = #parts == 7 and parts[1] ~= "" and decodeGoal(parts, 2) or nil
		return goal and { kind = "reroll", old = parts[1], goal = goal } or nil
	end
	return nil
end
