-- The Tackle Board's parts of onboarding in logic (core/onboarding.md; ONB-R37, ONB-R91; TKB-R5, TKB-R108): its line
-- on What's in the box, what Start my board on its guide page shows, and the guide's sample strip in the board's words.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

describe("the Tackle Board's def (ONB-R91)", function()
	it("carries its line for the Field guide's What's in the box step", function()
		local loaded, fake = board.load()
		fake.login()

		local def = fake.registry:ModuleOf(loaded.ns.Module).def
		assert.are.equal(
			"Small goals pinned to a cork board, if you want them. They wait while you’re away.",
			def.guideBlurb
		)
	end)
end)

describe("Start my board on the guide's page (ONB-R37, TKB-R5, TKB-R108)", function()
	local loaded = board.load()
	local ns = loaded.ns

	it("reads Start my board until the board is started, usable unless the projection is updating", function()
		assert.are.same({ label = "Start my board", usable = true, up = false }, ns.GuideStartShows(false, false))
		assert.are.same({ label = "Start my board", usable = false, up = false }, ns.GuideStartShows(false, true))
	end)

	it('reads "Your board is up", never usable, once the board is known started, even while it rebuilds', function()
		for _, updating in ipairs({ false, true }) do
			assert.are.same(
				{ label = "Your board is up", usable = false, up = true },
				ns.GuideStartShows(true, updating)
			)
		end
	end)
end)

describe("the guide's sample strip (ONB-R37)", function()
	local loaded = board.load()
	loaded.client.areaNames[33] = "Stranglethorn Vale"
	local sample = loaded.ns.GuideSample()

	it("is two Notices in the board's words: a Haul workable here, and a day-bound Collector", function()
		local haul, collector = sample.notices[1], sample.notices[2]
		assert.are.same({ kind = "haul", pay = 15 }, haul.goal)
		assert.are.same({ "Haul", "30 Catches in Stranglethorn Vale", "12 of 30", 0.4, true, "enabled" }, {
			haul.view.kicker,
			haul.view.text,
			haul.view.progress,
			haul.view.fill,
			haul.view.here,
			haul.view.takeDown,
		})
		assert.are.same({ kind = "collector", pay = 10 }, collector.goal)
		assert.are.same({ "Collector", "A junk item and a container today", "1 of 2 today", 0.5, false, "anywhere" }, {
			collector.view.kicker,
			collector.view.text,
			collector.view.progress,
			collector.view.fill,
			collector.view.here,
			collector.view.where,
		})
	end)

	it("has a Campfire of 13 days with 2 Kindling, and a Fly Box of 26 tied", function()
		assert.are.equal(13, sample.fireDays)
		assert.are.same({ "lit", 2, "longest 13" }, { sample.fire.state, sample.fire.kindling, sample.fire.longest })
		assert.are.equal("26 of 30 tied", sample.flies)
	end)
end)
