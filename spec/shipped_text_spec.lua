-- The shipped English counted strings, rendered (CORE-R8, DATA-R114, #512). A counted string is a table of plural
-- categories picked by `fields.count`. Each one is rendered through the real helper at counts 0, 1 and 2 with every
-- field it names filled, and must show the form English's rule picks (`one` for exactly 1, else `other`) with no
-- `{` or `}` left in it: a malformed spec (`{count:x}`), a lone brace or an unfilled field fails here, by key.
-- That the calls fill the fields their templates name is checked on the tree by scripts/tests/test_repo_text_fields.py.

local ADDONS = { "Pagle_Hunts", "Pagle_Ledger", "Pagle_QoL", "Pagle_Stats", "Pagle_TackleBoard" }
local CATEGORIES = { zero = true, one = true, two = true, few = true, many = true, other = true }
local COUNTS = { 0, 1, 2 }

---@param value any
---@return boolean
local function isCounted(value)
	if type(value) ~= "table" or type(value.other) ~= "string" then
		return false
	end
	for category, form in pairs(value) do
		if not CATEGORIES[category] or type(form) ~= "string" then
			return false
		end
	end
	return true
end

-- Every counted string below `value`, by its path (`KEY`, `TABLE.sub`, `LIST[2]`), at any depth.
---@param value any
---@param path string
---@param into table<string, table<string, string>>
local function collect(value, path, into)
	if isCounted(value) then
		into[path] = value
	elseif type(value) == "table" then
		for key, item in pairs(value) do
			collect(item, type(key) == "number" and ("%s[%d]"):format(path, key) or path .. "." .. tostring(key), into)
		end
	end
end

-- The names a counted string's forms put in braces, any spec dropped.
---@param forms table<string, string>
---@return string[]
local function fieldNames(forms)
	local seen, names = {}, {}
	for _, form in pairs(forms) do
		for name in form:gsub("{{", ""):gsub("}}", ""):gmatch("{([%w_]+)[:}]") do
			if not seen[name] then
				seen[name] = true
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

-- What the form should read as, worked out here rather than by the helper: the count as the field's spec writes it, any
-- other field as FIELD, and `{{` and `}}` as braces.
---@param form string
---@param count number
---@return string
local function expected(form, count)
	local text = form:gsub("{{", "\1"):gsub("}}", "\2")
	text = text:gsub("{count:(%d)}", function(places)
		return ("%." .. places .. "f"):format(count)
	end)
	text = text:gsub("{count:n}", tostring(count)):gsub("{count}", tostring(count))
	text = text:gsub("{([%w_]+):?%w*}", "FIELD")
	return (text:gsub("\1", "{"):gsub("\2", "}"))
end

describe("every counted string the addons ship, in English", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS, { also = ADDONS })
	local render = loaded.namespaces.Pagle.RenderText
	local sets = {}
	for _, addon in ipairs({ "Pagle", unpack(ADDONS) }) do
		local found = {}
		collect(loaded.namespaces[addon].L, "", found)
		sets[addon] = found
	end

	it("finds counted strings in every addon that has them", function()
		local total = 0
		for _, found in pairs(sets) do
			for _ in pairs(found) do
				total = total + 1
			end
		end
		assert.is_true(total > 50)
		assert.is_truthy(next(sets.Pagle))
	end)

	for _, addon in ipairs({ "Pagle", unpack(ADDONS) }) do
		describe(addon, function()
			local paths = {}
			for path in pairs(sets[addon]) do
				paths[#paths + 1] = path
			end
			table.sort(paths)
			for _, path in ipairs(paths) do
				it("shows the right form at counts 0, 1 and 2, " .. (path:gsub("^%.", "")), function()
					local forms = sets[addon][path]
					local fields = {}
					for _, name in ipairs(fieldNames(forms)) do
						fields[name] = "FIELD"
					end
					for _, count in ipairs(COUNTS) do
						fields.count = count
						local form = (count == 1 and forms.one) or forms.other
						local shown = render(forms, fields)
						assert.is_nil(shown:find("[{}]"), ("count %d shows %q"):format(count, shown))
						assert.are.equal(expected(form, count), shown)
					end
				end)
			end
		end)
	end
end)
