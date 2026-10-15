if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The live tracker's lines (STA-R81–R83, STA-R85; stats.md › UI › Live tracker): whether it shows, its header, this
-- Session's two lines and each watch's line, as data for the tracker block (adapter/TrackerBlock.lua), and each watch's
-- hover. Pure logic: the setting, the projection's state, Core's Session, the watches, the live skill and the server
-- time come in as arguments (CORE-R7); adapter/Tracker.lua docks the block and draws what these return.

--- What the tracker is drawn from, read at each draw.
---@class StatsTrackerInput
---@field on boolean               -- "Show the live tracker", PagleStatsDB.profile.tracker (STA-R81)
---@field state StatsState         -- the projection's state, ns.State()
---@field live PagleSession?       -- `Pagle.GetSession()`: Core's Session while one is open (STA-R32)
---@field watched StatsWatch[]     -- the watches, oldest first (STA-R60)
---@field updating boolean         -- whether the projection is updating (STA-R85)
---@field skill integer?           -- the live effective skill, nil when unknown (STA-R41)
---@field now integer              -- the server time
---@field places StatsPlaceTables? -- ns.places by default

--- The tracker as drawn now.
---@class StatsTrackerView
---@field shown boolean            -- STA-R81
---@field lines StatsTrackerLine[] -- top to bottom (STA-R82); a watch's line carries its `item` and `area`
---@field ticking boolean          -- a Session is current: the live-line tick runs (STA-R86)
---@field pending integer[]        -- watched items whose names the client hasn't loaded: ask, then redraw

-- The Session lines while one is current (STA-R82): "38 Casts · 31 Catches · 7 got away", then, from Stats' own
-- record, "{per hour} per hour · skill +{gained}". While the projection is updating, or has no record of Core's Session
-- yet, they come from Core's Session alone, with no per-hour or skill line (STA-R32, STA-R85).
---@param input StatsTrackerInput
---@param lines StatsTrackerLine[]
local function sessionLines(input, lines)
	local L, live = ns.L, input.live --[[@as PagleSession]]
	local shown = not input.updating and ns.CurrentSession(input.state.sessions, live) or nil
	local record = shown and shown.kind == "current" and shown.record or nil
	local session = record or live ---@type StatsSession|PagleSession
	lines[1].right = L.TRACKER_SESSION:format(ns.Duration(ns.TimeFished(session, input.now)))
	lines[#lines + 1] = {
		kind = "line",
		text = L.TRACKER_COUNTS:format(
			ns.Count(session.casts, "Casts"),
			ns.Count(session.catches, "Catches"),
			ns.Number(session.gotAway)
		),
	}
	if record then
		lines[#lines + 1] = {
			kind = "line",
			text = L.TRACKER_PER_HOUR:format(ns.Number(ns.CatchesPerHour(record, input.now)), ns.Number(record.skill)),
			dim = true,
		}
	end
end

-- A watch's line (STA-R82, STA-R64): its reading on the reading side of the moment, a band dot (grey with no luck
-- reading), the item's name, its Dry spell count on the right, and below them the watched place's own name, the
-- window's name if any and the band word, or the short odds with no band. While the projection is updating it shows
-- its name, grey, with "updating" for its count and the place's name below (STA-R85).
---@param input StatsTrackerInput
---@param watch StatsWatch
---@param pending integer[]
---@return StatsTrackerLine
local function watchLine(input, watch, pending)
	local L = ns.L
	local name, _, loaded = ns.Item(watch.item)
	if not loaded then
		pending[#pending + 1] = watch.item
	end
	local place = ns.AreaName(watch.area)
	local line = { kind = "watch", name = name, item = watch.item, area = watch.area } ---@type StatsTrackerLine
	if input.updating then
		line.count, line.sub = L.TRACKER_UPDATING, place
		return line
	end
	local reading = ns.Reading(input.state, watch.item, watch.area, input.skill, input.places)
	local band = ns.DrySpell(reading).band
	local sub = { place }
	if reading.windowName then
		sub[#sub + 1] = reading.windowName
	end
	sub[#sub + 1] = band and ns.BandWord(band) or ns.OddsShort(reading)
	line.band, line.count, line.sub = band, ns.DrySpellCount(reading), table.concat(sub, L.TRACKER_JOIN)
	return line
end

--- A watch's hover (STA-R83): the item's name for its title, then its Dry spell text (STA-R53's first sentence, "{since}
--- Casts since my last {item}.", and the luck wording, or STA-R50's or STA-R54's text), then the heading "Your odds"
--- (STA-R46) over its Your odds sentence for its state (the scope line when known, the learning or unseen sentence
--- otherwise) and STA-R46's extra sentences. While the projection is updating, only "Updating my records…"
--- (STA-R85), with no heading.
---@param input StatsTrackerInput the same as the tracker's (`on`, `live` and `watched` aren't read)
---@param watch StatsWatch
---@return string title
---@return string[] lines
---@return integer? heading the index in `lines` of the "Your odds" heading, which the hover draws as a heading
function ns.TrackerHover(input, watch)
	local name = ns.Item(watch.item)
	if input.updating then
		return name, { ns.L.BOOK_UPDATING }, nil
	end
	local reading = ns.Reading(input.state, watch.item, watch.area, input.skill, input.places)
	local first, after = ns.DrySpellText(reading, name)
	local lines = { first }
	if after then
		lines[2] = after
	end
	lines[#lines + 1] = ns.L.ODDS_HEADING
	local heading = #lines
	lines[#lines + 1] = ns.OddsSentence(reading)
	for _, note in ipairs(ns.OddsNotes(reading, input.places)) do
		lines[#lines + 1] = note
	end
	return name, lines, heading
end

--- The tracker's lines now (STA-R81, STA-R82, STA-R85): shown while on with a current Session or a watch; the header
--- "Stats" with "Session · 21m" or "no Session" on its right; during a current Session its two lines; then each watch,
--- oldest first.
---@param input StatsTrackerInput
---@return StatsTrackerView
function ns.TrackerLines(input)
	local L = ns.L
	local lines = { { kind = "header", text = L.TITLE, right = L.TRACKER_NO_SESSION } } ---@type StatsTrackerLine[]
	local current = input.live ~= nil
	if current then
		sessionLines(input, lines)
	end
	local pending = {}
	for _, watch in ipairs(input.watched) do
		lines[#lines + 1] = watchLine(input, watch, pending)
	end
	return {
		shown = input.on and (current or #input.watched > 0),
		lines = lines,
		ticking = current,
		pending = pending,
	}
end
