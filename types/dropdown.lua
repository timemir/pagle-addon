---@meta _
-- DropdownButtonMixin's menu methods, as far as Core's slot dropdowns call them (SET-R51), which Ketho's
-- vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack for DropdownButton. Declarations for the types
-- stage only: never loaded by the game, and excluded from luacheck. Source: Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_Menu/DropdownButton.lua.

---@class DropdownButtonMixin
local DropdownButtonMixin = {}

--- Keeps `generator` and builds the menu from it now; the button then shows its selected choice. The menu is built
--- again from it each time it opens.
---@param generator fun(owner: DropdownButton, rootDescription: RootMenuDescriptionProxy)
function DropdownButtonMixin:SetupMenu(generator) end

--- Builds the menu again from its generator, so the button's text shows the choice selected now.
function DropdownButtonMixin:GenerateMenu() end
