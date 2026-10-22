-- What Pagle Wagers' moments read (logic/WagerMoments.lua): an event's icon in a moment (HNT-R55, HNT-R161) and a
-- ladder title (HNT-R130, HNT-R148), over the fixture Hunt list's classes and lore.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local TRADE_FISHING = "Interface\\Icons\\Trade_Fishing"

describe("Pagle Wagers' moment parts", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local ns = hunts.load(fake).ns

	describe("an event's icon in a moment, its first Hunt's (HNT-R55, HNT-R161)", function()
		local function eventOf(hunt)
			return { id = "e", hunts = { hunt, { id = "e_2", species = C.BLACKMOUTH, tiers = { 1 } } } }
		end

		it("is a species target's item", function()
			assert.are.equal(C.NIGHTFIN, ns.EventMomentIcon(eventOf({ id = "e_1", species = C.NIGHTFIN })))
		end)

		it("is a fixed class's first member", function()
			assert.are.equal(C.DEVIATE, ns.EventMomentIcon(eventOf({ id = "e_1", class = "fixed.oddity" })))
		end)

		it("is Trade_Fishing, untinted, for a generated class", function()
			assert.are.equal(TRADE_FISHING, ns.EventMomentIcon(eventOf({ id = "e_1", class = "quality.uncommon" })))
			assert.are.equal(TRADE_FISHING, ns.EventMomentIcon(eventOf({ id = "e_1", class = "species.any" })))
		end)
	end)

	describe("a ladder title (HNT-R130, HNT-R148)", function()
		it("is its lore, `ladder.<n>.title`", function()
			assert.are.equal("Bookmaker's Bane", ns.LadderTitle(25))
		end)

		it("is its key while the lore has none (HNT-R1)", function()
			assert.are.equal("ladder.50", ns.LadderTitle(50))
		end)
	end)
end)
