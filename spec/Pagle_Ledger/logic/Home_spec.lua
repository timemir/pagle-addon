-- Home's Notes to self (LED-R133) through ns.NotesToSelf, over hand-made world indexes, states and celebrated sets,
-- with no Core and no frame: which notes apply, their order, their tie-breaks and their words.

describe("Home's Notes to self (LED-R133)", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	-- Words as context.text gives them: zones and items by ID.
	local text = {
		Zone = function(_, zone)
			return "Zone " .. zone
		end,
		Item = function(_, itemID)
			return "Fish " .. itemID
		end,
	}

	-- A charted zone listing `ungated` and `gated` Species (IDs), nothing else.
	local function listed(ungated, gated)
		local species = {}
		for _, id in ipairs(ungated) do
			species[id] = { gated = false, windows = {}, pool = false }
		end
		for _, id in ipairs(gated or {}) do
			species[id] = { gated = true, windows = { night = {} }, pool = false }
		end
		return { list = {}, species = species, families = {}, junk = false, treasure = false }
	end

	-- A world of `zones` (areaID -> listed()) with skill bases `skill` (areaID -> skill base).
	local function worldOf(zones, skill)
		local world = {
			zones = zones,
			charted = {},
			legends = {},
			species = {},
			items = {},
			families = {},
			skillBase = skill or {},
		}
		for zone in pairs(zones) do
			world.charted[#world.charted + 1] = zone
			for id in pairs(zones[zone].species) do
				world.species[id] = world.species[id] or { zones = {} }
				table.insert(world.species[id].zones, zone)
			end
		end
		table.sort(world.charted)
		return world
	end

	-- A state where each zone of `caught` (areaID -> Species IDs) has those Species caught there, at its computed rank
	-- `ranks[zone]`, and each Species of `counts` (ID -> Catches) is caught that often.
	local function stateOf(caught, ranks, counts)
		local state = { species = {}, zones = {}, items = {}, prestige = 0, xp = 0, catches = 0 }
		for zone, ids in pairs(caught) do
			local zoneState = ns.NewZoneState()
			zoneState.rank = ranks[zone]
			for _, id in ipairs(ids) do
				zoneState.species[id] = true
				state.species[id] = state.species[id] or { n = 0, zones = {}, windowsMet = {} }
				state.species[id].zones[zone] = true
			end
			state.zones[zone] = zoneState
		end
		for id, n in pairs(counts or {}) do
			state.species[id] = state.species[id] or { n = 0, zones = {}, windowsMet = {} }
			state.species[id].n = n
		end
		return state
	end

	-- The notes for this world and state, as { text, zone or species opened }.
	local function notes(world, state, celebrated, items)
		local context = {
			updating = false,
			world = world,
			state = state,
			celebrated = celebrated
				or { zones = {}, levels = {}, species = {}, speciesZones = {}, skill = {}, coins = 0 },
			text = text,
			getItem = function(itemID)
				return (items or {})[itemID] or { category = "fish", species = itemID, removed = false }
			end,
		}
		local out = {}
		for i, note in ipairs(ns.NotesToSelf(context)) do
			local args = note.place and note.place.args or {}
			out[i] = { note.text, note.place and note.place.id, args.zone or args.species }
		end
		return out
	end

	it('reads "Go fishing!", opening nothing, when no note applies (LED-R133)', function()
		assert.are.same({ { "Go fishing!" } }, notes(worldOf({ [12] = listed({ 1 }) }), stateOf({}, {})))
	end)

	it(
		"notes the next rank of the fished zone with the highest completion, Visitor to Expert (LED-R133, LED-R134)",
		function()
			-- Zone 12 is Regular at 2 of 4 (50%); zone 40 Local at 2 of 3 (66%); zone 10 is Master and left out.
			local world =
				worldOf({ [12] = listed({ 1, 2, 3, 4 }), [40] = listed({ 5, 6 }, { 8 }), [10] = listed({ 7 }) })
			local state = stateOf({ [12] = { 1, 2 }, [40] = { 5, 6 }, [10] = { 7 } }, { [12] = 2, [40] = 3, [10] = 5 })

			assert.are.same(
				{ "Zone 40: Local. Expert: 1 more day, night, seasonal or event catch", "zone", 40 },
				notes(world, state)[1]
			)
		end
	)

	it("breaks a completion tie by higher rank, then lower skill base, then lower areaID (LED-R133)", function()
		-- Each is at 50%: 30 is Local (both ungated caught, the gated pair not); 20, 21 and 12 are Regular, 20 and 21
		-- at skill 50, 12 at skill 100.
		local zones = {
			[30] = listed({ 1, 2 }, { 3, 4 }),
			[20] = listed({ 5, 6 }),
			[21] = listed({ 7, 8 }),
			[12] = listed({ 9, 10 }),
		}
		local caught = { [30] = { 1, 2 }, [20] = { 5 }, [21] = { 7 }, [12] = { 9 } }
		local ranks = { [30] = 3, [20] = 2, [21] = 2, [12] = 2 }
		local skill = { [30] = 300, [20] = 50, [21] = 50, [12] = 100 }

		assert.are.equal(30, notes(worldOf(zones, skill), stateOf(caught, ranks))[1][3])
		zones[30], caught[30] = nil, nil
		assert.are.equal(20, notes(worldOf(zones, skill), stateOf(caught, ranks))[1][3])
		skill[21] = 25
		assert.are.equal(21, notes(worldOf(zones, skill), stateOf(caught, ranks))[1][3])
	end)

	it(
		"leaves a zone with new to find out of the next rank, and notes the first such in tile order (LED-R133)",
		function()
			-- Both are Regular by their Catches; 40 (skill 50) was celebrated Local and 12 (skill 100) Expert.
			local world = worldOf(
				{ [12] = listed({ 1, 2 }, { 3 }), [40] = listed({ 5, 6 }) },
				{ [12] = 100, [40] = 50 }
			)
			local state = stateOf({ [12] = { 1 }, [40] = { 5 } }, { [12] = 2, [40] = 2 }, { [1] = 1, [5] = 1 })
			local celebrated =
				{ zones = { [12] = 4, [40] = 3 }, levels = {}, species = {}, speciesZones = {}, skill = {} }

			assert.are.same({
				{ "Zone 40: 1 new to find", "zone", 40 },
				{ drawnSymbols("Fish 1: 4 to ★"), "fish", 1 },
			}, notes(world, state, celebrated))
		end
	)

	it(
		"notes the caught, not removed Species without ★★★ with the most Catches, ties by lower ID (LED-R133)",
		function()
			local world = worldOf({ [12] = listed({ 1, 2, 3, 4 }) })
			-- 4 has 50 Catches (★★★), 3 is removed; 1 and 2 tie at 12.
			local state = stateOf({}, {}, { [1] = 12, [2] = 12, [3] = 40, [4] = 50 })
			local items = { [3] = { category = "fish", species = 3, removed = true } }

			assert.are.same({ { drawnSymbols("Fish 1: 38 to ★★★"), "fish", 1 } }, notes(world, state, nil, items))
		end
	)

	it(
		"counts down to ★ while it isn't shown, then to ★★★, a celebrated ★ counting as shown (LED-R133, LED-R45, LED-R48)",
		function()
			local world = worldOf({ [12] = listed({ 1 }) })
			local function note(n, celebrated)
				return notes(world, stateOf({}, {}, { [1] = n }), celebrated)[1][1]
			end
			local celebrated = {
				zones = {},
				levels = {},
				species = {},
				speciesZones = {},
				skill = {},
				stars = { [1] = { [1] = true } },
			}

			assert.are.equal(drawnSymbols("Fish 1: 2 to ★"), note(3))
			assert.are.equal(drawnSymbols("Fish 1: 45 to ★★★"), note(5))
			assert.are.equal(drawnSymbols("Fish 1: 47 to ★★★"), note(3, celebrated))
		end
	)

	it("skips a Species whose ★★★ was celebrated (LED-R133, LED-R48)", function()
		local world = worldOf({ [12] = listed({ 1, 2 }) })
		local state = stateOf({}, {}, { [1] = 30, [2] = 5 })
		local celebrated =
			{ zones = {}, levels = {}, species = {}, speciesZones = {}, skill = {}, stars = { [1] = { [3] = true } } }

		assert.are.same({ { drawnSymbols("Fish 2: 45 to ★★★"), "fish", 2 } }, notes(world, state, celebrated))
	end)

	it("gives at most the three notes, in order: next rank, new to find, next star (LED-R133)", function()
		local world = worldOf({ [12] = listed({ 1, 2 }), [40] = listed({ 5, 6 }) }, { [12] = 25, [40] = 75 })
		local state = stateOf({ [12] = { 1 }, [40] = { 5 } }, { [12] = 2, [40] = 2 }, { [1] = 3, [5] = 7 })
		local celebrated = { zones = { [40] = 3 }, levels = {}, species = {}, speciesZones = {}, skill = {} }

		assert.are.same({
			{ "Zone 12: Regular. Local: 1 more any-time Species", "zone", 12 },
			{ "Zone 40: 1 new to find", "zone", 40 },
			{ drawnSymbols("Fish 5: 43 to ★★★"), "fish", 5 },
		}, notes(world, state, celebrated))
	end)
end)

describe("a zone tile (LED-R131)", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	it("reads any skill for a charted, unfished zone whose skill base is 0 or below (LED-R131, DATA-R30)", function()
		local charted = { list = {}, species = {}, families = {}, junk = false, treasure = false }
		local context = {
			updating = false,
			now = SERVER_TIME,
			formatNumber = breakUpLargeNumbers,
			world = {
				zones = { [1] = charted, [2] = charted, [3] = charted },
				charted = { 1, 2, 3 },
				legends = {},
				species = {},
				items = {},
				families = {},
				skillBase = { [1] = -70, [2] = 0, [3] = 1 },
				getItem = function() end,
			},
			state = { zones = {} },
			text = {
				Zone = function(_, zone)
					return "Zone " .. zone
				end,
			},
		}

		local lines = {}
		for zone = 1, 3 do
			lines[zone] = ns.JournalZoneTile(zone, context).line
		end

		assert.are.same({ "unfished · any skill", "unfished · any skill", "unfished · skill ~1" }, lines)
	end)
end)
