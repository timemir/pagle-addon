---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Curio Shop window (wallet-and-shop.md › UI), drawn with the shop art kit as a travelling merchant's sample case:
-- the purse on the case's top band, the green velvet tray on the left with the search slip, the filters, the category
-- chips and the goods, and the quilted lid on the right with the showcase card (the preview stage) and the
-- description card. Buy asks with a bill of sale over the dimmed case. What it shows is logic/Shop.lua's model, read
-- afresh at each redraw; this file only draws it, from the atlases in data/ShopArt.lua and the pieces in
-- adapter/ShopArt.lua, and moves it with adapter/ShopMotion.lua's motion and sounds. It opens only through ns.shop (logic/Wiring.lua's ns.WireShop): Pagle.OpenShop, /pagle shop and
-- the compartment entry, never on its own. Every position is the canvas's, in UI units from the case's top left, y
-- growing downward.
local L = ns.L

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleCurioShop"
-- The case's drawn size; its handle stands above it.
local WIDTH, HEIGHT = 980, 640
-- The velvet tray, inside the case.
local TRAY_X, TRAY_Y, TRAY_W, TRAY_H = 22, 98, 470, 520
-- The search slip, the filters' row and the first chips' row, from the tray's top; the room the chips wrap in.
local FIND_Y, FILTER_Y, CHIP_Y, CONTROLS_W = 14, 59, 98, 438
-- The goods: their inset in the tray, a row's width and height, a slot's header's height.
local LIST_X, ROW_W, ROW_H, HEADER_H = 16, 432, 44, 31
-- The cards on the lid: the showcase card's top left; the stage inside it (the card's dark well, 370 x 132, centred
-- at its top, the paper round and under it; as wide as the toast styles' sample toast, 464 at 0.8, needs); the
-- description card under the showcase card, stretched to INFO_H.
local CARD_X, CARD_Y = 534, 159
local STAGE_X, STAGE_Y, STAGE_W, STAGE_H, WELL_H = 6, 16, 390, 190, 132
local INFO_Y, INFO_H, INFO_PAD = 385, 220, 20
-- The purse: the coin, then the label over the balance; the bar's right end, and its top with and without the held
-- line under it.
local PURSE_TEXT_X, BAR_RIGHT, BAR_Y, BAR_Y_HELD = 94, WIDTH - 74, 31, 24
-- Each paying Module's segment sprite and legend dot (shop.css's --board, --ledger, --hunts); any other Module's.
local SEGMENTS = {
	TackleBoard = { "seg-board", { 0.847, 0.604, 0.29 } },
	Ledger = { "seg-ledger", { 0.659, 0.251, 0.18 } },
	Hunts = { "seg-hunts", { 0.29, 0.596, 0.58 } },
}
local OTHER_SEGMENT = { "seg-board", { 0.6, 0.6, 0.6 } }
-- A faded segment's opacity (a Module off), and a greyed row's (Put away).
local OFF_ALPHA, GREYED_ALPHA = 0.45, 0.55
-- What separates tags on the stage.
local TAG_SEPARATOR = " · "
-- The bill of sale: its paper's size and top left on the case; where its wax seal lands, from the paper's top left.
local BILL_W, BILL_H, BILL_X, BILL_Y = 400, 420, 290, 56
local SEAL_X, SEAL_Y = 342, 300
-- The bill's medallion's top left on the case, and a row's medallion's size and inset.
local BILL_BEZEL_X, BILL_BEZEL_Y, ROW_BEZEL, ROW_BEZEL_X = BILL_X + (BILL_W - 64) / 2, BILL_Y + 111, 34, 8
-- The purse's coin's centre on the case: it turns about it as the purse pays out.
local PURSE_COIN_X, PURSE_COIN_Y = 56, 51
-- Fitting the screen: the case's whole extent with its handle above it, and how far its centre sits from the screen's.
local EXTENT_W, EXTENT_H, CENTRE_DY = 1000, 680, -20

---@class PagleShopSegmentFrame: Frame
---@field bar PagleSprite             the segment's colour on the bar
---@field separator Texture           the hairline before every segment but the first
---@field dot PagleSprite             the legend's dot
---@field legend PagleShopFontString  "Ledger 1,500"
---@field strike Texture              strikes the legend through while its Module is off
---@field share number                its part of the bar, 0 to 1
---@field tooltip string[]

---@class PagleShopTip: Frame
---@field head PagleShopFontString
---@field lines PagleShopFontString[] pooled: the shown ones are the tip's lines after its head

---@class PagleShopPurseFrame
---@field coin PagleSprite
---@field label PagleShopFontString   "PAGLE COINS"
---@field balance PagleShopFontString
---@field bar PagleThreeSlice
---@field held PagleShopFontString    SHOP-R12's held line, shown while the balance is held at 0
---@field segments PagleShopSegmentFrame[] pooled: the shown ones are the purse's
---@field tip PagleShopTip            a segment's tooltip, in the book's voice

---@class PagleShopPriceTag: Frame, PagleThreeSlice
---@field amount PagleShopFontString
---@field coin PagleSprite
---@field string PagleSprite          the tag's string, tied to its hole

---@class PagleShopLine: Button
---@field header boolean              a group's header, not a good's row
---@field goodID string?              a row's good
---@field label PagleShopFontString   a header's label, or a row's name
---@field count PagleShopFontString   a header's owned count or note
---@field rule PagleSprite            a header's rule between its label and count
---@field bezel PagleShopBezel        a row's medallion, with the good's icon
---@field tag PagleShopFontString     a row's tag: "IN USE", "Owned", "default", an earnedText, "Hunts is off"
---@field wax PagleSprite             the wax dot before "IN USE"
---@field price PagleShopPriceTag     a row's price tag, for a good for sale
---@field selectedMark PagleThreeSlice the gilt band under the selected good's row
---@field hover Texture
---@field listY number                where it sits in the list, from the scroll child's top
---@field glow Texture?               the warm glow a row gives once as a purchase is delivered to it
---@field stepDown PagleShopFontString? the slot's old good's new tag, fading in as a purchase takes its place

---@class PagleShopStageFrame
---@field card PagleSprite            the showcase card, its dark well at the top
---@field area Frame                  where previews draw, clipped to the card
---@field previews table<string, Frame> each good's own stage frame, made at its first preview
---@field swatch PagleShopBezel       the good's icon in a medallion, for a good with no preview
---@field hint PagleShopFontString    "Pick a look to see it here." with nothing selected
---@field info PagleSprite            the description card
---@field name PagleShopFontString
---@field slotLine PagleShopFontString
---@field description PagleShopFontString
---@field notes PagleShopFontString
---@field tags PagleShopFontString
---@field buy PagleShopPill           "Buy for N" and the coin
---@field needed PagleShopFontString  "N more Coins"
---@field use PagleShopPill
---@field short Button                over Buy while the balance doesn't cover it: a click shakes "N more Coins"

---@class PagleShopCheck: CheckButton
---@field box PagleSprite
---@field tick PagleSprite
---@field label PagleShopFontString

--- The bill of sale (wallet-and-shop.md › UI: Buy): over the dimmed case, it asks "Buy {name}?".
---@class PagleShopBill: PagleShopBillMotion
---@field slip Frame
---@field shade Texture                the case's dimming
---@field seal PagleSprite             the wax seal a purchase presses on
---@field head PagleShopFontString     "CURIO SHOP"
---@field question PagleShopFontString "Buy Ripple?"
---@field bezel PagleShopBezel
---@field priceLabel PagleShopFontString
---@field price PagleShopFontString
---@field coin PagleSprite
---@field leftLabel PagleShopFontString
---@field left PagleShopFontString
---@field fine PagleShopFontString     "Looks are yours for good."
---@field useNow PagleShopCheck        "Use it now", ticked at each asking
---@field buy PagleShopPill
---@field cancel Button
---@field cancelLabel PagleShopFontString
---@field goodID string?               the good it asks about

---@class PagleShopSearchBox: EditBox
---@field Instructions PagleShopFontString "Find a look…", shown while the box is empty

---@class PagleShopScrollBar: Slider
---@field track Texture
---@field thumb PagleSprite

---@class PagleShopFrame: Frame
---@field case PagleSprite            the sample case: leather, tray, hinge, lid and its trade label
---@field CloseButton Button
---@field purse PagleShopPurseFrame
---@field search PagleShopSearchBox
---@field filters table<string, PagleShopPill> by filter
---@field chips PagleShopPill[]       pooled: All, then a chip per category a live slot uses
---@field scroll ScrollFrame
---@field scrollBar PagleShopScrollBar
---@field content Frame               the list's scroll child
---@field lines PagleShopLine[]       pooled: the shown ones are the list, in order
---@field empty PagleShopFontString   "No looks match."
---@field stage PagleShopStageFrame
---@field bill PagleShopBill
---@field flyer PagleShopBezel        the medallion a purchase flies from the bill to its row
---@field listTop number              the list's top, from the case's

--- The window, made the first time it opens.
---@type PagleShopFrame?
ns.shopFrame = nil

-- What the player has narrowed the list to and selected; kept while the window closes and opens again.
---@type PagleShopQuery
local query = { filter = "all" }
---@type string?
local selected
-- A purchase whose motion is playing (adapter/ShopMotion.lua): the window redraws once it settles. `committing` while
-- ns.shop.Buy runs, whose events would draw the settled state at once; any other redraw meanwhile settles it early.
---@type { committing: true? }?
local playing

local redraw, askToBuy, buy

-- Anchors `region` with its top left `x`, `y` from `relativeTo`'s top left (y grows downward).
---@param region Region
---@param relativeTo Region
---@param x number
---@param y number
local function at(region, relativeTo, x, y)
	region:ClearAllPoints()
	region:SetPoint("TOPLEFT", relativeTo, "TOPLEFT", x, -y)
end

-- A texture of one colour on `frame`.
---@param frame Frame
---@param r number
---@param g number
---@param b number
---@param a number
---@param layer DrawLayer?
---@param sublevel integer?
---@return Texture
local function solid(frame, r, g, b, a, layer, sublevel)
	local texture = frame:CreateTexture(nil, layer or "ARTWORK", nil, sublevel or 0)
	texture:SetColorTexture(r, g, b, a)
	return texture
end

-- Hides the bill of sale if it is up, buying nothing: at once, or lifting it away (Cancel and Esc) while it still asks.
---@param frame PagleShopFrame
---@param lift boolean?
local function closeBill(frame, lift)
	local bill = frame.bill
	if lift then
		if bill.goodID and bill:IsShown() then
			bill.goodID = nil
			ns.CloseShopBill(bill, BILL_X, BILL_Y)
		end
		return
	end
	bill.goodID = nil
	ns.StopMotion(bill)
	bill:Hide()
end

-- Settles a purchase's motion (adapter/ShopMotion.lua), where it stopped or, `finished`, once it has played out: what
-- only the motion showed goes, and the next redraw draws the rest. Played out, nothing is stopped: the driver is
-- still walking what plays, and stopping an owner it no longer plays would add a key to the table it walks.
---@param frame PagleShopFrame
---@param finished boolean?
local function settlePurchase(frame, finished)
	if not playing then
		return
	end
	playing = nil
	if not finished then
		ns.StopMotion(frame)
	end
	local bill = frame.bill
	bill.seal:Hide()
	bill.bezel:Show()
	bill.buy:SetAlpha(1)
	frame.flyer:Hide()
	if not bill.goodID and bill:IsShown() then
		closeBill(frame)
	end
	local coin = frame.purse.coin
	coin:SetWidth(coin.w0 or coin:GetWidth())
end

-- Closes the window and its bill of sale, giving back the keyboard: a hidden edit box would keep it.
---@param frame PagleShopFrame
local function close(frame)
	closeBill(frame)
	frame.search:ClearFocus()
	frame:Hide()
end

-- The tooltip under a segment (wallet-and-shop.md › UI: the purse), in the book's voice: dark, edged in gilt, its
-- first line the head.
---@param frame PagleShopFrame
---@return PagleShopTip
local function buildTip(frame)
	local tip = CreateFrame("Frame", nil, frame) --[[@as PagleShopTip]]
	tip:SetFrameLevel(frame:GetFrameLevel() + 30)
	local edge = solid(tip, 0.788, 0.635, 0.29, 1, "BACKGROUND", 0)
	edge:SetAllPoints()
	local fill = solid(tip, 0.11, 0.07, 0.04, 0.97, "BACKGROUND", 1)
	fill:SetPoint("TOPLEFT", 1, -1)
	fill:SetPoint("BOTTOMRIGHT", -1, 1)
	tip.head = ns.ShopText(tip, "TipHead")
	tip.head:SetPoint("TOPLEFT", 14, -10)
	tip.lines = {}
	tip:Hide()
	return tip
end

-- Shows the tip with `lines` under `owner`, the first line its head.
---@param tip PagleShopTip
---@param owner Region
---@param lines string[]
local function showTip(tip, owner, lines)
	ns.SetShopText(tip.head, lines[1])
	local width = tip.head:GetStringWidth()
	for i = 2, #lines do
		local line = tip.lines[i - 1]
		if not line then
			line = ns.ShopText(tip, "Tip")
			tip.lines[i - 1] = line
		end
		at(line, tip, 14, 30 + (i - 2) * 21)
		ns.SetShopText(line, lines[i])
		line:Show()
		width = math.max(width, line:GetStringWidth())
	end
	for i = #lines, #tip.lines do
		tip.lines[i]:Hide()
	end
	tip:SetSize(math.max(210, width + 28), 30 + (#lines - 1) * 21 + 10)
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -34)
	tip:Show()
end

-- The purse (wallet-and-shop.md › UI) on the case's top band: the coin, "PAGLE COINS" over the balance, the income
-- bar with its legend, and SHOP-R12's held line.
---@param frame PagleShopFrame
---@return PagleShopPurseFrame
local function buildPurse(frame)
	local purse = {}
	purse.coin = ns.SetShopCoin(ns.ArtSprite(frame, "Shop", "coin", "ARTWORK", 1), 52)
	ns.CenterSpriteAt(purse.coin, frame, PURSE_COIN_X, PURSE_COIN_Y)
	purse.label = ns.ShopText(frame, "PurseLab")
	at(purse.label, frame, PURSE_TEXT_X, 27)
	purse.balance = ns.ShopText(frame, "Balance")
	at(purse.balance, frame, PURSE_TEXT_X, 43)
	purse.bar = CreateFrame("Frame", nil, frame) --[[@as PagleThreeSlice]]
	purse.held = ns.ShopText(frame, "Held")
	ns.SetShopText(purse.held, L.SHOP_HELD)
	purse.segments = {}
	purse.tip = buildTip(frame)
	return purse --[[@as PagleShopPurseFrame]]
end

-- The pooled segment `i`: its part of the bar, its legend dot and entry, and the line that strikes it through.
---@param frame PagleShopFrame
---@param i integer
---@return PagleShopSegmentFrame
local function segmentAt(frame, i)
	local purse = frame.purse
	local segment = purse.segments[i]
	if segment then
		return segment
	end
	segment = CreateFrame("Frame", nil, purse.bar) --[[@as PagleShopSegmentFrame]]
	segment:EnableMouse(true)
	segment.bar = ns.ArtSprite(segment, "Shop", "seg-board", "ARTWORK", 0)
	segment.separator = solid(segment, 0, 0, 0, 0.5, "ARTWORK", 1)
	segment.separator:SetWidth(1)
	segment.separator:SetPoint("TOPLEFT")
	segment.separator:SetPoint("BOTTOMLEFT")
	segment.dot = ns.ArtSprite(frame, "Shop", "dot", "ARTWORK", 1)
	segment.legend = ns.ShopText(frame, "Legend")
	segment.strike = frame:CreateTexture(nil, "OVERLAY", nil, 1)
	local ink = ns.SHOP_INKS.strike
	segment.strike:SetColorTexture(ink[1], ink[2], ink[3], 0.8)
	segment.strike:SetHeight(1.5)
	segment.strike:SetPoint("LEFT", segment.legend, "LEFT", 0, -1)
	segment.strike:SetPoint("RIGHT", segment.legend, "RIGHT", 0, -1)
	segment:SetScript("OnEnter", function(self)
		showTip(purse.tip, self, self.tooltip)
	end)
	segment:SetScript("OnLeave", function()
		purse.tip:Hide()
	end)
	purse.segments[i] = segment
	return segment
end

-- Draws the purse from `purse`: the bar from the balance's right to BAR_RIGHT, raised a little when the held line
-- shows under it; one segment per Module that has reported, left to right, each as wide as its share, faded and
-- greyed with its legend struck through while its Module is off.
---@param frame PagleShopFrame
---@param purse PagleShopPurse
local function drawPurse(frame, purse)
	local shown = frame.purse
	ns.SetShopText(shown.label, purse.label)
	ns.SetShopText(shown.balance, purse.balance)
	local x0 = PURSE_TEXT_X + math.max(shown.label:GetStringWidth(), shown.balance:GetStringWidth()) + 26
	local barWidth = BAR_RIGHT - x0
	local barY = purse.held and BAR_Y_HELD or BAR_Y
	ns.SetThreeSlice(shown.bar, "Shop", "ibar", barWidth, 8, "ARTWORK")
	at(shown.bar, frame, x0, barY)
	at(shown.held, frame, x0, barY + 47)
	shown.held:SetWidth(barWidth)
	shown.held:SetShown(purse.held) -- SHOP-R12: the balance reads 0 meanwhile
	local inner = barWidth - 4
	local x, legendX = 2, x0
	for i, data in ipairs(purse.segments) do
		local segment = segmentAt(frame, i)
		local look = SEGMENTS[data.module] or OTHER_SEGMENT
		segment.share = data.share
		segment.tooltip = data.tooltip
		local width = math.max(inner * data.share, 1)
		segment:SetSize(width, 10)
		at(segment, shown.bar, x, 2)
		ns.SetSprite(segment.bar, "Shop", look[1])
		segment.bar:SetAllPoints()
		segment.bar:SetDesaturated(data.off or look == OTHER_SEGMENT)
		segment.separator:SetShown(i > 1)
		segment:SetAlpha(data.off and OFF_ALPHA or 1)
		x = x + inner * data.share
		local color = look[2]
		segment.dot:SetVertexColor(color[1], color[2], color[3], data.off and 0.5 or 1)
		ns.PlaceSprite(segment.dot, frame, legendX, barY + 27)
		ns.SetShopFont(segment.legend, data.off and "LegendOff" or "Legend")
		ns.SetShopText(segment.legend, data.legend)
		at(segment.legend, frame, legendX + 15, barY + 21)
		legendX = legendX + 15 + segment.legend:GetStringWidth() + 16
		segment:Show()
		segment.dot:Show()
		segment.legend:Show()
		segment.strike:SetShown(data.off)
	end
	for i = #purse.segments + 1, #shown.segments do
		local segment = shown.segments[i]
		segment:Hide()
		segment.dot:Hide()
		segment.legend:Hide()
		segment.strike:Hide()
	end
end

-- The tray's controls (wallet-and-shop.md › UI): the search slip, the four filters, then the chips' rows; each
-- redraws.
---@param frame PagleShopFrame
local function buildControls(frame)
	local slip = ns.ArtSprite(frame, "Shop", "find", "ARTWORK", 1)
	ns.PlaceSprite(slip, frame, TRAY_X + LIST_X, TRAY_Y + FIND_Y)
	local search = CreateFrame("EditBox", nil, frame) --[[@as PagleShopSearchBox]]
	frame.search = search
	search:SetSize(CONTROLS_W - 43, 36)
	at(search, frame, TRAY_X + LIST_X + 35, TRAY_Y + FIND_Y)
	search:SetAutoFocus(false)
	search:SetFontObject(ns.SHOP_FONTS.Find)
	local ink = ns.SHOP_INKS.ink
	search:SetTextColor(ink[1], ink[2], ink[3])
	search.Instructions = ns.ShopText(search, "FindHint")
	search.Instructions:SetPoint("LEFT")
	ns.SetShopText(search.Instructions, L.SHOP_SEARCH)
	search:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		self.Instructions:SetShown(text == "")
		query.search = text
		redraw(false)
	end)
	-- A focused edit box takes Esc before UISpecialFrames does: Esc there closes the shop too.
	search:SetScript("OnEscapePressed", function()
		close(frame)
	end)
	search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)

	frame.filters = {}
	for _, filter in ipairs(ns.SHOP_FILTERS) do
		frame.filters[filter] = ns.NewShopPill(frame, function()
			query.filter = filter
			redraw(false)
		end)
	end
	frame.chips = {}
end

-- Lays out the filters, the one on pressed.
---@param frame PagleShopFrame
local function drawFilters(frame)
	local x = TRAY_X + LIST_X
	for _, filter in ipairs(ns.SHOP_FILTERS) do
		local pill = frame.filters[filter]
		pill.pressed = filter == (query.filter or "all")
		local width = ns.SetShopPill(
			pill,
			pill.pressed and "flt-on" or "flt",
			pill.pressed and "PillOn" or "Pill",
			L.SHOP_FILTERS[filter],
			12,
			15
		)
		at(pill, frame, x, TRAY_Y + FILTER_Y)
		x = x + width + 6
	end
end

-- Lays out the chips from `chips` (All first), wrapping them in the tray's width, the chosen one pressed; returns
-- how far down the tray the list starts.
---@param frame PagleShopFrame
---@param chips PagleShopChip[]
---@return number top the list's top, from the case's
local function drawChips(frame, chips)
	local all = { { label = L.SHOP_ALL_CATEGORIES } }
	for _, chip in ipairs(chips) do
		all[#all + 1] = chip
	end
	local left = TRAY_X + LIST_X
	local x, y = left, TRAY_Y + CHIP_Y
	for i, chip in ipairs(all) do
		local category = chip.category
		local made = frame.chips[i]
		if not made then
			made = ns.NewShopPill(frame)
			frame.chips[i] = made
		end
		made:SetScript("OnClick", function()
			query.category = category
			redraw(false)
		end)
		made.pressed = category == query.category
		local width = ns.SetShopPill(
			made,
			made.pressed and "chip-on" or "chip",
			made.pressed and "ChipOn" or "Chip",
			chip.label,
			11,
			10
		)
		if x + width > left + CONTROLS_W then
			x, y = left, y + 34
		end
		at(made, frame, x, y)
		x = x + width + 6
		made:Show()
	end
	for i = #all + 1, #frame.chips do
		frame.chips[i]:Hide()
	end
	return y + 28 + 12
end

-- The pooled list line `i`, made with what a header and a row show; a line is either for good.
---@param frame PagleShopFrame
---@param i integer
---@return PagleShopLine
local function lineAt(frame, i)
	local line = frame.lines[i]
	if line then
		return line
	end
	line = CreateFrame("Button", nil, frame.content) --[[@as PagleShopLine]]
	line:SetWidth(ROW_W)
	line.selectedMark = CreateFrame("Frame", nil, line) --[[@as PagleThreeSlice]]
	line.selectedMark:SetFrameLevel(line:GetFrameLevel())
	ns.SetThreeSlice(line.selectedMark, "Shop", "good-sel", ROW_W + 12, 16, "BACKGROUND")
	at(line.selectedMark, line, -12, 0)
	line.hover = solid(line, 1, 0.94, 0.78, 0.05, "HIGHLIGHT")
	line.hover:SetAllPoints()
	-- a header's
	line.label = ns.ShopText(line, "Good")
	line.count = ns.ShopText(line, "SlotCount")
	line.count:SetPoint("TOPRIGHT", 0, -10)
	line.rule = ns.ArtSprite(line, "Shop", "slot-rule", "ARTWORK")
	line.rule:ClearAllPoints()
	line.rule:SetPoint("LEFT", line.label, "RIGHT", 10, 0)
	line.rule:SetPoint("RIGHT", line.count, "LEFT", -10, 0)
	line.rule:SetHeight(1)
	-- a row's
	line.bezel = ns.NewShopBezel(line, 34)
	line.bezel:SetPoint("LEFT", 8, 0)
	line.tag = ns.ShopText(line, "Owned")
	line.tag:SetPoint("RIGHT", -8, 0)
	line.wax = ns.ArtSprite(line, "Shop", "wax-mini", "OVERLAY")
	line.wax:ClearAllPoints()
	line.wax:SetPoint("RIGHT", line.tag, "LEFT", -6 + line.wax.box[1], 0)
	local price = CreateFrame("Frame", nil, line) --[[@as PagleShopPriceTag]]
	price:SetFrameLevel(line:GetFrameLevel())
	price.amount = ns.ShopText(price, "Price")
	price.amount:SetPoint("LEFT", 15, 0)
	price.coin = ns.SetShopCoin(ns.ArtSprite(price, "Shop", "coin-small", "OVERLAY", 1), 15)
	price.coin:ClearAllPoints()
	price.coin:SetPoint("LEFT", price.amount, "RIGHT", 5 - price.coin.box[1], 0)
	price.string = ns.ArtSprite(price, "Shop", "tag-string", "ARTWORK")
	price.string:ClearAllPoints()
	price.string:SetPoint("RIGHT", price, "LEFT", 2, 1)
	line.price = price
	line:SetScript("OnClick", function(self)
		if self.goodID then
			selected = self.goodID
			redraw(true)
		end
	end)
	frame.lines[i] = line
	return line
end

-- Shows a header's regions or a row's on `line`.
---@param line PagleShopLine
---@param header boolean
local function shapeLine(line, header)
	line.header = header
	line.count:SetShown(header)
	line.rule:SetShown(header)
	line.bezel:SetShown(not header)
	line:EnableMouse(not header)
	ns.SetShopFont(line.label, header and "Slot" or "Good")
	line.label:ClearAllPoints()
	if header then
		line.label:SetPoint("TOPLEFT", 0, -12)
		line.selectedMark:Hide()
		line.tag:Hide()
		line.wax:Hide()
		line.price:Hide()
	else
		line.label:SetPoint("LEFT", line.bezel, "RIGHT", 12, 0)
	end
end

-- Sets a row's tag from `data`: "IN USE" after the wax dot, or the good's other state.
---@param line PagleShopLine
---@param data PagleShopRow
local function drawRowTag(line, data)
	local inUse = data.state == "equipped"
	ns.SetShopFont(line.tag, inUse and "InUse" or "Owned")
	ns.SetShopText(line.tag, data.tag)
	line.tag:Show()
	line.wax:SetShown(inUse)
end

-- Draws a row's right end from `data`: the price tag for a good for sale, in red when the balance doesn't cover it;
-- otherwise its tag. What a purchase's motion faded or added goes back to rest.
---@param line PagleShopLine
---@param data PagleShopRow
local function drawRowEnd(line, data)
	local price = line.price
	for _, region in ipairs({ price, line.tag, line.wax }) do
		region:SetAlpha(1)
	end
	if line.glow then
		line.glow:SetAlpha(0)
	end
	if line.stepDown then
		line.stepDown:Hide()
	end
	if data.price then
		ns.SetShopFont(price.amount, data.short and "PriceShort" or "Price")
		ns.SetShopText(price.amount, data.price)
		ns.SetThreeSlice(price, "Shop", "tag", 15 + price.amount:GetStringWidth() + 5 + 15 + 9, 14, "ARTWORK")
		price:ClearAllPoints()
		price:SetPoint("RIGHT", line, "RIGHT", -8, 0)
		price:Show()
		line.tag:Hide()
		line.wax:Hide()
		return
	end
	price:Hide()
	drawRowTag(line, data)
end

-- Draws the list from `groups`: each group's header, then its rows, top to bottom in the scroll child.
---@param frame PagleShopFrame
---@param groups PagleShopGroup[]
local function drawList(frame, groups)
	local i, y = 0, 0
	for _, group in ipairs(groups) do
		i = i + 1
		local header = lineAt(frame, i)
		shapeLine(header, true)
		header.goodID = nil
		header:SetHeight(HEADER_H)
		at(header, frame.content, LIST_X, y)
		ns.SetShopText(header.label, group.label)
		ns.SetShopText(header.count, group.count or group.note)
		header:SetAlpha(group.putAway and GREYED_ALPHA or 1)
		header:Show()
		y = y + HEADER_H
		for _, data in ipairs(group.rows) do
			i = i + 1
			local row = lineAt(frame, i)
			shapeLine(row, false)
			row.goodID = data.id
			row.listY = y
			row:SetHeight(ROW_H)
			at(row, frame.content, LIST_X, y)
			ns.SetShopText(row.label, data.name)
			ns.SetShopBezel(row.bezel, data.icon, data.state == "putAway", data.shield)
			drawRowEnd(row, data)
			row.selectedMark:SetShown(data.id == selected)
			row:SetAlpha(data.state == "putAway" and GREYED_ALPHA or 1)
			row:Show()
			y = y + ROW_H
		end
	end
	for j = i + 1, #frame.lines do
		frame.lines[j]:Hide()
	end
	frame.content:SetHeight(math.max(y + 8, 1))
	frame.empty:SetShown(i == 0)
end

-- Fits the scroll bar to the list: shown only when the list overflows the tray, its thumb as long as the share that
-- shows.
---@param frame PagleShopFrame
local function fitScrollBar(frame)
	local bar, scroll = frame.scrollBar, frame.scroll
	local range = scroll:GetVerticalScrollRange()
	bar:SetShown(range > 0)
	if range <= 0 then
		scroll:SetVerticalScroll(0)
		return
	end
	local visible = scroll:GetHeight()
	bar.thumb:SetHeight(math.max(24, bar:GetHeight() * visible / (visible + range)))
	bar:SetMinMaxValues(0, range)
	bar:SetValue(math.min(scroll:GetVerticalScroll(), range))
end

-- The list's scroll frame in the tray, its scroll child, and the slim brass scroll bar at its right; the wheel
-- scrolls it a row and a half at a time.
---@param frame PagleShopFrame
local function buildList(frame)
	frame.scroll = CreateFrame("ScrollFrame", nil, frame) --[[@as ScrollFrame]]
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetWidth(TRAY_W)
	frame.scroll:SetScrollChild(frame.content)
	frame.lines = {}
	frame.empty = ns.ShopText(frame.scroll, "Empty")
	frame.empty:SetPoint("TOP", 0, -24)
	ns.SetShopText(frame.empty, L.SHOP_NO_MATCH)
	local bar = CreateFrame("Slider", nil, frame) --[[@as PagleShopScrollBar]]
	frame.scrollBar = bar
	bar:SetOrientation("VERTICAL")
	bar:EnableMouse(true)
	bar:SetWidth(6)
	bar:SetValueStep(1)
	bar:SetObeyStepOnDrag(true)
	bar.track = solid(bar, 0, 0, 0, 0.35, "BACKGROUND")
	bar.track:SetAllPoints()
	bar.thumb = ns.ArtSprite(bar, "Shop", "scroll-thumb", "ARTWORK")
	bar.thumb:SetWidth(6)
	bar:SetThumbTexture(bar.thumb)
	bar:SetScript("OnValueChanged", function(_, value)
		frame.scroll:SetVerticalScroll(value)
	end)
	bar:Hide()
	frame.scroll:EnableMouseWheel(true)
	frame.scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = self:GetVerticalScrollRange()
		local offset = math.max(0, math.min(range, self:GetVerticalScroll() - delta * ROW_H * 1.5))
		self:SetVerticalScroll(offset)
		if bar:IsShown() then
			bar:SetValue(offset)
		end
	end)
	frame.scroll:SetScript("OnScrollRangeChanged", function()
		fitScrollBar(frame)
	end)
end

-- Places the list from `top` down to the tray's foot, and its scroll bar beside it.
---@param frame PagleShopFrame
---@param top number
local function placeList(frame, top)
	frame.listTop = top
	frame.scroll:ClearAllPoints()
	frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", TRAY_X, -top)
	frame.scroll:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", TRAY_X + TRAY_W - 14, -(TRAY_Y + TRAY_H - 4))
	local bar = frame.scrollBar
	bar:ClearAllPoints()
	bar:SetPoint("TOPRIGHT", frame, "TOPLEFT", TRAY_X + TRAY_W - 6, -(top + 10))
	bar:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", TRAY_X + TRAY_W - 6, -(TRAY_Y + TRAY_H - 12))
end

-- The stage (wallet-and-shop.md › UI) on the lid: the showcase card, its dark well and the paper under it where the
-- good's preview draws, then the description card with the good's name, slot and owner, description and notes, and
-- Buy or Use with its tags at the foot.
---@param frame PagleShopFrame
---@return PagleShopStageFrame
local function buildStage(frame)
	local stage = { previews = {} }
	stage.card = ns.ArtSprite(frame, "Papers", "show", "ARTWORK", 1)
	ns.PlaceSprite(stage.card, frame, CARD_X, CARD_Y)
	stage.area = CreateFrame("Frame", nil, frame)
	stage.area:SetSize(STAGE_W, STAGE_H)
	at(stage.area, frame, CARD_X + STAGE_X, CARD_Y + STAGE_Y)
	stage.area:SetClipsChildren(true)
	stage.swatch = ns.NewShopBezel(stage.area, 64)
	stage.swatch:SetPoint("CENTER", stage.area, "TOP", 0, -WELL_H / 2)
	stage.hint = ns.ShopText(stage.area, "Stage")
	stage.hint:SetPoint("CENTER", stage.area, "TOP", 0, -WELL_H / 2)
	ns.SetShopText(stage.hint, L.SHOP_PICK)

	-- The description card, stretched from its designed 176 to INFO_H: it is plain paper.
	local info = ns.ArtSprite(frame, "Papers", "info", "ARTWORK", 1)
	local k = INFO_H / info.box[4]
	info:SetHeight(info:GetHeight() * k)
	info.box = { info.box[1], info.box[2] * k, info.box[3], INFO_H }
	ns.PlaceSprite(info, frame, CARD_X, INFO_Y)
	stage.info = info
	local x, width = CARD_X + INFO_PAD, info.box[3] - 2 * INFO_PAD
	stage.name = ns.ShopText(frame, "GoodName")
	stage.name:SetWidth(width)
	at(stage.name, frame, x, INFO_Y + 14)
	stage.slotLine = ns.ShopText(frame, "Meta")
	at(stage.slotLine, frame, x, INFO_Y + 56)
	stage.description = ns.ShopText(frame, "Desc")
	stage.description:SetWidth(width)
	stage.description:SetWordWrap(true)
	at(stage.description, frame, x, INFO_Y + 77)
	stage.notes = ns.ShopText(frame, "Notes")
	stage.notes:SetWidth(width)
	stage.notes:SetWordWrap(true)
	stage.notes:SetPoint("TOPLEFT", stage.description, "BOTTOMLEFT", 0, -6)

	local footY = INFO_Y + INFO_H - 16 - 44
	stage.buy = ns.NewShopButton(frame, function()
		askToBuy(frame, selected)
	end)
	at(stage.buy, frame, x, footY)
	stage.needed = ns.ShopText(frame, "Need")
	-- Buy is disabled while the balance doesn't cover the price (SHOP-R13): a click on it then shakes "N more Coins".
	stage.short = CreateFrame("Button", nil, frame)
	stage.short:SetAllPoints(stage.buy)
	stage.short:SetFrameLevel(stage.buy:GetFrameLevel() + 2)
	stage.short:SetScript("OnClick", function(self)
		ns.ShakeShopNote(self, function(dx)
			stage.needed:ClearAllPoints()
			stage.needed:SetPoint("LEFT", stage.buy, "RIGHT", 14 + dx, 0)
		end)
	end)
	stage.short:Hide()
	stage.use = ns.NewShopButton(frame, function()
		if selected and ns.shop.Use(selected) then
			redraw(false)
		end
	end)
	at(stage.use, frame, x, footY)
	stage.tags = ns.ShopText(frame, "Tags")
	return stage --[[@as PagleShopStageFrame]]
end

-- Hides what shows the selected good, for a stage with none.
---@param stage PagleShopStageFrame
local function clearStage(stage)
	for _, region in ipairs({
		stage.swatch,
		stage.name,
		stage.slotLine,
		stage.description,
		stage.notes,
		stage.tags,
		stage.buy,
		stage.needed,
		stage.short,
		stage.use,
	}) do
		region:Hide()
	end
	for _, preview in pairs(stage.previews) do
		preview:Hide()
	end
end

-- Shows `goodID`'s look on the stage: its own stage frame, made at its first preview and the same each time, handed
-- to its preview through securecallfunction when `fresh`, so a preview that raises is reported and the rest still
-- shows; a good with no preview (or put away) shows its icon in a medallion instead.
---@param stage PagleShopStageFrame
---@param data PagleShopStage
---@param fresh boolean
local function drawLook(stage, data, fresh)
	local preview = data.preview
	if not preview then
		ns.SetShopBezel(stage.swatch, data.icon, data.greyed, data.shield)
		stage.swatch:Show()
		return
	end
	local own = stage.previews[data.id]
	if not own then
		own = CreateFrame("Frame", nil, stage.area)
		own:SetAllPoints()
		stage.previews[data.id] = own
		fresh = true
	end
	own:Show()
	if fresh then
		securecallfunction(preview, own)
	end
end

-- Draws the description card's foot from `data`: Buy, "N more Coins" or Use, and the tags beside them, each at rest.
---@param stage PagleShopStageFrame
---@param data PagleShopStage
local function drawFoot(stage, data)
	for _, region in ipairs({ stage.buy, stage.needed, stage.short, stage.use }) do
		region:Hide()
	end
	if data.buy then
		ns.SetShopButton(stage.buy, data.buy, true, data.canBuy == true) -- SHOP-R13
		stage.buy:Show()
	end
	if data.needed then
		ns.SetShopText(stage.needed, data.needed)
		stage.needed:ClearAllPoints()
		stage.needed:SetPoint("LEFT", stage.buy, "RIGHT", 14, 0)
		stage.needed:Show()
		stage.short:SetShown(data.buy ~= nil)
	end
	if data.use then
		ns.SetShopButton(stage.use, L.SHOP_USE, false, true)
		stage.use:Show()
	end
	ns.SetShopText(stage.tags, table.concat(data.tags, TAG_SEPARATOR))
	stage.tags:ClearAllPoints()
	if data.use then
		stage.tags:SetPoint("LEFT", stage.use, "RIGHT", 14, 0)
	else
		stage.tags:SetPoint("LEFT", stage.use, "LEFT", 0, 0)
	end
	stage.tags:SetAlpha(1)
	stage.tags:SetShown(#data.tags > 0)
end

-- Draws the stage from `data`, or the hint with nothing selected.
---@param frame PagleShopFrame
---@param data PagleShopStage?
---@param fresh boolean the selection changed or the shop opened: the preview draws again
local function drawStage(frame, data, fresh)
	local stage = frame.stage
	clearStage(stage)
	stage.hint:SetShown(data == nil)
	if not data then
		return
	end
	drawLook(stage, data, fresh)
	ns.SetShopText(stage.name, data.name)
	ns.SetShopText(stage.slotLine, data.slotLine)
	ns.SetShopText(stage.description, data.description)
	ns.SetShopText(stage.notes, table.concat(data.notes, "\n"))
	for _, region in ipairs({ stage.name, stage.slotLine, stage.description, stage.notes }) do
		region:Show()
	end
	drawFoot(stage, data)
end

-- A check box on the bill: the box, the tick while it is checked, and its words.
---@param parent Frame
---@param text string
---@return PagleShopCheck
local function newCheck(parent, text)
	local check = CreateFrame("CheckButton", nil, parent) --[[@as PagleShopCheck]]
	check:SetSize(160, 44)
	check.box = ns.ArtSprite(check, "Shop", "check-box", "ARTWORK")
	check.box:ClearAllPoints()
	check.box:SetPoint("LEFT", check, "LEFT", 14 - check.box.box[1], 0)
	check.tick = ns.ArtSprite(check, "Shop", "tick", "OVERLAY")
	check.tick:ClearAllPoints()
	check.tick:SetPoint("LEFT", check, "LEFT", 14, 0)
	check.label = ns.ShopText(check, "Check")
	check.label:SetPoint("LEFT", check, "LEFT", 14 + 22 + 10, 0)
	ns.SetShopText(check.label, text)
	check:SetScript("OnClick", function(self)
		self.tick:SetShown(self:GetChecked() == true)
	end)
	return check
end

-- Ticks or clears a check box.
---@param check PagleShopCheck
---@param checked boolean
local function setChecked(check, checked)
	check:SetChecked(checked)
	check.tick:SetShown(checked)
end

-- One of the bill's two lines: its label at `y` and its number at the right, the coin after it when `coin` is given.
---@param bill PagleShopBill
---@param y number
---@param coin PagleSprite?
---@return PagleShopFontString label
---@return PagleShopFontString number
local function billLine(bill, y, coin)
	local slip = bill.slip
	local label = ns.ShopText(slip, "SlipLine")
	at(label, slip, 32, y)
	local number = ns.ShopText(slip, "SlipNum")
	number:SetJustifyH("RIGHT")
	number:ClearAllPoints()
	if coin then
		coin:ClearAllPoints()
		coin:SetPoint("TOPRIGHT", slip, "TOPRIGHT", -32 + (coin:GetWidth() - 20 - coin.box[1]), -(y + 2 - coin.box[2]))
		number:SetPoint("TOPRIGHT", slip, "TOPRIGHT", -32 - 26, -(y - 4))
	else
		number:SetPoint("TOPRIGHT", slip, "TOPRIGHT", -32, -(y - 4))
	end
	return label, number
end

-- The bill of sale (wallet-and-shop.md › UI: Buy), over the case dimmed: "CURIO SHOP", "Buy {name}?", the good's
-- medallion, a dashed rule, the price with the coin and the Pagle Coins left after, "Looks are yours for good.", "Use
-- it now" and Buy / Cancel. Esc is Cancel: while it shows, it takes Esc before the game does, and lets every other
-- key through.
---@param frame PagleShopFrame
---@return PagleShopBill
local function buildBill(frame)
	local bill = CreateFrame("Frame", nil, frame) --[[@as PagleShopBill]]
	bill:SetAllPoints()
	-- Over the stage's previews too, whatever frame levels they take.
	bill:SetFrameStrata("DIALOG")
	bill:EnableMouse(true) -- the case under it takes no clicks
	bill.shade = solid(bill, 0.024, 0.016, 0.008, 0.6, "BACKGROUND")
	bill.shade:SetAllPoints()
	local slip = CreateFrame("Frame", nil, bill)
	bill.slip = slip
	slip:SetSize(BILL_W, BILL_H)
	at(slip, bill, BILL_X, BILL_Y)
	ns.PlaceSprite(ns.ArtSprite(slip, "Papers", "slip", "BACKGROUND"), slip, 0, 0)
	bill.seal = ns.ArtSprite(slip, "Shop", "seal", "OVERLAY", 6)
	bill.seal:Hide()
	bill.head = ns.ShopText(slip, "SlipHead")
	bill.head:SetPoint("TOP", 0, -30)
	ns.SetShopText(bill.head, L.SHOP_BILL_HEAD)
	bill.question = ns.ShopText(slip, "SlipQ")
	bill.question:SetPoint("TOP", 0, -55)
	bill.bezel = ns.NewShopBezel(slip, 64)
	bill.bezel:SetPoint("TOP", 0, -111)
	local ruleY = 191
	local rule = ns.ArtSprite(slip, "Shop", "dash-rule", "ARTWORK")
	rule:ClearAllPoints()
	rule:SetPoint("TOPLEFT", slip, "TOPLEFT", 32, -ruleY)
	rule:SetPoint("TOPRIGHT", slip, "TOPRIGHT", -32, -ruleY)
	rule:SetHeight(1)
	local y = ruleY + 17
	bill.coin = ns.SetShopCoin(ns.ArtSprite(slip, "Shop", "coin-small", "OVERLAY"), 20)
	bill.priceLabel, bill.price = billLine(bill, y, bill.coin)
	ns.SetShopText(bill.priceLabel, L.SHOP_PRICE_LINE)
	bill.leftLabel, bill.left = billLine(bill, y + 26)
	ns.SetShopText(bill.leftLabel, L.SHOP_LEFT_AFTER)
	bill.fine = ns.ShopText(slip, "SlipFine")
	bill.fine:SetPoint("TOP", 0, -(y + 58))
	ns.SetShopText(bill.fine, L.SHOP_FOR_GOOD)
	bill.useNow = newCheck(slip, L.SHOP_USE_NOW)
	bill.useNow:SetPoint("TOP", bill.fine, "BOTTOM", 0, -6)

	local buttonsY = y + 58 + 21 + 6 + 44 + 18
	bill.buy = ns.NewShopButton(slip, function()
		if bill.goodID then
			buy(frame, bill.goodID, bill.useNow:GetChecked() == true)
		end
	end)
	ns.SetShopButton(bill.buy, L.SHOP_BUY_ACCEPT, false, true)
	bill.buy:SetPoint("TOPRIGHT", slip, "TOP", -6, -buttonsY)
	bill.cancel = CreateFrame("Button", nil, slip)
	bill.cancel:SetSize(110, 44)
	bill.cancel:SetPoint("TOPLEFT", slip, "TOP", 6, -buttonsY)
	bill.cancelLabel = ns.ShopText(bill.cancel, "Cancel")
	bill.cancelLabel:SetPoint("CENTER")
	ns.SetShopText(bill.cancelLabel, L.SHOP_BUY_CANCEL)
	local underline = solid(bill.cancel, 0.353, 0.227, 0.11, 0.4)
	underline:SetHeight(1)
	underline:SetPoint("TOPLEFT", bill.cancelLabel, "BOTTOMLEFT", 0, -4)
	underline:SetPoint("TOPRIGHT", bill.cancelLabel, "BOTTOMRIGHT", 0, -4)
	bill.cancel:SetScript("OnClick", function()
		closeBill(frame, true)
	end)

	bill:EnableKeyboard(true)
	bill:SetScript("OnKeyDown", function(self, key)
		-- Only Esc stops here; the client blocks the call in combat, when the shop is closed anyway (SHOP-R41).
		if not InCombatLockdown() then
			self:SetPropagateKeyboardInput(key ~= "ESCAPE")
		end
		if key == "ESCAPE" then
			closeBill(frame, true)
		end
	end)
	bill:Hide()
	return bill
end

-- Buy on the stage (wallet-and-shop.md › UI: Buy): shows the bill of sale for `goodID`, with "Use it now" ticked,
-- when Buy is enabled for it now (SHOP-R13). Its Buy calls ns.shop.Buy; Cancel and Esc buy nothing.
---@param frame PagleShopFrame
---@param goodID string?
function askToBuy(frame, goodID)
	local purchase = ns.ShopModel(BreakUpLargeNumbers):Purchase(goodID)
	if not purchase then
		return
	end
	local bill = frame.bill
	frame.search:ClearFocus() -- Esc and the keys go to the bill, not the search slip
	frame.purse.tip:Hide()
	bill.goodID = purchase.id
	ns.SetShopText(bill.question, L.SHOP_BUY_CONFIRM:format(purchase.name))
	ns.SetShopBezel(bill.bezel, purchase.icon, false, purchase.shield)
	ns.SetShopText(bill.price, purchase.amount)
	ns.SetShopText(bill.left, purchase.left)
	setChecked(bill.useNow, true)
	bill:Show()
	ns.OpenShopBill(bill, BILL_X, BILL_Y)
end

-- The shown row for `goodID`, if the list shows it.
---@param frame PagleShopFrame
---@param goodID string?
---@return PagleShopLine?
local function shownRow(frame, goodID)
	for _, line in ipairs(frame.lines) do
		if goodID and line:IsShown() and line.goodID == goodID then
			return line
		end
	end
	return nil
end

-- The good in use in `goodID`'s slot, as `groups` list it, if it isn't `goodID`.
---@param groups PagleShopGroup[]
---@param goodID string
---@return string?
local function inUseBeside(groups, goodID)
	for _, group in ipairs(groups) do
		local inUse, here
		for _, row in ipairs(group.rows) do
			here = here or row.id == goodID
			if row.state == "equipped" and row.id ~= goodID then
				inUse = row.id
			end
		end
		if here then
			return inUse
		end
	end
	return nil
end

-- Where `line`'s medallion's top left is on the case, kept inside the tray when the list is scrolled away from it.
---@param frame PagleShopFrame
---@param line PagleShopLine
---@return number[]
local function rowBezelAt(frame, line)
	local y = frame.listTop + line.listY + (ROW_H - ROW_BEZEL) / 2 - frame.scroll:GetVerticalScroll()
	local bottom = TRAY_Y + TRAY_H - 4 - ROW_BEZEL
	return { TRAY_X + LIST_X + ROW_BEZEL_X, math.max(frame.listTop, math.min(bottom, y)) }
end

-- Draws `line`'s new tag from `data` faded out, for a purchase delivered to it: what fades out and in, and its glow.
---@param line PagleShopLine
---@param data PagleShopRow
---@return Region[] out
---@return Region[] into
---@return Texture glow
local function deliverTo(line, data)
	drawRowTag(line, data)
	local into = { line.tag }
	if line.wax:IsShown() then
		into[2] = line.wax
	end
	for _, region in ipairs(into) do
		region:SetAlpha(0)
	end
	if not line.glow then
		line.glow = line:CreateTexture(nil, "BORDER")
		line.glow:SetAllPoints()
		line.glow:SetColorTexture(1, 0.85, 0.45, 1)
		line.glow:SetBlendMode("ADD")
	end
	line.glow:SetAlpha(0)
	return { line.price }, into, line.glow
end

-- Draws the slot's old good's new tag from `data` on `line`, faded out, over its "IN USE": what fades out and in.
---@param line PagleShopLine
---@param data PagleShopRow
---@return Region[] out
---@return Region[] into
local function stepDown(line, data)
	if not line.stepDown then
		line.stepDown = ns.ShopText(line, "Owned")
		line.stepDown:SetPoint("RIGHT", -8, 0)
	end
	local shown = line.stepDown --[[@as PagleShopFontString]]
	ns.SetShopFont(shown, data.state == "equipped" and "InUse" or "Owned")
	ns.SetShopText(shown, data.tag)
	shown:SetAlpha(0)
	shown:Show()
	return { line.tag, line.wax }, { shown }
end

-- Plays a purchase of `goodID` just made (adapter/ShopMotion.lua), from the window as it was drawn before it: `was`
-- holds the balance then and the good then in use in its slot. The window redraws once it settles.
---@param frame PagleShopFrame
---@param goodID string
---@param was { balance: integer, inUse: string? }
local function playPurchase(frame, goodID, was)
	local bill, purse = frame.bill, frame.purse
	local line = shownRow(frame, goodID)
	local seal = ns.SetSprite(bill.seal, "Shop", "seal")
	ns.CenterSpriteAt(seal, bill.slip, SEAL_X, SEAL_Y)
	seal:SetAlpha(0)
	local shown = bill.bezel.shield and bill.bezel.Shield or bill.bezel.Icon
	ns.SetShopBezel(frame.flyer, shown:GetTexture(), false, bill.bezel.shield)
	frame.flyer:Hide()
	ns.PlayShopPurchase(frame, {
		press = bill.buy,
		seal = seal,
		bezel = bill.bezel,
		flyer = frame.flyer,
		from = { BILL_BEZEL_X, BILL_BEZEL_Y },
		to = line and rowBezelAt(frame, line),
		closeBill = function(owner)
			ns.CloseShopBill(bill, BILL_X, BILL_Y, owner)
		end,
		balance = function(coins)
			ns.SetShopText(purse.balance, BreakUpLargeNumbers(coins))
		end,
		balanceFrom = was.balance,
		balanceTo = Pagle.GetBalance().balance,
		coin = purse.coin,
		row = function()
			local model = ns.ShopModel(BreakUpLargeNumbers)
			local data = model:Row(goodID)
			if not (line and data and line.goodID == goodID) then
				return nil
			end
			local out, into, glow = deliverTo(line, data)
			local motion = { out = out, into = into, glow = glow }
			local old = shownRow(frame, was.inUse)
			local oldData = was.inUse and model:Row(was.inUse)
			if old and oldData and oldData.state ~= "equipped" then
				motion.stepOut, motion.stepIn = stepDown(old, oldData)
			end
			return motion
		end,
		lid = function()
			local stage = frame.stage
			local data = ns.ShopModel(BreakUpLargeNumbers):Stage(goodID)
			if not data then
				return {}, {}
			end
			drawFoot(stage, data)
			stage.buy:Show() -- it fades as what follows the purchase comes in
			local into = {}
			for _, region in ipairs({ stage.tags, stage.use }) do
				if region:IsShown() then
					region:SetAlpha(0)
					into[#into + 1] = region
				end
			end
			return { stage.buy }, into
		end,
	}, function()
		settlePurchase(frame, true)
		redraw(false)
	end)
end

-- Buy on the bill of sale (wallet-and-shop.md › UI: Buy): buys `goodID` through ns.shop.Buy, which checks SHOP-R13
-- again and buys nothing if it no longer holds. Bought, the window shows it at once with the Animations setting off;
-- with it on, the purchase plays first (playPurchase).
---@param frame PagleShopFrame
---@param goodID string
---@param useNow boolean
function buy(frame, goodID, useNow)
	settlePurchase(frame)
	local was = {
		balance = Pagle.GetBalance().balance,
		inUse = inUseBeside(ns.ShopModel(BreakUpLargeNumbers):List(query), goodID),
	}
	local moving = ns.MotionOn()
	frame.bill.goodID = nil
	playing = moving and { committing = true } or nil
	local bought = ns.shop.Buy(goodID, useNow)
	if not bought or not moving then
		playing = nil
		closeBill(frame)
		if bought then
			ns.ShopSound("buy")
			-- BalanceChanged redrew before the good was owned: "Owned" or "In use" shows at once.
			redraw(false)
		end
		return
	end
	ns.ShopSound("buy")
	playing = {}
	playPurchase(frame, goodID, was)
end

-- The window: the sample case, centred and movable by its leather, with its close button at the top right, the purse,
-- the tray's controls and list, the lid's cards, and the bill of sale over them, fitted to the screen with its handle
-- (adapter/Fit.lua), again when the UI scale or the window's size changes. Esc closes it.
---@return PagleShopFrame
local function build()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as PagleShopFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	ns.FitToScreen(frame, { width = EXTENT_W, height = EXTENT_H, lift = CENTRE_DY })
	frame:SetFrameStrata("HIGH")
	frame:EnableMouse(true)
	frame:SetMovable(true)
	-- Over the other windows in its strata (show raises it) and brought back over them when clicked.
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame.case = ns.ArtSprite(frame, "Case", "case", "BACKGROUND")
	ns.PlaceSprite(frame.case, frame, 0, 0)
	frame.CloseButton = CreateFrame("Button", nil, frame)
	frame.CloseButton:SetSize(44, 44)
	frame.CloseButton:SetPoint("TOPRIGHT", -18, -18)
	ns.PlaceSprite(ns.ArtSprite(frame.CloseButton, "Shop", "close", "ARTWORK"), frame.CloseButton, 0, 0)
	frame.CloseButton:SetScript("OnClick", function()
		close(frame)
	end)

	frame.purse = buildPurse(frame)
	buildControls(frame)
	buildList(frame)
	frame.stage = buildStage(frame)
	frame.bill = buildBill(frame)
	-- Over the bill, whose strata it shares.
	frame.flyer = ns.NewShopBezel(frame, 64)
	frame.flyer:SetFrameStrata("DIALOG")
	frame.flyer:SetFrameLevel(frame.bill:GetFrameLevel() + 50)
	frame.flyer:Hide()

	frame:Hide()
	-- Esc with the search box unfocused hides it through UISpecialFrames (CloseSpecialWindows); its bill goes too, and a
	-- purchase still playing settles.
	frame:SetScript("OnHide", function()
		settlePurchase(frame)
		closeBill(frame)
		frame.search:ClearFocus()
		frame.purse.tip:Hide()
		ns.ShopSound("close")
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	return frame
end

-- A redraw waits for the projections to finish updating (ns.projections:WhenIdle), once.
local waitingForIdle = false

-- Redraws the open window from the model now: the purse, the filters and chips, the list and the stage. A selection
-- the shop no longer shows is dropped. `fresh` draws the selected good's preview again. While a projection updates,
-- Buy is disabled (SHOP-R13), and the window redraws again once the update finishes.
---@param fresh boolean
function redraw(fresh)
	local frame = ns.shopFrame
	if not frame or not frame:IsShown() then
		return
	end
	if playing then
		if playing.committing then
			return
		end
		settlePurchase(frame)
	end
	if not waitingForIdle and ns.projections:IsUpdating() then
		waitingForIdle = true
		ns.projections:WhenIdle(function()
			waitingForIdle = false
			redraw(false)
		end)
	end
	local model = ns.ShopModel(BreakUpLargeNumbers)
	drawPurse(frame, model:Purse())
	drawFilters(frame)
	placeList(frame, drawChips(frame, model:Chips()))
	drawList(frame, model:List(query))
	fitScrollBar(frame)
	selected = model:Select(selected)
	drawStage(frame, model:Stage(selected), fresh)
end

-- Opens the window, or keeps it open: selecting `selection` (with the search, filter and chip cleared, so its row
-- shows), selecting nothing for false, or keeping the selection for nil.
---@param selection string|false|nil
local function show(selection)
	local frame = ns.shopFrame
	if not frame then
		frame = build()
		ns.shopFrame = frame
	end
	if selection ~= nil then
		selected = selection or nil
		if selection then
			query = { filter = "all" }
			frame.search:SetText("")
		end
	end
	if not frame:IsShown() then
		frame:Show()
		ns.ShopSound("open")
	end
	-- It opens over every window already open: the Pagle windows share its strata, at frame levels of their own.
	frame:Raise()
	redraw(true)
end

--- Opens the Curio Shop (SHOP-R40): selecting `goodID` if the shop shows it (under "Put away" for an owned good of a
--- Module off), nothing for any other ID, and keeping the selection with none. While restricted it prints "Pagle:
--- the Curio Shop opens after combat." instead and opens nothing (SHOP-R41). Every entry point calls it: /pagle shop
--- (a toggle), the compartment entry and Look and Feel's "Open the Curio Shop". The Curio Shop's entry points are
--- ns.shop (SHOP-R40, SHOP-R41) over this window, with ns.ShopModel.
---@type fun(goodID: string?)
Pagle.OpenShop = ns.WireShop(ns.host, {
	isShown = function()
		return ns.shopFrame ~= nil and ns.shopFrame:IsShown()
	end,
	show = show,
	hide = function()
		if ns.shopFrame then
			close(ns.shopFrame)
		end
	end,
})

-- The window follows the balance, the looks and the Modules On while it is open, so Buy re-evaluates (wallet-and-shop.md
-- › UI, SHOP-R13, SHOP-R33). Its own owner on the bus.
local OWNER = "Pagle shop window"
for _, event in ipairs({ "BalanceChanged", "AppearanceChanged", "ModulesChanged" }) do
	Pagle.RegisterCallback(OWNER, event, function()
		redraw(false)
	end)
end
