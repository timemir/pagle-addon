if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The seams later Tackle Board tickets meet at, so none waits on another's wiring (M7 graph, conventions). Each is a
-- field of ns with a stand-in here; the ticket that owns it replaces the field, and every caller calls it through ns
-- at call time (`ns.IsStarted()`, never a copy made at load), so the replacement reaches them all.
--
--   ns.ToggleBoard()          Opens the board, or closes it if shown (TKB-R1). Registration's view, the compartment
--                             entry and `/pagle board` call it. Defined in adapter/Board.lua (#238), not here: a stand-in
--                             here too would be a duplicate field for LuaLS.
--   ns.OpenBoard(goalID?)     Opens the board (never closes it); with a goal ID, highlights that goal's pin for 2 s
--                             (TKB-R109; the pins' ticket #239 draws the highlight). The Settings status button calls
--                             it, and the tracker's lines with their goal (#241). Defined in adapter/Board.lua (#238).
--   ns.State()                The projection's TackleBoardState (below), read-only for views but the live step's
--                             AdvanceTo (TKB-R14). `ns.projection:GetState()` once the adapter's OnInitialize has made
--                             the projection (#231); a new empty state before its first build, or with no projection.
--   ns.IsUpdating()           Whether the projection is catching up or rebuilding (LOG-R74): Start and "take it down"
--                             are disabled and views draw "Updating…" (TKB-R108, TKB-R124). `ns.projection:IsUpdating()`
--                             (#231): true from load until the first build ends; false with no projection.
--   ns.IsStarted()            Whether the board is started: the projection has applied a `start` record (TKB-R6).
--                             Registration's status button reads it (TKB-R1). Follows ns.State() (#231).
--   ns.Start()                Starts the board (TKB-R5): appends the `start` record and runs the live step. Called by
--                             the "Start my board" status button (registration, only when not started and not updating)
--                             and the empty board's Start button (adapter/Board.lua). Defined in logic/LiveStep.lua
--                             (#233), not here.
--   ns.TakeDown(goalID)       Takes a goal down (TKB-R55, TKB-R56): its confirm, then the `reroll` record. The pins
--                             (#239) call it. Stand-in: does nothing. The reroll's ticket (#234) assigns it.
--   ns.CanTakeDown(goalID)    Whether a goal's "take it down" shows and works now (TKB-R55). Stand-in: false. #234
--                             assigns it.
--   ns.ScheduleLiveStep()     Schedules the live step for the next frame (TKB-R13, TKB-R84). The projection's `done`
--                             calls it last (#231). Defined in adapter/LiveStep.lua (#233), not here.
--   ns.ReportCoins()          Reports lifetime Coins with M:ReportCoinsEarned (TKB-R63). `done` calls it before
--                             ns.ScheduleLiveStep (#231), and the projection's apply after a live entry that changes the
--                             Coins (#232). Reports ns.State().coins once started.
--   ns.InLoginWindow()        Whether an advance now is "at login": from login until the login's first live step has
--                             finished (TKB-R86's Campfire nods). The moments (#235) read it. Defined in
--                             logic/LiveStep.lua (#233), not here.
--   ns.OnRedraw(fn)           Subscribes a view (the board, the tracker) to redraws: fn(reason, detail) is called at
--                             every ns.Redraw, in subscription order. Subscribe once, when the view is made.
--   ns.Redraw(reason, detail) Asks every subscribed view to redraw. Callers and their reasons: "projection" after each
--                             live apply that changes the state and after each done (#231); "completed" with the goal ID
--                             as detail when a goal completes live (#232; the tracker flashes it, TKB-R123); "names"
--                             when an item name arrives (#228, GET_ITEM_INFO_RECEIVED); "step" after each live step
--                             (#233). A view that is hidden may ignore it.
--   ns.outlets                What the Tackle Board celebrates, called from the projection and the live step and filled
--                             by the moments' ticket (#235) in logic/Moments.lua, not here (a stand-in here too would
--                             be a duplicate field for LuaLS):
--     .Completed(goal, cast, earned, mode)  a goal completed in apply (#232): the TackleGoal, the completing Cast, what
--                             it earned (TackleEarned) and the apply's mode ("live", "replay" or "rebuild", LOG-R72)
--     .Advanced(result, mode) the projection advanced across board days (#231): the Campfire's outcome
--                             (TackleAdvance) and the mode, "live" for the live step's own advance (#233)
--     .Done(state, info)      the projection's done (#231), first in it (TKB-R84): the state and Core's done info
--     .Stepped()              a live step finished (#233): the summary line (TKB-R87)
--   ns.api                    The WoW calls board days read (TKB-R10, TKB-R11, TKB-R13): `GetServerTime`, `C_DateAndTime`,
--                             `GetGameTime` and `GetCurrentRegion`, as the client has them (a missing one is nil). The
--                             adapter sets it at file load; specs replace it (spec/Pagle_TackleBoard/support.lua). Days
--                             (#226) take it as `api`.
--   ns.random(m, n)           The random source generation draws from, like math.random (TKB-R30–R34). The adapter sets
--                             math.random at file load; specs replace it. Generation (#227) takes it in its context.
--
-- The goal ID handed to OpenBoard, TakeDown and CanTakeDown is the entry ID of the record that issued the goal (TKB-R23).

---@alias TackleGoalType "n"|"e"                  -- Notice, Expedition
---@alias TackleGoalKind "haul"|"variety"|"wanderer"|"quality"|"size"|"collector"|"lure"|"species"
---@alias TackleDayLog "lit"|"burned"|"out"|"unlit"
---@alias TackleApplyMode "live"|"replay"|"rebuild"

--- A goal's definition (M7 graph, shapes): what generation (#227) returns, the `issue` and `reroll` records carry
--- (tackle-board.md › Data) and the projection (#231) decodes. A Variety Expedition has `target` = its zone and `items`
--- = its representative items, ascending; a Notice of a kind with an empty target (`wanderer`, `collector`, `lure`) has
--- no `target`.
---@class TackleGoalDef
---@field type TackleGoalType
---@field kind TackleGoalKind
---@field tier integer               -- 1–3 for a Notice, 0 for an Expedition (TKB-R34)
---@field pay integer                -- Coins (TKB-R34)
---@field need integer               -- TKB-R34
---@field target? integer            -- zone, continent, minimum quality or band, or representative item
---@field items? integer[]           -- Variety Expedition: representative items, ascending

--- A goal on the board (tackle-board.md › Projection): its definition, from its record, and its progress.
---@class TackleGoal : TackleGoalDef
---@field id string                  -- TKB-R23: the entry ID of the record that issued it
---@field seq integer                -- seq of the record that issued it
---@field reposted boolean           -- issued by a `reroll`: it can't be taken down (TKB-R55)
---@field pin? integer               -- index in pins of its type; nil while in the overflow strip (TKB-R101)
---@field issuedDay integer
---@field time integer               -- server time of its record
---@field progress integer
---@field seen { [any]: true }       -- distinct keys for distinct-count kinds
---@field session? string            -- session-bound: the Session its progress belongs to (TKB-R41)
---@field doneDay? integer
---@field doneTime? integer
---@field doneCast? string           -- entry ID of the completing Cast (for TKB-R84's summary-only moments)
---@field fly? string                -- pattern ID tied (TKB-R62)

--- The projection's state (`PagleTackleBoardDB.global.board`, tackle-board.md › Projection).
---@class TackleBoardState
---@field started? { seq: integer, time: integer }
---@field boundary? { seq: integer, day: integer, week: integer, dayStart: integer, weekStart: integer }  -- latest start/day record
---@field day integer                 -- last processed board day (TKB-R14)
---@field week integer
---@field owed { notices: integer, expeditions: integer }
---@field pins { expeditions: (string|false)[], notices: (string|false)[] }   -- goal IDs per pin (TKB-R101)
---@field goals { [string]: TackleGoal }   -- open goals, and goals completed in the last 28 board days
---@field tally { notices: integer, expeditions: integer }
---@field coins integer               -- lifetime Coins earned (TKB-R63)
---@field flies { [string]: { day: integer, time: integer, goal: TackleGoal } }  -- tied patterns, with a copy of the goal that tied it
---@field titles { [string]: { day: integer, cast: string } }  -- titleID -> board day and Cast entry ID it was earned on
---@field fire { count: integer, kindling: integer, longest: integer, milestones: { [integer]: { day: integer, cast: string } }, log: { [integer]: TackleDayLog } }  -- log keeps the last 28 days
---@field zones { [integer]: integer }   -- zone areaID -> time of the Angler's last Cast there
---@field caught { [integer]: true }     -- every item ID ever caught (TKB-R46)

--- What one completion earned (TKB-R60), handed to ns.outlets.Completed (logic/Completions.lua, #232).
---@class TackleEarned
---@field pay integer                 -- the goal's pay (TKB-R34)
---@field coins integer               -- the goal's pay plus any Campfire milestone's Coins
---@field fly? string                 -- pattern ID tied (TKB-R62); nil when its pool was empty
---@field titles string[]             -- title IDs earned, in TKB-R60's order: tally, Campfire, Fly Box
---@field milestone? { days: integer, coins: integer, title: string }  -- Campfire milestone reached (TKB-R73)
---@field lit boolean                 -- this completion lit its day (TKB-R70)

--- The projection's state (`ns.projection:GetState()`, bound by the adapter's OnInitialize, #231): a new empty
--- TackleBoardState (ns.NewBoardState) before its first build, or with no projection.
---@return TackleBoardState
function ns.State()
	local projection = ns.projection
	return projection and projection:GetState() or ns.NewBoardState()
end

--- Whether the projection is catching up or rebuilding, or waiting for login to start it (LOG-R74,
--- `ns.projection:IsUpdating()`); false with no projection.
---@return boolean
function ns.IsUpdating()
	local projection = ns.projection
	return projection ~= nil and projection:IsUpdating()
end

--- Whether the board is started (TKB-R6): the projection's state has applied a `start` record.
---@return boolean
function ns.IsStarted()
	return ns.State().started ~= nil
end

--- Takes a goal down (TKB-R55). A stand-in until the reroll's ticket assigns the real one.
---@param goalID string
function ns.TakeDown(goalID) end -- luacheck: no unused args

--- Whether a goal can be taken down now (TKB-R55): false until the reroll's ticket assigns the real one.
---@param goalID string
---@return boolean
function ns.CanTakeDown(goalID) -- luacheck: no unused args
	return false
end

--- Reports lifetime Coins to Core (TKB-R63, SHOP-R2): the projection's `coins` with M:ReportCoinsEarned. Nothing
--- before Start (TKB-R2: silent until started) or without a Module handle (an inert Module, CORE-R13).
function ns.ReportCoins()
	local module = ns.Module
	if module and ns.IsStarted() then
		module:ReportCoinsEarned(ns.State().coins)
	end
end

local redrawn = {} -- the subscribed views' redraws, in subscription order

--- Subscribes a view to redraws: `fn(reason, detail)` runs at every ns.Redraw.
---@param fn fun(reason: string, detail: any)
function ns.OnRedraw(fn)
	redrawn[#redrawn + 1] = fn
end

--- Asks every subscribed view to redraw, in subscription order.
---@param reason "projection"|"completed"|"names"|"step"|string why (see the header)
---@param detail any what changed: the goal ID for "completed", else nil
function ns.Redraw(reason, detail)
	for _, fn in ipairs(redrawn) do
		fn(reason, detail)
	end
end

--- What the Tackle Board celebrates (TKB-R83–R87): Completed, Advanced, Done and Stepped, defined in
--- logic/Moments.lua (#235).
---@class TackleOutlets
ns.outlets = {}
