-- The Angler's titles (LED-R75–R77, LED-R35, LED-R54, LED-R70, LED-R72, LED-R92, LED-R161): which are earned and in
-- what order, their title keys, their names from lore, the active title and the titles not yet celebrated, over
-- hand-made states, a fixture world and a fixture Lore.lua. ledger.md › Titles, Ledger completion, Lore, Data. No Core.

-- Lake lists two Species, a junk item, a container, a trophy and a Legend; Cove lists one Species. A second Legend is
-- on no list.
local FISH_1, FISH_2, FISH_3 = 6303, 6291, 13759
local JUNK, CHEST, TROPHY = 6309, 6307, 13901
local LEGEND, LEGEND_2 = 19807, 19803
local LAKE, COVE = 12, 40

local getItem = itemLookup({
	[FISH_1] = fishRecord(FISH_1),
	[FISH_2] = fishRecord(FISH_2),
	[FISH_3] = fishRecord(FISH_3),
	[JUNK] = itemRecord("junk"),
	[CHEST] = itemRecord("container"),
	[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
	[LEGEND_2] = fishRecord(LEGEND_2, { legend = true }),
})
local entry = catchEntry

-- Core's lookups (LOG-R55) over `areas`: zones ascending, each catch with its areaID.
---@param areas table<integer, table>
local function lookups(areas)
	local zones = {}
	for zone in pairs(areas) do
		zones[#zones + 1] = zone
	end
	table.sort(zones)
	return {
		GetItem = getItem,
		GetZones = function()
			return zones
		end,
		GetArea = function(zone)
			return areas[zone]
		end,
		GetZoneCatches = function(zone)
			local list = {}
			for i, catch in ipairs(areas[zone].catches) do
				list[i] = { areaID = zone, itemID = catch.itemID, confirmed = catch.confirmed }
			end
			return list
		end,
	}
end

-- What the fixture's world leaves out: `cove` gives Cove no data, so it isn't charted (LED-R54); `junk` takes the
-- junk item off Lake's list.
---@alias TitlesFixtureWithout { cove: boolean?, junk: boolean? }

-- The fixture's zones (LED-R10), less what `without` names.
---@param without TitlesFixtureWithout?
local function areas(without)
	without = without or {}
	local lake = { entry(FISH_1), entry(FISH_2), entry(CHEST), entry(TROPHY), entry(LEGEND) }
	if not without.junk then
		lake[#lake + 1] = entry(JUNK)
	end
	return {
		[LAKE] = { hasData = true, catches = lake },
		[COVE] = { hasData = not without.cove, catches = { entry(FISH_3) } },
	}
end

-- XP at the start of level 23 (LED-R30): Σ (1,000 + 80 × L) for L = 1 … 22 = 22,000 + 80 × 253.
local LEVEL_23 = 42240

-- A first Catch (ledger.md › Data, LedgerFirst).
local function first()
	return { n = 1, time = SERVER_TIME - 700, char = 1, zone = LAKE }
end

-- A hand-made state (ledger.md › Data) at `xp` XP and prestige rank `prestige`, holding `species`, `items` and each
-- zone's computed rank in `ranks`.
---@param fields { xp: integer?, prestige: integer?, species: integer[]?, items: integer[]?, ranks: table<integer, integer>? }
---@return LedgerState
local function state(fields)
	local made = {
		casts = 0,
		catches = 0,
		xp = fields.xp or 0,
		prestige = fields.prestige or 0,
		fresh = 300,
		coins = 0,
		skill = {},
		milestones = {},
		species = {},
		items = {},
		uncharted = {},
		zones = {},
	}
	for _, id in ipairs(fields.species or {}) do
		made.species[id] = first()
	end
	for _, itemID in ipairs(fields.items or {}) do
		made.items[itemID] = first()
	end
	for zone, rank in pairs(fields.ranks or {}) do
		made.zones[zone] = { species = {}, families = {}, items = {}, junk = false, treasure = false, rank = rank }
	end
	return made
end

describe("the Angler's titles", function()
	local loaded = loadAddon(
		"Pagle_Ledger",
		FOREVER_GLOBALS,
		{ replace = { ["data/Lore.lua"] = "spec/Pagle_Ledger/fixtures/TitlesLore.lua" } }
	)
	local ns = loaded.ns

	-- What the titles read (LedgerTitleView): the fixture world, `made`, `celebrated` and the fixture's items.
	---@param made LedgerState?
	---@param celebrated table? a LedgerCelebrated, as hand-made as the state
	---@param without TitlesFixtureWithout?
	local function view(made, celebrated, without)
		return {
			world = ns.NewWorld(lookups(areas(without))),
			state = made,
			celebrated = celebrated or { coins = 0 },
			getItem = getItem,
		}
	end

	-- The Journal's words (#139's lore lookup) over a client that knows Lake's and Cove's names.
	-- Only the area names: the lore lookup reads nothing else.
	---@type table
	local client = {
		AreaName = function(areaID)
			return ({ [LAKE] = "Loch Modan", [COVE] = "Darkshore" })[areaID]
		end,
	}
	local text = ns.NewJournalText(client --[[@as LedgerTextClient]])

	describe("names", function()
		it("read a title's lore text, a Legend's its legend title (LED-R75, LED-R160)", function()
			assert.are.same({ "Minnow", "Dabbler", "Returning Tide", "Angler of Azeroth", "The Tasty One" }, {
				ns.TitleName("title:level1", text),
				ns.TitleName("title:level10", text),
				ns.TitleName("title:prestige1", text),
				ns.TitleName("title:complete.ledger", text),
				ns.TitleName("legend:" .. LEGEND, text),
			})
		end)

		it("fill a zonemaster title's {zone} with the zone's name (LED-R161, DATA-R108)", function()
			assert.are.equal("Warden of Loch Modan Waters", ns.TitleName("zonemaster:" .. LAKE, text))
			assert.are.equal("Warden of Darkshore Waters", ns.TitleName("zonemaster:" .. COVE, text))
		end)

		it("are nil for a title with no lore text, so a line naming it is left out (LED-R161)", function()
			assert.is_nil(ns.TitleName("title:prestige5", text))
			assert.is_nil(ns.TitleName("title:complete.trophy", text))
			assert.is_nil(ns.TitleName("legend:" .. LEGEND_2, text))
			assert.is_nil(ns.TitleName("title:nosuchtitle", text))
			assert.is_nil(ns.TitleName("TITLE", text))
		end)
	end)

	describe("the active title", function()
		-- A view at level 23 with Lake mastered, `stored` as the active title and the Journal's words.
		---@param stored string?
		---@param celebrated table? a LedgerCelebrated, as hand-made as the state
		local function signed(stored, celebrated)
			local signedView = view(state({ xp = LEVEL_23, ranks = { [LAKE] = 5 } }), celebrated)
			signedView.activeTitle = stored
			signedView.text = text
			return signedView
		end

		it("is automatic with none stored: the highest level title earned (LED-R77)", function()
			assert.are.same({ "title:level20", "Line-Caster" }, { ns.ActiveTitle(signed(nil)) })
			-- A celebrated level title counts as earned (LED-R76).
			assert.are.same(
				{ "title:level30", "Fisher" },
				{ ns.ActiveTitle(signed(nil, { coins = 0, titles = { ["title:level30"] = true } })) }
			)
		end)

		it("is the stored key when it is earned (LED-R77)", function()
			assert.are.same(
				{ "zonemaster:" .. LAKE, "Warden of Loch Modan Waters" },
				{ ns.ActiveTitle(signed("zonemaster:" .. LAKE)) }
			)
		end)

		it("reads a stored key that isn't earned as automatic, and leaves it stored (LED-R77)", function()
			local stored = signed("title:level60")

			assert.are.same({ "title:level20", "Line-Caster" }, { ns.ActiveTitle(stored) })
			assert.are.equal("title:level60", stored.activeTitle)
		end)

		it("has a key but no name while its title has no lore text (LED-R161)", function()
			local stored = signed("title:prestige5", { coins = 0, titles = { ["title:prestige5"] = true } })

			assert.are.same({ "title:prestige5" }, { ns.ActiveTitle(stored) })
		end)

		it("is none with no title earned, before the projection is built (LED-R77)", function()
			assert.are.same({}, { ns.ActiveTitle(view(nil)) })
		end)

		it("can be set only to an earned key, or to nil for automatic (LED-R77)", function()
			local profile = {}
			local current = signed(nil)

			assert.is_true(ns.StoreActiveTitle(profile, current, "zonemaster:" .. LAKE))
			assert.are.equal("zonemaster:" .. LAKE, profile.activeTitle)
			assert.is_false(ns.StoreActiveTitle(profile, current, "title:level60"))
			assert.is_false(ns.StoreActiveTitle(profile, current, "zonemaster:" .. COVE))
			assert.are.equal("zonemaster:" .. LAKE, profile.activeTitle)
			assert.is_true(ns.StoreActiveTitle(profile, current, nil))
			assert.is_nil(profile.activeTitle)
		end)
	end)

	describe("newly earned", function()
		it(
			"are the computed titles not yet celebrated, in LED-R75's order, never level1 (LED-R75, LED-R90, LED-R97)",
			function()
				local made = state({ xp = LEVEL_23, ranks = { [LAKE] = 5 }, items = { LEGEND, JUNK } })
				local celebrated = { coins = 0, titles = { ["title:level10"] = true, ["title:level60"] = true } }

				assert.are.same({
					"title:level20",
					"zonemaster:" .. LAKE,
					"legend:" .. LEGEND,
					"title:complete.junk",
				}, ns.NewTitles(view(made, celebrated)))
				assert.are.same({}, ns.NewTitles(view(nil, celebrated)))
			end
		)

		it("say which moment each rides on: its kind and number (LED-R97)", function()
			assert.are.same({ "level", 20 }, { ns.TitleKind("title:level20") })
			assert.are.same({ "prestige", 5 }, { ns.TitleKind("title:prestige5") })
			assert.are.same({ "zonemaster", LAKE }, { ns.TitleKind("zonemaster:" .. LAKE) })
			assert.are.same({ "legend", LEGEND }, { ns.TitleKind("legend:" .. LEGEND) })
			assert.are.same({ "complete", "ledger" }, { ns.TitleKind("title:complete.ledger") })
			assert.are.same({ "complete", "trophy" }, { ns.TitleKind("title:complete.trophy") })
			assert.are.same({}, { ns.TitleKind("title:nosuchtitle") })
		end)
	end)

	describe("celebrated", function()
		it("keeps a zonemaster title when its zone stops being charted (LED-R76, LED-R54, LED-R92)", function()
			local made = state({ ranks = { [COVE] = 5 } })
			local celebrated = { coins = 0, zones = { [COVE] = 5 }, titles = { ["zonemaster:" .. COVE] = true } }

			assert.are.same(
				{ "title:level1", "zonemaster:" .. COVE },
				ns.TitleKeys(view(made, celebrated, { cove = true }))
			)
		end)

		it("keeps level30 after a rebuild lowers the level, in LED-R75's order (LED-R76, LED-R92, LED-R72)", function()
			local made = state({ xp = LEVEL_23, ranks = { [LAKE] = 5 } })
			local celebrated = {
				coins = 0,
				titles = { ["title:level30"] = true, ["legend:" .. LEGEND] = true, ["title:level1"] = true },
			}

			assert.are.same({
				"title:level1",
				"title:level10",
				"title:level20",
				"title:level30",
				"zonemaster:" .. LAKE,
				"legend:" .. LEGEND,
			}, ns.TitleKeys(view(made, celebrated)))
		end)

		it("are the only titles before the projection is built (LED-R76)", function()
			local celebrated = {
				coins = 0,
				titles = {
					["title:complete.junk"] = true,
					["legend:" .. LEGEND] = true,
					["zonemaster:" .. COVE] = true,
					["zonemaster:" .. LAKE] = true,
					["title:prestige1"] = true,
					["title:level60"] = true,
				},
			}

			assert.are.same({
				"title:level60",
				"title:prestige1",
				"zonemaster:" .. LAKE,
				"zonemaster:" .. COVE,
				"legend:" .. LEGEND,
				"title:complete.junk",
			}, ns.TitleKeys(view(nil, celebrated)))
		end)
	end)

	describe("earned", function()
		it(
			"lists the level titles reached, a Master zone's and a caught Legend's in LED-R75's order (LED-R75, LED-R76)",
			function()
				local made = state({ xp = LEVEL_23, ranks = { [LAKE] = 5 }, items = { LEGEND } })
				assert.are.equal(23, ns.Level(made))

				assert.are.same({
					"title:level1",
					"title:level10",
					"title:level20",
					"zonemaster:" .. LAKE,
					"legend:" .. LEGEND,
				}, ns.TitleKeys(view(made)))
			end
		)

		it(
			"adds every level title and prestige1 at rank 1, the peak level being 60 (LED-R75, LED-R35, LED-R34)",
			function()
				local made = state({ prestige = 1, ranks = { [LAKE] = 5 }, items = { LEGEND } })

				assert.are.same({
					"title:level1",
					"title:level10",
					"title:level20",
					"title:level30",
					"title:level40",
					"title:level50",
					"title:level60",
					"title:prestige1",
					"zonemaster:" .. LAKE,
					"legend:" .. LEGEND,
				}, ns.TitleKeys(view(made)))
			end
		)

		it("gives ranks 5 and 10 their titles too, and no other rank (LED-R34, LED-R75)", function()
			local function prestigeKeys(rank)
				local found = {}
				for _, key in ipairs(ns.TitleKeys(view(state({ prestige = rank })))) do
					if key:find("^title:prestige") then
						found[#found + 1] = key
					end
				end
				return found
			end

			assert.are.same({ "title:prestige1" }, prestigeKeys(4))
			assert.are.same({ "title:prestige1", "title:prestige5" }, prestigeKeys(9))
			assert.are.same({ "title:prestige1", "title:prestige5", "title:prestige10" }, prestigeKeys(12))
		end)

		it("lists zonemaster titles by zone areaID and Legend titles by item ID (LED-R75)", function()
			local made = state({ ranks = { [COVE] = 5, [LAKE] = 5 }, items = { LEGEND, LEGEND_2 } })

			assert.are.same({
				"title:level1",
				"zonemaster:" .. LAKE,
				"zonemaster:" .. COVE,
				"legend:" .. LEGEND_2,
				"legend:" .. LEGEND,
			}, ns.TitleKeys(view(made)))
		end)

		it("gives a zone its title at a shown rank of Master, a celebrated rank too (LED-R75, LED-R52)", function()
			local made = state({ ranks = { [LAKE] = 4, [COVE] = 4 } })

			assert.are.same(
				{ "title:level1", "zonemaster:" .. COVE },
				ns.TitleKeys(view(made, { coins = 0, zones = { [COVE] = 5 } }))
			)
		end)

		it("gives complete.junk once the Junk Museum's count reaches a total above 0 (LED-R75, LED-R71)", function()
			assert.are.same({ "title:level1" }, ns.TitleKeys(view(state({ species = { FISH_1 } }))))
			assert.are.same({ "title:level1", "title:complete.junk" }, ns.TitleKeys(view(state({ items = { JUNK } }))))
			-- With no junk item in the world, its count is 0 of 0: no title.
			assert.are.same({ "title:level1" }, ns.TitleKeys(view(state({}), nil, { junk = true })))
		end)

		it(
			"gives complete.ledger at completion 100, after the Legends, with each part's title in LED-R75's order (LED-R75, LED-R70)",
			function()
				local everything = {
					species = { FISH_1, FISH_2, FISH_3 },
					items = { JUNK, CHEST, TROPHY, LEGEND },
					ranks = { [LAKE] = 5, [COVE] = 5 },
				}
				assert.are.same({
					"title:level1",
					"zonemaster:" .. LAKE,
					"zonemaster:" .. COVE,
					"legend:" .. LEGEND,
					"title:complete.ledger",
					"title:complete.junk",
					"title:complete.treasure",
					"title:complete.trophy",
				}, ns.TitleKeys(view(state(everything))))

				-- One Species short: 7 of 8 done, 87%.
				everything.species = { FISH_1, FISH_2 }
				local keys = ns.TitleKeys(view(state(everything)))
				assert.are.equal("title:complete.junk", keys[5])
				assert.are.equal(7, #keys)
			end
		)
	end)

	describe("a test log's devGoods (SHOP-R37)", function()
		local everyTitle = {
			"title:level1",
			"title:level10",
			"title:level20",
			"title:level30",
			"title:level40",
			"title:level50",
			"title:level60",
			"title:prestige1",
			"title:prestige5",
			"title:prestige10",
			"zonemaster:" .. LAKE,
			"zonemaster:" .. COVE,
			"legend:" .. LEGEND,
			"title:complete.ledger",
			"title:complete.junk",
			"title:complete.treasure",
			"title:complete.trophy",
			"title:complete.varieties",
		}

		it("makes every title there is earned in a view that asks, with nothing earned yet", function()
			local owning = view(state({}))
			owning.ownsAll = true

			assert.are.same(everyTitle, ns.TitleKeys(owning))
			assert.are.same(everyTitle, ns.TitleCatalogue(owning))
		end)

		it("signs with the highest level title for Automatic, and takes any title as the pick (LED-R77)", function()
			local owning = view(state({}))
			owning.ownsAll = true

			assert.are.equal("title:level60", (ns.ActiveTitle(owning)))
			owning.activeTitle = "title:prestige10"
			assert.are.equal("title:prestige10", (ns.ActiveTitle(owning)))
			local profile = {}
			assert.is_true(ns.StoreActiveTitle(profile, owning, "zonemaster:" .. COVE))
			assert.are.equal("zonemaster:" .. COVE, profile.activeTitle)
		end)

		it(
			"changes nothing in a view that doesn't ask: the state's own titles, as the projection folds them",
			function()
				local made = state({ xp = LEVEL_23 })
				local keys = ns.TitleKeys(view(made))

				assert.is_false(ns.StoreActiveTitle({}, view(made), "title:prestige10"))
				-- what is newly earned (the moments') reads the state alone, ownsAll or not
				local asking = view(made)
				asking.ownsAll = true
				assert.are.same(ns.NewTitles(view(made)), ns.NewTitles(asking))
				assert.is_true(#ns.TitleKeys(asking) > #keys)
			end
		)
	end)
end)
