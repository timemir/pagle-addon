if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunt Events' runs in Hunts' fold (HNT-R142–R150, HNT-R154, HNT-R199, HNT-R200): pure logic over the projection
-- state (hunts.md › Projection state), everything passed in (CORE-R7); the pool (`ns.events`) and the outlets are read
-- at call time. The projection (logic/Projection.lua) calls ns.ApplyRunRecord for its `run` and `def` records, and
-- ns.CreditRunCast and ns.SettleRun for every known run on at each Cast's time. Which runs get logged, and when, is
-- the run log's (#300): it reads ns.RunsKnown and the event lookups here, and appends the records this file folds.
--
-- Casts before their run's record: a run's record can come after Casts it must credit (a pushed run logged mid-run
-- with its real `start`, HNT-R151; the slots a catch-up logs, HNT-R155), and those Casts count (HNT-R149, HNT-R200).
-- So folding a `run` record walks the run's earlier Casts again with M:IterateCatches, from the first Cast at or
-- after its `start` up to the record, and credits them in order as `apply` would, without moments (HNT-R149). The
-- state's hour index (`hours`, server hour to the first seq of a Cast in it, for the last 14 days of Casts, Tunables)
-- says where to start; a run older than that is credited from the index's start. A rebuild reads the log in the same
-- order, so it folds to the same state as the live entries did.

--- A run's key (HNT-R142): `<eventID>@<start>`.
---@param eventID string
---@param start integer
---@return string
function ns.RunKey(eventID, start)
	return eventID .. "@" .. start
end

--- What a Cast or a `run` record newly reached (HNT-R91, HNT-R137 step 4), beside a Standing Hunt's tiers and set
--- titles (HuntsReached, logic/Projection.lua): each event Hunt's newly reached tier in a run, each run it completed
--- and each ladder step it reached, in the order reached. The moments read them (#301).
---@class HuntsRunsReached
---@field marks { run: string, hunt: string, tier: integer }[]   -- `state.runs[run].hunts[hunt].reached[tier]`
---@field settled string[]   -- run keys; `state.runs[key].completedAt`
---@field ladder integer[]   -- ladder steps; `state.ladder[step]`

-- Pushed events read from logged definitions (HNT-R154), by the state's `defs` entry they were read from: a complete
-- entry never changes again (its parts are kept first-come), so each is read and checked once per load and state.
-- false for one that failed.
local readEvents = setmetatable({}, { __mode = "k" })

-- The text of a complete `defs` entry, its parts joined in part order, or nil while a part is missing (HNT-R154).
---@param entry { parts: integer, texts: table<integer, string> }
---@return string?
local function reassemble(entry)
	local texts = {}
	for part = 1, entry.parts do
		local text = entry.texts[part]
		if not text then
			return nil
		end
		texts[part] = text
	end
	return table.concat(texts)
end

--- The Hunt Event with this ID that `state` knows (HNT-R140, HNT-R154): the pool's (`ns.events`), else the pushed
--- definition its `def` records carry, once every part is in, read with Hunts' own reader and passing the in-game
--- checks (logic/Content.lua). A definition with a part missing is unknown; one that fails is ignored, with a dev
--- diagnostic line (`ns.outlets.Diagnostic`). Nil for an unknown event.
---@param state HuntsState
---@param id string
---@param lookups HuntsCoreLookups? Qualify's lookups; ns.lookups by default
---@return HuntEvent?
function ns.KnownEvent(state, id, lookups)
	local pool = ns.events and ns.events:Event(id)
	if pool then
		return pool
	end
	local entry = state.defs and state.defs[id]
	if not entry then
		return nil
	end
	local read = readEvents[entry]
	if read ~= nil then
		return read or nil
	end
	local text = reassemble(entry)
	if not text then
		return nil
	end
	lookups = lookups or ns.lookups
	local item, problem = ns.ReadContentItem(text)
	if item and item.id ~= id then
		problem = ("its id %s isn't its records' %s"):format(tostring(item.id), id)
	elseif item then
		problem = ns.HuntEventProblem(item, lookups)
	end
	if problem then
		readEvents[entry] = false
		ns.outlets.Diagnostic(("Hunts: the logged definition of %s is ignored: %s (HNT-R140)"):format(id, problem))
		return nil
	end
	local event = ns.NewHuntEvent(item --[[@as HuntEventData]], true, lookups)
	readEvents[entry] = event
	return event
end

-- The known runs by end, then start, then event ID, each with its key: made from `state.runs` when first asked and
-- again after a run is added, by the runs table it was made from.
local byEnd = setmetatable({}, { __mode = "k" })

---@param state HuntsState
---@return { key: string, run: HuntRun }[]
local function runsByEnd(state)
	local runs = state.runs or {}
	local sorted = byEnd[runs]
	if sorted then
		return sorted
	end
	sorted = {}
	for key, run in pairs(runs) do
		sorted[#sorted + 1] = { key = key, run = run }
	end
	table.sort(sorted, function(a, b)
		local x, y = a.run, b.run
		if x.end_ ~= y.end_ then
			return x.end_ < y.end_
		elseif x.start ~= y.start then
			return x.start < y.start
		end
		return x.event < y.event
	end)
	byEnd[runs] = sorted
	return sorted
end

--- The known runs on at server time `t` (HNT-R143, HNT-R144: `start <= t < end`), with their keys, ordered by end,
--- then start, then event ID (HNT-R160). A Cast landing exactly at `end` belongs only to a run starting there
--- (HNT-R199).
---@param state HuntsState
---@param t integer
---@return { key: string, run: HuntRun }[]
function ns.RunsOnAt(state, t)
	local sorted = runsByEnd(state)
	-- The first run whose end is after t, by halving: the ones before it have all ended.
	local lo, hi = 1, #sorted + 1
	while lo < hi do
		local mid = math.floor((lo + hi) / 2)
		if sorted[mid].run.end_ > t then
			hi = mid
		else
			lo = mid + 1
		end
	end
	local on = {}
	for i = lo, #sorted do
		if sorted[i].run.start <= t then
			on[#on + 1] = sorted[i]
		end
	end
	return on
end

-- Whether two spans [start, end) overlap.
local function overlaps(a, b)
	return a.start < b.end_ and b.start < a.end_
end

--- Adds a decoded `run` record's run to `state.runs` (HNT-R150), unless it names an event `state` doesn't know or
--- overlaps a known run of the same event, the one logged first winning (HNT-R142). Returns the new run, its key and
--- its event, or nil when it was ignored.
---@param state HuntsState
---@param record HuntRunRecord
---@param lookups HuntsCoreLookups?
---@return HuntRun? run
---@return string? key
---@return HuntEvent? event
function ns.AddRun(state, record, lookups)
	local event = ns.KnownEvent(state, record.event, lookups)
	if not event then
		return nil
	end
	for _, run in pairs(state.runs) do
		if run.event == record.event and overlaps(run, record) then
			return nil
		end
	end
	local key = ns.RunKey(record.event, record.start)
	local run = { event = record.event, start = record.start, end_ = record.end_, source = record.source, hunts = {} }
	state.runs[key] = run
	byEnd[state.runs] = nil
	return run, key, event
end

--- Adds a decoded `def` record's part to `state.defs` (HNT-R154): kept by event ID, each part once, the first record
--- of a part winning; a part whose count of parts differs from the event's first is skipped, and so is any part for
--- a pool event. Returns whether it was added.
---@param state HuntsState
---@param record HuntDefRecord
---@return boolean
function ns.AddDefPart(state, record)
	if ns.events and ns.events:Event(record.event) then
		return false
	end
	local entry = state.defs[record.event]
	if not entry then
		entry = { parts = record.parts, texts = {} }
		state.defs[record.event] = entry
	elseif entry.parts ~= record.parts or entry.texts[record.part] then
		return false
	end
	entry.texts[record.part] = record.text
	return true
end

--- What an event Hunt reaching tier `k` of a run pays in Refreshes (HNT-R116): `ns.TICKETS_TIER3` at tier 3, nothing at
--- any other tier, so a Hunt pays it once per run.
---@param k integer
---@return integer
function ns.TierTickets(k)
	return k == 3 and ns.TICKETS_TIER3 or 0
end

--- Credits one Cast to a known run on at its time (HNT-R144, HNT-R145, HNT-R137 step 2): for each Hunt of its event,
--- in file order, the effort counter first (HNT-R25, HNT-R26: its condition spec, the event's zones included), then
--- each qualifying Catch in loot-slot order, with the Coins and Activity XP each newly reached tier pays (HNT-R110,
--- HNT-R114). A Hunt of the run has progress once it has effort or a Catch.
---@param state HuntsState
---@param on { key: string, run: HuntRun }
---@param event HuntEvent
---@param cast PagleCast
---@param lookups HuntsLookups
---@param reached HuntsRunsReached
function ns.CreditRunCast(state, on, event, cast, lookups, reached)
	local run = on.run
	for _, hunt in ipairs(event.hunts) do
		local progress = run.hunts[hunt.id] or ns.NewHuntProgress()
		local spec = event.where[hunt.id].boardSpec
		if spec and lookups.MatchesConditions(spec, cast.conditions) then
			progress.effort = progress.effort + 1
			progress.sinceLast = progress.sinceLast + 1
		end
		local count = progress.count
		for _, k in ipairs(ns.CountQualifying(progress, hunt, cast, ns.MatchingCatches(hunt, cast, lookups))) do
			state.coins = state.coins + ns.TierAmount(ns.COINS_EVENT, k)
			state.xp = state.xp + ns.TierAmount(ns.XP_EVENT, k)
			state.tickets = state.tickets + ns.TierTickets(k) -- tier 3 only, so once per Hunt per run (HNT-R116)
			reached.marks[#reached.marks + 1] = { run = on.key, hunt = hunt.id, tier = k }
		end
		if progress.count > count then
			progress.sinceLast = 0
		end
		if progress.effort > 0 or progress.count > 0 then
			run.hunts[hunt.id] = progress
		end
	end
end

--- Completes a run once every Hunt of its event has reached tier 1 within it (HNT-R146): its `completedAt` is the
--- last of those tier-1 times. A completed run pays its Coins and Activity XP (HNT-R110, HNT-R114) and adds 1 to the
--- completed-run count, and the count reaching a ladder step records the step with that time, never lost
--- (HNT-R148). HNT-R137 step 3, after the set titles.
---@param state HuntsState
---@param on { key: string, run: HuntRun }
---@param event HuntEvent
---@param reached HuntsRunsReached
function ns.SettleRun(state, on, event, reached)
	local run = on.run
	if run.completedAt then
		return
	end
	local last = 0
	for _, hunt in ipairs(event.hunts) do
		local tier = run.hunts[hunt.id] and run.hunts[hunt.id].reached[1]
		if not tier then
			return
		end
		last = math.max(last, tier.time)
	end
	run.completedAt = last
	state.settled = state.settled + 1
	state.coins = state.coins + ns.COINS_RUN
	state.xp = state.xp + ns.XP_RUN
	state.tickets = state.tickets + ns.TICKETS_RUN -- once per run (HNT-R116)
	reached.settled[#reached.settled + 1] = on.key
	for _, step in ipairs(ns.LADDER_STEPS) do
		if state.settled >= step and not state.ladder[step] then
			state.ladder[step] = last
			reached.ladder[#reached.ladder + 1] = step
		end
	end
end

--- Notes a Cast in the state's hour index (hunts.md › Projection state, `hours`): the first seq of a Cast in each
--- server hour, for the last 14 days of Casts (Tunables); an hour older than that is dropped once a newer one comes.
---@param state HuntsState
---@param cast PagleCast
function ns.NoteCastHour(state, cast)
	local hours = state.hours
	local hour = math.floor(cast.time / 3600)
	if hours[hour] then
		return
	end
	hours[hour] = cast.seq
	local oldest = hour - ns.HOUR_INDEX_HOURS
	for h in pairs(hours) do
		if h < oldest then
			hours[h] = nil
		end
	end
end

-- The first seq the hour index holds for a Cast at or after server time `t`'s hour; the index's start for a time
-- older than it; nil when it holds no Cast from then on.
---@param state HuntsState
---@param t integer
---@return integer?
local function firstSeqFrom(state, t)
	local from, first = math.floor(t / 3600), nil
	for hour, seq in pairs(state.hours) do
		if hour >= from and (not first or seq < first) then
			first = seq
		end
	end
	return first
end

--- Folds one of Hunts' own Module records (HNT-R136, HNT-R137's last paragraph): a `run` record adds its run
--- (ns.AddRun), then credits the run's Casts already folded, from the first Cast at or after its `start` up to the
--- record, in order (HNT-R149); a `def` record adds its part (ns.AddDefPart). Neither counts as a Cast. Returns what
--- it newly reached, or nil when the record changed nothing: one the codec can't read (logic/Records.lua), another
--- kind, an ignored run or a part already in.
---@param state HuntsState
---@param record PagleModuleRecord
---@param lookups HuntsCoreLookups
---@param iterate (fun(afterSeq: integer): fun(): PagleRecord?)? M:IterateCatches
---@return HuntsReached?
function ns.ApplyRunRecord(state, record, lookups, iterate)
	local reached = ns.NewReached()
	if record.recordKind == ns.DEF_RECORD then
		local def = ns.DecodeDef(record.payload)
		return def and ns.AddDefPart(state, def) and reached or nil
	elseif record.recordKind ~= ns.RUN_RECORD then
		return nil
	end
	local decoded = ns.DecodeRun(record.payload)
	local run, key, event = nil, nil, nil
	if decoded then
		run, key, event = ns.AddRun(state, decoded, lookups)
	end
	if not run then
		return nil
	end
	---@cast key string
	---@cast event HuntEvent
	local first = firstSeqFrom(state, run.start)
	if iterate and first then
		local on = { key = key, run = run }
		for entry in iterate(first - 1) do
			if entry.seq >= record.seq then
				break
			end
			if entry.kind == "cast" and run.start <= entry.time and entry.time < run.end_ then
				---@cast entry PagleCast
				ns.CreditRunCast(state, on, event, entry, lookups, reached)
				ns.SettleRun(state, on, event, reached)
			end
		end
	end
	return reached
end

-- The seams for the run log (#300), the board and tracker (#302–#304) and the moments (#301) -----------------------

--- Every known run (HNT-R150), as `{ key, run }`, ordered by end, then start, then event ID: what the run log reads
--- to see which slots are covered and whether a run is already logged (HNT-R151, HNT-R153). A state without runs
--- (one stored before Hunt Events, while it rebuilds) has none. Read-only.
---@param state HuntsState
---@return { key: string, run: HuntRun }[]
function ns.RunsKnown(state)
	return { unpack(runsByEnd(state)) }
end

--- The known runs on at server time `t` (HNT-R143), as `{ key, run }`, ordered by end, then start, then event ID
--- (HNT-R160): what the board, the tracker and the run log read for "on now". Read-only.
---@param state HuntsState
---@param t integer
---@return { key: string, run: HuntRun }[]
function ns.RunOn(state, t)
	if not state.runs then
		return {}
	end
	return ns.RunsOnAt(state, t)
end

--- How far a run has come (HNT-R146, HNT-R161): `done` of its event's `total` Hunts at their first mark (tier 1), and
--- the closest unfinished one, `closest` (nil once all are done): the Hunt without its first mark whose count is the
--- largest share of its tier 1, the first in file order on a tie, with `count` and `of` (its tier 1). `event` is nil
--- for a run whose event `state` doesn't know. `state` is the projection's by default (ns.State()).
---@param run HuntRun
---@param state HuntsState?
---@return { done: integer, total: integer, closest: HuntEventHunt?, count: integer?, of: integer?, event: HuntEvent? }
function ns.RunProgress(run, state)
	local event = ns.KnownEvent(state or ns.State(), run.event)
	if not event then
		return { done = 0, total = 0 }
	end
	local done, closest, best = 0, nil, nil
	for _, hunt in ipairs(event.hunts) do
		local progress = run.hunts[hunt.id]
		if ns.HuntDone(progress) then
			done = done + 1
		else
			local share = (progress and progress.count or 0) / hunt.tiers[1]
			if not best or share > best.share then
				best = { share = share, count = progress and progress.count or 0 }
				closest = hunt
			end
		end
	end
	return {
		done = done,
		total = #event.hunts,
		closest = closest,
		count = best and best.count,
		of = closest and closest.tiers[1],
		event = event,
	}
end
