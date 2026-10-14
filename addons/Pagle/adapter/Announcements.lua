---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Showing Announcements on the client (announcements.md › The display queue, › Interruption budget, › Sounds,
-- › Toast styles, › UI; ADR 0007): logic/Announcements.lua's lanes on GetTime and C_Timer.After, reading the budget
-- from PagleDB.profile.announcements, drawing the toast, Nod, banner and splash in the Timber style (ANN-R80) and
-- playing the sounds with PlaySoundFile on the SFX channel (ANN-R73). The look follows prototypes/catch-feedback/
-- (variant A).
local L = ns.L
---@class Pagle
local Pagle = Pagle

-- Its own owner on Core's bus, so no other Core file's registration replaces its RestrictionChanged listener.
local OWNER = "Pagle announcements"

-- Timber (ANN-R80), shared with the card frame: adapter/Timber.lua.
local TIMBER = ns.TIMBER
local solid, framed, text, textureOf = ns.SolidTexture, ns.Framed, ns.Text, ns.TextureOf

-- Stamp slots on a frame: the 4 stamps shown and the "+N" for the rest (ANN-R11).
local STAMP_SLOTS = ns.MOMENT_STAMPS + 1

---@class PagleStamp: Frame
---@field label FontString

---@class PagleRulerView: Frame
---@field track Texture
---@field fill Texture
---@field mark Texture
---@field old FontString
---@field value FontString
---@field margin FontString
---@field label FontString
---@field record PagleStamp
---@field compact boolean
---@field ruler { old: number, new: number, unit: string, label: string }
---@field elapsed number
---@field lengthUnit PagleLengthUnit

---@class PagleAnnouncementFrame: Frame
---@field display PagleDisplay?
---@field icon Texture
---@field title FontString
---@field text FontString
---@field stamps PagleStamp[]
---@field coins PagleStamp
---@field more FontString?
---@field ruler PagleRulerView?

--- The frame each form is drawn in, made the first time one shows (ANN-R80).
---@type table<PagleAnnouncementForm, PagleAnnouncementFrame>
ns.announcementFrames = {}

-- A stamp: a short label on a coloured tab (ANN-R11).
---@param parent Frame
---@param color number[]
---@return PagleStamp
local function newStamp(parent, color)
	local stamp = CreateFrame("Frame", nil, parent) --[[@as PagleStamp]]
	solid(stamp, color, "ARTWORK")
	stamp.label = text(stamp, "GameFontHighlightSmall")
	stamp.label:SetPoint("CENTER")
	stamp:Hide()
	return stamp
end

---@param stamp PagleStamp
---@param label string
local function setStamp(stamp, label)
	stamp.label:SetText(label)
	stamp:SetSize(stamp.label:GetStringWidth() + 12, 16)
	stamp:Show()
end

-- Fills a frame's stamps from an Announcement: its stamp texts, "+N" for those beyond 4, and the Coins stamp when
-- its moments carry any (ANN-R11, ANN-R23). Returns the ones showing, in order, for the frame to place.
---@param frame PagleAnnouncementFrame
---@param announcement PagleAnnouncement
---@return PagleStamp[]
local function fillStamps(frame, announcement)
	local showing = {}
	for i, stamp in ipairs(frame.stamps) do
		stamp:ClearAllPoints()
		local label = announcement.stamps[i]
		if i == STAMP_SLOTS and announcement.more > 0 then
			label = L.ANNOUNCEMENT_STAMPS_MORE:format(announcement.more)
		end
		if label then
			setStamp(stamp, label)
			showing[#showing + 1] = stamp
		else
			stamp:Hide()
		end
	end
	frame.coins:ClearAllPoints()
	if announcement.coins > 0 then
		setStamp(frame.coins, L.ANNOUNCEMENT_COINS:format(BreakUpLargeNumbers(announcement.coins)))
		showing[#showing + 1] = frame.coins
	else
		frame.coins:Hide()
	end
	return showing
end

-- Places stamps in a row from `point` on `relativeTo`, each next one to the right of the last.
---@param stamps PagleStamp[]
---@param point FramePoint
---@param relativeTo Region
---@param relativePoint FramePoint
---@param x number
---@param y number
local function rowRight(stamps, point, relativeTo, relativePoint, x, y)
	for i, stamp in ipairs(stamps) do
		if i == 1 then
			stamp:SetPoint(point, relativeTo, relativePoint, x, y)
		else
			stamp:SetPoint("LEFT", stamps[i - 1], "RIGHT", 3, 0)
		end
	end
end

-- The width a row of stamps takes.
---@param stamps PagleStamp[]
---@return number
local function rowWidth(stamps)
	local width = 0
	for _, stamp in ipairs(stamps) do
		width = width + stamp.label:GetStringWidth() + 12 + 3
	end
	return math.max(0, width - 3)
end

-- A record ruler (ANN-R22): a track with the old record's mark and a fill, the number, and once landed the margin
-- and, full size only, the old record's number over its mark and the "New record" stamp.
---@param parent Frame
---@param compact boolean a Nod's: shorter and thinner, with no old record's number, label or stamp
---@return PagleRulerView
local function newRuler(parent, compact)
	local ruler = CreateFrame("Frame", nil, parent) --[[@as PagleRulerView]]
	ruler.compact = compact
	ruler:SetSize(compact and 120 or 270, compact and 18 or 34)
	ruler.track = solid(ruler, TIMBER.track, "ARTWORK")
	ruler.track:ClearAllPoints()
	ruler.track:SetPoint("TOPLEFT")
	ruler.track:SetPoint("TOPRIGHT")
	ruler.track:SetHeight(compact and 7 or 12)
	ruler.fill = ruler:CreateTexture(nil, "OVERLAY")
	ruler.fill:SetColorTexture(TIMBER.fill[1], TIMBER.fill[2], TIMBER.fill[3], TIMBER.fill[4])
	ruler.fill:SetPoint("TOPLEFT", ruler.track)
	ruler.fill:SetPoint("BOTTOMLEFT", ruler.track)
	ruler.mark = ruler:CreateTexture(nil, "OVERLAY")
	ruler.mark:SetSize(2, compact and 11 or 18)
	-- The old record's number, over its mark; a compact ruler has no room for it.
	ruler.old = text(ruler, "GameFontDisableSmall")
	ruler.old:SetPoint("BOTTOM", ruler.mark, "TOP", 0, 1)
	ruler.old:SetShown(not compact)
	ruler.value = text(ruler, compact and "GameFontHighlightSmall" or "GameFontHighlight")
	ruler.value:SetPoint("TOPLEFT", ruler.track, "BOTTOMLEFT", 0, -3)
	ruler.margin = text(ruler, "GameFontNormalSmall", TIMBER.gold)
	ruler.margin:SetPoint("LEFT", ruler.value, "RIGHT", 6, 0)
	ruler.label = text(ruler, "GameFontDisableSmall")
	ruler.label:SetPoint("LEFT", ruler.margin, "RIGHT", 6, 0)
	ruler.record = newStamp(ruler, TIMBER.record)
	ruler.record:SetPoint("LEFT", ruler.label, "RIGHT", 6, 0)
	ruler.record.label:SetText(L.ANNOUNCEMENT_NEW_RECORD)
	return ruler
end

-- Draws a ruler at one moment of its animation.
---@param ruler PagleRulerView
---@param at PagleRulerFrame
local function drawRuler(ruler, at)
	local width = ruler.compact and 120 or 270
	ruler.fill:SetWidth(math.max(1, width * math.min(1, at.fill)))
	ruler.mark:ClearAllPoints()
	ruler.mark:SetPoint("CENTER", ruler.track, "LEFT", width * at.mark, 0)
	local mark = at.passed and TIMBER.passed or TIMBER.mark
	ruler.mark:SetColorTexture(mark[1], mark[2], mark[3], mark[4])
	ruler.old:SetText(at.old)
	ruler.value:SetText(at.value)
	ruler.margin:SetText(at.margin)
	ruler.margin:SetShown(at.done)
	ruler.label:SetText(not ruler.compact and at.label or "")
	ruler.label:SetShown(at.done and not ruler.compact)
	if at.stamped and not ruler.compact then
		setStamp(ruler.record, L.ANNOUNCEMENT_NEW_RECORD)
	else
		ruler.record:Hide()
	end
end

-- Shows a headline's ruler and starts its animation, or hides the ruler when it has none (ANN-R22).
---@param view PagleRulerView
---@param ruler { old: number, new: number, unit: string, label: string }?
local function startRuler(view, ruler)
	view:SetScript("OnUpdate", nil)
	if not ruler then
		view:Hide()
		return
	end
	-- A Simulated Size reads in the Angler's length unit as the ruler appears (LOG-R69).
	view.ruler, view.elapsed, view.lengthUnit = ruler, 0, ns.LengthUnit()
	drawRuler(view, ns.RulerAt(ruler, 0, view.lengthUnit))
	view:Show()
	view:SetScript("OnUpdate", function(self, elapsed)
		self.elapsed = self.elapsed + elapsed
		local at = ns.RulerAt(self.ruler, self.elapsed, self.lengthUnit)
		drawRuler(self, at)
		if at.stamped then
			self:SetScript("OnUpdate", nil)
		end
	end)
end

-- What every Announcement frame has: an icon, a title and a text on `content` (the frame, or the splash's card), and
-- the stamps.
---@param frame PagleAnnouncementFrame
---@param content Frame
---@param iconSize number
---@param titleTemplate string
---@param textTemplate string
local function addParts(frame, content, iconSize, titleTemplate, textTemplate)
	frame:SetFrameStrata("HIGH")
	frame.icon = content:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(iconSize, iconSize)
	frame.title = text(content, titleTemplate)
	frame.text = text(content, textTemplate)
	frame.stamps = {}
	for i = 1, STAMP_SLOTS do
		frame.stamps[i] = newStamp(frame, i == STAMP_SLOTS and TIMBER.stampsMore or TIMBER.stamp)
	end
	frame.coins = newStamp(frame, TIMBER.coins)
	frame:Hide()
end

-- The frames, one per form, as announcements.md › UI draws them.
---@type table<PagleAnnouncementForm, fun(): PagleAnnouncementFrame>
local BUILD = {
	-- Above the action bar: icon, title, text, stamps over the top right corner, a ruler, "+N more".
	toast = function()
		local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
		frame:SetWidth(350)
		framed(frame, TIMBER.wood, TIMBER.edge, 2)
		addParts(frame, frame, 44, "GameFontNormalLarge", "GameFontHighlight")
		frame.icon:SetPoint("TOPLEFT", 10, -10)
		frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
		frame.title:SetWidth(270)
		frame.title:SetJustifyH("LEFT")
		frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
		frame.text:SetWidth(270)
		frame.text:SetJustifyH("LEFT")
		frame.ruler = newRuler(frame, false)
		-- Room above the track for the old record's number.
		frame.ruler:SetPoint("TOPLEFT", frame.text, "BOTTOMLEFT", 0, -18)
		frame.more = text(frame, "GameFontHighlightSmall", TIMBER.more)
		frame.more:SetPoint("BOTTOMLEFT", 64, 8)
		return frame
	end,
	-- One line under the toast: icon, title, text, a compact ruler, then the stamps.
	nod = function()
		local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 156)
		frame:SetSize(460, 28)
		framed(frame, TIMBER.wood, TIMBER.edge, 1)
		addParts(frame, frame, 20, "GameFontNormal", "GameFontHighlightSmall")
		frame.icon:SetPoint("LEFT", 6, 0)
		frame.title:SetPoint("LEFT", frame.icon, "RIGHT", 6, 0)
		frame.text:SetPoint("LEFT", frame.title, "RIGHT", 6, 0)
		frame.ruler = newRuler(frame, true)
		frame.ruler:SetPoint("LEFT", frame.text, "RIGHT", 8, -5)
		return frame
	end,
	-- Centre screen, like the level-up banner: a dark band with brass rules, a large gold title and the text.
	banner = function()
		local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetPoint("TOP", UIParent, "TOP", 0, -160)
		frame:SetSize(720, 112)
		framed(frame, TIMBER.band, TIMBER.edge, 1)
		addParts(frame, frame, 40, "GameFontNormalHuge", "GameFontHighlightLarge")
		frame.icon:SetPoint("TOP", 0, -8)
		frame.title:SetPoint("TOP", frame.icon, "BOTTOM", 0, -4)
		frame.text:SetPoint("TOP", frame.title, "BOTTOM", 0, -4)
		return frame
	end,
	-- Full screen for a Legend, until clicked: the item icon, its name and its title on a parchment card.
	splash = function()
		local frame = CreateFrame("Button", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetAllPoints(UIParent)
		solid(frame, TIMBER.shade)
		local card = CreateFrame("Frame", nil, frame)
		card:SetPoint("CENTER")
		card:SetSize(440, 260)
		framed(card, TIMBER.parchment, TIMBER.parchmentEdge, 3)
		addParts(frame, card, 84, "GameFontNormalHuge", "GameFontHighlightLarge")
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:EnableMouse(true)
		frame.icon:SetPoint("TOP", card, "TOP", 0, -24)
		frame.title:SetTextColor(TIMBER.legend[1], TIMBER.legend[2], TIMBER.legend[3])
		frame.title:SetPoint("TOP", frame.icon, "BOTTOM", 0, -10)
		frame.text:SetTextColor(TIMBER.ink[1], TIMBER.ink[2], TIMBER.ink[3])
		frame.text:SetPoint("TOP", frame.title, "BOTTOM", 0, -6)
		local hint = text(card, "GameFontDisableSmall", TIMBER.ink)
		hint:SetPoint("BOTTOM", 0, 12)
		hint:SetText(L.ANNOUNCEMENT_SPLASH_HINT)
		frame:SetScript("OnClick", function(self)
			if self.display then
				ns.lanes:Dismiss(self.display)
			end
		end)
		return frame
	end,
}

-- Puts an Announcement's content in its form's frame and lays out what depends on it.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
local function draw(frame, display)
	local announcement = display.announcement
	local headline = announcement.headline
	frame.icon:SetTexture(textureOf(headline.icon))
	frame.title:SetText(headline.title)
	frame.text:SetText(headline.text or "")
	local stamps = fillStamps(frame, announcement)
	local form = display.form
	-- "While you were fighting" lists each held toast's headline, a line each (ANN-R36).
	local lines = 0
	if announcement.fighting then
		local list = {}
		for i, held in ipairs(announcement.fighting) do
			list[i] = held.text and L.ANNOUNCEMENT_FIGHTING_LINE:format(held.title, held.text) or held.title
		end
		frame.text:SetText(table.concat(list, "\n"))
		lines = #list - 1
	end
	if form == "toast" then
		rowRight(stamps, "TOPLEFT", frame, "TOPRIGHT", 8 - rowWidth(stamps), 10)
		local more = frame.more --[[@as FontString]]
		more:SetText(L.ANNOUNCEMENT_MORE:format(display.overflow))
		more:SetShown(display.overflow > 0)
		frame:SetHeight(64 + lines * 14 + (headline.ruler and 50 or 0) + (display.overflow > 0 and 14 or 0))
	elseif form == "nod" then
		rowRight(stamps, "LEFT", headline.ruler and frame.ruler or frame.text, "RIGHT", 8, 0)
	else
		rowRight(stamps, "TOPLEFT", frame.text, "BOTTOM", -rowWidth(stamps) / 2, -10)
	end
	if frame.ruler then
		startRuler(frame.ruler, headline.ruler)
	end
end

-- The lanes' show: the form's frame, made on first use, drawn and on screen.
---@param display PagleDisplay
local function show(display)
	local frame = ns.announcementFrames[display.form]
	if not frame then
		frame = BUILD[display.form]()
		ns.announcementFrames[display.form] = frame
	end
	frame.display = display
	draw(frame, display)
	frame:Show()
end

-- The lanes' hide: off screen, its ruler stopped, if the frame still shows this display.
---@param display PagleDisplay
local function hide(display)
	local frame = ns.announcementFrames[display.form]
	if frame and frame.display == display then
		frame.display = nil
		if frame.ruler then
			frame.ruler:SetScript("OnUpdate", nil)
		end
		frame:Hide()
	end
end

--- Core's three lanes (ANN-R20) on the client.
ns.lanes = ns.NewLanes({
	now = function()
		return GetTime()
	end,
	after = function(seconds, fn)
		C_Timer.After(seconds, fn)
	end,
	budget = function()
		return ns.db.profile.announcements.budget
	end,
	cozy = function()
		return ns.db.profile.announcements.cozy
	end,
	serverTime = function()
		return GetServerTime()
	end,
	-- Driftwood, the only set in M2 (ANN-R72); the Sound set slot comes with the Curio Shop (M4).
	soundSet = function()
		return ns.SOUND_SETS.driftwood
	end,
	show = show,
	hide = hide,
	play = function(path)
		PlaySoundFile(path, "SFX")
	end,
	-- The slot freed with nothing waiting: a card may show (ANN-R21). adapter/Cards.lua's, looked up when called.
	empty = function()
		ns.cards:Next()
	end,
})

-- The combat hold (ANN-R35, ANN-R36): a restriction holds the lanes and takes the card on screen off it; its end
-- starts the wait after which they show what they held, then the cards. A load while restricted (a /reload in
-- combat) starts held: RestrictionChanged never fires for the starting state (CORE-R30).
if Pagle.IsRestricted() then
	ns.lanes:Hold()
end
Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
	if isRestricted then
		ns.lanes:Hold()
		ns.cards:Hold()
	else
		ns.lanes:Release()
	end
end)
