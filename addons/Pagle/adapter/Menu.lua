---@class PagleNS
local ns = select(2, ...)

-- Core's Addon Compartment entry, "Pagle", and its menu (CORE-R50, CORE-R52). The entry comes from the TOC:
-- `## AddonCompartmentFunc` names Pagle_OnAddonCompartmentClick, and the compartment shows the TOC's title.

---@type fun()? opens the menu, once Core is running
local open

--- The compartment calls this when the player clicks Pagle (Pagle.toc's AddonCompartmentFunc). Off Forever Core
--- never started (CORE-R4), so it does nothing.
function Pagle_OnAddonCompartmentClick()
	if open then
		open()
	end
end

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The last entry. While restricted Pagle.OpenSettings prints CORE-R33's line instead (SET-R75).
local SETTINGS = ns.SettingsMenuEntry(function()
	Pagle.OpenSettings()
end)

-- Fills the context menu, reading each label now (CORE-R52). It opens while restricted too (CORE-R33).
---@param root table the menu's root description
local function generate(_, root)
	for _, entry in ipairs(ns.CompartmentMenu(ns.Modules:Modules(), SETTINGS, securecallfunction)) do
		root:CreateButton(entry.label, function()
			securecallfunction(entry.onClick)
		end)
	end
end

-- The compartment closes its own menu once the click returns, which would close a menu opened during it, so Core's
-- opens on the next frame, at the cursor.
open = function()
	C_Timer.After(0, function()
		MenuUtil.CreateContextMenu(nil, generate)
	end)
end
