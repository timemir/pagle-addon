---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's Addon Compartment entry and its menu (CORE-R50–R52). Core registers the entry itself at login, through
-- AddonCompartmentFrame:RegisterAddon, rather than with the TOC's AddonCompartmentFunc, whose label is the addon's
-- title and can't change: this one counts the moments Cozy mode holds ("Pagle · 3 waiting", CORE-R51). The
-- compartment reads each entry's `text` every time its menu opens, so changing the registered table's text is enough.
-- Its own owner on the event frames, so no other Core file's registration replaces it.
local OWNER = "Pagle compartment"

-- The last entry, Core's settings subcommand. While restricted Pagle.OpenSettings prints CORE-R33's line instead
-- (SET-R75).
local SETTINGS = ns.SettingsMenuEntry(ns.coreSubcommands.settings)

-- Fills the context menu, reading each label, the balance and the Field report count now (CORE-R50, CORE-R52). It
-- opens while restricted too (CORE-R33).
---@param root table the menu's root description
local function generate(_, root)
	local shop = ns.CurioShopMenuEntry(Pagle.GetBalance(), BreakUpLargeNumbers)
	-- Help chart the waters, Core's report subcommand: while restricted it prints REP-R44's line instead (CORE-R33).
	local fieldReport = ns.FieldReportMenuEntry(Pagle.GetFieldReportCount(), ns.coreSubcommands.report)
	for _, entry in ipairs(ns.CompartmentMenu(ns.Modules:Modules(), shop, fieldReport, SETTINGS, securecallfunction)) do
		local button = root:CreateButton(entry.label, function()
			securecallfunction(entry.onClick)
		end)
		if entry.disabled then
			button:SetEnabled(false)
		end
	end
end

-- The compartment closes its own menu once the click returns, which would close a menu opened during it, so Core's
-- opens on the next frame, at the cursor.
local function open()
	C_Timer.After(0, function()
		MenuUtil.CreateContextMenu(nil, generate)
	end)
end

--- The entry Core registered with the compartment, nil before login. Its text is the label (CORE-R51).
---@type AddonCompartmentEntry?
ns.compartmentEntry = nil

--- Sets the compartment entry's label from the waiting count (CORE-R51, ANN-R42). Before login there's no entry yet;
--- it starts with the count then.
function ns.UpdateCompartmentText()
	if ns.compartmentEntry then
		ns.compartmentEntry.text = ns.CompartmentText(ns.summary:Waiting())
	end
end

-- At login, once: the entry, with no icon (Pagle.toc names none), opening the menu when clicked.
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	ns.compartmentEntry = { text = ns.CompartmentText(ns.summary:Waiting()), func = open }
	AddonCompartmentFrame:RegisterAddon(ns.compartmentEntry)
end)
