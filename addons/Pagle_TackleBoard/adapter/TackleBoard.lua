if not Pagle then
	return
end

local addonName = ...
---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Tackle Board's AceAddon (TKB-R1). Core's libraries come through LibStub; the Tackle Board embeds none (CORE-R6).
ns.TackleBoard = LibStub("AceAddon-3.0"):NewAddon(addonName)

--- The WoW calls board days read (TKB-R10, TKB-R11, TKB-R13; logic/Seams.lua). Each is the client's own, nil where
--- the client lacks it, so the days' rules fall back on their own (TKB-R11).
---@class TackleResetAPI
ns.api = {
	GetServerTime = GetServerTime,
	C_DateAndTime = C_DateAndTime,
	GetGameTime = GetGameTime,
	GetCurrentRegion = GetCurrentRegion,
}

--- The random source generation draws from (TKB-R30–R34; logic/Seams.lua).
ns.random = math.random

--- AceAddon calls it once, at the Tackle Board's ADDON_LOADED, after Core's (CORE-R10).
function ns.TackleBoard.OnInitialize()
	--- The Tackle Board's Module handle: the calls that act for it (CORE-R12). Nil while it is inert.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef())
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end

	-- Account-wide, one shared profile, with the defaults in tackle-board.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleTackleBoardDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)

	--- The Tackle Board's one projection (TKB-R81): Core catches it up or rebuilds it after login and hands it each new
	--- entry (LOG-R71–R73). ns.State, ns.IsUpdating and ns.IsStarted follow it from here on.
	ns.projection = ns.Module:NewProjection(ns.ProjectionDef(ns.db.global, Pagle.SESSION_RULES_VERSION))
end
