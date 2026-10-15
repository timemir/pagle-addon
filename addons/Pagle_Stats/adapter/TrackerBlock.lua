if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The tracker block maker (STA-R82, STA-R84; stats.md › UI › Live tracker): a native objective-tracker-style block,
-- about 250 px wide, drawn from a list of line descriptions in a frame look. The Curio Shop's previews draw a sample
-- with it (STA-R88, adapter/Goods.lua); the live tracker (#218) fills it with live lines and docks it. Look reference:
-- tracker T1 in prototypes/stats-window/, whose CSS gives the colours below.

-- A tint from its hex code (adapter/BookWidgets.lua).
local tint = ns.BookTint

--- The tracker's width in pixels (Tunables: Tracker width, about 250 px).
ns.TRACKER_WIDTH = 250

--- A watch's band dot by band (STA-R82): green normal, amber unlucky, red very unlucky, and `none`, grey, with no
--- luck reading. Tracker T1's `--normal`, `--unlucky`, `--very` and `.dot.none`.
ns.BAND_DOT_COLORS = {
	normal = tint("7fbf6a"),
	unlucky = tint("e8b04a"),
	veryUnlucky = tint("e0603c"),
	none = tint("777777"),
}

--- The words' colours by role, a frame's `ink`: the header ("Stats"), plain text (a Session line, a watch's count),
--- dim text (the header's right text, a dim line, a watch's sub-line) and a watch's name.
---@class StatsTrackerInks
---@field header number[]
---@field text number[]
---@field dim number[]
---@field name number[]

--- The native block's colours (tracker T1): the gold header, white lines, grey small print, pale gold watch names.
---@type StatsTrackerInks
ns.TRACKER_INKS = {
	header = tint("ffd100"),
	text = tint("ffffff"),
	dim = tint("cfc8b8"),
	name = tint("ffd27a"),
}

--- A tracker frame's look (STA-R84, STA-R88): a backing laid behind the block in a tint, a border round it, and
--- optionally an inner rule inside the border, rivets on its corners, and inks for words on a pale backing (nil keeps
--- the native colours, ns.TRACKER_INKS).
---@class StatsTrackerFrameLook
---@field backing string      -- the backing's texture
---@field tint number[]       -- its vertex tint
---@field alpha number        -- its opacity
---@field border number[]     -- the border's colour
---@field borderSize number   -- its width, in pixels
---@field inner number[]?     -- a hairline inside the border, if any
---@field innerAlpha number?  -- its opacity (1 if nil)
---@field rivets number[]?    -- a rivet's tint on each corner, if any
---@field ink StatsTrackerInks?

--- One line of the tracker, top to bottom (STA-R82):
--- - `header`: `text` ("Stats") with `right` on the right ("Session · 21m"), over a faint rule;
--- - `line`: a plain line, `dim` for small grey print;
--- - `watch`: a band dot (`band`, nil for grey), `name`, the right-hand `count`, and below them the `sub` line.
---@class StatsTrackerLine
---@field kind "header"|"line"|"watch"
---@field text string?
---@field right string?
---@field dim boolean?
---@field band StatsBand?
---@field name string?
---@field count string?
---@field sub string?
---@field item integer?    -- a watch's item, for its hover and click (STA-R83)
---@field area integer?    -- a watch's place

-- Heights in pixels: the header, a plain line, a watch's top padding, its name line and its sub-line.
local HEADER_HEIGHT, LINE_HEIGHT, WATCH_PAD, NAME_HEIGHT, SUB_HEIGHT = 18, 15, 4, 14, 13
-- A band dot's size, the name's indent after it, and the room kept on the right for the count.
local DOT_SIZE, NAME_INDENT, COUNT_ROOM = 8, 14, 48
-- How far a frame reaches out round the block, the inner rule's inset from that edge, and a rivet's size.
local FRAME_PAD, INNER_INSET, RIVET_SIZE = 6, 3, 6

--- One row of the block: every widget a line kind may use, shown as its line needs. A button, so the live tracker can
--- give it clicks and hovers (STA-R83).
---@class StatsTrackerRow: Button
---@field line StatsTrackerLine
---@field dot Texture
---@field text FontString  -- the header's title, a plain line, a watch's name
---@field right FontString -- the header's right text, a watch's count
---@field sub FontString   -- a watch's sub-line
---@field rule Texture     -- the rule under the header

--- A tracker frame on a block (STA-R84): the backing, the border's lines, the inner rule's lines and the four rivets,
--- all hidden until a look dresses it.
---@class StatsTrackerFrameView
---@field backing Texture
---@field border Texture[]
---@field inner Texture[]
---@field rivets Texture[]

--- A tracker block (STA-R82): `SetLines` draws its lines and returns its height; `SetFrame` dresses it in a frame
--- look (nil: the plain native block). Either may come first.
---@class StatsTrackerBlock: Frame
---@field rows StatsTrackerRow[]
---@field frame StatsTrackerFrameView
---@field look StatsTrackerFrameLook?
---@field SetLines fun(self: StatsTrackerBlock, lines: StatsTrackerLine[]): number
---@field SetFrame fun(self: StatsTrackerBlock, look: StatsTrackerFrameLook?)

-- Four lines round `frame`'s edge, `out` pixels outside it (a negative `out` is inside), in `layer`: top, bottom,
-- left, right.
---@param frame Frame
---@param out number
---@param layer DrawLayer
---@return Texture[]
local function edgeLines(frame, out, layer)
	local lines = {}
	for i, points in ipairs({
		{ "TOPLEFT", "TOPRIGHT" },
		{ "BOTTOMLEFT", "BOTTOMRIGHT" },
		{ "TOPLEFT", "BOTTOMLEFT" },
		{ "TOPRIGHT", "BOTTOMRIGHT" },
	}) do
		local line = frame:CreateTexture(nil, layer)
		for _, point in ipairs(points) do
			line:SetPoint(point, point:find("RIGHT") and out or -out, point:find("TOP") and out or -out)
		end
		lines[i] = line
	end
	return lines
end

-- Sets edge lines' colour, opacity and width (the top and bottom lines' height, the sides' width), and shows them.
---@param lines Texture[]
---@param color number[]
---@param alpha number
---@param size number
local function paintLines(lines, color, alpha, size)
	for i, line in ipairs(lines) do
		line:SetColorTexture(color[1], color[2], color[3], alpha)
		if i <= 2 then
			line:SetHeight(size)
		else
			line:SetWidth(size)
		end
		line:Show()
	end
end

---@param lines Texture[]
local function hideAll(lines)
	for _, line in ipairs(lines) do
		line:Hide()
	end
end

-- Builds a block's frame view, hidden.
---@param block Frame
---@return StatsTrackerFrameView
local function newFrameView(block)
	local backing = block:CreateTexture(nil, "BACKGROUND")
	backing:SetPoint("TOPLEFT", -FRAME_PAD, FRAME_PAD)
	backing:SetPoint("BOTTOMRIGHT", FRAME_PAD, -FRAME_PAD)
	local rivets = {}
	for i, corner in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
		local rivet = block:CreateTexture(nil, "OVERLAY")
		rivet:SetTexture(ns.BOOK_TEXTURES.disc)
		rivet:SetSize(RIVET_SIZE, RIVET_SIZE)
		local inset = FRAME_PAD - INNER_INSET
		rivet:SetPoint(
			"CENTER",
			block,
			corner,
			corner:find("RIGHT") and inset or -inset,
			corner:find("TOP") and inset or -inset
		)
		rivets[i] = rivet
	end
	---@type StatsTrackerFrameView
	local view = {
		backing = backing,
		border = edgeLines(block, FRAME_PAD, "BORDER"),
		inner = edgeLines(block, FRAME_PAD - INNER_INSET, "BORDER"),
		rivets = rivets,
	}
	backing:Hide()
	hideAll(view.border)
	hideAll(view.inner)
	hideAll(rivets)
	return view
end

-- Dresses a frame view in `look`, or hides it all for nil.
---@param view StatsTrackerFrameView
---@param look StatsTrackerFrameLook?
local function dress(view, look)
	if not look then
		view.backing:Hide()
		hideAll(view.border)
		hideAll(view.inner)
		hideAll(view.rivets)
		return
	end
	view.backing:SetTexture(look.backing)
	view.backing:SetVertexColor(look.tint[1], look.tint[2], look.tint[3])
	view.backing:SetAlpha(look.alpha)
	view.backing:Show()
	paintLines(view.border, look.border, 1, look.borderSize)
	if look.inner then
		paintLines(view.inner, look.inner, look.innerAlpha or 1, 1)
	else
		hideAll(view.inner)
	end
	for _, rivet in ipairs(view.rivets) do
		if look.rivets then
			rivet:SetVertexColor(look.rivets[1], look.rivets[2], look.rivets[3])
			rivet:Show()
		else
			rivet:Hide()
		end
	end
end

-- Builds one row of `block`: the dot, the main text, the right-hand text, the sub-line and the header's rule.
---@param block Frame
---@return StatsTrackerRow
local function newRow(block)
	local row = CreateFrame("Button", nil, block) --[[@as StatsTrackerRow]]
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetTexture(ns.BOOK_TEXTURES.disc)
	row.dot:SetSize(DOT_SIZE, DOT_SIZE)
	row.dot:SetPoint("TOPLEFT", 1, -(WATCH_PAD + 3))
	row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.text:SetJustifyH("LEFT")
	row.text:SetWordWrap(false)
	row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.right:SetJustifyH("RIGHT")
	row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.sub:SetJustifyH("LEFT")
	row.sub:SetWordWrap(false)
	row.sub:SetPoint("TOPLEFT", NAME_INDENT, -(WATCH_PAD + NAME_HEIGHT))
	row.sub:SetPoint("TOPRIGHT", 0, -(WATCH_PAD + NAME_HEIGHT))
	row.rule = row:CreateTexture(nil, "ARTWORK")
	row.rule:SetPoint("BOTTOMLEFT", 0, 1)
	row.rule:SetPoint("BOTTOMRIGHT", 0, 1)
	row.rule:SetHeight(1)
	return row
end

-- Lays out `row` for `line` and returns its height.
---@param row StatsTrackerRow
---@param line StatsTrackerLine
---@return number
local function layOut(row, line)
	row.line = line
	local text, right = row.text, row.right
	text:ClearAllPoints()
	right:ClearAllPoints()
	row.dot:SetShown(line.kind == "watch")
	row.sub:SetShown(line.kind == "watch")
	row.rule:SetShown(line.kind == "header")
	if line.kind == "header" then
		text:SetFontObject("GameFontNormal")
		text:SetPoint("TOPLEFT")
		text:SetText(line.text)
		right:SetFontObject("GameFontHighlightSmall")
		right:SetPoint("TOPRIGHT", 0, -2)
		right:SetText(line.right)
		right:SetShown(line.right ~= nil)
		return HEADER_HEIGHT
	elseif line.kind == "watch" then
		local color = ns.BAND_DOT_COLORS[line.band or "none"]
		row.dot:SetVertexColor(color[1], color[2], color[3])
		text:SetFontObject("GameFontNormalSmall")
		text:SetPoint("TOPLEFT", NAME_INDENT, -WATCH_PAD)
		text:SetPoint("TOPRIGHT", -COUNT_ROOM, -WATCH_PAD)
		text:SetText(line.name)
		right:SetFontObject("GameFontHighlightSmall")
		right:SetPoint("TOPRIGHT", 0, -WATCH_PAD)
		right:SetText(line.count)
		right:Show()
		row.sub:SetFontObject("GameFontHighlightSmall")
		row.sub:SetText(line.sub)
		return WATCH_PAD + NAME_HEIGHT + SUB_HEIGHT
	end
	text:SetFontObject("GameFontHighlightSmall")
	text:SetPoint("TOPLEFT", 0, -2)
	text:SetPoint("TOPRIGHT", 0, -2)
	text:SetText(line.text)
	right:Hide()
	return LINE_HEIGHT
end

-- Sets `row`'s words in `inks` by their roles.
---@param row StatsTrackerRow
---@param inks StatsTrackerInks
local function ink(row, inks)
	local kind = row.line.kind
	local function paint(fontString, color)
		fontString:SetTextColor(color[1], color[2], color[3])
	end
	if kind == "header" then
		paint(row.text, inks.header)
		paint(row.right, inks.dim)
		row.rule:SetColorTexture(inks.header[1], inks.header[2], inks.header[3], 0.35)
	elseif kind == "watch" then
		paint(row.text, inks.name)
		paint(row.right, inks.text)
		paint(row.sub, inks.dim)
	else
		paint(row.text, row.line.dim and inks.dim or inks.text)
	end
end

--- A new, empty tracker block on `parent`, ns.TRACKER_WIDTH wide, with no frame.
---@param parent Frame
---@return StatsTrackerBlock
function ns.NewTrackerBlock(parent)
	local block = CreateFrame("Frame", nil, parent) --[[@as StatsTrackerBlock]]
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
