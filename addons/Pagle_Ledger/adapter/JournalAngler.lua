if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Angler page's own widget (LED-R146, LED-R154, LED-R112; ledger.md › UI): the bookplate's Prestige frame for the
-- prestige rank, Core's (Pagle.NewPrestigeFrame, its art in Core's media/prestige/), holding the Angler's likeness,
-- the player's portrait masked round in its well, with the equipped bookplate crest's shield pinned at the frame's
-- pin. From V up the frame moves while the page is open, with Animations on; hovering it names it (LED-R154). The
-- crest kit's P.Pinnable (Crests.lua) for the pin.

-- The frame drawn at this share of the kit's 260 × 280 box (LED-R146): 169 × 182 units, the likeness 73 across.
local FRAME_SCALE = 0.65
-- The pinned crest's shield is 120:140, its square texture's full height, and turned 6° clockwise (LED-R146).
local SHIELD_SIDE = 140 / 120
local PIN_TURN = 6
-- The room the frame takes at the page's left, past its box, for the words beside it.
local FLOAT_GAP = 4
-- The emblem before the rank's name in the frame's tooltip (LED-R152), and the gilt of its name.
local TIP_EMBLEM = 22
local TIP_GILT = "f0cd6a"

--- Turns a pinned crest's texture PIN_TURN degrees clockwise, on a client whose textures turn; upright otherwise.
---@param texture Texture
function ns.TurnPin(texture)
	if texture.SetRotation then
		texture:SetRotation(-math.rad(PIN_TURN))
	end
end

--- The pinned bookplate crest: the crest's whole square texture (so the turn never meets a crop), its shadow under
--- it and a gilt pin through its top.
---@class LedgerCrestPin: Frame
---@field shield Texture
---@field shadow Texture
---@field head Frame

---@param parent Frame
---@return LedgerCrestPin
local function newPin(parent)
	local pin = CreateFrame("Frame", nil, parent) --[[@as LedgerCrestPin]]
	pin.shadow = ns.JournalCrisp(pin:CreateTexture(nil, "ARTWORK", nil, 0))
	pin.shadow:SetVertexColor(0, 0, 0, 0.5)
	pin.shield = ns.JournalCrisp(pin:CreateTexture(nil, "ARTWORK", nil, 1))
	pin.shield:SetAllPoints()
	ns.TurnPin(pin.shadow)
	ns.TurnPin(pin.shield)
	pin.head = CreateFrame("Frame", nil, pin)
	for i, tint in ipairs({ { "281405", 0.55 }, { "E8C96A", 1 } }) do
		local dot = ns.JournalTint(pin.head, tint[1], tint[2], "OVERLAY", i)
		local inset = i - 1
		dot:SetPoint("TOPLEFT", inset, -inset)
		dot:SetPoint("BOTTOMRIGHT", -inset, inset)
		local mask = pin.head:CreateMaskTexture()
		mask:SetTexture(
			"Interface\\CharacterFrame\\TempPortraitAlphaMask",
			"CLAMPTOBLACKADDITIVE",
			"CLAMPTOBLACKADDITIVE"
		)
		mask:SetAllPoints(dot)
		dot:AddMaskTexture(mask)
	end
	return pin
end

-- Pins crest texture `icon` on the frame drawn at `widget`'s top left: its shield `width` wide, centred on the frame's
-- pin point (`x`, `y` from the top left, y down).
---@param pin LedgerCrestPin
---@param widget Frame
---@param icon integer|string
---@param x number
---@param y number
---@param width number
local function setPin(pin, widget, icon, x, y, width)
	local side = width * SHIELD_SIDE
	pin:SetSize(side, side)
	pin:ClearAllPoints()
	pin:SetPoint("CENTER", widget, "TOPLEFT", x, -y)
	pin.shield:SetTexture(icon)
	pin.shadow:SetTexture(icon)
	pin.shadow:SetSize(side, side)
	pin.shadow:ClearAllPoints()
	pin.shadow:SetPoint("CENTER", pin, "CENTER", 1, -2.5)
	local head = math.max(5, side * 0.12)
	pin.head:SetSize(head, head)
	pin.head:ClearAllPoints()
	pin.head:SetPoint("CENTER", pin, "TOP", side * 0.05, -side * 0.04)
end

---@class LedgerPrestigeFrameWidget: LedgerJournalWidget
---@field frame PaglePrestigeFrame
---@field pin LedgerCrestPin
---@field rank integer

-- The frame's tooltip (LED-R154), over the frame: its name in gilt and its description, then the rank's name with
-- its emblem.
---@param widget LedgerPrestigeFrameWidget
local function showTip(widget)
	local tip = ns.PrestigeFrameTip(widget.rank, Pagle.GetPrestigeFrame(widget.rank).key)
	GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
	GameTooltip:SetText(tip.name or tip.rank, ns.JournalRGB(TIP_GILT))
	if tip.description then
		GameTooltip:AddLine(tip.description, 1, 1, 1, true)
	end
	if tip.name then
		local emblem = Pagle.PrestigeEmblemMarkup(widget.rank, TIP_EMBLEM)
		GameTooltip:AddLine(emblem == "" and tip.rank or emblem .. " " .. tip.rank, 0.8, 0.8, 0.8)
	end
	GameTooltip:Show()
end

ns.RegisterJournalWidget("prestigeFrame", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerPrestigeFrameWidget]]
	widget.frame = Pagle.NewPrestigeFrame(widget)
	widget.frame:SetPoint("TOPLEFT")
	widget.pin = newPin(widget)
	widget.pin:SetFrameLevel(widget.frame:GetFrameLevel() + 2)
	widget.texture = widget.frame:GetWell()
	widget.rank = 0
	-- The page gives a float no height, so the frame itself takes the mouse.
	widget.frame:EnableMouse(true)
	widget.frame:SetScript("OnEnter", function()
		showTip(widget)
	end)
	widget.frame:SetScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	function widget.Fill(self, block)
		local rank = block.rank or 0
		self.rank = rank
		local frame = self.frame
		frame:SetRank(rank, FRAME_SCALE)
		SetPortraitTexture(frame:GetWell(), "player")
		-- From V up it moves while the page shows, with Animations on; the page closed, it stops (LED-R154).
		frame:Play()
		-- the bookplate crest the Angler has on (LED-R112), pinned at the frame's pin; none for Plain
		local x, y, width = frame:GetPin()
		if block.icon ~= nil and x and y and width then
			self.pin:Show()
			setPin(self.pin, self, block.icon, x, y, width)
		else
			self.pin:Hide()
		end
		local w, h = frame:GetSize()
		self.floatW, self.floatH = w + FLOAT_GAP, h
		if GameTooltip:IsOwned(frame) then
			showTip(self)
		end
		return 0
	end
	return widget
end)
