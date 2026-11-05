-- Locale registration and the one locale line every addon carries (DATA-R114, CORE-R8, ADR 0019): locale/Registry.lua
-- gives `ns.Locale` and `ns.ApplyLocale`, locale/Locales.xml lists the generated locale files between the two stable
-- entries, and locale/Apply.lua makes a Module follow Core's Language. Core's choice of Language is in
-- spec/Pagle/adapter/Language_spec.lua.

local GUARD =
	"if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)\n\treturn\nend\n\n"
local ADDONS = { "Pagle", "Pagle_Hunts", "Pagle_Ledger", "Pagle_QoL", "Pagle_Stats", "Pagle_TackleBoard" }

---@param path string
---@return string
local function read(path)
	return readFile(path)
end

-- A fresh addon namespace with Registry.lua loaded into it, and an English `L` for it to overlay.
---@return table ns
local function registry()
	local ns = { L = { GREETING = "Hello", FAREWELL = "Goodbye", DEEP = "Deep" } }
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile("addons/Pagle/locale/Registry.lua"))
	-- Registry.lua reads no global: an empty environment proves it.
	setfenv(
		chunk,
		setmetatable({
			error = error,
			pcall = pcall,
			type = type,
			tostring = tostring,
			table = table,
			ipairs = ipairs,
			select = select,
		}, {
			__index = function(_, name)
				error("Registry.lua read the global " .. tostring(name))
			end,
		})
	)
	chunk("Pagle", ns)
	return ns
end

-- The `<Script file>` entries of a Locales.xml, in order, comments removed.
---@param xml string
---@return string[]
local function locales(xml)
	local scripts = {}
	for script in xml:gsub("<!%-%-.-%-%->", ""):gmatch('<Script%s+file="([^"]+)"') do
		scripts[#scripts + 1] = script
	end
	return scripts
end

-- A file's text, or nil when there is none.
---@param path string
---@return string?
local function readFileOrNil(path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local file = io.open(path, "r")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

-- The three fields a Locale gives the text helper.
---@param decimal string?
---@return table
local function whole(decimal)
	return {
		name = "Test",
		listed = true,
		plural = function()
			return "other"
		end,
		decimal = decimal or ",",
		thousands = ".",
	}
end

describe("the locale line of every addon (ADR 0019)", function()
	for _, addon in ipairs(ADDONS) do
		describe(addon, function()
			local dir = "addons/" .. addon .. "/"

			it("lists locale\\Locales.xml once, right after the Lore (or the string table, with none)", function()
				local files = addonFiles(addon)
				local at, count = {}, 0
				for index, file in ipairs(files) do
					at[file] = index
					if file == "locale/Locales.xml" then
						count = count + 1
					end
				end

				assert.are.equal(1, count)
				local before = at["data/Lore.lua"] and "data/Lore.lua" or "locale/enUS.lua"
				assert.are.equal(at[before] + 1, at["locale/Locales.xml"])
				-- The scripts it loads follow it in addonFiles, and nothing of the TOC's own order moves.
				assert.are.equal("locale/Registry.lua", files[at["locale/Locales.xml"] + 1])
			end)

			it("carries no per-language TOC line: no Title-xx, Notes-xx or locale file named in it", function()
				local toc = read(dir .. addon .. ".toc")

				assert.is_nil(toc:find("Title%-%a%a"))
				assert.is_nil(toc:find("Notes%-%a%a"))
				for line in toc:gmatch("[^\r\n]+") do
					local code = line:match("^locale\\(%l%l%u%u)%.lua")
					assert(code == nil or code == "enUS", line)
					assert(line:match("^data\\Lore%.%a+%.lua") == nil, line)
				end
			end)

			it("ships Core's Registry.lua and Apply.lua, a Module's behind the CORE-R11 guard", function()
				-- Every Module file starts with the guard; Core's cannot, as `Pagle` does not exist while Core loads.
				-- Its class is its own too: no two addons' `ns` share a type for the types stage to merge.
				local guard = addon == "Pagle" and "" or GUARD
				local class = addon == "Pagle" and "PagleNS" or (addon:gsub("_", "") .. "NS")
				for _, file in ipairs({ "Registry.lua", "Apply.lua" }) do
					local core =
						read("addons/Pagle/locale/" .. file):gsub("%-%-%-@class PagleNS", "---@class " .. class)
					assert.are.equal(guard .. core, read(dir .. "locale/" .. file), file)
				end
			end)

			it(
				"lists deDE's, esES's and ruRU's locale files, each with its Lore where it has one, between Registry.lua and Apply.lua",
				function()
					-- The generator writes the list from the files an addon has (DATA-R114), so a Lore entry is there
					-- exactly where `data/Lore.<code>.lua` is: the files differ by addon, and QoL has no Lore.
					local expected = { "Registry.lua" }
					for _, code in ipairs({ "deDE", "esES", "ruRU" }) do
						expected[#expected + 1] = code .. ".lua"
						if readFileOrNil(dir .. "data/Lore." .. code .. ".lua") then
							expected[#expected + 1] = "..\\data\\Lore." .. code .. ".lua"
						end
					end
					expected[#expected + 1] = "Apply.lua"

					assert.are.same(expected, locales(read(dir .. "locale/Locales.xml")))
				end
			)
		end)
	end

	it("registers deDE, esES and ruRU listed in every addon, as the maintainer listed them (deDE for 1.1.1)", function()
		for code, name in pairs({ deDE = "Deutsch", esES = "Español", ruRU = "Русский" }) do
			for _, addon in ipairs(ADDONS) do
				local ns = registry()
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
				local chunk = assert(loadfile("addons/" .. addon .. "/locale/" .. code .. ".lua"))
				setfenv(chunk, setmetatable({ Pagle = {} }, { __index = _G }))

				chunk(addon, ns)

				local info = assert(ns.LocaleInfo(code), addon)
				assert.are.equal(true, info.listed, addon)
				assert.are.equal(name, info.name, addon)
			end
		end
		-- No other language is shipped: the codes a locale file or a Lore file may carry are deDE, esES and ruRU.
		for _, addon in ipairs(ADDONS) do
			for _, script in ipairs(locales(read("addons/" .. addon .. "/locale/Locales.xml"))) do
				local code = script:match("(%a%a%u%u)%.lua$")
				assert(code == nil or code == "deDE" or code == "esES" or code == "ruRU", script)
			end
		end
	end)
end)

describe("ns.Locale (DATA-R114)", function()
	it("only records: nothing is written into ns.L until the Locale is applied", function()
		local ns = registry()
		local ran = false

		ns.Locale("deDE", function(L)
			ran = true
			L.GREETING = "Hallo"
		end, whole())

		assert.is_false(ran)
		assert.are.equal("Hello", ns.L.GREETING)
	end)

	it("reports what is registered, a fresh table each time, and nothing for what is not", function()
		local ns = registry()
		ns.Locale("deDE", function() end, { name = "Deutsch", listed = false, fallback = "frFR", decimal = "," })

		local info = ns.LocaleInfo("deDE")
		assert.are.same({ code = "deDE", name = "Deutsch", listed = false, fallback = "frFR" }, info)
		assert.are_not.equal(info, ns.LocaleInfo("deDE"))
		assert.is_nil(ns.LocaleInfo("frFR"))
		assert.is_nil(ns.LocaleInfo("enUS"))
		assert.is_nil(ns.LocaleInfo(nil))
		assert.is_nil(ns.LocaleInfo(12))
	end)

	it("reports the translators the opts gave, as a copy, and none when it gave none", function()
		local ns = registry()
		local opts = whole()
		opts.translators = { "Ana", "Luis" }
		ns.Locale("esES", function() end, opts)
		ns.Locale("deDE", function() end, whole())
		ns.Locale(
			"frFR",
			function() end,
			{ name = "F", listed = true, translators = {}, plural = opts.plural, decimal = ",", thousands = "." }
		)

		local info = assert(ns.LocaleInfo("esES"))
		assert.are.same({ "Ana", "Luis" }, info.translators)
		info.translators[1] = "Changed"
		assert.are.same({ "Ana", "Luis" }, ns.LocaleInfo("esES").translators)
		assert.is_nil(ns.LocaleInfo("deDE").translators)
		assert.is_nil(ns.LocaleInfo("frFR").translators)
	end)

	it("takes a second call for the same code as another function, with no opts", function()
		local ns = registry()
		ns.Locale("deDE", function(L)
			L.GREETING = "Hallo"
		end, whole())
		ns.Locale("deDE", function(L)
			L.DEEP = "Tief"
		end)

		ns.ApplyLocale("deDE")

		assert.are.equal("Hallo", ns.L.GREETING)
		assert.are.equal("Tief", ns.L.DEEP)
	end)

	it("counts a code registered only by a Lore-style call as not registered, until its opts arrive", function()
		local ns = registry()
		ns.Locale("deDE", function(L)
			L.DEEP = "Tief"
		end)

		assert.is_nil(ns.LocaleInfo("deDE"))
		assert.is_nil(ns.ApplyLocale("deDE"))
		assert.are.equal("Deep", ns.L.DEEP)
	end)

	it("takes the opts on a later call than the first, for a Lore file that loads before the interface", function()
		local ns = registry()
		ns.Locale("deDE", function(L)
			L.DEEP = "Tief"
		end)
		ns.Locale("deDE", function(L)
			L.GREETING = "Hallo"
		end, whole())

		assert.is_table(ns.LocaleInfo("deDE"))
		ns.ApplyLocale("deDE")
		assert.are.equal("Tief", ns.L.DEEP)
		assert.are.equal("Hallo", ns.L.GREETING)
	end)

	describe("refuses a bad call, raising and registering nothing", function()
		local cases = {
			["a code that is not a string"] = function(ns)
				ns.Locale(12, function() end, whole())
			end,
			["an empty code"] = function(ns)
				ns.Locale("", function() end, whole())
			end,
			["enUS, which is built in"] = function(ns)
				ns.Locale("enUS", function() end, whole())
			end,
			["no function"] = function(ns)
				ns.Locale("deDE", nil, whole())
			end,
			["opts given twice"] = function(ns)
				ns.Locale("deDE", function() end, whole())
				ns.Locale("deDE", function() end, whole())
			end,
			["opts that are not a table"] = function(ns)
				ns.Locale("deDE", function() end, "opts")
			end,
			["no name"] = function(ns)
				local opts = whole()
				opts.name = nil
				ns.Locale("deDE", function() end, opts)
			end,
			["an empty name"] = function(ns)
				local opts = whole()
				opts.name = ""
				ns.Locale("deDE", function() end, opts)
			end,
			["listed that is not a boolean"] = function(ns)
				local opts = whole()
				opts.listed = "yes"
				ns.Locale("deDE", function() end, opts)
			end,
			["no listed"] = function(ns)
				local opts = whole()
				opts.listed = nil
				ns.Locale("deDE", function() end, opts)
			end,
			["a fallback that is its own code"] = function(ns)
				local opts = whole()
				opts.fallback = "deDE"
				ns.Locale("deDE", function() end, opts)
			end,
			["enUS as the fallback"] = function(ns)
				local opts = whole()
				opts.fallback = "enUS"
				ns.Locale("deDE", function() end, opts)
			end,
			["a plural that is not a function"] = function(ns)
				local opts = whole()
				opts.plural = "one"
				ns.Locale("deDE", function() end, opts)
			end,
			["an empty decimal"] = function(ns)
				ns.Locale("deDE", function() end, whole(""))
			end,
			["thousands that is not a string"] = function(ns)
				local opts = whole()
				opts.thousands = 1
				ns.Locale("deDE", function() end, opts)
			end,
			["translators that is not a table"] = function(ns)
				local opts = whole()
				opts.translators = "Ana"
				ns.Locale("deDE", function() end, opts)
			end,
			["a translator that is not a name"] = function(ns)
				local opts = whole()
				opts.translators = { "Ana", "" }
				ns.Locale("deDE", function() end, opts)
			end,
			["no plural rule and no fallback"] = function(ns)
				local opts = whole()
				opts.plural = nil
				ns.Locale("deDE", function() end, opts)
			end,
			["no decimal and no fallback"] = function(ns)
				local opts = whole()
				opts.decimal = nil
				ns.Locale("deDE", function() end, opts)
			end,
			["no thousands and no fallback"] = function(ns)
				local opts = whole()
				opts.thousands = nil
				ns.Locale("deDE", function() end, opts)
			end,
		}
		for name, call in pairs(cases) do
			it(name, function()
				local ns = registry()

				assert.has_error(function()
					call(ns)
				end)
				if name ~= "opts given twice" then
					assert.is_nil(ns.LocaleInfo("deDE"))
					assert.is_nil(ns.ApplyLocale("deDE"))
				end
			end)
		end

		it("but keeps what the first call registered when a second call's opts are refused", function()
			local ns = registry()
			ns.Locale("deDE", function(L)
				L.GREETING = "Hallo"
			end, whole())
			assert.has_error(function()
				ns.Locale("deDE", function(L)
					L.GREETING = "Servus"
				end, whole())
			end)

			ns.ApplyLocale("deDE")

			assert.are.equal("Hallo", ns.L.GREETING)
		end)
	end)
end)

describe("ns.ApplyLocale (DATA-R114)", function()
	it(
		"writes the Locale into ns.L in place: a table cached before sees it, and a missing key stays English",
		function()
			local ns = registry()
			local cached = ns.L
			ns.Locale("deDE", function(L)
				L.GREETING = "Hallo"
			end, whole())

			local record = ns.ApplyLocale("deDE")

			assert.are.equal(cached, ns.L)
			assert.are.equal("Hallo", cached.GREETING)
			assert.are.equal("Goodbye", cached.FAREWELL)
			assert.are.equal(",", record.decimal)
			assert.are.equal(".", record.thousands)
			assert.are.equal("other", record.plural(2))
		end
	)

	it("applies the fallback's functions before the Locale's, and its record under the Locale's own", function()
		local ns = registry()
		local order = {}
		ns.Locale("esMX", function(L)
			order[#order + 1] = "esMX"
			L.GREETING = "Que onda"
		end, { name = "Mexico", listed = true, fallback = "esES", decimal = "." })
		ns.Locale("esES", function(L)
			order[#order + 1] = "esES"
			L.GREETING = "Hola"
			L.FAREWELL = "Adios"
		end, whole())

		local record = ns.ApplyLocale("esMX")

		assert.are.same({ "esES", "esMX" }, order)
		assert.are.equal("Que onda", ns.L.GREETING)
		assert.are.equal("Adios", ns.L.FAREWELL)
		assert.are.equal(".", record.decimal, "the Locale's own separator")
		assert.are.equal(".", record.thousands, "the fallback's")
	end)

	it("runs a Locale's functions in the order they were registered", function()
		local ns = registry()
		ns.Locale("deDE", function(L)
			L.GREETING = "first"
		end, whole())
		ns.Locale("deDE", function(L)
			L.GREETING = L.GREETING .. " second"
		end)

		ns.ApplyLocale("deDE")

		assert.are.equal("first second", ns.L.GREETING)
	end)

	it("applies a fallback whether or not it is listed", function()
		local ns = registry()
		local base = whole()
		base.listed = false
		ns.Locale("esES", function(L)
			L.FAREWELL = "Adios"
		end, base)
		ns.Locale("esMX", function() end, { name = "Mexico", listed = true, fallback = "esES" })

		ns.ApplyLocale("esMX")

		assert.are.equal("Adios", ns.L.FAREWELL)
	end)

	it("applies what a chain holds when its fallback is not registered, if the Locale is whole", function()
		local ns = registry()
		local opts = whole()
		opts.fallback = "xxNone"
		ns.Locale("deDE", function(L)
			L.GREETING = "Hallo"
		end, opts)

		assert.is_table(ns.ApplyLocale("deDE"))
		assert.are.equal("Hallo", ns.L.GREETING)
	end)

	it(
		"applies nothing for a chain with no plural rule or separators, a loop, or a code that is not registered",
		function()
			for _, code in ipairs({ "incomplete", "loopA", "loopB", "missing", "enUS" }) do
				local ns = registry()
				ns.Locale("incomplete", function(L)
					L.GREETING = "!"
				end, { name = "I", listed = true, fallback = "xxNone", decimal = "," })
				ns.Locale("loopA", function(L)
					L.GREETING = "A"
				end, { name = "A", listed = true, fallback = "loopB", decimal = "," })
				ns.Locale("loopB", function(L)
					L.GREETING = "B"
				end, { name = "B", listed = true, fallback = "loopA", decimal = "," })

				local record, errors = ns.ApplyLocale(code)

				assert(record == nil, code)
				assert.are.same({}, errors)
				assert.are.equal("Hello", ns.L.GREETING, code)
			end
		end
	)

	it("returns the message of a function that raises, skips it and runs the rest", function()
		local ns = registry()
		ns.Locale("deDE", function()
			error("boom")
		end, whole())
		ns.Locale("deDE", function(L)
			L.GREETING = "Hallo"
		end)

		local record, errors = ns.ApplyLocale("deDE")

		assert.is_table(record)
		assert.are.equal(1, #errors)
		assert.matches("boom", errors[1])
		assert.are.equal("Hallo", ns.L.GREETING)
	end)

	it("applies once: a later call changes nothing and answers as the first did", function()
		local ns = registry()
		ns.Locale("deDE", function(L)
			L.GREETING = "Hallo"
		end, whole())
		ns.Locale("frFR", function(L)
			L.GREETING = "Bonjour"
		end, whole())

		local first = ns.ApplyLocale("deDE")
		local second = ns.ApplyLocale("frFR")

		assert.are.equal(first, second)
		assert.are.equal("Hallo", ns.L.GREETING)
	end)

	it("applies nothing, and does not count as applied, where there is no ns.L (a Module off Forever)", function()
		local ns = registry()
		ns.L = nil
		ns.Locale("deDE", function() end, whole())

		assert.is_nil(ns.ApplyLocale("deDE"))
		ns.L = { GREETING = "Hello" }
		assert.is_table(ns.ApplyLocale("deDE"))
	end)
end)

describe("locale/Apply.lua", function()
	-- Runs the file in `ns`, with `core` as the Pagle global (nil for none).
	---@param ns table
	---@param core any
	local function apply(ns, core)
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
		local chunk = assert(loadfile("addons/Pagle_Ledger/locale/Apply.lua"))
		local env = setmetatable({ Pagle = core }, { __index = _G })
		env._G = env
		setfenv(chunk, env)
		chunk("Pagle_Ledger", ns)
	end

	it("applies the Locale Pagle.GetLanguage names", function()
		local applied
		apply({
			ApplyLocale = function(code)
				applied = code
			end,
		}, {
			GetLanguage = function()
				return "esES"
			end,
		})

		assert.are.equal("esES", applied)
	end)

	it(
		"does nothing before Core has a Language (Core's own copy), off Forever, or on a Core without the call",
		function()
			local ns = {
				ApplyLocale = function()
					error("applied")
				end,
			}

			assert.has_no_error(function()
				apply(ns, nil)
				apply(ns, {})
				apply(ns, "Pagle")
			end)
		end
	)
end)
