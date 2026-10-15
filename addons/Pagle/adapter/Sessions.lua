---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Sessions on the client (LOG-R60–R64): logic/Sessions.lua's tracker over the Catch log, on the server time, with a
-- C_Timer for the 300 s after each Cast, as logic/Wiring.lua wires it. The session tag itself is the Catch log's
-- (logic/CatchLog.lua), so every record Core hands out carries it (LOG-R98).

--- Payload of `SessionStarted`: the Session a Cast just opened, already counting it (LOG-R62).
---@alias PagleSessionStartedHandler fun(event: "SessionStarted", session: PagleSession)
--- Payload of `SessionEnded`: the Session that ended, with `whileAway` when it ended while logged out (LOG-R62,
--- LOG-R63).
---@alias PagleSessionEndedHandler fun(event: "SessionEnded", session: PagleSession)

--- Changes whenever the Session rule changes; a Module that stores Sessions folds it into its rules version (LOG-R61).
Pagle.SESSION_RULES_VERSION = ns.SESSION_RULES_VERSION

--- The Session gap in seconds (LOG-R60): two Casts this far apart or more are in different Sessions. Modules that
--- need it read this one rather than keep a copy (LOG-R61).
Pagle.SESSION_GAP = ns.SESSION_GAP

--- Core's Sessions, as ns.sessions: logic/Wiring.lua's, over adapter/Host.lua's host. Login step 1 opens them
--- (ns.sessions:Open, LOG-R63); adapter/Fishing.lua calls ns.sessions:Cast right after each Cast's append, before
--- the projections get it (LOG-R9 step 3).
ns.WireSessions(ns.host)

--- The Session open now, while its last Cast is under 300 s ago, else nil (LOG-R64). A fresh copy each call.
---@return PagleSession?
function Pagle.GetSession()
	return ns.sessions:Get()
end
