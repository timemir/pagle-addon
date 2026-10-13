local addonName = ...
---@class PagleNS
local ns = select(2, ...)

-- Core's SavedVariables, PagleLog and PagleDB (CORE-R5), and Pagle.IterateCatches (LOG-R42).

-- Off Forever, Core never creates the Pagle global (CORE-R4), so there is nothing to load.
---@class Pagle
local Pagle = _G.Pagle
if not Pagle then
	return
end

-- PagleDB's defaults: only keys catch-log.md › Data lists. schemaVersion has none, so a DB that never stored it
-- reads as unmigrated.
local PAGLEDB_DEFAULTS = {
	global = {
		decodeErrors = 0, -- LOG-R16
	},
}

-- Its own owner, so no other Core file's ADDON_LOADED registration replaces this one (CORE-R23).
local OWNER = "Pagle Catch log"

-- Loads PagleLog and PagleDB once the client has loaded them (ADDON_LOADED, LOG-R1 step 1): checks PagleLog's
-- format (LOG-R18) and migrates PagleDB. Sets `ns.db` (the PagleDB AceDB object) and `ns.catchLog`.
local function load()
	-- One shared Default profile, account-wide (CORE-R5).
	ns.db = LibStub("AceDB-3.0"):New("PagleDB", PAGLEDB_DEFAULTS, true)
	local catchLog, started = ns.OpenCatchLog(_G.PagleLog, ns.db.global, GetServerTime())
	_G.PagleLog = catchLog.data
	ns.catchLog = catchLog
	if started then
		print(ns.L.LOG_FORMAT_CHANGED)
	end
	ns.Migrate(ns.db, ns.PAGLEDB_MIGRATIONS)
end

Pagle.RegisterEvent(OWNER, "ADDON_LOADED", function(_, loadedName)
	if loadedName == addonName then
		load()
		Pagle.UnregisterEvent(OWNER, "ADDON_LOADED")
	end
end)

--- Walks the Catch log's entries with `seq > afterSeq` (0 if nil), up to its length now, in order, and yields each
--- as a typed record, decoded as the walk reaches it (LOG-R42). It yields Casts, Skill Readings and builds. An entry
--- that can't be decoded is skipped (LOG-R16).
---@param afterSeq integer?
---@return fun(): PagleRecord?
function Pagle.IterateCatches(afterSeq)
	return ns.catchLog:Iterate(afterSeq)
end
