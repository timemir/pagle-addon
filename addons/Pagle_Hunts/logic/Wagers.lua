if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Pagle Wagers on the Board spread (HNT-R160, HNT-R161, HNT-R163, HNT-R164) as data: the wager strip above the
-- timeline's ruler, the WAGERS group's rows at the top of the timeline (logic/Timeline.lua puts them first), and a
-- run's entry on the right page. Pure logic, everything passed in (CORE-R7); the event pool (`ns.events`, for names)
-- is read at call time. adapter/Wagers.lua and adapter/Timeline.lua gather the inputs and draw the results; the Pagle
-- Wagers spread (#303) and the tracker's block (#304) read the same pieces.
--
-- Players see Hunt Events only as "Pagle Wagers" (CONTEXT.md); every word here is interface text in ns.L, and none
-- claims odds, a due fish or a chance (HNT-R27).

--- What the wager pieces are worked out from.
---@class WagersInput
---@field runs HuntsShownRun[]   -- ns.RunsShown(state, now): the runs on, then the runs ahead (HNT-R160)
---@field now integer            -- the grouping's time: countdowns count from it (HNT-R43)
---@field snapshot table         -- one live Pagle.GetConditions(): realm time (HNT-R50) and the live zone
---@field updating boolean       -- ns.IsUpdating(): nothing is drawn from the projection's state (HNT-R69)
---@field list HuntList          -- a fixed class's members (HNT-R54, HNT-R55)
---@field sources HuntNameSources

--- An event Hunt's shape (HNT-R163), worked out from its definition: "timed" with a `time` condition, "big" with a
--- `minBand`, "quality" for a quality class, "haul" for any fish, else "named". *Default chosen while building (#302):
--- HNT-R163 names the shape but not how it is read.*
---@alias EventHuntShape "timed"|"big"|"quality"|"haul"|"named"

--- An event Hunt's shape (HNT-R163): the first of these that fits, in this order.
---@param hunt HuntEventHunt
---@return EventHuntShape
function ns.EventHuntShape(hunt)
	if hunt.conditions and hunt.conditions.time then
		return "timed"
	elseif hunt.minBand then
		return "big"
	elseif hunt.class == "quality.uncommon" or hunt.class == "quality.rare" then
		return "quality"
	elseif hunt.class == "species.any" then
		return "haul"
	end
	return "named"
end

--- An event Hunt's shape and target line (HNT-R163): "Timed · Darkshore Grouper, 22:00–04:00", its target line by
--- HNT-R54 and, for a `time` condition, its ranges in HNT-R53's words.
---@param hunt HuntEventHunt
---@param list HuntList
---@param sources HuntNameSources
---@return string
function ns.EventHuntLine(hunt, list, sources)
	local L = ns.L
	local target = ns.HuntTargetLine(hunt, list, sources)
	local time = hunt.conditions and hunt.conditions.time
	if time then
		local ranges = {}
		for i, range in ipairs(time) do
			ranges[i] = L.TIME_RANGE:format(ns.FormatClock(range[1]), ns.FormatClock(range[2]))
		end
		target = L.RUN_TARGET_TIME:format(target, table.concat(ranges, L.JOIN_RANGES))
	end
	return L.RUN_HUNT_LINE:format(L.SHAPES[ns.EventHuntShape(hunt)], target)
end

--- The pay rule under a run's entry (HNT-R163), from the Tunables (HNT-R110, HNT-R114): what a first mark, a further
--- mark and a settled run pay.
---@return string
function ns.RunPayRule()
	return ns.L.RUN_PAY_RULE:format(
		ns.XP_EVENT[1],
		ns.COINS_EVENT[1],
		ns.XP_EVENT[2],
		ns.COINS_EVENT[2],
		ns.XP_RUN,
		ns.COINS_RUN
	)
end

--- Server time `t` as a realm weekday and clock time, "Sat 17:00" (HNT-R50), whatever the day: a run's end or start
--- is days away (HNT-R161, HNT-R203).
---@param t integer
---@param snapshot table one live Pagle.GetConditions()
---@return string
function ns.RealmWeekdayClock(t, snapshot)
	local clock = ns.RealmClockAt(t, snapshot)
	return ns.L.WEEKDAY_CLOCK:format(ns.FormatWeekday(clock.date), ns.FormatClock(clock.minute))
end

--- An event's name, a pushed definition's own or the pool's lore (ns.events, HNT-R140).
---@param event HuntEvent
---@return string
local function eventName(event)
	return ns.events and ns.events:EventName(event) or event.id
end

--- An event Hunt's name (ns.events, HNT-R140).
---@param hunt HuntEventHunt
---@return string
local function huntName(hunt)
	return ns.events and ns.events:HuntName(hunt) or hunt.id
end

--- The names of an event's zones, in its order (`C_Map.GetAreaInfo`, HNT-R161), "…" before one is known.
---@param event HuntEvent
---@param sources HuntNameSources
---@return string[]
function ns.EventZoneNames(event, sources)
	local names = {}
	for i, zone in ipairs(event.zones) do
		names[i] = sources.AreaName(zone) or ns.L.NAME_UNKNOWN
	end
	return names
end

--- The realm date a completed run was settled on (HNT-R146, HNT-R163): the stored date of the tier 1 that completed
--- it (hunts.md › Projection state: seal dates are stored realm dates), or its UTC day when none is found; nil for a
--- run not completed.
---@param run HuntRun
---@return { year: integer, month: integer, day: integer }?
function ns.RunSettledDate(run)
	if not run.completedAt then
		return nil
	end
	for _, progress in pairs(run.hunts) do
		local first = progress.reached[1]
		if first and first.time == run.completedAt then
			return first.date
		end
	end
	return ns.UtcDate(run.completedAt)
end

-- The wager strip ----------------------------------------------------------------------------------------------------

--- The wager strip above the timeline's ruler (HNT-R161): the first run on, or with none on the first run ahead.
---@class WagerStrip
---@field run string         -- the run it names: clicking it opens the Pagle Wagers spread on it (#303)
---@field on boolean
---@field kicker string      -- "Pagle Wagers"
---@field name string?       -- a run on: its event's name…
---@field zones string?      -- …its zones…
---@field closes string?     -- …"closes in 2d 4h" (HNT-R50, a server-time duration, HNT-R203)…
---@field pips boolean[]?    -- …and one pip per Hunt, in definition order, inked (true) at its first mark in this run;
--- nil while the projection updates (HNT-R69)
---@field updating string?   -- the updating line in place of the pips (HNT-R69)
---@field more string?       -- "+{n} more on the table" with more runs on
---@field next string?       -- none on: "Next: {name}, Sat 15:00", the first run ahead
---@field hint string?       -- the companion hint's line under it (HNT-R170), #305's to fill

--- The wager strip (HNT-R161), or nil with no run on or ahead (HNT-R204).
---@param input WagersInput
---@return WagerStrip?
function ns.BuildWagerStrip(input)
	local L, first = ns.L, input.runs[1]
	if not first then
		return nil
	end
	local strip = { run = first.key, on = first.on, kicker = L.WAGERS_KICKER }
	if not first.on then
		strip.next = L.STRIP_NEXT:format(eventName(first.event), ns.RealmWeekdayClock(first.run.start, input.snapshot))
		return strip
	end
	strip.name = eventName(first.event)
	strip.zones = table.concat(ns.EventZoneNames(first.event, input.sources), L.JOIN_ZONES)
	strip.closes = L.STRIP_CLOSES:format(ns.FormatDuration(first.run.end_ - input.now))
	if input.updating then
		strip.updating = L.UPDATING
	else
		strip.pips = {}
		for i, hunt in ipairs(first.event.hunts) do
			strip.pips[i] = ns.HuntDone(first.run.hunts[hunt.id])
		end
	end
	local on = 0
	for _, shown in ipairs(input.runs) do
		on = on + (shown.on and 1 or 0)
	end
	if on > 1 then
		strip.more = L.STRIP_MORE:format(on - 1)
	end
	return strip
end

-- The WAGERS group's rows ------------------------------------------------------------------------------------------

-- The time fields of an event Hunt's condition spec (HNT-R6), for its window on the ruler; nil without a `time`.
---@param hunt HuntEventHunt
---@return table?
local function timeSpec(hunt)
	local conditions = hunt.conditions
	if not (conditions and conditions.time) then
		return nil
	end
	return { time = conditions.time, season = conditions.season, events = conditions.events }
end

--- One run's row in the WAGERS group (HNT-R161): a TimelineRow (logic/Timeline.lua) with its run key.
---@param shown HuntsShownRun
---@param ruler { from: integer, to: integer }
---@param input WagersInput
---@return TimelineRow
local function runRow(shown, ruler, input)
	local run, event = shown.run, shown.event
	local span = ruler.to - ruler.from
	local function x(t)
		return (t - ruler.from) / span
	end
	-- Across the whole ruler while on, from its start while ahead; to its end, or the ruler's end when it outlasts it.
	local bars = {
		{ from = shown.on and 0 or math.max(0, x(run.start)), to = math.min(1, x(run.end_)), style = "run" },
	}
	local from, to = math.max(ruler.from, run.start), math.min(ruler.to, run.end_)
	for _, hunt in ipairs(event.hunts) do
		local spec = timeSpec(hunt)
		if spec and from < to then
			for _, window in ipairs(ns.TimelineSpans(spec, from, to, input.sources.NextWindow)) do
				bars[#bars + 1] = { from = x(window.from), to = x(window.to), style = "wager" }
			end
		end
	end
	local icon, tint = nil, nil
	if event.hunts[1] then
		icon, tint = ns.HuntIcon(event.hunts[1], input.list, input.sources)
	end
	local when = ns.RealmWeekdayClock(shown.on and run.end_ or run.start, input.snapshot)
	return {
		id = shown.key,
		run = shown.key,
		name = eventName(event),
		icon = icon,
		tint = tint,
		trim = nil,
		pinned = false,
		margin = shown.on and ns.L.LABEL_UNTIL:format(when) or when,
		tone = "wagers",
		bars = bars,
		more = run.end_ > ruler.to,
		selected = false,
	}
end

--- The WAGERS group's rows (HNT-R161): one per run on and per run ahead that starts within the ruler, in HNT-R160's
--- order. The group ignores "show completed" and pins (it has neither).
---@param input WagersInput
---@param ruler { from: integer, to: integer }
---@return TimelineRow[]
function ns.BuildWagerRows(input, ruler)
	local rows = {}
	for _, shown in ipairs(input.runs) do
		if shown.on or shown.run.start < ruler.to then
			rows[#rows + 1] = runRow(shown, ruler, input)
		end
	end
	return rows
end

-- A run's entry ----------------------------------------------------------------------------------------------------

--- One event Hunt in a run's entry (HNT-R163).
---@class RunEntryHunt
---@field id string
---@field name string
---@field line string             -- its shape and target line
---@field ladder HuntEntryLadder  -- its tier ladder in this run, or the updating line (HNT-R69)

--- A run's entry, top to bottom (HNT-R163). It has no pin toggle and no set line.
---@class RunEntry
---@field key string
---@field kicker string           -- "From the rotation · low waters", or "Sent by the companion"
---@field name string
---@field chips HuntEntryChip[]   -- its zones, the live zone first with "you're here" (HNT-R65's zone chips)
---@field until_ string           -- "until Sat 17:00"; for a run ahead "from Sat 15:00 until Tue 15:00"
---@field seal HuntEntrySeal      -- pressed "Settled 16 Oct" once completed, a dashed "not yet" before
---@field note string?            -- the event's note, in the hand
---@field hunts RunEntryHunt[]    -- in definition order
---@field casts string            -- "{n} Casts in these waters this run."
---@field soFar string            -- "So far +{xp} XP · {coins} Coins", this run's
---@field payRule string

-- The run's zone chips: its zones in its order, the live zone first with the "you're here" badge.
---@param event HuntEvent
---@param input WagersInput
---@return HuntEntryChip[]
local function zoneChips(event, input)
	local L, live = ns.L, input.snapshot.zone
	local chips = {}
	for _, zone in ipairs(event.zones) do
		local chip = { kind = "zone", text = input.sources.AreaName(zone) or L.NAME_UNKNOWN }
		if zone == live then
			chip.here, chip.badge = true, L.CHIP_HERE
			table.insert(chips, 1, chip)
		else
			chips[#chips + 1] = chip
		end
	end
	return chips
end

-- What a run has paid so far (HNT-R110, HNT-R114): every tier its Hunts reached in it, and the settled run on top.
---@param run HuntRun
---@return integer xp
---@return integer coins
local function paidSoFar(run)
	local xp, coins = 0, 0
	for _, progress in pairs(run.hunts) do
		for k in ipairs(progress.reached) do
			xp = xp + ns.TierAmount(ns.XP_EVENT, k)
			coins = coins + ns.TierAmount(ns.COINS_EVENT, k)
		end
	end
	if run.completedAt then
		xp, coins = xp + ns.XP_RUN, coins + ns.COINS_RUN
	end
	return xp, coins
end

-- The Casts made in a run's waters (HNT-R163): the most effort Casts any of its Hunts counted, as a Hunt whose spec
-- is only the event's zones counts every Cast there. *Decided while building (#302): the projection keeps effort per
-- Hunt, not per run; every pool event has a Haul with no other condition, so this is every Cast in its waters.*
---@param run HuntRun
---@return integer
local function castsIn(run)
	local most = 0
	for _, progress in pairs(run.hunts) do
		most = math.max(most, progress.effort)
	end
	return most
end

--- A run's entry (HNT-R163) for one of ns.RunsShown's runs. While the projection updates, its seal, ladders, Casts
--- and sums read the updating line (HNT-R69).
---@param input WagersInput
---@param shown HuntsShownRun
---@return RunEntry
function ns.BuildRunEntry(input, shown)
	local L, run, event = ns.L, shown.run, shown.event
	local kicker = run.source == "p" and L.RUN_KICKER_PUSHED or L.RUN_KICKER_ROTATION:format(L.BANDS[event.band])
	local untilWhen = ns.RealmWeekdayClock(run.end_, input.snapshot)
	local entry = {
		key = shown.key,
		kicker = kicker,
		name = eventName(event),
		chips = zoneChips(event, input),
		until_ = shown.on and L.LABEL_UNTIL:format(untilWhen)
			or L.RUN_FROM_UNTIL:format(ns.RealmWeekdayClock(run.start, input.snapshot), untilWhen),
		note = ns.events and ns.events:EventNote(event) or event.note,
		hunts = {},
		payRule = ns.RunPayRule(),
	}
	for i, hunt in ipairs(event.hunts) do
		entry.hunts[i] = {
			id = hunt.id,
			name = huntName(hunt),
			line = ns.EventHuntLine(hunt, input.list, input.sources),
			ladder = input.updating and { updating = L.UPDATING }
				or ns.HuntLadder(hunt, run.hunts[hunt.id], input.sources),
		}
	end
	if input.updating then
		entry.seal = { text = L.UPDATING, filled = false }
		entry.casts, entry.soFar = L.UPDATING, L.UPDATING
		return entry
	end
	local settled = ns.RunSettledDate(run)
	if settled then
		entry.seal = { text = L.SEAL_SETTLED:format(ns.FormatShortDate(settled)), filled = true }
	else
		entry.seal = { text = L.SEAL_NOT_YET, filled = false }
	end
	entry.casts = ns.CountText(castsIn(run), "RUN_CASTS")
	local xp, coins = paidSoFar(run)
	entry.soFar = L.RUN_SO_FAR:format(xp, coins)
	return entry
end
