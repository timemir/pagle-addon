-- /pagle dev fonts (#522, CORE-R9): tries SetFont on each known client font path, measures a sample of each script in
-- the fonts that load, saves the facts in PagleDB.global.fontProbe and shows one row per loaded font, through the real
-- TOC and the fake client. The fake client's fonts are stand-ins: which files exist, and which scripts each draws (the
-- rest measure as the box, as a font without the glyphs draws it).

local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- The script a measured text is in, from the lead byte of its first character.
local function scriptOf(text)
	local lead = text:byte(1)
	if lead < 0x80 or lead == 0xC3 then
		return "latin"
	elseif lead == 0xD0 or lead == 0xD1 then
		return "cyrillic"
	elseif lead == 0xED or lead == 0xEA then
		return "hangul"
	elseif lead == 0xE9 then
		return "hanzi"
	end
	return "box"
end

local BOX = 10

local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local made = {}
	for key, item in pairs(value) do
		made[key] = copy(item)
	end
	return made
end

-- The fake client's font files: path to the scripts it draws. A path not here fails SetFont. The widths are not real:
-- a drawn character is 12 wide, the box 10.
local CLIENT_FONTS = {
	["Fonts\\FRIZQT__.TTF"] = { latin = true },
	["Fonts\\ARIALN.TTF"] = { latin = true, cyrillic = true },
	["Fonts\\2002.ttf"] = { latin = true, hangul = true },
	["Fonts\\ARKai_T.ttf"] = { latin = true, hanzi = true },
}

-- Core logged in on a client of `locale` whose fonts are CLIENT_FONTS, dev mode on.
local function probing(locale)
	local loaded = enterWorld(loadCore({ BUILD_ENTRY }, nil), 2)
	local env = loaded.env
	env.GetLocale = function()
		return locale or "enUS"
	end
	env.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
	env.UNIT_NAME_FONT = "Fonts\\NEWFONT.ttf"
	local create = env.UIParent.CreateFontString
	env.UIParent.CreateFontString = function(...)
		local text = create(...)
		local fonts, current = CLIENT_FONTS, nil
		local set = text.SetFont
		function text:SetFont(path, ...)
			current = fonts[path]
			return current ~= nil and set(self, path, ...)
		end
		function text:GetStringWidth()
			local script = scriptOf(self.text)
			return (script ~= "box" and current and current[script]) and 12 or BOX
		end
		return text
	end
	pagle(loaded, "dev on")
	return loaded
end

describe("/pagle dev fonts", function()
	it("prints the dev-off line and saves nothing while dev mode is off", function()
		local loaded = enterWorld(loadCore({ BUILD_ENTRY }), 2)

		pagle(loaded, "dev fonts")

		assert.are.same({ "Pagle dev: dev commands are off; /pagle dev on turns them on." }, loaded.printed)
		assert.is_nil(loaded.env.PagleDB.global.fontProbe)
		assert.is_nil(loaded.ns.fontProbeFrame)
	end)

	it("is in the dev usage line", function()
		local loaded = probing()

		pagle(loaded, "dev")

		assert.truthy(loaded.printed[2]:find("| fonts", 1, true))
	end)

	it("saves which paths load, the box width and how many characters of each script differ from it", function()
		local loaded = probing("koKR")

		pagle(loaded, "dev fonts")

		local probe = loaded.env.PagleDB.global.fontProbe
		assert.are.equal(SERVER_TIME, probe.time)
		assert.are.equal("koKR", probe.locale)
		assert.are.equal("enUS", probe.language)
		assert.are.same({ version = "1.60.1", build = "70338", date = "Oct  9 2026", interface = 16001 }, probe.build)
		assert.are.same(
			{ STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF", UNIT_NAME_FONT = "Fonts\\NEWFONT.ttf" },
			probe.globals
		)
		local paths = {}
		for i, font in ipairs(probe.fonts) do
			paths[i] = font.path
		end
		-- The sixteen known paths in their order, then the font global's path the list lacks.
		assert.are.equal(17, #paths)
		assert.are.equal("Fonts\\FRIZQT__.TTF", paths[1])
		assert.are.equal("Fonts\\K_Pagetext.TTF", paths[16])
		assert.are.equal("Fonts\\NEWFONT.ttf", paths[17])
		assert.are.same({
			path = "Fonts\\FRIZQT__.TTF",
			ok = true,
			box = BOX,
			scripts = {
				latin = { chars = 2, width = 24, drawn = 2 },
				cyrillic = { chars = 2, width = 20, drawn = 0 },
				hangul = { chars = 2, width = 20, drawn = 0 },
				hanzi = { chars = 4, width = 40, drawn = 0 },
			},
		}, probe.fonts[1])
		assert.are.same({ path = "Fonts\\FRIZQT___CYR.TTF", ok = false }, probe.fonts[2])
		assert.are.equal(2, probe.fonts[3].scripts.cyrillic.drawn, "ARIALN draws Cyrillic")
		assert.are.equal(2, probe.fonts[13].scripts.hangul.drawn, "2002 draws Hangul")
		assert.are.equal(4, probe.fonts[6].scripts.hanzi.drawn, "ARKai_T draws Han")
	end)

	it(
		"prints one line per path, then the saved line, and leaves PagleDB.global.probe and everything else alone",
		function()
			local loaded = probing("enUS")
			pagle(loaded, "dev probe")
			loaded.client.advance(2)
			local before = copy(loaded.env.PagleDB.global)
			local printed = #loaded.printed

			pagle(loaded, "dev fonts")

			local lines = { unpack(loaded.printed, printed + 1) }
			assert.are.equal(18, #lines)
			assert.are.equal(
				"Pagle dev: font Fonts\\FRIZQT__.TTF: ok; latin 2/2, cyrillic 0/2, hangul 0/2, hanzi 0/4",
				lines[1]
			)
			assert.are.equal("Pagle dev: font Fonts\\FRIZQT___CYR.TTF: failed", lines[2])
			assert.matches("^Pagle dev: 4 of 17 client fonts load on this enUS client; ", lines[18])
			local after = copy(loaded.env.PagleDB.global)
			assert.are.same(before.probe, after.probe)
			after.fontProbe = nil
			assert.are.same(before, after)
		end
	)

	it("shows one row per loaded font, naming its path and what it drew, with the sample line in it", function()
		local loaded = probing("enUS")

		pagle(loaded, "dev fonts")

		local frame = loaded.ns.fontProbeFrame
		assert.is_true(frame:IsShown())
		assert.are.equal(4, #frame.rows)
		local sample = loaded.ns.DevFontProbeLine()
		assert.are.equal(
			"Fonts\\FRIZQT__.TTF (ok; latin 2/2, cyrillic 0/2, hangul 0/2, hanzi 0/4): " .. sample,
			frame.rows[1]:GetText()
		)
		assert.are.equal("PagleDevFontsFont1", frame.rows[1].fontObject)
		-- The glyph probe's panel is its own.
		assert.is_nil(loaded.ns.glyphProbeFrame)
		frame:Click()
		assert.is_false(frame:IsShown())
		-- The sample holds a line of each script: Latin W and e acute, Cyrillic, Hangul, Han.
		assert.are.equal(
			"W\195\169  \208\150\209\137  \237\149\156\234\184\128  \233\177\188\233\146\147\233\173\154\233\135\163",
			sample
		)
	end)

	it("draws no panel when no font loads", function()
		local loaded = probing("enUS")
		local create = loaded.env.UIParent.CreateFontString
		loaded.env.UIParent.CreateFontString = function(...)
			local text = create(...)
			text.SetFont = function()
				return false
			end
			return text
		end

		pagle(loaded, "dev fonts")

		assert.is_nil(loaded.ns.fontProbeFrame)
		assert.matches("Pagle dev: 0 of 17 client fonts load", loaded.printed[#loaded.printed])
	end)
end)
