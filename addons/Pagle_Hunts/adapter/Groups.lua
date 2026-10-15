if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Grouping at runtime (HNT-R40–R44, HNT-R80–R82, HNT-R193, HNT-R195): when to regroup, the timers and events that
-- say so, combat, pins and the filter setting. The rules are logic/Groups.lua's. Hunts registers no secure frames
-- and changes no bindings here (HNT-R193).
--
--   ns.groups                     The groups views draw (HuntsGroups): :Rows(filter?), :Row(huntID), :IsPaused(),
--                                 :Time(), :Grouping(). Empty before the first grouping.
--   ns.ViewNow()                  The time views draw at: now, or the grouping's while it is paused (HNT-R43).
--   ns.OnRegroup(fn)              fn(previous, current) after every regroup, before its redraw; previous is nil at
--                                 the first. Both are HuntsGroupings (window moments, HNT-R88).
--   ns.SetPinned(huntID, on)      Pins or unpins a current Hunt (HNT-R80, HNT-R81); false when refused.
--   ns.IsPinned(huntID)
--   ns.SetShowCompleted(on)       Saves the board's "show completed" filter (HNT-R82).
--   ns.SetViewShown(view, shown)  The board ("board") and the tracker ("tracker") say when they show and hide; while
--                                 either is shown the groups refresh every 60 s (HNT-R42).
--   ns.HoldSampleGrouping()       The dev tour (adapter/Tour.lua, CORE-R65): groups the Hunt list in ns.hunts now and
--   ns.EndSampleGrouping()        keeps that grouping, holding every regroup, until EndSampleGrouping puts back the
--                                 grouping it replaced, or regroups if one was asked for meanwhile.
--
-- Each of these, a regroup included, ends with ns.Redraw("groups").

local OWNER = "Pagle_Hunts groups"

--- The groups the board and the tracker draw (HNT-R40–R44).
ns.groups = ns.NewGroups({
	pins = function()
		return ns.db.profile.pins
	end,
	showCompleted = function()
		return ns.db.profile.showCompleted
	end,
	state = function()
		return ns.State()
	end,
	updating = function()
		return ns.IsUpdating()
	end,
})

local regrouped = {} -- ns.OnRegroup's listeners, in order
local shown = {} -- the views shown now, by name
local timers = {} -- the one-shot timers ahead: edge, list and refresh (HNT-R42)

--- The time every view draws at (the timeline, the clock, the entry, a set's page and the tracker): now, or while the
--- grouping is paused the grouping's time, so they freeze with it (HNT-R43). Between regroups a grouping's windows
--- stand (it regroups at every edge, HNT-R42), so now's countdowns and ruler read right from it however long ago it
--- was made.
---@return integer
function ns.ViewNow()
	local grouped = ns.groups:Time()
	if grouped and ns.groups:IsPaused() then
		return grouped
	end
	return GetServerTime()
end

--- Subscribes to regroups: `fn(previous, current)` after each one, `previous` nil at the first (HNT-R42, HNT-R88).
---@param fn fun(previous: HuntsGrouping?, current: HuntsGrouping)
function ns.OnRegroup(fn)
	regrouped[#regrouped + 1] = fn
end

-- Whether any view is shown, so the groups refresh (HNT-R42).
local function anyShown()
	return next(shown) ~= nil
end

-- A timer that runs `fn` once, `seconds` from now, unless cancelled first (a C_Timer ticker that cancels itself).
---@param seconds number
---@param fn fun()
---@return table ticker
local function once(seconds, fn)
	return C_Timer.NewTicker(seconds, function(ticker)
		ticker:Cancel()
		fn()
	end)
end

-- Cancels the timer under `name`, if any.
---@param name string
local function cancel(name)
	if timers[name] then
		timers[name]:Cancel()
		timers[name] = nil
	end
end

-- Removes the pins on Hunts that aren't current, or aren't in the list (HNT-R81, HNT-R3).
---@param now integer
local function dropStalePins(now)
	local pins = ns.db.profile.pins
	for _, huntID in ipairs(ns.StalePins(pins, ns.hunts, now)) do
		pins[huntID] = nil
	end
end

local regroup -- defined below; the timers call it

-- Cancels the timer under `name` and, with `at` given, sets it to regroup at server time `at`, `now` being now.
---@param name string
---@param at integer?
---@param now integer
local function setTimer(name, at, now)
	cancel(name)
	if at then
		timers[name] = once(at - now, function()
			timers[name] = nil
			regroup()
		end)
	end
end

-- Sets the refresh timer while a view is shown, on the next turn of the refresh interval in server time (with the
-- interval's 60 s, the realm minute: the countdowns and the board's ruler move as the realm clock does, the books kit
-- v2's live timeline); cancels it otherwise (HNT-R42).
local function setRefresh()
	local now = GetServerTime()
	local interval = ns.REFRESH_INTERVAL
	setTimer("refresh", anyShown() and now + interval - now % interval or nil, now)
end

-- Cancels every timer and sets each again from `grouping` (HNT-R42): the next window edge among current Hunts, the
-- next `since` or `retired` in the list, and the refresh while a view is shown.
---@param grouping HuntsGrouping
local function setTimers(grouping)
	local now = grouping.time
	local windows = {}
	for i, row in ipairs(grouping.rows) do
		windows[i] = row.window or false
	end
	setTimer("edge", ns.NextEdge(windows, now), now)
	setTimer("list", ns.NextListChange(ns.hunts:Hunts(), now), now)
	setRefresh()
end

-- Groups every current Hunt now (HNT-R40), from its board spec's NextWindow and the live conditions.
---@param now integer
---@return HuntsGrouping
local function group(now)
	local auras = Pagle.GetConditions().auras
	local angler = Pagle.GetAngler()
	local rows, byId = {}, {}
	for order, hunt in ipairs(ns.hunts:Current(now)) do
		local spec = ns.where[hunt.id].boardSpec
		local window = spec and Pagle.NextWindow(spec, now) or nil
		local short, lureGetsThere = ns.ShortOfSkill(hunt, angler)
		local groupName, auraUp = ns.GroupOf(spec, window, short, auras, now)
		local row = {
			id = hunt.id,
			hunt = hunt,
			group = groupName,
			window = window,
			auraUp = auraUp,
			short = short,
			lureGetsThere = lureGetsThere,
			pinned = false,
			order = order,
		}
		rows[order], byId[hunt.id] = row, row
	end
	return { time = now, rows = rows, byId = byId }
end

local started = false -- the first grouping has run (HNT-R42)
---@type { grouping: HuntsGrouping?, paused: boolean, missed: boolean, first: boolean? }?
local held -- while the dev tour shows its sample grouping: the grouping it replaced, and whether a regroup waited

--- Regroups now (HNT-R42): drops the pins of Hunts gone (HNT-R81), groups, re-sets the timers, tells the regroup
--- listeners and redraws. While restricted it doesn't (HNT-R43): the grouping stands, paused, until
--- RestrictionChanged(false), except the first grouping, which runs anyway, paused.
---@param first boolean?
function regroup(first)
	if not started and not first then
		return
	end
	if held then
		held.missed, held.first = true, held.first or first
		return
	end
	local restricted = Pagle.IsRestricted()
	if restricted and started then
		ns.groups:SetPaused(true)
		return
	end
	started = true
	local now = GetServerTime()
	dropStalePins(now)
	local previous = ns.groups:Grouping()
	local current = group(now)
	ns.groups:Set(current, restricted)
	setTimers(current)
	for _, fn in ipairs(regrouped) do
		fn(previous, current)
	end
	ns.Redraw("groups")
end

--- Groups the Hunt list in ns.hunts now and keeps that grouping, unpaused, in place of the one shown: the dev tour's
--- sample (adapter/Tour.lua, CORE-R65). Until ns.EndSampleGrouping every regroup waits, so no timer, event or window
--- moment acts on the sample (HNT-R88); nothing is redrawn here.
function ns.HoldSampleGrouping()
	if not held then
		held = { grouping = ns.groups:Grouping(), paused = ns.groups:IsPaused(), missed = false }
	end
	ns.groups:Set(group(GetServerTime()), false)
end

--- Ends the dev tour's sample grouping: puts back the grouping it replaced, paused if it was or restriction began
--- meanwhile (HNT-R43), or regroups now if a regroup waited. Nothing is redrawn here unless it regroups.
function ns.EndSampleGrouping()
	local saved = held
	held = nil
	if not saved then
		return
	end
	ns.groups:Set(saved.grouping, saved.paused or (started and Pagle.IsRestricted()))
	if saved.missed then
		regroup(saved.first)
	end
end

--- Pins or unpins a Hunt (HNT-R80, HNT-R81): only a current Hunt, with no limit. Saved in profile.pins, then a
--- redraw moves its row (HNT-R44) and the tracker lists it (HNT-R76).
---@param huntID string
---@param on boolean
---@return boolean accepted -- false for a Hunt that isn't current: Retired, not yet out or unknown
function ns.SetPinned(huntID, on)
	local hunt = ns.hunts:Hunt(huntID)
	if not hunt or not ns.IsCurrent(hunt, GetServerTime()) then
		return false
	end
	ns.db.profile.pins[huntID] = on and true or nil
	ns.Redraw("groups")
	return true
end

--- Whether a Hunt is pinned (HNT-R80).
---@param huntID string
---@return boolean
function ns.IsPinned(huntID)
	return ns.db.profile.pins[huntID] == true
end

--- Saves the board's "show completed" filter and redraws (HNT-R82).
---@param on boolean
function ns.SetShowCompleted(on)
	ns.db.profile.showCompleted = on
	ns.Redraw("groups")
end

--- A view says it is shown or hidden: "board" or "tracker". While either is shown the groups refresh every 60 s
--- (HNT-R42), counted from now.
---@param view string
---@param isShown boolean
function ns.SetViewShown(view, isShown)
	local before = anyShown()
	shown[view] = isShown or nil
	if anyShown() ~= before then
		setRefresh()
	end
end

--- Starts grouping, from OnInitialize once Hunts is registered: drops the pins on Hunts gone since the last session
--- (HNT-R81), then waits for the first PLAYER_ENTERING_WORLD to group, and regroups on ConditionsChanged,
--- SkillChanged and RestrictionChanged(false) (HNT-R42, HNT-R43).
function ns.StartGroups()
	dropStalePins(GetServerTime())
	Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
		Pagle.UnregisterEvent(OWNER, "PLAYER_ENTERING_WORLD")
		regroup(true)
	end)
	Pagle.RegisterCallback(OWNER, "ConditionsChanged", function()
		regroup()
	end)
	Pagle.RegisterCallback(OWNER, "SkillChanged", function()
		regroup()
	end)
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
		if not started then
			return
		end
		if isRestricted then
			ns.groups:SetPaused(true)
			ns.Redraw("groups")
		else
			regroup()
		end
	end)
end
