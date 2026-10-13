if not Pagle then
	return
end

local addonName = ...
---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's AceAddon (LED-R1). Core's libraries come through LibStub; the Ledger embeds none (CORE-R6).
ns.Ledger = LibStub("AceAddon-3.0"):NewAddon(addonName)

--- AceAddon calls it once, at the Ledger's ADDON_LOADED, after Core's (CORE-R10).
function ns.Ledger.OnInitialize()
	--- The Ledger's Module handle: the calls that act for the Ledger (CORE-R12). Nil while the Ledger is inert.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef())
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end

	-- Account-wide, one shared profile, with the defaults in ledger.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleLedgerDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)
end
