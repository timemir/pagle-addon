if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' seams, so no file waits on another's wiring. Each is a field of ns with a stand-in here; the file that owns
-- it replaces the field, and every caller calls it through ns at call time (`ns.State()`, never a copy made at load),
-- so the replacement reaches them all.
--
--   ns.ToggleBoard()          Opens the Hunts board, or closes it if shown (HNT-R68). Registration's view and
--                             `/pagle hunts` call it (HNT-R135). Defined by the board, adapter/Board.lua.
--   ns.OpenBoard(target?)     Opens the board (never closes it), on the Board ribbon with that Hunt selected if
--                             given (a Hunt's ID, or `{ hunt = id }`, HNT-R67, HNT-R77), or that run (`{ run = runKey
--                             }`, HNT-R164): the tracker's lines call it. Defined by the board, adapter/Board.lua.
--   ns.OpenWagers(runKey?)    Opens the board on the Pagle Wagers spread (HNT-R162), on that run if given: the wager
--                             strip and the "Pagle Wagers" breadcrumb call it (HNT-R161, HNT-R164). The spread is
--                             #303's, which replaces this stand-in; until then it does nothing.
--   ns.State()                The projection's HuntsState (hunts.md › Projection state). Read-only for views.
--                             Reads `ns.projection` (logic/Projection.lua, made in OnInitialize) at call time: a
--                             new empty state each call while it has none.
--   ns.IsUpdating()           Whether the projection is catching up or rebuilding (LOG-R74, HNT-R69): views then
--                             draw nothing from ns.State(). Reads `ns.projection` at call time; false with none.
--   ns.OnRedraw(fn)           Subscribes a view (the board, the tracker, the summary line) to redraws: fn(reason) is
--                             called at every ns.Redraw, in subscription order. Subscribe once, when the view is made.
--   ns.Redraw(reason)         Asks every subscribed view to redraw (HNT-R42's last paragraph). Callers and their
--                             reasons: "groups" after each regroup, pause, pin and filter change
--                             (adapter/Groups.lua), "projection" after each live apply that changes the state and
--                             after each done (logic/Projection.lua), "names" when item names load (adapter/Names.lua).
--                             A view that is hidden may ignore it.
--   ns.SetViewShown(view, shown) A view tells the grouping it showed or hid (HNT-R42's refresh): the board
--                             ("board") and the tracker ("tracker"). Defined in adapter/Groups.lua.
--
-- Hunt Events' seams, defined in logic/Runs.lua over a HuntsState (ns.State() for views), for the run log (#300), the
-- moments (#301), the board and the tracker (#302–#304):
--
--   ns.RunsKnown(state)       Every known run as `{ key, run }` (HuntRun), by end, then start, then event ID
--                             (HNT-R150): which slots logged runs cover, and whether a run is logged yet.
--   ns.RunOn(state, t)        The known runs on at server time `t` (`start <= t < end`, HNT-R143), as `{ key, run }`,
--                             by end, then start, then event ID (HNT-R160).
--   ns.RunProgress(run, state?) A run's `done` of `total` first marks and its closest unfinished Hunt (`closest`, with
--                             `count` of `of`), and its `event` (HNT-R146, HNT-R161).
--   ns.KnownEvent(state, id)  The Hunt Event with this ID: the pool's, or a logged pushed definition's (HNT-R140,
--                             HNT-R154); nil for one unknown, incomplete or failing its checks.
--   ns.events                 The event pool at runtime (logic/Events.lua: names, notes, Hunts' names), made in
--                             OnInitialize.
--   ns.outlets.Credited(record, reached) and the `marks`, `settled` and `ladder` of each HuntsReached
--                             (logic/Projection.lua): what a live entry newly reached in runs, for the moments.
--   ns.LadderTitle(step), ns.TitlesEarned(state), ns.EventMomentIcon(event) (logic/WagerMoments.lua, Moments.lua):
--                             a ladder title's text, the set and ladder titles earned (HNT-R165's "{n} titles"), and
--                             an event's icon in a moment (#301).
--   ns.ReadContentItem, ns.WriteContentItem, ns.HuntEventProblem (logic/Content.lua), ns.EncodeRun and
--                             ns.EncodeDefParts (logic/Records.lua): reading, checking and logging pushed definitions.

-- The projection's state, as hunts.md › Projection state gives it; logic/Projection.lua fills it in.

---@class HuntsState
---@field casts integer       -- Casts applied, for the Write-up heading
---@field coins integer       -- lifetime Pagle Coins earned (HNT-R110)
---@field xp integer          -- lifetime Activity XP earned (HNT-R115)
---@field runs table<string, HuntRun>   -- by run key, every known run (HNT-R150; logic/Runs.lua)
---@field defs table<string, { parts: integer, texts: table<integer, string> }>   -- pushed definitions' parts by event ID (HNT-R154)
---@field settled integer     -- the completed-run count (HNT-R148)
---@field ladder table<integer, integer>   -- ladder step (25, 50, 100) to the server time it was earned (HNT-R148)
---@field hunts table<string, HuntProgress>   -- by Hunt ID; absent until the Hunt has effort or a Catch
---@field sets table<string, HuntsSetTitle>   -- by set ID, only once earned (HNT-R23, HNT-R87; logic/Titles.lua)
---@field hours table<integer, integer>   -- server hour to the first seq of a Cast in it, the last 14 days (HNT-R149)

---@class HuntRun
---@field event string
---@field start integer       -- server time
---@field end_ integer        -- server time (`end` in the record)
---@field source "r"|"p"
---@field hunts table<string, HuntProgress>   -- by the event's Hunt IDs, progress within this run (HNT-R145)
---@field completedAt integer?  -- server time of completion (HNT-R146)

---@class HuntProgress
---@field count integer       -- qualifying Catches (HNT-R11)
---@field effort integer      -- effort Casts (HNT-R25)
---@field sinceLast integer   -- effort Casts after the latest qualifying Catch's Cast (HNT-R26)
---@field caught boolean      -- at least one qualifying Catch
---@field reached HuntTier[]  -- one per reached tier, in tier order

---@class HuntTier
---@field time integer        -- the Cast's server time
---@field catchId string
---@field itemID integer
---@field zone integer        -- the Cast's zone areaID (0 if unresolved)
---@field date { year: integer, month: integer, day: integer }   -- the Cast's realm date (cast.conditions.date; its UTC day without one)

---@class PagleHuntsNS
---@field projection PagleProjection? -- Hunts' projection, made in OnInitialize (HNT-R136, logic/Projection.lua)

--- The projection's state (`ns.projection:GetState()`): a new empty HuntsState while there is none, before the
--- projection's first build or with no projection.
---@return HuntsState
function ns.State()
	local projection = ns.projection
	return projection and projection:GetState() or ns.NewHuntsState()
end

--- Whether the projection is catching up or rebuilding, or waiting for login to start it (LOG-R74,
--- `ns.projection:IsUpdating()`); false with no projection.
---@return boolean
function ns.IsUpdating()
	local projection = ns.projection
	return projection ~= nil and projection:IsUpdating()
end

--- Opens the Pagle Wagers spread (HNT-R162): a stand-in that does nothing until #303's spread replaces it.
---@param runKey string?
function ns.OpenWagers(runKey) -- luacheck: no unused args
end

local redrawn = {} -- the subscribed views' redraws, in subscription order

--- Subscribes a view to redraws: `fn(reason)` runs at every ns.Redraw (HNT-R42).
---@param fn fun(reason: string)
function ns.OnRedraw(fn)
	redrawn[#redrawn + 1] = fn
end

--- Asks every subscribed view to redraw, in subscription order (HNT-R42).
---@param reason "groups"|"projection"|"names"|string why: a regroup, a projection change, names loaded
function ns.Redraw(reason)
	for _, fn in ipairs(redrawn) do
		fn(reason)
	end
end
