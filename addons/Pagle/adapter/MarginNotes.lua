---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Margin notes on the client (core/onboarding.md › Margin notes, › UI, › Motion): logic/MarginNotes.lua's notes as
-- logic/Wiring.lua wires them over adapter/Host.lua's host, drawn here. A note is a slip of the guide atlas's note
-- paper (GuideParts) in UIParent, unscaled (ONB-R106), its text in the Angler's pencil (Caveat) with its term in red,
-- a red-pencil number badge, and a pencil arrow of Line objects (Frame:CreateLine; the probe's drew in the client) to
-- a red ring on its target. Only the paper takes the mouse: a click sends it away (ONB-R51). Each frame while a note
-- shows, its arrow re-reads where its target is, redrawing at once when it moved (ONB-R56) and sending the note away
-- when its target hid (ONB-R51). The Field guide's illustrative notes draw their arrows here too (ns.DrawNoteArrow).
-- Core's first-moment notes come from adapter/Announcements.lua's and adapter/Cards.lua's show (ns.NoteAnnouncement,
-- ns.NoteCard). Loaded before adapter/Login.lua, so the onboarding hooks are set before PLAYER_LOGIN raises them.

local INKS = ns.GUIDE_INKS
local SEGMENTS = ns.NOTE_ARROW_SEGMENTS
-- CSS's ease-in, as a note leaves (MOTION.md).
local EASE_IN = ns.Bezier(0.42, 0, 1, 1)

-- A note's width when Core gives none (the canvas's, board "Margin notes on first moments"), and Core's own notes'.
local NOTE_WIDTH = 270
local CORE_WIDTHS = {
	["core.nod"] = 250,
	["core.toast"] = 280,
	["core.summary"] = 260,
	["core.uncharted"] = 300,
	["core.welcome"] = 250,
	["core.character"] = 250,
}
-- The arrow's bow, as the kit's P.Pointed gives an odd-numbered note (a share of its length, to the left of travel).
local BEND = 0.2

--- A note's pencil arrow: Lines from its note to its target, the head's two strokes after the curve's, and the ring.
---@class PagleNoteArrow: Frame
---@field lines Line[]
---@field ring PagleSprite
---@field from Region the note it starts from
---@field to fun(): Region? what it points at now, nil once that's gone
---@field reveal number how much of it is drawn on, 0 to 1 (MOTION.md)
---@field ringScale number the ring's size, 1 settled (MOTION.md's pop)
---@field drawn number[]? the rectangles it was last drawn for: the note's, then the target's
---@field onGone fun()? called once when its target hides or goes
---@field Redraw fun(self: PagleNoteArrow)

-- `region`'s rectangle in `frame`'s units (y up, from the screen's bottom left), or nil while it isn't laid out.
---@param region Region
---@param frame Frame
---@return PagleRect?
local function rectIn(region, frame)
	local left, right, bottom, top = region:GetLeft(), region:GetRight(), region:GetBottom(), region:GetTop()
	if not (left and right and bottom and top) then
		return nil
	end
	local k = region:GetEffectiveScale() / frame:GetEffectiveScale()
	return { left = left * k, right = right * k, bottom = bottom * k, top = top * k }
end

-- Shows as much of the arrow as `reveal` says, segment by segment, the head once the curve is whole, and the ring at
-- its size.
---@param arrow PagleNoteArrow
local function paintArrow(arrow)
	local shown = arrow.reveal * SEGMENTS
	local whole = arrow.reveal >= 1
	for i, line in ipairs(arrow.lines) do
		line:SetShown(arrow.drawn ~= nil and (i <= SEGMENTS and i <= shown or i > SEGMENTS and whole))
	end
	arrow.ring:SetShown(arrow.drawn ~= nil and whole)
	local box = ns.ATLASES.GuideParts.sprites.ring
	local size = box.w / ns.ATLASES.GuideParts.scale * arrow.ringScale
	arrow.ring:SetSize(size, size)
end

-- Whether `region` shows now.
---@param region Region?
---@return boolean
local function visible(region)
	return region ~= nil and region:IsVisible() == true
end

-- Draws the arrow from its note to its target as they are now (core/onboarding.md › UI), if both are laid out.
---@param arrow PagleNoteArrow
local function drawArrow(arrow)
	local target = arrow.to()
	local from = rectIn(arrow.from, arrow)
	local to = target and rectIn(target, arrow)
	if not (from and to) then
		return
	end
	arrow.drawn = { from.left, from.right, from.bottom, from.top, to.left, to.right, to.bottom, to.top }
	local path = ns.NoteArrowPath(from, to, BEND)
	local function ends(line, a, b)
		line:SetStartPoint("BOTTOMLEFT", UIParent, a[1], a[2])
		line:SetEndPoint("BOTTOMLEFT", UIParent, b[1], b[2])
	end
	for i = 1, SEGMENTS do
		ends(arrow.lines[i], path.points[i], path.points[i + 1])
	end
	for i, stroke in ipairs(path.head) do
		ends(arrow.lines[SEGMENTS + i], stroke, path.finish)
	end
	arrow.ring:ClearAllPoints()
	arrow.ring:SetPoint("CENTER", UIParent, "BOTTOMLEFT", path.finish[1], path.finish[2])
	paintArrow(arrow)
end

-- Each frame while shown: the target gone or hidden calls onGone, once; a note or target that moved redraws at once.
---@param arrow PagleNoteArrow
local function watch(arrow)
	if not arrow:IsVisible() then
		return
	end
	local target = arrow.to()
	if not visible(target) then
		local gone = arrow.onGone
		if gone then
			arrow.onGone = nil
			gone()
		end
		return
	end
	---@cast target Region
	local from, to = rectIn(arrow.from, arrow), rectIn(target, arrow)
	if not (from and to) then
		return
	end
	local drawn = arrow.drawn
	if
		not drawn
		or drawn[1] ~= from.left
		or drawn[2] ~= from.right
		or drawn[3] ~= from.bottom
		or drawn[4] ~= from.top
		or drawn[5] ~= to.left
		or drawn[6] ~= to.right
		or drawn[7] ~= to.bottom
		or drawn[8] ~= to.top
	then
		drawArrow(arrow)
	end
end

--- A pencil arrow on `parent` from `from` (a note) to what `to` returns (core/onboarding.md › UI): Lines 2 thick in
--- the Angler's pencil at 90%, a quadratic curve in 14 segments with a two-stroke head, and a 12-unit red ring at its
--- point, drawn settled. It follows both while shown, redrawing at once when either moves (ONB-R56). For First looks
--- (#326) as for Margin notes.
---@param parent Frame
---@param from Region
---@param to fun(): Region?
---@return PagleNoteArrow
function ns.NewNoteArrow(parent, from, to)
	local arrow = CreateFrame("Frame", nil, parent) --[[@as PagleNoteArrow]]
	arrow:SetAllPoints(UIParent)
	arrow:SetFrameLevel(parent:GetFrameLevel() + 1)
	arrow.from, arrow.to, arrow.reveal, arrow.ringScale = from, to, 1, 1
	arrow.lines = {}
	local ink = INKS.hand
	for i = 1, SEGMENTS + 2 do
		local line = arrow:CreateLine(nil, "OVERLAY")
		line:SetThickness(2)
		line:SetColorTexture(ink[1], ink[2], ink[3], 0.9)
		line:Hide()
		arrow.lines[i] = line
	end
	arrow.ring = ns.ArtSprite(arrow, "GuideParts", "ring", "OVERLAY", 2)
	arrow.ring:Hide()
	arrow.Redraw = drawArrow
	arrow:SetScript("OnUpdate", watch)
	drawArrow(arrow)
	return arrow
end

-- The Field guide's illustrative notes (nav.Note, adapter/GuideKit.lua): the arrow from the note to its target on the
-- page, part of the page, so drawn settled (ONB-R50).
---@param note Frame
---@param target Region
---@return PagleNoteArrow
function ns.DrawNoteArrow(note, target)
	return ns.NewNoteArrow(note, note, function()
		return target
	end)
end

--- A Margin note's frame: its paper, its text and its badge, with its arrow once shown. For First looks (#326) too.
---@class PagleMarginNoteFrame: Frame
---@field paper PagleNineSlice
---@field text FontString
---@field badge PagleSprite
---@field number FontString
---@field arrow PagleNoteArrow?
---@field note PagleMarginNote? the note it shows
---@field inUse boolean showing a note, or still leaving

--- A Margin note's paper on `parent` (core/onboarding.md › UI; the kit's P.Note): Caveat 19 in the Angler's pencil,
--- `width` wide and as tall as its text, with the red-pencil badge reading `n`. Only it takes the mouse (ONB-R51).
---@param parent Frame
---@return PagleMarginNoteFrame
function ns.NewMarginNoteFrame(parent)
	local frame = CreateFrame("Frame", nil, parent) --[[@as PagleMarginNoteFrame]]
	frame.paper = ns.NewNineSlice(frame, "GuideParts", "note", 6)
	frame.text = ns.GuideText(frame, "hand", 19, "hand", "", { wrap = true, spacing = 2.3 })
	frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 15, -10)
	frame.badge = ns.ArtSprite(frame, "GuideParts", "note-badge", "OVERLAY", 1)
	ns.PlaceSprite(frame.badge, frame, -12, -12)
	frame.number = ns.GuideText(frame, "handBold", 17, "red", "1", { justify = "CENTER" })
	frame.number:SetDrawLayer("OVERLAY", 3)
	frame.number:SetPoint("CENTER", frame, "TOPLEFT", 1, -1)
	frame:EnableMouse(true)
	frame.inUse = false
	return frame
end

--- Writes `text` on a note's paper `width` wide, numbered `n`, and sizes it to its text (the kit's P.Note).
---@param frame PagleMarginNoteFrame
---@param text string
---@param width number
---@param n integer
function ns.SetMarginNoteText(frame, text, width, n)
	frame.text:SetWidth(width - 28)
	frame.text:SetText(text)
	frame:SetSize(width, math.floor(frame.text:GetStringHeight() + 21 + 0.5))
	frame.number:SetText(tostring(n))
end

--- A note appearing (MOTION.md): it fades in (0.25 s, ease-out), its arrow draws on from note to target (0.2–0.55 s,
--- ease-in-out) and its ring pops from 0.4x (0.55–0.7 s), all `delay` later (a First look's notes start 0.12 s
--- apart). With Animations off it appears settled. The caller plays `noteIn`, once for a note or a set (ONB-R55).
---@param frame PagleMarginNoteFrame
---@param delay number?
function ns.NoteIn(frame, delay)
	delay = delay or 0
	local arrow = frame.arrow
	local animations = {
		{
			dur = 0.25,
			delay = delay,
			ease = ns.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	}
	if arrow then
		animations[2] = {
			dur = 0.35,
			delay = delay + 0.2,
			ease = ns.EASE.inOut,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				arrow.reveal = v[1]
				paintArrow(arrow)
			end,
		}
		animations[3] = {
			dur = 0.15,
			delay = delay + 0.55,
			ease = ns.Bezier(0.3, 1.6, 0.6, 1),
			keys = { { 0, { 0.4 } }, { 1, { 1 } } },
			apply = function(v)
				arrow.ringScale = v[1]
				paintArrow(arrow)
			end,
		}
		arrow.reveal, arrow.ringScale = 0, 0.4
		paintArrow(arrow)
	end
	frame:SetAlpha(0)
	ns.StopMotion(frame)
	ns.Animate(frame, animations)
end

--- `noteIn` (the kit's SOUND.md): never in Cozy mode, where only what the player clicks plays.
function ns.PlayNoteIn()
	if not ns.db.profile.announcements.cozy then
		ns.GuideSound("noteIn")
	end
end

--- The world's note frames, made as needed, in DIALOG strata over the Announcements (HIGH), under a splash: each with
--- the note it shows (`note`), nil once it leaves.
---@type PagleMarginNoteFrame[]
ns.marginNoteFrames = {}
local frames = ns.marginNoteFrames

-- The frame showing `note`, if one is.
---@param note PagleMarginNote
---@return PagleMarginNoteFrame?
local function frameOf(note)
	for _, frame in ipairs(frames) do
		if frame.note == note then
			return frame
		end
	end
	return nil
end

-- What a note points at now: its target, or what its function returns.
---@param note PagleMarginNote
---@return Region?
local function resolve(note)
	local target = note.target
	if type(target) == "function" then
		return target()
	end
	return target --[[@as Region]]
end

-- Puts a note's frame beside its target as it is now (ns.PlaceMarginNote), or in the screen's middle while the target
-- isn't laid out; its arrow follows once it is.
---@param frame PagleMarginNoteFrame
---@param note PagleMarginNote
local function placeNote(frame, note)
	local target = resolve(note)
	local rect = target and rectIn(target, frame)
	local width, height = frame:GetWidth(), frame:GetHeight()
	frame:ClearAllPoints()
	if rect then
		local screen = { width = UIParent:GetWidth(), height = UIParent:GetHeight() }
		local place = ns.PlaceMarginNote(rect, width, height, screen, note.side)
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", place.left, place.top)
	else
		frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
end

-- A frame free for a note, made if none is.
---@return PagleMarginNoteFrame
local function acquire()
	for _, frame in ipairs(frames) do
		if not frame.inUse then
			return frame
		end
	end
	local frame = ns.NewMarginNoteFrame(UIParent)
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frame:SetScript("OnMouseUp", function(self)
		if self.note then
			ns.marginNotes:Leave(self.note.id)
		end
	end)
	frames[#frames + 1] = frame
	return frame
end

-- The view's show: the note's frame, placed, its arrow drawn, moving in and playing noteIn.
---@param note PagleMarginNote
local function show(note)
	local frame = acquire()
	ns.StopMotion(frame)
	frame.inUse, frame.note = true, note
	ns.SetMarginNoteText(frame, note.text, CORE_WIDTHS[note.id] or NOTE_WIDTH, 1)
	placeNote(frame, note)
	frame:Show()
	if not frame.arrow then
		frame.arrow = ns.NewNoteArrow(frame, frame, function()
			return nil
		end)
	end
	local arrow = frame.arrow --[[@as PagleNoteArrow]]
	arrow.to = function()
		return resolve(note)
	end
	arrow.drawn = nil
	arrow.onGone = function()
		ns.marginNotes:TargetHidden(note.id)
	end
	arrow:Redraw()
	ns.NoteIn(frame)
	ns.PlayNoteIn()
end

-- The view's hide: the note fades out (0.2 s, ease-in), arrow and ring with it, then its frame is free; at once for a
-- restriction, with Animations off, or off screen (MOTION.md).
---@param note PagleMarginNote
---@param atOnce boolean
local function hide(note, atOnce)
	local frame = frameOf(note)
	if not frame then
		return
	end
	frame.note = nil
	if frame.arrow then
		frame.arrow.onGone = nil
	end
	ns.StopMotion(frame)
	local function free()
		frame:Hide()
		frame.inUse = false
	end
	if atOnce or not (ns.MotionOn() and frame:IsVisible()) then
		free()
		return
	end
	local alpha = frame:GetAlpha()
	ns.Animate(frame, {
		{
			dur = 0.2,
			ease = EASE_IN,
			keys = { { 0, { alpha } }, { 1, { 0 } } },
			apply = function(v)
				frame:SetAlpha(v[1])
			end,
		},
	})
	-- On the clock, so it goes even if nothing draws (a frame showing another note meanwhile stays).
	C_Timer.After(0.2, function()
		if not frame.note then
			ns.StopMotion(frame)
			free()
		end
	end)
end

-- The newest frame of the column showing `form` now.
---@param form PagleAnnouncementForm
---@return PagleAnnouncementFrame?
local function columnFrame(form)
	for _, frame in ipairs(ns.columnFrames) do
		if frame.display and frame.display.form == form then
			return frame
		end
	end
	return nil
end

-- What Core's notes point at, as the wiring's view resolves them (ONB-R52): a target function, or nil while nothing
-- it could point at shows.
---@type table<string, fun(): PagleNoteTarget?>
local CORE_TARGETS = {
	nod = function()
		local frame = columnFrame("nod")
		if not frame then
			return nil
		end
		return function()
			return frame.display and frame or nil
		end
	end,
	coin = function()
		local frame = columnFrame("toast")
		if not frame then
			return nil
		end
		return function()
			return frame.display and frame.coins.coin or nil
		end
	end,
	card = function()
		local frame = ns.cardFrame
		if not (frame and frame.card) then
			return nil
		end
		return function()
			return frame.card and frame or nil
		end
	end,
	-- Pagle's menu button (ONB-R52, ONB-R108): adapter/MinimapIcon.lua's, read each time; the compartment's button
	-- before that file is there.
	menu = function()
		return function()
			if ns.MenuButton then
				return ns.MenuButton() --[[@as Region]]
			end
			return AddonCompartmentFrame --[[@as Region]]
		end
	end,
}

ns.WireMarginNotes(ns.host, {
	show = show,
	hide = hide,
	place = function(note)
		local frame = frameOf(note)
		if frame and frame.arrow then
			frame.arrow:Redraw()
		end
	end,
	isShown = function(note)
		return visible(resolve(note))
	end,
	coreTarget = function(key)
		return CORE_TARGETS[key]()
	end,
	isUncharted = function(itemID)
		return ns.CatalogueItem(itemID) == nil
	end,
})

--- adapter/Announcements.lua's show, once an Announcement's frame is on screen (ONB-R52, ONB-R53): Core's first-moment
--- notes for it, beside the frame or at its coin, each while the frame still shows that Announcement.
---@param display PagleDisplay
---@param frame PagleAnnouncementFrame
function ns.NoteAnnouncement(display, frame)
	local function showing()
		return frame.display == display
	end
	ns.marginNotes:AnnouncementShown(display.announcement, display.form, {
		frame = function()
			return showing() and frame or nil
		end,
		coin = function()
			return showing() and frame.coins.coin or nil
		end,
	}, ns.IsUnchartedAnnouncement(display.announcement))
end

--- adapter/Cards.lua's show, once a card is on screen (ONB-R52): `core.summary` beside the first Session summary.
---@param card PagleCard
---@param frame PagleCardFrame
function ns.NoteCard(card, frame)
	ns.marginNotes:CardShown(card, function()
		return ns.cardFrame == frame and frame.card == card and frame or nil
	end)
end

-- ONB-R108: as Pagle's menu button changes (Show the minimap icon), a note meant for it moves its arrow. Installed at
-- PLAYER_LOGIN, over whatever adapter/MinimapIcon.lua set, so the files' order doesn't matter. Its own owner.
Pagle.RegisterEvent("Pagle margin notes", "PLAYER_LOGIN", function()
	Pagle.UnregisterEvent("Pagle margin notes", "PLAYER_LOGIN")
	local before = ns.MenuButtonChanged
	---@diagnostic disable-next-line: duplicate-set-field -- replacing adapter/MinimapIcon.lua's no-op is its contract
	ns.MenuButtonChanged = function(...)
		if before then
			before(...)
		end
		ns.marginNotes:Retarget()
	end
end)
