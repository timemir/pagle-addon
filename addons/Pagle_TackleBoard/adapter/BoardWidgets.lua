if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's pieces (TKB-R100; tackle-board.md › UI), drawn from the board art kit (PagleArtBoard) through
-- adapter/BoardArt.lua's sprites and fonts: a brass tack, a brass coin with its Coins, a progress bar, the red-pencil
-- "take it down", a leather button, the RE-POSTED stamp, an empty pin, the glowing ring of a highlighted pin and a
-- close mark. The pins (adapter/Pins.lua), the spike and the ledge (adapter/Ledge.lua), the board (adapter/Board.lua)
-- and the confirm (adapter/Reroll.lua) draw with these makers. Every symbol is a texture, never a glyph (CORE-R9).

--- A brass tack on `parent` (TKB-R102, TKB-R105, TKB-R107): the kit's 15-unit tack, or its 9-unit one; place it with
--- ns.PlaceSprite.
---@param parent Frame
---@param small boolean?
---@return TackleSprite
function ns.NewBoardTack(parent, small)
	return ns.ArtSprite(parent, small and "Marks" or "Board", small and "tack-s" or "tack", "OVERLAY", 2)
end

--- A brass coin with its Coins stamped on it (TKB-R102: a Notice's pay).
---@class TackleCoinView
---@field coin TackleSprite
---@field label FontString

--- A brass coin on `parent`, its drawn element's top left at `x`, `y` from `parent`'s top left (y down).
---@param parent Frame
---@param x number
---@param y number
---@return TackleCoinView
function ns.NewBoardCoin(parent, x, y)
	local coin = ns.ArtSprite(parent, "Board", "coin", "ARTWORK", 2)
	ns.PlaceSprite(coin, parent, x, y)
	local label = ns.ArtText(parent, "CoinNumber")
	label:SetJustifyH("CENTER")
	label:SetPoint("CENTER", parent, "TOPLEFT", x + coin.box[3] / 2, -(y + coin.box[4] / 2))
	return { coin = coin, label = label }
end

--- A progress bar (TKB-R102): the empty bar three-sliced to its width, the striped fill cut to the share done.
---@class TackleBarView: TackleThreeSlice
---@field fill TackleSprite
---@field value number
---@field width number
---@field SetBar fun(self: TackleBarView, width: number, fill: number)

---@param parent Frame
---@return TackleBarView
function ns.NewBoardBar(parent)
	local bar = CreateFrame("Frame", nil, parent) --[[@as TackleBarView]]
	bar.fill = ns.ArtSprite(bar, "Board", "bar-fill", "ARTWORK", 1)
	bar.value, bar.width = 0, 0
	function bar.SetBar(self, width, fill)
		fill = math.max(0, math.min(1, fill))
		ns.SetThreeSlice(self, "Board", "bar", width, 5, "ARTWORK")
		ns.SetCropSprite(self.fill, "Board", "bar-fill", math.max(3, width * fill))
		ns.PlaceSprite(self.fill, self, 0, 0)
		self.fill:SetShown(fill > 0)
		self.value, self.width = fill, width
	end
	return bar
end

--- "take it down" in red pencil over a dotted underline (TKB-R55, TKB-R108): a button, greyed while it can't be used.
---@class TackleTakeDownButton: Button
---@field label FontString
---@field dots Texture[]
---@field goalID string?
---@field SetUsable fun(self: TackleTakeDownButton, usable: boolean)

-- The underline's dots: one every 3 units, a little over a unit wide, half see-through.
local DOT_STEP, DOT_WIDTH, DOT_ALPHA = 3, 1.2, 0.5

--- Lays a dotted underline under `label` on `frame`, `width` long, in `hex`: the kit's "take it down" and "Keep it".
---@param frame Frame
---@param label FontString
---@param width number
---@param hex string
---@return Texture[]
function ns.BoardDots(frame, label, width, hex)
	local dots = {}
	for i = 0, width - 2, DOT_STEP do
		local dot = ns.BoardSolid(frame, hex, DOT_ALPHA, "ARTWORK")
		dot:ClearAllPoints()
		dot:SetSize(DOT_WIDTH, 1)
		dot:SetPoint("TOPLEFT", label, "BOTTOMLEFT", i, 0)
		dots[#dots + 1] = dot
	end
	return dots
end

---@param parent Frame
---@param text string
---@return TackleTakeDownButton
function ns.NewTakeDownLink(parent, text)
	local button = CreateFrame("Button", nil, parent) --[[@as TackleTakeDownButton]]
	button.label = ns.ArtText(button, "TakeDown")
	button.label:SetPoint("TOPRIGHT", 0, 0)
	button.label:SetText(text)
	local width = button.label:GetStringWidth()
	button:SetSize(width + 4, 20)
	button.dots = ns.BoardDots(button, button.label, width, ns.BOARD_FONTS.TakeDown[3])
	function button.SetUsable(self, usable)
		self:SetEnabled(usable)
		self:SetAlpha(usable and 1 or 0.45)
	end
	return button
end

--- A leather button with gilt words (TKB-R107: Start my board; TKB-R56: the confirm's "Take it down"), three-sliced to
--- `width`. `SetUsable` greys it while it can't be used; the mouse over it brightens it.
---@class TackleButtonView: Button
---@field face TackleThreeSlice
---@field label FontString
---@field SetUsable fun(self: TackleButtonView, usable: boolean)

---@param parent Frame
---@param text string
---@param width number
---@param font string a font key: "Button", or "ButtonSmall"
---@param onClick fun()
---@return TackleButtonView
function ns.NewBoardButton(parent, text, width, font, onClick)
	local button = CreateFrame("Button", nil, parent) --[[@as TackleButtonView]]
	button.face = CreateFrame("Frame", nil, button) --[[@as TackleThreeSlice]]
	ns.SetThreeSlice(button.face, "Board", "btn", width, 12, "ARTWORK")
	button.face:SetPoint("TOPLEFT")
	button:SetSize(width, button.face:GetHeight())
	button.label = ns.ArtText(button.face, font)
	button.label:SetJustifyH("CENTER")
	button.label:SetPoint("CENTER", button, "CENTER", 0, 1)
	button.label:SetText(text)
	local function light(brightness)
		for _, piece in ipairs({ button.face.left, button.face.middle, button.face.right }) do
			piece:SetVertexColor(brightness, brightness, brightness)
		end
	end
	button:SetScript("OnClick", function()
		onClick()
	end)
	button:SetScript("OnEnter", function(self)
		if self:IsEnabled() then
			light(1.15)
		end
	end)
	button:SetScript("OnLeave", function()
		light(1)
	end)
	function button.SetUsable(self, usable)
		self:SetEnabled(usable)
		self:SetAlpha(usable and 1 or 0.55)
		if not usable then
			light(1)
		end
	end
	return button
end

--- The RE-POSTED stamp (TKB-R55, TKB-R102): its word in red-ink capitals in a double rule, as ink on paper. The kit's
--- stamp sprite is empty, so it is drawn here.
---@class TackleStampView: Frame
---@field label FontString
---@field rules Texture[]

-- The stamp's ink: the kit's red, a little see-through.
local STAMP_INK, STAMP_ALPHA = "9A2A1A", 0.85

---@param parent Frame
---@param text string
---@return TackleStampView
function ns.NewBoardStamp(parent, text)
	local stamp = CreateFrame("Frame", nil, parent) --[[@as TackleStampView]]
	stamp.label = ns.ArtText(stamp, "Stamp")
	stamp.label:SetPoint("CENTER")
	stamp.label:SetText(text)
	stamp:SetSize(stamp.label:GetStringWidth() + 20, 26)
	stamp:SetAlpha(STAMP_ALPHA)
	stamp.rules = {}
	for _, ring in ipairs({ { 0, 2 }, { 4, 1 } }) do
		local inset, thickness = ring[1], ring[2]
		for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local rule = ns.BoardSolid(stamp, STAMP_INK, 1, "ARTWORK")
			rule:ClearAllPoints()
			if side == "TOP" or side == "BOTTOM" then
				local y = side == "TOP" and -inset or inset
				rule:SetPoint(side .. "LEFT", inset, y)
				rule:SetPoint(side .. "RIGHT", -inset, y)
				rule:SetHeight(thickness)
			else
				local x = side == "LEFT" and inset or -inset
				rule:SetPoint("TOP" .. side, x, -inset)
				rule:SetPoint("BOTTOM" .. side, x, inset)
				rule:SetWidth(thickness)
			end
			stamp.rules[#stamp.rules + 1] = rule
		end
	end
	return stamp
end

--- An empty pin (TKB-R105): a faint shade on the cork in a dashed outline, a lone tack, and its words by hand with the
--- time in brackets under them in italics. `SetEmpty` sets its words. It takes no mouse, so the board drags by it.
---@class TackleEmptyPinView: Frame
---@field dashes Texture[]
---@field tack TackleSprite
---@field label FontString
---@field note FontString
---@field SetEmpty fun(self: TackleEmptyPinView, text: string)

---@param parent Frame
---@param width number
---@param height number
---@return TackleEmptyPinView
function ns.NewBoardEmptyPin(parent, width, height)
	local pin = CreateFrame("Frame", nil, parent) --[[@as TackleEmptyPinView]]
	pin:SetSize(width, height)
	ns.BoardSolid(pin, "281204", 0.12, "BACKGROUND")
	pin.dashes = ns.DashBox(pin, width, height, "2C1404", 0.62, 2, 6, 3)
	pin.tack = ns.NewBoardTack(pin)
	ns.PlaceSprite(pin.tack, pin, width / 2 - 7.5, -5)
	pin.label = ns.ArtWrap(pin, "Empty", width - 32, 1)
	pin.label:SetJustifyH("CENTER")
	pin.note = ns.ArtText(pin, "EmptyNote")
	pin.note:SetJustifyH("CENTER")
	pin.note:SetPoint("TOP", pin.label, "BOTTOM", 0, -3)
	function pin.SetEmpty(self, text)
		local line, note = ns.EmptyPinWords(text)
		self.label:SetText(line)
		self.note:SetText(note or "")
		self.note:SetShown(note ~= nil)
		local tall = self.label:GetStringHeight() + (note and 20 or 0)
		self.label:ClearAllPoints()
		self.label:SetPoint("TOP", self, "TOP", 0, -((height - tall) / 2 + 4))
	end
	return pin
end

--- The glowing ring round a pin the board opened on (TKB-R109), hidden until shown, 9 units outside its parent; it
--- pulses twice as it shows (adapter/BoardMotion.lua). Its sprite is the tracker atlas's, set at its first showing, so
--- that atlas loads only when the tracker opens the board on a goal.
---@class TackleHighlightView: Frame
---@field ring TackleSprite?

-- How far the ring lies outside what it rings.
local RING_OUT = 9

---@param parent Frame
---@param poster boolean an Expedition's poster's ring, else a Notice's (stretched to a chip)
---@return TackleHighlightView
function ns.NewBoardHighlight(parent, poster)
	local highlight = CreateFrame("Frame", nil, parent) --[[@as TackleHighlightView]]
	highlight:SetAllPoints()
	highlight:SetScript("OnShow", function(self)
		if not self.ring then
			self.ring = ns.ArtSprite(self, "Tracker", poster and "hl-e" or "hl-n", "BACKGROUND", -8)
		end
		local ring = self.ring --[[@as TackleSprite]]
		local width, height = parent:GetSize()
		ns.SizeSprite(ring, width + 2 * RING_OUT, height + 2 * RING_OUT)
		ns.PlaceSprite(ring, self, -RING_OUT, -RING_OUT)
		ns.RingMotion(self, ring)
	end)
	highlight:Hide()
	return highlight
end

--- A close mark (the Campfire card's and the Fly Box drawer's): a handwritten "×" that hides `target` when clicked.
---@param parent Frame
---@param target Frame
---@param font string a font key: "CardClose", or "DrawerClose"
---@return Button
function ns.NewBoardCloseMark(parent, target, font)
	local close = CreateFrame("Button", nil, parent) --[[@as Button]]
	close:SetSize(26, 34)
	local mark = ns.ArtText(close, font)
	mark:SetPoint("TOPLEFT", 4, 0)
	mark:SetText(ns.L.CLOSE_MARK)
	close:SetScript("OnClick", function()
		target:Hide()
	end)
	return close
end
