-- A Locale's Lore (DATA-R104, DATA-R114, ADR 0019): addons/<Addon>/data/Lore.<code>.lua is a second `ns.Locale` function
-- for a code its interface file registered, applied after the interface's, and a key it lacks shows its English.
-- Two things are checked here. First, the English Lore.lua of each addon runs the way pagle-backend's Lore mode runs it
-- (PRJ-R18: `ns = { L = {} }`, a `Pagle = {}` global, plain Lua 5.1 globals, no GetLocale, no locale file loaded), so no
-- translation can have made it depend on one. Second, a generated fixture Lore.esES.lua (spec/fixtures/lore-locale/, the
-- generator's own output for a fixture tree, pinned by scripts/tests/test_lore_locale.py) runs under the real
-- locale/Registry.lua and locale/Apply.lua: a key it translates overlays, and a key it lacks stays English.

local LORE_ADDONS = { "Pagle", "Pagle_Hunts", "Pagle_Ledger", "Pagle_Stats", "Pagle_TackleBoard" }
local FIXTURE = "spec/fixtures/lore-locale/Lore.esES.lua"
-- The English Lore.lua the fixture translation is of (scripts/tests/test_lore.py pins it to the generator).
local ENGLISH_FIXTURE = "spec/Pagle_Ledger/fixtures/Lore.lua"

-- The Lua 5.1 globals pagle-backend's Lore mode gives a file: the pure functions and nothing of the client.
local PLAIN = {
	"assert",
	"error",
	"getmetatable",
	"ipairs",
	"math",
	"next",
	"pairs",
	"pcall",
	"rawequal",
	"rawget",
	"rawset",
	"select",
	"setmetatable",
	"string",
	"table",
	"tonumber",
	"tostring",
	"type",
	"unpack",
}

--- An environment of the plain globals, `Pagle`, and whatever else `extra` gives; reading any other global raises, as it
--- does in the backend (no GetLocale, no WoW name).
---@param extra table<string, any>?
---@return table
local function environment(extra)
	local given = {}
	for _, name in ipairs(PLAIN) do
		given[name] = _G[name]
	end
	for name, value in pairs(extra or {}) do
		given[name] = value
	end
	return setmetatable(given, {
		__index = function(_, name)
			error(tostring(name) .. " is not given to a Lore file", 2)
		end,
	})
end

--- Loads `path` into `env` and runs it as the client does: with the addon's name and its namespace.
---@param path string
---@param env table
---@param name string
---@param ns table
local function run(path, env, name, ns)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile(path))
	---@diagnostic disable-next-line: undefined-global -- ditto, setfenv
	setfenv(chunk, env)
	chunk(name, ns)
end

describe("the English Lore.lua, run the way pagle-backend's Lore mode runs it (PRJ-R18)", function()
	for _, addon in ipairs(LORE_ADDONS) do
		it(addon .. "/data/Lore.lua fills ns.L on its own, needing no locale file", function()
			local ns = { L = {} }

			run("addons/" .. addon .. "/data/Lore.lua", environment({ Pagle = {} }), addon, ns)

			assert.is_not_nil(next(ns.L))
			for key, value in pairs(ns.L) do
				assert.is_string(key)
				assert.is_string(value)
			end
		end)
	end
end)

describe("a Locale's Lore file (DATA-R104, DATA-R114)", function()
	-- The addon's own Registry.lua, loaded the way the client loads it, with an English L the fixture's Lore.lua filled.
	---@return table ns
	local function addon()
		local ns = { L = {} }
		run(ENGLISH_FIXTURE, environment({ Pagle = {} }), "Pagle_Ledger", ns)
		-- A Module's Registry.lua starts with Core's guard (CORE-R11), the one global it reads.
		run("addons/Pagle_Ledger/locale/Registry.lua", environment({ Pagle = {} }), "Pagle_Ledger", ns)
		return ns
	end

	-- What Pagle_Ledger's esES interface file registers (the fixture has no interface text of its own): the opts that make
	-- the code whole, which the Lore file's second call relies on.
	local function registerInterface(ns)
		ns.Locale("esES", function() end, {
			name = "Español",
			listed = true,
			plural = function(n)
				return n == 1 and "one" or "other"
			end,
			decimal = ",",
			thousands = ".",
		})
	end

	-- Locales.xml's order: the interface file, then the Lore file, then Apply.lua with Core's Language.
	---@param ns table
	---@param language string
	local function load(ns, language)
		registerInterface(ns)
		run(FIXTURE, environment({ Pagle = {} }), "Pagle_Ledger", ns)
		local pagle = {
			GetLanguage = function()
				return language
			end,
		}
		local env = environment({ Pagle = pagle })
		rawset(env, "_G", env)
		run("addons/Pagle_Ledger/locale/Apply.lua", env, "Pagle_Ledger", ns)
	end

	it("overlays a key it translates, and leaves English for a key it lacks", function()
		local ns = addon()
		assert.are.equal("Greenhorn", ns.L["title.level1.text"])
		assert.are.equal("Groupers", ns.L["family.1.name"])

		load(ns, "esES")

		assert.are.equal("Novato", ns.L["title.level1.text"])
		assert.are.equal("Maestro de {zone}", ns.L["title.zonemaster.text"])
		assert.are.equal("Pica donde el agua corre perezosa.", ns.L["species.13759.riddle"])
		-- Not in the fixture translation: still the English the Lore.lua wrote.
		assert.are.equal("Groupers", ns.L["family.1.name"])
		assert.are.equal("A snapper that keeps late hours.", ns.L["species.13759.blurb"])
		assert.are.equal("Nobody's seen it twice.", ns.L["legend.19807.blurb"])
	end)

	it("writes into ns.L in place, so a file that cached `local L = ns.L` sees it", function()
		local ns = addon()
		local cached = ns.L

		load(ns, "esES")

		assert.are.equal(cached, ns.L)
		assert.are.equal("El Sabrosón", cached["legend.19807.title"])
	end)

	it("changes nothing when another Language is chosen: only the chosen Locale's functions run", function()
		local ns = addon()

		load(ns, "enUS")

		assert.are.equal("Greenhorn", ns.L["title.level1.text"])
		assert.are.equal("Bites where the water runs lazy.", ns.L["species.13759.riddle"])
	end)

	it("does nothing alone: a Lore file whose interface file did not register the code is never applied", function()
		local ns = addon()
		run(FIXTURE, environment({ Pagle = {} }), "Pagle_Ledger", ns)

		assert.is_nil(ns.ApplyLocale("esES"))
		assert.are.equal("Greenhorn", ns.L["title.level1.text"])
	end)

	it("is skipped whole off Forever: without Pagle the file returns before it registers anything", function()
		-- No `ns.Locale` here: a file that got past its guard would raise.
		local ns = { L = {} }

		run(FIXTURE, environment({ Pagle = false }), "Pagle_Ledger", ns)

		assert.is_nil(ns.Locale)
	end)
end)
