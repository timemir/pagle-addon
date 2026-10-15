---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Curio Shop window (wallet-and-shop.md › UI, variant B of prototypes/curio-shop/): the purse along the top, the
-- list on the left, the stage on the right. What it shows is logic/Shop.lua's model, read afresh at each redraw; this
-- file only draws it. It opens only through ns.shop (logic/Wiring.lua's ns.WireShop): Pagle.OpenShop, /pagle shop
-- and the compartment entry, never on its own. Buy asks with a StaticPopup, whose Buy calls ns.shop.Buy.
--
-- Templates are FrameXML's at Gethe/wow-ui-source branch forever, 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/: ButtonFrameTemplate (Mainline/SharedUIPanelTemplates.xml,
-- the Collections window's frame: portrait, title, close button and an Inset), SearchBoxTemplate
-- (Shared/InputBox/InputBoxTemplates.xml), UIPanelScrollFrameTemplate (SecureScrollTemplates.xml),
-- UICheckButtonTemplate (Shared/Button/CheckButtonTemplates.xml, its label `Text`) and UIPanelButtonTemplate, as
-- Core's cards use it. The fonts are Blizzard_Fonts_Shared/Shared/FontStyles.xml's. The Buy popup is
-- Blizzard_StaticPopup/StaticPopup.lua's StaticPopup_Show(which, text_arg1, text_arg2, data, insertedFrame): its text
-- formatted with the good's name, and our frame inserted under it (Blizzard_StaticPopup_Game/GameDialog.lua,
-- SetupInsertedFrame), hidden and unparented again when it hides (StaticPopup_ReleaseInsertedFrame).
local L = ns.L

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleCurioShop"
local WIDTH, HEIGHT = 800, 540
-- The purse's band, under the title bar; the Inset holds the list and the stage below it.
local INSET_TOP = -96
-- The list column's width inside the Inset, and its rows'.
local LIST_WIDTH, ROW_WIDTH = 300, 266
local ROW_HEIGHT, HEADER_HEIGHT = 30, 22
-- The purse's bar.
local BAR_WIDTH, BAR_HEIGHT = 300, 10
-- The stage's height, under which the good's name, slot, description and actions sit.
local STAGE_HEIGHT = 250

-- The Pagle Coin as the window's portrait, and a swatch for a good with no icon.
local COIN_ICON = "Interface\\Icons\\INV_Misc_Coin_02"
local NO_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
-- Each paying Module's colour on the purse's bar (prototypes/curio-shop/, SRC_COLOR), and one for any other.
local SEGMENT_COLORS = {
	TackleBoard = { 0.85, 0.55, 0.2 },
	Ledger = { 0.3, 0.6, 0.85 },
	Hunts = { 0.45, 0.75, 0.35 },
}
local OTHER_COLOR = { 0.6, 0.6, 0.6 }
-- A faded segment's opacity (a Module off), and a greyed row's (Put away).
local OFF_ALPHA, GREYED_ALPHA = 0.35, 0.55
-- Text colours: white for a price the balance covers, red for one it doesn't, gold for tags (GameFontNormal's).
local WHITE, RED, GOLD = { 1, 1, 1 }, { 1, 0.25, 0.25 }, { 1, 0.82, 0 }
-- What separates tags on the stage.
local TAG_SEPARATOR = " · "
-- The Buy popup's StaticPopupDialogs key, the one field .luacheckrc lets Core set; and the size of the frame it
-- inserts under its text.
local BUY_DIALOG = "PAGLE_CURIO_BUY"
local CONFIRM_WIDTH, CONFIRM_HEIGHT = 300, 92

---@class PagleShopSegmentFrame: Frame
---@field bar Texture      the segment's colour on the bar
---@field legend FontString "Ledger 1,500"
---@field strike Texture   strikes the legend through while its Module is off
---@field share number     its part of the bar, 0 to 1
---@field tooltip string[]

---@class PagleShopPurseFrame
---@field icon Texture
---@field label FontString   "Pagle Coins"
---@field balance FontString
---@field bar Frame
---@field payNone FontString "Stats and QoL pay none"
---@field held FontString    SHOP-R12's held line, shown while the balance is held at 0
---@field segments PagleShopSegmentFrame[] pooled: the shown ones are the purse's

---@class PagleShopLine: Button
---@field header boolean     a group's header, not a good's row
---@field goodID string?     a row's good
---@field label FontString   a header's label, or a row's name
---@field count FontString   a header's owned count or note
---@field tag FontString     a row's tag or price
---@field swatch Texture     a row's icon
---@field selectedMark Texture shown on the selected good's row

---@class PagleShopStageFrame
---@field area Frame         where previews draw
---@field previews table<string, Frame> each good's own stage frame, made at its first preview
---@field swatch Texture     the good's icon, for a good with no preview
---@field hint FontString    "Pick a look to see it here." with nothing selected
---@field name FontString
---@field slotLine FontString
---@field description FontString
---@field notes FontString
---@field tags FontString
---@field price FontString
---@field needed FontString
---@field buy Button
---@field use Button

---@class PagleShopCheckButton: CheckButton
---@field Text FontString UICheckButtonTemplate's label

--- The frame the Buy popup inserts under "Buy {name}?" (wallet-and-shop.md › UI: Buy).
---@class PagleShopConfirmFrame: Frame
---@field swatch Texture
---@field price FontString
---@field leftAfter FontString "Pagle Coins left after: N. Looks are yours for good."
---@field useNow PagleShopCheckButton "Use it now", ticked at each asking

---@class PagleShopSearchBox: EditBox
---@field Instructions FontString SearchBoxTemplate's hint, shown while the box is empty

---@class PagleShopFrame: Frame
---@field Inset Frame         ButtonFrameTemplate's
---@field CloseButton Button  ButtonFrameTemplate's
---@field SetTitle fun(self: PagleShopFrame, title: string) TitledPanelMixin's
---@field SetPortraitToAsset fun(self: PagleShopFrame, texture: string|integer) PortraitFrameMixin's
---@field purse PagleShopPurseFrame
---@field search PagleShopSearchBox
---@field filters table<string, Button> by filter
---@field chips Button[]      pooled: All, then a chip per category a live slot uses
---@field scroll ScrollFrame
---@field content Frame       the list's scroll child
---@field lines PagleShopLine[] pooled: the shown ones are the list, in order
---@field empty FontString    "No looks match."
---@field stage PagleShopStageFrame

--- The window, made the first time it opens.
---@type PagleShopFrame?
ns.shopFrame = nil

-- What the player has narrowed the list to and selected; kept while the window closes and opens again.
---@type PagleShopQuery
local query = { filter = "all" }
---@type string?
local selected

-- Hides the Buy popup if it is up, buying nothing: it closes with the shop (SHOP-R41).
local function hideBuy()
	StaticPopup_Hide(BUY_DIALOG)
end

-- Closes the window and its Buy popup, giving back the keyboard: a hidden edit box would keep it.
---@param frame PagleShopFrame
local function close(frame)
	hideBuy()
	frame.search:ClearFocus()
	frame:Hide()
end

-- How wide a button reading its text is: the text and 10 pixels each side.
---@param made Button
---@return number
local function fitted(made)
	return made:GetTextWidth() + 20
end

-- A button with the native look reading `label`, `width` wide (or as wide as its text).
---@param parent Frame
---@param label string
---@param width number?
---@param height number?
---@return Button
local function button(parent, label, width, height)
	local made = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate") --[[@as Button]]
	made:SetText(label)
	made:SetSize(width or fitted(made), height or 22)
	return made
end

-- A font string on `parent` in `font`.
---@param parent Frame
---@param font string
---@return FontString
local function text(parent, font)
	return parent:CreateFontString(nil, "OVERLAY", font)
end

-- Shows GameTooltip at `owner` with `lines`, the first as its title.
---@param owner Frame
---@param lines string[]
local function showTooltip(owner, lines)
	GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
	GameTooltip:SetText(lines[1])
	for i = 2, #lines do
		GameTooltip:AddLine(lines[i], 1, 1, 1, true)
	end
	GameTooltip:Show()
end

local function hideTooltip()
	GameTooltip:Hide()
end

local redraw

-- The purse (wallet-and-shop.md › UI): the coin, "Pagle Coins" over the balance, the bar with its legend, who pays
-- none, and SHOP-R12's held line under them, in the band between the title bar and the Inset.
---@param frame PagleShopFrame
---@return PagleShopPurseFrame
local function buildPurse(frame)
	local purse = {}
	purse.icon = frame:CreateTexture(nil, "ARTWORK")
	purse.icon:SetSize(30, 30)
	purse.icon:SetPoint("TOPLEFT", 66, -34)
	purse.icon:SetTexture(COIN_ICON)
	purse.label = text(frame, "GameFontNormalSmall")
	purse.label:SetPoint("TOPLEFT", 102, -30)
	purse.balance = text(frame, "GameFontHighlightHuge")
	purse.balance:SetPoint("TOPLEFT", 102, -44)
	purse.bar = CreateFrame("Frame", nil, frame)
	purse.bar:SetSize(BAR_WIDTH, BAR_HEIGHT)
	purse.bar:SetPoint("TOPLEFT", 240, -38)
	local track = purse.bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(0.1, 0.1, 0.1, 0.9)
	purse.payNone = text(frame, "GameFontDisableSmall")
	purse.payNone:SetPoint("TOPRIGHT", -18, -40)
	purse.held = text(frame, "GameFontDisableSmall")
	purse.held:SetPoint("TOPLEFT", 102, -74)
	purse.held:SetWidth(WIDTH - 120)
	purse.held:SetJustifyH("LEFT")
	purse.held:SetText(L.SHOP_HELD)
	purse.segments = {}
	return purse --[[@as PagleShopPurseFrame]]
end

-- The pooled segment `i`: its part of the bar, its legend entry and the line that strikes it through.
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
	segment:SetHeight(BAR_HEIGHT)
	segment:EnableMouse(true)
	segment.bar = segment:CreateTexture(nil, "ARTWORK")
	segment.bar:SetAllPoints()
	segment.legend = text(frame, "GameFontHighlightSmall")
	segment.strike = frame:CreateTexture(nil, "OVERLAY")
	segment.strike:SetHeight(1)
	segment.strike:SetPoint("LEFT", segment.legend, "LEFT", -1, 0)
	segment.strike:SetPoint("RIGHT", segment.legend, "RIGHT", 1, 0)
	segment.strike:SetColorTexture(0.75, 0.75, 0.75, 1)
	segment:SetScript("OnEnter", function(self)
		showTooltip(self, self.tooltip)
	end)
	segment:SetScript("OnLeave", hideTooltip)
	purse.segments[i] = segment
	return segment
end

-- Draws the purse from `purse`: one segment per Module that has reported, left to right, each as wide as its share,
-- faded with its legend struck through while its Module is off.
---@param frame PagleShopFrame
---@param purse PagleShopPurse
local function drawPurse(frame, purse)
	frame.purse.label:SetText(purse.label)
	frame.purse.balance:SetText(purse.balance)
	frame.purse.payNone:SetText(purse.payNone)
	frame.purse.held:SetShown(purse.held) -- SHOP-R12: the balance reads 0 meanwhile
	local x, previous = 0, nil
	for i, data in ipairs(purse.segments) do
		local segment = segmentAt(frame, i)
		local color = SEGMENT_COLORS[data.module] or OTHER_COLOR
		segment.share = data.share
		segment.tooltip = data.tooltip
		segment:ClearAllPoints()
		segment:SetPoint("LEFT", frame.purse.bar, "LEFT", x, 0)
		segment:SetWidth(math.max(data.share * BAR_WIDTH, 1))
		x = x + data.share * BAR_WIDTH
		segment.bar:SetColorTexture(color[1], color[2], color[3], 1)
		segment:SetAlpha(data.off and OFF_ALPHA or 1)
		segment.legend:SetText(data.legend)
		segment.legend:SetTextColor(unpack(data.off and { 0.55, 0.55, 0.55 } or { 1, 1, 1 }))
		segment.legend:ClearAllPoints()
		if previous then
			segment.legend:SetPoint("LEFT", previous, "RIGHT", 12, 0)
		else
			segment.legend:SetPoint("TOPLEFT", frame.purse.bar, "BOTTOMLEFT", 0, -4)
		end
		previous = segment.legend
		segment:Show()
		segment.legend:Show()
		segment.strike:SetShown(data.off)
	end
	for i = #purse.segments + 1, #frame.purse.segments do
		local segment = frame.purse.segments[i]
		segment:Hide()
		segment.legend:Hide()
		segment.strike:Hide()
	end
end

-- Marks the pressed one of `buttons`: its highlight stays on.
---@param buttons Button[]
---@param pressed Button?
local function press(buttons, pressed)
	for _, each in pairs(buttons) do
		if each == pressed then
			each:LockHighlight()
		else
			each:UnlockHighlight()
		end
	end
end

-- The list's controls (wallet-and-shop.md › UI): the search box, the four filters, then the chips' row; each redraws.
---@param frame PagleShopFrame
local function buildControls(frame)
	local inset = frame.Inset
	frame.search = CreateFrame("EditBox", nil, inset, "SearchBoxTemplate") --[[@as PagleShopSearchBox]]
	frame.search:SetSize(LIST_WIDTH - 24, 20)
	frame.search:SetPoint("TOPLEFT", 16, -8)
	frame.search:SetAutoFocus(false)
	frame.search.Instructions:SetText(L.SHOP_SEARCH)
	frame.search:HookScript("OnTextChanged", function(self)
		query.search = self:GetText()
		redraw(false)
	end)
	-- A focused edit box takes Esc before UISpecialFrames does: Esc there closes the shop too.
	frame.search:SetScript("OnEscapePressed", function()
		close(frame)
	end)
	frame.search:SetScript("OnEnterPressed", function(self)
		self:ClearFocus()
	end)

	frame.filters = {}
	local x = 10
	for _, filter in ipairs(ns.SHOP_FILTERS) do
		local made = button(inset, L.SHOP_FILTERS[filter], nil, 20)
		made:SetPoint("TOPLEFT", x, -32)
		x = x + fitted(made) + 2
		made:SetScript("OnClick", function()
			query.filter = filter
			redraw(false)
		end)
		frame.filters[filter] = made
	end
	frame.chips = {}
end

-- Lays out the chips' row from `chips` (All first), wrapping it in the list's width, and returns how far down the
-- list starts.
---@param frame PagleShopFrame
---@param chips PagleShopChip[]
---@return number top the list's top, from the Inset's
local function drawChips(frame, chips)
	local all = { { label = L.SHOP_ALL_CATEGORIES } }
	for _, chip in ipairs(chips) do
		all[#all + 1] = chip
	end
	local x, y, pressed = 10, -56, nil
	for i, chip in ipairs(all) do
		local made = frame.chips[i]
		if not made then
			made = button(frame.Inset, chip.label, nil, 20)
			frame.chips[i] = made
		end
		made:SetText(chip.label)
		local width = fitted(made)
		made:SetWidth(width)
		if x + width > LIST_WIDTH - 6 then
			x, y = 10, y - 22
		end
		made:ClearAllPoints()
		made:SetPoint("TOPLEFT", x, y)
		x = x + width + 2
		local category = chip.category
		made:SetScript("OnClick", function()
			query.category = category
			redraw(false)
		end)
		made:Show()
		if category == query.category then
			pressed = made
		end
	end
	for i = #all + 1, #frame.chips do
		frame.chips[i]:Hide()
	end
	local shown = {}
	for i = 1, #all do
		shown[i] = frame.chips[i]
	end
	press(shown, pressed)
	return y - 24
end

-- The pooled list line `i`, made as a header or a row on first use; a line is either for good.
---@param frame PagleShopFrame
---@param i integer
---@return PagleShopLine
local function lineAt(frame, i)
	local line = frame.lines[i]
	if line then
		return line
	end
	line = CreateFrame("Button", nil, frame.content) --[[@as PagleShopLine]]
	line:SetWidth(ROW_WIDTH)
	line.selectedMark = line:CreateTexture(nil, "BACKGROUND")
	line.selectedMark:SetAllPoints()
	line.selectedMark:SetColorTexture(1, 0.82, 0, 0.15)
	local hover = line:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 0.82, 0, 0.08)
	line.swatch = line:CreateTexture(nil, "ARTWORK")
	line.swatch:SetSize(24, 24)
	line.swatch:SetPoint("LEFT", 4, 0)
	line.label = text(line, "GameFontHighlight")
	line.label:SetJustifyH("LEFT")
	line.tag = text(line, "GameFontNormalSmall")
	line.tag:SetPoint("RIGHT", -6, 0)
	line.count = text(line, "GameFontDisableSmall")
	line.count:SetPoint("RIGHT", -6, 0)
	line:SetScript("OnClick", function(self)
		if self.goodID then
			selected = self.goodID
			redraw(true)
		end
	end)
	frame.lines[i] = line
	return line
end

-- Draws the list from `groups`: each group's header, then its rows, top to bottom in the scroll child.
---@param frame PagleShopFrame
---@param groups PagleShopGroup[]
local function drawList(frame, groups)
	local i, y = 0, 0
	for _, group in ipairs(groups) do
		i = i + 1
		local header = lineAt(frame, i)
		header.header, header.goodID = true, nil
		header:SetHeight(HEADER_HEIGHT)
		header:ClearAllPoints()
		header:SetPoint("TOPLEFT", 0, -y)
		header.label:SetFontObject("GameFontNormalSmall")
		header.label:ClearAllPoints()
		header.label:SetPoint("LEFT", 6, 0)
		header.label:SetText(group.label)
		header.count:SetText(group.count or group.note)
		header.count:Show()
		header.tag:Hide()
		header.swatch:Hide()
		header.selectedMark:Hide()
		header:EnableMouse(false)
		header:SetAlpha(group.putAway and GREYED_ALPHA or 1)
		header:Show()
		y = y + HEADER_HEIGHT
		for _, data in ipairs(group.rows) do
			i = i + 1
			local row = lineAt(frame, i)
			row.header, row.goodID = false, data.id
			row:SetHeight(ROW_HEIGHT)
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 0, -y)
			row.label:SetFontObject("GameFontHighlight")
			row.label:ClearAllPoints()
			row.label:SetPoint("LEFT", 34, 0)
			row.label:SetText(data.name)
			row.swatch:SetTexture(data.icon or NO_ICON)
			row.swatch:Show()
			row.tag:SetText(data.price or data.tag)
			row.tag:SetTextColor(unpack(data.short and RED or data.price and WHITE or GOLD))
			row.tag:Show()
			row.count:Hide()
			row.selectedMark:SetShown(data.id == selected)
			row:EnableMouse(true)
			row:SetAlpha(data.state == "putAway" and GREYED_ALPHA or 1)
			row:Show()
			y = y + ROW_HEIGHT
		end
	end
	for j = i + 1, #frame.lines do
		frame.lines[j]:Hide()
	end
	frame.content:SetHeight(math.max(y, 1))
	frame.empty:SetShown(i == 0)
end

-- The frame the Buy popup inserts under its text (wallet-and-shop.md › UI: Buy): the good's swatch and price, the
-- Coins left after, and "Use it now". One, made at the first Buy, filled at each.
---@type PagleShopConfirmFrame?
local confirm

---@return PagleShopConfirmFrame
local function buildConfirm()
	local made = CreateFrame("Frame", nil, UIParent) --[[@as PagleShopConfirmFrame]]
	made:SetSize(CONFIRM_WIDTH, CONFIRM_HEIGHT)
	made.swatch = made:CreateTexture(nil, "ARTWORK")
	made.swatch:SetSize(36, 36)
	made.swatch:SetPoint("TOPLEFT", 16, -4)
	made.price = text(made, "GameFontHighlight")
	made.price:SetPoint("LEFT", made.swatch, "RIGHT", 10, 0)
	made.leftAfter = text(made, "GameFontHighlightSmall")
	made.leftAfter:SetPoint("TOPLEFT", made.swatch, "BOTTOMLEFT", 0, -8)
	made.leftAfter:SetWidth(CONFIRM_WIDTH - 32)
	made.leftAfter:SetJustifyH("LEFT")
	made.leftAfter:SetWordWrap(true)
	made.useNow = CreateFrame("CheckButton", nil, made, "UICheckButtonTemplate") --[[@as PagleShopCheckButton]]
	made.useNow:SetSize(24, 24)
	made.useNow:SetPoint("TOPLEFT", made.leftAfter, "BOTTOMLEFT", -4, -4)
	made.useNow.Text:SetText(L.SHOP_USE_NOW)
	made:Hide()
	return made
end

-- Buy on the stage (wallet-and-shop.md › UI: Buy): asks "Buy {name}?" with the swatch, the price, the Coins left
-- after and "Use it now" ticked, when Buy is enabled for `goodID` now (SHOP-R13). Its Buy calls ns.shop.Buy, which
-- checks SHOP-R13 again and does nothing if it no longer holds; Cancel and Esc buy nothing.
---@param goodID string?
local function askToBuy(goodID)
	local purchase = ns.ShopModel(BreakUpLargeNumbers):Purchase(goodID)
	if not purchase then
		return
	end
	local shown = confirm or buildConfirm()
	confirm = shown
	shown.swatch:SetTexture(purchase.icon or NO_ICON)
	shown.price:SetText(purchase.priceText)
	shown.leftAfter:SetText(purchase.leftAfter)
	shown.useNow:SetChecked(true)
	StaticPopupDialogs.PAGLE_CURIO_BUY = {
		text = L.SHOP_BUY_CONFIRM,
		button1 = L.SHOP_BUY_ACCEPT,
		button2 = L.SHOP_BUY_CANCEL,
		OnAccept = function(_, data)
			if ns.shop.Buy(data, shown.useNow:GetChecked() == true) then
				-- BalanceChanged redrew before the good was owned: "Owned" or "In use" shows at once.
				redraw(false)
			end
		end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
	}
	StaticPopup_Show(BUY_DIALOG, purchase.name, nil, purchase.id, shown)
end

-- The stage (wallet-and-shop.md › UI): the preview area, then the good's name, slot and owner, description and
-- notes on the left, and its tags or price and Buy or Use on the right.
---@param frame PagleShopFrame
---@return PagleShopStageFrame
local function buildStage(frame)
	local inset = frame.Inset
	local stage = { previews = {} }
	stage.area = CreateFrame("Frame", nil, inset)
	stage.area:SetPoint("TOPLEFT", LIST_WIDTH + 14, -8)
	stage.area:SetPoint("TOPRIGHT", -8, -8)
	stage.area:SetHeight(STAGE_HEIGHT)
	local backdrop = stage.area:CreateTexture(nil, "BACKGROUND")
	backdrop:SetAllPoints()
	backdrop:SetColorTexture(0.05, 0.07, 0.09, 1)
	stage.swatch = stage.area:CreateTexture(nil, "ARTWORK")
	stage.swatch:SetSize(64, 64)
	stage.swatch:SetPoint("CENTER")
	stage.hint = text(stage.area, "GameFontDisable")
	stage.hint:SetPoint("CENTER")
	stage.hint:SetText(L.SHOP_PICK)

	local left = LIST_WIDTH + 18
	stage.name = text(inset, "GameFontHighlightLarge")
	stage.name:SetPoint("TOPLEFT", stage.area, "BOTTOMLEFT", 4, -10)
	stage.slotLine = text(inset, "GameFontNormalSmall")
	stage.slotLine:SetPoint("TOPLEFT", stage.name, "BOTTOMLEFT", 0, -4)
	stage.description = text(inset, "GameFontHighlightSmall")
	stage.description:SetPoint("TOPLEFT", stage.slotLine, "BOTTOMLEFT", 0, -8)
	stage.description:SetWidth(WIDTH - left - 190)
	stage.description:SetJustifyH("LEFT")
	stage.description:SetWordWrap(true)
	stage.notes = text(inset, "GameFontNormalSmall")
	stage.notes:SetPoint("TOPLEFT", stage.description, "BOTTOMLEFT", 0, -8)
	stage.notes:SetWidth(WIDTH - left - 190)
	stage.notes:SetJustifyH("LEFT")

	stage.tags = text(inset, "GameFontNormal")
	stage.tags:SetPoint("TOPRIGHT", stage.area, "BOTTOMRIGHT", -4, -12)
	stage.price = text(inset, "GameFontHighlight")
	stage.price:SetPoint("TOPRIGHT", stage.area, "BOTTOMRIGHT", -4, -12)
	stage.buy = button(inset, "", 160)
	stage.buy:SetPoint("TOPRIGHT", stage.price, "BOTTOMRIGHT", 0, -6)
	stage.buy:SetScript("OnClick", function()
		askToBuy(selected)
	end)
	stage.needed = text(inset, "GameFontRedSmall")
	stage.needed:SetPoint("TOPRIGHT", stage.buy, "BOTTOMRIGHT", 0, -4)
	stage.use = button(inset, L.SHOP_USE, 120)
	stage.use:SetPoint("TOPRIGHT", stage.tags, "BOTTOMRIGHT", 0, -6)
	stage.use:SetScript("OnClick", function()
		if selected and ns.shop.Use(selected) then
			redraw(false)
		end
	end)
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
		stage.price,
		stage.buy,
		stage.needed,
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
-- shows; a good with no preview (or put away) shows its icon instead.
---@param stage PagleShopStageFrame
---@param data PagleShopStage
---@param fresh boolean
local function drawLook(stage, data, fresh)
	local preview = data.preview
	if not preview then
		stage.swatch:SetTexture(data.icon or NO_ICON)
		stage.swatch:SetDesaturated(data.greyed == true)
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
	stage.name:SetText(data.name)
	stage.slotLine:SetText(data.slotLine)
	stage.description:SetText(data.description or "")
	stage.notes:SetText(table.concat(data.notes, "\n"))
	stage.tags:SetText(table.concat(data.tags, TAG_SEPARATOR))
	for _, region in ipairs({ stage.name, stage.slotLine, stage.description, stage.notes, stage.tags }) do
		region:Show()
	end
	if data.price then
		stage.price:SetText(data.price)
		stage.price:SetTextColor(unpack(data.short and RED or WHITE))
		stage.price:Show()
	end
	if data.buy then
		stage.buy:SetText(data.buy)
		stage.buy:SetEnabled(data.canBuy == true) -- SHOP-R13
		stage.buy:Show()
	end
	if data.needed then
		stage.needed:SetText(data.needed)
		stage.needed:Show()
	end
	stage.use:SetShown(data.use == true)
end

-- The window: ButtonFrameTemplate with the coin as its portrait and "Curio Shop" as its title, the purse in the band
-- above the Inset, then the list and the stage inside it. Centred and movable by its frame; Esc closes it.
---@return PagleShopFrame
local function build()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "ButtonFrameTemplate") --[[@as PagleShopFrame]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetTitle(L.SHOP_TITLE)
	frame:SetPortraitToAsset(COIN_ICON)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame.Inset:ClearAllPoints()
	frame.Inset:SetPoint("TOPLEFT", 4, INSET_TOP)
	frame.Inset:SetPoint("BOTTOMRIGHT", -6, 4)

	frame.purse = buildPurse(frame)
	buildControls(frame)
	frame.scroll = CreateFrame("ScrollFrame", nil, frame.Inset, "UIPanelScrollFrameTemplate") --[[@as ScrollFrame]]
	frame.content = CreateFrame("Frame", nil, frame.scroll)
	frame.content:SetWidth(ROW_WIDTH)
	frame.scroll:SetScrollChild(frame.content)
	frame.lines = {}
	frame.empty = text(frame.Inset, "GameFontDisable")
	frame.empty:SetPoint("TOP", frame.scroll, "TOP", 0, -20)
	frame.empty:SetText(L.SHOP_NO_MATCH)
	frame.stage = buildStage(frame)

	-- Esc with the search box unfocused hides it through UISpecialFrames (CloseSpecialWindows); its Buy popup goes too.
	frame:SetScript("OnHide", function()
		hideBuy()
		frame.search:ClearFocus()
		hideTooltip()
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
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
	if not waitingForIdle and ns.projections:IsUpdating() then
		waitingForIdle = true
		ns.projections:WhenIdle(function()
			waitingForIdle = false
			redraw(false)
		end)
	end
	local model = ns.ShopModel(BreakUpLargeNumbers)
	drawPurse(frame, model:Purse())
	press(frame.filters, frame.filters[query.filter or "all"])
	local top = drawChips(frame, model:Chips())
	frame.scroll:ClearAllPoints()
	frame.scroll:SetPoint("TOPLEFT", 8, top)
	frame.scroll:SetPoint("BOTTOMLEFT", 8, 8)
	frame.scroll:SetWidth(ROW_WIDTH)
	drawList(frame, model:List(query))
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
	frame:Show()
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
