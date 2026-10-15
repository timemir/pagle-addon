-- Places, skill sides and windows (stats.md › Places, skill sides and windows): where a Cast counts, its side of a
-- zone's no-junk line, an item's window in a zone and a zone's windows, over the fixture catalogue through Core's own
-- accessors, as Stats reads them (STA-R10–R16, STA-R93).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

-- A Cast's conditions snapshot (LOG-R20), with only the fields Stats' places read.
---@param fields table
---@return table
local function conditions(fields)
	local snapshot = { time = 0, minute = 0, zone = 0, subzone = 0, events = {}, auras = {} }
	for key, value in pairs(fields) do
		snapshot[key] = value
	end
	return snapshot
end

describe("Stats' places", function()
	local ns = stats.load().ns

	describe("a Cast's places (STA-R10)", function()
		it("are its zone and its subzone", function()
			assert.are.same({ 148, 442 }, ns.PlacesOf(conditions({ zone = 148, subzone = 442 })))
		end)

		it("are its zone alone when its subzone is 0", function()
			assert.are.same({ 148 }, ns.PlacesOf(conditions({ zone = 148, subzone = 0 })))
		end)

		it(
			"are none when its zone is 0, whatever its subzone (STA-R93: a secret zone counts toward no place)",
			function()
				assert.are.same({}, ns.PlacesOf(conditions({ zone = 0, subzone = 442 })))
				assert.are.same({}, ns.PlacesOf(conditions({ zone = 0, subzone = 0 })))
			end
		)

		it("raise nothing on a snapshot without its zone fields (STA-R93)", function()
			assert.are.same({}, ns.PlacesOf({}))
			assert.are.same({ 148 }, ns.PlacesOf({ zone = 148 }))
		end)
	end)

	describe("the current place (STA-R10)", function()
		it("is the live subzone, or the zone when the subzone is 0, or none with zone 0", function()
			assert.are.equal(442, ns.CurrentPlace(conditions({ zone = 148, subzone = 442 })))
			assert.are.equal(148, ns.CurrentPlace(conditions({ zone = 148, subzone = 0 })))
			assert.is_nil(ns.CurrentPlace(conditions({ zone = 0, subzone = 442 })))
			assert.is_nil(ns.CurrentPlace({}))
		end)

		it("follows the live snapshot, Pagle.GetConditions()", function()
			local loaded, fake = stats.load()
			local live = fake.Pagle

			fake.setConditions(conditions({ zone = 148, subzone = 442 }))
			assert.are.equal(442, loaded.ns.CurrentPlace(live.GetConditions()))

			fake.setConditions(conditions({ zone = 12, subzone = 0 }))
			assert.are.equal(12, loaded.ns.CurrentPlace(live.GetConditions()))

			fake.setConditions(conditions({ zone = 0, subzone = 0 }))
			assert.is_nil(loaded.ns.CurrentPlace(live.GetConditions()))
		end)
	end)

	describe("effective skill (STA-R11)", function()
		it("is the rank plus the modifier", function()
			assert.are.equal(290, ns.EffectiveSkill(conditions({ skillRank = 265, skillMod = 25 })))
		end)

		it("is the rank alone without a modifier", function()
			assert.are.equal(265, ns.EffectiveSkill(conditions({ skillRank = 265 })))
		end)

		it("is unknown without a rank, whatever the modifier (STA-R93: a secret rank)", function()
			assert.is_nil(ns.EffectiveSkill(conditions({ skillMod = 25 })))
			assert.is_nil(ns.EffectiveSkill({}))
		end)

		it("reads the live snapshot the same way", function()
			local loaded, fake = stats.load()
			fake.setConditions(conditions({ zone = 148, skillRank = 150, skillMod = 10 }))

			assert.are.equal(160, loaded.ns.EffectiveSkill(fake.Pagle.GetConditions()))
		end)
	end)

	describe("a zone's no-junk line (STA-R12)", function()
		local _, fake = stats.load()
		local lookups = fake.Pagle

		it("is its skillBase plus the no-junk margin of 95 (Tunables)", function()
			assert.are.equal(95, ns.NO_JUNK_MARGIN)
			assert.are.equal(300, (ns.NoJunkLine(357, lookups)))
			assert.are.equal(170, (ns.NoJunkLine(148, lookups)))
		end)

		it("says whether it is confirmed, for STA-R46's sentence", function()
			assert.are.same({ 170, true }, { ns.NoJunkLine(148, lookups) })
			assert.are.same({ 225, false }, { ns.NoJunkLine(33, lookups) })
		end)

		it("is none for a zone without a skillBase, an unknown area or area 0", function()
			assert.is_nil(ns.NoJunkLine(12, lookups))
			assert.is_nil(ns.NoJunkLine(99999, lookups))
			assert.is_nil(ns.NoJunkLine(0, lookups))
			assert.is_nil(ns.NoJunkLine(1519, lookups))
		end)

		it("is a subzone's zone's line, never the subzone's own skillBase", function()
			assert.are.same({ 300, false }, { ns.NoJunkLine(1116, lookups) })
			assert.are.same({ 170, true }, { ns.NoJunkLine(442, lookups) })
		end)
	end)

	describe("a skill side (STA-R13)", function()
		local _, fake = stats.load()
		local lookups = fake.Pagle

		it("is hi at or above the zone's line and lo below it", function()
			assert.are.equal("hi", ns.SkillSide(300, ns.NoJunkLine(357, lookups)))
			assert.are.equal("hi", ns.SkillSide(301, ns.NoJunkLine(357, lookups)))
			assert.are.equal("lo", ns.SkillSide(299, ns.NoJunkLine(357, lookups)))
		end)

		it("is na with no line or an unknown skill (STA-R93: a secret rank puts the Cast on na)", function()
			assert.are.equal("na", ns.SkillSide(300, ns.NoJunkLine(12, lookups)))
			assert.are.equal("na", ns.SkillSide(nil, ns.NoJunkLine(357, lookups)))
			assert.are.equal("na", ns.SkillSide(ns.EffectiveSkill(conditions({ zone = 357 })), 300))
		end)

		it("is one side in both of a Cast's places, a subzone with its own skillBase included", function()
			for _, area in ipairs(ns.PlacesOf(conditions({ zone = 357, subzone = 1116 }))) do
				assert.are.equal("lo", ns.SkillSide(299, ns.NoJunkLine(area, lookups)))
				assert.are.equal("hi", ns.SkillSide(300, ns.NoJunkLine(area, lookups)))
			end
		end)
	end)

	describe("an item's window in a zone (STA-R14)", function()
		local _, fake = stats.load()
		local lookups = fake.Pagle

		it("is the one window every entry of the item carries: Nightfin bites in Darkshore at night", function()
			assert.are.equal("night", (ns.ItemWindow(148, 13759, lookups)))
			assert.are.equal("summer", (ns.ItemWindow(12, 13756, lookups)))
		end)

		it("is none where every entry is ungated: Nightfin in Elwynn Forest", function()
			assert.are.same({ nil, false }, { ns.ItemWindow(12, 13759, lookups) })
		end)

		it(
			"is none when some entries are gated and some not: Firefin, night in Darkshore, any hour in Auberdine",
			function()
				assert.is_nil(ns.ItemWindow(148, 6359, lookups))
			end
		)

		it("is none for an item on none of the zone's lists, and for an area that isn't a zone", function()
			assert.is_nil(ns.ItemWindow(148, 13756, lookups))
			assert.is_nil(ns.ItemWindow(442, 6359, lookups))
			assert.is_nil(ns.ItemWindow(99999, 13759, lookups))
			assert.is_nil(ns.ItemWindow(0, 13759, lookups))
		end)

		it("says whether any entry behind it has an unconfirmed gate", function()
			assert.are.same({ "night", true }, { ns.ItemWindow(148, 13759, lookups) })
			assert.are.same({ "summer", false }, { ns.ItemWindow(12, 13756, lookups) })
		end)

		it("is none when the item's entries carry different windows, never comparing their specs (LOG-R55)", function()
			local catalogue = stats.catalogue()
			-- Two windows with the same spec: still two windows.
			catalogue.windows.dusk = { spec = catalogue.windows.night.spec, confirmed = false }
			local auberdine = catalogue.areas[442].catches
			auberdine[#auberdine + 1] =
				{ itemID = 13759, confirmed = false, window = "dusk", gate = catalogue.windows.night.spec }
			local _, other = stats.load(nil, { catalogue = catalogue })

			assert.is_nil(ns.ItemWindow(148, 13759, other.Pagle))
		end)
	end)

	describe("a zone's windows (STA-R16)", function()
		local _, fake = stats.load()
		local lookups = fake.Pagle

		it("are the distinct window IDs on its entries and its subzones', sorted", function()
			assert.are.same({ "night" }, ns.ZoneWindows(148, lookups))
			assert.are.same({ "day", "summer" }, ns.ZoneWindows(12, lookups))
		end)

		it("include a Noise item's window and a removed item's", function()
			assert.are.same({ "day", "night", "summer" }, ns.ZoneWindows(357, lookups))
		end)

		it("are none for a zone without gates, an area that isn't a zone, or area 0", function()
			assert.are.same({}, ns.ZoneWindows(33, lookups))
			assert.are.same({}, ns.ZoneWindows(442, lookups))
			assert.are.same({}, ns.ZoneWindows(0, lookups))
		end)
	end)

	describe("testing a window (STA-R15)", function()
		local _, fake = stats.load()
		local lookups = fake.Pagle

		it("matches the window's spec against a Cast's conditions", function()
			assert.is_true(ns.InWindow("day", conditions({ zone = 12, minute = 8 * 60 + 15 }), lookups))
			assert.is_false(ns.InWindow("night", conditions({ zone = 12, minute = 8 * 60 + 15 }), lookups))
			assert.is_true(ns.InWindow("night", conditions({ zone = 12, minute = 23 * 60 }), lookups))
		end)

		it("matches nothing for a window the catalogue lacks", function()
			assert.is_false(ns.InWindow("event.301", conditions({ zone = 12 }), lookups))
		end)
	end)

	describe("the load-time tables (the fold reads them for every Cast)", function()
		-- Every area the fixture has, area 0 and one outside it; every item, item 0 and an Uncharted one.
		local function everything(catalogue)
			local areas, items = { 0, 99999 }, { 0, 77777 }
			for areaID in pairs(catalogue.areas) do
				areas[#areas + 1] = areaID
			end
			for itemID in pairs(catalogue.items) do
				items[#items + 1] = itemID
			end
			return areas, items
		end

		it("give the same answers as the uncached rules for every area, item and skill (STA-R12–R17)", function()
			local loaded, fake = stats.load()
			local lookups = fake.Pagle
			local tables = loaded.ns.NewPlaceTables(lookups)
			local areas, items = everything(stats.catalogue())
			local state =
				{ places = { [442] = { zone = 148, casts = 1, catches = 1, gotAway = 0, items = { [13756] = 1 } } } }

			-- Twice, so the second pass reads the tables the first built.
			for _ = 1, 2 do
				for _, area in ipairs(areas) do
					assert.are.same({ ns.NoJunkLine(area, lookups) }, { tables:NoJunkLine(area) })
					assert.are.same(ns.ZoneWindows(area, lookups), tables:ZoneWindows(area))
					assert.are.same(ns.Rows(state, area, lookups), tables:Rows(state, area))
					for _, skill in ipairs({ 169, 170, 224, 225, 299, 300 }) do
						assert.are.equal(ns.SkillSide(skill, ns.NoJunkLine(area, lookups)), tables:Side(area, skill))
					end
					assert.are.equal("na", tables:Side(area, nil))
					for _, itemID in ipairs(items) do
						assert.are.same({ ns.ItemWindow(area, itemID, lookups) }, { tables:ItemWindow(area, itemID) })
					end
				end
			end
		end)

		it("test a window as the uncached rule does (STA-R15)", function()
			local loaded, fake = stats.load()
			local tables = loaded.ns.NewPlaceTables(fake.Pagle)

			for _, minute in ipairs({ 0, 359, 360, 1079, 1080 }) do
				local cast = conditions({ zone = 12, minute = minute })
				for _, window in ipairs({ "day", "night", "summer", "event.301" }) do
					assert.are.equal(ns.InWindow(window, cast, fake.Pagle), tables:InWindow(window, cast))
				end
			end
		end)

		it(
			"are dropped when the content fingerprint changes, so a content update is read afresh (DATA-R70, LOG-R72)",
			function()
				local loaded, fake = stats.load()
				local tables = loaded.ns.NewPlaceTables(fake.Pagle)
				assert.are.equal("night", (tables:ItemWindow(148, 13759)))
				assert.are.same({ 170, true }, { tables:NoJunkLine(442) })
				assert.are.same({ "night" }, tables:ZoneWindows(148))

				local updated = stats.catalogue()
				updated.fingerprint = "0000000000000002"
				updated.areas[148].skillBase = 100
				updated.areas[148].catches[4] = { itemID = 13759, confirmed = false }
				updated.areas[148].catches[3] = { itemID = 6359, confirmed = false }
				fake.setCatalogue(updated)

				assert.is_nil(tables:ItemWindow(148, 13759))
				assert.are.same({ 195, true }, { tables:NoJunkLine(442) })
				assert.are.same({}, tables:ZoneWindows(148))
			end
		)
	end)
end)
