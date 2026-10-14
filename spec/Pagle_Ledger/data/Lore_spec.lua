-- The Ledger's generated lore (DATA-R104): addons/Pagle_Ledger/data/Lore.lua adds each key's text to ns.L. The
-- fixture is the generator's output for scripts/tests/test_lore.py's fixture ledger.toml (a pytest checks they agree),
-- loaded in the committed file's TOC place.

local FIXTURE = "spec/Pagle_Ledger/fixtures/Lore.lua"

describe("the Ledger's Lore.lua", function()
	it("adds each key's text to ns.L once Pagle_Ledger loads through its TOC (DATA-R104, LED-R160)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS, { replace = { ["data/Lore.lua"] = FIXTURE } })

		assert.are.equal("Bites where the water runs lazy.", loaded.ns.L["species.13759.riddle"])
		assert.are.equal("Master of {zone}", loaded.ns.L["title.zonemaster.text"])
		assert.are.equal('Somebody\'s boot. "Size 9".', loaded.ns.L["sub.4000.plaque"])
	end)

	it("keeps the hand-written interface strings beside the lore (CORE-R8)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS, { replace = { ["data/Lore.lua"] = FIXTURE } })

		assert.are.equal("Ledger", loaded.ns.L.TITLE)
	end)

	it("leaves a key with no text out, so its line shows nothing (LED-R161)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS, { replace = { ["data/Lore.lua"] = FIXTURE } })

		assert.is_nil(loaded.ns.L["species.6358.riddle"])
	end)

	it("loads as committed, in the TOC after locale\\enUS.lua (DATA-R75)", function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)

		assert.are.equal("Ledger", loaded.ns.L.TITLE)
	end)
end)

describe("the Ledger's committed lore (DATA-R111, its M3 batch)", function()
	-- The text each key needs, from the committed catalogue and Lore.lua as Pagle_Ledger loads them (DATA-R103,
	-- LED-R160): a key missing here would leave its Journal line out (LED-R161).
	local L, items

	setup(function()
		local loaded = loadAddon("Pagle_Ledger", FOREVER_GLOBALS)
		L, items = loaded.ns.L, loaded.namespaces.Pagle.catalogue.items
	end)

	---@param key string
	local function hasText(key)
		local text = L[key]
		assert(type(text) == "string" and text:find("%S"), key .. " has no text")
	end

	it("has a blurb and a riddle for every Species in the catalogue, Legends aside (DATA-R103, LED-R160)", function()
		local species = 0
		for itemID, item in pairs(items) do
			if item.species == itemID and not item.legend then
				species = species + 1
				hasText(("species.%d.blurb"):format(itemID))
				hasText(("species.%d.riddle"):format(itemID))
			end
		end
		assert.is_true(species > 30)
	end)

	it("has a blurb and a title for every Legend (DATA-R103, LED-R160)", function()
		local legends = {}
		for itemID, item in pairs(items) do
			if item.legend then
				legends[#legends + 1] = itemID
				hasText(("legend.%d.blurb"):format(itemID))
				hasText(("legend.%d.title"):format(itemID))
			end
		end
		table.sort(legends)
		assert.are.same({ 19803, 19805, 19806 }, legends)
	end)

	it("never gives a Legend the title Master Angler (LED-R75)", function()
		for _, itemID in ipairs({ 19803, 19805, 19806 }) do
			assert.are_not.equal("Master Angler", L[("legend.%d.title"):format(itemID)])
		end
	end)

	it("has a plaque for every curio item and a name for every trophy family (LED-R160)", function()
		for itemID, item in pairs(items) do
			if item.category == "junk" or item.category == "container" or item.category == "treasure" then
				hasText(("sub.%d.plaque"):format(itemID))
			elseif item.category == "trophy" then
				hasText(("family.%d.name"):format(item.family))
			end
		end
	end)

	it("has the four shared lines (LED-R138, LED-R144, LED-R147, LED-R162)", function()
		for _, id in ipairs({ "uncaughtlegend", "uncaughtjunk", "uncaughttreasure", "unchartedwaters" }) do
			hasText(("line.%s.text"):format(id))
		end
	end)
end)
