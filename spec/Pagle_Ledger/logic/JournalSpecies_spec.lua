-- A Species' page with no Core (DATA-R112, LED-R141): the plain hint, generated from a hand-made world index.

describe("the plain hint", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	local FISH = 13759
	local ELWYNN, WESTFALL, DUSKWOOD, MOONGLADE = 12, 40, 10, 493
	local NAMES = { [ELWYNN] = "Elwynn Forest", [WESTFALL] = "Westfall", [DUSKWOOD] = "Duskwood", [MOONGLADE] = "Moonglade" }

	-- The Journal's words, as far as the hint reads them: zone names and window labels.
	local text = {
		Zone = function(_, zone)
			return NAMES[zone] or "…"
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
			index.zones[zone] = { species = { [FISH] = { gated = true, windows = {}, pool = pools and pools[zone] or false } } }
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

	it("reads windows, pools, the first two zones by skill base, the rest and their lowest skill (DATA-R112, LED-R141)", function()
		local hint = ns.PlainHint(world({ DUSKWOOD, ELWYNN, WESTFALL }, { "night" }, { [DUSKWOOD] = true }), FISH, text)

		assert.are.equal("night · pools · Elwynn Forest · Westfall +1 · skill ~25", hint)
	end)

	it('is the window part alone with no listed zones (LED-R141)', function()
		assert.are.equal("night", ns.PlainHint(world({}, { "night" }), FISH, text))
	end)

	it('reads "Any time" without element windows, joins several, and sorts zones without a skill base last (LED-R141)', function()
		assert.are.equal("Any time · Duskwood · Moonglade · skill ~150", ns.PlainHint(world({ MOONGLADE, DUSKWOOD }), FISH, text))
		assert.are.equal(
			"day, summer · Moonglade",
			ns.PlainHint(world({ MOONGLADE }, { "summer", "day" }), FISH, text)
		)
	end)

	it("leaves the skill out when neither of the two zones has a skill base (LED-R141)", function()
		assert.are.equal("Any time · Moonglade", ns.PlainHint(world({ MOONGLADE }), FISH, text))
	end)
end)
