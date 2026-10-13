---@meta _
-- The general slash command registry, as far as Core uses it (CORE-R60), which Ketho's vscode-wow-api annotations
-- (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never loaded by the game, and
-- excluded from luacheck. Source: Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommandsRegistry.lua.

--- Each command's handler by its key; `SLASH_<KEY>1` (and 2, …) name the command. The handler gets the text after
--- the command.
---@type table<string, fun(msg: string, editBox: table?)>
SlashCmdList = {}
