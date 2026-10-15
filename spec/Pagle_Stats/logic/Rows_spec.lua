-- A place's rows (STA-R17): the items its page lists, from the catalogue's lists for the place and the items caught
-- there, over the fixture catalogue through Core's own accessors and a state in stats.md's `places` shape.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN, STRANGLETHORN, STORMWIND = 148, 442, 446, 12, 33, 1519
local FERALAS, FEATHERMOON = 357, 1116
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, BASS, MUD_SNAPPER, SMALLFISH = 6303, 6358, 6359, 13759, 13756, 6289, 6291
local MANA_POTION, RUSTED_LURE = 2455, 90001
local UNCHARTED = stats.IDS.UNCHARTED

-- A state with only `places[area]`, in stats.md's Projection state shape (all the rows read), whose items are
-- caught there.
---@param area integer
---@param zone integer
---@param items table<integer, integer> catches by item ID
---@return table
local function stateWith(area, zone, items)
	return { places = { [area] = { zone = zone, casts = 10, catches = 0, gotAway = 0, items = items } } }
end

-- A place's rows as { itemID, added } pairs, in their order.
---@param rows StatsRow[]
---@return table
local function pairsOf(rows)
	local out = {}
	for i, row in ipairs(rows) do
		out[i] = { row.item, row.added }
	end
	return out
end

describe("a place's rows (STA-R17)", function()
	local loaded, fake = stats.load()
	local ns, lookups = loaded.ns, fake.Pagle
	local empty = { places = {} }

	it("are a subzone's own list when it has one", function()
		assert.are.same({ { FIREFIN, false }, { SMALLFISH, false } }, pairsOf(ns.Rows(empty, AUBERDINE, lookups)))
	end)

	it("are the zone's own list for a subzone without one, its removed item dropped", function()
		assert.are.same(
			{ { MACKEREL, false }, { BLACKMOUTH, false }, { FIREFIN, false }, { NIGHTFIN, false } },
			pairsOf(ns.Rows(empty, BASHAL_ARAN, lookups))
		)
	end)

	it("use the zone's own list for a subzone without one, though the subzone has its own skillBase", function()
		assert.are.same({ { NIGHTFIN, false } }, pairsOf(ns.Rows(empty, FEATHERMOON, lookups)))
	end)

	it("are every item in a zone's GetZoneCatches once each, its subzones' included", function()
		assert.are.same({
			{ MACKEREL, false },
			{ BLACKMOUTH, false },
			{ FIREFIN, false },
			{ NIGHTFIN, false },
			{ SMALLFISH, false },
		}, pairsOf(ns.Rows(empty, DARKSHORE, lookups)))
		assert.are.same({
			{ NIGHTFIN, false },
			{ BASS, false },
			{ MUD_SNAPPER, false },
			{ SMALLFISH, false },
		}, pairsOf(ns.Rows(empty, ELWYNN, lookups)))
	end)

	it("never list a Noise or a removed item", function()
		assert.are.same({ { MACKEREL, false } }, pairsOf(ns.Rows(empty, STRANGLETHORN, lookups)))
		assert.are.same({ { NIGHTFIN, false } }, pairsOf(ns.Rows(empty, FERALAS, lookups)))
	end)

	it(
		"add each item caught in the place that its list lacks, marked, Uncharted ones included, in item ID order",
		function()
			local state = stateWith(AUBERDINE, DARKSHORE, { [FIREFIN] = 2, [UNCHARTED] = 1, [BASS] = 3 })

			assert.are.same({
				{ FIREFIN, false },
				{ SMALLFISH, false },
				{ BASS, true },
				{ UNCHARTED, true },
			}, pairsOf(ns.Rows(state, AUBERDINE, lookups)))
		end
	)

	it("never add a caught Noise or removed item, nor item 0", function()
		local state = stateWith(BASHAL_ARAN, DARKSHORE, { [MANA_POTION] = 1, [RUSTED_LURE] = 1, [0] = 4 })

		assert.are.same(
			{ { MACKEREL, false }, { BLACKMOUTH, false }, { FIREFIN, false }, { NIGHTFIN, false } },
			pairsOf(ns.Rows(state, BASHAL_ARAN, lookups))
		)
	end)

	it("are only the items caught there in a place with no list: no catch data, or outside the catalogue", function()
		assert.are.same({}, ns.Rows(empty, STORMWIND, lookups))
		assert.are.same(
			{ { MACKEREL, true } },
			pairsOf(ns.Rows(stateWith(STORMWIND, STORMWIND, { [MACKEREL] = 1 }), STORMWIND, lookups))
		)
		assert.are.same(
			{ { SMALLFISH, true } },
			pairsOf(ns.Rows(stateWith(99999, 99999, { [SMALLFISH] = 1 }), 99999, lookups))
		)
	end)

	it("read only the place's own record, not another place's catches", function()
		local state = stateWith(DARKSHORE, DARKSHORE, { [BASS] = 1 })

		assert.are.same({ { FIREFIN, false }, { SMALLFISH, false } }, pairsOf(ns.Rows(state, AUBERDINE, lookups)))
	end)
end)
