-- Gear's pure logic: the fishing set's choice (QOL-R40), the free-slot check (QOL-R42), the gear step (QOL-R43),
-- Swap gear's body (QOL-R46), the wait for a swap's result (QOL-R29) and the swap-back Nudge's text (QOL-R77).

describe("QoL's gear logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	-- The chosen fishing set as the game reads it: a pole in its main hand, nothing missing, not worn.
	---@param fields table?
	---@return PagleQoLFishingSet
	local function set(fields)
		local read = { setID = 3, name = "Fishing", hasPole = true, numLost = 0, isEquipped = false }
		for key, value in pairs(fields or {}) do
			read[key] = value
		end
		return read
	end

	describe("the set names", function()
		it("are Pagle Fishing and Pagle Previous, lookup keys that are never translated (QOL-R42)", function()
			assert.are.equal("Pagle Fishing", ns.FISHING_SET_NAME)
			assert.are.equal("Pagle Previous", ns.PREVIOUS_SET_NAME)
		end)
	end)

	describe("ns.ChosenSetID", function()
		-- The character's sets by ID: Fishing (3) and Pagle Previous (5).
		local function nameOf(setID)
			return ({ [3] = "Fishing", [5] = "Pagle Previous" })[setID]
		end

		it("is the stored set while a set has both its ID and its name (QOL-R40)", function()
			assert.are.equal(3, ns.ChosenSetID({ setID = 3, name = "Fishing" }, nameOf))
		end)

		it("is none when no set has that ID with that name any more (QOL-R40)", function()
			assert.is_nil(ns.ChosenSetID({ setID = 3, name = "Old fishing" }, nameOf)) -- renamed
			assert.is_nil(ns.ChosenSetID({ setID = 4, name = "Fishing" }, nameOf)) -- deleted
			assert.is_nil(ns.ChosenSetID(nil, nameOf))
		end)

		it("is never Pagle Previous (QOL-R40)", function()
			assert.is_nil(ns.ChosenSetID({ setID = 5, name = "Pagle Previous" }, nameOf))
		end)
	end)

	describe("ns.FishingSetOptions", function()
		it(
			"offers None, then the character's sets in the game's order, except Pagle Previous (SET-R20, QOL-R40)",
			function()
				assert.are.same(
					{
						{ value = ns.NO_FISHING_SET, label = "None (gear stays as it is)" },
						{ value = 0, label = "Raid" },
						{ value = 3, label = "Pagle Fishing" },
					},
					ns.FishingSetOptions({
						{ setID = 0, name = "Raid" },
						{ setID = 5, name = "Pagle Previous" },
						{ setID = 3, name = "Pagle Fishing" },
					})
				)
			end
		)

		it("keeps None apart from every set ID, 0 included (QOL-R40, probe B9)", function()
			assert.is_number(ns.NO_FISHING_SET)
			assert.is_true(ns.NO_FISHING_SET < 0)
		end)
	end)

	describe("ns.SlotsMessage", function()
		it("is nil while the free slots cover the sets to create (QOL-R42)", function()
			assert.is_nil(ns.SlotsMessage(1, false, true))
			assert.is_nil(ns.SlotsMessage(2, true, true))
			assert.is_nil(ns.SlotsMessage(0, false, false))
		end)

		it("names Pagle Previous, or both sets when two slots are needed (QOL-R42)", function()
			assert.are.equal(
				"Pagle: needs a free equipment set slot for Pagle Previous.",
				ns.SlotsMessage(0, false, true)
			)
			assert.are.equal(
				"Pagle: needs two free equipment set slots for Pagle Fishing and Pagle Previous.",
				ns.SlotsMessage(1, true, true)
			)
			assert.are.equal(
				"Pagle: needs two free equipment set slots for Pagle Fishing and Pagle Previous.",
				ns.SlotsMessage(0, true, true)
			)
		end)

		it("names Pagle Fishing when only it needs a slot (QOL-R41, QOL-R42)", function()
			assert.are.equal(
				"Pagle: needs a free equipment set slot for Pagle Fishing.",
				ns.SlotsMessage(0, true, false)
			)
		end)
	end)

	describe("ns.GearStepReady", function()
		it(
			"holds with a set chosen whose main hand is a pole, nothing missing and no pole in hand (QOL-R43)",
			function()
				assert.is_true(ns.GearStepReady(set(), false, false))
			end
		)

		-- Each row: why the step isn't ready, then the arguments.
		local NOT_READY = {
			{ "no set is chosen", nil, false, false },
			{ "a pole is in hand already", set(), true, false },
			{ "the set holds no pole", set({ hasPole = false }), false, false },
			{ "an item of the set is missing, such as its pole in the bank", set({ numLost = 1 }), false, false },
			{ "a swap is still settling (QOL-R29)", set(), false, true },
		}
		for _, row in ipairs(NOT_READY) do
			it(("doesn't hold when %s (QOL-R43)"):format(row[1]), function()
				assert.is_false(ns.GearStepReady(row[2], row[3], row[4]))
			end)
		end
	end)

	describe("ns.MaySavePrevious", function()
		it("holds only with no fishing pole in hand (QOL-R42, QOL-R44)", function()
			assert.is_true(ns.MaySavePrevious(false))
			assert.is_false(ns.MaySavePrevious(true))
		end)
	end)

	describe("ns.SwapGearAction", function()
		-- Pagle Previous as the game reads it: its main hand holds no fishing pole.
		local PREVIOUS = { hasPole = false }

		it("swaps back with the set fully worn and Pagle Previous there (QOL-R46, QOL-R45)", function()
			assert.are.equal("back", ns.SwapGearAction(true, set({ isEquipped = true }), PREVIOUS, false))
		end)

		it("does nothing with the set fully worn and no Pagle Previous (QOL-R46)", function()
			assert.are.equal("nothing", ns.SwapGearAction(true, set({ isEquipped = true }), nil, false))
		end)

		it("counts a Pagle Previous with a pole in its main hand as absent (QOL-R46)", function()
			local polePrevious = { hasPole = true }
			assert.are.equal("nothing", ns.SwapGearAction(true, set({ isEquipped = true }), polePrevious, false))
		end)

		it("swaps to the set while it is partly worn or not at all, with nothing missing (QOL-R46, QOL-R44)", function()
			assert.are.equal("equip", ns.SwapGearAction(true, set(), PREVIOUS, false))
			assert.are.equal("equip", ns.SwapGearAction(true, set(), nil, false))
			assert.are.equal("equip", ns.SwapGearAction(true, set(), { hasPole = true }, false))
			-- With no pole in it too: Swap gear isn't the gear step (QOL-R43).
			assert.are.equal("equip", ns.SwapGearAction(true, set({ hasPole = false }), PREVIOUS, false))
		end)

		it("does nothing with an item of the set missing (QOL-R46)", function()
			assert.are.equal("nothing", ns.SwapGearAction(true, set({ numLost = 2 }), PREVIOUS, false))
		end)

		it("does nothing while disarmed, with no set chosen, or while a swap settles (QOL-R46, QOL-R29)", function()
			assert.are.equal("nothing", ns.SwapGearAction(false, set(), PREVIOUS, false))
			assert.are.equal("nothing", ns.SwapGearAction(true, nil, PREVIOUS, false))
			assert.are.equal("nothing", ns.SwapGearAction(true, set(), PREVIOUS, true))
			assert.are.equal("nothing", ns.SwapGearAction(true, set({ isEquipped = true }), PREVIOUS, true))
		end)
	end)

	describe("a swap's result wait", function()
		it("settles a swap until EQUIPMENT_SWAP_FINISHED (QOL-R29)", function()
			local gear = ns.NewGearState()
			assert.is_false(gear:Settling(10))

			gear:Swapped(10)
			assert.is_true(gear:Settling(10.5))
			gear:SwapFinished()
			assert.is_false(gear:Settling(10.5))
		end)

		it("settles it for the 2 s result wait at most (QOL-R29, qol.md › Tunables)", function()
			local gear = ns.NewGearState()

			gear:Swapped(10)

			assert.is_true(gear:Settling(11.9))
			assert.is_false(gear:Settling(12))
		end)
	end)

	describe("ns.SwapBackNudge", function()
		it("names the key bound to Swap gear, on a key cap (QOL-R77)", function()
			local parts = ns.SwapBackNudge("s-G")

			assert.are.same({ "Still holding your pole. Press", { key = "s-G" }, "to swap back." }, parts)
			assert.are.equal("Still holding your pole. Press s-G to swap back.", ns.NudgeText(parts))
		end)

		it("asks for a binding while Swap gear has none, its name in red (QOL-R77)", function()
			local parts = ns.SwapBackNudge(nil)

			assert.are.same(
				{ "Still holding your pole. Bind", { em = "Pagle: Swap gear" }, "to swap back in one press." },
				parts
			)
			assert.are.equal(
				"Still holding your pole. Bind Pagle: Swap gear to swap back in one press.",
				ns.NudgeText(parts)
			)
		end)
	end)

	describe("ns.FishingSetIcon", function()
		it("is the pole's icon with a pole in hand, else the Fishing spell's (QOL-R41)", function()
			assert.are.equal(132932, ns.FishingSetIcon(true, 132932, 136245))
			assert.are.equal(136245, ns.FishingSetIcon(false, 135274, 136245))
			assert.are.equal(136245, ns.FishingSetIcon(false, nil, 136245))
		end)
	end)
end)
