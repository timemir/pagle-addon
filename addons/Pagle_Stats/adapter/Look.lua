if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's First look (core/onboarding.md › First looks; ONB-R55–R59, ONB-R90; board "First look · Stats"):
-- five notes on the place spread of Where I am with a fish's entry chosen, as the canvas draws them: the list's odds and
-- "since", Your odds, the Dry spell and "nothing is owed", Watch, and "Stats never pops up". Core draws the notes and
-- the coach bar (ONB-R92); this file says what each note points at and when the set shows, through Stats' handle
-- alone (ADR 0001), each call only on a Core that has it (ONB-R90). The book's "?" beside its close is
-- Core's shell's (BOOK-R15), its click adapter/Book.lua's.
--
-- The book opens on the home spread (STA-R70), which has none of the set's regions. So the first time the set would
-- show, the book opens on its spread instead: on an opening at the home spread it turns to that spread before it is
-- seen, asks Core for the set, and turns back to the home spread when Core shows nothing (seen already, or Margin
-- notes off). It tries that once a login: Core tells a Module neither, so after Core has said no, the book opens on
-- the home spread without drawing the other first. Core marks the set seen only as it shows, so a book that can't
-- reach the spread (zone 0, a water with no rows, the projection updating) leaves it for a later opening; and an
-- opening on a fish's entry shows it there whenever it is still unseen.

local L = ns.L

--- The set's id: Stats' own, "<module>.<window>" (ONB-R56).
ns.BOOK_LOOK_ID = "stats.book"

-- Each note's width, the probe's, and where it sits in the book's units from its top left: in the left margin, its
-- right edge 14 units off the leather, or the right margin, 14 past the book's 980 units (adapter/Book.lua's width);
-- down from the book's top as the canvas has them, beside what each points at (ONB-R58).
local NOTE_W = 196
local LEFT_X, RIGHT_X = -(NOTE_W + 14), 980 + 14

-- Whether the book turned to the set's spread on an opening this login and Core showed nothing: it doesn't again.
local declined = false

--- Whether this Core has First looks (ONB-R90): the book's "?" shows only then.
---@return boolean
function ns.HasBookLook()
	local M = ns.Module
	return M ~= nil and M.ShowFirstLook and true or false
end

-- The entry on the spread shown now, or nil unless the book shows a place page with a fish's entry drawn: the set's
-- regions are all there, so elsewhere each note points at nothing and drops (ONB-R56).
---@return StatsEntryView?
local function shownEntry()
	local book = ns.book
	if not book:IsShown() or ns.IsUpdating() then
		return nil
	end
	local place = book:Place()
	if place.page ~= "place" or not place.item then
		return nil
	end
	local right = book:Drawn("place", "right")
	local frame = right and ns.PlaceEntryFrame(right.content)
	local view = frame and frame.entryView
	if view and view.toggle:IsVisible() then
		return view
	end
	return nil
end

-- The spread the set shows on (ns.BookLookTarget): `area`'s place page with a fish chosen, or Where I am's with none
-- given; nil while the projection updates or with no place.
---@param area integer?
---@return StatsBookTarget?
local function lookTarget(area)
	if ns.IsUpdating() then
		return nil
	end
	local conditions = Pagle.GetConditions()
	area = area or ns.CurrentPlace(conditions)
	if area == nil then
		return nil
	end
	return ns.BookLookTarget(area, ns.Groups(ns.State(), area, ns.EffectiveSkill(conditions)))
end

-- A note's target: what `find` picks on the set's spread, nil off it.
---@param find fun(entry: StatsEntryView): Region?
---@return fun(): Region?
local function onSpread(find)
	return function()
		local entry = shownEntry()
		return entry and find(entry) or nil
	end
end

--- The book's First look (ONB-R57), registered at OnInitialize (adapter/Stats.lua); its tour stop opens the book on its
--- spread (ONB-R84).
---@return PagleFirstLook
function ns.BookFirstLook()
	return {
		id = ns.BOOK_LOOK_ID,
		window = function()
			return ns.book.frame
		end,
		title = L.LOOK_TITLE,
		open = function()
			ns.OpenBook(lookTarget())
		end,
		notes = {
			{
				-- the first row's short odds, its Dry spell in the margin beside them
				text = L.LOOK_ODDS_SINCE,
				target = onSpread(function()
					local left = ns.book:Drawn("place", "left")
					local row = left and ns.PlaceFirstRow(left.content)
					return row and row.odds
				end),
				x = LEFT_X,
				y = 120,
				w = NOTE_W,
			},
			{
				-- Your odds in large ink
				text = L.LOOK_YOUR_ODDS,
				target = onSpread(function(entry)
					return entry.headline
				end),
				x = RIGHT_X,
				y = 110,
				w = NOTE_W,
			},
			{
				-- the ruler's "Every Cast is its own roll; nothing is owed.", or the Dry spell's heading with no ruler
				-- (STA-R54) or one fading out at a catch
				text = L.LOOK_DRY_SPELL,
				target = onSpread(function(entry)
					if entry.ruler:IsShown() and not entry.rulerResting then
						return entry.ruler.owed
					end
					return entry.dryHeading
				end),
				x = RIGHT_X,
				y = 290,
				w = NOTE_W,
			},
			{
				-- the watch toggle (STA-R60, STA-R61)
				text = L.LOOK_WATCH,
				target = onSpread(function(entry)
					return entry.toggle
				end),
				x = RIGHT_X,
				y = 0,
				w = NOTE_W,
			},
			{
				-- the nameplate on the leather's foot band
				text = L.LOOK_NEVER_POPS_UP,
				target = onSpread(function()
					return ns.book.frame.plate
				end),
				x = LEFT_X,
				y = 420,
				w = NOTE_W,
			},
		},
	}
end

--- The book has opened and drawn (adapter/Book.lua's Book:Open): its First look, the first time (ONB-R55). On the
--- set's spread it shows there; on the home spread the book turns to the set's spread for it, and back when Core
--- shows nothing, once a login; anywhere else it waits for a later opening.
function ns.ShowBookLook()
	local M = ns.Module
	if not (M and M.ShowFirstLook) then
		return
	end
	if shownEntry() then
		M:ShowFirstLook(ns.BOOK_LOOK_ID)
		return
	end
	local book = ns.book
	if declined or book:Place().page ~= "home" then
		return
	end
	local target = lookTarget()
	if not target then
		return
	end
	book:Open(target, { motion = "still" })
	if not M:ShowFirstLook(ns.BOOK_LOOK_ID) then
		declined = true
		book:Open({ page = "home" }, { motion = "still" })
	end
end

--- The "?" pressed (ONB-R59): the set again, seen or not and with Margin notes off, the book turning to its spread
--- first when it shows another (a fish chosen on the place page shown, else Where I am's); pressed while the set
--- shows, Core hides it.
function ns.ShowBookLookAgain()
	local M = ns.Module
	if not (M and M.ShowFirstLook) then
		return
	end
	if not shownEntry() then
		local place = ns.book:Place()
		local target = (place.page == "place" and lookTarget(place.area)) or lookTarget()
		if target then
			ns.book:Open(target)
		end
	end
	M:ShowFirstLook(ns.BOOK_LOOK_ID, true)
end
