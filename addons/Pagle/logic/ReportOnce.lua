---@class PagleNS
local ns = select(2, ...)

--- Which failures have been reported this login: each owner and event gets one report (CORE-R23).
---@class PagleReportOnce
---@field private reported table<any, table<string, true>> owner -> event -> true
local ReportOnce = {}
ReportOnce.__index = ReportOnce

--- A record with nothing reported yet. It lives in memory only, so each login starts afresh.
---@return PagleReportOnce
function ns.NewReportOnce()
	return setmetatable({ reported = {} }, ReportOnce)
end

--- Whether this is the first failure of `owner` and `event` this login, so it should be reported. Marks it reported.
---@param owner any
---@param event string
---@return boolean
function ReportOnce:First(owner, event)
	local events = self.reported[owner]
	if not events then
		events = {}
		self.reported[owner] = events
	end
	if events[event] then
		return false
	end
	events[event] = true
	return true
end
