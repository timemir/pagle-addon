-- Lures' pure logic: the lure table (QOL-R54), which lure is next (QOL-R50, QOL-R51), the result wait and the skips
-- (QOL-R29), and the out-of-lures Nudge (QOL-R53).

describe("QoL's lure logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.LURES", function()
		it("is the six Classic lures with item ID, enchant ID and bonus (QOL-R54)", function()
			local rows = {}
			for i, lure in ipairs(ns.LURES) do
				rows[i] = { lure.itemID, lure.enchantID, lure.bonus }
			end

			-- qol.md › Lures, QOL-R54's table, row for row.
			assert.are.same({
				{ 6529, 263, 25 }, -- Shiny Bauble
				{ 6530, 264, 50 }, -- Nightcrawlers
				{ 6811, 264, 50 }, -- Aquadynamic Fish Lens
				{ 6532, 265, 75 }, -- Bright Baubles
				{ 7307, 265, 75 }, -- Flesh Eating Worm
				{ 6533, 266, 100 }, -- Aquadynamic Fish Attractor
			}, rows)
		end)

		it("holds no names: they come from C_Item at runtime (QOL-R54)", function()
			for _, lure in ipairs(ns.LURES) do
				assert.is_nil(lure.name)
			end
		end)
	end)

	describe("ns.ChooseLure", function()
		local SHINY_BAUBLE, NIGHTCRAWLERS, FISH_LENS, BRIGHT_BAUBLES, FLESH_EATING_WORM, FISH_ATTRACTOR =
			6529, 6530, 6811, 6532, 7307, 6533

		-- An availability test over these item IDs, as the adapter's bags, usability and skips give it.
		---@param ... integer
		---@return fun(itemID: integer): boolean
		local function have(...)
			local items = {}
			for _, itemID in ipairs({ ... }) do
				items[itemID] = true
			end
			return function(itemID)
				return items[itemID] == true
			end
		end

		it("picks the available lure with the highest bonus under Best I have (QOL-R51)", function()
			assert.are.equal(BRIGHT_BAUBLES, ns.ChooseLure("best", SHINY_BAUBLE, have(SHINY_BAUBLE, BRIGHT_BAUBLES)))
			assert.are.equal(FISH_ATTRACTOR, ns.ChooseLure("best", SHINY_BAUBLE, have(NIGHTCRAWLERS, FISH_ATTRACTOR)))
			assert.are.equal(SHINY_BAUBLE, ns.ChooseLure("best", BRIGHT_BAUBLES, have(SHINY_BAUBLE)))
		end)

		it("breaks a tie in bonus to the lower item ID (QOL-R51)", function()
			assert.are.equal(NIGHTCRAWLERS, ns.ChooseLure("best", SHINY_BAUBLE, have(FISH_LENS, NIGHTCRAWLERS)))
			assert.are.equal(
				BRIGHT_BAUBLES,
				ns.ChooseLure("best", SHINY_BAUBLE, have(FLESH_EATING_WORM, BRIGHT_BAUBLES))
			)
		end)

		it("is the chosen lure under Only this one, and none when it isn't available (QOL-R51)", function()
			local all = have(SHINY_BAUBLE, BRIGHT_BAUBLES, FISH_ATTRACTOR)

			assert.are.equal(SHINY_BAUBLE, ns.ChooseLure("one", SHINY_BAUBLE, all))
			assert.is_nil(ns.ChooseLure("one", NIGHTCRAWLERS, all))
		end)

		it("is none under Off, and none with no lure available (QOL-R50, QOL-R51)", function()
			assert.is_nil(ns.ChooseLure("off", SHINY_BAUBLE, have(SHINY_BAUBLE, FISH_ATTRACTOR)))
			assert.is_nil(ns.ChooseLure("best", SHINY_BAUBLE, have()))
		end)

		it("never picks an item that isn't in the lure table, even when chosen (QOL-R96)", function()
			local everything = function()
				return true
			end

			assert.is_nil(ns.ChooseLure("one", 5523, everything)) -- a Small Barnacled Clam
		end)
	end)

	describe("the result wait", function()
		it("lasts 2 s (qol.md › Tunables)", function()
			assert.are.equal(2, ns.RESULT_WAIT)
		end)

		it("counts the pole as lured after a lure's use, until the enchant shows (QOL-R29)", function()
			local lures = ns.NewLureState()

			lures:Applied(6529, 10)
			assert.is_true(lures:Lured(false, 10.5))
			assert.is_true(lures:Lured(true, 11))
			assert.is_true(lures:Lured(true, 30))
			assert.is_false(lures:IsSkipped(6529))
		end)

		it("ends with the enchant shown, so a lure gone later reads as off (QOL-R29)", function()
			local lures = ns.NewLureState()
			lures:Applied(6529, 10)
			lures:Lured(true, 11)

			assert.is_false(lures:Lured(false, 11.5))
			assert.is_false(lures:IsSkipped(6529))
		end)

		it("skips the lure when 2 s pass with no lure on (QOL-R29)", function()
			local lures = ns.NewLureState()
			lures:Applied(6529, 10)

			assert.is_true(lures:Lured(false, 11.9))
			assert.is_false(lures:Lured(false, 12))
			assert.is_true(lures:IsSkipped(6529))
			assert.is_false(lures:IsSkipped(6532))
		end)

		it("is the pole's own reading with no use awaited (QOL-R20, QOL-R29)", function()
			local lures = ns.NewLureState()

			assert.is_false(lures:Lured(false, 0))
			assert.is_true(lures:Lured(true, 0))
		end)
	end)

	describe("skipped lures", function()
		it("are skipped after a failed use until the skips are cleared (QOL-R29)", function()
			local lures = ns.NewLureState()

			lures:Skip(6529)
			lures:Skip(6532)
			assert.is_true(lures:IsSkipped(6529))
			assert.is_true(lures:IsSkipped(6532))

			lures:ClearSkips()
			assert.is_false(lures:IsSkipped(6529))
			assert.is_false(lures:IsSkipped(6532))
		end)
	end)

	describe("the out-of-lures Nudge", function()
		-- Feeds the pole's lure readings to a fresh state, all during stretch 1 under Best I have with none left.
		---@param readings boolean[]
		---@return boolean[] what each reading answered
		local function read(readings)
			local lures = ns.NewLureState()
			local answers = {}
			for i, enchanted in ipairs(readings) do
				answers[i] = lures:OutOfLures(enchanted, 1, "best", nil)
			end
			return answers
		end

		it("is due when the pole's lure goes from on to off, with none available (QOL-R53)", function()
			assert.are.same({ false, false, true }, read({ true, true, false }))
		end)

		it("isn't due for a pole that had no lure on, nor before a first reading (QOL-R53)", function()
			assert.are.same({ false, false }, read({ false, false }))
		end)

		it("is due at most once per Fishing stretch (QOL-R53)", function()
			local lures = ns.NewLureState()
			lures:OutOfLures(true, 1, "best", nil)
			assert.is_true(lures:OutOfLures(false, 1, "best", nil))

			lures:OutOfLures(true, 1, "best", nil)
			assert.is_false(lures:OutOfLures(false, 1, "best", nil))

			lures:OutOfLures(true, 2, "best", nil)
			assert.is_true(lures:OutOfLures(false, 2, "best", nil))
		end)

		it("isn't due outside a Fishing stretch, under Off, or with a lure left (QOL-R53)", function()
			local cases = {
				{ nil, "best", nil }, -- no stretch running
				{ 1, "off", nil },
				{ 1, "best", 6529 },
				{ 1, "one", 6529 },
			}
			for _, case in ipairs(cases) do
				local lures = ns.NewLureState()
				lures:OutOfLures(true, case[1], case[2], case[3])

				assert.is_false(lures:OutOfLures(false, case[1], case[2], case[3]))
			end
		end)

		it("doesn't count the pole coming off as its lure going off (QOL-R53)", function()
			local lures = ns.NewLureState()
			lures:OutOfLures(true, 1, "best", nil)

			assert.is_false(lures:OutOfLures(nil, 1, "best", nil)) -- no pole in hand
			assert.is_false(lures:OutOfLures(false, 1, "best", nil)) -- a pole with no lure goes on
		end)

		it("reads qol.md's text for Best I have and for Only this one (QOL-R53)", function()
			assert.are.equal("Your lure is gone and there are none left in your bags.", ns.OutOfLuresText("best", nil))
			assert.are.equal(
				"Your lure is gone and there's no Shiny Bauble left in your bags.",
				ns.OutOfLuresText("one", "Shiny Bauble")
			)
		end)
	end)
end)
