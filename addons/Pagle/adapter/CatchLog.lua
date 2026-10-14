---@class PagleNS
local ns = select(2, ...)

-- Core's SavedVariables, PagleLog and PagleDB (CORE-R5), Pagle.IterateCatches (LOG-R42), and the Prestige and
-- purchase entries (LOG-R38, LOG-R39).

-- Off Forever, Core never creates the Pagle global (CORE-R4), so there is nothing to load.
---@class Pagle
local Pagle = _G.Pagle
if not Pagle then
	return
end

--- Login step 1 (LOG-R1), once the client has loaded the SavedVariables: opens PagleDB and PagleLog, checking
--- PagleLog's format (LOG-R18). Sets `ns.db` (the PagleDB AceDB object) and `ns.catchLog`. adapter/Login.lua then
--- notes loginSeq and migrates PagleDB.
function ns.OpenSavedVariables()
	-- One shared Default profile, account-wide (CORE-R5), with logic/Migrations.lua's defaults.
	ns.db = LibStub("AceDB-3.0"):New("PagleDB", ns.PAGLEDB_DEFAULTS, true)
	-- Casts are sized by the catalogue built later in this step, which nothing decodes before (LOG-R65).
	local catchLog, started = ns.OpenCatchLog(_G.PagleLog, ns.db.global, GetServerTime(), ns.CatalogueItem)
	_G.PagleLog = catchLog.data
	ns.catchLog = catchLog
	if started then
		print(ns.L.LOG_FORMAT_CHANGED)
	end
end

--- Walks the Catch log's entries with `seq > afterSeq` (0 if nil), up to its length now, in order, and yields each
--- as a typed record, decoded as the walk reaches it (LOG-R42). It yields Casts, Skill Readings, Prestiges, builds and purchases. An entry
--- that can't be decoded is skipped (LOG-R16).
---@param afterSeq integer?
---@return fun(): PagleRecord?
function Pagle.IterateCatches(afterSeq)
	return ns.catchLog:Iterate(afterSeq)
end

--- Payload of `Prestige`: the Prestige just appended (LOG-R38).
---@alias PaglePrestigeHandler fun(event: "Prestige", record: PaglePrestige)

--- `M:RecordPrestige()` on every Module handle, `ns.RecordPrestige()` and `ns.RecordPurchase(goodID, price)`, the
--- Curio Shop's buy flow's only way to append a purchase (LOG-R38, LOG-R39): logic/Wiring.lua's, over
--- adapter/Host.lua's host.
ns.WireLogEntries(ns.host)
