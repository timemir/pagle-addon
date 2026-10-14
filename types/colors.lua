---@meta _
-- FrameXML's item quality colours, as far as Hunts' icon tints use them (HNT-R55), which Ketho's vscode-wow-api
-- annotations (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never loaded by the
-- game, and excluded from luacheck. Source: Gethe/wow-ui-source branch forever at
-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_Colors/Mainline/
-- ColorConstants.lua and ColorManager.lua (UpdateColorsForItemQuality).

--- Each item quality's colour, by Enum.ItemQuality: `{ r, g, b, hex, color }`.
---@type table<integer, { r: number, g: number, b: number, hex: string, color: table }>
ITEM_QUALITY_COLORS = {}
