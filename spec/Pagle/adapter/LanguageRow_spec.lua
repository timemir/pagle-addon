-- The Settings root's Language row (SET-R10 row 9b, SET-R13, CORE-R8, ADR 0019): the choices it offers, what a pick
-- stores, and the Reload now note a change asks with. The Locales are fixtures registered here under real client
-- codes, since the dropdown looks the ten client codes up (ns.LANGUAGE_CODES): none ships in this build, so it
-- offers only Game default and English.

local PLURAL = function()
	return "other"
end

-- Registers a fixture Locale in `ns`, the way a generated locale file does.
---@param ns table
---@param code string
---@param name string The Locale's own name.
---@param listed boolean
local function register(ns, code, name, listed)
	ns.Locale(code, function() end, { name = name, listed = listed, plural = PLURAL, decimal = ",", thousands = "." })
end

-- Every Locale the spec registers: a Latin one listed, a Latin one not, the other Latin ones, and each non-Latin one
-- listed. Registered in no particular order: the dropdown's order is its own.
local FIXTURES = {
	{ "zhTW", "繁體中文", true },
	{ "ruRU", "Русский", true },
	{ "frFR", "Français", false },
	{ "deDE", "Deutsch", true },
	{ "koKR", "한국어", true },
	{ "esES", "Español", true },
	{ "zhCN", "简体中文", true },
}

-- Core on a client of locale `client`, logged in, with the fixture Locales registered when `withLocales` and
-- `saved` in PagleDB.global.language.
---@param client string?
---@param withLocales boolean?
---@param saved string?
---@return LoadedAddon
local function core(client, withLocales, saved)
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			GetLocale = function()
				return client or "enUS"
			end,
			PagleDB = saved and { global = { language = saved } } or nil,
		})
	)
	if withLocales then
		for _, fixture in ipairs(FIXTURES) do
			register(loaded.ns, fixture[1], fixture[2], fixture[3])
		end
	end
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The Language row on the root, the row before it (Clock) and the root.
local function languageRow(loaded)
	local root = loaded.client.settings.category("Pagle")
	local initializers = root.layout.initializers
	for n, initializer in ipairs(initializers) do
		if initializer:GetName() == "Language" then
			return initializer, initializers[n - 1], root
		end
	end
	error("no Language row on the root")
end

-- Picks `value` in the dropdown, as the panel does.
local function pick(loaded, value)
	local row = languageRow(loaded)
	row:GetSetting():SetValue(value)
end

-- The dropdown's choices as "value label", in order.
local function choices(loaded)
	local list = {}
	for i, option in ipairs(languageRow(loaded).data.options()) do
		list[i] = option.value .. " " .. option.label
	end
	return list
end

-- The Reload now note Core drew, or nil before the first ask.
local function note(loaded)
	return loaded.ns.reloadNote
end

-- Long enough for the note's fade out (0.15 s) to end and hide it.
local FADE_OUT = 0.2

describe("The Language dropdown's choices", function()
	it("sits under Units after Clock, with its label, tooltip and no default (SET-R10 row 9b, SET-R13)", function()
		local row, clock = languageRow(core())

		assert.are.equal("Clock", clock:GetName())
		assert.are.same({ "Language", "SettingsDropdownControlTemplate" }, { row:GetName(), row.template })
		assert.are.equal(
			"The language Pagle is written in, on every character. A change takes effect after a /reload. Names the"
				.. " game supplies, such as items, zones and item quality, stay in the game's language.",
			row.data.tooltip
		)
		assert.is_nil(row:GetSetting():GetDefaultValue())
	end)

	it("offers Game default and English alone while no Locale is registered, as in the shipped build", function()
		assert.are.same({ "default Game default", "enUS English" }, choices(core()))
	end)

	it(
		"offers, on an enUS client, each listed Latin Locale by its own name and no unlisted or non-Latin one",
		function()
			-- deDE and esES listed, frFR not listed (a Latin one), and ruRU, koKR, zhCN and zhTW listed but in a script the
			-- bundled faces don't cover (ADR 0019, Q25).
			assert.are.same({
				"default Game default",
				"enUS English",
				"deDE Deutsch",
				"esES Español",
			}, choices(core("enUS", true)))
		end
	)

	it("offers a non-Latin Locale on its own client only, and the listed Latin ones as everywhere", function()
		for _, code in ipairs({ "ruRU", "koKR", "zhCN", "zhTW" }) do
			local own
			for _, fixture in ipairs(FIXTURES) do
				if fixture[1] == code then
					own = code .. " " .. fixture[2]
				end
			end
			assert.are.same(
				{ "default Game default", "enUS English", "deDE Deutsch", "esES Español", own },
				choices(core(code, true)),
				code .. " client: its own non-Latin Locale and no other"
			)
		end
	end)

	it("never offers an unlisted Locale, on its own client too (ADR 0019: once listed, always listed)", function()
		for _, list in ipairs({ choices(core("frFR", true)), choices(core("enUS", true)) }) do
			for _, choice in ipairs(list) do
				assert.is_nil(choice:find("frFR", 1, true))
			end
		end
	end)

	it("lists the Locales in a fixed order, whatever order they registered in", function()
		local loaded = core("enUS", false)
		for _, code in ipairs({ "esES", "deDE" }) do
			register(loaded.ns, code, code, true)
		end

		assert.are.same({ "default Game default", "enUS English", "deDE deDE", "esES esES" }, choices(loaded))
	end)

	it(
		"draws the choices from the registry each time the dropdown opens, so a Locale registered later shows",
		function()
			local loaded = core("enUS", false)
			assert.are.equal(2, #choices(loaded))

			register(loaded.ns, "deDE", "Deutsch", true)

			assert.are.same({ "default Game default", "enUS English", "deDE Deutsch" }, choices(loaded))
		end
	)
end)

describe("ns.CanRenderLanguage", function()
	it(
		"is the one place a non-Latin Locale's offer is decided: its own client only, until the font probe (#522)",
		function()
			local ns = core().ns

			assert.is_true(ns.CanRenderLanguage("deDE", "enUS"))
			assert.is_true(ns.CanRenderLanguage("esMX", "koKR"))
			assert.is_false(ns.CanRenderLanguage("ruRU", "enUS"))
			assert.is_false(ns.CanRenderLanguage("ruRU", "deDE"))
			assert.is_true(ns.CanRenderLanguage("ruRU", "ruRU"))
			assert.is_false(ns.CanRenderLanguage("zhCN", "zhTW"))
			assert.is_true(ns.CanRenderLanguage("zhTW", "zhTW"))
			assert.is_false(ns.CanRenderLanguage("koKR", nil))
		end
	)
end)

describe("The Language row's value", function()
	it("shows Game default while none is stored, and stores nothing for it (SET-R10 row 9b, catch-log.md)", function()
		local loaded = core("enUS", true)
		local setting = languageRow(loaded):GetSetting()

		assert.are.equal("default", setting:GetValue())
		setting:SetValue("deDE")
		setting:SetValue("default")

		assert.is_nil(loaded.env.PagleDB.global.language)
		assert.are.equal("default", setting:GetValue())
	end)

	it("stores a pick in PagleDB.global.language, account-wide, and shows it at once", function()
		local loaded = core("enUS", true)
		local setting = languageRow(loaded):GetSetting()

		setting:SetValue("deDE")
		local german = { loaded.env.PagleDB.global.language, setting:GetValue() }
		setting:SetValue("enUS")

		assert.are.same({ "deDE", "deDE" }, german)
		assert.are.same({ "enUS", "enUS" }, { loaded.env.PagleDB.global.language, setting:GetValue() })
		assert.is_nil(loaded.env.PagleDB.profiles.Default.language) -- not a profile's
	end)

	it("shows the stored pick on the next login", function()
		local loaded = core("enUS", true, "deDE")

		assert.are.equal("deDE", languageRow(loaded):GetSetting():GetValue())
	end)

	it("reads as Game default a stored value this client doesn't offer: unlisted, unregistered or non-Latin", function()
		for _, saved in ipairs({ "frFR", "xxXX", "ruRU" }) do
			local loaded = core("enUS", true, saved)

			assert.are.equal("default", languageRow(loaded):GetSetting():GetValue(), saved)
		end
		assert.are.equal("ruRU", languageRow(core("ruRU", true, "ruRU")):GetSetting():GetValue())
	end)

	it("changes nothing live: the strings, the plural rule and Pagle.GetLanguage stay as loaded (ADR 0019)", function()
		local loaded = core("enUS", true)
		local before = loaded.ns.L.SETTINGS_CLOCK

		pick(loaded, "deDE")

		assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
		assert.are.equal(before, loaded.ns.L.SETTINGS_CLOCK)
	end)
end)

describe("The Reload now note", function()
	it("opens when a different Language is picked, and not before, nor for the same pick again", function()
		local loaded = core("enUS", true)
		local setting = languageRow(loaded):GetSetting()
		assert.is_nil(note(loaded)) -- nothing asks at login

		setting:SetValue("default") -- already Game default
		assert.is_nil(note(loaded))
		setting:SetValue("deDE")

		local frame = assert(note(loaded))
		assert.is_true(frame:IsShown())
		assert.are.equal(0, loaded.client.reloads)
		assert.are.same({}, loaded.printed)
	end)

	it("asks in the language the session runs in, with Reload now and Later", function()
		local loaded = core("enUS", true)

		pick(loaded, "deDE")

		local texts = loaded.client.settings.textsOf(assert(note(loaded)))
		assert.are.same({ "Reload the interface to change the language?", "Reload now", "Later" }, texts)
	end)

	it("reloads only from a click on Reload now (QOL-R6's rule, kept in Core)", function()
		local loaded = core("enUS", true)
		pick(loaded, "deDE")
		local frame = assert(note(loaded))

		loaded.client.update(10) -- time passes
		loaded.client.fire("PLAYER_REGEN_ENABLED")
		assert.are.equal(0, loaded.client.reloads)
		frame.reload:Click()

		assert.are.equal(1, loaded.client.reloads)
	end)

	it("closes on Later without reloading, the pick stored", function()
		local loaded = core("enUS", true)
		pick(loaded, "deDE")
		local frame = assert(note(loaded))

		frame.later:Click()
		loaded.client.update(FADE_OUT)

		assert.is_false(frame:IsShown())
		assert.are.equal(0, loaded.client.reloads)
		assert.are.equal("deDE", loaded.env.PagleDB.global.language)
	end)

	it("closes on Esc without reloading", function()
		local loaded = core("enUS", true)
		pick(loaded, "deDE")
		local frame = assert(note(loaded))

		loaded.client.pressEscape()

		assert.is_false(frame:IsShown())
		assert.are.equal(0, loaded.client.reloads)
	end)

	it("opens again for the next change, and stays one frame while it is up", function()
		local loaded = core("enUS", true)
		local setting = languageRow(loaded):GetSetting()

		setting:SetValue("deDE")
		local first = assert(note(loaded))
		setting:SetValue("esES")
		assert.are.equal(first, note(loaded))
		first.later:Click()
		loaded.client.update(FADE_OUT)
		setting:SetValue("default")

		assert.is_true(first:IsShown())
	end)

	it("is a frame of Core's own: no entry in the game's StaticPopupDialogs, which taints its popups", function()
		local loaded = core("enUS", true)
		local before = {}
		for name in pairs(loaded.env.StaticPopupDialogs) do
			before[name] = true
		end

		pick(loaded, "deDE")

		for name in pairs(loaded.env.StaticPopupDialogs) do
			assert.are.equal(true, before[name], name)
		end
		assert.is_nil(loaded.client.popup)
	end)

	it("is the one place Core calls ReloadUI(), and only from Reload now's click", function()
		local calls = {}
		for _, path in ipairs(shippedFiles("addons/Pagle/")) do
			-- ApiInventory.lua lists every API name the probe checks, as strings.
			if not path:find("/libs/", 1, true) and not path:find("ApiInventory", 1, true) then
				local _, count = withoutComments(readFile(path)):gsub("%f[%w_]ReloadUI%f[^%w_]", "")
				if count > 0 then
					calls[path] = count
				end
			end
		end

		assert.are.same({ ["addons/Pagle/adapter/LanguageRow.lua"] = 1 }, calls)
		local code = withoutComments(readFile("addons/Pagle/adapter/LanguageRow.lua"))
		assert.truthy(code:find('note%.reload:SetScript%("OnClick", function%(%)%s*PlaySound%([^\n]*\n%s*ReloadUI%(%)'))
	end)
end)

describe("The root's Defaults button and the Language row (SET-R13)", function()
	it("leaves the Language as it is, and asks for no reload", function()
		local loaded = core("enUS", true)
		local row, _, root = languageRow(loaded)
		row:GetSetting():SetValue("deDE")
		note(loaded).later:Click()
		loaded.client.update(FADE_OUT)

		loaded.client.settings.defaults(root)
		loaded.client.update(FADE_OUT)

		assert.are.equal("deDE", loaded.env.PagleDB.global.language)
		assert.are.equal("deDE", row:GetSetting():GetValue())
		assert.is_false(note(loaded):IsShown())
		assert.are.equal(0, loaded.client.reloads)
	end)
end)
