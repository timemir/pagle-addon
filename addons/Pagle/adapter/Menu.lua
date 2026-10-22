---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's Addon Compartment entry and its menu (CORE-R50–R52), the menu the minimap icon opens too (CORE-R54), and
-- the tooltip both show (CORE-R55). Core registers the entry itself at login, through
-- AddonCompartmentFrame:RegisterAddon, rather than with the TOC's AddonCompartmentFunc, whose label is the addon's
-- title and can't change: this one counts the moments Cozy mode holds ("Pagle · 3 waiting", CORE-R51). The
-- compartment reads each entry's `text` every time its menu opens, so changing the registered table's text is enough.
-- Its own owner on the event frames, so no other Core file's registration replaces it.
local OWNER = "Pagle compartment"

-- Fills the context menu, reading each label, the balance and the Field report count now (CORE-R50, CORE-R52). It
-- opens while restricted too: the Curio Shop, Help chart the waters and Settings then print their CORE-R33 lines
-- (SHOP-R41, REP-R44, SET-R75).
---@param root table the menu's root description
local function generate(_, root)
	local entries =
		ns.CoreCompartmentMenu(Pagle, ns.coreSubcommands, ns.Modules:Modules(), BreakUpLargeNumbers, securecallfunction)
	for _, entry in ipairs(entries) do
		root:CreateButton(entry.label, function()
			securecallfunction(entry.onClick)
		end)
	end
end

--- Opens Pagle's menu now, at the cursor (CORE-R50, CORE-R54). `owner` is the region it belongs to, which closes it
--- by hiding: the minimap icon's button (adapter/MinimapIcon.lua), or nil for the compartment's.
---@param owner table?
function ns.OpenMenu(owner)
	MenuUtil.CreateContextMenu(owner, generate)
end

-- The compartment closes its own menu once the click returns, which would close a menu opened during it, so Core's
-- opens on the next frame, at the cursor.
local function open()
	C_Timer.After(0, function()
		ns.OpenMenu(nil)
	end)
end

--- Whether the Letter shows now (ONB-R13), for the tooltip's "A letter for you" line (CORE-R55). False until the
--- Letter exists: its file (#327) replaces this function with one that reads the onboarding state. Called each time
--- the tooltip shows.
---@return boolean
function ns.LetterShows()
	return false
end

--- Fills `tooltip` with the tooltip of Pagle's menu, read now (CORE-R55): "Pagle", then the waiting count while Cozy
--- mode holds moments and "A letter for you" while the Letter shows. `tooltip` is already owned and anchored.
---@param tooltip GameTooltip
function ns.FillMenuTooltip(tooltip)
	local lines = ns.MenuTooltipLines(ns.summary:Waiting(), ns.LetterShows())
	tooltip:SetText(lines[1])
	for i = 2, #lines do
		tooltip:AddLine(lines[i])
	end
end

--- Shows the tooltip of Pagle's menu on GameTooltip beside `owner`, as the mouse goes over the minimap icon or the
--- compartment entry's row (CORE-R55).
---@param owner table
---@param anchor TooltipAnchor
function ns.ShowMenuTooltip(owner, anchor)
	GameTooltip:SetOwner(owner, anchor)
	ns.FillMenuTooltip(GameTooltip)
	GameTooltip:Show()
end

--- Hides it as the mouse leaves `owner`, if GameTooltip is still `owner`'s.
---@param owner table
function ns.HideMenuTooltip(owner)
	if GameTooltip:IsOwned(owner) then
		GameTooltip:Hide()
	end
end

-- The compartment entry's row, as the mouse goes over it (funcOnEnter): the tooltip beside the row.
---@param row table
local function showTooltip(row)
	ns.ShowMenuTooltip(row, "ANCHOR_RIGHT")
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

-- At login, once: the entry, with no icon (Pagle.toc names none), opening the menu when clicked and showing the
-- menu's tooltip while the mouse is over it.
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	ns.compartmentEntry = {
		text = ns.CompartmentText(ns.summary:Waiting()),
		func = open,
		funcOnEnter = showTooltip,
		funcOnLeave = ns.HideMenuTooltip,
	}
	AddonCompartmentFrame:RegisterAddon(ns.compartmentEntry)
end)
