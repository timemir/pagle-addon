if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The board's left page, "What's biting, and when" (HNT-R62, HNT-R63, HNT-R66's left page, HNT-R67, HNT-R69), and the
-- realm clock on the leather (HNT-R61): pure logic, everything passed in (CORE-R7). ns.BuildTimeline turns the rows
-- ns.groups hands out into what the page draws: a realm-time ruler, its washes, the groups under their headings, each
-- row's icon, name, bars and margin label, and the Hunt the board selects. Positions on the ruler are fractions of
-- its width, 0 at its start and 1 at its end. adapter/Timeline.lua gathers the inputs and draws the result.

--- Tunables (hunts.md): the ruler runs from 2 hours before now to 22 hours after (HNT-R62), in seconds.
ns.RULER_BEFORE = 2 * 60 * 60
ns.RULER_AFTER = 22 * 60 * 60

-- An hour, and the hours whose ticks carry their time: every 6 realm hours, as variant E labels its axis.
local HOUR = 3600
local LABEL_EVERY = 6
-- How many windows one row may draw before the forecast walk stops: a guard, far more than a day holds.
local MAX_SPANS = 48

--- A stretch of the ruler, from `from` to `to` (0 to 1).
---@class TimelineSpan
---@field from number
---@field to number

--- A bar on a row (HNT-R63): its stretch and its style.
---@class TimelineBar: TimelineSpan
---@field style BoardBarStyle

--- One Hunt's row (HNT-R63).
---@class TimelineRow
---@field id string
---@field name string
---@field icon integer|string|nil    -- HNT-R55's icon; nil while the client hasn't it
---@field tint table?                -- the icon's tint (a generated class's quality colour), nil for the sepia
---@field trim ("bronze"|"silver"|"gold")?   -- the highest tier's trim; nil before tier 1 and while updating (HNT-R69)
---@field pinned boolean
---@field margin string              -- the margin label (HNT-R51)
---@field tone HuntGroup|"short"     -- what the margin label's ink says: its group, or short of skill
---@field bars TimelineBar[]
---@field note string?               -- "out of season" in place of bars
---@field selected boolean

--- One group under its heading (HNT-R62).
---@class TimelineGroup
---@field group HuntGroup
---@field heading string
---@field count integer
---@field rows TimelineRow[]

--- The ruler (HNT-R62): its ends in server time, the now line, and its hour ticks, every 6 realm hours labelled.
---@class TimelineRuler
---@field from integer
---@field to integer
---@field now number
---@field ticks { x: number, label: string? }[]

--- What the left page draws.
---@class HuntsTimeline
---@field title string               -- "What's biting, and when", or a set's heading (HNT-R66)
---@field ruler TimelineRuler
---@field washes { kind: "soon"|"night", from: number, to: number }[]
---@field groups TimelineGroup[]     -- the groups with rows, in board order
---@field legend string
---@field empty "noHunts"|"allDone"|nil   -- no Hunt is current at all, or no row is shown (HNT-R67)
---@field selected string?           -- the Hunt selected (HNT-R67), nil for none

--- What ns.BuildTimeline reads: the rows to show and the sources the labels and bars need.
---@class HuntsTimelineInput
---@field rows HuntRow[]             -- the shown rows, sorted: ns.groups:Rows(filter)
---@field anyCurrent boolean         -- whether any Hunt is current at all (HNT-R67)
---@field now integer                -- the grouping's time: the timeline freezes with it (HNT-R43)
---@field snapshot table             -- one live Pagle.GetConditions(), for realm time (HNT-R50)
---@field where table<string, HuntWhere>   -- ns.where
---@field list HuntList
---@field sources HuntNameSources    -- ns.names: NextWindow, icons
---@field nightSpec table?           -- Pagle.GetWindowSpec("night"), for the night wash
---@field best integer               -- the Angler's bestBaseSkill (HNT-R33)
---@field progress table<string, HuntProgress>   -- ns.State().hunts
---@field updating boolean           -- ns.IsUpdating(): nothing is drawn from the state (HNT-R69)
---@field auraExpiry fun(spellID: integer): integer?   -- an aura's expiry in server time, nil when unknown (HNT-R63)
---@field set { name: string, title: string, earned: boolean }?   -- a set's page (HNT-R66)
---@field selected string?           -- the Hunt asked for or selected before
---@field pick boolean               -- the Board picks a Hunt when none shown is asked for (HNT-R67)

-- Server time `t` on the ruler.
---@param ruler { from: integer, to: integer }
---@param t number
---@return number
local function x(ruler, t)
	return (t - ruler.from) / (ruler.to - ruler.from)
end

--- The spans where `spec`'s time fields hold between `from` and `to` (HNT-R63), in server time: NextWindow from
--- `from`, then from each closesAt, until a window opens at or after `to`. A window open at `from` starts there; one
--- with no closesAt runs to `to`. An always-open spec fills it; an on-demand one (auras alone) has none.
---@param spec table
---@param from integer
---@param to integer
---@param nextWindow fun(spec: table, fromTime: integer): Window?
---@return { from: integer, to: integer }[]
function ns.TimelineSpans(spec, from, to, nextWindow)
	local spans = {}
	local t = from
	while #spans < MAX_SPANS do
		local window = nextWindow(spec, t)
		if not window or window.onDemand then
			break
		end
		if window.always then
			return { { from = from, to = to } }
		end
		local opens = window.openNow and t or window.opensAt
		if not opens or opens >= to then
			break
		end
		local closes = window.closesAt
		spans[#spans + 1] = { from = math.max(opens, from), to = math.min(closes or to, to) }
		if not closes or closes >= to or closes <= t then
			break
		end
		t = closes
	end
	return spans
end

-- The seconds of realm clock at server time `t`, as one count: its realm minute's seconds plus the seconds into it,
-- so whole realm hours fall where it divides by 3600 (HNT-R50). With no realm minute (a secret clock), UTC's.
---@param t integer
---@param snapshot table
---@return integer
local function realmSeconds(t, snapshot)
	if snapshot.minute == nil or snapshot.date == nil then
		return t
	end
	return snapshot.minute * 60 + (t - snapshot.time)
end

-- The ruler around `now` (HNT-R62): a tick at every whole realm hour, labelled every 6 hours except where the now
-- line's "now" stands.
---@param now integer
---@param snapshot table
---@return TimelineRuler
local function rulerAt(now, snapshot)
	local ruler = { from = now - ns.RULER_BEFORE, to = now + ns.RULER_AFTER, ticks = {} }
	ruler.now = x(ruler, now)
	local first = ruler.from + (HOUR - realmSeconds(ruler.from, snapshot) % HOUR) % HOUR
	for t = first, ruler.to, HOUR do
		local clock = ns.RealmClockAt(t, snapshot)
		local label
		if math.floor(clock.minute / 60) % LABEL_EVERY == 0 and math.abs(t - now) >= HOUR then
			label = ns.FormatClock(clock.minute)
		end
		ruler.ticks[#ruler.ticks + 1] = { x = x(ruler, t), label = label }
	end
	return ruler
end

-- The washes under the rows (HNT-R62): the next 3 hours (Soon), then each span the night window holds.
---@param ruler TimelineRuler
---@param input HuntsTimelineInput
---@return { kind: "soon"|"night", from: number, to: number }[]
local function washesOf(ruler, input)
	local washes = { { kind = "soon", from = ruler.now, to = x(ruler, input.now + ns.SOON_HORIZON) } }
	if input.nightSpec then
		for _, span in ipairs(ns.TimelineSpans(input.nightSpec, ruler.from, ruler.to, input.sources.NextWindow)) do
			washes[#washes + 1] = { kind = "night", from = x(ruler, span.from), to = x(ruler, span.to) }
		end
	end
	return washes
end

-- When the aura of an aura-up row runs out (HNT-R63): the first of its spec's auras with a known expiry, nil when
-- none has one.
---@param spec table
---@param auraExpiry fun(spellID: integer): integer?
---@return integer?
local function campEnds(spec, auraExpiry)
	for _, spellID in ipairs(spec.auras or {}) do
		local expiry = auraExpiry(spellID)
		if expiry then
			return expiry
		end
	end
	return nil
end

-- A row's bars and its note (HNT-R63): an aura-up Hunt's blue bar from the now line to the aura's expiry (or the
-- ruler's end); none for an On demand Hunt or one without a board spec; otherwise its spans, styled hatched, dashed
-- when unconfirmed, pencil when short of skill (which wins), with an event the calendar shows open drawn from the now
-- line when no span covers it; "out of season" for a season Hunt with no span.
---@param row HuntRow
---@param spec table?
---@param ruler TimelineRuler
---@param input HuntsTimelineInput
---@return TimelineBar[]
---@return string?
local function barsOf(row, spec, ruler, input)
	if not spec then
		return {}, nil
	end
	if row.auraUp then
		local ends = campEnds(spec, input.auraExpiry)
		local to = ends and math.min(1, math.max(ruler.now, x(ruler, ends))) or 1
		return { { from = ruler.now, to = to, style = "camp" } }, nil
	end
	if row.group == "onDemand" then
		return {}, nil
	end
	local style = "hatched"
	if row.short then
		style = "pencil"
	elseif ns.Unconfirmed(row.hunt, row.window) then
		style = "dashed"
	end
	local bars, coversNow = {}, false
	for _, span in ipairs(ns.TimelineSpans(spec, ruler.from, ruler.to, input.sources.NextWindow)) do
		local bar = { from = x(ruler, span.from), to = x(ruler, span.to), style = style }
		coversNow = coversNow or (bar.from <= ruler.now and bar.to > ruler.now)
		bars[#bars + 1] = bar
	end
	if row.window and row.window.openNow and not coversNow then
		bars[#bars + 1] = { from = ruler.now, to = 1, style = style }
	end
	if #bars == 0 and spec.season then
		return bars, ns.L.OUT_OF_SEASON
	end
	return bars, nil
end

-- A Hunt's row on the timeline (HNT-R63).
---@param row HuntRow
---@param ruler TimelineRuler
---@param input HuntsTimelineInput
---@return TimelineRow
local function rowOf(row, ruler, input)
	local where = input.where[row.id]
	local spec = where.boardSpec
	local icon, tint = ns.HuntIcon(row.hunt, input.list, input.sources)
	local margin = ns.HuntLabels({
		group = row.group,
		auraUp = row.auraUp,
		window = row.window,
		spec = spec,
		need = where.skillNeed,
		best = input.best,
		now = input.now,
		snapshot = input.snapshot,
	})
	local bars, note = barsOf(row, spec, ruler, input)
	return {
		id = row.id,
		name = input.list:HuntName(row.id),
		icon = icon,
		tint = tint,
		trim = not input.updating and ns.HuntTrim(input.progress[row.id]) or nil,
		pinned = row.pinned,
		margin = margin,
		tone = row.short and "short" or row.group,
		bars = bars,
		note = note,
		selected = false,
	}
end

-- The Hunt the timeline selects (HNT-R67): the one asked for while it has a row; otherwise, when the Board picks,
-- the first under Now, or the first row if Now is empty; none when no row shows.
---@param rows HuntRow[]
---@param input HuntsTimelineInput
---@return string?
local function selectionOf(rows, input)
	for _, row in ipairs(rows) do
		if row.id == input.selected then
			return row.id
		end
	end
	if not input.pick or #rows == 0 then
		return nil
	end
	-- Rows come in board order, Now first: the first row is the first under Now whenever Now has one.
	return rows[1].id
end

--- The left page's timeline (HNT-R62, HNT-R63, HNT-R66, HNT-R67): the ruler at the grouping's time, its washes, the
--- shown rows under their groups' headings in board order (an empty group left out), the legend, and the selection.
---@param input HuntsTimelineInput
---@return HuntsTimeline
function ns.BuildTimeline(input)
	local L = ns.L
	local ruler = rulerAt(input.now, input.snapshot)
	local selected = selectionOf(input.rows, input)
	local byGroup = {}
	for _, row in ipairs(input.rows) do
		local drawn = rowOf(row, ruler, input)
		drawn.selected = row.id == selected
		byGroup[row.group] = byGroup[row.group] or {}
		table.insert(byGroup[row.group], drawn)
	end
	local groups = {}
	for _, group in ipairs(ns.GROUP_ORDER) do
		local rows = byGroup[group]
		if rows then
			groups[#groups + 1] = { group = group, heading = L.GROUP_HEADINGS[group], count = #rows, rows = rows }
		end
	end
	local title = L.TIMELINE_TITLE
	local set = input.set
	if set then
		title = (set.earned and L.SET_HEADING_EARNED or L.SET_HEADING_EARNS):format(set.name, set.title)
	end
	local empty
	if not input.anyCurrent then
		empty = "noHunts"
	elseif #input.rows == 0 then
		empty = "allDone"
	end
	return {
		title = title,
		ruler = ruler,
		washes = washesOf(ruler, input),
		groups = groups,
		legend = L.TIMELINE_LEGEND,
		empty = empty,
		selected = selected,
	}
end

--- The first season whose window matches the live snapshot (HNT-R61): summer, winter, spring, autumn, in that order;
--- nil when none does, or none has a spec.
---@param snapshot table one live Pagle.GetConditions()
---@param windowSpec fun(windowID: string): table? Pagle.GetWindowSpec
---@param matches fun(spec: table, snapshot: table): boolean Pagle.MatchesConditions
---@return string? -- the season's window ID
function ns.SeasonNow(snapshot, windowSpec, matches)
	for _, season in ipairs({ "summer", "winter", "spring", "autumn" }) do
		local spec = windowSpec(season)
		if spec and matches(spec, snapshot) then
			return season
		end
	end
	return nil
end

--- The realm clock on the leather (HNT-R61): the realm time at `t`, the short date with its weekday ("Tue 14 Oct")
--- and the season's name, then "(paused in combat)" while the grouping is paused (HNT-R43).
---@param t integer the grouping's time, so the clock freezes with it
---@param snapshot table one live Pagle.GetConditions()
---@param season string? the season's window ID (ns.SeasonNow)
---@param paused boolean
---@return string
function ns.TimelineClock(t, snapshot, season, paused)
	local L = ns.L
	local clock = ns.RealmClockAt(t, snapshot)
	local parts = {
		ns.FormatClock(clock.minute),
		L.WEEKDAY_DATE:format(ns.FormatWeekday(clock.date), ns.FormatShortDate(clock.date)),
	}
	if season then
		parts[#parts + 1] = L.SEASONS[season]
	end
	local line = table.concat(parts, L.JOIN_FIELDS)
	if paused then
		line = L.CLOCK_PAUSED:format(line)
	end
	return line
end
