---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

--- When a condition spec's time-based fields next hold (LOG-R50): `{ openNow = true, closesAt? }`,
--- `{ opensAt, closesAt? }` within 400 days, `{ onDemand = true }`, `{ always = true }` or nil, each with
--- `confirmed`. Times are server times. The realm's UTC offset comes from the realm clock (LOG-R49) and the events
--- open now from the live calendar (LOG-R46), both read on each call. The calendar counts at the call's own time
--- only, whatever `fromTime` is: every other event opening, before or after now, comes from the catalogue's weekly
--- rules alone. While the realm clock is secret, a spec with `time`, `season` or `events` gives
--- nil, as the offset can't be read then; one without them is still answered. Nothing is cached or polled: callers
--- pass now and call again when they redraw. A new table each call, shared and never changed once handed out
--- (CORE-R18).
---@param spec PagleConditionSpec|PagleWindowSpec
---@param fromTime integer server time to forecast from
---@return Window?
function Pagle.NextWindow(spec, fromTime)
	return ns.ForecastWindow(spec, fromTime, ns.TakeForecastSnapshot(), ns.Catalogue.GetEventRule)
end
