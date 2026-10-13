local CAMELOT, MAINLINE = PROJECT_IDS.CAMELOT, PROJECT_IDS.MAINLINE

describe("ns.IsForever", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("is true on Forever, where the project ID is the Camelot one (CORE-R4)", function()
		assert.is_true(ns.IsForever(CAMELOT, CAMELOT))
	end)

	it("is false on a client with another project ID (CORE-R4)", function()
		assert.is_false(ns.IsForever(MAINLINE, CAMELOT))
	end)

	it("is false when the client doesn't define WOW_PROJECT_CAMELOT (CORE-R4)", function()
		assert.is_false(ns.IsForever(MAINLINE, nil))
		assert.is_false(ns.IsForever(nil, nil))
	end)
end)
