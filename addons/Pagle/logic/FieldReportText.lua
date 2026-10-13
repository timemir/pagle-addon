---@class PagleNS
local ns = select(2, ...)

-- The Field report's text (field-report.md › Format): rows sorted (REP-R23) and written as `PAGLE-REPORT 1`
-- (REP-R30–R32), split into parts (REP-R33), with the reporter key (REP-R36). Pure: the adapter
-- (adapter/FieldReportText.lua) looks up the addon version, fingerprint, locale, logId and names and passes them in.
--
-- The format, one part:
--
--   PAGLE-REPORT 1
--   addon <version> data <8 hex> locale <locale> reporter <8 hex> part <n>/<m>
--   I <itemID> <areaID> <build> <count> [aura=<id,…>] [event=<id,…>] [t=<HH:MM> m=<month>] [ # <names>]
--   K <areaID> <build> casts=<n> away=<n> [land=<skill>] [lost=<skill>] [ # <names>]
--   P <areaID> <locale> "<text>" casts=<n> <itemID>x<count> … [ # <names>]
--   END
--
-- Each line ends in "\n", END's too. A comment is " # " then the names, for humans only; within each kind of row the
-- comments line up, the shorter rows padded with spaces. Inside the quotes of a P text, `\` escapes `"`, `\` and a
-- newline (`\n`) (REP-R32).
--
-- Versioning (REP-R31): the repo's parser (scripts/pagle_data/, DATA-R116) ignores comments and unknown `key=value`
-- keys, so adding a key needs no version bump. Changing the meaning of anything already written (a field, a key, the
-- header, the quoting) bumps `PAGLE-REPORT`, and the parser changes in the same commit (field-report.md › Contracts).

--- Tunable: line 1 of every part, the format version (REP-R30).
ns.FIELD_REPORT_FORMAT = "PAGLE-REPORT 1"
--- Tunable: the most bytes a part may hold, its header lines and END included (REP-R33).
ns.FIELD_REPORT_PART_BYTES = 60000

--- One row as ticket #121's `ns.FieldReportRows()` hands it over, unsorted (REP-R20–R22).
---@class PagleReportRow
---@field kind "I"|"K"|"P"
---@field area integer        -- the report area (REP-R3)
---@field build integer?      -- I, K: the build (REP-R4)
---@field item integer?       -- I
---@field count integer?      -- I: Catches
---@field auras integer[]?    -- I: active listed auras, ascending, maybe empty
---@field events integer[]?   -- I: active listed events, ascending, maybe empty
---@field t integer?          -- I: the start of the 15-minute realm-time bucket, in realm minutes of the day
---@field m integer?          -- I: the realm month, 1–12
---@field casts integer?      -- K, P
---@field away integer?       -- K
---@field land integer?       -- K
---@field lost integer?       -- K
---@field locale string?      -- P
---@field text string?        -- P: the hovered text
---@field items { item: integer, count: integer }[]? -- P: ascending by item

--- What the adapter looks up for the header (REP-R30, REP-R36).
---@class PagleReportHeader
---@field addon string        -- C_AddOns.GetAddOnMetadata("Pagle", "Version")
---@field fingerprint string  -- Pagle.CONTENT_FINGERPRINT, lowercase hex
---@field locale string       -- GetLocale()
---@field logId string        -- PagleLog.logId; only its reporter key is written (REP-R35)

--- The names a comment shows, in the player's locale (REP-R30). nil leaves a name out.
---@class PagleReportNames
---@field item fun(itemID: integer): string?  -- nil until C_Item.GetItemInfo has cached it
---@field area fun(areaID: integer): string?

-- XOR of two bytes, 0–255, with plain arithmetic: busted's Lua 5.1 may lack the client's `bit`.
---@param a integer
---@param b integer
---@return integer
local function xorByte(a, b)
	local result, place = 0, 1
	for _ = 1, 8 do
		local abit, bbit = a % 2, b % 2
		if abit ~= bbit then
			result = result + place
		end
		a, b, place = (a - abit) / 2, (b - bbit) / 2, place * 2
	end
	return result
end

--- The reporter key (REP-R36): the FNV-1a 32-bit hash of the bytes of `logId`, as 8 lowercase hex characters,
--- zero-padded. Portable Lua 5.1: every step stays an exact integer in a double.
---@param logId string
---@return string
function ns.ReporterKey(logId)
	local hash = 2166136261 -- the FNV-1a 32-bit offset basis
	for i = 1, #logId do
		local low = hash % 256
		hash = hash - low + xorByte(low, logId:byte(i))
		-- hash * 16777619 (the FNV prime, 2^24 + 403) mod 2^32, split so no product passes 2^53.
		hash = (hash * 403 + (hash % 256) * 16777216) % 4294967296
	end
	return string.format("%04x%04x", math.floor(hash / 65536), hash % 65536)
end

-- Compares two lists of numbers element by element; a list that is a prefix of the other is less (REP-R23).
-- Returns -1, 0 or 1.
---@param a integer[]
---@param b integer[]
---@return integer
local function compareLists(a, b)
	for i = 1, math.min(#a, #b) do
		if a[i] ~= b[i] then
			return a[i] < b[i] and -1 or 1
		end
	end
	if #a == #b then
		return 0
	end
	return #a < #b and -1 or 1
end

-- Compares two different strings by byte order (REP-R23), not Lua's `<`, which follows the C library's locale.
-- Returns -1 or 1.
---@param a string
---@param b string
---@return integer
local function compareBytes(a, b)
	for i = 1, math.min(#a, #b) do
		local x, y = a:byte(i), b:byte(i)
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	return #a < #b and -1 or 1
end

-- Compares two values of one sort key; an absent one (nil, or an empty list) sorts first (REP-R23). Returns -1, 0
-- or 1.
---@param a integer|integer[]|string|nil
---@param b integer|integer[]|string|nil
---@return integer
local function compareKey(a, b)
	if type(a) == "table" and #a == 0 then
		a = nil
	end
	if type(b) == "table" and #b == 0 then
		b = nil
	end
	if a == nil or b == nil then
		if a == b then
			return 0
		end
		return a == nil and -1 or 1
	end
	if type(a) == "table" then
		---@cast b integer[]
		return compareLists(a, b)
	end
	if a == b then
		return 0
	end
	if type(a) == "string" then
		---@cast b string
		return compareBytes(a, b)
	end
	---@cast b integer
	return a < b and -1 or 1
end

-- The kinds in report order (REP-R23).
local KIND_ORDER = { I = 1, K = 2, P = 3 }
-- Each kind's sort keys after its area (REP-R23).
local KIND_KEYS = {
	I = { "item", "build", "auras", "events", "t", "m" },
	K = { "build" },
	P = { "locale", "text" },
}

-- True when row `a` comes before row `b` (REP-R23): by kind, then area, then the kind's keys.
---@param a PagleReportRow
---@param b PagleReportRow
---@return boolean
local function rowBefore(a, b)
	if a.kind ~= b.kind then
		return KIND_ORDER[a.kind] < KIND_ORDER[b.kind]
	end
	if a.area ~= b.area then
		return a.area < b.area
	end
	for _, key in ipairs(KIND_KEYS[a.kind]) do
		local order = compareKey(a[key], b[key])
		if order ~= 0 then
			return order < 0
		end
	end
	return false
end

-- A P row's text in double quotes, with `\` escaping `"`, `\` and a newline (REP-R32).
---@param text string
---@return string
local function quote(text)
	local escaped = text:gsub('[\\"\n]', { ["\\"] = "\\\\", ['"'] = '\\"', ["\n"] = "\\n" })
	return '"' .. escaped .. '"'
end

-- A row's line without its comment (REP-R20–R22, REP-R30).
---@param row PagleReportRow
---@return string
local function rowBody(row)
	local fields
	if row.kind == "I" then
		fields = { "I", row.item, row.area, row.build, row.count }
		if row.auras and #row.auras > 0 then
			fields[#fields + 1] = "aura=" .. table.concat(row.auras, ",")
		end
		if row.events and #row.events > 0 then
			fields[#fields + 1] = "event=" .. table.concat(row.events, ",")
		end
		if row.t then
			fields[#fields + 1] = string.format("t=%02d:%02d", math.floor(row.t / 60), row.t % 60)
		end
		if row.m then
			fields[#fields + 1] = "m=" .. row.m
		end
	elseif row.kind == "K" then
		fields = { "K", row.area, row.build, "casts=" .. row.casts, "away=" .. row.away }
		if row.land then
			fields[#fields + 1] = "land=" .. row.land
		end
		if row.lost then
			fields[#fields + 1] = "lost=" .. row.lost
		end
	else
		fields = { "P", row.area, row.locale, quote(row.text), "casts=" .. row.casts }
		for _, entry in ipairs(row.items) do
			fields[#fields + 1] = entry.item .. "x" .. entry.count
		end
	end
	return table.concat(fields, " ")
end

-- A row's names for its comment, comma-separated, or nil with none (REP-R30): an I row's item name, then the area
-- name; a K or P row's area name. A line break in a name becomes a space, so a name never ends the line.
---@param row PagleReportRow
---@param names PagleReportNames
---@return string?
local function rowNames(row, names)
	local list = {}
	if row.kind == "I" then
		list[#list + 1] = names.item(row.item)
	end
	list[#list + 1] = names.area(row.area)
	if #list == 0 then
		return nil
	end
	return (table.concat(list, ", "):gsub("[\r\n]", " "))
end

-- A string's width in characters: its UTF-8 lead bytes, so a padded comment lines up on screen.
---@param s string
---@return integer
local function width(s)
	local _, count = s:gsub("[^\128-\191]", "")
	return count
end

-- Each row's full line with its "\n" (REP-R30): its body, then its comment, if it has names, lined up with the
-- other comments of its kind.
---@param rows PagleReportRow[] sorted
---@param names PagleReportNames
---@return string[]
local function rowLines(rows, names)
	local bodies, comments, widest = {}, {}, {}
	for i, row in ipairs(rows) do
		bodies[i], comments[i] = rowBody(row), rowNames(row, names)
		if comments[i] then
			widest[row.kind] = math.max(widest[row.kind] or 0, width(bodies[i]))
		end
	end
	local lines = {}
	for i, row in ipairs(rows) do
		local line = bodies[i]
		if comments[i] then
			line = line .. string.rep(" ", widest[row.kind] - width(line)) .. " # " .. comments[i]
		end
		lines[i] = line .. "\n"
	end
	return lines
end

-- A part's two header lines, each with its "\n" (REP-R30).
---@param header PagleReportHeader
---@param n integer
---@param m integer
---@return string
local function headerLines(header, n, m)
	return string.format(
		"%s\naddon %s data %s locale %s reporter %s part %d/%d\n",
		ns.FIELD_REPORT_FORMAT,
		header.addon,
		header.fingerprint:sub(1, 8),
		header.locale,
		ns.ReporterKey(header.logId),
		n,
		m
	)
end

local END = "END\n"

-- Groups the lines into parts (REP-R33): each part takes lines in order while it stays within the limit with its
-- header and END, assuming the part count has `digits` digits. A line too long for any part gets a part to itself.
---@param lines string[]
---@param header PagleReportHeader
---@param digits integer
---@return string[][]
local function fill(lines, header, digits)
	local widestCount = 10 ^ digits - 1
	local groups = {}
	local group, size
	for _, line in ipairs(lines) do
		if not group or size + #line > ns.FIELD_REPORT_PART_BYTES then
			group = {}
			groups[#groups + 1] = group
			size = #headerLines(header, #groups, widestCount) + #END
		end
		group[#group + 1] = line
		size = size + #line
	end
	if #groups == 0 then
		groups[1] = {}
	end
	return groups
end

--- The Field report's text, as its parts in order (REP-R23, REP-R30–R33, REP-R36). `rows` is ticket #121's, in any
--- order, and isn't changed. Each part is `PAGLE-REPORT 1`, the header, its rows in sort order and END, at most
--- `ns.FIELD_REPORT_PART_BYTES` bytes; a row is never cut. No rows give one part with none.
---@param rows PagleReportRow[]
---@param header PagleReportHeader
---@param names PagleReportNames
---@return string[]
function ns.FieldReportParts(rows, header, names)
	local sorted = {}
	for i, row in ipairs(rows) do
		sorted[i] = row
	end
	table.sort(sorted, rowBefore)
	local lines = rowLines(sorted, names)

	-- The header's size depends on the part count's digits, so fill again until the count has the digits assumed.
	local digits = 1
	local groups = fill(lines, header, digits)
	while #tostring(#groups) > digits do
		digits = #tostring(#groups)
		groups = fill(lines, header, digits)
	end

	local parts = {}
	for n, group in ipairs(groups) do
		parts[n] = headerLines(header, n, #groups) .. table.concat(group) .. END
	end
	return parts
end
