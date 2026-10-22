---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The First evening list on the client (core/onboarding.md › The First evening list): logic/Evening.lua's list, wired
-- over Core's host by logic/Wiring.lua's ns.WireEvening, which docks this file's frame as Core's own tracker at order 1
-- (CORE-R70), so it follows the dock wherever the player moved it (ONB-R107). It's drawn on the kit's tracker paper
-- (the GuideParts `trk` sprite: red double margin rule, blue ruling), as the onboarding kit's P.Tracker lays it out
-- (prototypes/onboarding-kit/PagleArtGuide/GuideKit.lua, UI units from the paper's top left): the header "First
-- evening", "{done} of {total}" and the close mark (ONB-R63), then a line per item, a done one ticked in green and
-- struck through, the next one on a green wash with its hint under it (ONB-R62). A tick inks in, the box popping from
-- 0.6x (0.3 s); 2.5 s after the last the list fades out rising 14 units (0.4 s) and hides (MOTION.md). With Animations
-- off each appears settled. Its sounds are `tick` and `listDone` (SOUND.md); in Cozy mode neither plays, as only what
-- the player clicks does.

local L = ns.L

-- The kit's tracker: 274 wide; its header row 30 tall; a line 21.6 tall, 34.6 with its hint; 12 under the last.
local WIDTH, TOP, LINE, LINE_HINT, BOTTOM = 274, 30, 21.6, 34.6, 12

-- The list's inks (the kit's P.Tracker): a done line, the next one, the rest.
ns.GUIDE_INKS.eveningDone = ns.Rgb("6A5A48")
ns.GUIDE_INKS.eveningNext = ns.Rgb("1E5A1E")
ns.GUIDE_INKS.evening = ns.Rgb("2E1C0C")

-- The list's sounds (SOUND.md): an item done, and the last one.
ns.GUIDE_SOUNDS.tick = { id = 856, motion = false } -- IG_MAINMENU_OPTION_CHECKBOX_ON
ns.GUIDE_SOUNDS.listDone = { id = 878, motion = false } -- IG_QUEST_LIST_COMPLETE

--- One line's regions, made the first time a list needs that many.
---@class PagleEveningRow
---@field wash Texture
---@field box PagleSprite
---@field tick PagleSprite
---@field text FontString
---@field strike Texture
---@field hint FontString

--- The tracker: the frame the dock places, and the body inside it that the fold fades and lifts.
---@class PagleEveningFrame: Frame
---@field body Frame
---@field paper PagleNineSlice
---@field head FontString
---@field count FontString
---@field close Button
---@field rows PagleEveningRow[]

local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleEveningFrame]]
frame:SetSize(WIDTH, TOP + BOTTOM)
frame:Hide()
ns.eveningFrame = frame

local body = CreateFrame("Frame", nil, frame)
body:SetSize(WIDTH, TOP + BOTTOM)
body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
frame.body = body
-- The paper follows the body's size: its 8-unit top and bottom keep, its ruling stretches (the kit's VSlice).
frame.paper = ns.NewNineSlice(body, "GuideParts", "trk", { 8, 8 }, "BACKGROUND")
frame.rows = {}

frame.head = ns.GuideText(body, "sc", 15, "title", L.EVENING_TITLE)
ns.GuideAt(frame.head, body, 24, 8 + 2.5)

-- The close mark (ONB-R63), at the header's right: × in the print face, red under the mouse.
local close = CreateFrame("Button", nil, body)
close:SetSize(16, 18)
close:SetPoint("TOPRIGHT", body, "TOPLEFT", WIDTH - 6, -8)
local mark = ns.GuideText(close, "print", 16, "kicker", L.EVENING_CLOSE, { justify = "CENTER" })
mark:SetPoint("CENTER", close, "CENTER", 0, 0)
close:SetScript("OnEnter", function()
	local red = ns.GUIDE_INKS.red
	mark:SetTextColor(red[1], red[2], red[3])
end)
close:SetScript("OnLeave", function()
	local ink = ns.GUIDE_INKS.kicker
	mark:SetTextColor(ink[1], ink[2], ink[3])
end)
close:SetScript("OnClick", function()
	ns.GuideSound("click")
	ns.evening:Close()
end)
frame.close = close

-- "{done} of {total}", right-aligned before the close mark.
frame.count = ns.GuideText(body, "italic", 12.5, "kicker", "", { justify = "RIGHT" })
frame.count:SetPoint("TOPRIGHT", body, "TOPLEFT", WIDTH - 26, -(10 + 2.25))

-- Sets a font string's ink by role.
---@param fontString FontString
---@param ink string
local function inkOf(fontString, ink)
	local color = ns.GUIDE_INKS[ink]
	fontString:SetTextColor(color[1], color[2], color[3])
end

-- Line `i`'s regions, made the first time.
---@param i integer
---@return PagleEveningRow
local function rowAt(i)
	local row = frame.rows[i]
	if not row then
		local wash = body:CreateTexture(nil, "BACKGROUND", nil, 2)
		wash:SetColorTexture(1, 1, 1, 1)
		wash:SetGradient("HORIZONTAL", CreateColor(0.24, 0.63, 0.24, 0.28), CreateColor(0.24, 0.63, 0.24, 0))
		local strike = body:CreateTexture(nil, "OVERLAY")
		local green = ns.GUIDE_INKS.green
		strike:SetColorTexture(green[1], green[2], green[3], 0.6)
		row = {
			wash = wash,
			box = ns.ArtSprite(body, "GuideParts", "li-box", "ARTWORK", 1),
			tick = ns.ArtSprite(body, "GuideParts", "li-done", "ARTWORK", 1),
			text = ns.GuideText(body, "print", 13.5, "evening", ""),
			strike = strike,
			hint = ns.GuideText(body, "italic", 12.5, "small", ""),
		}
		frame.rows[i] = row
	end
	return row
end

-- Hides line `row`'s regions.
---@param row PagleEveningRow
local function hideRow(row)
	row.wash:Hide()
	row.box:Hide()
	row.tick:Hide()
	row.text:Hide()
	row.strike:Hide()
	row.hint:Hide()
end

-- The tick inking in (MOTION.md): the done box pops from 0.6x about its centre (0.3 s); settled at once with
-- Animations off.
---@param tick PagleSprite
local function popTick(tick)
	local width, height = tick:GetSize()
	Pagle.Animate(tick, {
		{
			dur = 0.3,
			ease = Pagle.Bezier(0.3, 1.5, 0.6, 1),
			keys = { { 0, { 0.6 } }, { 1, { 1 } } },
			apply = function(v)
				tick:SetSize(width * v[1], height * v[1])
			end,
		},
	})
end

-- Puts the body back in its place, whole: a fold under way gives way.
local function settle()
	Pagle.StopMotion(body)
	body:SetAlpha(1)
	body:ClearAllPoints()
	body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
end

-- The view the list drives (PagleEveningView): `draw` lays the list out and shows it, docked.
---@param list PagleEveningList
---@param ticked string?
local function draw(list, ticked)
	settle()
	frame.count:SetText(L.EVENING_COUNT:format(list.done, list.total))
	local y = TOP
	for i, line in ipairs(list.lines) do
		local row = rowAt(i)
		local height = line.hint and LINE_HINT or LINE
		hideRow(row)
		if line.next then
			row.wash:SetSize(WIDTH - 22, height)
			ns.GuideAt(row.wash, body, 18, y)
			row.wash:Show()
		end
		-- the box, or the done one, whose tick rises above it: each placed by its 12-unit box's centre
		local box = line.done and row.tick or row.box
		ns.CenterSpriteAt(box, body, 24 + 6, y + 4 + 6)
		box:Show()
		row.text:SetText(line.text)
		inkOf(row.text, line.done and "eveningDone" or line.next and "eveningNext" or "evening")
		ns.GuideAt(row.text, body, 43, y + 2 + 2.05)
		row.text:Show()
		if line.done then
			row.strike:SetSize(math.ceil(row.text:GetStringWidth()), 1)
			ns.GuideAt(row.strike, body, 43, y + 11)
			row.strike:Show()
			if line.id == ticked then
				popTick(row.tick)
			end
		end
		if line.hint then
			row.hint:SetText(line.hint)
			ns.GuideAt(row.hint, body, 43, y + 19.6 + 1.9)
			row.hint:Show()
		end
		y = y + height
	end
	for i = #list.lines + 1, #frame.rows do
		hideRow(frame.rows[i])
	end
	local height = y + BOTTOM
	body:SetSize(WIDTH, height)
	frame:SetSize(WIDTH, height)
	frame:Show()
end

-- Hides the list at once.
local function hide()
	settle()
	frame:Hide()
end

-- Folds the list away (MOTION.md): it fades out rising 14 units (0.4 s, easing in), then hides; at once with
-- Animations off.
local function fold()
	Pagle.Animate(body, {
		{
			dur = 0.4,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { 1, 0 } }, { 1, { 0, 14 } } },
			apply = function(v)
				body:SetAlpha(v[1])
				body:ClearAllPoints()
				body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, v[2])
			end,
		},
	}, hide)
end

-- The list's sounds: none in Cozy mode, where only what the player clicks plays (SOUND.md).
---@param name string
local function sound(name)
	if not ns.db.profile.announcements.cozy then
		ns.GuideSound(name)
	end
end

ns.WireEvening(ns.host, { frame = frame, draw = draw, hide = hide, fold = fold, sound = sound })
-- ONB-R84: `core.onboarding.evening`, after Core's other stops of this file's time.
ns.AddEveningTourStop()
