if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The companion hint and its weekly Nod (HNT-R170–R172, HNT-R176): pure logic, everything passed in (CORE-R7). When
-- the hint applies and what it says on the board and the tracker, when the Nod is due, and the Nod itself.
-- adapter/Companion.lua reads the switch, Core's companion state and the saved profile, and raises.

--- The companion hint while it applies (HNT-R170): its lines on the wager strip and the hint slip, and its one
--- line on the tracker's Pagle Wagers block with no run on (HNT-R176).
---@class CompanionHint
---@field state "missing"|"notRunning"  -- the companion state it is for (PUSH-R15)
---@field lines string[]                -- the board's lines; the first is the Nod's text (HNT-R171)
---@field tracker string                -- the tracker's line: "New wagers with the Pagle companion"

--- The companion hint (HNT-R170), or nil while it doesn't apply: the switch off (HNT-R172), the companion state
--- `"checking"` or `"connected"`, or the hint dismissed (`profile.companionHint` false). Missing, its lines say what
--- the companion brings, then that a first install shows only after character select (PUSH-R90); not running, that
--- it isn't running.
---@param on boolean the companion hint switch (Tunables, ns.COMPANION_HINT_ON)
---@param state string `Pagle.GetCompanionState()` (PUSH-R15)
---@param remind boolean `profile.companionHint`: "Remind me about the Pagle companion"
---@return CompanionHint?
function ns.CompanionHint(on, state, remind)
	if not on or not remind then
		return nil
	end
	local L = ns.L
	if state == "missing" then
		return {
			state = state,
			lines = { L.HINT_MISSING, L.HINT_FIRST_INSTALL },
			tracker = L.TRACKER_HINT_MISSING,
		}
	elseif state == "notRunning" then
		return { state = state, lines = { L.HINT_NOT_RUNNING }, tracker = L.TRACKER_HINT_NOT_RUNNING }
	end
	return nil
end

--- Whether the weekly Nod is due (HNT-R171): the hint applies, and at least the Nod interval (Tunables,
--- ns.HINT_NOD_INTERVAL) has passed since the last one (`profile.lastHintNod`, 0 for never).
---@param hint CompanionHint?
---@param lastNod integer `profile.lastHintNod`, server time
---@param now integer server time
---@return boolean
function ns.HintNodDue(hint, lastNod, now)
	return hint ~= nil and now - (lastNod or 0) >= ns.HINT_NOD_INTERVAL
end

--- The weekly Nod (HNT-R86's `companionHint` row, HNT-R171): a `nod` titled "Pagle Wagers" with its text and its
--- `pastText` the hint's first line, or, while the companion is missing, a shorter line of its own (the hint's names
--- the Sonar Scope and wouldn't fit a Nod's one line), Trade_Fishing for its icon, no `cast` (an Announcement of its
--- own, ANN-R12) and no Coins. Clicking it runs `open`, which opens the board on the Pagle Wagers spread.
---@param hint CompanionHint
---@param open fun() opens the board on the Pagle Wagers spread (ns.OpenWagers)
---@return PagleMoment
function ns.HintNod(hint, open)
	local text = hint.state == "missing" and ns.L.HINT_NOD or hint.lines[1]
	return {
		rung = "nod",
		kind = "companionHint",
		title = ns.L.WAGERS_KICKER,
		text = text,
		pastText = text,
		icon = ns.TRADE_FISHING,
		onClick = open,
	}
end
