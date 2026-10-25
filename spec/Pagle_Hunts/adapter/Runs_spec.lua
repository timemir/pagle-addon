-- Hunt Events' runs in Hunts' projection (HNT-R140–R150, HNT-R154, HNT-R199, HNT-R200; HNT-R110, HNT-R113–R115,
-- HNT-R136–R138) on FakePagle, over the fixture Hunt list, event pool (spec/Pagle_Hunts/fixtures/EventList.lua) and
-- catalogue: Casts and Hunts' own `run` and `def` records in the Catch log before login, and live ones after it,
-- appended with the Module's own M:AppendRecord (LOG-R40).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local MARCH_1, NIGHT, DAY_MINUTE, DUSK = hunts.MARCH_1, hunts.NIGHT, hunts.DAY, hunts.DUSK
local cast, append, record, runPayload = hunts.cast, hunts.append, hunts.record, hunts.runPayload
local login, nextLogin, copy, fishAt = hunts.login, hunts.nextLogin, hunts.deepCopy, hunts.fishAt

local DARKSHORE = { zone = C.DARKSHORE }
local AUBERDINE = { zone = C.DARKSHORE, subzone = C.AUBERDINE }
local WESTFALL = { zone = C.WESTFALL }
local ELWYNN = { zone = C.ELWYNN }

-- A Cast as support.cast makes it, at exactly server time `time` (its realm minute left as given).
local function castAt(time, minute, where, itemIDs, auras)
	local entry = cast(0, minute, where, itemIDs, auras)
	entry.time = time
	return entry
end

-- A `run` record of `event` over [start, end_), logged at its start.
local function runRecord(event, start, end_, source)
	return record("run", runPayload(event, start, end_, source), start)
end

-- The run with this event and start in Hunts' state.
local function runOf(loaded, event, start)
	return loaded.ns.State().runs[event .. "@" .. start]
end

-- Each report Core accepted from Hunts, in order: Coins (SHOP-R2) or Activity XP (AXP-R2).
local function reports(list)
	local totals = {}
	for _, report in ipairs(list) do
		if report.module == "Hunts" then
			totals[#totals + 1] = report.total
		end
	end
	return totals
end

-- The next login over the same log, `prepare`d (to change a fingerprint or the rules version): what its done was
-- told, and its state.
local function again(fake, loaded, prepare, events)
	local info
	local next, nextFake = login(nil, {
		fake = nextLogin(fake, loaded),
		events = events,
		prepare = function(l)
			l.ns.outlets.Done = function(_, i)
				info = i
			end
			if prepare then
				prepare(l)
			end
		end,
	})
	return info, next.ns.State(), next, nextFake
end

describe("Hunt Events' runs in Hunts' projection", function()
	describe("which Casts count for a run (HNT-R141, HNT-R144, HNT-R199)", function()
		local S, E = MARCH_1, MARCH_1 + 4 * DAY
		local function shore()
			return login(function(fake)
				return append(fake, {
					castAt(S - 60, NIGHT, DARKSHORE, { C.NIGHTFIN }), -- before its start
					runRecord("fixture_shore", S, E),
					castAt(S + 30 * HOUR, NIGHT, AUBERDINE, { C.NIGHTFIN }), -- in a subzone of the event's zone
					castAt(S + 31 * HOUR, NIGHT, WESTFALL, { C.NIGHTFIN }), -- outside its zone
					runRecord("fixture_shore", E, E + 3 * DAY), -- back to back: the next run starts at the first's end
					castAt(E, NIGHT, DARKSHORE, { C.NIGHTFIN }), -- landing exactly at the first's end
				})
			end)
		end

		it("counts a Catch in the event's zone, or its subzones, during a known run, as an imposed Hunt", function()
			local loaded, _, records = shore()
			local date = records[3].conditions.date
			local snapper = runOf(loaded, "fixture_shore", S).hunts.fixture_shore_snapper
			assert.are.same({
				count = 1,
				effort = 1,
				sinceLast = 0,
				caught = true,
				reached = {
					{
						time = records[3].time,
						catchId = records[3].items[1].catchId,
						itemID = C.NIGHTFIN,
						zone = C.DARKSHORE,
						date = { year = date.year, month = date.month, day = date.day },
					},
				},
			}, snapper)
		end)

		it("doesn't count it outside the zone, before start, or landing exactly at end (HNT-R199)", function()
			local loaded = shore()
			local run = runOf(loaded, "fixture_shore", S)
			assert.are.same({ 1, 1 }, { run.hunts.fixture_shore_snapper.count, run.hunts.fixture_shore_haul.count })
			assert.is_nil(run.completedAt)
		end)

		it("counts a Cast at a back-to-back boundary only for the run starting there (HNT-R144)", function()
			local loaded, _, records = shore()
			local next = runOf(loaded, "fixture_shore", E)
			assert.are.same({ 1, 1 }, { next.hunts.fixture_shore_snapper.count, next.hunts.fixture_shore_haul.count })
			assert.are.equal(records[6].time, next.hunts.fixture_shore_snapper.reached[1].time)
		end)

		it(
			"keeps each run as a HuntRun by its run key, and counts neither record as a Cast (HNT-R136, HNT-R150)",
			function()
				local state = shore().ns.State()
				assert.are.same(
					{ "fixture_shore@" .. S, "fixture_shore@" .. E },
					(function()
						local keys = {}
						for key in pairs(state.runs) do
							keys[#keys + 1] = key
						end
						table.sort(keys)
						return keys
					end)()
				)
				local run = state.runs["fixture_shore@" .. S]
				assert.are.same({ "fixture_shore", S, E, "r" }, { run.event, run.start, run.end_, run.source })
				assert.are.equal(4, state.casts)
			end
		)
	end)

	describe("which runs Hunts knows (HNT-R142, HNT-R145, HNT-R150, HNT-R154)", function()
		it("starts each run of an event at 0, and pays its tiers again (HNT-R145, HNT-R110, HNT-R114)", function()
			local S = MARCH_1
			local loaded = login(function(fake)
				append(fake, {
					runRecord("fixture_shore", S, S + DAY),
					castAt(S + 2 * HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }),
					runRecord("fixture_shore", S + 2 * DAY, S + 3 * DAY),
					castAt(S + 2 * DAY + 2 * HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }),
				})
			end)

			local first, second = runOf(loaded, "fixture_shore", S), runOf(loaded, "fixture_shore", S + 2 * DAY)
			assert.are.same(
				{ 1, 1 },
				{ first.hunts.fixture_shore_snapper.count, #first.hunts.fixture_shore_snapper.reached }
			)
			assert.are.same(
				{ 1, 1 },
				{ second.hunts.fixture_shore_snapper.count, #second.hunts.fixture_shore_snapper.reached }
			)
			-- The Standing fixture_snapper completes once (30 Coins, 500 XP); the event's snapper pays 8 and 150 in each.
			local state = loaded.ns.State()
			assert.are.same({ 30 + 8 + 8, 500 + 150 + 150 }, { state.coins, state.xp })
		end)

		it(
			"ignores a run overlapping a known run of the same event, the one logged first winning (HNT-R142)",
			function()
				local S = MARCH_1
				local loaded = login(function(fake)
					append(fake, {
						runRecord("fixture_shore", S, S + 3 * DAY),
						runRecord("fixture_shore", S + DAY, S + 4 * DAY),
						-- Another event may be on at the same time.
						runRecord("fixture_vale", S + DAY, S + 4 * DAY),
						castAt(S + 3 * DAY + HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }),
					})
				end)

				local state = loaded.ns.State()
				assert.is_nil(state.runs["fixture_shore@" .. (S + DAY)])
				assert.is_table(state.runs["fixture_shore@" .. S])
				assert.is_table(state.runs["fixture_vale@" .. (S + DAY)])
				-- After the first run's end, nothing of fixture_shore is on: the ignored run credits nothing.
				assert.are.same({}, state.runs["fixture_shore@" .. S].hunts)
			end
		)

		it("ignores a run of an event it doesn't know, which credits nothing (HNT-R150)", function()
			local S = MARCH_1
			local loaded = login(function(fake)
				append(fake, {
					runRecord("fixture_nowhere", S, S + DAY),
					runRecord("p_never_defined", S, S + DAY, "p"),
					castAt(S + HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }),
				})
			end)

			local state = loaded.ns.State()
			assert.are.same({}, state.runs)
			assert.are.same({ 30, 500 }, { state.coins, state.xp }) -- the Standing fixture_snapper's alone
		end)

		it("skips a record it can't decode, and one of another kind (HNT-R136, hunts.md › Contracts)", function()
			local S = MARCH_1
			local loaded = login(function(fake)
				append(fake, {
					record("run", "fixture_shore|" .. (S + DAY) .. "|" .. S .. "|r", S), -- start after end
					record("run", "fixture_shore|" .. S .. "|" .. (S + DAY) .. "|x", S), -- an unknown source
					record("note", "fixture_shore", S),
					castAt(S + HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }),
				})
			end)

			assert.are.same({}, loaded.ns.State().runs)
		end)

		describe("a pushed definition (HNT-R140, HNT-R154)", function()
			-- A pushed event in Darkshore with a long note, so its definition takes more than one `def` record.
			local function pushedItem()
				return {
					kind = "huntEvent",
					v = 1,
					id = "p_fixture_tide",
					zones = { C.DARKSHORE },
					tags = { "coast", "night" },
					skill = { 75, 150 },
					rotation = false,
					name = "Pushed Tide",
					note = string.rep("A long night on the shore. ", 12),
					hunts = {
						{ id = "p_fixture_tide_haul", name = "Tide Haul", class = "species.any", tiers = { 1 } },
						{ id = "p_fixture_tide_snapper", species = C.NIGHTFIN, tiers = { 1 } },
						{
							id = "p_fixture_tide_oddity",
							class = "fixed.oddity",
							conditions = { time = { { 1080, 1260 } } },
							tiers = { 1 },
						},
					},
				}
			end

			-- Hunts over a history of the definition's `def` records (`keep` says which parts), its run and a night
			-- Nightfin and a dusk Deviate Fish in Darkshore inside it.
			local function withDefinition(keep)
				local S = MARCH_1
				local parts
				local loaded = login(function(fake)
					-- The parts as the run log (#300) writes them: logic/Records.lua over logic/Content.lua's text.
					local ns = newFakePagle().load("Pagle_Hunts", { holdAddonLoaded = true }).ns
					local text = assert(ns.WriteContentItem(pushedItem()))
					parts = ns.EncodeDefParts("p_fixture_tide", text)
					local records = {}
					for part, payload in ipairs(parts) do
						if keep(part) then
							records[#records + 1] = record("def", payload, S - HOUR)
						end
					end
					records[#records + 1] = runRecord("p_fixture_tide", S, S + 3 * DAY, "p")
					records[#records + 1] = castAt(S + HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN })
					records[#records + 1] = castAt(S + 2 * HOUR, DUSK, DARKSHORE, { C.DEVIATE })
					append(fake, records)
				end)
				return loaded, parts, S
			end

			it("is reassembled from its parts in order, and its run credited", function()
				local loaded, parts, S = withDefinition(function()
					return true
				end)

				assert.is_true(#parts > 1)
				local run = runOf(loaded, "p_fixture_tide", S)
				assert.are.equal("p", run.source)
				assert.are.equal(S + 2 * HOUR, run.completedAt)
				assert.are.equal(1, loaded.ns.State().settled)
				-- Its Hunts' names are the definition's own, where it has them (HNT-R140).
				local event = loaded.ns.KnownEvent(loaded.ns.State(), "p_fixture_tide")
				assert.are.same(
					{ "Tide Haul", "p_fixture_tide_snapper" },
					{ loaded.ns.events:HuntName(event.hunts[1]), loaded.ns.events:HuntName(event.hunts[2]) }
				)
				assert.are.equal("Pushed Tide", loaded.ns.events:EventName(event))
			end)

			it("is unknown with a part missing, and its runs aren't credited", function()
				local loaded, _, S = withDefinition(function(part)
					return part ~= 2
				end)

				assert.is_nil(runOf(loaded, "p_fixture_tide", S))
				assert.are.equal(0, loaded.ns.State().settled)
				assert.is_nil(loaded.ns.KnownEvent(loaded.ns.State(), "p_fixture_tide"))
			end)

			it("is ignored with a dev diagnostic line when it fails the checks (HNT-R140)", function()
				local lines = {}
				local S = MARCH_1
				local loaded = login(function(fake)
					local ns = newFakePagle().load("Pagle_Hunts", { holdAddonLoaded = true }).ns
					local item = pushedItem()
					item.hunts[3] = nil -- only two Hunts
					local records = {}
					for _, payload in ipairs(ns.EncodeDefParts("p_fixture_tide", assert(ns.WriteContentItem(item)))) do
						records[#records + 1] = record("def", payload, S - HOUR)
					end
					records[#records + 1] = runRecord("p_fixture_tide", S, S + 3 * DAY, "p")
					append(fake, records)
				end, {
					prepare = function(l)
						l.ns.outlets.Diagnostic = function(line)
							lines[#lines + 1] = line
						end
					end,
				})

				assert.are.same({}, loaded.ns.State().runs)
				assert.are.same({
					"Hunts: the logged definition of p_fixture_tide is ignored: it hasn't 3 to 5 Hunts (HNT-R140)",
				}, lines)
			end)
		end)
	end)

	describe("a run record appended after Casts inside its run (HNT-R149, HNT-R151, HNT-R155)", function()
		local S, E = MARCH_1, MARCH_1 + 4 * DAY
		-- A night Nightfin, then a dusk Deviate Fish in Darkshore: together every fixture_shore Hunt's tier 1.
		local function history(fake)
			return append(fake, {
				cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }),
				cast(1, DUSK, DARKSHORE, { C.DEVIATE }),
				cast(1, DUSK + 1, WESTFALL, { C.DEVIATE }),
			})
		end

		it("credits them, live, as apply would, and reports Coins and XP with the record (AXP-R2, AXP-R7)", function()
			local loaded, fake, records = login(history)
			local before = loaded.ns.State().xp

			local logged = loaded.ns.Module:AppendRecord("run", runPayload("fixture_shore", S, E))

			local run = runOf(loaded, "fixture_shore", S)
			assert.are.same({ 1, 2, 1 }, {
				run.hunts.fixture_shore_snapper.count,
				run.hunts.fixture_shore_haul.count,
				run.hunts.fixture_shore_oddity.count,
			})
			-- Its completion time is the last of its Hunts' tier-1 times (HNT-R146).
			assert.are.equal(records[2].time, run.completedAt)
			local xp = fake.xpReports[#fake.xpReports]
			assert.are.same({ "Hunts", before + 3 * 150 + 250 }, { xp.module, xp.total })
			assert.are.equal(logged.seq, xp.entry.seq)
		end)

		it("folds to the same state applied live and rebuilt from the log, twice (LOG-R72, HNT-R191)", function()
			local loaded, fake = login(history)
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_shore", S, E))
			local live = copy(loaded.ns.State())

			local info, rebuilt, next, nextFake = again(fake, loaded, function(l)
				l.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
			end)
			local info2, rebuiltAgain = again(nextFake, next, function(l)
				l.ns.huntList.fingerprint = "f1c7f1c7f1c70003"
			end)

			assert.are.same({ true, true }, { info.rebuilt, info2.rebuilt })
			assert.are.same(live, rebuilt)
			assert.are.same(live, rebuiltAgain)
		end)

		it(
			"credits a run older than the hour index from the index's start, live and rebuilt alike (HNT-R149)",
			function()
				-- Two Nightfin in Darkshore 20 days apart: the 14-day index (Tunables) has dropped the first one's hour.
				local loaded, fake = login(function(fake)
					append(fake, {
						cast(0, NIGHT, DARKSHORE, { C.NIGHTFIN }),
						cast(20, NIGHT, DARKSHORE, { C.NIGHTFIN }),
					})
				end)
				loaded.ns.Module:AppendRecord("run", runPayload("fixture_shore", S, S + 22 * DAY))
				local live = copy(loaded.ns.State())

				local _, rebuilt = again(fake, loaded, function(l)
					l.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
				end)

				assert.are.equal(1, live.runs["fixture_shore@" .. S].hunts.fixture_shore_snapper.count)
				assert.are.same(live, rebuilt)
			end
		)

		it("credits live Casts after it to a run on now, as a rebuild does (HNT-R137, HNT-R144)", function()
			local loaded, fake = login()
			local start = SERVER_TIME - HOUR
			loaded.ns.Module:AppendRecord("run", runPayload("fixture_shore", start, start + 3 * DAY))
			fishAt(fake, NIGHT, AUBERDINE)
			fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 }, { itemID = C.DEVIATE, quantity = 1 } })
			local live = copy(loaded.ns.State())

			local _, rebuilt = again(fake, loaded, function(l)
				l.ns.huntList.fingerprint = "f1c7f1c7f1c70002"
			end)

			local run = live.runs["fixture_shore@" .. start]
			assert.are.same({ 1, 2 }, { run.hunts.fixture_shore_snapper.count, run.hunts.fixture_shore_haul.count })
			assert.are.same(live, rebuilt)
		end)
	end)

	describe("completed runs and the ladder (HNT-R146, HNT-R148)", function()
		it("completes a run when every Hunt has reached tier 1, at the last tier-1 time", function()
			local S = MARCH_1
			local loaded = login(function(fake)
				append(fake, {
					runRecord("fixture_vale", S, S + 3 * DAY),
					castAt(S + HOUR, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH }), -- the Haul's and the Named fish's tier 1
					castAt(S + 5 * HOUR, DAY_MINUTE, ELWYNN, { C.UNCOMMON }), -- the Quality Hunt's: the last
					castAt(S + 6 * HOUR, DAY_MINUTE, ELWYNN, { C.UNCOMMON }),
				})
			end)

			local state = loaded.ns.State()
			assert.are.same({ S + 5 * HOUR, 1 }, { runOf(loaded, "fixture_vale", S).completedAt, state.settled })
		end)

		it("records the first ladder step at the 25th completed run, across events and repeats, never lost", function()
			local completions = {}
			local loaded = login(function(fake)
				local records = {}
				for i = 0, 24 do
					local start = MARCH_1 + i * 2 * HOUR
					-- One Cast with a Blackmouth and an uncommon item completes a fixture_vale run.
					records[#records + 1] = runRecord("fixture_vale", start, start + HOUR)
					records[#records + 1] = castAt(start + 60, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON })
					completions[#completions + 1] = start + 60
				end
				append(fake, records)
			end)

			local state = loaded.ns.State()
			assert.are.same({ 25, { [25] = completions[25] } }, { state.settled, state.ladder })
		end)
	end)

	describe("Coins and Activity XP (HNT-R110, HNT-R113–R115)", function()
		-- fixture_rack (a Standing Hunt, tiers 1 / 5) at tier 2 in Westfall, then a fixture_vale run completed with
		-- its Haul at tier 2 (1 / 3), in Elwynn.
		local function history(fake)
			local S = MARCH_1
			append(fake, {
				cast(0, DAY_MINUTE, WESTFALL, { C.UNCOMMON, C.UNCOMMON, C.UNCOMMON }, { C.RACK_AURA }),
				cast(0, DAY_MINUTE + 1, WESTFALL, { C.UNCOMMON, C.UNCOMMON }, { C.RACK_AURA }),
				runRecord("fixture_vale", S, S + 3 * DAY),
				castAt(S + HOUR, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON }),
				castAt(S + 2 * HOUR, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.BLACKMOUTH }),
			})
		end
		-- Standing: 30 + 15 Coins, 500 + 250 XP. The run: three tier 1s (8 Coins, 150 XP each), the Haul's tier 2 (5,
		-- 100) and the completed run (25, 250).
		local COINS = 30 + 15 + 3 * 8 + 5 + 25
		local XP = 500 + 250 + 3 * 150 + 100 + 250

		it("sums them over every tier, completed run and title", function()
			local loaded = login(history)

			local state = loaded.ns.State()
			assert.are.same({ COINS, XP }, { state.coins, state.xp })
			assert.are.same({ 2, 1 }, { #state.hunts.fixture_rack.reached, state.settled })
		end)

		it("reports XP from done, then once per live entry that changes it, and from every done (AXP-R2)", function()
			local loaded, fake = login(history)
			assert.are.same({ XP }, reports(fake.xpReports))

			-- A sixth uncommon item under the Rack's aura reaches no tier; a night Nightfin completes the Standing
			-- fixture_snapper and fixture_tide_late (500 each).
			fishAt(fake, DAY_MINUTE, WESTFALL, { C.RACK_AURA })
			fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fishAt(fake, NIGHT, AUBERDINE)
			local live = fake.playCast("caught", { { itemID = C.NIGHTFIN, quantity = 1 } })
			assert.are.same({ XP, XP + 1000 }, reports(fake.xpReports))
			assert.are.equal(live.seq, fake.xpReports[#fake.xpReports].entry.seq)

			local _, _, _, nextFake = again(fake, loaded)
			assert.are.same({ XP + 1000 }, reports(nextFake.xpReports))
			assert.are.same({ COINS + 60 }, reports(nextFake.coinReports))
		end)
	end)

	describe("rules version 3 and the fingerprint (HNT-R136, HNT-R138)", function()
		it(
			"is version 3 (2 with runs, 3 for the retuned Coins), and rebuilds a projection stored under version 1",
			function()
				local first, fake = login(function(fake)
					append(fake, { cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }) })
				end, {
					prepare = function(l)
						l.ns.HUNTS_RULES_VERSION = 1
					end,
				})
				assert.are.equal(1, first.env.PagleHuntsDB.global.projection.rulesVersion)

				local info, state, next = again(fake, first)

				assert.are.equal(3, next.ns.HUNTS_RULES_VERSION)
				assert.is_true(info.rebuilt)
				assert.are.same({ 3, 500 }, { next.env.PagleHuntsDB.global.projection.rulesVersion, state.xp })
			end
		)

		it(
			"stores the Hunt list's fingerprint joined with the event pool's, and rebuilds when the pool's changes",
			function()
				local first, fake = login(function(fake)
					append(fake, { cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }) })
				end)
				assert.are.equal(
					fake.Pagle.CONTENT_FINGERPRINT .. "+f1c7f1c7f1c7f1c7+e1e1e1e1e1e1e1e1",
					first.env.PagleHuntsDB.global.projection.fingerprint
				)

				local info, _, next = again(fake, first, nil, function(pool)
					local changed = copy(pool)
					changed.fingerprint = "e1e1e1e1e1e10002"
					return changed
				end)

				assert.is_true(info.rebuilt)
				assert.matches("%+e1e1e1e1e1e10002$", next.env.PagleHuntsDB.global.projection.fingerprint)
			end
		)
	end)
end)
