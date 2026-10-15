if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- Dry spells (STA-R50–R55): how many Casts since the item was last caught, in the same scope as its odds, and how
-- unusual that wait is, computed when shown from a reading (#206's `ns.Reading`, in the shape the M6 graph fixes) and
-- never stored (STA-R20). Pure logic: the words go through ns.L and Stats' words (logic/Text.lua). A Dry spell earns
-- nothing, never pops up and never ends with a message (STA-R55, STA-R2): nothing here raises anything. The item's
-- entry (#214), the place rows (#213), the item page (#215), the home spread (#212) and the tracker (#218) read it.

--- A luck reading's band (STA-R52).
---@alias StatsBand "normal"|"unlucky"|"veryUnlucky"

--- The least `P` that reads normal (Tunables: Band cut-offs, unlucky below 1 in 100).
ns.UNLUCKY_BELOW = 0.01
--- The least `P` that reads unlucky (Tunables: Band cut-offs, very unlucky below 1 in 10,000).
ns.VERY_UNLUCKY_BELOW = 0.0001

--- A reading's Dry spell (STA-R50, STA-R51, STA-R52).
---@class StatsDrySpell
---@field since integer       -- Casts since the last catch in the scope, `n − hit.at`; `n` when never caught there
---@field caught boolean      -- whether the item has been caught in the scope
---@field P number?           -- the luck reading `(1 − k/n)^since`, only when Your odds is known, the item has been
---                              caught in the scope and the Dry spell isn't 0 (STA-R51, STA-R54)
---@field band StatsBand?     -- the luck reading's band, with P only

--- The band of a luck reading (STA-R52): normal at `P ≥ 0.01`, unlucky below, very unlucky below `0.0001`.
---@param P number
---@return StatsBand
function ns.Band(P)
	if P >= ns.UNLUCKY_BELOW then
		return "normal"
	elseif P >= ns.VERY_UNLUCKY_BELOW then
		return "unlucky"
	end
	return "veryUnlucky"
end

--- A reading's Dry spell (STA-R50–R52, STA-R54), from its `n`, `k`, `hit` and `state` alone.
---@param reading { n: integer, k: integer, hit: StatsHit?, state: "learning"|"unseen"|"known" }
---@return StatsDrySpell
function ns.DrySpell(reading)
	local n, hit = reading.n, reading.hit
	if not hit then
		return { since = n, caught = false }
	end
	local dry = { since = n - hit.at, caught = true }
	if reading.state == "known" and reading.k > 0 and dry.since > 0 then
		dry.P = (1 - reading.k / n) ^ dry.since
		dry.band = ns.Band(dry.P)
	end
	return dry
end

--- The least `P` whose normal wording is "Nothing unusual." alone (Tunables: Wording steps within normal, P ≥ ½).
ns.NOTHING_UNUSUAL_FROM = 0.5
--- The least `P` whose normal wording counts anglers in 100 (Tunables: Wording steps within normal, P ≥ 5%).
ns.ANGLERS_IN_100_FROM = 0.05
--- The `P` below which the first sentence reads "Fewer than 1 angler in a million" (Tunables: P < 10⁻⁶).
ns.UNDER_A_MILLION_BELOW = 1e-6

--- The `P` at the luck ruler's right end, "1 in 1M" (stats.md › UI, Place spread); its left end, "all", is 1.
ns.RULER_RIGHT = 1e-6

--- Where the luck ruler's "me" mark sits for a luck reading (stats.md › UI, Place spread): 0 at the left end (P = 1,
--- "all") to 1 at the right (P = 10⁻⁶, "1 in 1M"), on a log scale, so each tick ("1 in 10", "1 in 100", …) is a
--- sixth further along. Clamped at both ends. The item's entry (#214) only draws it.
---@param P number
---@return number
function ns.RulerPosition(P)
	if P <= ns.RULER_RIGHT then
		return 1
	elseif P >= 1 then
		return 0
	end
	return math.log(P) / math.log(ns.RULER_RIGHT)
end

--- The luck wording for a luck reading (STA-R53), by its band and the two steps inside normal; "1 in {nice(1/P)}"
--- rounds as STA-R44 says.
---@param P number
---@return string
function ns.LuckWording(P)
	local L = ns.L
	local band = ns.Band(P)
	if band == "normal" then
		if P >= ns.NOTHING_UNUSUAL_FROM then
			return L.LUCK_NOTHING_UNUSUAL
		elseif P >= ns.ANGLERS_IN_100_FROM then
			return L.LUCK_ABOUT:format(ns.Count(ns.Round(P * 100), "anglers"))
		end
		return L.LUCK_LONG_WAIT:format(ns.Nice(1 / P))
	elseif band == "unlucky" then
		return L.LUCK_UNLUCKY:format(ns.Nice(1 / P))
	elseif P < ns.UNDER_A_MILLION_BELOW then
		return L.LUCK_UNDER_A_MILLION:format(L.LUCK_VERY_UNLUCKY_ROLL)
	end
	return L.LUCK_VERY_UNLUCKY:format(ns.Nice(1 / P), L.LUCK_VERY_UNLUCKY_ROLL)
end

--- A reading's Dry spell in words (STA-R50, STA-R53, STA-R54): the first sentence and what follows it, or nil.
---   never caught in the scope:  "412 Casts here, none yet.", nil
---   a Dry spell of 0:           "Caught one on my last Cast here.", nil, whatever the odds state
---   learning:                   the first sentence, "A luck reading comes once Your odds have a number."
---   known:                      the first sentence, the luck wording (StatsDrySpell's P has the luck ruler's mark)
--- The first sentence is the entry's, "212 Casts since my last one, 3h ago.", or with `item` the tracker hover's,
--- "212 Casts since my last {item}.". `where` is the reading's ("here", "across {zone}"; STA-R46).
---@param reading { n: integer, k: integer, hit: StatsHit?, state: "learning"|"unseen"|"known", where: string }
---@param item string? the item's name, for the tracker's hover
---@return string first
---@return string? after
function ns.DrySpellText(reading, item)
	local L = ns.L
	local dry = ns.DrySpell(reading)
	if not dry.caught then
		return L.DRY_NONE_YET:format(ns.Count(dry.since, "Casts"), reading.where), nil
	elseif dry.since == 0 then
		return L.DRY_CAUGHT_LAST:format(reading.where), nil
	end
	local first
	if item then
		first = L.DRY_SINCE_TRACKER:format(ns.Count(dry.since, "Casts"), item)
	else
		first = L.DRY_SINCE_ENTRY:format(ns.Count(dry.since, "Casts"), ns.TimeAgo(reading.hit.last))
	end
	if dry.P then
		return first, ns.LuckWording(dry.P)
	end
	return first, L.DRY_LEARNING
end

--- A band in a word (STA-R52, STA-R82): "normal", "unlucky" or "very unlucky".
---@param band StatsBand
---@return string
function ns.BandWord(band)
	return ns.L.BANDS[band]
end

--- Whether a band is unlucky or very unlucky (STA-R52): the views write those in red.
---@param band StatsBand?
---@return boolean
function ns.IsUnlucky(band)
	return band == "unlucky" or band == "veryUnlucky"
end

-- ", unlucky" or ", very unlucky" when the Dry spell's band is one of them, else nil.
---@param dry StatsDrySpell
---@return string?
local function unluckySuffix(dry)
	if ns.IsUnlucky(dry.band) then
		return ns.L.DRY_SHORT_BAND:format(ns.BandWord(dry.band))
	end
	return nil
end

--- A reading's Dry spell in short, for a row's margin and a tile (stats.md › UI, Place spread and Item page):
--- "212 since", with ", unlucky" or ", very unlucky" as a second value when it applies (the views write it in red),
--- "just now" for 0, and nothing when the item has never been caught in the scope.
---@param reading { n: integer, k: integer, hit: StatsHit?, state: "learning"|"unseen"|"known" }
---@return string? text
---@return string? band
function ns.DrySpellShort(reading)
	local dry = ns.DrySpell(reading)
	if not dry.caught then
		return nil
	elseif dry.since == 0 then
		return ns.L.DRY_JUST_NOW
	end
	return ns.L.DRY_SHORT_SINCE:format(ns.Number(dry.since)), unluckySuffix(dry)
end

--- The end of a home spread watch line, after "✎ {item}, {place}: " (stats.md › UI, Home spread): "212 since the
--- last, unlucky.", "caught on my last Cast." for 0, or "412 Casts, none yet." when never caught in the scope.
---@param reading { n: integer, k: integer, hit: StatsHit?, state: "learning"|"unseen"|"known" }
---@return string
function ns.DrySpellWatchText(reading)
	local L = ns.L
	local dry = ns.DrySpell(reading)
	if not dry.caught then
		return L.DRY_WATCH_NONE_YET:format(ns.Count(dry.since, "Casts"))
	elseif dry.since == 0 then
		return L.DRY_WATCH_CAUGHT_LAST
	end
	return L.DRY_WATCH_SINCE:format(ns.Number(dry.since), unluckySuffix(dry) or "")
end

--- A watch's count on the tracker (STA-R82): the Dry spell, the bare `n` when never caught in the scope, "just now"
--- for 0.
---@param reading { n: integer, k: integer, hit: StatsHit?, state: "learning"|"unseen"|"known" }
---@return string
function ns.DrySpellCount(reading)
	local dry = ns.DrySpell(reading)
	if dry.caught and dry.since == 0 then
		return ns.L.DRY_JUST_NOW
	end
	return ns.Number(dry.since)
end
