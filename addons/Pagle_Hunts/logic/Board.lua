if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunts board's page router (HNT-R60–R67): pure logic, everything passed in (CORE-R7). The board shows one mode at
-- a time, and the router decides which: the place (mode, set, Hunt), which renderer draws each page in it, and the
-- breadcrumb trail back up. adapter/Board.lua draws what it decides on the notebook.
--
-- The modes, and the renderers registered for them (`ns.board:RegisterPage(mode, side, renderer)`):
--   "board"    the Board ribbon (HNT-R62, HNT-R67): the timeline on the left (adapter/Timeline.lua), the selected
--              Hunt's entry on the right (adapter/Entry.lua), or HNT-R67's lines when there is none
--              (adapter/Timeline.lua). `hunt` is the Hunt asked for or selected; nil lets the timeline pick one
--              (HNT-R67).
--   "set"      a set's page (HNT-R66): the set's timeline on the left (adapter/Timeline.lua), the set's page on the
--              right (adapter/Sets.lua).
--   "entry"    a Hunt's entry opened from a set's page (HNT-R66's last bullet): the set's timeline on the left
--              (adapter/Timeline.lua), the entry with "back to {set}" on the right (adapter/Entry.lua).
--   "retired"  a done Retired Hunt's entry, opened from its set's page (HNT-R3): as "entry", the retired entry
--              (adapter/Entry.lua).

---@alias BoardMode "board"|"set"|"entry"|"retired"
---@alias BoardSide "left"|"right"

--- Where the board is: its mode, and the set and Hunt it shows.
---@class BoardPlace
---@field mode BoardMode
---@field set string?   -- a set's ID: the set's page, or the set an entry was opened from
---@field hunt string?  -- a Hunt's ID: the Board's selection, or the entry shown

--- One breadcrumb (HNT-R61): what it names, and the place it goes back to. adapter/Sets.lua gives it
--- its words ("Hunts", the set's name, the Hunt's name).
---@class BoardCrumb
---@field kind "hunts"|"set"|"hunt"
---@field id string?     -- the set's or the Hunt's ID; nil for "hunts"
---@field place BoardPlace

--- Draws one page of one mode: `page` is that page's own frame, `place` where the board is.
---@alias BoardRenderer fun(page: Frame, place: BoardPlace)

--- What each mode needs in its place, beyond its mode.
---@type table<BoardMode, { set: boolean, hunt: boolean }>
local NEEDS = {
	board = { set = false, hunt = false },
	set = { set = true, hunt = false },
	entry = { set = false, hunt = true },
	retired = { set = false, hunt = true },
}

--- The board's modes and page sides, in drawing order.
ns.BOARD_MODES = { "board", "set", "entry", "retired" }
ns.BOARD_SIDES = { "left", "right" }

---@class BoardRouter
---@field private place BoardPlace
---@field private renderers table<string, BoardRenderer> -- by "mode:side"
local Router = {}
Router.__index = Router

--- A router on the Board mode with nothing asked for (HNT-R67), and no renderers yet.
---@return BoardRouter
function ns.NewBoardRouter()
	return setmetatable({ place = { mode = "board" }, renderers = {} }, Router)
end

-- A copy of `place` with only the fields a place has.
---@param place BoardPlace
---@return BoardPlace
local function copy(place)
	return { mode = place.mode, set = place.set, hunt = place.hunt }
end

--- Registers `renderer` to draw page `side` of mode `mode`; a later registration replaces it. Raises on a mode or side
--- the board doesn't have, so a typo fails when the file loads.
---@param mode BoardMode
---@param side BoardSide
---@param renderer BoardRenderer
function Router:Register(mode, side, renderer)
	assert(NEEDS[mode], "the Hunts board has no mode " .. tostring(mode))
	assert(side == "left" or side == "right", "a Hunts board page is left or right, not " .. tostring(side))
	assert(type(renderer) == "function", "a Hunts board page's renderer is a function")
	self.renderers[mode .. ":" .. side] = renderer
end

--- The renderer of page `side` in mode `mode`, or nil when none is registered: that page is left blank.
---@param mode BoardMode
---@param side BoardSide
---@return BoardRenderer?
function Router:Renderer(mode, side)
	return self.renderers[mode .. ":" .. side]
end

--- Shows `place`. Raises when its mode is unknown or it lacks what the mode shows (a set's page needs its set, an
--- entry its Hunt), and the board stays where it was.
---@param place BoardPlace
function Router:Open(place)
	local needs = NEEDS[place.mode]
	assert(needs, "the Hunts board has no mode " .. tostring(place.mode))
	assert(not needs.set or place.set, "a set's page needs its set")
	assert(not needs.hunt or place.hunt, "an entry needs its Hunt")
	self.place = copy(place)
end

--- Selects `huntID` (or nothing) in the mode shown, as the timeline does when it picks the Hunt to show (HNT-R67).
--- Draws nothing: a renderer may call it while drawing.
---@param huntID string?
function Router:Select(huntID)
	self.place.hunt = huntID
end

--- Where the board is, as a copy.
---@return BoardPlace
function Router:Place()
	return copy(self.place)
end

--- The breadcrumb trail (HNT-R61): "Hunts", then the set, then the Hunt, as far as the place goes, each going back to
--- its own level. On the Board the Hunt follows "Hunts" directly.
---@return BoardCrumb[]
function Router:Trail()
	local place = self.place
	local trail = { { kind = "hunts", place = { mode = "board" } } }
	if place.mode ~= "board" and place.set then
		trail[#trail + 1] = { kind = "set", id = place.set, place = { mode = "set", set = place.set } }
	end
	if place.hunt then
		trail[#trail + 1] = { kind = "hunt", id = place.hunt, place = copy(place) }
	end
	return trail
end
