-- The shipped Russian Locale, ruRU (DATA-R104, DATA-R114, CORE-R8, CORE-R9, ADR 0019): machine-drafted for 1.1, with
-- no human translator yet. It is not listed (listing needs 100% of the interface and an approval from a native
-- speaker), so the Language setting cannot apply it; these specs load the real generated files under the real
-- Registry.lua and Apply.lua, once by driving ApplyLocale (what a player cannot do yet) and once as it will load when
-- the maintainer flips `listed`: a copy of the shipped ruRU.lua with only that flag changed. As a non-Latin Locale it is
-- offered only on a ruRU client (ns.CanRenderLanguage), whose own fonts Core then draws with (logic/Fonts.lua).

local TRANSLATED = { key = "CARD_CASTS", english = "Casts", russian = "Забросы" }
local NBSP = "\194\160" -- U+00A0, Russian's thousands separator in the header
-- A Ledger Lore key (DATA-R104), in English and in the shipped Lore.ruRU.lua.
local LORE = {
	key = "species.6362.blurb",
	english = "Stubborn on the line, sweet on the plate.",
	russian = "Упряма на леске, сладка на тарелке.",
}

-- The shipped Core locale file with `listed = false` changed to `listed = true`, in a temporary file; it is removed.
---@param action fun(path: string)
local function withListedCopy(action)
	local text = readFile("addons/Pagle/locale/ruRU.lua")
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

describe("ruRU as shipped, unlisted", function()
	it("is never applied by the Language setting, on any client", function()
		for _, client in ipairs({ "enUS", "ruRU" }) do
			for _, setting in ipairs({ "ruRU", "default" }) do
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

	it("is not offered in the Language dropdown, nor credited", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		for _, choice in ipairs(loaded.ns.LanguageChoices("ruRU")) do
			assert.are_not.equal("ruRU", choice.value)
		end
		assert.is_nil(loaded.ns.TranslatorCredits("ruRU"))
	end)

	it("names no translator: it is machine-drafted", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)

		local info = assert(loaded.ns.LocaleInfo("ruRU"))
		assert.are.equal("Русский", info.name)
		assert.is_true(info.translators == nil or #info.translators == 0)
	end)

	it("covers every key of each addon's English, with the Russian rule's four forms", function()
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

			local _, errors = loaded.ns.ApplyLocale("ruRU")

			assert.are.same({}, errors, addon)
			local written = {}
			-- Only the chosen Locale writes, so what it wrote is what the registration holds; reading it again from
			-- the file keeps the check independent of Apply.lua.
			local chunk = assert(loadstring(readFile("addons/" .. addon .. "/locale/ruRU.lua")))
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
					assert(type(value.few) == "string", addon .. " " .. key)
					assert(type(value.many) == "string", addon .. " " .. key)
				end
			end
		end
	end)

	it("applies when ApplyLocale is driven directly, with Russian's plural rule and separators", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local L = loaded.ns.L
		assert.are.equal(TRANSLATED.english, L[TRANSLATED.key])

		local record, errors = loaded.ns.ApplyLocale("ruRU")

		assert.are.same({}, errors)
		assert.are.equal(TRANSLATED.russian, L[TRANSLATED.key])
		assert.are.equal(",", record.decimal)
		assert.are.equal(NBSP, record.thousands)
		-- CLDR ru: one ends in 1 but not 11, few in 2–4 but not 12–14, many the other whole numbers, a fraction other.
		for n, category in pairs({
			[0] = "many",
			[1] = "one",
			[2] = "few",
			[4] = "few",
			[5] = "many",
			[11] = "many",
			[12] = "many",
			[14] = "many",
			[21] = "one",
			[22] = "few",
			[101] = "one",
			[111] = "many",
			[1234] = "few",
		}) do
			assert.are.equal(category, record.plural(n), n)
		end
		assert.are.equal("other", record.plural(1.5))
	end)
end)

describe("ruRU's Lore as shipped", function()
	it("registers a Module's Lore beside its interface text, and applies both", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		local L = loaded.ns.L
		assert.are.equal(LORE.english, L[LORE.key])

		loaded.ns.ApplyLocale("ruRU")

		assert.are.equal(LORE.russian, L[LORE.key])
		assert.are.equal("Рыболов", L.ANGLER_CRUMB)
	end)

	it("translates every Lore key English has, in each addon with Lore", function()
		for _, addon in ipairs({ "Pagle", "Pagle_Hunts", "Pagle_Ledger", "Pagle_Stats", "Pagle_TackleBoard" }) do
			local english, russian = {}, {}
			for _, pair in ipairs({ { "data/Lore.lua", english }, { "data/Lore.ruRU.lua", russian } }) do
				for key in readFile("addons/" .. addon .. "/" .. pair[1]):gmatch('\n\t*L%["([^"]+)"%] = ') do
					pair[2][key] = true
				end
			end
			assert(next(english) ~= nil, addon)
			for key in pairs(english) do
				assert(russian[key], addon .. " " .. key)
			end
		end
	end)
end)

describe("ruRU once listed (a copy of the shipped file with listed = true)", function()
	-- Core over these SavedVariables on a client of `client`, with the copy standing for locale/ruRU.lua; the Ledger
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
			{ replace = { ["locale/ruRU.lua"] = path }, also = { "Pagle_Ledger" } }
		)
	end

	it("applies on a ruRU client, by the setting and on Game default", function()
		withListedCopy(function(path)
			for _, setting in ipairs({ "ruRU", "default" }) do
				local loaded = login(path, setting, "ruRU")

				assert.are.equal("ruRU", loaded.env.Pagle.GetLanguage(), setting)
				assert.are.equal(TRANSLATED.russian, loaded.ns.L[TRANSLATED.key], setting)
				assert.are.same({}, loaded.client.errors, setting)
			end
		end)
	end)

	it("is not applied on a client that cannot render Cyrillic, nor offered there", function()
		withListedCopy(function(path)
			local loaded = login(path, "ruRU", "enUS")

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.equal(TRANSLATED.english, loaded.ns.L[TRANSLATED.key])
			for _, choice in ipairs(loaded.ns.LanguageChoices("enUS")) do
				assert.are_not.equal("ruRU", choice.value)
			end
		end)
	end)

	it(
		"hands the text helper Russian's plural rule and separators, for Core and for a Module's counted string",
		function()
			withListedCopy(function(path)
				local loaded = login(path, "ruRU", "ruRU")
				local Text = loaded.env.Pagle.Text
				local catches = loaded.namespaces.Pagle_Ledger.L.CATCHES

				assert.are.equal("1" .. NBSP .. "234,5", Text("{n:n}", { n = 1234.5 }))
				assert.are.equal("1 улов", Text(catches, { count = 1 }))
				assert.are.equal("2 улова", Text(catches, { count = 2 }))
				assert.are.equal("5 уловов", Text(catches, { count = 5 }))
				assert.are.equal("11 уловов", Text(catches, { count = 11 }))
				assert.are.equal("21 улов", Text(catches, { count = 21 }))
				assert.are.equal("1" .. NBSP .. "234 улова", Text(catches, { count = 1234 }))
				assert.are.equal("1,5 улова", Text(catches, { count = 1.5 }), "other, a fraction")
			end)
		end
	)

	it("makes a Module follow Core: its own Russian, with the Lore beside it", function()
		withListedCopy(function(path)
			local loaded = login(path, "ruRU", "ruRU")

			assert.are.equal("Рыболов", loaded.namespaces.Pagle_Ledger.L.ANGLER_CRUMB)
			assert.are.equal(LORE.russian, loaded.namespaces.Pagle_Ledger.L[LORE.key])
			assert.are.same({}, loaded.client.errors)
		end)
	end)
end)
