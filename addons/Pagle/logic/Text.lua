---@class PagleNS
local ns = select(2, ...)

-- Core's one text helper (CORE-R8, ADR 0019): a template with named {fields}, a counted string that picks its plural
-- form by the active Locale's CLDR rule, and numbers written with the separators the chosen Pagle language declares.
-- Pure Lua 5.1 (CORE-R7): it reads no global but the pure functions, no `ns.L` and no client call, so it loads under the
-- backend's replay driver (spec/logic_alone_spec.lua). Nothing on the fold path calls it: a fold needs no locale.

--- What a Locale gives the helper (DATA-R114): its plural rule and its two separators. English is the default.
---@class PagleTextLocale
---@field plural fun(n: number): string The CLDR category of a count: "zero", "one", "two", "few", "many" or "other". It is
--- handed the count's absolute value, and takes the integer part itself where the language's rule does.
---@field decimal string The decimal separator, never empty.
---@field thousands string The thousands separator; "" writes none.

---@type PagleTextLocale
local ENGLISH = {
	plural = function(n)
		return n == 1 and "one" or "other"
	end,
	decimal = ".",
	thousands = ",",
}

local active = ENGLISH

--- Sets the Locale the helper reads (DATA-R114), for Core's registration of a Locale to call; nil goes back to English.
--- A record that is not whole raises and changes nothing.
---@param record PagleTextLocale?
function ns.SetTextLocale(record)
	if record == nil then
		active = ENGLISH
		return
	end
	if type(record) ~= "table" then
		error("SetTextLocale: a Locale record is a table", 2)
	end
	if type(record.plural) ~= "function" then
		error("SetTextLocale: plural is a function", 2)
	end
	if type(record.decimal) ~= "string" or record.decimal == "" then
		error("SetTextLocale: decimal is a non-empty string", 2)
	end
	if type(record.thousands) ~= "string" then
		error("SetTextLocale: thousands is a string", 2)
	end
	active = { plural = record.plural, decimal = record.decimal, thousands = record.thousands }
end

--- The digits of `abs` with the Locale's separators: `decimals` places, or with none given as many as the number has.
---@param abs number non-negative and finite
---@param decimals integer?
---@return string
local function digits(abs, decimals)
	local text
	if decimals then
		text = ("%." .. decimals .. "f"):format(abs)
	elseif abs == math.floor(abs) then
		text = ("%.0f"):format(abs)
	else
		text = ("%.14g"):format(abs)
		if text:find("e", 1, true) then
			text = ("%.12f"):format(abs):gsub("0+$", "")
		end
	end
	local whole, fraction = text:match("^(%d+)%.?(%d*)$")
	local groups = {}
	local first = #whole % 3
	if first > 0 then
		groups[1] = whole:sub(1, first)
	end
	for at = first + 1, #whole, 3 do
		groups[#groups + 1] = whole:sub(at, at + 2)
	end
	local out = table.concat(groups, active.thousands)
	if fraction ~= "" then
		out = out .. active.decimal .. fraction
	end
	return out
end

--- A number in the active Locale's separators: 1234.5 is "1,234.5" in English and "1.234,5" with `.` for thousands and
--- `,` for the decimal. `decimals` fixes the places (rounded); none writes the number's own. A number given as a string
--- is read first; anything that is not a finite number comes back as `tostring` makes it. A minus sign is "-", and is
--- left off a value that rounds to zero.
---@param value number|string
---@param decimals integer?
---@return string
function ns.FormatNumber(value, decimals)
	local number = tonumber(value)
	if number == nil or number ~= number or number == math.huge or number == -math.huge then
		return tostring(value)
	end
	local text = digits(math.abs(number), decimals)
	if number < 0 and text:find("[1-9]") then
		return "-" .. text
	end
	return text
end

--- What one `{name}` or `{name:spec}` becomes. The spec is `n` (the number as it is) or a count of decimal places
--- ("0", "1", "2"); a plain `{name}` is the value as `tostring` makes it, so an ID, a name or a pre-formatted string such
--- as Pagle.FormatLength's passes through untouched. A string that is not a number passes through whatever the spec.
---@param value any
---@param spec string?
---@return string
local function field(value, spec)
	if spec == nil then
		return tostring(value)
	end
	local number = tonumber(value)
	if number == nil then
		return tostring(value)
	end
	return ns.FormatNumber(number, spec ~= "n" and tonumber(spec) or nil)
end

--- Fills a template: `{name}` and `{name:spec}` from `fields`, `{{` and `}}` for a literal brace. A field with no
--- value stays as written (spec and all), an extra field is ignored, and a brace that starts no field is kept.
---@param template string
---@param fields table<string, any>
---@return string
local function fill(template, fields)
	local out, at, length = {}, 1, #template
	while at <= length do
		local brace = template:find("[{}]", at)
		if not brace then
			out[#out + 1] = template:sub(at)
			break
		end
		out[#out + 1] = template:sub(at, brace - 1)
		local char = template:sub(brace, brace)
		if template:sub(brace + 1, brace + 1) == char then
			out[#out + 1] = char
			at = brace + 2
		elseif char == "{" then
			local name, close = template:match("^{([%w_]+)}()", brace)
			local spec
			if not name then
				name, spec, close = template:match("^{([%w_]+):(%w+)}()", brace)
			end
			local value = fields[name]
			if name and value ~= nil and (spec == nil or spec == "n" or spec:find("^%d+$")) then
				out[#out + 1] = field(value, spec)
				at = close
			else
				out[#out + 1] = char
				at = brace + 1
			end
		else
			out[#out + 1] = char
			at = brace + 1
		end
	end
	return table.concat(out)
end

--- Text for a string of `ns.L` (CORE-R8): a plain string is filled from `fields`; a counted string, a table of plural
--- categories (`zero`, `one`, `two`, `few`, `many`, `other`), first picks its form by the active Locale's rule on
--- `fields.count`, then fills it. A category the table lacks falls back to `other`, which a counted string must have;
--- a missing or non-numeric `count` picks `other`.
---@param source string|table<string, string>
---@param fields table<string, any>?
---@return string
function ns.RenderText(source, fields)
	fields = fields or {}
	if type(source) == "table" then
		local count = tonumber(fields.count)
		local category = count and active.plural(math.abs(count)) or "other"
		local form = source[category] or source.other
		if type(form) ~= "string" then
			error("Text: a counted string needs an 'other' form", 2)
		end
		return fill(form, fields)
	end
	if type(source) ~= "string" then
		error("Text: a string or a table of plural forms, not " .. type(source), 2)
	end
	return fill(source, fields)
end

--- Publishes the helper on `Pagle` as `Pagle.Text`, which reads the active Locale at each call (CORE-R8).
---@param Pagle table
function ns.PublishText(Pagle)
	---@class Pagle
	local api = Pagle
	--- Fills a template with named `{fields}`, and picks a counted string's plural form by `fields.count` in the active
	--- language. `{n:1}` writes a number with one decimal place, `{n:n}` as it is, both in the language's separators;
	--- `{{` and `}}` are literal braces (CORE-R8).
	---@type fun(source: string|table<string, string>, fields: table<string, any>?): string
	api.Text = ns.RenderText
end
