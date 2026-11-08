if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's news list (LED-R176–R179) and the Following spread's link to it (LED-R163): every item of the news
-- block Core hands out (Pagle.GetNews, VIEW-R42), newest first, worded as the sign words them (Pagle.NewsWords,
-- VIEW-R45), read at each drawing. A spread like Following: the list on the left, the chosen item on the right, or an
-- empty state for each of `absent`, `expired`, `none` and `ok` with no item. Pure logic, everything read from the
-- spread's context (CORE-R7); the book draws it (adapter/Journal.lua, adapter/JournalNews.lua), and marks the news seen
-- as it draws the list (LED-R177).

-- The spread is ns.JOURNAL_NEWS, its place ns.JournalPlace.news (logic/Journal.lua).

local HOUR, DAY = 3600, 24 * 3600

--- The Following spread's link to the news list (LED-R163), under its count line: "News: {n} new »" while the news has
--- new items (VIEW-R42), "News »" otherwise. None in state `absent`, which the news shares with the Following spread
--- (VIEW-R42: GetNews' `absent` and `expired` are GetFollowedAnglers').
---@param context LedgerSpreadContext
---@param followingState string the Following spread's state, GetFollowedAnglers'
---@return LedgerBlock?
function ns.FollowingNewsLink(context, followingState)
	if followingState == "absent" then
		return nil
	end
	local L = ns.L
	local fresh = 0
	for _, item in ipairs(context.news().items) do
		if item.new then
			fresh = fresh + 1
		end
	end
	return {
		kind = "link",
		hand = true,
		text = fresh > 0 and ns.Text(L.FOLLOWING_NEWS_NEW, { count = fresh }) or L.FOLLOWING_NEWS,
		place = ns.JournalPlace.news(),
	}
end

--- The news `items` newest first by `time`, ties in the file's order (LED-R176): a fresh array.
---@param items PagleNewsItem[]
---@return PagleNewsItem[]
function ns.NewsNewestFirst(items)
	local order = {}
	for i, item in ipairs(items) do
		order[i] = { item = item, at = i }
	end
	table.sort(order, function(a, b)
		if a.item.time ~= b.item.time then
			return a.item.time > b.item.time
		end
		return a.at < b.at
	end)
	local sorted = {}
	for i, entry in ipairs(order) do
		sorted[i] = entry.item
	end
	return sorted
end

--- An item's age at the row's right (LED-R176): "{n} h" under a day, "{n} d" from then on, whole hours and days.
---@param now integer
---@param time integer
---@return string
function ns.NewsAge(now, time)
	local age = math.max(0, now - time)
	if age < DAY then
		return ns.Text(ns.L.NEWS_AGE_HOURS, { hours = math.floor(age / HOUR) })
	end
	return ns.Text(ns.L.NEWS_AGE_DAYS, { days = math.floor(age / DAY) })
end

-- The left page's head (LED-R176, LED-R179): the kicker and the title, kept in every state.
---@return LedgerBlock[]
local function head()
	local L = ns.L
	return {
		{ kind = "kicker", text = L.NEWS_KICKER },
		{ kind = "title", text = L.NEWS_TITLE },
	}
end

-- The left page in state `ok` with items (LED-R176): its head and line, then a row per item in `sorted`'s order, each
-- its red wax dot when new, its kicker, its headline and its age, choosing it; the chosen one marked.
---@param context LedgerSpreadContext
---@param sorted PagleNewsItem[]
---@param words PagleNewsWords[]
---@param chosen integer
---@return LedgerBlock[]
local function list(context, sorted, words, chosen)
	local blocks = head()
	blocks[#blocks + 1] = { kind = "text", text = ns.L.NEWS_LINE }
	for i, item in ipairs(sorted) do
		blocks[#blocks + 1] = {
			kind = "newsRow",
			new = item.new or nil,
			kicker = words[i].kicker,
			text = words[i].head,
			value = ns.NewsAge(context.now, item.time),
			selected = i == chosen or nil,
			place = ns.JournalPlace.news(item.id),
		}
	end
	return blocks
end

-- The right page, the chosen item (LED-R176): its emblem at 96 units, its kicker, its headline in large, its detail
-- line, its date (LED-R126); then for an item about a followed Angler a link to that Angler's card, or for a region
-- headline about an Angler the player doesn't follow, how to follow them, in the hand. Only the words NewsWords gives
-- name anything, so a variety the player hasn't caught stays unnamed (VAR-R27), and an Angler is named by the line's
-- `name`, never a character (SIGN-R11).
---@param context LedgerSpreadContext
---@param item PagleNewsItem
---@param words PagleNewsWords
---@return LedgerBlock[]
local function card(context, item, words)
	local L = ns.L
	local blocks = { { kind = "newsEmblem", emblem = words.emblem } }
	if words.kicker then
		blocks[#blocks + 1] = { kind = "kicker", text = words.kicker }
	end
	blocks[#blocks + 1] = { kind = "title", text = words.head }
	if words.detail then
		blocks[#blocks + 1] = { kind = "text", style = "italic", text = words.detail }
	end
	blocks[#blocks + 1] = { kind = "text", color = "faded", text = context.text:DateAt(item.time) }
	if item.angler > 0 then
		blocks[#blocks + 1] = {
			kind = "link",
			text = ns.Text(L.NEWS_CARD, { name = item.name }),
			place = ns.JournalPlace.following(item.angler),
		}
	elseif item.kind == "region" then
		blocks[#blocks + 1] = { kind = "text", hand = true, text = L.NEWS_FOLLOW }
	end
	return blocks
end

-- The left page in an empty state (LED-R179): its head, then the state's lines, the first in the hand and the last
-- faded; `absent` and `expired` read the Following spread's (LED-R163). The right page stays blank.
---@param state string "absent", "expired", "none" or "ok" (with no item)
---@return LedgerBlock[]
local function emptyPage(state)
	local L = ns.L
	local lines = (state == "absent" or state == "expired") and L.FOLLOWING_EMPTY[state] or L.NEWS_EMPTY[state]
	local blocks = head()
	for i, text in ipairs(lines) do
		local block = { kind = "text", text = text }
		if i == 1 then
			block.hand = true
		elseif i == #lines then
			block.color = "faded"
		end
		blocks[#blocks + 1] = block
	end
	return blocks
end

ns.RegisterJournalSpread(ns.JOURNAL_NEWS, {
	-- Home ❧ Following ❧ News (LED-R176, LED-R125): the back link goes to Following.
	crumbs = function()
		local L = ns.L
		return {
			{ label = L.FOLLOWING_TITLE, place = ns.JournalPlace.following() },
			{ label = L.NEWS_TITLE, place = ns.JournalPlace.news() },
		}
	end,
	-- The list on the left and the item `args.id` on the right (the newest when it names none of the news'), or the
	-- state's empty page and a blank right page, read from GetNews at each drawing.
	draw = function(args, context)
		local news = context.news()
		if news.state ~= "ok" or #news.items == 0 then
			return { left = emptyPage(news.state), right = {} }
		end
		local sorted = ns.NewsNewestFirst(news.items)
		local words, chosen = {}, 1
		for i, item in ipairs(sorted) do
			words[i] = context.newsWords(item)
			if item.id == args.id then
				chosen = i
			end
		end
		return { left = list(context, sorted, words, chosen), right = card(context, sorted[chosen], words[chosen]) }
	end,
	-- The list is the spread's; the right page, the item chosen. Choosing another keeps the list's scroll (LED-R129).
	subjects = { left = {}, right = { "id" } },
})

--- Whether the news list at `place` draws items now, so drawing it marks them seen (LED-R177): the news spread, in
--- state `ok` with at least one item.
---@param context LedgerSpreadContext
---@param place LedgerJournalPlace
---@return boolean
function ns.NewsListDrawsItems(context, place)
	if place.id ~= ns.JOURNAL_NEWS then
		return false
	end
	local news = context.news()
	return news.state == "ok" and #news.items > 0
end
