-- The Collection's model (LED-R166–R172, LED-R175, LED-R132) through ns.BuildCollection and its reads, over a hand-made
-- Core (slots, goods, ownership, what is worn, progress, what is put away) and a hand-made world, state and Lore.lua for
-- the titles. ledger.md › The Collection, Titles, Data. No Core, no frame.

local LAKE = 12
local FISH_1, FISH_2, LEGEND = 6303, 6291, 19807
local DAY = 24 * 3600

local getItem = itemLookup({
	[FISH_1] = fishRecord(FISH_1),
	[FISH_2] = fishRecord(FISH_2),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
})

-- Lake lists two Species and a Legend; the world and its charted zone (LED-R10).
local function world(ns)
	return ns.NewWorld({
		GetItem = getItem,
		GetZones = function()
			return { LAKE }
		end,
		GetArea = function()
			return { hasData = true, catches = { catchEntry(FISH_1), catchEntry(FISH_2), catchEntry(LEGEND) } }
		end,
		GetZoneCatches = function()
			return {
				{ areaID = LAKE, itemID = FISH_1, confirmed = true },
				{ areaID = LAKE, itemID = FISH_2, confirmed = true },
				{ areaID = LAKE, itemID = LEGEND, confirmed = true },
			}
		end,
	})
end

-- A hand-made state (ledger.md › Data) at `xp` XP, holding Lake at `rank`.
local function stateOf(fields)
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
	if fields.rank then
		made.zones[LAKE] =
			{ species = {}, families = {}, items = {}, junk = false, treasure = false, rank = fields.rank }
	end
	return made
end

describe("the Collection", function()
	local loaded = loadAddon(
		"Pagle_Ledger",
		FOREVER_GLOBALS,
		{ replace = { ["data/Lore.lua"] = "spec/Pagle_Ledger/fixtures/TitlesLore.lua" } }
	)
	local ns = loaded.ns
	-- Only what the lore lookup, the Legend's name and the dates read.
	---@type table
	local client = {
		AreaName = function(areaID)
			return areaID == LAKE and "Loch Modan" or nil
		end,
		ItemName = function(itemID)
			return itemID == LEGEND and "Keefer's Prize" or nil
		end,
		RequestItem = function() end,
		Characters = function()
			return { { name = "Ada" } }
		end,
		ServerTime = function()
			return SERVER_TIME
		end,
		RealmMinute = function()
			return 0
		end,
	}
	local text = ns.NewJournalText(client --[[@as LedgerTextClient]])

	-- The slots Core hands over (SHOP-R36): toast styles, crests (with groups), a Stats tracker frame slot and a Hunts one.
	local SLOTS = {
		{ id = "core.toaststyle", label = "Toast style", category = "Announcements", module = "Core" },
		{
			id = "core.crest",
			label = "Crests",
			category = "Crests",
			module = "Core",
			groups = { { key = "zone", name = "Zone crests" }, { key = "fish", name = "Fish crests" } },
		},
		{ id = "hunts.trackerframe", label = "Hunts tracker frame", category = "Trackers", module = "Hunts" },
		{ id = "stats.trackerframe", label = "Stats tracker frame", category = "Trackers", module = "Stats" },
	}

	-- A good as Pagle.GetGood hands it over; `fields` over its defaults.
	local function good(id, slot, name, fields)
		local info = {
			id = id,
			name = name,
			slot = slot,
			category = slot:find("trackerframe", 1, true) and "Trackers" or "Announcements",
			module = "Core",
			isDefault = false,
			kind = "sale",
			purchased = false,
			fromCrate = false,
			owned = false,
		}
		for key, value in pairs(fields or {}) do
			info[key] = value
		end
		return info
	end

	-- A Core over `goods` (in registration order, each with `owned`), `equipped` ({ slot = id }), `progress`
	-- ({ id = PagleEarnedProgress }) and `away` (IDs of goods of Modules that are off).
	---@param options { goods: table[]?, slots: table[]?, equipped: table?, progress: table?, away: table[]?, balance: integer? }
	local function core(options)
		local byID, away = {}, {}
		for _, info in ipairs(options.goods or {}) do
			byID[info.id] = info
		end
		for _, info in ipairs(options.away or {}) do
			byID[info.id] = info
			away[#away + 1] = info.id
		end
		local equipped = options.equipped or {}
		return {
			slots = function()
				return options.slots or SLOTS
			end,
			slotGoods = function(slot)
				local ids = {}
				for _, info in ipairs(options.goods or {}) do
					if info.slot == slot then
						ids[#ids + 1] = info.id
					end
				end
				return ids
			end,
			getGood = function(id)
				return byID[id]
			end,
			isOwned = function(id)
				return byID[id] ~= nil and (byID[id].owned or byID[id].isDefault)
			end,
			getEquipped = function(slot)
				return equipped[slot]
			end,
			earnedProgress = function(id)
				return (options.progress or {})[id]
			end,
			putAway = function()
				return away
			end,
			balance = function()
				return options.balance or 0
			end,
		}
	end

	-- A spread context over `goods`, the Angler at level `level` and the given titles' state.
	---@param options table core()'s options with `state`, `collection`, `activeTitle`, `celebrated`
	local function contextOf(options)
		local made = options.state or stateOf({})
		return {
			goods = core(options),
			collection = options.collection or { seen = {}, looked = {} },
			world = world(ns),
			state = made,
			celebrated = options.celebrated or { coins = 0 },
			getItem = getItem,
			activeTitle = options.activeTitle,
			text = text,
			formatNumber = breakUpLargeNumbers,
			now = SERVER_TIME,
		}
	end

	-- A default toast style, one owned and in use, one for sale, one earned (with a count), and one the crate alone gives.
	local function toasts(extra)
		local goods = {
			good("core.toaststyle.plain", "core.toaststyle", "Torn Page", { isDefault = true, kind = "default" }),
			good(
				"core.toaststyle.ripple",
				"core.toaststyle",
				"Ripple",
				{ owned = true, purchased = true, ownedAt = SERVER_TIME - 3 * DAY, price = 250, tier = 1 }
			),
			good("core.toaststyle.ship", "core.toaststyle", "Ship's Log", { price = 250, tier = 1 }),
			good("ledger.toaststyle.koi", "core.toaststyle", "Plains Totem", { kind = "earned", module = "Ledger" }),
			good("core.toaststyle.foil", "core.toaststyle", "Prize Foil", { kind = "crate" }),
		}
		for _, more in ipairs(extra or {}) do
			goods[#goods + 1] = more
		end
		return goods
	end

	describe("the shelves (LED-R167)", function()
		it(
			"are one per slot in GetSlots' order with the label in the plural, the Tracker frames slots sharing one, and Titles last",
			function()
				local shelves = ns.CollectionShelves(SLOTS)

				local seen = {}
				for i, shelf in ipairs(shelves) do
					seen[i] = { shelf.key, shelf.label, shelf.singular, #shelf.slots }
				end
				assert.are.same({
					{ "core.toaststyle", "Toast styles", "Toast style", 1 },
					{ "core.crest", "Bookplate crests", "Bookplate crest", 1 },
					{ "trackers", "Tracker frames", "Tracker frame", 2 },
					{ "titles", "Titles", "Title", 0 },
				}, seen)
			end
		)

		it("name Core's four slots in the plural the spec gives and any other slot by its label and an s", function()
			local shelves = ns.CollectionShelves({
				{ id = "core.soundset", label = "Sound set", category = "Announcements", module = "Core" },
				{ id = "core.binding", label = "Book binding", category = "Books", module = "Core" },
				{ id = "later.charm", label = "Charm", category = "Books", module = "Later" },
				{ id = "later.sparks", label = "Sparks", category = "Books", module = "Later" },
			})

			assert.are.same(
				{ "Sound sets", "Bindings", "Charms", "Sparks", "Titles" },
				{ shelves[1].label, shelves[2].label, shelves[3].label, shelves[4].label, shelves[5].label }
			)
		end)

		it("put the Tracker frames shelf where its first slot stands, and none without a tracker slot", function()
			local without = ns.CollectionShelves({ SLOTS[1], SLOTS[2] })
			local between = ns.CollectionShelves({ SLOTS[1], SLOTS[3], SLOTS[2] })

			assert.are.same({ "core.toaststyle", "core.crest", "titles" }, {
				without[1].key,
				without[2].key,
				without[3].key,
			})
			assert.are.same({ "core.toaststyle", "trackers", "core.crest", "titles" }, {
				between[1].key,
				between[2].key,
				between[3].key,
				between[4].key,
			})
		end)

		it("are drawn by layout: toast styles and tracker frames as looks, the others by their slot", function()
			local shelves = ns.CollectionShelves({
				SLOTS[1],
				{ id = "core.soundset", label = "Sound set", category = "Announcements", module = "Core" },
				{ id = "core.binding", label = "Book binding", category = "Books", module = "Core" },
				SLOTS[2],
				SLOTS[3],
			})

			local layouts = {}
			for i, shelf in ipairs(shelves) do
				layouts[i] = ns.CollectionLayout(shelf)
			end
			assert.are.same({ "look", "speaker", "book", "shield", "look", "pick" }, layouts)
		end)
	end)

	describe("a look's state (LED-R167, LED-R170, LED-R172)", function()
		local function stateOfLook(model, id)
			return model.byID[id].state
		end

		it(
			"is in use for the equipped one, owned for any other the Angler has, the default counting as owned",
			function()
				local model = ns.BuildCollection(contextOf({
					goods = toasts(),
					equipped = { ["core.toaststyle"] = "core.toaststyle.ripple" },
				}))

				assert.are.same({ "owned", "inUse" }, {
					stateOfLook(model, "core.toaststyle.plain"),
					stateOfLook(model, "core.toaststyle.ripple"),
				})
				assert.is_true(model.byID["core.toaststyle.plain"].owned)
				assert.is_true(model.byID["core.toaststyle.plain"].default)
			end
		)

		it(
			"is to earn for an earned good not owned, with how far it is, and in the shop for one the shop sells",
			function()
				local progress = { tag = "62 of 100 fish", note = "Catch 100 fish as an Orc", have = 62, need = 100 }
				local model = ns.BuildCollection(contextOf({
					goods = toasts(),
					progress = { ["ledger.toaststyle.koi"] = progress },
				}))

				assert.are.same({ "earn", "shop" }, {
					stateOfLook(model, "ledger.toaststyle.koi"),
					stateOfLook(model, "core.toaststyle.ship"),
				})
				assert.are.same(progress, model.byID["ledger.toaststyle.koi"].progress)
				assert.is_false(model.byID["core.toaststyle.ship"].crateOnly)
			end
		)

		it("is in the shop, crate only, for a good a Curio crate alone gives", function()
			local model = ns.BuildCollection(contextOf({ goods = toasts() }))

			local foil = model.byID["core.toaststyle.foil"]

			assert.are.same({ "shop", true, false }, { foil.state, foil.crateOnly, foil.owned })
		end)

		it("is put away for every good of a Module that is off, owned or not, and never in use (LED-R172)", function()
			local model = ns.BuildCollection(contextOf({
				goods = toasts(),
				away = {
					good("hunts.toaststyle.glow", "core.toaststyle", "Hunt Glow", { module = "Hunts", owned = true }),
					good(
						"hunts.toaststyle.ember",
						"core.toaststyle",
						"Hunt Ember",
						{ module = "Hunts", kind = "earned" }
					),
				},
				equipped = { ["core.toaststyle"] = "hunts.toaststyle.glow" },
			}))

			assert.are.same({ "putAway", true, "putAway", false }, {
				model.byID["hunts.toaststyle.glow"].state,
				model.byID["hunts.toaststyle.glow"].owned,
				model.byID["hunts.toaststyle.ember"].state,
				model.byID["hunts.toaststyle.ember"].owned,
			})
		end)
	end)

	describe("a shelf's groups (LED-R169, LED-R172, SHOP-R27)", function()
		it("put the looks no group names first, then each group in the slot's order under its name", function()
			local crests = {
				good("core.crest.plain", "core.crest", "Plain", { isDefault = true, kind = "default" }),
				good("core.crest.fish.1", "core.crest", "Fish One", { group = "fish", kind = "earned" }),
				good(
					"ledger.crest.elwynn",
					"core.crest",
					"The Old Oak",
					{ group = "zone", kind = "earned", owned = true }
				),
				good("ledger.crest.westfall", "core.crest", "The Sheaf", { group = "zone", kind = "earned" }),
			}
			local model = ns.BuildCollection(contextOf({ goods = crests }))

			local groups = {}
			for i, group in ipairs(model.byKey["core.crest"].groups) do
				groups[i] = { group.name or false, #group.looks, group.owned }
			end

			assert.are.same({ { false, 1, 1 }, { "Zone crests", 2, 1 }, { "Fish crests", 1, 0 } }, groups)
		end)

		it(
			"group Tracker frames by Module, each its own slot's looks, and keep a group with only put away looks",
			function()
				local goods = {
					good(
						"hunts.trackerframe.plain",
						"hunts.trackerframe",
						"Plain",
						{ module = "Hunts", isDefault = true, kind = "default" }
					),
					good(
						"stats.trackerframe.plain",
						"stats.trackerframe",
						"No Frame",
						{ module = "Stats", isDefault = true, kind = "default" }
					),
					good(
						"stats.trackerframe.map",
						"stats.trackerframe",
						"Map Scrap",
						{ module = "Stats", owned = true, purchased = true }
					),
				}
				local model = ns.BuildCollection(contextOf({
					goods = goods,
					away = {
						good(
							"tackleboard.trackerframe.cork",
							"tackleboard.trackerframe",
							"Corkboard",
							{ module = "TackleBoard", owned = true }
						),
					},
				}))

				local groups = {}
				for i, group in ipairs(model.byKey.trackers.groups) do
					groups[i] = { group.name, #group.looks, group.owned }
				end

				assert.are.same({ { "Hunts", 1, 1 }, { "Stats", 2, 2 }, { "Tackle Board", 1, 1 } }, groups)
				assert.are.equal("putAway", model.byID["tackleboard.trackerframe.cork"].state)
			end
		)

		it(
			"put a put away look on Tracker frames by its slot's category, whatever its slot is called (SHOP-R36, LED-R172)",
			function()
				local model = ns.BuildCollection(contextOf({
					goods = toasts(),
					away = {
						good(
							"stats.frames.map",
							"stats.frames",
							"Map Scrap",
							{ module = "Stats", category = "Trackers", owned = true }
						),
						good(
							"stats.charms.one",
							"stats.charms",
							"A Charm",
							{ module = "Stats", category = "Books", owned = true }
						),
					},
				}))

				assert.are.same({ "trackers", "Tracker frame" }, {
					model.byID["stats.frames.map"].shelf,
					model.byID["stats.frames.map"].slotName,
				})
				assert.is_nil(model.byID["stats.charms.one"])
			end
		)

		it("make the Tracker frames shelf for put away looks when every tracker Module is off", function()
			local slots = { SLOTS[1] }
			local model = ns.BuildCollection(contextOf({
				slots = slots,
				goods = toasts(),
				away = {
					good(
						"stats.trackerframe.map",
						"stats.trackerframe",
						"Map Scrap",
						{ module = "Stats", owned = true }
					),
				},
			}))

			assert.are.same({ "core.toaststyle", "trackers", "titles" }, {
				model.shelves[1].key,
				model.shelves[2].key,
				model.shelves[3].key,
			})
			assert.are.same({ 1, 1 }, { model.byKey.trackers.owned, #model.byKey.trackers.looks })
		end)

		it('list put away looks of a slot shelf last, under "Put away: {Module} is off" for each Module', function()
			local model = ns.BuildCollection(contextOf({
				goods = toasts(),
				away = {
					good("hunts.toaststyle.glow", "core.toaststyle", "Hunt Glow", { module = "Hunts", owned = true }),
					good("stats.toaststyle.bar", "core.toaststyle", "Stat Bar", { module = "Stats" }),
				},
			}))

			local names = {}
			for i, group in ipairs(model.byKey["core.toaststyle"].groups) do
				names[i] = group.name or false
			end

			assert.are.same({ false, "Put away: Hunts is off", "Put away: Stats is off" }, names)
		end)
	end)

	describe("the counts (LED-R168, LED-R169, LED-R172)", function()
		it(
			"are {owned} of {total} per shelf and overall, a default and a put away look owned counting, titles too",
			function()
				local model = ns.BuildCollection(contextOf({
					goods = toasts(),
					away = {
						good(
							"hunts.toaststyle.glow",
							"core.toaststyle",
							"Hunt Glow",
							{ module = "Hunts", owned = true }
						),
					},
					state = stateOf({ xp = 0 }),
				}))

				local toast, titles = model.byKey["core.toaststyle"], model.byKey.titles
				assert.are.same({ 3, 6 }, { toast.owned, #toast.looks })
				-- Automatic and Minnow, level 1's, are earned from the start (LED-R75); Dabbler to the whole Ledger are not
				assert.are.same({ 2, true }, { titles.owned, #titles.looks > 2 })
				assert.are.same(
					{ toast.owned + titles.owned, #toast.looks + #titles.looks },
					{ model.owned, model.total }
				)
			end
		)
	end)

	describe("the filters (LED-R169)", function()
		local function looks()
			return ns.BuildCollection(contextOf({ goods = toasts() })).byKey["core.toaststyle"].looks
		end

		it("keep Yours the owned, To earn those to earn, In the shop those in the shop, All every one", function()
			local all = looks()

			local function names(tab)
				local list = {}
				for i, look in ipairs(ns.CollectionFilter(all, tab)) do
					list[i] = look.name
				end
				return list
			end
			assert.are.same({ "Torn Page", "Ripple", "Ship's Log", "Plains Totem", "Prize Foil" }, names("all"))
			assert.are.same({ "Torn Page", "Ripple" }, names("yours"))
			assert.are.same({ "Plains Totem" }, names("earn"))
			assert.are.same({ "Ship's Log", "Prize Foil" }, names("shop"))
			assert.are.same({ "Torn Page", "Ripple", "Ship's Log", "Plains Totem", "Prize Foil" }, names("nonsense"))
		end)

		it(
			"count Yours with the put away owned ones, and leave a tab with nothing in it out unless it is on",
			function()
				local model = ns.BuildCollection(contextOf({
					goods = {
						good(
							"core.toaststyle.plain",
							"core.toaststyle",
							"Torn Page",
							{ isDefault = true, kind = "default" }
						),
					},
					away = {
						good(
							"hunts.toaststyle.glow",
							"core.toaststyle",
							"Hunt Glow",
							{ module = "Hunts", owned = true }
						),
					},
				}))
				local shelf = model.byKey["core.toaststyle"]

				local function tabs(on)
					local list = {}
					for i, tab in ipairs(ns.CollectionTabs(shelf.looks, on)) do
						list[i] = { tab.key, tab.count, tab.on }
					end
					return list
				end
				assert.are.same({ { "all", 2, true }, { "yours", 2, false } }, tabs("all"))
				assert.are.same({ { "all", 2, false }, { "yours", 2, false }, { "shop", 0, true } }, tabs("shop"))
			end
		)

		it("read an unknown tab as All", function()
			assert.are.same(
				{ "all", "all", "earn" },
				{ ns.CollectionTabOf(nil), ns.CollectionTabOf("elsewhere"), ns.CollectionTabOf("earn") }
			)
		end)
	end)

	describe("the chosen look (LED-R170)", function()
		it("is the one asked for when it is on the shelf, else the one in use, else the first", function()
			local shelf = ns.BuildCollection(contextOf({
				goods = toasts(),
				equipped = { ["core.toaststyle"] = "core.toaststyle.ripple" },
			})).byKey["core.toaststyle"]
			local plain = ns.BuildCollection(contextOf({ goods = toasts({}) })).byKey["core.toaststyle"]

			assert.are.equal("Ship's Log", ns.CollectionChosen(shelf, "core.toaststyle.ship").name)
			assert.are.equal("Ripple", ns.CollectionChosen(shelf, "elsewhere").name)
			assert.are.equal("Ripple", ns.CollectionChosen(shelf, nil).name)
			assert.are.equal("Torn Page", ns.CollectionChosen(plain, nil).name)
		end)
	end)

	describe("Within reach (LED-R168)", function()
		-- Five earned looks with counts: 62/100, 99/100, 100/100 (full), 0/10 (nothing yet) and 3/4.
		local function counted()
			local goods, progress = {}, {}
			for i, count in ipairs({ { 62, 100 }, { 99, 100 }, { 100, 100 }, { 0, 10 }, { 3, 4 }, { 1, 100 } }) do
				local id = "ledger.toaststyle.c" .. i
				goods[i] = good(id, "core.toaststyle", "Count " .. i, { kind = "earned" })
				progress[id] = { tag = "x", have = count[1], need = count[2] }
			end
			goods[#goods + 1] = good("ledger.toaststyle.plain", "core.toaststyle", "No count", { kind = "earned" })
			return goods, progress
		end

		it("holds the four looks to earn with the highest share, above 0 and below 1, highest first", function()
			local goods, progress = counted()
			local model = ns.BuildCollection(contextOf({ goods = goods, progress = progress }))

			local reach = ns.CollectionReach(model)

			local names = {}
			for i, found in ipairs(reach) do
				names[i] = found.look.name
			end
			assert.are.same({ "Count 2", "Count 5", "Count 1", "Count 6" }, names)
			assert.are.equal(0.99, reach[1].share)
		end)

		it("never holds a look with no count, whose earned text shows on its shelf only, nor an owned one", function()
			local goods, progress = counted()
			goods[1].owned = true
			progress["ledger.toaststyle.plain"] = { tag = "Land a Legend", note = "Land a Legend" }
			local model = ns.BuildCollection(contextOf({ goods = goods, progress = progress }))

			local names = {}
			for _, found in ipairs(ns.CollectionReach(model)) do
				names[#names + 1] = found.look.name
			end

			assert.are.same({ "Count 2", "Count 5", "Count 6" }, names)
		end)

		it("breaks a tie by the Collection's order", function()
			local goods = {
				good("a.one", "core.toaststyle", "First", { kind = "earned" }),
				good("a.two", "core.toaststyle", "Second", { kind = "earned" }),
			}
			local model = ns.BuildCollection(contextOf({
				goods = goods,
				progress = { ["a.one"] = { have = 1, need = 2 }, ["a.two"] = { have = 5, need = 10 } },
			}))

			local reach = ns.CollectionReach(model)

			assert.are.same({ "First", "Second" }, { reach[1].look.name, reach[2].look.name })
		end)
	end)

	describe("Lately added (LED-R168, LED-R171)", function()
		-- Owned looks: Ripple bought at -3 days, two earned ones first seen -1 day and -5 days, and a crate's good at -2.
		local function owned()
			return {
				good("core.toaststyle.plain", "core.toaststyle", "Torn Page", { isDefault = true, kind = "default" }),
				good(
					"core.toaststyle.ripple",
					"core.toaststyle",
					"Ripple",
					{ owned = true, purchased = true, ownedAt = SERVER_TIME - 3 * DAY }
				),
				good("ledger.toaststyle.a", "core.toaststyle", "Earned A", { kind = "earned", owned = true }),
				good("ledger.toaststyle.b", "core.toaststyle", "Earned B", { kind = "earned", owned = true }),
				good(
					"core.toaststyle.foil",
					"core.toaststyle",
					"Prize Foil",
					{ kind = "crate", owned = true, fromCrate = true, ownedAt = SERVER_TIME - 2 * DAY }
				),
				good("core.toaststyle.unseen", "core.toaststyle", "Unseen", { kind = "earned", owned = true }),
			}
		end

		it(
			"holds the four looks owned most recently, newest first, by the purchase or crate's time else by when first seen",
			function()
				local collection = {
					seen = {
						["ledger.toaststyle.a"] = SERVER_TIME - 1 * DAY,
						["ledger.toaststyle.b"] = SERVER_TIME - 5 * DAY,
						["core.toaststyle.ripple"] = SERVER_TIME, -- a purchase is dated by its entry, never by when it was seen
					},
					looked = {},
				}
				local model = ns.BuildCollection(contextOf({ goods = owned(), collection = collection }))

				local lately = ns.CollectionLately(model, collection)

				local names = {}
				for i, found in ipairs(lately) do
					names[i] = { found.look.name, found.time }
				end
				assert.are.same({
					{ "Earned A", SERVER_TIME - 1 * DAY },
					{ "Prize Foil", SERVER_TIME - 2 * DAY },
					{ "Ripple", SERVER_TIME - 3 * DAY },
					{ "Earned B", SERVER_TIME - 5 * DAY },
				}, names)
			end
		)

		it("leaves out a default, a title and a look not yet seen, and never lists more than four", function()
			local goods = owned()
			for i = 1, 4 do
				goods[#goods + 1] =
					good("ledger.toaststyle.m" .. i, "core.toaststyle", "More " .. i, { kind = "earned", owned = true })
			end
			local collection = { seen = {}, looked = {} }
			for i = 1, 4 do
				collection.seen["ledger.toaststyle.m" .. i] = SERVER_TIME - i
			end
			collection.seen["core.toaststyle.plain"] = SERVER_TIME
			collection.seen.automatic = SERVER_TIME
			local model = ns.BuildCollection(contextOf({ goods = goods, collection = collection }))

			local lately = ns.CollectionLately(model, collection)

			assert.are.equal(4, #lately)
			for _, found in ipairs(lately) do
				assert.is_false(found.look.default or found.look.title or false)
			end
		end)

		it("says how each came: a purchase, a Curio crate, or earned (LED-R170)", function()
			local model = ns.BuildCollection(contextOf({ goods = owned() }))

			assert.are.same({ "default", "bought", "earned", "crate" }, {
				ns.CollectionSource(model.byID["core.toaststyle.plain"]),
				ns.CollectionSource(model.byID["core.toaststyle.ripple"]),
				ns.CollectionSource(model.byID["ledger.toaststyle.a"]),
				ns.CollectionSource(model.byID["core.toaststyle.foil"]),
			})
		end)
	end)

	describe("new and looked (LED-R171)", function()
		it(
			"start nothing new on a first opening: every look and title owned is noted, as seen and looked at once",
			function()
				local global = {}

				local collection =
					ns.NoteCollectionSeen(global, { "core.toaststyle.plain", "title:level1" }, SERVER_TIME)

				assert.are.equal(collection, global.collection)
				assert.are.same({
					seen = { ["core.toaststyle.plain"] = SERVER_TIME, ["title:level1"] = SERVER_TIME },
					looked = { ["core.toaststyle.plain"] = true, ["title:level1"] = true },
				}, collection)
			end
		)

		it("note only what it hasn't seen once there is a collection, with the time now and not looked at", function()
			local global = { collection = { seen = { old = SERVER_TIME - DAY }, looked = { old = true } } }

			ns.NoteCollectionSeen(global, { "old", "fresh" }, SERVER_TIME)

			assert.are.same({
				seen = { old = SERVER_TIME - DAY, fresh = SERVER_TIME },
				looked = { old = true },
			}, global.collection)
		end)

		it(
			"make a look new while it is owned, seen and not looked at, and count it on its shelf and overall",
			function()
				local collection = {
					seen = { ["core.toaststyle.ripple"] = SERVER_TIME, ["core.toaststyle.plain"] = SERVER_TIME },
					looked = { ["core.toaststyle.plain"] = true },
				}
				local model = ns.BuildCollection(contextOf({ goods = toasts(), collection = collection }))

				assert.are.same({ true, false, false }, {
					model.byID["core.toaststyle.ripple"].new,
					model.byID["core.toaststyle.plain"].new,
					model.byID["core.toaststyle.ship"].new, -- not owned, never new
				})
				assert.are.same({ 1, 1 }, { model.byKey["core.toaststyle"].new, model.new })
			end
		)

		it("note a shelf's owned looks as looked at, and no other", function()
			local collection = {
				seen = { ["core.toaststyle.ripple"] = SERVER_TIME, ["core.crest.plain"] = SERVER_TIME },
				looked = {},
			}
			local context = contextOf({
				goods = {
					toasts()[2],
					good("core.crest.plain", "core.crest", "Plain", { isDefault = true, kind = "default" }),
				},
				collection = collection,
			})
			local model = ns.BuildCollection(context)

			ns.NoteShelfLooked(collection, model.byKey["core.toaststyle"])

			assert.are.same({ ["core.toaststyle.ripple"] = true }, collection.looked)
		end)

		it("note every look and title owned, put away ones and Automatic included, and never one not owned", function()
			local ids = ns.CollectionOwnedIDs(contextOf({
				goods = toasts(),
				away = {
					good("hunts.toaststyle.glow", "core.toaststyle", "Hunt Glow", { module = "Hunts", owned = true }),
				},
			}))

			table.sort(ids)
			assert.are.same({
				"automatic",
				"core.toaststyle.plain",
				"core.toaststyle.ripple",
				"hunts.toaststyle.glow",
				"title:level1",
			}, ids)
		end)
	end)

	describe("the titles (LED-R75, LED-R77, LED-R161, LED-R167, LED-R169)", function()
		-- Level 23 with Lake mastered, the Legend caught: Minnow to Line-Caster, the Warden and the Legend's are earned.
		local function titled(fields)
			local options = { goods = {}, state = stateOf({ xp = 42240, rank = 5 }) }
			for key, value in pairs(fields or {}) do
				options[key] = value
			end
			options.state.items[LEGEND] = { n = 1, time = SERVER_TIME - 700, char = 1, zone = LAKE }
			return contextOf(options)
		end

		it("list Automatic first, then every title with lore text in LED-R75's order, under the four groups", function()
			local model = ns.BuildCollection(titled())

			local groups = {}
			for i, group in ipairs(model.byKey.titles.groups) do
				local names = {}
				for j, look in ipairs(group.looks) do
					names[j] = look.name
				end
				groups[i] = { group.name, table.concat(names, ", ") }
			end
			assert.are.same({
				{
					"Levels and Prestige",
					"Automatic, Minnow, Dabbler, Line-Caster, Fisher, Old Salt, Ledgerkeeper, Pagle's Peer, Returning Tide",
				},
				{ "Wardens", "Warden of Loch Modan Waters" },
				{ "Legends", "The Tasty One" },
				{ "The whole Ledger", "Angler of Azeroth, Collector of Boots" },
			}, groups)
		end)

		it("are owned when earned, in use for the stored pick or else Automatic, and to earn otherwise", function()
			local stored = ns.BuildCollection(titled({ activeTitle = "zonemaster:" .. LAKE })).byID
			local automatic = ns.BuildCollection(titled()).byID

			assert.are.same({ "inUse", "owned", "owned", "earn" }, {
				stored["zonemaster:" .. LAKE].state,
				stored.automatic.state,
				stored["title:level20"].state,
				stored["title:level30"].state,
			})
			assert.are.same({ "inUse", "owned", "earn" }, {
				automatic.automatic.state,
				automatic["zonemaster:" .. LAKE].state,
				automatic["title:level30"].state,
			})
		end)

		it("read a stored title that isn't earned as Automatic", function()
			local model = ns.BuildCollection(titled({ activeTitle = "title:level60" }))

			assert.are.same({ "inUse", "earn" }, { model.byID.automatic.state, model.byID["title:level60"].state })
		end)

		it("give each its earning line, a Legend uncaught never named", function()
			local byID = ns.BuildCollection(titled()).byID

			assert.are.same({
				"Angler Level 30",
				"Prestige I",
				"Master in Loch Modan",
				"First Catch of Keefer's Prize",
				"Fill the Junk Museum",
				"Complete the Ledger",
				"Your highest level title, whatever it is",
			}, {
				byID["title:level30"].earnLine,
				byID["title:prestige1"].earnLine,
				byID["zonemaster:" .. LAKE].earnLine,
				byID["legend:" .. LEGEND].earnLine,
				byID["title:complete.junk"].earnLine,
				byID["title:complete.ledger"].earnLine,
				byID.automatic.earnLine,
			})
			local uncaught = ns.BuildCollection(contextOf({ goods = {}, state = stateOf({}) })).byID
			assert.are.equal("Land a Legend", uncaught["legend:" .. LEGEND].earnLine)
		end)

		it("count Automatic among the titles, owned and in all", function()
			local shelf = ns.BuildCollection(titled()).byKey.titles

			-- Automatic, Minnow, Dabbler, Line-Caster, the Warden and the Legend's of the thirteen with lore text
			assert.are.same({ 6, 13 }, { shelf.owned, #shelf.looks })
		end)

		it('wear the title signed with, "Signed “{title}”", Automatic\'s being the highest level title', function()
			local model = ns.BuildCollection(titled())
			local stored = ns.BuildCollection(titled({ activeTitle = "zonemaster:" .. LAKE }))

			assert.are.equal("Signed “Line-Caster”", model.byKey.titles.wearing)
			assert.are.equal("Signed “Warden of Loch Modan Waters”", stored.byKey.titles.wearing)
		end)

		it("keep an earned title the world no longer lists, a zone no longer charted (LED-R54, LED-R92)", function()
			local context = titled({ celebrated = { coins = 0, titles = { ["zonemaster:99"] = true } } })

			local catalogue = ns.TitleCatalogue(context)

			local found = false
			for _, key in ipairs(catalogue) do
				found = found or key == "zonemaster:99"
			end
			assert.is_true(found)
		end)
	end)

	describe("what a shelf wears (LED-R168)", function()
		it('is "Wearing {name}", and on Tracker frames the frames\' names joined, one per Module', function()
			local goods = {
				good(
					"hunts.trackerframe.plain",
					"hunts.trackerframe",
					"Plain",
					{ module = "Hunts", isDefault = true, kind = "default" }
				),
				good("hunts.trackerframe.ink", "hunts.trackerframe", "Ink Wash", { module = "Hunts", owned = true }),
				good(
					"stats.trackerframe.plain",
					"stats.trackerframe",
					"No Frame",
					{ module = "Stats", isDefault = true, kind = "default" }
				),
			}
			local model = ns.BuildCollection(contextOf({
				goods = goods,
				equipped = {
					["hunts.trackerframe"] = "hunts.trackerframe.ink",
					["stats.trackerframe"] = "stats.trackerframe.plain",
				},
			}))

			assert.are.equal("Ink Wash · No Frame", model.byKey.trackers.wearing)
			assert.are.equal("Ink Wash", model.byKey.trackers.worn.name)
			local toast = ns.BuildCollection(contextOf({
				goods = toasts(),
				equipped = { ["core.toaststyle"] = "core.toaststyle.ripple" },
			}))
			assert.are.equal("Wearing Ripple", toast.byKey["core.toaststyle"].wearing)
		end)
	end)

	describe("the art (LED-R168–R170)", function()
		it(
			"is Core's preview for a toast style or tracker frame, and the Ledger's own for a binding, crest, sound set or title",
			function()
				local function art(slot)
					local look = { id = "x", slot = slot, info = { icon = "icon" } }
					return ns.CollectionArt(look).kind
				end

				assert.are.same({ "preview", "preview", "book", "shield", "speaker" }, {
					art("core.toaststyle"),
					"preview",
					art("core.binding"),
					art("core.crest"),
					art("core.soundset"),
				})
				assert.are.equal("quill", ns.CollectionArt({ id = "title:level1", title = true }).kind)
			end
		)
	end)

	describe("the shelf of a good (LED-R174)", function()
		it("is its slot's shelf, Tracker frames for any tracker slot, and nothing for a good never cached", function()
			local context = contextOf({
				goods = toasts({
					good("stats.trackerframe.map", "stats.trackerframe", "Map Scrap", { module = "Stats" }),
				}),
			})

			assert.are.same({ "core.toaststyle", "trackers" }, {
				ns.CollectionShelfOf(context.goods, "core.toaststyle.ship"),
				ns.CollectionShelfOf(context.goods, "stats.trackerframe.map"),
			})
			assert.is_nil(ns.CollectionShelfOf(context.goods, "nope.nothing"))
		end)
	end)

	describe("search (LED-R175)", function()
		-- Ripple, Ship's Log and a title: "ip" is in two looks and no title.
		local context = function()
			return contextOf({ goods = toasts(), state = stateOf({ xp = 42240 }) })
		end

		it(
			"matches the names of every look, owned or not, case-insensitively, sorted by name, each opening its shelf with it chosen",
			function()
				local results = ns.CollectionSearch("IP", context())

				assert.are.same({
					{
						label = "Ripple",
						shelf = "Toast style",
						place = { id = "shelf", args = { shelf = "core.toaststyle", look = "core.toaststyle.ripple" } },
					},
					{
						label = "Ship's Log",
						shelf = "Toast style",
						place = { id = "shelf", args = { shelf = "core.toaststyle", look = "core.toaststyle.ship" } },
					},
				}, results)
			end
		)

		it(
			"matches the earned titles, never one not earned, and gives nil for an empty box and {} for no match",
			function()
				local results = ns.CollectionSearch("er", context())

				local labels = {}
				for i, result in ipairs(results) do
					labels[i] = result.label
				end
				-- Dabbler and Line-Caster are earned at level 23; Fisher (30) is not, and "Ship's Log" has no "er"
				assert.are.same({ "Dabbler", "Line-Caster" }, labels)
				assert.are.same(
					{ place = { id = "shelf", args = { shelf = "titles", look = "title:level10" } } },
					{ place = results[1].place }
				)
				assert.is_nil(ns.CollectionSearch("", context()))
				assert.are.same({}, ns.CollectionSearch("zzz", context()))
			end
		)

		it("shows at most ten", function()
			local goods = {}
			for i = 1, 14 do
				goods[i] = good("a.look" .. i, "core.toaststyle", "Look " .. i, {})
			end

			assert.are.equal(10, #ns.CollectionSearch("look", contextOf({ goods = goods })))
		end)
	end)

	describe("Home's line (LED-R132, LED-R174)", function()
		it(
			'reads "The Collection: looks and titles" with x / N of both and "{n} new" in red hand while any is new',
			function()
				local context = contextOf({
					goods = toasts(),
					collection = { seen = { ["core.toaststyle.ripple"] = SERVER_TIME }, looked = {} },
				})
				local model = ns.CollectionModel(context)

				local line = ns.CollectionContentsLine(context, "iv.")

				assert.are.same({
					kind = "leader",
					numeral = "iv.",
					text = "The Collection: looks and titles",
					value = ("%d / %d"):format(model.owned, model.total),
					note = "1 new",
					place = { id = "collection" },
				}, line)
			end
		)

		it("has no note with nothing new", function()
			local line = ns.CollectionContentsLine(contextOf({ goods = toasts() }), "iv.")

			assert.is_nil(line.note)
		end)
	end)
end)
