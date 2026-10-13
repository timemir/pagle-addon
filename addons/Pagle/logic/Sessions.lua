---@class PagleNS
local ns = select(2, ...)

-- Sessions (LOG-R60–R64, LOG-R98): pure logic, fed the Catch log's records in seq order (CORE-R7). Sessions are cut
-- from the log whenever they're needed and never stored in it (LOG-R61); the cutter here is the one function that
-- does it, for the session tag on every record Core hands out and for the live Session events alike.

--- Consecutive Casts this many seconds apart, or more, are in different Sessions (Tunables: Session gap).
ns.SESSION_GAP = 900
--- Changes whenever the Session rule changes; Modules that store Sessions fold it into their rules version (LOG-R61).
ns.SESSION_RULES_VERSION = 1

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
