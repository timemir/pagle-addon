-- A Species' page with no Core (DATA-R112, LED-R141): the plain hint, generated from a hand-made world index.

describe("the plain hint", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	local FISH = 13759
	local ELWYNN, WESTFALL, DUSKWOOD, MOONGLADE = 12, 40, 10, 493
	local NAMES =
		{ [ELWYNN] = "Elwynn Forest", [WESTFALL] = "Westfall", [DUSKWOOD] = "Duskwood", [MOONGLADE] = "Moonglade" }

	-- The Journal's words, as far as the hint reads them: zone names and window labels.
	local text = {
		Zone = function(_, zone)
			return NAMES[zone] or "..."
		end,
		WindowLabel = function(_, window)
			return ns.WindowLabel(window)
		end,
	}

	-- A world index (LED-R10) where FISH is listed in `zones`, with element windows `elements` (window IDs) and
	-- pool-associated in the zones of `pools`. Skill bases: Elwynn 25, Westfall 55, Duskwood 150; Moonglade none.
	local function world(zones, elements, pools)
		local index = {
			zones = {},
			species = {},
			skillBase = { [ELWYNN] = 25, [WESTFALL] = 55, [DUSKWOOD] = 150 },
		}
		local listed = {}
		for _, zone in ipairs(zones) do
			listed[#listed + 1] = zone
			index.zones[zone] =
				{ species = { [FISH] = { gated = true, windows = {}, pool = pools and pools[zone] or false } } }
		end
		table.sort(listed)
		local windows
		if elements then
			windows = {}
			for _, window in ipairs(elements) do
				windows[window] = { time = { { 1200, 360 } } }
			end
		end
		index.species[FISH] = { zones = listed, elements = windows }
		return index
	end

	it(
		"reads windows, pools, the first two zones by skill base, the rest and their lowest skill (DATA-R112, LED-R141)",
		function()
			local hint =
				ns.PlainHint(world({ DUSKWOOD, ELWYNN, WESTFALL }, { "night" }, { [DUSKWOOD] = true }), FISH, text)

			assert.are.equal("night · pools · Elwynn Forest · Westfall +1 · skill ~25", hint)
		end
	)

	it("is the window part alone with no listed zones (LED-R141)", function()
		assert.are.equal("night", ns.PlainHint(world({}, { "night" }), FISH, text))
	end)

	it(
		'reads "Any time" without element windows, joins several, and sorts zones without a skill base last (LED-R141)',
		function()
			assert.are.equal(
				"Any time · Duskwood · Moonglade · skill ~150",
				ns.PlainHint(world({ MOONGLADE, DUSKWOOD }), FISH, text)
			)
			assert.are.equal(
				"day, summer · Moonglade",
				ns.PlainHint(world({ MOONGLADE }, { "summer", "day" }), FISH, text)
			)
		end
	)

	it("reads any skill when the lowest skill base of the two zones is 0 or below (LED-R141, DATA-R30)", function()
		local index = world({ ELWYNN, WESTFALL })
		index.skillBase[ELWYNN], index.skillBase[WESTFALL] = -70, 0

		assert.are.equal("Any time · Elwynn Forest · Westfall · any skill", ns.PlainHint(index, FISH, text))
	end)

	it("leaves the skill out when neither of the two zones has a skill base (LED-R141)", function()
		assert.are.equal("Any time · Moonglade", ns.PlainHint(world({ MOONGLADE }), FISH, text))
	end)
end)

describe("the Journal's search", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	-- Seven charted zones and one fished uncharted zone named "Lake {n}", eight caught Species named "Lake fish {n}",
	-- one caught Species whose name isn't loaded yet (9), and one uncaught Species, "Lake secret" (10), listed.
	local zoneNames, itemNames = {}, { [10] = "Lake secret" }
	local world = { charted = {}, zones = {}, species = { [10] = { zones = { 101 } } }, skillBase = {} }
	local state = { species = {}, zones = { [108] = {} } }
	for n = 1, 8 do
		zoneNames[100 + n] = "Lake " .. (9 - n)
		itemNames[n] = "Lake fish " .. (9 - n)
		state.species[n] = { n = 1, zones = {} }
		if n < 8 then
			world.charted[n] = 100 + n
			world.zones[100 + n] = { species = {} }
		end
	end
	state.species[9] = { n = 1, zones = {} }
	-- The Journal's words, as far as search reads them: zone and item names, "…" while unknown.
	local names = {}
	function names.Zone(_, zone)
		return zoneNames[zone] or "..."
	end
	function names.Item(_, id)
		return itemNames[id] or "..."
	end
	---@type LedgerJournalContext
	local context = { updating = false, state = state, world = world, now = 0, formatNumber = tostring, text = names }

	local function labels(results)
		local list = {}
		for i, result in ipairs(results) do
			list[i] = result.label
		end
		return list
	end

	it("shows at most 4 zones, then 6 caught fish, each part sorted by name, never one uncaught (LED-R148)", function()
		local results = ns.JournalSearch("LAKE", context)

		assert.are.same({
			"Lake 1",
			"Lake 2",
			"Lake 3",
			"Lake 4",
			"Lake fish 1",
			"Lake fish 2",
			"Lake fish 3",
			"Lake fish 4",
			"Lake fish 5",
			"Lake fish 6",
		}, labels(results))
		assert.are.same({ id = "zone", args = { zone = 108 } }, results[1].place)
		assert.are.same({ id = "fish", args = { species = 8 } }, results[5].place)
	end)

	it("matches from the first character, anywhere in the name (LED-R148)", function()
		assert.are.same({ "Lake 5" }, labels(ns.JournalSearch("e 5", context)))
	end)

	it("finds nothing for a name not loaded yet, nor for an empty box (LED-R148, LED-R126)", function()
		assert.are.same({}, ns.JournalSearch("...", context))
		assert.is_nil(ns.JournalSearch("", context))
	end)
end)
