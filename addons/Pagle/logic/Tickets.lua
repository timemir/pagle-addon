---@class PagleNS
local ns = select(2, ...)

-- Core's Refresh purse (ADR 0017, core/refresh.md): each Module's last reported lifetime Refreshes earned and spent,
-- tied to the log's logId, and what is left. Pure logic, everything passed in (CORE-R7); logic/Wiring.lua binds it to
-- PagleDB.global.tickets. Core pays and spends none itself (REF-R1). The name "Refresh" is provisional (CONTEXT.md),
-- so the code says "tickets" and a rename is a glossary and string change.

--- What `Pagle.GetTickets()` returns and `TicketsChanged` carries (refresh.md › Contracts).
---@class PagleTickets
---@field tickets integer  -- Refreshes held: max(0, earned - spent) (REF-R5)
---@field earned integer   -- the sum of every Module's last reported total earned
---@field spent integer    -- the sum of every Module's last reported total spent

--- Fires whenever any field of the Tickets changes (REF-R6).
---@alias PagleTicketsChangedHandler fun(event: "TicketsChanged", tickets: PagleTickets)

--- Why `total` can't be a Module's lifetime Refreshes earned or spent, or nil if it can: a whole number, 0 or more
--- (REF-R2). `method` is the report's name, `"ReportTicketsEarned"` or `"ReportTicketsSpent"`, for the message.
---@param total any
---@param method string
---@return string?
function ns.TicketTotalProblem(total, method)
	if type(total) ~= "number" or total ~= total or total < 0 or total ~= math.floor(total) or total == math.huge then
		return ("M:%s takes a whole number of Refreshes, 0 or more; got %s"):format(method, tostring(total))
	end
	return nil
end

--- What the purse reads from where Core runs. Every function is called when needed.
---@class PagleTicketsOptions
---@field fire fun(event: "TicketsChanged", tickets: PagleTickets) fires TicketsChanged on Core's bus
---@field logId fun(): string? PagleLog.logId now

--- The stored totals (PagleDB.global.tickets): per Module, by def.name, and the log they belong to (REF-R3).
---@class PagleTicketStore: PagleLoggedTotals
---@field spent table<string, integer>

---@class PagleTicketPurse
---@field private options PagleTicketsOptions
---@field private store PagleTicketStore
local Tickets = {}
Tickets.__index = Tickets

--- A purse with nothing stored, until `Open` hands it PagleDB's store.
---@param options PagleTicketsOptions
---@return PagleTicketPurse
function ns.NewTickets(options)
	return setmetatable({ options = options, store = { earned = {}, spent = {} } }, Tickets)
end

--- Login step 1, once PagleDB is open: ties `store` (PagleDB.global.tickets) to the log (ns.TieTotalsToLog), then
--- reads and writes it in place from now on. A total stays until its Module reports another, so a disabled or
--- uninstalled Module's still counts (REF-R3, REF-R90).
---@param store PagleTicketStore
function Tickets:Open(store)
	ns.TieTotalsToLog(store, self.options.logId())
	self.store = store
end

--- `Pagle.GetTickets()` (REF-R5, REF-R6): the Refreshes held and the two sums, a fresh table each call.
---@return PagleTickets
function Tickets:Get()
	local earned, spent = 0, 0
	for _, total in pairs(self.store.earned) do
		earned = earned + total
	end
	for _, total in pairs(self.store.spent) do
		spent = spent + total
	end
	return { tickets = math.max(earned - spent, 0), earned = earned, spent = spent }
end

-- Stores `total` as the Module's in `kind` ("earned" or "spent"), under the log's logId now, and fires
-- `TicketsChanged` if that changes any field of the Tickets (REF-R2–R4, REF-R6).
---@param kind "earned"|"spent"
---@param name string
---@param total integer
function Tickets:Report(kind, name, total)
	local store = self.store
	-- A fresh log gets its logId at PLAYER_LOGIN (LOG-R15), after ADDON_LOADED tied the store: these totals are its.
	store.logId = self.options.logId()
	local before = self:Get()
	store[kind][name] = total
	local after = self:Get()
	if after.tickets ~= before.tickets or after.earned ~= before.earned or after.spent ~= before.spent then
		self.options.fire("TicketsChanged", after)
	end
end

--- Stores a Module's lifetime Refreshes earned, taken as given. Only a later, lower report lowers a total (REF-R4).
--- The caller checks it with ns.TicketTotalProblem.
---@param name string the Module's def.name
---@param total integer
function Tickets:ReportEarned(name, total)
	self:Report("earned", name, total)
end

--- Stores a Module's lifetime Refreshes spent, taken as given (REF-R4). The caller checks it with
--- ns.TicketTotalProblem.
---@param name string the Module's def.name
---@param total integer
function Tickets:ReportSpent(name, total)
	self:Report("spent", name, total)
end

--- `M:ReportTicketsEarned(total)` and `M:ReportTicketsSpent(total)` over `tickets` (REF-R2), so Core's adapter and
--- FakePagle publish one method each: an error at the Module's call, storing nothing, for anything but a whole number
--- of Refreshes, 0 or more. Like ReportCoinsEarned, a report is the Module's to time (from its done and after a live
--- entry); Core does not police the mode.
---@param registry PagleModuleRegistry
---@param tickets PagleTicketPurse
---@param kind "earned"|"spent"
---@return fun(self: PagleModuleHandle, total: integer)
function ns.ReportTicketsMethod(registry, tickets, kind)
	local method = kind == "earned" and "ReportTicketsEarned" or "ReportTicketsSpent"
	return function(self, total)
		local module = registry:ModuleCalling(self, method, "total")
		local problem = ns.TicketTotalProblem(total, method)
		if problem then
			error(problem, 2)
		end
		tickets:Report(kind, module.def.name, total)
	end
end
