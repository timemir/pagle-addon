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
--   ns.OpenBoard(huntID?)     Opens the board (never closes it), on that Hunt if given (HNT-R67, HNT-R77): the
--                             tracker's lines call it. Defined by the board, adapter/Board.lua.
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

-- The projection's state, as hunts.md › Projection state gives it; logic/Projection.lua fills it in.

---@class HuntsState
---@field casts integer       -- Casts applied, for the Write-up heading
---@field coins integer       -- lifetime Pagle Coins earned (HNT-R110)
---@field hunts table<string, HuntProgress>   -- by Hunt ID; absent until the Hunt has effort or a Catch
---@field sets table<string, HuntsSetTitle>   -- by set ID, only once earned (HNT-R23, HNT-R87; logic/Titles.lua)

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
