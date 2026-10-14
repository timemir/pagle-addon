-- Your odds (STA-R3, STA-R40–R43, STA-R45–R47): a reading's side, scope and state, its short and long text, Wilson's
-- range and the scope line with its extra sentences, over hand-built StatsState tables and the fixture catalogue
-- through Core's own accessors.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN, STRANGLETHORN = 148, 442, 446, 12, 33
local FERALAS, FEATHERMOON = 357, 1116
local UNCHARTED_SUBZONE = 9999 -- a subzone the catalogue lacks
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, BASS, MUD_SNAPPER = 6303, 6358, 6359, 13759, 13756, 6289
local UNCHARTED = 77777 -- an item the catalogue lacks

-- A state in stats.md's Projection state shape with only what a reading reads: `scopes`, `hits` and `places`.
---@param scopes table<string, integer>
---@param hits table<string, StatsHit>?
---@param places table<integer, StatsPlace>?
---@return StatsState
local function stateWith(scopes, hits, places)
	---@type table
	local state = { scopes = scopes, hits = hits or {}, places = places or {} }
	return state
end

describe("Your odds", function()
	local loaded = stats.load()
	local ns = loaded.ns
	loaded.client.areaNames[DARKSHORE] = "Darkshore"
	loaded.client.areaNames[FERALAS] = "Feralas"

	describe("states (STA-R43)", function()
		it("is learning while the scope holds fewer than 100 Casts", function()
			local reading = ns.Reading(stateWith({ ["148:hi"] = 99 }), MACKEREL, DARKSHORE, 200)

			assert.are.equal("learning", reading.state)
			assert.are.equal(99, reading.n)
			assert.are.equal("learning 99/100", ns.OddsShort(reading))
		end)

		it("is unseen at the threshold with none caught, bounded by the rule of three", function()
			local reading = ns.Reading(stateWith({ ["357:hi:night"] = 412 }), NIGHTFIN, FERALAS, 300)

			assert.are.equal("unseen", reading.state)
			assert.are.same({ 412, 0 }, { reading.n, reading.k })
			assert.is_nil(reading.hit)
			assert.are.equal("not seen yet", ns.OddsShort(reading))
			assert.are.equal("not seen yet", ns.OddsHeadline(reading))
			assert.are.equal(
				"In 412 Casts here by night, at or above 300 skill: rarer than about 1 in 140, if it bites here at all.",
				ns.OddsSentence(reading)
			)
		end)

		it("is known once caught in the scope, with the scope line (STA-R46's example)", function()
			local hit = { n = 9, at = 200, last = 1791731747 }
			local state = stateWith({ ["357:hi:night"] = 412 }, { ["357:hi:night#13759"] = hit })
			local reading = ns.Reading(state, NIGHTFIN, FERALAS, 300)

			assert.are.equal("known", reading.state)
			assert.are.same({ 412, 9 }, { reading.n, reading.k })
			assert.are.same(hit, reading.hit)
			assert.are.equal("1 in 46", ns.OddsShort(reading))
			assert.are.equal("about 1 in 46", ns.OddsHeadline(reading))
			assert.are.equal(
				"From 412 of my Casts here by night, at or above 300 skill; 9 caught.",
				ns.OddsSentence(reading)
			)
		end)

		it("checks learning before a catch: under the threshold a caught item is still learning", function()
			local state = stateWith({ ["148:hi"] = 40 }, { ["148:hi#6303"] = { n = 3, at = 38, last = 1 } })
			local reading = ns.Reading(state, MACKEREL, DARKSHORE, 200)

			assert.are.equal("learning", reading.state)
			assert.are.equal(3, reading.k)
			assert.are.equal("Learning…", ns.OddsHeadline(reading))
			assert.are.equal(
				"40 of the 100 Casts I need here, at or above 170 skill before Your odds show a number.",
				ns.OddsSentence(reading)
			)
		end)
	end)

	describe("the scope (STA-R42)", function()
		it("uses a subzone's zone, with its side, while the subzone's own scope is under the threshold", function()
			local state = stateWith(
				{ ["442:hi"] = 40, ["148:hi"] = 500 },
				{ ["148:hi#6359"] = { n = 5, at = 480, last = 1 } }
			)
			local reading = ns.Reading(state, FIREFIN, AUBERDINE, 200)

			assert.are.same(
				{ AUBERDINE, DARKSHORE, "148:hi", true, 500, 5, "known" },
				{ reading.area, reading.zone, reading.scope, reading.viaZone, reading.n, reading.k, reading.state }
			)
			assert.are.equal("across Darkshore", reading.where)
			assert.are.equal(
				"From 500 of my Casts across Darkshore, at or above 170 skill; 5 caught.",
				ns.OddsSentence(reading)
			)
		end)

		it("uses the subzone's own scope once it holds the threshold", function()
			local state = stateWith(
				{ ["442:hi"] = 100, ["148:hi"] = 500 },
				{ ["442:hi#6359"] = { n = 2, at = 90, last = 1 } }
			)
			local reading = ns.Reading(state, FIREFIN, AUBERDINE, 200)

			assert.are.same({ "442:hi", false, 100, 2 }, { reading.scope, reading.viaZone, reading.n, reading.k })
			assert.are.equal("here", reading.where)
		end)

		it("keeps the item's window in the zone's scope, and says across the zone in every state", function()
			local state = stateWith({ ["1116:hi:night"] = 40, ["357:hi:night"] = 60, ["357:hi"] = 900 })
			local reading = ns.Reading(state, NIGHTFIN, FEATHERMOON, 310)

			assert.are.same(
				{ "357:hi:night", true, 60, "learning" },
				{ reading.scope, reading.viaZone, reading.n, reading.state }
			)
			assert.are.equal(
				"60 of the 100 Casts I need across Feralas by night, at or above 300 skill before Your odds show a number.",
				ns.OddsSentence(reading)
			)

			state.scopes["357:hi:night"] = 300
			assert.are.equal(
				"In 300 Casts across Feralas by night, at or above 300 skill: rarer than about 1 in 100, if it bites here at all.",
				ns.OddsSentence(ns.Reading(state, NIGHTFIN, FEATHERMOON, 310))
			)
		end)

		it("reads a place's zone from the projection when the catalogue lacks the place", function()
			local places =
				{ [UNCHARTED_SUBZONE] = { zone = DARKSHORE, casts = 3, catches = 0, gotAway = 0, items = {} } }
			local state = stateWith({ ["9999:hi"] = 3, ["148:hi"] = 120 }, {}, places)
			local reading = ns.Reading(state, MACKEREL, UNCHARTED_SUBZONE, 200)

			assert.are.same(
				{ DARKSHORE, "hi", "148:hi", true },
				{ reading.zone, reading.side, reading.scope, reading.viaZone }
			)
		end)

		it("is the zone's own scope on a zone page", function()
			local reading = ns.Reading(stateWith({ ["148:hi"] = 20 }), MACKEREL, DARKSHORE, 200)

			assert.are.same({ "148:hi", false, "here" }, { reading.scope, reading.viaZone, reading.where })
		end)
	end)

	describe("the reading side (STA-R41)", function()
		it("is the live effective skill against the zone's line", function()
			assert.are.equal("hi", ns.Reading(stateWith({}), MACKEREL, DARKSHORE, 170).side)
			local below = ns.Reading(stateWith({ ["148:lo"] = 120 }), MACKEREL, DARKSHORE, 169)

			assert.are.same({ "lo", "148:lo", "below 170 skill" }, { below.side, below.scope, below.sideText })
			assert.are.equal(
				"In 120 Casts here, below 170 skill: rarer than about 1 in 40, if it bites here at all.",
				ns.OddsSentence(below)
			)
		end)

		it("follows the largest side scope of the place when the live skill is unknown", function()
			local reading =
				ns.Reading(stateWith({ ["148:hi"] = 10, ["148:lo"] = 30, ["148:na"] = 20 }), MACKEREL, DARKSHORE, nil)

			assert.are.same({ "lo", "148:lo", 30 }, { reading.side, reading.scope, reading.n })
			assert.are.equal(
				"na",
				ns.Reading(stateWith({ ["148:hi"] = 10, ["148:na"] = 20 }), MACKEREL, DARKSHORE, nil).side
			)
		end)

		it("breaks ties hi, then lo, then na", function()
			local side = function(scopes)
				return ns.Reading(stateWith(scopes), MACKEREL, DARKSHORE, nil).side
			end

			assert.are.equal("hi", side({ ["148:hi"] = 30, ["148:lo"] = 30, ["148:na"] = 30 }))
			assert.are.equal("lo", side({ ["148:hi"] = 10, ["148:lo"] = 30, ["148:na"] = 30 }))
			assert.are.equal("hi", side({}))
		end)

		it("counts the reading's own place's side scopes, not its zone's", function()
			local scopes = { ["442:lo"] = 30, ["442:hi"] = 10, ["148:hi"] = 900, ["148:lo"] = 400 }
			local reading = ns.Reading(stateWith(scopes), FIREFIN, AUBERDINE, nil)

			assert.are.same({ "lo", "148:lo", true, 400 }, { reading.side, reading.scope, reading.viaZone, reading.n })
		end)

		it("is na with no side words when the zone has no line, whatever the skill", function()
			local state = stateWith({ ["12:na:day"] = 150 }, { ["12:na:day#6289"] = { n = 2, at = 140, last = 1 } })
			local reading = ns.Reading(state, MUD_SNAPPER, ELWYNN, 300)

			assert.are.same({ "na", "12:na:day", "known" }, { reading.side, reading.scope, reading.state })
			assert.is_nil(reading.sideText)
			assert.are.equal("From 150 of my Casts here by day; 2 caught.", ns.OddsSentence(reading))
			assert.are.equal("na", ns.Reading(state, MUD_SNAPPER, ELWYNN, nil).side)
		end)
	end)

	describe("window names (STA-R47)", function()
		it("name each window by its ID", function()
			local names = {}
			for _, id in ipairs({
				"day",
				"night",
				"spring",
				"summer",
				"autumn",
				"winter",
				"event.2794",
				"fishingContest",
			}) do
				names[#names + 1] = ns.WindowName(id)
			end

			assert.are.same({
				"by day",
				"by night",
				"in spring",
				"in summer",
				"in autumn",
				"in winter",
				"during its event",
				"in its window",
			}, names)
		end)

		it("name a reading's window, and none without one", function()
			assert.are.equal("by night", ns.Reading(stateWith({}), NIGHTFIN, FERALAS, 300).windowName)
			assert.is_nil(ns.Reading(stateWith({}), MACKEREL, DARKSHORE, 300).windowName)
		end)
	end)

	describe("the extra sentences (STA-R46)", function()
		local BITES = "Pagle hasn't confirmed it bites here yet."
		local WINDOW = "The window isn't confirmed yet."
		local LINE = "The no-junk line isn't confirmed yet."
		local POOL = "Open water and pools combined: there is no pool data."

		-- The extra sentences of `item`'s reading in `area` with no Casts, in any state.
		local function notes(item, area, onNs)
			onNs = onNs or ns
			return onNs.OddsNotes(onNs.Reading(stateWith({}), item, area, 300))
		end

		it("are none for a confirmed entry with no window, in a zone with a confirmed line", function()
			assert.are.same({}, notes(MACKEREL, DARKSHORE))
		end)

		it("say so for an unconfirmed entry, an unconfirmed gate and an unconfirmed line, in that order", function()
			assert.are.same({ BITES, WINDOW, LINE }, notes(NIGHTFIN, FERALAS))
			assert.are.same({ BITES, WINDOW }, notes(NIGHTFIN, DARKSHORE))
		end)

		it("leave the window out when its gate is confirmed, and the line out when the zone has none", function()
			assert.are.same({ BITES }, notes(BASS, ELWYNN))
		end)

		it("say there is no pool data for a pool-associated item", function()
			assert.are.same({ BITES, POOL }, notes(BLACKMOUTH, DARKSHORE))
		end)

		it("read a subzone without its own list by its zone's own list", function()
			assert.are.same({}, notes(MACKEREL, BASHAL_ARAN))
			assert.are.same({ BITES }, notes(FIREFIN, BASHAL_ARAN))
		end)

		it("read a subzone with its own list by that list, and a zone by every entry in GetZoneCatches", function()
			local catalogue = stats.catalogue()
			-- Mackerel unconfirmed in Auberdine's own list, while Darkshore's own entry is confirmed.
			table.insert(catalogue.areas[AUBERDINE].catches, { itemID = MACKEREL, confirmed = false })
			local other = stats.load(nil, { catalogue = catalogue }).ns

			assert.are.same({ BITES }, notes(MACKEREL, AUBERDINE, other))
			assert.are.same({}, notes(MACKEREL, DARKSHORE, other))
		end)

		it(
			"never say an Also caught here item isn't confirmed, though the place's other sentences still apply",
			function()
				assert.are.same({}, notes(UNCHARTED, AUBERDINE))
				assert.are.same({ LINE }, notes(UNCHARTED, STRANGLETHORN))
				-- On Darkshore's list (unconfirmed) but not Auberdine's own: no entry behind its row there.
				assert.are.same({ POOL }, notes(BLACKMOUTH, AUBERDINE))
			end
		)

		it("apply in every state, the scope line's only in the known state", function()
			local hit = { n = 9, at = 200, last = 1 }
			for _, state in ipairs({
				stateWith({ ["357:hi:night"] = 40 }),
				stateWith({ ["357:hi:night"] = 412 }),
				stateWith({ ["357:hi:night"] = 412 }, { ["357:hi:night#13759"] = hit }),
			}) do
				assert.are.same({ BITES, WINDOW, LINE }, ns.OddsNotes(ns.Reading(state, NIGHTFIN, FERALAS, 300)))
			end
		end)
	end)

	describe("no baseline (STA-R3)", function()
		it(
			"reads no number from the catalogue: a place with no Casts is learning 0/100, whatever an entry carries",
			function()
				local catalogue = stats.catalogue()
				for _, entry in ipairs(catalogue.areas[DARKSHORE].catches) do
					entry.rate, entry.chance = 0.25, 0.25
				end
				local reading =
					stats.load(nil, { catalogue = catalogue }).ns.Reading(stateWith({}), MACKEREL, DARKSHORE, 300)

				assert.are.same({ 0, 0, "learning" }, { reading.n, reading.k, reading.state })
				assert.are.equal("learning 0/100", ns.OddsShort(reading))
			end
		)
	end)

	describe("the range (STA-R45)", function()
		-- A known reading of `k` of `n` Mackerel in Darkshore, on side hi.
		local function known(k, n)
			local state = stateWith({ ["148:hi"] = n }, { ["148:hi#6303"] = { n = k, at = n, last = 1 } })
			return ns.Reading(state, MACKEREL, DARKSHORE, 200)
		end

		it("reads Wilson's 95% interval as two odds, the higher chance first", function()
			assert.are.equal("Likely between 1 in 24 and 1 in 87 (95%).", ns.OddsRange(known(9, 412)))
			assert.are.equal("Likely between 1 in 18 and 1 in 570 (95%).", ns.OddsRange(known(1, 100)))
		end)

		it("reads within rounding when both ends round alike", function()
			assert.are.equal("Within rounding of 1 in 2 (95%).", ns.OddsRange(known(50, 100)))
		end)

		it("reads within rounding of 1 in 1 when every Cast caught it (hi = 1)", function()
			assert.are.equal("Within rounding of 1 in 1 (95%).", ns.OddsRange(known(100, 100)))
			assert.are.equal("1 in 1", ns.OddsShort(known(100, 100)))
		end)

		it("is shown only in the known state", function()
			assert.is_nil(ns.OddsRange(known(0, 412)))
			assert.is_nil(ns.OddsRange(known(5, 99)))
		end)
	end)
end)
