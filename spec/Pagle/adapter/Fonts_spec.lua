-- Core's faces on the client (CORE-R9, ADR 0019 "Scripts and fonts", #522): the bundled faces in a Latin language,
-- the client's own for ruRU, koKR, zhCN and zhTW, set again on Core's font objects once the Language applies at
-- ADDON_LOADED, and the same sizes in English as before. The four Locales are fixtures (spec/Pagle/fixtures/locale/).

local FIXTURES = "spec/Pagle/fixtures/locale/"
local WITH_NON_LATIN = {
	["locale/Locales.xml"] = FIXTURES .. "LocalesNonLatin.xml",
	["locale/NonLatin.lua"] = FIXTURES .. "NonLatin.lua",
}
local BUNDLED = "Interface\\AddOns\\Pagle\\media\\fonts\\"
local FALLBACK = "Fonts\\FRIZQT__.TTF"

-- Core logged in on a `client` locale with `setting` as the Language, its font objects kept in `made` by name. A
-- font file in `missing` is one the client doesn't have: SetFont gives false for it, as the client does.
---@param setting string?
---@param client string
---@param missing table<string, true>?
---@return LoadedAddon loaded
---@return table<string, table> made
local function core(setting, client, missing)
	local made = {}
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			GetLocale = function()
				return client
			end,
			PagleDB = setting and { global = { language = setting } } or nil,
			CreateFont = function(name)
				local font = { name = name }
				function font:SetFont(file, size, flags)
					self.font = { file, size, flags }
					return not (missing or {})[file]
				end
				font.SetTextColor = function() end
				font.SetShadowOffset = function() end
				font.SetShadowColor = function() end
				made[name] = font
				return font
			end,
		}),
		{ replace = WITH_NON_LATIN }
	)
	return loaded, made
end

describe("Core's faces", function()
	describe("in English", function()
		local loaded, made = core(nil, "enUS")

		it("draw with the bundled faces at the sizes they always had", function()
			assert.are.same({ BUNDLED .. "IMFeENrm28P.ttf", 16, "" }, made.PagleArtWhat.font)
			assert.are.same({ BUNDLED .. "Caveat-SemiBold.ttf", 31, "" }, made.PagleArtName.font)
			assert.are.same({ BUNDLED .. "Marcellus-Regular.ttf", 21, "" }, made.PagleArtKick.font)
			assert.are.same({ BUNDLED .. "IMFeENsc28P.ttf", 14, "" }, made.PagleArtSmallCaps.font)
			assert.are.same({ BUNDLED .. "IMFeENrm28P.ttf", 14, "" }, made.PagleShopTip.font)
			assert.are.same({ BUNDLED .. "CutiveMono-Regular.ttf", 12, "" }, loaded.ns.ArtFaceFont("mono", 12).font)
		end)

		it("are Pagle.FaceFile's answer to Modules", function()
			assert.are.equal(BUNDLED .. "Caveat-Bold.ttf", loaded.env.Pagle.FaceFile("Caveat-Bold.ttf"))
		end)
	end)

	for client, expect in pairs({
		ruRU = {
			body = "Fonts\\FRIZQT___CYR.TTF",
			heading = "Fonts\\FRIZQT___CYR.TTF",
			hand = "Fonts\\FRIZQT___CYR.TTF",
		},
		koKR = { body = "Fonts\\2002.ttf", heading = "Fonts\\2002B.ttf", hand = "Fonts\\K_Pagetext.TTF" },
		zhCN = { body = "Fonts\\ARKai_T.ttf", heading = "Fonts\\ARKai_T.ttf", hand = "Fonts\\ARKai_C.ttf" },
		zhTW = { body = "Fonts\\bHEI00M.ttf", heading = "Fonts\\bHEI01B.ttf", hand = "Fonts\\bKAI00M.ttf" },
	}) do
		describe("in " .. client, function()
			local loaded, made = core(nil, client)

			it("swap every font object Core made as its files loaded to the client's, at the same sizes", function()
				assert.are.same({ expect.body, 16, "" }, made.PagleArtWhat.font)
				assert.are.same({ expect.hand, 31, "" }, made.PagleArtName.font)
				assert.are.same({ expect.heading, 21, "" }, made.PagleArtKick.font)
				assert.are.same({ expect.body, 14, "" }, made.PagleArtSmallCaps.font)
				assert.are.equal(client, loaded.env.Pagle.GetLanguage())
				for name, font in pairs(made) do
					assert(not font.font[1]:find("media\\fonts", 1, true), name .. " still on a bundled face")
				end
			end)

			it("draw the faces made later in the client's too, and give Modules the same file", function()
				assert.are.equal(expect.hand, loaded.ns.ArtFaceFont("handBold", 20).font[1])
				assert.are.equal(expect.body, loaded.env.Pagle.FaceFile("IMFeENit28P.ttf"))
				assert.are.equal(expect.heading, loaded.env.Pagle.FaceFile("Marcellus-Regular.ttf"))
			end)
		end)
	end

	it("fall back to the locale's body for a client heading the client doesn't have", function()
		local _, made = core(nil, "koKR", { ["Fonts\\2002B.ttf"] = true })

		assert.are.same({ "Fonts\\2002.ttf", 21, "" }, made.PagleArtKick.font)
		assert.are.same({ "Fonts\\2002.ttf", 16, "" }, made.PagleArtWhat.font)
	end)

	it("stay bundled when a non-Latin Language is chosen on a client that can't render it", function()
		local loaded, made = core("ruRU", "enUS")

		assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
		assert.are.same({ BUNDLED .. "IMFeENrm28P.ttf", 16, "" }, made.PagleArtWhat.font)
	end)

	it("follow a chosen non-Latin Language on its own client", function()
		local loaded, made = core("ruRU", "ruRU")

		assert.are.equal("ruRU", loaded.env.Pagle.GetLanguage())
		assert.are.same({ "Fonts\\FRIZQT___CYR.TTF", 16, "" }, made.PagleArtWhat.font)
	end)

	it("stay the client's in English chosen on a non-Latin client, as the names it gives are in its script", function()
		for client, body in pairs({ koKR = "Fonts\\2002.ttf", ruRU = "Fonts\\FRIZQT___CYR.TTF" }) do
			local loaded, made = core("enUS", client)

			assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
			assert.are.same({ body, 16, "" }, made.PagleArtWhat.font, client)
			assert.are.equal(body, loaded.env.Pagle.FaceFile("IMFeENit28P.ttf"))
		end
	end)
end)

describe("ns.ResolveLanguage and the render rule (#522, SET-R10 row 9b)", function()
	local ns = core(nil, "enUS").ns

	it("gives English for a listed non-Latin Locale the client can't render", function()
		assert.are.equal("enUS", ns.ResolveLanguage("ruRU", "enUS"))
		assert.are.equal("enUS", ns.ResolveLanguage("zhCN", "zhTW"))
		assert.are.equal("enUS", ns.ResolveLanguage("koKR", nil))
	end)

	it("gives the Locale on its own client, and a Latin Locale anywhere", function()
		assert.are.equal("ruRU", ns.ResolveLanguage("ruRU", "ruRU"))
		assert.are.equal("zhTW", ns.ResolveLanguage("zhTW", "zhTW"))
	end)

	it("gives Game default's Locale on its own client", function()
		assert.are.equal("koKR", ns.ResolveLanguage("default", "koKR"))
		assert.are.equal("enUS", ns.ResolveLanguage("default", "enUS"))
	end)
end)

describe("the within-locale fallback (CORE-R9)", function()
	it("draws zhTW's body and heading in bKAI00M when the client has neither bHEI", function()
		local loaded, made = core(nil, "zhTW", { ["Fonts\\bHEI00M.ttf"] = true, ["Fonts\\bHEI01B.ttf"] = true })

		assert.are.same({ "Fonts\\bKAI00M.ttf", 16, "" }, made.PagleArtWhat.font)
		assert.are.same({ "Fonts\\bKAI00M.ttf", 21, "" }, made.PagleArtKick.font)
		assert.are.same({ "Fonts\\bKAI00M.ttf", 31, "" }, made.PagleArtName.font)
		local font = loaded.env.CreateFont("ModuleFont")
		assert.are.equal("Fonts\\bKAI00M.ttf", loaded.env.Pagle.SetFace(font, "Marcellus-Regular.ttf", 12))
	end)

	it("tries the heading next when only zhTW's body is missing", function()
		local _, made = core(nil, "zhTW", { ["Fonts\\bHEI00M.ttf"] = true })

		assert.are.same({ "Fonts\\bHEI01B.ttf", 16, "" }, made.PagleArtWhat.font)
	end)

	it("draws koKR's hand in 2002 and zhCN's in ARKai_T when the hand face is missing", function()
		local _, korean = core(nil, "koKR", { ["Fonts\\K_Pagetext.TTF"] = true })
		local _, chinese = core(nil, "zhCN", { ["Fonts\\ARKai_C.ttf"] = true })

		assert.are.same({ "Fonts\\2002.ttf", 31, "" }, korean.PagleArtName.font)
		assert.are.same({ "Fonts\\ARKai_T.ttf", 31, "" }, chinese.PagleArtName.font)
	end)

	it("draws ruRU's faces in ARIALN, its mono, before FRIZQT__, which has no Cyrillic", function()
		local _, made = core(nil, "ruRU", { ["Fonts\\FRIZQT___CYR.TTF"] = true })

		assert.are.same({ "Fonts\\ARIALN.TTF", 16, "" }, made.PagleArtWhat.font)
	end)

	it("falls back to FRIZQT__ only when none of the locale's faces loads", function()
		local loaded, made = core(nil, "zhTW", {
			["Fonts\\bHEI00M.ttf"] = true,
			["Fonts\\bHEI01B.ttf"] = true,
			["Fonts\\bKAI00M.ttf"] = true,
		})

		assert.are.same({ FALLBACK, 16, "" }, made.PagleArtWhat.font)
		local font = loaded.env.CreateFont("ModuleFont")
		assert.are.equal(FALLBACK, loaded.env.Pagle.SetFace(font, "Caveat-Bold.ttf", 12))
	end)

	it("keeps a bundled face's fallback FRIZQT__ on a Latin client", function()
		local _, made = core(nil, "enUS", { [BUNDLED .. "IMFeENrm28P.ttf"] = true })

		assert.are.same({ FALLBACK, 16, "" }, made.PagleArtWhat.font)
	end)
end)

-- The Modules whose strings are loaded alongside Core's below: every one that has a string table.
local MODULES = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" }
local MIDDLE_DOT = "\194\183"

-- Each string of `L` at any depth that holds `glyph`, as "KEY.form" paths.
---@param L table
---@param glyph string
---@return string[]
local function holding(L, glyph)
	local found, seen = {}, {}
	local function walk(t, path)
		seen[t] = true
		for key, value in pairs(t) do
			local here = path .. tostring(key)
			if type(value) == "string" and value:find(glyph, 1, true) then
				found[#found + 1] = here
			elseif type(value) == "table" and not seen[value] then
				walk(value, here .. ".")
			end
		end
	end
	walk(L, "")
	table.sort(found)
	return found
end

-- Core and every Module logged in on a `client` locale with `setting` as the Language, on the real Locales.
---@param setting string?
---@param client string
---@return LoadedAddon
local function withModules(setting, client)
	return loadAddon(
		"Pagle",
		foreverWith({
			GetLocale = function()
				return client
			end,
			PagleDB = setting and { global = { language = setting } } or nil,
		}),
		{ also = MODULES }
	)
end

describe("the client faces' glyphs (CORE-R9)", function()
	for _, setting in ipairs({ "enUS", "esES" }) do
		it("leave no U+00B7 in any string Core or a Module draws, in " .. setting .. " on a ruRU client", function()
			local loaded = withModules(setting, "ruRU")

			assert.are.equal(setting, loaded.env.Pagle.GetLanguage())
			for _, addon in ipairs({ "Pagle", unpack(MODULES) }) do
				assert.are.same({}, holding(loaded.namespaces[addon].L, MIDDLE_DOT), addon)
			end
		end)
	end

	it("draw the separator as the bullet there, which FRIZQT___CYR and ARIALN both have", function()
		local loaded = withModules("enUS", "ruRU")

		assert.are.equal(" \226\128\162 ", loaded.ns.L.SHOP_TAG_SEPARATOR)
		assert.are.equal(" \226\128\162 ", loaded.namespaces.Pagle_Hunts.L.TRACKER_JOIN)
		assert.are.equal("{name} \226\128\162 {band} \226\128\162 {length}", loaded.ns.L.CATCH_TOAST)
	end)

	it("stay as written on a client whose faces are Pagle's own", function()
		local english = withModules("enUS", "enUS")
		local spanish = withModules("esES", "deDE")

		assert.are.equal(" " .. MIDDLE_DOT .. " ", english.ns.L.SHOP_TAG_SEPARATOR)
		assert.are.equal(" " .. MIDDLE_DOT .. " ", english.namespaces.Pagle_Hunts.L.TRACKER_JOIN)
		assert.are_not.same({}, holding(spanish.ns.L, MIDDLE_DOT))
	end)

	for _, setting in ipairs({ "enUS", "esES", "deDE" }) do
		it("leave no guillemet, which no zhCN or zhTW face has, in any string drawn in " .. setting, function()
			for _, client in ipairs({ "zhCN", "zhTW" }) do
				local loaded = withModules(setting, client)

				assert.are.equal(setting, loaded.env.Pagle.GetLanguage())
				for _, addon in ipairs({ "Pagle", unpack(MODULES) }) do
					assert.are.same({}, holding(loaded.namespaces[addon].L, "\194\171"), addon)
					assert.are.same({}, holding(loaded.namespaces[addon].L, "\194\187"), addon)
				end
			end
		end)
	end

	it("draw a guillemet standing apart, an arrow, as the arrow's ASCII there", function()
		for _, client in ipairs({ "zhCN", "zhTW" }) do
			local english = withModules("enUS", client)
			local german = withModules("deDE", client)

			assert.are.equal("Next >", english.ns.L.GUIDE_NEXT, client)
			assert.are.equal("< back", english.namespaces.Pagle_Ledger.L.JOURNAL_BACK, client)
			assert.are.equal(">", english.namespaces.Pagle_Ledger.L.HOME_ANGLER_MARK, client)
			assert.are.equal("> Toast", english.ns.L.PREVIEW_TOAST, client)
			assert.are.equal(
				"Zieh jetzt Angelhut, Handschuhe und Rute an und drück dann den Knopf. Das geht auch später unter "
					.. "Einstellungen > Angeln.",
				german.namespaces.Pagle_QoL.L.GUIDE_SAVE_SMALL,
				client
			)
		end
	end)

	it("draw guillemets that hold words, quotation marks either way round, as the curly quotes there", function()
		for _, client in ipairs({ "zhCN", "zhTW" }) do
			local german = withModules("deDE", client)

			assert.are.equal("\226\128\156{riddle}\226\128\157", german.namespaces.Pagle_Ledger.L.ENTRY_RIDDLE, client)
			assert(
				german.ns.L.SETTINGS_CLOCK_TOOLTIP:find(" \226\128\156Wie im Spiel\226\128\157 nutzt ", 1, true),
				client
			)
		end
		local loaded = withModules("enUS", "zhCN")
		local L = {
			SPANISH = "Usa \194\171Como en el juego\194\187 y \194\171otra\194\187.",
			MIXED = "Ajustes \194\187 \194\171Pesca\194\187",
			PSEUDO = "[Next \194\187]",
		}

		assert.is_true(loaded.env.Pagle.ApplyClientGlyphs(L))
		assert.are.same({
			SPANISH = "Usa \226\128\156Como en el juego\226\128\157 y \226\128\156otra\226\128\157.",
			MIXED = "Ajustes > \226\128\156Pesca\226\128\157",
			PSEUDO = "[Next >]",
		}, L)
	end)

	it("change nothing on koKR, whose 2002 faces have every character the strings use", function()
		local korean = withModules("enUS", "koKR")
		local english = withModules("enUS", "enUS")

		assert.are.same(english.ns.L, korean.ns.L)
		assert.are.same(english.namespaces.Pagle_Hunts.L, korean.namespaces.Pagle_Hunts.L)
	end)

	it("are given to a Module's table through Pagle.ApplyClientGlyphs, which answers whether it changed one", function()
		local loaded = withModules("enUS", "ruRU")
		local L = { JOIN = " " .. MIDDLE_DOT .. " ", FORMS = { one = "a " .. MIDDLE_DOT .. " b" }, PLAIN = "text" }

		assert.is_true(loaded.env.Pagle.ApplyClientGlyphs(L))
		assert.are.same({ JOIN = " \226\128\162 ", FORMS = { one = "a \226\128\162 b" }, PLAIN = "text" }, L)
		assert.is_false(loaded.env.Pagle.ApplyClientGlyphs(L))
		assert.is_false(withModules("enUS", "enUS").env.Pagle.ApplyClientGlyphs({ JOIN = MIDDLE_DOT }))
	end)
end)
