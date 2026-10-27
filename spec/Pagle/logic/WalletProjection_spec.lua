-- The wallet projection (SHOP-R10, SHOP-R11, SHOP-R34, SHOP-R91–R96, LOG-R78) as pure logic: ns.AddWalletProjection
-- on a real projection machinery over a saved log, feeding a real wallet and goods registry.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local LOG_ID = "3f9a2c1e7b0d4a65" -- savedLog's logId
local FINGERPRINT = "0123456789abcdef"
local CRIMSON, SILVER = "core.crest.crimson", "core.crest.silver"

-- A world over a saved log holding `entries` and a stored wallet projection `db` (empty by default): the machinery
-- (frames the spec runs, chunked from more than `syncLimit` pending entries), a wallet with each BalanceChanged in
-- `world.balances`, and a goods registry with Core's crest slot (Plain the default, Crimson and Silver for sale),
-- started, with each AppearanceChanged in `world.looks`.
local function newWorld(entries, db, syncLimit)
	local catchLog = ns.OpenCatchLog(savedLog(entries), { decodeErrors = 0 }, SERVER_TIME)
	local world = {
		catchLog = catchLog,
		db = db or {},
		fingerprint = FINGERPRINT,
		now = 0,
		frames = {},
		balances = {},
		looks = {},
		snapshots = {},
		pagleDB = { global = { goods = {} }, profile = { appearance = {} } },
	}
	world.projections = ns.NewProjections({
		length = function()
			return #catchLog.data.entries
		end,
		logId = function()
			return catchLog.data.logId
		end,
		fingerprint = function()
			return world.fingerprint
		end,
		clock = function()
			world.now = world.now + 1 -- every step costs 1 ms
			return world.now
		end,
		nextFrame = function(step)
			world.frames[#world.frames + 1] = step
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		syncLimit = syncLimit,
		budget = 1, -- one step a frame
	})
	world.wallet = ns.NewWallet(function(_, balance)
		world.balances[#world.balances + 1] = balance
	end)
	world.wallet:Open({})
	world.goods = ns.NewGoods({
		db = function()
			return world.pagleDB
		end,
		modules = function()
			return {}
		end,
		fire = function(_, slot, goodID)
			world.looks[#world.looks + 1] = slot .. " " .. goodID
		end,
		call = function(fn, ...)
			return fn(...)
		end,
		report = error,
	})
	local goods = world.goods
	assert.is_nil(goods:RegisterSlot("Core", { id = "core.crest", label = "Crests", category = "Crests" }))
	assert.is_nil(
		goods:RegisterGood("Core", { id = "core.crest.plain", slot = "core.crest", name = "Plain", default = true })
	)
	assert.is_nil(goods:RegisterGood("Core", { id = CRIMSON, slot = "core.crest", name = "Crimson", tier = 1 }))
	assert.is_nil(goods:RegisterGood("Core", { id = SILVER, slot = "core.crest", name = "Silver", tier = 2 }))

	-- Login step 1: the projection binds and hands over what it stored. ModulesChanged starts the looks.
	world.projection = ns.AddWalletProjection({
		projections = world.projections,
		db = world.db,
		iterate = function(afterSeq, reader)
			return catchLog:Iterate(afterSeq, reader)
		end,
		wallet = world.wallet,
		goods = goods,
		published = function(snapshot)
			world.snapshots[#world.snapshots + 1] = snapshot
		end,
	})
	goods:Start()

	-- Login step 3: the catch-up or rebuild, run to its end unless `frames` limits the frames run.
	function world.enterWorld(frames)
		world.projections:Start(#catchLog.data.entries)
		world.runFrames(frames)
	end
	function world.runFrames(limit)
		local count = 0
		while #world.frames > 0 and (not limit or count < limit) do
			table.remove(world.frames, 1)()
			count = count + 1
		end
	end
	-- Appends a record and hands it over live, as ns.RecordPurchase and the Cast state machine do (LOG-R73).
	function world.live(record)
		record.char, record.time = 1, SERVER_TIME
		world.projections:Live(catchLog:Append(record))
	end
	return world
end

-- A stored wallet projection, up to date with a log of `lastSeq` entries, as login finds it in PagleDB.
local function stored(spent, purchased, lastSeq)
	return {
		projection = { spent = spent, purchased = purchased },
		lastSeq = lastSeq,
		logId = LOG_ID,
		fingerprint = FINGERPRINT,
		rulesVersion = ns.WALLET_RULES_VERSION,
	}
end

describe("ns.AddWalletProjection", function()
	it(
		"counts U1 entries for two goods at 150 and 400 as 550 spent, both owned, after the catch-up (SHOP-R11)",
		function()
			local world = newWorld({
				castEntry(SERVER_TIME - 9000),
				purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150),
				purchaseEntry(SERVER_TIME - 7000, SILVER, 400),
			})
			world.wallet:Report("Ledger", 600)

			world.enterWorld()

			assert.are.same({
				spent = 550,
				purchased = { [CRIMSON] = true, [SILVER] = true },
				ownedAt = { [CRIMSON] = SERVER_TIME - 8000, [SILVER] = SERVER_TIME - 7000 },
			}, world.db.projection)
			assert.are.equal(3, world.db.rulesVersion) -- wallet-and-shop.md › Data: rules version 3 (SHOP-R53, SHOP-R36)
			assert.are.same({ true, true }, { world.goods:IsOwned(CRIMSON), world.goods:IsOwned(SILVER) })
			assert.are.same({ balance = 50, held = false, earned = { Ledger = 600 } }, world.wallet:Get())
		end
	)

	it("ignores a second U1 for a good already purchased, so it never costs twice (SHOP-R11)", function()
		local world = newWorld({
			purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150),
			purchaseEntry(SERVER_TIME - 7000, SILVER, 400),
			purchaseEntry(SERVER_TIME - 6000, CRIMSON, 150),
		})
		world.enterWorld()
		local fired = #world.balances

		world.live({ kind = "purchase", good = SILVER, price = 400 })

		assert.are.same({
			spent = 550,
			purchased = { [CRIMSON] = true, [SILVER] = true },
			ownedAt = { [CRIMSON] = SERVER_TIME - 8000, [SILVER] = SERVER_TIME - 7000 },
		}, world.db.projection) -- the first U1 gives the time, a later one for the good changes nothing
		assert.are.equal(fired, #world.balances, "no BalanceChanged for a duplicate")
	end)

	it("counts the price stored in the entry, never the good's tier price now (SHOP-R10)", function()
		local world = newWorld({ purchaseEntry(SERVER_TIME - 8000, SILVER, 380) })

		world.enterWorld()

		assert.are.equal(380, world.db.projection.spent)
	end)

	it(
		"applies a live purchase: spent rises, BalanceChanged fires once and the good is owned (SHOP-R10, SHOP-R11)",
		function()
			local world = newWorld({ purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150) })
			world.wallet:Report("Ledger", 600)
			world.enterWorld()
			local fired = #world.balances

			world.live({ kind = "purchase", good = SILVER, price = 400 })

			assert.are.equal(550, world.db.projection.spent)
			assert.are.equal(fired + 1, #world.balances)
			assert.are.same({ balance = 50, held = false, earned = { Ledger = 600 } }, world.balances[#world.balances])
			assert.is_true(world.goods:IsOwned(SILVER))
		end
	)

	it("fires AppearanceChanged for a live purchase that changes an equipped look (SHOP-R33)", function()
		local world = newWorld({})
		world.enterWorld()
		world.pagleDB.profile.appearance["core.crest"] = SILVER -- picked before, while owned on another PagleDB profile

		world.live({ kind = "purchase", good = SILVER, price = 400 })

		assert.are.same({ "core.crest " .. SILVER }, world.looks)
	end)

	it("hands over the stored spent and purchased set at login, before the catch-up (SHOP-R34)", function()
		local world =
			newWorld({ purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150) }, stored(150, { [CRIMSON] = true }, 1))
		world.wallet:Report("Ledger", 600)

		assert.is_true(world.goods:IsOwned(CRIMSON))
		assert.are.equal(450, world.wallet:Get().balance)
	end)

	it(
		"keeps answering IsOwned from the set saved before a rebuild, with an equipped bought look kept, until its"
			.. " done (SHOP-R34, SHOP-R91)",
		function()
			local entries = { purchaseEntry(SERVER_TIME - 9000, SILVER, 400) }
			for i = 1, 5 do
				entries[#entries + 1] = castEntry(SERVER_TIME - 8000 + i)
			end
			entries[#entries + 1] = purchaseEntry(SERVER_TIME - 7000, CRIMSON, 150)
			local db = stored(550, { [CRIMSON] = true, [SILVER] = true }, #entries)
			db.fingerprint = "an older release" -- DATA-R71: a new content fingerprint rebuilds it
			local world = newWorld(entries, db, 0)
			world.pagleDB.profile.appearance["core.crest"] = CRIMSON
			world.goods:Settle()
			world.looks = {}

			world.enterWorld(4) -- the rebuild has applied the Silver crest and some Casts, not the Crimson one yet
			assert.is_true(world.projection:IsUpdating())
			assert.is_nil(world.projection:GetState().purchased[CRIMSON])
			assert.are.same({ true, true }, { world.goods:IsOwned(CRIMSON), world.goods:IsOwned(SILVER) })
			assert.are.equal(CRIMSON, world.goods:GetEquipped("core.crest"))

			world.runFrames()
			assert.is_false(world.projection:IsUpdating())
			assert.are.same({
				spent = 550,
				purchased = { [CRIMSON] = true, [SILVER] = true },
				ownedAt = { [CRIMSON] = SERVER_TIME - 7000, [SILVER] = SERVER_TIME - 9000 },
			}, world.db.projection)
			assert.are.same({}, world.looks, "the look never fell back to the default")
		end
	)

	it("owns a good a catch-up finds only once the catch-up is done (SHOP-R34)", function()
		local entries = { purchaseEntry(SERVER_TIME - 9000, SILVER, 400) }
		for i = 1, 3 do
			entries[#entries + 1] = castEntry(SERVER_TIME - 8000 + i)
		end
		local world = newWorld(entries, stored(400, { [SILVER] = true }, 1), 0)
		world.wallet:Report("Ledger", 600)
		world.catchLog:Append({ kind = "purchase", char = 1, time = SERVER_TIME - 7000, good = CRIMSON, price = 150 })

		world.enterWorld(5) -- every entry applied in replay, the finish not run yet
		assert.is_true(world.projection:IsUpdating())
		assert.is_false(world.goods:IsOwned(CRIMSON))
		assert.are.equal(200, world.wallet:Get().balance)

		world.runFrames()
		assert.is_true(world.goods:IsOwned(CRIMSON))
		assert.are.same({ 550, 50 }, { world.db.projection.spent, world.wallet:Get().balance })
	end)

	it("rebuilds on a new content fingerprint to the same spent and purchased set (LOG-R72, DATA-R71)", function()
		local entries = {
			purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150),
			purchaseEntry(SERVER_TIME - 7000, SILVER, 400),
			purchaseEntry(SERVER_TIME - 6000, CRIMSON, 150),
		}
		local first = newWorld(entries)
		first.enterWorld()

		local db = first.db
		local before = db.projection
		local world = newWorld(entries, db)
		world.fingerprint = "a new release"
		world.enterWorld()

		assert.are_not.equal(before, db.projection, "rebuilt into a fresh state")
		assert.are.equal("a new release", db.fingerprint)
		assert.are.same({
			spent = 550,
			purchased = { [CRIMSON] = true, [SILVER] = true },
			ownedAt = { [CRIMSON] = SERVER_TIME - 8000, [SILVER] = SERVER_TIME - 7000 },
		}, db.projection)
	end)

	it(
		"lets a Module's recount below spent hold the balance at 0, nothing bought taken back (SHOP-R91, SHOP-R12)",
		function()
			local world = newWorld({
				purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150),
				purchaseEntry(SERVER_TIME - 7000, SILVER, 400),
			})
			world.wallet:Report("Ledger", 600)
			world.enterWorld()
			assert.are.equal(50, world.wallet:Get().balance)

			world.wallet:Report("Ledger", 500) -- the Ledger's rebuild recounts its total lower

			assert.are.same({ balance = 0, held = true, earned = { Ledger = 500 } }, world.wallet:Get())
			assert.are.same({ true, true }, { world.goods:IsOwned(CRIMSON), world.goods:IsOwned(SILVER) })
		end
	)

	it("takes a late-enabled Module's whole earned total at once as one balance move (SHOP-R92)", function()
		local world = newWorld({ purchaseEntry(SERVER_TIME - 8000, CRIMSON, 150) })
		world.enterWorld()
		local fired = #world.balances

		world.wallet:Report("Hunts", 1000) -- its first build's done reports everything it ever paid

		assert.are.equal(fired + 1, #world.balances)
		assert.are.equal(850, world.balances[#world.balances].balance)
	end)

	it(
		"owns nothing for a purchase lost with its session in a crash: neither log nor PagleDB kept it (SHOP-R94)",
		function()
			-- Saved at the last logout: one purchase. The Crimson crest was bought after it, then the client crashed.
			local world =
				newWorld({ purchaseEntry(SERVER_TIME - 8000, SILVER, 400) }, stored(400, { [SILVER] = true }, 1))

			world.enterWorld()

			assert.is_false(world.goods:IsOwned(CRIMSON))
			assert.are.same({ spent = 400, purchased = { [SILVER] = true } }, world.db.projection)
		end
	)

	it("counts purchases either side of a daily and a weekly reset alike: no rule depends on one (SHOP-R95)", function()
		local world = newWorld({
			purchaseEntry(SERVER_TIME - 8 * 86400, CRIMSON, 150),
			purchaseEntry(SERVER_TIME - 1, SILVER, 400),
		})

		world.enterWorld()

		assert.are.same({
			spent = 550,
			purchased = { [CRIMSON] = true, [SILVER] = true },
			ownedAt = { [CRIMSON] = SERVER_TIME - 8 * 86400, [SILVER] = SERVER_TIME - 1 },
		}, world.db.projection)
	end)

	it("leaves the wallet alone for Casts, Uncharted Catches included, and Prestiges (SHOP-R96)", function()
		local world = newWorld({})
		world.wallet:Report("Ledger", 600)
		world.enterWorld()
		local fired = #world.balances

		world.live({
			kind = "cast",
			outcome = "caught",
			conditions = { minute = 494, zone = 148, subzone = 453, events = {}, auras = {} },
			items = { { itemID = 9999, quantity = 1 } }, -- Uncharted: in no catalogue
		})
		world.live({ kind = "prestige", rank = 1 })

		assert.are.same({ spent = 0, purchased = {} }, world.db.projection)
		assert.are.equal(fired, #world.balances)
	end)
end)

describe("The wallet projection's Curio crates", function()
	local ADA = "Player-4618-0A1B2C3D" -- savedLog's character 1
	local FOIL = "core.toaststyle.foil"
	local PRICE = 1500
	local realHash, realPool = ns.SizeHash, ns.CRATE_POOL

	-- A crate's U1 at server time `time` (SHOP-R50).
	local function crateEntry(time, price)
		return purchaseEntry(time, "core.crate", price or PRICE)
	end

	-- The crates' entry IDs hash as `tierHash[time]` says, and their good's hash to 0, in place of LOG-R66's.
	local function stubHashes(tierHash)
		ns.SizeHash = function(id)
			if id:sub(-5) == "/good" then
				return 0
			end
			return assert(tierHash[tonumber(id:match("%-(%d+)%-%d+$"))], "no hash for " .. id)
		end
	end

	-- The pool of the stubbed crates: Crimson in tier 1, Silver in tier 2, Prize Foil crate only; tiers 3 to 6 empty.
	local function stubPool()
		ns.CRATE_POOL = {
			{ id = CRIMSON, tier = 1, kind = "crest" },
			{ id = SILVER, tier = 2, kind = "crest" },
			{ id = FOIL, tier = "curio", kind = "toaststyle" },
		}
	end

	-- The first hash of tier 2, 4 and Curio (SHOP-R51's thresholds), and tier 1's: 0.
	local TIER_1, TIER_2, TIER_4, CURIO = 0, 1717986919, 3521873183, 4294967295

	after_each(function()
		ns.SizeHash, ns.CRATE_POOL = realHash, realPool
	end)

	-- `n` crates at server times SERVER_TIME - 90000 + 1 … n, each of tier 1 unless `tiers` says (by index).
	local function crates(n, tiers, price)
		local entries, hash = {}, {}
		for i = 1, n do
			local time = SERVER_TIME - 90000 + i
			entries[i] = crateEntry(time, price)
			hash[time] = (tiers and tiers[i]) or TIER_1
		end
		stubHashes(hash)
		return entries
	end

	it(
		"opens each crate from its U1's entry ID: a good, or its payback, in log order; every crate spends its price less"
			.. " its payback, and a crate is never a good purchased (SHOP-R11, SHOP-R50, SHOP-R51)",
		function()
			stubPool()
			-- Crimson; tier 1 again, with it owned: pays 250; Silver; tier 2 again: pays 400; tier 4, no goods in it: pays
			-- 1,500; Prize Foil; Curio again: pays 1,500.
			local world = newWorld(crates(7, { TIER_1, TIER_1, TIER_2, TIER_2, TIER_4, CURIO, CURIO }))
			world.wallet:Report("Ledger", 10000)

			world.enterWorld()

			local state = world.db.projection
			assert.are.same({ CRIMSON, 250, SILVER, 400, 1500, FOIL, 1500 }, state.crates)
			assert.are.equal(7 * 1500 - (250 + 400 + 1500 + 1500), state.spent)
			assert.are.same({}, state.purchased)
			assert.are.same({ true, true, true }, {
				world.goods:IsOwned(CRIMSON),
				world.goods:IsOwned(SILVER),
				world.goods:IsOwned(FOIL), -- by the log, registered or not
			})
			assert.are.equal(10000 - 6850, world.wallet:Get().balance)
			local snapshot = world.snapshots[#world.snapshots]
			assert.are.same(state.crates, snapshot.crates)
			assert.are.same({ [CRIMSON] = true, [SILVER] = true, [FOIL] = true }, snapshot.owned)
			assert.are.equal(1, snapshot.dry)
		end
	)

	it("counts a payback as the entry's price allows, never more than it cost (SHOP-R11, SHOP-R51)", function()
		stubPool()
		-- tier 4 pays min(3,000, 300) at a crate recorded at 300; tier 1 min(250, 200) at one at 200
		local entries = {
			crateEntry(SERVER_TIME - 9000, 300),
			crateEntry(SERVER_TIME - 8000, 200),
			crateEntry(SERVER_TIME - 7000, 2000),
		}
		stubHashes({ [SERVER_TIME - 9000] = TIER_4, [SERVER_TIME - 8000] = TIER_4, [SERVER_TIME - 7000] = TIER_4 })
		local world = newWorld(entries)

		world.enterWorld()

		assert.are.same({ 300, 200, 2000 }, world.db.projection.crates)
		assert.are.equal(
			0,
			world.db.projection.spent,
			"each paid back all it cost: a tier's price is more than it cost"
		)
	end)

	it("counts a Curio crate's payback as the crate's price (SHOP-R51)", function()
		ns.CRATE_POOL = {}
		local world = newWorld(crates(1, { CURIO }, 1500))

		world.enterWorld()

		assert.are.same({ 1500 }, world.db.projection.crates)
		assert.are.equal(0, world.db.projection.spent)
	end)

	it("keeps `dry` as the crates since the last crate-only good: a good or a payback adds one (SHOP-R52)", function()
		stubPool()
		local world = newWorld(crates(4, { TIER_1, TIER_1, CURIO, TIER_1 }))

		world.enterWorld()

		assert.are.same({ CRIMSON, 250, FOIL, 250 }, world.db.projection.crates)
		assert.are.equal(1, world.db.projection.dry)
		local after = newWorld(crates(3, { TIER_1, TIER_1, CURIO }))
		after.enterWorld()
		assert(after.db.projection.dry == nil, "a crate-only good sets it back to 0, left out")
	end)

	it(
		"makes the 100th crate in a row without a crate-only good a Curio crate, and not once none is left (SHOP-R52)",
		function()
			ns.CRATE_POOL = { { id = FOIL, tier = "curio", kind = "toaststyle" } }
			local world = newWorld(crates(99))
			world.enterWorld()
			local state = world.db.projection
			assert.are.equal(99, #state.crates)
			assert.are.equal(99, state.dry)
			for _, result in ipairs(state.crates) do
				assert.are.equal(250, result, "tier 1 has no good: a payback")
			end

			local hundredth = newWorld(crates(100))
			hundredth.enterWorld()
			state = hundredth.db.projection
			assert.are.equal(FOIL, state.crates[100], "the 100th is Curio whatever the hash says")
			assert(state.dry == nil, "and a crate-only good sets the count back")

			local past = newWorld(crates(400))
			past.enterWorld()
			state = past.db.projection
			assert.are.equal(FOIL, state.crates[100])
			for i = 101, 400 do
				assert.are.equal(250, state.crates[i], "no crate-only good is left: no pity at crate " .. i)
			end
			assert.are.equal(300, state.dry)
		end
	)

	it(
		"never gives a good bought before, and gives the same results again on a rebuild (SHOP-R51, ADR 0004)",
		function()
			local entries = { purchaseEntry(SERVER_TIME - 9500, CRIMSON, 150) }
			for i = 1, 12 do
				entries[#entries + 1] = crateEntry(SERVER_TIME - 9000 + i * 10)
			end
			ns.CRATE_POOL = { { id = CRIMSON, tier = 1, kind = "crest" }, { id = SILVER, tier = 2, kind = "crest" } }
			local first = newWorld(entries)
			first.enterWorld()
			local results = first.db.projection.crates
			for _, result in ipairs(results) do
				assert.are_not.equal(CRIMSON, result)
			end
			assert.are.equal(13, #entries)
			assert.are.equal(12, #results)

			local world = newWorld(entries, first.db)
			world.fingerprint = "a new release"
			world.enterWorld()

			assert.are.same(results, world.db.projection.crates)
			assert.are.equal(first.db.projection.dry, world.db.projection.dry)
			assert.are.equal(first.db.projection.spent, world.db.projection.spent)
		end
	)

	it("rebuilds a projection stored under rules version 1 into version 2's results (SHOP-R53, LOG-R72)", function()
		local entries = { crateEntry(SERVER_TIME - 9000, 2000), crateEntry(SERVER_TIME - 8000, 2000) }
		local old = stored(4000, {}, #entries)
		old.rulesVersion = 1
		old.projection.crates = { "core.toaststyle.storm", "core.toaststyle.foil" }
		old.projection.dry = 3
		local world = newWorld(entries, old)

		world.enterWorld()

		assert.are.equal(2, world.db.rulesVersion)
		local state = world.db.projection
		assert.are.equal(2, #state.crates)
		local first = ns.CrateRoll(("%s-%d-0"):format(ADA, SERVER_TIME - 9000), {}, 0, SERVER_TIME - 9000, 2000)
		assert.are.equal(first.good or first.payback, state.crates[1])
	end)

	it("opens a crate bought live at once: its result in, the snapshot handed over (SHOP-R55)", function()
		local world = newWorld({})
		world.wallet:Report("Ledger", 3000)
		world.enterWorld()

		world.live({ kind = "purchase", good = "core.crate", price = PRICE })

		local roll = ns.CrateRoll(("%s-%d-0"):format(ADA, SERVER_TIME), {}, 0, SERVER_TIME, PRICE)
		assert.are.equal(roll.good, world.db.projection.crates[1])
		assert.is_true(world.goods:IsOwned(roll.good))
		assert.are.equal(1500, world.wallet:Get().balance)
		assert.are.same({ roll.good }, world.snapshots[#world.snapshots].crates)
	end)

	it("opens a crate that pays back live: the purse is out only the difference (SHOP-R11, SHOP-R55)", function()
		ns.CRATE_POOL = {}
		local world = newWorld({})
		stubHashes({ [SERVER_TIME] = TIER_1 })
		world.wallet:Report("Ledger", 3000)
		world.enterWorld()

		world.live({ kind = "purchase", good = "core.crate", price = PRICE })

		assert.are.same({ 250 }, world.db.projection.crates)
		assert.are.equal(1250, world.db.projection.spent)
		assert.are.equal(3000 - 1250, world.wallet:Get().balance)
		assert.are.same({ 250 }, world.snapshots[#world.snapshots].crates)
	end)
end)

describe("The wallet projection's Companion entry", function()
	it(
		"marks the companion linked once it applies a K1, replayed or live, and hands it over (SHOP-R29, LOG-R37)",
		function()
			local world = newWorld({ ("K1|1|%d|0|testKey|42"):format(SERVER_TIME - 9000) })

			world.enterWorld()

			assert.is_true(world.db.projection.companion)
			assert.is_true(world.snapshots[#world.snapshots].companion)
			assert.are.equal(0, world.db.projection.spent)

			local live = newWorld({})
			live.enterWorld()
			assert.is_false(live.snapshots[#live.snapshots].companion)
			local handed = #live.snapshots
			live.live({ kind = "companion", keyId = "testKey", pushedSeq = 42 })
			assert.are.equal(handed + 1, #live.snapshots)
			assert.is_true(live.snapshots[#live.snapshots].companion)
		end
	)
end)
