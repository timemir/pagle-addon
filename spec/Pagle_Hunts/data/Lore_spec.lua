-- Hunts' generated lore (DATA-R104, DATA-R105, HNT-R130): addons/Pagle_Hunts/data/Lore.lua adds to ns.L the name and
-- note of every Hunt and the name, title and note of every set, from data/hunts/hunts.toml, and the name and
-- description of each of Hunts' goods, from data/lore/hunts.toml: the M5 batch (DATA-R111). Read from the shipped
-- Hunt list, without the fixture.

-- HNT-R121: Hunts' seven goods.
local GOODS = {
	"hunts.notebookcover.leather",
	"hunts.notebookcover.oilcloth",
	"hunts.notebookcover.tooled",
	"hunts.notebookcover.verdigris",
	"hunts.trackerframe.none",
	"hunts.trackerframe.inkwash",
	"hunts.trackerframe.waxseal",
}

describe("Hunts' committed lore (DATA-R111, its M5 batch)", function()
	local ns

	setup(function()
		ns = newFakePagle().load("Pagle_Hunts").ns
	end)

	---@param key string
	---@return string
	local function text(key)
		local value = rawget(ns.L, key)
		assert(type(value) == "string" and value:find("%S"), key .. " has no text")
		return value
	end

	it("names each of the 16 v1 Hunts once Pagle_Hunts loads (HNT-R1, DATA-R105)", function()
		assert.are.equal(16, #ns.huntList.hunts)
		for _, hunt in ipairs(ns.huntList.hunts) do
			assert.are.equal(text(("hunt.%s.name"):format(hunt.id)), ns.hunts:HuntName(hunt.id))
		end
	end)

	it("gives each of the 5 sets a name and a title (HNT-R1, HNT-R22, DATA-R105)", function()
		assert.are.equal(5, #ns.huntList.sets)
		for _, set in ipairs(ns.huntList.sets) do
			assert.are.equal(text(("set.%s.name"):format(set.id)), ns.hunts:SetName(set.id))
			assert.are.equal(text(("set.%s.title"):format(set.id)), ns.hunts:SetTitle(set.id))
		end
	end)

	it("keeps Sunday Showdown's note: the Extravaganza, at level 60 (hunts.md › Data)", function()
		local note = ns.hunts:SetNote("sunday_showdown")
		assert.is_truthy(note and note:find("Extravaganza", 1, true))
		assert.is_truthy(note and note:find("level 60", 1, true))
	end)

	it("has a name and a description for each of Hunts' seven goods (HNT-R121, HNT-R130)", function()
		for _, good in ipairs(GOODS) do
			text(("huntgood.%s.name"):format(good))
			text(("huntgood.%s.description"):format(good))
		end
	end)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		assert.are.equal("Hunts", ns.L.TITLE)
	end)
end)
