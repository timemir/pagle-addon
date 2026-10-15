if not Pagle then
	return
end

local addonName = ...
---@class PagleQoLNS
local ns = select(2, ...)

-- QoL's AceAddon (QOL-R1, QOL-R2). Core's libraries come through LibStub; QoL embeds none (CORE-R6).
ns.QoL = LibStub("AceAddon-3.0"):NewAddon(addonName)

-- What the Settings rows, the compartment entry and `/pagle qol` read and change, passed into their logic (CORE-R7).
-- PagleQoLDB is read when a row or the menu asks, so it may open after the rows are added.
---@type PagleQoLStore
local store = {
	profile = function()
		return ns.db.profile
	end,
	input = ns.CurrentInput,
	setInput = ns.SetInput,
	evaluate = ns.EvaluateFishingKey,
	changeLease = ns.ChangeLeaseSetting,
	itemName = ns.ItemName,
	fishingSetChoice = ns.FishingSetChoice,
	chooseFishingSet = ns.ChooseFishingSet,
	fishingSetOptions = ns.ReadFishingSetOptions,
	canEditGear = ns.CanEditGear,
	saveFishingSet = ns.SaveFishingSet,
	resetButton = ns.ResetNextActionButton,
}

--- AceAddon calls it once, at QoL's ADDON_LOADED, after Core's (CORE-R10).
function ns.QoL.OnInitialize()
	--- QoL's Module handle: the calls that act for QoL (CORE-R12). Nil while QoL is inert.
	ns.Module = Pagle.RegisterModule(ns.ModuleDef(function(topic)
		Pagle.OpenSettings(topic)
	end, print, store))
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end
	-- QoL's rows on the Fishing page, before ModulesChanged (CORE-R42, SET-R20).
	ns.AddSettings(ns.Module, store)
	-- QoL's stop for `/pagle dev tour` (CORE-R65), on a Core that has the call.
	if ns.Module.RegisterTourStop then
		ns.RegisterTourStops(ns.Module)
	end

	-- Account-wide, one shared profile (QOL-R1), with the defaults in qol.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleQoLDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)
	-- The leftover restore comes before anything else (QOL-R64).
	ns.StartStretch()

	ns.StartFishingKey()
	ns.StartDoubleClick()
	ns.StartLures()
	ns.StartGear()
	ns.StartCombat()
end
