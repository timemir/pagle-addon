-- The Curio Shop expansion's earned goods (LED-R116, LED-R117, LED-R34, LED-R63, LED-R75, LED-R80, LED-R90,
-- VAR-R22): each rule over a hand-made state, a fixture world and the celebrated set, the goods kept once noted in the
-- set, and LED-R117's four goods as registered, through ns.EarnedGoodOwned, ns.NoteEarnedGoods and ns.CoreSlotGoods.
-- No Core.

-- Lake lists a Species, a trophy and two Legends; a third Legend is on no list, and a fourth is removed. A Species
-- with ten varieties (VAR-R2) is on Lake's list only in the Iridescent Scale's world.
local FISH, TROPHY = 6303, 13901
local LEGEND, LEGEND_2, UNLISTED, REMOVED = 19807, 19803, 19805, 19806
local COLOURED = 6359
local KEYS = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
local LAKE = 12

local getItem = itemLookup({
	[FISH] = fishRecord(FISH),
	[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
	[LEGEND_2] = fishRecord(LEGEND_2, { legend = true }),
	[UNLISTED] = fishRecord(UNLISTED, { legend = true }),
	[REMOVED] = fishRecord(REMOVED, { legend = true, removed = true }),
	[COLOURED] = fishRecord(COLOURED, { varieties = KEYS }),
})

-- Core's lookups (LOG-R55) over Lake, which `legends` lists the Legends of (both listed ones without it), and
-- `coloured` the Species with varieties too.
---@param legends integer[]?
---@param coloured boolean?
local function lookups(legends, coloured)
	local catches = { catchEntry(FISH), catchEntry(TROPHY), catchEntry(REMOVED) }
	for _, itemID in ipairs(legends or { LEGEND, LEGEND_2 }) do
		catches[#catches + 1] = catchEntry(itemID)
	end
	if coloured then
		catches[#catches + 1] = catchEntry(COLOURED)
	end
	return {
		GetItem = getItem,
		GetZones = function()
			return { LAKE }
		end,
		GetArea = function()
			return { hasData = true, catches = catches }
		end,
		GetZoneCatches = function()
			local list = {}
			for i, catch in ipairs(catches) do
				list[i] = { areaID = LAKE, itemID = catch.itemID, confirmed = catch.confirmed }
			end
			return list
		end,
	}
end

-- A first Catch (ledger.md › Data, LedgerFirst), with a record in `band` when given (LED-R80).
---@param band integer?
local function first(band)
	local entry = { n = 1, time = SERVER_TIME - 700, char = 1, zone = LAKE, since = 0 }
	if band then
		entry.record = { length = 300, band = band, catchId = "c", time = SERVER_TIME - 700, char = 1, zone = LAKE }
	end
	return entry
end

-- A hand-made state (ledger.md › Data) at prestige rank `prestige`, holding `items` and the Species FISH when
-- `fishBand` is given, its record in that band.
---@param fields { prestige: integer?, items: integer[]?, fishBand: integer?, legendBand: integer? }
---@return LedgerState
local function state(fields)
	local made = {
		casts = 0,
		catches = 0,
		xp = 0,
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
	for _, itemID in ipairs(fields.items or {}) do
		made.items[itemID] = first(itemID == LEGEND and fields.legendBand or nil)
	end
	if fields.fishBand then
		made.species[FISH] = first(fields.fishBand)
	end
	return made
end

describe("the expansion's earned goods", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	-- What the rules read: the fixture world (Lake's Legends `legends`, and the Species with varieties when
	-- `coloured`), `made`, `celebrated` and Core's five Size bands (LOG-R67).
	---@param made LedgerState?
	---@param celebrated table? a LedgerCelebrated, as hand-made as the state
	---@param legends integer[]?
	---@param coloured boolean?
	---@return LedgerEarnedView
	local function view(made, celebrated, legends, coloured)
		return {
			world = ns.NewWorld(lookups(legends, coloured)),
			state = made,
			celebrated = celebrated or {},
			sizeBands = 5,
		}
	end

	-- Whether `goodID`, by `rule`, is owned over `v`.
	local function owned(goodID, rule, v)
		return ns.EarnedGoodOwned(goodID, rule, v)
	end

	it("are the five earned bindings and LED-R117's four, each by its rule (LED-R116, LED-R117)", function()
		local rules = {}
		for _, good in ipairs(ns.EarnedGoods()) do
			rules[#rules + 1] = { good.id, good.earn }
		end

		assert.are.same({
			{ "ledger.binding.legend", "legends" },
			{ "ledger.binding.monster", "monster" },
			{ "ledger.binding.abyssal", "prestige10" },
			{ "ledger.binding.keeper", "ledger" },
			{ "ledger.binding.iridescent", "varieties" },
			{ "ledger.toaststyle.legend", "legend" },
			{ "ledger.toaststyle.prestige", "prestige5" },
			{ "ledger.soundset.concertina", "prestige1" },
			{ "ledger.soundset.choir", "legends" },
		}, rules)
	end)

	describe("Three Gilt Fish and Choir of the Deep", function()
		it(
			"are earned with every listed Legend item caught, the unlisted and removed ones aside (LED-R116, LED-R117, LED-R63)",
			function()
				assert.is_false(owned("ledger.binding.legend", "legends", view(state({ items = { LEGEND } }))))
				assert.is_true(owned("ledger.binding.legend", "legends", view(state({ items = { LEGEND, LEGEND_2 } }))))
				assert.is_true(owned("ledger.soundset.choir", "legends", view(state({ items = { LEGEND, LEGEND_2 } }))))
				-- a caught unlisted Legend joins the Legends to catch (LED-R11)
				assert.is_false(
					owned("ledger.binding.legend", "legends", view(state({ items = { LEGEND, UNLISTED } })))
				)
			end
		)

		it(
			"count a Legend item in the celebrated set as caught, as after a rebuild that lost it (LED-R116, LED-R90)",
			function()
				local celebrated = { items = { [LEGEND_2] = true } }

				assert.is_true(
					owned("ledger.binding.legend", "legends", view(state({ items = { LEGEND } }), celebrated))
				)
				assert.is_false(owned("ledger.binding.legend", "legends", view(nil, celebrated)))
			end
		)

		it("aren't earned in a world with no Legend (LED-R116)", function()
			assert.is_false(owned("ledger.binding.legend", "legends", view(state({}), nil, {})))
		end)
	end)

	it(
		"earn The Tall Tale with the first Legend caught, in the state or the celebrated set (LED-R117, LED-R63)",
		function()
			assert.is_false(owned("ledger.toaststyle.legend", "legend", view(state({ items = { TROPHY } }))))
			assert.is_true(owned("ledger.toaststyle.legend", "legend", view(state({ items = { UNLISTED } }))))
			assert.is_true(owned("ledger.toaststyle.legend", "legend", view(nil, { items = { [LEGEND] = true } })))
		end
	)

	it("earn Monster Hide with a Species' or Legend's record in the Monster band (LED-R116, LED-R80)", function()
		assert.is_false(owned("ledger.binding.monster", "monster", view(state({ fishBand = 4 }))))
		assert.is_true(owned("ledger.binding.monster", "monster", view(state({ fishBand = 5 }))))
		assert.is_true(owned("ledger.binding.monster", "monster", view(state({ items = { LEGEND }, legendBand = 5 }))))
		assert.is_false(owned("ledger.binding.monster", "monster", view(nil)))
	end)

	it(
		"take the Monster band as the last of the Size bands Core passes in, none without them (LED-R80, CORE-R7)",
		function()
			local fishAt5 = view(state({ fishBand = 5 }))
			fishAt5.sizeBands = 6
			assert.is_false(owned("ledger.binding.monster", "monster", fishAt5))
			fishAt5.sizeBands = nil
			assert.is_false(owned("ledger.binding.monster", "monster", fishAt5))
		end
	)

	it("count Core's Size bands by index, a read-only copy's too (LOG-R67, CORE-R18)", function()
		local bands = { { key = "a" }, { key = "b" }, { key = "c" } }
		local proxy = setmetatable({}, { __index = bands })

		assert.are.same({ 3, 3 }, { ns.SizeBandCount(bands), ns.SizeBandCount(proxy) })
		assert.is_nil(ns.SizeBandCount(nil))
		assert.is_nil(ns.SizeBandCount({}))
	end)

	it(
		"earn Old Salt's Concertina at Prestige I, Oxblood Vellum at V and Abyssal Black at X, by the state or the highest celebrated rank (LED-R116, LED-R117, LED-R34)",
		function()
			local function ranks(made, celebrated)
				local v = view(made, celebrated)
				return {
					owned("ledger.soundset.concertina", "prestige1", v),
					owned("ledger.toaststyle.prestige", "prestige5", v),
					owned("ledger.binding.abyssal", "prestige10", v),
				}
			end

			assert.are.same({ false, false, false }, ranks(state({})))
			assert.are.same({ true, false, false }, ranks(state({ prestige = 1 })))
			assert.are.same({ true, true, false }, ranks(state({ prestige = 9 })))
			assert.are.same({ true, true, true }, ranks(state({ prestige = 10 })))
			assert.are.same({ true, true, true }, ranks(state({ prestige = 2 }), { prestige = 11 }))
			assert.are.same({ true, true, false }, ranks(nil, { prestige = 5 }))
		end
	)

	it("earn Keeper's Gold with the complete.ledger title, earned now or celebrated (LED-R116, LED-R75)", function()
		local made = state({ items = { TROPHY } })
		assert.is_false(owned("ledger.binding.keeper", "ledger", view(made)))

		made.species[FISH] = first()
		made.zones[LAKE] = { species = {}, families = {}, items = {}, junk = false, treasure = false, rank = 5 }
		assert.are.equal(100, ns.LedgerCompletion(ns.NewWorld(lookups()), made).percent)
		assert.is_true(owned("ledger.binding.keeper", "ledger", view(made)))
		assert.is_true(
			owned("ledger.binding.keeper", "ledger", view(nil, { titles = { ["title:complete.ledger"] = true } }))
		)
	end)

	describe("Iridescent Scale", function()
		-- A state holding the Species with varieties, its first `n` varieties caught (ledger.md › Data, VAR-R20).
		---@param n integer
		---@return LedgerState
		local function colours(n)
			local made = state({})
			made.species[COLOURED] = first()
			made.varieties = { [COLOURED] = {} }
			for index = 1, n do
				made.varieties[COLOURED][index] = {
					count = 1,
					first = { entryId = "c" .. index, zone = LAKE, char = 1 },
				}
			end
			return made
		end

		it(
			"is earned with the complete.varieties title: every variety of every Species with varieties caught, or the title celebrated (LED-R116, VAR-R22, LED-R90)",
			function()
				assert.is_false(owned("ledger.binding.iridescent", "varieties", view(colours(9), nil, nil, true)))
				assert.is_true(owned("ledger.binding.iridescent", "varieties", view(colours(10), nil, nil, true)))
				assert.is_true(
					owned(
						"ledger.binding.iridescent",
						"varieties",
						view(nil, { titles = { ["title:complete.varieties"] = true } }, nil, true)
					)
				)
				assert.is_false(owned("ledger.binding.iridescent", "varieties", view(nil, nil, nil, true)))
			end
		)

		it(
			"isn't earned in a world with no Species with varieties, the title's total above 0 (LED-R116, VAR-R22)",
			function()
				assert.is_false(owned("ledger.binding.iridescent", "varieties", view(state({}))))
			end
		)

		it(
			"is kept once noted, through a rebuild that loses a variety and without the title celebrated (LED-R116, LED-R90, SHOP-R31)",
			function()
				local celebrated = {}
				assert.is_true(ns.NoteEarnedGoods(celebrated, view(colours(10), celebrated, nil, true)))
				assert.is_true(celebrated.goods["ledger.binding.iridescent"])

				local rebuilt = view(colours(9), celebrated, nil, true)
				assert.is_false(ns.EarnedRuleHolds("varieties", rebuilt))
				assert.is_true(owned("ledger.binding.iridescent", "varieties", rebuilt))
			end
		)
	end)

	describe("noted in the celebrated set", function()
		it(
			"are added once their rule holds, saying so, and kept when it no longer does (LED-R116, LED-R90, SHOP-R31)",
			function()
				local celebrated = { prestige = 0, items = {} }
				local made = state({ prestige = 1, fishBand = 5 })

				assert.is_true(ns.NoteEarnedGoods(celebrated, view(made, celebrated)))
				assert.are.same({
					["ledger.binding.monster"] = true,
					["ledger.soundset.concertina"] = true,
				}, celebrated.goods)
				assert.is_false(ns.NoteEarnedGoods(celebrated, view(made, celebrated)))

				-- A rebuild in which the Species' Catches turned Uncharted (LED-R64): no record, the binding kept.
				local rebuilt = state({})
				assert.is_false(ns.EarnedRuleHolds("monster", view(rebuilt, celebrated)))
				assert.is_true(owned("ledger.binding.monster", "monster", view(rebuilt, celebrated)))
				assert.is_true(owned("ledger.soundset.concertina", "prestige1", view(nil, celebrated)))
			end
		)

		it("keep Three Gilt Fish when a release lists another Legend (LED-R116, LED-R92)", function()
			local celebrated = {}
			local made = state({ items = { LEGEND, LEGEND_2 } })
			ns.NoteEarnedGoods(celebrated, view(made, celebrated))

			local grown = view(made, celebrated, { LEGEND, LEGEND_2, UNLISTED })
			assert.is_false(ns.EarnedRuleHolds("legends", grown))
			assert.is_true(owned("ledger.binding.legend", "legends", grown))
		end)
	end)

	it(
		"register LED-R117's four in Core's open slots, named and described by lore, earned by their rules, with no preview (LED-R117, LED-R160, SHOP-R23)",
		function()
			local asked = {}
			local goods = ns.CoreSlotGoods(function(goodID, rule)
				asked[#asked + 1] = goodID .. " " .. rule
				return rule == "prestige1"
			end)

			local rows = {}
			for i, good in ipairs(goods) do
				rows[i] = { good.id, good.slot, good.name, good.earnedText, good.isEarned(), good.preview }
				assert.are.equal(ns.L["ledgergood." .. good.id .. ".description"], good.description)
				assert.matches("^Interface\\Icons\\", good.icon)
			end
			assert.are.same({
				{ "ledger.toaststyle.legend", "core.toaststyle", "The Tall Tale", "Land a Legend", false },
				{ "ledger.toaststyle.prestige", "core.toaststyle", "Oxblood Vellum", "Prestige V", false },
				{ "ledger.soundset.concertina", "core.soundset", "Old Salt's Concertina", "Prestige I", true },
				{ "ledger.soundset.choir", "core.soundset", "Choir of the Deep", "Land all three Legends", false },
			}, rows)
			assert.are.same({
				"ledger.toaststyle.legend legend",
				"ledger.toaststyle.prestige prestige5",
				"ledger.soundset.concertina prestige1",
				"ledger.soundset.choir legends",
			}, asked)
		end
	)
end)
