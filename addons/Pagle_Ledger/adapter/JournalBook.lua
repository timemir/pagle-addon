if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's book shell (ledger.md › UI): the leather binding (its tiled grain under the rounded nine-slice
-- band), two parchment pages with their gutters at the spine and slightly rounded outer corners, the gilt strip with
-- the breadcrumbs and the search slip, the wax close button and the brass plate; and a binding's look over them
-- (LED-R110, LED-R112). The kit's Book.lua and Bindings.lua (PagleArtLedger), forked from the books kit, drawn on
-- Core's book textures (Pagle/media/books) and the Ledger's binding leathers. adapter/Journal.lua lays its pages out.

local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB

--- The book's measures (the kit's Ledger.lua): 920 × 600, the leather at the sides and under the pages, and the
--- strip above them for the crumbs and the search slip.
ns.JOURNAL_BOOK = {
	width = 920,
	height = 600,
	side = 18,
	strip = 38,
	foot = 16,
	-- the book's whole extent, the wax close and the brass plate hanging over its edges included (the kit's fit)
	extentW = 950,
	extentH = 640,
}
local BOOK = ns.JOURNAL_BOOK
--- A page's size: half the room between the leather's sides, and from the strip to the foot.
ns.JOURNAL_PAGE_W = (BOOK.width - 2 * BOOK.side) / 2
ns.JOURNAL_PAGE_H = BOOK.height - BOOK.strip - BOOK.foot

-- The band's shown size (32 texels), how far in the tiled grain starts, and its repeat (Leather is 256 texels).
local BAND, FILL_INSET, LEATHER_TILE = 16, 7, 128
-- The spine's gutter shade's width, and a page's rounded corner's radius.
local GUTTER_W, CORNER = 40, 6
local CORNER_MASKS = {
	TOPLEFT = "Interface\\AddOns\\Pagle\\media\\books\\CornerTL",
	TOPRIGHT = "Interface\\AddOns\\Pagle\\media\\books\\CornerTR",
	BOTTOMLEFT = "Interface\\AddOns\\Pagle\\media\\books\\CornerBL",
	BOTTOMRIGHT = "Interface\\AddOns\\Pagle\\media\\books\\CornerBR",
}
-- The search slip (the kit's 252 × 23), centred in the strip between the band's inner edge and the pages.
local SEARCH_W, SEARCH_H = 252, 23
local STRIP_MIDDLE = (FILL_INSET + BOOK.strip) / 2

---@class LedgerJournalPaper: Frame
---@field parchment Texture
---@field gutter Texture

---@class LedgerJournalPlateView: Frame
---@field label FontString
---@field slices Texture[]

---@class LedgerJournalShell: Frame
---@field leatherFill Texture
---@field vignette Texture
---@field bandFrame Frame
---@field band Texture[]
---@field pagesFrame Frame
---@field papers table<"left"|"right", LedgerJournalPaper>
---@field strip Frame
---@field crumbs Frame
---@field search EditBox
---@field searchHint FontString
---@field close Button
---@field plate LedgerJournalPlateView
---@field binding string?
---@field leatherTint number[]   -- the leather's tint as last drawn (LED-R112)

-- The leather: the tiled grain shading toward its foot, the vignette over it, and the band on a frame of its own
-- above the pages' level, so nothing on the leather pokes over it.
---@param frame LedgerJournalShell
local function buildLeather(frame)
	local fill = ns.JournalCrisp(frame:CreateTexture(nil, "BACKGROUND", nil, 0))
	fill:SetTexture(ns.JOURNAL_FILES.leather, "REPEAT", "REPEAT")
	fill:SetPoint("TOPLEFT", FILL_INSET, -FILL_INSET)
	fill:SetPoint("BOTTOMRIGHT", -FILL_INSET, FILL_INSET)
	frame.leatherFill = fill
	frame.vignette = ns.JournalPiece(frame, "Book", "vignette", "BACKGROUND", 1, { 1, 1, 126, 126 })
	frame.vignette:SetAllPoints(fill)
	local bandFrame = CreateFrame("Frame", nil, frame)
	bandFrame:SetAllPoints()
	bandFrame:SetFrameLevel(frame:GetFrameLevel() + 6)
	frame.bandFrame = bandFrame
	-- the nine slices of the 96-texel binding sprite: 32-texel corners, the edges stretched from a 2-texel slice
	local function piece(sx, sy, sw, sh)
		return ns.JournalPiece(bandFrame, "Book", "binding", "BORDER", 0, { sx, sy, sw, sh })
	end
	local tl, tr, bl, br = piece(0, 0, 32, 32), piece(64, 0, 32, 32), piece(0, 64, 32, 32), piece(64, 64, 32, 32)
	local top, bottom = piece(47, 0, 2, 32), piece(47, 64, 2, 32)
	local left, right = piece(0, 47, 32, 2), piece(64, 47, 32, 2)
	for _, corner in ipairs({ tl, tr, bl, br }) do
		corner:SetSize(BAND, BAND)
	end
	tl:SetPoint("TOPLEFT")
	tr:SetPoint("TOPRIGHT")
	bl:SetPoint("BOTTOMLEFT")
	br:SetPoint("BOTTOMRIGHT")
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
	top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
	bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
	left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
	right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
	frame.band = { tl, tr, bl, br, top, bottom, left, right }
end

-- One page's paper: the parchment (the right page's mirrored, so the two don't match), its outer corners slightly
-- rounded, and the gutter's shade at the spine. It takes the mouse, so a click on the paper goes no further.
---@param frame LedgerJournalShell
---@param side "left"|"right"
---@return LedgerJournalPaper
local function buildPaper(frame, side)
	local paper = CreateFrame("Frame", nil, frame.pagesFrame) --[[@as LedgerJournalPaper]]
	paper:SetSize(ns.JOURNAL_PAGE_W, ns.JOURNAL_PAGE_H)
	paper:SetPoint("TOPLEFT", side == "left" and 0 or ns.JOURNAL_PAGE_W, 0)
	paper:EnableMouse(true)
	local parchment = ns.JournalCrisp(paper:CreateTexture(nil, "BACKGROUND"))
	parchment:SetTexture(ns.JOURNAL_FILES.parchment)
	parchment:SetAllPoints()
	if side == "right" then
		parchment:SetTexCoord(1, 0, 0, 1)
	end
	for _, corner in ipairs(side == "left" and { "TOPLEFT", "BOTTOMLEFT" } or { "TOPRIGHT", "BOTTOMRIGHT" }) do
		local mask = paper:CreateMaskTexture()
		mask:SetTexture(CORNER_MASKS[corner], "CLAMPTOWHITE", "CLAMPTOWHITE")
		mask:SetSize(CORNER, CORNER)
		mask:SetPoint(corner, parchment, corner)
		parchment:AddMaskTexture(mask)
	end
	paper.parchment = parchment
	local gutter = ns.JournalPiece(paper, "Book", "gutter", "BORDER", 0, { 1, 1, 62, 6 })
	gutter:SetWidth(GUTTER_W)
	if side == "left" then
		gutter:SetPoint("TOPRIGHT")
		gutter:SetPoint("BOTTOMRIGHT")
	else
		local l, r, t, b = ns.JournalCoords("Book", "gutter", { 1, 1, 62, 6 })
		gutter:SetTexCoord(r, l, t, b)
		gutter:SetPoint("TOPLEFT")
		gutter:SetPoint("BOTTOMLEFT")
	end
	paper.gutter = gutter
	return paper
end

-- The search slip on the strip's right: a parchment field in a leather trim, its magnifier, and the placeholder in
-- italic until something is typed (LED-R148).
---@param frame LedgerJournalShell
local function buildSearch(frame)
	local search = CreateFrame("EditBox", nil, frame.strip) --[[@as EditBox]]
	search:SetSize(SEARCH_W, SEARCH_H)
	search:SetPoint("TOPRIGHT", frame.strip, "TOPRIGHT", 0, -(STRIP_MIDDLE - SEARCH_H / 2))
	search:SetAutoFocus(false)
	search:SetFontObject(ns.JournalFont("print", 14))
	search:SetTextColor(rgb(INK.body))
	search:SetTextInsets(26, 8, 0, 0)
	local trim = ns.JournalTint(search, INK.trim, 1, "BACKGROUND", 0)
	trim:SetAllPoints()
	local field = ns.JournalTint(search, INK.field, 1, "BACKGROUND", 1)
	field:SetPoint("TOPLEFT", 1, -1)
	field:SetPoint("BOTTOMRIGHT", -1, 1)
	local glass = ns.JournalSprite(search, "Parts", "glass", "ARTWORK")
	glass:SetPoint("LEFT", search, "LEFT", 9 - glass.box[1], 0)
	frame.searchHint =
		ns.JournalLabel(search, "italic", 14, INK.noteLight, ns.L.JOURNAL_SEARCH_HINT, { layer = "ARTWORK" })
	frame.searchHint:SetPoint("LEFT", 26, 0)
	search:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)
	frame.search = search
end

-- The brass plate (LED-R149): a three-slice of the plate sprite, its words in Marcellus, over the leather's corner.
---@param frame LedgerJournalShell
local function buildPlate(frame)
	local plate = CreateFrame("Frame", nil, frame) --[[@as LedgerJournalPlateView]]
	plate:SetHeight(32)
	local left = ns.JournalPiece(plate, "Book", "plate", "ARTWORK", 0, { 0, 0, 16, 64 })
	local middle = ns.JournalPiece(plate, "Book", "plate", "ARTWORK", 0, { 63, 0, 2, 64 })
	local right = ns.JournalPiece(plate, "Book", "plate", "ARTWORK", 0, { 112, 0, 16, 64 })
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(8)
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(8)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	plate.slices = { left, middle, right }
	plate.label = ns.JournalLabel(plate, "gilt", 12, INK.brass, "")
	plate.label:SetPoint("CENTER", 0, 1)
	plate:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -12, -14)
	plate:SetFrameLevel(frame:GetFrameLevel() + 10)
	plate:Hide()
	frame.plate = plate
end

--- Sets the brass plate's words, sized to them; hidden with none (LED-R149).
---@param frame LedgerJournalShell
---@param text string?
function ns.SetJournalPlate(frame, text)
	local plate = frame.plate
	if not text or text == "" then
		plate:Hide()
		return
	end
	plate.label:SetText(text)
	plate:SetWidth(math.ceil(plate.label:GetStringWidth()) + 22)
	plate:Show()
end

-- The wax close button: a round seal of red wax with a cross, pressed when clicked, glowing under the mouse.
---@param frame LedgerJournalShell
local function buildClose(frame)
	local close = CreateFrame("Button", nil, frame) --[[@as Button]]
	close:SetSize(26, 26)
	local normal = ns.JournalPiece(close, "Book", "close", "ARTWORK")
	normal:SetAllPoints()
	local pushed = ns.JournalPiece(close, "Book", "close-pushed", "ARTWORK")
	pushed:SetAllPoints()
	pushed:Hide()
	local glow = ns.JournalPiece(close, "Book", "close-highlight", "HIGHLIGHT")
	glow:SetAllPoints()
	glow:SetBlendMode("ADD")
	glow:Hide()
	close:SetScript("OnMouseDown", function()
		pushed:Show()
		normal:Hide()
	end)
	close:SetScript("OnMouseUp", function()
		pushed:Hide()
		normal:Show()
	end)
	close:SetScript("OnEnter", function()
		glow:Show()
	end)
	close:SetScript("OnLeave", function()
		glow:Hide()
	end)
	close:SetPoint("CENTER", frame, "TOPRIGHT", -3, -3)
	close:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.close = close
end

--- Builds the shell on `frame` (sized 920 × 600): the leather and its band, the two papers on `frame.pagesFrame`, the
--- strip with the crumbs' row and the search slip, the brass plate and the wax close button.
---@param frame LedgerJournalShell
function ns.BuildJournalShell(frame)
	frame:SetSize(BOOK.width, BOOK.height)
	buildLeather(frame)
	frame.pagesFrame = CreateFrame("Frame", nil, frame)
	frame.pagesFrame:SetPoint("TOPLEFT", BOOK.side, -BOOK.strip)
	frame.pagesFrame:SetPoint("BOTTOMRIGHT", -BOOK.side, BOOK.foot)
	frame.pagesFrame:SetSize(BOOK.width - 2 * BOOK.side, ns.JOURNAL_PAGE_H)
	frame.papers = { left = buildPaper(frame, "left"), right = buildPaper(frame, "right") }
	frame.strip = CreateFrame("Frame", nil, frame)
	frame.strip:SetPoint("TOPLEFT", BOOK.side + 6, 0)
	frame.strip:SetSize(BOOK.width - 2 * BOOK.side - 12, BOOK.strip)
	frame.crumbs = CreateFrame("Frame", nil, frame.strip)
	frame.crumbs:SetPoint("TOPLEFT", 0, -(STRIP_MIDDLE - 10))
	frame.crumbs:SetSize(BOOK.width - 2 * BOOK.side - 12 - SEARCH_W - 24, 20)
	buildSearch(frame)
	buildPlate(frame)
	buildClose(frame)
end

-- ---------------------------------------------------------------- a binding's look (LED-R110, LED-R112)

--- Draws the book in binding `look` (logic/Bindings.lua's ns.BindingLook): the leather's texture and tint (a vertex
--- tint over the grey leather, or Birch Bark's and Buckram's own grain), the band toward the binding's hue, the gilt
--- of the crumbs and fleurons, a silver plate for a silver gilt, and the page paper cooled by a tenth of the
--- binding's hue (the kit's Bindings.lua).
---@param frame LedgerJournalShell
---@param look LedgerBindingLook
function ns.TintJournalShell(frame, look)
	local fill = frame.leatherFill
	fill:SetTexture(ns.JOURNAL_FILES[look.texture], "REPEAT", "REPEAT")
	local tile = look.tile or LEATHER_TILE
	local w, h = BOOK.width - 2 * FILL_INSET, BOOK.height - 2 * FILL_INSET
	fill:SetTexCoord(0, w / tile, 0, h / tile)
	local t = look.tint or { 1, 1, 1 }
	fill:SetGradient("VERTICAL", CreateColor(t[1] * 0.8, t[2] * 0.8, t[3] * 0.8, 1), CreateColor(t[1], t[2], t[3], 1))
	frame.leatherTint = t
	for _, piece in ipairs(frame.band) do
		if look.band then
			piece:SetDesaturated(true)
			piece:SetVertexColor(look.band[1], look.band[2], look.band[3])
		else
			piece:SetDesaturated(false)
			piece:SetVertexColor(1, 1, 1)
		end
	end
	for _, slice in ipairs(frame.plate.slices) do
		slice:SetDesaturated(look.silver)
		local lift = look.silver and 1.1 or 1
		slice:SetVertexColor(lift, lift, look.silver and 1.15 or 1)
	end
	for _, paper in pairs(frame.papers) do
		paper.parchment:SetVertexColor(look.paperTint[1], look.paperTint[2], look.paperTint[3])
	end
end
