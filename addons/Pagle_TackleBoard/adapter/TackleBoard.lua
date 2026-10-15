if not Pagle then
	return
end

local addonName = ...
---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's AceAddon (TKB-R1). Core's libraries come through LibStub; the Tackle Board embeds none (CORE-R6).
ns.TackleBoard = LibStub("AceAddon-3.0"):NewAddon(addonName)

--- AceAddon calls it once, at the Tackle Board's ADDON_LOADED, after Core's (CORE-R10).
function ns.TackleBoard.OnInitialize()
	--- The Tackle Board's Module handle: the calls that act for it (CORE-R12). Nil while it is inert.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef())
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end
	-- Its tracker frame slot and goods (TKB-R125, SHOP-R21).
	ns.RegisterGoods(ns.Module)

	-- Account-wide, one shared profile, with the defaults in tackle-board.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleTackleBoardDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)
	-- Its section on the Trackers page (SET-R43), before ModulesChanged (CORE-R42).
	ns.AddSettings(ns.Module)

	--- The Tackle Board's one projection (TKB-R81): Core catches it up or rebuilds it after login and hands it each new
	--- entry (LOG-R71–R73). ns.State, ns.IsUpdating and ns.IsStarted follow it from here on.
	ns.projection = ns.Module:NewProjection(ns.ProjectionDef(ns.db.global, Pagle.SESSION_RULES_VERSION))
	-- Its tracker, docked third (TKB-R120, CORE-R70).
	ns.StartTracker(ns.Module)
end

--- Whether the board is known to be started (TKB-R6, logic/Seams.lua): started now, or, while the projection updates,
--- in the projection stored in PagleTackleBoardDB, which a rebuild leaves in place until its done (LOG-R72).
---@return boolean
function ns.KnownStarted()
	if ns.IsStarted() then
		return true
	end
	if not ns.IsUpdating() or ns.db == nil then
		return false
	end
	local stored = ns.db.global.board and ns.db.global.board.projection
	return type(stored) == "table" and stored.started ~= nil
end
