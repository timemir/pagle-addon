-- The shipped Spanish Locale, esES (DATA-R104, DATA-R114, CORE-R8, ADR 0019, #528): fmartingr's translation of #510
-- converted to the 1.1 shape and filled for 1.1. The maintainer listed it for 1.1 before a second native speaker
-- reviewed it, so the Language setting applies it; these specs load the real generated files under the real
-- Registry.lua and Apply.lua, by the setting and by driving ApplyLocale. A translated key reads Spanish, and
-- since 1.1's fill the file has every interface key, so a key it lacks (one the spec adds to English) reads English.

-- A key from #510, and one of the 1.1 strings #510 never had, filled for 1.1 (machine-drafted, awaiting review).
local TRANSLATED = { key = "CARD_CASTS", english = "Casts", spanish = "Lances" }
local FILLED = { key = "LANGUAGE_RELOAD_NOW", english = "Reload now", spanish = "Recargar ahora" }
-- A key no Locale has: the spec puts it in English's table, so the overlay has nothing to write over it.
local ENGLISH_ONLY = { key = "SPEC_ENGLISH_ONLY", english = "Only in English" }

-- The shipped Core locale file, listed since the maintainer listed it for 1.1; `action` gets its path.
---@param action fun(path: string)
local function withListedCopy(action)
	local text = readFile("addons/Pagle/locale/esES.lua")
	local _, count = text:gsub("listed = true", "")
	assert.are.equal(1, count, "the shipped header says listed = true once")
	action("addons/Pagle/locale/esES.lua")
end

describe("esES as shipped, listed", function()
	it("applies by the setting on any client, and on Game default on an esES or esMX client only", function()
		for client, default in pairs({ enUS = "enUS", esES = "esES", esMX = "esES" }) do
			for setting, language in pairs({ esES = "esES", default = default }) do
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
				local expected = language == "esES" and TRANSLATED.spanish or TRANSLATED.english
				assert.are.equal(expected, loaded.ns.L[TRANSLATED.key], client .. " " .. setting)
			end
		end
	end)

	it("is offered in the Language dropdown, and credits fmartingr, the translator of #510", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		local offered = false
		for _, choice in ipairs(loaded.ns.LanguageChoices("enUS")) do
			offered = offered or (choice.value == "esES" and choice.label == "Español")
		end
		assert.is_true(offered)
		assert.are.equal("Translations: Español by fmartingr", loaded.ns.TranslatorCredits("enUS"))
	end)

	it("applies when ApplyLocale is driven directly: Spanish where it has text, English where it has none", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local L = loaded.ns.L
		assert.are.equal(TRANSLATED.english, L[TRANSLATED.key])
		assert.are.equal(FILLED.english, L[FILLED.key])
		L[ENGLISH_ONLY.key] = ENGLISH_ONLY.english

		local record, errors = loaded.ns.ApplyLocale("esES")

		assert.are.same({}, errors)
		assert.are.equal(TRANSLATED.spanish, L[TRANSLATED.key])
		assert.are.equal(FILLED.spanish, L[FILLED.key])
		assert.are.equal(ENGLISH_ONLY.english, L[ENGLISH_ONLY.key])
		-- CLDR es: one is exactly 1, many a non-zero whole multiple of a million, everything else other.
		assert.are.equal(",", record.decimal)
		assert.are.equal(".", record.thousands)
		assert.are.equal("one", record.plural(1))
		assert.are.equal("other", record.plural(0))
		assert.are.equal("other", record.plural(2))
		assert.are.equal("other", record.plural(1000000.5))
		assert.are.equal("many", record.plural(1000000))
		assert.are.equal("many", record.plural(3000000))
	end)

	it("registers a Module's Lore beside its interface text, and applies both", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local L = loaded.ns.L
		assert.are.equal("Stubborn on the line, sweet on the plate.", L["species.6362.blurb"])

		loaded.ns.ApplyLocale("esES")

		assert.are.equal("Terco en el sedal, dulce en el plato.", L["species.6362.blurb"])
		assert.are.equal("El Pescador", L.ANGLER_CRUMB)
	end)
end)

describe("esES listed, as shipped", function()
	-- Core over these SavedVariables on a client of `client`, with the shipped locale/esES.lua; the Ledger
	-- loads after it, as the client loads a Module, following Core's choice.
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
			{ replace = { ["locale/esES.lua"] = path }, also = { "Pagle_Ledger" } }
		)
	end

	it("shows Spanish for #510's keys and for the keys filled for 1.1, when the setting is esES", function()
		withListedCopy(function(path)
			local loaded = login(path, "esES", "enUS")

			assert.are.equal("esES", loaded.env.Pagle.GetLanguage())
			assert.are.equal(TRANSLATED.spanish, loaded.ns.L[TRANSLATED.key])
			assert.are.equal(FILLED.spanish, loaded.ns.L[FILLED.key])
			assert.are.same({}, loaded.client.errors)
		end)
	end)

	it(
		"hands the text helper Spanish's plural rule and separators, for Core and for a Module's counted string",
		function()
			withListedCopy(function(path)
				local loaded = login(path, "esES", "enUS")
				local Text = loaded.env.Pagle.Text
				local catches = loaded.namespaces.Pagle_Ledger.L.ANGLER_CATCHES

				assert.are.equal("1.234,5", Text("{n:n}", { n = 1234.5 }))
				assert.are.equal("1 Captura", Text(catches, { count = 1 }))
				assert.are.equal("1.234 Capturas", Text(catches, { count = 1234 }))
				assert.are.equal("2.000.000 Capturas", Text(catches, { count = 2000000 }), "many, a copy of other")
			end)
		end
	)

	it("serves an esMX client on Game default, with Core's Spanish", function()
		withListedCopy(function(path)
			local loaded = login(path, "default", "esMX")

			assert.are.equal("esES", loaded.env.Pagle.GetLanguage())
			assert.are.equal(TRANSLATED.spanish, loaded.ns.L[TRANSLATED.key])
			assert.are.equal(FILLED.spanish, loaded.ns.L[FILLED.key])
		end)
	end)

	it("makes a Module follow Core: its own Spanish, with the Lore beside it", function()
		withListedCopy(function(path)
			local loaded = login(path, "esES", "enUS")
			local L = loaded.namespaces.Pagle_Ledger.L

			assert.are.equal("El Pescador", L.ANGLER_CRUMB)
			assert.are.equal("Terco en el sedal, dulce en el plato.", L["species.6362.blurb"])
			assert.are.same({}, loaded.client.errors)
		end)
	end)
end)
