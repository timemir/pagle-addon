if not Pagle then
	return
end

local addonName = ...
---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' AceAddon (STA-R4). Core's libraries come through LibStub; Stats embeds none (CORE-R6).
ns.Stats = LibStub("AceAddon-3.0"):NewAddon(addonName)

--- AceAddon calls it once, at Stats' ADDON_LOADED, after Core's (CORE-R10).
function ns.Stats.OnInitialize()
	--- Stats' Module handle: the calls that act for Stats (CORE-R12). Nil while Stats is inert. The toggle is looked
	--- up at call time, so the book's ticket fills ns.ToggleBook in without touching this.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef(function()
		ns.ToggleBook()
	end))
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end
	-- Stats' tracker frame slot and its goods, right after registering (STA-R88).
	ns.RegisterGoods(ns.Module)

	-- Account-wide, one shared profile, with the defaults in stats.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleStatsDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)

	--- The places rules over Core's catalogue (STA-R10–R17): built here, where the catalogue is ready (CORE-R10).
	--- `Pagle` itself is the lookups, read at each call, so a new fingerprint drops the tables (LOG-R72). Core sets
	--- these fields at runtime, so the type checker can't see them on Pagle: hence the cast.
	ns.places = ns.NewPlaceTables(Pagle --[[@as StatsLookups]])

	--- Stats' one projection (STA-R20): Core catches it up or rebuilds it after login and hands it each new entry
	--- (LOG-R71–R73). ns.State and ns.IsUpdating follow it from here on: before its first build the state is an empty
	--- one, and it reads as updating (LOG-R74).
	ns.projection = ns.Module:NewProjection(ns.ProjectionDef(ns.db.global, ns.places, Pagle.SESSION_RULES_VERSION))

	--- Stats' section on the Trackers page (SET-R42), before ModulesChanged (CORE-R42).
	ns.AddSettings(ns.Module)

	--- The live tracker, docked once at order 20 (STA-R80). An inert or disabled Stats never gets here, so it docks
	--- nothing (STA-R90, CORE-R17).
	ns.StartTracker(ns.Module)
end
