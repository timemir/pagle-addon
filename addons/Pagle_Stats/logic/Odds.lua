if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Your odds (stats.md › Your odds, STA-R40–R47): one item's reading in one place, computed when shown from the
-- projection's state and never stored (STA-R20). Every number comes from the Angler's own Casts: no rate is read from
-- the catalogue and there is no baseline (STA-R3). Pure logic: the state, the live skill and the place tables come
-- in as arguments (CORE-R7), so the exit reader can compute a reading outside the client.

--- The Cast threshold (stats.md › Tunables): Your odds is learning below it, and a subzone reading uses its zone's
--- scope until its own holds it (STA-R42, STA-R43).
ns.ODDS_THRESHOLD = 100
--- The never-caught bound (Tunables): the rule of three, so an unseen item is rarer than about 1 in n / 3.
ns.NEVER_CAUGHT_BOUND = 3

--- One item's reading in one place (STA-R40): the reading shape every view and the Dry spell read.
---@class StatsReading : StatsReadingCounts
---@field where string          -- "here", or "across {zone}" (STA-R46)
---@field windowName string?    -- the window's name (STA-R47), nil for none
---@field sideText string?      -- "at or above {line} skill" or "below {line} skill", nil for side `na` (STA-R46)

--- A reading without its words (ns.ReadingCounts): what the backend reads (#223).
---@class StatsReadingCounts
---@field item integer
---@field area integer          -- the reading's own place, a zone or subzone
---@field zone integer          -- its zone
---@field side StatsSide        -- the reading side (STA-R41)
---@field window string?        -- the item's window ID in the zone (STA-R14), nil for none
---@field scope string          -- the scope key the numbers come from (STA-R42)
---@field viaZone boolean       -- true when a subzone reading uses its zone's scope (STA-R42)
---@field n integer             -- the scope's Cast count
---@field k integer             -- the hit's n, 0 if none
---@field hit StatsHit?         -- the item's hit in the scope (STA-R24)
---@field state "learning"|"unseen"|"known"   -- STA-R43

-- The side scopes in STA-R41's tie order: the first of the largest wins.
local SIDES = { "hi", "lo", "na" }

--- A place's zone: its projection record's `zone` (STA-R22, which needs no catalogue), else the catalogue's, else the
--- place itself (a zone the catalogue lacks, never fished). Your odds and the home spread's watches read it.
---@param state StatsState
---@param area integer
---@param lookups StatsLookups
---@return integer
function ns.ZoneOf(state, area, lookups)
	local place = state.places[area]
	return place and place.zone or lookups.GetZoneOf(area) or area
end

--- The reading side (STA-R41): the live effective skill against the zone's line; with the live skill unknown, the
--- largest of the place's own side scopes, ties hi, lo, na; `na` with no line.
---@param state StatsState
---@param area integer the reading's own place
---@param live integer?
---@param line integer?
---@return StatsSide
local function readingSide(state, area, live, line)
	if line == nil or live ~= nil then
		return ns.SkillSide(live, line)
	end
	local best, most = "hi", -1
	for _, side in ipairs(SIDES) do
		local casts = state.scopes[ns.ScopeKey(area, side)] or 0
		if casts > most then
			best, most = side, casts
		end
	end
	return best
end

--- An item's reading in a place (STA-R40–R43): the reading side (STA-R41), the scope (STA-R42), its counts and its
--- state (STA-R43), and the words its sentences use (STA-R46, STA-R47).
---@param state StatsState the projection's state (ns.State())
---@param item integer
---@param area integer the reading's own place: the page's place, or a watch's `area`
---@param live integer? the live effective skill (STA-R11, ns.EffectiveSkill(Pagle.GetConditions())), nil when unknown
---@param places StatsPlaceTables? the place tables to read lines and windows from; `ns.places` if nil
---@return StatsReading
function ns.Reading(state, item, area, live, places)
	places = places or ns.places
	local reading = ns.ReadingCounts(state, item, area, live, places) --[[@as StatsReading]]
	local line = places:NoJunkLine(reading.zone)
	local L = ns.L
	if reading.side == "hi" then
		reading.sideText = L.ODDS_SIDE_HI:format(line)
	elseif reading.side == "lo" then
		reading.sideText = L.ODDS_SIDE_LO:format(line)
	end
	reading.where = reading.viaZone and L.ODDS_ACROSS:format(ns.AreaName(reading.zone)) or L.ODDS_HERE
	reading.windowName = reading.window and ns.WindowName(reading.window)
	return reading
end

--- An item's reading in a place without its words (STA-R40–R43): ns.Reading's side, scope, counts and state, with no
--- `where`, `windowName` or `sideText`. It reads no ns.L, so Pagle's backend reads it from logic/ alone (#223).
---@param state StatsState
---@param item integer
---@param area integer
---@param live integer?
---@param places StatsPlaceTables? `ns.places` if nil
---@return StatsReadingCounts
function ns.ReadingCounts(state, item, area, live, places)
	places = places or ns.places
	local zone = ns.ZoneOf(state, area, places.lookups)
	local line = places:NoJunkLine(zone)
	local side = readingSide(state, area, live, line)
	local window = places:ItemWindow(zone, item)
	local scope = ns.ScopeKey(area, side, window)
	-- STA-R42: a subzone uses its zone's scope, same side and window, until its own holds the threshold.
	local viaZone = area ~= zone and (state.scopes[scope] or 0) < ns.ODDS_THRESHOLD
	if viaZone then
		scope = ns.ScopeKey(zone, side, window)
	end
	local n = state.scopes[scope] or 0
	local hit = state.hits[ns.HitKey(scope, item)]
	local k = hit and hit.n or 0
	local odds = n < ns.ODDS_THRESHOLD and "learning" or k == 0 and "unseen" or "known"
	return {
		item = item,
		area = area,
		zone = zone,
		side = side,
		window = window,
		scope = scope,
		viaZone = viaZone,
		n = n,
		k = k,
		hit = hit,
		state = odds,
	}
end

--- A window's name by its ID (STA-R47): "by day", "by night", "in spring" … "in winter", "during its event" for
--- `event.<eventID>`, "in its window" for any other ID.
---@param windowID string
---@return string
function ns.WindowName(windowID)
	local names = ns.L.WINDOW_NAMES
	return names[windowID] or (windowID:find("^event%.") and names.event) or names.other
end

--- What a reading's numbers rest on, as its sentences say it (STA-R46): "{where}{ window}{, side}", e.g. "here by
--- night, at or above 300 skill".
---@param reading StatsReading
---@return string
local function restsOn(reading)
	local L, text = ns.L, reading.where
	if reading.windowName then
		text = L.ODDS_WITH_WINDOW:format(text, reading.windowName)
	end
	if reading.sideText then
		text = L.ODDS_WITH_SIDE:format(text, reading.sideText)
	end
	return text
end

--- Your odds in short (STA-R43), for rows, tiles, the tracker and the item page: "learning {n}/100", "not seen yet"
--- or "1 in {nice(n / k)}".
---@param reading StatsReading
---@return string
function ns.OddsShort(reading)
	local L = ns.L
	if reading.state == "learning" then
		return L.ODDS_LEARNING_SHORT:format(reading.n, ns.ODDS_THRESHOLD)
	elseif reading.state == "unseen" then
		return L.ODDS_UNSEEN
	end
	return L.ODDS_KNOWN_SHORT:format(ns.Nice(reading.n / reading.k))
end

--- Your odds in large ink on an item's entry (UI › Place spread): "Learning…", "not seen yet" or "about 1 in
--- {nice(n / k)}".
---@param reading StatsReading
---@return string
function ns.OddsHeadline(reading)
	local L = ns.L
	if reading.state == "learning" then
		return L.ODDS_LEARNING
	elseif reading.state == "unseen" then
		return L.ODDS_UNSEEN
	end
	return L.ODDS_KNOWN:format(ns.Nice(reading.n / reading.k))
end

--- The sentence under the headline (STA-R43, STA-R46, UI › Place spread): while learning "{n} of the 100 Casts I need
--- {where}{ window}{, side} before Your odds show a number."; unseen "In {n} Casts {where}{ window}{, side}: rarer than
--- about 1 in {nice(n / 3)}, if it bites here at all."; known, the scope line "From {n} of my Casts {where}{ window}{,
--- side}; {k} caught."
---@param reading StatsReading
---@return string
function ns.OddsSentence(reading)
	local L, n = ns.L, reading.n
	if reading.state == "learning" then
		return L.ODDS_LEARNING_SENTENCE:format(ns.Number(n), ns.ODDS_THRESHOLD, restsOn(reading))
	elseif reading.state == "unseen" then
		return L.ODDS_UNSEEN_SENTENCE:format(ns.Number(n), restsOn(reading), ns.Nice(n / ns.NEVER_CAUGHT_BOUND))
	end
	return L.ODDS_SCOPE_LINE:format(ns.Number(n), restsOn(reading), ns.Number(reading.k))
end

--- The confidence for the range (stats.md › Tunables): 95%, z = 1.96.
ns.ODDS_Z = 1.96

--- Wilson's score interval for `k` of `n` (STA-R45): with `p = k/n`, `d = 1 + z²/n`, `c = p + z²/(2n)` and
--- `r = z·√(p(1−p)/n + z²/(4n²))`, the bounds `(c − r)/d` and `(c + r)/d`.
---@param k integer
---@param n integer more than 0
---@return number lo
---@return number hi
function ns.Wilson(k, n)
	local z2 = ns.ODDS_Z * ns.ODDS_Z
	local p = k / n
	local d = 1 + z2 / n
	local c = p + z2 / (2 * n)
	local r = ns.ODDS_Z * math.sqrt(p * (1 - p) / n + z2 / (4 * n * n))
	return (c - r) / d, (c + r) / d
end

--- The range under a known reading's headline (STA-R45): "Likely between 1 in {nice(1/hi)} and 1 in {nice(1/lo)}
--- (95%).", or "Within rounding of 1 in {nice(n/k)} (95%)." when both ends round to the same text. Nil unless known.
---@param reading StatsReading
---@return string?
function ns.OddsRange(reading)
	if reading.state ~= "known" then
		return nil
	end
	local L = ns.L
	local lo, hi = ns.Wilson(reading.k, reading.n)
	local likelier, rarer = ns.Nice(1 / hi), ns.Nice(1 / lo)
	if likelier == rarer then
		return L.ODDS_RANGE_ROUNDING:format(ns.Nice(reading.n / reading.k))
	end
	return L.ODDS_RANGE:format(likelier, rarer)
end

--- Whether every catch entry behind an item's row in a place is unconfirmed (STA-R46): on a subzone, its entries in
--- the list its rows come from (its own, or its zone's own, STA-R17, a subzone the catalogue lacks included); on a
--- zone, every entry for it in `GetZoneCatches`. False with no entry: an *Also caught here* item gets no such sentence.
---@param item integer
---@param area integer
---@param zone integer the place's zone (ns.ZoneOf)
---@param lookups StatsLookups
---@return boolean
local function unconfirmedEntry(item, area, zone, lookups)
	local any = false
	for _, entry in ipairs(ns.PlaceList(area, lookups, zone)) do
		if entry.itemID == item then
			if entry.confirmed ~= false then
				return false
			end
			any = true
		end
	end
	return any
end

--- The extra sentences after a reading's own sentence, in every state (STA-R46), each that applies, in this order:
--- the entry behind its row isn't confirmed, its window's gate isn't confirmed, the zone's no-junk line isn't
--- confirmed, and the pool sentence for a pool-associated item.
---@param reading StatsReading
---@param places StatsPlaceTables? the place tables the reading was made with; `ns.places` if nil
---@return string[]
function ns.OddsNotes(reading, places)
	places = places or ns.places
	local L, lookups, notes = ns.L, places.lookups, {}
	if unconfirmedEntry(reading.item, reading.area, reading.zone, lookups) then
		notes[#notes + 1] = L.ODDS_NOTE_ENTRY
	end
	local window, gateUnconfirmed = places:ItemWindow(reading.zone, reading.item)
	if window and gateUnconfirmed then
		notes[#notes + 1] = L.ODDS_NOTE_WINDOW
	end
	local line, lineConfirmed = places:NoJunkLine(reading.zone)
	if line and not lineConfirmed then
		notes[#notes + 1] = L.ODDS_NOTE_LINE
	end
	local record = lookups.GetItem(reading.item)
	if record and record.pool then
		notes[#notes + 1] = L.ODDS_NOTE_POOL
	end
	return notes
end
