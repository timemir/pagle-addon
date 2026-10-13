---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Sessions on the client (LOG-R60–R64): logic/Sessions.lua's tracker over the Catch log, on the server time, with a
-- C_Timer for the 900 s after each Cast. The session tag itself is the Catch log's (logic/CatchLog.lua), so every
-- record Core hands out carries it (LOG-R98).

--- Payload of `SessionStarted`: the Session a Cast just opened, already counting it (LOG-R62).
---@alias PagleSessionStartedHandler fun(event: "SessionStarted", session: PagleSession)
--- Payload of `SessionEnded`: the Session that ended, with `whileAway` when it ended while logged out (LOG-R62,
--- LOG-R63).
---@alias PagleSessionEndedHandler fun(event: "SessionEnded", session: PagleSession)

--- Changes whenever the Session rule changes; a Module that stores Sessions folds it into its rules version (LOG-R61).
Pagle.SESSION_RULES_VERSION = ns.SESSION_RULES_VERSION

---@type PagleSessionTracker?
local tracker

-- Each wait started bumps this, so only the latest one's timer calls Tick.
local waits = 0

-- Calls Tick `seconds` from now, unless a later wait replaces it; nothing for nil.
---@param seconds integer?
local function waitFor(seconds)
	waits = waits + 1
	local wait = waits
	if seconds then
		C_Timer.After(seconds, function()
			if wait == waits and tracker then
				waitFor(tracker:Tick(GetServerTime()))
			end
		end)
	end
end

--- Login step 1 (LOG-R1), once the Catch log and PagleDB are open: notes the latest Session (LOG-R63). One still
--- open ends 900 s after its last Cast; one that ended while away gets its SessionEnded once no projection is
--- updating, unless a Cast fires it first.
function ns.OpenSessions()
	tracker = ns.NewSessionTracker({ catchLog = ns.catchLog, global = ns.db.global, fire = ns.Fire })
	waitFor(tracker:Start(GetServerTime()))
	ns.projections:WhenIdle(function()
		tracker:Idle()
	end)
end

--- LOG-R9 step 3, right after a Cast's entry is appended and before the projections get it: any SessionEnded still
--- due, then SessionStarted if the Cast opened a Session (LOG-R62, LOG-R63).
function ns.SessionCast()
	if tracker then
		waitFor(tracker:Cast())
	end
end

--- The Session open now, while its last Cast is under 900 s ago, else nil (LOG-R64). A fresh copy each call.
---@return PagleSession?
function Pagle.GetSession()
	return tracker and tracker:Get(GetServerTime())
end
