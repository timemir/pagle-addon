-- The Fishing key's pure logic: the ladder (QOL-R20), the fishing-pole test (QOL-R21), each action's target
-- (QOL-R24) and the re-point decision (QOL-R25, QOL-R26).

describe("QoL's Fishing key logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.NextAction", function()
		-- Each row: the state, then the next action. Unlisted fields are false. M1 has steps 1, 2 and 6 only.
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
			-- Step 6, with or without a pole (QOL-R23).
			{ "idle with a pole in hand", { armed = true, poleInHand = true }, "cast" },
			{ "idle with no pole in hand", { armed = true }, "cast" },
		}
		for _, row in ipairs(LADDER) do
			it(("gives %s when %s (QOL-R20, QOL-R23)"):format(row[3], row[1]), function()
				assert.are.equal(row[3], ns.NextAction(row[2]))
			end)
		end
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
