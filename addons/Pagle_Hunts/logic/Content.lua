if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Pushed Hunt Events (HNT-R140, HNT-R154, hunts.md › Contracts › Pushed Hunt Events and runs): Hunts' own strict
-- reader and writer of one item in the content grammar (core/pushed-content.md › The payload), and the checks it runs
-- in game on a `huntEvent` item. Pure logic (CORE-R7). Modules never call Core's internals (ADR 0001), so the text a
-- `def` record carries is read here, never by Core's parser. The projection reads logged definitions with it
-- (logic/Runs.lua); the step that logs pushed runs (#300) writes each `GetPushedContent("huntEvent")` item with
-- ns.WriteContentItem and checks it with ns.HuntEventProblem first.

--- The closed tag list of data/hunts/tags.toml (DATA-R97), by ID. The generator checks the pool's tags against the
--- file; a pushed definition's are checked against this copy, which spec/Pagle_Hunts/logic/Content_spec.lua keeps
--- equal to the file.
ns.EVENT_TAGS = {}
for _, tag in ipairs({
	"hallows_end",
	"winter_veil",
	"lunar_festival",
	"noblegarden",
	"midsummer",
	"harvest_festival",
	"stv_extravaganza",
	"night",
	"day",
	"dusk",
	"coast",
	"lake",
	"river",
	"pool",
	"low",
	"mid",
	"high",
}) do
	ns.EVENT_TAGS[tag] = true
end

-- The reader -------------------------------------------------------------------------------------------------------

-- A reader over `text`: its position, and the first problem it met.
---@class HuntsContentReader
---@field text string
---@field at integer

local NAME = "^[%a_][%w_]*"
local INTEGER = "^%-?%d+"

-- Skips the whitespace before the next token.
---@param reader HuntsContentReader
local function skip(reader)
	reader.at = reader.text:find("[^ \t\r\n]", reader.at) or #reader.text + 1
end

-- Takes `token` if it comes next.
---@param reader HuntsContentReader
---@param token string
---@return boolean
local function take(reader, token)
	skip(reader)
	if reader.text:sub(reader.at, reader.at + #token - 1) == token then
		reader.at = reader.at + #token
		return true
	end
	return false
end

-- Takes `token`, or raises the reader's error.
---@param reader HuntsContentReader
---@param token string
local function expect(reader, token)
	if not take(reader, token) then
		error({ problem = ("expected %s at byte %d"):format(token, reader.at) })
	end
end

-- The match of `pattern` at the next token, taken, or nil.
---@param reader HuntsContentReader
---@param pattern string
---@return string?
local function match(reader, pattern)
	skip(reader)
	local found = reader.text:match(pattern, reader.at)
	if found then
		reader.at = reader.at + #found
	end
	return found
end

-- A double-quoted string with only the \\, \" and \n escapes, and no raw newline.
---@param reader HuntsContentReader
---@return string
local function readString(reader)
	local parts, text = {}, reader.text
	local at = reader.at + 1
	while true do
		local stop = text:find('["\\\n]', at)
		if not stop or text:sub(stop, stop) == "\n" then
			error({ problem = ("an unterminated string at byte %d"):format(reader.at) })
		end
		parts[#parts + 1] = text:sub(at, stop - 1)
		if text:sub(stop, stop) == '"' then
			reader.at = stop + 1
			return table.concat(parts)
		end
		local escaped = text:sub(stop + 1, stop + 1)
		if escaped == "\\" or escaped == '"' then
			parts[#parts + 1] = escaped
		elseif escaped == "n" then
			parts[#parts + 1] = "\n"
		else
			error({ problem = ("an escape the grammar has no room for at byte %d"):format(stop) })
		end
		at = stop + 2
	end
end

local readValue

-- A table constructor after its "{": a list of values or of fields, each followed by ",", never both (the grammar's
-- `"{" *(value ",") "}"` and `"{" *(field ",") "}"`), with no field named twice.
---@param reader HuntsContentReader
---@return table
local function readTable(reader)
	local out, fields, n = {}, nil, 0
	while not take(reader, "}") do
		local mark = reader.at
		local name = match(reader, NAME)
		local isField = name ~= nil and take(reader, "=")
		if not isField then
			reader.at = mark
		end
		if fields == nil then
			fields = isField
		elseif fields ~= isField then
			error({ problem = ("a table mixing values and fields at byte %d"):format(mark) })
		end
		if isField then
			---@cast name string
			if out[name] ~= nil then
				error({ problem = ("the field %s twice"):format(name) })
			end
			out[name] = readValue(reader)
		else
			n = n + 1
			out[n] = readValue(reader)
		end
		expect(reader, ",")
	end
	return out
end

-- One value: a string, an integer, a boolean or a table (the grammar's `value`).
---@param reader HuntsContentReader
---@return any
function readValue(reader)
	skip(reader)
	local first = reader.text:sub(reader.at, reader.at)
	if first == '"' then
		return readString(reader)
	elseif first == "{" then
		reader.at = reader.at + 1
		return readTable(reader)
	end
	local integer = match(reader, INTEGER)
	if integer then
		local value = tonumber(integer) --[[@as number]]
		if math.abs(value) >= 2 ^ 53 or reader.text:find("^[%w_.]", reader.at) then
			error({ problem = ("not an integer at byte %d"):format(reader.at) })
		end
		return value
	end
	local word = match(reader, NAME)
	if word == "true" or word == "false" then
		return word == "true"
	end
	error({ problem = ("a value the grammar has no room for at byte %d"):format(reader.at) })
end

--- One item of the content grammar read from `text` (core/pushed-content.md › The payload): `{ kind = <str>, v =
--- <int>, <field>, … }`, each field followed by ",", whitespace allowed between tokens and nothing after. Strings,
--- integers, booleans and tables only, never `loadstring`. Returns the item, or nil and why it isn't one.
---@param text string
---@return table? item
---@return string? problem
function ns.ReadContentItem(text)
	if type(text) ~= "string" then
		return nil, "not text"
	end
	local reader = { text = text, at = 1 }
	local ok, result = pcall(function()
		expect(reader, "{")
		expect(reader, "kind")
		expect(reader, "=")
		skip(reader)
		if reader.text:sub(reader.at, reader.at) ~= '"' then
			error({ problem = "an item's kind is a string" })
		end
		local kind = readString(reader)
		expect(reader, ",")
		expect(reader, "v")
		expect(reader, "=")
		local v = match(reader, INTEGER)
		if not v then
			error({ problem = "an item's v is an integer" })
		end
		expect(reader, ",")
		local item = readTable(reader)
		if item.kind ~= nil or item.v ~= nil or (item[1] ~= nil) then
			error({ problem = "an item names kind or v twice, or lists values" })
		end
		item.kind, item.v = kind, tonumber(v)
		skip(reader)
		if reader.at <= #reader.text then
			error({ problem = ("text after the item at byte %d"):format(reader.at) })
		end
		return item
	end)
	if ok then
		return result
	end
	if type(result) == "table" then
		return nil, result.problem
	end
	error(result, 0)
end

-- The writer -------------------------------------------------------------------------------------------------------

-- The keys of a table, as a list if it is one (keys exactly 1 to n), else its field names in byte order; nil for a
-- table the grammar can't write (mixed keys, or a key that isn't a name).
---@param value table
---@return any[]? keys
---@return boolean isList
local function keysOf(value)
	local n, names = #value, {}
	local count = 0
	for key in pairs(value) do
		count = count + 1
		if type(key) == "string" then
			if not key:find("^[%a_][%w_]*$") then
				return nil, false
			end
			names[#names + 1] = key
		elseif type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > n then
			return nil, false
		end
	end
	if #names == 0 then
		return nil, count == n
	end
	if #names ~= count then
		return nil, false
	end
	table.sort(names)
	return names, false
end

local writeValue

-- Writes `value` onto `out`.
---@param out string[]
---@param value any
function writeValue(out, value)
	local kind = type(value)
	if kind == "string" then
		out[#out + 1] = '"' .. value:gsub('[\\"\n]', { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n" }) .. '"'
	elseif kind == "number" then
		if value % 1 ~= 0 or math.abs(value) >= 2 ^ 53 then
			error({ problem = "a number that isn't an integer" })
		end
		out[#out + 1] = ("%d"):format(value)
	elseif kind == "boolean" then
		out[#out + 1] = tostring(value)
	elseif kind == "table" then
		local names, isList = keysOf(value)
		out[#out + 1] = "{"
		if names then
			for _, name in ipairs(names) do
				out[#out + 1] = name .. "="
				writeValue(out, value[name])
				out[#out + 1] = ","
			end
		elseif isList then
			for _, entry in ipairs(value) do
				writeValue(out, entry)
				out[#out + 1] = ","
			end
		else
			error({ problem = "a table that is neither a list nor fields" })
		end
		out[#out + 1] = "}"
	else
		error({ problem = "a " .. kind .. " the grammar has no room for" })
	end
end

--- `item` written in the content grammar, on one line with no whitespace, so ns.ReadContentItem reads it back the same
--- and a `def` record can carry it (HNT-R154, LOG-R40): `kind` and `v` first, then the other fields, and the fields
--- of each table, in byte order of their names. Returns the text, or nil and why the grammar can't hold the item.
---@param item table
---@return string? text
---@return string? problem
function ns.WriteContentItem(item)
	if type(item) ~= "table" or type(item.kind) ~= "string" or type(item.v) ~= "number" then
		return nil, "an item has a string kind and an integer v"
	end
	local ok, result = pcall(function()
		local out = { "{kind=" }
		writeValue(out, item.kind)
		out[#out + 1] = ",v="
		writeValue(out, item.v)
		out[#out + 1] = ","
		local rest = {}
		for key, value in pairs(item) do
			if key ~= "kind" and key ~= "v" then
				rest[key] = value
			end
		end
		local body = {}
		writeValue(body, rest)
		-- The fields without their table's braces: the item's own braces hold them.
		for i = 2, #body - 1 do
			out[#out + 1] = body[i]
		end
		out[#out + 1] = "}"
		return table.concat(out)
	end)
	if ok then
		return result
	end
	if type(result) == "table" then
		return nil, result.problem
	end
	error(result, 0)
end

-- The checks -------------------------------------------------------------------------------------------------------

--- What the checks read besides the item: the Hunt list's classes (`Class`) and Core's catalogue (`GetItem`,
--- `GetArea`), as HuntsLookups carry them (logic/Qualify.lua).
---@class HuntsEventChecks
---@field Class fun(classID: string): table<integer, true>?
---@field GetItem fun(itemID: integer): PagleItem?
---@field GetArea fun(areaID: integer): PagleArea?

local EVENT_FIELDS = {
	kind = true,
	v = true,
	id = true,
	zones = true,
	tags = true,
	skill = true,
	rotation = true,
	name = true,
	note = true,
	hunts = true,
}
local HUNT_FIELDS =
	{ id = true, name = true, species = true, class = true, minBand = true, conditions = true, tiers = true }

-- Whether `value` is a whole number from `lo` to `hi` (either bound may be nil).
---@param value any
---@param lo number?
---@param hi number?
---@return boolean
local function whole(value, lo, hi)
	return type(value) == "number" and value % 1 == 0 and (lo == nil or value >= lo) and (hi == nil or value <= hi)
end

-- Whether `value` is a list (keys 1 to n only) of `lo` to `hi` entries, each passing `each`.
---@param value any
---@param lo integer
---@param hi integer?
---@param each fun(entry: any): boolean
---@return boolean
local function listOf(value, lo, hi, each)
	if type(value) ~= "table" then
		return false
	end
	local n = 0
	for key in pairs(value) do
		n = n + 1
		if not whole(key, 1, nil) then
			return false
		end
	end
	if n ~= #value or n < lo or (hi and n > hi) then
		return false
	end
	for _, entry in ipairs(value) do
		if not each(entry) then
			return false
		end
	end
	return true
end

-- Whether `value` is a table with only the fields `allowed` names.
---@param value any
---@param allowed table<string, true>
---@return boolean
local function fieldsOnly(value, allowed)
	if type(value) ~= "table" then
		return false
	end
	for key in pairs(value) do
		if not allowed[key] then
			return false
		end
	end
	return true
end

local function positive(entry)
	return whole(entry, 1, nil)
end

local function skillValue(entry)
	return whole(entry, 0, nil)
end

local function knownTag(entry)
	return ns.EVENT_TAGS[entry] == true
end

local function isTable(entry)
	return type(entry) == "table"
end

local function minuteRange(entry)
	return listOf(entry, 2, 2, function(minute)
		return whole(minute, 0, 1439)
	end) and entry[1] ~= entry[2]
end

local function monthDay(entry)
	return listOf(entry, 2, 2, function()
		return true
	end) and whole(entry[1], 1, 12) and whole(entry[2], 1, 31)
end

local function seasonRange(entry)
	return fieldsOnly(entry, { from = true, to = true }) and monthDay(entry.from) and monthDay(entry.to)
end

-- Each LOG-R48 field an event Hunt's own conditions may hold, and its shape; `areas` isn't one (HNT-R141).
local CONDITION_SHAPES = {
	time = function(value)
		return listOf(value, 1, nil, minuteRange)
	end,
	season = function(value)
		return listOf(value, 1, nil, seasonRange)
	end,
	events = function(value)
		return listOf(value, 1, nil, positive)
	end,
	auras = function(value)
		return listOf(value, 1, nil, positive)
	end,
	lure = function(value)
		return value == true or listOf(value, 1, nil, positive)
	end,
	skill = function(value)
		return fieldsOnly(value, { min = true }) and whole(value.min, 0, nil)
	end,
}

-- Why an event Hunt's own conditions fail LOG-R48 (HNT-R141), or nil.
---@param conditions any
---@return string?
local function conditionsProblem(conditions)
	if type(conditions) ~= "table" then
		return "its conditions aren't a table"
	end
	for field, value in pairs(conditions) do
		if field == "areas" then
			return "its conditions name areas: the event's zones supply them (HNT-R141)"
		end
		local shape = CONDITION_SHAPES[field]
		if not shape then
			return ("its conditions have a field LOG-R48 doesn't: %s"):format(tostring(field))
		elseif not shape(value) then
			return ("its conditions' %s isn't LOG-R48's shape"):format(field)
		end
	end
	return nil
end

-- Why one Hunt of a pushed event fails the checks (DATA-R99's that run in game), or nil.
---@param hunt any
---@param checks HuntsEventChecks
---@return string?
local function huntProblem(hunt, checks)
	if not fieldsOnly(hunt, HUNT_FIELDS) then
		return "it isn't a table of a Hunt's fields only"
	end
	if type(hunt.id) ~= "string" or not hunt.id:find("^[%w_]+$") then
		return "its id isn't [%w_]+"
	end
	if hunt.name ~= nil and type(hunt.name) ~= "string" then
		return "its name isn't text"
	end
	if (hunt.species == nil) == (hunt.class == nil) then
		return "it has neither or both of species and class"
	end
	if hunt.species ~= nil then
		local item = whole(hunt.species, 1, nil) and checks.GetItem(hunt.species)
		if not item or item.species ~= hunt.species then
			return ("its species %s isn't a Species of the catalogue"):format(tostring(hunt.species))
		end
	elseif type(hunt.class) ~= "string" or not checks.Class(hunt.class) then
		return ("its class %s isn't one of the Hunt list's"):format(tostring(hunt.class))
	end
	if hunt.minBand ~= nil and not whole(hunt.minBand, 2, 4) then
		return "its minBand isn't 2 to 4"
	end
	if hunt.conditions ~= nil then
		local problem = conditionsProblem(hunt.conditions)
		if problem then
			return problem
		end
	end
	if not listOf(hunt.tiers, 1, nil, positive) then
		return "its tiers aren't a list of counts"
	end
	for k = 2, #hunt.tiers do
		if hunt.tiers[k] <= hunt.tiers[k - 1] then
			return "its tiers aren't ascending"
		end
	end
	return nil
end

--- Why a `huntEvent` item fails the checks Hunts can run in game (hunts.md › Contracts, DATA-R99), or nil when it
--- passes: kind `huntEvent` at version 1 with only its fields; an ID `[%w_]+` starting `p_`; 1–2 zones, each a zone
--- of the catalogue; known tags (data/hunts/tags.toml); a skill range; `rotation`, `name` and `note` of their types;
--- and 3–5 Hunts, each with a unique `[%w_]+` ID, a Species of the catalogue or a class of the Hunt list, `minBand`
--- 2–4, LOG-R48 conditions without `areas` (HNT-R141) and ascending tiers. One that fails is ignored (HNT-R140).
---@param item any
---@param checks HuntsEventChecks
---@return string?
function ns.HuntEventProblem(item, checks)
	if type(item) ~= "table" or item.kind ~= "huntEvent" or item.v ~= 1 then
		return "it isn't a huntEvent item of version 1"
	end
	for key in pairs(item) do
		if not EVENT_FIELDS[key] then
			return ("it has a field a huntEvent doesn't: %s"):format(tostring(key))
		end
	end
	if type(item.id) ~= "string" or not item.id:find("^p_[%w_]+$") then
		return "its id isn't [%w_]+ starting p_"
	end
	-- A zone of the catalogue: an area whose parent is 0 (LOG-R55).
	local function isZone(zone)
		local area = whole(zone, 1, nil) and checks.GetArea(zone)
		return area ~= nil and area ~= false and area.parent == 0
	end
	if not listOf(item.zones, 1, 2, isZone) or item.zones[1] == item.zones[2] then
		return "its zones aren't 1 or 2 zones of the catalogue"
	end
	if not listOf(item.tags, 0, nil, knownTag) then
		return "its tags aren't from data/hunts/tags.toml"
	end
	local skill = item.skill
	if not listOf(skill, 2, 2, skillValue) or skill[1] > skill[2] then
		return "its skill isn't a range { low, high }"
	end
	if item.rotation ~= nil and type(item.rotation) ~= "boolean" then
		return "its rotation isn't a boolean"
	end
	if (item.name ~= nil and type(item.name) ~= "string") or (item.note ~= nil and type(item.note) ~= "string") then
		return "its name or note isn't text"
	end
	if not listOf(item.hunts, 3, 5, isTable) then
		return "it hasn't 3 to 5 Hunts"
	end
	local ids = {}
	for i, hunt in ipairs(item.hunts) do
		local problem = huntProblem(hunt, checks)
		if problem then
			return ("its Hunt %d: %s"):format(i, problem)
		end
		if ids[hunt.id] then
			return ("its Hunt %s twice"):format(hunt.id)
		end
		ids[hunt.id] = true
	end
	return nil
end
