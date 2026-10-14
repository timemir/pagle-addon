if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The seams later Hunts tickets meet at, so none waits on another's wiring (M5 graph, open question 5). Each is a
-- field of ns with a stand-in here; the ticket that owns it replaces the field, and every caller calls it through
-- ns at call time (`ns.State()`, never a copy made at load), so the replacement reaches them all.
--
--   ns.ToggleBoard()          Opens the Hunts board, or closes it if shown (HNT-R68). Registration's view and
--                             `/pagle hunts` call it (HNT-R135). Stand-in: does nothing. The board's ticket (#191)
--                             assigns the real one when its file loads.
--   ns.OpenBoard(huntID?)     Opens the board (never closes it), on that Hunt if given (HNT-R67, HNT-R77): the
--                             tracker's lines call it. Stand-in: does nothing. The board's ticket (#191) assigns it.
--   ns.State()                The projection's HuntsState (hunts.md › Projection state). Read-only for views.
--                             Stand-in: a new empty state each call. The projection's ticket (#188) binds it to
--                             `projection:GetState()` in OnInitialize.
--   ns.IsUpdating()           Whether the projection is catching up or rebuilding (LOG-R74, HNT-R69): views then
--                             draw nothing from ns.State(). Stand-in: false. The projection's ticket (#188) binds it.
--   ns.OnRedraw(fn)           Subscribes a view (the board, the tracker, the summary line) to redraws: fn(reason) is
--                             called at every ns.Redraw, in subscription order. Subscribe once, when the view is made.
--   ns.Redraw(reason)         Asks every subscribed view to redraw (HNT-R42's last paragraph). Callers and their
--                             reasons: "groups" after each regroup, pause, pin and filter change (#189; see
--                             adapter/Groups.lua), "projection" after each live apply that
--                             changes the state and after each done (#188), "names" when item names load (#190).
--                             A view that is hidden may ignore it.

--- Opens or closes the Hunts board (HNT-R68). A stand-in until the board's ticket assigns the real one.
function ns.ToggleBoard() end

--- Opens the Hunts board on `huntID`, or on the Board mode with none (HNT-R67, HNT-R77). A stand-in until the
--- board's ticket assigns the real one.
---@param huntID string?
function ns.OpenBoard(huntID) end -- luacheck: no unused args

-- The projection's state, as hunts.md › Projection state gives it; the projection's ticket fills it in.

---@class HuntsState
---@field casts integer       -- Casts applied, for the Write-up heading
---@field coins integer       -- lifetime Pagle Coins earned (HNT-R110)
---@field hunts table<string, HuntProgress>   -- by Hunt ID; absent until the Hunt has effort or a Catch
---@field sets table<string, { earnedAt: integer, date: { year: integer, month: integer, day: integer }, fromRetirement: boolean }>   -- by set ID, only once earned (HNT-R23, HNT-R87)

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
---@field date { year: integer, month: integer, day: integer }   -- the Cast's realm date (cast.conditions.date)

--- The projection's state: a new empty HuntsState until the projection binds it.
---@return HuntsState
function ns.State()
	return { casts = 0, coins = 0, hunts = {}, sets = {} }
end

--- Whether the projection is catching up or rebuilding (LOG-R74): false until the projection binds it.
---@return boolean
function ns.IsUpdating()
	return false
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
