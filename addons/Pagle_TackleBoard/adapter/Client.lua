if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The client and Core as logic/ reads them (logic/Seams.lua): ns.api, the one table of the client's calls and Core
-- that logic/ reads, and ns.random, the draws. Both are set here at file load and read through ns at call time, so a
-- spec that replaces a call (spec/Pagle_TackleBoard/support.lua) reaches every reader. An item a name asks for that
-- the client hasn't cached is requested, and its GET_ITEM_INFO_RECEIVED asks every view to redraw
-- (`ns.Redraw("names")`) on the next frame, once however many arrive in it (TKB-R36).

-- The owner of the GET_ITEM_INFO_RECEIVED registration.
local OWNER = "Pagle_TackleBoard names"

local listening, queued = false, false

-- An item a name asked for has arrived (TKB-R36): one "names" redraw on the next frame, however many arrive in it.
---@param itemID integer
---@param success boolean?
local function itemArrived(_, itemID, success)
	if ns.ItemArrived(itemID, success) and not queued then
		queued = true
		C_Timer.After(0, function()
			queued = false
			ns.Redraw("names")
		end)
	end
end

--- The client's calls and Core, as logic/ reads them (logic/Seams.lua › TackleClientAPI).
---@type TackleClientAPI
ns.api = {
	-- Board days (TKB-R10, TKB-R11, TKB-R13): each the client's own, nil where the client lacks it, so the days'
	-- rules fall back on their own (TKB-R11).
	GetServerTime = GetServerTime,
	C_DateAndTime = C_DateAndTime,
	GetGameTime = GetGameTime,
	GetCurrentRegion = GetCurrentRegion,
	-- The realm clock is secret while the client says so (LOG-R49, CORE-R31): ns.RealmMinute reads it as missing.
	issecretvalue = issecretvalue,
	AreaName = function(areaID)
		return (C_Map.GetAreaInfo(areaID))
	end,
	MapName = function(uiMapID)
		local info = C_Map.GetMapInfo(uiMapID)
		return info and info.name
	end,
	ItemName = function(itemID)
		return C_Item.GetItemNameByID(itemID)
	end,
	-- Registered on the first item asked for: only a drawn view asks, so an inert board never listens (CORE-R13).
	RequestItem = function(itemID)
		if not listening then
			listening = true
			Pagle.RegisterEvent(OWNER, "GET_ITEM_INFO_RECEIVED", itemArrived)
		end
		C_Item.RequestLoadItemDataByID(itemID)
	end,
	-- The client's number format, read at each call (TKB-R84: "written up from 2,340 Casts").
	FormatNumber = function(n)
		return BreakUpLargeNumbers(n)
	end,
	-- Core, through its API only (ADR 0001).
	pagle = Pagle,
}

--- The random source generation draws from (TKB-R30–R34; logic/Seams.lua).
ns.random = math.random
