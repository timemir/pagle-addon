local addonName = ...
---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's login sequence (LOG-R1). Each step is another Core file's function, called here in its place, so the order
-- lives in one file rather than in the order separate frames happen to receive an event. Nothing here depends on the
-- daily or weekly reset (CORE-R84). Its own owner, so no other Core file's registration replaces these.
local OWNER = "Pagle login"

--- The Catch log's length at load, before anything is appended this session (LOG-R1). Every entry after it is
--- "live" to a projection (LOG-R74).
---@type integer?
ns.loginSeq = nil

-- Step 1, Core's ADDON_LOADED. All of it is done before any Module's OnInitialize runs: a Module's TOC depends on
-- Pagle, so its files load after this (CORE-R10).
Pagle.RegisterEvent(OWNER, "ADDON_LOADED", function(_, loadedName)
	if loadedName ~= addonName then
		return
	end
	Pagle.UnregisterEvent(OWNER, "ADDON_LOADED")
	ns.OpenSavedVariables() -- checks PagleLog's format (LOG-R18)
	ns.loginSeq = #ns.catchLog.data.entries
	ns.Migrate(ns.db, ns.PAGLEDB_MIGRATIONS)
	ns.BuildCatalogue()
	ns.angler = ns.NewAngler(ns.catchLog)
end)

-- Step 2. PLAYER_LOGIN comes after every addon's ADDON_LOADED, so every enabled Module has run its OnInitialize
-- (CORE-R19).
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	ns.SeeCharacter() -- LOG-R25
	ns.BuildAreaIndex() -- LOG-R23
	ns.Fire("ModulesChanged") -- CORE-R19
end)

-- Steps 3 and 4, at the first PLAYER_ENTERING_WORLD after a login or reload only, never on a later loading screen.
-- Step 3, starting the projections, comes in M2 (LOG-R71, LOG-R72).
Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_ENTERING_WORLD")
	ns.LogBuild() -- LOG-R36
	ns.ReadSkill() -- LOG-R31
end)
