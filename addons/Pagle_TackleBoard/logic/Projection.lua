if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's one projection (TKB-R81): the fold over every entry M:IterateCatches yields, its own Module
-- records and every Cast. Pure logic (CORE-R7): the state is a function of the entries applied, the catalogue and
-- the day it has been advanced to (TKB-R82). It numbers board days from the records (TKB-R12, through logic/Days.lua),
-- advances through them with their Campfire closes and refills (TKB-R14, TKB-R20), and puts issued and re-posted
-- goals on their pins (TKB-R21–R23, TKB-R57, TKB-R101). Completions are #232's: they slot in where marked below.

--- The Tackle Board's rules version (Tunables, TKB-R81): rises whenever a progress, Campfire, Fly Box or
--- pattern-order rule changes. Generation changes don't need it (TKB-R22). Not bumped within M7.
ns.TKB_RULES_VERSION = 1

-- Tunables (TKB-R20). The caps are the pin counts (ns.NOTICE_PINS, ns.EXPEDITION_PINS).
local NOTICES_PER_DAY = 3 -- Notices owed at each daily reset, up to the cap
local EXPEDITIONS_PER_WEEK = 1 -- Expeditions owed at each weekly reset, up to the cap
local START_NOTICES = 3 -- Goals owed at Start
local START_EXPEDITIONS = 1

--- What an advance did (TKB-R14, TKB-R72), handed to ns.outlets.Advanced: the days closed and the Campfire after.
---@class TackleAdvance
---@field from integer                -- the first day closed: the projection's day before
---@field to integer                  -- the day advanced to
---@field closed { day: integer, log: TackleDayLog }[] -- each day closed, in order, with its Campfire outcome
---@field burned integer              -- Kindling burned
---@field wentOut boolean             -- the fire went out
---@field count integer               -- the Campfire count after it
---@field longest integer

-- `n` empty pins.
---@param n integer
---@return false[]
local function emptyPins(n)
	local pins = {}
	for i = 1, n do
		pins[i] = false
	end
	return pins
end

--- A fresh, empty TackleBoardState (tackle-board.md › Projection): unstarted, no goals, no fire, nothing learned.
---@return TackleBoardState
function ns.NewBoardState()
	return {
		day = 0,
		week = 0,
		owed = { notices = 0, expeditions = 0 },
		pins = { expeditions = emptyPins(ns.EXPEDITION_PINS), notices = emptyPins(ns.NOTICE_PINS) },
		goals = {},
		tally = { notices = 0, expeditions = 0 },
		coins = 0,
		flies = {},
		titles = {},
		fire = { count = 0, kindling = 0, longest = 0, milestones = {}, log = {} },
		zones = {},
		caught = {},
	}
end

-- The pin list of a goal type.
---@param state TackleBoardState
---@param goalType TackleGoalType
---@return (string|false)[]
local function pinsOf(state, goalType)
	return goalType == "e" and state.pins.expeditions or state.pins.notices
end

-- The open goals (not completed) of each type.
---@param state TackleBoardState
---@return integer notices
---@return integer expeditions
local function openCounts(state)
	local notices, expeditions = 0, 0
	for _, goal in pairs(state.goals) do
		if goal.doneDay == nil then
			if goal.type == "e" then
				expeditions = expeditions + 1
			else
				notices = notices + 1
			end
		end
	end
	return notices, expeditions
end

-- The open goals waiting unpinned in the overflow strip, by seq (TKB-R101); only those of `goalType` if given.
---@param state TackleBoardState
---@param goalType TackleGoalType?
---@return TackleGoal[]
local function overflow(state, goalType)
	local waiting = {}
	for _, goal in pairs(state.goals) do
		if goal.doneDay == nil and goal.pin == nil and (goalType == nil or goal.type == goalType) then
			waiting[#waiting + 1] = goal
		end
	end
	table.sort(waiting, function(a, b)
		return a.seq < b.seq
	end)
	return waiting
end

-- One weekly accrual (TKB-R20): an Expedition owed, up to the cap.
---@param state TackleBoardState
local function weeklyAccrual(state)
	local _, open = openCounts(state)
	local owed = state.owed
	owed.expeditions = owed.expeditions
		+ math.max(0, math.min(EXPEDITIONS_PER_WEEK, ns.EXPEDITION_PINS - open - owed.expeditions))
end

-- Raises the projection's week to `week`, one weekly accrual per week risen; it never falls (TKB-R14).
---@param state TackleBoardState
---@param week integer
local function raiseWeek(state, week)
	while state.week < week do
		state.week = state.week + 1
		weeklyAccrual(state)
	end
end

--- Advances a started projection from its day to board day `q` (TKB-R14): closes each day from `state.day` to
--- `q − 1` in order (the Campfire's close, TKB-R72; the daily accrual into the next day, TKB-R20; the week rising to
--- the next day's week, TKB-R12, each rise one weekly accrual), then hands what it did to ns.outlets.Advanced with
--- `mode`. A `q` at or below the projection's day, or an unstarted board, changes nothing. The live step (#233)
--- calls it with "live", the only change made outside apply.
---@param state TackleBoardState
---@param q integer
---@param mode TackleApplyMode
---@return TackleAdvance? result nil when nothing was closed
function ns.AdvanceTo(state, q, mode)
	if not state.started or q <= state.day then
		return nil
	end
	local fire = state.fire
	---@type TackleAdvance
	local result = { from = state.day, to = q, closed = {}, burned = 0, wentOut = false, count = 0, longest = 0 }
	for k = state.day, q - 1 do
		local log = ns.Campfire.CloseDay(fire, k, fire.log[k] == "lit")
		result.closed[#result.closed + 1] = { day = k, log = log }
		if log == "burned" then
			result.burned = result.burned + 1
		elseif log == "out" then
			result.wentOut = true
		end
		local open = openCounts(state)
		local owed = state.owed
		owed.notices = owed.notices + math.max(0, math.min(NOTICES_PER_DAY, ns.NOTICE_PINS - open - owed.notices))
		raiseWeek(state, ns.WeekOfDay(state.boundary, k + 1))
		state.day = k + 1
	end
	result.count, result.longest = fire.count, fire.longest
	ns.outlets.Advanced(result, mode)
	return result
end

--- Frees a goal's pin (TKB-R101): the first goal of its type waiting in the overflow strip takes it, before any new
--- goal does. The completions (#232) call it once a goal is marked done; a goal in the strip has no pin to free.
---@param state TackleBoardState
---@param goal TackleGoal
function ns.FreePin(state, goal)
	local pin = goal.pin
	if pin == nil then
		return
	end
	local pins = pinsOf(state, goal.type)
	goal.pin = nil
	pins[pin] = false
	local waiting = overflow(state, goal.type)[1]
	if waiting then
		waiting.pin, pins[pin] = pin, waiting.id
	end
end

--- The open goals in board order (TKB-R101, TKB-R45): the Expedition pins, the Notice pins left to right and top to
--- bottom, then the overflow strip by seq.
---@param state TackleBoardState
---@return TackleGoal[]
function ns.BoardOrder(state)
	local order = {}
	for _, pins in ipairs({ state.pins.expeditions, state.pins.notices }) do
		for _, id in ipairs(pins) do
			if id then
				order[#order + 1] = state.goals[id]
			end
		end
	end
	for _, goal in ipairs(overflow(state)) do
		order[#order + 1] = goal
	end
	return order
end

-- Puts a new goal on the board from its record (TKB-R21–R23): open, its definition from the record alone, on the
-- first empty pin of its type or else in the overflow strip (TKB-R101).
---@param state TackleBoardState
---@param record PagleModuleRecord
---@param def TackleGoalDef
---@param reposted boolean
---@return TackleGoal
local function post(state, record, def, reposted)
	---@type TackleGoal
	local goal = {
		id = record.id,
		seq = record.seq,
		time = record.time,
		issuedDay = state.day,
		type = def.type,
		kind = def.kind,
		tier = def.tier,
		pay = def.pay,
		need = def.need,
		target = def.target,
		items = def.items,
		reposted = reposted,
		progress = 0,
		seen = {},
	}
	state.goals[goal.id] = goal
	return goal
end

-- Puts a goal on the first empty pin of its type, or leaves it in the overflow strip (TKB-R101).
---@param state TackleBoardState
---@param goal TackleGoal
local function pinFirstEmpty(state, goal)
	local pins = pinsOf(state, goal.type)
	for pin, id in ipairs(pins) do
		if not id then
			goal.pin, pins[pin] = pin, goal.id
			return
		end
	end
end

-- Applies one of the board's own records to a started board, after advancing to its day. Returns whether it changed
-- the state.
---@param state TackleBoardState
---@param record PagleModuleRecord
---@param decoded TackleRecord
---@param day integer the record's day: the latest boundary's numbering, never below the projection's day
---@param mode TackleApplyMode
---@return boolean
local function applyRecord(state, record, decoded, day, mode)
	if decoded.kind == "day" then
		local numbered = ns.NumberBoundary(state.boundary, decoded.dayStart, decoded.weekStart)
		ns.AdvanceTo(state, numbered.day, mode)
		raiseWeek(state, numbered.week)
		state.boundary = {
			seq = record.seq,
			day = numbered.day,
			week = numbered.week,
			dayStart = decoded.dayStart,
			weekStart = decoded.weekStart,
		}
		return true
	end
	if decoded.kind == "reroll" then
		-- TKB-R57: an old goal that isn't open ignores the whole record, new goal included
		local old = state.goals[decoded.old]
		if not old or old.doneDay ~= nil then
			return false
		end
		ns.AdvanceTo(state, day, mode)
		local goal = post(state, record, decoded.goal, true)
		state.goals[old.id] = nil
		-- The re-posted goal takes the old one's pin, or its place in the overflow strip (TKB-R101). A new definition
		-- of another type (never generated, TKB-R55) frees the old pin and is pinned as a new goal.
		if old.type == goal.type then
			if old.pin then
				goal.pin = old.pin
				pinsOf(state, goal.type)[old.pin] = goal.id
			end
		else
			ns.FreePin(state, old)
			pinFirstEmpty(state, goal)
		end
		return true
	end
	ns.AdvanceTo(state, day, mode)
	local goal = post(state, record, decoded.goal, false)
	pinFirstEmpty(state, goal)
	local owed = state.owed
	if goal.type == "e" then
		owed.expeditions = math.max(0, owed.expeditions - 1)
	else
		owed.notices = math.max(0, owed.notices - 1)
	end
	return true
end

-- Starts the board from its first `start` record (TKB-R6, TKB-R20, TKB-R71): day 0 and week 0, 3 Notices and an
-- Expedition owed, 2 Kindling.
---@param state TackleBoardState
---@param record PagleModuleRecord
---@param decoded TackleRecord
local function start(state, record, decoded)
	state.started = { seq = record.seq, time = record.time }
	local numbered = ns.NumberBoundary(nil, decoded.dayStart, decoded.weekStart)
	state.boundary = {
		seq = record.seq,
		day = numbered.day,
		week = numbered.week,
		dayStart = decoded.dayStart,
		weekStart = decoded.weekStart,
	}
	state.day, state.week = numbered.day, numbered.week
	state.owed.notices, state.owed.expeditions = START_NOTICES, START_EXPEDITIONS
	ns.Campfire.Start(state.fire)
end

--- Applies one entry (TKB-R81): one of the board's own Module records, or a Cast, Skill Reading or any other entry
--- M:IterateCatches yields. Returns whether it changed the state.
---@param state TackleBoardState
---@param record PagleRecord
---@param mode TackleApplyMode
---@return boolean
function ns.ApplyEntry(state, record, mode)
	local changed = false
	if record.kind == "module" then
		local moduleRecord = record --[[@as PagleModuleRecord]]
		local decoded = ns.DecodeRecord(moduleRecord.recordKind, moduleRecord.payload)
		if not decoded then
			return false -- TKB-R80: skipped
		end
		if decoded.kind == "start" then
			if state.started then
				return false -- TKB-R6: only the first start record counts
			end
			start(state, moduleRecord, decoded)
			return true
		end
		if not state.started then
			return false -- TKB-R2: before the start record, nothing else changes
		end
		return applyRecord(state, moduleRecord, decoded, math.max(state.day, ns.DayOf(state.boundary, record.time)), mode)
	end
	if state.started then
		-- TKB-R12, TKB-R14: every other entry advances to its day, never below the projection's day
		changed = ns.AdvanceTo(state, ns.DayOf(state.boundary, record.time), mode) ~= nil
	end
	if record.kind == "cast" then
		local cast = record --[[@as PagleCast]]
		-- (#232: each open goal counts the Cast's Catches here, before `caught` learns them, TKB-R46.)
		-- TKB-R2, TKB-R30: zone recency, from every Cast, caught or not
		local zone = cast.conditions.zone
		if zone ~= 0 then
			state.zones[zone] = cast.time
			changed = true
		end
		-- TKB-R2, TKB-R46: every item ever caught
		if cast.outcome == "caught" then
			for _, slot in ipairs(cast.items) do
				if slot.itemID ~= 0 and not state.caught[slot.itemID] then
					state.caught[slot.itemID] = true
					changed = true
				end
			end
		end
	end
	return changed
end

--- The Tackle Board's projection def for `M:NewProjection` (TKB-R81) over `global.board` (made here if missing):
--- rules version TKB_RULES_VERSION × 1000 + Core's Session rules version (SIZE_RULES_VERSION isn't folded). A live
--- apply that changes the state asks the views to redraw; `done` runs in graph.md's order: ns.outlets.Done,
--- ns.ReportCoins, ns.ScheduleLiveStep (TKB-R84), then a redraw.
---@param global table PagleTackleBoardDB's global section
---@param sessionRulesVersion integer Pagle.SESSION_RULES_VERSION
---@return PagleProjectionDef
function ns.ProjectionDef(global, sessionRulesVersion)
	if type(global.board) ~= "table" then
		global.board = {}
	end
	return {
		db = global.board,
		rulesVersion = ns.TKB_RULES_VERSION * 1000 + sessionRulesVersion,
		reset = ns.NewBoardState,
		apply = function(state, record, mode)
			if ns.ApplyEntry(state, record, mode) and mode == "live" then
				ns.Redraw("projection")
			end
		end,
		done = function(state, info)
			ns.outlets.Done(state, info)
			ns.ReportCoins()
			ns.ScheduleLiveStep()
			ns.Redraw("projection")
		end,
	}
end
