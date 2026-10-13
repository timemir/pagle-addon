---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4), so there is nothing to hang the bus on.
if not Pagle then
	return
end
local Pagle = Pagle

--- An event Core fires on its bus. Each topic adds its own; payloads are on the handler aliases.
---@alias PagleEvent
---| "RestrictionChanged" # PagleRestrictionChangedHandler
---| "SkillChanged" # PagleSkillChangedHandler
---| "ConditionsChanged" # PagleConditionsChangedHandler
---| "CastStarted" # PagleCastStartedHandler
---| "Catch" # PagleCatchHandler
---| "CastEnded" # PagleCastEndedHandler
---| "FishingStateChanged" # PagleFishingStateChangedHandler
---| "BalanceChanged" # PagleBalanceChangedHandler
---| "SessionStarted" # PagleSessionStartedHandler
---| "SessionEnded" # PagleSessionEndedHandler
---| string

---@class Pagle
--- Adds a listener for a Core event (CORE-R20). It's called with `(event, ...)`, through `securecallfunction`, so its
--- errors go to `geterrorhandler()` and the other listeners still run (CORE-R21). One listener per owner and event:
--- registering again replaces it.
---@field RegisterCallback fun(owner: table|string, event: PagleEvent, fn: fun(event: string, ...: any))
--- Removes `owner`'s listener for `event` (CORE-R20).
---@field UnregisterCallback fun(owner: table|string, event: PagleEvent)
--- Removes every listener `owner` added (CORE-R20).
---@field UnregisterAllCallbacks fun(owner: table|string)

-- The registry's Fire stays here: only Core fires events on Pagle (CORE-R22).
local registry =
	LibStub("CallbackHandler-1.0"):New(Pagle, "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")

--- Fires `event` on Core's bus with `...` as its payload, each secret value in it replaced by nil (CORE-R31).
--- Core alone calls it (CORE-R22).
---@param event PagleEvent
---@param ... any
function ns.Fire(event, ...)
	registry:Fire(event, ns.StripSecrets(issecretvalue, ...))
end
