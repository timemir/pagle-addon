-- Core's generated lore (DATA-R104): addons/Pagle/data/Lore.lua adds each of Core's goods' names and descriptions to
-- ns.L (SHOP-R25), from data/lore/core.toml, Core's M4 batch (DATA-R111).

-- SHOP-R25: Core's thirty goods, the Curio Shop expansion's among them, and Plain; the crest slot's zone crests are the
-- Ledger's (LED-R113).
local GOODS = {
	"core.toaststyle.page",
	"core.toaststyle.ripple",
	"core.toaststyle.lanternglow",
	"core.toaststyle.ship",
	"core.toaststyle.birch",
	"core.toaststyle.tidepool",
	"core.toaststyle.chart",
	"core.toaststyle.frost",
	"core.toaststyle.goblin",
	"core.toaststyle.kelp",
	"core.toaststyle.moon",
	"core.toaststyle.leaf",
	"core.toaststyle.bottle",
	"core.toaststyle.rune",
	"core.toaststyle.folio",
	"core.soundset.driftwood",
	"core.soundset.gilded",
	"core.soundset.rain",
	"core.soundset.marimba",
	"core.soundset.shipbell",
	"core.soundset.kalimba",
	"core.soundset.musicbox",
	"core.soundset.glass",
	"core.soundset.steelpan",
	"core.soundset.dulcimer",
	"core.soundset.frost",
	"core.soundset.harp",
	"core.soundset.gizmo",
	"core.soundset.wardrums",
	"core.crest.plain",
}

describe("Core's committed lore (DATA-R111, its M4 batch)", function()
	local L

	setup(function()
		L = loadAddon("Pagle", FOREVER_GLOBALS).ns.L
	end)

	---@param key string
	local function hasText(key)
		local text = rawget(L, key)
		assert(type(text) == "string" and text:find("%S"), key .. " has no text")
	end

	it("has a name and a description for each of Core's thirty goods once Pagle loads (SHOP-R25, DATA-R104)", function()
		for _, good in ipairs(GOODS) do
			hasText(("good.%s.name"):format(good))
			hasText(("good.%s.description"):format(good))
		end
	end)

	it("has no zone crest's lore, which is the Ledger's (LED-R113)", function()
		local found = {}
		for key in pairs(L) do
			if
				type(key) == "string"
				and key:find("^good%.core%.crest%.")
				and not key:find("^good%.core%.crest%.plain%.")
				and not key:find("^good%.core%.crest%.fish%.")
			then
				found[#found + 1] = key
			end
		end
		assert.are.same({}, found)
	end)

	it(
		"names every fish crest {fish} Crest, the fish filled in at runtime, with its own description (VAR-R12)",
		function()
			local names, described = 0, 0
			for key, text in pairs(L) do
				if type(key) == "string" and key:find("^good%.core%.crest%.fish%.%d+%.name$") then
					names = names + 1
					assert.are.equal("{fish} Crest", text)
					hasText((key:gsub("%.name$", ".description")))
					described = described + 1
				end
			end
			assert.are.same({ 37, 37 }, { names, described })
		end
	)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		assert.are.equal("Pagle", L.SETTINGS_CATEGORY)
	end)
end)
