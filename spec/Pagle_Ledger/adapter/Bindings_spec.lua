-- The Ledger's earned bindings on FakePagle (LED-R110–R116, LED-R35, LED-R92, LED-R93; SHOP-R21–R23, SHOP-R30–R33;
-- ADR 0015): its goods in Core's binding slot, the level bindings earned by the peak or celebrated level, the
-- expansion's earned bindings by their rules, M:RefreshGoods only from a live entry or done, the Journal redrawn for a
-- new binding or crest, and the zone crests in Core's crest slot. The Journal wearing the binding is
-- JournalBinding_spec.lua's.

-- Core's binding slot (SHOP-R25), where the Ledger registers its earned bindings (SHOP-R23).
local SLOT = "core.binding"

-- LED-R110's earned bindings, in its order, with their earnedText.
local GOODS = {
	{ "ledger.binding.level10", "earned", "Angler Level 10" },
	{ "ledger.binding.level20", "earned", "Angler Level 20" },
	{ "ledger.binding.level30", "earned", "Angler Level 30" },
	{ "ledger.binding.level40", "earned", "Angler Level 40" },
	{ "ledger.binding.level50", "earned", "Angler Level 50" },
	{ "ledger.binding.level60", "earned", "Angler Level 60" },
	{ "ledger.binding.legend", "earned", "Land all three Legends" },
	{ "ledger.binding.monster", "earned", "Land a Monster" },
	{ "ledger.binding.abyssal", "earned", "Prestige X" },
	{ "ledger.binding.keeper", "earned", "Complete the Ledger" },
	{ "ledger.binding.iridescent", "earned", "Every fish in every colour" },
}

-- A good's kind as LED-R110's table writes it.
---@param good PagleRegisteredGood
---@return string
local function kindOf(good)
	if good.default then
		return "default"
	elseif good.tier then
		return "tier " .. good.tier
	end
	return "earned"
end

-- A zone the catalogue knows but doesn't chart, so no Zone Mastery rank adds XP (LED-R54).
local DUSKWOOD = 10
local T0 = SERVER_TIME - 700

-- A catalogue in the shape of ns.catalogue (DATA-R76) listing `count` Species, items 1001 on, and Duskwood without
-- data; `fingerprint` names the release.
---@param count integer
---@param fingerprint string
local function catalogue(count, fingerprint)
	local items = {}
	for id = 1001, 1000 + count do
		items[id] = fishRecord(id)
	end
	return catalogueWith({
		fingerprint = fingerprint,
		items = items,
		areas = { [DUSKWOOD] = areaRecord(0, { hasData = false }) },
	})
end

-- One caught Cast in Duskwood of items `first` to `last`, one each.
---@param time integer
---@param first integer
---@param last integer
local function cast(time, first, last)
	local items = {}
	for id = first, last do
		items[#items + 1] = id
	end
	return castRecord({ time = time, zone = DUSKWOOD, items = items })
end

-- Notes the projection mode Core is in at each M:RefreshGoods (the fake's Core registry's Refresh), "idle" outside
-- any apply or done.
---@param fake FakePagle
---@return string[]
local function noteRefreshes(fake)
	local modes = {}
	local goods = fake.ns.goods
	local refresh = goods.Refresh
	goods.Refresh = function(self, module)
		if module == "Ledger" then -- not Core's own, its fish crests' (VAR-R13)
			modes[#modes + 1] = fake.projections:Mode() or "idle"
		end
		return refresh(self, module)
	end
	return modes
end

-- A Ledger on a fresh fake, logged in and in the world over an empty log, the Journal closed.
---@return FakePagle fake
---@return LoadedAddon loaded
local function ledger()
	return openJournal({ id = false })
end

describe("the Ledger's earned bindings", function()
	it(
		"register in Core's binding slot after Core's own, in LED-R110's order, earned, with no slot and no preview of their own, and Field Leather equipped (LED-R110, LED-R116, SHOP-R21, SHOP-R23, SHOP-R32)",
		function()
			local fake = ledger()
			local goods = fake.ns.goods

			for _, slot in ipairs(goods:Slots()) do
				assert.are_not.equal("Ledger", slot.module, slot.id)
			end
			local registered = {}
			for _, good in ipairs(goods:GoodsOf(SLOT)) do
				if good.module == "Ledger" then
					registered[#registered + 1] = { good.id, kindOf(good), good.earnedText }
					assert(good.preview == nil, good.id)
				else
					assert.are.same({ "Core", 0 }, { good.module, #registered }, good.id) -- Core's all come first
				end
			end
			assert.are.same(GOODS, registered)
			assert.are.equal("core.binding.field", fake.Pagle.GetEquipped(SLOT))
			assert.are.same({}, fake.reported)
		end
	)

	it(
		"name each binding from its lore keys, and by its good's ID while a key has no text (LED-R110, LED-R160, SHOP-R26)",
		function()
			local fake = newFakePagle()
			local loaded = fake.load("Pagle_Ledger", { holdAddonLoaded = true })
			loaded.ns.L["ledgergood.ledger.binding.monster.name"] = "Monster Hide"
			loaded.ns.L["ledgergood.ledger.binding.monster.description"] = "Scaled hide."
			-- As before the committed Lore.lua had them (LED-R161): level10's keys with no text.
			loaded.ns.L["ledgergood.ledger.binding.level10.name"] = nil
			loaded.ns.L["ledgergood.ledger.binding.level10.description"] = nil
			loaded.client.fire("ADDON_LOADED", "Pagle_Ledger")

			assert.are.same({ "Monster Hide", "Scaled hide." }, {
				fake.Pagle.GetGood("ledger.binding.monster").name,
				fake.Pagle.GetGood("ledger.binding.monster").description,
			})
			assert.are.equal("ledger.binding.level10", fake.Pagle.GetGood("ledger.binding.level10").name)
			assert.is_nil(fake.Pagle.GetGood("ledger.binding.level10").description)
		end
	)

	it(
		"own a level binding after the one M:RefreshGoods of the live entry reaching its level, and keep it through a rebuild that lowers the level (LED-R111, LED-R92, LED-R35, SHOP-R30, SHOP-R31)",
		function()
			local fake = newFakePagle()
			fake.setCatalogue(catalogue(20, "first release"))
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			-- 19 new Species in a new zone: 200 + 19 × (20 + 500 + 100) = 11,980 XP, level 9 (LED-R20, LED-R30).
			fake.catchLog:Append(cast(T0, 1001, 1019))
			local loaded = fake.load("Pagle_Ledger")
			local modes = noteRefreshes(fake)
			fake.login()
			fake.enterWorld()
			local ns = loaded.ns
			assert.are.equal(9, ns.PeakLevel(ns.projection:GetState()))
			assert.are.same({ "done" }, modes)
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.level10"))

			-- A 20th Species: + 620 XP, 12,600, level 10.
			fake.playCast("caught", { { itemID = 1020, quantity = 1 } })

			assert.are.equal(10, ns.PeakLevel(ns.projection:GetState()))
			assert.are.same({ "done", "live" }, modes)
			assert.is_true(fake.Pagle.IsOwned("ledger.binding.level10"))
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.level20"))

			-- The next login: a release that lists only the first 10 Species rebuilds the projection (LED-R191), and
			-- the other ten become Uncharted, so the climb falls below level 10.
			local later = newFakePagle()
			later.setCatalogue(catalogue(10, "second release"))
			later.catchLog.data = fake.catchLog.data
			later.globals.PagleLedgerDB = loaded.env.PagleLedgerDB
			local reloaded = later.load("Pagle_Ledger")
			local laterModes = noteRefreshes(later)
			later.login()
			later.enterWorld()

			assert.is_true(reloaded.ns.PeakLevel(reloaded.ns.projection:GetState()) < 10)
			assert.are.same({ "done" }, laterModes) -- never mid-rebuild (SHOP-R31)
			assert.is_true(later.Pagle.IsOwned("ledger.binding.level10"))
			assert.is_false(later.Pagle.IsOwned("ledger.binding.level20"))
		end
	)

	it(
		"redraw the open Journal when the binding or the crest changes: the Angler page's \"In use\", the bookplate's emblem the crest's icon (LED-R112, LED-R146, SHOP-R33)",
		function()
			local fake = newFakePagle()
			fake.profile.announcements.motion = false
			fake.catchLog.data.logId = "log"
			-- Celebrated at level 10 before (LED-R90): Tanned Hide is earned (LED-R111); and zone 12 at Master, so its
			-- crest is too (LED-R114).
			fake.globals.PagleLedgerDB = {
				global = { celebrated = { coins = 0, levels = { [0] = 10 }, zones = { [12] = 5 }, logId = "log" } },
			}
			local loaded = fake.load("Pagle_Ledger")
			fake.login()
			fake.enterWorld()
			local ns = loaded.ns
			ns.ToggleJournal()
			assert.is_nil(ns.CrestIcon()) -- Plain, the default: no emblem (LED-R112, SHOP-R25)
			local drawn = ns.journal.pages

			assert.is_true(fake.Pagle.SetEquipped(SLOT, "ledger.binding.level10"))

			assert.are_not.equal(drawn, ns.journal.pages)
			drawn = ns.journal.pages

			assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.elwynn"))

			assert.are_not.equal(drawn, ns.journal.pages)
			assert.are.equal("Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn", ns.CrestIcon())
		end
	)
end)

describe("the Ledger's expansion earned bindings", function()
	local RACER, ANGELFISH, QUEENFISH, MACKEREL = 19803, 19805, 19806, 6303
	local STV, FERALAS = 33, 357

	-- A catalogue (DATA-R76) named `fingerprint`: Stranglethorn lists the Racer and the Angelfish, Feralas the Mackerel
	-- and, unless `queenfish` is false, the Queenfish; every item sized (LOG-R65), a Legend from its Catch ID alone.
	-- With `racer` false, the Racer is in no release, so its Catches are Uncharted (LED-R64).
	---@param fingerprint string
	---@param options { queenfish: boolean?, racer: boolean? }?
	local function release(fingerprint, options)
		options = options or {}
		local items = {
			[ANGELFISH] = fishRecord(ANGELFISH, { legend = true, typicalLength = 1800 }),
			[MACKEREL] = fishRecord(MACKEREL, { typicalLength = 300 }),
		}
		local stv = { catchEntry(ANGELFISH) }
		if options.racer ~= false then
			items[RACER] = fishRecord(RACER, { legend = true, typicalLength = 2200 })
			stv[2] = catchEntry(RACER)
		end
		local feralas = { catchEntry(MACKEREL) }
		if options.queenfish ~= false then
			items[QUEENFISH] = fishRecord(QUEENFISH, { legend = true, typicalLength = 2000 })
			feralas[2] = catchEntry(QUEENFISH)
		end
		return catalogueWith({
			fingerprint = fingerprint,
			items = items,
			areas = {
				[STV] = areaRecord(0, { catches = stv }),
				[FERALAS] = areaRecord(0, { continent = 1, catches = feralas }),
			},
		})
	end

	-- A Ledger on a fresh fake over `data`, its log `log` (or the saved one of `from`, with its PagleLedgerDB), logged in
	-- and in the world, M:RefreshGoods noted.
	---@param data table
	---@param from { fake: FakePagle, loaded: LoadedAddon }?
	---@param log table[]?
	---@return FakePagle fake
	---@return LoadedAddon loaded
	---@return string[] modes
	local function ledgerOver(data, from, log)
		local fake = newFakePagle()
		fake.setCatalogue(data)
		if from then
			fake.catchLog.data = from.fake.catchLog.data
			fake.globals.PagleLedgerDB = from.loaded.env.PagleLedgerDB
		else
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			for _, record in ipairs(log or {}) do
				fake.catchLog:Append(record)
			end
		end
		local loaded = fake.load("Pagle_Ledger")
		local modes = noteRefreshes(fake)
		fake.login()
		fake.enterWorld()
		return fake, loaded, modes
	end

	it(
		"own Three Gilt Fish after the live entry that lands the last listed Legend, and keep it when a release lists another (LED-R116, LED-R63, SHOP-R31)",
		function()
			local fake, loaded, modes = ledgerOver(
				release("first release", { queenfish = false }),
				nil,
				{ castRecord({ time = T0, zone = STV, items = { RACER } }) }
			)
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.legend"))

			fake.playCast("caught", { { itemID = ANGELFISH, quantity = 1 } })

			assert.are.same({ "done", "live" }, modes)
			assert.is_true(fake.Pagle.IsOwned("ledger.binding.legend"))

			-- The next login: a release listing the Queenfish rebuilds the projection (LED-R191); two of three caught.
			local later, reloaded, laterModes = ledgerOver(release("second release"), { fake = fake, loaded = loaded })
			assert.are.same({ "done" }, laterModes)
			assert.are.same(
				{ done = 2, total = 3 },
				reloaded.ns.LedgerCompletion(reloaded.ns.world, reloaded.ns.projection:GetState()).legends
			)
			assert.is_true(later.Pagle.IsOwned("ledger.binding.legend"))
		end
	)

	it(
		"own Monster Hide from the live entry of the first Catch in the Monster band, and keep it through a rebuild that loses the record (LED-R116, LED-R80, LED-R64)",
		function()
			-- A Legend is sized from its Catch ID alone (LOG-R67), so any Catch of it may be a Monster; the Racer caught
			-- before, so its first Catch's moment is behind.
			local fake, loaded, modes =
				ledgerOver(release("first release"), nil, { castRecord({ time = T0, zone = STV, items = { RACER } }) })
			local before = loaded.ns.projection:GetState().items[RACER].record
			assert.are_not.equal(5, before and before.band)
			local monsterAt
			fake.Pagle.RegisterCallback("Spec", "Catch", function(_, catch)
				if catch.size and catch.size.band == 5 and not monsterAt then
					monsterAt = #modes + 1 -- the refresh this Cast's live entry makes
				end
			end)
			for _ = 1, 40 do
				fake.playCast("caught", { { itemID = RACER, quantity = 1 } })
				assert.are.equal(monsterAt ~= nil, fake.Pagle.IsOwned("ledger.binding.monster"))
			end
			assert(monsterAt, "no Racer in the Monster band in 40 Casts")
			-- one refresh at the done, one for the Monster's Cast (LED-R116), and none for the other Casts
			assert.are.same({ "done", "live" }, modes)

			local later, reloaded = ledgerOver(release("second release", { racer = false }), {
				fake = fake,
				loaded = loaded,
			})
			assert.is_nil(reloaded.ns.projection:GetState().items[RACER])
			assert.is_true(later.Pagle.IsOwned("ledger.binding.monster"))
		end
	)

	it("own Abyssal Black at Prestige X, not at IX (LED-R116, LED-R34)", function()
		local function owned(ranks)
			local entries = {}
			for rank = 1, ranks do
				entries[rank] = prestigeEntry(SERVER_TIME - 5000 + rank, rank)
			end
			local fake = openJournal({ entries = entries, id = false })
			return fake.Pagle.IsOwned("ledger.binding.abyssal")
		end

		assert.is_false(owned(9))
		assert.is_true(owned(10))
	end)

	it(
		"own Keeper's Gold with the complete.ledger title celebrated, from registration on (LED-R116, LED-R75, LED-R90)",
		function()
			local fake = newFakePagle()
			fake.catchLog.data.logId = "log"
			fake.globals.PagleLedgerDB = {
				global = { celebrated = { coins = 0, titles = { ["title:complete.ledger"] = true }, logId = "log" } },
			}
			fake.load("Pagle_Ledger")

			assert.is_true(fake.Pagle.IsOwned("ledger.binding.keeper"))
			fake.login()
			fake.enterWorld()
			assert.is_true(fake.Pagle.IsOwned("ledger.binding.keeper"))
			assert.is_false(fake.Pagle.IsOwned("ledger.binding.legend"))
		end
	)

	it(
		"own Iridescent Scale with the complete.varieties title celebrated, from registration on, and not before it (LED-R116, VAR-R22, LED-R90)",
		function()
			local function owned(titles)
				local fake = newFakePagle()
				fake.catchLog.data.logId = "log"
				fake.globals.PagleLedgerDB = { global = { celebrated = { coins = 0, titles = titles, logId = "log" } } }
				fake.load("Pagle_Ledger")
				local registered = fake.Pagle.IsOwned("ledger.binding.iridescent")
				fake.login()
				fake.enterWorld()
				return { registered, fake.Pagle.IsOwned("ledger.binding.iridescent") }
			end

			assert.are.same({ true, true }, owned({ ["title:complete.varieties"] = true }))
			assert.are.same({ false, false }, owned({ ["title:complete.ledger"] = true }))
		end
	)

	it(
		"keep Iridescent Scale once noted in the celebrated set, its title not celebrated (LED-R116, LED-R90)",
		function()
			local fake = newFakePagle()
			fake.catchLog.data.logId = "log"
			fake.globals.PagleLedgerDB = {
				global = { celebrated = { coins = 0, goods = { ["ledger.binding.iridescent"] = true }, logId = "log" } },
			}
			fake.load("Pagle_Ledger")
			fake.login()
			fake.enterWorld()

			assert.is_true(fake.Pagle.IsOwned("ledger.binding.iridescent"))
		end
	)

	describe("the second round's (LED-R118)", function()
		-- `n` caught Casts, each the first in a zone of its own on 1 October 2026: `n` glass shards (LED-R119), and
		-- with them `n` zones fished.
		---@param n integer
		local function firstWaters(n)
			local log = {}
			for i = 1, n do
				log[i] = castRecord({
					time = T0 + i,
					zone = 1000 + i,
					date = { year = 2026, month = 10, day = 1, weekday = 5 },
					items = { MACKEREL },
				})
			end
			return log
		end

		it(
			"own Chapel Glass after the done that counts its twelfth shard, noted in the celebrated set, and count toward it before (LED-R118, LED-R119, SHOP-R31)",
			function()
				local fake, loaded = ledgerOver(release("first release"), nil, firstWaters(11))
				assert.is_false(fake.Pagle.IsOwned("ledger.toaststyle.glass"))
				local toastStyles = fake.ns.goods:GoodsOf("core.toaststyle")
				local glass
				for _, registered in ipairs(toastStyles) do
					if registered.id == "ledger.toaststyle.glass" then
						glass = registered
					end
				end
				assert.are.same({ "11 of 12 shards", "12 glass shards" }, { glass.earnedText() })

				local later, reloaded = ledgerOver(release("first release"), nil, firstWaters(12))
				assert.is_true(later.Pagle.IsOwned("ledger.toaststyle.glass"))
				assert.is_true(reloaded.env.PagleLedgerDB.global.celebrated.goods["ledger.toaststyle.glass"])
				assert.is_nil(loaded.env.PagleLedgerDB.global.celebrated.goods)
			end
		)

		it("note a binding not yet registered, kept for ADR 0015's registration (LED-R118, LED-R90)", function()
			local _, loaded = ledgerOver(release("first release"), nil, firstWaters(25))
			local goods = loaded.env.PagleLedgerDB.global.celebrated.goods
			assert.is_true(goods["ledger.binding.logbook"])
		end)
	end)
end)

describe("the Ledger's goods in Core's open slots", function()
	local RACER, ANGELFISH = 19803, 19805
	local STV = 33

	-- A catalogue (DATA-R76) named `fingerprint` whose Stranglethorn lists the Racer and the Angelfish, or the Racer
	-- alone without `angelfish`.
	---@param fingerprint string
	---@param angelfish boolean
	local function release(fingerprint, angelfish)
		local items = { [RACER] = fishRecord(RACER, { legend = true, typicalLength = 2200 }) }
		local catches = { catchEntry(RACER) }
		if angelfish then
			items[ANGELFISH] = fishRecord(ANGELFISH, { legend = true, typicalLength = 1800 })
			catches[2] = catchEntry(ANGELFISH)
		end
		return catalogueWith({
			fingerprint = fingerprint,
			items = items,
			areas = { [STV] = areaRecord(0, { catches = catches }) },
		})
	end

	-- Which of LED-R117's four `fake` owns, in its order.
	---@param fake FakePagle
	local function owned(fake)
		local list = {}
		for i, id in ipairs({
			"ledger.toaststyle.legend",
			"ledger.toaststyle.prestige",
			"ledger.soundset.concertina",
			"ledger.soundset.choir",
		}) do
			list[i] = fake.Pagle.IsOwned(id)
		end
		return list
	end

	it(
		"register LED-R117's four and LED-R118's seven toast styles in Core's toast style and sound set slots, the Ledger's, after Core's own (LED-R117, LED-R118, SHOP-R23, SHOP-R25)",
		function()
			local fake = ledger()
			local goods = fake.ns.goods

			-- Each of the Ledger's goods in `slot`: its ID, name and row tag (an earnedText function's first text).
			local function ledgerGoods(slot)
				local list = {}
				for _, good in ipairs(goods:GoodsOf(slot)) do
					if good.module == "Ledger" then
						local tag = good.earnedText
						if type(tag) == "function" then
							tag = tag()
						end
						list[#list + 1] = { good.id, good.name, tag }
					end
				end
				return list
			end
			assert.are.same({
				{ "ledger.toaststyle.legend", "The Tall Tale", "Land a Legend" },
				{ "ledger.toaststyle.prestige", "Oxblood Vellum", "Prestige V" },
				{ "ledger.toaststyle.glass", "Chapel Glass", "0 of 12 shards" },
				{ "ledger.toaststyle.deep", "The Deep Lure", "0 of 100 catches" },
				{ "ledger.toaststyle.koi", "Ink and Koi", "0 of 25 pairs" },
				{ "ledger.toaststyle.trophy", "Mounted Trophy", "0 of 25 records" },
				{ "ledger.toaststyle.slate", "Fishmonger's Slate", "0 of 30 Species" },
				{ "ledger.toaststyle.ice", "Through the Ice", "0 of 100 catches" },
				{ "ledger.toaststyle.stitch", "Cross-Stitch Sampler", "0 of 20 fish" },
			}, ledgerGoods("core.toaststyle"))
			assert.are.same({
				{ "ledger.soundset.concertina", "Old Salt's Concertina", "Prestige I" },
				{ "ledger.soundset.choir", "Choir of the Deep", "Land all three Legends" },
			}, ledgerGoods("core.soundset"))
			assert.are.same({ false, false, false, false }, owned(fake))
			assert.are.same({}, fake.reported)
		end
	)

	it(
		"own The Tall Tale from the first Legend's live entry and Choir of the Deep from the last's, and keep Choir through a rebuild with another Legend listed (LED-R117, LED-R63, SHOP-R31)",
		function()
			local fake = newFakePagle()
			fake.setCatalogue(release("first release", false))
			fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
			local loaded = fake.load("Pagle_Ledger")
			fake.login()
			fake.enterWorld()
			assert.are.same({ false, false, false, false }, owned(fake))

			fake.playCast("caught", { { itemID = RACER, quantity = 1 } })

			assert.are.same({ true, false, false, true }, owned(fake))

			local later = newFakePagle()
			later.setCatalogue(release("second release", true))
			later.catchLog.data = fake.catchLog.data
			later.globals.PagleLedgerDB = loaded.env.PagleLedgerDB
			later.load("Pagle_Ledger")
			later.login()
			later.enterWorld()

			assert.are.same({ true, false, false, true }, owned(later))
		end
	)

	it(
		"own Old Salt's Concertina at Prestige I and Oxblood Vellum at V, from the log's Prestiges (LED-R117, LED-R34)",
		function()
			local function after(ranks)
				local entries = {}
				for rank = 1, ranks do
					entries[rank] = prestigeEntry(SERVER_TIME - 5000 + rank, rank)
				end
				return owned((openJournal({ entries = entries, id = false })))
			end

			assert.are.same({ false, false, true, false }, after(1))
			assert.are.same({ false, false, true, false }, after(4))
			assert.are.same({ false, true, true, false }, after(5))
		end
	)
end)

describe("the Ledger's zone crests", function()
	-- A Ledger on a fresh fake whose client names each crest's zone by its key backwards (C_Map.GetAreaInfo), with
	-- `celebrated` saved (LED-R90), logged in and in the world over an empty log: no zone is charted.
	---@param celebrated table?
	---@return FakePagle fake
	---@return LoadedAddon loaded
	local function crested(celebrated)
		local fake = newFakePagle()
		fake.catchLog.data.logId = "log"
		if celebrated then
			celebrated.logId = "log"
			fake.globals.PagleLedgerDB = { global = { celebrated = celebrated } }
		end
		local loaded = fake.load("Pagle_Ledger", { holdAddonLoaded = true })
		for _, crest in ipairs(loaded.ns.ZONE_CRESTS) do
			loaded.client.areaNames[crest.areaID] = crest.key:reverse()
		end
		loaded.client.fire("ADDON_LOADED", "Pagle_Ledger")
		fake.login()
		fake.enterWorld()
		return fake, loaded
	end

	it(
		"register in Core's crest slot after Plain, the fifty-three earned goods in LED-R113's order, the Ledger's, in the zone group (LED-R113, SHOP-R23)",
		function()
			local fake, loaded = crested()
			local ns = loaded.ns
			local sorted = ns.SortedZoneCrests(function(areaID)
				return loaded.client.areaNames[areaID]
			end)

			-- Plain, then Core's fish crests, registered before any Module (VAR-R12), then the Ledger's.
			local registered = fake.ns.goods:GoodsOf("core.crest")
			local before = 1 + #FISH_CREST_SPECIES
			assert.are.equal(before + 53, #registered)
			assert.are.equal("core.crest.plain", registered[1].id)
			for i, crest in ipairs(sorted) do
				local good = registered[before + i]
				assert.are.same({
					ns.ZoneCrestID(crest),
					"Ledger",
					"zone",
					"Interface\\AddOns\\Pagle_Ledger\\media\\crests\\" .. crest.key,
					ns.L["crest." .. crest.key .. ".name"],
				}, { good.id, good.module, good.group, good.icon, good.name })
				assert.is_false(fake.Pagle.IsOwned(good.id))
			end
			assert.are.equal("Ledger", fake.Pagle.GetGood("ledger.crest.zephras").module)
			assert.are.equal("core.crest.plain", fake.Pagle.GetEquipped("core.crest"))
		end
	)

	it(
		"own the crest of a zone celebrated at Master, which the Journal's bookplate then shows (LED-R114, LED-R112)",
		function()
			local fake, loaded = crested({ coins = 0, zones = { [1] = 5, [12] = 4 } })

			assert.is_true(fake.Pagle.IsOwned("ledger.crest.dunmorogh"))
			assert.is_false(fake.Pagle.IsOwned("ledger.crest.elwynn"))
			assert.is_true(fake.Pagle.SetEquipped("core.crest", "ledger.crest.dunmorogh"))
			assert.are.equal("Interface\\AddOns\\Pagle_Ledger\\media\\crests\\dunmorogh", loaded.ns.CrestIcon())
		end
	)

	it(
		"say how a crest not yet earned is earned, its zone named by the client, which the shop, listing no earned crest,"
			.. " never shows (LED-R115, SHOP-R22, SHOP-R25)",
		function()
			local fake = crested()
			local goods = fake.ns.goods

			-- The fake's catalogue charts zone 12, unfished over the empty log; the new zones aren't charted (LED-R54).
			assert.are.same({
				"Unfished",
				"Earned when nnywle reaches Master in the Fish Journal. Catch anything there to begin.",
			}, { goods:EarnedTexts("ledger.crest.elwynn") })
			assert.are.same({
				"Not yet charted",
				"Earned when sedalgrevir reaches Master in the Fish Journal, once its waters are charted.",
			}, { goods:EarnedTexts("ledger.crest.riverglades") })
			assert.is_nil(fake.ns.ShopModel():Row("ledger.crest.elwynn"))
		end
	)
end)
