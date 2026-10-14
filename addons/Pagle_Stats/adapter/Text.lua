if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' words on the client (STA-R44, STA-R59): logic/Text.lua over the client's thousands separators, local clock,
-- item and area names, Core's Angler and the game's quality names and colours. Each is read when a word is written:
-- ITEM_QUALITY_COLORS in particular is a new table whenever the player's colour overrides change.

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
		return date(format, time)
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
