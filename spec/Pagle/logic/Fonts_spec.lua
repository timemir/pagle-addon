-- Core's per-locale font table (CORE-R9, ADR 0019 "Scripts and fonts", #522): which file draws a bundled face in each
-- Pagle language, and Faces:Set's fallback when the client lacks it. Pure logic, over a stub font that says which
-- files it has.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local BUNDLED = "Interface\\AddOns\\Pagle\\media\\fonts\\"
local NON_LATIN = { "ruRU", "koKR", "zhCN", "zhTW" }
local ROLES = { "body", "heading", "hand", "mono" }

-- A font (object or string) that has the files in `has` and keeps what SetFont gave it, as the client's does: false
-- for a file it lacks.
---@param has table<string, true>?
local function stub(has)
	local font = { calls = {} }
	function font:SetFont(file, size, flags)
		self.calls[#self.calls + 1] = { file, size, flags }
		return has == nil or has[file] == true
	end
	return font
end

describe("ns.FaceFile", function()
	it("gives the bundled face itself in every Latin language", function()
		for _, language in ipairs({ "enUS", "deDE", "esES", "esMX", "frFR", "itIT", "ptBR" }) do
			assert.are.equal(BUNDLED .. "Caveat-Medium.ttf", ns.FaceFile("Caveat-Medium.ttf", language))
			assert.are.equal(BUNDLED .. "IMFeENrm28P.ttf", ns.FaceFile("IMFeENrm28P.ttf", language))
		end
	end)

	it("gives the client's face for the role in each of ruRU, koKR, zhCN and zhTW", function()
		local expected = {
			ruRU = { body = "Fonts\\FRIZQT___CYR.TTF", heading = "Fonts\\FRIZQT___CYR.TTF", mono = "Fonts\\ARIALN.TTF" },
			koKR = { body = "Fonts\\2002.ttf", heading = "Fonts\\2002B.ttf", mono = "Fonts\\2002.ttf" },
			zhCN = { body = "Fonts\\ARKai_T.ttf", heading = "Fonts\\ARKai_T.ttf", mono = "Fonts\\ARKai_T.ttf" },
			zhTW = { body = "Fonts\\bHEI00M.ttf", heading = "Fonts\\bHEI01B.ttf", mono = "Fonts\\bHEI00M.ttf" },
		}
		for language, files in pairs(expected) do
			assert.are.equal(files.body, ns.FaceFile("IMFeENrm28P.ttf", language), language)
			assert.are.equal(files.body, ns.FaceFile("IMFeENit28P.ttf", language), language)
			assert.are.equal(files.body, ns.FaceFile("IMFeENsc28P.ttf", language), language)
			assert.are.equal(files.heading, ns.FaceFile("Marcellus-Regular.ttf", language), language)
			assert.are.equal(files.mono, ns.FaceFile("CutiveMono-Regular.ttf", language), language)
		end
		assert.are.equal("Fonts\\K_Pagetext.TTF", ns.FaceFile("Caveat-Bold.ttf", "koKR"))
		assert.are.equal("Fonts\\ARKai_C.ttf", ns.FaceFile("Caveat-SemiBold.ttf", "zhCN"))
		assert.are.equal("Fonts\\bKAI00M.ttf", ns.FaceFile("Caveat-Medium.ttf", "zhTW"))
	end)

	it("draws a face with no role as the body", function()
		assert.are.equal("Fonts\\2002.ttf", ns.FaceFile("Unknown.ttf", "koKR"))
	end)

	it("has a role for every face in media/fonts, and a file for every role in each of the four languages", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local listing = assert(io.popen("ls addons/Pagle/media/fonts"))
		local found = 0
		for name in listing:lines() do
			if name:match("%.ttf$") then
				found = found + 1
				assert(type(ns.FACE_ROLES[name]) == "string", name .. " has no role")
			end
		end
		listing:close()
		assert.are.equal(
			found,
			(function()
				local count = 0
				for _ in pairs(ns.FACE_ROLES) do
					count = count + 1
				end
				return count
			end)()
		)
		for _, language in ipairs(NON_LATIN) do
			for _, role in ipairs(ROLES) do
				assert(type(ns.CLIENT_FONTS[language][role]) == "string", language .. " " .. role)
			end
		end
		for language in pairs(ns.CLIENT_FONTS) do
			assert(({ ruRU = 1, koKR = 1, zhCN = 1, zhTW = 1 })[language], language .. " swaps but isn't non-Latin")
		end
	end)

	it("names only client fonts that /pagle dev fonts tries", function()
		local tried = {}
		for _, path in ipairs(ns.DEV_CLIENT_FONT_PATHS) do
			tried[path:lower()] = true
		end
		for language, roles in pairs(ns.CLIENT_FONTS) do
			for role, path in pairs(roles) do
				assert(tried[path:lower()], ("%s %s: %s"):format(language, role, path))
			end
		end
	end)
end)

describe("Faces", function()
	local language
	local faces = ns.NewFaces(function()
		return language
	end)

	before_each(function()
		language = "enUS"
	end)

	it("sets the bundled face on a Latin language, and returns the file", function()
		local font = stub()

		assert.are.equal(BUNDLED .. "Caveat-Bold.ttf", faces:Set(font, "Caveat-Bold.ttf", 22))
		assert.are.same({ { BUNDLED .. "Caveat-Bold.ttf", 22, "" } }, font.calls)
	end)

	it("sets the client's face on each of the four", function()
		for _, code in ipairs(NON_LATIN) do
			language = code
			local font = stub()

			faces:Set(font, "Marcellus-Regular.ttf", 17, "OUTLINE")

			assert.are.same({ { ns.CLIENT_FONTS[code].heading, 17, "OUTLINE" } }, font.calls)
		end
	end)

	it("falls back to FRIZQT__ for a file the client doesn't have, at the same size", function()
		language = "zhTW"
		local font = stub({ ["Fonts\\FRIZQT__.TTF"] = true })

		local file = faces:Set(font, "IMFeENrm28P.ttf", 15)

		assert.are.equal("Fonts\\FRIZQT__.TTF", file)
		assert.are.same({ { "Fonts\\bHEI00M.ttf", 15, "" }, { "Fonts\\FRIZQT__.TTF", 15, "" } }, font.calls)
	end)

	it("falls back in English too when the bundled face won't load", function()
		local font = stub({ ["Fonts\\FRIZQT__.TTF"] = true })

		assert.are.equal("Fonts\\FRIZQT__.TTF", faces:Set(font, "CutiveMono-Regular.ttf", 12))
	end)

	it("sets a tracked font object again when the Language changes", function()
		local first, second = stub(), stub()
		faces:Track(first, "IMFeENrm28P.ttf", 16)
		faces:Track(second, "Caveat-Medium.ttf", 19)
		language = "koKR"

		faces:Refit()

		assert.are.same({ BUNDLED .. "IMFeENrm28P.ttf", 16, "" }, first.calls[1])
		assert.are.same({ "Fonts\\2002.ttf", 16, "" }, first.calls[2])
		assert.are.same({ "Fonts\\K_Pagetext.TTF", 19, "" }, second.calls[2])
	end)
end)

describe("ns.PublishFaces", function()
	it("gives Pagle.FaceFile and Pagle.SetFace, following the language the faces read", function()
		local language = "enUS"
		local Pagle = {}
		ns.PublishFaces(
			Pagle,
			ns.NewFaces(function()
				return language
			end)
		)
		local font = stub()

		assert.are.equal(BUNDLED .. "Marcellus-Regular.ttf", Pagle.FaceFile("Marcellus-Regular.ttf"))
		language = "ruRU"
		assert.are.equal("Fonts\\FRIZQT___CYR.TTF", Pagle.FaceFile("Marcellus-Regular.ttf"))
		assert.are.equal("Fonts\\FRIZQT___CYR.TTF", Pagle.SetFace(font, "Marcellus-Regular.ttf", 20))
	end)
end)
