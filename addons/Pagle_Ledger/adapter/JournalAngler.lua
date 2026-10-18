if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Angler page's own widget (LED-R146, LED-R34, LED-R112; ledger.md › UI): the bookplate's crest, the Ledger art
-- kit's Prestige crest for the prestige rank (none, I to X, and Master past X) holding the Angler's likeness, the
-- player's portrait masked round over the crest's dark well, with the equipped bookplate crest's emblem pinned at its
-- foot. The kit's P.Crest (Angler.lua, Demo.lua's crests board).

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

---@class LedgerCrestWidget: LedgerJournalWidget
---@field frameArt LedgerSpriteTexture
---@field portrait Texture
---@field emblem LedgerMedal

ns.RegisterJournalWidget("crest", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerCrestWidget]]
	widget.frameArt = ns.JournalSprite(widget, "Crests", "crest-none", "ARTWORK", 0, PLAIN_W, PLAIN_W * 230 / 200)
	widget.portrait = ns.JournalCrisp(widget:CreateTexture(nil, "ARTWORK", nil, 1))
	local mask = widget:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(widget.portrait)
	widget.portrait:AddMaskTexture(mask)
	widget.emblem = ns.JournalMedal(widget, 26)
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
		-- the bookplate crest the Angler has on (LED-R112), pinned at the well's foot; none for Plain
		self.emblem:SetShown(block.icon ~= nil)
		if block.icon ~= nil then
			ns.JournalSetMedal(self.emblem, block.icon, "sepia")
			ns.JournalAt(self.emblem, self, w * 0.21 + size - 22, h * 0.1826 + size - 22)
		end
		self.floatW, self.floatH = w + 18, h + 6
		return 0
	end
	return widget
end)
