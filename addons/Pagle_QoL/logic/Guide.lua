if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- QoL's two Field guide steps (core/onboarding.md › The steps): what Casting (ONB-R32, ONB-R100) and Fishing clothes
-- (ONB-R33) show, as pure logic, everything passed in (CORE-R7). adapter/Guide.lua registers and draws them.

--- Where QoL's steps sit in the guide (ONB-R21): after Core's What's in the box (20), before its Moments (50).
ns.GUIDE_CASTING_ORDER = 30
ns.GUIDE_CLOTHES_ORDER = 40

--- One Input card on the Casting step (ONB-R32).
---@class PagleQoLInputCard
---@field input PagleQoLInput
---@field title string
---@field line string
---@field tag string?

--- The Casting step's three Input cards, in order (ONB-R32): *Fishing key*, *Double right-click* and *Both*, which
--- carries the pencilled tag "the usual" (QOL-R12's default).
---@return PagleQoLInputCard[]
function ns.InputCards()
	local L = ns.L
	return {
		{ input = "key", title = L.GUIDE_CARD_KEY, line = L.GUIDE_CARD_KEY_LINE },
		{ input = "click", title = L.GUIDE_CARD_CLICK, line = L.GUIDE_CARD_CLICK_LINE },
		{ input = "both", title = L.GUIDE_CARD_BOTH, line = L.GUIDE_CARD_BOTH_LINE, tag = L.GUIDE_CARD_BOTH_TAG },
	}
end

--- Whether the Casting step's Fishing key field is greyed (ONB-R32, ONB-R100): under Double right-click, where the key
--- isn't armed (QOL-R12), as the Fishing page greys its row, and while QoL stands down (QOL-R82).
---@param input PagleQoLInput
---@param standingDown boolean
---@return boolean
function ns.FishingKeyFieldGreyed(input, standingDown)
	return standingDown or not ns.InputArmsKey(input)
end

--- The Casting step's resting line while QoL stands down (ONB-R100), naming the other fishing-key addons by title,
--- joined by ", "; nil while it doesn't.
---@param titles string[] the titles QoL stands down for, empty while it doesn't
---@return string?
function ns.RestingLine(titles)
	if #titles == 0 then
		return nil
	end
	return ns.L.GUIDE_RESTING:format(table.concat(titles, ", "))
end

--- One press of the next-action sequence the Casting step draws (ONB-R32): its action, which the button's look names
--- (QOL-R71), and its caption.
---@class PagleQoLGuidePress
---@field action PagleQoLAction
---@field caption string

--- The next-action sequence on the Casting step, Gear » Lure » Cast » Reel (ONB-R32).
---@return PagleQoLGuidePress[]
function ns.GuideSequence()
	local L = ns.L
	return {
		{ action = "gear", caption = L.GUIDE_CASTING_GEAR },
		{ action = "lure", caption = L.GUIDE_CASTING_LURE },
		{ action = "cast", caption = L.GUIDE_CASTING_CAST },
		{ action = "reel", caption = L.GUIDE_CASTING_REEL },
	}
end

--- The inventory slots a set card on the Fishing clothes step shows, left to right (ONB-R33): the head, chest, hands
--- and main hand, the pole's.
ns.GUIDE_SET_SLOTS = { 1, 5, 10, 16 }

--- What one slot of a set card shows: an icon (a file ID, or a texture path for a drawn placeholder), or nothing.
---@class PagleQoLGuideSlot
---@field icon (integer|string)?
---@field placeholder boolean drawn, not the player's: the set doesn't exist

--- A set card's slots (ONB-R33): the set's real items when it exists (`items`, its `C_EquipmentSet.GetItemIDs`), an
--- empty slot showing nothing; else the drawn placeholders.
---@param items table<integer, integer>? the set's items by inventory slot; nil while it doesn't exist
---@param iconOf fun(itemID: integer): integer? an item's icon, as `C_Item.GetItemIconByID` reads it
---@param placeholders string[] the drawn icons, one per slot of ns.GUIDE_SET_SLOTS
---@return PagleQoLGuideSlot[]
function ns.SetCardSlots(items, iconOf, placeholders)
	local slots = {}
	for i, slot in ipairs(ns.GUIDE_SET_SLOTS) do
		if items then
			local itemID = items[slot]
			slots[i] = { icon = itemID and iconOf(itemID) or nil, placeholder = false }
		else
			slots[i] = { icon = placeholders[i], placeholder = true }
		end
	end
	return slots
end

--- The scale that fits something `width` wide into `room`: 1 when it fits, else smaller.
---@param width number
---@param room number
---@return number
function ns.FitScale(width, room)
	if width <= room or width <= 0 then
		return 1
	end
	return room / width
end
