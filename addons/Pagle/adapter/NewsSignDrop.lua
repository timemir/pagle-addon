---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The news sign with the news (core/news-sign.md SIGN-R14–R19): once a session, the drop delay after its first
-- PLAYER_ENTERING_WORLD, Core reads the news (Pagle.GetNews, VIEW-R42) and decides: set the floor, hold the sign, or
-- drop it in the equipped look with the pick's words and its more line, marking every item seen as it drops
-- (Pagle.MarkNewsSeen, VIEW-R43). The pick is logic/NewsSign.lua's; the words are Pagle.NewsWords' (VIEW-R45); the
-- drop is adapter/NewsSign.lua's, which waits for combat, a restriction and a letter (SIGN-R40).
--
-- The news API comes from the news reader (#656), the switches' rows from Settings (#659, SET-R37) and the looks from
-- the Curio Shop's slot (#660, SHOP-R60). This file reads each through a seam that holds without them: no
-- Pagle.GetNews reads as news that isn't `ok`, a missing switch reads as on (news-sign.md › Data), and a slot with no
-- goods wears Wood (ns.EquippedNewsSignLook).

local OWNER = "Pagle news sign drop"

-- The news reader's API (VIEW-R42–R45, #656), read at each call: Pagle.GetNews, MarkNewsSeen and NewsWords.
local news = Pagle --[[@as table]]

-- PagleDB.global.newsSign, or nil before it is written (news-sign.md › Data).
local function stored()
	return ns.db and ns.db.global and ns.db.global.newsSign
end

--- A news sign switch (SET-R37), as news-sign.md › Data stores it: `show` ("Show news at login"), `headlines` ("Region
--- headlines"), or with `kind`, that followed kind's row (`kinds[kind]`). Each is on unless stored false, so a key
--- that isn't there reads as on.
---@param key "show"|"headlines"|"kinds"
---@param kind string?
---@return boolean
function ns.NewsSignOption(key, kind)
	local sign = stored()
	if key == "kinds" then
		local kinds = sign and sign.kinds
		return not (type(kinds) == "table" and kinds[kind] == false)
	end
	return not (sign and sign[key] == false)
end

-- The switches the pick reads (logic/NewsSign.lua).
---@type PagleNewsSignSwitches
local SWITCHES = {
	kind = function(kind)
		return ns.NewsSignOption("kinds", kind)
	end,
	headlines = function()
		return ns.NewsSignOption("headlines")
	end,
}

-- Cozy mode (ANN-R40): nothing pops up or plays.
local function cozy()
	local profile = ns.db and ns.db.profile
	return profile ~= nil and profile.announcements ~= nil and profile.announcements.cozy == true
end

-- Every item of the news block marked seen (SIGN-R17, VIEW-R43).
local function markAll()
	if news.MarkNewsSeen then
		news.MarkNewsSeen()
	end
end

-- PagleDB.global.news, VIEW-R44's: the floor and the seen items.
local function newsStore()
	ns.db.global.news = ns.db.global.news or {}
	return ns.db.global.news
end

-- The kinds whose words name the line's `item` (SIGN-R19): a fish, a Legend or a Species.
local NAMES_ITEM = { first = true, region = true, legend = true, colour = true, monster = true }

-- Runs `fn` once the client has the name of `item`'s fish (SIGN-R19), asking for it if it hasn't, or after the name
-- wait if it never comes: then Pagle.NewsWords words it as SIGN_ITEM_UNKNOWN.
local function whenNamed(item, fn)
	local id = item.item
	if not NAMES_ITEM[item.kind] or type(id) ~= "number" or id <= 0 or C_Item.GetItemNameByID(id) then
		fn()
		return
	end
	local done = false
	local function once()
		if not done then
			done = true
			fn()
		end
	end
	Item:CreateFromItemID(id):ContinueOnItemLoad(once)
	C_Timer.After(ns.NEWS_SIGN_NAME_WAIT, once)
end

--- SIGN-R14's decision, run once a session after the drop delay; also for the specs. Returns what it decided:
--- "none" (the news isn't `ok`: nothing read or marked), "floor" (the floor set, every item marked), "held" (Show news
--- at login off, or Cozy mode: every item marked), "nothing" (nothing due: every item marked) or "drop" (the sign
--- drops, marking every item as it does).
---@return "none"|"floor"|"held"|"nothing"|"drop"
function ns.DecideNewsSign()
	local block = news.GetNews and news.GetNews()
	if type(block) ~= "table" or block.state ~= "ok" or type(block.items) ~= "table" then
		return "none"
	end
	local store = newsStore()
	local now = GetServerTime()
	if type(store.since) ~= "number" then
		store.since = now -- SIGN-R18: the first login with news shows nothing older than this
		markAll()
		return "floor"
	end
	if not ns.NewsSignOption("show") or cozy() then
		markAll()
		return "held"
	end
	local pick, more = ns.PickNews(block.items, now, store.since, SWITCHES)
	if not pick or not news.NewsWords then
		markAll()
		return "nothing"
	end
	whenNamed(pick, function()
		local words = news.NewsWords(pick)
		---@type PagleNewsSignNews
		local shown = {
			kind = words.kind,
			kicker = words.kicker,
			head = words.head,
			detail = words.detail,
			emblem = words.emblem,
			-- SIGN-R16: the other due followed items, left out at 0
			more = more > 0 and ns.RenderText(ns.L.SIGN_MORE, { count = more }) or nil,
			id = pick.id, -- the item shown, for the Fish Journal's news list (SIGN-R42, VIEW-R46)
		}
		ns.DropNewsSign(nil, shown, markAll)
	end)
	return "drop"
end

-- SIGN-R14: the session's first PLAYER_ENTERING_WORLD starts the drop delay; a later loading screen changes nothing.
Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_ENTERING_WORLD")
	C_Timer.After(ns.NEWS_SIGN_DELAY, function()
		ns.DecideNewsSign()
	end)
end)
