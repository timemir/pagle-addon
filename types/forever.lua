---@meta _
-- Forever-only client globals that Ketho's vscode-wow-api annotations (WOW_API_COMMIT, scripts/tools.env) lack.
-- Declarations for the types stage only: never loaded by the game, and excluded from luacheck.

-- The Forever client's project ID, which WOW_PROJECT_ID equals there (CORE-R4).
-- Ketho/BlizzardInterfaceResources README.md on branch forever at BIR_COMMIT: "WOW_PROJECT_ID => WOW_PROJECT_CAMELOT (18)".
---@type integer
WOW_PROJECT_CAMELOT = 18
