-- Every addon's locale/esES.lua overrides enUS keys only, with the same value shapes, the same format specifiers and
-- the same markup escapes, and does nothing on any other client locale (CORE-R8).

local ADDONS = { "Pagle", "Pagle_Hunts", "Pagle_Ledger", "Pagle_QoL", "Pagle_Stats", "Pagle_TackleBoard" }

---@param addon string
---@param file string
---@param locale string the client locale GetLocale answers
---@param ns table the addon's namespace, shared by every file loaded into it
local function load(addon, file, locale, ns)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile("addons/" .. addon .. "/locale/" .. file .. ".lua"))
	local env = setmetatable({
		Pagle = true,
		GetLocale = function()
			return locale
		end,
	}, { __index = _G })
	---@diagnostic disable-next-line: undefined-global -- Lua 5.1's setfenv
	setfenv(chunk, env)
	chunk(addon, ns)
end

---@param value any
---@return any
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = copy(v)
	end
	return out
end

-- The format specifiers of `text` in order, without their argument position, plus its Blizzard markup escapes.
---@param text string
---@return string[]
local function shape(text)
	local found = {}
	for flags, kind in text:gsub("%%%%", ""):gmatch("%%%d*%$?([%-%+#0]*%d*%.?%d*)([a-zA-Z])") do
		found[#found + 1] = "%" .. flags .. kind
	end
	for escape in text:gmatch("|[cCrRTtHhnN]") do
		found[#found + 1] = escape:lower()
	end
	for token in text:gmatch("|T[^|]*|t") do
		found[#found + 1] = token
	end
	table.sort(found)
	return found
end

---@param english any
---@param spanish any
---@param path string
---@param problems string[]
local function compare(english, spanish, path, problems)
	if type(english) ~= type(spanish) then
		problems[#problems + 1] = path .. ": " .. type(english) .. " became " .. type(spanish)
	elseif type(english) == "string" then
		local a, b = table.concat(shape(english), " "), table.concat(shape(spanish), " ")
		if a ~= b then
			problems[#problems + 1] = path .. ": specifiers and markup `" .. a .. "` became `" .. b .. "`"
		end
	elseif type(english) == "table" then
		for key, value in pairs(spanish) do
			if english[key] == nil then
				problems[#problems + 1] = path .. "." .. tostring(key) .. ": not in enUS"
			else
				compare(english[key], value, path .. "." .. tostring(key), problems)
			end
		end
		-- A top-level key left out keeps enUS's value; a key left out of a table esES replaces is gone.
		local top = path == "L"
		for key in pairs(english) do
			if spanish[key] == nil and (type(english[key]) == "table" or not top) then
				problems[#problems + 1] = path .. "." .. tostring(key) .. ": missing"
			end
		end
	end
end

describe("locale/esES.lua", function()
	for _, addon in ipairs(ADDONS) do
		describe(addon, function()
			it("overrides only keys enUS has, keeping each value's shape, specifiers and markup", function()
				local ns = {}
				load(addon, "enUS", "esES", ns)
				local english = copy(ns.L)
				load(addon, "esES", "esES", ns)

				local problems = {}
				compare(english, ns.L, "L", problems)
				assert.are.same({}, problems)
			end)

			it("changes nothing on another locale", function()
				local ns = {}
				load(addon, "enUS", "enUS", ns)
				local english = copy(ns.L)
				load(addon, "esES", "enUS", ns)

				assert.are.same(english, ns.L)
			end)
		end)
	end
end)
