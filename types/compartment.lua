---@meta _
-- The minimap's Addon Compartment, as far as Core registers its entry (CORE-R50, CORE-R51), which Ketho's
-- vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never
-- loaded by the game, and excluded from luacheck. Source: Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_Minimap/Mainline/
-- AddonCompartment.xml and AddonCompartment.lua.

--- An entry the compartment lists: its menu shows `text` (read each time it opens) and `icon`, and a click calls
--- `func`. The mouse going over its row and off it calls `funcOnEnter` and `funcOnLeave` with the row and its element
--- description (the menu's `button:SetOnEnter(addonData.funcOnEnter)`; Blizzard_Menu/Menu.lua's
--- MenuElementDescriptionProxyMixin:HandleOnEnter calls `self.onEnter(frame, self)`).
---@class AddonCompartmentEntry
---@field text string
---@field icon? string|integer
---@field func fun(data: any, menuInputData: { buttonName: string }, menu: table)
---@field funcOnEnter? fun(row: table, description: table)
---@field funcOnLeave? fun(row: table, description: table)

---@class AddonCompartmentFrame
AddonCompartmentFrame = {}

--- Adds an entry to the compartment; it keeps the table.
---@param addonData AddonCompartmentEntry
function AddonCompartmentFrame:RegisterAddon(addonData) end
