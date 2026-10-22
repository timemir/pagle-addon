---@meta _
-- The globals the Companion's two data addons set (core/anglers-in-game.md, pagle-backend IGV Contracts › The addon
-- folders): Pagle_Following's data file, which loads after Pagle, sets PagleFollowingData before PLAYER_LOGIN;
-- Pagle_Anglers', load-on-demand, sets PagleAnglersData when Core loads it (VIEW-R3). Pagle never defines or writes
-- either, and its zip never holds the folders (VIEW-R4); Core reads each once (adapter/AnglersInGame.lua).
-- Declarations for the types stage only.

--- `v`, `generatedAt`, `count`, `anglers` and `ok`, as the Companion wrote them; nil with no Pagle_Following loaded.
--- Core reads it absent unless IGV-R44's conditions all pass (VIEW-R1).
---@type table?
PagleFollowingData = nil

--- `v`, `generatedAt`, `count`, `blocks` and `ok`, as the Companion wrote them; nil until Core loads Pagle_Anglers.
--- Core reads it absent unless IGV-R44's conditions all pass (VIEW-R1).
---@type table?
PagleAnglersData = nil
