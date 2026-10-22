---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Letter on the client (core/onboarding.md › The Letter; the onboarding kit's board "1 · The letter arrives" and
-- PagleArtGuide's P.ShowLetter): logic/Letter.lua's Letter, wired over Core's host by logic/Wiring.lua's
-- ns.WireLetter, drawn here as a frame of Core's own in the toast column's place, above the action bar and centred
-- (ONB-R11): the wax seal and the slip from the guide atlas, its kicker and line in the Angler's hand, Open the letter
-- on leather and Later in the light. It is no Announcement: it never goes through the lanes, so it never counts as an
-- interruption (ANN-R30), Cozy mode never holds it and it never expires. It rises in with its seal dropping (the
-- kit's MOTION.md), settled at once with Animations off, and plays `letter` (SOUND.md). Esc doesn't close it: only its
-- two buttons answer it. PLAYER_ENTERING_WORLD and ZONE_CHANGED_NEW_AREA reach it here (ONB-R10); it is also the menu
-- tooltip's "A letter for you" (ns.LetterShows, ONB-R13), `/pagle dev onboarding letter` (ONB-R83, in the wiring) and
-- the tour stop `core.onboarding.letter` (ONB-R84).

local L = ns.L

-- Its own owner for the client's events, so no other Core file's registration replaces these.
local OWNER = "Pagle letter"

--- The Letter's sound (the kit's SOUND.md): TUTORIAL_POPUP as it arrives, beside the guide's own.
ns.GUIDE_SOUNDS.letter = { id = 7355, motion = false }

--- The Letter's measures, the kit's P.ShowLetter in UI units: the frame (seal and slip), the slip, the seal and where
--- each sits in the frame, its rise and the seal's drop (MOTION.md).
ns.LETTER = {
	width = 534,
	height = 132,
	slipX = 64,
	slipWidth = 470,
	seal = 82,
	sealY = 25,
	rise = 30,
	riseTime = 0.5,
	sealDelay = 0.15,
	sealTime = 0.4,
	sealFrom = 1.6,
}
local LETTER = ns.LETTER

--- The Letter's frame.
---@class PagleLetterFrame: Frame
---@field seal Frame        -- the wax seal and its P, scaled about its centre as it drops
---@field slip Frame        -- the paper, its words and its two buttons
---@field kicker FontString
---@field line FontString
---@field open PagleGuideButton
---@field later PagleGuideButton

--- The Letter's frame, made the first time it shows.
---@type PagleLetterFrame?
ns.letterFrame = nil

-- The light leather button (the kit's LButton with look "light"): its words in the printed ink, no shadow, the
-- paper a little brighter under the mouse; `click` and `onClick` as the guide's buttons.
---@param parent Frame
---@param text string
---@param onClick fun()
---@param height number
---@return PagleGuideButton
local function lightButton(parent, text, onClick, height)
	local button = CreateFrame("Button", nil, parent) --[[@as PagleGuideButton]]
	button.rest = ns.NewNineSlice(button, "GuideParts", "button-light", { 10, 8 })
	button.label = ns.GuideText(button, "gilt", 15, "body", text, { justify = "CENTER" })
	button:SetSize(math.ceil(button.label:GetStringWidth()) + 36, height)
	button.label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetScript("OnEnter", function(self)
		self.rest:SetVertexColor(1.08, 1.08, 1.08)
	end)
	button:SetScript("OnLeave", function(self)
		self.rest:SetVertexColor(1, 1, 1)
	end)
	button:SetScript("OnClick", function()
		ns.GuideSound("click")
		onClick()
	end)
	return button
end

-- Puts the seal at scale `scale` about its centre, the kit's 41, 41 inside its 82-unit square at 0, 25 of the frame:
-- a frame's offsets are in its own scale, so they shrink with it.
---@param frame PagleLetterFrame
---@param scale number
local function scaleSeal(frame, scale)
	local seal = frame.seal
	seal:SetScale(scale)
	seal:ClearAllPoints()
	seal:SetPoint("CENTER", frame, "TOPLEFT", LETTER.seal / 2 / scale, -(LETTER.sealY + LETTER.seal / 2) / scale)
end

-- Puts the frame `drop` units below its place: its foot on the toast column's (ANN-R20), centred.
---@param frame PagleLetterFrame
---@param drop number
local function place(frame, drop)
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, ns.ANNOUNCE_COLUMN_FOOT - drop)
end

-- The frame at rest: in its place, whole, its seal on.
---@param frame PagleLetterFrame
local function settle(frame)
	Pagle.StopMotion(frame)
	place(frame, 0)
	frame:SetAlpha(1)
	scaleSeal(frame, 1)
	frame.seal:SetAlpha(1)
end

-- The frame, made at the first showing: the kit's P.ShowLetter, positions from its top left, y down.
---@return PagleLetterFrame
local function frameOf()
	local frame = ns.letterFrame
	if frame then
		return frame
	end
	frame = CreateFrame("Frame", "PagleLetter", UIParent) --[[@as PagleLetterFrame]]
	frame:SetSize(LETTER.width, LETTER.height)
	frame:SetFrameStrata("DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	local slip = CreateFrame("Frame", nil, frame)
	slip:SetSize(LETTER.slipWidth, LETTER.height)
	ns.GuideAt(slip, frame, LETTER.slipX, 0)
	ns.PlaceSprite(ns.ArtSprite(slip, "GuideParts", "letter-slip", "BACKGROUND"), slip, 0, 0)
	frame.slip = slip
	-- The kit's P.T: each line's box is its line height, the text in its middle.
	frame.kicker = ns.GuideText(slip, "sc", 14, "kicker", L.LETTER_KICKER)
	ns.GuideAt(frame.kicker, slip, 34, 12 + (18 - 14) / 2)
	frame.line = ns.GuideText(slip, "hand", 25, "hand", L.LETTER_LINE, { wrap = true, width = 392, spacing = 2.5 })
	ns.GuideAt(frame.line, slip, 34, 30 + (27.5 - 25) / 2)
	frame.open = ns.NewGuideButton(slip, L.LETTER_OPEN, function()
		ns.letter:Open()
	end, nil, 28)
	ns.GuideAt(frame.open, slip, 34, 92)
	frame.later = lightButton(slip, L.LETTER_LATER, function()
		ns.letter:Later()
	end, 28)
	ns.GuideAt(frame.later, slip, 34 + frame.open:GetWidth() + 14, 92)

	-- The seal over the slip's left edge, its P in gilt on the wax.
	local seal = CreateFrame("Frame", nil, frame)
	seal:SetSize(LETTER.seal, LETTER.seal)
	seal:SetFrameLevel(frame:GetFrameLevel() + 3)
	ns.PlaceSprite(ns.ArtSprite(seal, "GuideParts", "letter-seal", "ARTWORK"), seal, 0, 0)
	local mark = ns.GuideText(seal, "gilt", 26, "wax", L.LETTER_SEAL, { shadow = true, justify = "CENTER" })
	mark:SetPoint("TOP", seal, "TOPLEFT", LETTER.seal / 2, -(25 + (32 - 26) / 2))
	frame.seal = seal

	ns.letterFrame = frame
	settle(frame)
	return frame
end

-- The Letter's view (PagleLetterView): on screen with `letter` and its rise (0.5 s, ease-out, 30 units up and in)
-- and its seal's drop (from 1.6x, 0.15–0.55 s, overshooting a little); with Animations off it appears settled. In
-- Cozy mode it arrives silently (onboarding.md › Sounds: only what the player clicks plays).
local function show()
	local frame = frameOf()
	settle(frame)
	frame:Show()
	if not ns.db.profile.announcements.cozy then
		ns.GuideSound("letter")
	end
	frame:SetAlpha(0)
	frame.seal:SetAlpha(0)
	Pagle.Animate(frame, {
		{
			dur = LETTER.riseTime,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0, LETTER.rise } }, { 1, { 1, 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
				place(frame, v[2])
			end,
		},
		{
			dur = LETTER.sealTime,
			delay = LETTER.sealDelay,
			ease = Pagle.Bezier(0.3, 1.4, 0.6, 1),
			keys = { { 0, { LETTER.sealFrom, 0 } }, { 1, { 1, 1 } } },
			apply = function(v)
				scaleSeal(frame, v[1])
				frame.seal:SetAlpha(v[2])
			end,
		},
	})
end

-- Off screen at once, left at rest for its next showing.
local function hide()
	local frame = ns.letterFrame
	if frame then
		settle(frame)
		frame:Hide()
	end
end

ns.WireLetter(ns.host, {
	show = show,
	hide = hide,
	inInstance = function()
		return (IsInInstance()) == true
	end,
})

-- ONB-R10: the delay counts from each PLAYER_ENTERING_WORLD (an instance's loading screen hides it); a new zone is
-- checked again.
Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", function()
	ns.letter:EnteredWorld()
end)
Pagle.RegisterEvent(OWNER, "ZONE_CHANGED_NEW_AREA", function()
	ns.letter:Check()
end)

-- ONB-R13: the menu's tooltip (adapter/Menu.lua's ns.FillMenuTooltip) reads "A letter for you" while it shows. Put in
-- at PLAYER_LOGIN, so it replaces the menu's stand-in whichever file loads first.
Pagle.RegisterEvent(OWNER, "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent(OWNER, "PLAYER_LOGIN")
	-- rawset: a replacement of adapter/Menu.lua's hook, not a second definition of it.
	rawset(ns, "LetterShows", function()
		return ns.letter:IsShowing()
	end)
end)

-- ONB-R84: the Letter as a sample, whose hide puts back what its show changed (CORE-R68).
local problem = ns.tourStops:Add(ns.TOUR_CORE, "onboarding.letter", L.DEV_TOUR_LETTER, function()
	ns.letter:TourShow()
end, function()
	ns.letter:TourHide()
end)
if problem then
	error(problem)
end
