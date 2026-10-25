-- Pagle Wagers' moments (HNT-R85, HNT-R86's wager rows, HNT-R89–R92, HNT-R110–R112, HNT-R114, HNT-R148, HNT-R149;
-- ANN-R4, ANN-R10, ANN-R23, ANN-R63; LOG-R76, LOG-R77) on FakePagle, over the fixture Hunt list, event pool and
-- catalogue: the Announcements, Write-up sections and Session summary Core would make from what Hunts raises for
-- event Hunts' marks, settled runs and ladder titles.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local MARCH_1, NIGHT, DAY_MINUTE, DUSK = hunts.MARCH_1, hunts.NIGHT, hunts.DAY, hunts.DUSK
local cast, append, record, runPayload, fishAt = hunts.cast, hunts.append, hunts.record, hunts.runPayload, hunts.fishAt
local TRADE_FISHING = "Interface\\Icons\\Trade_Fishing"

local DARKSHORE = { zone = C.DARKSHORE }
local ELWYNN = { zone = C.ELWYNN }

-- A Cast as support.cast makes it, at exactly server time `time` (its realm minute left as given).
local function castAt(time, minute, where, itemIDs)
	local entry = cast(0, minute, where, itemIDs)
	entry.time = time
	return entry
end

-- A `run` record of `event` over [start, end_), logged at its start.
local function runRecord(event, start, end_)
	return record("run", runPayload(event, start, end_), start)
end

-- A run of fixture_vale over [start, end_), completed by one Cast in Elwynn an hour in (a Blackmouth and an uncommon
-- item: each of its three Hunts' tier 1, HNT-R146).
local function valeRun(start, end_)
	return {
		runRecord("fixture_vale", start, end_),
		castAt(start + 60, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON }),
	}
end

-- `records` with each list in `lists` appended.
local function joined(lists)
	local out = {}
	for _, list in ipairs(lists) do
		for _, entry in ipairs(list) do
			out[#out + 1] = entry
		end
	end
	return out
end

local function login(history, options)
	return hunts.login(history, options)
end

-- The next login over the last one's log and PagleHuntsDB, with `between` appended first (Casts and records while
-- Hunts was off, HNT-R190), `prepare`d.
local function nextLogin(last, lastLoaded, between, prepare)
	return login(function(fake)
		append(fake, between or {})
	end, { fake = hunts.nextLogin(last, lastLoaded), prepare = prepare })
end

-- A release with a new Hunt list fingerprint, which rebuilds the projection (LOG-R72, HNT-R191).
local function release(loaded)
	loaded.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
end

local WAGER_KINDS = { wagerMark = true, wagerTier = true, wagerSettled = true, wagerTitle = true }

-- The fields a wager moment sets, of each Pagle Wagers moment Core kept from Hunts, in order (fake.summarized).
local function wagers(fake)
	local out = {}
	for _, moment in ipairs(fake.summarized) do
		if moment.module == "Hunts" and WAGER_KINDS[moment.kind] then
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

-- The kind of each moment Core kept from Hunts, in order.
local function kinds(fake)
	local out = {}
	for _, moment in ipairs(fake.summarized) do
		if moment.module == "Hunts" then
			out[#out + 1] = moment.kind
		end
	end
	return out
end

-- Each Write-up section Hunts raised, as its heading followed by its lines.
local function writeUps(fake)
	local sections = {}
	for _, section in ipairs(fake.writeUps) do
		if section.module == "Hunts" then
			sections[#sections + 1] = { section.heading, unpack(section.lines) }
		end
	end
	return sections
end

-- Hunts' Session summary line as Core holds it, or nil.
local function line(fake)
	local lines = fake.global.summary.lines.Hunts
	return lines and lines.lines.hunts
end

local function celebrated(loaded)
	return loaded.env.PagleHuntsDB.global.celebrated
end

-- A first mark's moment, as HNT-R86 has it.
local function mark(huntName, icon, castID)
	return {
		rung = "toast",
		kind = "wagerMark",
		title = "Pagle Wagers",
		text = huntName .. " · first mark",
		stamp = "Mark",
		icon = icon,
		coins = 8,
		cast = castID,
	}
end

describe("Pagle Wagers' moments", function()
	describe("in a live apply (HNT-R85, HNT-R86, HNT-R91)", function()
		it("raise a first mark on its Cast, nothing for it again, and again in the event's next run", function()
			local loaded, fake = login()
			local start = SERVER_TIME - HOUR
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_vale", start, start + 2 * HOUR))
			fishAt(fake, DAY_MINUTE, ELWYNN)

			-- An uncommon item: fixture_vale_uncommon's tier 1, and no other Hunt's (the fixture pool's header).
			local live = fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fake.nextFrame()

			assert.are.same({ mark("fixture_vale_uncommon", C.UNCOMMON, live.id) }, wagers(fake))
			-- One Announcement for the Cast, with the mark's Coins (ANN-R10, ANN-R23).
			assert.are.equal(1, #fake.announcements)
			assert.are.same({ live.id, 8 }, { fake.announcements[1].cast, fake.announcements[1].coins })
			-- The celebrated set's run entry, by run key, with the run's end (HNT-R90, HNT-R92).
			assert.are.same({
				["fixture_vale@" .. start] = { tiers = { fixture_vale_uncommon = 1 }, endsAt = start + 2 * HOUR },
			}, celebrated(loaded).runs)

			-- A second one in the same run reaches nothing new (HNT-R91).
			fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fake.nextFrame()
			assert.are.equal(1, #wagers(fake))

			-- The next run of the event starts at 0 and pays again (HNT-R145): the same tier is raised again.
			fake.wait(2 * HOUR)
			local next = start + 2 * HOUR
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_vale", next, next + 3 * DAY))
			local again = fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fake.nextFrame()

			assert.are.same({
				mark("fixture_vale_uncommon", C.UNCOMMON, live.id),
				mark("fixture_vale_uncommon", C.UNCOMMON, again.id),
			}, wagers(fake))
		end)

		it("raise each mark, then the settled run, on the Cast that completes it, after the Standing Hunts", function()
			local loaded, fake = login()
			local start = SERVER_TIME - HOUR
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_shore", start, start + 3 * DAY))
			fishAt(fake, DUSK, DARKSHORE)

			-- A Nightfin and a Deviate Fish at dusk in Darkshore: the Haul's tier 1 (2), the Named fish's and the Timed
			-- oddity's, completing the run (HNT-R146); and the Standing Hunts they complete.
			local live =
				fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 }, { itemID = C.DEVIATE, quantity = 1 } })
			fake.nextFrame()

			assert.are.same({
				-- The Haul's tier 1 is its second Catch, the Deviate Fish (HNT-R55).
				mark("fixture_shore_haul", C.DEVIATE, live.id),
				mark("Shore Snapper", C.NIGHTFIN, live.id),
				mark("fixture_shore_oddity", C.DEVIATE, live.id),
				{
					rung = "toast.high",
					kind = "wagerSettled",
					title = "Wager settled",
					text = "Shore Wager",
					stamp = "Settled",
					-- The event's icon is its first Hunt's (HNT-R161): the Haul's, any fish, so Trade_Fishing (HNT-R55).
					icon = TRADE_FISHING,
					coins = 25,
					cast = live.id,
				},
			}, wagers(fake))
			-- The Standing Hunts' moments come first, then the wagers', in the order reached (HNT-R86, HNT-R137).
			local all = kinds(fake)
			assert.are.same({ "wagerMark", "wagerMark", "wagerMark", "wagerSettled" }, { unpack(all, #all - 3) })
			for i = 1, #all - 4 do
				assert.is_nil(WAGER_KINDS[all[i]])
			end
			-- Every moment of the Cast merges into one Announcement (ANN-R10).
			assert.are.equal(1, #fake.announcements)
			assert.are.same({
				tiers = {
					fixture_shore_haul = 1,
					fixture_shore_snapper = 1,
					fixture_shore_oddity = 1,
				},
				settled = true,
				endsAt = start + 3 * DAY,
			}, celebrated(loaded).runs["fixture_shore@" .. start])
		end)

		it("raise a further mark as a quiet toast with its trim", function()
			local loaded, fake = login()
			local start = SERVER_TIME - HOUR
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_vale", start, start + 3 * DAY))
			fishAt(fake, DAY_MINUTE, ELWYNN)
			fake.playCast("caught", { { itemID = C.BLACKMOUTH, quantity = 1 } })

			-- Two more Blackmouth: the Haul's third Catch, its tier 2 (1 / 3).
			local live = fake.playCast(
				"caught",
				{ { itemID = C.BLACKMOUTH, quantity = 1 }, { itemID = C.BLACKMOUTH, quantity = 1 } }
			)
			fake.nextFrame()

			local moments = wagers(fake)
			assert.are.same({
				rung = "toast.low",
				kind = "wagerTier",
				title = "Silver mark",
				text = "fixture_vale_haul · 3 caught",
				stamp = "Silver",
				icon = C.BLACKMOUTH,
				coins = 5,
				cast = live.id,
			}, moments[#moments])
			assert.are.equal(2, celebrated(loaded).runs["fixture_vale@" .. start].tiers.fixture_vale_haul)
		end)

		it("raise the ladder title at the 25th settled run as a banner with no Coins (HNT-R86, HNT-R148)", function()
			-- 24 runs completed in March, then a 25th on now.
			local loaded, fake = login(function(fake)
				local runs = {}
				for i = 0, 23 do
					local start = MARCH_1 + i * 2 * HOUR
					runs[#runs + 1] = valeRun(start, start + HOUR)
				end
				append(fake, joined(runs))
			end)
			assert.are.same({}, wagers(fake))
			local start = SERVER_TIME - HOUR
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_vale", start, start + 3 * DAY))
			fishAt(fake, DAY_MINUTE, ELWYNN)

			local live = fake.playCast(
				"caught",
				{ { itemID = C.BLACKMOUTH, quantity = 1 }, { itemID = C.UNCOMMON, quantity = 1 } }
			)
			fake.nextFrame()

			assert.are.same({ "wagerMark", "wagerMark", "wagerMark", "wagerSettled", "wagerTitle" }, kinds(fake))
			assert.are.same({
				rung = "banner",
				kind = "wagerTitle",
				title = "Title earned",
				text = "Bookmaker's Bane",
				stamp = "Title",
				icon = TRADE_FISHING,
				seal = "quill",
				cast = live.id,
			}, wagers(fake)[5])
			-- The Cast's two Announcements, the banner first (ANN-R10, ANN-R11): the title pays no Coins (HNT-R110).
			assert.are.equal(2, #fake.announcements)
			local banner, toast = fake.announcements[1], fake.announcements[2]
			assert.are.same(
				{ "Title earned", "Bookmaker's Bane", "quill" },
				{ banner.headline.title, banner.headline.text, banner.headline.seal }
			)
			assert.are.equal(0, banner.coins or 0)
			assert.are.equal(3 * 8 + 25, toast.coins)
			assert.are.same({ [25] = true }, celebrated(loaded).ladder)
		end)

		it("raise what a run record credits late summary-only, with no cast, and mark it (HNT-R149)", function()
			-- A Blackmouth and an uncommon item in Elwynn, three hours ago, before Hunts knew of the run.
			local loaded, fake = login(function(fake)
				append(fake, { castAt(SERVER_TIME - 3 * HOUR, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON }) })
			end)
			local start = SERVER_TIME - 5 * HOUR

			loaded.ns.Module:AppendRecord("run", runPayload("fixture_vale", start, start + 3 * DAY))
			fake.nextFrame()

			local function summaryOnly(moment)
				moment.cast, moment.summaryOnly = nil, true
				return moment
			end
			assert.are.same({
				summaryOnly(mark("fixture_vale_haul", C.BLACKMOUTH)),
				summaryOnly(mark("fixture_vale_blackmouth", C.BLACKMOUTH)),
				summaryOnly(mark("fixture_vale_uncommon", C.UNCOMMON)),
				{
					rung = "toast.high",
					kind = "wagerSettled",
					title = "Wager settled",
					text = "fixture_vale",
					stamp = "Settled",
					icon = TRADE_FISHING,
					coins = 25,
					summaryOnly = true,
				},
			}, wagers(fake))
			-- They never pop up (ANN-R63).
			assert.are.same({}, fake.announcements)
			assert.is_true(celebrated(loaded).runs["fixture_vale@" .. start].settled)
		end)
	end)

	describe("from done (HNT-R92, HNT-R111, HNT-R112)", function()
		it("writes a first build's settled runs and Angler XP, and raises no moment", function()
			-- One fixture_vale run completed in March: three first marks (8 Coins, 150 XP each) and the run (25, 250).
			local loaded, fake = login(function(fake)
				append(fake, valeRun(MARCH_1, MARCH_1 + DAY))
			end)

			assert.are.same({
				{ "Your Hunts were written up from 1 Cast", "1 wager settled", "Pagle Coins +49", "Angler XP +700" },
			}, writeUps(fake))
			assert.are.same({}, wagers(fake))
			-- The run ended more than 30 days ago, so it keeps no celebrated entry (HNT-R92).
			assert.are.same({}, celebrated(loaded).runs)
		end)

		it("writes what a catch-up settled under While Hunts was off, with Angler XP, and marks it", function()
			local lastLoaded, last = login(function(fake)
				append(fake, { cast(0, NIGHT, ELWYNN) })
			end)
			assert.are.equal("Hunts: 0 of 8 done · 0 titles", line(last))

			-- Two fixture_vale runs this week, each completed while Hunts was off.
			local first, second = SERVER_TIME - 6 * DAY, SERVER_TIME - 4 * DAY
			local loaded, fake =
				nextLogin(last, lastLoaded, joined({ valeRun(first, first + DAY), valeRun(second, second + DAY) }))

			assert.are.same({
				{ "While Hunts was off", "2 wagers settled", "Pagle Coins +98", "Angler XP +1,400" },
			}, writeUps(fake))
			assert.are.same({ {}, {} }, { wagers(fake), fake.announcements })
			local runs = celebrated(loaded).runs
			assert.are.same(
				{ true, true },
				{ runs["fixture_vale@" .. first].settled, runs["fixture_vale@" .. second].settled }
			)
			-- The summary line counts them once a run is settled (HNT-R89).
			assert.are.equal("Hunts: 0 of 8 done · 0 titles · 2 wagers settled", line(fake))
		end)

		it("writes nothing for a catch-up whose runs earned nothing new", function()
			local start = SERVER_TIME - 6 * DAY
			local lastLoaded, last = login(function(fake)
				append(fake, valeRun(start, start + DAY))
			end)

			local _, fake = nextLogin(last, lastLoaded, { cast(0, NIGHT, ELWYNN) })

			assert.are.same({ {}, {} }, { writeUps(fake), wagers(fake) })
			assert.are.equal("Hunts: 0 of 8 done · 0 titles · 1 wager settled", line(fake))
		end)

		it(
			"raises a rebuild's uncelebrated marks and settled runs summary-only, none for a run ended 31 days ago",
			function()
				-- A fixture_vale run that ended 31 days ago and one that ended 2 days ago, each with its uncommon mark.
				local old, near = SERVER_TIME - 35 * DAY, SERVER_TIME - 5 * DAY
				local lastLoaded, last = login(function(fake)
					append(fake, {
						runRecord("fixture_vale", old, SERVER_TIME - 31 * DAY),
						castAt(old + 60, DAY_MINUTE, ELWYNN, { C.UNCOMMON }),
						runRecord("fixture_vale", near, SERVER_TIME - 2 * DAY),
						castAt(near + 60, DAY_MINUTE, ELWYNN, { C.UNCOMMON }),
					})
				end)
				assert.are.same(
					{ "fixture_vale@" .. near },
					(function()
						local keys = {}
						for key in pairs(celebrated(lastLoaded).runs) do
							keys[#keys + 1] = key
						end
						return keys
					end)()
				)

				-- While Hunts was off, a Blackmouth in each completes both runs; then a release rebuilds.
				local loaded, fake = nextLogin(last, lastLoaded, {
					castAt(old + 120, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH }),
					castAt(near + 120, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH }),
				}, release)

				assert.are.same({}, writeUps(fake))
				assert.are.same({}, fake.announcements)
				local moments = wagers(fake)
				assert.are.same({ "wagerMark", "wagerMark", "wagerSettled" }, {
					moments[1] and moments[1].kind,
					moments[2] and moments[2].kind,
					moments[3] and moments[3].kind,
				})
				assert.are.equal(3, #moments)
				assert.are.same(
					{ "fixture_vale_haul · first mark", "fixture_vale_blackmouth · first mark", "fixture_vale" },
					{ moments[1].text, moments[2].text, moments[3].text }
				)
				for _, moment in ipairs(moments) do
					assert.are.same({ true, nil }, { moment.summaryOnly, moment.cast })
				end
				-- What the old run earned counts in the totals only (HNT-R92).
				assert.are.equal(2, loaded.ns.State().settled)
				assert.is_nil(celebrated(loaded).runs["fixture_vale@" .. old])
				assert.is_true(celebrated(loaded).runs["fixture_vale@" .. near].settled)
			end
		)

		it("drops celebrated run entries whose run ended more than 30 days ago (HNT-R92)", function()
			local lastLoaded, last = login(function(fake)
				append(fake, { cast(0, NIGHT, ELWYNN) })
			end)
			local runs = celebrated(lastLoaded).runs
			runs["fixture_vale@1"] = { tiers = { fixture_vale_haul = 1 }, endsAt = SERVER_TIME - 30 * DAY - 1 }
			runs["fixture_vale@2"] = { tiers = { fixture_vale_haul = 1 }, endsAt = SERVER_TIME - 30 * DAY }

			local loaded = nextLogin(last, lastLoaded)

			assert.are.same(
				{ ["fixture_vale@2"] = { tiers = { fixture_vale_haul = 1 }, endsAt = SERVER_TIME - 30 * DAY } },
				celebrated(loaded).runs
			)
		end)

		it("raises a ladder title a rebuild finds summary-only, and lists one a catch-up finds", function()
			-- 24 runs completed in March.
			local lastLoaded, last = login(function(fake)
				local runs = {}
				for i = 0, 23 do
					local start = MARCH_1 + i * 2 * HOUR
					runs[#runs + 1] = valeRun(start, start + HOUR)
				end
				append(fake, joined(runs))
			end)

			-- The 25th, last week, while Hunts was off.
			local start = SERVER_TIME - 7 * DAY
			local loaded, fake = nextLogin(last, lastLoaded, valeRun(start, start + DAY))

			assert.are.same({
				{
					"While Hunts was off",
					"1 wager settled",
					"Title: Bookmaker's Bane",
					"Pagle Coins +49",
					"Angler XP +700",
				},
			}, writeUps(fake))
			assert.are.same({ [25] = true }, celebrated(loaded).ladder)
			-- The ladder title counts with the set titles (HNT-R165).
			assert.are.equal("Hunts: 0 of 8 done · 1 title · 25 wagers settled", line(fake))

			-- A rebuild over a celebrated set without it raises it summary-only, with no Coins (HNT-R112).
			celebrated(loaded).ladder = {}
			local _, rebuilt = nextLogin(fake, loaded, nil, release)
			assert.are.same({
				{
					rung = "banner",
					kind = "wagerTitle",
					title = "Title earned",
					text = "Bookmaker's Bane",
					stamp = "Title",
					icon = TRADE_FISHING,
					seal = "quill",
					summaryOnly = true,
				},
			}, wagers(rebuilt))
		end)
	end)
end)
