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
--- open now from the live calendar (LOG-R46), both read on each call; later event openings come from the
--- catalogue's weekly rules. Nil while the realm clock is secret, as the offset can't be read then. Nothing is cached
--- or polled: callers pass now and call again when they redraw.
---@param spec PagleConditionSpec|PagleWindowSpec
---@param fromTime integer server time to forecast from
---@return Window?
function Pagle.NextWindow(spec, fromTime)
	local now = Pagle.GetConditions()
	if now.time == nil or now.minute == nil then
		return nil
	end
	local offset = ns.RealmUtcOffset(now.time, now.minute)
	return ns.NextWindow(spec, fromTime, offset, now.events, ns.Catalogue.GetEventRule)
end
