-- The shipped German Locale, deDE (DATA-R104, DATA-R114, CORE-R8, CORE-R9, ADR 0019): machine-drafted for 1.1.1, with
-- no human translator yet. The maintainer listed it for 1.1.1 before a native speaker reviewed it; these specs load the
-- real generated files under the real Registry.lua and Apply.lua, by the setting and by driving ApplyLocale. As a Latin
-- Locale it is offered on every client, and Game default applies it on a deDE client.

local TRANSLATED = { key = "CARD_CASTS", english = "Casts", german = "Würfe" }
local CRUMB = "Der Angler" -- the Ledger's ANGLER_CRUMB in German

-- The shipped Core locale file, listed since the maintainer listed it for 1.1.1; `action` gets its path.
---@param action fun(path: string)
local function withListedCopy(action)
	local text = readFile("addons/Pagle/locale/deDE.lua")
	local _, count = text:gsub("listed = true", "")
	assert.are.equal(1, count, "the shipped header says listed = true once")
	action("addons/Pagle/locale/deDE.lua")
end

describe("deDE as shipped, listed", function()
	it("applies by the setting on any client, and on Game default on a deDE client only", function()
		for client, default in pairs({ enUS = "enUS", deDE = "deDE", esES = "esES" }) do
			for setting, language in pairs({ deDE = "deDE", default = default }) do
				local loaded = loadAddon(
					"Pagle",
					foreverWith({
						GetLocale = function()
							return client
						end,
						PagleDB = { global = { language = setting } },
					})
				)

				assert.are.equal(language, loaded.env.Pagle.GetLanguage(), client .. " " .. setting)
				if language ~= "esES" then
					local expected = language == "deDE" and TRANSLATED.german or TRANSLATED.english
					assert.are.equal(expected, loaded.ns.L[TRANSLATED.key], client .. " " .. setting)
				end
			end
		end
	end)

	it("is offered in the Language dropdown on a Latin client, and credits nobody", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		local function offered(client)
			for _, choice in ipairs(loaded.ns.LanguageChoices(client)) do
				if choice.value == "deDE" then
					return choice.label
				end
			end
		end
		assert.are.equal("Deutsch", offered("enUS"))
		assert.are.equal("Deutsch", offered("deDE"))
		-- Machine-drafted, it has no translator: the line credits only esES's.
		assert.are.equal("Translations: Español by fmartingr", loaded.ns.TranslatorCredits("deDE"))
	end)

	it("names no translator: it is machine-drafted", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		local info = assert(loaded.ns.LocaleInfo("deDE"))
		assert.are.equal("Deutsch", info.name)
		assert.is_true(info.translators == nil or #info.translators == 0)
	end)

	it("covers every key of each addon's English, with the German rule's two forms", function()
		for _, addon in ipairs({
			"Pagle",
			"Pagle_Hunts",
			"Pagle_Ledger",
			"Pagle_QoL",
			"Pagle_Stats",
			"Pagle_TackleBoard",
		}) do
			local loaded = loadAddon(addon, FOREVER_GLOBALS)
			local L = loaded.ns.L
			local english = {}
			for key in pairs(L) do
				english[key] = true
			end

			local _, errors = loaded.ns.ApplyLocale("deDE")

			assert.are.same({}, errors, addon)
			local written = {}
			-- Only the chosen Locale writes, so what it wrote is what the registration holds; reading it again from
			-- the file keeps the check independent of Apply.lua.
			local chunk = assert(loadstring(readFile("addons/" .. addon .. "/locale/deDE.lua")))
			setfenv(chunk, setmetatable({ Pagle = {} }, { __index = _G }))
			chunk(addon, {
				Locale = function(_, fill)
					fill(written)
				end,
			})
			for key in pairs(english) do
				if not key:find("%.") then -- Lore keys ("species.6362.blurb") are optional and checked by the generator
					assert(written[key] ~= nil, addon .. " " .. key)
				end
			end
			for key, value in pairs(written) do
				if type(value) == "table" and value.other and value.one then
					assert(value.few == nil and value.many == nil, addon .. " " .. key)
				end
			end
		end
	end)

	it("applies when ApplyLocale is driven directly, with German's plural rule and separators", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local L = loaded.ns.L
		assert.are.equal(TRANSLATED.english, L[TRANSLATED.key])

		local record, errors = loaded.ns.ApplyLocale("deDE")

		assert.are.same({}, errors)
		assert.are.equal(TRANSLATED.german, L[TRANSLATED.key])
		assert.are.equal(",", record.decimal)
		assert.are.equal(".", record.thousands)
		-- CLDR de: one is exactly 1, everything else other.
		for n, category in pairs({ [0] = "other", [1] = "one", [2] = "other", [21] = "other", [1000] = "other" }) do
			assert.are.equal(category, record.plural(n), n)
		end
		assert.are.equal("other", record.plural(1.5))
	end)
end)

describe("deDE listed, as shipped", function()
	-- Core over these SavedVariables on a client of `client`, with the shipped locale/deDE.lua; the Ledger loads after
	-- it, as the client loads a Module, following Core's choice.
	---@param path string
	---@param setting any
	---@param client string
	---@return LoadedAddon
	local function login(path, setting, client)
		return loadAddon(
			"Pagle",
			foreverWith({
				GetLocale = function()
					return client
				end,
				PagleDB = setting ~= nil and { global = { language = setting } } or nil,
			}),
			{ replace = { ["locale/deDE.lua"] = path }, also = { "Pagle_Ledger" } }
		)
	end

	it("applies on a deDE client by the setting and on Game default, and on an enUS client by the setting", function()
		withListedCopy(function(path)
			for _, case in ipairs({ { "deDE", "deDE" }, { "default", "deDE" }, { "deDE", "enUS" } }) do
				local loaded = login(path, case[1], case[2])

				assert.are.equal("deDE", loaded.env.Pagle.GetLanguage(), case[1] .. " " .. case[2])
				assert.are.equal(TRANSLATED.german, loaded.ns.L[TRANSLATED.key], case[1] .. " " .. case[2])
				assert.are.same({}, loaded.client.errors, case[1] .. " " .. case[2])
			end
		end)
	end)

	it(
		"hands the text helper German's plural rule and separators, for Core and for a Module's counted string",
		function()
			withListedCopy(function(path)
				local loaded = login(path, "deDE", "deDE")
				local Text = loaded.env.Pagle.Text
				local catches = loaded.namespaces.Pagle_Ledger.L.CATCHES

				assert.are.equal("1.234,5", Text("{n:n}", { n = 1234.5 }))
				assert.are.equal("1 Fang", Text(catches, { count = 1 }))
				assert.are.equal("2 Fänge", Text(catches, { count = 2 }))
				assert.are.equal("0 Fänge", Text(catches, { count = 0 }))
				assert.are.equal("1.234 Fänge", Text(catches, { count = 1234 }))
				assert.are.equal("1,5 Fänge", Text(catches, { count = 1.5 }), "other, a fraction")
			end)
		end
	)

	it("makes a Module follow Core: its own German", function()
		withListedCopy(function(path)
			local loaded = login(path, "deDE", "deDE")

			assert.are.equal(CRUMB, loaded.namespaces.Pagle_Ledger.L.ANGLER_CRUMB)
			assert.are.same({}, loaded.client.errors)
		end)
	end)
end)
