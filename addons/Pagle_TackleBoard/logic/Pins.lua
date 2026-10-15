if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What the board's pins show (TKB-R44, TKB-R55, TKB-R101, TKB-R102, TKB-R104, TKB-R105, TKB-R108, TKB-R109): each
-- pinned goal's lines, the empty pins' texts and where each open goal hangs. Pure logic over the projection's state,
-- the board's words (logic/Words.lua), Core through ns.api.pagle and progress (logic/Progress.lua); adapter/Pins.lua
-- draws what it decides on the board's "pins" and "overflow" parts.

--- What a view knows besides the goal: the board day now, the current zone, whether the projection is updating and
--- whether the goal can be taken down now.
---@class TacklePinContext
---@field today integer             -- the board day now, ns.State().day (TKB-R104)
---@field zone integer              -- the current zone, ns.CurrentZone() (TKB-R121)
---@field updating boolean          -- ns.IsUpdating() (TKB-R108)
---@field canTakeDown boolean       -- ns.CanTakeDown(goal.id) (TKB-R55)

--- One Species of a Variety Expedition on its hover (TKB-R102).
---@class TackleHoverSpecies
---@field name string
---@field caught boolean

--- What one pinned goal shows (TKB-R102).
---@class TacklePinView
---@field kicker string                 -- its kind, set in small caps
---@field text string                   -- the goal text, printed
---@field progress string               -- "12 of 30", or "1 of 2 today" (TKB-R104)
---@field fill number                   -- the ink bar, 0 to 1
---@field where string                  -- where it can be worked
---@field here boolean                  -- a goal tied to a place, workable here: "I'm here" replaces where (TKB-R121)
---@field pay string                    -- "pays N Coins"
---@field seal string?                  -- an Expedition's wax seal: its pay
---@field stamp boolean                 -- re-posted: stamped RE-POSTED (TKB-R55)
---@field stranded string?              -- "no longer catchable" (TKB-R44)
---@field takeDown "hidden"|"enabled"|"disabled"  -- the "take it down" button (TKB-R55, TKB-R108)
---@field hover string[]                -- the posted time and the note
---@field species TackleHoverSpecies[]? -- a Variety Expedition's Species, in its items' order
---@field chip string                   -- its chip in the overflow strip: "Lure: 25 Catches with a lure on"

-- A Variety Expedition's Species for its hover (TKB-R102): each stored representative item the catalogue still has
-- with a `species` and not `removed` (TKB-R44, as its need counts them), named by the item, ticked when its Species is
-- among those counted (`seen`, TKB-R42).
---@param goal TackleGoal
---@param pagle table
---@return TackleHoverSpecies[]
local function hoverSpecies(goal, pagle)
	local list, listed = {}, {}
	for _, itemID in ipairs(goal.items or {}) do
		local item = pagle.GetItem(itemID)
		local species = item and not item.removed and item.species
		if species and not listed[species] then
			listed[species] = true
			list[#list + 1] = { name = ns.SpeciesName(itemID), caught = goal.seen[species] == true }
		end
	end
	return list
end

-- The "take it down" button (TKB-R55, TKB-R108): shown while the goal can be taken down, disabled while updating.
---@param ctx TacklePinContext
---@return "hidden"|"enabled"|"disabled"
local function takeDown(ctx)
	if not ctx.canTakeDown then
		return "hidden"
	end
	return ctx.updating and "disabled" or "enabled"
end

--- What a pinned goal shows (TKB-R102): its kind; its text; its displayed progress over its need (TKB-R104), "today"
--- for a day-bound goal; where it can be worked, or "I'm here" for a goal tied to a place that is
--- workable here (TKB-R121); its pay, on a seal too for an Expedition; RE-POSTED for a re-posted goal; "no longer
--- catchable" for a stranded one (TKB-R44); "take it down" (TKB-R55, TKB-R108); and its hover.
---@param goal TackleGoal
---@param ctx TacklePinContext
---@return TacklePinView
function ns.PinView(goal, ctx)
	local L, pagle = ns.L, ns.api.pagle
	local need = ns.GoalNeed(goal, pagle)
	local progress = ns.DisplayedProgress(goal, ctx.today)
	local bound = ns.IsDayBound(goal)
	local isVarietyExpedition = goal.type == "e" and goal.kind == "variety"
	local kicker, text = ns.KindLabel(goal.kind), ns.GoalText(goal)
	return {
		kicker = kicker,
		text = text,
		chip = ns.Fill(L.OVERFLOW_CHIP, { kind = kicker, text = text }),
		progress = ns.Fill(bound and L.PROGRESS_TODAY or L.PROGRESS, { n = progress, need = need }),
		fill = need > 0 and math.min(1, progress / need) or 0,
		where = ns.GoalWhere(goal),
		here = ns.IsPlaceGoal(goal) and ns.IsWorkableHere(goal, ctx.zone),
		pay = ns.Plural(goal.pay, "PAYS"),
		seal = goal.type == "e" and tostring(goal.pay) or nil,
		stamp = goal.reposted,
		stranded = ns.IsStranded(goal, pagle) and L.NO_LONGER_CATCHABLE or nil,
		takeDown = takeDown(ctx),
		hover = { ns.PostedTime(goal.time), bound and L.ONLY_SINCE_TODAY or L.ONLY_SINCE },
		species = isVarietyExpedition and hoverSpecies(goal, pagle) or nil,
	}
end

-- The board's layout and its empty pins (TKB-R101, TKB-R105).

--- One pin: the goal on it, or the empty pin's text.
---@class TacklePin
---@field goal TackleGoal?
---@field empty string?

--- Where the open goals hang (TKB-R101): the pins of each type in order, and the overflow strip.
---@class TacklePinLayout
---@field expeditions TacklePin[]   -- the top row's 2 pins
---@field notices TacklePin[]       -- the two rows of 3, left to right and top to bottom
---@field overflow TackleGoal[]     -- the open goals with no pin, by seq

-- The empty pins' texts, read live (TKB-R105): the countdown to the daily reset and the realm weekday of the next
-- weekly reset, from the current board day's and week's starts (TKB-R10, TKB-R11).
---@param api TackleResetAPI
---@return string notice the first empty Notice pins' text
---@return string expedition the first empty Expedition pin's text
local function emptyTexts(api)
	local L = ns.L
	local dayStart, weekStart = ns.LiveBoundaries(api)
	local countdown = ns.Countdown(dayStart + ns.DAY_SECONDS - api.GetServerTime())
	local weekday = ns.WeekdayName(weekStart + ns.WEEK_SECONDS)
	return ns.Fill(L.EMPTY_NOTICE, { time = countdown }), ns.Fill(L.EMPTY_EXPEDITION, { weekday = weekday })
end

-- A row of pins: each pin's open goal, or the empty pin's text, `first` for the first `firstCount` empty pins and
-- `later` after them.
---@param state TackleBoardState
---@param ids (string|false)[]
---@param first string
---@param firstCount integer
---@param later string
---@return TacklePin[]
local function pinRow(state, ids, first, firstCount, later)
	local row, empty = {}, 0
	for i, id in ipairs(ids) do
		local goal = id and state.goals[id]
		if goal then
			row[i] = { goal = goal }
		else
			empty = empty + 1
			row[i] = { empty = empty <= firstCount and first or later }
		end
	end
	return row
end

--- Where each open goal of a started board hangs (TKB-R101), with the empty pins' texts (TKB-R105): the first 3 empty
--- Notice pins read the countdown to the daily reset and any further ones "More Notices at later resets"; the first
--- empty Expedition pin reads the next weekly reset's realm weekday and a second "Another at the weekly reset after".
---@param state TackleBoardState
---@param api TackleResetAPI ns.api: the times are read from it at each call
---@return TacklePinLayout
function ns.PinLayout(state, api)
	local L = ns.L
	local notice, expedition = emptyTexts(api)
	local overflow = {}
	for _, goal in ipairs(ns.BoardOrder(state)) do
		if goal.pin == nil then
			overflow[#overflow + 1] = goal
		end
	end
	return {
		expeditions = pinRow(state, state.pins.expeditions, expedition, 1, L.EMPTY_EXPEDITION_LATER),
		-- As many empty Notice pins promise a fresh Notice at the next reset as a reset issues (TKB-R105, TKB-R20).
		notices = pinRow(state, state.pins.notices, notice, ns.NOTICES_PER_DAY, L.EMPTY_NOTICE_LATER),
		overflow = overflow,
	}
end

--- The overflow strip's last chip when more goals wait than it has chips for (TKB-R101): "+N more waiting for a pin".
---@param n integer the goals it stands for
---@return string
function ns.OverflowMore(n)
	return ns.Fill(ns.L.OVERFLOW_MORE, { n = n })
end

--- The goal the board highlights when opened with `goalID` (TKB-R109): that goal while it is open, else none.
---@param state TackleBoardState
---@param goalID string?
---@return string?
function ns.HighlightedGoal(state, goalID)
	local goal = goalID and state.goals[goalID]
	if goal and goal.doneDay == nil then
		return goalID
	end
	return nil
end
