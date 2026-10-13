---@class PagleNS
local ns = select(2, ...)

--- Work that waits while Pagle is restricted, run in the order it was queued (CORE-R32).
---@class PagleWorkQueue
---@field private items fun()[]
local WorkQueue = {}
WorkQueue.__index = WorkQueue

---@return PagleWorkQueue
function ns.NewWorkQueue()
	return setmetatable({ items = {} }, WorkQueue)
end

---@param work fun()
function WorkQueue:Push(work)
	self.items[#self.items + 1] = work
end

--- Hands each queued piece of work to `run`, in order, and empties the queue. Work queued meanwhile runs last.
---@param run fun(work: fun()) How to call it, e.g. `securecallfunction`, so one failure doesn't stop the rest.
function WorkQueue:Drain(run)
	while #self.items > 0 do
		local items = self.items
		self.items = {}
		for _, work in ipairs(items) do
			run(work)
		end
	end
end
