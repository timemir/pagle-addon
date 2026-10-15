if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The figures Stats works out from its Session records when they are shown, never stored (STA-R33): which record is
-- the current Session or "My last Session" (STA-R32), time fished, Catches per hour, got-away rates, Catches by
-- quality, lifetime time at the water, the bests and the first Cast's date. Pure logic over StatsSession records
-- (stats.md › Projection state); Core's Session, the server time and the item lookups come in (CORE-R7). A Session
-- that crosses midnight is one record, dated by its start: nothing here reads the daily reset (STA-R95). The book's
-- leather, the home spread, the Session pages, Lifetime and the tracker read them.

--- The least time fished Catches per hour divides by, in seconds (Tunables: Minimum time for Catches per hour).
ns.CATCHES_PER_HOUR_MIN_SECONDS = 60

--- The least `endTime − startTime` a record needs for the most Catches per hour, in seconds (Tunables: Bests minimum
--- for Catches per hour).
ns.BESTS_MIN_SECONDS = 1200

--- The live-line tick, in seconds (Tunables: Live-line tick): the book's live line and the tracker refresh on it
--- (STA-R73, STA-R86).
ns.LIVE_LINE_TICK = 30

--- Which Session the book and the tracker show (STA-R32): `kind` is
---   "current"     Core's Session is open and is the last record, `record` (its `index` in `sessions`);
---   "mismatched"  Core's Session is open but isn't the last record (in practice only while the projection is
---                 updating): the book's live line and the tracker use `live` alone (STA-R72, STA-R85);
---   "last"        no Session is open: `record` is "My last Session".
---@class StatsShownSession
---@field kind "current"|"mismatched"|"last"
---@field record StatsSession?   -- for "current" and "last"
---@field index integer?         -- the record's index in `sessions`, oldest first (Session {n}, numbered from 1)
---@field live PagleSession?     -- Core's Session (LOG-R64), for "mismatched"

--- The current Session or "My last Session" (STA-R32): nil when no Session is open and there are no records.
---@param sessions StatsSession[] the projection's Session records, oldest first (STA-R30)
---@param live PagleSession? `Pagle.GetSession()`: Core's Session while one is open, else nil (LOG-R64)
---@return StatsShownSession?
function ns.CurrentSession(sessions, live)
	local index = #sessions
	local last = sessions[index]
	if live ~= nil then
		if last ~= nil and last.id == live.id then
			return { kind = "current", record = last, index = index }
		end
		return { kind = "mismatched", live = live }
	end
	if last ~= nil then
		return { kind = "last", record = last, index = index }
	end
	return nil
end

--- Seconds fished in `session` (STA-R33): `endTime − startTime`, or for the current Session, with `now` given, so far:
--- `now − startTime`. A `now` behind the latest Cast (the server clock lagging) counts to that Cast.
---@param session StatsSession|PagleSession a Session record, or Core's Session (LOG-R64)
---@param now integer? the server time, for the current Session only
---@return integer
function ns.TimeFished(session, now)
	local to = session.endTime
	if now ~= nil and now > to then
		to = now
	end
	return to - session.startTime
end

--- The server time `session` is dated by: its start, even when it crosses midnight or a reset (STA-R95).
---@param session StatsSession|PagleSession
---@return integer
function ns.SessionDate(session)
	return session.startTime
end

-- Catches per hour, unrounded (STA-R33): catches × 3600 / max(time fished, 60).
---@param catches integer
---@param seconds integer
---@return number
local function rate(catches, seconds)
	return catches * 3600 / math.max(seconds, ns.CATCHES_PER_HOUR_MIN_SECONDS)
end

--- Catches per hour in `session`, a whole number rounded half up (STA-R33, STA-R44), over its time fished (so far,
--- for the current Session with `now` given), counting at least 60 s.
---@param session StatsSession|PagleSession a Session record, or Core's Session (LOG-R64)
---@param now integer? the server time, for the current Session only
---@return integer
function ns.CatchesPerHour(session, now)
	return ns.Round(rate(session.catches, ns.TimeFished(session, now)))
end

--- The share of Casts that got away, a whole percentage rounded half up (STA-R33, STA-R44); nil with 0 Casts.
---@param counts { casts: integer, gotAway: integer } a Session record, Core's Session, the totals, a place, a margin
---@return integer?
function ns.GotAwayRate(counts)
	if counts.casts == 0 then
		return nil
	end
	return ns.Round(counts.gotAway * 100 / counts.casts)
end

--- Where Catches by quality reads an item's quality (STA-R33): Core's `Pagle.GetItem` (LOG-R55) and, for an item Core
--- has no quality for (an Uncharted item), the client's `C_Item.GetItemQualityByID`.
---@class StatsQualityLookups
---@field GetItem fun(itemID: integer): PagleItem?
---@field GetItemQualityByID fun(itemID: integer): integer?

--- A Session's Catches of one quality.
---@class StatsQualityCount
---@field quality integer     -- the item quality, 0 poor ... 5 legendary
---@field catches integer

--- `items` grouped by quality (STA-R33), highest quality first, each with its Catches: Core's quality, else the
--- client's. An item whose quality the client hasn't loaded yet is left out and returned in `pending` (item IDs,
--- ascending), so the caller asks for it (`C_Item.RequestLoadItemDataByID`) and redraws when it loads.
---@param items table<integer, integer> catches by item ID, item 0 left out (a Session record's `items`)
---@param lookups StatsQualityLookups
---@return StatsQualityCount[] qualities
---@return integer[] pending
function ns.CatchesByQuality(items, lookups)
	local byQuality, pending = {}, {}
	for itemID, catches in pairs(items) do
		local item = lookups.GetItem(itemID)
		local quality = item and item.quality
		if quality == nil then
			quality = lookups.GetItemQualityByID(itemID)
		end
		if quality == nil then
			pending[#pending + 1] = itemID
		else
			byQuality[quality] = (byQuality[quality] or 0) + catches
		end
	end
	local qualities = {}
	for quality, catches in pairs(byQuality) do
		qualities[#qualities + 1] = { quality = quality, catches = catches }
	end
	table.sort(qualities, function(a, b)
		return a.quality > b.quality
	end)
	table.sort(pending)
	return qualities, pending
end

--- Lifetime time at the water, in seconds (STA-R33): every record's `endTime − startTime` summed, the current Session's
--- up to its latest Cast.
---@param sessions StatsSession[]
---@return integer
function ns.TimeAtTheWater(sessions)
	local seconds = 0
	for _, session in ipairs(sessions) do
		seconds = seconds + ns.TimeFished(session)
	end
	return seconds
end

--- The longest Session (STA-R33): the record with the most `endTime − startTime`, the current one included, the
--- earliest on a tie; nil with no records.
---@param sessions StatsSession[] oldest first
---@return StatsSession?
function ns.LongestSession(sessions)
	local longest, most = nil, -1
	for _, session in ipairs(sessions) do
		local seconds = ns.TimeFished(session)
		if seconds > most then
			longest, most = session, seconds
		end
	end
	return longest
end

--- The most Catches per hour (STA-R33): the record with the best unrounded rate among those (the current one
--- included) with at least ns.BESTS_MIN_SECONDS of `endTime − startTime`, the earliest on a tie, and its rate as a
--- whole number rounded half up (STA-R44). Nil when no record qualifies.
---@param sessions StatsSession[] oldest first
---@return StatsSession? session
---@return integer? rate
function ns.BestCatchesPerHour(sessions)
	local best, bestRate = nil, -1
	for _, session in ipairs(sessions) do
		local seconds = ns.TimeFished(session)
		if seconds >= ns.BESTS_MIN_SECONDS then
			local exact = rate(session.catches, seconds)
			if exact > bestRate then
				best, bestRate = session, exact
			end
		end
	end
	if best == nil then
		return nil, nil
	end
	return best, ns.Round(bestRate)
end

--- The server time of the first Cast Stats has a record of (STA-R33): `sessions[1].startTime`; nil with no records.
---@param sessions StatsSession[] oldest first
---@return integer?
function ns.FirstCastTime(sessions)
	local first = sessions[1]
	return first and first.startTime
end
