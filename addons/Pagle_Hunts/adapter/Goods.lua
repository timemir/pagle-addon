if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' goods on the client (HNT-R120–R122, HNT-R70): registered with Core, previewed on the Curio Shop's stage, and
-- the looks the board's leather and the tracker's frame wear. Every texture is an in-client file, in build 70338's
-- ManifestInterfaceData, laid over a tint as adapter/BoardWidgets.lua's are.

-- A tint from its hex code, as the prototypes' CSS writes it: { r, g, b }, 0 to 1 (ns.BoardTint).
local tint = ns.BoardTint

-- The grains: the board's rock backdrop (the default leather's) and FrameGeneral's smoother marble, for a waxed cloth.
local ROCK = ns.BOARD_TEXTURES.leather
local MARBLE = "Interface\\FrameGeneral\\UI-Background-Marble"

--- A notebook cover's look (HNT-R70, HNT-R121): the leather the board wears (adapter/Board.lua's BoardCoverLook, every
--- field given) and the elastic strap the closed notebook shows in the shop.
---@class HuntsCoverLook: BoardCover
---@field strap number[]

-- The default cover's strap; its leather is filled in from ns.BOARD_COVER below.
local defaultCover = { strap = tint("a01818") }

--- Each notebook cover's look, by good ID (HNT-R121). Leather is the board's own (ns.BOARD_COVER); Oilcloth takes
--- prototypes/curio-shop/'s swatch (#1a2a1a, #8aa07a, #d0a020); Tooled Leather and Verdigris are picked from their
--- lore (data/lore/hunts.toml).
---@type table<string, HuntsCoverLook>
ns.COVERS = {
	-- The board's own leather (ns.BOARD_COVER), filled in below, with a red strap.
	[ns.DEFAULT_COVER] = defaultCover --[[@as HuntsCoverLook]],
	-- Black-green waxed cloth, smooth, with a pale green rule and a mustard strap.
	["hunts.notebookcover.oilcloth"] = {
		leather = tint("1a2a1a"),
		edge = tint("080e08"),
		rule = tint("8aa07a"),
		grain = MARBLE,
		grainAlpha = 0.35,
		strap = tint("d0a020"),
	},
	-- Dark hide, deeply grained as if worked with a tool (its lore: tooled with reeds and leaping fish), gilt rule.
	["hunts.notebookcover.tooled"] = {
		leather = tint("3a2212"),
		edge = tint("120a04"),
		rule = tint("c9a46a"),
		grain = ROCK,
		grainAlpha = 0.8,
		strap = tint("6a3e20"),
	},
	-- Copper gone green (its lore: copper corners and clasp, green in the sea air): dark leather, a verdigris rule and
	-- clasp.
	["hunts.notebookcover.verdigris"] = {
		leather = tint("24302a"),
		edge = tint("0c120e"),
		rule = tint("5aa08a"),
		grain = ROCK,
		grainAlpha = 0.45,
		strap = tint("4a8a78"),
	},
}

for key, value in pairs(ns.BOARD_COVER) do
	ns.COVERS[ns.DEFAULT_COVER][key] = value
end

--- The look of cover good `goodID`, or Leather's for an ID that isn't a cover's.
---@param goodID string?
---@return HuntsCoverLook
function ns.CoverLook(goodID)
	return ns.COVERS[goodID] or ns.COVERS[ns.DEFAULT_COVER]
end

-- The closed notebook on the stage, as prototypes/curio-shop/'s notebook swatch: its size, its spine's shadow, and the
-- elastic strap down its right side.
local NOTEBOOK_WIDTH, NOTEBOOK_HEIGHT = 110, 140
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
	notebook.cover = ns.NewBoardLeather(notebook)
	local spine = notebook:CreateTexture(nil, "BORDER", nil, 2)
	spine:SetColorTexture(0, 0, 0, 0.35)
	spine:SetPoint("TOPLEFT", 2, -2)
	spine:SetPoint("BOTTOMLEFT", 2, 2)
	spine:SetWidth(SPINE_WIDTH)
	notebook.strap = notebook:CreateTexture(nil, "ARTWORK")
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

--- A tracker frame's look (HNT-R79, CORE-R73): a backdrop laid behind the native block, in a tint, and a border round
--- it; Wax Seal also presses a seal on the header's corner.
---@class HuntsTrackerFrameLook
---@field backdrop string   -- the backdrop's texture
---@field tint number[]     -- its vertex tint
---@field alpha number      -- its opacity
---@field border number[]   -- the border's colour
---@field borderSize number -- its width, in pixels
---@field seal number[]?    -- a wax seal's tint, if it has one
---@field ink number[]?     -- the words' colour on a pale backdrop; nil keeps the native block's

--- Each tracker frame's look, by good ID (HNT-R121). No frame (ns.NO_TRACKER_FRAME) has none: the plain native
--- block.
---@type table<string, HuntsTrackerFrameLook>
ns.TRACKER_FRAMES = {
	-- A thin grey wash of ink behind the lines (its lore), in a fine ink line.
	["hunts.trackerframe.inkwash"] = {
		backdrop = MARBLE,
		tint = tint("3a3e44"),
		alpha = 0.55,
		border = tint("22262c"),
		borderSize = 1,
	},
	-- Parchment edged in brown, with a red seal pressed in the corner (its lore): the words in the board's ink.
	["hunts.trackerframe.waxseal"] = {
		backdrop = ns.BOARD_TEXTURES.paper,
		tint = ns.BOARD_LOOK.paper,
		alpha = 0.95,
		border = tint("5a3a1a"),
		borderSize = 2,
		seal = ns.BOARD_LOOK.seal,
		ink = ns.BOARD_LOOK.ink,
	},
}

-- How far a frame reaches out round the block it dresses, and the seal's size.
local FRAME_PAD, SEAL_SIZE = 6, 18

--- A tracker frame on a block (HNT-R79): the backdrop, the border's four lines and the seal, all hidden until a look
--- dresses it. The tracker's block (ns.NewTrackerBlock) makes one.
---@class HuntsTrackerFrameView
---@field backdrop Texture
---@field border Texture[]
---@field seal Texture
---@field SetFrame fun(self: HuntsTrackerFrameView, look: HuntsTrackerFrameLook?) -- nil: no frame

---@param block Frame
---@return HuntsTrackerFrameView
function ns.NewTrackerFrame(block)
	local backdrop = block:CreateTexture(nil, "BACKGROUND")
	backdrop:SetPoint("TOPLEFT", -FRAME_PAD, FRAME_PAD)
	backdrop:SetPoint("BOTTOMRIGHT", FRAME_PAD, -FRAME_PAD)
	local outline = ns.BoardOutline(block, -FRAME_PAD)
	local border = outline.edges
	local seal = block:CreateTexture(nil, "OVERLAY")
	seal:SetTexture(ns.BOARD_TEXTURES.disc)
	seal:SetSize(SEAL_SIZE, SEAL_SIZE)
	seal:SetPoint("CENTER", block, "TOPLEFT", -FRAME_PAD + 2, FRAME_PAD - 2)
	---@type HuntsTrackerFrameView
	local view = { backdrop = backdrop, border = border, seal = seal, SetFrame = function() end }
	function view.SetFrame(_, look)
		backdrop:SetShown(look ~= nil)
		if look then
			outline:Solid(look.border, 1, look.borderSize)
		else
			outline:Hide()
		end
		seal:SetShown(look ~= nil and look.seal ~= nil)
		if look then
			backdrop:SetTexture(look.backdrop)
			backdrop:SetVertexColor(look.tint[1], look.tint[2], look.tint[3])
			backdrop:SetAlpha(look.alpha)
			if look.seal then
				seal:SetVertexColor(look.seal[1], look.seal[2], look.seal[3])
			end
		end
	end
	view:SetFrame(nil)
	return view
end

--- The tracker block's sizes (HNT-R76): the native block's width, its header, each Hunt's two lines and the room
--- below the last; and the header's collapse marks, minus while expanded and plus while collapsed, as the client's own
--- collapsible lists.
ns.TRACKER_BLOCK = {
	width = 220,
	headerHeight = 18,
	lineHeight = 14,
	huntHeight = 2 * 14 + 2,
	dotSize = 8,
	pad = 4,
	expandedMark = "Interface\\Buttons\\UI-MinusButton-Up",
	collapsedMark = "Interface\\Buttons\\UI-PlusButton-Up",
}
local BLOCK = ns.TRACKER_BLOCK
local WIDTH, HEADER_HEIGHT, LINE_HEIGHT, DOT_SIZE = BLOCK.width, BLOCK.headerHeight, BLOCK.lineHeight, BLOCK.dotSize
local HUNT_HEIGHT = BLOCK.huntHeight

--- The tracker's widgets, for its draws (and specs that read them).
---@class HuntsTrackerView
---@field frame Frame            -- the block Core docks
---@field look HuntsTrackerFrameView   -- the tracker frame it wears (HNT-R79)
---@field header Button          -- collapses and expands it (HNT-R77)
---@field title FontString       -- "Hunts"
---@field mark Texture           -- the collapse mark
---@field lines HuntsTrackerLineButton[]   -- one per shown Hunt, ns.TRACKER_SHOWN of them
---@field more HuntsTrackerMoreButton   -- "+N more", opens the board (HNT-R77)
---@field empty FontString       -- "Pin a Hunt to keep it here."
---@field words { text: FontString, font: string }[]   -- every word, for the frame's ink
---@field wearing string?      -- a tracker frame's good ID the dev tour dresses it in (adapter/Tour.lua); nil: the
--- equipped one

---@class HuntsTrackerLineButton: Button
---@field dot BoardDotView
---@field first FontString
---@field second FontString
---@field huntID string?

---@class HuntsTrackerMoreButton: Button
---@field text FontString

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

-- A font string on `parent` in the native font object `font`, listed in `words` for the frame's ink.
---@param parent Frame
---@param font string
---@param words { text: FontString, font: string }[]
---@return FontString
local function word(parent, font, words)
	local text = parent:CreateFontString(nil, "OVERLAY", font)
	text:SetJustifyH("LEFT")
	text:SetWordWrap(false)
	words[#words + 1] = { text = text, font = font }
	return text
end

-- The header: "Hunts" in the native header font over a faint gold rule, with the collapse mark at its right.
---@param block Frame
---@param words { text: FontString, font: string }[]
---@return Button header
---@return FontString title
---@return Texture mark
local function buildHeader(block, words)
	local header = CreateFrame("Button", nil, block)
	header:SetPoint("TOPLEFT")
	header:SetPoint("TOPRIGHT")
	header:SetHeight(HEADER_HEIGHT)
	local title = word(header, "GameFontNormal", words)
	title:SetPoint("LEFT", 2, 0)
	title:SetText(ns.L.TITLE)
	local mark = header:CreateTexture(nil, "ARTWORK")
	mark:SetSize(14, 14)
	mark:SetPoint("RIGHT", -2, 0)
	local rule = header:CreateTexture(nil, "ARTWORK")
	rule:SetColorTexture(1, 0.82, 0, 0.35) -- the native header's faint gold rule
	rule:SetPoint("BOTTOMLEFT", 0, 1)
	rule:SetPoint("BOTTOMRIGHT", 0, 1)
	rule:SetHeight(1)
	passDrags(header, block)
	return header, title, mark
end

-- Hunt `i`'s two lines, a button (the tracker opens the board on its Hunt, HNT-R77): its dot, then the name and
-- label, then the target line and progress under them.
---@param block Frame
---@param i integer
---@param words { text: FontString, font: string }[]
---@return HuntsTrackerLineButton
local function buildLine(block, i, words)
	local line = CreateFrame("Button", nil, block) --[[@as HuntsTrackerLineButton]]
	line:SetPoint("TOPLEFT", 0, -HEADER_HEIGHT - (i - 1) * HUNT_HEIGHT)
	line:SetSize(WIDTH, HUNT_HEIGHT)
	line.dot = ns.NewBoardDot(line, DOT_SIZE)
	line.dot:SetPoint("TOPLEFT", 2, -3)
	line.first = word(line, "GameFontHighlightSmall", words)
	line.first:SetPoint("TOPLEFT", DOT_SIZE + 6, 0)
	line.first:SetPoint("TOPRIGHT", 0, 0)
	line.second = word(line, "GameFontDisableSmall", words)
	line.second:SetPoint("TOPLEFT", DOT_SIZE + 12, -LINE_HEIGHT)
	line.second:SetPoint("TOPRIGHT", 0, -LINE_HEIGHT)
	line:SetScript("OnClick", function(self)
		ns.OpenBoard(self.huntID)
	end)
	passDrags(line, block)
	line:Hide()
	return line
end

--- The tracker's block on `parent` (HNT-R76): the header, the Hunts' line buttons, "+N more" and the empty line, all
--- hidden until drawn, in a tracker frame. The tracker (adapter/Tracker.lua) wires its clicks; the Curio Shop's sample
--- (HNT-R121) draws two fixed Hunts in one.
---@param parent Frame
---@return HuntsTrackerView
function ns.NewTrackerBlock(parent)
	local block = CreateFrame("Frame", nil, parent)
	block:SetSize(WIDTH, HEADER_HEIGHT)
	local words = {}
	local look = ns.NewTrackerFrame(block)
	local header, title, mark = buildHeader(block, words)
	local lines = {}
	for i = 1, ns.TRACKER_SHOWN do
		lines[i] = buildLine(block, i, words)
	end

	local more = CreateFrame("Button", nil, block) --[[@as HuntsTrackerMoreButton]]
	more:SetSize(WIDTH, LINE_HEIGHT)
	more.text = word(more, "GameFontNormalSmall", words)
	more.text:SetPoint("LEFT", DOT_SIZE + 6, 0)
	more:SetScript("OnClick", function()
		ns.OpenBoard()
	end)
	passDrags(more, block)
	more:Hide()

	local empty = word(block, "GameFontDisableSmall", words)
	empty:SetText(ns.L.TRACKER_EMPTY)
	empty:Hide()
	---@type HuntsTrackerView
	return {
		frame = block,
		look = look,
		header = header,
		title = title,
		mark = mark,
		lines = lines,
		more = more,
		empty = empty,
		words = words,
	}
end

--- A sample Hunts tracker on a stage (HNT-R121): the tracker's own block, its "Hunts" header and two fixed Hunts, in
--- a tracker frame.
---@class HuntsSampleTracker: Frame
---@field frame HuntsTrackerFrameView
---@field words { text: FontString, font: string }[] -- every word, with its native font object

-- Builds a stage's sample tracker: the tracker's block, expanded, with a Hunt Now and a Hunt On demand.
---@param stage Frame
---@return HuntsSampleTracker
local function buildSampleTracker(stage)
	local L = ns.L
	local view = ns.NewTrackerBlock(stage)
	local tracker = view.frame --[[@as HuntsSampleTracker]]
	tracker.frame, tracker.words = view.look, view.words
	tracker:SetPoint("TOP", 0, -24)
	view.mark:SetTexture(BLOCK.expandedMark)
	for i, line in ipairs({ { L.PREVIEW_TRACKER_LINE_1, "now" }, { L.PREVIEW_TRACKER_LINE_2, "onDemand" } }) do
		local hunt = view.lines[i]
		hunt.dot:SetGroup(line[2])
		hunt.first:SetText(line[1])
		hunt.second:Hide()
		hunt:Show()
	end
	tracker:SetHeight(HEADER_HEIGHT + 2 * HUNT_HEIGHT + BLOCK.pad)
	return tracker
end

--- Sets the words of a tracker on `look`'s backdrop: in its ink, or back in their native font objects' colours.
---@param words { text: FontString, font: string }[]
---@param look HuntsTrackerFrameLook?
function ns.InkTrackerWords(words, look)
	local ink = look and look.ink
	for _, entry in ipairs(words) do
		if ink then
			entry.text:SetTextColor(ink[1], ink[2], ink[3])
		else
			entry.text:SetFontObject(entry.font)
		end
	end
end

--- Draws tracker frame `goodID`'s sample tracker on `stage` (HNT-R121), in that frame.
---@param stage Frame
---@param goodID string
local function previewTrackerFrame(stage, goodID)
	local tracker = drawn[stage] --[[@as HuntsSampleTracker?]]
	if not tracker then
		tracker = buildSampleTracker(stage)
		drawn[stage] = tracker
	end
	local look = ns.TRACKER_FRAMES[goodID]
	tracker.frame:SetFrame(look)
	ns.InkTrackerWords(tracker.words, look)
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

--- Dresses the board's leather in the equipped notebook cover (HNT-R70), open or not.
local function wearCover()
	ns.board:SetCover(ns.CoverLook(Pagle.GetEquipped(ns.COVER_SLOT)))
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
	Pagle.RegisterCallback(OWNER, "ModulesChanged", wearCover)
	Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
		if slot == ns.COVER_SLOT then
			wearCover()
		end
	end)
end
