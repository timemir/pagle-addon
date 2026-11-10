---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- `/pagle dev sign <look> [kind] [more]` (SIGN-R60): drops the news sign in a look with sample news of a kind, so
-- each look and kind can be seen before the news itself exists. The samples are the sign kit's: one Angler, the
-- Old Crafty, Keefer's Angelfish (a Legend, DATA-R22), the Raw Spotted Yellowtail's All-gold (a Rare variety) and a
-- Stonescale Eel. Their names are the dev's sample text, so they stay English; the sign's own words are ns.L's.

--- The kinds, in the order the brief ranks them (SIGN-R10), then the region headline.
ns.NEWS_SIGN_KINDS = { "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster", "region" }

local SAMPLE = {
	name = "Kukli Emnabi",
	region = "EU",
	fish = "the Old Crafty",
	legend = "Keefer's Angelfish",
	rank = "III",
	variety = "All-gold",
	species = "Spotted Yellowtail",
	monster = "Stonescale Eel",
	hunt = "The Long Haul",
	zone = "Elwynn Forest",
	length = "64 in",
}

--- Each kind's emblem (SIGN-R13): reused art where the add-on has it, the sign's own where it doesn't.
local EMBLEMS = {
	first = { sign = "laurel" },
	region = { sign = "laurel" },
	legend = { legend = "angelfish", item = 19805 },
	prestige = { atlas = "PrestigeEmblems", sprite = "emblem-iii" },
	ledger = { file = "Interface\\AddOns\\Pagle\\media\\minimap\\Ledger-Book", fill = 1.25 },
	colour = { variety = { species = 4603, position = 8 } },
	hunt = { sign = "medal" },
	zone = { file = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn", fill = 0.92 },
	monster = { file = "Interface\\AddOns\\Pagle\\media\\crests\\fish\\13422", fill = 0.92, tape = true },
}

--- The sample news of `kind`, with "+`more` more from your anglers" when `more` is a number.
---@param kind string
---@param more integer?
---@return PagleNewsSignNews
function ns.NewsSignSample(kind, more)
	local L = ns.L
	local f = SAMPLE
	local detail
	if kind == "first" or kind == "region" then
		detail = f.name
	elseif kind == "legend" then
		detail = f.legend
	elseif kind == "colour" then
		detail = ns.RenderText(L.SIGN_DETAIL_COLOUR, { variety = f.variety, species = f.species })
	elseif kind == "hunt" then
		detail = f.hunt
	elseif kind == "monster" then
		detail = ns.RenderText(L.SIGN_DETAIL_MONSTER, { species = f.monster, length = f.length })
	end
	return {
		kind = kind,
		kicker = ns.RenderText(L.SIGN_KICKER[kind], f),
		head = ns.RenderText(L.SIGN_HEAD[kind], f),
		detail = detail,
		more = more and ns.RenderText(L.SIGN_MORE, { count = more }) or nil,
		emblem = EMBLEMS[kind],
	}
end

local function has(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

--- Runs what follows `/pagle dev sign`: a look, then a kind (first by default), then `more` for the "+11 more" line.
---@param args string
function ns.RunNewsSignDev(args)
	local L = ns.L
	local words = {}
	for word in args:lower():gmatch("%S+") do
		words[#words + 1] = word
	end
	local look, kind, more = words[1], words[2] or "first", words[3] == "more" or words[2] == "more"
	if kind == "more" then
		kind = "first"
	end
	if not look or not ns.NEWS_SIGN_LOOKS[look] or not has(ns.NEWS_SIGN_KINDS, kind) then
		print(ns.RenderText(L.DEV_SIGN_USAGE, {
			looks = table.concat(ns.NEWS_SIGN_LOOK_ORDER, ", "),
			kinds = table.concat(ns.NEWS_SIGN_KINDS, ", "),
		}))
		return
	end
	if Pagle.IsRestricted() then
		print(L.DEV_SIGN_WAITING)
	end
	print(ns.RenderText(L.DEV_SIGN_DROPPED, { look = look, kind = kind }))
	ns.DropNewsSign(look, ns.NewsSignSample(kind, more and kind ~= "region" and 11 or nil))
end
