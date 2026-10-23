if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Pagle Wagers spread's left page (HNT-R162) as data, the Wagers redesign's variant A (the Bookmaker's Ledger,
-- data/art/wagers/art.json): the note that follows the table, the closing note, a wager ticket per run on (and per run
-- that closed while the board was open), a dashed row per run ahead, the empty box, and the ladder as a rail. Pure
-- logic, everything passed in (CORE-R7), over logic/Wagers.lua's pieces (the event mark, the time dial, "needs skill
-- {n}"); adapter/WagersSpread.lua gathers the inputs and draws it. Every word is interface text in ns.L, and none
-- claims odds, a due fish or a chance (HNT-R27).

-- The ladder ---------------------------------------------------------------------------------------------------------

--- One post on the ladder's rail (HNT-R148, HNT-R162): its step, its title (`ladder.<n>.title`, lore), whether it is
--- earned (pressed in oxblood), and where it stands on the rail (a third to each step).
---@class WagersLadderMark
---@field step integer
---@field title string
---@field reached boolean
---@field at number

--- The ladder at the spread's foot (HNT-R162).
---@class WagersLadder
---@field label string              -- "The ladder"
---@field marks WagersLadderMark[]  -- at 25, 50 and 100 (Tunables)
---@field share number?             -- where the token stands on the rail and the fill ends, 0–1; nil while updating
---@field line string               -- "{count} wagers settled · {n} more for {title}", or the updating line
---@field runs { text: string, ink: "count"|"line"|"title" }[]  -- the line cut where its ink changes

--- The rail's share for `count` completed runs (HNT-R162): 0 at 0, a third at the first step (25), two thirds at the
--- second (50) and the whole rail at the last (100) and past it, straight between within each step. The website draws
--- the same rail (pagle-backend's ANG-R77).
---@param count number
---@return number
function ns.LadderShare(count)
	local steps = ns.LADDER_STEPS
	local below = 0
	for i, step in ipairs(steps) do
		if count < step then
			return (i - 1 + math.max(0, count - below) / (step - below)) / #steps
		end
		below = step
	end
	return 1
end

--- The ladder (HNT-R148, HNT-R162) for `settled` completed runs, the steps earned in `ladder` (state.ladder, never
--- lost). Past the last mark the line is only "{count} wagers settled". *Default chosen in #303: HNT-R162 doesn't say
--- what the line reads past 100.* While the projection updates, nothing comes from its state (HNT-R69): no post pressed,
--- no token, and the updating line.
---@param settled integer state.settled
---@param ladder table<integer, integer> state.ladder
---@param updating boolean?
---@return WagersLadder
function ns.BuildWagersLadder(settled, ladder, updating)
	local L = ns.L
	local marks, next = {}, nil
	for i, step in ipairs(ns.LADDER_STEPS) do
		marks[i] = {
			step = step,
			title = ns.LadderTitle(step),
			reached = not updating and ladder[step] ~= nil,
			at = i / #ns.LADDER_STEPS,
		}
		if not next and settled < step then
			next = step
		end
	end
	if updating then
		return {
			label = L.LADDER_LABEL,
			marks = marks,
			line = L.UPDATING,
			runs = { { text = L.UPDATING, ink = "line" } },
		}
	end
	local function count(marked)
		return ns.CountText(settled, "WAGERS_SETTLED", marked and function()
			return "\1"
		end or nil)
	end
	local line, marked
	if next then
		local title = ns.LadderTitle(next)
		line = L.WAGERS_LADDER_LINE:format(count(), next - settled, title)
		marked = ns.InkRuns(
			L.WAGERS_LADDER_LINE:format(count(true), next - settled, "\2"),
			"line",
			{ ["\1"] = { tostring(settled), "count" }, ["\2"] = { title, "title" } }
		)
	else
		line = count()
		marked = ns.InkRuns(count(true), "line", { ["\1"] = { tostring(settled), "count" } })
	end
	return {
		label = L.LADDER_LABEL,
		marks = marks,
		share = ns.LadderShare(settled),
		line = line,
		runs = marked --[[@as { text: string, ink: "count"|"line"|"title" }[] ]],
	}
end

-- The tickets and the rows ahead -------------------------------------------------------------------------------------

--- A wager ticket (HNT-R162): a run on, or one that closed while the board was open this showing.
---@class WagerTicket
---@field run string              -- its run key: clicking it chooses it, its entry on the right page
---@field closed boolean          -- ended while the board was open this showing: greyed, struck through, never chosen
---@field selected boolean        -- the run the right page shows: an oxblood rim, pointing to the entry
---@field settled boolean         -- completed: the SETTLED stamp in place of the pips; never while updating
---@field source "rotation"|"companion"  -- the mark before its line
---@field mark string[]           -- the event mark's layers (HNT-R166)
---@field dial WagerDial          -- in its stub (HNT-R167), with the duration left or "closed"
---@field name string
---@field holiday string?         -- a holiday run's tag's name, on a green tag after the name, never cut
---@field line string             -- "Darkshore · until Sat 17:00", "Darkshore · closed Sat 17:00"
---@field need string?            -- "needs skill {n}" in pencil (HNT-R156)
---@field pips boolean[]?         -- one per Hunt, in definition order, inked bronze at its first mark; nil once settled
--- and while updating
---@field marks string?           -- "{done} of {n} first marks", or "updating…" (HNT-R69); nil once settled

--- A dashed row for a run ahead (HNT-R162).
---@class WagerAheadRow
---@field run string              -- its run key: clicking it chooses it
---@field selected boolean
---@field mark string[]
---@field name string
---@field zones string            -- "Silithus", "Felwood & Moonglade"
---@field need string?            -- "needs skill {n}"
---@field opens string            -- "opens Sat 17:00"
---@field length string           -- "for 3d"

-- A run's zones, joined: "Felwood & Moonglade".
---@param event HuntEvent
---@param input WagersInput
---@return string
local function zonesOf(event, input)
	return table.concat(ns.EventZoneNames(event, input.sources), ns.L.JOIN_ZONES)
end

-- One run's ticket: on, or closed this showing.
---@param shown HuntsShownRun
---@param input WagersInput
---@param closed boolean
---@return WagerTicket
local function ticketOf(shown, input, closed)
	local L, run, event = ns.L, shown.run, shown.event
	local settled = not input.updating and run.completedAt ~= nil
	local ends = ns.RealmWeekdayClock(run.end_, input.snapshot)
	local ticket = {
		run = shown.key,
		closed = closed,
		selected = false,
		settled = settled,
		source = run.source == "p" and "companion" or "rotation",
		mark = ns.EventMarkLayers(event.tags),
		dial = ns.WagerDial(shown, input.now, settled, closed),
		name = ns.events and ns.events:EventName(event) or event.id,
		holiday = ns.EventHolidayName(event),
		line = L.TICKET_LINE:format(
			zonesOf(event, input),
			(closed and L.TICKET_CLOSED_AT or L.LABEL_UNTIL):format(ends)
		),
		need = ns.EventSkillNeed(event, input.best),
	}
	if input.updating then
		ticket.marks = L.TICKET_UPDATING
		return ticket
	elseif settled then
		return ticket
	end
	ticket.pips = {}
	local done = 0
	for i, hunt in ipairs(event.hunts) do
		ticket.pips[i] = ns.HuntDone(run.hunts[hunt.id])
		done = done + (ticket.pips[i] and 1 or 0)
	end
	ticket.marks = L.TICKET_MARKS:format(done, #event.hunts)
	return ticket
end

-- One run ahead's dashed row.
---@param shown HuntsShownRun
---@param input WagersInput
---@return WagerAheadRow
local function aheadOf(shown, input)
	local L, run, event = ns.L, shown.run, shown.event
	return {
		run = shown.key,
		selected = false,
		mark = ns.EventMarkLayers(event.tags),
		name = ns.events and ns.events:EventName(event) or event.id,
		zones = zonesOf(event, input),
		need = ns.EventSkillNeed(event, input.best),
		opens = L.AHEAD_OPENS:format(ns.RealmWeekdayClock(run.start, input.snapshot)),
		length = L.AHEAD_FOR:format(ns.FormatDuration(run.end_ - run.start)),
	}
end

-- The spread ---------------------------------------------------------------------------------------------------------

--- A section's heading over the tickets or the rows ahead: "On now 4", "Ahead 2" and its caption.
---@class WagersSection
---@field label string
---@field count integer
---@field caption string?

--- The Pagle Wagers spread's left page, top to bottom (HNT-R162).
---@class WagersSpread
---@field kicker string           -- "Pagle Wagers"
---@field title string            -- "On the table"
---@field note string             -- follows the table: how many are on, or when the next opens
---@field closing string?         -- the closing note: "{event} closes in {duration}!"
---@field hint string[]?          -- the companion hint's lines on the hint slip (HNT-R170), with Get it and Dismiss;
--- nil while it doesn't apply
---@field onNow WagersSection?    -- "On now {n}" over the tickets, with any ticket
---@field tickets WagerTicket[]   -- the runs on (HNT-R160), then those that closed this showing
---@field ahead WagersSection?    -- "Ahead {n}", captioned, with any run ahead
---@field aheadRows WagerAheadRow[]
---@field empty string?           -- the dashed box's words, with no ticket and no run ahead
---@field ladder WagersLadder
---@field selected string?        -- the run the right page shows: the one chosen, else the first run on or ahead

--- What the spread reads besides WagersInput: the ladder's count and steps, the runs that ended while the board was
--- open this showing, and the run chosen.
---@class WagersSpreadInput
---@field settled integer         -- state.settled (HNT-R148)
---@field ladder table<integer, integer>   -- state.ladder
---@field ended HuntsShownRun[]   -- runs that were on this showing and have ended since (HNT-R143, HNT-R162)
---@field run string?             -- the ticket or row chosen (BoardPlace.run)
---@field hint string[]?          -- the companion hint's lines while it applies (HNT-R170)

-- The note under the title (HNT-R162), which follows the table: how many wagers are on, else when the next opens.
---@param on integer
---@param firstAhead HuntsShownRun?
---@param input WagersInput
---@return string
local function noteOf(on, firstAhead, input)
	local L = ns.L
	if on > 1 then
		return L.SPREAD_NOTE_MANY:format(on)
	elseif on == 1 then
		return L.SPREAD_NOTE_ONE
	elseif firstAhead then
		return L.SPREAD_NOTE_AHEAD:format(ns.RealmWeekdayClock(firstAhead.run.start, input.snapshot))
	end
	return L.SPREAD_NOTE_NONE
end

-- The closing note (HNT-R162): the soonest run on, not settled, that closes within the closing-note time (Tunables),
-- "{event} closes in {duration}!", the event's name up to its first comma; nil with none. While the projection
-- updates a run's settling isn't known, so none is taken for settled.
---@param tickets WagerTicket[]
---@param shownByKey table<string, HuntsShownRun>
---@param input WagersInput
---@return string?
local function closingOf(tickets, shownByKey, input)
	for _, ticket in ipairs(tickets) do
		local shown = shownByKey[ticket.run]
		if shown and not ticket.closed and not ticket.settled and ns.ClosingSoon(shown.run.end_ - input.now) then
			local name = ticket.name:match("^([^,]*)") or ticket.name
			return ns.L.SPREAD_CLOSING:format(name, ns.FormatDuration(shown.run.end_ - input.now))
		end
	end
	return nil
end

--- The Pagle Wagers spread's left page (HNT-R162): a ticket per run on, in HNT-R160's order, then one for each run that
--- ended while the board was open this showing, greyed and closed (by end); a dashed row per run ahead; the empty box
--- with neither; the companion hint's slip when it applies (HNT-R170); and the ladder at the foot. The right page shows
--- the run chosen, else the first run on or ahead; a closed ticket is never chosen (its run is no longer shown,
--- HNT-R143).
---@param input WagersInput
---@param spread WagersSpreadInput
---@return WagersSpread
function ns.BuildWagersSpread(input, spread)
	local L = ns.L
	local tickets, aheadRows, shown, firstAhead = {}, {}, {}, nil
	local on = 0
	for _, run in ipairs(input.runs) do
		shown[run.key] = run
		if run.on then
			tickets[#tickets + 1] = ticketOf(run, input, false)
			on = on + 1
		else
			aheadRows[#aheadRows + 1] = aheadOf(run, input)
			firstAhead = firstAhead or run
		end
	end
	local ended = {}
	for _, run in ipairs(spread.ended or {}) do
		if not shown[run.key] then
			ended[#ended + 1] = run
		end
	end
	table.sort(ended, function(a, b)
		if a.run.end_ ~= b.run.end_ then
			return a.run.end_ < b.run.end_
		end
		return a.key < b.key
	end)
	for _, run in ipairs(ended) do
		tickets[#tickets + 1] = ticketOf(run, input, true)
	end
	local selected = spread.run and shown[spread.run] and spread.run or (input.runs[1] and input.runs[1].key)
	for _, ticket in ipairs(tickets) do
		ticket.selected = not ticket.closed and ticket.run == selected
	end
	for _, row in ipairs(aheadRows) do
		row.selected = row.run == selected
	end
	return {
		kicker = L.WAGERS_KICKER,
		title = L.SPREAD_TITLE,
		note = noteOf(on, firstAhead, input),
		closing = closingOf(tickets, shown, input),
		hint = spread.hint,
		onNow = #tickets > 0 and { label = L.SPREAD_ON_NOW, count = on } or nil,
		tickets = tickets,
		ahead = #aheadRows > 0 and { label = L.SPREAD_AHEAD, count = #aheadRows, caption = L.SPREAD_AHEAD_CAPTION }
			or nil,
		aheadRows = aheadRows,
		empty = #tickets == 0 and #aheadRows == 0 and L.SPREAD_EMPTY or nil,
		ladder = ns.BuildWagersLadder(spread.settled or 0, spread.ladder or {}, input.updating),
		selected = selected,
	}
end
