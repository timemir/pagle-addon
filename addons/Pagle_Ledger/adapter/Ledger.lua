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
	ns.Module = Pagle.RegisterModule(ns.ModuleDef(ns.ToggleJournal))
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end

	-- Account-wide, one shared profile, with the defaults in ledger.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleLedgerDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)

	--- The world index (LED-R10): built here, where the catalogue is ready (CORE-R10), held in memory, never stored.
	ns.world = ns.NewWorld({
		GetItem = Pagle.GetItem,
		GetZones = Pagle.GetZones,
		GetArea = Pagle.GetArea,
		GetZoneCatches = Pagle.GetZoneCatches,
	})

	---@diagnostic disable-next-line: undefined-field -- Core defines it in M4, with Simulated Size (LOG-R68); nil till then
	local sizeRulesVersion = Pagle.SIZE_RULES_VERSION --[[@as integer?]]
	--- The Ledger's projection (LED-R2): Core catches it up or rebuilds it after login and hands it each new entry
	--- live (LOG-R71–R74). While `:IsUpdating()`, the Ledger shows nothing (LOG-R74). The Fish Journal redraws after
	--- its live entries and its done (LED-R122, LED-R123).
	--- The fold reads the world index and Core's MatchesConditions as lookups (LED-R3, LED-R45).
	local lookups = { GetItem = Pagle.GetItem, MatchesConditions = Pagle.MatchesConditions, world = ns.world }
	ns.projection = ns.Module:NewProjection(
		ns.WithJournalRedraws(ns.ProjectionDef(ns.db.global, lookups, ns.Outlets(ns.Module), sizeRulesVersion))
	)
end

--- Where the Ledger's moments, Write-up sections, Coins and summary line go, and what they read: the client's names
--- and numbers, and the Angler's logId (LED-R89, LED-R90, LED-R93–R95, LED-R97).
---@param module PagleModuleHandle
---@return LedgerOutlets
function ns.Outlets(module)
	return {
		RaiseMoment = function(moment)
			module:RaiseMoment(moment)
		end,
		ReportCoinsEarned = function(total)
			module:ReportCoinsEarned(total)
		end,
		SetSummaryLine = function(text)
			module:SetSummaryLine("ledger", text)
		end,
		ItemName = function(itemID)
			return C_Item.GetItemNameByID(itemID)
		end,
		ZoneName = function(zone)
			return (C_Map.GetAreaInfo(zone))
		end,
		RaiseWriteUp = function(section)
			module:RaiseWriteUp(section)
		end,
		LogId = function()
			return Pagle.GetAngler().logId
		end,
		FormatNumber = function(n)
			return BreakUpLargeNumbers(n)
		end,
	}
end
