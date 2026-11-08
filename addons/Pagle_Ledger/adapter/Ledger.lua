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
	ns.Module = Pagle.RegisterModule(ns.ModuleDef(ns.ToggleJournal, ns.OpenCollection))
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end

	-- Account-wide, one shared profile, with the defaults in ledger.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleLedgerDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)

	-- Core's lookups the Ledger reads (LOG-R55, LOG-R49), the world index's and the fold's.
	local lookups = ns.LedgerLookups(Pagle)
	--- The world index (LED-R10): built here, where the catalogue is ready (CORE-R10), held in memory, never stored.
	ns.world = lookups.world

	-- The climb's Activity XP comes from Core's total, read whenever the level is worked out (LED-R37, AXP-R6).
	ns.SetActivityXPSource(function()
		return Pagle.GetActivityXP().total
	end)

	local sizeRulesVersion = Pagle.SIZE_RULES_VERSION -- the Ledger stores lengths (LED-R2, LOG-R68)
	--- The Ledger's projection (LED-R2): Core catches it up or rebuilds it after login and hands it each new entry
	--- live (LOG-R71–R74). While `:IsUpdating()`, the Ledger shows nothing (LOG-R74). The Fish Journal redraws after
	--- its live entries and its done (LED-R122, LED-R123).
	--- The fold reads the world index and Core's MatchesConditions as lookups (LED-R3, LED-R45).
	local def, activityXPChanged = ns.ProjectionDef(ns.db.global, lookups, ns.Outlets(ns.Module), sizeRulesVersion)
	-- The crest and title records (LED-R156, LED-R157, #76 items 19 and 2): the frame after the crest the bookplate
	-- pins or the title "Signed as" picks changes, and after the projection's done, each is logged when the last record
	-- of its kind doesn't name it: the log's latest crest record, as the fold keeps it, and the title record the Ledger
	-- noted in PagleLedgerDB.global.titleLogged, which the fold ignores. Never from done itself, where M:AppendRecord
	-- raises (LOG-R40), nor while the projection updates: its done queues them again.
	local choicesQueued = false
	local function logChoices()
		choicesQueued = false
		local state = ns.StateNow()
		if not state then
			return
		end
		local equipped = Pagle.GetEquipped(ns.CREST_SLOT)
		local good = equipped and Pagle.GetGood(equipped)
		local isDefault = not equipped or (good ~= nil and good.isDefault == true)
		local payload = ns.CrestRecordFor(state, equipped or "", isDefault)
		if payload then
			ns.Module:AppendRecord(ns.CREST_RECORD, payload)
		end
		local logId = ns.LedgerLogKey(Pagle.GetAngler())
		local title = ns.TitleRecordFor(ns.db.global.titleLogged, logId, ns.db.profile.activeTitle)
		if title and logId then
			ns.Module:AppendRecord(ns.TITLE_RECORD, title)
			ns.db.global.titleLogged = { logId = logId, key = title }
		end
	end
	--- Logs the crest and title records due, the next frame (LED-R156, LED-R157).
	function ns.QueueChoiceRecords()
		if not choicesQueued then
			choicesQueued = true
			C_Timer.After(0, logChoices)
		end
	end
	local journalDef = ns.WithJournalRedraws(def)
	local journalDone = journalDef.done
	journalDef.done = function(state, info)
		if journalDone then
			journalDone(state, info)
		end
		ns.QueueChoiceRecords()
	end
	ns.projection = ns.Module:NewProjection(journalDef)
	Pagle.RegisterCallback(ns.Ledger, "AppearanceChanged", function(_, slot)
		if slot == ns.CREST_SLOT then
			ns.QueueChoiceRecords()
		end
		-- the Collection shows each look in use as the Curio Shop's Use and Look and Feel change it (LED-R173)
		ns.journal:QueueDraw()
	end)
	-- A purchase or a crate opened from the Collection turns a look owned while its shelf is shown (LED-R170, ledger.md ›
	-- UI): the Coins spent change the balance, and the open spread draws again.
	Pagle.RegisterCallback(ns.Ledger, "BalanceChanged", function()
		ns.journal:QueueDraw()
	end)
	-- Another Module's Activity XP changed the climb (LED-R39): the shown level is worked out again, then the Journal
	-- redraws. While the projection updates, its done does it instead; one that already ran (the entries appended
	-- meanwhile still applying) leaves it to the next frame's try, which finds nothing new when done did it.
	local retrying = false
	local function workOutLevel(entry)
		local projection = ns.projection
		if projection:IsUpdating() then
			if not retrying then
				retrying = true
				C_Timer.After(0, function()
					retrying = false
					workOutLevel(nil)
				end)
			end
			return
		end
		activityXPChanged(projection:GetState() --[[@as LedgerState]], entry)
		-- The Activity XP may have brought the climb to 60 (LED-R201).
		ns.NotePrestigeLetter()
		ns.journal:QueueDraw()
	end
	Pagle.RegisterCallback(ns.Ledger, "ActivityXPChanged", function(_, entry)
		workOutLevel(entry)
	end)
	-- The Journal bindings (LED-R110): after the projection, which their isEarned reads (LED-R111).
	ns.RegisterBindings(ns.Module)
	-- The Field guide's Your Ledger step (ONB-R21, ONB-R36), before ModulesChanged, on a Core that has the call
	-- (ONB-R90).
	if ns.Module.RegisterGuideStep then
		ns.RegisterGuideLedgerStep(ns.Module)
	end
	-- The Prestige letter (LED-R200), on a Core that has the call (ONB-R90).
	if ns.Module.RegisterLetter then
		ns.RegisterPrestigeLetter(ns.Module)
	end
	-- The Fish Journal's First look (ONB-R56, ONB-R57), before the book first shows, on a Core that has it.
	if ns.Module.RegisterFirstLook then
		ns.RegisterJournalFirstLook(ns.Module)
	end
	-- The Journal's stops for `/pagle dev tour` (CORE-R65), on a Core that has the call.
	if ns.Module.RegisterTourStop then
		ns.RegisterTourStops(ns.Module)
	end
end

--- The projection's state for what the Ledger shows now (LOG-R74): nil while it is updating, or while the Ledger is
--- inert.
---@return LedgerState?
function ns.StateNow()
	local projection = ns.projection
	return projection and not projection:IsUpdating() and projection:GetState() --[[@as LedgerState?]] or nil
end

--- The celebrated set as saved (LED-R90): reading it makes none of its keys, as ns.CelebratedSet would.
---@return LedgerCelebrated
function ns.SavedCelebrated()
	return ns.db.global.celebrated or {}
end

--- A Catch's or record's size text (LED-R81) in Core's band names and the Angler's length unit (LED-R85).
---@param size { length: integer, band: integer }?
---@return string?
function ns.ClientSizeText(size)
	return ns.SizeText(size, Pagle.SIZE_BANDS, Pagle.FormatLength)
end

--- A Catch's or record's Size band's name in Core's band names (a size record's ruler label, ANN-R22).
---@param size { length: integer, band: integer }?
---@return string?
function ns.ClientBandName(size)
	return ns.BandName(size, Pagle.SIZE_BANDS)
end

-- The Size band a Monster-size record names on its ruler (Pagle.SIZE_BANDS' "monster"), nil without one.
---@return string?
local function monsterBandName()
	local bands = Pagle.SIZE_BANDS
	for i = 1, 10 do
		local band = bands and bands[i]
		if not band then
			return nil
		elseif band.key == "monster" then
			return band.name
		end
	end
	return nil
end

--- The party kind of a Ledger moment (announcements.md ANN-R104, from 1.5.2, #640), which Core shares with the
--- player's party, or nil: a Legend's first Catch (`legend`), a Rare or Epic variety's (`colour`), a size record in
--- the Monster band (`monster`, its ruler labelled with that band's name, LED-R82), a Zone Master (`zone`), a
--- Prestige (`prestige`) and the `complete.ledger` title's moment (`ledger`, its text that title's name, LED-R75).
--- Read from what the moment already holds, so what the Ledger computes is unchanged; it is here, not in logic/, as
--- a 1.5.2 patch changes no hashed file.
---@param moment PagleMoment
---@return ("legend"|"colour"|"monster"|"zone"|"prestige"|"ledger")?
function ns.PartyKind(moment)
	local kind = moment.kind
	if kind == "legend" then
		return "legend"
	elseif kind == "rareVariety" or kind == "epicVariety" then
		return "colour"
	elseif kind == "zoneMaster" then
		return "zone"
	elseif kind == "prestige" then
		return "prestige"
	elseif kind == "sizeRecord" then
		local monster = monsterBandName()
		return monster and moment.ruler and moment.ruler.label == monster and "monster" or nil
	elseif kind == "completeTitle" then
		local ledger = ns.TitleName("title:complete.ledger", ns.NewLoreText(ns.ClientNames.AreaName))
		return ledger and moment.text == ledger and "ledger" or nil
	end
	return nil
end

--- Where the Ledger's moments, Write-up sections, Coins and summary line go, and what they read: the client's names
--- and numbers, the Angler's logId, the goods' refresh, Core's size text and band names, a zone's crest, a variety's
--- name and art and a fish crest's name and icon (LED-R81, LED-R89, LED-R90, LED-R93–R95, LED-R97, LED-R111, VAR-R25).
---@param module PagleModuleHandle
---@return LedgerOutlets
function ns.Outlets(module)
	-- Each zone name the moments looked up, back to its areaID: a Zone Master's moment names its zone in its text
	-- (LED-R97), and its party mark carries the areaID, so a groupmate reads the name in their own language
	-- (ANN-R104).
	local areaOf = {}
	return {
		RaiseMoment = function(moment)
			-- Marked for the player's party, if it is a kind Core shares (ANN-R104).
			moment.party = ns.PartyKind(moment)
			if moment.party == "zone" then
				moment.partyArea = areaOf[moment.text]
			end
			module:RaiseMoment(moment)
		end,
		ReportCoinsEarned = function(total)
			module:ReportCoinsEarned(total)
		end,
		SetSummaryLine = function(text)
			module:SetSummaryLine("ledger", text)
		end,
		ItemName = ns.ClientNames.ItemName,
		AreaName = function(areaID)
			local name = ns.ClientNames.AreaName(areaID)
			if name then
				areaOf[name] = areaID
			end
			return name
		end,
		RaiseWriteUp = function(section)
			module:RaiseWriteUp(section)
		end,
		LogId = function()
			return ns.LedgerLogKey(Pagle.GetAngler())
		end,
		FormatNumber = function(n)
			return ns.FormatCount(n)
		end,
		RefreshGoods = function()
			module:RefreshGoods()
		end,
		SizeText = ns.ClientSizeText,
		BandName = ns.ClientBandName,
		-- logic/ZoneCrests.lua's, read at each call (LED-R97, LED-R113).
		ZoneCrest = function(areaID)
			return ns.ZoneCrestOf(areaID)
		end,
		Variety = function(speciesID, index)
			-- Core's static list (VAR-R11); nil for a Species without varieties, so the moment names none.
			local list = Pagle.GetVarieties(speciesID)
			return list and list[index]
		end,
		Good = function(goodID)
			return Pagle.GetGood(goodID)
		end,
	}
end
