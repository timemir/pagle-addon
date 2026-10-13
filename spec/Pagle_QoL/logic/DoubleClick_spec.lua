-- The double-click's pure logic: a qualifying click and the window it opens (QOL-R13), when it is live (QOL-R14) and
-- its BUTTON2 column (QOL-R15, QOL-R24).

describe("QoL's double-click logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.OnGameWorld", function()
		local world, button = {}, {}

		it("holds when the mouse is over WorldFrame alone, or over nothing (QOL-R13)", function()
			assert.is_true(ns.OnGameWorld({ world }, world))
			assert.is_true(ns.OnGameWorld({}, world))
		end)

		it("fails over a UI frame, alone or above the world (QOL-R13)", function()
			assert.is_false(ns.OnGameWorld({ button }, world))
			assert.is_false(ns.OnGameWorld({ button, world }, world))
		end)
	end)

	describe("ns.DoubleClickTarget", function()
		-- Each row: the ladder's state, then the BUTTON2 target (QOL-R24's double-click column).
		local TARGETS = {
			{ "idle with a pole in hand", { armed = true, poleInHand = true }, { kind = "spell", value = "Fishing" } },
			{
				"channeling Fishing",
				{ armed = true, poleInHand = true, channelingFishing = true },
				{ kind = "command", value = "INTERACTTARGET" },
			},
			{
				"a pole with no lure on and a lure available",
				{ armed = true, poleInHand = true, lure = 6529 },
				{ kind = "click", value = "PagleQoLActionButton", item = 6529 },
			},
			{ "a loot window open", { armed = true, poleInHand = true, lootOpen = true }, nil },
			{ "disarmed", { poleInHand = true }, nil },
		}
		for _, row in ipairs(TARGETS) do
			it(("is the Fishing key's target when %s (QOL-R24)"):format(row[1]), function()
				assert.are.same(row[3], ns.DoubleClickTarget(row[2], "Fishing"))
			end)
		end

		it("skips the gear step, never equipping the fishing set (QOL-R13, QOL-R15, QOL-R20)", function()
			local state = { armed = true, gearReady = true, lure = 6529 }
			assert.are.equal("gear", ns.NextAction(state))

			-- With no pole in hand the ladder goes on to the cast, which QOL-R14 then keeps from going live.
			assert.are.same({ kind = "spell", value = "Fishing" }, ns.DoubleClickTarget(state, "Fishing"))
			assert.is_false(ns.DoubleClickLive("both", state, ns.DoubleClickTarget(state, "Fishing")))
			-- The state the Fishing key reads is left as it was.
			assert.is_nil(state.skipGear)
		end)
	end)

	describe("ns.DoubleClickLive", function()
		local CAST = { kind = "spell", value = "Fishing" }
		local ARMED_WITH_POLE = { armed = true, poleInHand = true }

		it("holds under Double-click or Both, armed, with a pole in hand and a target (QOL-R14)", function()
			assert.is_true(ns.DoubleClickLive("click", ARMED_WITH_POLE, CAST))
			assert.is_true(ns.DoubleClickLive("both", ARMED_WITH_POLE, CAST))
		end)

		it(
			"fails under Fishing key, disarmed, with no pole, or with nothing to do (QOL-R12, QOL-R14, QOL-R15)",
			function()
				assert.is_false(ns.DoubleClickLive("key", ARMED_WITH_POLE, CAST))
				assert.is_false(ns.DoubleClickLive("both", { poleInHand = true }, CAST))
				assert.is_false(ns.DoubleClickLive("both", { armed = true }, CAST))
				assert.is_false(ns.DoubleClickLive("both", ARMED_WITH_POLE, nil))
			end
		)
	end)

	describe("ns.NewDoubleClickWindow", function()
		it("counts a right mouse-down and mouse-up on the world within 0.3 s (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()

			window:MouseDown("RightButton", 10)
			assert.is_true(window:MouseUp("RightButton", 10.29, true))
		end)

		it("doesn't count one held longer, a camera turn (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()

			window:MouseDown("RightButton", 10)
			assert.is_false(window:MouseUp("RightButton", 10.31, true))
		end)

		it("doesn't count one off the world, a left click, or a mouse-up with no mouse-down (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()

			window:MouseDown("RightButton", 10)
			assert.is_false(window:MouseUp("RightButton", 10.1, false))
			window:MouseDown("LeftButton", 11)
			assert.is_false(window:MouseUp("LeftButton", 11.1, true))
			assert.is_false(window:MouseUp("RightButton", 12, true))
		end)

		it("ignores other buttons between a right mouse-down and its mouse-up (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()

			window:MouseDown("RightButton", 10)
			window:MouseDown("LeftButton", 10.05)
			assert.is_false(window:MouseUp("LeftButton", 10.1, true))
			assert.is_true(window:MouseUp("RightButton", 10.2, true))
		end)

		it("closes 0.4 s after it opens (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()

			window:Open(10)
			assert.is_true(window:IsOpen())
			assert.is_false(window:Due(10.39))
			assert.is_true(window:Due(10.4))
		end)

		it(
			"closes on a frame after the next right mouse-up, never the frame of that mouse-up itself (QOL-R13)",
			function()
				local window = ns.NewDoubleClickWindow()
				window:Open(10)

				window:MouseDown("RightButton", 10.1)
				assert.is_false(window:MouseUp("RightButton", 10.15, true))
				-- GetTime() holds one value through a frame, so a later time is a later frame.
				assert.is_false(window:Due(10.15))
				assert.is_true(window:Due(10.166))
			end
		)

		it("never opens again from a mouse-up whose mouse-down came while a window was open (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()
			window:Open(10)

			-- The second click's press falls inside the window, which runs out while it is held.
			window:MouseDown("RightButton", 10.35)
			assert.is_true(window:Due(10.4))
			window:Close()
			assert.is_false(window:MouseUp("RightButton", 10.45, true))
		end)

		it("counts the third click of a triple click as a new first click (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()
			window:MouseDown("RightButton", 10)
			assert.is_true(window:MouseUp("RightButton", 10.1, true))
			window:Open(10.1)
			window:MouseDown("RightButton", 10.2)
			assert.is_false(window:MouseUp("RightButton", 10.25, true))
			assert.is_true(window:Due(10.27))
			window:Close()

			window:MouseDown("RightButton", 10.35)
			assert.is_true(window:MouseUp("RightButton", 10.4, true))
		end)

		it("is closed at first, and Close shuts it at once (QOL-R13)", function()
			local window = ns.NewDoubleClickWindow()
			assert.is_false(window:IsOpen())
			assert.is_false(window:Due(10))

			window:Open(10)
			window:Close()

			assert.is_false(window:IsOpen())
			assert.is_false(window:Due(11))
		end)
	end)
end)
