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
	--- Hunts' moments, Write-up and summary line (HNT-R85–R91, HNT-R111, HNT-R112): the projection's outlets and the
	--- redraws reach them (logic/Moments.lua).
	ns.moments = ns.NewHuntsMoments(ns.db.global, {
		RaiseMoment = function(moment)
			ns.Module:RaiseMoment(moment)
		end,
		RaiseWriteUp = function(section)
			ns.Module:RaiseWriteUp(section)
		end,
		SetSummaryLine = function(text)
			ns.Module:SetSummaryLine("hunts", text)
		end,
		FormatNumber = function(n)
			return BreakUpLargeNumbers(n)
		end,
		ServerTime = GetServerTime,
	})

	-- Grouping (HNT-R40–R44): pins of Hunts gone are dropped now; the first grouping waits for the world.
	ns.StartGroups()
end
