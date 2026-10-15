if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The names Hunts' labels read (HNT-R53–R55): no game name ships (DATA-R3), so items, areas, auras and calendar
-- events are named at runtime. ns.names is logic/Labels.lua's HuntNameSources over the client and Core, each read
-- when a label asks; only what loads late is kept: the items asked for until they arrive, and the event names, looked
-- up once per login outside restriction (HNT-R53, HNT-R193).

-- The owner of Hunts' name registrations.
local OWNER = "Pagle_Hunts names"

local loading = {} -- itemID -> true while its Item:ContinueOnItemLoad waits
local redrawQueued = false
---@type table<integer, string>?
local eventNames -- by event ID, once the calendar has been read; nil before
local afterRestriction -- the calendar step waiting for RestrictionChanged(false)

-- A name has loaded: the views redraw on the next frame, once however many load in it (HNT-R54).
local function queueRedraw()
	if redrawQueued then
		return
	end
	redrawQueued = true
	C_Timer.After(0, function()
		redrawQueued = false
		ns.Redraw("names")
	end)
end

---@type HuntNameSources
ns.names = {
	-- An item's name, or nil until the client has it: asked for with Item:CreateFromItemID, once until it loads.
	ItemName = function(itemID)
		local name = C_Item.GetItemNameByID(itemID)
		if name == nil and not loading[itemID] then
			loading[itemID] = true
			Item:CreateFromItemID(itemID):ContinueOnItemLoad(function()
				loading[itemID] = nil
				queueRedraw()
			end)
		end
		return name
	end,
	ItemIcon = function(itemID)
		return C_Item.GetItemIconByID(itemID)
	end,
	AreaName = function(areaID)
		return (C_Map.GetAreaInfo(areaID))
	end,
	AuraName = function(spellID)
		return C_Spell.GetSpellName(spellID)
	end,
	-- nil until the calendar has been read, then the name, or false for an event it doesn't list.
	EventName = function(eventID)
		if eventNames == nil then
			return nil
		end
		return eventNames[eventID] or false
	end,
	BandName = function(band)
		local entry = Pagle.SIZE_BANDS[band]
		return entry and entry.name
	end,
	-- Read at each call: the client replaces the table when its colours change. As the board's tints: { r, g, b }.
	QualityColor = function(quality)
		local color = ITEM_QUALITY_COLORS[quality]
		return color and { color.r, color.g, color.b }
	end,
	NextWindow = function(spec, fromTime)
		return Pagle.NextWindow(spec, fromTime)
	end,
}

-- Runs `step` now, or at the next RestrictionChanged(false) while restricted: calendar reads can be secret then
-- (LOG-R46, HNT-R193).
---@param step fun()
local function outsideRestriction(step)
	if Pagle.IsRestricted() then
		afterRestriction = step
	else
		step()
	end
end

-- The calendar's month offset of the current month: calendar reads count from the month it shows, which the player
-- may have paged away from.
---@return integer
local function currentMonthOffset()
	local today = C_DateAndTime.GetCurrentCalendarTime()
	local shown = C_Calendar.GetMonthInfo(0)
	return (today.year - shown.year) * 12 + today.month - shown.month
end

-- Reads the calendar days of the current and next month for the wanted events' names (HNT-R53 step 2), keeps them
-- for the login (step 3) and redraws for names. A secret read finds nothing.
---@param wanted table<integer, true>
local function readCalendar(wanted)
	local found = {}
	local current = currentMonthOffset()
	for offset = current, current + 1 do
		local month = C_Calendar.GetMonthInfo(offset)
		for day = 1, month and month.numDays or 0 do
			local count = C_Calendar.GetNumDayEvents(offset, day)
			for index = 1, issecretvalue(count) and 0 or count do
				local event = C_Calendar.GetDayEvent(offset, day, index)
				local eventID = event and event.eventID
				if eventID and not issecretvalue(eventID) and wanted[eventID] and found[eventID] == nil then
					if not issecretvalue(event.title) then
						found[eventID] = event.title
					end
				end
			end
		end
	end
	eventNames = found
	ns.Redraw("names")
end

-- Opens the calendar for the events Hunts' specs name and reads it at its first update (HNT-R53 step 1). With no
-- event named, there is nothing to look up.
local function openCalendar()
	local wanted = ns.HuntEventIDs(ns.hunts:Hunts(), Pagle.GetWindowSpec)
	if next(wanted) == nil then
		eventNames = {}
		return
	end
	Pagle.RegisterEvent(OWNER, "CALENDAR_UPDATE_EVENT_LIST", function()
		Pagle.UnregisterEvent(OWNER, "CALENDAR_UPDATE_EVENT_LIST")
		outsideRestriction(function()
			readCalendar(wanted)
		end)
	end)
	C_Calendar.OpenCalendar()
end

--- Starts the event name lookup (HNT-R53): at the first PLAYER_ENTERING_WORLD, or at the first
--- RestrictionChanged(false) if that falls while restricted. The adapter's OnInitialize calls it once Hunts is active.
function ns.StartNames()
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
		if not isRestricted and afterRestriction then
			local step = afterRestriction
			afterRestriction = nil
			step()
		end
	end)
	Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
		Pagle.UnregisterEvent(OWNER, "PLAYER_ENTERING_WORLD")
		outsideRestriction(openCalendar)
	end)
end
