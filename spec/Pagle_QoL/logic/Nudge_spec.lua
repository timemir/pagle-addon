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

	describe("ns.NudgeParts", function()
		it("splits the line at its %s, the value a key or red words, the spaces round it dropped (QOL-R75)", function()
			assert.are.same(
				{ "Press", { key = "G" }, "to swap back." },
				ns.NudgeParts("Press %s to swap back.", "G", "key")
			)
			assert.are.same({ "Bind", { em = "Pagle: Swap gear" } }, ns.NudgeParts("Bind %s", "Pagle: Swap gear", "em"))
			assert.are.same({ { key = "G" }, "first." }, ns.NudgeParts("%s first.", "G", "key"))
		end)

		it("is the line alone with no %s or no value (QOL-R75)", function()
			assert.are.same({ "Your lure is gone." }, ns.NudgeParts("Your lure is gone.", "G", "key"))
			assert.are.same({ "Press %s." }, ns.NudgeParts("Press %s.", nil, "key"))
		end)
	end)

	it("ns.NudgeText joins the pieces with spaces (QOL-R75)", function()
		assert.are.equal("Press G to swap back.", ns.NudgeText({ "Press", { key = "G" }, "to swap back." }))
		assert.are.equal("Bind Pagle: Swap gear", ns.NudgeText({ "Bind", { em = "Pagle: Swap gear" } }))
	end)

	describe("ns.NudgeLayout", function()
		it("puts the pieces 30 px in, 8 px apart, with 30 px to the strip's end (the field art kit)", function()
			local widths = { 100, 10, 40 }
			local pieces, width = ns.NudgeLayout({ "Press", { key = "G" }, "to swap back." }, function(index)
				return widths[index]
			end)

			-- The key's cap is its text and 6 px either side, at least 26 px.
			assert.are.same({ { x = 30, width = 100 }, { x = 138, width = 26 }, { x = 172, width = 40 } }, pieces)
			assert.are.equal(242, width)
		end)

		it("widens a key's cap past 26 px for a long key", function()
			local pieces = ns.NudgeLayout({ { key = "SHIFT-G" } }, function()
				return 42
			end)

			assert.are.same({ { x = 30, width = 54 } }, pieces)
		end)
	end)
end)
