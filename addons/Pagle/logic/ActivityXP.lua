---@class PagleNS
local ns = select(2, ...)

-- Core's Activity XP (ADR 0011, core/activity-xp.md): each paying Module's last reported lifetime total, tied to the
-- log's logId, and their sum, which every Prestige entry snapshots (AXP-R5). Pure logic, everything passed in
-- (CORE-R7); logic/Wiring.lua binds it to PagleDB.global.activityXP. Core pays none itself, and the Ledger alone reads
-- the totals (AXP-R1).

--- What `Pagle.GetActivityXP()` returns (activity-xp.md › Contracts).
---@class ActivityXP
---@field total integer
---@field bySource table<string, { total: integer, enabled: boolean }>

--- Fires once when a stored total changes, after storing it (AXP-R7): `entry` is the live entry whose apply led to
--- the report (the Cast or Module record), or nil for a report from a projection's done or outside any apply.
---@alias PagleActivityXPChangedHandler fun(event: "ActivityXPChanged", entry: PagleRecord?)

--- Lifetime totals that belong to one Catch log (SHOP-R3, AXP-R3): PagleDB.global.coins or .activityXP.
---@class PagleLoggedTotals
---@field earned table<string, integer> the last report per Module, by def.name
---@field logId string? the PagleLog.logId they were reported under

--- Ties a store of totals to the log (SHOP-R3, AXP-R3), as login step 1 does at ADDON_LOADED: when `logId` (PagleLog's
--- now) differs from the stored one, as for a new log (LOG-R18), the totals are emptied in place and the store takes
--- `logId`, so a new log never inherits the old one's. Returns whether it emptied them.
---@param store PagleLoggedTotals
---@param logId string?
---@return boolean emptied
function ns.TieTotalsToLog(store, logId)
	if store.logId == logId then
		return false
	end
	for name in pairs(store.earned) do
		store.earned[name] = nil
	end
	store.logId = logId
	return true
end

--- Why `total` can't be a Module's lifetime Activity XP, or nil if it can: a whole number, 0 or more (AXP-R2).
---@param total any
---@return string?
function ns.XPTotalProblem(total)
	if type(total) ~= "number" or total ~= total or total < 0 or total ~= math.floor(total) or total == math.huge then
		return ("M:ReportXPEarned takes a whole number of Activity XP, 0 or more; got %s"):format(tostring(total))
	end
	return nil
end

--- What Activity XP reads from where Core runs. Every function is called when needed.
---@class PagleActivityXPOptions
---@field fire fun(event: "ActivityXPChanged", entry: PagleRecord?) fires ActivityXPChanged on Core's bus
---@field modules fun(): PagleModule[] the Modules registered this session: On (CORE-R41)
---@field logId fun(): string? PagleLog.logId now

---@class PagleActivityXP
---@field private options PagleActivityXPOptions
---@field private store PagleLoggedTotals
local ActivityXP = {}
ActivityXP.__index = ActivityXP

--- Activity XP with nothing stored, until `Open` hands it PagleDB's store.
---@param options PagleActivityXPOptions
---@return PagleActivityXP
function ns.NewActivityXP(options)
	return setmetatable({ options = options, store = { earned = {} } }, ActivityXP)
end

--- Login step 1, once PagleDB is open: ties `store` (PagleDB.global.activityXP) to the log (ns.TieTotalsToLog), then
--- reads and writes it in place from now on. A total stays until its Module reports another, so a disabled or
--- uninstalled Module's still counts (AXP-R3, AXP-R90).
---@param store PagleLoggedTotals
function ActivityXP:Open(store)
	ns.TieTotalsToLog(store, self.options.logId())
	self.store = store
end

--- The sum of the stored totals (AXP-R5, AXP-R6): what a Prestige entry snapshots, as the totals stand (AXP-R92).
---@return integer
function ActivityXP:Total()
	local sum = 0
	for _, total in pairs(self.store.earned) do
		sum = sum + total
	end
	return sum
end

--- `Pagle.GetActivityXP()` (AXP-R6): the sum and each Module that has reported, with its last total and whether it is
--- On this session (CORE-R41), a fresh table each call.
---@return ActivityXP
function ActivityXP:Get()
	local on = {}
	for _, module in ipairs(self.options.modules()) do
		on[module.def.name] = true
	end
	local bySource = {}
	for name, total in pairs(self.store.earned) do
		bySource[name] = { total = total, enabled = on[name] == true }
	end
	return { total = self:Total(), bySource = bySource }
end

--- Stores a Module's lifetime total, taken as given, under the log's logId now, and fires `ActivityXPChanged(entry)`
--- unless it equals the stored one (AXP-R3, AXP-R4, AXP-R7). Only a later, lower report lowers a total. The caller
--- checks it with ns.XPTotalProblem.
---@param name string the Module's def.name
---@param total integer
---@param entry PagleRecord? the live entry being applied, nil from a done or outside any apply
function ActivityXP:Report(name, total, entry)
	local store = self.store
	-- A fresh log gets its logId at PLAYER_LOGIN (LOG-R15), after ADDON_LOADED tied the store: these totals are its.
	store.logId = self.options.logId()
	if store.earned[name] == total then
		return
	end
	store.earned[name] = total
	self.options.fire("ActivityXPChanged", entry)
end

--- `M:ReportXPEarned(total)` over `activityXP` (AXP-R2, AXP-R7), so Core's adapter and FakePagle publish one method:
--- an error at the Module's call, storing nothing, for anything but a whole number, 0 or more, or from a replay or
--- rebuild apply (a Module reports from its done, or after a live entry). A report from a live apply carries that
--- entry to `ActivityXPChanged`.
---@param registry PagleModuleRegistry
---@param activityXP PagleActivityXP
---@param projections PagleProjections
---@return fun(self: PagleModuleHandle, total: integer)
function ns.ReportXPEarnedMethod(registry, activityXP, projections)
	return function(self, total)
		local module = registry:ModuleCalling(self, "ReportXPEarned", "total")
		local problem = ns.XPTotalProblem(total)
		if problem then
			error(problem, 2)
		end
		local mode = projections:Mode()
		if mode == "replay" or mode == "rebuild" then
			error(("M:ReportXPEarned can't report from a projection's %s: report from its done"):format(mode), 2)
		end
		activityXP:Report(module.def.name, total, projections:LiveEntry())
	end
end
