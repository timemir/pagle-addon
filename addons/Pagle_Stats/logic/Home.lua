if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The home spread's lines (stats.md › UI › Home spread): the zone tiles of its left page, Where I've fished, and what
-- its right page, Right now, reads in handwriting. Pure logic: the projection's state, the live snapshot, Core's
-- Session, the watches and the server time come in as arguments (CORE-R7); adapter/Home.lua draws what these return.
-- Secret values reach here as unknowns (zone 0, a nil skill or realm minute), and Right now leaves out what it can't
-- read rather than guess (STA-R93).

--- A tile's words and the page it opens, as the book's tile grid draws it (adapter/BookWidgets.lua's
--- ns.NewBookTileGrid): the home spread's zones and the item page's waters.
---@class StatsTile
---@field name string
---@field line string
---@field here string?
---@field note string?
---@field target StatsBookTarget

--- One zone's tile on the left page: its name, its line, "I'm here" and "watching {N}" when they apply, and the place
--- page it opens.
---@class StatsHomeTile: StatsTile
---@field zone integer
---@field name string
---@field line string             -- "{Casts} Casts · {N} waters", or "not fished yet"
---@field here string?            -- "I'm here" on the current zone
---@field note string?            -- "watching {N}"
---@field target StatsBookTarget

---@class StatsHomeWaters
---@field tiles StatsHomeTile[]
---@field empty string?           -- "Not fished anywhere yet." when there are no tiles (STA-R97)

--- One watched Dry spell's line (its "✎" is the adapter's mark before it): "{item}, {place}: {Dry spell}", with the
--- part to write in red, and the entry it opens.
---@class StatsHomeWatch
---@field item integer
---@field area integer
---@field text string
---@field red string?             -- ", unlucky" or ", very unlucky" inside `text`, when it applies
---@field target StatsBookTarget

--- One line of *In this book*: its words, its number at the right, and the page it opens.
---@class StatsHomeLink
---@field label string
---@field value string?
---@field target StatsBookTarget

---@class StatsHomeRightNow
---@field where string            -- "Fishing {subzone}, {zone}, by {day or night}." or "I can't tell where I am."
---@field skill string?           -- the skill against the no-junk line; nil on side na
---@field session string          -- this Session, the last one's end, or "No Session yet."
---@field watches StatsHomeWatch[]
---@field noWatches string?       -- the line with no watches
---@field contents StatsHomeLink[]
---@field pending integer[]       -- watched items whose names the client hasn't loaded: ask, then redraw

---@alias StatsWatch { item: integer, area: integer }

--- The left page's tiles (stats.md › UI › Home spread): one per zone in `places` (a record whose `zone` is its own
--- areaID) plus the current zone, most Casts first, the current zone first when it has none, ties by areaID. A tile
--- reads its Casts and its waters (subzones in `places` in it), or "not fished yet"; "I'm here" on the current zone;
--- "watching {N}" when watches are on it or one of its subzones (STA-R60). With no Casts at all there are no tiles,
--- only "Not fished anywhere yet." (STA-R97).
---@param state StatsState
---@param conditions ConditionsSnapshot the live snapshot, `Pagle.GetConditions()`
---@param watched StatsWatch[] the watches, `PagleStatsDB.profile.watched`
---@param places StatsPlaceTables? ns.places by default
---@return StatsHomeWaters
function ns.HomeWaters(state, conditions, watched, places)
	local L, lookups = ns.L, (places or ns.places).lookups
	local tiles = {} ---@type StatsHomeTile[]
	if state.totals.casts == 0 then
		return { tiles = tiles, empty = L.HOME_NOT_FISHED }
	end
	local here = conditions.zone or 0
	-- By zone: its waters, its watches, and its Casts to sort by (the current zone with none first).
	local waters, watching, casts = {}, {}, {}
	for area, record in pairs(state.places) do
		if record.zone ~= area then
			waters[record.zone] = (waters[record.zone] or 0) + 1
		end
	end
	for _, watch in ipairs(watched) do
		local zone = ns.ZoneOf(state, watch.area, lookups)
		watching[zone] = (watching[zone] or 0) + 1
	end
	---@param zone integer
	---@param n integer? my Casts there; nil for the current zone with none
	local function add(zone, n)
		casts[zone] = n or math.huge
		tiles[#tiles + 1] = {
			zone = zone,
			name = ns.AreaName(zone),
			line = n and L.HOME_TILE_LINE:format(ns.Count(n, "Casts"), ns.Count(waters[zone] or 0, "waters"))
				or L.HOME_TILE_NOT_FISHED,
			here = zone == here and L.HOME_HERE or nil,
			note = watching[zone] and L.HOME_WATCHING:format(watching[zone]) or nil,
			target = { page = "place", area = zone },
		}
	end
	for area, record in pairs(state.places) do
		if record.zone == area then
			add(area, record.casts)
		end
	end
	if here ~= 0 and not (state.places[here] and state.places[here].zone == here) then
		add(here, nil)
	end
	table.sort(tiles, function(a, b)
		if casts[a.zone] ~= casts[b.zone] then
			return casts[a.zone] > casts[b.zone]
		end
		return a.zone < b.zone
	end)
	return { tiles = tiles, empty = #tiles == 0 and L.HOME_NOT_FISHED or nil }
end

-- "Fishing {subzone}, {zone}, by {day or night}." (the subzone left out when 0; by night when the night window
-- matches the snapshot, the phrase left out with no realm minute), or "I can't tell where I am." with zone 0.
---@param conditions ConditionsSnapshot
---@param places StatsPlaceTables
---@return string
local function whereText(conditions, places)
	local L = ns.L
	local zone, subzone = conditions.zone or 0, conditions.subzone or 0
	if zone == 0 then
		return L.HOME_NOWHERE
	end
	local where = ns.AreaName(zone)
	if subzone ~= 0 then
		where = L.HOME_PLACE:format(ns.AreaName(subzone), where)
	end
	if conditions.minute == nil then
		return L.HOME_FISHING:format(where)
	end
	local when = places:InWindow("night", conditions) and "night" or "day"
	return L.HOME_FISHING_WHEN:format(where, L.WINDOW_NAMES[when])
end

-- "Skill {effective}, past the no-junk line ({line})." on side hi, "… below …" on lo, nil on na (STA-R13).
---@param conditions ConditionsSnapshot
---@param places StatsPlaceTables
---@return string?
local function skillText(conditions, places)
	local zone, skill = conditions.zone or 0, ns.EffectiveSkill(conditions)
	if zone == 0 or skill == nil then
		return nil
	end
	local line = places:NoJunkLine(zone)
	local side = ns.SkillSide(skill, line)
	if side == "hi" then
		return ns.L.HOME_SKILL_HI:format(skill, line)
	elseif side == "lo" then
		return ns.L.HOME_SKILL_LO:format(skill, line)
	end
	return nil
end

-- This Session's line during one (Core's Session alone while it isn't the last record, STA-R32), the last one's end
-- with none open, or "No Session yet.".
---@param shown StatsShownSession?
---@param now integer
---@return string
local function sessionText(shown, now)
	local L = ns.L
	if shown == nil then
		return L.HOME_NO_SESSION
	elseif shown.kind == "last" then
		return L.HOME_LAST_SESSION:format(ns.TimeAgo(shown.record.endTime, now))
	end
	local session = shown.record or shown.live --[[@as StatsSession|PagleSession]]
	return L.HOME_SESSION:format(
		ns.Count(session.casts, "Casts"),
		ns.Count(session.catches, "Catches"),
		ns.Number(session.gotAway),
		ns.Duration(ns.TimeFished(session, now))
	)
end

-- A watch's line: its reading on the reading side of the moment (STA-R64), its Dry spell's home spread ending.
---@param state StatsState
---@param watch StatsWatch
---@param live integer? the live effective skill
---@param places StatsPlaceTables
---@param pending integer[]
---@return StatsHomeWatch
local function watchLine(state, watch, live, places, pending)
	local reading = ns.Reading(state, watch.item, watch.area, live, places)
	local name, _, loaded = ns.Item(watch.item)
	if not loaded then
		pending[#pending + 1] = watch.item
	end
	local dry = ns.DrySpell(reading)
	local red
	if dry.caught and dry.since > 0 and ns.IsUnlucky(dry.band) then
		red = ns.L.DRY_SHORT_BAND:format(ns.BandWord(dry.band))
	end
	return {
		item = watch.item,
		area = watch.area,
		text = ns.L.HOME_WATCH:format(name, ns.AreaName(watch.area), ns.DrySpellWatchText(reading)),
		red = red,
		target = { page = "place", area = watch.area, item = watch.item },
	}
end

--- The right page, Right now (stats.md › UI › Home spread): where I am, by day or night; my skill against the zone's
--- no-junk line; this Session or the last one; each watched Dry spell (STA-R60, STA-R64); and *In this book*: Where I
--- am (unknown with zone 0, opening the home spread), This Session or My last Session, Lifetime with my Casts, Every
--- Session with the count (STA-R74).
---@param state StatsState
---@param conditions ConditionsSnapshot the live snapshot, `Pagle.GetConditions()`
---@param live PagleSession? `Pagle.GetSession()`
---@param watched StatsWatch[] the watches, `PagleStatsDB.profile.watched`
---@param now integer the server time
---@param places StatsPlaceTables? ns.places by default
---@return StatsHomeRightNow
function ns.HomeRightNow(state, conditions, live, watched, now, places)
	places = places or ns.places
	local L = ns.L
	local shown = ns.CurrentSession(state.sessions, live)
	local skill = ns.EffectiveSkill(conditions)
	local watches, pending = {}, {}
	for i, watch in ipairs(watched) do
		watches[i] = watchLine(state, watch, skill, places, pending)
	end
	local here = ns.CurrentPlace(conditions)
	return {
		where = whereText(conditions, places),
		skill = skillText(conditions, places),
		session = sessionText(shown, now),
		watches = watches,
		noWatches = #watches == 0 and L.HOME_NO_WATCHES or nil,
		contents = {
			{
				label = here and L.HOME_WHERE_I_AM:format(ns.AreaName(here)) or L.HOME_WHERE_UNKNOWN,
				target = ns.WhereIAm(conditions),
			},
			{
				label = (shown and shown.kind == "last") and L.BOOK_LAST_SESSION or L.BOOK_THIS_SESSION,
				target = { page = "session" },
			},
			{ label = L.BOOK_LIFETIME, value = ns.Number(state.totals.casts), target = { page = "lifetime" } },
			{ label = L.HOME_EVERY_SESSION, value = ns.Number(#state.sessions), target = { page = "sessions" } },
		},
		pending = pending,
	}
end
