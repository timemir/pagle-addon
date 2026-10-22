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

-- #262: the clock once Core's files have loaded (this is the TOC's last). The client reads the SavedVariables between
-- this and ADDON_LOADED, so with a large PagleLog the gap is mostly that read. Kept only with dev mode on.
local filesLoaded = debugprofilestop()

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
	local addonLoaded = debugprofilestop()
	ns.OpenSavedVariables() -- checks PagleLog's format (LOG-R18)
	ns.loginSeq = #ns.catchLog.data.entries
	-- #262: with dev mode on, this login's load timings, before any projection starts.
	ns.StartLoadTimings(ns.db.global, GetServerTime(), ns.loginSeq, {
		filesLoaded = filesLoaded,
		addonLoaded = addonLoaded,
		logOpened = debugprofilestop(),
	})
	ns.Migrate(ns.db, ns.PAGLEDB_MIGRATIONS, { catchLog = ns.catchLog }) -- step 2 reads the log (ONB-R2)
	ns.OpenWallet() -- SHOP-R3
	ns.OpenActivityXP() -- AXP-R3
	ns.RegisterCoreGoods(ns.CORE_PREVIEWS) -- SHOP-R25: before any Module registers its own
	ns.BuildCatalogue()
	ns.StartFishCrests() -- VAR-R12: Core's fish crests, over the catalogue, before the variety projection refreshes them
	ns.WireFieldReport(ns.host) -- LOG-R78: Core's projection, ahead of every Module's
	ns.StartWalletProjection() -- SHOP-R11, SHOP-R34: the stored spent and purchased set, before the catch-up
	ns.StartVarietyProjection() -- VAR-R10: Core's varieties caught, which its fish crests read (VAR-R13)
	ns.angler = ns.NewAngler(ns.catchLog)
	ns.sessions:Open() -- LOG-R63
end)

-- Step 2. PLAYER_LOGIN comes after every addon's ADDON_LOADED, so every enabled Module has run its OnInitialize
-- (CORE-R19).
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	ns.MarkLoadTiming("playerLogin", debugprofilestop()) -- #262
	ns.SeeCharacter() -- LOG-R25
	ns.BuildAreaIndex() -- LOG-R23
	ns.StartConditions() -- LOG-R47: its baseline has real areas, and a Module meets a running service
	ns.Fire("ModulesChanged") -- CORE-R19
	-- PUSH-R1, PUSH-R10: PagleContentData, read once, its check from the next frame on; with no file it ends here,
	-- "missing", after ModulesChanged so each Module has met Core first.
	ns.StartPushedContent()
	-- VIEW-R1: PagleFollowingData, read once; Pagle_Following loaded after Pagle, before this.
	ns.StartAnglerViews()
	-- ONB-R1–R3: the character joins the onboarding state, after ModulesChanged, so whatever a hook shows (#325)
	-- meets Core's menu and every Module registered.
	ns.StartOnboarding()
end)

-- Steps 3 and 4, at the first PLAYER_ENTERING_WORLD after a login or reload only, never on a later loading screen.
-- The entries step 4 appends come after loginSeq, so projections get them live (LOG-R1).
Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_ENTERING_WORLD")
	ns.MarkLoadTiming("enteringWorld", debugprofilestop()) -- #262
	ns.StartProjections() -- LOG-R71, LOG-R72
	if ns.loadTimings then
		ns.projections:WhenIdle(function()
			ns.MarkLoadTiming("idle", debugprofilestop()) -- #262: every catch-up and rebuild has finished
		end)
	end
	ns.LogBuild() -- LOG-R36
	ns.ReadSkill() -- LOG-R31
end)
