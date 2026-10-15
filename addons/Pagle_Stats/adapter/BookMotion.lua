if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The Stats book's motion and sounds (stats.md › UI; the books art kit v2's MOTION.md and SOUND.md), played by
-- adapter/Motion.lua's driver: the page turn between spreads (the kit's Views.lua, copied over the book's page views),
-- the ink of a rewritten figure fading up, and the book's UI foley. With Core's Animations setting off, everything
-- draws settled at once (ns.SyncMotion); the turn's sound and the catch's "write" go with the motion, the open and
-- close sounds don't. The sounds are the client's own sound kits, by number, on the SFX channel: the client's sound
-- volume and mute are the only switch (no Pagle setting), and they belong to no sound set.

--- Reads Core's Animations setting (`Pagle.IsAnimationsOn()`, announcements.md › Contracts) into ns.motion, which
--- adapter/Motion.lua's driver obeys; every move calls it first. Returns whether things move.
---@return boolean
function ns.SyncMotion()
	ns.motion = Pagle.IsAnimationsOn() ~= false
	return ns.motion
end

--- The book's sounds (the kit's SOUND.md, Books): sound kit ids, and whether each goes with the motion.
---@type table<string, { id: integer, motion: boolean }>
ns.BOOK_SOUNDS = {
	open = { id = 829, motion = false }, -- IG_SPELLBOOK_OPEN: the book opens
	close = { id = 830, motion = false }, -- IG_SPELLBOOK_CLOSE: it closes
	pageTurn = { id = 836, motion = true }, -- IG_ABILITY_PAGE_TURN: a ribbon or crumb turns the page
	write = { id = 3093, motion = true }, -- IG_WRITE_QUEST: a catch resets the Dry spell shown
}

--- Plays the book's sound `name` on the SFX channel; one that goes with the motion only while things move.
---@param name string
function ns.BookSound(name)
	local sound = assert(ns.BOOK_SOUNDS[name], "the Stats book has no sound " .. tostring(name))
	if sound.motion and not ns.SyncMotion() then
		return
	end
	PlaySound(sound.id, "SFX")
end

--- A rewritten figure's ink fades up from 30% (0.3 s, ease-out), as the kit's ink(): settled at once with the motion
--- off.
---@param region Region
function ns.InkIn(region)
	ns.SyncMotion()
	ns.Animate(region, {
		{
			dur = 0.3,
			ease = ns.Ease.out,
			keys = { { 0, { 0.3 } }, { 1, { 1 } } },
			apply = function(v)
				region:SetAlpha(v[1])
			end,
		},
	})
end

-- The page turn (the kit's Views.lua). Each spread's side draws inside a clip frame on its paper, whose visible strip
-- can be narrowed from either edge, so a turn is two complementary wipes, with no frame levels changed:
--   forward (to a later ribbon): the right page lifts away toward the spine, uncovering the new right page (0.22 s,
--   speeding up), then lands on the left from the spine outward, covering the old left page (0.28 s, settling).
--   Backward is the mirror image. A fold shade darkens the lifting page (up to 28%) and a 26-unit shadow falls on the
--   page beside the moving edge, with a 1.5-unit light line on the edge itself; both fade as the page lands.

--- A spread's side as the turn sees it: the clip frame on its paper, and the paper's width.
---@class StatsTurnSide
---@field clip Frame
---@field paper Frame

--- The turn's halves, in seconds.
ns.TURN_LIFT, ns.TURN_LAND = 0.22, 0.28
-- The fold's shade at its darkest, its cast shadow's width and darkness, and the edge's light.
local SHADE, CAST_WIDTH, CAST_DARK, EDGE_WIDTH, EDGE_LIGHT = 0.28, 26, 0.32, 1.5, 0.55

--- Shows only the strip [a, b] (shares of the paper's width) of `side`; none when it is (near) empty.
---@param side StatsTurnSide?
---@param a number
---@param b number
function ns.RevealSide(side, a, b)
	if not side then
		return
	end
	local clip, paper = side.clip, side.paper
	if b - a <= 0.002 then
		clip:Hide()
		return
	end
	local width = paper:GetWidth()
	clip:Show()
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", paper, "TOPLEFT", a * width, 0)
	clip:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", a * width, 0)
	clip:SetWidth((b - a) * width)
end

---@class StatsBookFold: Frame
---@field shade Texture
---@field cast Texture
---@field edge Texture

--- The fold over `book`'s pages: a shade over the turning strip and a cast shadow beside its edge, made once.
---@param book StatsBookFrame
---@return StatsBookFold
local function foldOf(book)
	local fold = book.turnFold --[[@as StatsBookFold?]]
	if fold then
		return fold
	end
	fold = CreateFrame("Frame", nil, book) --[[@as StatsBookFold]]
	fold:SetAllPoints()
	fold:SetFrameLevel(book:GetFrameLevel() + 40)
	fold.shade = fold:CreateTexture(nil, "OVERLAY", nil, 0)
	fold.shade:SetColorTexture(0.16, 0.08, 0.02, 1)
	fold.cast = fold:CreateTexture(nil, "OVERLAY", nil, 1)
	fold.cast:SetColorTexture(1, 1, 1, 1)
	fold.edge = fold:CreateTexture(nil, "OVERLAY", nil, 2)
	fold.edge:SetColorTexture(1, 0.97, 0.85, 1)
	fold:Hide()
	book.turnFold = fold
	return fold
end

-- Places the fold: the turning strip [x0, x1] on `paper` (units from its left), its moving edge at `ex`, the cast
-- shadow on the side `side` names (-1 left of the edge, 1 right of it).
---@param fold StatsBookFold
---@param paper Frame
---@param x0 number
---@param x1 number
---@param ex number
---@param side integer
---@param shade number
---@param cast number
local function placeFold(fold, paper, x0, x1, ex, side, shade, cast)
	fold.shade:ClearAllPoints()
	fold.shade:SetPoint("TOPLEFT", paper, "TOPLEFT", x0, 0)
	fold.shade:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", x0, 0)
	fold.shade:SetWidth(math.max(0.01, x1 - x0))
	fold.shade:SetAlpha(shade)
	local castX = side > 0 and ex or ex - CAST_WIDTH
	fold.cast:ClearAllPoints()
	fold.cast:SetPoint("TOPLEFT", paper, "TOPLEFT", castX, 0)
	fold.cast:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", castX, 0)
	fold.cast:SetWidth(CAST_WIDTH)
	local dark, clear = CreateColor(0.12, 0.06, 0.02, CAST_DARK * cast), CreateColor(0.12, 0.06, 0.02, 0)
	if side > 0 then
		fold.cast:SetGradient("HORIZONTAL", dark, clear)
	else
		fold.cast:SetGradient("HORIZONTAL", clear, dark)
	end
	local edgeX = ex - (side > 0 and EDGE_WIDTH or 0)
	fold.edge:ClearAllPoints()
	fold.edge:SetPoint("TOPLEFT", paper, "TOPLEFT", edgeX, 0)
	fold.edge:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", edgeX, 0)
	fold.edge:SetWidth(EDGE_WIDTH)
	fold.edge:SetAlpha(EDGE_LIGHT * cast)
end

--- A turn between two spreads: each one's sides, by "left" and "right" (a side with nothing drawn is nil).
---@class StatsTurn
---@field from table<StatsBookSide, StatsTurnSide?>
---@field to table<StatsBookSide, StatsTurnSide?>
---@field forward boolean
---@field papers table<StatsBookSide, Frame>
---@field midway fun()    -- at the spine: the crumbs change
---@field done fun()      -- when it has landed, or is cut short

--- Plays `turn` on `book` (the book's frame), the kit's two halves; settled at once with the motion off. Returns the
--- owner it plays on, which ns.StopMotion cuts short (the caller then settles it with turn.done).
---@param book StatsBookFrame
---@param turn StatsTurn
---@return table owner
function ns.PlayTurn(book, turn)
	local owner = {}
	local from, to, papers = turn.from, turn.to, turn.papers
	local leftWidth, rightWidth = papers.left:GetWidth(), papers.right:GetWidth()
	local fold = foldOf(book)
	local function settle()
		fold:Hide()
		turn.done()
	end
	if not ns.SyncMotion() then
		turn.midway()
		settle()
		return owner
	end
	ns.BookSound("pageTurn")
	fold:Show()
	local forward = turn.forward
	if forward then
		ns.RevealSide(to.left, 1, 1)
		ns.RevealSide(from.left, 0, 1)
	else
		ns.RevealSide(to.right, 0, 0)
		ns.RevealSide(from.right, 0, 1)
	end
	ns.Animate(owner, {
		-- first half: the page lifts toward the spine
		{
			dur = ns.TURN_LIFT,
			ease = ns.Bezier(0.5, 0, 0.9, 0.6),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if forward then
					ns.RevealSide(from.right, 0, 1 - k)
					ns.RevealSide(to.right, 1 - k, 1)
					placeFold(fold, papers.right, 0, (1 - k) * rightWidth, (1 - k) * rightWidth, 1, SHADE * k, 1)
				else
					ns.RevealSide(from.left, k, 1)
					ns.RevealSide(to.left, 0, k)
					placeFold(fold, papers.left, k * leftWidth, leftWidth, k * leftWidth, -1, SHADE * k, 1)
				end
			end,
			done = turn.midway,
		},
		-- second half: it lands on the other page, from the spine outward
		{
			dur = ns.TURN_LAND,
			delay = ns.TURN_LIFT,
			ease = ns.Bezier(0.1, 0.4, 0.4, 1),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if k <= 0 then
					return
				end
				if forward then
					ns.RevealSide(from.right, 0, 0)
					ns.RevealSide(to.right, 0, 1)
					ns.RevealSide(to.left, 1 - k, 1)
					ns.RevealSide(from.left, 0, 1 - k)
					local x = (1 - k) * leftWidth
					placeFold(fold, papers.left, x, leftWidth, x, -1, SHADE * (1 - k), 1 - k)
				else
					ns.RevealSide(from.left, 0, 0)
					ns.RevealSide(to.left, 0, 1)
					ns.RevealSide(to.right, 0, k)
					ns.RevealSide(from.right, k, 1)
					placeFold(fold, papers.right, 0, k * rightWidth, k * rightWidth, 1, SHADE * (1 - k), 1 - k)
				end
			end,
		},
	}, settle)
	return owner
end
