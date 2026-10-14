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
end
