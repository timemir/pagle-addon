-- Where a Hunt bites (HNT-R6, HNT-R7, HNT-R30–R34, HNT-R137, HNT-R198): board specs, waters, places, zones, skill
-- need and unconfirmed, worked out once at load over the fixture Hunt list and the fixture catalogue.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local C = catalogue
local JAN_1 = 1767225600 -- 2026-01-01, the fixture Hunts' since

-- Pagle_Hunts on a FakePagle serving `data` (the fixture catalogue as first shipped by default).
local function load(data)
	local fake = newFakePagle()
	fake.setCatalogue(data or catalogue.base())
	local loaded = hunts.load(fake)
	return loaded, fake
end

-- Hunts the fixture list lacks, as the list emits them (DATA-R93), each made from `fields` over an imposed Hunt of
-- set fixture_extra: where they bite, worked out as at load, by Hunt ID.
local function whereOf(loaded, fake, huntFields, classes)
	local list = { fingerprint = "e", sets = { { id = "fixture_extra" } }, hunts = {}, classes = classes or {} }
	for i, fields in ipairs(huntFields) do
		local hunt = { id = "extra_" .. i, set = "fixture_extra", kind = "imposed", since = JAN_1, tiers = { 1 } }
		for key, value in pairs(fields) do
			hunt[key] = value
		end
		list.hunts[i] = hunt
	end
	local ns = loaded.ns
	return ns.NewWhere(ns.NewHuntList(list, ns.L), fake.globals.Pagle), list.hunts
end

describe("Where a Hunt bites", function()
	describe("waters (HNT-R30)", function()
		local loaded, fake = load()
		local where = loaded.ns.where

		it("are worked out at load for every Hunt of the list, Retired and not-yet ones too (HNT-R137)", function()
			for _, hunt in ipairs(loaded.ns.hunts:Hunts()) do
				assert.is_table(where[hunt.id], hunt.id)
			end
		end)

		it("are, for a natural night Hunt, exactly the areas gating its Species by night, subzones too", function()
			-- Darkshore and Auberdine list Nightfin by night, Ashenvale a Forever item of its Species by night; the
			-- Pier gates that item by day and Elwynn lists Nightfin ungated, so neither is a water.
			assert.are.same({ C.DARKSHORE, C.ASHENVALE, C.AUBERDINE }, where.fixture_snapper.waters)
		end)

		it("are, for an imposed Species Hunt, every area listing an item of its Species, gated or not", function()
			-- Blackmouth: ungated in Darkshore and Westfall, night-gated on the Pier.
			assert.are.same({ C.WESTFALL, C.DARKSHORE, C.PIER }, where.fixture_hefty_blackmouth.waters)
			assert.are.same({ C.PIER }, where.fixture_grouper.waters)
		end)

		it("are, for an imposed fixed-class Hunt, every area listing a member; a member listed nowhere adds none", function()
			assert.are.same({ C.DARKSHORE }, where.fixture_oddity.waters)
		end)

		it("are none for a generated-class Hunt", function()
			assert.are.same({}, where.fixture_rack.waters)
		end)

		it("are none for a Hunt with areas, even when those areas list its target", function()
			local extra = whereOf(loaded, fake, {
				{ species = C.BLACKMOUTH, conditions = { areas = { C.ELWYNN, C.AUBERDINE } } },
				{ class = "fixed.oddity", conditions = { areas = { C.DARKSHORE } } },
			}, { ["fixed.oddity"] = { [C.DEVIATE] = true } })
			assert.are.same({}, extra.extra_1.waters)
			assert.are.same({}, extra.extra_2.waters)
		end)
	end)

	describe("places and zones (HNT-R31)", function()
		local loaded, fake = load()
		local where = loaded.ns.where

		it("are its waters, and their zones without duplicates, ascending", function()
			assert.are.same({ C.DARKSHORE, C.ASHENVALE, C.AUBERDINE }, where.fixture_snapper.places)
			-- Auberdine is in Darkshore, so Darkshore is listed once.
			assert.are.same({ C.DARKSHORE, C.ASHENVALE }, where.fixture_snapper.zones)
			-- Westfall 40 comes before Darkshore 148; the Pier is two levels down in Darkshore.
			assert.are.same({ C.WESTFALL, C.DARKSHORE }, where.fixture_hefty_blackmouth.zones)
			assert.are.same({ C.DARKSHORE }, where.fixture_grouper.zones)
		end)

		it("are a Hunt's areas when it has them", function()
			local extra = whereOf(loaded, fake, { { species = C.BLACKMOUTH, conditions = { areas = { C.PIER, C.ELWYNN } } } })
			assert.are.same({ C.PIER, C.ELWYNN }, extra.extra_1.places)
			assert.are.same({ C.ELWYNN, C.DARKSHORE }, extra.extra_1.zones)
		end)

		it("are none for a generated-class Hunt without areas", function()
			assert.are.same({}, where.fixture_rack.places)
			assert.are.same({}, where.fixture_rack.zones)
		end)
	end)

	describe("skill need (HNT-R32)", function()
		local loaded, fake = load()
		local where = loaded.ns.where

		it("is the lowest skill base among its places, a subzone without one taking its zone's", function()
			-- Darkshore 75, Ashenvale 150, Auberdine none of its own so Darkshore's 75.
			assert.are.equal(75, where.fixture_snapper.skillNeed)
			-- The Pier's own 150.
			assert.are.equal(150, where.fixture_grouper.skillNeed)
			-- Westfall has no base and is skipped; Darkshore 75, the Pier 150.
			assert.are.equal(75, where.fixture_hefty_blackmouth.skillNeed)
		end)

		it("is raised by skill.min, and is skill.min alone for a Hunt with no places", function()
			local extra = whereOf(loaded, fake, {
				{ species = C.BLACKMOUTH, conditions = { areas = { C.PIER, C.ELWYNN }, skill = { min = 100 } } },
				{ species = C.BLACKMOUTH, conditions = { areas = { C.PIER, C.ELWYNN }, skill = { min = 10 } } },
				{ class = "quality.uncommon", conditions = { skill = { min = 225 } } },
			})
			-- Elwynn's 25 is the lowest base; 100 raises it, 10 doesn't.
			assert.are.equal(100, extra.extra_1.skillNeed)
			assert.are.equal(25, extra.extra_2.skillNeed)
			assert.are.equal(225, extra.extra_3.skillNeed)
		end)

		it("is none with no base among its places and no skill condition, or when it is 0 or less", function()
			local extra = whereOf(loaded, fake, {
				{ species = C.SMALLFISH }, -- Westfall only, which has no base
				{ class = "quality.uncommon", conditions = { areas = { C.STORMWIND, C.WESTFALL }, skill = { min = 0 } } },
			})
			assert.is_nil(where.fixture_rack.skillNeed)
			assert.are.same({ C.WESTFALL }, extra.extra_1.places)
			assert.is_nil(extra.extra_1.skillNeed)
			assert.is_nil(extra.extra_2.skillNeed)
		end)
	end)

	describe("board spec (HNT-R6, HNT-R7)", function()
		local loaded, fake = load()
		local ns = loaded.ns

		it("is a natural Hunt's window spec, as GetWindowSpec gives it, its confirmed included", function()
			local spec = ns.where.fixture_snapper.boardSpec
			assert.are.same({ 1200, 360 }, { spec.time[1][1], spec.time[1][2] })
			assert.is_true(spec.confirmed)
			assert.is_false(ns.where.fixture_sunscale.boardSpec.confirmed)
		end)

		it("is an imposed Hunt's own conditions", function()
			assert.are.equal(ns.hunts:Hunt("fixture_oddity").conditions, ns.where.fixture_oddity.boardSpec)
			assert.are.equal(ns.hunts:Hunt("fixture_rack").conditions, ns.where.fixture_rack.boardSpec)
		end)

		it("is none for a natural Hunt whose window has no spec, which is never unconfirmed", function()
			local where, extra = whereOf(loaded, fake, { { kind = "natural", species = C.NIGHTFIN, window = "event.999" } })
			local shipped = ns.where
			ns.where = where
			assert.is_nil(where.extra_1.boardSpec)
			assert.is_nil(where.extra_1.unconfirmedWindow)
			assert.is_nil(ns.Unconfirmed(extra[1], { opensAt = 0, confirmed = false }))
			ns.where = shipped
		end)
	end)

	describe("unconfirmed (HNT-R34)", function()
		local loaded, fake = load()
		local ns, Pagle = loaded.ns, fake.globals.Pagle
		local now = Pagle.GetConditions().time

		-- The Hunt's NextWindow result now, as the grouping reads it (HNT-R40).
		local function forecast(huntID)
			return Pagle.NextWindow(ns.where[huntID].boardSpec, now)
		end

		it("is not a natural Hunt with a confirmed window and a gateConfirmed entry among its waters", function()
			assert.is_nil(ns.where.fixture_snapper.unconfirmedWindow)
			assert.is_nil(ns.Unconfirmed(ns.hunts:Hunt("fixture_snapper"), forecast("fixture_snapper")))
		end)

		it("is a natural Hunt whose window is unconfirmed: the window is an estimate", function()
			assert.are.equal("window", ns.where.fixture_sunscale.unconfirmedWindow)
			assert.are.equal("window", ns.Unconfirmed(ns.hunts:Hunt("fixture_sunscale"), forecast("fixture_sunscale")))
		end)

		it("is a natural Hunt none of whose waters' entries has gateConfirmed: not yet seen biting only then", function()
			local where, extra = whereOf(loaded, fake, {
				-- Ashenvale's Forever Nightfin, its one night water, has gateConfirmed false.
				{ kind = "natural", species = C.NIGHTFIN, window = "night" },
				-- Smallfish is gated nowhere, so this one has no waters, and none gateConfirmed.
				{ kind = "natural", species = C.SMALLFISH, window = "night" },
			})
			assert.is_nil(where.extra_1.unconfirmedWindow) -- Auberdine's entry is gateConfirmed
			assert.are.equal("gating", where.extra_2.unconfirmedWindow)
			local shipped = ns.where
			ns.where = where
			assert.are.equal("gating", ns.Unconfirmed(extra[2], Pagle.NextWindow(where.extra_2.boardSpec, now)))
			ns.where = shipped
		end)

		it("is any Hunt whose NextWindow result has confirmed = false, an estimate whatever its gating", function()
			local where, extra = whereOf(loaded, fake, {
				{ species = C.BLACKMOUTH, conditions = { events = { 301 } } }, -- an unconfirmed weekly rule
				{ kind = "natural", species = C.SMALLFISH, window = "event.301" },
			})
			local shipped = ns.where
			ns.where = where
			local window = Pagle.NextWindow(where.extra_1.boardSpec, now)
			assert.is_false(window.confirmed)
			assert.is_nil(where.extra_1.unconfirmedWindow)
			assert.are.equal("window", ns.Unconfirmed(extra[1], window))
			assert.are.equal("window", ns.Unconfirmed(extra[2], Pagle.NextWindow(where.extra_2.boardSpec, now)))
			-- With no result (a secret realm clock), only what was worked out at load.
			assert.is_nil(ns.Unconfirmed(extra[1], nil))
			ns.where = shipped
			assert.are.equal("window", ns.Unconfirmed(ns.hunts:Hunt("fixture_sunscale"), nil))
		end)

		it("is never an imposed Hunt with a confirmed forecast", function()
			assert.is_nil(ns.where.fixture_oddity.unconfirmedWindow)
			assert.is_nil(ns.Unconfirmed(ns.hunts:Hunt("fixture_oddity"), forecast("fixture_oddity")))
		end)
	end)

	describe("short of skill (HNT-R33)", function()
		it("flips as the Angler's bestBaseSkill crosses the need, a lure getting there within 100", function()
			local loaded, fake = load()
			local ns, Pagle = loaded.ns, fake.globals.Pagle
			local grouper = ns.hunts:Hunt("fixture_grouper") -- needs 150
			fake.login()

			-- (short, a lure gets me there) at each best base rank, read from the Angler as it is then.
			local function at(rank)
				if rank then
					fake.readSkill(rank, 300, 0)
				end
				return { ns.ShortOfSkill(grouper, Pagle.GetAngler()) }
			end
			assert.are.same({ true, false }, at()) -- no reading yet: best 0, 150 short
			assert.are.same({ true, false }, at(49)) -- 101 short
			assert.are.same({ true, true }, at(50)) -- 100 short: the lure reach
			assert.are.same({ true, true }, at(149))
			assert.are.same({ false, false }, at(150))
			assert.are.same({ false, false }, at(225))
		end)

		it("is never short for a Hunt with no skill need", function()
			local loaded, fake = load()
			fake.login()
			local rack = loaded.ns.hunts:Hunt("fixture_rack")
			assert.are.same({ false, false }, { loaded.ns.ShortOfSkill(rack, fake.globals.Pagle.GetAngler()) })
		end)
	end)

	describe("in its waters (HNT-R25, HNT-R30)", function()
		local loaded, fake = load()
		local ns = loaded.ns
		local list = ns.hunts

		-- A Cast fished in `zone`, and `subzone` (0 when unresolved, LOG-R22).
		local function castIn(zone, subzone)
			return { kind = "cast", outcome = "caught", conditions = { zone = zone, subzone = subzone or 0 } }
		end

		it("holds when the Cast's subzone or its zone is one of the Hunt's waters", function()
			local snapper = list:Hunt("fixture_snapper")
			assert.is_true(ns.InWaters(snapper, castIn(C.DARKSHORE, C.AUBERDINE)))
			assert.is_true(ns.InWaters(snapper, castIn(C.DARKSHORE)))
			-- The Pier isn't a water, but its zone is.
			assert.is_true(ns.InWaters(snapper, castIn(C.DARKSHORE, C.PIER)))
			assert.is_true(ns.InWaters(snapper, castIn(C.ASHENVALE)))
			assert.is_false(ns.InWaters(snapper, castIn(C.ELWYNN)))
			assert.is_false(ns.InWaters(snapper, castIn(0)))
		end)

		it("holds only in a water subzone when the zone isn't one", function()
			local grouper = list:Hunt("fixture_grouper")
			assert.is_true(ns.InWaters(grouper, castIn(C.DARKSHORE, C.PIER)))
			assert.is_false(ns.InWaters(grouper, castIn(C.DARKSHORE, C.AUBERDINE)))
			assert.is_false(ns.InWaters(grouper, castIn(C.DARKSHORE)))
		end)

		it("holds anywhere for a Hunt that has no waters by rule: its areas, if any, constrain it instead", function()
			local rack = list:Hunt("fixture_rack")
			assert.is_true(ns.InWaters(rack, castIn(C.ELWYNN)))
			assert.is_true(ns.InWaters(rack, castIn(0)))
		end)

		it("never holds for a natural Hunt left with no waters", function()
			-- No catch entry is gated by event.999, so the data left this natural Hunt without waters.
			local where, extra = whereOf(loaded, fake, { { kind = "natural", species = C.NIGHTFIN, window = "event.999" } })
			local shipped = ns.where
			ns.where = where
			assert.are.same({}, where.extra_1.waters)
			assert.is_false(ns.InWaters(extra[1], castIn(C.DARKSHORE, C.AUBERDINE)))
			ns.where = shipped
		end)

		it("holds anywhere for an imposed target Hunt whose target no area lists", function()
			local where, extra = whereOf(loaded, fake, { { class = "fixed.lost" } }, { ["fixed.lost"] = { [1] = true } })
			local shipped = ns.where
			ns.where = where
			assert.are.same({}, where.extra_1.waters)
			assert.is_true(ns.InWaters(extra[1], castIn(C.ELWYNN)))
			ns.where = shipped
		end)
	end)
end)
