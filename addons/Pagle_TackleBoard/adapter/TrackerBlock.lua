if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The tracker block maker (TKB-R122, TKB-R124, CORE-R73; tackle-board.md › UI, the tracker): a native
-- objective-tracker-style block, 250 px wide, drawn from a list of line descriptions in a frame look. The Curio Shop's
-- previews draw a sample with it (TKB-R125, adapter/Goods.lua); the live tracker (#241) fills it with live lines,
-- gives its rows clicks and docks it. Look reference: prototypes/tackle-board/'s tracker mode K2 (`.tb`), whose CSS
-- gives the colours below.

-- A tint from its hex code, as the prototype's CSS writes it: { r, g, b }, 0 to 1.
---@param hex string "RRGGBB"
---@return number[]
local function tint(hex)
	return {
		tonumber(hex:sub(1, 2), 16) / 255,
		tonumber(hex:sub(3, 4), 16) / 255,
		tonumber(hex:sub(5, 6), 16) / 255,
	}
end

--- The tracker's width in pixels, as the Stats tracker's, so the dock's blocks line up (CORE-R70).
ns.TRACKER_WIDTH = 250

--- The words' colours by role, a frame's `ink`: the header's title, dim text (the header's right text), a Notice's
--- text, an Expedition's text, a goal's count, its where line, a plain line ("+N more", "All done"), and a goal
--- completed live, flashing "Complete" (TKB-R123; nil in a look's inks keeps the native green).
---@class TackleTrackerInks
---@field header number[]
---@field dim number[]
---@field goal number[]
---@field expedition number[]
---@field count number[]
---@field where number[]
---@field more number[]
---@field complete number[]?

--- The native block's colours (tracker K2's `.tb`): the gold header, grey small print, pale gold goals, amber
--- Expeditions, white counts, and `.ln.fin`'s green for a goal flashing "Complete".
---@type TackleTrackerInks
ns.TRACKER_INKS = {
	header = tint("ffd100"),
	dim = tint("cfc8b8"),
	goal = tint("ffd27a"),
	expedition = tint("ffb060"),
	count = tint("ffffff"),
	where = tint("cfc8b8"),
	more = tint("9a9284"),
	complete = tint("7dff7d"),
}

--- A tracker frame's look (TKB-R124, TKB-R125): a solid base laid behind the block, a grain texture over it in a
--- tint, a border round it with a black hairline outside, and inks for words on a pale backing (nil keeps the native
--- colours, ns.TRACKER_INKS).
---@class TackleTrackerFrameLook
---@field base number[]       -- the backing's solid colour
---@field texture string      -- the grain laid over it, tiled
---@field tint number[]       -- the grain's vertex tint
---@field alpha number        -- the grain's opacity
---@field border number[]     -- the border's colour
---@field borderSize number   -- its width, in pixels
---@field ink TackleTrackerInks?

--- One line of the tracker, top to bottom (TKB-R122):
--- - `header`: `text` ("Tackle Board") after the collapse mark (plus while `collapsed`), and `right` on the right
---   ("12 · 4 open"), with a small flame before it while `fire`, over a faint rule;
--- - `goal`: `text` with its `count` right-aligned ("12/30"), then its `where` line; `expedition` inks it as one;
---   `complete` (a goal completed live, TKB-R123) draws it as one green line, "Complete" in the count's place, with
---   no where line;
--- - `line`: a plain line in small grey print.
---@class TackleTrackerLine
---@field kind "header"|"goal"|"line"
---@field text string
---@field right string?
---@field fire boolean?
---@field collapsed boolean?
---@field count string?
---@field where string?
---@field expedition boolean?
---@field complete boolean?
---@field goalID string?   -- a goal's ID, for the live tracker's click (TKB-R123)
---@field board boolean?   -- a plain line whose click opens the board ("+N more", TKB-R123)

-- Heights in pixels: the header, a goal's top padding, its text line and its where line, and a plain line.
local HEADER_HEIGHT, GOAL_PAD, TEXT_HEIGHT, WHERE_HEIGHT, LINE_HEIGHT = 18, 3, 14, 13, 15
-- The collapse mark's and the flame's sizes, the title's indent after the mark, the where line's indent and the room
-- kept on the right for a goal's count.
local MARK_SIZE, FLAME_SIZE, TITLE_INDENT, WHERE_INDENT, COUNT_ROOM = 12, 14, 16, 12, 44
-- How far a frame reaches out round the block, and the grain texture's tile in pixels.
local FRAME_PAD, GRAIN_TILE = 7, 128
-- The header's collapse mark: minus while expanded, plus while collapsed, as the client's own collapsible lists.
local EXPANDED_MARK = "Interface\\Buttons\\UI-MinusButton-Up"
local COLLAPSED_MARK = "Interface\\Buttons\\UI-PlusButton-Up"
-- How far the fire icon's square is cropped to its flame, each side (an icon's edge is a frame), as on the ledge.
local ICON_CROP = 0.08

--- One row of the block: every widget a line kind may use, shown as its line needs. A button, so the live tracker can
--- give it clicks (TKB-R122, TKB-R123).
---@class TackleTrackerRow: Button
---@field line TackleTrackerLine
---@field mark Texture     -- the header's collapse mark
---@field flame Texture    -- the header's small flame
---@field text FontString  -- the header's title, a goal's text, a plain line
---@field right FontString -- the header's right text, a goal's count
---@field sub FontString   -- a goal's where line
---@field rule Texture     -- the rule under the header

--- A tracker frame on a block (TKB-R124): the base, the grain, the border's lines and the hairline outside them, all
--- hidden until a look dresses it.
---@class TackleTrackerFrameView
---@field backing Texture
---@field grain Texture
---@field border Texture[]
---@field outline Texture[]

--- A tracker block (TKB-R122): `SetLines` draws its lines and returns its height; `SetFrame` dresses it in a frame
--- look (nil: the plain native block). Either may come first.
---@class TackleTrackerBlock: Frame
---@field rows TackleTrackerRow[]
---@field frame TackleTrackerFrameView
---@field look TackleTrackerFrameLook?
---@field SetLines fun(self: TackleTrackerBlock, lines: TackleTrackerLine[]): number
---@field SetFrame fun(self: TackleTrackerBlock, look: TackleTrackerFrameLook?)

-- Four lines round `frame`'s edge, from `out` pixels outside it, `size` thick inward, in `layer`: top, bottom, left,
-- right.
---@param frame Frame
---@param out number
---@param size number
---@param layer DrawLayer
---@return Texture[]
local function edgeLines(frame, out, size, layer)
	local lines = {}
	for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local line = frame:CreateTexture(nil, layer)
		if side == "TOP" or side == "BOTTOM" then
			local y = side == "TOP" and out or -out
			line:SetPoint(side .. "LEFT", -out, y)
			line:SetPoint(side .. "RIGHT", out, y)
			line:SetHeight(size)
		else
			local x = side == "LEFT" and -out or out
			line:SetPoint("TOP" .. side, x, out)
			line:SetPoint("BOTTOM" .. side, x, -out)
			line:SetWidth(size)
		end
		line:Hide()
		lines[i] = line
	end
	return lines
end

-- Sets edge lines' colour and thickness and shows them.
---@param lines Texture[]
---@param color number[]
---@param size number
local function paintLines(lines, color, size)
	for i, line in ipairs(lines) do
		line:SetColorTexture(color[1], color[2], color[3], 1)
		if i <= 2 then
			line:SetHeight(size)
		else
			line:SetWidth(size)
		end
		line:Show()
	end
end

---@param regions Region[]
local function hideAll(regions)
	for _, region in ipairs(regions) do
		region:Hide()
	end
end

-- Builds a block's frame view, hidden.
---@param block Frame
---@return TackleTrackerFrameView
local function newFrameView(block)
	local backing = block:CreateTexture(nil, "BACKGROUND")
	backing:SetPoint("TOPLEFT", -FRAME_PAD, FRAME_PAD)
	backing:SetPoint("BOTTOMRIGHT", FRAME_PAD, -FRAME_PAD)
	backing:Hide()
	local grain = block:CreateTexture(nil, "BACKGROUND", nil, 1)
	grain:SetAllPoints(backing)
	grain:Hide()
	return {
		backing = backing,
		grain = grain,
		border = edgeLines(block, FRAME_PAD, 1, "BORDER"),
		outline = edgeLines(block, FRAME_PAD + 1, 1, "BORDER"),
	}
end

-- Sets the grain's tiling to the block's size, so its repeats keep their size as the block grows.
---@param view TackleTrackerFrameView
---@param height number the block's height
local function tile(view, height)
	local width = ns.TRACKER_WIDTH + 2 * FRAME_PAD
	view.grain:SetTexCoord(0, width / GRAIN_TILE, 0, (height + 2 * FRAME_PAD) / GRAIN_TILE)
end

-- Dresses a frame view in `look`, or hides it all for nil.
---@param view TackleTrackerFrameView
---@param look TackleTrackerFrameLook?
local function dress(view, look)
	if not look then
		view.backing:Hide()
		view.grain:Hide()
		hideAll(view.border)
		hideAll(view.outline)
		return
	end
	view.backing:SetColorTexture(look.base[1], look.base[2], look.base[3], 1)
	view.backing:Show()
	view.grain:SetTexture(look.texture, "REPEAT", "REPEAT")
	view.grain:SetVertexColor(look.tint[1], look.tint[2], look.tint[3])
	view.grain:SetAlpha(look.alpha)
	view.grain:Show()
	paintLines(view.border, look.border, look.borderSize)
	paintLines(view.outline, { 0, 0, 0 }, 1)
end

---@param row Button
---@param font string
---@return FontString
local function fontString(row, font)
	local text = row:CreateFontString(nil, "OVERLAY", font)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	return text
end

-- Builds one row of `block`: the mark, the flame, the main text, the right-hand text, the where line and the header's
-- rule.
---@param block Frame
---@return TackleTrackerRow
local function newRow(block)
	local row = CreateFrame("Button", nil, block) --[[@as TackleTrackerRow]]
	row.mark = row:CreateTexture(nil, "ARTWORK")
	row.mark:SetSize(MARK_SIZE, MARK_SIZE)
	row.mark:SetPoint("TOPLEFT", 0, -2)
	row.text = fontString(row, "GameFontHighlightSmall")
	row.right = fontString(row, "GameFontHighlightSmall")
	row.right:SetJustifyH("RIGHT")
	row.sub = fontString(row, "GameFontHighlightSmall")
	row.sub:SetPoint("TOPLEFT", WHERE_INDENT, -(GOAL_PAD + TEXT_HEIGHT))
	row.sub:SetPoint("TOPRIGHT", 0, -(GOAL_PAD + TEXT_HEIGHT))
	row.flame = row:CreateTexture(nil, "ARTWORK")
	row.flame:SetTexture(ns.BOARD_TEXTURES.flame)
	row.flame:SetTexCoord(ICON_CROP, 1 - ICON_CROP, ICON_CROP, 1 - ICON_CROP)
	row.flame:SetSize(FLAME_SIZE, FLAME_SIZE)
	row.flame:SetPoint("RIGHT", row.right, "LEFT", -2, 0)
	row.rule = row:CreateTexture(nil, "ARTWORK")
	row.rule:SetPoint("BOTTOMLEFT", 0, 1)
	row.rule:SetPoint("BOTTOMRIGHT", 0, 1)
	row.rule:SetHeight(1)
	return row
end

-- Lays out `row` for `line` and returns its height.
---@param row TackleTrackerRow
---@param line TackleTrackerLine
---@return number
local function layOut(row, line)
	row.line = line
	local kind, text, right = line.kind, row.text, row.right
	text:ClearAllPoints()
	right:ClearAllPoints()
	row.mark:SetShown(kind == "header")
	row.rule:SetShown(kind == "header")
	row.flame:SetShown(kind == "header" and line.fire == true)
	row.sub:SetShown(kind == "goal" and not line.complete)
	text:SetText(line.text)
	if kind == "header" then
		row.mark:SetTexture(line.collapsed and COLLAPSED_MARK or EXPANDED_MARK)
		text:SetFontObject("GameFontNormal")
		text:SetPoint("TOPLEFT", TITLE_INDENT, 0)
		right:SetFontObject("GameFontHighlightSmall")
		right:SetPoint("TOPRIGHT", 0, -2)
		right:SetText(line.right)
		right:SetShown(line.right ~= nil)
		return HEADER_HEIGHT
	elseif kind == "goal" then
		text:SetFontObject("GameFontNormalSmall")
		text:SetPoint("TOPLEFT", 0, -GOAL_PAD)
		text:SetPoint("TOPRIGHT", -COUNT_ROOM, -GOAL_PAD)
		right:SetFontObject("GameFontHighlightSmall")
		right:SetPoint("TOPRIGHT", 0, -GOAL_PAD)
		right:SetText(line.count)
		right:Show()
		if line.complete then
			return GOAL_PAD + TEXT_HEIGHT
		end
		row.sub:SetFontObject("GameFontHighlightSmall")
		row.sub:SetText(line.where)
		return GOAL_PAD + TEXT_HEIGHT + WHERE_HEIGHT
	end
	text:SetFontObject("GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", 0, -3)
	text:SetPoint("TOPRIGHT", 0, -3)
	right:Hide()
	return LINE_HEIGHT
end

-- Sets `row`'s words in `inks` by their roles.
---@param row TackleTrackerRow
---@param inks TackleTrackerInks
local function ink(row, inks)
	local line = row.line
	local function paint(words, color)
		words:SetTextColor(color[1], color[2], color[3])
	end
	if line.kind == "header" then
		paint(row.text, inks.header)
		paint(row.right, inks.dim)
		row.mark:SetVertexColor(inks.dim[1], inks.dim[2], inks.dim[3])
		row.rule:SetColorTexture(inks.header[1], inks.header[2], inks.header[3], 0.35)
	elseif line.kind == "goal" and line.complete then
		local green = inks.complete or ns.TRACKER_INKS.complete --[[@as number[] ]]
		paint(row.text, green)
		paint(row.right, green)
	elseif line.kind == "goal" then
		paint(row.text, line.expedition and inks.expedition or inks.goal)
		paint(row.right, inks.count)
		paint(row.sub, inks.where)
	else
		paint(row.text, inks.more)
	end
end

--- A new, empty tracker block on `parent`, ns.TRACKER_WIDTH wide, with no frame.
---@param parent Frame
---@return TackleTrackerBlock
function ns.NewTrackerBlock(parent)
	local block = CreateFrame("Frame", nil, parent) --[[@as TackleTrackerBlock]]
	block:SetSize(ns.TRACKER_WIDTH, 1)
	block.rows = {}
	block.frame = newFrameView(block)

	local function inkAll()
		local inks = block.look and block.look.ink or ns.TRACKER_INKS
		for _, row in ipairs(block.rows) do
			if row:IsShown() then
				ink(row, inks)
			end
		end
	end

	function block.SetLines(_, lines)
		local top = 0
		for i, line in ipairs(lines) do
			local row = block.rows[i]
			if not row then
				row = newRow(block)
				block.rows[i] = row
			end
			local height = layOut(row, line)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -top)
			row:SetPoint("TOPRIGHT", 0, -top)
			row:SetHeight(height)
			row:Show()
			top = top + height
		end
		for i = #lines + 1, #block.rows do
			block.rows[i]:Hide()
		end
		block:SetHeight(math.max(top, 1))
		tile(block.frame, top)
		inkAll()
		return top
	end

	function block.SetFrame(_, look)
		block.look = look
		dress(block.frame, look)
		inkAll()
	end

	return block
end
