if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Journal's words on the client (LED-R126, LED-R127, LED-R161): logic/JournalText.lua over the client's item
-- cache, maps, clocks and Core's Angler and window forecasts, each read when a page asks. An item the client hasn't
-- cached is asked for, and its GET_ITEM_INFO_RECEIVED redraws the open Journal on the next frame.

-- The owner of the GET_ITEM_INFO_RECEIVED registration.
local OWNER = "Pagle_Ledger Journal names"

local listening = false

-- An item the Journal asked for has arrived (LED-R126): the open spread redraws on the next frame, once however many
-- arrive in it.
---@param itemID integer
---@param success boolean?
local function itemArrived(_, itemID, success)
	if ns.journalText:ItemArrived(itemID, success) then
		ns.journal:QueueDraw()
	end
end

--- The client's item and area names, as both the Journal's words and the moments read them (LED-R126, LED-R97).
ns.ClientNames = {
	ItemName = function(itemID)
		return C_Item.GetItemNameByID(itemID)
	end,
	AreaName = function(areaID)
		return (C_Map.GetAreaInfo(areaID))
	end,
}

--- The Journal's words, as every spread reads them (`context.text`).
ns.journalText = ns.NewJournalText({
	ItemName = ns.ClientNames.ItemName,
	-- Registered on the first item asked for: only a drawn Journal asks, so an inert Ledger never listens (CORE-R13).
	RequestItem = function(itemID)
		if not listening then
			listening = true
			Pagle.RegisterEvent(OWNER, "GET_ITEM_INFO_RECEIVED", itemArrived)
		end
		C_Item.RequestLoadItemDataByID(itemID)
	end,
	AreaName = ns.ClientNames.AreaName,
	MapName = function(uiMapID)
		local info = C_Map.GetMapInfo(uiMapID)
		return info and info.name
	end,
	Characters = function()
		return Pagle.GetAngler().characters
	end,
	ServerTime = function()
		return GetServerTime()
	end,
	-- The realm clock as a minute of day; nil while it is secret (LOG-R49), when no offset can be read.
	RealmMinute = function()
		local hour, minute = GetGameTime()
		if issecretvalue(hour) or issecretvalue(minute) then
			return nil
		end
		return hour * 60 + minute
	end,
	WindowSpec = function(windowID)
		return Pagle.GetWindowSpec(windowID)
	end,
	-- Forecast afresh at each call, never kept (LED-R127, LED-R195).
	NextWindow = function(spec, fromTime)
		return Pagle.NextWindow(spec, fromTime)
	end,
})
