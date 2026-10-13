local addon = require("spec.support.addon")

-- Forever's project ID, WOW_PROJECT_CAMELOT (BIR forever README, scripts/tools.env).
local CAMELOT = 18

describe("Pagle.toc", function()
	local loaded = addon.load("Pagle", { WOW_PROJECT_ID = CAMELOT, WOW_PROJECT_CAMELOT = CAMELOT })

	for _, lib in ipairs({ "CallbackHandler-1.0", "AceAddon-3.0", "AceEvent-3.0", "AceDB-3.0" }) do
		it("embeds " .. lib .. ", reachable through LibStub (CORE-R6)", function()
			assert.is_table(loaded.env.LibStub:GetLibrary(lib, true))
		end)
	end
end)
