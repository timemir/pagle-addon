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

	describe("the Refreshes a moment carries (HNT-R86, HNT-R117, REF-R7)", function()
		local event = ns.events:Event("fixture_vale") --[[@as HuntEvent]]
		local haul = { id = "fixture_vale_haul", class = "species.any", tiers = { 1, 2, 3 } }
		local huntTier = hunts.progress({ tiers = 3 }).reached[3]

		it("is a settled run's", function()
			local moment = ns.WagerSettledMoment(event)

			assert.are.equal(ns.TICKETS_RUN, moment.tickets)
			assert.are.equal(ns.COINS_RUN, moment.coins)
		end)

		it("is a third mark's, beside its Coins", function()
			local moment = ns.WagerMarkMoment(haul, 3, huntTier)

			assert.are.same({ "wagerTier", ns.TICKETS_TIER3, ns.TierAmount(ns.COINS_EVENT, 3) }, {
				moment.kind,
				moment.tickets,
				moment.coins,
			})
		end)

		it("is none for a first or a second mark, nor for a ladder title", function()
			assert.is_nil(ns.WagerMarkMoment(haul, 1, huntTier).tickets)
			assert.is_nil(ns.WagerMarkMoment(haul, 2, huntTier).tickets)
			assert.is_nil(ns.WagerTitleMoment(25).tickets)
		end)

		it("is left out while a count is 0, as a moment with no Refreshes has no field (REF-R7)", function()
			local run, tier3 = ns.TICKETS_RUN, ns.TICKETS_TIER3
			ns.TICKETS_RUN, ns.TICKETS_TIER3 = 0, 0

			local settled, mark = ns.WagerSettledMoment(event), ns.WagerMarkMoment(haul, 3, huntTier)
			ns.TICKETS_RUN, ns.TICKETS_TIER3 = run, tier3

			assert.is_nil(settled.tickets)
			assert.is_nil(mark.tickets)
		end)
	end)

	describe("a ladder title (HNT-R130, HNT-R148)", function()
		it("is its lore, `ladder.<n>.title`", function()
			assert.are.equal("Bookmaker's Bane", ns.LadderTitle(25))
		end)

		it("is its key while the lore has none (HNT-R1)", function()
			-- Step 75 isn't on the ladder, so no lore names it: 25, 50 and 100 all have titles (#307).
			assert.are.equal("ladder.75", ns.LadderTitle(75))
		end)
	end)
end)
