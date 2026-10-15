if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's words on the client (TKB-R36, TKB-R105, TKB-R121): logic/Words.lua over the client's maps, item cache
-- and realm clock and Core's catalogue and conditions, each read when a view asks. An item the client hasn't cached is
-- asked for, and its GET_ITEM_INFO_RECEIVED asks every view to redraw (`ns.Redraw("names")`) on the next frame, once
-- however many arrive in it.

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

--- The reads the board's words take (logic/Words.lua).
---@type TackleWordsReads
ns.reads = {
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
	-- The realm clock through ns.api, read at each call (specs replace ns.api); nil while it is secret (LOG-R49,
	-- CORE-R31) or the client lacks it.
	RealmMinute = function()
		local getGameTime = ns.api.GetGameTime
		if not getGameTime then
			return nil
		end
		local hour, minute = getGameTime()
		if hour == nil or minute == nil or issecretvalue(hour) or issecretvalue(minute) then
			return nil
		end
		return hour * 60 + minute
	end,
	-- The client's number format, read at each call (TKB-R84: "written up from 2,340 Casts").
	FormatNumber = function(n)
		return BreakUpLargeNumbers(n)
	end,
	pagle = Pagle,
}
