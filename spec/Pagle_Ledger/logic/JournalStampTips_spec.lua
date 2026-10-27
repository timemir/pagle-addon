-- The tooltips on a Species' and a trophy family's three stamps with no Core (LED-R165): the rule and where the player
-- stands, as data, over a hand-made world index and state.

describe("the stamp tooltips", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	local FISH = 13759
	local ELWYNN, WESTFALL, DUSKWOOD = 12, 40, 10

	-- The Journal's words, as far as a tooltip reads them: window labels.
	local text = {
		WindowLabel = function(_, window)
			return ns.WindowLabel(window)
		end,
	}

	-- A world index (LED-R10) where FISH is listed in `zones`, with element windows `elements` (window IDs).
	local function world(zones, elements)
		local windows
		if elements then
			windows = {}
			for _, window in ipairs(elements) do
				windows[window] = { time = { { 1200, 360 } } }
			end
		end
		return { species = { [FISH] = { zones = zones, elements = windows } } }
	end

	-- A state where FISH is caught `n` times, in `zones` (a list), with the element windows `met` met (a list).
	local function state(n, zones, met)
		local species = { n = n, zones = {}, windowsMet = {} }
		for _, zone in ipairs(zones or {}) do
			species.zones[zone] = true
		end
		for _, window in ipairs(met or {}) do
			species.windowsMet[window] = true
		end
		return { species = { [FISH] = species }, items = {} }
	end

	describe("of a Species (LED-R165)", function()
		it("says nothing for a Species not caught: it has no stamps to hover (LED-R124)", function()
			assert.is_nil(ns.SpeciesStampTips(world({ ELWYNN }), { species = {}, items = {} }, FISH, text))
		end)

		it("is three tips, titled as the stamps are (LED-R140)", function()
			local tips = ns.SpeciesStampTips(world({ ELWYNN }), state(2, { ELWYNN }), FISH, text)

			assert.are.same({ "Caught", "In its element", "Regular" }, { tips[1].title, tips[2].title, tips[3].title })
		end)

		it("gives Caught its rule and how many are landed, counting no further than 5 (LED-R45)", function()
			local early = ns.SpeciesStampTips(world({ ELWYNN }), state(3, { ELWYNN }), FISH, text)
			local done = ns.SpeciesStampTips(world({ ELWYNN }), state(9, { ELWYNN }), FISH, text)

			assert.are.same({ "Land it 5 times.", "3 of 5 landed." }, early[1].lines)
			assert.are.same({ "Land it 5 times.", "5 of 5 landed." }, done[1].lines)
		end)

		it("gives Regular its rule and how many are landed, counting no further than 50 (LED-R45)", function()
			local early = ns.SpeciesStampTips(world({ ELWYNN }), state(12, { ELWYNN }), FISH, text)
			local done = ns.SpeciesStampTips(world({ ELWYNN }), state(80, { ELWYNN }), FISH, text)

			assert.are.same({ "Land it 50 times.", "12 of 50 landed." }, early[3].lines)
			assert.are.same({ "Land it 50 times.", "50 of 50 landed." }, done[3].lines)
		end)

		it("takes the singular when one Catch is all a star asks for", function()
			local tunable = ns.CAUGHT_STAR_CATCHES
			ns.CAUGHT_STAR_CATCHES = 1
			local ok, tips = pcall(ns.SpeciesStampTips, world({ ELWYNN }), state(1, { ELWYNN }), FISH, text)
			ns.CAUGHT_STAR_CATCHES = tunable

			assert.is_true(ok)
			assert.are.same({ "Land it 1 time.", "1 of 1 landed." }, tips[1].lines)
		end)

		it("names the windows still to be met for In its element, with windows (LED-R45, LED-R10)", function()
			local tips =
				ns.SpeciesStampTips(world({ ELWYNN }, { "night", "summer" }), state(2, {}, { "night" }), FISH, text)

			assert.are.same({
				"Land it under each of its 2 element windows, in any zone.",
				"1 of 2 met. Still needed: summer.",
			}, tips[2].lines)
		end)

		it("lists every window still needed, joined as prose", function()
			local tips = ns.SpeciesStampTips(
				world({ ELWYNN }, { "day", "night", "summer" }),
				state(2, {}, { "night" }),
				FISH,
				text
			)

			assert.are.same("1 of 3 met. Still needed: day and summer.", tips[2].lines[2])
			assert.are.same("Land it under each of its 3 element windows, in any zone.", tips[2].lines[1])
		end)

		it("names all the windows once they are all met (LED-R45)", function()
			local tips = ns.SpeciesStampTips(
				world({ ELWYNN }, { "night", "summer" }),
				state(2, {}, { "night", "summer" }),
				FISH,
				text
			)

			assert.are.same({
				"Land it under each of its 2 element windows, in any zone.",
				"All met: night and summer.",
			}, tips[2].lines)
		end)

		it("takes the singular for a Species with one window", function()
			local blank = ns.SpeciesStampTips(world({ ELWYNN }, { "night" }), state(2, {}), FISH, text)
			local met = ns.SpeciesStampTips(world({ ELWYNN }, { "night" }), state(2, {}, { "night" }), FISH, text)

			assert.are.same({
				"Land it under its element window, in any zone.",
				"0 of 1 met. Still needed: night.",
			}, blank[2].lines)
			assert.are.same("All met: night.", met[2].lines[2])
		end)

		it("counts different zones for In its element without windows, up to 3 (LED-R45)", function()
			local listed = world({ ELWYNN, WESTFALL, DUSKWOOD, 99 })

			local few = ns.SpeciesStampTips(listed, state(2, { ELWYNN }), FISH, text)
			local all = ns.SpeciesStampTips(listed, state(9, { ELWYNN, WESTFALL, DUSKWOOD, 99 }), FISH, text)

			assert.are.same({ "Land it in 3 different zones.", "In 1 of 3 zones." }, few[2].lines)
			assert.are.same({ "Land it in 3 different zones.", "In 3 of 3 zones." }, all[2].lines)
		end)

		it("takes the zones needed from the zones listed, and the singular for one (LED-R45)", function()
			local two = ns.SpeciesStampTips(world({ ELWYNN, WESTFALL }), state(2, { ELWYNN }), FISH, text)
			local one = ns.SpeciesStampTips(world({ ELWYNN }), state(2, { ELWYNN }), FISH, text)
			local none = ns.SpeciesStampTips(world({ ELWYNN }), state(2, {}), FISH, text)

			assert.are.same({ "Land it in 2 different zones.", "In 1 of 2 zones." }, two[2].lines)
			assert.are.same({ "Land it in any zone.", "In 1 of 1 zone." }, one[2].lines)
			assert.are.same({ "Land it in any zone.", "In 0 of 1 zone." }, none[2].lines)
		end)

		it("reads a Species on no list as needing one zone (LED-R45)", function()
			local tips = ns.SpeciesStampTips({ species = {} }, state(2, { ELWYNN }), FISH, text)

			assert.are.same({ "Land it in any zone.", "In 1 of 1 zone." }, tips[2].lines)
		end)
	end)

	describe("of a trophy family (LED-R165, LED-R47)", function()
		local FAMILY = 2
		local W17, W19, W22, W26 = 9017, 9019, 9022, 9026
		local WEIGHT = { [W17] = 17, [W19] = 19, [W22] = 22, [W26] = 26 }

		-- A world where the family lists `weights` (item IDs), the heaviest last.
		local function family(weights)
			return {
				families = { [FAMILY] = { weights = weights, heaviest = weights[#weights] } },
				getItem = function(itemID)
					return { weight = WEIGHT[itemID] }
				end,
			}
		end

		local function landed(...)
			local items = {}
			for _, itemID in ipairs({ ... }) do
				items[itemID] = true
			end
			return { items = items }
		end

		local FOUR = { W17, W19, W22, W26 }

		it("is three tips, titled as the stamps are (LED-R143)", function()
			local tips = ns.FamilyStampTips(family(FOUR), landed(), FAMILY, {})

			assert.are.same(
				{ "Any weight", "Half the weights", "The heaviest" },
				{ tips[1].title, tips[2].title, tips[3].title }
			)
		end)

		it("says Any weight is waiting, then counts the listed weights landed", function()
			local none = ns.FamilyStampTips(family(FOUR), landed(), FAMILY, {})
			local some = ns.FamilyStampTips(family(FOUR), landed(W17, W22), FAMILY, { true })

			assert.are.same({ "Land any weight of this family.", "None landed yet." }, none[1].lines)
			assert.are.same({ "Land any weight of this family.", "2 of 4 weights landed." }, some[1].lines)
		end)

		it("says so when only a weight off the list is landed", function()
			local tips = ns.FamilyStampTips(family(FOUR), landed(), FAMILY, { true })

			assert.are.same(
				{ "Land any weight of this family.", "Landed, though not on this family's list." },
				tips[1].lines
			)
		end)

		it("takes the singular for a family with one listed weight", function()
			local tips = ns.FamilyStampTips(family({ W17 }), landed(W17), FAMILY, { true, true, true })

			assert.are.same("1 of 1 weight landed.", tips[1].lines[2])
			assert.are.same({ "Land its one listed weight.", "1 of 1 weight landed." }, tips[2].lines)
		end)

		it("asks for at least half of the listed weights, rounded up (LED-R47)", function()
			local four = ns.FamilyStampTips(family(FOUR), landed(W17), FAMILY, {})
			local three = ns.FamilyStampTips(family({ W17, W19, W22 }), landed(W17), FAMILY, {})

			assert.are.same({ "Land at least 2 of its 4 listed weights.", "1 of 4 weights landed." }, four[2].lines)
			assert.are.same({ "Land at least 2 of its 3 listed weights.", "1 of 3 weights landed." }, three[2].lines)
		end)

		it("names the heaviest listed weight in pounds (LED-R47)", function()
			local before = ns.FamilyStampTips(family(FOUR), landed(W17), FAMILY, {})
			local after = ns.FamilyStampTips(family(FOUR), landed(W17, W26), FAMILY, { true, true, true })

			assert.are.same({ "Land its heaviest listed weight, 26 lb.", "Not yet." }, before[3].lines)
			assert.are.same({ "Land its heaviest listed weight, 26 lb.", "Landed." }, after[3].lines)
		end)

		it("writes the weight through the number formatter given", function()
			local tips = ns.FamilyStampTips(family(FOUR), landed(), FAMILY, {}, function(n)
				return "<" .. n .. ">"
			end)

			assert.are.same("Land its heaviest listed weight, <26> lb.", tips[3].lines[1])
		end)

		it("reads a star already celebrated as landed, though the log no longer shows it (LED-R47, LED-R92)", function()
			local tips = ns.FamilyStampTips(family(FOUR), landed(), FAMILY, { false, false, true })

			assert.are.same("Landed.", tips[3].lines[2])
		end)

		it("has no half or heaviest to land with no listed weights (LED-R47)", function()
			local tips = ns.FamilyStampTips(family({}), landed(), FAMILY, {})

			assert.are.same({ "This family lists no weights yet." }, tips[2].lines)
			assert.are.same({ "This family lists no weights yet." }, tips[3].lines)
			assert.are.same({ "Land any weight of this family.", "None landed yet." }, tips[1].lines)
		end)

		it("reads a family the world does not list as having no listed weights (LED-R47)", function()
			local tips = ns.FamilyStampTips({ families = {}, getItem = function() end }, landed(), 77, {})

			assert.are.same({ "This family lists no weights yet." }, tips[2].lines)
		end)
	end)
end)
