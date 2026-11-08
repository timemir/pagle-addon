---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The party toast's frame (announcements.md › Party toasts and cheers, ANN-R107, ANN-R108, UI › Party toast; from
-- 1.5.x, #640): one compact style for every groupmate and every toast style, the groupmate's name over the moment's
-- line, and the mug at its right edge. adapter/Announcements.lua's lanes acquire it for a party toast shown as a
-- toast (a stepped-down one is a plain Nod) and draw it through ns.DrawAnnouncement. Loaded by adapter/Settings.xml.
local L = ns.L

--- A frame the lanes draw a party toast on (ANN-R107): ns.DrawAnnouncement draws it in the party style.
---@class PagleAnnouncementFrame
---@field party? true

--- The party style's art, every reference in one place (ANN-R107): placeholders from Pagle's own textures and the
--- game's icons until the designer's party atlas arrives, which drops in here.
ns.PARTY_ART = {
	-- The page, nine-sliced to the frame: the Session summary card's torn ledger page.
	page = { atlas = "Announce", sprite = "card-body", cap = 12 },
	-- The medallion's ring at 34.
	ring = { atlas = "Announce", sprite = "bezel-silver-34" },
	-- The mug (ANN-R108), and the icon of a cheer's Nod.
	mug = "Interface\\Icons\\INV_Drink_04",
	-- The medallion's icon for a kind that sends no item.
	icons = {
		zone = "Interface\\Icons\\INV_Misc_Spyglass_03",
		prestige = "Interface\\Icons\\INV_Misc_Ribbon_01",
		ledger = "Interface\\Icons\\INV_Scroll_03",
	},
}

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"

--- The party sounds (ANN-R108), every path in one place: placeholders from Pagle's own Glass Floats set, green glass
--- floats knocking together, until party sounds of their own are made.
ns.PARTY_SOUNDS = {
	arrive = SOUNDS .. "glass\\toast_2.ogg",
	raise = SOUNDS .. "glass\\toast_1.ogg",
	cheered = SOUNDS .. "glass\\toast_3.ogg",
}

--- The party toast's size (ANN-R107; Tunables): smaller than the player's own 464 × 92.
ns.PARTY_TOAST_WIDTH, ns.PARTY_TOAST_HEIGHT = 380, 50

-- The layout: the medallion's left, the words' left, the mug's size and its inset from the right edge.
local MEDALLION_X, WORDS_X, MUG_SIZE, MUG_INSET = 9, 52, 28, 10
-- A raised mug's look: greyed and dimmed.
local RAISED_ALPHA = 0.55
-- The fade it shows with (UI › Motion: a Nod's).
local FADE_SECONDS = 0.3

-- Draws the mug as it is for `frame`'s toast: raised, or not yet.
---@param frame table
local function paintMug(frame)
	local display = frame.display
	local toast = display and display.announcement.headline.partyToast
	local raised = toast ~= nil and toast.raised == true
	local mug = frame.mug
	mug.icon:SetDesaturated(raised)
	mug:SetAlpha(raised and RAISED_ALPHA or 1)
	if GameTooltip:IsOwned(mug) then
		GameTooltip:SetText(raised and L.PARTY_MUG_RAISED or L.PARTY_MUG, 1, 1, 1)
	end
end

--- A party toast's frame, hidden, on `parent` (UIParent by default): the page, the medallion, the two lines and the
--- mug, a button of its own whose clicks never reach the toast (ANN-R108).
---@param parent Frame?
---@return table
function ns.NewPartyToastFrame(parent)
	local art = ns.PARTY_ART
	local frame = CreateFrame("Frame", nil, parent or UIParent)
	frame:SetSize(ns.PARTY_TOAST_WIDTH, ns.PARTY_TOAST_HEIGHT)
	frame:SetFrameStrata("HIGH")
	frame.party = true
	frame.page = ns.NewNineSlice(frame, art.page.atlas, art.page.sprite, art.page.cap)
	frame.bezel = ns.NewBezel(frame)
	frame.bezel:SetPoint("LEFT", frame, "LEFT", MEDALLION_X, 0)
	frame.kicker = ns.ArtText(frame, "NodWhat")
	frame.kicker:SetPoint("TOPLEFT", frame, "TOPLEFT", WORDS_X, -7)
	frame.line = ns.ArtText(frame, "NodName")
	frame.line:SetPoint("TOPLEFT", frame.kicker, "BOTTOMLEFT", 0, -1)
	local mug = CreateFrame("Button", nil, frame)
	mug:SetSize(MUG_SIZE, MUG_SIZE)
	mug:SetPoint("RIGHT", frame, "RIGHT", -MUG_INSET, 0)
	mug.icon = mug:CreateTexture(nil, "ARTWORK")
	mug.icon:SetAllPoints(mug)
	mug.icon:SetTexture(art.mug)
	mug.icon:SetTexCoord(ns.ICON_CROP, 1 - ns.ICON_CROP, ns.ICON_CROP, 1 - ns.ICON_CROP)
	mug:SetScript("OnClick", function()
		local display = frame.display
		if display and ns.RaisePartyMug(display) then
			paintMug(frame)
		end
	end)
	-- The pointer on the mug keeps the toast's clock stopped: leaving the toast for it ran the toast's OnLeave.
	mug:SetScript("OnEnter", function(self)
		local display = frame.display
		if display then
			ns.lanes:Pause(display)
			local toast = display.announcement.headline.partyToast
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(toast and toast.raised and L.PARTY_MUG_RAISED or L.PARTY_MUG, 1, 1, 1)
			GameTooltip:Show()
		end
	end)
	mug:SetScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
		if frame.display then
			ns.lanes:Resume(frame.display)
		end
	end)
	frame.mug = mug
	frame:Hide()
	return frame
end

--- Draws a party toast in the party style (ANN-R107): the moment's icon, the groupmate's name in capitals over the
--- line, cut to the room before the mug, and the mug as it is. A new display fades in (UI › Motion); drawn again for
--- the same one, it stays as it is.
---@param frame table
---@param display PagleDisplay
function ns.DrawPartyToast(frame, display)
	local headline = display.announcement.headline
	ns.SetBezel(frame.bezel, 34, ns.PARTY_ART.ring, ns.TextureOf(headline.icon))
	local room = ns.PARTY_TOAST_WIDTH - WORDS_X - MUG_INSET - MUG_SIZE - 8
	frame.kicker:SetText(ns.Capitals(headline.title))
	ns.ShrinkToFit(frame.kicker, "NodWhat", room)
	frame.line:SetText(headline.text or "")
	ns.ShrinkToFit(frame.line, "NodName", room)
	paintMug(frame)
	if frame.moved ~= display and frame.lanes then
		frame.moved = display
		ns.StopMotion(frame)
		ns.Animate(frame, {
			{
				dur = FADE_SECONDS,
				ease = ns.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					frame:SetAlpha(v[1])
				end,
			},
		})
	end
end
