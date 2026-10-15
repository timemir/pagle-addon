if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- What the Lifetime ribbon's spread says (stats.md › UI › Lifetime), worked out from the projection's state when it is
-- shown: the lifetime totals and time at the water (STA-R22, STA-R33), the bests (STA-R33), the got-away rate by skill
-- margin (STA-R26), each character's numbers (STA-R22) and the index of every item caught (STA-R25, STA-R96). Pure
-- logic over a StatsState, in ns.L's words through logic/Text.lua's formats (STA-R59); adapter/Lifetime.lua draws it.

--- One line of figures: its words at the left and its number at the right ("Casts", "1,840").
---@class StatsFigure
---@field label string
---@field value string

--- A group of figure lines under a heading (*Bests*), with the heading's small note if it has one.
---@class StatsFigureGroup
---@field heading string
---@field note string?
---@field figures StatsFigure[]

--- One item in the index of every fish: its count and what hovering it shows.
---@class StatsIndexEntry
---@field item integer
---@field count string        -- "1,204"
---@field hover string        -- "First 5 Oct 2026, last 12 Oct 2026"

--- The Lifetime spread's words: the left page's totals, then its groups (a group with no lines is left out); the right
--- page's index.
---@class StatsLifetime
---@field totals StatsFigure[]
---@field groups StatsFigureGroup[]
---@field index StatsIndexEntry[]

-- The index of every fish (STA-R25, STA-R96): every item in `items` (Noise and Uncharted ones too; item 0 never), most
-- caught first, ties by item ID.
---@param items table<integer, StatsItemTotal>
---@return StatsIndexEntry[]
local function everyFish(items)
	local L = ns.L
	local ids = {}
	for itemID in pairs(items) do
		if itemID ~= 0 then
			ids[#ids + 1] = itemID
		end
	end
	table.sort(ids, function(a, b)
		if items[a].n ~= items[b].n then
			return items[a].n > items[b].n
		end
		return a < b
	end)
	local entries = {}
	for i, itemID in ipairs(ids) do
		local total = items[itemID]
		entries[i] = {
			item = itemID,
			count = ns.Number(total.n),
			hover = L.LIFETIME_FIRST_LAST:format(ns.Date(total.first), ns.Date(total.last)),
		}
	end
	return entries
end

-- The bests (STA-R33): the longest Session and the most Catches per hour, each with its Session's date; the second
-- left out when no Session reaches the bests minimum.
---@param sessions StatsSession[]
---@return StatsFigure[]
local function bests(sessions)
	local L = ns.L
	local figures = {}
	local longest = ns.LongestSession(sessions)
	if longest then
		figures[#figures + 1] = {
			label = L.LIFETIME_LONGEST:format(ns.Date(ns.SessionDate(longest))),
			value = ns.Duration(ns.TimeFished(longest)),
		}
	end
	local best, rate = ns.BestCatchesPerHour(sessions)
	if best and rate then
		figures[#figures + 1] = {
			label = L.LIFETIME_BEST_RATE:format(ns.Date(ns.SessionDate(best))),
			value = ns.Number(rate),
		}
	end
	return figures
end

-- The skill margin buckets in the order the spread lists them (STA-R26): furthest below the line first.
local MARGINS = { "lo50", "lo1", "hi0", "hi25" }

-- Got away by skill (STA-R26): one line per bucket with Casts, "{rate}% of {Casts} Casts".
---@param margins table<string, StatsMargin>
---@return StatsFigure[]
local function byMargin(margins)
	local L = ns.L
	local figures = {}
	for _, bucket in ipairs(MARGINS) do
		local margin = margins[bucket]
		if margin and margin.casts > 0 then
			figures[#figures + 1] = {
				label = L.LIFETIME_MARGIN_NAMES[bucket],
				value = L.LIFETIME_MARGIN_VALUE:format(ns.GotAwayRate(margin), ns.Count(margin.casts, "Casts")),
			}
		end
	end
	return figures
end

-- The characters (STA-R22): each with Casts, alphabetically by name (by index on a tie), with its numbers.
---@param chars table<integer, StatsCounts>
---@return StatsFigure[]
local function characters(chars)
	local L = ns.L
	local named = {}
	for index, counts in pairs(chars) do
		if counts.casts > 0 then
			named[#named + 1] = { index = index, name = ns.CharacterName(index), counts = counts }
		end
	end
	table.sort(named, function(a, b)
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.index < b.index
	end)
	local figures = {}
	for i, char in ipairs(named) do
		local counts = char.counts
		figures[i] = {
			label = char.name,
			value = L.LIFETIME_CHARACTER_VALUE:format(
				ns.Count(counts.casts, "Casts"),
				ns.Count(counts.catches, "Catches"),
				ns.Number(counts.gotAway)
			),
		}
	end
	return figures
end

--- The Lifetime spread's words, or nil with no Casts (STA-R97: both pages then read "No Sessions yet.").
---@param state StatsState
---@return StatsLifetime?
function ns.Lifetime(state)
	local L = ns.L
	local totals, sessions = state.totals, state.sessions
	if totals.casts == 0 then
		return nil
	end
	local groups = {}
	-- Adds a group that has lines.
	local function group(heading, note, figures)
		if #figures > 0 then
			groups[#groups + 1] = { heading = heading, note = note, figures = figures }
		end
	end
	group(L.LIFETIME_BESTS, nil, bests(sessions))
	group(L.LIFETIME_BY_SKILL, L.LIFETIME_BY_SKILL_NOTE, byMargin(state.margins))
	group(L.LIFETIME_CHARACTERS, nil, characters(state.chars))
	return {
		totals = {
			{ label = L.LIFETIME_CASTS, value = ns.Number(totals.casts) },
			{ label = L.LIFETIME_CATCHES, value = ns.Number(totals.catches) },
			{
				label = L.LIFETIME_GOT_AWAY,
				value = L.LIFETIME_GOT_AWAY_VALUE:format(ns.Number(totals.gotAway), ns.GotAwayRate(totals)),
			},
			{ label = L.LIFETIME_SESSIONS, value = ns.Number(#sessions) },
			{ label = L.LIFETIME_TIME_AT_THE_WATER, value = ns.Duration(ns.TimeAtTheWater(sessions)) },
		},
		groups = groups,
		index = everyFish(state.items),
	}
end
