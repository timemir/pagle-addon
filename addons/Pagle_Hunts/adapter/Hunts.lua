if not Pagle then
	return
end

local addonName = ...
---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' AceAddon (HNT-R135). Core's libraries come through LibStub; Hunts embeds none (CORE-R6).
ns.Hunts = LibStub("AceAddon-3.0"):NewAddon(addonName)

-- A Hunt's gold tier is marked for the player's party (announcements.md ANN-R104, from 1.5.2, #640): the moment of
-- the tier whose trim is the first gold one (logic/Qualify.lua's ns.Trim, HNT-R86) carries `party = "gold"` and the
-- Hunt's ID, which a groupmate's Hunts names. It wraps logic/Moments.lua's ns.HuntTierMoment here, adding only the
-- mark, as a 1.5.2 patch changes no hashed file; what the moment says is unchanged.
local tierMoment = ns.HuntTierMoment
---@diagnostic disable-next-line: duplicate-set-field -- the wrap is the point: logic/ can't change in a patch
function ns.HuntTierMoment(hunt, k, huntTier)
	local moment = tierMoment(hunt, k, huntTier)
	if k > 1 and ns.Trim(k) == "gold" and ns.Trim(k - 1) ~= "gold" then
		moment.party = "gold"
		moment.partyHunt = hunt.id
	end
	return moment
end

--- AceAddon calls it once, at Hunts' ADDON_LOADED, after Core's (CORE-R10).
function ns.Hunts.OnInitialize()
	--- Hunts' Module handle: the calls that act for Hunts (CORE-R12). Nil while Hunts is inert.
	local def = ns.ModuleDef(function()
		ns.ToggleBoard()
	end)
	-- A groupmate's Hunt gold names its Hunt in the player's language (announcements.md ANN-R106, from 1.5.2, #640):
	-- the Hunt's name from its lore, or nil for one this Hunts doesn't know.
	def.partyHuntName = function(huntID)
		local name = ns.hunts and ns.hunts:HuntName(huntID)
		return name ~= huntID and name or nil
	end
	-- From 1.6, a groupmate's "Completed for the party" for a run names its event the same way (ANN-R111): a pooled or
	-- logged pushed event's name, or nil for one this Hunts doesn't know.
	def.partyEventName = function(eventID)
		local event = ns.events and ns.KnownEvent(ns.State(), eventID)
		local name = event and ns.events:EventName(event)
		return name ~= eventID and name or nil
	end
	ns.Module = Pagle.RegisterModule(def)
	-- An inert Module must stop (CORE-R13).
	if not ns.Module then
		return
	end
	-- Hunts' slots and goods, right after RegisterModule (HNT-R122).
	ns.RegisterGoods(ns.Module)
	-- The board's First look, before the board first opens, so it joins Off you go's list and the tour (ONB-R56), on a
	-- Core that has First looks (ONB-R90).
	ns.RegisterBoardLook(ns.Module)

	-- Account-wide, one shared profile, with the defaults in hunts.md › Data.
	ns.db = LibStub("AceDB-3.0"):New("PagleHuntsDB", ns.DB_DEFAULTS, true)
	ns.MigrateDB(ns.db.global)

	--- The Hunt list at runtime (HNT-R1): every file has loaded by now, data\HuntList.lua and the lore included. On a
	--- test log with a release date (catch-log.md › Test logs), every Hunt is out from then.
	ns.hunts = ns.NewHuntList(ns.HuntListFrom(ns.huntList, Pagle.GetTestLogGrant("devHuntsSince")), ns.L)
	--- Hunts' reads of Core's catalogue and rules (logic/Qualify.lua).
	ns.lookups = ns.NewLookups(Pagle, ns.hunts)
	--- Where each Hunt bites (HNT-R30–R34): worked out here, once per load, where the catalogue is ready (CORE-R10).
	ns.where = ns.NewWhere(ns.hunts, ns.lookups)
	--- The event pool at runtime (HNT-R140), each event Hunt's waters worked out here too, once per load (HNT-R30).
	ns.events = ns.NewEventList(ns.eventList, ns.L, ns.lookups)

	--- Hunts' projection (HNT-R136): Core catches it up or rebuilds it after login and hands it each new entry live
	--- (LOG-R71–R74). The views read it through ns.State() and ns.IsUpdating() (logic/Seams.lua).
	ns.projection = ns.Module:NewProjection(ns.ProjectionDef(ns.db.global, ns.lookups, {
		ReportCoinsEarned = function(total)
			ns.Module:ReportCoinsEarned(total)
		end,
		ReportXPEarned = function(total)
			ns.Module:ReportXPEarned(total)
		end,
		ReportTicketsEarned = function(total)
			ns.Module:ReportTicketsEarned(total)
		end,
		-- A run record's earlier Casts, read back from the log (HNT-R149, LOG-R42).
		IterateCatches = function(afterSeq)
			return ns.Module:IterateCatches(afterSeq)
		end,
		ServerTime = GetServerTime,
	}))
	--- The run log (HNT-R150–R155): which runs are on, and the live step that logs each run the first time it is used
	--- (adapter/RunLog.lua, logic/RunLog.lua).
	ns.StartRunLog(ns.Module)
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
			return Pagle.Text("{n:n}", { n = n }) -- the Language's separators (CORE-R8)
		end,
		ServerTime = GetServerTime,
	})

	-- Grouping (HNT-R40–R44): pins of Hunts gone are dropped now; the first grouping waits for the world.
	ns.StartGroups()

	-- The Hunts tracker in Core's dock, and its setting on the Trackers page (HNT-R75, SET-R41).
	ns.StartTracker(ns.Module)

	-- Calendar event names for the conditions line, looked up once this login (HNT-R53).
	ns.StartNames()

	-- Window moments (HNT-R88): their Announcements row (SET-R32) and the regroup baseline.
	ns.StartWindowMoments()

	-- The companion hint (HNT-R170–R172): its Announcements row after the window moments' and its weekly Nod, only
	-- while the hint switch is on.
	ns.StartCompanionHint()

	-- Hunts' stops for `/pagle dev tour` (CORE-R65), on a Core that has the call.
	if ns.Module.RegisterTourStop then
		ns.RegisterTourStops(ns.Module)
	end
end
