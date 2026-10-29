if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Collection's widgets (LED-R168–R170; ledger.md › UI › The Collection): the blocks logic/JournalShelves.lua makes,
-- drawn in the Journal's look with the kit's parts: a look's art (Core's preview of it, a binding's closed book, a
-- crest's shield, a sound set's speaker, a title's quill), in ink or in pencil, the cards of a shelf with their solid
-- and dashed edges, a shelf's row, the rows of "Within reach" and "Lately added", the dark stage of the chosen look and
-- the state under it. A look that turns owned inks in from pencil (0.6 s) as "new!" is written beside it, and "Use it"
-- gives way to a wax seal pressed on from 2.2 times its size (0.45 s) with the Journal's seal sound.

local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB
local bound = ns.JournalBound
local newWidget = ns.NewJournalWidget

-- ---------------------------------------------------------------- a look's art, in ink or in pencil

-- A closed book's proportions on its card (LED-R169): 70 x 92.
local BOOK_W, BOOK_H = 70, 92
-- The warm tone the pencil tints toward, and the textures each pencilled one was before.
local SEPIA_TONE = { 0.7, 0.55, 0.35 }
---@type table<Texture, { [1]: boolean, [2]: number, [3]: number, [4]: number, [5]: number }>
local pencilled = setmetatable({}, { __mode = "k" })

-- Pencils `texture` to `k`, 0 (in ink) to 1 (in pencil): desaturated by k and tinted sepia by the Tunable's share of it,
-- and back to what it was at 0 (LED-R170).
---@param texture Texture
---@param k number
local function pencilTexture(texture, k)
	local saved = pencilled[texture]
	if k > 0 and not saved then
		local r, g, b, a = 1, 1, 1, 1
		if texture.GetVertexColor then
			r, g, b, a = texture:GetVertexColor()
		end
		saved = { texture.IsDesaturated and texture:IsDesaturated() or false, r, g, b, a }
		pencilled[texture] = saved
	end
	if not saved then
		return
	end
	if k <= 0 then
		texture:SetDesaturated(saved[1])
		texture:SetVertexColor(saved[2], saved[3], saved[4], saved[5])
		pencilled[texture] = nil
		return
	end
	if texture.SetDesaturation then
		texture:SetDesaturation(k)
	else
		texture:SetDesaturated(k >= 0.5 or saved[1])
	end
	local sepia = ns.COLLECTION_PENCIL.sepia * k
	texture:SetVertexColor(
		saved[2] * (1 - (1 - SEPIA_TONE[1]) * sepia),
		saved[3] * (1 - (1 - SEPIA_TONE[2]) * sepia),
		saved[4] * (1 - (1 - SEPIA_TONE[3]) * sepia),
		saved[5]
	)
end

-- Every texture under `frame`, in it and in the frames under it, on a client that lists them.
---@param frame Frame
---@param fn fun(texture: Texture)
local function eachTexture(frame, fn)
	if frame.GetRegions then
		for i = 1, select("#", frame:GetRegions()) do
			local region = select(i, frame:GetRegions())
			if region.GetObjectType and region:GetObjectType() == "Texture" then
				fn(region)
			end
		end
	end
	if frame.GetChildren then
		for i = 1, select("#", frame:GetChildren()) do
			eachTexture((select(i, frame:GetChildren())), fn)
		end
	end
end

--- A look's art on a card, a row or the Collection's rows (LED-R168–R170): one frame that draws what its look is drawn
--- as, in ink or in pencil.
---@class LedgerLookArtView: Frame
---@field w number
---@field h number
---@field preview Frame          -- Core's preview of the good (Pagle.DrawGoodPreview) is drawn into it
---@field book LedgerSpriteTexture
---@field live Frame             -- a binding no kit drew closed, drawn live
---@field binding PagleBookBinding?
---@field shield Texture
---@field medal LedgerMedal      -- a sound set's speaker
---@field quill LedgerSpriteTexture
---@field pencil number          -- 1 in pencil, 0 in ink, in between while it inks in
---@field kind string?

--- A look's art `w` by `h`, empty until ns.SetJournalLookArt.
---@param parent Frame
---@param w number
---@param h number
---@return LedgerLookArtView
function ns.NewJournalLookArt(parent, w, h)
	local view = CreateFrame("Frame", nil, parent) --[[@as LedgerLookArtView]]
	view:SetSize(w, h)
	view.w, view.h, view.pencil = w, h, 0
	-- sized outright: Core's card draw scales its stage to the frame's size as it is asked
	view.preview = CreateFrame("Frame", nil, view)
	view.preview:SetSize(w, h)
	view.preview:SetPoint("TOPLEFT")
	view.preview:SetClipsChildren(true)
	view.book = ns.JournalSprite(view, "Bindings", "binding-field-leather", "ARTWORK")
	-- a live book's parts (its corner pieces, a whole book's clasp and ribbon) draw at their own sizes, so the frame keeps
	-- them inside the art's box
	view.live = CreateFrame("Frame", nil, view)
	view.live:SetClipsChildren(true)
	view.shield = ns.JournalCrisp(view:CreateTexture(nil, "ARTWORK"))
	view.medal = ns.JournalMedal(view, math.min(w, h))
	view.medal:SetPoint("CENTER")
	view.quill = ns.JournalSprite(view, "Parts", "quill", "ARTWORK", 0, math.min(w, h))
	for _, part in ipairs({ view.preview, view.book, view.live, view.shield, view.medal, view.quill }) do
		part:Hide()
	end
	return view
end

-- The closed book of binding `goodID`: its swatch in the Journal's atlases (every kit's: Bindings, Bindings2, Covers2
-- and Bindings3), or a live book where no kit drew one (Tooled Leather, Verdigris), as Core's stage draws it (BIND-R1).
-- A swatch's atlas missing here must not fall to the live book: a whole book's clasp and ribbon draw at their own sizes
-- (BIND-R14, BIND-R15), not the thumbnail's, as Captain's Logbook's did.
---@param view LedgerLookArtView
---@param goodID string
local function drawBook(view, goodID)
	local look = Pagle.GetBindingLook(goodID)
	local atlas = look.swatchAtlas
	local width = math.min(view.w, view.h * BOOK_W / BOOK_H)
	if look.swatch and atlas and ns.JOURNAL_ATLASES[atlas] then
		ns.JournalResprite(view.book, atlas, look.swatch, width)
		ns.JournalBoxAt(view.book, view, (view.w - width) / 2, 0)
		view.book:Show()
		return
	end
	local height = width * BOOK_H / BOOK_W
	view.live:SetSize(width, height)
	view.live:ClearAllPoints()
	view.live:SetPoint("TOP")
	view.live:Show()
	if view.binding then
		view.binding:SetLook(goodID)
	else
		local scale = height / 600
		view.binding = Pagle.NewBookBinding(view.live, {
			pinned = goodID,
			cornerSize = math.floor(44 * scale + 0.5),
			giltCornerSize = math.floor(40 * scale + 0.5),
		})
	end
end

--- Sets what `view` draws (LedgerLookArt) and how far it is in pencil (1 in pencil, 0 in ink).
---@param view LedgerLookArtView
---@param art LedgerLookArt?
---@param pencil number
function ns.SetJournalLookArt(view, art, pencil)
	for _, part in ipairs({ view.preview, view.book, view.live, view.shield, view.medal, view.quill }) do
		part:Hide()
	end
	if not art then
		view.kind = nil
		ns.SetJournalPencil(view, pencil)
		return
	end
	local kind = art.kind
	view.kind = kind
	if kind == "preview" then
		view.preview:Show()
		Pagle.DrawGoodPreview(view.preview, art.good --[[@as string]], "card")
	elseif kind == "book" then
		drawBook(view, art.good --[[@as string]])
	elseif kind == "shield" and art.icon then
		view.shield:SetTexture(art.icon)
		view.shield:SetSize(view.h, view.h)
		view.shield:ClearAllPoints()
		view.shield:SetPoint("CENTER")
		view.shield:Show()
	elseif kind == "speaker" and art.icon then
		-- the speaker in its own colours: the good's icon in the brass ring, not in sepia
		view.medal.unknown:Hide()
		view.medal.ring:Show()
		view.medal.icon:Show()
		view.medal.icon:SetTexture(art.icon)
		view.medal:Show()
	elseif kind == "quill" then
		ns.JournalCenter(view.quill, view, view.w / 2, view.h / 2)
		view.quill:Show()
	end
	ns.SetJournalPencil(view, pencil)
end

--- Draws `view` `pencil` of the way to pencil (LED-R170): its whole art desaturated and tinted sepia by the Tunables,
--- at the Tunable alpha when fully in pencil, the paper showing through.
---@param view LedgerLookArtView
---@param pencil number
function ns.SetJournalPencil(view, pencil)
	view.pencil = pencil
	view:SetAlpha(1 - (1 - ns.COLLECTION_PENCIL.alpha) * pencil)
	eachTexture(view, function(texture)
		pencilTexture(texture, pencil)
	end)
end

--- A look turned owned: its art inks in from pencil to its colours (0.6 s). With Animations off it is in ink at once.
---@param view LedgerLookArtView
function ns.InkInJournalLookArt(view)
	Pagle.StopMotion(view)
	if not ns.MotionOn() then
		ns.SetJournalPencil(view, 0)
		return
	end
	ns.SetJournalPencil(view, 1)
	Pagle.Animate(view, {
		{
			dur = 0.6,
			ease = Pagle.EASE.out,
			keys = { { 0, { 1 } }, { 1, { 0 } } },
			apply = function(v)
				ns.SetJournalPencil(view, v[1])
			end,
		},
	}, function()
		ns.SetJournalPencil(view, 0)
	end)
end

-- ---------------------------------------------------------------- a row's pieces

-- The wax seal at 12 units, the dot before "In use" (LED-R169).
---@param parent Frame
---@return LedgerSpriteTexture
local function waxDot(parent)
	local dot = ns.JournalSprite(parent, "Book", "seal", "ARTWORK", 1, 12)
	dot:SetRotation(math.rad(-8))
	dot:Hide()
	return dot
end

-- The Curio Shop's brass coin at 14 units, after a price.
---@param parent Frame
---@return LedgerSpriteTexture
local function coin(parent)
	local texture = ns.JournalSprite(parent, "Shop", "coin-small", "ARTWORK", 1, 14)
	texture:Hide()
	return texture
end

---@class LedgerDottedWidget: LedgerJournalWidget
---@field dots LedgerDotLine

-- Dotted rule along the foot of a row (the kit's contents leaders).
---@param widget LedgerDottedWidget
---@param width number
---@param y number
local function footRule(widget, width, y)
	widget.dots = widget.dots or ns.JournalDotLine(widget, INK.noteLight, 0.6, 3)
	widget.dots:Lay(0, y, width)
end

-- ---------------------------------------------------------------- a shelf's row on the Collection's left page

---@class LedgerShelfRowWidget: LedgerDottedWidget
---@field art LedgerLookArtView
---@field name FontString
---@field new FontString
---@field sub FontString
---@field count FontString
---@field bar LedgerInkBar
---@field dots LedgerDotLine

local ROW_ART_W, ROW_ART_H = 66, 44
local SHELF_ROW_H = 62

-- A shelf's row (LED-R168): the look in use drawn small, the shelf's name, "{n} new" in red hand, in the hand under it what
-- it wears, and at the right "{owned} of {total}" over a small ink bar; it opens the shelf.
ns.RegisterJournalWidget("shelfRow", function(parent)
	local widget = newWidget(parent) --[[@as LedgerShelfRowWidget]]
	ns.JournalClickable(widget)
	widget.art = ns.NewJournalLookArt(widget, ROW_ART_W, ROW_ART_H)
	widget.art:SetPoint("TOPLEFT", 6, -8)
	widget.name = ns.JournalLabel(widget, "print", 19, INK.title)
	widget.new = ns.JournalLabel(widget, "hand", 17, INK.red)
	widget.sub = ns.JournalLabel(widget, "hand", 19, INK.hand)
	widget.count = ns.JournalLabel(widget, "print", 16, INK.small, "", { justify = "RIGHT" })
	widget.bar = ns.JournalInkBar(widget, 120)
	widget:SetScript("OnEnter", function(self)
		self.name:SetTextColor(rgb(INK.hover))
	end)
	widget:SetScript("OnLeave", function(self)
		self.name:SetTextColor(rgb(INK.title))
	end)
	function widget.Fill(self, block, width, open, draw)
		self.place, self.open, self.action = block.place, open, nil
		ns.SetJournalLookArt(self.art, block.lookArt, 0)
		self.art:SetShown(block.lookArt ~= nil)
		local x = ROW_ART_W + 18
		local right = 128
		self.count:SetText(block.value or "")
		bound(self.count, right)
		self.count:ClearAllPoints()
		self.count:SetPoint("TOPRIGHT", self, "TOPLEFT", width, -10)
		self.bar:ClearAllPoints()
		self.bar:SetPoint("TOPRIGHT", self, "TOPLEFT", width, -36)
		self.name:SetText(block.text)
		self.name:ClearAllPoints()
		self.name:SetPoint("TOPLEFT", x, -8)
		bound(self.name, width - x - right - 8)
		self.new:SetShown(block.note ~= nil)
		self.new:SetText(block.note or "")
		self.new:ClearAllPoints()
		self.new:SetPoint("LEFT", self.name, "RIGHT", 8, -1)
		bound(self.new, 80)
		self.sub:SetShown(block.sub ~= nil)
		self.sub:SetText(block.sub or "")
		self.sub:ClearAllPoints()
		self.sub:SetPoint("TOPLEFT", x, -30)
		bound(self.sub, width - x - 130)
		local same, before = ns.JournalRemember(self, draw, "shelfRow:" .. block.text, block.value)
		self.bar:Set(block.fill or 0)
		if same and before ~= nil and before ~= block.value then
			ns.JournalInk(self.count)
		end
		footRule(self, width, SHELF_ROW_H - 1)
		return SHELF_ROW_H
	end
	return widget
end)

-- ---------------------------------------------------------------- the right page's rows

local SMALL_ART_W, SMALL_ART_H = 60, 38

---@class LedgerLookRowWidget: LedgerJournalWidget
---@field art LedgerLookArtView
---@field name FontString
---@field shelf FontString
---@field count FontString
---@field sub FontString
---@field new FontString
---@field bar LedgerInkBar

-- A look in a list on the right page: its art small, its name, its shelf in italic at the right; `reach` adds an ink bar
-- and its count in the hand (LED-R168 "Within reach"), else how it came in italic and "new!" in red (LED-R168 "Lately
-- added").
---@param reach boolean
---@return fun(parent: Frame): LedgerJournalWidget
local function lookRow(reach)
	return function(parent)
		local widget = newWidget(parent) --[[@as LedgerLookRowWidget]]
		ns.JournalClickable(widget)
		widget.art = ns.NewJournalLookArt(widget, SMALL_ART_W, SMALL_ART_H)
		widget.art:SetPoint("TOPLEFT", 4, -4)
		widget.name = ns.JournalLabel(widget, "print", 18, INK.title)
		widget.shelf = ns.JournalLabel(widget, "italic", 14, INK.noteLight, "", { justify = "RIGHT" })
		widget.count = ns.JournalLabel(widget, "hand", 18, INK.hand, "", { justify = "RIGHT" })
		widget.sub = ns.JournalLabel(widget, "italic", 14, INK.note)
		widget.new = ns.JournalLabel(widget, "italic", 14, INK.red, "", { justify = "RIGHT" })
		widget.bar = ns.JournalInkBar(widget, 200)
		widget:SetScript("OnEnter", function(self)
			self.name:SetTextColor(rgb(INK.hover))
		end)
		widget:SetScript("OnLeave", function(self)
			self.name:SetTextColor(rgb(INK.title))
		end)
		function widget.Fill(self, block, width, open)
			self.place, self.open, self.action = block.place, open, nil
			ns.SetJournalLookArt(self.art, block.lookArt, 0)
			local x = SMALL_ART_W + 14
			self.shelf:SetText(block.value or "")
			bound(self.shelf, 120)
			self.shelf:ClearAllPoints()
			self.shelf:SetPoint("TOPRIGHT", self, "TOPLEFT", width, -6)
			self.name:SetText(block.text)
			self.name:ClearAllPoints()
			self.name:SetPoint("TOPLEFT", x, -4)
			bound(self.name, width - x - self.shelf:GetWidth() - 10)
			self.bar:SetShown(reach)
			self.count:SetShown(reach)
			self.sub:SetShown(not reach)
			self.new:SetShown(not reach and block.note ~= nil)
			if reach then
				ns.JournalInkBarWidth(self.bar, width - x)
				self.bar:ClearAllPoints()
				self.bar:SetPoint("TOPLEFT", x, -30)
				self.bar:Set(block.fill or 0)
				self.count:SetText(block.note or "")
				bound(self.count, width - x)
				self.count:ClearAllPoints()
				self.count:SetPoint("TOPRIGHT", self, "TOPLEFT", width, -44)
				return 66
			end
			self.sub:SetText(block.sub or "")
			self.sub:ClearAllPoints()
			self.sub:SetPoint("TOPLEFT", x, -28)
			bound(self.sub, width - x - 60)
			self.new:SetText(block.note or "")
			bound(self.new, 60)
			self.new:ClearAllPoints()
			self.new:SetPoint("TOPRIGHT", self, "TOPLEFT", width, -28)
			return 52
		end
		return widget
	end
end
ns.RegisterJournalWidget("reachRow", lookRow(true))
ns.RegisterJournalWidget("latelyRow", lookRow(false))

---@class LedgerShopFootWidget: LedgerJournalWidget
---@field rule Texture
---@field words FontString
---@field dots LedgerDotLine

-- The right page's foot (LED-R168): "{n} looks for sale you don't have yet." in italic at the left and the link "Open the
-- Curio Shop" at the right, calling the block's action.
ns.RegisterJournalWidget("shopFoot", function(parent)
	local widget = newWidget(parent) --[[@as LedgerShopFootWidget]]
	ns.JournalClickable(widget)
	widget.rule = ns.JournalTint(widget, INK.rule, 1)
	widget.rule:SetHeight(1)
	widget.rule:SetPoint("TOPLEFT")
	widget.rule:SetPoint("TOPRIGHT")
	widget.words = ns.JournalLabel(widget, "italic", 14, INK.noteLight)
	widget.label = ns.JournalLabel(widget, "print", 18, INK.link, "", { justify = "RIGHT" })
	widget.dots = ns.JournalDotLine(widget, INK.link, 0.5, 2)
	widget:SetScript("OnEnter", function(self)
		self.label:SetTextColor(rgb(INK.red))
	end)
	widget:SetScript("OnLeave", function(self)
		self.label:SetTextColor(rgb(INK.link))
	end)
	function widget.Fill(self, block, width, open)
		self.place, self.open, self.action = nil, open, block.action
		self.label:SetText(block.value or "")
		bound(self.label, width * 0.6)
		self.label:ClearAllPoints()
		self.label:SetPoint("TOPRIGHT", self, "TOPLEFT", width, -10)
		self.words:SetText(block.text or "")
		self.words:ClearAllPoints()
		self.words:SetPoint("TOPLEFT", 0, -14)
		bound(self.words, width - self.label:GetWidth() - 12)
		self.dots:Lay(width - self.label:GetWidth(), 32, self.label:GetWidth())
		return 38
	end
	return widget
end)

-- ---------------------------------------------------------------- a shelf's cards

-- How each layout draws its cards (LED-R169): across, the look's size and the card's height. The look at card size is
-- 176 x 54, a closed book 70 x 92, a shield 56 x 62; the sound set's speaker sits beside the name.
local LAYOUTS = {
	look = { columns = 2, art = { 176, 54 }, height = 118 },
	speaker = { columns = 2, art = { 40, 40 }, height = 58 },
	book = { columns = 4, art = { BOOK_W, BOOK_H }, height = 148 },
	shield = { columns = 5, art = { 56, 62 }, height = 112 },
	pick = { columns = 1, height = 29 },
}
local CARD_GAP = 8
-- A card's art above its name, and the name and tag lines below it.
local ART_TOP, NAME_GAP = 8, 6

---@class LedgerCardView: LedgerJournalClickable
---@field id string?
---@field wasOwned boolean?
---@field layout string
---@field cardW number
---@field paper Texture
---@field edges Texture[]
---@field dashes Frame
---@field chosen Texture[]
---@field art LedgerLookArtView?
---@field name FontString
---@field tag FontString
---@field state FontString
---@field newMark FontString
---@field dot LedgerSpriteTexture
---@field coin LedgerSpriteTexture
---@field radio LedgerSpriteTexture
---@field bar LedgerInkBar
---@field dots LedgerDotLine
---@field hover Texture

-- One card, made at its widget's width and layout.
---@param parent Frame
---@param layout string
---@param cardW number
---@return LedgerCardView
local function newCard(parent, layout, cardW)
	local spec = LAYOUTS[layout]
	local card = CreateFrame("Button", nil, parent) --[[@as LedgerCardView]]
	ns.JournalClickable(card)
	card.layout, card.cardW = layout, cardW
	card:SetSize(cardW, spec.height)
	if layout ~= "pick" then
		card.paper = ns.JournalTint(card, "fff8e4", 0.3, "BACKGROUND")
		card.paper:SetAllPoints()
		card.edges = ns.JournalOutline(card, 0, 0, cardW, spec.height, INK.rule, 1, "BORDER", 1)
		card.dashes = ns.JournalDashes(card, 0, 0, cardW, spec.height, INK.tileInk, 0.45, "BORDER")
		card.art = ns.NewJournalLookArt(card, spec.art[1], spec.art[2])
	else
		card.dots = ns.JournalDotLine(card, INK.noteLight, 0.6, 3)
		card.radio = ns.JournalSprite(card, "Parts", "radio-off", "ARTWORK")
	end
	card.hover = ns.JournalTint(card, "784614", 0.1, "BACKGROUND", 1)
	card.hover:SetAllPoints()
	card.hover:Hide()
	card.chosen = ns.JournalOutline(card, -1, -1, cardW + 2, spec.height + 2, INK.red, 1, "OVERLAY", 2)
	card.name = ns.JournalLabel(card, "print", layout == "pick" and 16 or 16, INK.title, "", { justify = "CENTER" })
	card.tag = ns.JournalLabel(card, "hand", 16, INK.green, "", { justify = "CENTER" })
	card.state = ns.JournalLabel(card, "sc", 13, INK.red, "", { justify = "CENTER" })
	card.newMark = ns.JournalLabel(card, "hand", 17, INK.red, "", { justify = "RIGHT" })
	card.dot = waxDot(card)
	card.coin = coin(card)
	card.bar = ns.JournalInkBar(card, 100)
	card:SetScript("OnEnter", function(self)
		self.hover:Show()
	end)
	card:SetScript("OnLeave", function(self)
		self.hover:Hide()
	end)
	return card
end

-- Draws the card's words: its name and its tag, by the kind of tag (LED-R169): "In use" after a wax dot, "Yours" and "The
-- default" in green hand, the earned text in blue hand over a small ink bar, a price after the coin, "Curio crate", a
-- title's earning line in italic. `mode` is "center" (under the art), "side" (a sound set's, beside its speaker) or
-- "inline" (a title's pick list, the tag at the right of the name's line).
---@param card LedgerCardView
---@param data LedgerCard
---@param width number
---@param top number    -- where the name starts
---@param mode "center"|"side"|"inline"
local function fillWords(card, data, width, top, mode)
	local owned = data.owned
	local kind, tag = data.tagKind, data.tag
	card.name:SetTextColor(rgb(owned and INK.title or INK.faded))
	card.tag:Hide()
	card.state:Hide()
	card.dot:Hide()
	card.coin:Hide()
	card.bar:Hide()
	if mode == "inline" then
		-- the radios' list: the earning line in italic at the right, "signed as" for the title signed with
		ns.JournalRestyle(card.tag, "italic", 13.5, owned and INK.note or INK.faded)
		card.tag:SetJustifyH("RIGHT")
		card.tag:SetText(tag or "")
		card.tag:SetShown(tag ~= nil)
		bound(card.tag, width * 0.5)
		card.tag:ClearAllPoints()
		card.tag:SetPoint("TOPRIGHT", card, "TOPLEFT", width - 8, -8)
		card.name:SetJustifyH("LEFT")
		card.name:SetText(data.name)
		card.name:ClearAllPoints()
		card.name:SetPoint("TOPLEFT", 28, -top)
		bound(card.name, width - 28 - (tag and card.tag:GetWidth() + 14 or 0))
		return
	end
	local side = mode == "side"
	local x0 = 58
	local room = side and width - x0 - 8 or width - 8
	card.name:SetJustifyH(side and "LEFT" or "CENTER")
	card.name:SetText(data.name)
	card.name:ClearAllPoints()
	if side then
		card.name:SetPoint("TOPLEFT", card, "TOPLEFT", x0, -top)
	else
		card.name:SetPoint("TOP", card, "TOPLEFT", width / 2, -top)
	end
	bound(card.name, room)
	local y = top + (side and 22 or 20)
	-- where a line `total` wide starts: the speaker's edge, or centred under the art
	local function startX(total)
		return side and x0 or (width - total) / 2
	end
	if kind == "inUse" then
		card.state:SetText(tag or "")
		card.state:SetShown(true)
		bound(card.state, room - 16)
		local x = startX(16 + card.state:GetWidth())
		ns.JournalBoxAt(card.dot, card, x, y + 1)
		card.dot:Show()
		card.state:ClearAllPoints()
		card.state:SetPoint("TOPLEFT", card, "TOPLEFT", x + 16, -y)
	elseif kind == "price" then
		card.tag:SetShown(true)
		ns.JournalRestyle(card.tag, "print", 15, INK.title)
		card.tag:SetJustifyH("LEFT")
		card.tag:SetText(tag or "")
		bound(card.tag, room - 20)
		local x = startX(20 + card.tag:GetWidth())
		ns.JournalBoxAt(card.coin, card, x, y + 1)
		card.coin:Show()
		card.tag:ClearAllPoints()
		card.tag:SetPoint("TOPLEFT", card, "TOPLEFT", x + 20, -y)
	else
		card.tag:SetShown(tag ~= nil)
		if kind == "earn" then
			ns.JournalRestyle(card.tag, "hand", 16, INK.hand)
		elseif kind == "yours" or kind == "default" then
			ns.JournalRestyle(card.tag, "hand", 16, INK.green)
		else
			ns.JournalRestyle(card.tag, "italic", 13.5, INK.note)
		end
		card.tag:SetJustifyH(side and "LEFT" or "CENTER")
		card.tag:SetText(tag or "")
		bound(card.tag, room)
		card.tag:ClearAllPoints()
		if side then
			card.tag:SetPoint("TOPLEFT", card, "TOPLEFT", x0, -y)
		else
			card.tag:SetPoint("TOP", card, "TOPLEFT", width / 2, -y)
		end
		if kind == "earn" and data.fill then
			card.bar:Show()
			ns.JournalInkBarWidth(card.bar, math.min(100, room))
			card.bar:ClearAllPoints()
			if side then
				card.bar:SetPoint("TOPLEFT", card, "TOPLEFT", x0, -(y + 22))
			else
				card.bar:SetPoint("TOP", card, "TOPLEFT", width / 2, -(y + 22))
			end
			card.bar:Set(data.fill)
		end
	end
end

-- Fills one card with `data` (LedgerCard): its edge solid in ink or dashed in pencil (LED-R170), its art, its words, "new!"
-- at its corner (LED-R169), red ink round the chosen one. `inks` plays the ink-in (LED-R170 Motion).
---@param card LedgerCardView
---@param data LedgerCard
---@param open fun(place: LedgerJournalPlace)
---@param inks boolean
local function fillCard(card, data, open, inks)
	local layout = LAYOUTS[card.layout]
	local width = card.cardW
	card.place, card.open, card.action = data.place, open, nil
	card.id, card.wasOwned = data.id, data.owned
	for _, edge in ipairs(card.chosen) do
		edge:SetShown(data.chosen)
	end
	card.newMark:SetShown(data.new)
	card.newMark:SetText(data.new and ns.L.COLLECTION_NEW_MARK or "")
	card.newMark:ClearAllPoints()
	if inks and data.new then
		ns.JournalInk(card.newMark)
	end
	if card.layout == "pick" then
		ns.JournalSetSprite(card.radio, "Parts", data.tagKind == "signed" and "radio-on" or "radio-off")
		ns.JournalBoxAt(card.radio, card, 2, 8)
		card.radio:SetAlpha(data.owned and 1 or 0.45)
		card.dots:Lay(0, layout.height - 1, width)
		fillWords(card, data, width, 5, "inline")
		card.newMark:SetPoint("TOPLEFT", card, "TOPLEFT", -2, 3)
		card.newMark:SetJustifyH("LEFT")
		return
	end
	-- solid in ink, dashed in pencil (a look not owned, or put away)
	for _, edge in ipairs(card.edges) do
		edge:SetShown(data.owned)
	end
	card.paper:SetShown(data.owned)
	card.dashes:SetShown(not data.owned)
	local art = card.art --[[@as LedgerLookArtView]]
	art:ClearAllPoints()
	if card.layout == "speaker" then
		art:SetPoint("TOPLEFT", card, "TOPLEFT", 10, -9)
	else
		art:SetPoint("TOP", card, "TOPLEFT", width / 2, -ART_TOP)
	end
	ns.SetJournalLookArt(art, data.art, data.owned and 0 or 1)
	if inks then
		ns.InkInJournalLookArt(art)
	end
	card.newMark:SetPoint("TOPRIGHT", card, "TOPRIGHT", -5, 1)
	card.newMark:SetJustifyH("RIGHT")
	if card.layout == "speaker" then
		fillWords(card, data, width, 10, "side")
	else
		fillWords(card, data, width, ART_TOP + layout.art[2] + NAME_GAP, "center")
	end
end

---@class LedgerCardsWidget: LedgerJournalWidget
---@field views LedgerCardView[]
---@field layout string?
---@field cardW number?

-- A shelf's cards (LED-R169): `layout` says how many across and how each is drawn; a card opens its shelf with it chosen.
ns.RegisterJournalWidget("cards", function(parent)
	local widget = newWidget(parent) --[[@as LedgerCardsWidget]]
	widget.views = {}
	function widget.Fill(self, block, width, open, draw)
		local layout = block.layout or "look"
		local spec = LAYOUTS[layout]
		local gap = layout == "pick" and 0 or CARD_GAP
		local cardW = (width - (spec.columns - 1) * gap) / spec.columns
		if self.layout ~= layout or self.cardW ~= cardW then
			for _, view in ipairs(self.views) do
				view:Hide()
			end
			self.views, self.layout, self.cardW = {}, layout, cardW
		end
		local list = block.cards or {}
		local same = ns.JournalRemember(self, draw, "cards:" .. layout, nil)
		for i, data in ipairs(list) do
			local view = self.views[i] or newCard(self, layout, cardW)
			self.views[i] = view
			-- a look that turned owned while its shelf is shown inks in; so does one that is new when first drawn (LED-R170)
			local turned = same and view.id == data.id and view.wasOwned == false and data.owned
			local column, row = (i - 1) % spec.columns, math.floor((i - 1) / spec.columns)
			ns.JournalAt(view, self, column * (cardW + gap), row * (spec.height + gap))
			fillCard(view, data, open, (turned or (data.new and data.owned)) and layout ~= "pick" and true or false)
			view:Show()
		end
		for i = #list + 1, #self.views do
			self.views[i]:Hide()
		end
		local rows = math.ceil(#list / spec.columns)
		return math.max(0, rows * (spec.height + gap) - gap)
	end
	return widget
end)

-- ---------------------------------------------------------------- the chosen look's stage and state

-- The stage's size (LED-R170, ledger.md › UI): 380 wide, the page body's 382 less a hair, and the well as tall as
-- Core's stage for a look: Pagle.DrawGoodPreview's "stage" is the shop's 390 x 190 (SHOP-R36), so the well is that and
-- the 2 of its rim each side, 194; the preview's frame, inside the rim, is wide enough for the widest sample toast
-- (464 at 0.8) and holds the whole stage, nothing of it past the well. A title's paper well is 156. Where the look
-- isn't owned, "A look before you have it" is under the well on the paper, in a line of its own.
local STAGE_W, LOOK_H, TITLE_H, RIM = 380, 194, 156, 2
local CAPTION_GAP, CAPTION_H = 4, 18
local STAGE_DARK, STAGE_RIM = "0d2a30", "e8c96a"

---@class LedgerStageWidget: LedgerJournalWidget
---@field well Texture
---@field rim Texture[]
---@field preview Frame
---@field signed FontString
---@field words FontString
---@field line FontString
---@field foot FontString

-- The stage of the chosen look: a dark well with a gilt rim, the look drawn into it by Core (Pagle.DrawGoodPreview,
-- "stage") in its colours whatever its state, "A look before you have it" under the well while it isn't owned; a title
-- is a paper well with "Signed as", the title in the hand and the Angler's name and level.
ns.RegisterJournalWidget("stage", function(parent)
	local widget = newWidget(parent) --[[@as LedgerStageWidget]]
	widget.well = ns.JournalTint(widget, STAGE_DARK, 1, "BACKGROUND")
	widget.rim = ns.JournalOutline(widget, 0, 0, STAGE_W, LOOK_H, STAGE_RIM, 1, "BORDER", RIM)
	widget.preview = CreateFrame("Frame", nil, widget)
	widget.preview:SetSize(STAGE_W - 2 * RIM, LOOK_H - 2 * RIM)
	widget.preview:SetClipsChildren(true)
	widget.signed = ns.JournalLabel(widget, "sc", 14, INK.kicker, "", { justify = "CENTER" })
	widget.words =
		ns.JournalLabel(widget, "hand", 34, INK.hand, "", { justify = "CENTER", wrap = true, width = STAGE_W - 30 })
	widget.line = ns.JournalLabel(widget, "italic", 15, INK.note, "", { justify = "CENTER" })
	widget.foot = ns.JournalLabel(widget, "italic", 13.5, INK.noteLight, "", { justify = "CENTER" })
	function widget.Fill(self, block, width)
		local x = math.max(0, (width - STAGE_W) / 2)
		local title = block.lookArt == nil
		local height = title and TITLE_H or LOOK_H
		local well, rim = title and "efe0bb" or STAGE_DARK, title and INK.tileInk or STAGE_RIM
		self.well:SetColorTexture(rgb(well))
		self.well:SetSize(STAGE_W, height)
		ns.JournalAt(self.well, self, x, 0)
		for _, edge in ipairs(self.rim) do
			local r, g, b = rgb(rim)
			edge:SetColorTexture(r, g, b, 1)
		end
		self.rim[3]:SetHeight(height)
		self.rim[4]:SetHeight(height)
		ns.JournalAt(self.rim[1], self, x, 0)
		ns.JournalAt(self.rim[2], self, x, height - RIM)
		ns.JournalAt(self.rim[3], self, x, 0)
		ns.JournalAt(self.rim[4], self, x + STAGE_W - RIM, 0)
		self.preview:SetShown(not title)
		self.signed:SetShown(title)
		self.words:SetShown(title)
		self.line:SetShown(title)
		if title then
			self.signed:SetText(block.sub or "")
			ns.JournalAt(self.signed, self, x + STAGE_W / 2 - 100, 34)
			self.signed:SetWidth(200)
			self.words:SetText(block.text or "")
			self.words:ClearAllPoints()
			self.words:SetPoint("TOP", self, "TOPLEFT", x + STAGE_W / 2, -58)
			self.line:SetText((block.lines or {})[1] or "")
			self.line:SetWidth(STAGE_W - 30)
			self.line:ClearAllPoints()
			self.line:SetPoint("TOP", self, "TOPLEFT", x + STAGE_W / 2, -(TITLE_H - 44))
		else
			self.preview:ClearAllPoints()
			self.preview:SetPoint("TOPLEFT", self, "TOPLEFT", x + RIM, -RIM)
			Pagle.DrawGoodPreview(self.preview, block.lookArt.good, "stage")
		end
		self.foot:SetShown(block.note ~= nil)
		self.foot:SetText(block.note or "")
		self.foot:SetWidth(STAGE_W - 20)
		self.foot:ClearAllPoints()
		self.foot:SetPoint("TOP", self, "TOPLEFT", x + STAGE_W / 2, -(height + CAPTION_GAP))
		return block.note and height + CAPTION_GAP + CAPTION_H or height
	end
	return widget
end)

---@class LedgerUseRowWidget: LedgerJournalWidget
---@field seal LedgerSeal
---@field face LedgerButton
---@field words FontString
---@field sub FontString

local SEAL_SIZE = 64

-- The state of a look under its description (LED-R170): a button ("Use it", "Wear it", "Sign with it", "Buy in the Curio
-- Shop", "Open a crate") calling the block's action, or the wax seal "In use", then in the hand what it does and in
-- italic how it came. Where the seal takes the button's place on the page, it is pressed on from 2.2 times its size
-- (0.45 s, overshooting) with the Journal's seal sound, which plays with Animations off too (LED-R173 Motion).
ns.RegisterJournalWidget("useRow", function(parent)
	local widget = newWidget(parent) --[[@as LedgerUseRowWidget]]
	widget.seal = ns.JournalSeal(widget, SEAL_SIZE, 12)
	widget.face = ns.JournalButton(widget)
	widget.words = ns.JournalLabel(widget, "hand", 20, INK.brown, "", { wrap = true, spacing = 2 })
	widget.sub = ns.JournalLabel(widget, "italic", 14, INK.note, "", { wrap = true, spacing = 3 })
	function widget.Fill(self, block, width, _, draw)
		local sealed = block.seal ~= nil
		local same, before = ns.JournalRemember(self, draw, "useRow", sealed and "seal" or "button")
		self.seal:SetShown(sealed)
		self.face:SetShown(not sealed)
		local x, height
		Pagle.StopMotion(self.seal)
		self.seal:SetSize(SEAL_SIZE, SEAL_SIZE)
		self.seal:SetAlpha(1)
		if sealed then
			ns.JournalSetSeal(self.seal, block.seal, true)
			self.seal:ClearAllPoints()
			self.seal:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -2)
			x, height = SEAL_SIZE + 10, SEAL_SIZE + 4
			if same and before == "button" then
				self.seal:ClearAllPoints()
				self.seal:SetPoint("CENTER", self, "TOPLEFT", SEAL_SIZE / 2, -(SEAL_SIZE / 2 + 2))
				if ns.MotionOn() then
					Pagle.Animate(self.seal, {
						{
							dur = 0.45,
							ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
							keys = { { 0, { 2.2, 0 } }, { 0.7, { 0.94, 1 } }, { 1, { 1, 1 } } },
							apply = function(v)
								self.seal:SetSize(SEAL_SIZE * v[1], SEAL_SIZE * v[1])
								self.seal:SetAlpha(v[2])
							end,
						},
					})
				end
				-- the seal sounds whether things move or not (LED-R173)
				PlaySound(ns.JOURNAL_SOUNDS.stamp, "SFX")
			end
		else
			self.face.action = block.action
			ns.JournalSetButton(self.face, block.button or "")
			self.face:ClearAllPoints()
			self.face:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -4)
			x, height = self.face:GetWidth() + 14, 42
		end
		local room = math.max(60, width - x)
		self.words:SetShown(block.text ~= nil)
		self.words:SetText(block.text or "")
		self.words:SetWidth(room)
		self.words:ClearAllPoints()
		self.words:SetPoint("TOPLEFT", self, "TOPLEFT", x, -6)
		local top = block.text and self.words:GetStringHeight() + 2 or 0
		self.sub:SetShown(block.sub ~= nil)
		self.sub:SetText(block.sub or "")
		self.sub:SetWidth(room)
		self.sub:ClearAllPoints()
		self.sub:SetPoint("TOPLEFT", self, "TOPLEFT", x, -(sealed and 8 + top or 12))
		if sealed then
			return math.max(height, 8 + top + (block.sub and self.sub:GetStringHeight() + 2 or 0))
		end
		return math.max(height, 12 + (block.sub and self.sub:GetStringHeight() + 2 or 0))
	end
	return widget
end)

---@class LedgerPriceWidget: LedgerJournalWidget
---@field coin LedgerSpriteTexture
---@field label FontString

-- The room the price's coin takes: its sprite, shadow's margin and all, and 4 before the figure.
local COIN_ROOM = 32

-- A look's price with the Curio Shop's coin (LED-R170).
ns.RegisterJournalWidget("price", function(parent)
	local widget = newWidget(parent) --[[@as LedgerPriceWidget]]
	widget.coin = ns.JournalSprite(widget, "Shop", "coin-small", "ARTWORK", 0, 20)
	widget.label = ns.JournalLabel(widget, "print", 21, INK.title)
	function widget.Fill(self, block, width)
		-- The coin's sprite has its shadow's margin round its 20 x 20 box: the box sits that far in, so the whole
		-- sprite is on the page and none of it is clipped at the page body's left edge.
		local margin = self.coin.box[1]
		ns.JournalBoxAt(self.coin, self, margin, margin)
		self.label:SetText(block.value or "")
		self.label:ClearAllPoints()
		self.label:SetPoint("TOPLEFT", COIN_ROOM, -2)
		bound(self.label, width - COIN_ROOM)
		return 28
	end
	return widget
end)

---@class LedgerCountWidget: LedgerJournalWidget
---@field bar LedgerInkBar
---@field label FontString

-- A look to earn's count (LED-R170): an ink bar and "{have} of {need} {unit}" in the hand under it.
ns.RegisterJournalWidget("count", function(parent)
	local widget = newWidget(parent) --[[@as LedgerCountWidget]]
	widget.bar = ns.JournalInkBar(widget, 200)
	widget.bar:SetPoint("TOPLEFT", 0, -4)
	widget.label = ns.JournalLabel(widget, "hand", 19, INK.hand)
	function widget.Fill(self, block, width)
		ns.JournalInkBarWidth(self.bar, math.min(width, 300))
		self.bar:Set(block.fill or 0)
		self.label:SetText(block.text or "")
		self.label:ClearAllPoints()
		self.label:SetPoint("TOPLEFT", 0, -22)
		bound(self.label, width)
		return 46
	end
	return widget
end)
