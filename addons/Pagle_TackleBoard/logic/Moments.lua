if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What the Angler is told about the board (tackle-board.md › Announcements, TKB-R83–R87): the moments of a live
-- completion and its titles, the Campfire nods of a live advance, the Write-up after a first build or a catch-up, the
-- summary-only moments after any other rebuild, and the board's line on the Session summary, each guarded by the
-- celebrated set. It fills logic/Seams.lua's outlets, which the projection (logic/Projection.lua), the completions
-- (logic/Completions.lua) and the live step (adapter/LiveStep.lua) call. Pure logic (CORE-R7): what it tells Core goes through adapter/Moments.lua's seams
-- (ns.RaiseMoment, ns.RaiseWriteUp, ns.SetSummaryLine), which hold the Module handle, the celebrated set comes from
-- ns.Celebrated (PagleTackleBoardDB) and the client's number format from ns.api.FormatNumber. Every string is ns.L's;
-- fly and title names are lore (TKB-R130): ns.FlyName and ns.TitleName (logic/Words.lua).

-- The titles (ns.TITLES) and the milestone of each Campfire title (ns.CAMPFIRE_MILESTONES), by title ID; the icon
-- of each fly pattern (ns.FLY_PATTERNS), by pattern ID.
local TITLES, MILESTONES, FLY_ICONS = {}, {}, {}
for _, title in ipairs(ns.TITLES) do
	TITLES[title.id] = title
end
for _, milestone in ipairs(ns.CAMPFIRE_MILESTONES) do
	MILESTONES[milestone.title] = milestone
end
for _, pattern in ipairs(ns.FLY_PATTERNS) do
	FLY_ICONS[pattern.id] = pattern.icon
end

-- Each title source's moment (TKB-R86): its kind, its `order` on the banner rung and its icon key (ns.REWARD_ICONS).
local TITLE_MOMENTS = {
	campfire = { kind = "campfireMilestone", order = 10, icon = "campfire" },
	tally = { kind = "tallyTitle", order = 20, icon = "tally" },
	flybox = { kind = "flyBoxComplete", order = 30, icon = "flyBox" },
}

-- ns.L's template at `key`, its `{name}` fields filled from `fields` (a count in `fields.n` picks its form).
---@param key string
---@param fields table<string, any>?
---@return string
local function say(key, fields)
	return ns.Plural(fields and tonumber(fields.n) or 0, key, fields)
end

-- A count of days in words: "1 day", "7 days".
---@param n integer
---@return string
local function days(n)
	return ns.Plural(n, "DAYS")
end

-- The celebrated set (TKB-R83, ns.Celebrated), which only grows: there whenever the projection runs, which an inert
-- Module never makes (CORE-R13).
---@return { goals: table<string, true>, titles: table<string, true> }
local function celebrated()
	return ns.Celebrated() --[[@as { goals: table<string, true>, titles: table<string, true> }]]
end

-- A done goal's moment (TKB-R86): Notice or Expedition complete, its pay, the fly it tied in the text and as its
-- icon (else its kind's icon), on the completing Cast.
---@param goal TackleGoal
---@param castID string
---@return PagleMoment
local function goalMoment(goal, castID)
	local expedition = goal.type == "e"
	local text = ns.GoalText(goal)
	if goal.fly then
		text = say("TIED_FOR_FLY_BOX", { goal = text, fly = ns.FlyName(goal.fly) })
	end
	return {
		kind = expedition and "expeditionDone" or "noticeDone",
		rung = expedition and "toast" or "toast.low",
		title = expedition and ns.L.EXPEDITION_COMPLETE or ns.L.NOTICE_COMPLETE,
		text = text,
		icon = goal.fly and FLY_ICONS[goal.fly] or ns.KIND_ICONS[goal.kind],
		stamp = expedition and ns.L.EXPEDITION_DONE or ns.L.NOTICE_DONE,
		cast = castID,
		coins = goal.pay,
	}
end

-- A title's banner (TKB-R86): a Campfire milestone with its Coins, a tally title or the Fly Box, on the Cast that
-- earned it.
---@param titleID string
---@param castID string?
---@return PagleMoment
local function titleMoment(titleID, castID)
	local title = TITLES[titleID]
	local shape = TITLE_MOMENTS[title.source]
	local heading
	local milestone = MILESTONES[titleID]
	if title.source == "campfire" then
		heading = say("CAMPFIRE_MILESTONE", { n = title.need })
	elseif title.source == "tally" then
		heading = say("TALLY_TITLE", { n = title.need })
	else
		heading = ns.L.FLY_BOX_COMPLETE
	end
	return {
		kind = shape.kind,
		rung = "banner",
		order = shape.order,
		title = heading,
		text = say("TITLE_LINE", { title = ns.TitleName(titleID) }),
		icon = ns.REWARD_ICONS[shape.icon],
		cast = castID,
		coins = milestone and milestone.coins or nil,
	}
end

-- Raises `moment` for the Tackle Board, as a summary-only one if asked (ANN-R63).
---@param moment PagleMoment
---@param summaryOnly boolean?
local function raise(moment, summaryOnly)
	if summaryOnly then
		moment.summaryOnly = true
	end
	ns.RaiseMoment(moment)
end

-- Raises a Write-up section (ANN-R60).
---@param heading string
---@param lines string[]
local function raiseWriteUp(heading, lines)
	ns.RaiseWriteUp({ heading = heading, lines = lines })
end

--- The board's line on the Session summary (TKB-R87): "Tackle Board: {n} done today, Campfire {d} days", with
--- "Campfire not lit" at a count of 0 and the first part left out when nothing is done today. Never before Start
--- (TKB-R2).
local function setSummaryLine()
	if not ns.IsStarted() then
		return
	end
	local state = ns.State()
	local done = 0
	for _, goal in pairs(state.goals) do
		if goal.doneDay == state.day then
			done = done + 1
		end
	end
	local count = state.fire.count
	local campfire = count > 0 and ns.Plural(count, "CAMPFIRE_DAYS") or ns.L.CAMPFIRE_NOT_LIT
	local line = done > 0 and say("SUMMARY_LINE", { done = ns.Plural(done, "DONE_TODAY"), campfire = campfire })
		or say("SUMMARY_LINE_NOTHING_DONE", { campfire = campfire })
	ns.SetSummaryLine(line)
end

-- The scratch tally (TKB-R84): what the entries applied in "replay" or "rebuild" mode earned, outside the stored
-- state. Cleared by the projection's reset and after its done.
---@class TackleScratch
---@field casts integer               -- caught and got-away Casts applied after the start record
---@field goals string[]              -- goals completed, by ID, in order
---@field notices integer
---@field expeditions integer
---@field coins integer
---@field flies integer
---@field titles string[]             -- titles earned, by ID, in order
---@field burned integer              -- Kindling burned
---@field wentOut boolean             -- the fire went out
local scratch

-- An empty scratch tally.
---@return TackleScratch
local function newScratch()
	return {
		casts = 0,
		goals = {},
		notices = 0,
		expeditions = 0,
		coins = 0,
		flies = 0,
		titles = {},
		burned = 0,
		wentOut = false,
	}
end
scratch = newScratch()

--- Clears the scratch tally (TKB-R84): the projection's reset calls it.
function ns.ClearScratch()
	scratch = newScratch()
end

--- Counts an entry applied in "replay" or "rebuild" mode toward a first build's heading (TKB-R84: caught and got-away
--- Casts since the `start` record). The projection's apply calls it after each entry; a live one counts nothing.
---@param state TackleBoardState the state after the entry
---@param record PagleRecord
---@param mode TackleApplyMode
function ns.CountForWriteUp(state, record, mode)
	if mode ~= "live" and state.started and record.kind == "cast" then
		scratch.casts = scratch.casts + 1
	end
end

-- The Write-up's lines (TKB-R85) from the scratch tally and the Campfire after the last entry, each only if non-zero.
---@param state TackleBoardState
---@return string[]
local function writeUpLines(state)
	local lines = {}
	local notices, expeditions = scratch.notices, scratch.expeditions
	if notices > 0 and expeditions > 0 then
		lines[#lines + 1] = say("GOALS_DONE", {
			goals = say("GOALS_AND", {
				notices = ns.Plural(notices, "NOTICES"),
				expeditions = ns.Plural(expeditions, "EXPEDITIONS"),
			}),
		})
	elseif notices > 0 or expeditions > 0 then
		local goals = notices > 0 and ns.Plural(notices, "NOTICES") or ns.Plural(expeditions, "EXPEDITIONS")
		lines[#lines + 1] = say("GOALS_DONE", { goals = goals })
	end
	if scratch.coins > 0 then
		lines[#lines + 1] = say("COINS_LINE", { coins = ns.api.FormatNumber(scratch.coins) })
	end
	if scratch.flies > 0 then
		lines[#lines + 1] = ns.Plural(scratch.flies, "FLIES_TIED")
	end
	for _, titleID in ipairs(scratch.titles) do
		lines[#lines + 1] = say("TITLE_LINE", { title = ns.TitleName(titleID) })
	end
	local fire = state.fire
	if fire.count == 0 and scratch.wentOut then
		lines[#lines + 1] = say("CAMPFIRE_WENT_OUT", { longest = days(fire.longest) })
	elseif fire.count > 0 then
		local campfire = ns.Plural(fire.count, "CAMPFIRE_DAYS")
		if scratch.burned > 0 then
			campfire = say("CAMPFIRE_BURNED", { campfire = campfire, k = scratch.burned })
		end
		lines[#lines + 1] = campfire
	end
	return lines
end

-- Marks every goal and title the scratch tally holds as celebrated (TKB-R83).
local function celebrateScratch()
	local set = celebrated()
	for _, goalID in ipairs(scratch.goals) do
		set.goals[goalID] = true
	end
	for _, titleID in ipairs(scratch.titles) do
		set.titles[titleID] = true
	end
end

--- A goal completed in apply (TKB-R60): live, its moment and its titles' (TKB-R86), each unless already celebrated,
--- which they then are (TKB-R83), and the summary line (TKB-R87); in "replay" or "rebuild" mode, what it earned goes
--- to the scratch tally (TKB-R84) and nothing is raised.
---@param goal TackleGoal
---@param cast PagleCast the completing Cast
---@param earned TackleEarned
---@param mode TackleApplyMode
function ns.outlets.Completed(goal, cast, earned, mode)
	if mode ~= "live" then
		scratch.goals[#scratch.goals + 1] = goal.id
		if goal.type == "e" then
			scratch.expeditions = scratch.expeditions + 1
		else
			scratch.notices = scratch.notices + 1
		end
		scratch.coins = scratch.coins + earned.coins
		if earned.fly then
			scratch.flies = scratch.flies + 1
		end
		for _, titleID in ipairs(earned.titles) do
			scratch.titles[#scratch.titles + 1] = titleID
		end
		return
	end
	local set = ns.Celebrated()
	if not set then
		return -- an inert Module tells nothing (CORE-R13)
	end
	if not set.goals[goal.id] then
		set.goals[goal.id] = true
		raise(goalMoment(goal, cast.id))
	end
	for _, titleID in ipairs(earned.titles) do
		if not set.titles[titleID] then
			set.titles[titleID] = true
			raise(titleMoment(titleID, cast.id))
		end
	end
	setSummaryLine()
end

--- The projection advanced across board days (TKB-R14): live, one Campfire nod if it burned Kindling or put the
--- fire out (TKB-R86), worded for login while ns.InLoginWindow(); in "replay" or "rebuild" mode, the Kindling burned
--- and whether the fire went out go to the scratch tally (TKB-R84).
---@param result TackleAdvance
---@param mode TackleApplyMode
function ns.outlets.Advanced(result, mode)
	if mode ~= "live" then
		scratch.burned = scratch.burned + result.burned
		scratch.wentOut = scratch.wentOut or result.wentOut
		return
	end
	if not result.wentOut and result.burned == 0 then
		return
	end
	local away = ns.InLoginWindow()
	local kind, text
	if result.wentOut then
		kind = "fireOut"
		text = say(away and "FIRE_OUT_AWAY" or "FIRE_OUT", { longest = days(result.longest) })
	else
		kind = "kindlingBurned"
		text = say(away and "KINDLING_AWAY" or "KINDLING_BURNED", { k = result.burned, count = days(result.count) })
	end
	raise({ kind = kind, rung = "nod", title = text, icon = ns.REWARD_ICONS.campfire })
end

--- The projection's done (TKB-R84), first in it: after a first build, everything done and earned is celebrated and,
--- if a goal is done, one Write-up section is raised; after a catch-up whose replayed entries earned something or
--- changed the Campfire, one "While Tackle Board was off" section, and what they earned is celebrated; after any
--- other rebuild, each done goal and earned title not yet celebrated is raised summary-only on its Cast, then
--- celebrated. The scratch tally is cleared after.
---@param state TackleBoardState
---@param info { firstBuild: boolean?, rebuilt: boolean?, replayed: integer? }
function ns.outlets.Done(state, info)
	local set = celebrated()
	if info.firstBuild then
		for id, goal in pairs(state.goals) do
			if goal.doneDay ~= nil then
				set.goals[id] = true
			end
		end
		for titleID in pairs(state.titles) do
			set.titles[titleID] = true
		end
		celebrateScratch()
		if #scratch.goals > 0 then
			raiseWriteUp(
				ns.Plural(scratch.casts, "WRITE_UP_FIRST", { n = ns.api.FormatNumber(scratch.casts) }),
				writeUpLines(state)
			)
		end
	elseif (info.replayed or 0) > 0 then
		if #scratch.goals > 0 or #scratch.titles > 0 or scratch.burned > 0 or scratch.wentOut then
			raiseWriteUp(ns.L.WRITE_UP_WHILE_OFF, writeUpLines(state))
		end
		celebrateScratch()
	elseif info.rebuilt then
		local done = {}
		for _, goal in pairs(state.goals) do
			if goal.doneDay ~= nil and not set.goals[goal.id] then
				done[#done + 1] = goal
			end
		end
		table.sort(done, function(a, b)
			return a.doneTime < b.doneTime or (a.doneTime == b.doneTime and a.seq < b.seq)
		end)
		for _, goal in ipairs(done) do
			set.goals[goal.id] = true
			raise(goalMoment(goal, goal.doneCast), true)
		end
		-- In the Titles table's order (TKB-R106's tie-break).
		for _, title in ipairs(ns.TITLES) do
			local earned = state.titles[title.id]
			if earned and not set.titles[title.id] then
				set.titles[title.id] = true
				raise(titleMoment(title.id, earned.cast), true)
			end
		end
	end
	scratch = newScratch()
end

--- A live step finished (TKB-R13): the summary line (TKB-R87).
function ns.outlets.Stepped()
	setSummaryLine()
end
