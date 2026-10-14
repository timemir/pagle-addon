-- A Nudge's timing (QOL-R75): shown for 3 s, then a 0.5 s fade.

describe("QoL's Nudge logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.NudgeAlpha", function()
		it("is fully shown for 3 s (QOL-R75, qol.md › Tunables)", function()
			assert.are.equal(1, ns.NudgeAlpha(0))
			assert.are.equal(1, ns.NudgeAlpha(2.9))
			assert.are.equal(1, ns.NudgeAlpha(3))
		end)

		it("then fades out over 0.5 s, and is gone after (QOL-R75, qol.md › Tunables)", function()
			assert.are.equal(0.5, ns.NudgeAlpha(3.25))
			assert.is_near(0.2, ns.NudgeAlpha(3.4), 1e-9)
			assert.is_nil(ns.NudgeAlpha(3.5))
			assert.is_nil(ns.NudgeAlpha(10))
		end)
	end)

	it("sits 4 px below the game's error text (QOL-R75, qol.md › Tunables)", function()
		assert.are.equal(4, ns.NUDGE_GAP)
	end)
end)
