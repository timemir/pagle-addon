local addon = require("spec.support.addon")

-- Project IDs as the clients define them: Forever's is WOW_PROJECT_CAMELOT (BIR forever README, scripts/tools.env).
local CAMELOT = 18
local MAINLINE = 1

describe("ns.IsForever", function()
	local ns = addon.load("Pagle", { WOW_PROJECT_ID = CAMELOT, WOW_PROJECT_CAMELOT = CAMELOT }).ns

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
