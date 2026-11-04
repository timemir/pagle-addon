-- The shipped Spanish Locale, esES (DATA-R104, DATA-R114, CORE-R8, ADR 0019, #528): fmartingr's translation of #510
-- converted to the 1.1 shape. It is not listed (listing needs 100% of the interface and a second native speaker), so
-- the Language setting cannot apply it; these specs load the real generated files under the real Registry.lua and
-- Apply.lua, once by driving ApplyLocale (what a player cannot do yet) and once as it will load when the maintainer
-- flips `listed`: a copy of the shipped esES.lua with only that flag changed. A translated key reads Spanish, a key
-- the file lacks reads English.

-- A key the Spanish has, and one it lacks. LANGUAGE_RELOAD_NOW is a 1.1 string #510 never had, so it stays English
-- whatever a translator adds for the keys listed as dropped.
local TRANSLATED = { key = "CARD_CASTS", english = "Casts", spanish = "Lances" }
local UNTRANSLATED = { key = "LANGUAGE_RELOAD_NOW", english = "Reload now" }

-- The shipped Core locale file with `listed = false` changed to `listed = true`, in a temporary file; it is removed.
---@param action fun(path: string)
local function withListedCopy(action)
	local text = readFile("addons/Pagle/locale/esES.lua")
	local listed, count = text:gsub("listed = false", "listed = true")
	assert.are.equal(1, count, "the shipped header says listed = false once")
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io or os
	local path = os.tmpname()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io or os
	local file = assert(io.open(path, "w"))
	file:write(listed)
	file:close()
	local ok, err = pcall(action, path)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io or os
	os.remove(path)
	assert(ok, err)
end

describe("esES as shipped, unlisted", function()
	it("is never applied by the Language setting, on any client", function()
		for _, client in ipairs({ "enUS", "esES", "esMX" }) do
			for _, setting in ipairs({ "esES", "default" }) do
				local loaded = loadAddon(
					"Pagle",
					foreverWith({
						GetLocale = function()
							return client
						end,
						PagleDB = { global = { language = setting } },
					})
				)

				assert.are.equal("enUS", loaded.env.Pagle.GetLanguage(), client .. " " .. setting)
				assert.are.equal(TRANSLATED.english, loaded.ns.L[TRANSLATED.key], client .. " " .. setting)
			end
		end
	end)

	it("is not offered in the Language dropdown", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		for _, choice in ipairs(loaded.ns.LanguageChoices("esES")) do
			assert.are_not.equal("esES", choice.value)
		end
		-- An unlisted Locale is not credited either.
		assert.is_nil(loaded.ns.TranslatorCredits("esES"))
	end)

	it("applies when ApplyLocale is driven directly: Spanish where it has text, English where it has none", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local L = loaded.ns.L
		assert.are.equal(TRANSLATED.english, L[TRANSLATED.key])

		local record, errors = loaded.ns.ApplyLocale("esES")

		assert.are.same({}, errors)
		assert.are.equal(TRANSLATED.spanish, L[TRANSLATED.key])
		assert.are.equal(UNTRANSLATED.english, L[UNTRANSLATED.key])
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

describe("esES once listed (a copy of the shipped file with listed = true)", function()
	-- Core over these SavedVariables on a client of `client`, with the copy standing for locale/esES.lua; the Ledger
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

	it("shows Spanish for a translated key and English for one it lacks, when the setting is esES", function()
		withListedCopy(function(path)
			local loaded = login(path, "esES", "enUS")

			assert.are.equal("esES", loaded.env.Pagle.GetLanguage())
			assert.are.equal(TRANSLATED.spanish, loaded.ns.L[TRANSLATED.key])
			assert.are.equal(UNTRANSLATED.english, loaded.ns.L[UNTRANSLATED.key])
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
			assert.are.equal(UNTRANSLATED.english, loaded.ns.L[UNTRANSLATED.key])
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
