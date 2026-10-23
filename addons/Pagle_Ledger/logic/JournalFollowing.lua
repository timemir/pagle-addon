if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's Following spread (LED-R151) and Home's "Following" line (LED-R132): the Followed Anglers the
-- Companion brings in, as Core hands them out (Pagle.GetFollowedAnglers, VIEW-R11), read at each drawing. A spread
-- like Legends: the index on the left, the selected Angler's card on the right, or an empty state for each of `none`,
-- `absent` and `expired`. Pure logic, everything read from the spread's context (CORE-R7); the book draws it
-- (adapter/Journal.lua, adapter/JournalFollowing.lua).

-- The spread is ns.JOURNAL_FOLLOWING, its place ns.JournalPlace.following (logic/Journal.lua).

--- Home's contents line for Following (LED-R132, LED-R151), numbered `numeral`: the number of Followed Anglers in
--- state `ok`, "0" in `none`, "—" in `expired`, and greyed out as "no Companion" in `absent`. Every state opens the
--- spread.
---@param context LedgerSpreadContext
---@param numeral string
---@return LedgerBlock
function ns.FollowingContentsLine(context, numeral)
	local L = ns.L
	local followed = context.followedAnglers()
	local line = {
		kind = "leader",
		numeral = numeral,
		text = L.FOLLOWING_TITLE,
		place = ns.JournalPlace.following(),
	}
	if followed.state == "ok" then
		line.value = context.formatNumber(#followed.anglers)
	elseif followed.state == "none" then
		line.value = context.formatNumber(0)
	elseif followed.state == "expired" then
		line.value = L.FOLLOWING_EXPIRED_MARK
	else
		line.value, line.color = L.FOLLOWING_NO_COMPANION, "faded"
	end
	return line
end

-- An index row's right-hand value (LED-R151): "Lv {L} · {roman} · {p}%", with no roman numeral before the first
-- Prestige and X from rank 11 on, as the Prestige emblem reads (LED-R34).
---@param followed PagleFollowedAngler
---@return string
local function rowValue(followed)
	local L = ns.L
	local emblem = ns.PrestigeMark(followed.prestige).emblem
	if emblem then
		return L.FOLLOWING_ROW:format(followed.level, emblem, followed.ledger)
	end
	return L.FOLLOWING_ROW_NO_PRESTIGE:format(followed.level, followed.ledger)
end

-- The left page in state `ok` (LED-R151): kicker, title, the count, then the index in GetFollowedAnglers' order (by
-- name, IGV-R31), each row the Angler's name, an "HC" stamp for a Hardcore Angler and its level, Prestige and Ledger
-- completion at the right with its Prestige emblem's rank (LED-R152; none at rank 0), selecting it; the selected one
-- is marked.
---@param context LedgerSpreadContext
---@param anglers PagleFollowedAngler[]
---@param selected integer
---@return LedgerBlock[]
local function index(context, anglers, selected)
	local L = ns.L
	local count = ns.CountText(#anglers, L.FOLLOWING_COUNT_ONE, L.FOLLOWING_COUNT_OTHER, context.formatNumber)
	local blocks = {
		{ kind = "kicker", text = L.FOLLOWING_KICKER },
		{ kind = "title", text = L.FOLLOWING_TITLE },
		{ kind = "text", text = count },
	}
	for i, followed in ipairs(anglers) do
		blocks[#blocks + 1] = {
			kind = "row",
			text = followed.name,
			stamp = followed.hardcore and L.FOLLOWING_HARDCORE_STAMP or nil,
			value = rowValue(followed),
			rank = followed.prestige >= 1 and followed.prestige or nil,
			selected = i == selected,
			place = ns.JournalPlace.following(i),
		}
	end
	return blocks
end

-- An as-of date (IGV-R15: a UTC date as YYYYMMDD) as the Journal prints a date (LED-R126): "12 Oct", with the year
-- when it isn't the current realm year.
---@param context LedgerSpreadContext
---@param asOf integer
---@return string
local function asOfDate(context, asOf)
	local date = { year = math.floor(asOf / 10000), month = math.floor(asOf / 100) % 100, day = asOf % 100 }
	return context.text:Date(date)
end

-- The right page, the selected Angler's card (LED-R151): "Hardcore Angler" when it applies, the name, "and {n} more
-- characters" when it has others, the title in the hand (none when ""), the Angler Level in large numerals with the
-- Prestige under it as the bookplate words it (LED-R146) and a wax seal with its Ledger completion, the ruled rows,
-- and the as-of date. No region.
---@param context LedgerSpreadContext
---@param followed PagleFollowedAngler
---@return LedgerBlock[]
local function card(context, followed)
	local L = ns.L
	local format = context.formatNumber
	local blocks = {}
	if followed.hardcore then
		blocks[1] = { kind = "kicker", text = L.FOLLOWING_HARDCORE }
	end
	blocks[#blocks + 1] = { kind = "title", text = followed.name }
	if followed.more > 0 then
		blocks[#blocks + 1] = {
			kind = "text",
			color = "faded",
			text = ns.CountText(followed.more, L.FOLLOWING_MORE_ONE, L.FOLLOWING_MORE_OTHER, format),
		}
	end
	if followed.title ~= "" then
		blocks[#blocks + 1] = { kind = "text", hand = true, text = followed.title }
	end
	blocks[#blocks + 1] = {
		kind = "level",
		text = tostring(followed.level),
		value = L.HOME_LEVEL,
		note = ns.PrestigeName(followed.prestige) or L.ANGLER_NO_PRESTIGE,
		seal = L.FOLLOWING_SEAL:format(followed.ledger),
	}
	local legends = L.FOLLOWING_LEGENDS_COUNT:format(format(followed.legends), format(followed.legendsTotal))
	for _, row in ipairs({
		{ L.FOLLOWING_LEGENDS, legends },
		{ L.FOLLOWING_WATERS, format(followed.waters) },
		{ L.FOLLOWING_CATCHES, format(followed.catches) },
	}) do
		blocks[#blocks + 1] = { kind = "leader", style = "ruled", text = row[1], value = row[2] }
	end
	blocks[#blocks + 1] = {
		kind = "text",
		color = "faded",
		text = L.FOLLOWING_AS_OF:format(asOfDate(context, followed.asOf)),
	}
	return blocks
end

-- The left page in state `none`, `absent` or `expired` (LED-R151): its kicker and title, then the state's three
-- lines, the first in the hand and the last faded. The right page stays blank.
---@param state string "none", "absent" or "expired"
---@return LedgerBlock[]
local function emptyPage(state)
	local L = ns.L
	local lines = L.FOLLOWING_EMPTY[state]
	return {
		{ kind = "kicker", text = L.FOLLOWING_KICKER },
		{ kind = "title", text = L.FOLLOWING_TITLE },
		{ kind = "text", hand = true, text = lines[1] },
		{ kind = "text", text = lines[2] },
		{ kind = "text", color = "faded", text = lines[3] },
	}
end

ns.RegisterJournalSpread(ns.JOURNAL_FOLLOWING, {
	-- Home ❧ Following (LED-R125).
	crumbs = function()
		return { { label = ns.L.FOLLOWING_TITLE, place = ns.JournalPlace.following() } }
	end,
	-- The index on the left and the Angler `args.angler` on the right (the first when it names none of the file's),
	-- or the state's empty page and a blank right page, read from GetFollowedAnglers at each drawing.
	draw = function(args, context)
		local followed = context.followedAnglers()
		local anglers = followed.anglers
		if followed.state ~= "ok" then
			return { left = emptyPage(followed.state), right = {} }
		end
		local selected = anglers[args.angler] and args.angler or 1
		return { left = index(context, anglers, selected), right = card(context, anglers[selected]) }
	end,
	-- The index is the spread's; the right page, the Angler selected. Selecting another keeps the index's scroll
	-- (LED-R129).
	subjects = { left = {}, right = { "angler" } },
})
