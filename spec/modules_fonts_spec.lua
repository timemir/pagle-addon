-- Each Module's art kit draws with the client's own fonts in ruRU, koKR, zhCN and zhTW, asking Core for them through
-- Pagle.SetFace (CORE-R9, API version 2, #522), and with the bundled faces otherwise, as before. The language is the
-- one FakePagle answers Pagle.GetLanguage with, set before the Module loads.

local BUNDLED = "Interface\\AddOns\\Pagle\\media\\fonts\\"

-- How each Module makes a font in a face: a function of its loaded namespace, giving the font object, and the bundled
-- file the face is.
local KITS = {
	{
		module = "Pagle_Hunts",
		font = function(ns)
			return ns.ArtFont("handSemi", 20)
		end,
		file = "Caveat-SemiBold.ttf",
	},
	{
		module = "Pagle_Stats",
		font = function(ns)
			return ns.ArtFont("gilt", 14)
		end,
		file = "Marcellus-Regular.ttf",
	},
	{
		module = "Pagle_Ledger",
		font = function(ns)
			return ns.JournalFont("sc", 14)
		end,
		file = "IMFeENsc28P.ttf",
	},
	{
		module = "Pagle_QoL",
		font = function(ns)
			return ns.FaceFont("italic", 13)
		end,
		file = "IMFeENit28P.ttf",
	},
	{
		module = "Pagle_TackleBoard",
		font = function(ns)
			return ns.ArtFont("Goal")
		end,
		file = "IMFeENrm28P.ttf",
	},
}

local function fontOf(kit, language)
	local fake = newFakePagle()
	fake.language = language
	local loaded = fake.load(kit.module)
	return kit.font(loaded.ns).font[1], fake
end

describe("the Modules' art kits", function()
	for _, kit in ipairs(KITS) do
		describe(kit.module, function()
			it("draw with the bundled face in English", function()
				assert.are.equal(BUNDLED .. kit.file, (fontOf(kit, "enUS")))
			end)

			it("draw with the bundled face in a Latin language", function()
				assert.are.equal(BUNDLED .. kit.file, (fontOf(kit, "deDE")))
			end)

			for _, language in ipairs({ "ruRU", "koKR", "zhCN", "zhTW" }) do
				it("draw with Core's font table's face in " .. language, function()
					local file, fake = fontOf(kit, language)

					assert.are.equal(fake.Pagle.FaceFile(kit.file), file)
					assert.is_nil(file:find("media\\fonts", 1, true))
				end)
			end
		end)
	end
end)
