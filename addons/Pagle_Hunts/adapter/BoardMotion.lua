if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The board's motion and sounds (hunts.md › UI, the books art kit v2's MOTION.md and SOUND.md), played by
-- adapter/Motion.lua's driver: the book fading in and out, the page turn between spreads (the kit's Views.lua: each
-- spread's page in a clip frame, two complementary wipes with a fold shade, a cast shadow and a light edge), and the
-- seam the rest of the board reads: whether things move, the kit's sounds, and fitting the board to the screen
-- (adapter/Fit.lua). With Core's Animations setting off, everything draws settled.

--- Whether things move: Core's Animations setting, `Pagle.IsAnimationsOn()` (announcements.md › Contracts; on by
--- default).
---@return boolean
function ns.AnimationsOn()
	return Pagle.IsAnimationsOn() ~= false
end

--- Sets the kit's driver to Core's Animations setting (adapter/Motion.lua reads ns.motion) and returns it: the board
--- calls it before it starts anything that moves.
---@return boolean
function ns.SyncMotion()
	ns.motion = ns.AnimationsOn()
	return ns.motion
end

-- The books kit's sounds (SOUND.md), by the client's sound kit ids, on the SFX channel: UI foley, never part of a
-- sound set, with no setting of Pagle's own (the client's SFX volume is their switch).
---@type table<string, integer>
ns.BOARD_SOUNDS = {
	bookOpen = 829, -- IG_SPELLBOOK_OPEN
	bookClose = 830, -- IG_SPELLBOOK_CLOSE
	pageTurn = 836, -- IG_ABILITY_PAGE_TURN: a ribbon or crumb turns the page; a notebook cover changes
	check = 856, -- IG_MAINMENU_OPTION_CHECKBOX_ON: "show completed"
	uncheck = 857, -- IG_MAINMENU_OPTION_CHECKBOX_OFF
	huntOpens = 3175, -- MAP_PING: a Hunt's window opens while the board is open
	write = 3093, -- IG_WRITE_QUEST: a catch is written into the Hunt's count
}
-- The beats tied to a motion, which play only while things move: the page turn and the ink running on.
local MOTION_TIED = { pageTurn = true, write = true }

--- Plays the board's sound `name` (ns.BOARD_SOUNDS) on the SFX channel; a beat tied to a motion only while things move.
---@param name string
function ns.BoardSound(name)
	local id = assert(ns.BOARD_SOUNDS[name], "the board has no sound " .. tostring(name))
	if MOTION_TIED[name] and not ns.AnimationsOn() then
		return
	end
	PlaySound(id, "SFX")
end

--- Fits `frame` to the screen (adapter/Fit.lua's P.FitToScreen): `width` × `height` is its whole extent with what
--- hangs outside it, `lift` how far its centre sits above that extent's centre. Never larger than 1; centred, `lift`
--- up. Before the client has a screen size (UIParent measures nothing), it is centred at its own size.
---@param frame Frame
---@param width number
---@param height number
---@param lift number
function ns.FitBoard(frame, width, height, lift)
	if (UIParent:GetHeight() or 0) > 0 and (UIParent:GetWidth() or 0) > 0 then
		ns.FitToScreen(frame, width, height, lift)
		return
	end
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", 0, lift)
end

--- Fades `frame` in (0.16 s, ease-out), as the kit's book opens.
---@param frame Frame
function ns.FadeIn(frame)
	ns.SyncMotion()
	ns.StopMotion(frame)
	ns.Animate(frame, {
		{
			dur = 0.16,
			ease = ns.Ease.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	})
end

--- How long the closing fade takes (MOTION.md › Opening and closing).
ns.CLOSE_FADE = 0.12

--- Fades `frame` out (ns.CLOSE_FADE, ease-in), then runs `done`; at once with the motion off.
---@param frame Frame
---@param owner table the fade's owner: not the frame, whose own fade-in it would cut
---@param done fun()
function ns.FadeOut(frame, owner, done)
	ns.SyncMotion()
	ns.Animate(owner, {
		{
			dur = ns.CLOSE_FADE,
			ease = ns.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	}, done)
end

-- The page turn (the kit's Views.lua). Each spread's page is a frame inside a clip frame on the parchment, whose
-- visible strip narrows from either edge; a turn is two complementary wipes, so no frame levels change.

--- A spread's page: its own frame, fixed to the page's body, inside a clip frame over the whole paper.
---@class BoardTurnPage: Frame
---@field clip Frame
---@field paper Frame

--- A spread's page on `paper`, its frame filling `body` (the paper's padded body) inside a clip frame over the paper.
---@param paper Frame
---@param body Frame
---@return BoardTurnPage
function ns.NewTurnPage(paper, body)
	local clip = CreateFrame("Frame", nil, paper)
	clip:SetClipsChildren(true)
	clip:SetAllPoints()
	local page = CreateFrame("Frame", nil, clip) --[[@as BoardTurnPage]]
	page:SetAllPoints(body)
	page:SetSize(body:GetWidth(), body:GetHeight())
	page.clip, page.paper = clip, paper
	return page
end

--- Shows only the strip `from`..`to` (fractions of the paper's `width`) of a spread's page; none hides it.
---@param page BoardTurnPage
---@param width number
---@param from number
---@param to number
function ns.RevealPage(page, width, from, to)
	local clip = page.clip
	if to - from <= 0.002 then
		clip:Hide()
		return
	end
	clip:Show()
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", page.paper, "TOPLEFT", from * width, 0)
	clip:SetPoint("BOTTOMLEFT", page.paper, "BOTTOMLEFT", from * width, 0)
	clip:SetWidth((to - from) * width)
end

--- The fold over the pages while a turn runs: a shade over the turning strip, a cast shadow beside its moving edge and a
--- light line on the edge.
---@class BoardFold: Frame
---@field shade Texture
---@field cast Texture
---@field edge Texture

--- The fold on `pages` (a frame over both papers), above every spread's page.
---@param pages Frame
---@return BoardFold
function ns.NewBoardFold(pages)
	local fold = CreateFrame("Frame", nil, pages) --[[@as BoardFold]]
	fold:SetAllPoints()
	fold:SetFrameLevel(pages:GetFrameLevel() + 40)
	fold.shade = fold:CreateTexture(nil, "OVERLAY", nil, 0)
	fold.shade:SetColorTexture(0.16, 0.08, 0.02, 1)
	fold.cast = fold:CreateTexture(nil, "OVERLAY", nil, 1)
	fold.cast:SetColorTexture(1, 1, 1, 1)
	fold.edge = fold:CreateTexture(nil, "OVERLAY", nil, 2)
	fold.edge:SetColorTexture(1, 0.97, 0.85, 1)
	fold:Hide()
	return fold
end

-- The cast shadow's width.
local CAST_WIDTH = 26

--- Places the fold: the turning strip `x0`..`x1` on `paper` (units from its left), its moving edge at `edgeX`, the cast
--- shadow on the side `side` (-1 left of the edge, 1 right of it), the shade's alpha `shade` and the shadow's `cast`.
---@param fold BoardFold
---@param paper Frame
---@param x0 number
---@param x1 number
---@param edgeX number
---@param side integer
---@param shade number
---@param cast number
function ns.PlaceFold(fold, paper, x0, x1, edgeX, side, shade, cast)
	fold.shade:ClearAllPoints()
	fold.shade:SetPoint("TOPLEFT", paper, "TOPLEFT", x0, 0)
	fold.shade:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", x0, 0)
	fold.shade:SetWidth(math.max(0.01, x1 - x0))
	fold.shade:SetAlpha(shade)
	local castX = side > 0 and edgeX or edgeX - CAST_WIDTH
	fold.cast:ClearAllPoints()
	fold.cast:SetPoint("TOPLEFT", paper, "TOPLEFT", castX, 0)
	fold.cast:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", castX, 0)
	fold.cast:SetWidth(CAST_WIDTH)
	local dark, clear = CreateColor(0.12, 0.06, 0.02, 0.32 * cast), CreateColor(0.12, 0.06, 0.02, 0)
	if side > 0 then
		fold.cast:SetGradient("HORIZONTAL", dark, clear)
	else
		fold.cast:SetGradient("HORIZONTAL", clear, dark)
	end
	local lineX = edgeX - (side > 0 and 1.5 or 0)
	fold.edge:ClearAllPoints()
	fold.edge:SetPoint("TOPLEFT", paper, "TOPLEFT", lineX, 0)
	fold.edge:SetPoint("BOTTOMLEFT", paper, "BOTTOMLEFT", lineX, 0)
	fold.edge:SetWidth(1.5)
	fold.edge:SetAlpha(0.55 * cast)
end

--- The page turn's halves (MOTION.md): the page lifts toward the spine, then lands on the other page.
ns.TURN_LIFT, ns.TURN_LAND = 0.22, 0.28

--- One spread's two pages, and each paper's width, as a turn moves them.
---@class BoardSpread
---@field left BoardTurnPage
---@field right BoardTurnPage

--- Turns from spread `from` to spread `to` (forward to a later ribbon, or back), the papers `leftWidth` and `rightWidth`
--- wide, the fold `fold` over them: forward, the right page lifts away toward the spine uncovering the new right page,
--- then lands on the left from the spine outward; backward is its mirror. `owner` runs it; `halfway` runs as the leaf
--- passes the spine (the crumbs change then); `done` when it has landed.
---@param owner table
---@param fold BoardFold
---@param from BoardSpread
---@param to BoardSpread
---@param forward boolean
---@param leftWidth number
---@param rightWidth number
---@param halfway fun()
---@param done fun()
function ns.TurnPages(owner, fold, from, to, forward, leftWidth, rightWidth, halfway, done)
	local reveal = ns.RevealPage
	local leftPaper, rightPaper = from.left.paper, from.right.paper
	fold:Show()
	if forward then
		reveal(to.left, leftWidth, 1, 1)
		reveal(from.left, leftWidth, 0, 1)
	else
		reveal(to.right, rightWidth, 0, 0)
		reveal(from.right, rightWidth, 0, 1)
	end
	local landed = false
	ns.Animate(owner, {
		-- the page lifts toward the spine, speeding up
		{
			dur = ns.TURN_LIFT,
			ease = ns.Bezier(0.5, 0, 0.9, 0.6),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if landed then
					return
				end
				if forward then
					reveal(from.right, rightWidth, 0, 1 - k)
					reveal(to.right, rightWidth, 1 - k, 1)
					ns.PlaceFold(fold, rightPaper, 0, (1 - k) * rightWidth, (1 - k) * rightWidth, 1, 0.28 * k, 1)
				else
					reveal(from.left, leftWidth, k, 1)
					reveal(to.left, leftWidth, 0, k)
					ns.PlaceFold(fold, leftPaper, k * leftWidth, leftWidth, k * leftWidth, -1, 0.28 * k, 1)
				end
			end,
			done = halfway,
		},
		-- it lands on the other page, from the spine outward, settling
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
				landed = true
				if forward then
					from.right.clip:Hide()
					reveal(to.right, rightWidth, 0, 1)
					reveal(to.left, leftWidth, 1 - k, 1)
					reveal(from.left, leftWidth, 0, 1 - k)
					ns.PlaceFold(
						fold,
						leftPaper,
						(1 - k) * leftWidth,
						leftWidth,
						(1 - k) * leftWidth,
						-1,
						0.28 * (1 - k),
						1 - k
					)
				else
					from.left.clip:Hide()
					reveal(to.left, leftWidth, 0, 1)
					reveal(to.right, rightWidth, 0, k)
					reveal(from.right, rightWidth, k, 1)
					ns.PlaceFold(fold, rightPaper, 0, k * rightWidth, k * rightWidth, 1, 0.28 * (1 - k), 1 - k)
				end
			end,
		},
	}, done)
end
