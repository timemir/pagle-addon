if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- An item's entry on a place's page (stats.md › UI › Place spread, the item's entry): its reading (STA-R40) in words,
-- Your odds in full (STA-R43, STA-R45, STA-R46), its Dry spell (STA-R50–R54) and my records of it. Pure logic: the
-- projection's state, the live skill and the place tables come in as arguments (CORE-R7); adapter/Entry.lua draws
-- what this returns. A watched item that has left the place's rows (STA-R60) reads like any other: nothing here looks
-- at the rows.

--- An item's entry, in words.
---@class StatsEntry
---@field reading StatsReading
---@field kicker string          -- "Your odds · {place}", plus ", {window name}" with a window
---@field headline string        -- Your odds in large ink: "about 1 in 30", "Learning…", "not seen yet"
---@field bar number?            -- the learning bar's share, n / 100, only while learning
---@field range string?          -- the range (STA-R45), only when known
---@field sentence string        -- the scope line when known; the learning or unseen sentence otherwise
---@field notes string?          -- STA-R46's extra sentences that apply, joined; nil for none
---@field dryFirst string        -- the Dry spell's first sentence (STA-R50, STA-R53, STA-R54)
---@field dryAfter string?       -- the luck wording, or the learning line; nil after a bare count or a Dry spell of 0
---@field luck number?           -- the luck reading's P (STA-R51): the luck ruler's mark; nil for no ruler
---@field records { label: string, value: string }[]  -- *In my records*: Caught in this count, Caught anywhere,
---                                 First caught and Last caught
---@field link StatsBookTarget   -- "Every water it bites in ☛": the item's page

--- The luck ruler's ticks (UI › Place spread), left to right: `P` from 1 ("all") to 10⁻⁶ ("1 in 1M"), a power of ten
--- each, so on the ruler's log scale (ns.RulerPosition) each is a sixth further along. Labels are ns.L.RULER_TICKS.
ns.LUCK_RULER_TICKS = { 1, 1e-1, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6 }

--- An item's entry in `area` (UI › Place spread).
---@param state StatsState the projection's state (ns.State())
---@param item integer
---@param area integer the page's place
---@param live integer? the live effective skill, nil when unknown (STA-R41)
---@param places StatsPlaceTables? `ns.places` if nil
---@return StatsEntry
function ns.Entry(state, item, area, live, places)
	places = places or ns.places
	local L = ns.L
	local reading = ns.Reading(state, item, area, live, places)
	local notes = ns.OddsNotes(reading, places)
	local kicker = L.ENTRY_KICKER:format(ns.AreaName(area))
	if reading.windowName then
		kicker = L.ENTRY_KICKER_WINDOW:format(kicker, reading.windowName)
	end
	local dryFirst, dryAfter = ns.DrySpellText(reading)
	local total = state.items[item]
	return {
		reading = reading,
		kicker = kicker,
		headline = ns.OddsHeadline(reading),
		bar = reading.state == "learning" and reading.n / ns.ODDS_THRESHOLD or nil,
		range = ns.OddsRange(reading),
		sentence = ns.OddsSentence(reading),
		notes = #notes > 0 and table.concat(notes, ns.L.SENTENCE_JOIN) or nil,
		dryFirst = dryFirst,
		dryAfter = dryAfter,
		luck = ns.DrySpell(reading).P,
		records = {
			{ label = L.ENTRY_CAUGHT_HERE, value = ns.Number(reading.k) },
			{ label = L.ENTRY_CAUGHT_ANYWHERE, value = ns.Number(total and total.n or 0) },
			{ label = L.ITEM_FIRST_CAUGHT, value = total and ns.Date(total.first) or L.ITEM_NEVER },
			{ label = L.ITEM_LAST_CAUGHT, value = total and ns.Date(total.last) or L.ITEM_NEVER },
		},
		link = { page = "item", item = item },
	}
end
