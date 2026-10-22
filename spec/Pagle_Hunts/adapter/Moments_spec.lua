-- Hunts' moments (HNT-R85–R87, HNT-R89–R91, HNT-R111, HNT-R112, HNT-R190–R192, HNT-R194; LOG-R73–R77, LOG-R90;
-- ANN-R4, ANN-R10, ANN-R12, ANN-R60, ANN-R63) on FakePagle, over the fixture Hunt list and catalogue: the
-- Announcements, Write-up sections and Session summary Core would make from what Hunts raises.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local cast, append, fishAt = hunts.cast, hunts.append, hunts.fishAt
local NIGHT, DAY, DUSK = hunts.NIGHT, hunts.DAY, hunts.DUSK
local RACK_AURA, UNCOMMON = C.RACK_AURA, C.UNCOMMON -- fixture_rack's aura, and a member of its class
local TRADE_FISHING = "Interface\\Icons\\Trade_Fishing"

local ELWYNN = { zone = C.ELWYNN }
local DARKSHORE = { zone = C.DARKSHORE }
local WESTFALL = { zone = C.WESTFALL }

-- Pagle_Hunts logged in over `history` on the fixture catalogue; fixture_tide_late is named "Late Tide".
---@param history (fun(fake: table): any)?
---@param options { prepare: fun(loaded: LoadedAddon)?, fake: table? }?
---@return LoadedAddon loaded
---@return table fake
---@return any appended
local function login(history, options)
	options = options or {}
	return hunts.login(history, {
		fake = options.fake,
		prepare = function(loaded)
			loaded.ns.L["hunt.fixture_tide_late.name"] = "Late Tide"
			if options.prepare then
				options.prepare(loaded)
			end
		end,
	})
end

-- The fields a Hunts moment sets, of each moment Core kept from Hunts, in order (fake.summarized).
---@param fake table
---@return table[]
local function kept(fake)
	local out = {}
	for _, moment in ipairs(fake.summarized) do
		if moment.module == "Hunts" then
			out[#out + 1] = {
				rung = moment.rung,
				kind = moment.kind,
				title = moment.title,
				text = moment.text,
				stamp = moment.stamp,
				icon = moment.icon,
				coins = moment.coins,
				cast = moment.cast,
				summaryOnly = moment.summaryOnly,
				seal = moment.seal,
			}
		end
	end
	return out
end

-- Each Write-up section Hunts raised, as its heading followed by its lines.
---@param fake table
---@return string[][]
local function writeUps(fake)
	local sections = {}
	for _, section in ipairs(fake.writeUps) do
		if section.module == "Hunts" then
			sections[#sections + 1] = { section.heading, unpack(section.lines) }
		end
	end
	return sections
end

-- Nine Nightfin in Elwynn in March, before fixture_tide_late's since: fixture_snapper done, one short of tier 2.
local function nineNightfin(fake)
	local records = {}
	for i = 1, 9 do
		records[i] = cast(0, NIGHT + i, ELWYNN, { C.NIGHTFIN })
	end
	return append(fake, records)
end

describe("Hunts' moments", function()
	describe("in a live apply (HNT-R85, HNT-R86, HNT-R91)", function()
		it("raise a completion and a further tier for one Catch, on its Cast, and nothing for the next", function()
			local loaded, fake = login(nineNightfin)
			fishAt(fake, NIGHT, ELWYNN)

			-- Today's Nightfin is fixture_snapper's 10th (tier 2) and Late Tide's first (its since is 2026-04-01).
			local live = fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
			fake.nextFrame()

			assert.are.same({
				{
					rung = "toast.high",
					kind = "huntTier",
					title = "Silver tier",
					text = "Snapper Run · 10 caught",
					stamp = "Silver",
					icon = C.NIGHTFIN,
					coins = 15,
					cast = live.id,
				},
				{
					rung = "toast.high",
					kind = "huntCompleted",
					title = "Hunt complete",
					text = "Late Tide",
					stamp = "Hunt",
					icon = C.NIGHTFIN,
					coins = 30,
					cast = live.id,
				},
			}, kept(fake))
			-- One Announcement for the Cast, both moments merged into it (ANN-R10, ANN-R23).
			assert.are.equal(1, #fake.announcements)
			assert.are.same({ live.id, 45 }, { fake.announcements[1].cast, fake.announcements[1].coins })
			assert.are.same(
				{ fixture_snapper = 2, fixture_tide_late = 1 },
				loaded.env.PagleHuntsDB.global.celebrated.tiers
			)

			-- A second Nightfin reaches no tier: nothing new (HNT-R91).
			fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
			fake.nextFrame()
			assert.are.equal(2, #kept(fake))
			assert.are.equal(1, #fake.announcements)
		end)

		it("raise a set title from a Catch as a banner on that Cast (HNT-R86, HNT-R87)", function()
			-- fixture_oddity done; fixture_grouper doesn't exist yet, so fixture_rack completes fixture_wagers.
			local loaded, fake = login(function(fake)
				append(fake, { cast(2, DUSK, DARKSHORE, { C.DEVIATE }) })
			end)
			fishAt(fake, DAY, WESTFALL, { RACK_AURA })

			local live = fake.playCast("caught", { { itemID = UNCOMMON, quantity = 1 } })
			fake.nextFrame()

			local moments = kept(fake)
			assert.are.same({ "huntCompleted", "fixture_rack" }, { moments[1].kind, moments[1].text })
			assert.are.same({
				rung = "banner",
				kind = "huntSetTitle",
				title = "Title earned",
				-- fixture_wagers has no title in the lore, so its ID stands in (HNT-R1).
				text = "fixture_wagers",
				stamp = "Title",
				icon = TRADE_FISHING,
				coins = 100,
				seal = "quill",
				cast = live.id,
			}, moments[2])
			-- The Cast's two Announcements, the big side first: the banner, then the completion's toast (ANN-R10,
			-- ANN-R11), each with its own Coins.
			assert.are.equal(2, #fake.announcements)
			local banner, toast = fake.announcements[1], fake.announcements[2]
			-- The banner's seal is the quill (announcements.md › Contracts).
			assert.are.same(
				{ "Title earned", {}, 100, "quill" },
				{ banner.headline.title, banner.stamps, banner.coins, banner.headline.seal }
			)
			assert.are.same({ "Hunt complete", {}, 30 }, { toast.headline.title, toast.stamps, toast.coins })
			assert.are.same({ fixture_wagers = true }, loaded.env.PagleHuntsDB.global.celebrated.sets)
		end)

		it(
			"raise a title a retirement completed, found by a live apply, summary-only with no cast (HNT-R87)",
			function()
				-- fixture_hefty_blackmouth retires a minute from now, fixture_sunscale retired in June: fixture_snapper,
				-- done in March, is then fixture_dusk's only Hunt (HNT-R20, HNT-R197).
				local _, fake = login(function(fake)
					append(fake, { cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }) })
				end, {
					prepare = function(loaded)
						loaded.ns.huntList.hunts[4].retired = SERVER_TIME + 60
					end,
				})
				fishAt(fake, NIGHT, ELWYNN)
				fake.wait(120)

				fake.playCast("gotAway")
				fake.nextFrame()

				assert.are.same({
					{
						rung = "banner",
						kind = "huntSetTitle",
						title = "Title earned",
						text = "the Duskwatcher",
						stamp = "Title",
						icon = TRADE_FISHING,
						coins = 100,
						seal = "quill",
						summaryOnly = true,
					},
				}, kept(fake))
				-- It never pops up (ANN-R63).
				assert.are.same({}, fake.announcements)
			end
		)
	end)

	describe("at a first build (HNT-R111, HNT-R192)", function()
		-- A Nightfin (fixture_snapper), a Deviate Fish in fixture_oddity's hours, then five uncommon items under the
		-- Rack's aura (fixture_rack's tiers 1 and 5), completing fixture_wagers.
		local function earning(fake)
			return append(fake, {
				cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }),
				cast(1, DUSK, DARKSHORE, { C.DEVIATE }),
				cast(2, DAY, WESTFALL, { UNCOMMON, UNCOMMON, UNCOMMON, UNCOMMON, UNCOMMON }, { RACK_AURA }),
			})
		end

		it("writes up what the history earned in one section, raises no moment and marks it all", function()
			local loaded, fake = login(earning)

			assert.are.same({
				{
					"Your Hunts were written up from 3 Casts",
					"3 Hunts completed",
					"1 further tier",
					"Title: fixture_wagers",
					"Pagle Coins +205",
					-- Standing Hunts pay Activity XP too: 500 at tier 1, 250 a further tier (HNT-R113, HNT-R111).
					"Angler XP +1,750",
				},
			}, writeUps(fake))
			assert.are.same({}, kept(fake))
			assert.are.same({
				tiers = { fixture_snapper = 1, fixture_oddity = 1, fixture_rack = 2 },
				sets = { fixture_wagers = true },
				runs = {},
				ladder = {},
				goods = { ["hunts.binding.pathfinder"] = true }, -- noted once its rule held (HNT-R122)
			}, loaded.env.PagleHuntsDB.global.celebrated)

			-- Already celebrated: the next Nightfin, fixture_snapper's second, raises nothing (HNT-R91).
			fishAt(fake, NIGHT, ELWYNN)
			fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
			fake.nextFrame()
			assert.are.same({ "huntCompleted", "Late Tide" }, { kept(fake)[1].kind, kept(fake)[1].text })
			assert.are.equal(1, #kept(fake))
		end)

		it("writes the Casts and Coins as the client groups numbers, in the singular for one", function()
			local _, fake = login(function(fake)
				append(fake, { cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }) })
			end, {
				prepare = function(loaded)
					loaded.ns.COINS_COMPLETED = 1234
				end,
			})

			assert.are.same({
				{
					"Your Hunts were written up from 1 Cast",
					"1 Hunt completed",
					"Pagle Coins +1,234",
					"Angler XP +500",
				},
			}, writeUps(fake))
		end)

		it("raises nothing for a fresh install with no Casts, nor for Casts that earned nothing", function()
			local loaded, fake = login(nil)
			local _, quiet = login(function(other)
				append(other, { cast(0, NIGHT, ELWYNN), cast(0, NIGHT + 1, WESTFALL, { C.SMALLFISH }) })
			end)

			assert.are.same({ {}, {} }, { writeUps(fake), kept(fake) })
			assert.are.same(
				{ tiers = {}, sets = {}, runs = {}, ladder = {} },
				loaded.env.PagleHuntsDB.global.celebrated
			)
			assert.are.same({ {}, {} }, { writeUps(quiet), kept(quiet) })
		end)
	end)

	-- The next login over the last one's log and PagleHuntsDB, with `between` appended first: Casts recorded while
	-- Hunts was off (HNT-R190).
	---@param last table
	---@param lastLoaded LoadedAddon
	---@param between table[]?
	---@param prepare fun(loaded: LoadedAddon)?
	local function nextLogin(last, lastLoaded, between, prepare)
		return login(function(fake)
			append(fake, between or {})
		end, { fake = hunts.nextLogin(last, lastLoaded), prepare = prepare })
	end

	describe("at a catch-up (HNT-R111, HNT-R112, HNT-R190)", function()
		it("writes up what the Casts while Hunts was off earned, with no pop-up, and marks it", function()
			local lastLoaded, last = login(function(fake)
				append(fake, { cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }) })
			end)

			-- fixture_oddity and fixture_rack complete fixture_wagers while Hunts is off.
			local loaded, fake = nextLogin(last, lastLoaded, {
				cast(2, DUSK, DARKSHORE, { C.DEVIATE }),
				cast(3, DAY, WESTFALL, { UNCOMMON }, { RACK_AURA }),
			})

			assert.are.same({
				{
					"While Hunts was off",
					"2 Hunts completed",
					"Title: fixture_wagers",
					"Pagle Coins +160",
					"Angler XP +1,000",
				},
			}, writeUps(fake))
			assert.are.same({ {}, {} }, { kept(fake), fake.announcements })
			assert.are.same({
				tiers = { fixture_snapper = 1, fixture_oddity = 1, fixture_rack = 1 },
				sets = { fixture_wagers = true },
				runs = {},
				ladder = {},
				goods = { ["hunts.binding.pathfinder"] = true }, -- noted once its rule held (HNT-R122)
			}, loaded.env.PagleHuntsDB.global.celebrated)
		end)

		it("raises a title a retirement completed summary-only, never in the section (HNT-R87)", function()
			local lastLoaded, last = login(function(fake)
				append(fake, { cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }) })
			end)

			-- fixture_hefty_blackmouth's retired date, 2026-06-01, has passed by the next login: with fixture_sunscale
			-- retired then too, fixture_snapper alone completes fixture_dusk (HNT-R20, HNT-R197).
			local loaded, fake = nextLogin(
				last,
				lastLoaded,
				{ cast(2, DUSK, DARKSHORE, { C.DEVIATE }) },
				function(loaded)
					loaded.ns.huntList.hunts[4].retired = hunts.JUN_1
				end
			)

			assert.are.same(
				{ { "While Hunts was off", "1 Hunt completed", "Pagle Coins +30", "Angler XP +500" } },
				writeUps(fake)
			)
			assert.are.same({
				{
					rung = "banner",
					kind = "huntSetTitle",
					title = "Title earned",
					text = "the Duskwatcher",
					stamp = "Title",
					icon = TRADE_FISHING,
					coins = 100,
					seal = "quill",
					summaryOnly = true,
				},
			}, kept(fake))
			assert.are.same({}, fake.announcements)
			assert.is_true(loaded.env.PagleHuntsDB.global.celebrated.sets.fixture_dusk)
		end)

		it("raises nothing at a login with nothing new (LOG-R76)", function()
			local lastLoaded, last = login(function(fake)
				append(fake, { cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }) })
			end)

			local _, fake = nextLogin(last, lastLoaded)

			assert.are.same({ {}, {} }, { writeUps(fake), kept(fake) })
		end)
	end)

	describe("at a rebuild (HNT-R112, HNT-R190, HNT-R191)", function()
		it("raises what is newly earned as summary-only moments, never a section, and never lowers the set", function()
			-- fixture_snapper done; four uncommon items and a Smallfish under the Rack's aura: fixture_rack done, at 4.
			local lastLoaded, last = login(function(fake)
				append(fake, {
					cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }),
					cast(1, DAY, WESTFALL, { UNCOMMON, UNCOMMON, UNCOMMON, UNCOMMON }, { RACK_AURA }),
					cast(1, DAY + 1, WESTFALL, { C.SMALLFISH }, { RACK_AURA }),
				})
			end)
			local saved = lastLoaded.env.PagleHuntsDB.global.celebrated
			-- A tier shown before that this history no longer reaches (possible only before 1.0).
			saved.tiers.fixture_snapper = 3

			-- While Hunts was off: a Deviate Fish, and a release whose Hunt list makes the Smallfish uncommon.
			local loaded, fake = nextLogin(
				last,
				lastLoaded,
				{ cast(2, DUSK, DARKSHORE, { C.DEVIATE }) },
				function(loaded)
					loaded.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
					loaded.ns.huntList.classes["quality.uncommon"][C.SMALLFISH] = true
				end
			)

			assert.are.same({}, writeUps(fake))
			assert.are.same({}, fake.announcements)
			assert.are.same({
				{
					rung = "toast.high",
					kind = "huntCompleted",
					title = "Hunt complete",
					text = "Oddity Hour",
					stamp = "Hunt",
					icon = C.DEVIATE,
					coins = 30,
					summaryOnly = true,
				},
				{
					rung = "toast.high",
					kind = "huntTier",
					title = "Silver tier",
					text = "fixture_rack · 5 caught",
					stamp = "Silver",
					icon = C.SMALLFISH,
					coins = 15,
					summaryOnly = true,
				},
				{
					rung = "banner",
					kind = "huntSetTitle",
					title = "Title earned",
					text = "fixture_wagers",
					stamp = "Title",
					icon = TRADE_FISHING,
					coins = 100,
					seal = "quill",
					summaryOnly = true,
				},
			}, kept(fake))
			assert.are.same({
				tiers = { fixture_snapper = 3, fixture_oddity = 1, fixture_rack = 2 },
				sets = { fixture_wagers = true },
				runs = {},
				ladder = {},
				goods = { ["hunts.binding.pathfinder"] = true }, -- noted once its rule held (HNT-R122)
			}, loaded.env.PagleHuntsDB.global.celebrated)
		end)
	end)

	describe("the summary line (HNT-R89)", function()
		-- Hunts' Session summary line as Core holds it, or nil.
		local function line(fake)
			local lines = fake.global.summary.lines.Hunts
			return lines and lines.lines.hunts
		end

		it("is set first from done, with lifetime numbers over the current Hunts", function()
			-- fixture_snapper, fixture_oddity and fixture_rack done, fixture_wagers' title. Current now: every fixture
			-- Hunt but the two retired and fixture_grouper, whose since is ahead (HNT-R2).
			local _, fake = login(function(fake)
				append(fake, {
					cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }),
					cast(1, DUSK, DARKSHORE, { C.DEVIATE }),
					cast(2, DAY, WESTFALL, { UNCOMMON }, { RACK_AURA }),
				})
			end)

			assert.are.equal("Hunts: 3 of 8 done · 1 title", line(fake))
		end)

		it("is never set while the projection is updating, then at every redraw", function()
			local fake = newFakePagle()
			fake.setCatalogue(C.base())
			local loaded = hunts.load(fake)
			fake.login()
			loaded.ns.Redraw("groups")
			assert.is_nil(line(fake))

			fake.enterWorld()
			assert.are.equal("Hunts: 0 of 8 done · 0 titles", line(fake))

			-- A live Catch completes two Hunts (fixture_snapper and fixture_tide_late): the projection's redraw.
			fishAt(fake, NIGHT, ELWYNN)
			fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
			assert.are.equal("Hunts: 2 of 8 done · 0 titles", line(fake))

			-- fixture_grouper's since comes: the regroup's redraw counts it current.
			loaded.ns.huntList.hunts[6].since = SERVER_TIME
			loaded.ns.Redraw("groups")
			assert.are.equal("Hunts: 2 of 9 done · 0 titles", line(fake))
		end)

		it("counts titles in the plural, Retired Hunts' completions not among the current", function()
			-- fixture_sunscale (retired) done; fixture_wagers and, with fixture_hefty_blackmouth retired in June,
			-- fixture_dusk earned.
			local _, fake = login(function(fake)
				append(fake, {
					cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }),
					cast(0, DAY, ELWYNN, { C.SUNSCALE }),
					cast(1, DUSK, DARKSHORE, { C.DEVIATE }),
					cast(2, DAY, WESTFALL, { UNCOMMON }, { RACK_AURA }),
				})
			end, {
				prepare = function(loaded)
					loaded.ns.huntList.hunts[4].retired = hunts.JUN_1
				end,
			})

			-- Current: 7 (fixture_hefty_blackmouth retired too); done among them: snapper, oddity, rack.
			assert.are.equal("Hunts: 3 of 7 done · 2 titles", line(fake))
		end)
	end)

	it("celebrates again a tier reached only by a Catch a crash lost, once reached for real (HNT-R194)", function()
		local lastLoaded, last = login(function(fake)
			append(fake, { cast(0, NIGHT, ELWYNN, { C.NIGHTFIN }) })
		end)
		-- What the last save held: the log and PagleHuntsDB before the next Cast.
		local copy = hunts.deepCopy
		local savedLog, savedGlobal = copy(last.catchLog.data), copy(lastLoaded.env.PagleHuntsDB.global)
		fishAt(last, NIGHT, ELWYNN)
		last.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
		assert.are.equal(1, lastLoaded.env.PagleHuntsDB.global.celebrated.tiers.fixture_tide_late)

		-- The crash: the next login has the last save's log and celebrated set.
		local fake = newFakePagle()
		fake.catchLog.data = savedLog
		fake.globals.PagleHuntsDB = { global = savedGlobal }
		local loaded = login(nil, { fake = fake })
		assert.is_nil(loaded.ns.State().hunts.fixture_tide_late)
		fishAt(fake, NIGHT, ELWYNN)
		fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })

		assert.are.same({ { "huntCompleted", "Late Tide" } }, {
			{ kept(fake)[1].kind, kept(fake)[1].text },
		})
	end)
end)
