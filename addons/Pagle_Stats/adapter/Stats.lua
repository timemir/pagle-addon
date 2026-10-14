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

	-- Account-wide, one shared profile, with the defaults in stats.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleStatsDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)
end
