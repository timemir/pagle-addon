if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What the Tackle Board decides about its board (TKB-R5, TKB-R100, TKB-R107, TKB-R108): pure logic, everything passed
-- in (CORE-R7). Whether it shows the empty slip, the Start button and "Updating…", and which of its parts it draws;
-- adapter/Board.lua draws what it decides on the frame.
--
-- The parts, and the tickets that register their renderers (`ns.board:RegisterPart(part, renderer)`):
--   "pins"      the Expedition row (2 pins) and the two Notice rows (3 pins each), TKB-R101, TKB-R102, TKB-R105,
--               TKB-R109 (#239)
--   "overflow"  the strip under the Notice rows for goals with no empty pin, TKB-R101 (#239)
--   "spike"     the nail on the right with today's done goals, TKB-R103 (#240)
--   "ledge"     the Campfire, the Fly Box, the tally plate and the shop link, TKB-R106 (#240)
-- A part with no renderer is bare. Before Start no part is drawn: the cork and the ledge are bare (TKB-R107).

---@alias TackleBoardPart "pins"|"overflow"|"spike"|"ledge"

--- The board's parts, in drawing order.
---@type TackleBoardPart[]
ns.BOARD_PARTS = { "pins", "overflow", "spike", "ledge" }

--- What one draw hands each part's renderer.
---@class TackleBoardDraw
---@field updating boolean    -- the projection is updating (TKB-R108): every "take it down" is disabled
---@field highlight string?   -- the goal ID ns.OpenBoard was given, on the draw that opened it only (TKB-R109): the
---                           -- pins part keeps the highlight for its 2 s itself
---@field reason string       -- "open", "start", or the ns.Redraw reason ("projection", "completed", "names", "step")
---@field detail any          -- ns.Redraw's detail: the goal ID for "completed"

--- Draws one part on its frame (adapter/Board.lua makes one frame per part, in its place on the board).
---@alias TackleBoardRenderer fun(frame: Frame, draw: TackleBoardDraw)

--- What the board shows.
---@class TackleBoardShows
---@field empty boolean               -- the empty slip and its Start my board button (TKB-R107, TKB-R5)
---@field startEnabled boolean        -- the Start button takes clicks: before Start and not while updating (TKB-R5)
---@field updating boolean            -- "Updating…" over the cork (TKB-R108)
---@field parts TackleBoardPart[]     -- the parts drawn, in drawing order: all once started, none before (TKB-R107)

--- What the board shows, from whether it is started (TKB-R6) and whether the projection is updating (LOG-R74). A
--- started board has no Start button (TKB-R5).
---@param started boolean
---@param updating boolean
---@return TackleBoardShows
function ns.BoardShows(started, updating)
	local parts = {}
	if started then
		for i, part in ipairs(ns.BOARD_PARTS) do
			parts[i] = part
		end
	end
	return { empty = not started, startEnabled = not started and not updating, updating = updating, parts = parts }
end

--- The renderers registered for the board's parts.
---@class TackleBoardParts
---@field private renderers table<TackleBoardPart, TackleBoardRenderer>
local Parts = {}
Parts.__index = Parts

--- No renderers yet.
---@return TackleBoardParts
function ns.NewBoardParts()
	return setmetatable({ renderers = {} }, Parts)
end

--- Registers `renderer` to draw `part`; a later registration replaces it. Raises on a part the board doesn't have, so a
--- typo fails when the file loads.
---@param part TackleBoardPart
---@param renderer TackleBoardRenderer
function Parts:Register(part, renderer)
	local known = false
	for _, name in ipairs(ns.BOARD_PARTS) do
		known = known or name == part
	end
	assert(known, "the Tackle Board has no part " .. tostring(part))
	assert(type(renderer) == "function", "a Tackle Board part's renderer is a function")
	self.renderers[part] = renderer
end

--- The renderer registered for `part`, or nil: the part is bare.
---@param part TackleBoardPart
---@return TackleBoardRenderer?
function Parts:Renderer(part)
	return self.renderers[part]
end
