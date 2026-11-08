-- Hunts' moments marked for the player's party (announcements.md ANN-R104, from 1.5.x, #640): a Hunt's gold tier, as
-- its adapter raises it, carries `party = "gold"`, and nothing else of Hunts' does.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- What FakePagle kept of Hunts' moments, each as "<kind> <stamp> <party>".
local function marked(fake)
	local out = {}
	for _, moment in ipairs(fake.summarized) do
		if moment.module == "Hunts" then
			out[#out + 1] = ("%s %s %s"):format(moment.kind, tostring(moment.stamp), tostring(moment.party))
		end
	end
	return out
end

describe("Hunts' party moments (ANN-R104)", function()
	it("mark a Hunt's gold tier as gold, and not its silver tier, its completion or a set title", function()
		local loaded, fake = hunts.login(nil, {})
		local raise = loaded.ns.moments.client.RaiseMoment
		local L = loaded.ns.L
		raise({ rung = "toast.high", kind = "huntTier", title = "Gold tier", stamp = L.TRIMS.gold, icon = 6303 })
		raise({ rung = "toast.high", kind = "huntTier", title = "Silver tier", stamp = L.TRIMS.silver, icon = 6303 })
		raise({ rung = "toast.high", kind = "huntCompleted", title = "Hunt complete", stamp = "Hunt", icon = 6303 })
		raise({ rung = "banner", kind = "huntSetTitle", title = "Title earned", stamp = L.TITLE_EARNED_STAMP })
		assert.are.same({
			"huntTier Gold gold",
			"huntTier Silver nil",
			"huntCompleted Hunt nil",
			"huntSetTitle " .. L.TITLE_EARNED_STAMP .. " nil",
		}, marked(fake))
	end)
end)
