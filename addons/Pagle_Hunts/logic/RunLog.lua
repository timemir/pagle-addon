if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Which runs are on, and the records that make them known (HNT-R150–R155, HNT-R160, HNT-R200–R204): the companion's
-- pushed runs and definitions as one login's snapshot, the precedence between them and the fallback rotation
-- (logic/Rotation.lua), the runs the board shows, and the live step that logs each run Hunts uses the first time it
-- uses it. Pure logic over what it is handed (CORE-R7): the pool (`ns.events`), the rotation's origin and the
-- outlets are read at call time; the step appends through the Module handle it was made with. This is the only file
-- that appends Hunts' records (hunts.md › Contracts, spec/Pagle_Hunts/boundary_spec.lua).
--
-- The step never runs inside an apply or a done (LOG-R40): adapter/RunLog.lua schedules it for a later frame after
-- each regroup (HNT-R42), at login once PushedContentReady has fired (HNT-R151) and after each done, and it does
-- nothing while the projection is updating. Each record it appends is applied "live" at once (LOG-R73), so the next
-- step reads it back as a known run and appends nothing for it again.
--
-- Catch-ups (HNT-R155): Casts replayed while Hunts was off may fall in fallback slots nobody logged, and no record
-- may be appended during the replay. So the fold notes the earliest and latest replayed Cast times here
-- (ns.NoteReplayedCast, in memory only), and the next step logs a run for each uncovered slot in that span, by the
-- current rotation rule; folding each `run` record then credits those Casts (HNT-R149, logic/Runs.lua).

-- The pushed content this login (PUSH-R15, PUSH-R22) --------------------------------------------------------------

--- A `huntRun` item kept from the snapshot (hunts.md › Pushed Hunt Events and runs): its event ID and its exact
--- server times.
---@class HuntsPushedRun
---@field event string
---@field start integer
---@field end_ integer

--- A checked `huntEvent` item (HNT-R140): the event at runtime, and the `def` payloads that log it (HNT-R154).
---@class HuntsPushedEvent
---@field event HuntEvent
---@field parts string[]

--- One login's pushed content, as Hunts reads it once PushedContentReady has fired: the companion's state, fixed for
--- the login (PUSH-R15), the `huntEvent` items that pass the in-game checks, by ID, the first of an ID winning, and
--- the well-formed `huntRun` items in payload order.
---@class HuntsPushedSnapshot
---@field companion PagleCompanionState
---@field events table<string, HuntsPushedEvent>
---@field runs HuntsPushedRun[]

-- Whether `value` is a whole number at least 0.
---@param value any
---@return boolean
local function whole(value)
	return type(value) == "number" and value >= 0 and value % 1 == 0
end

--- Reads one login's pushed content (HNT-R140, HNT-R151, hunts.md › Contracts): each `huntEvent` item is checked with
--- ns.HuntEventProblem and written in the content grammar for its `def` records; one that fails, or whose ID came
--- earlier, is ignored with a dev diagnostic line (`ns.outlets.Diagnostic`). A `huntRun` item needs an event ID and
--- whole server times with `start < end`; one without is ignored the same way. Whether a run's event is known is
--- judged when it is used (ns.PushedRuns).
---@param companion PagleCompanionState
---@param eventItems table[] `Pagle.GetPushedContent("huntEvent")`
---@param runItems table[] `Pagle.GetPushedContent("huntRun")`
---@param lookups HuntsCoreLookups
---@return HuntsPushedSnapshot
function ns.ReadPushedSnapshot(companion, eventItems, runItems, lookups)
	local events, runs = {}, {}
	for _, item in ipairs(eventItems) do
		local id = type(item) == "table" and item.id or nil
		local problem = ns.HuntEventProblem(item, lookups)
		local text, parts
		if not problem and events[id] then
			problem = "its id came earlier in the snapshot"
		end
		if not problem then
			text, problem = ns.WriteContentItem(item)
		end
		if text then
			local ok, encoded = pcall(ns.EncodeDefParts, id, text)
			if ok then
				parts = encoded
			else
				problem = "its definition can't be logged"
			end
		end
		if problem then
			ns.outlets.Diagnostic(ns.L.RUN_LOG_EVENT_IGNORED:format(tostring(id), problem))
		else
			---@cast id string -- checked: an ID starting p_ (ns.HuntEventProblem)
			events[id] = {
				event = ns.NewHuntEvent(item --[[@as HuntEventData]], true, lookups),
				parts = parts,
			}
		end
	end
	for _, item in ipairs(runItems) do
		local event = type(item) == "table" and item.event or nil
		local start, end_ = type(item) == "table" and item.start, type(item) == "table" and item["end"]
		if type(event) == "string" and event:find("^[%w_]+$") and whole(start) and whole(end_) and start < end_ then
			runs[#runs + 1] = { event = event, start = start, end_ = end_ }
		else
			ns.outlets.Diagnostic(ns.L.RUN_LOG_RUN_IGNORED:format(tostring(event)))
		end
	end
	return { companion = companion, events = events, runs = runs }
end

-- Whether two spans [start, end) overlap.
local function overlaps(a, b)
	return a.start < b.end_ and b.start < a.end_
end

--- A pushed run Hunts would use (HNT-R151): its run key, its event at runtime, the run (HuntRun's fields, source
--- `p`, no progress), whether it is logged already, and for an event known only from the snapshot, the `def` payloads
--- to log before it (HNT-R154).
---@class HuntsPushedUse
---@field key string
---@field event HuntEvent
---@field run HuntRun
---@field logged boolean
---@field parts string[]?

--- The snapshot's pushed runs Hunts would use, in payload order (HNT-R142, HNT-R151, hunts.md › Pushed Hunt Events
--- and runs): each whose event is pooled, logged earlier or delivered in the same snapshot (a logged definition
--- winning over the snapshot's, since a definition never changes), and that doesn't overlap a known run of the same
--- event (unless it is that run, logged) or an earlier unlogged one of this list. Ended ones are listed too; the caller
--- judges the time.
---@param state HuntsState
---@param snapshot HuntsPushedSnapshot
---@return HuntsPushedUse[]
function ns.PushedRuns(state, snapshot)
	local known = ns.RunsKnown(state)
	local out = {}
	for _, pushed in ipairs(snapshot.runs) do
		local key = ns.RunKey(pushed.event, pushed.start)
		local logged = state.runs ~= nil and state.runs[key] ~= nil
		local event, parts = ns.KnownEvent(state, pushed.event), nil
		if not event and snapshot.events[pushed.event] then
			event, parts = snapshot.events[pushed.event].event, snapshot.events[pushed.event].parts
		end
		local clash = false
		if event and not logged then
			for _, on in ipairs(known) do
				clash = clash or (on.run.event == pushed.event and overlaps(on.run, pushed))
			end
			for _, use in ipairs(out) do
				clash = clash or (not use.logged and use.run.event == pushed.event and overlaps(use.run, pushed))
			end
		end
		if event and not clash then
			out[#out + 1] = {
				key = key,
				event = event,
				run = { event = pushed.event, start = pushed.start, end_ = pushed.end_, source = "p", hunts = {} },
				logged = logged,
				parts = parts,
			}
		end
	end
	return out
end

-- What the run log plans (HNT-R151, HNT-R153, HNT-R155) ----------------------------------------------------------

---@class HuntsRunLogInput
---@field state HuntsState
---@field now integer
---@field snapshot HuntsPushedSnapshot
---@field pool HuntEvent[]   -- the pool's events (ns.events:Events())
---@field replayed { first: integer, last: integer }?   -- the replayed Casts' earliest and latest times (HNT-R155)

--- One record the run log appends: its kind (`run` or `def`) and payload (hunts.md › Contracts).
---@class HuntsLogRecord
---@field kind "run"|"def"
---@field payload string

-- The spans a slot can't overlap: every known run, then the runs planned so far.
---@param state HuntsState
---@return { event: string, start: integer, end_: integer }[]
local function knownSpans(state)
	local spans = {}
	for i, on in ipairs(ns.RunsKnown(state)) do
		spans[i] = on.run
	end
	return spans
end

-- Whether any of `spans` overlaps [start, end), optionally only those of event `id`.
local function anyOverlap(spans, span, id)
	for _, other in ipairs(spans) do
		if (not id or other.event == id) and overlaps(other, span) then
			return true
		end
	end
	return false
end

-- Slot `k`'s event for the rotation to log or show (HNT-R152, HNT-R153), or nil when `spans` cover it or every pick
-- is busy: a pick is busy when a run of its event in `spans`, or one of `ahead` (pushed runs not logged yet, still to
-- come), overlaps the slot.
---@param pool HuntEvent[]
---@param slot HuntsRotationSlot
---@param spans { event: string, start: integer, end_: integer }[]
---@param ahead { event: string, start: integer, end_: integer }[]
---@return HuntEvent?
local function slotEvent(pool, slot, spans, ahead)
	if anyOverlap(spans, slot) then
		return nil
	end
	return ns.RotationPick(pool, slot.slot, function(event)
		return anyOverlap(spans, slot, event.id) or anyOverlap(ahead, slot, event.id)
	end)
end

--- The records the run log appends now, in order (HNT-R150, HNT-R151, HNT-R153–R155):
--- 1. for each pushed run on now (`start <= now < end`) that isn't logged (ns.PushedRuns), first its event's `def`
---    parts if the event is known only from the snapshot (and not planned already), then its `run` with its real
---    `start` and `end` and source `p`; an ahead or ended one is never logged;
--- 2. unless the companion is `"connected"`, for each fallback slot from the replayed Casts' span (HNT-R155) and the
---    slot holding now, in slot order, that no known or planned run overlaps: a `run` with the slot's bounds and
---    source `r`, of its pick, or the band's next pick when the slot's own has a run in the slot (HNT-R153).
--- A logged run is never changed or withdrawn: nothing here touches one.
---@param input HuntsRunLogInput
---@return HuntsLogRecord[]
function ns.PlanRunLog(input)
	local state, now, snapshot = input.state, input.now, input.snapshot
	local records, spans, ahead, defs = {}, knownSpans(state), {}, {}
	for _, use in ipairs(ns.PushedRuns(state, snapshot)) do
		local run = use.run
		if not use.logged and run.start <= now and now < run.end_ then
			if use.parts and not defs[run.event] then
				defs[run.event] = true
				for _, payload in ipairs(use.parts) do
					records[#records + 1] = { kind = ns.DEF_RECORD, payload = payload }
				end
			end
			records[#records + 1] =
				{ kind = ns.RUN_RECORD, payload = ns.EncodeRun(run.event, run.start, run.end_, "p") }
			spans[#spans + 1] = run
		elseif not use.logged and now < run.start then
			ahead[#ahead + 1] = run
		end
	end
	if snapshot.companion == "connected" then
		return records
	end
	local current = ns.RotationSlotAt(now)
	if not current then
		return records
	end
	local from = current
	local replayed = input.replayed
	if replayed and replayed.last >= ns.ROTATION_ORIGIN then
		from = math.min(current, ns.RotationSlotAt(math.max(replayed.first, ns.ROTATION_ORIGIN)) --[[@as integer]])
	end
	for k = from, current do
		local slot = ns.RotationSlot(k)
		local inSpan = k == current or (replayed ~= nil and slot.end_ > replayed.first and slot.start <= replayed.last)
		local event = inSpan and slotEvent(input.pool, slot, spans, ahead)
		if event then
			records[#records + 1] =
				{ kind = ns.RUN_RECORD, payload = ns.EncodeRun(event.id, slot.start, slot.end_, "r") }
			spans[#spans + 1] = { event = event.id, start = slot.start, end_ = slot.end_ }
		end
	end
	return records
end

-- The catch-up's span (HNT-R155): the earliest and latest replayed Cast times since the last step took it.
---@type { first: integer, last: integer }?
local replayed

--- Notes a Cast folded in `"replay"` mode (HNT-R155): its time widens the span the next step logs slots over. Called
--- by the projection's apply (logic/Projection.lua); kept in memory only, as no record can be appended during the
--- replay (LOG-R40).
---@param time integer
function ns.NoteReplayedCast(time)
	if replayed then
		replayed.first, replayed.last = math.min(replayed.first, time), math.max(replayed.last, time)
	else
		replayed = { first = time, last = time }
	end
end

-- The runs the board shows (HNT-R160, HNT-R204) -------------------------------------------------------------------

--- One run the board, the ribbon and the tracker show (HNT-R160):
--- - `key`: its run key (HNT-R142);
--- - `run`: for a run on, the known HuntRun itself, progress and all (read it with ns.RunProgress); for a run ahead, a
---   HuntRun-shaped table with its event ID, `start`, `end_` and `source` and no progress (`hunts = {}`);
--- - `event`: its Hunt Event at runtime (logic/Events.lua; names through ns.events:EventName and :HuntName), the
---   pool's, a logged pushed definition's, or for a pushed run ahead the snapshot's checked one;
--- - `on`: true for a run on (known, HNT-R150), false for a run ahead (not logged yet, so it may still be withdrawn).
---@class HuntsShownRun
---@field key string
---@field run HuntRun
---@field event HuntEvent
---@field on boolean

---@return HuntsPushedSnapshot?
local function currentSnapshot()
	local runLog = ns.runLog
	return runLog and runLog:Snapshot() or nil
end

---@return HuntEvent[]
local function currentPool()
	return ns.events and ns.events:Events() or {}
end

--- The runs the board shows at server time `now` (HNT-R160): the runs on (known, `start <= now < end`), ordered by
--- `end`, then `start`, then event ID; then the runs ahead, ordered by `start`, then event ID: the snapshot's pushed
--- runs not started yet that Hunts would use (ns.PushedRuns), and the next fallback slot's pick when the rotation
--- would fill it (the companion not `"connected"`, now at or after the origin, and no known run, nor a pushed run
--- starting by the slot's start, overlapping it, HNT-R153). Before the snapshot is read (the companion `"checking"`),
--- only the runs on. Before the origin with no pushed run, empty (HNT-R204). A run ended is never listed (HNT-R143).
---@param state HuntsState
---@param now integer
---@param snapshot HuntsPushedSnapshot? the current login's by default (ns.runLog)
---@param pool HuntEvent[]? the pool's events by default (ns.events)
---@return HuntsShownRun[]
function ns.RunsShown(state, now, snapshot, pool)
	snapshot = snapshot or currentSnapshot()
	pool = pool or currentPool()
	local shown = {}
	for _, on in ipairs(ns.RunOn(state, now)) do
		local event = ns.KnownEvent(state, on.run.event)
		if event then
			shown[#shown + 1] = { key = on.key, run = on.run, event = event, on = true }
		end
	end
	if not snapshot then
		return shown
	end
	local ahead, coming = {}, {}
	for _, use in ipairs(ns.PushedRuns(state, snapshot)) do
		if not use.logged and now < use.run.start then
			ahead[#ahead + 1] = { key = use.key, run = use.run, event = use.event, on = false }
			coming[#coming + 1] = use.run
		end
	end
	local current = ns.RotationSlotAt(now)
	if snapshot.companion ~= "connected" and current then
		local slot = ns.RotationSlot(current + 1)
		local spans = knownSpans(state)
		-- A pushed run starting by the slot's start is logged by then, and covers it.
		local later = {}
		for _, run in ipairs(coming) do
			if run.start <= slot.start then
				spans[#spans + 1] = run
			else
				later[#later + 1] = run
			end
		end
		local event = slotEvent(pool, slot, spans, later)
		if event then
			ahead[#ahead + 1] = {
				key = ns.RunKey(event.id, slot.start),
				run = { event = event.id, start = slot.start, end_ = slot.end_, source = "r", hunts = {} },
				event = event,
				on = false,
			}
		end
	end
	table.sort(ahead, function(a, b)
		if a.run.start ~= b.run.start then
			return a.run.start < b.run.start
		end
		return a.run.event < b.run.event
	end)
	for _, entry in ipairs(ahead) do
		shown[#shown + 1] = entry
	end
	return shown
end

--- The earliest server time after `now` at which the runs on or ahead change (HNT-R42): a known run's `start` or
--- `end`, a pushed run's (from the snapshot), or the next fallback slot's turn (the origin itself before it). The
--- regroup timer is set to it; the live step after that regroup logs what is due.
---@param state HuntsState
---@param now integer
---@param snapshot HuntsPushedSnapshot? the current login's by default
---@return integer
function ns.NextRunEdge(state, now, snapshot)
	snapshot = snapshot or currentSnapshot()
	local current = ns.RotationSlotAt(now)
	local edge = current and ns.RotationSlot(current + 1).start or ns.ROTATION_ORIGIN
	local function consider(t)
		if t > now and t < edge then
			edge = t
		end
	end
	for _, on in ipairs(ns.RunsKnown(state)) do
		consider(on.run.start)
		consider(on.run.end_)
	end
	for _, run in ipairs(snapshot and snapshot.runs or {}) do
		consider(run.start)
		consider(run.end_)
	end
	return edge
end

-- The live step (HNT-R151) ------------------------------------------------------------------------------------------

--- What the run log reads besides its state: the server time, the companion's state and pushed content (PUSH-R15,
--- PUSH-R22), the projection's state and whether it is updating (ns.State, ns.IsUpdating), and Qualify's lookups for
--- the checks (HNT-R140).
---@class HuntsRunLogClient
---@field ServerTime fun(): integer
---@field CompanionState fun(): PagleCompanionState
---@field PushedContent fun(kind: string): table[]
---@field State fun(): HuntsState
---@field IsUpdating fun(): boolean
---@field lookups HuntsCoreLookups

---@class PagleHuntsNS
---@field runLog HuntsRunLog? -- the run log, made in OnInitialize (adapter/RunLog.lua's ns.StartRunLog)

---@class HuntsRunLog
---@field module PagleModuleHandle
---@field client HuntsRunLogClient
---@field snapshot HuntsPushedSnapshot?
---@field appended table<string, true>   -- "<kind>|<payload>" of each record appended this login
local RunLog = {}
RunLog.__index = RunLog

--- The run log over Hunts' Module handle `M` (the one that appends its records, LOG-R40) and `client`.
---@param M PagleModuleHandle
---@param client HuntsRunLogClient
---@return HuntsRunLog
function ns.NewRunLog(M, client)
	return setmetatable({ module = M, client = client, appended = {} }, RunLog)
end

--- This login's pushed content (HuntsPushedSnapshot), read once the check has ended (PushedContentReady, PUSH-R16),
--- the same for the rest of the login; nil while the companion is `"checking"`.
---@return HuntsPushedSnapshot?
function RunLog:Snapshot()
	if not self.snapshot then
		local client = self.client
		local companion = client.CompanionState()
		if companion == "checking" then
			return nil
		end
		self.snapshot = ns.ReadPushedSnapshot(
			companion,
			client.PushedContent("huntEvent"),
			client.PushedContent("huntRun"),
			client.lookups
		)
	end
	return self.snapshot
end

--- The live step (HNT-R151): unless the projection is updating or the companion is still `"checking"`, appends what
--- ns.PlanRunLog says, each record once per login, then forgets the catch-up's span. Returns how many records it
--- appended, or false when it didn't run. Never call it from an apply or a done (LOG-R40): schedule it.
---@return integer|false
function RunLog:Step()
	local client = self.client
	if client.IsUpdating() then
		return false
	end
	local snapshot = self:Snapshot()
	if not snapshot then
		return false
	end
	local plan = ns.PlanRunLog({
		state = client.State(),
		now = client.ServerTime(),
		snapshot = snapshot,
		pool = currentPool(),
		replayed = replayed,
	})
	replayed = nil
	local count = 0
	for _, record in ipairs(plan) do
		local id = record.kind .. "|" .. record.payload
		if not self.appended[id] then
			self.appended[id] = true
			self.module:AppendRecord(record.kind, record.payload)
			count = count + 1
		end
	end
	return count
end
