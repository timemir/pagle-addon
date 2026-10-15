if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What the spike and the ledge show (TKB-R62, TKB-R64, TKB-R70–R74, TKB-R103, TKB-R105, TKB-R106, TKB-R130): the
-- goals on the spike, the Campfire and its flame's step, the Campfire card's 28 days and titles, the Fly Box drawer's
-- cells and the tally plate with the latest title. Pure logic over the projection's state, the board's words
-- (logic/Words.lua) and the rewards' data (logic/Rewards.lua); adapter/Ledge.lua draws what it decides on the board's
-- "spike" and "ledge" parts. Fly and title names are lore (TKB-R130): `ns.L`'s keys, falling back to their IDs until
-- the lore batch gives them text (M7 graph, open question 7).

--- A template with `{name}` fields filled from `fields`.
---@param template string
---@param fields table<string, any>
---@return string
local function fill(template, fields)
	return (
		template:gsub("{(%w+)}", function(name)
			local value = fields[name]
			return value ~= nil and tostring(value) or nil
		end)
	)
end

--- A fly pattern's name (TKB-R130): `fly.<id>.name`, or its ID.
---@param patternID string
---@return string
local function flyName(patternID)
	return ns.L["fly." .. patternID .. ".name"] or patternID
end

-- The spike (TKB-R103).

--- One goal on the spike.
---@class TackleSpikeGoal
---@field id string
---@field text string        -- the goal text, on its slip
---@field hover string[]     -- the goal text, its Coins and the fly it tied

--- What the spike shows (TKB-R103).
---@class TackleSpikeView
---@field goals TackleSpikeGoal[]   -- in completion order, the first at the top of the stack
---@field label string              -- "{n} done today. The fire's lit." or "Done ones go on the spike."

-- Whether `a` completed before `b`: by the completing Cast's time, then its entry ID (LOG-R13: the second's counter),
-- then, for goals one Catch completed together, in board order (TKB-R45): Expeditions before Notices, then by seq.
---@param a TackleGoal
---@param b TackleGoal
---@return boolean
local function completedBefore(a, b)
	if a.doneTime ~= b.doneTime then
		return a.doneTime < b.doneTime
	end
	if a.doneCast ~= b.doneCast then
		return tostring(a.doneCast) < tostring(b.doneCast)
	end
	if a.type ~= b.type then
		return a.type == "e"
	end
	return a.seq < b.seq
end

--- What the spike shows (TKB-R103): the goals done on the projection's current board day, in completion order, each
--- with its text and a hover of its Coins (its pay) and the fly it tied; underneath, how many are done and that the
--- fire's lit, or "Done ones go on the spike." with none. At the next reset the projection's day moves on, and the
--- spike empties.
---@param state TackleBoardState
---@return TackleSpikeView
function ns.SpikeView(state)
	local L = ns.L
	local done = {}
	for _, goal in pairs(state.goals) do
		if goal.doneDay ~= nil and goal.doneDay == state.day then
			done[#done + 1] = goal
		end
	end
	table.sort(done, completedBefore)
	local goals = {}
	for i, goal in ipairs(done) do
		local text = ns.GoalText(goal)
		local hover = { text, ns.Plural(goal.pay, "SPIKE_COINS") }
		if goal.fly then
			hover[#hover + 1] = fill(L.SPIKE_FLY, { fly = flyName(goal.fly) })
		end
		goals[i] = { id = goal.id, text = text, hover = hover }
	end
	return {
		goals = goals,
		label = #goals > 0 and fill(L.SPIKE_DONE, { n = #goals }) or L.SPIKE_EMPTY,
	}
end

-- The Campfire (TKB-R70–R74, TKB-R106).

--- What the Campfire on the ledge shows (TKB-R106).
---@class TackleCampfireView
---@field state "lit"|"out"|"unlit"   -- a flame; embers after a fire went out; bare logs before the first fire
---@field text string                 -- "{n} days", "Gone out" or "Not lit yet"
---@field step integer                -- the flame's size: 0 (none), 1 below 7 days, then one more at 7, 30, 100, 365
---@field bright number               -- the flame's brightness within its step, 0.5 to 1 (0 with no flame)
---@field kindling integer            -- the Kindling, drawn as sticks
---@field kindlingCap integer         -- the sticks drawn: the Kindling cap, the missing ones faint (TKB-R70)
---@field longest string              -- "longest {L}" (TKB-R74)

--- What the Campfire shows (TKB-R106): a flame with "{n} days" while the count is above 0; "Gone out" with embers when
--- it is 0 after a fire (the longest above 0, TKB-R74); "Not lit yet" with bare logs before the first fire; its
--- Kindling as sticks and "longest {L}". The flame steps up at each milestone's count of the current fire (7, 30, 100,
--- 365, TKB-R73) and brightens from 0.5 to 1 between them; past the last step it brightens over as many days again.
---@param fire TackleFire the projection's fire
---@return TackleCampfireView
function ns.CampfireView(fire)
	local L = ns.L
	local count = fire.count
	local view = {
		kindling = fire.kindling,
		kindlingCap = ns.KINDLING_CAP,
		longest = fill(L.CAMPFIRE_LONGEST, { n = fire.longest }),
		step = 0,
		bright = 0,
	}
	if count == 0 then
		view.state = fire.longest > 0 and "out" or "unlit"
		view.text = fire.longest > 0 and L.CAMPFIRE_OUT or L.CAMPFIRE_UNLIT
		return view
	end
	view.state, view.text = "lit", ns.Plural(count, "CAMPFIRE_DAYS")
	local reached, previous, nextDays = 0, 0, nil
	for _, milestone in ipairs(ns.CAMPFIRE_MILESTONES) do
		if count >= milestone.days then
			reached, previous = reached + 1, milestone.days
		elseif not nextDays then
			nextDays = milestone.days
		end
	end
	local span = (nextDays or previous * 2) - previous
	view.step = reached + 1
	view.bright = 0.5 + 0.5 * math.min(1, (count - previous) / span)
	return view
end

-- The Campfire card (TKB-R106, TKB-R64).

--- A title's name (TKB-R130): `boardtitle.<id>.text`, or its ID.
---@param titleID string
---@return string
local function titleName(titleID)
	return ns.L["boardtitle." .. titleID .. ".text"] or titleID
end

--- A server time's realm date (TKB-R105): "Sun 11 Oct", its day of the month and its weekday ("Sun").
---@param serverTime integer
---@return string date
---@return integer number
---@return string weekday
local function realmDay(serverTime)
	local L = ns.L
	local date = ns.RealmDate(serverTime)
	local weekday = L.WEEKDAYS[date.weekday]
	return fill(L.CARD_DATE, { weekday = weekday, day = date.day, month = L.MONTHS[date.month] }), date.day, weekday
end

--- The board day the `start` record numbers 0 (TKB-R12, ns.NumberBoundary): the board's first day. Earlier days are
--- "before the board".
local FIRST_DAY = 0

--- One day of the Campfire card's four-week log.
---@class TackleCardDay
---@field day integer        -- the board day
---@field status "lit"|"burned"|"out"|"unlit"|"before"|"today"
---@field text string        -- "lit", "Kindling burned", "went out", "not lit", "before the board" or "today"
---@field date string        -- its realm date: "Sun 11 Oct"
---@field number integer     -- its day of the month, on its cell

--- One title on the Campfire card: earned, or greyed with what it needs.
---@class TackleCardTitle
---@field id string
---@field name string
---@field need string        -- what earns it: "a Campfire of 7 days", "25 goals done", "every Fly Box pattern tied"
---@field coins string?      -- a milestone's Coins: "25 Coins"
---@field earned boolean     -- earned in the projection, or shown through the celebrated set (TKB-R64)

--- What the Campfire card shows (TKB-R106).
---@class TackleCampfireCard
---@field days TackleCardDay[]          -- the last 28 board days, oldest first, today last
---@field heads string[]                -- the weekdays of its first seven days, over its four weeks
---@field milestones TackleCardTitle[]  -- the Campfire milestones in order, with their Coins
---@field tally TackleCardTitle[]       -- the tally titles
---@field flybox TackleCardTitle[]      -- the Fly Box title

-- A day's status on the card: before the board's first day, "before"; today, "lit" once lit, else "today"; any other
-- day, its Campfire log ("unlit" if it has none).
---@param state TackleBoardState
---@param day integer
---@return "lit"|"burned"|"out"|"unlit"|"before"|"today"
local function dayStatus(state, day)
	local logged = state.fire.log[day]
	if day < FIRST_DAY then
		return "before"
	elseif day == state.day then
		return logged == "lit" and "lit" or "today"
	end
	return logged or "unlit"
end

--- The Campfire card of a started board (TKB-R106): its four-week log, each of the last 28 board days (ns.KEPT_DAYS)
--- with today: lit, Kindling burned, went out, not lit, before the board, or "today" while today is unlit, each dated in
--- realm time by the day's start; the milestones with their Coins and titles; the tally titles; the Fly Box title. A
--- title is earned when the projection's `titles` has it or the celebrated set does (TKB-R64: a title shown once stays
--- shown); one not earned is greyed with what it needs.
---@param state TackleBoardState
---@param celebrated { [string]: true } the celebrated set's titles (PagleTackleBoardDB.global.celebrated.titles)
---@return TackleCampfireCard
function ns.CampfireCard(state, celebrated)
	local L = ns.L
	local card = { days = {}, heads = {}, milestones = {}, tally = {}, flybox = {} }
	for i = 1, ns.KEPT_DAYS do
		local day = state.day - ns.KEPT_DAYS + i
		local status = dayStatus(state, day)
		local date, number, weekday = realmDay(ns.DayStartOf(state.boundary --[[@as TackleBoundary]], day))
		card.days[i] = { day = day, status = status, text = L.CARD_DAYS[status], date = date, number = number }
		if i <= 7 then
			card.heads[i] = weekday
		end
	end
	local coins = {}
	for _, milestone in ipairs(ns.CAMPFIRE_MILESTONES) do
		coins[milestone.title] = milestone.coins
	end
	for _, title in ipairs(ns.TITLES) do
		local row = {
			id = title.id,
			name = titleName(title.id),
			need = fill(L.CARD_NEEDS[title.source], { n = title.need }),
			earned = state.titles[title.id] ~= nil or celebrated[title.id] == true,
		}
		local list = card.tally
		if title.source == "campfire" then
			row.coins, list = ns.Plural(coins[title.id], "COINS"), card.milestones
		elseif title.source == "flybox" then
			list = card.flybox
		end
		list[#list + 1] = row
	end
	return card
end

-- The Fly Box (TKB-R62, TKB-R106).

--- The drawer's columns: 6 across, so the 30 patterns fill 5 rows and the rare six the last.
local DRAWER_COLUMNS = 6

--- One felt compartment of the Fly Box drawer.
---@class TackleFlyCell
---@field id string          -- the pattern ID
---@field row integer        -- 1–5, top to bottom
---@field column integer     -- 1–6, left to right
---@field rare boolean       -- a gilt edge: tied only by Expeditions
---@field tied boolean
---@field icon string?       -- the pattern's icon, once tied
---@field text string        -- its name once tied, else "not tied yet"
---@field hover string[]     -- its name, then when and by which goal it was tied, or "not tied yet"; a rare one adds
---                          -- "tied only by Expeditions"

--- What the Fly Box shows (TKB-R106).
---@class TackleFlyBoxView
---@field label string            -- "{n} of 30 tied", on the box
---@field cells TackleFlyCell[]   -- the drawer's compartments, in pattern order

--- What the Fly Box shows (TKB-R106): "{n} of 30 tied" on the box, and its drawer of 6 × 5 felt compartments filled
--- in pattern order row by row, so the rare six fill the last row. A tied pattern shows its icon and name, and on hover
--- the realm date it was tied and the goal that tied it, from the copy the fly keeps (TKB-R62), so a goal pruned after
--- 28 board days still names it; an untied one reads "not tied yet". The rare ones read "tied only by Expeditions".
---@param flies { [string]: { day: integer, time: integer, goal: TackleGoal } } the projection's flies
---@return TackleFlyBoxView
function ns.FlyBoxView(flies)
	local L = ns.L
	local cells, tied = {}, 0
	for i, pattern in ipairs(ns.FLY_PATTERNS) do
		local name, fly = flyName(pattern.id), flies[pattern.id]
		local cell = {
			id = pattern.id,
			row = math.floor((i - 1) / DRAWER_COLUMNS) + 1,
			column = (i - 1) % DRAWER_COLUMNS + 1,
			rare = pattern.rare,
			tied = fly ~= nil,
			text = fly and name or L.FLY_UNTIED,
		}
		if fly then
			tied = tied + 1
			cell.icon = pattern.icon
			cell.hover = {
				name,
				fill(L.FLY_TIED, { date = (realmDay(fly.time)) }),
				fill(L.FLY_GOAL, { goal = ns.GoalText(fly.goal) }),
			}
		else
			cell.hover = { name, L.FLY_UNTIED }
		end
		if pattern.rare then
			cell.hover[#cell.hover + 1] = L.FLY_RARE
		end
		cells[i] = cell
	end
	return { label = fill(L.FLY_BOX_TIED, { n = tied, total = #ns.FLY_PATTERNS }), cells = cells }
end

-- The tally plate (TKB-R61, TKB-R64, TKB-R106).

--- What the brass tally plate shows (TKB-R106).
---@class TackleTallyView
---@field counts string     -- "{n} Notices, {m} Expeditions"
---@field latest string?    -- the latest title's name; nil before any

--- The latest title earned (TKB-R106): the one on the highest board day in the projection's `titles`, a tie going to
--- the one later in the Titles table, as one Cast grants its titles in that order (TKB-R60: tally, Campfire, Fly
--- Box). Only `titles` counts: a title shown only through the celebrated set never is the latest (TKB-R64).
---@param titles { [string]: { day: integer, cast: string } }
---@return string? titleID
local function latestTitle(titles)
	local latest, latestDay
	for _, title in ipairs(ns.TITLES) do
		local earned = titles[title.id]
		if earned and (latestDay == nil or earned.day >= latestDay) then
			latest, latestDay = title.id, earned.day
		end
	end
	return latest
end

--- What the tally plate shows (TKB-R106): the Notices and Expeditions done for life (TKB-R61), and the latest title
--- earned, by name (TKB-R130).
---@param state TackleBoardState
---@return TackleTallyView
function ns.TallyView(state)
	local latest = latestTitle(state.titles)
	return {
		counts = fill(ns.L.TALLY_PLATE, {
			notices = ns.Plural(state.tally.notices, "NOTICES"),
			expeditions = ns.Plural(state.tally.expeditions, "EXPEDITIONS"),
		}),
		latest = latest and titleName(latest),
	}
end
