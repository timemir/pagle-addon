if not Pagle then
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- The tracker block maker (STA-R82, STA-R84; stats.md › UI › Live tracker): an objective-tracker-style block, about
-- 250 px wide, drawn from a list of line descriptions in a look. The Curio Shop's previews draw a sample with it
-- (STA-R88, adapter/Goods.lua); the live tracker (adapter/Tracker.lua) fills it with live lines and docks it. The three
-- looks are the books art kit's: the native block in the kit's type over the world, the Logbook's ruled paper and the
-- Brass plate (adapter/BookAtlas.lua's TrackerLogbook and TrackerBrass), each sliced down so it grows with its lines.

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

--- A tracker look (STA-R84): the books kit's geometry and type for one of the three. The block is `width` wide; the
--- words sit from `x` to `right`, the header `top` down; `frame` is its paper's atlas, sliced down to the block's
--- height, its middle repeated every `period` units when it keeps a ruling's pitch.
---@class StatsTrackerFrameLook
---@field frame string?        -- nil: no frame, the native look
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

--- The tracker's looks: "native" for No frame, and the two frames for sale.
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
-- The paper keeps this much of its top and its foot when it slices down.
local FRAME_TOP, FRAME_FOOT = 30, 20

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
		block:SetSize(look.width, height)
		block.paper:SetShown(look.frame ~= nil)
		if look.frame then
			ns.SetVSlice(block.paper, look.frame, "frame", height, FRAME_TOP, FRAME_FOOT, look.period)
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
