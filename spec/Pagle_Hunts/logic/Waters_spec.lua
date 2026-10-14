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
