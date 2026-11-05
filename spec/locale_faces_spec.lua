-- The client's own font on a client whose script the bundled faces lack (CORE-R9, 1.0.2, the early slice of #522):
-- each addon's ns.LocaleFace, and the font objects its art kits make, on a fake client of each language.

local FONTS = "Interface\\AddOns\\Pagle\\media\\fonts\\"
local PRINT = FONTS .. "IMFeENrm28P.ttf"

-- Each language whose client gets its own font, with the STANDARD_TEXT_FONT the forever client's FrameXML sets for it
-- (Gethe/wow-ui-source branch forever, Interface/AddOns/Blizzard_Fonts_Shared/Shared/GameFonts.xml).
local CLIENT_FONTS = {
	ruRU = "Fonts\\FRIZQT___CYR.TTF",
	koKR = "Fonts\\2002.TTF",
	zhCN = "Fonts\\ARKai_T.ttf",
	zhTW = "Fonts\\blei00d.TTF",
}

local ADDONS = { "Pagle", "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_QoL", "Pagle_TackleBoard" }

-- A fake client's CreateFont that keeps each font object by name in `made`, as the stub does but findable.
---@param made table<string, table>
---@return fun(name: string): table
local function keptFonts(made)
	return function(name)
		local font = { name = name }
		function font:SetFont(file, size, flags)
			self.font = { file, size, flags }
			return true
		end
		font.SetTextColor = function() end
		font.SetShadowOffset = function() end
		font.SetShadowColor = function() end
		made[name] = font
		return font
	end
end

-- `name` loaded on a client of `locale`, whose FrameXML set STANDARD_TEXT_FONT to `standard` (nil: none), its font
-- objects kept by name in the second return.
---@param name string
---@param locale string
---@param standard string?
---@return LoadedAddon
---@return table<string, table>
local function on(name, locale, standard)
	local made = {}
	local loaded = loadAddon(
		name,
		foreverWith({
			GetLocale = function()
				return locale
			end,
			STANDARD_TEXT_FONT = standard,
			CreateFont = keptFonts(made),
		})
	)
	assert.are.same({}, loaded.client.errors)
	return loaded, made
end

describe("each addon's ns.LocaleFace (CORE-R9)", function()
	for _, addon in ipairs(ADDONS) do
		describe(addon, function()
			it("keeps the bundled face on an enUS or deDE client", function()
				for _, locale in ipairs({ "enUS", "deDE" }) do
					local loaded = on(addon, locale, "Fonts\\FRIZQT__.TTF")

					assert.are.equal(PRINT, loaded.ns.LocaleFace(PRINT), locale)
				end
			end)

			it("draws every face in the client's STANDARD_TEXT_FONT on ruRU, koKR, zhCN and zhTW", function()
				for locale, standard in pairs(CLIENT_FONTS) do
					local loaded = on(addon, locale, standard)

					assert.are.equal(standard, loaded.ns.LocaleFace(PRINT), locale)
					assert.are.equal(standard, loaded.ns.LocaleFace(FONTS .. "Caveat-Bold.ttf"), locale)
				end
			end)

			it("falls back to FRIZQT__ when the client has no STANDARD_TEXT_FONT", function()
				local loaded = on(addon, "ruRU", nil)

				assert.are.equal("Fonts\\FRIZQT__.TTF", loaded.ns.LocaleFace(PRINT))
			end)
		end)
	end
end)

describe("the art kits' fonts on a ruRU client (CORE-R9)", function()
	local CYR = CLIENT_FONTS.ruRU

	it("are Core's: the announcements', the Curio Shop's, the field kit's and the Field guide's faces", function()
		local loaded, made = on("Pagle", "ruRU", CYR)
		local ns = loaded.ns

		assert.are.equal(CYR, made.PagleArtName.font[1]) -- a toast's fish name, in Caveat
		assert.are.equal(CYR, made.PagleArtWhat.font[1]) -- its kicker, in IM Fell English
		assert.are.equal(CYR, made.PagleShopGoodName.font[1])
		assert.are.equal(CYR, ns.FieldFont("Type").font[1]) -- Cutive Mono
		assert.are.equal(CYR, ns.ArtFaceFont("sc", 14).font[1])
		local label = loaded.env.CreateFrame("Frame"):CreateFontString(nil, "OVERLAY")
		ns.FieldScaleFont(label, "PostAt", 0.8)
		assert.are.equal(CYR, label.font[1])
	end)

	it("are each Module's", function()
		local ledger = on("Pagle_Ledger", "ruRU", CYR)
		local hunts = on("Pagle_Hunts", "ruRU", CYR)
		local stats = on("Pagle_Stats", "ruRU", CYR)
		local qol = on("Pagle_QoL", "ruRU", CYR)
		local board = on("Pagle_TackleBoard", "ruRU", CYR)

		assert.are.equal(CYR, ledger.ns.JournalFont("sc", 14).font[1])
		assert.are.equal(CYR, hunts.ns.ArtFont("hand", 20).font[1])
		assert.are.equal(CYR, stats.ns.ArtFont("gilt", 14).font[1])
		assert.are.equal(CYR, qol.ns.FaceFont("print", 19).font[1])
		assert.are.equal(CYR, board.ns.ArtFont("Goal").font[1])
	end)

	it("stay the bundled faces on an enUS client, as in 1.0.1", function()
		local loaded, made = on("Pagle", "enUS", "Fonts\\FRIZQT__.TTF")

		assert.are.equal(FONTS .. "Caveat-SemiBold.ttf", made.PagleArtName.font[1])
		assert.are.equal(FONTS .. "CutiveMono-Regular.ttf", loaded.ns.FieldFont("Type").font[1])
		assert.are.equal(PRINT, on("Pagle_TackleBoard", "enUS").ns.ArtFont("Goal").font[1])
	end)
end)
