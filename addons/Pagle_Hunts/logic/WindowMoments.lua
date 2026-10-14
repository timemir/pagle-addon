if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Window moments (HNT-R88): a quiet Nod when a pinned Hunt's window opens. Pure logic, everything passed in
-- (CORE-R7): the baseline one regroup records, which windows the next regroup finds opened, and the Nod for each.
-- adapter/WindowMoments.lua keeps the baseline in memory between regroups, adds the setting (SET-R32) and raises.

--- Whether each current Hunt's NextWindow result was openNow at a regroup, by Hunt ID (HNT-R88).
---@alias HuntWindowBaseline table<string, boolean>

-- Whether a NextWindow result is openNow: an always-open or aura-only window never is (LOG-R50).
---@param window Window?
---@return boolean
local function isOpen(window)
	return window ~= nil and window.openNow == true
end

--- The baseline a regroup records (HNT-R88): for every current Hunt, pinned or not, whether its NextWindow result is
--- openNow.
---@param grouping HuntsGrouping
---@return HuntWindowBaseline
function ns.WindowBaseline(grouping)
	local baseline = {}
	for _, row in ipairs(grouping.rows) do
		baseline[row.id] = isOpen(row.window)
	end
	return baseline
end

--- The rows whose window a regroup found opened (HNT-R88), in the rows' order: pinned now, openNow now, not short of
--- skill (HNT-R33), and recorded as not openNow in `baseline`, the previous regroup's. None with no baseline (the
--- first grouping after login only sets it, HNT-R190), for a Hunt it has no record of (it just became current), or
--- with the setting off (SET-R32). An aura starting or a skill change never turns a window openNow.
---@param baseline HuntWindowBaseline? the previous regroup's; nil at the first grouping
---@param rows HuntRow[] the current grouping's rows
---@param pins table<string, true> `profile.pins` (HNT-R81)
---@param on boolean the setting "Tell me when a pinned Hunt's window opens" (`profile.windowMoments`)
---@return HuntRow[]
function ns.WindowOpenings(baseline, rows, pins, on)
	local opened = {}
	if not on or not baseline then
		return opened
	end
	for _, row in ipairs(rows) do
		if pins[row.id] and not row.short and isOpen(row.window) and baseline[row.id] == false then
			opened[#opened + 1] = row
		end
	end
	return opened
end

--- What a window Nod says, as the adapter reads it for one opened row.
---@class HuntWindowNodInfo
---@field name string the Hunt's name (HNT-R1)
---@field label string its tracker label (HNT-R51)
---@field icon integer|string its icon (HNT-R55): an item ID or a texture path
---@field window Window its NextWindow result, openNow
---@field from integer the server time the regroup found it open
---@field snapshot table one live `Pagle.GetConditions()`, for the realm clock (HNT-R50)

--- The window moment (HNT-R88): a `nod` of kind "huntWindow", "{Hunt name} is open" over its tracker label, with its
--- icon, `expiresAt` at the window's `closesAt` (none when unknown), and `pastText` "{Hunt name} window opened
--- {from}–{to}" in realm clock, "–{to}" left out when `closesAt` is unknown. No `cast` (ANN-R12) and no Coins.
---@param info HuntWindowNodInfo
---@return PagleMoment
function ns.WindowNod(info)
	local L = ns.L
	local closesAt = info.window.closesAt
	local from = ns.FormatClock(ns.RealmClockAt(info.from, info.snapshot).minute)
	local pastText
	if closesAt then
		local to = ns.FormatClock(ns.RealmClockAt(closesAt, info.snapshot).minute)
		pastText = L.WINDOW_OPENED_UNTIL:format(info.name, from, to)
	else
		pastText = L.WINDOW_OPENED:format(info.name, from)
	end
	return {
		rung = "nod",
		kind = "huntWindow",
		title = L.WINDOW_OPEN:format(info.name),
		text = info.label,
		icon = info.icon,
		expiresAt = closesAt,
		pastText = pastText,
	}
end
