if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The next-action button (QOL-R70–R74): when it shows, its icon and label, its hotkey text, its tooltip and its
-- saved place. Pure logic, everything passed in (CORE-R7); adapter/NextActionButton.lua draws it.

--- The button's size in pixels, and how far above the bottom centre of the screen it sits by default, over the main
--- action bar (qol.md › Tunables).
ns.BUTTON_SIZE = 36
ns.BUTTON_DEFAULT_Y = 230

--- What decides whether the button shows (QOL-R72).
---@class PagleQoLButtonShownInput
---@field setting boolean Show the next-action button is on (`profile.indicator.shown`)
---@field standingDown boolean QoL stands down (QOL-R82)
---@field stretch boolean a Fishing stretch is running (QOL-R61)
---@field poleInHand boolean a fishing pole is in hand (QOL-R21)
---@field gearReady boolean the gear step is ready (QOL-R43)

--- Whether the button shows (QOL-R72): the setting is on, QoL isn't standing down, and a Fishing stretch is running,
--- a pole is in hand or the gear step is ready. In combat it still shows, as *nothing* (ns.ButtonLook).
---@param input PagleQoLButtonShownInput
---@return boolean
function ns.ButtonShown(input)
	return input.setting and not input.standingDown and (input.stretch or input.poleInHand or input.gearReady)
end

--- The icons the button can show, as the game reads them now (QOL-R71). The set's and the item's are read only for
--- the action that shows them.
---@class PagleQoLButtonIcons
---@field fishing integer? the Fishing spell's icon (`C_Spell.GetSpellTexture(7620)`)
---@field set integer? the fishing set's icon, for equip
---@field item integer? the lure's item icon, for a lure

--- What the button shows (QOL-R71).
---@class PagleQoLButtonLook
---@field icon integer?
---@field label string? the one-word label; nil for nothing
---@field desaturated boolean

--- The button's icon and label for the next action (QOL-R71): the Fishing icon with "Cast" or "Reel", the fishing
--- set's icon with "Gear", the lure's item icon with "Lure". For *nothing*, the last icon shown (the Fishing icon if
--- none was yet), desaturated, with no label. A set or item icon the game hasn't given falls back to the Fishing icon.
---@param action PagleQoLAction
---@param icons PagleQoLButtonIcons
---@param last integer? the icon the button showed last
---@return PagleQoLButtonLook
function ns.ButtonLook(action, icons, last)
	local L = ns.L
	if action == "cast" then
		return { icon = icons.fishing, label = L.BUTTON_CAST, desaturated = false }
	elseif action == "reel" then
		return { icon = icons.fishing, label = L.BUTTON_REEL, desaturated = false }
	elseif action == "gear" then
		return { icon = icons.set or icons.fishing, label = L.BUTTON_GEAR, desaturated = false }
	elseif action == "lure" then
		return { icon = icons.item or icons.fishing, label = L.BUTTON_LURE, desaturated = false }
	end
	return { icon = last or icons.fishing, desaturated = true }
end

--- The button's hotkey text (QOL-R70): the Fishing key's first bound key in the short form action bars use, or none
--- under Input *Double-click* (where the key isn't armed, QOL-R12) or with no key bound (QOL-R11).
---@param input PagleQoLInput
---@param keys string[] the Fishing key's bound keys, as `GetBindingKey` returns them
---@param textOf fun(key: string): string? `GetBindingText(key, true)`
---@return string?
function ns.ButtonHotkey(input, keys, textOf)
	if not ns.InputArmsKey(input) or not keys[1] then
		return nil
	end
	return textOf(keys[1])
end

--- The button's tooltip (QOL-R74): "Cast", "Reel in", "Put on {set name}", "Apply {lure name}" or "Nothing to do".
--- Nil while the name it needs isn't known, so the tooltip waits for the item to load.
---@param action PagleQoLAction
---@param name string? the fishing set's name for equip, the lure's for a lure
---@return string?
function ns.ButtonTooltip(action, name)
	local L = ns.L
	if action == "cast" then
		return L.BUTTON_TOOLTIP_CAST
	elseif action == "reel" then
		return L.BUTTON_TOOLTIP_REEL
	elseif action == "gear" then
		return name and L.BUTTON_TOOLTIP_GEAR:format(name)
	elseif action == "lure" then
		return name and L.BUTTON_TOOLTIP_LURE:format(name)
	end
	return L.BUTTON_TOOLTIP_NOTHING
end

--- The button's place as `PagleQoLDB.profile.indicator.point` keeps it (qol.md › Data): an anchor on UIParent.
---@class PagleQoLButtonPoint
---@field point string
---@field relativeTo "UIParent"
---@field relativePoint string
---@field x number
---@field y number

--- The point Shift-drag leaves the button at, to save (QOL-R73), as `GetPoint` reads it once the drag stops. It is
--- always kept relative to UIParent.
---@param point string
---@param relativePoint string
---@param x number
---@param y number
---@return PagleQoLButtonPoint
function ns.SavedButtonPoint(point, relativePoint, x, y)
	return { point = point, relativeTo = "UIParent", relativePoint = relativePoint, x = x, y = y }
end

--- Where the button goes (QOL-R73): the saved point, or the default, bottom centre BUTTON_DEFAULT_Y px up, with none saved or one it can't read. A fresh table each time.
---@param saved any `PagleQoLDB.profile.indicator.point`
---@return PagleQoLButtonPoint
function ns.ButtonPoint(saved)
	local readable = type(saved) == "table"
		and type(saved.point) == "string"
		and type(saved.relativePoint) == "string"
		and type(saved.x) == "number"
		and type(saved.y) == "number"
	if readable then
		return ns.SavedButtonPoint(saved.point, saved.relativePoint, saved.x, saved.y)
	end
	return ns.SavedButtonPoint("BOTTOM", "BOTTOM", 0, ns.BUTTON_DEFAULT_Y)
end
