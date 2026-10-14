if not Pagle then
	return
end

local addonName = ...
---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' AceAddon (HNT-R135). Core's libraries come through LibStub; Hunts embeds none (CORE-R6).
ns.Hunts = LibStub("AceAddon-3.0"):NewAddon(addonName)

--- AceAddon calls it once, at Hunts' ADDON_LOADED, after Core's (CORE-R10).
function ns.Hunts.OnInitialize()
	--- Hunts' Module handle: the calls that act for Hunts (CORE-R12). Nil while Hunts is inert.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef(function()
		ns.ToggleBoard()
	end))
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end

	-- Account-wide, one shared profile, with the defaults in hunts.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleHuntsDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)

	--- The Hunt list at runtime (HNT-R1): every file has loaded by now, data\HuntList.lua and the lore included.
	ns.hunts = ns.NewHuntList(ns.huntList, ns.L)
	--- Where each Hunt bites (HNT-R30–R34): worked out here, once per load, where the catalogue is ready (CORE-R10).
	ns.where = ns.NewWhere(ns.hunts, {
		GetItem = Pagle.GetItem,
		GetZones = Pagle.GetZones,
		GetZoneCatches = Pagle.GetZoneCatches,
		GetZoneOf = Pagle.GetZoneOf,
		GetArea = Pagle.GetArea,
		GetWindowSpec = Pagle.GetWindowSpec,
	})

	--- Hunts' projection (HNT-R136): Core catches it up or rebuilds it after login and hands it each new entry live
	--- (LOG-R71–R74). The views read it through ns.State() and ns.IsUpdating() (logic/Seams.lua).
	local lookups = {
		GetItem = Pagle.GetItem,
		MatchesConditions = Pagle.MatchesConditions,
		Class = function(id)
			return ns.hunts:Class(id)
		end,
	}
	ns.projection = ns.Module:NewProjection(ns.ProjectionDef(ns.db.global, lookups, {
		ReportCoinsEarned = function(total)
			ns.Module:ReportCoinsEarned(total)
		end,
		ServerTime = GetServerTime,
	}))

	-- Grouping (HNT-R40–R44): pins of Hunts gone are dropped now; the first grouping waits for the world.
	ns.StartGroups()

	-- Calendar event names for the conditions line, looked up once this login (HNT-R53).
	ns.StartNames()

	-- Window moments (HNT-R88): their Announcements row (SET-R32) and the regroup baseline.
	ns.StartWindowMoments()
end
