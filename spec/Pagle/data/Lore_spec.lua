-- Core's generated lore (DATA-R104): addons/Pagle/data/Lore.lua adds each of Core's goods' names and descriptions to
-- ns.L (SHOP-R25), from data/lore/core.toml, Core's M4 batch (DATA-R111).

-- SHOP-R25: Core's sixteen goods at M4.
local GOODS = {
	"core.toaststyle.page",
	"core.toaststyle.ripple",
	"core.toaststyle.lanternglow",
	"core.soundset.driftwood",
	"core.soundset.gilded",
	"core.crest.plain",
	"core.crest.elwynn",
	"core.crest.westfall",
	"core.crest.darkshore",
	"core.crest.redridge",
	"core.crest.wetlands",
	"core.crest.stranglethorn",
	"core.crest.dustwallow",
	"core.crest.feralas",
	"core.crest.tanaris",
	"core.crest.winterspring",
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

	it(
		"has a name and a description for each of Core's sixteen goods once Pagle loads (SHOP-R25, DATA-R104)",
		function()
			for _, good in ipairs(GOODS) do
				hasText(("good.%s.name"):format(good))
				hasText(("good.%s.description"):format(good))
			end
		end
	)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		assert.are.equal("Pagle", L.SETTINGS_CATEGORY)
	end)
end)
