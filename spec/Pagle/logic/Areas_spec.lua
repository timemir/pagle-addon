-- The runtime area index (LOG-R23) and zone and subzone resolution (LOG-R22), through the logic/ functions Core's
-- adapter calls, over fixture area names and a fixture AreaTable slice.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- What C_Map.GetAreaInfo answers in the fixture client: an enUS name per areaID, nil for the rest.
local NAMES = {
	[1] = "Dun Morogh",
	[17] = "The Barrens",
	[18] = "Crystal Lake",
	[20] = "Twin Peaks",
	[21] = "Twin Peaks",
	[36] = "Alterac Mountains",
	[148] = "Darkshore",
	[279] = "Dalaran",
	[453] = "The Long Wash",
	[454] = "Lighthouse",
	[455] = "Lighthouse",
	[16200] = "Riverglades",
	[16521] = "Glimmer Bay",
	[17824] = "The Eventide",
	[17845] = "Dreambound Pinnacle",
	[30001] = "Duskwood Glade",
	[30002] = "Duskwood Glade",
	[30010] = "Mirror Pool",
	[30011] = "Mirror Hollow",
}

-- The AreaTable slice (DATA-R25, DATA-R79): Dun Morogh (1) and a Twin Peaks (20) on continent 0; Darkshore (148,
-- with The Long Wash 453 and a Lighthouse 454), The Barrens (17, with another Lighthouse 455) and another Twin Peaks
-- (21) on continent 1; Glimmer Bay (16521), on another map, stands for Crystal Lake (18). Riverglades (16200) and
-- Duskwood Glade (30001, 30002) are named by the client but aren't in the slice. The Eventide (17824) is nested: its
-- parent is Dalaran (279), whose parent is Alterac Mountains (36) on continent 0. Dreambound Pinnacle (17845) has a
-- parent (16597) missing from the slice, as in areas.csv; Mirror Pool (30010) and Mirror Hollow (30011) are each
-- other's parent.
local function slice()
	local function area(parent, continent)
		return { parent = parent, continent = continent, hasData = false, skillBaseConfirmed = false, catches = {} }
	end
	return ns.NewCatalogue({
		fingerprint = "0123456789abcdef",
		items = {},
		areas = {
			[1] = area(0, 0),
			[12] = area(0, 0),
			[17] = area(0, 1),
			[18] = area(12, 0),
			[20] = area(0, 0),
			[21] = area(0, 1),
			[36] = area(0, 0),
			[148] = area(0, 1),
			[279] = area(36, 0),
			[453] = area(148, 1),
			[454] = area(148, 1),
			[455] = area(17, 1),
			[16521] = area(0, 0),
			[17824] = area(279, 0),
			[17845] = area(16597, 1),
			[30010] = area(30011, 1),
			[30011] = area(30010, 1),
		},
		aliases = { [16521] = 18 },
		pools = {},
		windows = {},
		events = {},
		fishingSpells = {},
		auras = {},
	})
end

local KALIMDOR, EASTERN_KINGDOMS = 1, 0

describe("ns.NewAreaIndex", function()
	it("asks for every ID from 1 to the last, once each, in order (LOG-R23)", function()
		local asked = {}
		ns.NewAreaIndex(function(id)
			asked[#asked + 1] = id
			return NAMES[id]
		end, 40000)

		assert.are.equal(40000, #asked)
		for i = 1, 40000 do
			if asked[i] ~= i then
				error(("asked for %s at call %d"):format(tostring(asked[i]), i))
			end
		end
	end)

	it("maps each name to every ID that has it, ascending, and skips IDs with no name (LOG-R23)", function()
		local index = ns.NewAreaIndex(function(id)
			if id == 99 then
				return ""
			end
			return NAMES[id]
		end, 40000)

		assert.are.same({ 148 }, index["Darkshore"])
		assert.are.same({ 454, 455 }, index["Lighthouse"])
		assert.are.same({ 30001, 30002 }, index["Duskwood Glade"])
		assert.is_nil(index[""])
	end)
end)

describe("ns.ResolveAreas", function()
	local index = ns.NewAreaIndex(function(id)
		return NAMES[id]
	end, 40000)
	local catalogue = slice()

	local function resolve(zoneText, subzoneText, continent)
		return ns.ResolveAreas(index, catalogue, zoneText, subzoneText, continent)
	end

	it("resolves a zone name with one ID in the slice on the current continent (LOG-R22)", function()
		assert.are.same({ 148, 0 }, { resolve("Darkshore", "", KALIMDOR) })
	end)

	it("gives 0 for a zone in the slice only on another continent (LOG-R22)", function()
		assert.are.same({ 0, 0, { zone = "Darkshore", subzone = "" } }, { resolve("Darkshore", "", EASTERN_KINGDOMS) })
	end)

	it("picks the current continent's zone when the name is on two continents (LOG-R22)", function()
		assert.are.equal(21, (resolve("Twin Peaks", "", KALIMDOR)))
		assert.are.equal(20, (resolve("Twin Peaks", "", EASTERN_KINGDOMS)))
	end)

	it("uses a name outside the slice that has exactly one ID (LOG-R22)", function()
		assert.are.same({ 16200, 0 }, { resolve("Riverglades", "", KALIMDOR) })
	end)

	it("gives 0 for a name with several IDs, none in the slice, and hands back the text (LOG-R22)", function()
		assert.are.same(
			{ 0, 0, { zone = "Duskwood Glade", subzone = "" } },
			{ resolve("Duskwood Glade", "", KALIMDOR) }
		)
	end)

	it("gives subzone 0 for an empty subzone text, which isn't unresolved (LOG-R22)", function()
		assert.are.same({ 148, 0 }, { resolve("Darkshore", "", KALIMDOR) })
	end)

	it("gives subzone 0 for a subzone text equal to the zone's, which isn't unresolved (LOG-R22)", function()
		assert.are.same({ 148, 0 }, { resolve("Darkshore", "Darkshore", KALIMDOR) })
	end)

	it("resolves a subzone to the one of its IDs under the resolved zone (LOG-R22)", function()
		assert.are.same({ 148, 453 }, { resolve("Darkshore", "The Long Wash", KALIMDOR) })
		assert.are.same({ 148, 454 }, { resolve("Darkshore", "Lighthouse", KALIMDOR) })
		assert.are.same({ 17, 455 }, { resolve("The Barrens", "Lighthouse", KALIMDOR) })
	end)

	it("gives 0 for a subzone whose IDs are in the slice but not under the zone (LOG-R22)", function()
		assert.are.same(
			{ 17, 0, { zone = "The Barrens", subzone = "The Long Wash" } },
			{ resolve("The Barrens", "The Long Wash", KALIMDOR) }
		)
	end)

	it("resolves a subzone whose parent chain reaches the zone (LOG-R22)", function()
		assert.are.same({ 36, 17824 }, { resolve("Alterac Mountains", "The Eventide", EASTERN_KINGDOMS) })
		assert.are.same({ 36, 279 }, { resolve("Alterac Mountains", "Dalaran", EASTERN_KINGDOMS) })
	end)

	it("gives 0 for a subzone whose parent is missing from the slice (LOG-R22)", function()
		assert.are.same(
			{ 148, 0, { zone = "Darkshore", subzone = "Dreambound Pinnacle" } },
			{ resolve("Darkshore", "Dreambound Pinnacle", KALIMDOR) }
		)
	end)

	it("gives 0 for a subzone in a parent cycle, and the walk ends (LOG-R22)", function()
		assert.are.same(
			{ 148, 0, { zone = "Darkshore", subzone = "Mirror Pool" } },
			{ resolve("Darkshore", "Mirror Pool", KALIMDOR) }
		)
	end)

	it("uses a subzone name outside the slice that has exactly one ID (LOG-R22)", function()
		assert.are.same({ 148, 16200 }, { resolve("Darkshore", "Riverglades", KALIMDOR) })
	end)

	it("maps an alias source to its baseline area (LOG-R22, LOG-R56)", function()
		assert.are.same({ 18, 0 }, { resolve("Glimmer Bay", "", EASTERN_KINGDOMS) })
	end)

	it("gives 0 for an unresolved name and hands back both texts (LOG-R22, LOG-R81)", function()
		assert.are.same(
			{ 0, 0, { zone = "Nowhere", subzone = "Lighthouse" } },
			{ resolve("Nowhere", "Lighthouse", KALIMDOR) }
		)
		assert.are.same(
			{ 148, 0, { zone = "Darkshore", subzone = "Somewhere" } },
			{ resolve("Darkshore", "Somewhere", KALIMDOR) }
		)
	end)

	it("gives zone 0 for an empty zone text, which isn't unresolved, as for nil (LOG-R22, LOG-R81)", function()
		assert.are.same({ 0, 0 }, { resolve("", "", KALIMDOR) })
		assert.are.same({ 0, 0 }, { resolve("", nil, KALIMDOR) })
	end)

	it("gives 0 with no text to hand back for a secret text, passed in as nil (LOG-R22, CORE-R31)", function()
		assert.are.same({ 0, 0 }, { resolve(nil, nil, KALIMDOR) })
		assert.are.same({ 148, 0 }, { resolve("Darkshore", nil, KALIMDOR) })
	end)

	it("gives zone 0 without the current continent (LOG-R22, CORE-R31)", function()
		assert.are.same({ 0, 0, { zone = "Darkshore", subzone = "" } }, { resolve("Darkshore", "", nil) })
	end)
end)
