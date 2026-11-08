-- Party Catches in Hunts' projection (HNT-R180–R187, HNT-R205–R208; from 1.6, rule set pagle-2026j): a groupmate's
-- Catch, logged as a Party Catch (LOG-R115) and handed to Hunts' projection only (LOG-R117), counts toward the
-- Angler's Hunts exactly as the Angler's own Catch would at the groupmate's Cast time and conditions, with no effort
-- and no bonus. Hunts' projection def (logic/Projection.lua) is folded here by hand, as Core's projections fold it, over
-- a Catch log Core's codec writes: the receiver's Casts, Module records and `G1` Party Catches (support.partyCatch), in
-- log order, read back by CatchLog:Iterate as M:IterateCatches reads them for a Module that takes Party Catches.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local MARCH_1, NIGHT, DAY_MINUTE, DUSK = hunts.MARCH_1, hunts.NIGHT, hunts.DAY, hunts.DUSK
local cast, partyCatch, record, runPayload = hunts.cast, hunts.partyCatch, hunts.record, hunts.runPayload
local copy = hunts.deepCopy

local DARKSHORE = { zone = C.DARKSHORE }
local AUBERDINE = { zone = C.DARKSHORE, subzone = C.AUBERDINE }
local WESTFALL = { zone = C.WESTFALL }
local ELWYNN = { zone = C.ELWYNN }

-- A Cast as support.cast makes it, at exactly server time `time` (its realm minute as given).
local function castAt(time, minute, where, itemIDs, auras)
	local entry = cast(0, minute, where, itemIDs, auras)
	entry.time = time
	return entry
end

-- A `run` record of `event` over [start, end_), logged at server time `at` (its start by default).
local function runRecord(event, start, end_, at)
	return record("run", runPayload(event, start, end_), at or start)
end

-- The receiver's Catch log, written by Core's codec (the player's character first): each Cast and Module record of
-- `entries`, and each Party Catch (support.partyCatch) as the `G1` of its copy at its receipt time (LOG-R115). Returns
-- the records as appended, in log order, a Party Catch with the live-only `name` and `sourceId` its template has, and
-- the log as `records.log`.
---@param entries table[]
---@return table[]
local function log(entries)
	local own = newFakePagle()
	own.setCatalogue(C.base())
	own.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	local records = { log = own.catchLog }
	for i, entry in ipairs(entries) do
		local made
		if entry.kind == "party" then
			---@type table
			local party =
				copy(own.catchLog:Append({ kind = "party", char = entry.char, time = entry.time, copy = entry.copy }))
			assert(party.id == entry.id, "a Party Catch's template is another entry's: " .. party.id)
			party.name, party.sourceId = entry.name, entry.sourceId
			made = party
		else
			made = copy(own.catchLog:Append(entry))
		end
		records[i] = made
	end
	return records
end

-- Every string anywhere in `value`, keys included.
local function strings(value, out)
	out = out or {}
	if type(value) == "string" then
		out[#out + 1] = value
	elseif type(value) == "table" then
		for key, v in pairs(value) do
			strings(key, out)
			strings(v, out)
		end
	end
	return out
end

describe("Party Catches in Hunts' projection", function()
	local fake = newFakePagle()
	fake.setCatalogue(C.base())
	local ns = hunts.load(fake).ns

	-- What the outlets were handed during a fold, and the reports the client got.
	local raised, credited, saved

	before_each(function()
		raised, credited, saved = {}, {}, {}
		for key, fn in pairs(ns.outlets) do
			saved[key] = fn
		end
		ns.outlets.Reached = function(entry, reached)
			raised[#raised + 1] = { record = entry, reached = reached }
		end
		ns.outlets.Credited = function(entry, reached)
			credited[#credited + 1] = { record = entry, reached = reached }
		end
		ns.outlets.Done = function() end
		ns.outlets.RefreshGoods = function() end
		ns.outlets.StepDue = function() end
	end)

	after_each(function()
		for key, fn in pairs(saved) do
			ns.outlets[key] = fn
		end
	end)

	-- Hunts' projection def over `records`, as Core binds it: M:IterateCatches reads them back (LOG-R42, LOG-R117),
	-- and each report is noted in `reports`.
	local function defOver(records, reports)
		return ns.ProjectionDef({}, ns.lookups, {
			ReportCoinsEarned = function(total)
				reports.coins[#reports.coins + 1] = total
			end,
			ReportXPEarned = function(total)
				reports.xp[#reports.xp + 1] = total
			end,
			ReportTicketsEarned = function(total)
				reports.tickets[#reports.tickets + 1] = total
			end,
			-- M:IterateCatches for Hunts, whose projection takes Party Catches (LOG-R42, LOG-R117).
			IterateCatches = function(afterSeq)
				return records.log:Iterate(afterSeq, "Hunts", true)
			end,
			ServerTime = function()
				return SERVER_TIME
			end,
		})
	end

	-- `records` folded from reset in `mode` ("rebuild" by default), one apply each in log order, as Core folds a
	-- rebuild, a catch-up or live entries: the state, and the reports made.
	local function fold(records, mode)
		local reports = { coins = {}, xp = {}, tickets = {} }
		local def = defOver(records, reports)
		local state = def.reset()
		for _, entry in ipairs(records) do
			def.apply(state, entry, mode or "rebuild")
		end
		return state, reports, def
	end

	describe("which Party Catches qualify (HNT-R180)", function()
		it("counts a groupmate's Catch toward a Standing Hunt as the Angler's own would, at its time", function()
			local t = hunts.at(0, NIGHT)
			local mine = fold(log({
				castAt(t - 30, NIGHT, DARKSHORE),
				castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN }),
			}))
			local pc = partyCatch(castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN }))
			local theirs = fold(log({ castAt(t - 30, NIGHT, DARKSHORE), pc }))

			local own, party = mine.hunts.fixture_snapper, theirs.hunts.fixture_snapper
			assert.are.same({ 1, 1 }, { own.count, party.count })
			local ownTier, partyTier = own.reached[1], party.reached[1]
			assert.are.same(
				{ ownTier.time, ownTier.itemID, ownTier.zone, ownTier.date },
				{ partyTier.time, partyTier.itemID, partyTier.zone, partyTier.date }
			)
			-- The same tier pays the same (HNT-R182).
			assert.are.same({ mine.coins, mine.xp }, { theirs.coins, theirs.xp })
		end)

		it("judges an imposed Hunt by the groupmate's conditions, never the Angler's", function()
			-- fixture_rack counts uncommon items under the Rack's aura: the groupmate was under it, the Angler wasn't.
			local t = hunts.at(1, DAY_MINUTE)
			local underAura = partyCatch(castAt(t, DAY_MINUTE, WESTFALL, { C.UNCOMMON }, { C.RACK_AURA }), t + 1)
			local without = partyCatch(castAt(t + 60, DAY_MINUTE, WESTFALL, { C.UNCOMMON }), t + 61)

			local state = fold(log({ castAt(t - 30, DAY_MINUTE, WESTFALL), underAura, without }))

			assert.are.equal(1, state.hunts.fixture_rack.count)
			assert.are.equal(underAura.items[1].catchId, state.hunts.fixture_rack.reached[1].catchId)
		end)

		it("judges an imposed Hunt's realm hours by the groupmate's Cast's minute", function()
			-- fixture_oddity counts a Deviate Fish at 18:00–21:00 realm time.
			local atDusk = partyCatch(cast(2, DUSK, DARKSHORE, { C.DEVIATE }))
			local atDay = partyCatch(cast(3, DAY_MINUTE, DARKSHORE, { C.DEVIATE }))

			assert.are.equal(1, fold(log({ atDusk })).hunts.fixture_oddity.count)
			assert.is_nil(fold(log({ atDay })).hunts.fixture_oddity)
		end)

		it(
			"counts toward a Standing Hunt only when it exists at catchTime, not at receipt (HNT-R2, HNT-R13)",
			function()
				-- fixture_tide_late, a night Nightfin Hunt, exists from 2026-04-01; fixture_snapper from 2026-01-01.
				local since = 1775001600
				local before = partyCatch(castAt(since - 1, NIGHT, DARKSHORE, { C.NIGHTFIN }), since + 1)
				local after = partyCatch(castAt(since + 60, NIGHT, DARKSHORE, { C.NIGHTFIN }), since + 61)

				local state = fold(log({ before }))
				assert.are.equal(1, state.hunts.fixture_snapper.count)
				assert.is_nil(state.hunts.fixture_tide_late)

				state = fold(log({ before, after }))
				assert.are.same({ 2, 1 }, { state.hunts.fixture_snapper.count, state.hunts.fixture_tide_late.count })
			end
		)

		it("never counts toward a Retired Hunt after its retired date", function()
			-- fixture_sunscale retired on 2026-06-01.
			local retired = 1780272000
			local late = partyCatch(castAt(retired + HOUR, DAY_MINUTE, ELWYNN, { C.SUNSCALE }))
			local early = partyCatch(castAt(retired - HOUR, DAY_MINUTE, ELWYNN, { C.SUNSCALE }))

			assert.is_nil(fold(log({ late })).hunts.fixture_sunscale)
			assert.are.equal(1, fold(log({ early })).hunts.fixture_sunscale.count)
		end)

		it("never qualifies for a Hunt with a minBand: it has no Simulated Size (HNT-R10 item 3, HNT-R14)", function()
			-- fixture_hefty_blackmouth: Oily Blackmouth of band 3 or more, 22:00–04:00.
			local pc = partyCatch(cast(0, NIGHT + 60, WESTFALL, { C.BLACKMOUTH, C.BLACKMOUTH }))
			assert.is_nil(pc.items[1].size)

			local state = fold(log({ pc }))

			assert.is_nil(state.hunts.fixture_hefty_blackmouth)
			assert.is_false(defOver({}, {}).wantsPartyCatch(ns.NewHuntsState(), pc))
		end)

		it("is folded in log order, after the Angler's Casts logged before it, whatever its catchTime", function()
			local t = hunts.at(0, NIGHT)
			local pc = partyCatch(castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN }), t + 20)
			local own = castAt(t + 10, NIGHT, DARKSHORE, { C.NIGHTFIN })

			-- The Angler's Cast is logged first, though the groupmate's Catch came 10 seconds earlier.
			local records = log({ own, pc })
			local first = fold(records).hunts.fixture_snapper.reached[1]
			assert.are.same({ records[1].items[1].catchId, t + 10 }, { first.catchId, first.time })
			assert.is_nil(first.party)

			-- The other way round, the Party Catch reaches tier 1.
			first = fold(log({ pc, castAt(t + 30, NIGHT, DARKSHORE, { C.NIGHTFIN }) })).hunts.fixture_snapper.reached[1]
			assert.are.same({ pc.items[1].catchId, t, true }, { first.catchId, first.time, first.party })
		end)
	end)

	describe("what a Party Catch changes (HNT-R181)", function()
		it(
			"stores the tier it reaches with catchTime, its Party Catch ID, the copied zone and date, and party",
			function()
				local pc = partyCatch(cast(0, NIGHT, AUBERDINE, { C.SMALLFISH, C.NIGHTFIN, C.NIGHTFIN }), nil, true)

				local state = fold(log({ pc }))

				local snapper = state.hunts.fixture_snapper
				assert.are.same({
					count = 2,
					effort = 0,
					sinceLast = 0,
					caught = true,
					reached = {
						{
							time = pc.catchTime,
							catchId = pc.id .. ":2", -- the first Nightfin in slot order (HNT-R15)
							itemID = C.NIGHTFIN,
							zone = C.DARKSHORE,
							date = {
								year = pc.conditions.date.year,
								month = pc.conditions.date.month,
								day = pc.conditions.date.day,
							},
							party = true,
						},
					},
				}, snapper)
			end
		)

		it("adds no effort Cast, leaves sinceLast alone and adds nothing to casts (HNT-R25, HNT-R26)", function()
			local t = hunts.at(0, NIGHT)
			local records = log({
				castAt(t - 60, NIGHT, DARKSHORE, { C.NIGHTFIN }),
				castAt(t - 30, NIGHT, DARKSHORE),
				partyCatch(castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN })),
			})

			local state = fold(records)

			local snapper = state.hunts.fixture_snapper
			assert.are.same({ 2, 2, 1 }, { snapper.count, snapper.effort, snapper.sinceLast })
			assert.are.equal(2, state.casts)
		end)

		it("checks the set titles at catchTime, so a Party Catch can complete a set (HNT-R23)", function()
			-- fixture_wagers' Hunts in March: fixture_oddity and fixture_rack (fixture_grouper exists from November).
			local rack = cast(1, DAY_MINUTE, WESTFALL, { C.UNCOMMON }, { C.RACK_AURA })
			local pc = partyCatch(cast(2, DUSK, DARKSHORE, { C.DEVIATE }), nil, true)
			local records = log({ rack, pc })

			local def = defOver(records, { coins = {}, xp = {}, tickets = {} })
			local state = def.reset()
			def.apply(state, records[1], "live")
			def.apply(state, records[2], "live")

			assert.are.same({ earnedAt = pc.catchTime, fromRetirement = false }, {
				earnedAt = state.sets.fixture_wagers.earnedAt,
				fromRetirement = state.sets.fixture_wagers.fromRetirement,
			})
			assert.are.same({ "fixture_wagers" }, raised[#raised].reached.sets)
			assert.are.equal(2 * ns.COINS_COMPLETED + ns.COINS_TITLE, state.coins)
		end)

		it("keeps nothing that names the groupmate: no GUID, no name, no source ID (LOG-R120)", function()
			local pc = partyCatch(cast(0, NIGHT, DARKSHORE, { C.NIGHTFIN }), nil, true)
			local records = log({ pc })

			local state = fold(records, "live")

			for _, text in ipairs(strings(state)) do
				assert.is_nil(text:find(hunts.GROUPMATE_GUID, 1, true))
				assert.is_nil(text:find(hunts.GROUPMATE_NAME, 1, true))
			end
		end)
	end)

	describe("no bonus for grouping (HNT-R182)", function()
		it("pays a tier reached through a Party Catch exactly as the Angler's own Catch would, once", function()
			-- fixture_rack's tiers 1 and 5: five uncommon items under the Rack's aura reach both.
			local function items()
				return { C.UNCOMMON, C.UNCOMMON, C.UNCOMMON, C.UNCOMMON, C.UNCOMMON }
			end
			local t = hunts.at(1, DAY_MINUTE)
			local mine = fold(log({ castAt(t, DAY_MINUTE, WESTFALL, items(), { C.RACK_AURA }) }))
			local theirs = fold(log({ partyCatch(castAt(t, DAY_MINUTE, WESTFALL, items(), { C.RACK_AURA })) }))

			assert.are.equal(ns.COINS_COMPLETED + ns.COINS_TIER, theirs.coins)
			assert.are.same({ mine.coins, mine.xp, mine.tickets }, { theirs.coins, theirs.xp, theirs.tickets })
		end)

		it("pays a run a Party Catch completes exactly as the Angler's own Catch would", function()
			-- fixture_vale: one Cast in Elwynn with an Oily Blackmouth and an uncommon item completes a run.
			local S = MARCH_1
			local function catchIn(minute)
				return castAt(S + HOUR, minute, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON })
			end
			local mine = fold(log({ runRecord("fixture_vale", S, S + 3 * DAY), catchIn(DAY_MINUTE) }))
			local theirs = fold(log({ runRecord("fixture_vale", S, S + 3 * DAY), partyCatch(catchIn(DAY_MINUTE)) }))

			local run = theirs.runs["fixture_vale@" .. S]
			assert.are.same({ S + HOUR, 1 }, { run.completedAt, theirs.settled })
			assert.are.same(
				{ mine.coins, mine.xp, mine.tickets, mine.settled },
				{ theirs.coins, theirs.xp, theirs.tickets, theirs.settled }
			)
		end)
	end)

	describe("Pagle Wagers: the Angler's own runs only (HNT-R183)", function()
		local S, E = MARCH_1, MARCH_1 + 3 * DAY
		local SHORE = "fixture_shore@" .. MARCH_1

		it("credits a known run on at catchTime in its zones, with no effort, its tiers marked party", function()
			local pc = partyCatch(castAt(S + HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }))
			local state = fold(log({ runRecord("fixture_shore", S, E), pc }))

			local run = state.runs[SHORE]
			assert.are.same({
				count = 1,
				effort = 0,
				sinceLast = 0,
				caught = true,
				reached = {
					{
						time = pc.catchTime,
						catchId = pc.id .. ":1",
						itemID = C.NIGHTFIN,
						zone = C.DARKSHORE,
						date = {
							year = pc.conditions.date.year,
							month = pc.conditions.date.month,
							day = pc.conditions.date.day,
						},
						party = true,
					},
				},
			}, run.hunts.fixture_shore_snapper)
			assert.are.same({ 1, 0 }, { run.hunts.fixture_shore_haul.count, run.hunts.fixture_shore_haul.effort })
		end)

		it("credits no event Hunt for an Angler with no known run on then, and logs none (HNT-R151)", function()
			local pc = partyCatch(castAt(S + HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }))
			local steps = 0
			ns.outlets.StepDue = function()
				steps = steps + 1
			end

			local state = fold(log({ pc }), "live")

			assert.are.same({}, state.runs)
			assert.are.equal(1, state.hunts.fixture_snapper.count) -- its Standing Hunt still counts it
			assert.are.equal(0, steps)
		end)

		it("credits a groupmate's run the Angler doesn't know to nothing: each Angler credits their own", function()
			-- The groupmate fishes fixture_vale's Elwynn on a run of their own; the Angler knows only fixture_shore's.
			local pc = partyCatch(castAt(S + HOUR, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON }))

			local state = fold(log({ runRecord("fixture_shore", S, E), pc }))

			local known = ns.RunsKnown(state)
			assert.are.same({ 1, SHORE }, { #known, known[1].key })
			assert.are.same({}, state.runs[SHORE].hunts)
		end)

		it(
			"credits the run on at catchTime, never at receipt, at a back-to-back boundary (HNT-R144, HNT-R199)",
			function()
				local before = partyCatch(castAt(S - 1, NIGHT, DARKSHORE, { C.NIGHTFIN }), S + 1)
				local atEnd = partyCatch(castAt(E, NIGHT, DARKSHORE, { C.NIGHTFIN }), E + 1)
				local records = log({
					runRecord("fixture_shore", S, E),
					before,
					runRecord("fixture_shore", E, E + 3 * DAY, S + 2),
					atEnd,
				})

				local state = fold(records)

				assert.are.same({}, state.runs[SHORE].hunts)
				local next = state.runs["fixture_shore@" .. E].hunts.fixture_shore_snapper
				assert.are.equal(atEnd.items[1].catchId, next.reached[1].catchId)
			end
		)

		it("is walked again with the Casts, in log order, when its run's record comes after it (HNT-R149)", function()
			local own = castAt(S + 10, DUSK, DARKSHORE, { C.DEVIATE })
			local pc = partyCatch(castAt(S + 20, NIGHT, DARKSHORE, { C.NIGHTFIN }))
			local records = log({ own, pc, runRecord("fixture_shore", S, E, S + 60) })

			local state = fold(records, "live")

			-- The Haul's tier 1 (2 fish) is reached by the second in log order, the Party Catch's Nightfin; the oddity's
			-- by the Angler's own Deviate Fish.
			local run = state.runs[SHORE]
			local haul, snapper = run.hunts.fixture_shore_haul, run.hunts.fixture_shore_snapper
			assert.are.same(
				{ 2, pc.items[1].catchId, true },
				{ haul.count, haul.reached[1].catchId, haul.reached[1].party }
			)
			assert.are.same({ pc.items[1].catchId, true }, { snapper.reached[1].catchId, snapper.reached[1].party })
			assert.is_nil(run.hunts.fixture_shore_oddity.reached[1].party)
			-- Its earlier Catches' marks reach the moments summary-only, through Credited (HNT-R149).
			assert.are.equal(1, #credited)
		end)

		it("is walked again when it came before the first Cast of its run's hour (the hour index notes it)", function()
			-- The Angler's last Cast was 4 minutes before the run's start, and none came between it and the record.
			local own = castAt(S - 240, NIGHT, DARKSHORE)
			local pc = partyCatch(castAt(S + 30, NIGHT, DARKSHORE, { C.NIGHTFIN }))
			local records = log({ own, pc, runRecord("fixture_shore", S, E, S + 40) })

			local state = fold(records, "live")

			assert.are.equal(pc.items[1].catchId, state.runs[SHORE].hunts.fixture_shore_snapper.reached[1].catchId)
		end)

		it("notes no replayed Cast for the run log's catch-up: its span is from Casts only (HNT-R155)", function()
			local noted = {}
			local note = ns.NoteReplayedCast
			ns.NoteReplayedCast = function(time)
				noted[#noted + 1] = time
			end
			local own = castAt(S + 10, NIGHT, DARKSHORE)
			local records = log({ own, partyCatch(castAt(S + 4 * DAY, NIGHT, DARKSHORE, { C.NIGHTFIN })) })

			fold(records, "replay")
			ns.NoteReplayedCast = note

			assert.are.same({ S + 10 }, noted)
		end)
	end)

	describe("the filter (HNT-R184)", function()
		local S, E = MARCH_1, MARCH_1 + 3 * DAY

		-- Whether Hunts' filter takes `pc` over `state`, and that it left `state` as it was.
		local function wants(state, pc)
			local before = copy(state)
			local answer = defOver({}, { coins = {}, xp = {}, tickets = {} }).wantsPartyCatch(state, pc)
			assert.are.same(before, state)
			return answer
		end

		it("takes a Party Catch with an item that qualifies for a Standing Hunt", function()
			assert.is_true(
				wants(ns.NewHuntsState(), partyCatch(cast(0, NIGHT, DARKSHORE, { C.SMALLFISH, C.NIGHTFIN })))
			)
		end)

		it("takes one for a Hunt whose tiers are all reached, since its count still rises (HNT-R16)", function()
			-- fixture_sunscale has one tier.
			local state = fold(log({ partyCatch(cast(0, DAY_MINUTE, ELWYNN, { C.SUNSCALE })) }))
			assert.is_true(ns.HuntFinished(state.hunts.fixture_sunscale, ns.hunts:Hunt("fixture_sunscale")))

			assert.is_true(wants(state, partyCatch(cast(1, DAY_MINUTE, ELWYNN, { C.SUNSCALE }))))
		end)

		it("takes one for an event Hunt of a known run on at catchTime, and refuses it with none", function()
			-- An Oily Blackmouth by day in Darkshore: no Standing Hunt takes it (fixture_hefty_blackmouth wants a size
			-- and the night), fixture_shore's Haul (species.any) does.
			local pc = partyCatch(castAt(S + HOUR, DAY_MINUTE, DARKSHORE, { C.BLACKMOUTH }))
			local state = fold(log({ runRecord("fixture_shore", S, E) }))

			assert.is_true(wants(state, pc))
			assert.is_false(wants(ns.NewHuntsState(), pc))
			assert.is_false(wants(state, partyCatch(castAt(E + HOUR, DAY_MINUTE, DARKSHORE, { C.BLACKMOUTH }))))
		end)

		it("refuses one that counts for nothing the Angler hunts (HNT-R206)", function()
			assert.is_false(wants(ns.NewHuntsState(), partyCatch(cast(0, NIGHT, WESTFALL, { C.SMALLFISH }))))
		end)
	end)

	describe("moments (HNT-R185; the groupmate's name and the party toast are #646's)", function()
		it(
			"hands a live Party Catch that reaches a tier to the moments, as its own record, and reports Coins",
			function()
				local pc = partyCatch(cast(0, NIGHT, DARKSHORE, { C.NIGHTFIN }), nil, true)

				local state, reports = fold(log({ pc }), "live")

				assert.are.equal(1, #raised)
				assert.are.same({ "party", pc.id }, { raised[1].record.kind, raised[1].record.id })
				assert.are.same({ { hunt = "fixture_snapper", tier = 1 } }, raised[1].reached.tiers)
				assert.are.same({ state.coins }, reports.coins)
			end
		)

		it("raises nothing in a catch-up or a rebuild, nor for a live one that reaches nothing new", function()
			local t = hunts.at(0, NIGHT)
			local records = log({
				partyCatch(castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN })),
				partyCatch(castAt(t + 60, NIGHT, DARKSHORE, { C.NIGHTFIN })),
			})

			fold(records, "replay")
			fold(records, "rebuild")
			assert.are.same({}, raised)

			local def = defOver(records, { coins = {}, xp = {}, tickets = {} })
			local state = def.reset()
			def.apply(state, records[1], "rebuild")
			def.apply(state, records[2], "live")
			assert.are.same({}, raised)
		end)
	end)

	describe("on the board (HNT-R186, HNT-R208)", function()
		local SOURCES = {
			AreaName = function(areaID)
				return C.NAMES.areas[areaID]
			end,
		}

		-- A tier reached on realm date 12 October 2026 in `zone`, by a Party Catch when `party`.
		local function tier(zone, party)
			return {
				time = SERVER_TIME,
				catchId = "c1",
				itemID = C.NIGHTFIN,
				zone = zone,
				date = { year = 2026, month = 10, day = 12 },
				party = party,
			}
		end

		-- fixture_snapper's ladder (tiers 1, 10, 40) with `reached`.
		local function ladder(reached)
			local progress = { count = #reached, effort = 0, sinceLast = 0, caught = true, reached = reached }
			return ns.HuntLadder(ns.hunts:Hunt("fixture_snapper"), progress, SOURCES)
		end

		it("writes 'party' after a party tier's date and zone, with the tooltip saying what it is", function()
			local tiers = ladder({ tier(C.DARKSHORE, true), tier(0, true) }).tiers

			assert.are.same({
				tier = 1,
				threshold = 1,
				reached = true,
				when = "12 Oct, Darkshore · party",
				party = true,
				tooltip = {
					"A groupmate's catch, while you fished the same water.",
					"On pagle.app it counts once your groupmate has uploaded their Catch log too.",
				},
			}, tiers[1])
			assert.are.equal("12 Oct · party", tiers[2].when)
		end)

		it("leaves a tier the Angler's own Catch reached as it was", function()
			assert.are.same(
				{ tier = 1, threshold = 1, reached = true, when = "12 Oct, Darkshore" },
				ladder({ tier(C.DARKSHORE) }).tiers[1]
			)
		end)
	end)

	describe("a rebuild folds to the state the live entries did (HNT-R183, HNT-R191, LOG-R122)", function()
		it("gives the same state live, in a catch-up and in a rebuild, run records and titles included", function()
			local S, E = MARCH_1, MARCH_1 + 3 * DAY
			local records = log({
				castAt(S + 10, DUSK, DARKSHORE, { C.DEVIATE }),
				partyCatch(castAt(S + 20, NIGHT, AUBERDINE, { C.NIGHTFIN, C.NIGHTFIN }), nil, true),
				runRecord("fixture_shore", S, E, S + 60),
				castAt(S + 90, DAY_MINUTE, WESTFALL, { C.UNCOMMON }, { C.RACK_AURA }),
				partyCatch(castAt(S + 120, DUSK, DARKSHORE, { C.DEVIATE }), nil, true),
				runRecord("fixture_vale", S + HOUR, E, S + HOUR),
				partyCatch(castAt(S + 2 * HOUR, DAY_MINUTE, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON }), nil, true),
				castAt(S + 3 * HOUR, NIGHT, DARKSHORE, { C.NIGHTFIN }),
			})

			local live = fold(records, "live")
			local replayed = fold(records, "replay")
			local rebuilt = fold(records, "rebuild")

			assert.are.same(live, rebuilt)
			assert.are.same(live, replayed)
			-- What it folded: both runs completed, fixture_wagers' title earned.
			assert.are.same({ 2, true }, { live.settled, live.sets.fixture_wagers ~= nil })
		end)

		it("folds a log with no Party Catch to the state it had (HNT-R187)", function()
			local records = log({
				cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }),
				cast(2, DUSK, DARKSHORE, { C.DEVIATE }),
			})

			local state = fold(records)

			assert.are.same({ 2, 2 * ns.COINS_COMPLETED }, { state.casts, state.coins })
			for _, progress in pairs(state.hunts) do
				for _, tier in ipairs(progress.reached) do
					assert.is_nil(tier.party)
				end
			end
		end)
	end)

	describe("registration (HNT-R136, HNT-R187)", function()
		it("takes Party Catches, filters them, and is rules version 5", function()
			local def = defOver({}, { coins = {}, xp = {}, tickets = {} })

			assert.are.same({ 5, true, "function" }, { def.rulesVersion, def.partyCatches, type(def.wantsPartyCatch) })
		end)
	end)

	describe("edge cases", function()
		it(
			"keeps what Party Catches credited once the party ends, through later Casts and a rebuild (HNT-R205)",
			function()
				local t = hunts.at(0, NIGHT)
				local records = log({
					partyCatch(castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN })),
					castAt(t + DAY, DAY_MINUTE, WESTFALL, { C.SMALLFISH }),
					castAt(t + 2 * DAY, NIGHT, WESTFALL),
				})

				local live = fold(records, "live")

				assert.is_true(live.hunts.fixture_snapper.reached[1].party)
				assert.are.same(live, fold(records))
			end
		)

		it(
			"counts one item once toward each Hunt it qualifies for, and two groupmates' Catches each (HNT-R207)",
			function()
				local S, E = MARCH_1, MARCH_1 + 3 * DAY
				local t = S + HOUR
				-- Two groupmates' Casts of a Nightfin, the same second, in different subzones: two copies, both logged.
				local records = log({
					runRecord("fixture_shore", S, E),
					partyCatch(castAt(t, NIGHT, DARKSHORE, { C.NIGHTFIN }), t + 1),
					partyCatch(castAt(t, NIGHT, AUBERDINE, { C.NIGHTFIN }), t + 2),
				})

				local state = fold(records)

				local run = state.runs["fixture_shore@" .. S]
				assert.are.same({ 2, 2, 2 }, {
					state.hunts.fixture_snapper.count,
					run.hunts.fixture_shore_snapper.count,
					run.hunts.fixture_shore_haul.count,
				})
			end
		)
	end)
end)
