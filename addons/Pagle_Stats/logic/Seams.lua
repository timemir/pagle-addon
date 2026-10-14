if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The seams later Stats tickets meet at, so none waits on another's wiring (M6 graph, open question 3). Each is a
-- field of ns with a stand-in here; the ticket that owns it replaces the field, and every caller calls it through
-- ns at call time (`ns.State()`, never a copy made at load), so the replacement reaches them all.
--
--   ns.ToggleBook()           Opens the Stats book, or closes it if shown (STA-R70). Registration's view, the
--                             compartment entry, the "Open Stats" button and `/pagle stats` call it (STA-R4); so does
--                             the tracker header. Stand-in: does nothing. The book's ticket (#211) assigns the real one
--                             when its file loads.
--   ns.OpenBook(target?)      Opens the book (never closes it) on `target`, a StatsBookTarget, or where it was left
--                             (STA-R70) with none. The place page's rows, the item page, search, Lifetime and the
--                             tracker's lines call it. Stand-in: does nothing. The book's ticket (#211) assigns it.
--   ns.State()                The projection's StatsState (stats.md › Projection state). Read-only for views.
--                             Stand-in: a new empty state each call. The projection's ticket (#203) binds it to
--                             `projection:GetState()` in OnInitialize.
--   ns.IsUpdating()           Whether the projection is catching up or rebuilding (LOG-R74): views then draw nothing
--                             from ns.State() (STA-R72, STA-R85). Stand-in: false. The projection's ticket (#203)
--                             binds it.
--   ns.OnRedraw(fn)           Subscribes a view (the book, the tracker) to redraws: fn(reason) is called at every
--                             ns.Redraw, in subscription order. Subscribe once, when the view is made.
--   ns.Redraw(reason)         Asks every subscribed view to redraw (STA-R73, STA-R91). Callers and their reasons:
--                             "projection" after each live apply that changes the state and after each done (#203),
--                             "watches" when a watch is added or stopped (#208). A view that is hidden may ignore it.

---@alias StatsBookPage "home"|"place"|"item"|"session"|"lifetime"|"sessions"

--- Where ns.OpenBook opens the book (stats.md › UI): a spread or page, with the place, item or Session it shows.
---@class StatsBookTarget
---@field page StatsBookPage
---@field area integer?       -- the place, a zone or subzone areaID ("place", and "item" when opened from a place)
---@field item integer?       -- the item ID ("item", or an entry chosen on a "place" spread)
---@field session string?     -- Core's Session ID ("session")

--- Opens or closes the Stats book (STA-R70). A stand-in until the book's ticket assigns the real one.
function ns.ToggleBook() end

--- Opens the Stats book on `target`, or where it was left with none (STA-R70). A stand-in until the book's ticket
--- assigns the real one.
---@param target StatsBookTarget?
function ns.OpenBook(target) end -- luacheck: no unused args

-- The projection's state, as stats.md › Projection state gives it; the projection's ticket fills it in. Scope keys
-- are "<area>:<side>" and "<area>:<side>:<windowID>", hit keys "<scope>#<itemID>", sides "hi", "lo" or "na"
-- (STA-R13, STA-R23, STA-R24).

---@alias StatsSide "hi"|"lo"|"na"

---@class StatsState
---@field totals StatsCounts                      -- every Cast (STA-R22)
---@field places table<integer, StatsPlace>       -- by zone or subzone areaID, never 0 (STA-R10, STA-R22)
---@field chars table<integer, StatsCounts>       -- by the Catch log's character index (STA-R22)
---@field scopes table<string, integer>          -- Casts per scope key (STA-R23)
---@field hits table<string, StatsHit>           -- by hit key (STA-R24)
---@field items table<integer, StatsItemTotal>   -- by item ID, item 0 left out (STA-R25)
---@field margins table<"lo50"|"lo1"|"hi0"|"hi25", StatsMargin>   -- by skill margin bucket (STA-R26)
---@field lastRank table<integer, integer>        -- each character's last Skill Reading rank (STA-R27)
---@field sessions StatsSession[]                 -- one record per Session, oldest first (STA-R30)

---@class StatsCounts
---@field casts integer
---@field catches integer     -- entries in the Casts' `items`, item 0 included (STA-R22)
---@field gotAway integer

---@class StatsPlace : StatsCounts
---@field zone integer        -- the Cast's zone: the area itself for a zone, its parent for a subzone (STA-R22)
---@field items table<integer, integer>   -- catches by item ID, item 0 left out (STA-R22)

---@class StatsHit
---@field n integer           -- Casts in the scope that caught the item (STA-R24)
---@field at integer          -- the scope's count after the latest such Cast (STA-R24)
---@field last integer        -- that Cast's server time (STA-R24)

---@class StatsItemTotal
---@field n integer           -- catches of the item, every place (STA-R25)
---@field first integer       -- the first one's server time
---@field last integer        -- the latest one's server time

---@class StatsMargin
---@field casts integer
---@field gotAway integer

---@class StatsSession : StatsCounts
---@field id string           -- Core's Session ID (LOG-R98)
---@field startTime integer   -- its first Cast's server time
---@field endTime integer     -- its latest Cast's server time
---@field chars table<integer, integer>   -- Casts by character index
---@field zones table<integer, integer>   -- Casts by zone areaID, zone 0 left out
---@field items table<integer, integer>   -- catches by item ID, item 0 left out
---@field skill integer       -- skill gained (STA-R27)

--- The projection's state: a new empty StatsState until the projection binds it.
---@return StatsState
function ns.State()
	local function margin()
		return { casts = 0, gotAway = 0 }
	end
	return {
		totals = { casts = 0, catches = 0, gotAway = 0 },
		places = {},
		chars = {},
		scopes = {},
		hits = {},
		items = {},
		margins = { lo50 = margin(), lo1 = margin(), hi0 = margin(), hi25 = margin() },
		lastRank = {},
		sessions = {},
	}
end

--- Whether the projection is catching up or rebuilding (LOG-R74): false until the projection binds it.
---@return boolean
function ns.IsUpdating()
	return false
end

local redrawn = {} -- the subscribed views' redraws, in subscription order

--- Subscribes a view to redraws: `fn(reason)` runs at every ns.Redraw (STA-R73).
---@param fn fun(reason: string)
function ns.OnRedraw(fn)
	redrawn[#redrawn + 1] = fn
end

--- Asks every subscribed view to redraw, in subscription order (STA-R73).
---@param reason "projection"|"watches"|string why: a projection change, a watch added or stopped
function ns.Redraw(reason)
	for _, fn in ipairs(redrawn) do
		fn(reason)
	end
end
