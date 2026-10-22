if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Angler page's own widget (LED-R146, LED-R34, LED-R112; ledger.md › UI): the bookplate's crest, the Ledger art
-- kit's Prestige crest for the prestige rank (none, I to X, and Master past X) holding the Angler's likeness, the
-- player's portrait masked round over the crest's dark well, with the equipped bookplate crest's shield pinned at its
-- lower right. The kit's P.Crest (Angler.lua, Demo.lua's crests board) and the crest kit's P.Pinnable (Crests.lua).

-- The crest frames by prestige rank (LED-R34): the kit's twelve, ranks 1 to 10 their own, every Master Prestige the
-- Master's.
local NUMERALS = { "i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x" }

--- The kit's crest sprite for prestige rank `rank`.
---@param rank integer
---@return string
function ns.CrestSprite(rank)
	if rank <= 0 then
		return "crest-none"
	end
	return "crest-" .. (NUMERALS[rank] or "master")
end

-- A crest's width: the plain frame is drawn smaller than a Prestige one, as the canvas does.
local PLAIN_W, PRESTIGE_W = 132, 150

-- The pinned bookplate crest (LED-R146): its shield's width, of the frame's; how far its right edge sits past the
-- frame's and its foot above the frame's, of the frame's width and height, on the plain frame and on a Prestige one,
-- whose wreath and ribbon fill the foot; and its turn, clockwise.
local PIN_W = 0.34
local PIN_PAST = { plain = 0.04, prestige = 0.12 }
local PIN_UP = { plain = 0.02, prestige = 0.16 }
local PIN_TURN = 6

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

-- Pins crest texture `icon` on a crest frame `w` x `h` (`frame` "plain" or "prestige") drawn at `widget`'s top left.
---@param pin LedgerCrestPin
---@param widget Frame
---@param icon integer|string
---@param frame "plain"|"prestige"
---@param w number
---@param h number
local function setPin(pin, widget, icon, frame, w, h)
	local side = w * PIN_W * 140 / 120 -- the shield, 120:140, is the square texture's full height
	pin:SetSize(side, side)
	pin:ClearAllPoints()
	pin:SetPoint(
		"CENTER",
		widget,
		"TOPLEFT",
		w + PIN_PAST[frame] * w - side * 60 / 140,
		-(h - PIN_UP[frame] * h - side / 2)
	)
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

---@class LedgerCrestWidget: LedgerJournalWidget
---@field frameArt LedgerSpriteTexture
---@field portrait Texture
---@field pin LedgerCrestPin

ns.RegisterJournalWidget("crest", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerCrestWidget]]
	widget.frameArt = ns.JournalSprite(widget, "Crests", "crest-none", "ARTWORK", 0, PLAIN_W, PLAIN_W * 230 / 200)
	widget.portrait = ns.JournalCrisp(widget:CreateTexture(nil, "ARTWORK", nil, 1))
	local mask = widget:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(widget.portrait)
	widget.portrait:AddMaskTexture(mask)
	widget.pin = newPin(widget)
	widget.texture = widget.portrait
	function widget.Fill(self, block)
		local name = ns.CrestSprite(block.rank or 0)
		local w = name == "crest-none" and PLAIN_W or PRESTIGE_W
		local h = w * 230 / 200
		local atlas = ns.JOURNAL_ATLASES.Crests
		local sprite = atlas.sprites[name]
		local kx, ky = w / sprite.box[3], h / sprite.box[4]
		ns.JournalSetSprite(self.frameArt, "Crests", name)
		self.frameArt:SetSize(sprite.w / atlas.scale * kx, sprite.h / atlas.scale * ky)
		self.frameArt.box = { sprite.box[1] * kx, sprite.box[2] * ky, w, h }
		ns.JournalBoxAt(self.frameArt, self, 0, 0)
		-- the likeness over the frame's dark well, as the canvas stacks them
		local size = w * 0.58
		self.portrait:SetSize(size, size)
		ns.JournalAt(self.portrait, self, w * 0.21, h * 0.1826)
		SetPortraitTexture(self.portrait, "player")
		-- the bookplate crest the Angler has on (LED-R112), pinned at the frame's lower right; none for Plain
		self.pin:SetShown(block.icon ~= nil)
		if block.icon ~= nil then
			setPin(self.pin, self, block.icon, name == "crest-none" and "plain" or "prestige", w, h)
		end
		self.floatW, self.floatH = w + 18, h + 6
		return 0
	end
	return widget
end)
