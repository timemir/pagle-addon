---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The news sign with the news (core/news-sign.md SIGN-R14–R19): once a session, the drop delay after its first
-- PLAYER_ENTERING_WORLD, Core reads the news (Pagle.GetNews, VIEW-R42) and decides: set the floor (ns.SetNewsFloor,
-- VIEW-R44), hold the sign, or drop it in the equipped look with the pick's words and its more line, marking every
-- item seen as it drops (Pagle.MarkNewsSeen, VIEW-R43). The pick is logic/NewsSign.lua's; the words are
-- Pagle.NewsWords' (VIEW-R45); the switches are ns.NewsOption and ns.NewsKindOn (adapter/NewsSign.lua, SET-R37); the
-- drop is adapter/NewsSign.lua's, which waits for combat, a restriction, a letter and the Field guide (SIGN-R40).

local OWNER = "Pagle news sign drop"

-- The switches the pick reads (logic/NewsSign.lua).
---@type PagleNewsSignSwitches
local SWITCHES = {
	kind = function(kind)
		return ns.NewsKindOn(kind)
	end,
	headlines = function()
		return ns.NewsOption("headlines")
	end,
}

-- Cozy mode (ANN-R40): nothing pops up or plays.
local function cozy()
	local profile = ns.db and ns.db.profile
	return profile ~= nil and profile.announcements ~= nil and profile.announcements.cozy == true
end

-- Every item of the news block marked seen (SIGN-R17, VIEW-R43).
local function markAll()
	Pagle.MarkNewsSeen()
end

-- The floor, PagleDB.global.news.since (VIEW-R44), or nil before the first decision with news sets it (SIGN-R18).
---@return integer?
local function floor()
	local kept = ns.db.global.news
	return kept and type(kept.since) == "number" and kept.since or nil
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
	-- absent, expired or none: nothing to read or mark (VIEW-R42)
	local block = Pagle.GetNews()
	if block.state ~= "ok" then
		return "none"
	end
	local since = floor()
	if not since then
		ns.SetNewsFloor() -- SIGN-R18: the first login with news shows nothing older than this
		markAll()
		return "floor"
	end
	if not ns.NewsOption("show") or cozy() then
		markAll()
		return "held"
	end
	local pick, more = ns.PickNews(block.items, GetServerTime(), since, SWITCHES)
	if not pick then
		markAll()
		return "nothing"
	end
	whenNamed(pick, function()
		local words = Pagle.NewsWords(pick)
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
