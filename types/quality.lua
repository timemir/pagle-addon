---@meta _
-- The game's item quality names and colours, as Stats' words (STA-R59) and Hunts' icon tints (HNT-R55) read them,
-- which Ketho's vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage
-- only: never loaded by the game, and excluded from luacheck.

-- Ketho/BlizzardInterfaceResources branch forever at BIR_COMMIT, Resources/GlobalStrings/enUS.lua.
---@type string
ITEM_QUALITY0_DESC = "Poor"
---@type string
ITEM_QUALITY1_DESC = "Common"
---@type string
ITEM_QUALITY2_DESC = "Uncommon"
---@type string
ITEM_QUALITY3_DESC = "Rare"
---@type string
ITEM_QUALITY4_DESC = "Epic"
---@type string
ITEM_QUALITY5_DESC = "Legendary"
---@type string
ITEM_QUALITY6_DESC = "Artifact"
---@type string
ITEM_QUALITY7_DESC = "Heirloom"

--- One quality's colour, as ColorManager fills it.
---@class ItemQualityColor
---@field r number
---@field g number
---@field b number
---@field hex string   -- "|cff" and the colour's six hex digits
---@field color table  -- the ColorMixin

-- Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
-- Interface/AddOns/Blizzard_Colors/Mainline/ColorConstants.lua ("ITEM_QUALITY_COLORS = { };") and
-- Mainline/ColorManager.lua (ColorManager.UpdateColorsForItemQuality).
---@type table<integer, ItemQualityColor>
ITEM_QUALITY_COLORS = {}
