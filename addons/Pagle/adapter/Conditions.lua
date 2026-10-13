---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core never creates the Pagle global (CORE-R4), so there is nothing to publish on.
---@class Pagle
local Pagle = _G.Pagle
if not Pagle then
	return
end

--- Whether a snapshot meets a condition spec (LOG-R48). Takes a live snapshot (`Pagle.GetConditions()`) or a Cast's
--- (`cast.conditions`), and raises an error in the caller for an invalid spec (LOG-R49).
Pagle.MatchesConditions = ns.MatchesConditions
