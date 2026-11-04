-- The Language at load (CORE-R8, CORE-R10, SET-R10 row 9b, DATA-R114, ADR 0019): Core reads the setting from the raw
-- PagleDB in its ADDON_LOADED, ahead of everything that prints or publishes interface text, and overlays `ns.L` with
-- the chosen Locale; a Module applies Core's choice as its files load. The Locales here are made-up fixtures in
-- spec/Pagle/fixtures/locale/, listed by a stand-in locale/Locales.xml, never shipped.

local FIXTURES = "spec/Pagle/fixtures/locale/"
-- Replaces the shipped (empty) locale list with the fixtures', as the generator's list will stand in its place.
local WITH_FIXTURES = {
	["locale/Locales.xml"] = FIXTURES .. "Locales.xml",
	["locale/Fixture.lua"] = FIXTURES .. "Fixture.lua",
}
local WITH_ESMX = {
	["locale/Locales.xml"] = FIXTURES .. "LocalesWithMX.xml",
	["locale/Fixture.lua"] = FIXTURES .. "Fixture.lua",
	["locale/EsMX.lua"] = FIXTURES .. "EsMX.lua",
}

-- Core over these SavedVariables on a client of `client` locale, with the fixture Locales; ADDON_LOADED has fired.
---@param setting any The Language setting in PagleDB.global.language, or nil for none.
---@param client string? The client's GetLocale(), enUS by default.
---@param extra table? More globals, e.g. a PagleLog.
---@param replace table? The fixture files, WITH_FIXTURES by default.
---@return LoadedAddon
local function login(setting, client, extra, replace)
	local globals = foreverWith({
		GetLocale = function()
			return client or "enUS"
		end,
		PagleDB = setting ~= nil and { global = { language = setting } } or nil,
	})
	for key, value in pairs(extra or {}) do
		globals[key] = value
	end
	return loadAddon("Pagle", globals, { replace = replace or WITH_FIXTURES })
end

describe("the shipped locale list", function()
	it("registers esES unlisted: English is the only language a player can have until it is listed", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		-- fmartingr's Spanish (#510, #528): registered with its header, and never applied while `listed` is false.
		assert.are.same(
			{ code = "esES", name = "Español", listed = false, translators = { "fmartingr" } },
			loaded.ns.LocaleInfo("esES")
		)
		assert.is_nil(loaded.ns.LocaleInfo("deDE"))
		assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
		assert.are.equal("A collection worth keeping", loaded.ns.L.TRAILER_CAPTION_JOURNAL)
	end)
end)

describe("Core's Language at ADDON_LOADED", function()
	describe("overlaying ns.L", function()
		it(
			"writes the chosen Locale into ns.L in place, so a table cached before it sees the text (CORE-R8)",
			function()
				local cached
				local loaded = loadAddon("Pagle", foreverWith({ PagleDB = { global = { language = "xxXX" } } }), {
					replace = WITH_FIXTURES,
					beforeLoaded = {
						Pagle = function(ns)
							cached = ns.L
						end,
					},
				})

				assert.are.equal(cached, loaded.ns.L)
				assert.are.equal("[xx] catch", cached.TRAILER_CAPTION_CATCH)
				assert.are.equal("[xx] name", cached.TRAILER_CAPTION_NAME, "a second registration's function ran too")
				assert.are.equal("xxXX", loaded.env.Pagle.GetLanguage())
			end
		)

		it("keeps English for a string the Locale lacks", function()
			local loaded = login("xxXX")

			assert.are.equal("Every pursuit adds up", loaded.ns.L.TRAILER_CAPTION_XP)
		end)

		it("runs the fallback's functions first, then the Locale's, and merges their records", function()
			local loaded = login("xxYY")

			assert.are.equal("[yy] catch", loaded.ns.L.TRAILER_CAPTION_CATCH, "xxYY overlays xxXX")
			assert.are.equal("[xx] journal", loaded.ns.L.TRAILER_CAPTION_JOURNAL, "what xxYY lacks comes from xxXX")
			-- xxYY's decimal, xxXX's thousands and plural rule.
			assert.are.equal("1.234'5", loaded.env.Pagle.Text("{n:n}", { n = 1234.5 }))
			assert.are.equal("3 fews", loaded.env.Pagle.Text(loaded.ns.L.FIXTURE_COUNTED, { count = 3 }))
			assert.are.equal("xxYY", loaded.env.Pagle.GetLanguage())
		end)

		it("hands the text helper the Locale's plural rule and separators (DATA-R114)", function()
			local loaded = login("xxXX")

			assert.are.equal("3 fews", loaded.env.Pagle.Text(loaded.ns.L.FIXTURE_COUNTED, { count = 3 }))
			assert.are.equal("1 others", loaded.env.Pagle.Text(loaded.ns.L.FIXTURE_COUNTED, { count = 1 }))
			assert.are.equal("1.234,5", loaded.env.Pagle.Text("{n:n}", { n = 1234.5 }))
		end)

		it("reports a function that raises through the error handler, skips it and carries on", function()
			local loaded = login("xxER")

			assert.are.equal(1, #loaded.client.errors)
			assert.matches("this Locale's first function raises", loaded.client.errors[1])
			assert.are.equal("[er] catch", loaded.ns.L.TRAILER_CAPTION_CATCH)
			assert.is_function(loaded.env.Pagle.GetItem)
			assert.are.equal("xxER", loaded.env.Pagle.GetLanguage())
		end)
	end)

	describe("choosing the Locale", function()
		it("is English with no setting on an English client", function()
			local loaded = login(nil, "enUS")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal("Every catch tells a story", loaded.ns.L.TRAILER_CAPTION_CATCH)
			assert.are.equal("1,234.5", loaded.env.Pagle.Text("{n:n}", { n = 1234.5 }))
		end)

		it("is English when the setting says English, on a client whose own language is listed", function()
			local loaded = login("enUS", "xxXX")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal("Every catch tells a story", loaded.ns.L.TRAILER_CAPTION_CATCH)
		end)

		it("follows the client with Game default when the client's Locale is listed", function()
			for _, setting in ipairs({ "default" }) do
				assert.are.equal("xxXX", login(setting, "xxXX").env.Pagle.GetLanguage())
			end
			assert.are.equal("xxXX", login(nil, "xxXX").env.Pagle.GetLanguage(), "no setting is Game default")
		end)

		it("is English with Game default when the client's Locale is registered but not listed", function()
			local loaded = login("default", "xxZZ")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal("Every catch tells a story", loaded.ns.L.TRAILER_CAPTION_CATCH)
		end)

		it("is English with Game default when the client's Locale is not registered at all", function()
			assert.are.equal("enUS", login("default", "frFR").env.Pagle.GetLanguage())
		end)

		it("never applies an unlisted Locale chosen by the setting", function()
			local loaded = login("xxZZ", "xxZZ")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal("Every catch tells a story", loaded.ns.L.TRAILER_CAPTION_CATCH)
			assert.are.equal("1,234.5", loaded.env.Pagle.Text("{n:n}", { n = 1234.5 }))
		end)

		it("is English when the chosen code is not registered", function()
			local loaded = login("qqQQ", "xxXX")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal("Every catch tells a story", loaded.ns.L.TRAILER_CAPTION_CATCH)
		end)

		it("is English when the chain never gives a plural rule and both separators, and writes nothing", function()
			local loaded = login("xxFB")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal("Every catch tells a story", loaded.ns.L.TRAILER_CAPTION_CATCH)
		end)

		it("serves an esMX client with esES until a separate esMX exists", function()
			local loaded = login("default", "esMX")

			assert.are.equal("esES", loaded.env.Pagle.GetLanguage())
			assert.are.equal("[es] catch", loaded.ns.L.TRAILER_CAPTION_CATCH)
		end)

		it("serves esMX with its own Locale, over esES, once one exists", function()
			local loaded = login("default", "esMX", nil, WITH_ESMX)

			assert.are.equal("esMX", loaded.env.Pagle.GetLanguage())
			assert.are.equal("[mx] catch", loaded.ns.L.TRAILER_CAPTION_CATCH, "esMX overlays esES")
			assert.are.equal("[es] journal", loaded.ns.L.TRAILER_CAPTION_JOURNAL, "what esMX lacks comes from esES")
			-- esMX gives its own decimal; esES gives the thousands.
			assert.are.equal("1.234.5", loaded.env.Pagle.Text("{n:n}", { n = 1234.5 }))
		end)

		it("serves esES with esES, not esMX, on an esES client", function()
			assert.are.equal("esES", login("default", "esES", nil, WITH_ESMX).env.Pagle.GetLanguage())
		end)
	end)

	describe("reading the setting from the raw PagleDB", function()
		-- ns.ReadLanguageSetting takes whatever the client loaded, so a damaged file can't stop login.
		local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

		it("is the key PagleDB.global.language, with 'default' for Game default", function()
			assert.are.equal("language", ns.LANGUAGE_KEY)
			assert.are.equal("default", ns.LANGUAGE_GAME_DEFAULT)
			assert.are.equal("esES", ns.ReadLanguageSetting({ global = { language = "esES" } }))
		end)

		it("counts as Game default when PagleDB is absent, not a table, has no global or holds a wrong type", function()
			for name, saved in pairs({
				["nil"] = false,
				["a string"] = "junk",
				["a number"] = 7,
				["a boolean"] = true,
				["a function"] = function() end,
				["no global"] = {},
				["global a string"] = { global = "junk" },
				["global a number"] = { global = 3 },
				["language missing"] = { global = {} },
				["language a number"] = { global = { language = 5 } },
				["language a table"] = { global = { language = {} } },
				["language a boolean"] = { global = { language = true } },
				["language empty"] = { global = { language = "" } },
			}) do
				assert.are.equal("default", ns.ReadLanguageSetting(saved or nil), name)
			end
		end)

		it("ignores a metatable on PagleDB that would raise or answer", function()
			local trap = setmetatable({}, {
				__index = function()
					error("PagleDB read through its metatable")
				end,
			})

			assert.are.equal("default", ns.ReadLanguageSetting(trap))
			assert.are.equal("default", ns.ReadLanguageSetting({ global = trap }))
		end)

		it("lets login finish and give English when PagleDB is not a table, without raising", function()
			local loaded = loadAddon("Pagle", foreverWith({ PagleDB = false }), {
				replace = WITH_FIXTURES,
				holdAddonLoaded = true,
			})
			loaded.env.PagleDB = 42

			assert.has_no_error(function()
				loaded.ns.ApplyLanguage()
			end)
			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
		end)

		it("treats a setting of the wrong type as Game default, which follows a listed client", function()
			assert.are.equal("xxXX", login(5, "xxXX").env.Pagle.GetLanguage())
		end)
	end)

	describe("the order of Core's ADDON_LOADED (LOG-R1)", function()
		it(
			"applies before StartRecovery and OpenSavedVariables, and before the Size and Variety names publish",
			function()
				local seen = {}
				local loaded = loadAddon("Pagle", foreverWith({ PagleDB = { global = { language = "xxXX" } } }), {
					replace = WITH_FIXTURES,
					beforeLoaded = {
						Pagle = function(ns)
							local startRecovery, open = ns.StartRecovery, ns.OpenSavedVariables
							ns.StartRecovery = function(...)
								seen[#seen + 1] = "StartRecovery after " .. ns.language
								return startRecovery(...)
							end
							ns.OpenSavedVariables = function(...)
								seen[#seen + 1] = "OpenSavedVariables after " .. ns.language
								return open(...)
							end
							local publishSize = ns.PublishSizeAtLogin
							ns.PublishSizeAtLogin = function(...)
								seen[#seen + 1] = "PublishSizeAtLogin after " .. ns.language
								return publishSize(...)
							end
						end,
					},
				})

				assert.are.same({
					"PublishSizeAtLogin after xxXX",
					"StartRecovery after xxXX",
					"OpenSavedVariables after xxXX",
				}, seen)
				assert.is_function(loaded.env.Pagle.GetItem)
			end
		)

		it("prints LOG_UNREADABLE already in the chosen language", function()
			local log = savedLog()
			log.format = 5
			local loaded = login("xxYY", "enUS", { PagleLog = log })

			assert.are.equal(1, #loaded.printed)
			assert.matches("^%[yy%] unreadable %(", loaded.printed[1])
			assert.is_true(loaded.ns.recoveryBlocked)
		end)

		it("prints LOG_UNREADABLE in English with no Language, as before 1.1", function()
			local log = savedLog()
			log.format = 5
			local loaded = login(nil, "enUS", { PagleLog = log })

			assert.matches("^Pagle stopped: your Catch log can't be read", loaded.printed[1])
		end)

		it("publishes the Size band and Variety rarity names in the chosen language", function()
			local loaded = login("xxXX")
			local Pagle = loaded.env.Pagle

			assert.are.equal("Aa", Pagle.SIZE_BANDS[1].name)
			assert.are.equal("Ee", Pagle.SIZE_BANDS[5].name)
			assert.are.equal("tiddler", Pagle.SIZE_BANDS[1].key)
			assert.are.equal("Va", Pagle.VARIETY_RARITIES[1].name)
			assert.are.equal("Vd", Pagle.VARIETY_RARITIES[4].name)
		end)

		it("publishes the English names with no Language", function()
			local Pagle = login(nil, "enUS").env.Pagle

			assert.are.equal("Tiddler", Pagle.SIZE_BANDS[1].name)
			assert.are.equal("Common", Pagle.VARIETY_RARITIES[1].name)
		end)
	end)
end)

describe("a Module's Language at file load (CORE-R10)", function()
	local LEDGER = "spec/Pagle_Ledger/fixtures/locale/"
	local function ledger(setting, client)
		return loadAddon(
			"Pagle_Ledger",
			foreverWith({
				GetLocale = function()
					return client or "enUS"
				end,
				PagleDB = setting ~= nil and { global = { language = setting } } or nil,
			}),
			{
				replace = {
					["locale/Locales.xml"] = LEDGER .. "Locales.xml",
					["locale/Fixture.lua"] = LEDGER .. "Fixture.lua",
				},
				beforeLoaded = {
					-- Core's own Locales, the same Language to resolve (a dependency loads from the shipped files).
					Pagle = function(ns)
						ns.Locale("xxXX", function() end, {
							name = "Xxxx",
							listed = true,
							plural = function()
								return "other"
							end,
							decimal = ",",
							thousands = ".",
						})
						ns.Locale("xxYY", function() end, { name = "Yyyy", listed = true, fallback = "xxXX" })
					end,
				},
			}
		)
	end

	it("gets the Language Core chose, without reading PagleDB, and overlays its own ns.L in place", function()
		local loaded = ledger("xxXX")
		local Ledger = loaded.namespaces.Pagle_Ledger or loaded.ns

		assert.are.equal("xxXX", loaded.env.Pagle.GetLanguage())
		assert.are.equal("[xx] unfished", Ledger.L.UNFISHED)
		assert.are.equal("pools", Ledger.L.POOLS, "a string the Module's Locale lacks stays English")
	end)

	it("runs the fallback chain from its own registrations", function()
		local Ledger = ledger("xxYY").ns

		assert.are.equal("[xx] unfished", Ledger.L.UNFISHED)
		assert.are.equal("[yy] pools", Ledger.L.POOLS)
	end)

	it("stays in English when Core did, even for a Locale it has itself", function()
		-- xxZZ is unlisted in Core's resolution, so Core says English and the Module applies nothing.
		local Ledger = ledger("xxZZ").ns

		assert.are.equal("unfished", Ledger.L.UNFISHED)
	end)

	it("follows Game default on a listed client", function()
		assert.are.equal("[xx] unfished", ledger(nil, "xxXX").ns.L.UNFISHED)
	end)
end)
