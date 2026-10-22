---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The book shell (core/book.md, ADR 0016): Pagle.NewBook, which the Fish Journal, the Stats book, the Hunts board and
-- the Field guide are built on. It was the Stats book's shell (Pagle_Stats/adapter/Book.lua, BookWidgets.lua and
-- BookMotion.lua), drawn here on Core's media/books (data/GuideArt.lua's Book and BookParts atlases) through Core's art
-- helpers (adapter/Art.lua), with the binding Core's renderer (Pagle.NewBookBinding, ADR 0015). logic/Book.lua holds its
-- router and measures; this file draws it. A book's handle is made at once and its frame at its first opening
-- (BOOK-R1). FakePagle loads this same file on a Module's client fake (spec/support/fake_pagle.lua).

local SHELL = ns.BOOK_SHELL
local RIBBON = ns.BOOK_RIBBON
local rgb = ns.Rgb

-- The shell's inks (the books kit's design-system colours).
local INKS = {
	giltBright = rgb("FFF4C8"), -- a crumb under the mouse
	strip = rgb("C9B27A"), -- the strip's words at its right ("{n} of {m}")
	back = rgb("7A3A10"), -- « back
	backHover = rgb("9A2A1A"), -- under the mouse
	hand = rgb("23407A"), -- the notice, in the hand
	plate = rgb("2A1A04"), -- the brass nameplate's words
	wax = rgb("F4DFA8"), -- the gilt "?" pressed into the wax
	ribbon = rgb("EFD286"), -- a ribbon's words
	ribbonOn = rgb("FFF0BC"), -- the chosen ribbon's
	tip = rgb("E6D8B8"), -- the "?"'s tooltip words
	count = rgb("E8C96A"), -- a ribbon's count under its name, in the hand
}
-- The kit's fleuron gilt (#e8c96a), which a binding's gilt tints it toward.
local FLEURON_GILT = { 0.91, 0.79, 0.42 }
-- Where the binding's tiled grain starts, under its band (the renderer's inset): the strip sits midway to the pages.
local FILL_INSET = 7
-- The spine's gutter shade, a page's rounded outer corners and their masks.
local GUTTER_WIDTH, CORNER_RADIUS = 40, 6
local CORNER_MASKS = {
	TOPLEFT = "Interface\\AddOns\\Pagle\\media\\books\\CornerTL",
	TOPRIGHT = "Interface\\AddOns\\Pagle\\media\\books\\CornerTR",
	BOTTOMLEFT = "Interface\\AddOns\\Pagle\\media\\books\\CornerBL",
	BOTTOMRIGHT = "Interface\\AddOns\\Pagle\\media\\books\\CornerBR",
}
-- The wax buttons' size, the gap between them, and the "?"'s shade while pressed.
local WAX, WAX_GAP, WAX_PRESSED = 26, 4, 0.78
-- What covers the binding (its band six levels up, its features seven): ten levels up.
local OVER = 10
-- The plate's end caps and the room its words leave; a silver plate's lift and blue.
local PLATE_CAP, PLATE_ROOM, SILVER_LIFT, SILVER_BLUE = 8, 22, 1.1, 1.15
-- The turn's fold: its shade at its darkest, its cast shadow's width and darkness, the edge's width and light, and
-- its levels above the book's.
local SHADE, CAST_WIDTH, CAST_DARK, EDGE_WIDTH, EDGE_LIGHT, FOLD_LEVELS = 0.28, 26, 0.32, 1.5, 0.55, 40
local TURN_LIFT, TURN_LAND = 0.22, 0.28
-- Where a ribbon's words sit above its swallowtail end: its name, its name over a count, and the count (BOOK-R19).
local RIBBON_LABEL_Y, RIBBON_LABEL_OVER_Y, RIBBON_COUNT_Y = 31, 38, 17

-- The ids books have taken (BOOK-R1).
local taken = {}

---@param id integer
local function sound(id)
	PlaySound(id, "SFX")
end

---@return boolean
local function motionOn()
	return Pagle.IsAnimationsOn() ~= false
end

-- Each movable book's saved position, by id (BOOK-R5): PagleDB.profile.books.
---@return table<string, table>?
local function positions()
	local db = ns.host and ns.host.db()
	local profile = db and db.profile
	if not profile then
		return nil
	end
	profile.books = profile.books or {}
	return profile.books
end

---@param parent Frame
---@param face PagleArtFace
---@param size number
---@param ink number[]
---@param shadow boolean?
---@return FontString
local function text(parent, face, size, ink, shadow)
	local fontString = parent:CreateFontString(nil, "OVERLAY")
	fontString:SetFontObject(ns.ArtFaceFont(face, size, shadow))
	fontString:SetTextColor(ink[1], ink[2], ink[3])
	fontString:SetJustifyH("LEFT")
	return fontString
end

-- Shows `lines` in GameTooltip over `owner`: the first as its heading, one line each (BOOK-R14, BOOK-R19).
---@param owner Frame
---@param lines string[]?
local function showTooltip(owner, lines)
	if not lines or #lines == 0 then
		return
	end
	GameTooltip:SetOwner(owner, "ANCHOR_TOP")
	GameTooltip:SetText(lines[1])
	for i = 2, #lines do
		GameTooltip:AddLine(lines[i])
	end
	GameTooltip:Show()
end

---@param owner Frame
local function hideTooltip(owner)
	if GameTooltip:IsOwned(owner) then
		GameTooltip:Hide()
	end
end

-- Lays `fontString` on one line, no wider than `room`.
---@param fontString FontString
---@param room number
local function bound(fontString, room)
	fontString:SetWordWrap(false)
	fontString:SetWidth(0)
	fontString:SetWidth(math.max(1, math.min(fontString:GetStringWidth() + 1, room)))
end

-- Shows texels [x0, x0 + w] × [y0, y0 + h] of `atlas` in `texture`.
local function cut(texture, atlas, x0, y0, w, h)
	texture:SetTexture(atlas.file)
	texture:SetTexCoord(x0 / atlas.width, (x0 + w) / atlas.width, y0 / atlas.height, (y0 + h) / atlas.height)
end

---------------------------------------------------------------------------------------------------------------------
-- The parts
---------------------------------------------------------------------------------------------------------------------

--- A parchment page (BOOK-R11): the paper, mirrored on a right page, its outer corners rounded, the gutter at its spine.
---@class PagleBookParchment
---@field paper Texture
---@field gutter Texture

---@param frame Frame
---@param spine "LEFT"|"RIGHT"
---@return PagleBookParchment
local function newParchment(frame, spine)
	local paper = ns.ArtCrisp(frame:CreateTexture(nil, "BACKGROUND"))
	paper:SetTexture(ns.BOOK_FILES.parchment)
	paper:SetAllPoints()
	if spine == "LEFT" then
		paper:SetTexCoord(1, 0, 0, 1)
	end
	for _, corner in ipairs(spine == "RIGHT" and { "TOPLEFT", "BOTTOMLEFT" } or { "TOPRIGHT", "BOTTOMRIGHT" }) do
		local mask = frame:CreateMaskTexture()
		mask:SetTexture(CORNER_MASKS[corner], "CLAMPTOWHITE", "CLAMPTOWHITE")
		mask:SetSize(CORNER_RADIUS, CORNER_RADIUS)
		mask:SetPoint(corner, paper, corner)
		paper:AddMaskTexture(mask)
	end
	local atlas = ns.ATLASES.Book
	local sprite = atlas.sprites.gutter
	local gutter = ns.ArtCrisp(frame:CreateTexture(nil, "BORDER"))
	gutter:SetTexture(atlas.file)
	local left, right = (sprite.x + 1) / atlas.width, (sprite.x + sprite.w - 1) / atlas.width
	local top, bottom = (sprite.y + 1) / atlas.height, (sprite.y + sprite.h - 1) / atlas.height
	if spine == "LEFT" then
		gutter:SetTexCoord(right, left, top, bottom)
	else
		gutter:SetTexCoord(left, right, top, bottom)
	end
	gutter:SetWidth(GUTTER_WIDTH)
	gutter:SetPoint("TOP" .. spine)
	gutter:SetPoint("BOTTOM" .. spine)
	return { paper = paper, gutter = gutter }
end

--- The wax close (BOOK-R15).
---@class PagleBookClose: Button
---@field normal Texture
---@field pushed Texture
---@field glow Texture

---@param parent Frame
---@return PagleBookClose
local function newClose(parent)
	local close = CreateFrame("Button", nil, parent) --[[@as PagleBookClose]]
	close:SetSize(WAX, WAX)
	local function layer(name, drawLayer, sublevel)
		local texture = ns.ArtSprite(close, "Book", name, drawLayer, sublevel)
		texture:SetAllPoints()
		return texture
	end
	close.normal = layer("close", "ARTWORK", 0)
	close.pushed = layer("close-pushed", "ARTWORK", 1)
	close.pushed:Hide()
	close.glow = layer("close-highlight", "HIGHLIGHT", 0)
	close.glow:SetBlendMode("ADD")
	close:SetScript("OnMouseDown", function(self)
		self.pushed:Show()
	end)
	close:SetScript("OnMouseUp", function(self)
		self.pushed:Hide()
	end)
	return close
end

--- The "?" beside the close (BOOK-R15): the plain wax seal with a gilt "?", and its tooltip under it.
---@class PagleBookHelp: Button
---@field wax Texture
---@field glow Texture
---@field label FontString
---@field tip Frame|{ text: FontString }

---@param parent Frame
---@param tooltip string
---@return PagleBookHelp
local function newHelp(parent, tooltip)
	local help = CreateFrame("Button", nil, parent) --[[@as PagleBookHelp]]
	help:SetSize(WAX, WAX)
	help.wax = ns.ArtSprite(help, "Book", "seal", "ARTWORK", 0)
	help.wax:SetAllPoints()
	help.label = text(help, "gilt", 17, INKS.wax, true)
	help.label:SetJustifyH("CENTER")
	help.label:SetPoint("CENTER", 0, 1)
	help.label:SetText("?")
	help.glow = ns.ArtSprite(help, "Book", "close-highlight", "HIGHLIGHT", 0)
	help.glow:SetAllPoints()
	help.glow:SetBlendMode("ADD")
	local tip = CreateFrame("Frame", nil, parent)
	local slip = tip:CreateTexture(nil, "BACKGROUND")
	slip:SetColorTexture(0.12, 0.08, 0.05, 0.94)
	slip:SetAllPoints()
	tip.text = text(tip, "print", 13.5, INKS.tip)
	tip.text:SetWordWrap(false)
	tip.text:SetPoint("LEFT", 12, 0)
	tip.text:SetText(tooltip)
	tip:Hide()
	help.tip = tip
	help:SetScript("OnMouseDown", function(self)
		self.wax:SetVertexColor(WAX_PRESSED, WAX_PRESSED, WAX_PRESSED)
	end)
	help:SetScript("OnMouseUp", function(self)
		self.wax:SetVertexColor(1, 1, 1)
	end)
	help:SetScript("OnEnter", function(self)
		tip:SetSize(math.ceil(tip.text:GetStringWidth()) + 24, 30)
		tip:ClearAllPoints()
		tip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, -4)
		tip:SetFrameLevel(self:GetFrameLevel() + 20)
		tip:Show()
	end)
	help:SetScript("OnLeave", function()
		tip:Hide()
	end)
	return help
end

--- The brass nameplate (BOOK-R14).
---@class PagleBookPlate: Frame
---@field brass PagleThreeSlice
---@field label FontString
---@field silver boolean
---@field tooltip string[]?

---@param plate PagleBookPlate
local function tonePlate(plate)
	if not plate.brass.left then
		return
	end
	for _, slice in ipairs({ plate.brass.left, plate.brass.middle, plate.brass.right }) do
		slice:SetDesaturated(plate.silver)
		if plate.silver then
			slice:SetVertexColor(SILVER_LIFT, SILVER_LIFT, SILVER_BLUE)
		else
			slice:SetVertexColor(1, 1, 1)
		end
	end
end

---@param plate PagleBookPlate
---@param words string
---@param tooltip string[]?
local function writePlate(plate, words, tooltip)
	plate.tooltip = tooltip
	plate:EnableMouse(tooltip ~= nil)
	plate.label:SetText(words)
	local width = math.ceil(plate.label:GetStringWidth()) + PLATE_ROOM
	ns.SetThreeSlice(plate.brass, "Book", "plate", width, PLATE_CAP, "ARTWORK")
	plate:SetSize(width, plate.brass:GetHeight())
	tonePlate(plate)
end

---@param parent Frame
---@return PagleBookPlate
local function newPlate(parent)
	local plate = CreateFrame("Frame", nil, parent) --[[@as PagleBookPlate]]
	plate.brass = CreateFrame("Frame", nil, plate) --[[@as PagleThreeSlice]]
	plate.brass:SetPoint("TOPLEFT")
	plate.label = text(plate.brass, "gilt", 12, INKS.plate)
	plate.label:SetPoint("CENTER", plate, "CENTER", 0, 1)
	plate.silver = false
	plate:SetScript("OnEnter", function(self)
		showTooltip(self, self.tooltip)
	end)
	plate:SetScript("OnLeave", function(self)
		hideTooltip(self)
	end)
	return plate
end

--- A grosgrain ribbon (BOOK-R17).
---@class PagleBookRibbonView: Button
---@field body Texture
---@field stitch Texture
---@field label FontString
---@field chosen boolean
---@field hover boolean
---@field color number[]
---@field length number
---@field id string?
---@field count FontString
---@field tooltip string[]?

-- Shows the bottom `length` units of BookParts sprite `name` in `texture`, the ribbon's width across.
local function hang(texture, ribbon, name, length)
	local atlas = ns.ATLASES.BookParts
	local sprite = atlas.sprites[name]
	local box = sprite.box
	local k = RIBBON.width / box[3]
	local dropped = (box[4] - length) * atlas.scale
	cut(texture, atlas, sprite.x, sprite.y + dropped, sprite.w, sprite.h - dropped)
	texture:SetSize(sprite.w / atlas.scale * k, sprite.h / atlas.scale - box[4] + length)
	texture:ClearAllPoints()
	texture:SetPoint("TOPLEFT", ribbon, "TOPLEFT", -box[1] * k, 0)
end

---@param ribbon PagleBookRibbonView
---@param length number
local function hangRibbon(ribbon, length)
	ribbon.length = length
	ribbon:SetSize(RIBBON.width, length)
	hang(ribbon.body, ribbon, "ribbon", length)
	hang(ribbon.stitch, ribbon, "ribbon-stitch", length)
end

---@param ribbon PagleBookRibbonView
local function paintRibbon(ribbon)
	local lift = (ribbon.chosen or ribbon.hover) and RIBBON.lift or 1
	local color = ribbon.color
	ribbon.body:SetVertexColor(math.min(1, color[1] * lift), math.min(1, color[2] * lift), math.min(1, color[3] * lift))
	local ink = ribbon.chosen and INKS.ribbonOn or INKS.ribbon
	ribbon.label:SetTextColor(ink[1], ink[2], ink[3])
end

---@param parent Frame
---@return PagleBookRibbonView
local function newRibbon(parent)
	local ribbon = CreateFrame("Button", nil, parent) --[[@as PagleBookRibbonView]]
	ribbon.body = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK", nil, 0))
	ribbon.stitch = ns.ArtCrisp(ribbon:CreateTexture(nil, "ARTWORK", nil, 1))
	ribbon.label = text(ribbon, "gilt", 12, INKS.ribbon, true)
	ribbon.label:SetJustifyH("CENTER")
	ribbon.label:SetWordWrap(false)
	ribbon.label:SetPoint("BOTTOM", ribbon, "BOTTOM", 0, RIBBON_LABEL_Y)
	ribbon.count = text(ribbon, "hand", 15, INKS.count, true)
	ribbon.count:SetJustifyH("CENTER")
	ribbon.count:SetWordWrap(false)
	ribbon.count:SetPoint("BOTTOM", ribbon, "BOTTOM", 0, RIBBON_COUNT_Y)
	ribbon.count:Hide()
	ribbon.chosen, ribbon.hover, ribbon.color = false, false, { 1, 1, 1 }
	ribbon:SetScript("OnEnter", function(self)
		self.hover = true
		paintRibbon(self)
		showTooltip(self, self.tooltip)
	end)
	ribbon:SetScript("OnLeave", function(self)
		self.hover = false
		paintRibbon(self)
		hideTooltip(self)
	end)
	hangRibbon(ribbon, RIBBON.length)
	return ribbon
end

-- Sets a ribbon's words, colour and choice; a change of choice runs its length over 0.2 s when `animate`.
---@param ribbon PagleBookRibbonView
---@param data PagleBookRibbon
---@param chosen boolean
---@param animate boolean?
local function setRibbon(ribbon, data, chosen, animate)
	ribbon.id = data.id
	ribbon.tooltip = data.tooltip
	ribbon.label:SetText(data.text)
	ribbon.count:SetText(data.count or "")
	ribbon.count:SetShown(data.count ~= nil)
	ribbon.label:ClearAllPoints()
	ribbon.label:SetPoint("BOTTOM", ribbon, "BOTTOM", 0, data.count and RIBBON_LABEL_OVER_Y or RIBBON_LABEL_Y)
	ribbon.color, ribbon.chosen = data.color, chosen
	paintRibbon(ribbon)
	local to = chosen and RIBBON.lengthChosen or RIBBON.length
	Pagle.StopMotion(ribbon)
	if animate and to ~= ribbon.length and motionOn() then
		Pagle.Animate(ribbon, {
			{
				dur = RIBBON.ease,
				ease = Pagle.EASE.out,
				keys = { { 0, { ribbon.length } }, { 1, { to } } },
				apply = function(v)
					hangRibbon(ribbon, v[1])
				end,
			},
		})
	else
		hangRibbon(ribbon, to)
	end
end

---------------------------------------------------------------------------------------------------------------------
-- The page turn (BOOK-R31)
---------------------------------------------------------------------------------------------------------------------

--- Shows only the strip [a, b] (shares of the paper's width) of `side`; none when it is (near) empty.
---@param side PagleBookSideView?
---@param a number
---@param b number
local function reveal(side, a, b)
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

---@class PagleBookFold: Frame
---@field shade Texture
---@field cast Texture
---@field edge Texture

---@param frame PagleBookFrame
---@return PagleBookFold
local function foldOf(frame)
	local fold = frame.turnFold
	if fold then
		return fold
	end
	fold = CreateFrame("Frame", nil, frame) --[[@as PagleBookFold]]
	fold:SetAllPoints()
	fold:SetFrameLevel(frame:GetFrameLevel() + FOLD_LEVELS)
	fold.shade = fold:CreateTexture(nil, "OVERLAY", nil, 0)
	fold.shade:SetColorTexture(0.16, 0.08, 0.02, 1)
	fold.cast = fold:CreateTexture(nil, "OVERLAY", nil, 1)
	fold.cast:SetColorTexture(1, 1, 1, 1)
	fold.edge = fold:CreateTexture(nil, "OVERLAY", nil, 2)
	fold.edge:SetColorTexture(1, 0.97, 0.85, 1)
	fold:Hide()
	frame.turnFold = fold
	return fold
end

-- Places the fold: the turning strip [x0, x1] on `paper`, its moving edge at `ex`, the cast shadow on the side `side`
-- names (-1 left of the edge, 1 right of it).
local function placeFold(fold, paper, x0, x1, ex, side, shade, castAlpha)
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
	local dark, clear = CreateColor(0.12, 0.06, 0.02, CAST_DARK * castAlpha), CreateColor(0.12, 0.06, 0.02, 0)
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
	fold.edge:SetAlpha(EDGE_LIGHT * castAlpha)
end

---------------------------------------------------------------------------------------------------------------------
-- The book
---------------------------------------------------------------------------------------------------------------------

---@class PagleBookFrame
---@field dim Frame?
---@field binding PagleBookBinding
---@field parchments table<PagleBookSide, PagleBookParchment>
---@field notices table<PagleBookSide, FontString>
---@field crumbs Frame
---@field crumbButtons Button[]
---@field stripText FontString
---@field back Button?
---@field plate PagleBookPlate?
---@field close PagleBookClose
---@field help PagleBookHelp?
---@field ribbons PagleBookRibbonView[]
---@field turnFold PagleBookFold?

--- A turn or crossfade under way.
---@class PagleBookMotion
---@field turn PagleBookTurn
---@field owner table
---@field fade boolean

local Book = {}
Book.__index = Book

---@param book PagleBook
---@param phase PagleBookTurnPhase
---@param turn PagleBookTurn
---@param k number?
local function hook(book, turn, phase, k)
	local onTurn = book.options.onTurn
	if onTurn then
		onTurn(turn, phase, k)
	end
end

-- Inks `crumb` in `look`'s gilt and gilt shadow, its fleuron toned toward that gilt.
local function inkCrumb(crumb, look)
	local gilt, shadow = look.gilt, look.giltShadow
	crumb.label:SetTextColor(gilt[1], gilt[2], gilt[3])
	crumb.label:SetShadowColor(shadow[1], shadow[2], shadow[3], shadow[4])
	crumb.label:SetShadowOffset(shadow[5], shadow[6])
	if crumb.fleuron then
		crumb.fleuron:SetVertexColor(
			math.min(1, gilt[1] / FLEURON_GILT[1]),
			math.min(1, gilt[2] / FLEURON_GILT[2]),
			math.min(1, gilt[3] / FLEURON_GILT[3])
		)
	end
end

-- Dresses the shell in `look` (BOOK-R10), then hands it to the book.
---@param book PagleBook
---@param look PagleBindingLook
local function wear(book, look)
	book.look = look
	local frame = book.frame
	if frame then
		for _, crumb in ipairs(frame.crumbButtons) do
			inkCrumb(crumb, look)
		end
		if frame.plate then
			frame.plate.silver = look.silver == true
			tonePlate(frame.plate)
		end
		local tint = look.paperTint
		for _, parchment in pairs(frame.parchments) do
			parchment.paper:SetVertexColor(tint[1], tint[2], tint[3])
		end
	end
	if book.options.onLook then
		book.options.onLook(look)
	end
end

-- Places the frame (BOOK-R5, BOOK-R6): where it was left, in UIParent's units, or centred and lifted.
---@param book PagleBook
---@param frame Frame
local function position(book, frame)
	local options = book.options
	local saved = positions()
	local point = not options.fixed and saved and ns.BookSavedPoint(saved[options.id]) or nil
	if saved and not point then
		saved[options.id] = nil
	end
	frame:ClearAllPoints()
	if point then
		local scale = frame:GetScale()
		frame:SetPoint(point[1], UIParent, point[2], point[3] / scale, point[4] / scale)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, SHELL.lift)
	end
end

-- Ribbon `i`, made on first use, under the leather's foot (BOOK-R17).
---@param book PagleBook
---@param i integer
---@return PagleBookRibbonView
local function ribbonAt(book, i)
	local frame = book.frame --[[@as PagleBookFrame]]
	local ribbon = frame.ribbons[i]
	if not ribbon then
		ribbon = newRibbon(frame)
		ribbon:SetFrameLevel(frame:GetFrameLevel() + 1) -- under the band, six levels up: its tucked top hides
		ribbon:SetPoint(
			"TOPLEFT",
			frame,
			"TOPLEFT",
			(book.options.ribbonsLeft or SHELL.ribbonsLeft) + (i - 1) * (RIBBON.width + RIBBON.gap),
			-(book.options.height - RIBBON.tuck)
		)
		ribbon:SetScript("OnClick", function()
			local data = book.ribbonList[i]
			if data then
				local target = data.target
				book:Open(type(target) == "function" and target() or target)
			end
		end)
		frame.ribbons[i] = ribbon
	end
	return ribbon
end

-- Hangs the ribbons for `place` (BOOK-R17, BOOK-R18), running a change of choice when `animate`.
---@param book PagleBook
---@param place PagleBookPlace
---@param animate boolean?
local function drawRibbons(book, place, animate)
	local frame = book.frame --[[@as PagleBookFrame]]
	local list = book.ribbonList
	local chosen
	if book.options.chosenRibbon then
		chosen = book.options.chosenRibbon(place)
	else
		for _, data in ipairs(list) do
			if type(data.target) == "table" and data.target.page == place.page then
				chosen = data.id
				break
			end
		end
	end
	for i, data in ipairs(list) do
		local ribbon = ribbonAt(book, i)
		setRibbon(ribbon, data, data.id == chosen, animate and ribbon:IsShown())
		ribbon:Show()
	end
	for i = #list + 1, #frame.ribbons do
		frame.ribbons[i]:Hide()
	end
end

-- Crumb `i`, made on first use: its gilt words and, after the first, the fleuron before them.
---@param book PagleBook
---@param i integer
local function crumbAt(book, i)
	local frame = book.frame --[[@as PagleBookFrame]]
	local crumb = frame.crumbButtons[i]
	if not crumb then
		crumb = CreateFrame("Button", nil, frame.crumbs)
		if i > 1 then
			crumb.fleuron = ns.ArtSprite(crumb, "Book", "fleuron", "OVERLAY")
			crumb.fleuron:SetSize(16, 16)
			crumb.fleuron:SetPoint("LEFT", 8, 0)
		end
		crumb.label = text(crumb, "gilt", 14, book.look.gilt, true)
		crumb.label:SetPoint("LEFT", i > 1 and 32 or 0, 0)
		crumb:SetScript("OnEnter", function(self)
			if self:GetScript("OnClick") then
				self.label:SetTextColor(INKS.giltBright[1], INKS.giltBright[2], INKS.giltBright[3])
			end
		end)
		crumb:SetScript("OnLeave", function(self)
			local gilt = book.look.gilt
			self.label:SetTextColor(gilt[1], gilt[2], gilt[3])
		end)
		frame.crumbButtons[i] = crumb
	end
	return crumb
end

-- Lays the crumbs along the strip (BOOK-R12, BOOK-R24).
---@param book PagleBook
local function drawCrumbs(book)
	local frame = book.frame --[[@as PagleBookFrame]]
	local trail = book.options.trail and book.options.trail(book.router:Place()) or {}
	local x = 0
	for i, data in ipairs(trail) do
		local crumb = crumbAt(book, i)
		crumb.label:SetText(data.text)
		inkCrumb(crumb, book.look)
		local lead = i > 1 and 34 or 2
		bound(crumb.label, frame.crumbs:GetWidth() - x - lead)
		local width = crumb.label:GetWidth() + lead
		crumb:SetSize(width, 20)
		crumb:ClearAllPoints()
		crumb:SetPoint("LEFT", x, 0)
		local target = data.target
		crumb:SetScript("OnClick", target and function()
			book:Open(target)
		end or nil)
		crumb:Show()
		x = x + width
	end
	for i = #trail + 1, #frame.crumbButtons do
		frame.crumbButtons[i]:Hide()
	end
end

-- Builds the book's frame, hidden (BOOK-R2–R17).
---@param book PagleBook
---@return PagleBookFrame
local function build(book)
	local options = book.options
	local strata = options.strata or "HIGH"
	local dim
	if options.dim then
		dim = CreateFrame("Frame", nil, UIParent)
		dim:SetAllPoints(UIParent)
		dim:SetFrameStrata(strata)
		dim:EnableMouse(false)
		local shade = dim:CreateTexture(nil, "BACKGROUND")
		shade:SetColorTexture(0x06 / 255, 0x08 / 255, 0x08 / 255, options.dim)
		shade:SetAllPoints()
		dim:Hide()
	end

	local frame = CreateFrame("Frame", options.name, UIParent) --[[@as PagleBookFrame]]
	book.frame = frame
	frame.dim = dim
	frame:SetSize(options.width, options.height)
	frame:SetFrameStrata(strata)
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetClampRectInsets(0, 0, 0, -(RIBBON.lengthChosen - RIBBON.tuck))
	frame:EnableMouse(true)
	if not options.fixed then
		frame:SetMovable(true)
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", frame.StartMoving)
		frame:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			self:SetUserPlaced(false)
			local point, _, relativePoint, x, y = self:GetPoint(1)
			local saved = positions()
			if point and saved then
				local scale = self:GetScale()
				saved[options.id] = { point, relativePoint, x * scale, y * scale }
			end
		end)
	end

	-- the pages
	local side, strip = options.side or SHELL.side, options.strip or SHELL.strip
	local pad = options.pad or SHELL.pad
	local leftRect, rightRect, pageHeight, foot = ns.BookPageRects(options)
	frame.papers, frame.parchments, frame.bodies, frame.notices = {}, {}, {}, {}
	for name, rect in pairs({ left = leftRect, right = rightRect }) do
		local paper = CreateFrame("Frame", nil, frame)
		paper:SetSize(rect.width, pageHeight)
		paper:SetPoint("BOTTOMLEFT", rect.left, foot)
		paper:EnableMouse(true)
		frame.papers[name] = paper
		frame.parchments[name] = newParchment(paper, name == "left" and "RIGHT" or "LEFT")
		local body = CreateFrame("Frame", nil, paper)
		body:SetPoint("TOPLEFT", pad.x, -pad.top)
		body:SetPoint("BOTTOMRIGHT", -pad.x, pad.bottom)
		body:SetSize(rect.width - 2 * pad.x, pageHeight - pad.top - pad.bottom)
		frame.bodies[name] = body
		local notice = text(body, "hand", 20, INKS.hand)
		notice:SetWordWrap(true)
		notice:SetSpacing(2)
		notice:SetPoint("TOPLEFT")
		notice:SetWidth(rect.width - 2 * pad.x)
		notice:Hide()
		frame.notices[name] = notice
	end

	-- the strip: the crumbs at its left, the book's words at its right
	local middle = (FILL_INSET + strip) / 2
	frame.crumbs = CreateFrame("Frame", nil, frame)
	frame.crumbs:SetPoint("TOPLEFT", side + 6, -(middle - 10))
	frame.crumbs:SetSize(options.width - 2 * side - 12 - (options.stripRoom or 0), 20)
	frame.crumbs:SetFrameLevel(frame:GetFrameLevel() + OVER)
	frame.crumbButtons = {}
	frame.stripText = text(frame.crumbs, "gilt", 14, INKS.strip, true)
	frame.stripText:SetJustifyH("RIGHT")
	frame.stripText:SetPoint("RIGHT", frame, "TOPRIGHT", -(side + 6), -middle)
	frame.stripText:SetText(book.stripWords or "")

	-- the back link at the left page's foot
	if options.back then
		local back = CreateFrame("Button", nil, frame.papers.left)
		back:SetFrameLevel(frame.papers.left:GetFrameLevel() + 20)
		back.label = text(back, "hand", 20, INKS.back)
		back.label:SetPoint("LEFT")
		back.label:SetText(options.back.text)
		back:SetSize(back.label:GetStringWidth() + 4, 24)
		back:SetPoint("BOTTOMLEFT", pad.x, 4)
		back:SetScript("OnEnter", function(self)
			self.label:SetTextColor(INKS.backHover[1], INKS.backHover[2], INKS.backHover[3])
		end)
		back:SetScript("OnLeave", function(self)
			self.label:SetTextColor(INKS.back[1], INKS.back[2], INKS.back[3])
		end)
		back:Hide()
		frame.back = back
	end

	-- the nameplate
	if options.plate then
		frame.plate = newPlate(frame)
		frame.plate:SetPoint("TOPLEFT", frame, "TOPLEFT", options.plate.x, -options.plate.y)
		frame.plate:SetFrameLevel(frame:GetFrameLevel() + OVER)
		writePlate(frame.plate, book.plateWords or "", book.plateTooltip)
	end

	-- the leather anchors
	for name, def in pairs(options.anchors or {}) do
		local anchor = CreateFrame("Frame", nil, frame)
		anchor:SetSize(def.width, def.height)
		anchor:SetPoint(def.point, frame, def.point, def.x, def.y)
		anchor:SetFrameLevel(frame:GetFrameLevel() + OVER)
		anchor:EnableMouse(true)
		book.anchors[name] = anchor
	end

	frame.ribbons = {}

	-- the leather: made once the parts it inks are (BOOK-R10)
	book.binding = Pagle.NewBookBinding(frame, {
		pinned = options.pinned,
		onLook = function(look)
			wear(book, look)
		end,
	})
	frame.binding = book.binding

	frame.close = newClose(frame)
	frame.close:SetPoint("CENTER", frame, "TOPRIGHT", -3, -3)
	frame.close:SetFrameLevel(frame:GetFrameLevel() + OVER)
	frame.close:SetScript("OnClick", function()
		book:Close()
	end)
	if options.help then
		frame.help = newHelp(frame, options.help.tooltip)
		frame.help:SetPoint("RIGHT", frame.close, "LEFT", -WAX_GAP, 0)
		frame.help:SetFrameLevel(frame:GetFrameLevel() + OVER)
		frame.help:SetScript("OnClick", function()
			options.help.onClick()
		end)
		frame.help:SetShown(book.helpShown)
	end
	drawRibbons(book, book.router:Place(), false)

	frame:Hide()
	-- Esc hides it (UISpecialFrames). Hiding UIParent also runs OnHide but leaves it shown: that isn't closing.
	frame:SetScript("OnHide", function(self)
		if self:IsShown() then
			return
		end
		book:Hidden()
		sound(SHELL.sounds.close)
	end)
	table.insert(UISpecialFrames, options.name)
	return frame
end

--- A book's handle (BOOK-R1). The fields past the contract's are the shell's own.
---@class PagleBook
---@field options PagleBookOptions
---@field router PagleBookRouter
---@field look PagleBindingLook?
---@field ribbonList PagleBookRibbon[]
---@field views table<string, PagleBookSideView>      -- by "page:side:leaf"
---@field leaves table<string, integer>                -- each page's side's leaf now, by "page:side"
---@field leatherRenderers table<string, fun(anchor: Frame, place: PagleBookPlace, notice: string?)>
---@field drawnKey string?
---@field drawnPage string?
---@field drawnSides table<PagleBookSide, PagleBookSideView>
---@field motion PagleBookMotion?
---@field closing table?
---@field showing integer
---@field queued boolean
---@field plateWords string?
---@field plateTooltip string[]?
---@field stripWords string?
---@field helpShown boolean

---@param options PagleBookOptions
---@return PagleBook
function Pagle.NewBook(options)
	assert(type(options) == "table", "Pagle.NewBook takes its options")
	assert(type(options.id) == "string", "a book needs its id")
	assert(not taken[options.id], "a book is already called " .. options.id)
	assert(type(options.name) == "string", "a book needs its frame's name")
	assert(type(options.width) == "number" and type(options.height) == "number", "a book needs its size")
	local router = ns.NewBookRouter(options.pages, options.home)
	taken[options.id] = true
	return setmetatable({
		options = options,
		router = router,
		anchors = {},
		ribbonList = options.ribbons or {},
		views = {},
		leaves = {},
		leatherRenderers = {},
		drawnSides = {},
		showing = 0,
		queued = false,
		helpShown = true,
	}, Book)
end

function Book:RegisterPage(page, side, renderer)
	self.router:Register(page, side, renderer)
end

function Book:RegisterLeather(name, renderer)
	assert(self.options.anchors and self.options.anchors[name], "the book's leather has no anchor " .. tostring(name))
	assert(type(renderer) == "function", "a leather anchor's renderer is a function")
	self.leatherRenderers[name] = renderer
end

function Book:IsShown()
	return self.frame ~= nil and self.frame:IsShown()
end

function Book:Showing()
	return self.showing
end

function Book:Place()
	return self.router:Place()
end

function Book:Look()
	return self.look
end

function Book:Toggle()
	if self:IsShown() and not self.closing then
		self:Close()
	else
		self:Open()
	end
end

function Book:SetRibbons(ribbons)
	self.ribbonList = ribbons or {}
	if self.frame then
		drawRibbons(self, self.router:Place(), false)
	end
end

function Book:SetPlate(words, tooltip)
	self.plateWords, self.plateTooltip = words, tooltip
	if self.frame and self.frame.plate then
		writePlate(self.frame.plate, words, tooltip)
	end
end

function Book:RibbonFrame(id)
	local frame = self.frame
	if not frame then
		return nil
	end
	for _, ribbon in ipairs(frame.ribbons) do
		if ribbon.id == id and ribbon:IsShown() then
			return ribbon
		end
	end
	return nil
end

function Book:SetStripText(words)
	self.stripWords = words
	if self.frame then
		self.frame.stripText:SetText(words or "")
	end
end

function Book:SetHelpShown(shown)
	self.helpShown = shown == true
	if self.frame and self.frame.help then
		self.frame.help:SetShown(self.helpShown)
	end
end

function Book:Open(place, how)
	local from = self.router:Place()
	if place then
		self.router:Open(place)
	end
	if how == nil and self.options.how then
		how = self.options.how(from, self.router:Place())
	end
	local frame = self.frame or build(self)
	local open = frame:IsShown() and not self.closing
	if self.closing then
		-- opened again while fading out: it stays, whole
		Pagle.StopMotion(self.closing)
		self.closing = nil
		frame:SetAlpha(1)
	end
	local opening = not frame:IsShown()
	if opening then
		local options = self.options
		Pagle.FitToScreen(frame, {
			width = options.width + SHELL.extentX,
			height = options.height + SHELL.extentY,
			keepPlace = true,
		})
		position(self, frame)
		if frame.dim then
			frame.dim:Show()
		end
		frame:Show()
		sound(SHELL.sounds.open)
		Pagle.Animate(frame, {
			{
				dur = SHELL.openFade,
				ease = Pagle.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					frame:SetAlpha(v[1])
				end,
			},
		})
	end
	frame:Raise()
	self:Draw(open and (how or {}) or nil)
	if opening and self.options.onShow then
		self.options.onShow()
	end
end

function Book:Close()
	local frame = self.frame
	if not frame or not frame:IsShown() or self.closing then
		return
	end
	if not motionOn() then
		frame:Hide()
		return
	end
	local closing = {}
	self.closing = closing
	Pagle.StopMotion(frame) -- an opening fade still running gives way
	local function finish()
		if self.closing == closing then
			Pagle.StopMotion(closing)
			self.closing = nil
			frame:Hide()
			frame:SetAlpha(1)
		end
	end
	Pagle.Animate(closing, {
		{
			dur = SHELL.closeFade,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	}, finish)
	C_Timer.After(SHELL.closeFade, finish)
end

-- Settles the turn or crossfade under way, if any (BOOK-R32).
---@param book PagleBook
local function settle(book)
	local motion = book.motion
	if not motion then
		return
	end
	book.motion = nil
	Pagle.StopMotion(motion.owner)
	for _, view in pairs(motion.turn.from) do
		view.clip:Hide()
		view.clip:SetAlpha(1)
	end
	for _, view in pairs(book.drawnSides) do
		reveal(view, 0, 1)
		view.clip:SetAlpha(1)
	end
	if book.frame and book.frame.turnFold then
		book.frame.turnFold:Hide()
	end
	if not motion.fade then
		hook(book, motion.turn, "done")
	end
end

function Book:Settle()
	local frame = self.frame
	if not frame then
		return
	end
	if self.closing then
		local closing = self.closing
		self.closing = nil
		Pagle.StopMotion(closing)
		frame:Hide()
	end
	Pagle.StopMotion(frame)
	frame:SetAlpha(1)
	settle(self)
end

--- The book has closed, however it closed (BOOK-R40).
function Book:Hidden()
	self.showing = self.showing + 1
	if self.closing then
		Pagle.StopMotion(self.closing)
		self.closing = nil
	end
	settle(self)
	local frame = self.frame
	if frame then
		frame:SetAlpha(1)
		if frame.dim then
			frame.dim:Hide()
		end
	end
	if self.options.onHide then
		self.options.onHide()
	end
end

function Book:QueueDraw()
	if not self:IsShown() or self.queued then
		return
	end
	self.queued = true
	C_Timer.After(0, function()
		self.queued = false
		self:Draw()
	end)
end

-- Side `side` of `page` on leaf `leaf`: its clip on the side's paper, its scroll frame over the body and its content,
-- made at its first draw.
---@param book PagleBook
---@param page string
---@param side PagleBookSide
---@param leaf integer
---@return PagleBookSideView
local function viewOf(book, page, side, leaf)
	local key = page .. ":" .. side .. ":" .. leaf
	local view = book.views[key]
	if not view then
		local frame = book.frame --[[@as PagleBookFrame]]
		local body, paper = frame.bodies[side], frame.papers[side]
		local clip = CreateFrame("Frame", nil, paper)
		clip:SetClipsChildren(true)
		clip:SetAllPoints()
		local scroll = CreateFrame("ScrollFrame", nil, clip) --[[@as ScrollFrame]]
		scroll:SetAllPoints(body)
		local content = CreateFrame("Frame", nil, scroll)
		content:SetSize(body:GetWidth(), body:GetHeight())
		scroll:SetScrollChild(content)
		scroll:EnableMouseWheel(true)
		local wheel = { height = body:GetHeight() }
		scroll:SetScript("OnMouseWheel", function(self, delta)
			Pagle.WheelScroll(self, delta, wheel)
		end)
		view = { clip = clip, paper = paper, scroll = scroll, content = content }
		book.views[key] = view
	end
	return view
end

-- Plays the turn (BOOK-R31) from the spread drawn to the one just drawn.
---@param book PagleBook
---@param turn PagleBookTurn
local function playTurn(book, turn)
	local frame = book.frame --[[@as PagleBookFrame]]
	local owner = {}
	local motion = { turn = turn, owner = owner, fade = false }
	book.motion = motion
	hook(book, turn, "start")
	local function midway()
		drawCrumbs(book)
		hook(book, turn, "midway")
	end
	local function done()
		if book.motion == motion then
			settle(book)
		end
	end
	if not motionOn() then
		midway()
		done()
		return
	end
	sound(SHELL.sounds.turn)
	local from, to, papers = turn.from, turn.to, turn.papers
	local leftWidth, rightWidth = papers.left:GetWidth(), papers.right:GetWidth()
	local fold = foldOf(frame)
	fold:Show()
	local forward = turn.forward
	if forward then
		reveal(to.left, 1, 1)
		reveal(from.left, 0, 1)
	else
		reveal(to.right, 0, 0)
		reveal(from.right, 0, 1)
	end
	Pagle.Animate(owner, {
		{
			dur = TURN_LIFT,
			ease = Pagle.Bezier(0.5, 0, 0.9, 0.6),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if forward then
					reveal(from.right, 0, 1 - k)
					reveal(to.right, 1 - k, 1)
					placeFold(fold, papers.right, 0, (1 - k) * rightWidth, (1 - k) * rightWidth, 1, SHADE * k, 1)
				else
					reveal(from.left, k, 1)
					reveal(to.left, 0, k)
					placeFold(fold, papers.left, k * leftWidth, leftWidth, k * leftWidth, -1, SHADE * k, 1)
				end
				hook(book, turn, "lift", k)
			end,
			done = midway,
		},
		{
			dur = TURN_LAND,
			delay = TURN_LIFT,
			ease = Pagle.Bezier(0.1, 0.4, 0.4, 1),
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				local k = v[1]
				if k <= 0 then
					return
				end
				if forward then
					reveal(from.right, 0, 0)
					reveal(to.right, 0, 1)
					reveal(to.left, 1 - k, 1)
					reveal(from.left, 0, 1 - k)
					local x = (1 - k) * leftWidth
					placeFold(fold, papers.left, x, leftWidth, x, -1, SHADE * (1 - k), 1 - k)
				else
					reveal(from.left, 0, 0)
					reveal(to.left, 0, 1)
					reveal(to.right, 0, k)
					reveal(from.right, k, 1)
					placeFold(fold, papers.right, 0, k * rightWidth, k * rightWidth, 1, SHADE * (1 - k), 1 - k)
				end
				hook(book, turn, "land", k)
			end,
		},
	}, done)
end

-- Crossfades each side from the spread drawn to the one just drawn (BOOK-R30).
---@param book PagleBook
---@param turn PagleBookTurn
local function crossfade(book, turn)
	local owner = {}
	local motion = { turn = turn, owner = owner, fade = true }
	book.motion = motion
	local function done()
		if book.motion == motion then
			settle(book)
		end
	end
	if not motionOn() then
		done()
		return
	end
	for _, view in pairs(turn.from) do
		reveal(view, 0, 1)
	end
	Pagle.Animate(owner, {
		{
			dur = SHELL.crossfade,
			ease = Pagle.EASE.inOut,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				for _, view in pairs(turn.from) do
					view.clip:SetAlpha(1 - v[1])
				end
				for _, view in pairs(turn.to) do
					view.clip:SetAlpha(v[1])
				end
			end,
		},
	}, done)
end

--- Draws the book now, if open (BOOK-R21–R24, BOOK-R30): `how`, from Open on a book already open, says how it moves.
---@param how PagleBookOpenHow?
function Book:Draw(how)
	local frame = self.frame
	if not frame or not frame:IsShown() then
		return
	end
	local options = self.options
	local router = self.router
	local place = router:Place()
	local notice = options.notice and options.notice() or nil
	local key = ns.BookPlaceKey(place)
	local moved = key ~= self.drawnKey
	self.drawnKey = key
	local fromPage, fromSides = self.drawnPage, self.drawnSides
	local mode = "still"
	if how and not notice and fromPage ~= nil then
		local asked = how.motion or "auto"
		if asked == "auto" then
			mode = fromPage ~= place.page and "turn" or "still"
		elseif asked == "turn" or asked == "fade" then
			mode = asked
		end
	end
	if mode ~= "still" or notice then
		settle(self)
	end
	-- a turn or crossfade on the same page draws on the page's other leaf
	local flip = mode ~= "still" and fromPage == place.page
	local keep = {}
	local motion = self.motion
	for _, sides in ipairs({
		motion and motion.turn.from or {},
		motion and motion.turn.to or {},
		mode ~= "still" and fromSides or {},
	}) do
		for _, view in pairs(sides) do
			keep[view] = true
		end
	end
	for _, view in pairs(self.views) do
		if not keep[view] then
			view.clip:Hide()
		end
	end
	local sides = {}
	for _, side in ipairs({ "left", "right" }) do
		local noticeText = frame.notices[side]
		noticeText:SetShown(notice ~= nil)
		noticeText:SetText(notice or "")
		local renderer = not notice and router:Renderer(place.page, side)
		if renderer then
			local leafKey = place.page .. ":" .. side
			local leaf = self.leaves[leafKey] or 1
			if flip then
				leaf = 3 - leaf
				self.leaves[leafKey] = leaf
			end
			local view = viewOf(self, place.page, side, leaf)
			if not keep[view] then
				reveal(view, 0, 1)
				view.clip:SetAlpha(mode == "fade" and 0 or 1)
			end
			local height = renderer(view.content, router:Place())
			view.content:SetHeight(math.max(1, height or frame.bodies[side]:GetHeight()))
			if moved or flip then
				view.scroll:SetVerticalScroll(0)
			end
			sides[side] = view
		end
	end
	self.drawnPage = not notice and place.page or nil
	self.drawnSides = sides
	---@type PagleBookTurn
	local turn = { from = fromSides, to = sides, papers = frame.papers, forward = true }
	if mode == "turn" then
		if how and how.forward ~= nil then
			turn.forward = how.forward
		else
			turn.forward = router:Forward(fromPage --[[@as string]], place.page)
		end
		playTurn(self, turn)
	elseif mode == "fade" then
		drawCrumbs(self)
		crossfade(self, turn)
	else
		drawCrumbs(self)
	end
	drawRibbons(self, place, how ~= nil)
	if frame.back then
		local target = options.back.target(router:Place())
		frame.back:SetScript("OnClick", target and function()
			self:Open(target)
		end or nil)
		frame.back:SetShown(target ~= nil)
	end
	for name, renderer in pairs(self.leatherRenderers) do
		renderer(self.anchors[name], router:Place(), notice)
	end
	if options.onDraw then
		options.onDraw(router:Place(), notice)
	end
end
