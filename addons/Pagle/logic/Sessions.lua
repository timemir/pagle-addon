---@class PagleNS
local ns = select(2, ...)

-- Sessions (LOG-R60–R64, LOG-R98): pure logic, fed the Catch log's records in seq order (CORE-R7). Sessions are cut
-- from the log whenever they're needed and never stored in it (LOG-R61); the cutter here is the one function that
-- does it, for the session tag on every record Core hands out and for the live Session events alike.

--- Consecutive Casts this many seconds apart, or more, are in different Sessions (Tunables: Session gap).
ns.SESSION_GAP = 300
--- Changes whenever the Session rule changes; Modules that store Sessions fold it into their rules version (LOG-R61).
ns.SESSION_RULES_VERSION = 2

--- A Session, as `SessionStarted`, `SessionEnded` and `Pagle.GetSession` hand it out (catch-log.md › Events).
---@class PagleSession
---@field id string             -- the entry ID of its first Cast
---@field startTime integer     -- its first Cast's time
---@field endTime integer       -- its last Cast's time (LOG-R62)
---@field firstSeq integer
---@field lastSeq integer
---@field casts integer
---@field catches integer       -- Catches (items), not quantities (LOG-R64)
---@field gotAway integer
---@field characters integer[]  -- character indices, in the order they first cast in it
---@field zones integer[]       -- zone areaIDs (not subzones), without 0, in the order first fished (LOG-R64)
---@field whileAway? boolean    -- on the SessionEnded fired at login for a Session that ended while away (LOG-R63)

--- The Session a cutter is in, as it builds it: a PagleSession plus the sets behind its lists.
---@class PagleSessionCut : PagleSession
---@field package seenCharacters table<integer, true>
---@field package seenZones table<integer, true>

--- Cuts Sessions from records fed in seq order (LOG-R60) and tags each Cast and Skill Reading with its Session's ID
--- (LOG-R98).
---@class PagleSessionCutter
---@field package session PagleSessionCut? -- the latest Session fed so far, open or not
local Cutter = {}
Cutter.__index = Cutter

---@return PagleSessionCutter
function ns.NewSessionCutter()
	return setmetatable({}, Cutter)
end

-- A Session that `cast` opens.
---@param cast PagleCast
---@return PagleSessionCut
local function open(cast)
	return {
		id = cast.id,
		startTime = cast.time,
		endTime = cast.time,
		firstSeq = cast.seq,
		lastSeq = cast.seq,
		casts = 0,
		catches = 0,
		gotAway = 0,
		characters = {},
		zones = {},
		seenCharacters = {},
		seenZones = {},
	}
end

-- Counts `cast` into `session` (LOG-R64).
---@param session PagleSessionCut
---@param cast PagleCast
local function count(session, cast)
	session.endTime, session.lastSeq = cast.time, cast.seq
	session.casts = session.casts + 1
	session.catches = session.catches + #cast.items
	if cast.outcome == "gotAway" then
		session.gotAway = session.gotAway + 1
	end
	if not session.seenCharacters[cast.char] then
		session.seenCharacters[cast.char] = true
		session.characters[#session.characters + 1] = cast.char
	end
	local zone = cast.conditions.zone
	if zone ~= 0 and not session.seenZones[zone] then
		session.seenZones[zone] = true
		session.zones[#session.zones + 1] = zone
	end
end

--- Feeds the next record (LOG-R60, LOG-R98). A Cast less than the gap after the previous Cast, by entry time, joins
--- its Session; otherwise it opens a new one. A Skill Reading belongs to the Session whose last Cast is less than
--- the gap before it, else to none. Sets `record.session`; other kinds are passed over.
---@param record PagleRecord
function Cutter:Add(record)
	local session = self.session
	if record.kind == "cast" then
		---@cast record PagleCast
		if not session or record.time - session.endTime >= ns.SESSION_GAP then
			session = open(record)
			self.session = session
		end
		count(session, record)
		record.session = session.id
	elseif record.kind == "skill" and session and record.time - session.endTime < ns.SESSION_GAP then
		---@cast record PagleSkillReading
		record.session = session.id
	end
end

--- A cutter that goes on from where this one is, sharing nothing with it.
---@return PagleSessionCutter
function Cutter:Copy()
	local copy = ns.NewSessionCutter()
	local session = self.session
	if session then
		local cut = {}
		for key, value in pairs(session) do
			cut[key] = value
		end
		for _, list in ipairs({ "characters", "zones", "seenCharacters", "seenZones" }) do
			cut[list] = {}
			for key, value in pairs(session[list]) do
				cut[list][key] = value
			end
		end
		copy.session = cut
	end
	return copy
end

--- The latest Session fed so far, open or ended, or nil before the first Cast. It is the cutter's own table, which
--- changes as Casts join it: copy it (ns.SessionPayload) before handing it out.
---@return PagleSessionCut?
function Cutter:Session()
	return self.session
end

--- Where a Session in progress starts (LOG-R98): `reverseCasts` yields the log's Casts from some point back to the
--- first, newest first. Returns the seq of the first Cast of the newest one's Session, or nil if it yields none.
--- Feeding a cutter from there gets every later record the same tag as reading the log from seq 0.
---@param reverseCasts fun(): PagleCast?
---@return integer?
function ns.SessionStartSeq(reverseCasts)
	local first = reverseCasts()
	if not first then
		return nil
	end
	for cast in reverseCasts do
		if first.time - cast.time >= ns.SESSION_GAP then
			break
		end
		first = cast
	end
	return first.seq
end

--- What the Session tracker is fed.
---@class PagleSessionTrackerOptions
---@field catchLog PagleCatchLog                       -- its latest Session is the one the events are about
---@field global table                                 -- PagleDB.global, which keeps lastEndedSession (LOG-R63)
---@field fire fun(event: "SessionStarted"|"SessionEnded", session: PagleSession)

--- The live Session events (LOG-R62, LOG-R63) and the Session open now (LOG-R64), over the Catch log's latest
--- Session. Core feeds it the server time; when to call Tick is the adapter's timer.
---@class PagleSessionTracker
---@field package options PagleSessionTrackerOptions
---@field package session PagleSession? -- the latest Session the tracker has seen
---@field package ended boolean         -- SessionEnded has fired for it, or had before login
---@field package away boolean          -- it ended while logged out and its SessionEnded is still to fire
local Tracker = {}
Tracker.__index = Tracker

---@param options PagleSessionTrackerOptions
---@return PagleSessionTracker
function ns.NewSessionTracker(options)
	return setmetatable({ options = options, ended = true, away = false }, Tracker)
end

-- Seconds until `session`'s gap has passed at `now`; 0 or less once it has.
---@param session PagleSession
---@param now integer
---@return integer
local function remaining(session, now)
	return ns.SESSION_GAP - (now - session.endTime)
end

-- Fires SessionEnded for the tracker's Session and notes it in lastEndedSession (LOG-R63).
---@param tracker PagleSessionTracker
local function fireEnded(tracker)
	local session = tracker.session --[[@as PagleSession]]
	local whileAway = tracker.away or nil
	tracker.ended, tracker.away = true, false
	tracker.options.global.lastEndedSession = session.id
	tracker.options.fire("SessionEnded", ns.SessionPayload(session, whileAway))
end

--- At login (LOG-R63): notes the log's latest Session. One that ended 300 s or more before `now` and isn't
--- `lastEndedSession` gets its SessionEnded, with `whileAway`, at Idle or at the next Cast, whichever comes first.
--- Returns the seconds until a Session still open ends (call Tick then), else nil.
---@param now integer server time
---@return integer?
function Tracker:Start(now)
	local session = self.options.catchLog:Session()
	self.session = session
	if not session then
		return nil
	end
	local wait = remaining(session, now)
	if wait > 0 and session.id == self.options.global.lastEndedSession then
		-- Still within the gap, yet already ended: `/pagle dev endsession` ended it early (EndNow).
		self.ended, self.away = true, false
		return nil
	elseif wait > 0 then
		self.ended, self.away = false, false
		return wait
	end
	self.away = session.id ~= self.options.global.lastEndedSession
	self.ended = not self.away
	return nil
end

--- LOG-R9 step 3, right after a Cast's entry is appended: fires any SessionEnded still due for the previous
--- Session, then SessionStarted if this Cast opened a new one, counting it (LOG-R62, LOG-R63). Returns the seconds
--- until this Session ends (call Tick then).
---@return integer
function Tracker:Cast()
	local session = self.options.catchLog:Session() --[[@as PagleSession]]
	if session.id ~= (self.session and self.session.id) then
		if self.session and not self.ended then
			fireEnded(self)
		end
		self.session, self.ended, self.away = session, false, false
		self.options.fire("SessionStarted", ns.SessionPayload(session))
	elseif self.ended then
		-- A Session ended early (EndNow) that this Cast still joins in the log (LOG-R60): it opens again.
		self.session, self.ended = session, false
		self.options.fire("SessionStarted", ns.SessionPayload(session))
	end
	return ns.SESSION_GAP
end

--- Fires SessionEnded for the Session open while logged in once 300 s have passed since its last Cast (LOG-R62).
--- Returns the seconds still to wait if they haven't, else nil.
---@param now integer server time
---@return integer?
function Tracker:Tick(now)
	if not self.session or self.ended or self.away then
		return nil
	end
	local wait = remaining(self.session, now)
	if wait > 0 then
		return wait
	end
	fireEnded(self)
	return nil
end

--- `/pagle dev endsession` (#247): ends the Session open at `now` as if its gap had passed (LOG-R62), firing
--- SessionEnded and noting it in lastEndedSession. The log is untouched, so a later Cast that the gap still puts in
--- this Session opens it again (Cast), and a reload within the gap finds it ended (Start). Returns false, firing
--- nothing, when no Session is open.
---@param now integer server time
---@return boolean ended
function Tracker:EndNow(now)
	local session = self.session
	if not session or self.ended or self.away or remaining(session, now) <= 0 then
		return false
	end
	fireEnded(self)
	return true
end

--- Once no projection is updating (LOG-R63): fires the SessionEnded due since login, if no Cast has fired it yet.
function Tracker:Idle()
	if self.away then
		fireEnded(self)
	end
end

--- The Session open at `now`, its last Cast under 300 s before, as a fresh copy; else nil (LOG-R64).
---@param now integer server time
---@return PagleSession?
function Tracker:Get(now)
	local session = self.options.catchLog:Session()
	local endedEarly = self.ended and session and self.session and session.id == self.session.id
	if session and not endedEarly and remaining(session, now) > 0 then
		return ns.SessionPayload(session)
	end
	return nil
end

--- A fresh copy of `session` to hand out (catch-log.md › Events), with `whileAway` if given.
---@param session PagleSession
---@param whileAway true?
---@return PagleSession
function ns.SessionPayload(session, whileAway)
	return {
		id = session.id,
		startTime = session.startTime,
		endTime = session.endTime,
		firstSeq = session.firstSeq,
		lastSeq = session.lastSeq,
		casts = session.casts,
		catches = session.catches,
		gotAway = session.gotAway,
		characters = { unpack(session.characters) },
		zones = { unpack(session.zones) },
		whileAway = whileAway,
	}
end
