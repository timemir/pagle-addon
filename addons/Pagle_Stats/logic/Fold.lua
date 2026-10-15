if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Stats' one projection (STA-R20) and its fold (STA-R21): every Cast and Skill Reading counted into the state
-- stats.md › Projection state gives. Pure logic: the places rules over Core's catalogue lookups (ns.places, a
-- StatsPlaceTables) come in as arguments (CORE-R7). The fold is the same in every mode and raises nothing (STA-R2);
-- secret values count as unknowns (STA-R93): zone 0 is no place, an unknown skill is side `na`, item 0 a Catch with no
-- hit, index entry or place item.

--- Rises with any change to what the fold counts or how: sides, windows, the no-junk margin, the margin buckets, the
--- Session record (STA-R20, Tunables). Never with a display-time value.
ns.STATS_RULES_VERSION = 1

--- The projection's rules version (STA-R20): `100 × STATS_RULES_VERSION + Pagle.SESSION_RULES_VERSION`, so a change
--- to either rebuilds (LOG-R72).
---@param sessionRulesVersion integer Pagle.SESSION_RULES_VERSION
---@return integer
function ns.RulesVersion(sessionRulesVersion)
	return 100 * ns.STATS_RULES_VERSION + sessionRulesVersion
end

-- New counts (StatsCounts): no Casts, Catches or got away.
---@return StatsCounts
local function newCounts()
	return { casts = 0, catches = 0, gotAway = 0 }
end

--- A new, empty projection state (stats.md › Projection state): no Casts, the four margin buckets at 0.
---@return StatsState
function ns.NewStatsState()
	local function margin()
		return { casts = 0, gotAway = 0 }
	end
	return {
		totals = newCounts(),
		places = {},
		chars = {},
		scopes = {},
		hits = {},
		items = {},
		margins = { lo50 = margin(), lo1 = margin(), hi0 = margin(), hi25 = margin() },
		lastRank = {},
		sessions = {},
	}
end

--- A scope's key in the state's `scopes` (STA-R23): "<area>:<side>", or "<area>:<side>:<window>" for a window scope.
---@param area integer
---@param side StatsSide
---@param window string?
---@return string
function ns.ScopeKey(area, side, window)
	local scope = area .. ":" .. side
	return window and (scope .. ":" .. window) or scope
end

--- A hit's key in the state's `hits` (STA-R24): "<scope>#<itemID>".
---@param scope string a ns.ScopeKey
---@param itemID integer
---@return string
function ns.HitKey(scope, itemID)
	return scope .. "#" .. itemID
end

--- A skill margin's bucket (STA-R26, Tunables): `lo50` 50 or more below the line, `lo1` 1–49 below, `hi0` 0–24 above,
--- `hi25` 25 or more above.
---@param margin integer effective skill minus the no-junk line
---@return "lo50"|"lo1"|"hi0"|"hi25"
function ns.MarginBucket(margin)
	if margin <= -50 then
		return "lo50"
	elseif margin < 0 then
		return "lo1"
	elseif margin < 25 then
		return "hi0"
	end
	return "hi25"
end

-- Adds one Cast to a counter (STA-R22): 1 to `casts`, its entries to `catches`, 1 to `gotAway` if it got away.
---@param counts StatsCounts
---@param entries integer the Cast's entries in `items`, item 0 included
---@param gotAway boolean
local function count(counts, entries, gotAway)
	counts.casts = counts.casts + 1
	counts.catches = counts.catches + entries
	if gotAway then
		counts.gotAway = counts.gotAway + 1
	end
end

-- Adds 1 to `map[key]`, from 0.
---@param map table
---@param key any
local function add(map, key)
	map[key] = (map[key] or 0) + 1
end

-- Counts a Cast into its Session's record (STA-R30): the last record when its `session` is that record's `id`,
-- else a new one. A Cast without a `session` (Core always sets one, LOG-R98) goes into none.
---@param sessions StatsSession[]
---@param cast PagleCast
---@param entries integer
---@param gotAway boolean
local function countSession(sessions, cast, entries, gotAway)
	local id = cast.session
	if id == nil then
		return
	end
	local record = sessions[#sessions]
	if not record or record.id ~= id then
		record = {
			id = id,
			startTime = cast.time,
			endTime = cast.time,
			casts = 0,
			catches = 0,
			gotAway = 0,
			chars = {},
			zones = {},
			items = {},
			skill = 0,
		}
		sessions[#sessions + 1] = record
	end
	record.endTime = cast.time
	count(record, entries, gotAway)
	add(record.chars, cast.char)
	local zone = cast.conditions.zone or 0
	if zone ~= 0 then
		add(record.zones, zone)
	end
	for _, item in ipairs(cast.items) do
		if item.itemID ~= 0 then
			add(record.items, item.itemID)
		end
	end
end

-- Folds one Cast (STA-R22–R26, STA-R30).
---@param state StatsState
---@param cast PagleCast
---@param places StatsPlaceTables
local function foldCast(state, cast, places)
	local conditions = cast.conditions
	local gotAway = cast.outcome == "gotAway"
	local entries, distinct, seen = 0, {}, {}
	for _, item in ipairs(cast.items) do
		entries = entries + 1
		local itemID = item.itemID
		if itemID ~= 0 and not seen[itemID] then
			seen[itemID] = true
			distinct[#distinct + 1] = itemID
		end
	end

	-- STA-R22: the totals, the character and each place.
	count(state.totals, entries, gotAway)
	local char = state.chars[cast.char]
	if not char then
		char = newCounts()
		state.chars[cast.char] = char
	end
	count(char, entries, gotAway)
	local zone = conditions.zone or 0
	local areas = ns.PlacesOf(conditions)
	for _, area in ipairs(areas) do
		local place = state.places[area]
		if not place then
			place = { zone = zone, casts = 0, catches = 0, gotAway = 0, items = {} }
			state.places[area] = place
		end
		count(place, entries, gotAway)
		for _, item in ipairs(cast.items) do
			if item.itemID ~= 0 then
				add(place.items, item.itemID)
			end
		end
	end

	-- STA-R25: each entry but item 0.
	for _, item in ipairs(cast.items) do
		local itemID = item.itemID
		if itemID ~= 0 then
			local total = state.items[itemID]
			if not total then
				total = { n = 0, first = cast.time, last = cast.time }
				state.items[itemID] = total
			end
			total.n = total.n + 1
			total.last = cast.time
		end
	end

	if #areas > 0 then
		-- One side for both places: the subzone uses its zone's line (STA-R12, STA-R13).
		local skill = ns.EffectiveSkill(conditions)
		local side = places:Side(zone, skill)
		local matched, isMatched = {}, {} -- the zone's windows that match the Cast (STA-R15, STA-R16), list and set
		for _, window in ipairs(places:ZoneWindows(zone)) do
			if places:InWindow(window, conditions) then
				matched[#matched + 1] = window
				isMatched[window] = true
			end
		end
		-- STA-R23: each place's side scope, and its window scopes for the zone's windows that match the Cast.
		for _, area in ipairs(areas) do
			add(state.scopes, ns.ScopeKey(area, side))
			for _, window in ipairs(matched) do
				add(state.scopes, ns.ScopeKey(area, side, window))
			end
		end
		-- STA-R24: after the scope counts, one hit per distinct item and place, in the item's scope there.
		for _, itemID in ipairs(distinct) do
			local window = places:ItemWindow(zone, itemID)
			if window == nil or isMatched[window] then
				for _, area in ipairs(areas) do
					local scope = ns.ScopeKey(area, side, window)
					local key = ns.HitKey(scope, itemID)
					local hit = state.hits[key]
					if not hit then
						hit = { n = 0, at = 0, last = 0 }
						state.hits[key] = hit
					end
					hit.n, hit.at, hit.last = hit.n + 1, state.scopes[scope], cast.time
				end
			end
		end
		-- STA-R26: with a line and a known effective skill.
		local line = places:NoJunkLine(zone)
		if line and skill then
			local margin = state.margins[ns.MarginBucket(skill - line)]
			margin.casts = margin.casts + 1
			if gotAway then
				margin.gotAway = margin.gotAway + 1
			end
		end
	end

	countSession(state.sessions, cast, entries, gotAway)
end

-- Folds one Skill Reading (STA-R27, STA-R31): a rise over the character's last reading adds to the last Session
-- record when the reading belongs to it; then the rank becomes the character's last. A first reading adds nothing.
-- Both of STA-R27's accepted inaccuracies follow from this as written: a reading with no `session` (taken before a
-- new Session's first Cast) credits no Session, and one taken inside an open Session credits it with whatever rose
-- since the last reading, wherever that was gained.
---@param state StatsState
---@param reading PagleSkillReading
local function foldSkill(state, reading)
	local c, rank = reading.char, reading.rank
	local last = state.lastRank[c]
	local record = state.sessions[#state.sessions]
	if last and rank > last and reading.session ~= nil and record and record.id == reading.session then
		record.skill = record.skill + rank - last
	end
	state.lastRank[c] = rank
end

--- The fold (STA-R21): what `apply` does to the state for one record. Casts and Skill Readings are counted; every
--- other kind is ignored. The same in every mode.
---@param state StatsState
---@param record PagleRecord
---@param places StatsPlaceTables the places rules over Core's catalogue (ns.places)
---@return boolean folded whether the record was a Cast or a Skill Reading, so the state changed
function ns.Fold(state, record, places)
	if record.kind == "cast" then
		---@cast record PagleCast
		foldCast(state, record, places)
		return true
	elseif record.kind == "skill" then
		---@cast record PagleSkillReading
		foldSkill(state, record)
		return true
	end
	return false
end

--- Stats' projection for Pagle's backend (#223, #76 item 5), whose projection driver folds the Catch log through
--- logic/ alone, without adapter/ or locale/ (CORE-R7). Makes the places rules (ns.places) and binds ns.ProjectionDef
--- with `M:NewProjection` over a table of its own making, as the adapter's OnInitialize does. Stats pays no Coins, so
--- it has no ns.CoinsEarned. The client's adapter never calls it.
---@param M PagleModuleHandle
---@return PagleProjection
function ns.BindProjections(M)
	-- The driver hands over only M, so Core comes from the Pagle API it hosts.
	local pagle = Pagle -- luacheck: read globals Pagle (#223: the backend's driver passes no Core)
	ns.places = ns.NewPlaceTables(pagle --[[@as StatsLookups]])
	return M:NewProjection(ns.ProjectionDef({}, ns.places, pagle.SESSION_RULES_VERSION))
end

---@class StatsJournalSession
---@field start integer       -- its first Cast's server time
---@field length integer      -- endTime − startTime, in seconds
---@field casts integer
---@field catches integer
---@field gotAway integer
---@field zones integer[]     -- its zones' areaIDs by Casts, most first (ns.ZonesByCasts)

--- Stats' Journal values for Pagle's backend (#223, the Angler page's Journal values), from a state alone:
--- - `stats`: lifetime time at the water in seconds, the got-away rate (0 with no Casts), the longest Session's start
---   and length and the best Catches per hour's Session start and rate, each nil with no such Session (STA-R33);
--- - `sessions`: the latest Sessions, newest first, at most `sessionRows` of them (STA-R30, STA-R33).
--- Not yet `odds`, Your odds and Dry spells per zone (STA-R40–R54).
---@param state StatsState
---@param sessionRows integer
---@return { stats: table, sessions: StatsJournalSession[] }
function ns.JournalValues(state, sessionRows)
	local sessions = state.sessions
	local stats = { time = ns.TimeAtTheWater(sessions), gotAwayRate = ns.GotAwayRate(state.totals) or 0 }
	local longest = ns.LongestSession(sessions)
	if longest then
		stats.longest = { start = longest.startTime, length = ns.TimeFished(longest) }
	end
	local best, rate = ns.BestCatchesPerHour(sessions)
	if best then
		stats.bestRate = { start = best.startTime, rate = rate }
	end
	local latest = {}
	for i = #sessions, math.max(1, #sessions - sessionRows + 1), -1 do
		local session = sessions[i]
		local zones = {}
		for n, zone in ipairs(ns.ZonesByCasts(session.zones)) do
			zones[n] = zone.zone
		end
		latest[#latest + 1] = {
			start = session.startTime,
			length = ns.TimeFished(session),
			casts = session.casts,
			catches = session.catches,
			gotAway = session.gotAway,
			zones = zones,
		}
	end
	return { stats = stats, sessions = latest }
end

--- Stats' projection def (STA-R20, LOG-R70), bound to `global.projection`, which it makes if missing: Core owns it
--- from here on. No `extraFingerprint`: a content change rebuilds through Core's fingerprint alone. Nothing is raised
--- in any mode (STA-R2): a live Cast or Skill Reading, and every done, only asks the views to redraw (ns.Redraw).
---@param global table PagleStatsDB's global section
---@param places StatsPlaceTables the places rules over Core's catalogue (ns.places)
---@param sessionRulesVersion integer Pagle.SESSION_RULES_VERSION
---@return PagleProjectionDef
function ns.ProjectionDef(global, places, sessionRulesVersion)
	if type(global.projection) ~= "table" then
		global.projection = {}
	end
	return {
		db = global.projection,
		rulesVersion = ns.RulesVersion(sessionRulesVersion),
		reset = ns.NewStatsState,
		apply = function(state, record, mode)
			if ns.Fold(state, record, places) and mode == "live" then
				ns.Redraw("projection")
			end
		end,
		done = function()
			ns.Redraw("projection")
		end,
	}
end
