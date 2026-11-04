-- The development pseudo-locale (#524, CORE-R8, CORE-R9, ADR 0019 "Scripts and fonts"): a runtime transform of the
-- English ns.L in Core's dev code (adapter/DevPseudo.lua) that pads each string by about 40%, swaps Latin letters for
-- accented and Cyrillic look-alikes and wraps it in [brackets], to show where a layout breaks before a real language is
-- offered. It leaves every {field}, `{{`, `}}`, colour code, texture, `|n`, `%` and slash word alone. `/pagle dev
-- pseudo on` saves PagleDB.global.devPseudo; Core applies it in its ADDON_LOADED, a Module through
-- `Pagle.ApplyPseudoLocale`. Every shipped string through the transform and the helper is spec/pseudo_locale_spec.lua's.

local FIXTURES = "spec/Pagle/fixtures/locale/"
local WITH_FIXTURES = {
	["locale/Locales.xml"] = FIXTURES .. "Locales.xml",
	["locale/Fixture.lua"] = FIXTURES .. "Fixture.lua",
}

-- The code points in `text`: every byte that is not a UTF-8 continuation byte.
---@param text string
---@return integer
local function points(text)
	local _, count = text:gsub("[^\128-\191]", "")
	return count
end

-- Core's namespace over these SavedVariables, ADDON_LOADED fired.
---@param db table?
---@param replace table?
---@return LoadedAddon
local function login(db, replace)
	return loadAddon("Pagle", foreverWith({ PagleDB = db }), { replace = replace })
end

local ON = { global = { dev = true, devPseudo = true } }

describe("the pseudo-locale's transform of one string", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
	local pseudo = ns.PseudoText

	it("wraps the string in brackets", function()
		local text = pseudo("Every catch tells a story")

		assert.are.equal("[", text:sub(1, 1))
		assert.are.equal("]", text:sub(-1))
	end)

	it("grows an ordinary string by at least 40% in code points, short ones too", function()
		for _, source in ipairs({
			"A",
			"Buy",
			"Cast",
			"Fish Journal",
			"Every catch tells a story",
			"Pagle is a small kit, not one big window. Each part has its own place.",
			"{fish} caught at {zone}",
		}) do
			assert.is_true(
				points(pseudo(source)) >= 1.4 * points(source),
				("%q grew to %q"):format(source, pseudo(source))
			)
		end
	end)

	it("swaps letters for accented ones and, for some, Cyrillic look-alikes, leaving no plain vowel", function()
		local text = pseudo("Copy the Pagle scope")

		assert.is_nil(text:sub(2):gsub("%]$", ""):find("[aeiouAEIOU]"))
		assert(text:find("[\208\209]"), "some letter is Cyrillic")
		assert(text:find("[\195-\197]"), "some letter is a Latin-1 or Latin Extended-A letter")
	end)

	it("writes the Cyrillic and accents from code points, so the Lua source holds no such character", function()
		-- CORE-R9: the pseudo-locale ships no file and needs no glyph range, so adapter/DevPseudo.lua stays in the
		-- base set (spec/glyphs_spec.lua checks it with every other file).
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local at = io.open("addons/Pagle/adapter/DevPseudo.lua", "rb")
		assert(at, "adapter/DevPseudo.lua")
		local source = at:read("*a")
		at:close()
		assert.is_nil(source:find("[\128-\255]"))
	end)

	it("keeps every {field}, with its spec, in place", function()
		local text = pseudo("{fish} at {weight:1} and {count:n} then {n:0}%")

		assert.is_truthy(text:find("{fish}", 1, true))
		assert.is_truthy(text:find("{weight:1}", 1, true))
		assert.is_truthy(text:find("{count:n}", 1, true))
		assert.is_truthy(text:find("{n:0}%", 1, true))
	end)

	it("keeps the brace escapes `{{` and `}}`", function()
		local text = pseudo("Write {{braces}} like this")

		assert.is_truthy(text:find("{{", 1, true))
		assert.is_truthy(text:find("}}", 1, true))
	end)

	it("keeps colour codes whole, hex letters included, and the text between them changes", function()
		local text = pseudo("Use |cffaabbccPagle|r now, or |cFF3E220Cthis|r")

		assert.is_truthy(text:find("|cffaabbcc", 1, true))
		assert.is_truthy(text:find("|cFF3E220C", 1, true))
		assert.are.equal(2, select(2, text:gsub("|r", "")))
		assert.is_nil(text:find("Pagle", 1, true))
		assert.is_nil(text:find("now", 1, true))
	end)

	it("keeps a texture escape whole, its path and coordinates included", function()
		local texture =
			"|TInterface\\AddOns\\Pagle_Ledger\\media\\journal\\LedgerParts:11:15:0:0:1024:2048:486:513:1586:1606|t"

		local text = pseudo("caught " .. texture .. " here")

		assert.is_truthy(text:find(texture, 1, true))
		assert.is_nil(text:find("caught", 1, true))
	end)

	it("keeps |n, || and a literal %, and changes the letters after them", function()
		local text = pseudo("50% done|nnext line || end")

		assert.is_truthy(text:find("50%", 1, true))
		assert.is_truthy(text:find("|n", 1, true))
		assert.is_truthy(text:find("||", 1, true))
		assert.is_nil(text:find("|nnext", 1, true))
		assert.is_nil(text:find("done", 1, true))
	end)

	it("keeps a link's payload and an atlas name whole", function()
		local text = pseudo("see |Hitem:6358::::|h[Oily Blackmouth]|h and |Aflag-icon|a now")

		assert.is_truthy(text:find("|Hitem:6358::::|h", 1, true))
		assert.is_truthy(text:find("|Aflag-icon|a", 1, true))
		assert.is_nil(text:find("Oily", 1, true))
	end)

	it("keeps a slash command word, which stays English (ADR 0019), but not a slash inside a word", function()
		local text = pseudo("Use /pagle guide or and/or more")

		assert.is_truthy(text:find("/pagle", 1, true))
		assert.is_nil(text:find("guide", 1, true))
		assert.is_nil(text:find("and/or", 1, true))
	end)

	it("leaves a string with no literal letter alone: a join, a symbol, a bare field, an icon", function()
		for _, source in ipairs({
			"",
			", ",
			" \194\183 ",
			"\195\151",
			"{a}/{b}",
			"{count:0}%",
			"|TInterface\\x:0|t",
			"|cff3e220c|r",
		}) do
			assert.are.equal(source, pseudo(source))
		end
		assert.are.equal(5, pseudo(5))
	end)

	it("is deterministic", function()
		assert.are.equal(pseudo("Catch {fish}"), pseudo("Catch {fish}"))
	end)
end)

describe("the pseudo-locale over a string table", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	local function table_()
		return {
			PLAIN = "Fish Journal",
			COUNTED = { one = "{count} fish", other = "{count} fishes" },
			NESTED = { deep = { "First line", "Second line" }, ["12h"] = { am = "{hour}:{minute} AM" } },
			GAP = ", ",
			DEV_TEST = "Pagle dev: untouched",
		}
	end

	it("changes the strings in place, forms of a counted string and nested ones included, keeping every key", function()
		local L = table_()
		local same = L
		local plain = ns.PseudoText("Fish Journal")

		assert.is_true(ns.PseudoLocalize(L))

		assert.are.equal(same, L)
		assert.are.equal(plain, L.PLAIN)
		assert.are.equal(ns.PseudoText("{count} fish"), L.COUNTED.one)
		assert.are.equal(ns.PseudoText("{count} fishes"), L.COUNTED.other)
		assert.are.equal(ns.PseudoText("Second line"), L.NESTED.deep[2])
		assert.are.equal(ns.PseudoText("{hour}:{minute} AM"), L.NESTED["12h"].am)
		assert.are.equal(", ", L.GAP)
	end)

	it("leaves the dev text English: a DEV_ key at the top", function()
		local L = table_()

		ns.PseudoLocalize(L)

		assert.are.equal("Pagle dev: untouched", L.DEV_TEST)
	end)

	it("applies once to a table: a second call changes nothing and says so", function()
		local L = table_()

		assert.is_true(ns.PseudoLocalize(L))
		local once = ns.PseudoText("Fish Journal")
		assert.is_false(ns.PseudoLocalize(L))

		assert.are.equal(once, L.PLAIN)
		assert.are.equal(ns.PseudoText("{count} fish"), L.COUNTED.one)
	end)
end)

describe("Core's pseudo-locale at ADDON_LOADED", function()
	it("is off by default: ns.L is English", function()
		local loaded = login()

		assert.are.equal("A collection worth keeping", loaded.ns.L.TRAILER_CAPTION_JOURNAL)
		assert.is_false(loaded.ns.pseudo)
	end)

	it("overlays ns.L in place, over English, when dev mode and the pseudo flag are both on", function()
		local cached
		local loaded = loadAddon("Pagle", foreverWith({ PagleDB = ON }), {
			beforeLoaded = {
				Pagle = function(ns)
					cached = ns.L
				end,
			},
		})

		assert.is_true(loaded.ns.pseudo)
		assert.are.equal(cached, loaded.ns.L)
		assert.are.equal(loaded.ns.PseudoText("A collection worth keeping"), cached.TRAILER_CAPTION_JOURNAL)
	end)

	it("needs dev mode: a saved flag with dev off applies nothing", function()
		for _, db in ipairs({
			{ global = { dev = false, devPseudo = true } },
			{ global = { devPseudo = true } },
			{ global = { dev = true } },
			{ global = { dev = true, devPseudo = "yes" } },
		}) do
			assert.are.equal("A collection worth keeping", login(db).ns.L.TRAILER_CAPTION_JOURNAL)
		end
	end)

	it("reads the raw PagleDB without raising on junk or a trap", function()
		local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
		local trap = setmetatable({}, {
			__index = function()
				error("PagleDB read through its metatable")
			end,
		})

		for name, saved in pairs({
			["no PagleDB"] = false,
			["not a table"] = 42,
			["global a string"] = { global = "junk" },
			["global a number"] = { global = 3 },
			["a trap"] = trap,
			["a trap global"] = { global = trap },
			["dev only"] = { global = { dev = true } },
			["pseudo only"] = { global = { devPseudo = true } },
			["pseudo a string"] = { global = { dev = true, devPseudo = "yes" } },
		}) do
			assert(ns.ReadPseudoSetting(saved or nil) == false, name)
		end
		assert.is_true(ns.ReadPseudoSetting(ON))
	end)

	it("keeps dev text in English", function()
		local loaded = login(ON)

		assert.are.equal("Pagle dev: dev commands are on.", loaded.ns.L.DEV_ON)
	end)

	it("keeps counted strings counted, with the helper still on English's rule", function()
		local ns = login(ON).ns
		local counted = ns.L.GUIDE_BOX_PARTS
		local fields = { words = "WORDS" }

		assert.is_table(counted)
		assert.is_truthy(counted.one:find("^%["))
		fields.count = 1
		assert.are.equal(ns.RenderText(counted.one, fields), ns.RenderText(counted, fields))
		fields.count = 2
		assert.are.equal(ns.RenderText(counted.other, fields), ns.RenderText(counted, fields))
		assert.are_not.equal(counted.one, counted.other)
	end)

	it("replaces the Language for the session: English is what it pads, and GetLanguage says enUS", function()
		local db = { global = { dev = true, devPseudo = true, language = "xxXX" } }
		local loaded = login(db, WITH_FIXTURES)

		assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
		assert.are.equal("enUS", loaded.ns.language)
		assert.are.equal(loaded.ns.PseudoText("Every catch tells a story"), loaded.ns.L.TRAILER_CAPTION_CATCH)
		assert.is_nil(loaded.ns.L.TRAILER_CAPTION_CATCH:find("[xx]", 1, true))
	end)

	it("brings the Language back with the flag off, the setting untouched", function()
		local db = { global = { dev = true, language = "xxXX" } }
		local loaded = login(db, WITH_FIXTURES)

		assert.are.equal("xxXX", loaded.env.Pagle.GetLanguage())
		assert.are.equal("[xx] catch", loaded.ns.L.TRAILER_CAPTION_CATCH)
	end)

	it("is never a choice: the Language dropdown and the Locale list are the same with it on", function()
		local off = login(nil, WITH_FIXTURES).ns
		local on = login(ON, WITH_FIXTURES).ns

		-- The labels are pseudo text too; the values, which the dropdown stores, are the same.
		for _, client in ipairs({ "enUS", "xxXX" }) do
			local values = {}
			for _, choice in ipairs(off.LanguageChoices(client)) do
				values[#values + 1] = choice.value
			end
			local pseudoValues = {}
			for _, choice in ipairs(on.LanguageChoices(client)) do
				pseudoValues[#pseudoValues + 1] = choice.value
			end
			assert.are.same(values, pseudoValues)
		end
		assert.is_nil(on.LocaleInfo("pseudo"))
		assert.is_nil(on.LocaleInfo("enUS"))
		for _, code in ipairs(on.LANGUAGE_CODES) do
			assert.is_nil(code:lower():find("pseudo", 1, true))
			assert.is_nil(code:find("^xx"))
		end
		assert.is_nil(on.TranslatorCredits("enUS"))
	end)

	it("is applied before anything prints: LOG_UNREADABLE is already padded", function()
		local log = savedLog()
		log.format = 5
		local loaded = loadAddon("Pagle", foreverWith({ PagleDB = ON, PagleLog = log }))

		assert.matches("^%[", loaded.printed[1])
		assert.matches("%]$", loaded.printed[1])
	end)
end)

describe("a Module's pseudo-locale", function()
	local ALSO = { also = { "Pagle_Ledger", "Pagle_QoL" } }

	it("is applied through Pagle.ApplyPseudoLocale when its files load, with the flag on", function()
		local loaded = loadAddon("Pagle", foreverWith({ PagleDB = ON }), ALSO)
		local english = loadAddon("Pagle", FOREVER_GLOBALS, ALSO)

		for _, addon in ipairs({ "Pagle_Ledger", "Pagle_QoL" }) do
			local plain = english.namespaces[addon].L
			local L = loaded.namespaces[addon].L
			local key = next(plain)
			while type(plain[key]) ~= "string" or not plain[key]:find("%a") do
				key = next(plain, key)
			end
			assert.are_not.equal(plain[key], L[key], addon)
			assert.are.equal(loaded.ns.PseudoText(plain[key]), L[key], addon)
		end
	end)

	it("leaves a Module's English alone with the flag off", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS, ALSO)
		local reference = loadAddon("Pagle", foreverWith({ PagleDB = { global = { dev = true } } }), ALSO)

		assert.are.same(reference.namespaces.Pagle_Ledger.L, loaded.namespaces.Pagle_Ledger.L)
	end)

	it("answers false from Pagle.ApplyPseudoLocale with the flag off, and changes nothing", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local L = { KEY = "Text" }

		assert.is_false(loaded.env.Pagle.ApplyPseudoLocale(L))
		assert.are.equal("Text", L.KEY)
	end)

	it("applies a table once through Pagle.ApplyPseudoLocale", function()
		local loaded = loadAddon("Pagle", foreverWith({ PagleDB = ON }))
		local L = { KEY = "Text" }

		assert.is_true(loaded.env.Pagle.ApplyPseudoLocale(L))
		local once = L.KEY
		assert.is_false(loaded.env.Pagle.ApplyPseudoLocale(L))

		assert.are.equal(loaded.ns.PseudoText("Text"), once)
		assert.are.equal(once, L.KEY)
	end)
end)

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

describe("/pagle dev pseudo", function()
	local function ready(saved)
		return enterWorld(loadCore({ BUILD_ENTRY }, saved), 2)
	end

	it("saves the flag in PagleDB.global.devPseudo and asks for a /reload, in English", function()
		local loaded = ready()
		pagle(loaded, "dev on")

		pagle(loaded, "dev pseudo on")
		assert.is_true(loaded.env.PagleDB.global.devPseudo)
		pagle(loaded, "dev pseudo OFF")

		assert.is_nil(loaded.env.PagleDB.global.devPseudo)
		assert.are.same({
			"Pagle dev: dev commands are on.",
			"Pagle dev: pseudo-locale on; /reload to see every string padded, accented and in brackets.",
			"Pagle dev: pseudo-locale off; /reload to go back to your language.",
		}, loaded.printed)
	end)

	it("changes nothing in this session: the text switches at the next /reload", function()
		local loaded = ready()
		pagle(loaded, "dev on")

		pagle(loaded, "dev pseudo on")

		assert.is_false(loaded.ns.pseudo)
		assert.are.equal("A collection worth keeping", loaded.ns.L.TRAILER_CAPTION_JOURNAL)
	end)

	it("says its usage for anything but on and off", function()
		local loaded = ready()
		pagle(loaded, "dev on")

		pagle(loaded, "dev pseudo")
		pagle(loaded, "dev pseudo maybe")

		assert.are.equal("Pagle dev: /pagle dev pseudo on | off", loaded.printed[2])
		assert.are.equal("Pagle dev: /pagle dev pseudo on | off", loaded.printed[3])
		assert.is_nil(loaded.env.PagleDB.global.devPseudo)
	end)

	it("is refused with one line while dev mode is off, changing nothing", function()
		local loaded = ready()

		pagle(loaded, "dev pseudo on")

		assert.are.same({ "Pagle dev: dev commands are off; /pagle dev on turns them on." }, loaded.printed)
		assert.is_nil(loaded.env.PagleDB.global.devPseudo)
	end)

	it("is cleared by /pagle dev off, so it never comes back with dev mode", function()
		local loaded = ready({ global = { dev = true, devPseudo = true } })

		pagle(loaded, "dev off")

		assert.is_nil(loaded.env.PagleDB.global.devPseudo)
		assert.are.same({
			"Pagle dev: dev commands are off.",
			"Pagle dev: pseudo-locale off; /reload to go back to your language.",
		}, loaded.printed)
	end)

	it("is in the dev usage line", function()
		local loaded = ready()
		pagle(loaded, "dev on")

		pagle(loaded, "dev nonsense")

		assert.is_truthy(loaded.printed[2]:find("| fonts | pseudo on | off | onboarding", 1, true))
	end)
end)
