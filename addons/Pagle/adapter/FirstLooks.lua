---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- First looks on the client (core/onboarding.md › First looks, › UI, › Motion): logic/FirstLooks.lua's sets as
-- logic/Wiring.lua wires them over adapter/Host.lua's host, drawn here with adapter/MarginNotes.lua's note paper and
-- pencil arrows. A set's notes are unscaled frames in UIParent (ONB-R106), anchored to its window where the set says
-- (ns.PlaceLookNote), so they go where the window goes; each frame while the set shows, a moved window's notes are
-- placed again and its arrows follow at once, without motion, and a target that hid drops its note (ONB-R56). Under
-- the window is the leather coach bar (GuideParts' `coachbar`; the kit's P.CoachBar): "First look · {title}", how
-- many notes, and "Got it, put the notes away" (ONB-R55). Closing the window, or Esc closing it, takes the set away.
-- Registers Core's own set, the Curio Shop's (adapter/Shop.lua's ns.ShopFirstLook), and gives every set its tour stop.

local INKS = ns.GUIDE_INKS
-- The coach bar's link at rest and under the mouse (the kit's P.CoachBar), and its rules' ink.
local LINK, LINK_HOVER = ns.Rgb("E8D6A8"), ns.Rgb("FFF4C8")
-- The coach bar's room round each part, its height, and how far under the window it hangs.
local BAR_PAD, BAR_HEIGHT, BAR_DROP = 16, 40, 8

--- A note of a set on screen: a Margin note's frame with the entry it shows.
---@class PagleLookNoteFrame: PagleMarginNoteFrame
---@field entry PagleLookEntry?

--- The coach bar.
---@class PagleCoachBar: Frame, PagleThreeSlice
---@field title FontString
---@field count FontString
---@field rules Texture[]
---@field done Button
---@field doneLabel FontString

--- The note frames, made as needed, in DIALOG strata over the windows: each with the entry it shows, nil while free.
---@type PagleLookNoteFrame[]
ns.lookNoteFrames = {}
local frames = ns.lookNoteFrames

--- The coach bar, made at the first set shown.
---@type PagleCoachBar?
ns.coachBar = nil

-- The set on screen: its set, its window, and what its notes were last placed for.
---@type { set: PagleFirstLook, window: Frame, placed: string? }?
local current

-- A frame free for a note, made if none is.
---@return PagleLookNoteFrame
local function acquire()
	for _, frame in ipairs(frames) do
		if not frame.entry then
			return frame
		end
	end
	local frame = ns.NewMarginNoteFrame(UIParent) --[[@as PagleLookNoteFrame]]
	frame:SetFrameStrata("DIALOG")
	frame:Hide()
	frames[#frames + 1] = frame
	return frame
end

-- Where the window is now, as its notes' placing reads it: its scale against UIParent's and the room on each side,
-- nil while it isn't laid out (ONB-R58).
---@param window Frame
---@return number scale
---@return { left: number, right: number }? free
local function measure(window)
	local scale = window:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local left, right = window:GetLeft(), window:GetRight()
	if not (left and right) then
		return scale, nil
	end
	return scale, { left = left * scale, right = UIParent:GetWidth() - right * scale }
end

-- What the notes' places were worked out from, to tell when the window moved or rescaled.
---@param window Frame
---@return string
local function signature(window)
	local scale, free = measure(window)
	local width = window:GetWidth()
	if not free then
		return ("%s %s"):format(scale, width)
	end
	return ("%s %s %s %s %s"):format(scale, width, free.left, free.right, tostring(window:GetTop()))
end

-- Puts each note of the set on screen beside its window (ns.PlaceLookNote); their arrows follow (ONB-R56).
local function place()
	if not current then
		return
	end
	local window = current.window
	local scale, free = measure(window)
	local width = window:GetWidth()
	for _, frame in ipairs(frames) do
		local entry = frame.entry
		if entry then
			local note = current.set.notes[entry.index]
			local anchor = ns.PlaceLookNote(note, { width = width, scale = scale, free = free })
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", window, anchor.relativePoint, anchor.x, anchor.y)
		end
	end
	current.placed = signature(window)
end

-- A rule between the bar's parts.
---@param bar Frame
---@return Texture
local function rule(bar)
	local texture = bar:CreateTexture(nil, "ARTWORK")
	local ink = INKS.crumb
	texture:SetColorTexture(ink[1], ink[2], ink[3], 0.35)
	texture:SetSize(1, 18)
	return texture
end

-- The coach bar (the kit's P.CoachBar): leather three-sliced from GuideParts' `coachbar`, its words in Marcellus on
-- it, the link in italic. While a set shows, it watches the window each frame: moved or rescaled, the notes are
-- placed again.
---@return PagleCoachBar
local function newBar()
	local bar = CreateFrame("Frame", nil, UIParent) --[[@as PagleCoachBar]]
	bar:SetFrameStrata("DIALOG")
	bar:SetClampedToScreen(true)
	bar.title = ns.GuideText(bar, "gilt", 14, "crumb", "", { shadow = true })
	bar.count = ns.GuideText(bar, "gilt", 14, "count", "", { shadow = true })
	bar.rules = { rule(bar), rule(bar) }
	bar.done = CreateFrame("Button", nil, bar)
	bar.doneLabel = ns.GuideText(bar.done, "italic", 14, "count", ns.L.LOOK_BAR_DONE, { shadow = true })
	bar.doneLabel:SetTextColor(LINK[1], LINK[2], LINK[3])
	bar.doneLabel:SetPoint("LEFT", bar.done, "LEFT")
	bar.done:SetScript("OnEnter", function()
		bar.doneLabel:SetTextColor(LINK_HOVER[1], LINK_HOVER[2], LINK_HOVER[3])
	end)
	bar.done:SetScript("OnLeave", function()
		bar.doneLabel:SetTextColor(LINK[1], LINK[2], LINK[3])
	end)
	bar.done:SetScript("OnClick", function()
		ns.GuideSound("click")
		ns.firstLooks:Hide()
	end)
	bar:SetScript("OnUpdate", function()
		if current and current.placed ~= signature(current.window) then
			place()
		end
	end)
	bar:Hide()
	return bar
end

-- Writes the bar for `set` with `n` notes and lays it out: "First look · {title}" | "{n} notes, shown once" | the link.
---@param bar PagleCoachBar
---@param set PagleFirstLook
---@param n integer
local function drawBar(bar, set, n)
	local L = ns.L
	bar.title:SetText(L.LOOK_BAR_TITLE:format(set.title))
	bar.count:SetText(n == 1 and L.LOOK_BAR_COUNT_ONE or L.LOOK_BAR_COUNT:format(n))
	local wa = math.ceil(bar.title:GetStringWidth())
	local wb = math.ceil(bar.count:GetStringWidth())
	local wc = math.ceil(bar.doneLabel:GetStringWidth())
	ns.SetThreeSlice(bar, "GuideParts", "coachbar", BAR_PAD * 6 + wa + wb + wc + 2, 12, "BACKGROUND")
	bar:SetHeight(BAR_HEIGHT)
	bar.title:ClearAllPoints()
	bar.title:SetPoint("LEFT", bar, "LEFT", BAR_PAD, 0)
	bar.rules[1]:ClearAllPoints()
	bar.rules[1]:SetPoint("LEFT", bar, "LEFT", BAR_PAD * 2 + wa, 0)
	bar.count:ClearAllPoints()
	bar.count:SetPoint("LEFT", bar.rules[1], "RIGHT", BAR_PAD, 0)
	bar.rules[2]:ClearAllPoints()
	bar.rules[2]:SetPoint("LEFT", bar, "LEFT", BAR_PAD * 4 + wa + wb + 1, 0)
	bar.done:SetSize(math.max(1, wc), 20)
	bar.done:ClearAllPoints()
	bar.done:SetPoint("LEFT", bar.rules[2], "RIGHT", BAR_PAD, 0)
end

-- Each set whose window's OnHide and OnSizeChanged are hooked, by id.
---@type table<string, true>
local hooked = {}

-- The view's hide: the notes and the bar off screen, at once.
---@param set PagleFirstLook?
local function hide(set)
	if set and current and current.set.id ~= set.id then
		return
	end
	current = nil
	for _, frame in ipairs(frames) do
		if frame.entry then
			frame.entry = nil
			if frame.arrow then
				frame.arrow.onGone = nil
			end
			ns.StopMotion(frame)
			frame:Hide()
		end
	end
	if ns.coachBar then
		ns.coachBar:Hide()
	end
end

-- The view's show: each note numbered beside the window, its arrow to its target, moving in 0.12 s apart, `noteIn`
-- once (ONB-R55), and the bar under the window.
---@param set PagleFirstLook
---@param entries PagleLookEntry[]
local function show(set, entries)
	hide()
	local window = ns.firstLooks:Window(set.id)
	if not window then
		return
	end
	if not hooked[set.id] then
		hooked[set.id] = true
		window:HookScript("OnHide", function()
			ns.firstLooks:WindowHidden(set.id)
		end)
		window:HookScript("OnSizeChanged", place)
	end
	current = { set = set, window = window }
	for _, entry in ipairs(entries) do
		local note = set.notes[entry.index]
		local frame = acquire()
		frame.entry = entry
		ns.SetMarginNoteText(frame, ns.RedPencil(note.text), note.w, entry.n)
	end
	place()
	for _, frame in ipairs(frames) do
		local entry = frame.entry
		if entry then
			frame:Show()
			if not frame.arrow then
				frame.arrow = ns.NewNoteArrow(frame, frame, function()
					return nil
				end)
			end
			local arrow = frame.arrow --[[@as PagleNoteArrow]]
			arrow.to = entry.target
			arrow.drawn = nil
			arrow.onGone = function()
				ns.firstLooks:TargetHidden(set.id, entry.index)
			end
			arrow:Redraw()
			ns.NoteIn(frame, ns.LOOK_NOTE_STAGGER * (entry.n - 1))
		end
	end
	local bar = ns.coachBar or newBar()
	ns.coachBar = bar
	drawBar(bar, set, #entries)
	bar:ClearAllPoints()
	bar:SetPoint("TOP", window, "BOTTOM", 0, -BAR_DROP)
	bar:Show()
	ns.PlayNoteIn()
end

-- The view's renumber: a note dropped, the rest renumbered at once, and the bar's count with them (ONB-R56).
---@param set PagleFirstLook
---@param entries PagleLookEntry[]
local function renumber(set, entries)
	local kept = {}
	for _, entry in ipairs(entries) do
		kept[entry] = true
	end
	for _, frame in ipairs(frames) do
		local entry = frame.entry
		if entry and not kept[entry] then
			frame.entry = nil
			if frame.arrow then
				frame.arrow.onGone = nil
			end
			ns.StopMotion(frame)
			frame:Hide()
		elseif entry then
			frame.number:SetText(tostring(entry.n))
		end
	end
	if ns.coachBar then
		drawBar(ns.coachBar, set, #entries)
	end
end

ns.WireFirstLooks(ns.host, {
	show = show,
	renumber = renumber,
	hide = hide,
	isShown = function(region)
		return region:IsVisible() == true and region:GetLeft() ~= nil
	end,
})

ns.RegisterCoreFirstLook(ns.ShopFirstLook())
ns.AddFirstLookTourStops()
