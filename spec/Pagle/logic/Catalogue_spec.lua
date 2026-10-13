-- The catalogue accessors (LOG-R55–R57) over a fixture catalogue in the M1 shape (DATA-R79), through
-- ns.NewCatalogue, which the adapter builds once over ns.catalogue and publishes on Pagle.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A catalogue as DATA-R79 allows before M2: areas with empty catches, aliases, events and the two lists; no items,
-- pools or windows. Areas: Dun Morogh (1) and Elwynn Forest (12, with Crystal Lake 18) on continent 0; Darkshore
-- (148, with The Long Wash 453) and The Barrens (17) on continent 1; 16521 stands for Crystal Lake on another map.
-- Event 301 has a weekly rule; 302 has none, which the generator emits as {}.
local function fixture()
	local function area(parent, continent)
		return { parent = parent, continent = continent, hasData = false, skillBaseConfirmed = false, catches = {} }
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {},
		areas = {
			[1] = area(0, 0),
			[12] = area(0, 0),
			[17] = area(0, 1),
			[18] = area(12, 0),
			[148] = area(0, 1),
			[453] = area(148, 1),
			[16521] = area(0, 0),
		},
		aliases = { [16521] = 18 },
		pools = {},
		windows = {},
		events = { [301] = { weekday = 1, start = 840, duration = 120, confirmed = false }, [302] = {} },
		fishingSpells = { 7620, 7731, 7732, 18248 },
		auras = { 1265220, 1280341 },
	}
end

describe("ns.NewCatalogue", function()
	it("lists every zone (parent 0) in the slice, ascending (LOG-R55)", function()
		assert.are.same({ 1, 12, 17, 148, 16521 }, ns.NewCatalogue(fixture()).GetZones())
	end)

	it("hands out an area's own record, and nil for an area outside the slice (LOG-R55, CORE-R18)", function()
		local data = fixture()
		local catalogue = ns.NewCatalogue(data)

		assert.are.equal(data.areas[453], catalogue.GetArea(453))
		assert.are.same(
			{ parent = 148, continent = 1, hasData = false, skillBaseConfirmed = false, catches = {} },
			catalogue.GetArea(453)
		)
		assert.is_nil(catalogue.GetArea(9999))
	end)

	it("gives a subzone's zone, and a zone itself (LOG-R55)", function()
		local data = fixture()
		data.areas[454] = { parent = 453, continent = 1, hasData = false, skillBaseConfirmed = false, catches = {} }
		local catalogue = ns.NewCatalogue(data)

		assert.are.equal(148, catalogue.GetZoneOf(453))
		assert.are.equal(148, catalogue.GetZoneOf(454), "an area under a subzone still belongs to the zone")
		assert.are.equal(148, catalogue.GetZoneOf(148))
		assert.is_nil(catalogue.GetZoneOf(9999))
	end)

	it("charts no item before M2, so every Catch is Uncharted (LOG-R55, LOG-R57)", function()
		assert.is_nil(ns.NewCatalogue(fixture()).GetItem(6358))
	end)

	it("lists no catches for a zone while the areas have none (LOG-R55, DATA-R79)", function()
		local catalogue = ns.NewCatalogue(fixture())

		assert.are.same({}, catalogue.GetZoneCatches(148))
		assert.are.same({}, catalogue.GetZoneCatches(12))
	end)

	it("lists a zone's catches and its subzones', once per area, each with its areaID (LOG-R55)", function()
		local data = fixture()
		data.areas[148].catches = { { itemID = 6358, confirmed = true } }
		data.areas[453].catches = { { itemID = 6358, confirmed = false }, { itemID = 13759, confirmed = true } }

		assert.are.same({
			{ areaID = 148, itemID = 6358, confirmed = true },
			{ areaID = 453, itemID = 6358, confirmed = false },
			{ areaID = 453, itemID = 13759, confirmed = true },
		}, ns.NewCatalogue(data).GetZoneCatches(148))
	end)

	it("has no window spec before M2 (LOG-R55, DATA-R79)", function()
		local catalogue = ns.NewCatalogue(fixture())

		for _, window in ipairs({ "day", "night", "spring", "summer", "autumn", "winter", "event.301" }) do
			assert.is_nil(catalogue.GetWindowSpec(window))
		end
	end)

	it("carries the generator's fingerprint (LOG-R55, DATA-R70)", function()
		assert.are.equal("0123456789abcdef", ns.NewCatalogue(fixture()).CONTENT_FINGERPRINT)
	end)
end)

describe("ns.NewCatalogue's Core-internal reads", function()
	local catalogue = ns.NewCatalogue(fixture())

	it("knows the fishing spells (LOG-R2, LOG-R56)", function()
		assert.is_true(catalogue.IsFishingSpell(7620))
		assert.is_true(catalogue.IsFishingSpell(18248))
		assert.is_false(catalogue.IsFishingSpell(1))
	end)

	it("lists the fishing auras, ascending as shipped (LOG-R20, LOG-R56)", function()
		assert.are.same({ 1265220, 1280341 }, catalogue.GetFishingAuras())
	end)

	it("lists the event IDs ascending, each with its weekly rule if it has one (LOG-R46, LOG-R56)", function()
		assert.are.same({ 301, 302 }, catalogue.GetEventIDs())
		assert.are.same({ weekday = 1, start = 840, duration = 120, confirmed = false }, catalogue.GetEventRule(301))
		assert.is_nil(catalogue.GetEventRule(302))
		assert.is_nil(catalogue.GetEventRule(999))
	end)

	it("maps an alias source to its baseline area, and any other area to itself (LOG-R22, LOG-R56)", function()
		assert.are.equal(18, catalogue.Unalias(16521))
		assert.are.equal(453, catalogue.Unalias(453))
	end)
end)
