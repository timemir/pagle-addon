if not Pagle then
	return
end

local addonName = ...
---@class PagleQoLNS
local ns = select(2, ...)

-- QoL's AceAddon (QOL-R1, QOL-R2). Core's libraries come through LibStub; QoL embeds none (CORE-R6).
ns.QoL = LibStub("AceAddon-3.0"):NewAddon(addonName)

--- AceAddon calls it once, at QoL's ADDON_LOADED, after Core's (CORE-R10).
function ns.QoL.OnInitialize()
	--- QoL's Module handle: the calls that act for QoL (CORE-R12). Nil while QoL is inert.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef(function(topic)
		Pagle.OpenSettings(topic)
	end))
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end
	-- QoL's rows on the Fishing page, before ModulesChanged (CORE-R42, SET-R20).
	ns.AddSettings(ns.Module)

	-- Account-wide, one shared profile (QOL-R1), with the defaults in qol.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleQoLDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)
	-- The leftover restore comes before anything else (QOL-R64).
	ns.StartStretch()

	ns.StartFishingKey()
	ns.StartLures()
	ns.StartCombat()
end
