-- The Settings root's Translations line (SET-R10 row 13, ADR 0019, Credits): one line after the Catch log row crediting
-- the translators of each listed language the client can render, and no row at all when none has translators. The
-- Locales are fixtures registered under real client codes, as spec/Pagle/adapter/LanguageRow_spec.lua does; none ships
-- in this build.

local PLURAL = function()
	return "other"
end

-- Registers a fixture Locale in `ns`, the way a generated locale file does.
---@param ns table
---@param code string
---@param name string The Locale's own name.
---@param listed boolean
---@param translators string[]?
local function register(ns, code, name, listed, translators)
	ns.Locale(code, function() end, {
		name = name,
		listed = listed,
		translators = translators,
		plural = PLURAL,
		decimal = ",",
		thousands = ".",
	})
end

-- Registered in no particular order: the line follows ns.LANGUAGE_CODES, the dropdown's order.
local FIXTURES = {
	{ "esES", "Español", true, { "Ana", "Luis" } },
	{ "ruRU", "Русский", true, { "Olga" } },
	{ "frFR", "Français", false, { "Camille" } }, -- not listed: not credited
	{ "itIT", "Italiano", true }, -- listed, nobody to credit
	{ "deDE", "Deutsch", true, { "Max" } },
}

-- Core on a client of locale `client`, logged in, with `fixtures` registered.
---@param client string?
---@param fixtures table[]?
---@return LoadedAddon
local function core(client, fixtures)
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			GetLocale = function()
				return client or "enUS"
			end,
		})
	)
	for _, fixture in ipairs(fixtures or {}) do
		register(loaded.ns, fixture[1], fixture[2], fixture[3], fixture[4])
	end
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The texts of Core's own text rows on the root, in order: the paragraph and note rows, the status list and the
-- Getting started rows, ending with the row under test when it is there.
---@param loaded LoadedAddon
---@return string[]
local function rowTexts(loaded)
	local texts = {}
	for _, row in ipairs(loaded.client.settings.show(assert(loaded.client.settings.category("Pagle")))) do
		if row.initializer:GetTemplate() == "PagleSettingsRowTemplate" then
			texts[#texts + 1] = loaded.client.settings.textsOf(row.frame)[1]
		end
	end
	return texts
end

-- The last row of the root and the one before it.
---@param loaded LoadedAddon
---@return string last
---@return string before
local function lastRows(loaded)
	local texts = rowTexts(loaded)
	return texts[#texts], texts[#texts - 1]
end

describe("The Translations line on the Settings root (SET-R10 row 13)", function()
	it(
		"credits each listed language that has translators, by its own name, in the order of the client codes",
		function()
			local last = lastRows(core("enUS", FIXTURES))

			assert.are.equal("Translations: Deutsch by Max; Español by Ana, Luis", last)
		end
	)

	it("sits after the Catch log row, as the last row of the root", function()
		local loaded = core("enUS", FIXTURES)
		local rows = loaded.client.settings.category("Pagle").layout.initializers

		assert.are.equal("Catch log", rows[#rows - 1]:GetName())
		assert.are.equal("PagleSettingsRowTemplate", rows[#rows]:GetTemplate())
	end)

	it("is not there while no language is registered, as in the shipped build", function()
		local loaded = core("enUS")
		local rows = loaded.client.settings.category("Pagle").layout.initializers

		assert.are.equal("Catch log", rows[#rows]:GetName())
		assert.is_nil(loaded.ns.TranslatorCredits("enUS"))
	end)

	it("is not there when no listed language has translators", function()
		local loaded = core("enUS", {
			{ "itIT", "Italiano", true },
			{ "frFR", "Français", false, { "Camille" } },
			{ "deDE", "Deutsch", true, {} },
		})
		local rows = loaded.client.settings.category("Pagle").layout.initializers

		assert.are.equal("Catch log", rows[#rows]:GetName())
		assert.is_nil(loaded.ns.TranslatorCredits("enUS"))
	end)

	it("leaves out a language the client cannot render, whole, and credits it on its own client", function()
		-- ruRU is listed and has Olga, but a Cyrillic Locale is only rendered on a ruRU client (ns.CanRenderLanguage).
		local last = lastRows(core("enUS", FIXTURES))
		assert.is_nil(last:find("Русский", 1, true))
		assert.is_nil(last:find("Olga", 1, true))

		assert.are.equal(
			"Translations: Deutsch by Max; Español by Ana, Luis; Русский by Olga",
			(lastRows(core("ruRU", FIXTURES)))
		)
	end)

	it("is not there when the only credited language is one the client cannot render", function()
		local loaded = core("enUS", { { "ruRU", "Русский", true, { "Olga" } } })
		local rows = loaded.client.settings.category("Pagle").layout.initializers

		assert.are.equal("Catch log", rows[#rows]:GetName())
	end)

	it("never credits an unlisted language, on its own client either", function()
		assert.is_nil(core("frFR", { { "frFR", "Français", false, { "Camille" } } }).ns.TranslatorCredits("frFR"))
	end)

	it("reads the names a Locale registered, as given by ns.LocaleInfo, and hands out a copy of them", function()
		local loaded = core("enUS", FIXTURES)
		local info = assert(loaded.ns.LocaleInfo("esES"))

		assert.are.same({ "Ana", "Luis" }, info.translators)
		info.translators[1] = "Changed"
		assert.are.same({ "Ana", "Luis" }, loaded.ns.LocaleInfo("esES").translators)
		assert.is_nil(loaded.ns.LocaleInfo("itIT").translators)
	end)

	it("is filled from the Locale's own template, so a translator can reorder its fields", function()
		local loaded = core("enUS", FIXTURES)
		loaded.ns.L.SETTINGS_TRANSLATIONS = "{credits} (translators)"
		loaded.ns.L.SETTINGS_TRANSLATIONS_ENTRY = "{names}: {language}"

		assert.are.equal("Max: Deutsch; Ana, Luis: Español (translators)", loaded.ns.TranslatorCredits("enUS"))
	end)

	it("joins the names, and the entries, with the Locale's own separators (#520)", function()
		local loaded = core("enUS", FIXTURES)
		loaded.ns.L.SETTINGS_TRANSLATIONS_NAMES_JOIN = " & "
		loaded.ns.L.SETTINGS_TRANSLATIONS_JOIN = " | "

		assert.are.equal("Translations: Deutsch by Max | Español by Ana & Luis", loaded.ns.TranslatorCredits("enUS"))
	end)
end)
