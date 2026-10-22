if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's parts of onboarding (core/onboarding.md): what its Field guide step shows (ONB-R37). Pure logic
-- (CORE-R7): the client's names come through ns.api, read through ns at call time; adapter/GuidePage.lua draws it.

--- The step's place in the guide (ONB-R21, ONB-R37): after the Ledger's (60), before Core's Off you go (90); its
--- skip link "Not now" goes on to the next step, not to the last.
ns.GUIDE_STEP = { id = "board", order = 70, skipTo = "next" }

--- What Start my board on the guide's page shows (ONB-R37, TKB-R5): "Start my board" until the board is started,
--- usable unless the projection is updating; then "Your board is up", never usable. A board known to be started while
--- it rebuilds (ns.KnownStarted, TKB-R108) is up already.
---@param knownStarted boolean
---@param updating boolean
---@return { label: string, usable: boolean, up: boolean }
function ns.GuideStartShows(knownStarted, updating)
	if knownStarted then
		return { label = ns.L.BOARD_IS_UP, usable = false, up = true }
	end
	return { label = ns.L.START_MY_BOARD, usable = not updating, up = false }
end

--- What a goal's paper draws of the goal itself (adapter/Pins.lua's ns.DrawGoalSlip): its kind and pay, and its ID,
--- which a sample has none of, so nothing acts on it. A TackleGoal is one.
---@class TackleSlipGoal
---@field id string?
---@field kind TackleGoalKind
---@field pay integer

--- One sample Notice on the guide's page: the goal its paper draws and what the paper shows (a TacklePinView,
--- logic/Pins.lua).
---@class TackleGuideNotice
---@field goal TackleSlipGoal
---@field view TacklePinView

--- What the guide's sample strip shows (ONB-R37; board 8): two Notices, a Campfire of 13 days and a Fly Box part
--- filled, in the board's own words (logic/Words.lua, logic/Ledge.lua), standing still.
---@class TackleGuideSample
---@field notices TackleGuideNotice[]
---@field fire TackleCampfireView
---@field fireDays integer
---@field flies string    -- the Fly Box's count, "26 of 30 tied"

-- The sample's goals (board 8): a Haul of 30 in Stranglethorn Vale (its area ID, named by the client), 12 caught and
-- workable here, and a Collector, one of two; and the Campfire and Fly Box beside them.
local SAMPLE_ZONE, SAMPLE_FIRE, SAMPLE_TIED = 33, { count = 13, kindling = 2, longest = 13 }, 26

-- A sample Notice's paper: `goal` (a TackleGoalDef with its pay) at `progress` of its need.
---@param goal table
---@param progress integer
---@param here boolean
---@return TackleGuideNotice
local function sampleNotice(goal, progress, here)
	local L = ns.L
	local kicker, text = ns.KindLabel(goal.kind), ns.GoalText(goal)
	return {
		goal = { kind = goal.kind, pay = goal.pay },
		view = {
			kicker = kicker,
			text = text,
			chip = ns.Fill(L.OVERFLOW_CHIP, { kind = kicker, text = text }),
			progress = ns.Fill(
				ns.IsDayBound(goal) and L.PROGRESS_TODAY or L.PROGRESS,
				{ n = progress, need = goal.need }
			),
			fill = progress / goal.need,
			where = ns.GoalWhere(goal),
			here = here,
			pay = ns.Plural(goal.pay, "PAYS"),
			stamp = false,
			takeDown = "enabled",
			hover = {},
		},
	}
end

--- The guide's sample strip (ONB-R37), in the board's own words now.
---@return TackleGuideSample
function ns.GuideSample()
	local pay = ns.NOTICE_PAY
	return {
		notices = {
			sampleNotice({ type = "n", kind = "haul", target = SAMPLE_ZONE, need = 30, pay = pay[2] }, 12, true),
			sampleNotice({ type = "n", kind = "collector", need = 2, pay = pay[1] }, 1, false),
		},
		fire = ns.CampfireView(SAMPLE_FIRE),
		fireDays = SAMPLE_FIRE.count,
		flies = ns.Fill(ns.L.FLY_BOX_TIED, { n = math.min(SAMPLE_TIED, #ns.FLY_PATTERNS), total = #ns.FLY_PATTERNS }),
	}
end
