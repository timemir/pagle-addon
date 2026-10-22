if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' goods on the client (HNT-R120–R122, HNT-R70, HNT-R79): registered with Core, previewed on the Curio Shop's
-- stage, and the looks the board's leather and the tracker wear. The four covers are the books art kit v2's
-- (adapter/BoardWidgets.lua's leather): Leather, Oilcloth and Verdigris drawn at the board's size, Tooled Leather with
-- its gilt double rule, Verdigris with its gilt corner. The tracker's three looks are the kit's: the native block
-- restyled, Ink Wash's paper and Wax Seal's parchment (adapter/BookAtlas.lua's TrackerInk and TrackerWax), each with
-- its own fonts and inks.

-- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1 (ns.BoardTint).
local tint = ns.BoardTint

--- A notebook cover's look (HNT-R70, HNT-R121): the leather the board wears (adapter/Board.lua's BoardCoverLook, every
--- field given) and the elastic strap the closed notebook shows in the shop.
---@class HuntsCoverLook: BoardCover
---@field strap number[]

-- The straps, as the kit's cover swatches draw them: dark leather, or deep green on the green cloth.
local STRAP, GREEN_STRAP = tint("2a1608"), tint("1c3a30")

--- Each notebook cover's look, by good ID (HNT-R121), the books kit v2's Covers.lua: Leather is the board's own
--- (ns.BOARD_COVER); Oilcloth a waxed green cloth; Tooled Leather the leather, darker at its foot, with a gilt double
--- rule; Verdigris copper gone green, with a gilt corner.
---@type table<string, HuntsCoverLook>
ns.COVERS = {
	[ns.DEFAULT_COVER] = { foot = ns.BOARD_COVER.foot, strap = STRAP },
	["hunts.notebookcover.oilcloth"] = { foot = 1, fill = ns.COVER_FILES.oilcloth, strap = STRAP },
	["hunts.notebookcover.tooled"] = { foot = 0.75, tooled = true, strap = STRAP },
	["hunts.notebookcover.verdigris"] = {
		foot = 1,
		fill = ns.COVER_FILES.verdigris,
		corner = true,
		strap = GREEN_STRAP,
	},
}

--- The look of cover good `goodID`, or Leather's for an ID that isn't a cover's.
---@param goodID string?
---@return HuntsCoverLook
function ns.CoverLook(goodID)
	return ns.COVERS[goodID] or ns.COVERS[ns.DEFAULT_COVER]
end

-- The closed notebook on the stage, as prototypes/curio-shop/'s notebook swatch: its size, its spine's shadow, and the
-- elastic strap down its right side, and Verdigris's corner on it.
local NOTEBOOK_WIDTH, NOTEBOOK_HEIGHT, NOTEBOOK_CORNER = 110, 140, 24
local SPINE_WIDTH = 8
local STRAP_WIDTH, STRAP_INSET, STRAP_OVER = 8, 14, 3

--- A closed notebook on a stage (HNT-R121): the leather in a cover, its spine's shadow and its strap; no pages.
---@class HuntsNotebook: Frame
---@field cover BoardLeatherView
---@field strap Texture

-- Builds a stage's notebook, at its top as the Ledger's closed book and Core's crest bookplate sit.
---@param stage Frame
---@return HuntsNotebook
local function buildNotebook(stage)
	local notebook = CreateFrame("Frame", nil, stage) --[[@as HuntsNotebook]]
	notebook:SetSize(NOTEBOOK_WIDTH, NOTEBOOK_HEIGHT)
	notebook:SetPoint("TOP", 0, -16)
	notebook.cover = ns.NewBoardLeather(notebook, NOTEBOOK_CORNER)
	local spine = notebook:CreateTexture(nil, "BORDER", nil, 2)
	spine:SetColorTexture(0, 0, 0, 0.35)
	spine:SetPoint("TOPLEFT", 2, -2)
	spine:SetPoint("BOTTOMLEFT", 2, 2)
	spine:SetWidth(SPINE_WIDTH)
	-- The strap rides over the kit's band.
	local over = CreateFrame("Frame", nil, notebook)
	over:SetAllPoints()
	over:SetFrameLevel(notebook:GetFrameLevel() + 8)
	notebook.strap = over:CreateTexture(nil, "ARTWORK")
	notebook.strap:SetPoint("TOPRIGHT", -STRAP_INSET, STRAP_OVER)
	notebook.strap:SetPoint("BOTTOMRIGHT", -STRAP_INSET, -STRAP_OVER)
	notebook.strap:SetWidth(STRAP_WIDTH)
	return notebook
end

-- Each stage's preview frame, made at its first drawing: the shop gives every good its own stage (#157), so one
-- frame each. Weak, so a stage the shop drops goes.
---@type table<Frame, Frame>
local drawn = setmetatable({}, { __mode = "k" })

--- Draws cover `goodID`'s closed notebook on `stage` (HNT-R121), in that cover.
---@param stage Frame
---@param goodID string
local function previewCover(stage, goodID)
	local notebook = drawn[stage] --[[@as HuntsNotebook?]]
	if not notebook then
		notebook = buildNotebook(stage)
		drawn[stage] = notebook
	end
	local look = ns.CoverLook(goodID)
	notebook.cover:SetCover(look)
	notebook.strap:SetColorTexture(look.strap[1], look.strap[2], look.strap[3], 1)
	notebook:Show()
end

--- A font as a tracker look sets it: its face, size, ink and whether it has a shadow (words over the world have one).
---@class HuntsTrackerFont
---@field [1] HuntsArtFace
---@field [2] number
---@field [3] number[]
---@field [4] boolean?

--- A tracker look (HNT-R79): the books kit's geometry and type for one of the three. The block is `width` wide; the
--- words sit from `x` to `right`; the first Hunt's lines start `first` down and each Hunt takes `step`, its second line
--- `second` below its first. `frame` is its paper's atlas (adapter/BookAtlas.lua), sliced down so it grows with its lines.
---@class HuntsTrackerLook
---@field frame string?        -- nil: no frame, the native look
---@field width number
---@field x number
---@field right number
---@field first number
---@field step number
---@field second number
---@field foot number          -- the room under the last line
---@field shade boolean        -- the native look's fading shade behind each line
---@field paper boolean        -- dots in ink on paper, not bright over the world
---@field caps boolean         -- "Hunts" in small caps
---@field header HuntsTrackerFont
---@field chevron number[]
---@field name HuntsTrackerFont
---@field label HuntsTrackerFont
---@field sub HuntsTrackerFont

-- The native look's inks; its grey a little lighter than the kit's, to read over bright ground.
local GOLD, WHITE, GREY = tint("ffd100"), tint("ffffff"), tint("e4dcc6")
local PAPER_INK, PAPER_SMALL = tint("2e1c0c"), tint("5a4028")

--- The tracker's looks: "native" for No frame (the plain block, restyled in the kit's type), and the two frames for
--- sale.
---@type table<string, HuntsTrackerLook>
ns.TRACKER_LOOKS = {
	native = {
		width = 260,
		x = 8,
		right = 252,
		first = 26,
		step = 41,
		second = 20,
		foot = 4,
		shade = true,
		paper = false,
		caps = false,
		header = { "gilt", 14, GOLD, true },
		chevron = GOLD,
		name = { "print", 13, WHITE, true },
		label = { "print", 13, GOLD, true },
		sub = { "print", 13, GREY, true },
	},
	inkwash = {
		frame = "TrackerInk",
		width = 268,
		x = 12,
		right = 256,
		first = 32,
		step = 44,
		second = 23,
		foot = 8,
		shade = false,
		paper = true,
		caps = true,
		header = { "print", 12, tint("23407a") },
		chevron = tint("23407a"),
		name = { "handSemi", 18, PAPER_INK },
		label = { "hand", 17, tint("9a2a1a") },
		sub = { "print", 13, PAPER_SMALL },
	},
	waxseal = {
		frame = "TrackerWax",
		width = 272,
		x = 16,
		right = 260,
		first = 32,
		step = 42,
		second = 21,
		foot = 8,
		shade = false,
		paper = true,
		caps = true,
		header = { "print", 12, tint("7a1a0e") },
		chevron = tint("7a1a0e"),
		name = { "gilt", 15, PAPER_INK },
		label = { "hand", 17, tint("7a1a0e") },
		sub = { "print", 13, PAPER_SMALL },
	},
}
local LOOKS = ns.TRACKER_LOOKS

--- Each tracker frame's look, by good ID (HNT-R121). No frame (ns.NO_TRACKER_FRAME) has none: the native look.
---@type table<string, HuntsTrackerLook>
ns.TRACKER_FRAMES = {
	["hunts.trackerframe.inkwash"] = LOOKS.inkwash,
	["hunts.trackerframe.waxseal"] = LOOKS.waxseal,
}

--- The look the tracker wears for tracker frame `goodID`: its own, or the native look for none.
---@param goodID string?
---@return HuntsTrackerLook
function ns.TrackerLook(goodID)
	return ns.TRACKER_FRAMES[goodID] or LOOKS.native
end

-- The frame's paper keeps this much of its top and its foot when it slices down.
local FRAME_TOP, FRAME_FOOT = 30, 20
-- A dot's size; an extra line's height ("+N more", the empty line); the room between the Pagle Wagers block and the
-- Hunts block's header under it.
local DOT_SIZE, EXTRA_LINE, WAGERS_GAP = 8, 20, 6

--- The tracker's widgets, for its draws (and specs that read them).
---@class HuntsTrackerView
---@field frame Frame            -- the block Core docks
---@field paper HuntsVSlice      -- the frame's paper, sliced to the block's height
---@field header Button          -- collapses and expands it (HNT-R77)
---@field title FontString       -- "Hunts"
---@field chevron Texture[]      -- the collapse mark: two strokes, down while expanded, right while collapsed
---@field lines HuntsTrackerLineButton[]   -- one per shown Hunt, ns.TRACKER_SHOWN of them
---@field more HuntsTrackerMoreButton   -- "+N more", opens the board (HNT-R77)
---@field empty FontString       -- "Pin a Hunt to keep it here."
---@field wagers HuntsTrackerWagersView   -- the Pagle Wagers block above the header (HNT-R175)
---@field look HuntsTrackerLook  -- the look it last drew in
---@field wearing string?        -- a tracker frame's good ID the dev tour dresses it in (adapter/Tour.lua); nil: the
--- equipped one
---@field counting boolean?      -- whether the tracker last told the grouping lines that count down show (HNT-R42)

--- The Pagle Wagers block's widgets (HNT-R175), on the same block above the Hunts block, all hidden while no run is on.
---@class HuntsTrackerWagersView
---@field header Button          -- collapses and expands it (HNT-R177)
---@field title FontString       -- "Pagle Wagers"
---@field chevron Texture[]
---@field lines HuntsTrackerLineButton[]   -- one per shown run, ns.TRACKER_RUNS of them, its run key in `runKey`
---@field more HuntsTrackerMoreButton   -- "+{n} more wagers on the table", opens the Pagle Wagers spread

---@class HuntsTrackerLineButton: Button
---@field shade Texture
---@field dot BoardDotView
---@field first FontString       -- the Hunt's name, or the run's event's
---@field label FontString       -- its tracker label, at the right
---@field second FontString
---@field huntID string?
---@field runKey string?         -- a run's lines (HNT-R175)

---@class HuntsTrackerMoreButton: Button
---@field text FontString

--- What a tracker block shows (HNT-R76): each Hunt's dot, name, label and second line (none in the shop's sample),
--- "+N more", the empty line, and whether it is collapsed to its header; above them, while a run is on, the Pagle
--- Wagers block (HNT-R175).
---@class HuntsTrackerContent
---@field hunts { dot: HuntGroup, name: string, label: string, second: string? }[]
---@field more string?
---@field empty boolean
---@field collapsed boolean
---@field wagers HuntsTrackerWagersContent?   -- nil: no Pagle Wagers block

--- What the Pagle Wagers block shows (HNT-R175, HNT-R177): each run's name, label and second line, under a dot in
--- the wagers' oxblood, "+{n} more wagers on the table", and whether it is collapsed to its header.
---@class HuntsTrackerWagersContent
---@field runs { name: string, label: string, second: string }[]
---@field more string?
---@field collapsed boolean

-- Lets a Shift-drag that starts on `child` move the dock: a mouse-enabled child takes the drag, so it hands it to the
-- docked block, whose drag scripts Core hooked (CORE-R71).
---@param child Frame
---@param block Frame
local function passDrags(child, block)
	child:RegisterForDrag("LeftButton")
	for _, script in ipairs({ "OnDragStart", "OnDragStop" }) do
		child:SetScript(script, function()
			local fn = block:GetScript(script)
			if fn then
				fn(block, "LeftButton")
			end
		end)
	end
end

-- Sets a font string in a look's font.
---@param text FontString
---@param font HuntsTrackerFont
local function setFont(text, font)
	text:SetFontObject(ns.ArtFont(font[1], font[2], font[4]))
	text:SetTextColor(font[3][1], font[3][2], font[3][3])
end

-- A fading shade behind a line in the native look, as the client's objective tracker lays its lines on the world.
---@param parent Frame
---@return Texture
local function newShade(parent)
	local shade = parent:CreateTexture(nil, "BACKGROUND")
	shade:SetColorTexture(1, 1, 1, 1)
	shade:SetGradient("HORIZONTAL", CreateColor(0, 0, 0, 0.6), CreateColor(0, 0, 0, 0))
	return shade
end

-- Hunt `i`'s lines, a button (the tracker opens the board on its Hunt, HNT-R77): its dot, its name and label, then
-- the target line and progress under them.
---@param block Frame
---@return HuntsTrackerLineButton
local function buildLine(block)
	local line = CreateFrame("Button", nil, block) --[[@as HuntsTrackerLineButton]]
	line.shade = newShade(line)
	line.shade:SetPoint("TOPLEFT")
	line.shade:SetPoint("BOTTOMRIGHT", 0, 3)
	line.dot = ns.NewBoardDot(line, DOT_SIZE)
	local function text(justify)
		local made = line:CreateFontString(nil, "OVERLAY")
		made:SetJustifyH(justify)
		made:SetWordWrap(false)
		return made
	end
	line.first, line.label, line.second = text("LEFT"), text("RIGHT"), text("LEFT")
	line:SetScript("OnClick", function(self)
		ns.OpenBoard(self.huntID)
	end)
	passDrags(line, block)
	line:Hide()
	return line
end

-- An extra line's button ("+N more"), hidden until drawn.
---@param block Frame
---@return HuntsTrackerMoreButton
local function buildMore(block)
	local more = CreateFrame("Button", nil, block) --[[@as HuntsTrackerMoreButton]]
	more.text = more:CreateFontString(nil, "OVERLAY")
	more.text:SetJustifyH("LEFT")
	passDrags(more, block)
	more:Hide()
	return more
end

-- The header: "Hunts" with the collapse mark before it.
---@param block Frame
---@return Button header
---@return FontString title
---@return Texture[] chevron
local function buildHeader(block)
	local header = CreateFrame("Button", nil, block)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	local title = header:CreateFontString(nil, "OVERLAY")
	title:SetJustifyH("LEFT")
	local chevron = {}
	for i = 1, 2 do
		chevron[i] = header:CreateTexture(nil, "OVERLAY")
		chevron[i]:SetSize(6, 1.6)
	end
	passDrags(header, block)
	return header, title, chevron
end

--- The tracker's block on `parent` (HNT-R76): the header, the Hunts' line buttons, "+N more" and the empty line, all
--- hidden until drawn, on its look's paper. The tracker (adapter/Tracker.lua) wires its clicks; the Curio Shop's sample
--- (HNT-R121) draws two fixed Hunts in one.
---@param parent Frame
---@return HuntsTrackerView
function ns.NewTrackerBlock(parent)
	local block = CreateFrame("Frame", nil, parent)
	block:SetSize(LOOKS.native.width, LOOKS.native.first)
	local paper = CreateFrame("Frame", nil, block) --[[@as HuntsVSlice]]
	paper:SetPoint("TOPLEFT")
	paper:SetFrameLevel(block:GetFrameLevel())
	paper:Hide()
	local header, title, chevron = buildHeader(block)
	local lines = {}
	for i = 1, ns.TRACKER_SHOWN do
		lines[i] = buildLine(block)
	end
	local more = buildMore(block)
	more:SetScript("OnClick", function()
		ns.OpenBoard()
	end)
	local wagers = {}
	wagers.header, wagers.title, wagers.chevron = buildHeader(block)
	wagers.header:Hide()
	wagers.lines = {}
	for i = 1, ns.TRACKER_RUNS do
		wagers.lines[i] = buildLine(block)
	end
	wagers.more = buildMore(block)
	local empty = block:CreateFontString(nil, "OVERLAY")
	empty:SetJustifyH("LEFT")
	empty:Hide() -- its words come with its look's font, at its draw
	---@type HuntsTrackerView
	return {
		frame = block,
		paper = paper,
		header = header,
		title = title,
		chevron = chevron,
		lines = lines,
		more = more,
		empty = empty,
		wagers = wagers,
		look = LOOKS.native,
	}
end

-- Draws the collapse mark at `x`, `y` in `color`: "v" while expanded, ">" while collapsed.
---@param chevron Texture[]
---@param header Frame
---@param x number
---@param y number
---@param color number[]
---@param collapsed boolean
local function drawChevron(chevron, header, x, y, color, collapsed)
	local places = collapsed and { { 5, 2.5, -45 }, { 5, 7.5, 45 } } or { { 3, 5, -45 }, { 7, 5, 45 } }
	for i, stroke in ipairs(chevron) do
		local place = places[i]
		stroke:SetColorTexture(color[1], color[2], color[3], 1)
		stroke:ClearAllPoints()
		stroke:SetPoint("CENTER", header, "TOPLEFT", x + place[1], -(y + place[2]))
		stroke:SetRotation(math.rad(place[3]))
	end
end

-- Draws a header `top` down the block in `look`: `text` (in small caps on paper) after the collapse mark.
---@param header Button
---@param title FontString
---@param chevron Texture[]
---@param look HuntsTrackerLook
---@param text string
---@param top number
---@param collapsed boolean
local function drawHeader(header, title, chevron, look, text, top, collapsed)
	header:ClearAllPoints()
	header:SetPoint("TOPLEFT", 0, -top)
	header:SetPoint("TOPRIGHT", 0, -top)
	header:SetHeight(look.first)
	setFont(title, look.header)
	title:SetText(look.caps and ns.BoardSmallCaps(text) or text)
	title:ClearAllPoints()
	title:SetPoint("TOPLEFT", header, "TOPLEFT", look.x + 16, -(look.caps and 12 or 10))
	drawChevron(chevron, header, look.x, 14, look.chevron, collapsed)
end

-- Draws each of `entries` (a Hunt's or a run's two lines) on `lines` from `y` down, under a dot of its group
-- (`entry.dot`, else `dot`), and hides the lines past them; returns the y under the last.
---@param lines HuntsTrackerLineButton[]
---@param entries { dot: (HuntGroup|"wagers")?, name: string, label: string, second: string? }[]
---@param look HuntsTrackerLook
---@param y number
---@param dot (HuntGroup|"wagers")?
---@return number
local function drawLines(lines, entries, look, y, dot)
	local x, right = look.x, look.right
	for i, line in ipairs(lines) do
		local entry = entries[i]
		line:SetShown(entry ~= nil)
		if entry then
			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", 0, -y)
			line:SetSize(look.width, look.step)
			line.shade:SetShown(look.shade)
			line.dot:SetGroup(entry.dot or dot --[[@as HuntGroup|"wagers"]], look.paper)
			line.dot:ClearAllPoints()
			line.dot:SetPoint("TOPLEFT", x, -8)
			setFont(line.label, look.label)
			line.label:SetText(entry.label)
			line.label:ClearAllPoints()
			line.label:SetPoint("TOPRIGHT", line, "TOPLEFT", right, -4)
			setFont(line.first, look.name)
			line.first:SetText(entry.name)
			line.first:ClearAllPoints()
			line.first:SetPoint("TOPLEFT", x + 14, -3)
			line.first:SetWidth(math.max(1, right - x - 14 - line.label:GetStringWidth() - 6))
			setFont(line.second, look.sub)
			line.second:SetText(entry.second or "")
			line.second:SetShown(entry.second ~= nil)
			line.second:ClearAllPoints()
			line.second:SetPoint("TOPLEFT", x + 14, -look.second)
			-- a long target line shrinks a little, then is cut short, within the block
			local sub = look.sub
			ns.FitText(line.second, sub[1], sub[2], right - x - 14, sub[2] - 2, sub[4], sub[3])
			y = y + look.step
		end
	end
	return y
end

-- Draws an extra line's `text` ("+N more") at `y`, or hides it for nil; returns the y under it.
---@param more HuntsTrackerMoreButton
---@param look HuntsTrackerLook
---@param text string?
---@param y number
---@return number
local function drawMore(more, look, text, y)
	more:SetShown(text ~= nil)
	if not text then
		return y
	end
	setFont(more.text, look.label)
	more.text:SetText(text)
	more.text:ClearAllPoints()
	more.text:SetPoint("LEFT", look.x + 14, 0)
	more:ClearAllPoints()
	more:SetPoint("TOPLEFT", 0, -y)
	more:SetSize(look.width, EXTRA_LINE)
	return y + EXTRA_LINE
end

-- Draws the Pagle Wagers block at the block's top (HNT-R175, HNT-R177), or hides it for `content` nil; returns how
-- far down the Hunts block's header goes under it.
---@param view HuntsTrackerWagersView
---@param look HuntsTrackerLook
---@param content HuntsTrackerWagersContent?
---@return number
local function drawWagers(view, look, content)
	view.header:SetShown(content ~= nil)
	if not content then
		drawLines(view.lines, {}, look, 0)
		drawMore(view.more, look, nil, 0)
		return 0
	end
	drawHeader(view.header, view.title, view.chevron, look, ns.L.WAGERS_KICKER, 0, content.collapsed)
	local y = drawLines(view.lines, content.collapsed and {} or content.runs, look, look.first, "wagers")
	y = drawMore(view.more, look, not content.collapsed and content.more or nil, y)
	return y + WAGERS_GAP
end

--- Draws `content` on a tracker block in `look` (HNT-R76, HNT-R79, HNT-R175): the paper under both blocks; the Pagle
--- Wagers block while a run is on, its header, each run's lines and "+{n} more wagers on the table"; under it the
--- Hunts header with its mark, each Hunt's dot, name and label with its second line, "+N more" or the empty line.
--- Sizes the block to what shows, so the dock reflows (CORE-R70).
---@param view HuntsTrackerView
---@param look HuntsTrackerLook
---@param content HuntsTrackerContent
function ns.DrawTrackerBlock(view, look, content)
	view.look = look
	local block = view.frame
	local top = drawWagers(view.wagers, look, content.wagers)
	drawHeader(view.header, view.title, view.chevron, look, ns.L.TITLE, top, content.collapsed)
	local y = drawLines(view.lines, content.hunts, look, top + look.first)
	y = drawMore(view.more, look, content.more, y)
	view.empty:SetShown(content.empty)
	if content.empty then
		setFont(view.empty, look.sub)
		view.empty:SetText(ns.L.TRACKER_EMPTY)
		view.empty:ClearAllPoints()
		view.empty:SetPoint("TOPLEFT", look.x + 14, -(y + 2))
		y = y + EXTRA_LINE
	end
	local headerOnly = top + look.first
	local height = y == headerOnly and (look.frame and headerOnly + look.foot or headerOnly) or y + look.foot
	block:SetSize(look.width, height)
	view.paper:SetShown(look.frame ~= nil)
	if look.frame then
		ns.SetVSlice(view.paper, look.frame, "frame", height, FRAME_TOP, FRAME_FOOT)
	end
end

--- A sample Hunts tracker on a stage (HNT-R121): the tracker's own block, its "Hunts" header and two fixed Hunts, in
--- a tracker frame's look.
---@class HuntsSampleTracker: Frame
---@field view HuntsTrackerView

-- Builds a stage's sample tracker: the tracker's block, at the stage's top.
---@param stage Frame
---@return HuntsSampleTracker
local function buildSampleTracker(stage)
	local view = ns.NewTrackerBlock(stage)
	local tracker = view.frame --[[@as HuntsSampleTracker]]
	tracker.view = view
	tracker:SetPoint("TOP", 0, -24)
	return tracker
end

--- Draws tracker frame `goodID`'s sample tracker on `stage` (HNT-R121), in that frame's look: a Hunt Now and a Hunt
--- On demand, a line each.
---@param stage Frame
---@param goodID string
local function previewTrackerFrame(stage, goodID)
	local tracker = drawn[stage] --[[@as HuntsSampleTracker?]]
	if not tracker then
		tracker = buildSampleTracker(stage)
		drawn[stage] = tracker
	end
	local hunts = {}
	for i, sample in ipairs(ns.L.PREVIEW_TRACKER_HUNTS) do
		hunts[i] = { dot = i == 1 and "now" or "onDemand", name = sample[1], label = sample[2] }
	end
	ns.DrawTrackerBlock(tracker.view, ns.TrackerLook(goodID), { hunts = hunts, empty = false, collapsed = false })
	tracker:Show()
end

--- Draws `goodID`'s look on the Curio Shop's stage (HNT-R121): a cover's closed notebook, a tracker frame's sample
--- tracker.
---@param stage Frame
---@param slotID string
---@param goodID string
function ns.PreviewGood(stage, slotID, goodID)
	if slotID == ns.COVER_SLOT then
		previewCover(stage, goodID)
	else
		previewTrackerFrame(stage, goodID)
	end
end

-- The bus owner of the board's cover (CORE-R23).
local OWNER = "Pagle_Hunts goods"

--- Dresses the board's leather in the equipped notebook cover (HNT-R70), open or not; `animate` for a change the
--- player made, which an open board shows by dipping its binding while the cover changes.
---@param animate boolean?
local function wearCover(animate)
	ns.board:SetCover(ns.CoverLook(Pagle.GetEquipped(ns.COVER_SLOT)), animate)
end

--- Registers Hunts' slots and goods (HNT-R120, HNT-R121, SHOP-R21), from OnInitialize right after RegisterModule
--- (HNT-R122), and dresses the board in the equipped cover: at ModulesChanged, when every slot is registered and the
--- stored purchases are owned (Core notes that look without an AppearanceChanged, SHOP-R33), and at once at every
--- AppearanceChanged for the slot after.
---@param module PagleModuleHandle
function ns.RegisterGoods(module)
	for _, entry in ipairs(ns.HuntsGoods(ns.PreviewGood)) do
		module:RegisterSlot(entry.slot)
		for _, good in ipairs(entry.goods) do
			module:RegisterGood(good)
		end
	end
	Pagle.RegisterCallback(OWNER, "ModulesChanged", function()
		wearCover(false)
	end)
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.COVER_SLOT then
			wearCover(true)
		end
	end)
end
