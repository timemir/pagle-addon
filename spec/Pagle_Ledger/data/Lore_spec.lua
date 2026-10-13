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
