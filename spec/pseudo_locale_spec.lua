-- Every string the six addons ship in English, through the pseudo-locale (#524, CORE-R8, DATA-R114) and then the text
-- helper. Each addon's generated enUS table is loaded twice, once plain and once with the pseudo-locale on (dev mode and
-- PagleDB.global.devPseudo), and the two are compared key by key: the same keys, the same {fields}, `{{`, `}}`, colour
-- codes, textures, `|n` and `%` in the same order, a string with a letter in brackets and at least 1.4 times as long, and
-- the helper fills the padded string with no error and no field left unfilled. The transform and where it applies is
-- spec/Pagle/adapter/DevPseudo_spec.lua's. The harness is spec/shipped_text_spec.lua's: the same six addons, the same
-- counted-string shape, the same counts.

local ADDONS = { "Pagle_Hunts", "Pagle_Ledger", "Pagle_QoL", "Pagle_Stats", "Pagle_TackleBoard" }
local ALL = { "Pagle", unpack(ADDONS) }
local CATEGORIES = { zero = true, one = true, two = true, few = true, many = true, other = true }

-- The code points in `text`.
---@param text string
---@return integer
local function points(text)
	local _, count = text:gsub("[^\128-\191]", "")
	return count
end

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

-- Every string below `value`, by its path (`KEY`, `TABLE.sub`, `LIST[2]`), and every counted string by its path.
---@param value any
---@param path string
---@param strings table<string, string>
---@param counted table<string, table<string, string>>
local function collect(value, path, strings, counted)
	if type(value) == "string" then
		strings[path] = value
	elseif type(value) == "table" then
		if isCounted(value) then
			counted[path] = value
		end
		for key, item in pairs(value) do
			collect(
				item,
				type(key) == "number" and ("%s[%d]"):format(path, key) or path .. "." .. tostring(key),
				strings,
				counted
			)
		end
	end
end

-- The markup a string holds, kind by kind, each in the order it stands.
local KINDS = {
	{ "field", "{[%w_]+:?%w*}" },
	{ "open brace escape", "{{" },
	{ "close brace escape", "}}" },
	{ "colour", "|c%x%x%x%x%x%x%x%x" },
	{ "colour end", "|r" },
	{ "newline", "|n" },
	{ "texture", "|T.-|t" },
	{ "percent", "%%" },
}

---@param text string
---@param pattern string
---@return string[]
local function all(text, pattern)
	local found = {}
	for match in text:gmatch(pattern) do
		found[#found + 1] = match
	end
	return found
end

-- The text with its markup and slash words taken out: what is left is the literal text the transform may change.
---@param text string
---@return string
local function literal(text)
	for _, kind in ipairs(KINDS) do
		text = text:gsub(kind[2], "")
	end
	text = text:gsub("|[%a|]", ""):gsub("^/%a[%w_]*", ""):gsub("%s/%a[%w_]*", "")
	return text
end

describe("every string the addons ship, through the pseudo-locale", function()
	local english = loadAddon("Pagle", FOREVER_GLOBALS, { also = ADDONS })
	local padded = loadAddon("Pagle", foreverWith({ PagleDB = { global = { dev = true, devPseudo = true } } }), {
		also = ADDONS,
	})
	local render = padded.namespaces.Pagle.RenderText

	local seen = 0
	for _, addon in ipairs(ALL) do
		describe(addon, function()
			local plain, plainCounted = {}, {}
			local pseudo, pseudoCounted = {}, {}
			collect(english.namespaces[addon].L, "", plain, plainCounted)
			collect(padded.namespaces[addon].L, "", pseudo, pseudoCounted)
			local paths = {}
			for path in pairs(plain) do
				paths[#paths + 1] = path
			end
			table.sort(paths)
			seen = seen + #paths

			it("keeps every key and the shape of every counted string", function()
				for path, source in pairs(plain) do
					assert.is_string(pseudo[path], path)
					assert.is_string(source)
				end
				for path in pairs(pseudo) do
					assert.is_string(plain[path], path)
				end
				for path, forms in pairs(plainCounted) do
					assert.is_table(pseudoCounted[path], path)
					for category in pairs(forms) do
						assert.is_string(pseudoCounted[path][category], path .. " " .. category)
					end
				end
				assert.is_true(#paths > 50)
			end)

			it("pads, brackets and keeps the markup of each string, and leaves a letterless one alone", function()
				local failures = {}
				for _, path in ipairs(paths) do
					local source, shown = plain[path], pseudo[path]
					if path:find("^%.DEV_") then
						if shown ~= source then
							failures[#failures + 1] = path .. ": dev text changed"
						end
					elseif not literal(source):find("%a") then
						if shown ~= source then
							failures[#failures + 1] = path .. ": changed with no literal letter: " .. shown
						end
					elseif shown:sub(1, 1) ~= "[" or shown:sub(-1) ~= "]" then
						failures[#failures + 1] = path .. ": not in brackets: " .. shown
					elseif points(shown) < 1.4 * points(source) then
						failures[#failures + 1] = ("%s: %d points from %d"):format(path, points(shown), points(source))
					else
						for _, kind in ipairs(KINDS) do
							local want = table.concat(all(source, kind[2]), "\0")
							if want ~= table.concat(all(shown, kind[2]), "\0") then
								failures[#failures + 1] = ("%s: the %ss changed: %s"):format(path, kind[1], shown)
							end
						end
					end
				end
				assert.are.same({}, failures)
			end)

			it("fills with every field given, with no error and no field left", function()
				local failures = {}
				for _, path in ipairs(paths) do
					local shown = pseudo[path]
					local fields = {}
					for name in plain[path]:gsub("{{", ""):gsub("}}", ""):gmatch("{([%w_]+)[:}]") do
						fields[name] = "FIELD"
					end
					local ok, text = pcall(render, shown, fields)
					if not ok then
						failures[#failures + 1] = path .. ": raised " .. tostring(text)
					elseif text:find("{[%w_]+[:}]") then
						failures[#failures + 1] = path .. ": left a field in " .. text
					elseif plain[path]:find("{{", 1, true) == nil and text:find("[{}]") then
						failures[#failures + 1] = path .. ": left a brace in " .. text
					end
				end
				assert.are.same({}, failures)
			end)

			it("renders each counted string at counts 0, 1 and 2 with the same form picked as in English", function()
				local failures = {}
				for path, forms in pairs(plainCounted) do
					-- Dev text stays English.
					local counts = path:find("^%.DEV_") and {} or { 0, 1, 2 }
					local fields = {}
					for _, form in pairs(forms) do
						for name in form:gsub("{{", ""):gsub("}}", ""):gmatch("{([%w_]+)[:}]") do
							fields[name] = "FIELD"
						end
					end
					for _, count in ipairs(counts) do
						fields.count = count
						local ok, text = pcall(render, pseudoCounted[path], fields)
						local picked = (count == 1 and forms.one or forms.other)
						if not ok then
							failures[#failures + 1] = ("%s at %d: raised %s"):format(path, count, tostring(text))
						elseif text:find("{[%w_]+[:}]") then
							failures[#failures + 1] = ("%s at %d: left a field in %s"):format(path, count, text)
						elseif literal(picked):find("%a") and text:sub(1, 1) ~= "[" then
							failures[#failures + 1] = ("%s at %d: not the padded form: %s"):format(path, count, text)
						end
					end
				end
				assert.are.same({}, failures)
			end)
		end)
	end

	it("went through every addon's table: well over a thousand strings", function()
		assert.is_true(seen > 1000, tostring(seen))
	end)
end)
