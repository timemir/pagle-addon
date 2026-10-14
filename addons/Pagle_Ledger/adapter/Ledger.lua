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

	-- Core's lookups the Ledger reads (LOG-R55, LOG-R49): the world index's, and the fold's with the world added.
	local lookups = {
		GetItem = Pagle.GetItem,
		GetZones = Pagle.GetZones,
		GetArea = Pagle.GetArea,
		GetZoneCatches = Pagle.GetZoneCatches,
		MatchesConditions = Pagle.MatchesConditions,
	}
	--- The world index (LED-R10): built here, where the catalogue is ready (CORE-R10), held in memory, never stored.
	ns.world = ns.NewWorld(lookups)
	lookups.world = ns.world

	local sizeRulesVersion = Pagle.SIZE_RULES_VERSION -- the Ledger stores lengths (LED-R2, LOG-R68)
	--- The Ledger's projection (LED-R2): Core catches it up or rebuilds it after login and hands it each new entry
	--- live (LOG-R71–R74). While `:IsUpdating()`, the Ledger shows nothing (LOG-R74). The Fish Journal redraws after
	--- its live entries and its done (LED-R122, LED-R123).
	--- The fold reads the world index and Core's MatchesConditions as lookups (LED-R3, LED-R45).
	ns.projection = ns.Module:NewProjection(
		ns.WithJournalRedraws(ns.ProjectionDef(ns.db.global, lookups, ns.Outlets(ns.Module), sizeRulesVersion))
	)
	-- The Journal bindings (LED-R110): after the projection, which their isEarned reads (LED-R111).
	ns.RegisterBindings(ns.Module)
end

--- Where the Ledger's moments, Write-up sections, Coins and summary line go, and what they read: the client's names
--- and numbers, the Angler's logId, the goods' refresh and Core's size text (LED-R81, LED-R89, LED-R90, LED-R93–R95,
--- LED-R97, LED-R111).
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
		ItemName = ns.ClientNames.ItemName,
		AreaName = ns.ClientNames.AreaName,
		RaiseWriteUp = function(section)
			module:RaiseWriteUp(section)
		end,
		LogId = function()
			return Pagle.GetAngler().logId
		end,
		FormatNumber = function(n)
			return BreakUpLargeNumbers(n)
		end,
		RefreshGoods = function()
			module:RefreshGoods()
		end,
		SizeText = function(size)
			return ns.SizeText(size, Pagle.SIZE_BANDS, Pagle.FormatLength)
		end,
	}
end
