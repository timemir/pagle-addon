---@class PagleNS
local ns = select(2, ...)

-- The pushed payload's reader (PUSH-R20, PUSH-R21; pushed-content.md › The payload): a strict recursive-descent
-- parser for the Lua-data-only text the backend writes, in plain Lua and never by running it, so nothing in a payload
-- is ever code. It takes tables, double-quoted strings with only \\, \" and \n escapes, decimal integers, true and
-- false, and names [%a_][%w_]*; anything else is a parse error at its byte. Two forms beyond the grammar's letter are
-- read, both still plain Lua data: a field name written ["name"] (hunts.md writes huntRun's `["end"]` so, `end` being
-- a Lua keyword), and a table's last element without its comma.
--
-- It returns its errors rather than raising them: the pushed-content check runs it in a coroutine that yields from
-- `pause`, and Lua 5.1 can't yield through pcall.

local byte, find, sub, concat = string.byte, string.find, string.sub, table.concat

--- How deep tables may nest, the payload's own table counting as 1 (PUSH-R20): a huntEvent's time window is at 8.
ns.PAYLOAD_DEPTH_LIMIT = 16

--- The kinds and versions Core passes on (PUSH-R21, Tunables); an item of any other is dropped quietly.
ns.PUSHED_KINDS = { huntEvent = 1, huntRun = 1 }

-- Values read between two calls of `pause`: a few hundred microseconds of parsing.
local PAUSE_EVERY = 200

-- The largest integer a payload holds: 15 digits, exact in a double.
local DIGITS = 15

local OPEN, CLOSE, EQUALS, COMMA, QUOTE, BACKSLASH = 123, 125, 61, 44, 34, 92
local BRACKET, CLOSE_BRACKET, MINUS, N = 91, 93, 45, 110

--- A parse in progress.
---@class PaglePayloadParser
---@field text string
---@field at integer the next byte to read
---@field count integer values read since the last pause
---@field pause fun()?
---@field failAt integer? where it failed
---@field failKey string? why: an ns.L key (PAYLOAD_*)
---@field failArg any? what that line names

-- Notes the failure and returns false, for the caller to return at once.
---@param p PaglePayloadParser
---@param at integer
---@param key string
---@param arg any
---@return false
local function fail(p, at, key, arg)
	p.failAt, p.failKey, p.failArg = at, key, arg
	return false
end

-- Skips whitespace: spaces, tabs and line ends.
---@param p PaglePayloadParser
local function skip(p)
	local _, last = find(p.text, "^[ \t\r\n]*", p.at)
	p.at = last + 1
end

-- Counts one value read, pausing every PAUSE_EVERY.
---@param p PaglePayloadParser
local function tick(p)
	p.count = p.count + 1
	if p.count >= PAUSE_EVERY then
		p.count = 0
		if p.pause then
			p.pause()
		end
	end
end

-- A double-quoted string at p.at: true and its text, or false.
---@param p PaglePayloadParser
---@return boolean ok
---@return string? text
local function parseString(p)
	local text, start = p.text, p.at
	local at, pieces = start + 1, {}
	while true do
		local stop = find(text, '["\\\n\r]', at)
		if not stop then
			return fail(p, start, "PAYLOAD_UNENDED_STRING")
		end
		if stop > at then
			pieces[#pieces + 1] = sub(text, at, stop - 1)
		end
		local c = byte(text, stop)
		if c == QUOTE then
			p.at = stop + 1
			return true, concat(pieces)
		elseif c ~= BACKSLASH then
			return fail(p, stop, "PAYLOAD_LINE_IN_STRING")
		end
		local escaped = byte(text, stop + 1)
		if escaped == BACKSLASH then
			pieces[#pieces + 1] = "\\"
		elseif escaped == QUOTE then
			pieces[#pieces + 1] = '"'
		elseif escaped == N then
			pieces[#pieces + 1] = "\n"
		else
			return fail(p, stop, "PAYLOAD_BAD_ESCAPE")
		end
		at = stop + 2
		tick(p)
	end
end

-- A decimal integer at p.at: true and its value, or false.
---@param p PaglePayloadParser
---@return boolean ok
---@return integer? value
local function parseInteger(p)
	local text, at = p.text, p.at
	local first, last = find(text, "^%-?%d+", at)
	if not first then
		return fail(p, at, "PAYLOAD_UNEXPECTED", sub(text, at, at))
	end
	if find(text, "^[%w_.]", last + 1) then
		return fail(p, at, "PAYLOAD_NOT_INTEGER")
	end
	if last - first + 1 - (byte(text, first) == MINUS and 1 or 0) > DIGITS then
		return fail(p, at, "PAYLOAD_TOO_LARGE", DIGITS)
	end
	p.at = last + 1
	return true, tonumber(sub(text, first, last))
end

-- Whether a field starts at p.at: a name followed by "=" (not "=="), or "[".
---@param p PaglePayloadParser
---@return boolean
local function fieldAhead(p)
	local text, at = p.text, p.at
	if byte(text, at) == BRACKET then
		return true
	end
	local _, last = find(text, "^[%a_][%w_]*[ \t\r\n]*=", at)
	return last ~= nil and byte(text, last + 1) ~= EQUALS
end

-- A field's name at p.at, bare or as ["name"]: true and the name, or false.
---@param p PaglePayloadParser
---@return boolean ok
---@return string? name
local function parseKey(p)
	local text, at = p.text, p.at
	local first, last = find(text, "^[%a_][%w_]*", at)
	if first then
		p.at = last + 1
		return true, sub(text, first, last)
	elseif byte(text, at) ~= BRACKET then
		return fail(p, at, "PAYLOAD_EXPECTED_FIELD")
	end
	p.at = at + 1
	skip(p)
	if byte(text, p.at) ~= QUOTE then
		return fail(p, p.at, "PAYLOAD_EXPECTED", '"')
	end
	local ok, name = parseString(p)
	if not ok then
		return false
	end
	---@cast name string
	if not find(name, "^[%a_][%w_]*$") then
		return fail(p, at, "PAYLOAD_BAD_NAME")
	end
	skip(p)
	if byte(text, p.at) ~= CLOSE_BRACKET then
		return fail(p, p.at, "PAYLOAD_EXPECTED", "]")
	end
	p.at = p.at + 1
	return true, name
end

local parseTable

-- A value at p.at, in a table at `depth`: true and the value, or false.
---@param p PaglePayloadParser
---@param depth integer
---@return boolean ok
---@return any value
local function parseValue(p, depth)
	tick(p)
	local text, at = p.text, p.at
	local c = byte(text, at)
	if c == OPEN then
		return parseTable(p, depth + 1)
	elseif c == QUOTE then
		return parseString(p)
	elseif c == MINUS or (c and c >= 48 and c <= 57) then
		return parseInteger(p)
	elseif not c then
		return fail(p, at, "PAYLOAD_ENDED")
	end
	local first, last = find(text, "^[%a_][%w_]*", at)
	if not first then
		return fail(p, at, "PAYLOAD_UNEXPECTED", sub(text, at, at))
	end
	local name = sub(text, first, last)
	if name == "true" or name == "false" then
		p.at = last + 1
		return true, name == "true"
	end
	return fail(p, at, "PAYLOAD_NAME_AS_VALUE", name)
end

-- After an element: true and true at the table's "}" (read), true and false after its "," with more to come, or
-- false.
---@param p PaglePayloadParser
---@return boolean ok
---@return boolean? closed
local function separator(p)
	skip(p)
	local c = byte(p.text, p.at)
	if c == COMMA then
		p.at = p.at + 1
		skip(p)
		if byte(p.text, p.at) == CLOSE then
			p.at = p.at + 1
			return true, true
		end
		return true, false
	elseif c == CLOSE then
		p.at = p.at + 1
		return true, true
	elseif not c then
		return fail(p, p.at, "PAYLOAD_ENDED")
	end
	return fail(p, p.at, "PAYLOAD_EXPECTED", ", or }")
end

--- A table at p.at ("{"), at `depth`: a list of values, or a record of fields, never both. Returns true, the table
--- and its first two field names in order (a record's), or false.
---@param p PaglePayloadParser
---@param depth integer
---@return boolean ok
---@return table? value
---@return string? first
---@return string? second
function parseTable(p, depth)
	local open = p.at
	if depth > ns.PAYLOAD_DEPTH_LIMIT then
		return fail(p, open, "PAYLOAD_TOO_DEEP", ns.PAYLOAD_DEPTH_LIMIT)
	end
	p.at = open + 1
	skip(p)
	local value, count = {}, 0
	if byte(p.text, p.at) == CLOSE then
		p.at = p.at + 1
		return true, value
	end
	local record = fieldAhead(p)
	local first, second ---@type string?, string?
	while true do
		if record then
			local keyAt = p.at
			local ok, key = parseKey(p)
			if not ok then
				return false
			end
			---@cast key string
			skip(p)
			if byte(p.text, p.at) ~= EQUALS then
				return fail(p, p.at, "PAYLOAD_EXPECTED", "=")
			end
			p.at = p.at + 1
			skip(p)
			if value[key] ~= nil then
				return fail(p, keyAt, "PAYLOAD_DUPLICATE", key)
			end
			local read, field = parseValue(p, depth)
			if not read then
				return false
			end
			value[key] = field
			count = count + 1
			if count == 1 then
				first = key
			elseif count == 2 then
				second = key
			end
		else
			if fieldAhead(p) then
				return fail(p, p.at, "PAYLOAD_MIXED")
			end
			local read, element = parseValue(p, depth)
			if not read then
				return false
			end
			count = count + 1
			value[count] = element
		end
		local ok, closed = separator(p)
		if not ok then
			return false
		elseif closed then
			return true, value, first, second
		end
	end
end

--- Reads a decoded payload (PUSH-R20): `{ items = { item, … }, }`, each item `{ kind = "…", v = n, fields… }`, with
--- kind `[%w_]+` and v an integer, its first two fields in that order. Returns the items in payload order; or nil,
--- the byte the error is at, its ns.L key (PAYLOAD_*) and what that line names. `pause`, if given, is called every
--- few hundred values, where the check's coroutine may yield.
---@param text string
---@param pause fun()?
---@return table[]? items
---@return integer? at
---@return string? key
---@return any arg
function ns.ParsePayload(text, pause)
	---@type PaglePayloadParser
	local p = { text = text, at = 1, count = 0, pause = pause }
	-- On a failure, its byte, key and argument.
	local function failed()
		return nil, p.failAt, p.failKey, p.failArg
	end
	skip(p)
	if byte(text, p.at) ~= OPEN then
		fail(p, p.at, "PAYLOAD_EXPECTED", "{")
		return failed()
	end
	p.at = p.at + 1
	skip(p)
	local keyAt = p.at
	local ok, key = parseKey(p)
	if not ok then
		return failed()
	elseif key ~= "items" then
		fail(p, keyAt, "PAYLOAD_EXPECTED", "items")
		return failed()
	end
	skip(p)
	if byte(text, p.at) ~= EQUALS then
		fail(p, p.at, "PAYLOAD_EXPECTED", "=")
		return failed()
	end
	p.at = p.at + 1
	skip(p)
	if byte(text, p.at) ~= OPEN then
		fail(p, p.at, "PAYLOAD_EXPECTED", "{")
		return failed()
	end
	p.at = p.at + 1
	skip(p)
	local items = {}
	local closed = byte(text, p.at) == CLOSE
	if closed then
		p.at = p.at + 1
	end
	while not closed do
		local itemAt = p.at
		if byte(text, itemAt) ~= OPEN then
			fail(p, itemAt, "PAYLOAD_EXPECTED_ITEM")
			return failed()
		end
		tick(p)
		local read, item, first, second = parseTable(p, 3)
		if not read then
			return failed()
		end
		---@cast item table
		local kind, v = item.kind, item.v
		if
			first ~= "kind"
			or second ~= "v"
			or type(kind) ~= "string"
			or not find(kind, "^[%w_]+$")
			or type(v) ~= "number"
		then
			fail(p, itemAt, "PAYLOAD_BAD_ITEM")
			return failed()
		end
		items[#items + 1] = item
		local separated, last = separator(p)
		if not separated then
			return failed()
		end
		closed = last == true
	end
	-- The payload's own table: its one field is done; a "," may follow it, then "}".
	local separated, last = separator(p)
	if not separated then
		return failed()
	elseif not last then
		fail(p, p.at, "PAYLOAD_EXPECTED", "}")
		return failed()
	end
	skip(p)
	if p.at <= #text then
		fail(p, p.at, "PAYLOAD_AFTER_TABLE")
		return failed()
	end
	return items
end

--- The items Core passes on (PUSH-R21): those whose kind and version are in ns.PUSHED_KINDS, by kind, each kind's in
--- payload order; and how many of every other kind were dropped, by "kind v" ("notice v1").
---@param items table[] ns.ParsePayload's
---@return table<string, table[]> kept
---@return table<string, integer> dropped
function ns.KeepPushedItems(items)
	local kept, dropped = {}, {}
	for _, item in ipairs(items) do
		local kind = item.kind
		if ns.PUSHED_KINDS[kind] == item.v then
			local list = kept[kind] or {}
			kept[kind] = list
			list[#list + 1] = item
		else
			local label = ("%s v%s"):format(tostring(kind), tostring(item.v))
			dropped[label] = (dropped[label] or 0) + 1
		end
	end
	return kept, dropped
end
