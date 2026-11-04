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

	it("fall back to FRIZQT__ for a client font the client doesn't have", function()
		local _, made = core(nil, "koKR", { ["Fonts\\2002B.ttf"] = true })

		assert.are.same({ FALLBACK, 21, "" }, made.PagleArtKick.font)
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

	it("stay bundled in English chosen on a non-Latin client", function()
		local loaded, made = core("enUS", "koKR")

		assert.are.equal("enUS", loaded.env.Pagle.GetLanguage())
		assert.are.same({ BUNDLED .. "IMFeENrm28P.ttf", 16, "" }, made.PagleArtWhat.font)
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
