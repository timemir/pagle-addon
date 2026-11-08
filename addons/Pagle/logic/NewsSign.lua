---@class PagleNS
local ns = select(2, ...)

-- The news sign's pick (core/news-sign.md SIGN-R15, SIGN-R16): which news items are due, which one the sign shows and
-- how many more it counts. Pure logic over the items VIEW-R42 hands out (CORE-R7); adapter/NewsSignDrop.lua decides
-- once a session (SIGN-R14) and drops the sign with it.

--- Tunables (core/news-sign.md › Tunables): the drop delay after the session's first PLAYER_ENTERING_WORLD
--- (SIGN-R14), the news age past which an item is never due (SIGN-R15) and the name wait (SIGN-R19), in seconds.
ns.NEWS_SIGN_DELAY = 5
ns.NEWS_AGE = 30 * 86400
ns.NEWS_SIGN_NAME_WAIT = 2

--- The followed kinds in SIGN-R10's rank; `region`, the region headline, is ranked after all of them (SIGN-R15).
ns.NEWS_FOLLOWED_KINDS = { "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster" }

local RANK = {}
for rank, kind in ipairs(ns.NEWS_FOLLOWED_KINDS) do
	RANK[kind] = rank
end

--- The sign's switches (SET-R37), read when asked: a followed kind's row, and Region headlines.
---@class PagleNewsSignSwitches
---@field kind fun(kind: string): boolean
---@field headlines fun(): boolean

-- The UTC month of a server time, as a count of months: the realm date at a realm minute that is the UTC one's.
---@param time integer
---@return integer
local function utcMonth(time)
	local date = ns.RealmDate(time, math.floor(time / 60) % 1440)
	return date.year * 12 + date.month
end

--- Whether a news item is due at `now` (SIGN-R15): new at the session's first read (VIEW-R42: not seen, VIEW-R44),
--- timed at or after the floor (SIGN-R18) and within the news age, its switch on, and a region headline's time in
--- the current UTC month.
---@param item table a news item of Pagle.GetNews (VIEW-R42)
---@param now integer GetServerTime()
---@param floor integer the floor, PagleDB.global.news.since
---@param switches PagleNewsSignSwitches
---@return boolean
function ns.NewsItemDue(item, now, floor, switches)
	if item.new ~= true or type(item.time) ~= "number" or item.time < floor or now - item.time > ns.NEWS_AGE then
		return false
	end
	if item.kind == "region" then
		return switches.headlines() == true and utcMonth(item.time) == utcMonth(now)
	end
	return RANK[item.kind] ~= nil and switches.kind(item.kind) == true
end

--- The pick and its count (SIGN-R15, SIGN-R16): the first due followed item in SIGN-R10's rank, then the newest, then
--- the first in the block's order, with how many other followed items are due; with no due followed item, the newest
--- due region headline (the block's first of the newest), counting none. Nil and 0 when nothing is due.
---@param items table[] Pagle.GetNews().items, in the block's order
---@param now integer GetServerTime()
---@param floor integer the floor, PagleDB.global.news.since
---@param switches PagleNewsSignSwitches
---@return table? pick
---@return integer more
function ns.PickNews(items, now, floor, switches)
	local best, headline, due = nil, nil, 0
	for _, item in ipairs(items) do
		if ns.NewsItemDue(item, now, floor, switches) then
			if item.kind == "region" then
				if not headline or item.time > headline.time then
					headline = item
				end
			else
				due = due + 1
				local rank = RANK[item.kind]
				if not best or rank < RANK[best.kind] or (rank == RANK[best.kind] and item.time > best.time) then
					best = item
				end
			end
		end
	end
	if best then
		return best, due - 1
	end
	return headline, 0
end
