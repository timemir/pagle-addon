-- The Fishing key's pure logic: the ladder (QOL-R20), the fishing-pole test (QOL-R21), each action's target
-- (QOL-R24) and the re-point decision (QOL-R25, QOL-R26).

describe("QoL's Fishing key logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.NextAction", function()
		-- Each row: the state, then the next action. Unlisted fields are false. Clams (step 5) come in Track Q step 6.
		local LADDER = {
			-- Step 1: disarmed, a loot window open, or casting a spell with a cast time (QOL-R20, QOL-R28, QOL-R30).
			{ "disarmed, idle", {}, "nothing" },
			{ "disarmed while channeling Fishing", { channelingFishing = true }, "nothing" },
			{ "a loot window open", { armed = true, lootOpen = true }, "nothing" },
			{
				"a loot window open while channeling",
				{ armed = true, lootOpen = true, channelingFishing = true },
				"nothing",
			},
			{ "casting a spell with a cast time", { armed = true, casting = true, poleInHand = true }, "nothing" },
			-- Step 2: channeling Fishing (QOL-R22).
			{ "channeling Fishing", { armed = true, channelingFishing = true, poleInHand = true }, "reel" },
			-- Step 4: a pole in hand with no lure on, and a lure available under the Lures setting (QOL-R20, QOL-R51).
			{ "a pole with no lure on and a lure available", { armed = true, poleInHand = true, lure = 6529 }, "lure" },
			{
				"a pole with a lure on (or counting as lured, QOL-R29)",
				{ armed = true, poleInHand = true, lured = true, lure = 6529 },
				"cast",
			},
			{ "a pole with no lure on and none available", { armed = true, poleInHand = true }, "cast" },
			{ "no pole in hand with a lure available", { armed = true, lure = 6529 }, "cast" },
			{
				"channeling Fishing with no lure on: never mid-channel",
				{ armed = true, channelingFishing = true, poleInHand = true, lure = 6529 },
				"reel",
			},
			{
				"a loot window open with no lure on",
				{ armed = true, lootOpen = true, poleInHand = true, lure = 6529 },
				"nothing",
			},
			{
				"casting a lure's use",
				{ armed = true, casting = true, poleInHand = true, lure = 6529 },
				"nothing",
			},
			-- Step 3: the gear step is ready (QOL-R43), on the Fishing key only (QOL-R15).
			{ "the gear step ready", { armed = true, gearReady = true, lure = 6529 }, "gear" },
			{
				"the gear step ready while channeling Fishing",
				{ armed = true, channelingFishing = true, gearReady = true },
				"reel",
			},
			{
				"the gear step ready with a loot window open",
				{ armed = true, lootOpen = true, gearReady = true },
				"nothing",
			},
			{
				"the gear step ready, for the double-click, which skips it",
				{ armed = true, gearReady = true, skipGear = true },
				"cast",
			},
			-- Step 6, with or without a pole (QOL-R23).
			{ "idle with a pole in hand", { armed = true, poleInHand = true }, "cast" },
			{ "idle with no pole in hand", { armed = true }, "cast" },
		}
		for _, row in ipairs(LADDER) do
			it(("gives %s when %s (QOL-R20, QOL-R23)"):format(row[3], row[1]), function()
				assert.are.equal(row[3], ns.NextAction(row[2]))
			end)
		end

		-- Step 2's "unless the reel didn't take" (QOL-R35).
		it("casts while channeling Fishing once the reel didn't take (QOL-R20, QOL-R35)", function()
			assert.are.equal(
				"cast",
				ns.NextAction({ armed = true, channelingFishing = true, poleInHand = true, reelMissed = true })
			)
			-- The cast takes the existing target: no lure goes on mid-channel.
			assert.are.equal(
				"cast",
				ns.NextAction({
					armed = true,
					channelingFishing = true,
					poleInHand = true,
					lure = 6529,
					reelMissed = true,
				})
			)
		end)

		it("still does nothing at step 1 when the reel didn't take (QOL-R20, QOL-R35)", function()
			assert.are.equal("nothing", ns.NextAction({ channelingFishing = true, reelMissed = true }))
			assert.are.equal(
				"nothing",
				ns.NextAction({ armed = true, lootOpen = true, channelingFishing = true, reelMissed = true })
			)
		end)
	end)

	describe("ns.NewReelWatch", function()
		local WAIT = 0.5 -- qol.md › Tunables, the reel wait

		it("takes a key going down while the reel is armed as a reel press (QOL-R35)", function()
			local watch = ns.NewReelWatch()
			assert.is_false(watch:Frame(true, false, 10))
			assert.is_false(watch:Frame(true, true, 10.25))
			assert.is_false(watch:Frame(true, false, 10.5))
			assert.is_false(watch:Missed())

			assert.is_true(watch:Frame(true, false, 10.25 + WAIT))
			assert.is_true(watch:Missed())
			-- It says so once.
			assert.is_false(watch:Frame(true, false, 11))
			assert.is_true(watch:Missed())
		end)

		it("holds no press before the reel wait has passed (QOL-R35)", function()
			local watch = ns.NewReelWatch()
			watch:Frame(true, false, 10)
			watch:Frame(true, true, 10.25)

			assert.is_false(watch:Frame(true, true, 10.5))
			assert.is_false(watch:Missed())
		end)

		it("counts no press while the reel isn't armed, or for a key already down (QOL-R35)", function()
			local watch = ns.NewReelWatch()
			watch:Frame(false, false, 10)
			watch:Frame(false, true, 10.1)
			-- Held from before the reel was armed: not a press.
			watch:Frame(true, true, 10.2)

			assert.is_false(watch:Frame(true, true, 11))
			assert.is_false(watch:Missed())
		end)

		it("keeps the first press's time when another comes while it waits (QOL-R35)", function()
			local watch = ns.NewReelWatch()
			watch:Frame(true, false, 10)
			watch:Frame(true, true, 10.25)
			watch:Frame(true, false, 10.5)
			watch:Frame(true, true, 10.625)

			assert.is_true(watch:Frame(true, true, 10.25 + WAIT))
		end)

		it("drops a waiting press and the miss on Clear (QOL-R35)", function()
			local watch = ns.NewReelWatch()
			watch:Frame(true, false, 10)
			watch:Frame(true, true, 10.1)
			watch:Clear()
			assert.is_false(watch:Frame(true, false, 11))
			assert.is_false(watch:Missed())

			watch:Frame(true, true, 11.1)
			watch:Frame(true, false, 12)
			assert.is_true(watch:Missed())
			watch:Clear()
			assert.is_false(watch:Missed())
		end)
	end)

	describe("ns.IsFishingPole", function()
		it("holds for class Weapon (2), subclass Fishing Pole (20) only (QOL-R21)", function()
			assert.is_true(ns.IsFishingPole(2, 20))
			assert.is_false(ns.IsFishingPole(2, 7)) -- a one-handed sword
			assert.is_false(ns.IsFishingPole(4, 20))
			assert.is_false(ns.IsFishingPole(nil, nil)) -- nothing in hand
		end)
	end)

	describe("ns.KeyTarget", function()
		it("casts Fishing by name, reels with INTERACTTARGET and has no target for nothing (QOL-R24)", function()
			assert.are.same({ kind = "spell", value = "Fishing" }, ns.KeyTarget("cast", "Fishing"))
			assert.are.same({ kind = "command", value = "INTERACTTARGET" }, ns.KeyTarget("reel", "Fishing"))
			assert.is_nil(ns.KeyTarget("nothing", "Fishing"))
		end)

		it("has no cast target while the Fishing spell's name is unknown (QOL-R24)", function()
			assert.is_nil(ns.KeyTarget("cast", nil))
		end)

		it("applies a lure by clicking PagleQoLActionButton set to the lure's item (QOL-R24, QOL-R52)", function()
			assert.are.same(
				{ kind = "click", value = "PagleQoLActionButton", item = 6529 },
				ns.KeyTarget("lure", "Fishing", 6529)
			)
		end)

		it("equips the fishing set by clicking PagleQoLGearButton, with no item (QOL-R24)", function()
			assert.are.same({ kind = "click", value = "PagleQoLGearButton" }, ns.KeyTarget("gear", "Fishing"))
			assert.is_false(
				ns.SameArming(
					ns.Arming({ "F" }, ns.KeyTarget("gear", "Fishing")),
					ns.Arming({ "F" }, ns.KeyTarget("lure", "Fishing", 6529))
				)
			)
		end)
	end)

	describe("ns.Arming", function()
		local CAST = { kind = "spell", value = "Fishing" }
		local REEL = { kind = "command", value = "INTERACTTARGET" }

		it("is the same only when both the keys and the target are (QOL-R25)", function()
			local now = ns.Arming({ "F", "SHIFT-F" }, CAST)

			assert.is_true(ns.SameArming(now, ns.Arming({ "F", "SHIFT-F" }, { kind = "spell", value = "Fishing" })))
			assert.is_false(ns.SameArming(now, ns.Arming({ "F", "SHIFT-F" }, REEL)))
			assert.is_false(ns.SameArming(now, ns.Arming({ "F" }, CAST)))
			assert.is_false(ns.SameArming(now, ns.Arming({ "G", "SHIFT-F" }, CAST)))
		end)

		it("re-points for another lure, though the click is the same (QOL-R24, QOL-R25)", function()
			local bauble = ns.Arming({ "F" }, ns.KeyTarget("lure", "Fishing", 6529))

			assert.is_true(ns.SameArming(bauble, ns.Arming({ "F" }, ns.KeyTarget("lure", "Fishing", 6529))))
			assert.is_false(ns.SameArming(bauble, ns.Arming({ "F" }, ns.KeyTarget("lure", "Fishing", 6532))))
		end)

		it("binds no key when there's no target, so a rebinding while disarmed changes nothing (QOL-R11)", function()
			assert.are.same({}, ns.Arming({ "F" }, nil).keys)
			assert.is_true(ns.SameArming(ns.Arming({ "F" }, nil), ns.Arming({ "G" }, nil)))
			assert.is_false(ns.SameArming(ns.Arming({}, CAST), ns.Arming({ "F" }, CAST)))
		end)

		it("has nothing to arm with no key bound, whatever the target (QOL-R11)", function()
			assert.is_true(ns.SameArming(ns.Arming({}, CAST), ns.Arming({}, nil)))
			assert.is_nil(ns.Arming({}, REEL).target)
		end)
	end)

	describe("ns.ClickRegistration", function()
		it("fires on key-down while ActionButtonUseKeyDown is 1, else on key-up (QOL-R27)", function()
			assert.are.equal("AnyDown", ns.ClickRegistration("1"))
			assert.are.equal("AnyUp", ns.ClickRegistration("0"))
			assert.are.equal("AnyUp", ns.ClickRegistration(nil)) -- a client that doesn't know the CVar
		end)
	end)

	describe("ns.KeyWithoutModifiers", function()
		it("is the key's last part, which IsKeyDown takes (QOL-R26)", function()
			assert.are.equal("F", ns.KeyWithoutModifiers("F"))
			assert.are.equal("F", ns.KeyWithoutModifiers("SHIFT-F"))
			assert.are.equal("BUTTON4", ns.KeyWithoutModifiers("ALT-CTRL-SHIFT-BUTTON4"))
			assert.are.equal("-", ns.KeyWithoutModifiers("CTRL--"))
			assert.are.equal("MOUSEWHEELUP", ns.KeyWithoutModifiers("META-MOUSEWHEELUP"))
		end)
	end)
end)
