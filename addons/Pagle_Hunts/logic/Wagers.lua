if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Pagle Wagers on the Board spread (HNT-R160, HNT-R161, HNT-R163, HNT-R164) as data: the wager strip above the
-- timeline's ruler, the WAGERS group's rows at the top of the timeline (logic/Timeline.lua puts them first), and a
-- run's entry on the right page (HNT-R163, the Pagle Wagers kit's variant A), with what the entry and the Pagle Wagers
-- spread share: the event mark's layers (HNT-R166), the time dial (HNT-R167) and "needs skill {n}" (HNT-R156). Pure
-- logic, everything passed in (CORE-R7); the event pool (`ns.events`, for names) is read at call time.
-- adapter/Wagers.lua and adapter/Timeline.lua gather the inputs and draw the strip and the rows, adapter/WagersEntry.lua
-- the entry; the spread's left page is logic/WagersSpread.lua's, and the tracker's block (#304) reads the same pieces.
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
---@field hint CompanionHint?    -- the companion hint while it applies (HNT-R170, logic/Companion.lua); nil while not
---@field best integer?          -- Pagle.GetAngler().bestBaseSkill: "needs skill {n}" above it (HNT-R156); none, none

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

--- The pay rule under a run's entry (HNT-R163), from the Tunables (HNT-R110, HNT-R114, HNT-R117): what a first mark, a
--- further mark and a settled run pay, then the Refreshes a third mark and a settled run pay, where either does.
---@return string
function ns.RunPayRule()
	local L = ns.L
	local rule = L.RUN_PAY_RULE:format(
		ns.XP_EVENT[1],
		ns.COINS_EVENT[1],
		ns.XP_EVENT[2],
		ns.COINS_EVENT[2],
		ns.XP_RUN,
		ns.COINS_RUN
	)
	local tier, settle = ns.TICKETS_TIER3, ns.TICKETS_RUN
	if tier > 0 and settle > 0 then
		return rule .. L.RUN_PAY_RULE_REFRESH_BOTH:format(ns.CountText(tier, "REFRESH"), settle)
	elseif tier > 0 then
		return rule .. L.RUN_PAY_RULE_REFRESH_TIER:format(ns.CountText(tier, "REFRESH"))
	elseif settle > 0 then
		return rule .. L.RUN_PAY_RULE_REFRESH_RUN:format(ns.CountText(settle, "REFRESH"))
	end
	return rule
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

--- The wager strip above the timeline's ruler (HNT-R161): the first run on as a one-line wager ticket, or with none on
--- the first run ahead as the spread's dashed row. It has no kicker: the ticket's paper and mark name it.
---@class WagerStrip
---@field run string         -- the run it names: clicking it opens the Pagle Wagers spread on it (#303)
---@field on boolean
---@field ahead WagerAheadRow?  -- none on: the first run ahead, drawn as the spread's dashed row (HNT-R162)
---@field mark string[]?     -- a run on: its event mark's layers (HNT-R166)…
---@field dial WagerDial?    -- …its time dial in the stub, without words (HNT-R167)…
---@field name string?       -- …its event's name…
---@field zones string?      -- …its zones, in italic after the name…
---@field settled boolean?   -- …the SETTLED stamp in place of the pips once completed; never while updating…
---@field pips boolean[]?    -- …one pip per Hunt, in definition order, inked (true) at its first mark in this run; nil
--- once settled and while the projection updates (HNT-R69)…
---@field updating string?   -- …the updating line in place of the pips (HNT-R69)…
---@field closes string?     -- …"closes in 2d 4h" in the hand (HNT-R50, a server-time duration, HNT-R203)…
---@field urgent boolean?    -- …red within the closing-note time while not settled (Tunables, HNT-R167)
---@field more string?       -- "+{n} more on the table" with more runs on
---@field hint string[]?     -- the companion hint's lines under it, with Get it and Dismiss, while it applies (HNT-R170)

--- The wager strip (HNT-R161), or nil with no run on or ahead (HNT-R204).
---@param input WagersInput
---@return WagerStrip?
function ns.BuildWagerStrip(input)
	local L, first = ns.L, input.runs[1]
	if not first then
		return nil
	end
	local strip = { run = first.key, on = first.on, hint = input.hint and input.hint.lines }
	if not first.on then
		strip.ahead = ns.WagerAheadRow(first, input)
		return strip
	end
	local run = first.run
	local settled = not input.updating and run.completedAt ~= nil
	local dial = ns.WagerDial(first, input.now, settled, false)
	dial.left = nil -- wordless: "closes in …" says the time
	strip.mark = ns.EventMarkLayers(first.event.tags)
	strip.dial = dial
	strip.name = eventName(first.event)
	strip.zones = ns.EventZonesText(first.event, input.sources)
	strip.settled = settled
	strip.closes = L.STRIP_CLOSES:format(ns.FormatDuration(run.end_ - input.now))
	strip.urgent = dial.urgent
	if input.updating then
		strip.updating = L.TICKET_UPDATING -- as the tickets read it (HNT-R163)
	elseif not settled then
		strip.pips = {}
		for i, hunt in ipairs(first.event.hunts) do
			strip.pips[i] = ns.HuntDone(run.hunts[hunt.id])
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

--- The least room, in UI units with its gap, the zones take on the strip's line (HNT-R161): with less, they are left
--- out rather than cut to a stub. *Default chosen while building (#376), as #375's prototype laid it.*
ns.WAGER_STRIP_ZONES_LEAST = 38

--- What the strip's line weighs, in UI units (HNT-R161): the room from the name's left to what sits at the right (the
--- pips or the stamp, and "closes in …"), and the widths the name, "+{n} more on the table" and the zones would take,
--- each of the last two with its gap (0 for one not there).
---@class WagerStripSizes
---@field room number
---@field name number
---@field more number
---@field zones number

--- The strip's fit rule (HNT-R161): short of room, the zones go first, cut short, then left out under
--- ns.WAGER_STRIP_ZONES_LEAST; then "+{n} more on the table"; and only then is the name cut short. Returns the name's
--- width, whether "+{n} more" shows, and the zones' width with their gap (nil when left out).
---@param sizes WagerStripSizes
---@return { name: number, more: boolean, zones: number? }
function ns.WagerStripFit(sizes)
	local room = sizes.room
	local fit = { more = false }
	if sizes.more > 0 then
		if sizes.name + sizes.more > room then
			-- "+{n} more" leaves, and the zones, which go before it, with it
			fit.name = math.max(0, math.min(sizes.name, room))
			return fit
		end
		fit.more, room = true, room - sizes.more
	end
	fit.name = math.max(0, math.min(sizes.name, room))
	local left = room - fit.name
	if sizes.zones > 0 and left >= ns.WAGER_STRIP_ZONES_LEAST then
		fit.zones = math.min(sizes.zones, left)
	end
	return fit
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

--- One run's row in the WAGERS group (HNT-R161): a TimelineRow (logic/Timeline.lua) with its run key and, in place of
--- an icon, its event mark.
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
	local when = ns.RealmWeekdayClock(shown.on and run.end_ or run.start, input.snapshot)
	return {
		id = shown.key,
		run = shown.key,
		name = eventName(event),
		mark = ns.EventMarkLayers(event.tags), -- in the place of a Hunt's icon (HNT-R166)
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

-- What the spread and the entry share ----------------------------------------------------------------------------

-- The tags that pick the event mark's layers (HNT-R166), by kind, from DATA-R97's closed list: a time tag its sky, a
-- water tag its water, a holiday tag its charm.
local SKIES = { night = true, day = true, dusk = true }
local WATERS = { coast = true, lake = true, river = true, pool = true }
local HOLIDAY_TAGS = {
	hallows_end = true,
	winter_veil = true,
	lunar_festival = true,
	noblegarden = true,
	midsummer = true,
	harvest_festival = true,
	stv_extravaganza = true,
}

--- The event mark's layers for an event's `tags` (HNT-R166), bottom to top, by their names in the Wagers atlas: the
--- shadow, the sky of its time tag (`mark-sky-plain` with none), the water of its water tag (none: open water), the
--- brass ring, and its holiday tag's charm. Of each kind the first tag in the event's order picks; nothing else of the
--- event counts, so events with the same tags share a mark, and a pushed event gets one too.
---@param tags string[]?
---@return string[]
function ns.EventMarkLayers(tags)
	local sky, water, charm
	for _, tag in ipairs(tags or {}) do
		if SKIES[tag] then
			sky = sky or tag
		elseif WATERS[tag] then
			water = water or tag
		elseif HOLIDAY_TAGS[tag] then
			charm = charm or tag
		end
	end
	local layers = { "mark-shadow", "mark-sky-" .. (sky or "plain") }
	if water then
		layers[#layers + 1] = "mark-water-" .. water
	end
	layers[#layers + 1] = "mark-ring"
	if charm then
		layers[#layers + 1] = "mark-charm-" .. charm
	end
	return layers
end

--- An event's zones' names joined, "Felwood & Moonglade" (HNT-R161, HNT-R162).
---@param event HuntEvent
---@param sources HuntNameSources
---@return string
function ns.EventZonesText(event, sources)
	return table.concat(ns.EventZoneNames(event, sources), ns.L.JOIN_ZONES)
end

--- A dashed row for a run ahead (HNT-R162), on the spread and, with none on, as the wager strip (HNT-R161).
---@class WagerAheadRow
---@field run string              -- its run key: clicking it chooses it
---@field selected boolean
---@field mark string[]
---@field name string
---@field zones string            -- "Silithus", "Felwood & Moonglade"
---@field need string?            -- "needs skill {n}"
---@field opens string            -- "opens Sat 17:00"
---@field length string           -- "for 3d"

--- Run ahead `shown`'s dashed row (HNT-R162): its mark, name, zones, "needs skill {n}", and when it opens over its
--- length; not chosen.
---@param shown HuntsShownRun
---@param input WagersInput
---@return WagerAheadRow
function ns.WagerAheadRow(shown, input)
	local L, run, event = ns.L, shown.run, shown.event
	return {
		run = shown.key,
		selected = false,
		mark = ns.EventMarkLayers(event.tags),
		name = eventName(event),
		zones = ns.EventZonesText(event, input.sources),
		need = ns.EventSkillNeed(event, input.best),
		opens = L.AHEAD_OPENS:format(ns.RealmWeekdayClock(run.start, input.snapshot)),
		length = L.AHEAD_FOR:format(ns.FormatDuration(run.end_ - run.start)),
	}
end

--- An event's holiday tag's name (DATA-R97's holiday tags, interface text in ns.L keyed by tag ID), nil for an event
--- with none: a holiday run's name has it on a green tag (HNT-R162), and its entry as a chip (HNT-R163). *Default
--- chosen in #303: HNT-R162 names the tag but not its words.* The names are the locale's full ones, never cut.
---@param event HuntEvent
---@return string?
function ns.EventHolidayName(event)
	for _, tag in ipairs(event.tags or {}) do
		if HOLIDAY_TAGS[tag] then
			return ns.L.HOLIDAYS[tag] or tag
		end
	end
	return nil
end

--- "needs skill {n}" (HNT-R156) for an event short of skill: its skill range's lower end above the Angler's
--- `bestBaseSkill` (as HNT-R33); nil otherwise, or with no best known. A skill below 0 is never shown: the bound is at
--- least 0, and 0 is no requirement.
---@param event HuntEvent
---@param best integer?
---@return string?
function ns.EventSkillNeed(event, best)
	local need = event.skill and math.max(event.skill[1], 0)
	if need and need > 0 and best and need > best then
		return ns.L.NEEDS_SKILL:format(need)
	end
	return nil
end

--- The time dial's step (HNT-R167) for `left` seconds of a run `length` long: the share still to go in 36ths, rounded
--- up, at least 1 while any is left; nil with none left.
---@param left number
---@param length number
---@return integer?
function ns.DialStep(left, length)
	if left <= 0 or length <= 0 then
		return nil
	end
	local steps = ns.WAGER_DIAL_STEPS
	return math.max(1, math.min(steps, math.ceil(steps * left / length)))
end

--- A run's time dial (HNT-R162's stub, HNT-R163's time block, HNT-R167).
---@class WagerDial
---@field kind "on"|"settled"|"closed"|"ahead"  -- oxblood, grey, empty, or the dashed ring of a run ahead
---@field step integer?    -- the fill's step, 1–36, while on or settled
---@field urgent boolean   -- a run on, not settled, within the closing-note time (Tunables): its ring and words in red
---@field left string?     -- the stub's words: the duration left ("42m", "2d 21h"), or "closed"

--- Whether `left` seconds to a run's end is within the closing-note time (Tunables, HNT-R162, HNT-R167).
---@param left number
---@return boolean
function ns.ClosingSoon(left)
	return left > 0 and left <= ns.WAGER_CLOSING_NOTE
end

--- Run `shown`'s time dial at `now` (HNT-R167): `settled` once completed, `closed` once it ended while the board was
--- open. It only repeats what its words say, so it steps at each draw and never moves on its own.
---@param shown HuntsShownRun
---@param now integer
---@param settled boolean
---@param closed boolean
---@return WagerDial
function ns.WagerDial(shown, now, settled, closed)
	if closed then
		return { kind = "closed", urgent = false, left = ns.L.TICKET_CLOSED }
	elseif not shown.on then
		return { kind = "ahead", urgent = false }
	end
	local run = shown.run
	local left = run.end_ - now
	return {
		kind = settled and "settled" or "on",
		step = ns.DialStep(left, run.end_ - run.start),
		urgent = not settled and ns.ClosingSoon(left),
		left = ns.FormatDuration(left),
	}
end

--- `text` cut at its markers into runs of words, each with its ink: `marks` gives the words and the ink for a marker
--- (a control character "\1", "\2"), and every other word is in `ink`; an empty run is left out. A line in two or three
--- inks is written whole in its locale string, then cut here, so its words stay the locale's.
---@param text string
---@param ink string
---@param marks table<string, { [1]: string, [2]: string }>
---@return { text: string, ink: string }[]
function ns.InkRuns(text, ink, marks)
	local runs = {}
	local function add(words, wordsInk)
		if words ~= "" then
			runs[#runs + 1] = { text = words, ink = wordsInk }
		end
	end
	local at = 1
	while true do
		local found = text:find("[\1-\9]", at)
		if not found then
			add(text:sub(at), ink)
			return runs
		end
		add(text:sub(at, found - 1), ink)
		local mark = marks[text:sub(found, found)]
		if mark then
			add(mark[1], mark[2])
		end
		at = found + 1
	end
end

-- A run's entry ----------------------------------------------------------------------------------------------------

--- An event Hunt's window line in a run's entry (HNT-R163), a Timed Hunt's alone: its window open now or when it
--- opens next, by its `time` condition alone.
---@class RunEntryWindow
---@field open boolean       -- "open now, until {time}", in green
---@field text string

--- One event Hunt in a run's entry (HNT-R163).
---@class RunEntryHunt
---@field id string
---@field name string
---@field shape EventHuntShape     -- its glyph
---@field line string              -- its shape and target line
---@field got boolean?             -- it has its first mark: its glyph and ink bar in oxblood; nil while updating
---@field count { count: string, rest: string }?  -- "{count} / {next threshold}" (or "{count} caught" once every tier
--- is reached), cut where the count's ink ends; nil while updating
---@field tiers { trim: "bronze"|"silver"|"gold", reached: boolean }[]?  -- its diamonds; nil while updating
---@field fill number?             -- the ink bar toward the next threshold, 0–1; nil while updating
---@field window RunEntryWindow?   -- a Timed Hunt's, for a run on

--- One of the two pay boxes (HNT-R163): its label over its amount, and the Refreshes it pays beside its label
--- (HNT-R117).
---@class RunEntryPay
---@field label string
---@field amount string
---@field refresh string?   -- "+2 Refreshes"; nil where none are paid

--- The time block (HNT-R163): the dial, then a line in the hand over a small one.
---@class RunEntryTime
---@field dial WagerDial
---@field hand string        -- "closes in 2d 21h", "settled, and still open", or "opens Sat 17:00"
---@field ahead boolean      -- a run ahead: its hand in the Angler's blue, not in red
---@field small string       -- "until Sat 17:00 · 3d in all", or "… · 3d on the table" ahead

--- A run's entry, top to bottom (HNT-R163). It has no pin toggle and no set line; a field left nil isn't shown.
---@class RunEntry
---@field key string
---@field source "rotation"|"companion"   -- its kicker's mark
---@field kicker string             -- "From the rotation · low waters", or "Sent by the companion"
---@field name string
---@field mark string[]             -- the event mark's layers (HNT-R166)
---@field seal { word: string, date: string }?  -- pressed over the mark once settled; never while updating
---@field time RunEntryTime
---@field chips HuntEntryChip[]     -- its zones (the live zone first, "you're here"), "needs skill {n}", its holiday
---@field note string?              -- the event's note, in the hand
---@field updating string?          -- "Updating from your Catch log…" over the rows, which fade (HNT-R69)
---@field hunts RunEntryHunt[]      -- in definition order
---@field tight boolean             -- five Hunts or more: the rows tighten, the window lines are left out
---@field casts string?             -- "{n} Casts in these waters this run · {done} of {count} first marks"
---@field pay RunEntryPay[]?        -- "Paid so far", then "Settle it" or "Settled"
---@field payRule string

-- The run's chips: its zones in its order, the live zone first with the "you're here" badge (HNT-R65's zone chips);
-- then "needs skill {n}" in pencil when short of skill (HNT-R156); then a holiday run's holiday on green.
---@param event HuntEvent
---@param input WagersInput
---@return HuntEntryChip[]
local function chipsOf(event, input)
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
	local need = ns.EventSkillNeed(event, input.best)
	if need then
		chips[#chips + 1] = { kind = "skill", text = need }
	end
	local holiday = ns.EventHolidayName(event)
	if holiday then
		chips[#chips + 1] = { kind = "holiday", text = holiday }
	end
	return chips
end

-- What a run has paid so far (HNT-R110, HNT-R114, HNT-R117): every tier its Hunts reached in it, and the settled run
-- on top.
---@param run HuntRun
---@return integer xp
---@return integer coins
---@return integer tickets
local function paidSoFar(run)
	local xp, coins, tickets = 0, 0, 0
	for _, progress in pairs(run.hunts) do
		for k in ipairs(progress.reached) do
			xp = xp + ns.TierAmount(ns.XP_EVENT, k)
			coins = coins + ns.TierAmount(ns.COINS_EVENT, k)
			tickets = tickets + ns.TierTickets(k)
		end
	end
	if run.completedAt then
		xp, coins, tickets = xp + ns.XP_RUN, coins + ns.COINS_RUN, tickets + ns.TICKETS_RUN
	end
	return xp, coins, tickets
end

-- A pay box's Refreshes line, "+2 Refreshes" (HNT-R117), or nil for none: the box shows it beside its Coins.
---@param n integer
---@return string?
local function refreshLine(n)
	return n > 0 and ns.CountText(n, "PAY_REFRESH") or nil
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

-- A Timed Hunt's window line (HNT-R163) at `now`, from its `time` condition alone (its window on the ruler,
-- HNT-R161): "open now, until {time}" or "opens at {time}, in {duration}", in realm time (HNT-R50); nil for a Hunt
-- without one, or with no window known.
---@param hunt HuntEventHunt
---@param input WagersInput
---@return RunEntryWindow?
local function windowOf(hunt, input)
	local spec, nextWindow = timeSpec(hunt), input.sources.NextWindow
	if not (spec and nextWindow) then
		return nil
	end
	local window = nextWindow(spec, input.now)
	if not window then
		return nil
	end
	local L = ns.L
	local function clock(t)
		return ns.FormatClock(ns.RealmClockAt(t, input.snapshot).minute)
	end
	if window.openNow and window.closesAt then
		return { open = true, text = L.RUN_WINDOW_OPEN:format(clock(window.closesAt)) }
	elseif window.opensAt and window.opensAt > input.now then
		return {
			open = false,
			text = L.RUN_WINDOW_SHUT:format(clock(window.opensAt), ns.FormatDuration(window.opensAt - input.now)),
		}
	end
	return nil
end

-- An event Hunt's row in the entry (HNT-R163): its glyph, name, line and, unless updating (HNT-R69), its count toward
-- the next threshold, its diamonds in their trims and its ink bar; a Timed Hunt's window for a run on.
---@param hunt HuntEventHunt
---@param shown HuntsShownRun
---@param input WagersInput
---@return RunEntryHunt
local function huntRow(hunt, shown, input)
	local L = ns.L
	local row = {
		id = hunt.id,
		name = huntName(hunt),
		shape = ns.EventHuntShape(hunt),
		line = ns.EventHuntLine(hunt, input.list, input.sources),
		window = shown.on and windowOf(hunt, input) or nil,
	}
	if input.updating then
		return row
	end
	local progress = shown.run.hunts[hunt.id]
	local ladder = ns.HuntLadder(hunt, progress, input.sources)
	row.got = ns.HuntDone(progress)
	row.tiers = {}
	local next
	for k, step in ipairs(ladder.tiers) do
		row.tiers[k] = { trim = ns.Trim(k), reached = step.reached }
		if not step.reached and not next then
			next = step.threshold
		end
	end
	local bar = ladder.bar --[[@as { fill: number, label: string }]]
	row.fill = bar.fill
	local count = tostring(progress and progress.count or 0)
	local text = next and L.RUN_HUNT_PROGRESS:format("\1", next) or L.RUN_HUNT_CAUGHT:format("\1")
	local before, after = text:match("^(.-)\1(.*)$")
	row.count = { count = before .. count, rest = after }
	return row
end

--- A run's entry (HNT-R163) for one of ns.RunsShown's runs. A run ahead has no Casts line and no pay boxes, and no
--- window lines; while the projection updates, nothing comes from its state (HNT-R69): no seal, the rows without their
--- counts, diamonds and bars under the updating line, and no Casts line or boxes.
---@param input WagersInput
---@param shown HuntsShownRun
---@return RunEntry
function ns.BuildRunEntry(input, shown)
	local L, run, event = ns.L, shown.run, shown.event
	local pushed = run.source == "p"
	local settled = not input.updating and run.completedAt ~= nil
	local untilWhen = ns.RealmWeekdayClock(run.end_, input.snapshot)
	local length = ns.FormatDuration(run.end_ - run.start)
	local time
	if shown.on then
		time = {
			dial = ns.WagerDial(shown, input.now, settled, false),
			hand = settled and L.RUN_SETTLED_OPEN or L.STRIP_CLOSES:format(ns.FormatDuration(run.end_ - input.now)),
			ahead = false,
			small = L.RUN_UNTIL_ALL:format(untilWhen, length),
		}
	else
		time = {
			dial = ns.WagerDial(shown, input.now, false, false),
			hand = L.RUN_OPENS:format(ns.RealmWeekdayClock(run.start, input.snapshot)),
			ahead = true,
			small = L.RUN_UNTIL_TABLE:format(untilWhen, length),
		}
	end
	local entry = {
		key = shown.key,
		source = pushed and "companion" or "rotation",
		kicker = pushed and L.RUN_KICKER_PUSHED or L.RUN_KICKER_ROTATION:format(L.BANDS[event.band]),
		name = eventName(event),
		mark = ns.EventMarkLayers(event.tags),
		time = time,
		chips = chipsOf(event, input),
		note = ns.events and ns.events:EventNote(event) or event.note,
		updating = input.updating and L.UPDATING or nil,
		hunts = {},
		tight = #event.hunts >= 5,
		payRule = ns.RunPayRule(),
	}
	local done = 0
	for i, hunt in ipairs(event.hunts) do
		entry.hunts[i] = huntRow(hunt, shown, input)
		done = done + (entry.hunts[i].got and 1 or 0)
	end
	if settled then
		local date = ns.RunSettledDate(run) --[[@as { year: integer, month: integer, day: integer }]]
		entry.seal = { word = L.SEAL_SETTLED_WORD, date = ns.FormatShortDate(date) }
	end
	if input.updating or not shown.on then
		return entry
	end
	local casts = castsIn(run)
	entry.casts = L["RUN_CASTS_" .. (casts == 1 and "ONE" or "OTHER")]:format(casts, done, #event.hunts)
	local xp, coins, tickets = paidSoFar(run)
	entry.pay = {
		{ label = L.PAY_SO_FAR, amount = L.PAY_AMOUNT:format(xp, coins), refresh = refreshLine(tickets) },
		settled and { label = L.PAY_SETTLED, amount = L.PAY_PAID_OUT } or {
			label = L.PAY_SETTLE,
			amount = L.PAY_AMOUNT:format(ns.XP_RUN, ns.COINS_RUN),
			refresh = refreshLine(ns.TICKETS_RUN),
		},
	}
	return entry
end

--- What the entry's fit rule (HNT-R163) weighs, in UI units down the page: where the entry would end with everything
--- in, and the room each part it may leave out takes (0 for a part not shown).
---@class RunEntrySizes
---@field ends number      -- the entry's foot with everything in
---@field rule number      -- the pay rule, with its gap
---@field casts number     -- the Casts line, with its gap
---@field windows number   -- every window line's room together

--- The entry's fit rule (HNT-R163): laid top down, while it would end below `limit` (half the page's bottom margin
--- below its drawable area) it leaves out the pay rule first (its words become the pay boxes' tooltip), then the Casts
--- line, then the window lines, and stops as soon as it fits. Returns what it leaves out, and where it then ends.
---@param sizes RunEntrySizes
---@param limit number
---@return { rule: boolean, casts: boolean, windows: boolean }
---@return number
function ns.RunEntryFit(sizes, limit)
	local out = { rule = false, casts = false, windows = false }
	local ends = sizes.ends
	for _, part in ipairs({ "rule", "casts", "windows" }) do
		if ends <= limit then
			break
		end
		if sizes[part] > 0 then
			out[part], ends = true, ends - sizes[part]
		end
	end
	return out, ends
end
