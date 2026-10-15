-- Search on the Stats book's leather (STA-R76; stats.md › Tunables: 6 fish, 5 places): what a query finds among the
-- items of my records and the places in them, over hand-built StatsState tables, the fixture catalogue through
-- Core's own accessors and names given as tables. The box and its dropdown are in adapter/Search_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, ELWYNN, STRANGLETHORN = 148, 442, 446, 12, 33
local FERALAS, FEATHERMOON = 357, 1116
local MACKEREL, FIREFIN, MANA_POTION = 6303, 6359, 2455
local UNCHARTED = stats.IDS.UNCHARTED

-- The fixture's names (stats.NAMES), and the Uncharted item's.
local ITEM_NAMES = setmetatable({ [UNCHARTED] = "Strange Old Boot" }, { __index = stats.NAMES.items })
local AREA_NAMES = stats.NAMES.areas

-- A place record (StatsPlace) in `zone`, with catches by item.
local function place(zone, items)
	return { zone = zone, casts = 1, catches = 0, gotAway = 0, items = items or {} }
end

-- A state with `places` and `items` (the Lifetime index, STA-R25).
local function stateWith(places, items)
	return { places = places or {}, items = items or {}, scopes = {}, hits = {} }
end

-- Names as the client gives them: each table's, nil for one not loaded.
local function namesFrom(items, areas)
	return {
		item = function(id)
			return items[id]
		end,
		area = function(id)
			return areas[id]
		end,
	}
end
local NAMES = namesFrom(ITEM_NAMES, AREA_NAMES)

-- Each result as "{name} ({label})".
local function lines(found)
	local out = {}
	for i, result in ipairs(found.results) do
		out[i] = result.name .. " (" .. result.label .. ")"
	end
	return out
end

describe("search (STA-R76)", function()
	local loaded = stats.load()
	local ns = loaded.ns
	for id, name in pairs(AREA_NAMES) do
		loaded.client.areaNames[id] = name
	end

	-- Darkshore and two of its waters, Elwynn, and Feralas with Feathermoon: Elwynn's and Darkshore's rows hold seven
	-- fish between them (Darkshore's GetZoneCatches has Auberdine's list in it).
	local function fished()
		return stateWith({
			[DARKSHORE] = place(DARKSHORE),
			[AUBERDINE] = place(DARKSHORE),
			[BASHAL_ARAN] = place(DARKSHORE),
			[ELWYNN] = place(ELWYNN),
			[FERALAS] = place(FERALAS),
			[FEATHERMOON] = place(FERALAS),
		})
	end

	it("finds nothing, and shows nothing, for an empty box", function()
		assert.is_nil(ns.Search("", fished(), NAMES))
	end)

	it("matches case-insensitively anywhere in the name, fish first, each with its label", function()
		local found = ns.Search("FIN", fished(), NAMES)

		assert.are.same({ "Firefin Snapper (fish)", "Raw Nightfin Snapper (fish)" }, lines(found))
		assert.is_nil(found.none)
		assert.are.same({ page = "item", item = FIREFIN }, found.results[1].target)
	end)

	it("labels a zone 'zone' and a subzone with its zone's name, and opens its place page", function()
		local found = ns.Search("ther", fished(), NAMES)

		assert.are.same({ "Feathermoon Stronghold (Feralas)" }, lines(found))
		assert.are.same({ page = "place", area = FEATHERMOON }, found.results[1].target)
		assert.are.same({ "Darkshore (zone)" }, lines(ns.Search("darks", fished(), NAMES)))
	end)

	it("shows up to 6 fish, then up to 5 places, each list alphabetical (stats.md › Tunables)", function()
		local state = fished()
		state.places[STRANGLETHORN] = place(STRANGLETHORN)

		-- seven fish and six places have an "a"; Raw Summer Bass and Stranglethorn Vale come last
		local found = ns.Search("a", state, NAMES)

		assert.are.same({
			"Firefin Snapper (fish)",
			"Oily Blackmouth (fish)",
			"Raw Brilliant Smallfish (fish)",
			"Raw Mackerel (fish)",
			"Raw Mud Snapper (fish)",
			"Raw Nightfin Snapper (fish)",
			"Auberdine (Darkshore)",
			"Bashal'Aran (Darkshore)",
			"Darkshore (zone)",
			"Feathermoon Stronghold (Feralas)",
			"Feralas (zone)",
		}, lines(found))
	end)

	it("finds the fish on the rows of zones I've fished and in my records, nothing else", function()
		local state = stateWith({ [STRANGLETHORN] = place(STRANGLETHORN) }, {
			[MANA_POTION] = { n = 1, first = 0, last = 0 },
			[UNCHARTED] = { n = 1, first = 0, last = 0 },
		})

		-- Stranglethorn's rows hold Mackerel (Mana Potion is Noise); my records hold the potion and the boot. Elwynn's
		-- fish aren't in reach: I haven't fished there.
		assert.are.same({ "Raw Mackerel (fish)" }, lines(ns.Search("mack", state, NAMES)))
		assert.are.same({ "Minor Mana Potion (fish)" }, lines(ns.Search("potion", state, NAMES)))
		assert.are.same({ "Strange Old Boot (fish)" }, lines(ns.Search("boot", state, NAMES)))
		assert.are.same({}, lines(ns.Search("mud", state, NAMES)))
		assert.are.same({ MANA_POTION, MACKEREL, UNCHARTED }, ns.SearchItems(state))
	end)

	it("matches an item only once its name has loaded", function()
		local partly = namesFrom({ [MACKEREL] = "Raw Mackerel" }, AREA_NAMES)

		assert.are.same({ "Raw Mackerel (fish)" }, lines(ns.Search("raw", fished(), partly)))
		assert.are.same({ "Raw Mackerel (fish)", "Raw Mud Snapper (fish)" }, lines(ns.Search("raw m", fished(), NAMES)))
	end)

	it('reads "Nothing by that name in my records." with no results, and takes the query as plain text', function()
		local found = ns.Search("zzz", fished(), NAMES)

		assert.are.same({}, found.results)
		assert.are.equal("Nothing by that name in my records.", found.none)
		assert.are.same({}, ns.Search("(%", fished(), NAMES).results)
	end)
end)
