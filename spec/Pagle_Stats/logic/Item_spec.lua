-- The item page's lines (stats.md › UI › Item page; STA-R14, STA-R17, STA-R43, STA-R47, STA-R50, STA-R52, STA-R96):
-- when it bites, my records of it and *Where I am* on the left page, the tiles of the waters I've fished for it on the
-- right, over hand-built StatsState tables and the fixture catalogue through Core's own accessors. The book drawing
-- them is in adapter/Item_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN, STRANGLETHORN = 148, 442, 446, 12, 33
local FERALAS, FEATHERMOON = 357, 1116
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN = 6303, 6358, 6359, 13759
local BASS, SMALLFISH, MANA_POTION, UNCHARTED = 13756, 6291, 2455, 77777
local NOW = 1791740000

-- A place record (StatsPlace) with `casts` Casts in `zone`, and catches by item.
local function place(zone, casts, items)
	return { zone = zone, casts = casts, catches = 0, gotAway = 0, items = items or {} }
end

-- A state in stats.md's Projection state shape with what the item page reads.
---@param fields table
---@return StatsState
local function stateWith(fields)
	local state = {
		totals = { casts = 0, catches = 0, gotAway = 0 },
		places = {},
		scopes = {},
		hits = {},
		items = {},
		sessions = {},
	}
	for key, value in pairs(fields) do
		state[key] = value
	end
	return state
end

-- A live snapshot (LOG-R45) in `zone`/`subzone`, by day, with Fishing rank+mod.
local function conditions(zone, subzone, rank, mod)
	return { zone = zone, subzone = subzone, minute = 600, skillRank = rank, skillMod = mod, events = {}, auras = {} }
end

-- The texts of a list of tiles, by field (false for a nil).
local function pluck(list, field)
	local out = {}
	for i, entry in ipairs(list) do
		local value = entry[field]
		if value == nil then
			value = false
		end
		out[i] = value
	end
	return out
end

describe("the item page", function()
	local loaded = stats.load()
	local ns = loaded.ns
	local names = loaded.client.areaNames
	names[DARKSHORE], names[AUBERDINE], names[BASHAL_ARAN] = "Darkshore", "Auberdine", "Bashal'Aran"
	names[ELWYNN], names[STRANGLETHORN] = "Elwynn Forest", "Stranglethorn Vale"
	names[FERALAS], names[FEATHERMOON] = "Feralas", "Feathermoon Stronghold"

	describe("when it bites (stats.md › UI › Item page; STA-R14, STA-R47)", function()
		it("names the window, with its realm-time range, in the zone where I've cast most that lists it", function()
			local state = stateWith({
				places = { [DARKSHORE] = place(DARKSHORE, 30), [ELWYNN] = place(ELWYNN, 10) },
			})

			local facts = ns.ItemFacts(state, NIGHTFIN, conditions(ELWYNN, 0), NOW)

			-- the fixture's night is 18:00–06:00 realm time; Nightfin is night-gated in Darkshore
			assert.are.equal("Bites only by night (18:00–06:00 realm time).", facts.bites)
		end)

		it('reads "Bites at any hour." where its entries carry no window', function()
			local state = stateWith({
				places = { [DARKSHORE] = place(DARKSHORE, 10), [ELWYNN] = place(ELWYNN, 30) },
			})

			-- Nightfin is ungated in Elwynn, where I've cast most
			assert.are.equal("Bites at any hour.", ns.ItemFacts(state, NIGHTFIN, conditions(0, 0), NOW).bites)
		end)

		it("counts the current zone among them, with no Casts of mine there", function()
			local state = stateWith({ places = { [FERALAS] = place(FERALAS, 5) } })

			assert.are.equal(
				"Bites only by night (18:00–06:00 realm time).",
				ns.ItemFacts(state, NIGHTFIN, conditions(ELWYNN, 0), NOW).bites
			)
			assert.are.equal(
				"Bites at any hour.",
				ns.ItemFacts(stateWith({}), NIGHTFIN, conditions(ELWYNN, 0), NOW).bites
			)
		end)

		it("leaves out the range for a window whose spec has no time", function()
			local state = stateWith({ places = { [ELWYNN] = place(ELWYNN, 5) } })

			assert.are.equal("Bites only in summer.", ns.ItemFacts(state, BASS, conditions(0, 0), NOW).bites)
		end)

		it("joins several realm-time ranges with commas", function()
			local catalogue = stats.catalogue()
			catalogue.windows.dusk = { spec = { time = { { 1080, 1140 }, { 300, 360 } } }, confirmed = false }
			catalogue.areas[ELWYNN].catches[#catalogue.areas[ELWYNN].catches + 1] =
				{ itemID = UNCHARTED, confirmed = false, window = "dusk", gate = {}, gateConfirmed = false }
			local own = stats.load(nil, { catalogue = catalogue }).ns

			local facts = own.ItemFacts(stateWith({}), UNCHARTED, conditions(ELWYNN, 0), NOW)

			assert.are.equal("Bites only in its window (18:00–19:00, 05:00–06:00 realm time).", facts.bites)
		end)

		it("is left out when no such zone lists it: Uncharted, Noise, or not listed where I've fished", function()
			local state = stateWith({
				places = {
					[DARKSHORE] = place(DARKSHORE, 5, { [UNCHARTED] = 1 }),
					[STRANGLETHORN] = place(STRANGLETHORN, 5, { [MANA_POTION] = 1 }),
				},
			})

			assert.is_nil(ns.ItemFacts(state, UNCHARTED, conditions(0, 0), NOW).bites)
			assert.is_nil(ns.ItemFacts(state, MANA_POTION, conditions(0, 0), NOW).bites)
			-- Summer Bass is listed only in Elwynn, where I haven't fished
			assert.is_nil(ns.ItemFacts(state, BASS, conditions(DARKSHORE, 0), NOW).bites)
		end)

		it("adds the pool line for a pool-associated item, and no other", function()
			local state = stateWith({ places = { [DARKSHORE] = place(DARKSHORE, 5) } })

			local facts = ns.ItemFacts(state, BLACKMOUTH, conditions(0, 0), NOW)

			assert.are.equal("Bites at any hour.", facts.bites)
			assert.are.equal("Also in pools; with no pool data, both are counted together.", facts.pool)
			assert.is_nil(ns.ItemFacts(state, MACKEREL, conditions(0, 0), NOW).pool)
		end)
	end)

	describe("my records of it (stats.md › UI › Item page; STA-R25)", function()
		it("reads Caught, First caught and Last caught with its time ago", function()
			-- NOW is 11 Oct 2026, 17:33 on the fake's local clock (UTC)
			local state = stateWith({
				items = { [NIGHTFIN] = { n = 1234, first = NOW - 10 * 86400, last = NOW - 3 * 3600 } },
			})

			local facts = ns.ItemFacts(state, NIGHTFIN, conditions(0, 0), NOW)

			assert.are.same(
				{ "1,234", "1 Oct 2026", "11 Oct 2026, 3h ago" },
				{ facts.caught, facts.first, facts.last }
			)
		end)

		it('reads 0 and "—" for an item never caught', function()
			local facts = ns.ItemFacts(stateWith({}), NIGHTFIN, conditions(0, 0), NOW)

			assert.are.same({ "0", "—", "—" }, { facts.caught, facts.first, facts.last })
		end)
	end)

	describe("Where I am (stats.md › UI › Item page; STA-R17, STA-R43, STA-R50)", function()
		-- 200 Casts in Darkshore below its line (75 + 95 = 170; skill 86 + 25 = 111), Mackerel unwindowed there.
		local function darkshore(hit)
			return stateWith({
				places = { [DARKSHORE] = place(DARKSHORE, 200) },
				scopes = { [DARKSHORE .. ":lo"] = 200 },
				hits = { [DARKSHORE .. ":lo#" .. MACKEREL] = hit },
			})
		end

		it("reads the short odds and the Casts since the last, and opens its entry here", function()
			local state = darkshore({ n = 10, at = 180, last = NOW })

			local here = ns.ItemFacts(state, MACKEREL, conditions(DARKSHORE, 0, 86, 25), NOW).here

			assert.are.same({
				area = DARKSHORE,
				place = "Darkshore",
				text = "1 in 20; 20 since the last.",
				target = { page = "place", area = DARKSHORE, item = MACKEREL },
			}, here)
		end)

		it("reads its other two forms: caught on my last Cast, and none yet", function()
			local caught = ns.ItemFacts(darkshore({ n = 10, at = 200, last = NOW }), MACKEREL, conditions(DARKSHORE, 0, 86, 25), NOW)
			local never = ns.ItemFacts(darkshore(nil), MACKEREL, conditions(DARKSHORE, 0, 86, 25), NOW)

			assert.are.equal("1 in 20; caught on my last Cast.", caught.here.text)
			assert.are.equal("not seen yet; none yet.", never.here.text)
		end)

		it("reads learning odds in short while the scope has fewer than 100 Casts", function()
			local state = stateWith({
				places = { [DARKSHORE] = place(DARKSHORE, 40) },
				scopes = { [DARKSHORE .. ":lo"] = 40 },
				hits = { [DARKSHORE .. ":lo#" .. MACKEREL] = { n = 2, at = 30, last = NOW } },
			})

			local here = ns.ItemFacts(state, MACKEREL, conditions(DARKSHORE, 0, 86, 25), NOW).here

			assert.are.equal("learning 40/100; 10 since the last.", here.text)
		end)

		it("shows only when the item is on the current place's rows", function()
			local state = darkshore({ n = 10, at = 180, last = NOW })

			-- Auberdine's rows are its own list (Firefin, Smallfish) and what I caught there
			assert.is_nil(ns.ItemFacts(state, MACKEREL, conditions(DARKSHORE, AUBERDINE, 86, 25), NOW).here)
			assert.is_nil(ns.ItemFacts(state, MACKEREL, conditions(0, 0), NOW).here)
			local smallfish = ns.ItemFacts(state, SMALLFISH, conditions(DARKSHORE, AUBERDINE, 86, 25), NOW).here
			assert.are.equal("Auberdine", smallfish.place)
			assert.are.same({ page = "place", area = AUBERDINE, item = SMALLFISH }, smallfish.target)
		end)
	end)

	describe("the right page, Where I've fished for it (stats.md › UI › Item page)", function()
		-- Elwynn: 50 Casts, Firefin caught there though its list lacks it. Darkshore: 30 Casts, 5 in Auberdine and 10
		-- in Bashal'Aran; Firefin is on Darkshore's rows, Auberdine's own list and Bashal'Aran's (its zone's own).
		local function fished()
			return stateWith({
				places = {
					[ELWYNN] = place(ELWYNN, 50, { [FIREFIN] = 1 }),
					[DARKSHORE] = place(DARKSHORE, 30),
					[AUBERDINE] = place(DARKSHORE, 5),
					[BASHAL_ARAN] = place(DARKSHORE, 10),
					[FERALAS] = place(FERALAS, 80),
				},
			})
		end

		it("groups tiles by zone, most Casts first: the zone, then its subzones alphabetically", function()
			local waters = ns.ItemWaters(fished(), FIREFIN, conditions(0, 0))

			assert.is_nil(waters.empty)
			assert.are.same({ ELWYNN, DARKSHORE, AUBERDINE, BASHAL_ARAN }, pluck(waters.tiles, "area"))
			assert.are.same(
				{ "Elwynn Forest", "Darkshore", "Auberdine", "Bashal'Aran" },
				pluck(waters.tiles, "name")
			)
			assert.are.same({ page = "place", area = BASHAL_ARAN, item = FIREFIN }, waters.tiles[4].target)
		end)

		it("orders a zone's subzones by name, not by areaID or Casts", function()
			names[AUBERDINE] = "Zoram Strand"
			local waters = ns.ItemWaters(fished(), FIREFIN, conditions(0, 0))
			names[AUBERDINE] = "Auberdine"

			assert.are.same({ ELWYNN, DARKSHORE, BASHAL_ARAN, AUBERDINE }, pluck(waters.tiles, "area"))
		end)

		it("reads each tile's zone (for a subzone) and short odds, and I'm here on the current place", function()
			local waters = ns.ItemWaters(fished(), FIREFIN, conditions(DARKSHORE, AUBERDINE, 86, 25))

			assert.are.same({
				"learning 0/100",
				"learning 0/100",
				"Darkshore · learning 0/100",
				"Darkshore · learning 0/100",
			}, pluck(waters.tiles, "line"))
			assert.are.same({ false, false, "I'm here", false }, pluck(waters.tiles, "here"))
		end)

		it('writes "{since} since" in red only when the Dry spell is unlucky or very unlucky (STA-R52)', function()
			-- Darkshore below its line: 200 Casts, Firefin in 100 of them, so k/n = 1/2. Since 10: P = 0.5^10, unlucky;
			-- Elwynn (no line): 200 Casts, since 1: P = 0.5, normal.
			local state = fished()
			state.scopes = { [DARKSHORE .. ":lo"] = 200, [ELWYNN .. ":na"] = 200 }
			state.hits = {
				[DARKSHORE .. ":lo#" .. FIREFIN] = { n = 100, at = 190, last = NOW },
				[ELWYNN .. ":na#" .. FIREFIN] = { n = 100, at = 199, last = NOW },
			}

			local waters = ns.ItemWaters(state, FIREFIN, conditions(0, 0, 86, 25))

			assert.are.same({ "1 in 2", "1 in 2", "Darkshore · 1 in 2", "Darkshore · 1 in 2" }, pluck(waters.tiles, "line"))
			assert.are.same({ false, "10 since", "10 since", "10 since" }, pluck(waters.tiles, "note"))
		end)

		it("tiles an Uncharted item where I caught it, and a Noise item nowhere (STA-R17, STA-R96)", function()
			local state = fished()
			state.places[DARKSHORE].items[UNCHARTED] = 1
			state.places[BASHAL_ARAN].items[UNCHARTED] = 1
			state.places[STRANGLETHORN] = place(STRANGLETHORN, 5, { [MANA_POTION] = 1 })

			local uncharted = ns.ItemWaters(state, UNCHARTED, conditions(0, 0))
			local noise = ns.ItemWaters(state, MANA_POTION, conditions(0, 0))

			assert.are.same({ DARKSHORE, BASHAL_ARAN }, pluck(uncharted.tiles, "area"))
			assert.are.same({}, noise.tiles)
			assert.are.equal("I haven't fished anywhere it bites.", noise.empty)
		end)

		it("tiles only places in my records, not every subzone that lists it", function()
			local state = fished()
			state.places[AUBERDINE] = nil

			local waters = ns.ItemWaters(state, SMALLFISH, conditions(DARKSHORE, AUBERDINE))

			-- Smallfish is on Elwynn's list and Darkshore's (from Auberdine's), and not on Bashal'Aran's
			assert.are.same({ ELWYNN, DARKSHORE }, pluck(waters.tiles, "area"))
		end)
	end)
end)
