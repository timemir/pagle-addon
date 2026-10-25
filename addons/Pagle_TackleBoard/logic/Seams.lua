if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The seams the Tackle Board's files meet at. Each is a field of ns, defined once (here, or in the file named), and
-- every caller calls it through ns at call time (`ns.IsStarted()`, never a copy made at load), so a spec that replaces
-- one reaches every caller. logic/ reaches Core and the client only through these: ns.api and ns.random for the
-- client's calls, Core and the draws, and the adapter's seams below for what needs the Module handle, the DB or a timer.
--
--   ns.ToggleBoard()          Opens the board, or closes it if shown (TKB-R1). Registration's view, the compartment
--                             entry and `/pagle board` call it. Defined in adapter/Board.lua.
--   ns.OpenBoard(goalID?)     Opens the board (never closes it); with a goal ID, highlights that goal's pin for 2 s
--                             (TKB-R109, drawn by adapter/Pins.lua). The Settings status button calls it, and the
--                             tracker's lines with their goal. Defined in adapter/Board.lua.
--   ns.State()                The projection's TackleBoardState (below), read-only for views but the live step's
--                             AdvanceTo (TKB-R14). `ns.projection:GetState()` once the adapter's OnInitialize has made
--                             the projection; a new empty state before its first build, or with no projection.
--   ns.IsUpdating()           Whether the projection is catching up or rebuilding (LOG-R74): Start and "take it down"
--                             are disabled and views draw "Updating…" (TKB-R108, TKB-R124). `ns.projection:IsUpdating()`:
--                             true from load until the first build ends; false with no projection.
--   ns.IsStarted()            Whether the board is started: the projection has applied a `start` record (TKB-R6).
--                             Follows ns.State(), so a rebuild reads false until it applies the `start` record again.
--   ns.KnownStarted()         Whether the board is known to be started (TKB-R6) across an update: while the projection
--                             updates, also when the stored projection, which a rebuild replaces only at its done
--                             (LOG-R72), is started. The status button's label (TKB-R1), the board's empty slip and
--                             Start (TKB-R5), the Trackers checkbox (SET-R43) and the tracker (TKB-R120) read it.
--                             Defined in adapter/TackleBoard.lua.
--   ns.Start()                Starts the board (TKB-R5): appends the `start` record and runs the live step. Called by
--                             the "Start my board" status button (registration, only when not started and not updating)
--                             and the empty board's Start button (adapter/Board.lua). Defined in adapter/LiveStep.lua.
--   ns.TakeDown(goalID)       Takes a goal down (TKB-R55, TKB-R56): its confirm, then the `reroll` record. adapter/Pins.lua
--                             calls it. Defined in adapter/Reroll.lua.
--   ns.CanTakeDown(goalID)    Whether a goal's "take it down" shows (TKB-R55), whatever the projection's updating: the
--                             pins grey it while ns.IsUpdating() (TKB-R108), and ns.TakeDown refuses then. Defined in
--                             adapter/Reroll.lua.
--   ns.Post(goalType)         Spends a Refresh on an empty slot (TKB-R58, TKB-R59): its confirm, then the `post` record.
--                             adapter/Pins.lua calls it from an empty pin's click. Defined in adapter/Reroll.lua.
--   ns.CanPost(goalType)      Whether a Refresh can post a goal of `goalType` now (TKB-R58): started, not updating, one
--                             held and an empty pin of the type. The empty pins are clickable while it holds. Defined in
--                             adapter/Reroll.lua.
--   ns.RefreshesHeld()        The Refreshes held, `Pagle.GetTickets().tickets` (REF-R5): the pins' clicks and the ledge's
--                             count (TKB-R58, TKB-R106) read it. Defined here.
--   ns.ReportTickets()        Reports lifetime Refreshes spent with M:ReportTicketsSpent (TKB-R58, REF-R2): `done` calls
--                             it after ns.ReportXP, and the projection's apply after a live entry that changes it.
--                             Reports ns.State().ticketsSpent, 0 before Start. Defined in adapter/Moments.lua.
--   ns.ScheduleLiveStep()     Schedules the live step for the next frame (TKB-R13, TKB-R84). The projection's `done`
--                             calls it last. Defined in adapter/LiveStep.lua.
--   ns.InLoginWindow()        Whether an advance now is "at login": from login until the login's first live step has
--                             finished (TKB-R86's Campfire nods). logic/Moments.lua reads it. Defined in
--                             adapter/LiveStep.lua.
--   ns.ReportCoins()          Reports lifetime Coins with M:ReportCoinsEarned (TKB-R63). `done` calls it before
--                             ns.ScheduleLiveStep, and the projection's apply after a live entry that changes the Coins.
--                             Reports ns.State().coins, 0 before Start (SHOP-R2). Defined in adapter/Moments.lua.
--   ns.ReportXP()             Reports lifetime Activity XP with M:ReportXPEarned (TKB-R65, AXP-R2), on ReportCoins'
--                             timing: `done` calls it after ns.ReportCoins, and the projection's apply after a live
--                             entry that changes the XP, so Core takes that entry as the one it came from (AXP-R7).
--                             Reports ns.State().xp, 0 before Start. Defined in adapter/Moments.lua.
--   ns.RefreshGoods()         Asks Core to read the earned goods again with M:RefreshGoods (TKB-R126, SHOP-R31): the
--                             projection's apply after a live entry that reaches an earned good's Campfire milestone,
--                             and its `done` after ns.ReportXP. Nothing without a Module handle. Defined in
--                             adapter/Goods.lua.
--   ns.RaiseMoment(moment, remake?), ns.RaiseWriteUp(section), ns.SetSummaryLine(line)
--                             What logic/Moments.lua tells Core (TKB-R84–R87), through the Module handle; nothing while
--                             the Module is inert (CORE-R13). A goal's moment still reading "…" for a Species name
--                             waits up to 1 s for it, made again by `remake` (TKB-R36). Defined in adapter/Moments.lua.
--   ns.Celebrated()           The celebrated set in PagleTackleBoardDB (TKB-R83), nil while the Module is inert.
--                             logic/Moments.lua marks it; adapter/Ledge.lua reads it. Defined in adapter/Moments.lua.
--   ns.ClearScratch(), ns.CountForWriteUp(state, record, mode)
--                             The scratch tally of a build (TKB-R84): the projection's reset clears it and its apply
--                             counts each entry. Defined in logic/Moments.lua.
--   ns.OnRedraw(fn)           Subscribes a view (the board, the tracker) to redraws: fn(reason, detail) is called at
--                             every ns.Redraw, in subscription order. Subscribe once, when the view is made.
--   ns.Redraw(reason, detail) Asks every subscribed view to redraw. Callers and their reasons: "projection" after each
--                             live apply that changes the state and after each done; "completed" with the goal ID as
--                             detail when a goal completes live (the tracker flashes it, TKB-R123); "names" when an item
--                             name arrives (GET_ITEM_INFO_RECEIVED, adapter/Client.lua); "step" after each live step;
--                             "tracker" when the tracker's setting changes (adapter/Settings.lua). A view that is
--                             hidden may ignore it.
--   ns.outlets                What the Tackle Board celebrates, called from the projection and the live step and filled
--                             in logic/Moments.lua, not here (a stand-in here too would be a duplicate field for LuaLS):
--     .Completed(goal, cast, earned, mode)  a goal completed in apply: the TackleGoal, the completing Cast, what it
--                             earned (TackleEarned) and the apply's mode ("live", "replay" or "rebuild", LOG-R72)
--     .Advanced(result, mode) the projection advanced across board days: the Campfire's outcome (TackleAdvance) and
--                             the mode, "live" for the live step's own advance
--     .Done(state, info)      the projection's done, first in it (TKB-R84): the state and Core's done info
--     .Stepped()              a live step finished: the summary line (TKB-R87)
--   ns.api                    The client's calls and Core, as logic/ reads them (TackleClientAPI, below): the WoW calls
--                             board days read (TKB-R10, TKB-R11, TKB-R13), the realm clock's secrecy (CORE-R31), the
--                             names (TKB-R36), the number format and `pagle`, Core (ADR 0001: its API only). A missing
--                             WoW call is nil. adapter/Client.lua sets it at file load; specs replace its calls
--                             (spec/Pagle_TackleBoard/support.lua). Days take it as `api`.
--   ns.random(m, n)           The random source generation draws from, like math.random (TKB-R30–R34).
--                             adapter/Client.lua sets math.random at file load; specs replace it. Generation takes it
--                             in its context.
--
-- The goal ID handed to OpenBoard, TakeDown and CanTakeDown is the entry ID of the record that issued the goal (TKB-R23).

--- The WoW calls board days read (TKB-R10, TKB-R11, TKB-R13; logic/Days.lua), each nil where the client lacks it.
---@class TackleResetAPI
---@field GetServerTime fun(): integer
---@field C_DateAndTime table               -- GetSecondsUntilDailyReset, GetSecondsUntilWeeklyReset, GetCurrentCalendarTime
---@field GetGameTime? fun(): integer?, integer?   -- the realm clock: hour, minute
---@field GetCurrentRegion? fun(): integer
---@field issecretvalue? fun(value: any): boolean   -- whether a value is secret (CORE-R31): the realm clock may be

--- ns.api: the client's calls and Core, as logic/ reads them (adapter/Client.lua).
---@class TackleClientAPI : TackleResetAPI
---@field AreaName fun(areaID: integer): string?         -- a zone's name, C_Map.GetAreaInfo; nil if the client has none
---@field MapName fun(uiMapID: integer): string?         -- a uiMap's name, C_Map.GetMapInfo(uiMapID).name; nil if none
---@field ItemName fun(itemID: integer): string?         -- C_Item.GetItemNameByID; nil until the client has it cached
---@field RequestItem fun(itemID: integer)               -- asks the client to load an item (ns.ItemArrived on arrival)
---@field FormatNumber fun(n: integer): string           -- BreakUpLargeNumbers: "2,340" (the Write-up's heading, TKB-R84)
---@field pagle table                                    -- Core: GetArea, GetZones, GetZoneCatches, GetItem, GetAngler, GetConditions

---@alias TackleGoalType "n"|"e"                  -- Notice, Expedition
---@alias TackleGoalKind "haul"|"variety"|"wanderer"|"rarity"|"collector"|"lure"|"species"
---@alias TackleDayLog "lit"|"burned"|"out"|"unlit"
---@alias TackleApplyMode "live"|"replay"|"rebuild"

--- A goal's definition: what generation (logic/Generate.lua) returns, the `issue` and `reroll` records carry
--- (tackle-board.md › Data) and the projection (logic/Projection.lua) decodes. A Variety Expedition has `target` = its zone and `items`
--- = its representative items, ascending; a Notice of a kind with an empty target (`wanderer`, `collector`, `lure`) has
--- no `target`.
---@class TackleGoalDef
---@field type TackleGoalType
---@field kind TackleGoalKind
---@field tier integer               -- 1–3 for a Notice, 0 for an Expedition (TKB-R34)
---@field pay integer                -- Coins (TKB-R34)
---@field need integer               -- TKB-R34
---@field target? integer            -- zone, continent, minimum Variety rarity rank, or representative item
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
---@field progressDay? integer       -- day-bound: the board day its progress belongs to (TKB-R41)
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
---@field xp integer                  -- lifetime Activity XP earned (TKB-R65)
---@field ticketsSpent integer        -- lifetime Refreshes spent: the `post` records applied (TKB-R58)
---@field flies { [string]: { day: integer, time: integer, goal: TackleGoal } }  -- tied patterns, with a copy of the goal that tied it
---@field titles { [string]: { day: integer, cast: string } }  -- titleID -> board day and Cast entry ID it was earned on
---@field fire { count: integer, kindling: integer, longest: integer, milestones: { [integer]: { day: integer, cast: string } }, log: { [integer]: TackleDayLog } }  -- log keeps the last 28 days
---@field zones { [integer]: integer }   -- zone areaID -> time of the Angler's last Cast there
---@field caught { [integer]: true }     -- every item ID ever caught (TKB-R46)

--- What one completion earned (TKB-R60), handed to ns.outlets.Completed (logic/Completions.lua).
---@class TackleEarned
---@field pay integer                 -- the goal's pay (TKB-R34)
---@field coins integer               -- the goal's pay plus any Campfire milestone's Coins
---@field xp integer                  -- the goal's Activity XP (TKB-R65); a milestone pays none
---@field fly? string                 -- pattern ID tied (TKB-R62); nil when its pool was empty
---@field titles string[]             -- title IDs earned, in TKB-R60's order: tally, Campfire, Fly Box
---@field milestone? { days: integer, coins: integer, title: string }  -- Campfire milestone reached (TKB-R73)
---@field lit boolean                 -- this completion lit its day (TKB-R70)

--- The projection's state (`ns.projection:GetState()`, bound by the adapter's OnInitialize): a new empty
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

--- The Refreshes the Angler holds now (REF-R5), from Core: `Pagle.GetTickets().tickets`, 0 or more.
---@return integer
function ns.RefreshesHeld()
	return ns.api.pagle.GetTickets().tickets
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

--- What the Tackle Board celebrates (TKB-R83–R87), defined in logic/Moments.lua.
---@class TackleOutlets
---@field Completed fun(goal: TackleGoal, cast: PagleCast, earned: TackleEarned, mode: TackleApplyMode)
---@field Advanced fun(result: TackleAdvance, mode: TackleApplyMode)
---@field Done fun(state: TackleBoardState, info: { firstBuild: boolean?, rebuilt: boolean?, replayed: integer? })
---@field Stepped fun()
ns.outlets = {}
