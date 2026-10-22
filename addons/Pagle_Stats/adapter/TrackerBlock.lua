if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The tracker block maker (STA-R82, STA-R84; stats.md › UI › Live tracker): an objective-tracker-style block, about
-- 250 px wide, drawn from a list of line descriptions in a look. The Curio Shop's previews draw a sample with it
-- (STA-R88, adapter/Goods.lua); the live tracker (adapter/Tracker.lua) fills it with live lines and docks it. The first
-- three looks are the books art kit's: the native block in the kit's type over the world, the Logbook's ruled paper and
-- the Brass plate (adapter/BookAtlas.lua's TrackerLogbook and TrackerBrass). The Curio Shop expansion's five are the
-- shop expansion kit's (TrackerFrames2, goods.json's metrics). Each paper is sliced down so it grows with its lines.

-- A tint from its hex code (adapter/BookWidgets.lua).
local tint = ns.BookTint

--- The tracker's width in pixels in its native look (Tunables: Tracker width, about 250 px); the papers are a little
--- wider, round the same words.
ns.TRACKER_WIDTH = 250

--- A watch's band dot by band (STA-R82): green normal, amber unlucky, red very unlucky, and `none`, grey, with no
--- luck reading; bright over the world.
ns.BAND_DOT_COLORS = {
	normal = tint("4aa84a"),
	unlucky = tint("e0a030"),
	veryUnlucky = tint("e0603c"),
	none = tint("8a8a8a"),
}

--- The same in ink, on the Logbook's paper.
ns.BAND_DOT_INKS = {
	normal = tint("3a8a3a"),
	unlucky = tint("c89030"),
	veryUnlucky = tint("b4281a"),
	none = tint("8a8070"),
}

--- The words' colours by role, a look's `ink`: the header ("Stats"), plain text (a Session line, a watch's name),
--- dim text (a dim line, a watch's sub-line), the header's right text, and a watch's count.
---@class StatsTrackerInks
---@field header number[]
---@field text number[]
---@field dim number[]
---@field right number[]
---@field count number[]

--- The native look's colours: the gold header, white lines, grey small print, a pale right text, gold counts.
---@type StatsTrackerInks
ns.TRACKER_INKS = {
	header = tint("ffd100"),
	text = tint("ffffff"),
	dim = tint("e4dcc6"), -- a little lighter than the kit's grey, to read over bright ground
	right = tint("e8d8a8"),
	count = tint("ffd100"),
}

--- A font as a look sets it: its face, size and whether it has a shadow (words over the world have one).
---@class StatsTrackerFont
---@field [1] StatsArtFace
---@field [2] number
---@field [3] boolean?

--- A tracker look (STA-R84, STA-R88): a frame's geometry and type. The block is `width` wide; the words sit from `x` to
--- `right`, the header `top` down; `frame` is its paper's atlas and `sprite` the paper in it, sliced down to the block's
--- height (ns.SliceDown): `sliceTop` and `sliceFoot` kept, its middle stretched, or repeated every `period` units when
--- it keeps a ruling's pitch.
---@class StatsTrackerFrameLook
---@field frame string?        -- nil: no frame, the native look
---@field sprite string?
---@field sliceTop number?
---@field sliceFoot number?
---@field period number?
---@field width number
---@field x number
---@field right number
---@field top number
---@field foot number          -- the room under the last line
---@field caps boolean         -- "Stats" in small caps
---@field shade boolean        -- the native look's fading shade behind each line
---@field paper boolean        -- band dots in ink on paper
---@field ink StatsTrackerInks
---@field header StatsTrackerFont
---@field em StatsTrackerFont      -- the header's right text
---@field text StatsTrackerFont
---@field count StatsTrackerFont

local PAPER_INKS = {
	header = tint("3e220c"),
	text = tint("2e1c0c"),
	dim = tint("5a4028"),
	right = tint("8a5a2a"),
	count = tint("9a2a1a"),
}
local BRASS_INKS = {
	header = tint("f0cd6a"),
	text = tint("ffffff"),
	dim = tint("e4dcc6"),
	right = tint("e8d8a8"),
	count = tint("ffd100"),
}

-- A Curio Shop expansion frame's inks from the kit's four (header, text, dim, accent): the accent is the header's right
-- text and a watch's count both.
---@param header string
---@param text string
---@param dim string
---@param accent string
---@return StatsTrackerInks
local function kitInks(header, text, dim, accent)
	return { header = tint(header), text = tint(text), dim = tint(dim), right = tint(accent), count = tint(accent) }
end

-- A Curio Shop expansion frame (goods.json): its sprite in TrackerFrames2, 262 wide; the words `insets` (left, right,
-- top, foot) in from its edges; its three-slice's fixed top and foot, and its tiled middle's period (nil: stretched);
-- its inks; and the type of the papers like it, `pale` (the Logbook's, dark ink with band dots in ink) or dark (the
-- Brass plate's, bright words with a shadow).
---@param sprite string
---@param insets number[]
---@param slice number[]
---@param ink StatsTrackerInks
---@param pale boolean
---@return StatsTrackerFrameLook
local function kitLook(sprite, insets, slice, ink, pale)
	local width = 262
	return {
		frame = "TrackerFrames2",
		sprite = sprite,
		sliceTop = slice[1],
		sliceFoot = slice[2],
		period = slice[3],
		width = width,
		x = insets[1],
		right = width - insets[2],
		top = insets[3],
		foot = insets[4],
		caps = pale,
		shade = false,
		paper = pale,
		ink = ink,
		header = pale and { "print", 12 } or { "gilt", 14 },
		em = { "italic", 12.5 },
		text = { "print", 13, not pale },
		count = pale and { "hand", 17 } or { "print", 13, true },
	}
end

--- The tracker's looks: "native" for No frame, and the seven frames for sale.
---@type table<string, StatsTrackerFrameLook>
ns.TRACKER_LOOKS = {
	native = {
		width = 250,
		x = 8,
		right = 242,
		top = 0,
		foot = 4,
		caps = false,
		shade = true,
		paper = false,
		ink = ns.TRACKER_INKS,
		header = { "gilt", 14, true },
		em = { "italic", 12.5, true },
		text = { "print", 13, true },
		count = { "print", 13, true },
	},
	logbook = {
		frame = "TrackerLogbook",
		sprite = "frame",
		sliceTop = 30,
		sliceFoot = 20,
		period = 40,
		width = 274,
		x = 28,
		right = 262,
		top = 6,
		foot = 8,
		caps = true,
		shade = false,
		paper = true,
		ink = PAPER_INKS,
		header = { "print", 12 },
		em = { "italic", 12.5 },
		text = { "print", 13 },
		count = { "hand", 17 },
	},
	brass = {
		frame = "TrackerBrass",
		sprite = "frame",
		sliceTop = 30,
		sliceFoot = 20,
		width = 262,
		x = 14,
		right = 248,
		top = 8,
		foot = 8,
		caps = false,
		shade = false,
		paper = false,
		ink = BRASS_INKS,
		header = { "gilt", 14 },
		em = { "italic", 12.5 },
		text = { "print", 13, true },
		count = { "print", 13, true },
	},
	-- Tally paper banded in pale green, its bands repeated as it grows.
	greenbar = kitLook(
		"frame-greenbar",
		{ 22, 22, 14, 14 },
		{ 14, 14, 36 },
		kitInks("2a4a1a", "14240e", "4a5a3a", "2a6a2a"),
		true
	),
	-- A green board in a pine frame, somebody's tally marks in its corner.
	chalkboard = kitLook(
		"frame-chalkboard",
		{ 16, 16, 14, 14 },
		{ 20, 36 },
		kitInks("ffffff", "f4f4e8", "b8d0c0", "f0e080"),
		false
	),
	-- Sea-blue glass behind the tide staff down its left.
	tidegauge = kitLook(
		"frame-tidegauge",
		{ 32, 16, 14, 14 },
		{ 16, 40 },
		kitInks("f0d080", "e8f6ff", "a8c8d8", "7ae0ff"),
		false
	),
	-- A counting frame, its beads pushed to the ends.
	abacus = kitLook(
		"frame-abacus",
		{ 16, 16, 22, 22 },
		{ 20, 20 },
		kitInks("5a2a0a", "2a1a0a", "6a5030", "a8501a"),
		true
	),
	-- A star map under brass rings, the rings over its top right.
	astrolabe = kitLook(
		"frame-astrolabe",
		{ 16, 60, 16, 16 },
		{ 68, 20 },
		kitInks("f0cd6a", "eef0ff", "a8b0d8", "f0cd6a"),
		false
	),
}
local LOOKS = ns.TRACKER_LOOKS

--- One line of the tracker, top to bottom (STA-R82):
--- - `header`: `text` ("Stats") with `right` on the right ("Session · 21m");
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

-- Heights in pixels: the header, a plain line, a watch; where a watch's sub-line sits; the name's indent after its dot;
-- a dot's size.
local HEADER_HEIGHT, LINE_HEIGHT, WATCH_HEIGHT, SUB_Y, NAME_INDENT, DOT_SIZE = 26, 20, 42, 24, 14, 8

--- One row of the block: every widget a line kind may use, shown as its line needs. A button, so the live tracker can
--- give it clicks and hovers (STA-R83).
---@class StatsTrackerRow: Button
---@field line StatsTrackerLine
---@field shade Texture
---@field dot Texture
---@field text FontString  -- the header's title, a plain line, a watch's name
---@field right FontString -- the header's right text, a watch's count
---@field sub FontString   -- a watch's sub-line

--- A tracker block (STA-R82): `SetLines` draws its lines and returns its height; `SetFrame` dresses it in a look (nil:
--- the native look). Either may come first.
---@class StatsTrackerBlock: Frame
---@field rows StatsTrackerRow[]
---@field paper StatsVSlice           -- the look's paper, sliced to the block's height
---@field look StatsTrackerFrameLook  -- the look it draws in
---@field lines StatsTrackerLine[]
---@field SetLines fun(self: StatsTrackerBlock, lines: StatsTrackerLine[]): number
---@field SetFrame fun(self: StatsTrackerBlock, look: StatsTrackerFrameLook?)

-- Builds one row of `block`: the shade, the dot, the main text, the right-hand text and the sub-line.
---@param block Frame
---@return StatsTrackerRow
local function newRow(block)
	local row = CreateFrame("Button", nil, block) --[[@as StatsTrackerRow]]
	row.shade = row:CreateTexture(nil, "BACKGROUND")
	row.shade:SetColorTexture(1, 1, 1, 1)
	row.shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0))
	row.shade:SetAllPoints()
	row.dot = row:CreateTexture(nil, "ARTWORK")
	row.dot:SetTexture(ns.BOOK_TEXTURES.disc)
	row.dot:SetSize(DOT_SIZE, DOT_SIZE)
	local function text(justify)
		local made = row:CreateFontString(nil, "OVERLAY")
		made:SetJustifyH(justify)
		made:SetWordWrap(false)
		return made
	end
	row.text, row.right, row.sub = text("LEFT"), text("RIGHT"), text("LEFT")
	return row
end

-- Sets a font string in a look's font and ink.
---@param fontString FontString
---@param font StatsTrackerFont
---@param color number[]
local function setFont(fontString, font, color)
	fontString:SetFontObject(ns.ArtFont(font[1], font[2], font[3]))
	fontString:SetTextColor(color[1], color[2], color[3])
end

-- Lays out `row` for `line` in `look` and returns its height.
---@param row StatsTrackerRow
---@param line StatsTrackerLine
---@param look StatsTrackerFrameLook
---@return number
local function layOut(row, line, look)
	row.line = line
	local ink, x, right = look.ink, look.x, look.right
	local text, count = row.text, row.right
	text:ClearAllPoints()
	count:ClearAllPoints()
	row.dot:SetShown(line.kind == "watch")
	row.sub:SetShown(line.kind == "watch")
	if line.kind == "header" then
		setFont(text, look.header, ink.header)
		text:SetPoint("TOPLEFT", x, -(look.caps and 7 or 5))
		text:SetText(look.caps and ns.BookSmallCaps(line.text) or line.text)
		setFont(count, look.em, ink.right)
		count:SetPoint("TOPRIGHT", row, "TOPLEFT", right, -6)
		count:SetText(line.right)
		count:SetShown(line.right ~= nil)
		return HEADER_HEIGHT
	elseif line.kind == "watch" then
		local colors = look.paper and ns.BAND_DOT_INKS or ns.BAND_DOT_COLORS
		local color = colors[line.band or "none"]
		row.dot:SetVertexColor(color[1], color[2], color[3])
		row.dot:ClearAllPoints()
		row.dot:SetPoint("TOPLEFT", x, -9)
		setFont(count, look.count, ink.count)
		count:SetPoint("TOPRIGHT", row, "TOPLEFT", right, -4)
		count:SetText(line.count)
		count:Show()
		setFont(text, look.text, ink.text)
		text:SetPoint("TOPLEFT", x + NAME_INDENT, -4)
		text:SetText(line.name)
		text:SetWidth(math.max(1, right - x - NAME_INDENT - count:GetStringWidth() - 6))
		setFont(row.sub, look.text, ink.dim)
		row.sub:ClearAllPoints()
		row.sub:SetPoint("TOPLEFT", x + NAME_INDENT, -SUB_Y)
		row.sub:SetText(line.sub)
		-- a long sub-line shrinks a little, then is cut short, within the block
		local font = look.text
		ns.FitText(row.sub, font[1], font[2], right - x - NAME_INDENT, font[2] - 2, font[3], ink.dim)
		return WATCH_HEIGHT
	end
	setFont(text, look.text, line.dim and ink.dim or ink.text)
	text:SetPoint("TOPLEFT", x, -3)
	text:SetWidth(right - x)
	text:SetText(line.text)
	count:Hide()
	return LINE_HEIGHT
end

--- A new, empty tracker block on `parent`, in the native look.
---@param parent Frame
---@return StatsTrackerBlock
function ns.NewTrackerBlock(parent)
	local block = CreateFrame("Frame", nil, parent) --[[@as StatsTrackerBlock]]
	block:SetSize(ns.TRACKER_WIDTH, 1)
	block.rows, block.lines, block.look = {}, {}, LOOKS.native
	block.paper = CreateFrame("Frame", nil, block) --[[@as StatsVSlice]]
	block.paper:SetPoint("TOPLEFT")
	block.paper:SetFrameLevel(block:GetFrameLevel())
	block.paper:Hide()

	-- Lays every line out in the look, and sizes the block and its paper to them; returns the lines' height.
	local function draw()
		local look = block.look
		local top = look.top
		for i, line in ipairs(block.lines) do
			local row = block.rows[i]
			if not row then
				row = newRow(block)
				block.rows[i] = row
			end
			local height = layOut(row, line, look)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -top)
			row:SetSize(look.width, height)
			row.shade:SetShown(look.shade)
			row:Show()
			top = top + height
		end
		for i = #block.lines + 1, #block.rows do
			block.rows[i]:Hide()
		end
		local height = math.max(top + look.foot, 1)
		if look.frame then
			-- never shorter than the paper's fixed top and foot
			height = ns.SliceDown(height, look.sliceTop, look.sliceFoot, look.period)
		end
		block:SetSize(look.width, height)
		block.paper:SetShown(look.frame ~= nil)
		if look.frame then
			ns.SetVSlice(block.paper, look.frame, look.sprite, height, look.sliceTop, look.sliceFoot, look.period)
		end
		return height
	end

	function block.SetLines(_, lines)
		block.lines = lines
		return draw()
	end

	function block.SetFrame(_, look)
		block.look = look or LOOKS.native
		draw()
	end

	return block
end
