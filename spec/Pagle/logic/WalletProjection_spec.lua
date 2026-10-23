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

			assert.are.same({ spent = 550, purchased = { [CRIMSON] = true, [SILVER] = true } }, world.db.projection)
			assert.are.equal(1, world.db.rulesVersion) -- wallet-and-shop.md › Data: rules version 1
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

		assert.are.same({ spent = 550, purchased = { [CRIMSON] = true, [SILVER] = true } }, world.db.projection)
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
			assert.are.same({ spent = 550, purchased = { [CRIMSON] = true, [SILVER] = true } }, world.db.projection)
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
		assert.are.same({ spent = 550, purchased = { [CRIMSON] = true, [SILVER] = true } }, db.projection)
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

		assert.are.same({ spent = 550, purchased = { [CRIMSON] = true, [SILVER] = true } }, world.db.projection)
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
	local FOIL, STORM, SHAGREEN = "core.toaststyle.foil", "core.toaststyle.storm", "core.binding.shagreenbone"

	-- A crate's U1 at server time `time` (SHOP-R50).
	local function crateEntry(time)
		return purchaseEntry(time, "core.crate", 2000)
	end

	-- The goods crates bought at `times` give, worked out with the draw over each one's entry ID (SHOP-R51).
	local function drawn(times)
		local owned, given, dry = {}, {}, 0
		for i, time in ipairs(times) do
			local good, crateOnly = ns.CrateDraw(("%s-%d-0"):format(ADA, time), owned, dry, time)
			given[i] = good
			if good then
				owned[good] = true
				dry = crateOnly and 0 or dry + 1
			end
		end
		return given
	end

	-- `list` as a sorted copy.
	local function sorted(list)
		local copy = { unpack(list) }
		table.sort(copy)
		return copy
	end

	local TIMES = { SERVER_TIME - 9000, SERVER_TIME - 8000, SERVER_TIME - 7000 }

	it(
		"opens each crate from its U1's entry ID: every crate counts its 2,000, three crates give the three pool goods,"
			.. " never one twice, each owned (SHOP-R11, SHOP-R50, SHOP-R51)",
		function()
			local world =
				newWorld({ crateEntry(TIMES[1]), castEntry(TIMES[1] + 1), crateEntry(TIMES[2]), crateEntry(TIMES[3]) })
			world.wallet:Report("Ledger", 7000)

			world.enterWorld()

			local state = world.db.projection
			assert.are.equal(6000, state.spent)
			assert.are.same({}, state.purchased, "a crate is never a good purchased")
			assert.are.same(drawn(TIMES), state.crates)
			assert.are.same({ SHAGREEN, FOIL, STORM }, sorted(state.crates))
			assert.are.same({ true, true }, { world.goods:IsOwned(FOIL), world.goods:IsOwned(STORM) })
			assert(world.goods:IsOwned(SHAGREEN), "owned by the log, registered or not")
			assert.are.equal(1000, world.wallet:Get().balance)
			local snapshot = world.snapshots[#world.snapshots]
			assert.are.same(state.crates, snapshot.crates)
			assert.are.same({ [FOIL] = true, [STORM] = true, [SHAGREEN] = true }, snapshot.owned)
		end
	)

	it("counts a crate bought with nothing left to give, giving nothing (SHOP-R11, SHOP-R50)", function()
		local world = newWorld({
			crateEntry(TIMES[1]),
			crateEntry(TIMES[2]),
			crateEntry(TIMES[3]),
			crateEntry(SERVER_TIME - 6000), -- only by a race: Buy is gone once the crate is empty (SHOP-R54)
		})

		world.enterWorld()

		assert.are.equal(8000, world.db.projection.spent)
		assert.are.equal(3, #world.db.projection.crates)
	end)

	it("never gives a good bought before, and gives the same goods again on a rebuild (SHOP-R51, ADR 0004)", function()
		local entries = { purchaseEntry(SERVER_TIME - 9500, STORM, 5000), crateEntry(TIMES[1]), crateEntry(TIMES[2]) }
		local first = newWorld(entries)
		first.enterWorld()
		local crates = first.db.projection.crates
		assert.are.same({ SHAGREEN, FOIL }, sorted(crates))

		local world = newWorld(entries, first.db)
		world.fingerprint = "a new release"
		world.enterWorld()

		assert.are.same(crates, world.db.projection.crates)
		assert.are.equal(9000, world.db.projection.spent)
	end)

	it("opens a crate bought live at once: its good owned, the snapshot handed over (SHOP-R55)", function()
		local world = newWorld({})
		world.wallet:Report("Ledger", 3000)
		world.enterWorld()

		world.live({ kind = "purchase", good = "core.crate", price = 2000 })

		local given = world.db.projection.crates[1]
		assert.are.equal(drawn({ SERVER_TIME })[1], given)
		assert.is_true(world.goods:IsOwned(given))
		assert.are.equal(1000, world.wallet:Get().balance)
		assert.are.same({ given }, world.snapshots[#world.snapshots].crates)
	end)

	it(
		"counts the crates in a row without a crate-only good, and gives one by the 8th at the latest (SHOP-R52)",
		function()
			local pool = ns.CRATE_POOL
			-- A pool grown long, where a crate-only good is rare: one good in nineteen weights.
			local grown = { { id = FOIL, crateOnly = true } }
			for i = 1, 9 do
				grown[#grown + 1] = { id = "core.toaststyle.extra" .. i }
			end
			ns.CRATE_POOL = grown
			local ok, problem = pcall(function()
				for start = 0, 40 do
					local entries = {}
					for i = 1, 8 do
						entries[i] = crateEntry(SERVER_TIME - 90000 + start * 100 + i)
					end
					local world = newWorld(entries)
					world.enterWorld()
					local crates = world.db.projection.crates
					local at
					for i, good in ipairs(crates) do
						at = at or (good == FOIL and i or nil)
					end
					assert(at and at <= 8, "a crate-only good by the 8th crate")
					assert(world.db.projection.dry == (#crates > at and #crates - at or nil), "dry counts from it")
				end
			end)
			ns.CRATE_POOL = pool
			assert(ok, problem)
		end
	)
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
