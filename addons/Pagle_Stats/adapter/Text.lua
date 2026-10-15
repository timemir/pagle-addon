if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' words on the client (STA-R44, STA-R59): logic/Text.lua over the client's thousands separators, local clock,
-- item and area names, Core's Angler and the game's quality names and colours. Each is read when a word is written:
-- ITEM_QUALITY_COLORS in particular is a new table whenever the player's colour overrides change. Then the one item
-- loader every view asks the client through, and the next-frame redraw its loads queue.

-- The game's quality names (GlobalStrings), by quality.
---@param quality integer
---@return string?
local function qualityName(quality)
	local names = {
		[0] = ITEM_QUALITY0_DESC,
		ITEM_QUALITY1_DESC,
		ITEM_QUALITY2_DESC,
		ITEM_QUALITY3_DESC,
		ITEM_QUALITY4_DESC,
		ITEM_QUALITY5_DESC,
		ITEM_QUALITY6_DESC,
		ITEM_QUALITY7_DESC,
	}
	return names[quality]
end

ns.WireText({
	BreakUpLargeNumbers = function(n)
		return BreakUpLargeNumbers(n)
	end,
	Date = function(format, time)
		return (date(format, time)) --[[@as string]]
	end,
	ServerTime = function()
		return GetServerTime()
	end,
	ItemName = function(itemID)
		return C_Item.GetItemNameByID(itemID)
	end,
	ItemIcon = function(itemID)
		return C_Item.GetItemIconByID(itemID)
	end,
	AreaName = function(areaID)
		return (C_Map.GetAreaInfo(areaID))
	end,
	Characters = function()
		return Pagle.GetAngler().characters
	end,
	QualityName = qualityName,
	QualityColor = function(quality)
		return ITEM_QUALITY_COLORS[quality]
	end,
})

--- `fn` run on the next frame, once however many times the returned function is called in this one (STA-R73: at
--- most one redraw per frame).
---@param fn fun()
---@return fun()
function ns.OncePerFrame(fn)
	local queued = false
	return function()
		if queued then
			return
		end
		queued = true
		C_Timer.After(0, function()
			queued = false
			fn()
		end)
	end
end

--- An item loader for one view (STA-R59, STA-R73): the returned `request(itemID)` asks the client for an item
--- ns.Item reports not loaded (C_Item.RequestLoadItemDataByID), once while it is on its way. When it loads
--- (ITEM_DATA_LOAD_RESULT, registered under `owner` at the first request, CORE-R23), `onLoaded(itemID)` runs; a load
--- that fails runs nothing, and the item is asked for again at its next request.
---@param owner string
---@param onLoaded fun(itemID: integer)
---@return fun(itemID: integer) request
function ns.NewItemLoader(owner, onLoaded)
	local asked, listening = {}, false
	return function(itemID)
		if asked[itemID] then
			return
		end
		asked[itemID] = true
		if not listening then
			listening = true
			Pagle.RegisterEvent(owner, "ITEM_DATA_LOAD_RESULT", function(_, loadedID, success)
				if asked[loadedID] then
					asked[loadedID] = nil
					if success ~= false then
						onLoaded(loadedID)
					end
				end
			end)
		end
		C_Item.RequestLoadItemDataByID(itemID)
	end
end
