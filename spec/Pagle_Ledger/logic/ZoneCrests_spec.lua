-- The zone crests (LED-R113–R115; wallet-and-shop.md SHOP-R22, SHOP-R23, SHOP-R25) through ns.ZONE_CRESTS,
-- ns.SortedZoneCrests, ns.ZoneCrestEarned, ns.ZoneCrestTexts, ns.ZoneMasterReached and ns.ZoneCrestGoods, with no
-- Core: the fifty earned goods the Ledger registers in Core's crest slot, their order, when each is earned and what
-- the shop says of one not yet earned.

-- A charted zone, Lake: two ungated Species, one gated (night), no junk or treasure requirement, one trophy family.
-- Uncharted is a zone in no world index (LED-R54).
local LAKE, UNCHARTED = 12, 16591
local ANY_1, ANY_2, NIGHT = 6303, 6291, 13759

-- A world index charting Lake alone, in ns.NewWorld's shape (LED-R10).
local function lakeWorld()
	return {
		zones = {
			[LAKE] = {
				species = { [ANY_1] = { gated = false }, [ANY_2] = { gated = false }, [NIGHT] = { gated = true } },
				families = { [1] = true },
				junk = false,
				treasure = false,
			},
		},
	}
end

-- A state with Lake at stored rank `rank` and `species` caught there, or Lake unfished when `rank` is nil.
local function stateWith(rank, species)
	local zones = {}
	if rank then
		local caught = {}
		for _, id in ipairs(species or {}) do
			caught[id] = true
		end
		zones[LAKE] = { species = caught, families = {}, items = {}, junk = false, treasure = false, rank = rank }
	end
	return { zones = zones }
end

describe("the zone crests", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	describe("their table", function()
		it(
			"holds fifty, one per zone, keys and areaIDs each once: 26 in the Eastern Kingdoms, 23 in Kalimdor, 1 elsewhere (LED-R113)",
			function()
				local keys, areas, byContinent = {}, {}, {}
				for _, crest in ipairs(ns.ZONE_CRESTS) do
					assert(not keys[crest.key], crest.key)
					assert(not areas[crest.areaID], crest.key)
					assert(crest.key:match("^%l+$"), crest.key)
					keys[crest.key], areas[crest.areaID] = true, true
					byContinent[crest.continent] = (byContinent[crest.continent] or 0) + 1
					assert.are.equal("ledger.crest." .. crest.key, ns.ZoneCrestID(crest))
				end

				assert.are.equal(50, #ns.ZONE_CRESTS)
				assert.are.same({ [0] = 26, [1] = 23, [2991] = 1 }, byContinent)
				-- The lake, the sea and the mountain's gate have none; their Master earns the title alone (LED-R113).
				assert.are.same(
					{ false, false, false },
					{ areas[170] or false, areas[457] or false, areas[25] or false }
				)
			end
		)

		it("has lore for each, a name and a description (LED-R113, LED-R160)", function()
			local missing = {}
			for _, crest in ipairs(ns.ZONE_CRESTS) do
				for _, field in ipairs({ "name", "description" }) do
					if not ns.Lore(("crest.%s.%s"):format(crest.key, field)) then
						missing[#missing + 1] = crest.key .. " " .. field
					end
				end
			end

			assert.are.same({}, missing)
		end)

		it("ships a texture for each in the Ledger's media, and none besides (LED-R113, SHOP-R25)", function()
			local missing, keys = {}, {}
			for _, crest in ipairs(ns.ZONE_CRESTS) do
				keys[crest.key .. ".blp"] = true
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the client has no io
				local handle = io.open("addons/Pagle_Ledger/media/crests/" .. crest.key .. ".blp", "rb")
				if handle then
					handle:close()
				else
					missing[#missing + 1] = crest.key
				end
			end
			local extra = {}
			for _, file in ipairs(shippedFiles("addons/Pagle_Ledger/media/crests")) do
				local name = file:match("([^/]+)$")
				if not keys[name] then
					extra[#extra + 1] = name
				end
			end

			assert.are.same({}, missing)
			assert.are.same({}, extra)
		end)
	end)

	describe("their order", function()
		it(
			"is by continent, the Eastern Kingdoms, Kalimdor, then any other, each by its zones' names (LED-R113)",
			function()
				-- Names that run against the keys: each zone named by its key backwards.
				local function backwards(areaID)
					for _, crest in ipairs(ns.ZONE_CRESTS) do
						if crest.areaID == areaID then
							return crest.key:reverse()
						end
					end
				end

				local sorted = ns.SortedZoneCrests(backwards)

				assert.are.equal(50, #sorted)
				local last
				for i, crest in ipairs(sorted) do
					local rank = crest.continent == 0 and 1 or crest.continent == 1 and 2 or 3
					if last then
						assert(
							last.rank < rank or last.rank == rank and last.name < crest.key:reverse(),
							"out of order at " .. i .. ": " .. crest.key
						)
					end
					last = { rank = rank, name = crest.key:reverse() }
				end
				assert.are.equal("zephras", sorted[50].key)
				assert.are.same({ "alterac", "azshara" }, { sorted[1].key, sorted[27].key }) -- "caretla", "arahsza"
			end
		)

		it(
			"puts a zone the client has no name for after its continent's named ones, by key, and leaves the table as it is (LED-R113, LED-R126)",
			function()
				local before = ns.ZONE_CRESTS[1].key

				local sorted = ns.SortedZoneCrests(function(areaID)
					return areaID ~= 36 and areaID ~= 45 and "Same" or nil -- Alterac's and Arathi's areaIDs: no name
				end)

				assert.are.same({ "alterac", "arathi" }, { sorted[25].key, sorted[26].key })
				assert.are.equal("badlands", sorted[1].key) -- the rest of one name, by key
				assert.are.equal(before, ns.ZONE_CRESTS[1].key)
			end
		)
	end)

	describe("a crest's isEarned", function()
		it("is true once its zone's computed rank is Master, and not before (LED-R114, LED-R52)", function()
			assert.is_true(ns.ZoneCrestEarned(stateWith(5), {}, LAKE))
			assert.is_false(ns.ZoneCrestEarned(stateWith(4), {}, LAKE))
			assert.is_false(ns.ZoneCrestEarned(stateWith(nil), {}, LAKE))
		end)

		it(
			"is true at a celebrated Master alone, so new data, a rebuild or no state yet never takes it away (LED-R114, LED-R92)",
			function()
				local celebrated = { zones = { [LAKE] = 5 } }

				assert.is_true(ns.ZoneCrestEarned(stateWith(3), celebrated, LAKE))
				assert.is_true(ns.ZoneCrestEarned(nil, celebrated, LAKE))
				assert.is_false(ns.ZoneCrestEarned(stateWith(3), { zones = { [LAKE] = 4 } }, LAKE))
			end
		)

		it(
			"is false for a zone that isn't charted, until it reaches Master; one that stops being charted keeps it (LED-R114, LED-R54)",
			function()
				assert.is_false(ns.ZoneCrestEarned(stateWith(nil), {}, UNCHARTED))
				assert.is_false(ns.ZoneCrestEarned(nil, {}, UNCHARTED))
				assert.is_true(ns.ZoneCrestEarned(stateWith(nil), { zones = { [UNCHARTED] = 5 } }, UNCHARTED))
			end
		)
	end)

	describe("a crest's texts", function()
		it(
			"for a charted zone fished are its rank and completion, and on the stage the next requirement (LED-R115, LED-R134)",
			function()
				-- Regular with one of the two ungated Species (ceil(2 / 2) = 1); Local needs the other; 1 of 4 parts done.
				local row, stage = ns.ZoneCrestTexts(lakeWorld(), stateWith(2, { ANY_1 }), {}, LAKE, "Lake")

				assert.are.equal("Regular · 25%", row)
				assert.are.equal(
					"Earned when Lake reaches Master in the Fish Journal. It is Regular, 25%. Local: 1 more any-time Species.",
					stage
				)
			end
		)

		it("follow the shown rank, the celebrated one when higher (LED-R115, LED-R52)", function()
			local row, stage =
				ns.ZoneCrestTexts(lakeWorld(), stateWith(2, { ANY_1 }), { zones = { [LAKE] = 4 } }, LAKE, "Lake")

			assert.are.equal("Expert · 25%", row)
			-- Local's other Species and the night one are new to find (LED-R52).
			assert.are.equal(
				"Earned when Lake reaches Master in the Fish Journal. It is Expert, 25%. Master: a trophy from 1 more"
					.. " family · 2 new to find: the data grew, and your seal stays.",
				stage
			)
		end)

		it("for a charted zone not fished say so, and how to begin (LED-R115)", function()
			assert.are.same({
				"Unfished",
				"Earned when Lake reaches Master in the Fish Journal. Catch anything there to begin.",
			}, { ns.ZoneCrestTexts(lakeWorld(), stateWith(nil), {}, LAKE, "Lake") })
			assert.are.equal("Unfished", (ns.ZoneCrestTexts(lakeWorld(), nil, {}, LAKE, "Lake")))
		end)

		it("for a zone not charted say it isn't yet (LED-R115, LED-R54)", function()
			assert.are.same({
				"Not yet charted",
				"Earned when Riverglades reaches Master in the Fish Journal, once its waters are charted.",
			}, { ns.ZoneCrestTexts(lakeWorld(), stateWith(nil), {}, UNCHARTED, "Riverglades") })
		end)
	end)

	describe("the moment to refresh", function()
		it("is a live entry's zoneRank that reaches Master (LED-R114, SHOP-R31)", function()
			assert.is_true(ns.ZoneMasterReached({ { kind = "zoneRank", zone = LAKE, ranks = { 4, 5 } } }))
			assert.is_false(ns.ZoneMasterReached({ { kind = "zoneRank", zone = LAKE, ranks = { 3, 4 } } }))
			assert.is_false(ns.ZoneMasterReached({ { kind = "levelUp", level = 5 } }))
			assert.is_false(ns.ZoneMasterReached({}))
		end)
	end)

	describe("the goods", function()
		-- The goods over `sources` (state, updating, celebrated), Lake's crest's areaID moved to the fixture's Lake, every
		-- zone named "Zone <areaID>".
		local function goodsOver(sources)
			return ns.ZoneCrestGoods({
				state = function()
					return sources.state
				end,
				updating = function()
					return sources.updating == true
				end,
				celebrated = function()
					return sources.celebrated or {}
				end,
				world = lakeWorld,
				areaName = function(areaID)
					return "Zone " .. areaID
				end,
			})
		end

		-- The good for zone `areaID` among `goods`.
		local function goodOf(goods, areaID)
			for _, good in ipairs(goods) do
				for _, crest in ipairs(ns.ZONE_CRESTS) do
					if crest.areaID == areaID and good.id == ns.ZoneCrestID(crest) then
						return good
					end
				end
			end
			error("no good for " .. areaID)
		end

		it(
			"are fifty earned goods in Core's crest slot, in the zone group, named from lore, each with the Ledger's texture (LED-R113, SHOP-R23)",
			function()
				local goods = goodsOver({ state = stateWith(nil) })
				local elwynn = goodOf(goods, 12)

				assert.are.equal(50, #goods)
				assert.are.same({
					id = "ledger.crest.elwynn",
					slot = "core.crest",
					group = "zone",
					name = ns.L["crest.elwynn.name"],
					description = ns.L["crest.elwynn.description"],
					icon = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn",
					isEarned = elwynn.isEarned,
					earnedText = elwynn.earnedText,
				}, elwynn)
				for _, good in ipairs(goods) do
					assert.are.same({ "function", "function", "nil", "nil", "nil" }, {
						type(good.isEarned),
						type(good.earnedText),
						type(good.default),
						type(good.tier),
						type(good.preview), -- Core's slot draws the bookplate (SHOP-R25)
					})
				end
			end
		)

		it("register in LED-R113's order, by continent then the zones' names", function()
			local goods = goodsOver({ state = stateWith(nil) })
			local sorted = ns.SortedZoneCrests(function(areaID)
				return "Zone " .. areaID
			end)

			for i, crest in ipairs(sorted) do
				assert.are.equal(ns.ZoneCrestID(crest), goods[i].id)
			end
		end)

		it("are earned from the state and celebrated set as they stand when Core asks (LED-R114, SHOP-R31)", function()
			local sources = { state = stateWith(4) }
			local lake = goodOf(goodsOver(sources), LAKE)
			assert.is_false(lake.isEarned())

			sources.state = stateWith(5)
			assert.is_true(lake.isEarned())
			sources.state, sources.celebrated = stateWith(1), { zones = { [LAKE] = 5 } }
			assert.is_true(lake.isEarned())
		end)

		it(
			"give their texts from the last finished state, and while the projection updates the texts they gave last (LED-R115)",
			function()
				local sources = { state = stateWith(nil), updating = true }
				local lake = goodOf(goodsOver(sources), LAKE)
				assert.are.same({}, { lake.earnedText() }) -- updating, and nothing given yet

				sources.updating = false
				assert.are.equal("Unfished", (lake.earnedText()))
				sources.state, sources.updating = stateWith(2, { ANY_1 }), true
				assert.are.same({
					"Unfished",
					"Earned when Zone 12 reaches Master in the Fish Journal. Catch anything there to begin.",
				}, { lake.earnedText() })
				sources.updating = false
				assert.are.equal("Regular · 25%", (lake.earnedText()))
				assert.are.equal("Not yet charted", (goodOf(goodsOver(sources), UNCHARTED).earnedText()))
			end
		)

		it("name a zone the client doesn't know as … (LED-R126)", function()
			local goods = ns.ZoneCrestGoods({
				state = function()
					return stateWith(nil)
				end,
				updating = function()
					return false
				end,
				celebrated = function()
					return {}
				end,
				world = lakeWorld,
				areaName = function() end,
			})

			local _, stage = goodOf(goods, LAKE).earnedText()

			assert.are.equal(
				"Earned when ... reaches Master in the Fish Journal. Catch anything there to begin.",
				stage
			)
		end)
	end)
end)
