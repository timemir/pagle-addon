-- A place's page in logic (STA-R17, STA-R18, STA-R42, STA-R96; stats.md › UI › Place spread): its rows grouped Any time,
-- Pools, In their window and Also caught here and sorted by Your odds, a zone's waters, and the no-junk sentence, over
-- hand-built StatsState tables and the fixture catalogue through Core's own accessors.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN, FERALAS = 148, 442, 446, 12, 357
local UNCHARTED_SUBZONE = 9999 -- a subzone the catalogue lacks
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH = 6303, 6358, 6359, 13759, 6291
local BASS, MUD_SNAPPER = 13756, 6289
local UNCHARTED = 77777 -- an item the catalogue lacks

-- A state in stats.md's Projection state shape with what the place page reads: `scopes`, `hits` and `places`.
---@param scopes table<string, integer>
---@param hits table<string, StatsHit>?
---@param places table<integer, StatsPlace>?
---@return StatsState
local function stateWith(scopes, hits, places)
	---@type table
	local state = { scopes = scopes, hits = hits or {}, places = places or {} }
	return state
end

-- A hit of `n` catches, the last at `at`.
local function hit(n, at)
	return { n = n, at = at or n, last = 1791731000 }
end

-- The groups as { id, { item, ... } } pairs, in their order.
---@param groups StatsGroup[]
local function shapeOf(groups)
	local out = {}
	for i, group in ipairs(groups) do
		local items = {}
		for j, reading in ipairs(group.readings) do
			items[j] = reading.item
		end
		out[i] = { group.id, items }
	end
	return out
end

describe("a place's page in logic", function()
	local loaded, fake = stats.load()
	local ns, lookups = loaded.ns, fake.Pagle
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	loaded.client.areaNames[AUBERDINE] = "Auberdine"
	loaded.client.areaNames[BASHAL_ARAN] = "Bashal'Aran"

	describe("the groups (STA-R18)", function()
		it("put each row in Any time, Pools, In their window or Also caught here, in that order", function()
			-- Darkshore at skill 200 (line 170: side hi). Mackerel, Firefin (mixed entries: no window, STA-R14) and
			-- Smallfish are ungated and not pool fish; Blackmouth is a pool fish; Nightfin keeps `night`; the Uncharted
			-- item was caught here, and item 0's catches never make a row (STA-R96).
			local state = stateWith(
				{ ["148:hi"] = 150, ["148:hi:night"] = 120 },
				{ ["148:hi#6303"] = hit(3), ["148:hi#6359"] = hit(6), ["148:hi#6358"] = hit(2) },
				{ [DARKSHORE] = { zone = DARKSHORE, casts = 270, catches = 12, gotAway = 0, items = { [UNCHARTED] = 1 } } }
			)

			local groups = ns.Groups(state, DARKSHORE, 200)

			assert.are.same({
				{ "any", { FIREFIN, MACKEREL, SMALLFISH } },
				{ "pools", { BLACKMOUTH } },
				{ "window", { NIGHTFIN } },
				{ "added", { UNCHARTED } },
			}, shapeOf(groups))
			assert.are.equal("night", groups[3].readings[1].window)
			assert.is_nil(groups[4].readings[1].window) -- an Uncharted Catch has no window (STA-R96)
		end)

		it("carry each group's heading and its small note", function()
			local state = stateWith({}, {}, {
				[DARKSHORE] = { zone = DARKSHORE, casts = 1, catches = 1, gotAway = 0, items = { [UNCHARTED] = 1 } },
			})

			local words = {}
			for _, group in ipairs(ns.Groups(state, DARKSHORE, 200)) do
				words[#words + 1] = { group.heading, group.note }
			end

			assert.are.same({
				{ "Any time", "Your odds · Dry spell" },
				{ "Pools", "open water and pools combined" },
				{ "In their window", "only Casts in their window" },
				{ "Also caught here", "not on Pagle's chart for these waters" },
			}, words)
		end)

		it("leave an empty group out", function()
			-- Auberdine's own list: Firefin and Smallfish, both ungated there and in no pool.
			assert.are.same(
				{ { "any", { SMALLFISH, FIREFIN } } }, -- both learning: by item ID
				shapeOf(ns.Groups(stateWith({}), AUBERDINE, 200))
			)
		end)

		it("give a place with no list and no catches no groups", function()
			assert.are.same({}, ns.Groups(stateWith({}), UNCHARTED_SUBZONE, 200))
		end)

		it("put an item caught here that the list lacks under Also caught here, though it has a window", function()
			-- Nightfin isn't on Auberdine's own list; its reading still keeps its window in Darkshore (STA-R14).
			local state = stateWith({}, {}, {
				[AUBERDINE] = { zone = DARKSHORE, casts = 1, catches = 1, gotAway = 0, items = { [NIGHTFIN] = 1 } },
			})

			local groups = ns.Groups(state, AUBERDINE, 200)

			assert.are.same({ { "any", { SMALLFISH, FIREFIN } }, { "added", { NIGHTFIN } } }, shapeOf(groups))
			assert.are.equal("night", groups[2].readings[1].window)
		end)
	end)

	describe("the order within a group (STA-R18)", function()
		it("puts known odds by k/n, highest first, not by k", function()
			-- Elwynn has no line (side na). Mud Snapper: 3 of 100 by day; Summer Bass: 4 of 200 in summer.
			local state = stateWith(
				{ ["12:na:day"] = 100, ["12:na:summer"] = 200 },
				{ ["12:na:day#6289"] = hit(3), ["12:na:summer#13756"] = hit(4) }
			)

			assert.are.same({ MUD_SNAPPER, BASS }, shapeOf(ns.Groups(state, ELWYNN, 150))[2][2])
		end)

		it("puts known before unseen before learning, whatever the item IDs", function()
			-- Summer Bass unseen in 200 summer Casts, Mud Snapper learning at 60 day Casts.
			local unseenFirst = stateWith({ ["12:na:day"] = 60, ["12:na:summer"] = 200 })
			assert.are.same({ BASS, MUD_SNAPPER }, shapeOf(ns.Groups(unseenFirst, ELWYNN, 150))[2][2])

			-- Darkshore by day: Smallfish known, Firefin unseen, Mackerel known higher.
			local mixed = stateWith({ ["148:hi"] = 150 }, { ["148:hi#6291"] = hit(1), ["148:hi#6303"] = hit(5) })
			assert.are.same({ MACKEREL, SMALLFISH, FIREFIN }, shapeOf(ns.Groups(mixed, DARKSHORE, 200))[1][2])
		end)

		it("breaks ties by item ID, ascending", function()
			-- Equal known odds (3 in 150), then two learning rows (Elwynn under the threshold).
			local known = stateWith({ ["148:hi"] = 150 }, { ["148:hi#6359"] = hit(3), ["148:hi#6303"] = hit(3) })
			assert.are.same({ MACKEREL, FIREFIN, SMALLFISH }, shapeOf(ns.Groups(known, DARKSHORE, 200))[1][2])

			local learning = stateWith({ ["12:na"] = 50 })
			assert.are.same({ SMALLFISH, NIGHTFIN }, shapeOf(ns.Groups(learning, ELWYNN, 150))[1][2])
		end)
	end)

	describe("reading across the zone (STA-R42)", function()
		it("is true while any of a subzone's rows uses its zone's scope", function()
			local early = ns.Groups(stateWith({ ["442:hi"] = 40 }), AUBERDINE, 200)
			assert.is_true(ns.ReadsAcrossZone(early))

			local own = ns.Groups(stateWith({ ["442:hi"] = 100 }), AUBERDINE, 200)
			assert.is_false(ns.ReadsAcrossZone(own))
		end)

		it("is false on a zone", function()
			assert.is_false(ns.ReadsAcrossZone(ns.Groups(stateWith({}), DARKSHORE, 200)))
		end)
	end)

	describe("a zone's waters (stats.md › UI › Place spread)", function()
		it("are its subzones with their own list or a places record, alphabetical, with my Casts", function()
			-- Auberdine has its own list (never fished); Bashal'Aran has none but was fished; an uncharted subzone was
			-- fished in Darkshore; Feralas' subzone is another zone's.
			local state = stateWith({}, {}, {
				[BASHAL_ARAN] = { zone = DARKSHORE, casts = 4, catches = 0, gotAway = 4, items = {} },
				[UNCHARTED_SUBZONE] = { zone = DARKSHORE, casts = 2, catches = 0, gotAway = 2, items = {} },
				[1116] = { zone = FERALAS, casts = 9, catches = 0, gotAway = 9, items = {} },
			})

			local waters = ns.PlaceWaters(state, DARKSHORE, lookups)

			-- "Area 9999" sorts first: AreaName's fallback for an area the client can't name (STA-R59).
			assert.are.same({
				{ area = UNCHARTED_SUBZONE, name = "Area 9999", casts = 2 },
				{ area = AUBERDINE, name = "Auberdine" },
				{ area = BASHAL_ARAN, name = "Bashal'Aran", casts = 4 },
			}, waters)
		end)

		it("are none for a zone without subzones I know of", function()
			assert.are.same({}, ns.PlaceWaters(stateWith({}), ELWYNN, lookups))
		end)
	end)

	describe("the no-junk sentence (stats.md › UI › Place spread)", function()
		it("says I'm past the line for side hi, below it for lo, and just the line for an unknown skill", function()
			assert.are.equal(
				"No junk from 170; at 200 I'm past it, so only those Casts count.",
				ns.NoJunkSentence(AUBERDINE, 200)
			)
			assert.are.equal(
				"No junk from 170; at 120 I'm below it, so only my Casts below it count.",
				ns.NoJunkSentence(DARKSHORE, 120)
			)
			assert.are.equal("No junk from 170.", ns.NoJunkSentence(DARKSHORE, nil))
		end)

		it("is none where the zone has no line", function()
			assert.is_nil(ns.NoJunkSentence(ELWYNN, 200))
			assert.is_nil(ns.NoJunkSentence(UNCHARTED_SUBZONE, 200))
		end)
	end)
end)
