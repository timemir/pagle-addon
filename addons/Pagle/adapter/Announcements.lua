---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Showing Announcements on the client (announcements.md › The display queue, › Interruption budget, › Sounds,
-- › Toast styles, › UI; ADR 0007): logic/Announcements.lua's lanes on GetTime and C_Timer.After, reading the budget
-- from PagleDB.profile.announcements, drawing the toast, Nod, banner and splash in the announcements art kit
-- (adapter/Art.lua), the toast and Nod in the equipped toast style (ANN-R80), and playing the sounds with
-- PlaySoundFile on the SFX channel (ANN-R73). A toast is a fresh entry in the Angler's ledger: a torn page on a
-- leather spine with the catch's icon in a medallion, the title printed over the text in the Angler's hand, rubber
-- stamps in the corner and the Coins beside a brass coin.
local L = ns.L
---@class Pagle
local Pagle = Pagle

-- Its own owner on Core's bus, so no other Core file's registration replaces its RestrictionChanged listener.
local OWNER = "Pagle announcements"

local textureOf = ns.TextureOf

-- Stamp slots on a frame: the 4 stamps shown and the "+N" for the rest (ANN-R11).
local STAMP_SLOTS = ns.MOMENT_STAMPS + 1
-- Held headlines "While you were fighting" lists, a row each; the last row says how many more when there are more.
local DIGEST_ROWS = 4
-- Its icon: crossed blades.
local FIGHTING_ICON = "Interface\\Icons\\Ability_DualWield"
-- A Nod's line at most, and the track of its compact ruler, which the number and the margin follow.
local NOD_WIDTH, COMPACT_TRACK = 640, 90
-- The ticks on a full ruler's track, every fourth one long.
local TICKS = 20

---@class PagleCoinsView: Frame
---@field coin PagleSprite
---@field label FontString

---@class PagleRulerView: Frame
---@field compact boolean a Nod's: shorter, with no label, old record's number or stamp
---@field bar Frame the track's own frame: the ticks, the fill and the marks
---@field ticks Texture[] a full ruler's ticks along the track
---@field track Texture the track's base line
---@field fill PagleSprite
---@field mark Texture the old record's mark
---@field newMark Texture where the fill has reached
---@field old FontString
---@field value FontString
---@field margin FontString
---@field label FontString
---@field record PagleStamp
---@field trackWidth number
---@field style PagleToastStyle
---@field ruler { old: number, new: number, unit: string, label: string }
---@field elapsed number
---@field lengthUnit PagleLengthUnit

---@class PagleDigestRow: Frame
---@field bezel PagleBezel
---@field what FontString
---@field name FontString

---@class PagleAnnouncementFrame: Frame
---@field display PagleDisplay?
---@field drawnRuler PagleDisplay? the display whose ruler is animating
---@field words Frame the frame its words, stamps and coins sit on, over the art
---@field icon Texture?
---@field title FontString
---@field text FontString
---@field stamps PagleStamp[]
---@field coins PagleCoinsView
---@field more FontString?
---@field ruler PagleRulerView?
---@field page PagleSprite? a toast's page
---@field strip PagleThreeSlice? a Nod's strip
---@field bezel PagleBezel?
---@field wax PagleSprite? toast.high's wax
---@field rows PagleDigestRow[]? "While you were fighting"'s
---@field seal PagleSprite? a banner's
---@field sealNumber FontString?
---@field crest PagleSprite?
---@field portrait Texture?
---@field crestLabel FontString?
---@field extras Frame? a banner's or the splash's row of labels and Coins

--- The frame each form is drawn in, made the first time one shows (ANN-R80).
---@type table<PagleAnnouncementForm, PagleAnnouncementFrame>
ns.announcementFrames = {}

-- A font string's width, unbounded, then held to `width` at most: a longer one ends in "...".
---@param fontString FontString
---@param width number
local function fit(fontString, width)
	fontString:SetWidth(0)
	fontString:SetWidth(math.min(fontString:GetStringWidth(), width))
end

-- A frame on `parent` over it, `levels` frame levels up: a toast's medallion over its page, its words over both.
---@param parent Frame
---@param levels integer
---@return Frame
local function layer(parent, levels)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetAllPoints()
	frame:SetFrameLevel(parent:GetFrameLevel() + levels)
	return frame
end

-- The Coins (ANN-R23): a brass coin and "+N" in `font` beside it, hidden until set.
---@param parent Frame
---@param font string
---@return PagleCoinsView
local function newCoins(parent, font)
	local coins = CreateFrame("Frame", nil, parent) --[[@as PagleCoinsView]]
	coins.coin = ns.ArtSprite(coins, "Announce", "coin", "OVERLAY", 1)
	coins.label = ns.ArtText(coins, font)
	coins:Hide()
	return coins
end

-- Shows `amount` Coins with the coin `size` across, the coin first (a Nod's, a banner's) or last (a toast's), or
-- hides them for none. Returns their width, 0 for none.
---@param coins PagleCoinsView
---@param amount integer
---@param size number
---@param coinFirst boolean
---@return number
local function setCoins(coins, amount, size, coinFirst)
	if amount <= 0 then
		coins:Hide()
		return 0
	end
	coins.label:SetText(L.ANNOUNCEMENT_COINS:format(BreakUpLargeNumbers(amount)))
	local coin = ns.SetCoin(coins.coin, size)
	local width = size + 8 + coins.label:GetStringWidth()
	coins:SetSize(width, size)
	ns.PlaceSprite(coin, coins, coinFirst and 0 or width - size, 0)
	coins.label:ClearAllPoints()
	if coinFirst then
		coins.label:SetPoint("LEFT", coins, "LEFT", size + 8, 0)
	else
		coins.label:SetPoint("RIGHT", coins, "RIGHT", -(size + 8), 0)
	end
	coins:Show()
	return width
end

-- A leather label with gilt words, as a banner's and the splash's stamps ride.
---@param parent Frame
---@return PagleStamp
local function newLabel(parent)
	local label = CreateFrame("Frame", nil, parent) --[[@as PagleStamp]]
	label.border = CreateFrame("Frame", nil, label) --[[@as PagleThreeSlice]]
	label.border:SetPoint("TOPLEFT")
	-- On the border's own frame, which draws over the label's.
	label.label = ns.ArtText(label.border, "Label")
	label.label:SetPoint("CENTER", label, "CENTER")
	label:Hide()
	return label
end

---@param label PagleStamp
---@param text string
local function setLabel(label, text)
	label.label:SetText(ns.Capitals(text))
	local width = label.label:GetStringWidth() + 24
	ns.SetThreeSlice(label.border, "Announce", "label", width, 10, "ARTWORK")
	label:SetSize(width, 28)
	label:Show()
end

-- Fills a frame's stamps from an Announcement: its stamp texts and "+N" for those beyond 4 (ANN-R11), each set by
-- `set`. Returns the ones showing, in order, for the frame to place.
---@param frame PagleAnnouncementFrame
---@param announcement PagleAnnouncement
---@param set fun(stamp: PagleStamp, text: string)
---@return PagleStamp[]
local function fillStamps(frame, announcement, set)
	local showing = {}
	for i, stamp in ipairs(frame.stamps) do
		stamp:ClearAllPoints()
		local label = announcement.stamps[i]
		if i == STAMP_SLOTS and announcement.more > 0 then
			label = L.ANNOUNCEMENT_STAMPS_MORE:format(announcement.more)
		end
		if label then
			set(stamp, label)
			showing[#showing + 1] = stamp
		else
			stamp:Hide()
		end
	end
	return showing
end

-- A solid line on `frame` in an ink, at `alpha`.
---@param frame Frame
---@param role string
---@param alpha number
---@param layerName DrawLayer
---@param sublevel integer
---@return Texture
local function inkLine(frame, role, alpha, layerName, sublevel)
	local color = ns.ANNOUNCE_COLORS[role]
	local texture = frame:CreateTexture(nil, layerName, nil, sublevel)
	texture:SetColorTexture(color[1], color[2], color[3], alpha)
	return texture
end

-- A record ruler (ANN-R22), inked on the page: the label, a ticked track with the blue-black fill up to the number,
-- a pencil mark at the old record with its number over it, the number by the fill, then the margin in red once
-- landed and the "New record" stamp. Back to front: the track, the fill over it, then the marks, so the old record's
-- mark stays in sight as the fill passes it; the words are in OVERLAY, over the fill too. Its stamp is on `stamps`,
-- the toast's words frame, to sit with the toast's stamps.
---@param parent Frame
---@param compact boolean a Nod's: shorter, the number and margin after the track, with no label, old number or stamp
---@return PagleRulerView
local function newRuler(parent, compact)
	local ruler = CreateFrame("Frame", nil, parent) --[[@as PagleRulerView]]
	ruler.compact = compact
	ruler.bar = CreateFrame("Frame", nil, ruler)
	local bar = ruler.bar
	ruler.track = inkLine(bar, "rule", 1, "ARTWORK", 0)
	ruler.track:SetPoint("BOTTOMLEFT")
	ruler.track:SetPoint("BOTTOMRIGHT")
	ruler.track:SetHeight(1.5)
	ruler.ticks = {}
	for i = 0, compact and -1 or TICKS do
		local long = i % 4 == 0
		local tick = inkLine(bar, "rule", long and 0.8 or 0.35, "ARTWORK", 0)
		tick:SetSize(1, long and 10 or 5)
		ruler.ticks[#ruler.ticks + 1] = tick
	end
	ruler.fill = ns.ArtSprite(bar, "Announce", "ruler-fill", "ARTWORK", 1)
	ruler.mark = inkLine(bar, "pencil", 0.85, "ARTWORK", 2)
	ruler.mark:SetSize(2, compact and 12 or 18)
	ruler.newMark = inkLine(bar, "fill", 1, "ARTWORK", 3)
	ruler.newMark:SetSize(2, compact and 13 or 20)
	ruler.old = ns.ArtText(bar, "RuleOld")
	ruler.old:SetPoint("BOTTOMRIGHT", ruler.mark, "TOPLEFT", -3, -8)
	ruler.old:SetShown(not compact)
	ruler.value = ns.ArtText(bar, compact and "NodStat" or "RuleNew")
	ruler.margin = ns.ArtText(ruler, compact and "NodStat" or "RuleGain")
	ruler.label = ns.ArtText(ruler, "RuleLabel")
	ruler.label:SetShown(not compact)
	ruler.record = ns.NewStamp(parent)
	if compact then
		ns.Ink(ruler.value, "ink")
		ruler:SetHeight(20)
		bar:SetPoint("LEFT")
		bar:SetSize(COMPACT_TRACK, 9)
		ruler.trackWidth = COMPACT_TRACK
		ruler.value:SetPoint("LEFT", bar, "RIGHT", 6, 2)
		ruler.margin:SetPoint("LEFT", ruler.value, "RIGHT", 6, 0)
	else
		ruler.label:SetPoint("BOTTOMLEFT")
		ruler.margin:SetPoint("BOTTOMRIGHT")
		ruler.value:SetPoint("BOTTOMLEFT", ruler.newMark, "TOPRIGHT", 3, 0)
	end
	ruler:Hide()
	return ruler
end

-- Lays a full ruler `width` wide: the label at the left, room for the margin at the right, the track between.
---@param ruler PagleRulerView
---@param width number
---@param label string
local function layRuler(ruler, width, label)
	ruler:SetSize(width, 28)
	ruler.label:SetText(ns.Capitals(label))
	local left = ruler.label:GetStringWidth() + 10
	local trackWidth = math.max(60, width - left - 74)
	ruler.trackWidth = trackWidth
	ruler.bar:ClearAllPoints()
	ruler.bar:SetPoint("TOPLEFT", ruler, "TOPLEFT", left, -16)
	ruler.bar:SetSize(trackWidth, 10)
	for i, tick in ipairs(ruler.ticks) do
		tick:ClearAllPoints()
		tick:SetPoint("BOTTOMLEFT", ruler.bar, "BOTTOMLEFT", trackWidth * (i - 1) / TICKS, 0)
	end
end

-- Draws a ruler at one moment of its animation.
---@param ruler PagleRulerView
---@param at PagleRulerFrame
local function drawRuler(ruler, at)
	local width = ruler.trackWidth
	local reached = width * math.min(1, at.fill)
	ruler.fill:ClearAllPoints()
	ruler.fill:SetPoint("BOTTOMLEFT", ruler.bar, "BOTTOMLEFT", -3, 0)
	ruler.fill:SetSize(reached + 3, ruler.compact and 8 or 9)
	ruler.mark:ClearAllPoints()
	ruler.mark:SetPoint("BOTTOMLEFT", ruler.bar, "BOTTOMLEFT", width * at.mark, -4)
	ruler.newMark:ClearAllPoints()
	ruler.newMark:SetPoint("BOTTOMLEFT", ruler.bar, "BOTTOMLEFT", reached, -5)
	ruler.old:SetText(at.old)
	ruler.value:SetText(at.value)
	ruler.margin:SetText(at.margin)
	ruler.margin:SetShown(at.done)
	if at.stamped and not ruler.compact then
		ns.SetStamp(ruler.record, L.ANNOUNCEMENT_NEW_RECORD, ruler.style)
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
		view.record:Hide()
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

-- The headline's words at `x`, `y` from the frame's top left: its title printed in capitals, its text under it in the
-- Angler's hand; or, with no text, the title alone in the hand. Each is held to `width`. `fonts` and `inks` give the
-- printed and handwritten fonts and inks.
---@param frame PagleAnnouncementFrame
---@param headline { title: string, text: string? }
---@param fonts { what: string, name: string }
---@param inks { what: string, name: string }
---@param width number
local function writeHeadline(frame, headline, fonts, inks, width)
	local title, text = frame.title, frame.text
	if headline.text then
		ns.SetArtFont(title, fonts.what)
		ns.Ink(title, inks.what)
		title:SetText(ns.Capitals(headline.title))
		fit(title, width)
		ns.SetArtFont(text, fonts.name)
		ns.Ink(text, inks.name)
		text:SetText(headline.text)
		fit(text, width)
		text:Show()
	else
		ns.SetArtFont(title, fonts.name)
		ns.Ink(title, inks.name)
		title:SetText(headline.title)
		fit(title, width)
		text:SetText("")
		text:Hide()
	end
end

-- The handwritten line under the title: the text, or the title when there is none.
---@param frame PagleAnnouncementFrame
---@return FontString
local function nameLine(frame)
	return frame.text:IsShown() and frame.text or frame.title
end

-- "While you were fighting"'s row `i`, made on first use: a small medallion, the held headline's title and text.
---@param frame PagleAnnouncementFrame
---@param i integer
---@return PagleDigestRow
local function digestRow(frame, i)
	local rows = frame.rows --[[@as PagleDigestRow[] ]]
	local row = rows[i]
	if not row then
		row = CreateFrame("Frame", nil, frame.words) --[[@as PagleDigestRow]]
		row:SetSize(22, 22)
		row.bezel = ns.NewBezel(row)
		row.bezel:SetPoint("LEFT")
		row.what = ns.ArtText(row, "DigestWhat")
		row.what:SetPoint("LEFT", row, "LEFT", 30, 0)
		row.name = ns.ArtText(row, "DigestName")
		row.name:SetPoint("LEFT", row, "LEFT", 150, 1)
		rows[i] = row
	end
	return row
end

-- Lists the held headlines a row each under the title (ANN-R36), up to DIGEST_ROWS; with more, the last row says
-- how many more.
---@param frame PagleAnnouncementFrame
---@param held PagleRaisedMoment[]
---@param style PagleToastStyle
---@param width number
local function drawDigest(frame, held, style, width)
	local shown = math.min(#held, DIGEST_ROWS)
	for i = 1, shown do
		local row = digestRow(frame, i)
		local moment = held[i]
		local rest = i == DIGEST_ROWS and #held - DIGEST_ROWS + 1 or 0
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", i == 1 and frame.title or frame.rows[i - 1], "BOTTOMLEFT", 0, i == 1 and -8 or -6)
		ns.SetBezel(row.bezel, 22, style.trim, textureOf(moment.icon))
		row.bezel:SetShown(rest <= 1)
		ns.Ink(row.what, style.what)
		ns.Ink(row.name, style.name)
		if rest > 1 then
			row.what:SetText("")
			row.name:SetText(L.ANNOUNCEMENT_MORE:format(rest))
		else
			row.what:SetText(ns.Capitals(moment.title))
			row.name:SetText(moment.text or "")
		end
		fit(row.name, width - 150)
		row:Show()
	end
	for i = shown + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
end

-- The words, stamps and parts every toast and Nod has: the medallion, the title and text, the stamps and the Coins.
---@param frame PagleAnnouncementFrame
---@param coinsFont string
local function addWords(frame, coinsFont)
	frame.bezel = ns.NewBezel(layer(frame, 2))
	frame.icon = frame.bezel.Icon
	frame.words = layer(frame, 3)
	frame.title = ns.ArtText(frame.words, "What")
	frame.text = ns.ArtText(frame.words, "Name")
	frame.stamps = {}
	for i = 1, STAMP_SLOTS do
		frame.stamps[i] = ns.NewStamp(frame.words)
	end
	frame.coins = newCoins(frame.words, coinsFont)
end

-- Draws a toast: its page by rung (logic/ToastStyles.lua's ns.ToastPage), the medallion, the words, the ruler or the
-- held headlines, the stamps right to left from the top right corner, "+N more" and the Coins at the bottom right.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
---@param style PagleToastStyle
local function drawToast(frame, display, style)
	local announcement = display.announcement
	local headline = announcement.headline
	local page = ns.ToastPage(announcement)
	frame:SetSize(page.w, page.h)
	ns.SetSprite(frame.page, style.atlas, "toast-" .. page.page)
	ns.PlaceSprite(frame.page, frame, 0, 0)
	local bezel = frame.bezel --[[@as PagleBezel]]
	local icon = announcement.fighting and FIGHTING_ICON or textureOf(headline.icon)
	ns.SetBezel(bezel, page.bezel, page.high and style.highTrim or style.trim, icon)
	bezel:ClearAllPoints()
	bezel:SetPoint("TOPLEFT", frame, "TOPLEFT", page.bx, -(page.h - page.bezel) / 2)

	local width = page.w - page.tx - 34 - (announcement.coins > 0 and 34 or 0)
	local inks = {
		what = page.low and "pencil" or page.high and "giltDeep" or style.what,
		name = page.low and "pencilName" or style.name,
	}
	local fonts = { what = "What", name = page.low and "NameLow" or page.high and "NameHigh" or "Name" }
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", page.tx, -page.ty)
	frame.text:ClearAllPoints()
	frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
	if announcement.fighting then
		writeHeadline(frame, { title = headline.title, text = "" }, fonts, inks, width)
		frame.text:Hide()
		drawDigest(frame, announcement.fighting, style, page.w - page.tx - 34)
	else
		writeHeadline(frame, headline, fonts, inks, width)
		drawDigest(frame, {}, style, 0)
	end

	local ruler = frame.ruler --[[@as PagleRulerView]]
	ruler.style = style
	ruler:ClearAllPoints()
	if page.ruled then
		local nameSize = ns.ArtFontSize(fonts.name)
		local top = page.ty + (frame.text:IsShown() and 18 or 0) + nameSize + 4
		ruler:SetPoint("TOPLEFT", frame, "TOPLEFT", page.tx, -top)
		layRuler(ruler, width - 6, headline.ruler.label)
	end

	local more = frame.more --[[@as FontString]]
	more:SetText(L.ANNOUNCEMENT_MORE:format(display.overflow))
	more:SetShown(display.overflow > 0)
	more:ClearAllPoints()
	if page.ruled or announcement.fighting then
		more:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", page.tx, 6)
	else
		more:SetPoint("TOPLEFT", nameLine(frame), "BOTTOMLEFT", 2, 2)
	end

	frame.wax:SetShown(page.high == true)
	local x = page.high and page.w - 96 or page.w - 30
	local drops = { 2, 8, 4, 6, 3 }
	local stamps = fillStamps(frame, announcement, function(stamp, text)
		ns.SetStamp(stamp, text, style)
	end)
	for i, stamp in ipairs(stamps) do
		stamp:SetPoint("TOPRIGHT", frame, "TOPLEFT", x, -drops[i])
		x = x - stamp:GetWidth() - 4
	end
	ruler.record:ClearAllPoints()
	ruler.record:SetPoint("TOPRIGHT", frame, "TOPLEFT", x, -6)

	frame.coins:ClearAllPoints()
	if setCoins(frame.coins, announcement.coins, page.coin, false) > 0 then
		frame.coins:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, page.low and 4 or -2)
		ns.Ink(frame.coins.label, page.low and "amtLow" or "amt")
	end
end

-- Draws a Nod: the medallion, then on a torn strip its words, a compact ruler, its stamps and its Coins, in a line
-- the strip is three-sliced to fit.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
---@param style PagleToastStyle
local function drawNod(frame, display, style)
	local announcement = display.announcement
	local headline = announcement.headline
	ns.SetBezel(frame.bezel --[[@as PagleBezel]], 34, style.trim, textureOf(headline.icon))
	local fonts, inks = { what = "NodWhat", name = "NodName" }, { what = style.what, name = style.name }
	writeHeadline(frame, headline, fonts, inks, 300)
	local x = 72 + frame.title:GetWidth()
	---@type Region
	local last = frame.title
	frame.text:ClearAllPoints()
	if frame.text:IsShown() then
		frame.text:SetPoint("LEFT", frame.title, "RIGHT", 9, 1)
		x = x + 9 + frame.text:GetWidth()
		last = frame.text
	end
	local ruler = frame.ruler --[[@as PagleRulerView]]
	ruler.style = style
	ruler:ClearAllPoints()
	if headline.ruler then
		-- As wide as it ends: the track, then the number and the margin once landed.
		local landed = ns.RulerAt(headline.ruler, math.huge, ns.LengthUnit())
		ruler.value:SetText(landed.value)
		ruler.margin:SetText(landed.margin)
		local width = COMPACT_TRACK + 6 + ruler.value:GetStringWidth() + 6 + ruler.margin:GetStringWidth()
		ruler:SetWidth(width)
		ruler:SetPoint("LEFT", last, "RIGHT", 9, 0)
		x = x + 9 + width
		last = ruler
	end
	local stamps = fillStamps(frame, announcement, function(stamp, text)
		ns.SetStamp(stamp, text, style)
	end)
	for _, stamp in ipairs(stamps) do
		stamp:SetPoint("LEFT", last, "RIGHT", 6, 0)
		x = x + 6 + stamp:GetWidth()
		last = stamp
	end
	frame.coins:ClearAllPoints()
	local coins = setCoins(frame.coins, announcement.coins, 22, true)
	if coins > 0 then
		frame.coins:SetPoint("LEFT", last, "RIGHT", 9, 0)
		x = x + 9 + coins
	end
	local strip = math.min(x, NOD_WIDTH)
	ns.SetThreeSlice(frame.strip --[[@as PagleThreeSlice]], style.atlas, "nod-strip", strip, 26, "BACKGROUND")
	frame:SetWidth(22 + strip)
end

-- Lays a banner's or the splash's labels and Coins in one centred row on `extras`; hides it with neither.
---@param frame PagleAnnouncementFrame
---@param announcement PagleAnnouncement
---@param coinSize number
local function drawExtras(frame, announcement, coinSize)
	local extras = frame.extras --[[@as Frame]]
	local labels = fillStamps(frame, announcement, setLabel)
	local width = 0
	for i, label in ipairs(labels) do
		label:SetPoint("LEFT", extras, "LEFT", width, 0)
		width = width + label:GetWidth() + (i < #labels and 12 or 0)
	end
	frame.coins:ClearAllPoints()
	local coins = setCoins(frame.coins, announcement.coins, coinSize, true)
	if coins > 0 then
		width = width + (#labels > 0 and 12 or 0)
		frame.coins:SetPoint("LEFT", extras, "LEFT", width, 0)
		width = width + coins
	end
	extras:SetSize(math.max(1, width), 40)
	extras:SetShown(width > 0)
end

-- Draws a banner: the spaced gilt title, the seal (a number, a mark, or the Prestige crest with the Angler's portrait),
-- the text in gilt handwriting, then the labels and Coins.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
local function drawBanner(frame, display)
	local announcement = display.announcement
	local headline = announcement.headline
	frame.title:SetText(ns.SpacedCaps(headline.title))
	local seal = ns.BannerSeal(headline)
	local wax = frame.seal --[[@as PagleSprite]]
	local number = frame.sealNumber --[[@as FontString]]
	wax:SetShown(not seal.crest)
	frame.crest:SetShown(seal.crest == true)
	frame.portrait:SetShown(seal.crest == true)
	frame.crestLabel:SetShown(seal.crest == true)
	number:SetShown(seal.number ~= nil)
	if seal.crest then
		SetPortraitTexture(frame.portrait, "player")
		frame.crestLabel:SetText(ns.Capitals(headline.title))
	else
		ns.SetSprite(wax, "Announce", seal.mark and "seal-" .. seal.mark or "seal")
		ns.PlaceSprite(wax, wax:GetParent() --[[@as Frame]], 0, 0)
	end
	if seal.number then
		local digits = BreakUpLargeNumbers(seal.number)
		ns.SetArtFont(number, #digits > 2 and "SealSmall" or "SealNumber")
		number:SetText(digits)
	end
	local y = -29 - 150 - (seal.crest and 26 or 4)
	local text = frame.text
	text:ClearAllPoints()
	text:SetPoint("TOP", frame, "TOP", 0, y)
	text:SetText(headline.text or "")
	ns.SetArtFont(text, "TitleGilt")
	if text:GetStringWidth() > 860 then
		ns.SetArtFont(text, "Say")
	end
	text:SetShown(headline.text ~= nil)
	if headline.text then
		y = y - 52
	end
	frame.extras:ClearAllPoints()
	frame.extras:SetPoint("TOP", frame, "TOP", 0, y - 10)
	drawExtras(frame, announcement, 38)
end

-- Draws the splash: the Legend's icon in the crest's window, its title printed over its name on the torn page, the
-- labels and Coins under them.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
local function drawSplash(frame, display)
	local announcement = display.announcement
	local headline = announcement.headline
	frame.icon:SetTexture(textureOf(headline.icon))
	frame.title:SetText(ns.Capitals(headline.title))
	frame.text:SetText(headline.text or "")
	fit(frame.text, 820)
	frame.text:SetShown(headline.text ~= nil)
	frame.extras:ClearAllPoints()
	frame.extras:SetPoint("TOP", headline.text and frame.text or frame.title, "BOTTOM", 0, -12)
	drawExtras(frame, announcement, 42)
end

-- The frames, one per form, as announcements.md › UI draws them.
---@type table<PagleAnnouncementForm, fun(parent: Frame?): PagleAnnouncementFrame>
local BUILD = {
	-- Above the action bar. On `parent` instead, for a sample toast.
	toast = function(parent)
		local frame = CreateFrame("Frame", nil, parent or UIParent) --[[@as PagleAnnouncementFrame]]
		if not parent then
			frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 190)
		end
		frame:SetSize(464, 92)
		frame:SetFrameStrata("HIGH")
		frame.page = ns.ArtSprite(frame, "ToastsLedger", "toast-toast", "BACKGROUND")
		addWords(frame, "Amt")
		frame.more = ns.ArtText(frame.words, "More")
		frame.wax = ns.ArtSprite(frame.words, "Announce", "wax-hunt", "OVERLAY", 2)
		ns.PlaceSprite(frame.wax, frame, 524 - 26 - 58, -14)
		frame.ruler = newRuler(frame.words, false)
		frame.rows = {}
		return frame
	end,
	-- One line under the toast.
	nod = function()
		local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 156)
		frame:SetSize(NOD_WIDTH, 40)
		frame:SetFrameStrata("HIGH")
		frame.strip = CreateFrame("Frame", nil, frame) --[[@as PagleThreeSlice]]
		frame.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, 0)
		addWords(frame, "NodAmt")
		frame.bezel:SetPoint("LEFT")
		frame.title:SetPoint("LEFT", frame, "LEFT", 72, 0)
		frame.ruler = newRuler(frame.words, true)
		return frame
	end,
	-- Centre screen over the world, with no frame: a dark glow, faint gilt rays, the spaced gilt title, gilt tooling
	-- either side of the red wax seal, the text, then the labels and Coins.
	banner = function()
		local frame = CreateFrame("Frame", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetPoint("TOP", UIParent, "TOP", 0, -120)
		frame:SetSize(980, 330)
		frame:SetFrameStrata("HIGH")
		ns.PlaceSprite(ns.ArtSprite(frame, "Splash", "glow", "BACKGROUND", 0), frame, 0, 40)
		local rays = ns.ArtSprite(frame, "Splash", "rays", "BACKGROUND", 1)
		rays:ClearAllPoints()
		rays:SetPoint("CENTER", frame, "TOP", 0, -128)
		frame.title = ns.ArtText(frame, "Kick")
		frame.title:SetPoint("TOP")
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(802, 150)
		row:SetPoint("TOP", 0, -29)
		ns.PlaceSprite(ns.ArtSprite(row, "Announce", "tool-left", "ARTWORK"), row, 0, 45)
		ns.PlaceSprite(ns.ArtSprite(row, "Announce", "tool-right", "ARTWORK"), row, 462, 45)
		local centre = CreateFrame("Frame", nil, row)
		centre:SetSize(150, 150)
		centre:SetPoint("TOP")
		frame.seal = ns.ArtSprite(centre, "Announce", "seal", "ARTWORK", 1)
		frame.sealNumber = ns.ArtText(centre, "SealNumber")
		frame.sealNumber:SetPoint("CENTER", centre, "CENTER", 0, -2)
		frame.sealNumber:SetShadowColor(1, 0.67, 0.59, 0.45)
		frame.sealNumber:SetShadowOffset(0, -1.5)
		-- The crest's sprite carries 16 units of shadow above it, and the crest rises 44 above the row.
		frame.crest = ns.ArtSprite(centre, "Announce", "crest-prestige", "ARTWORK", 1)
		ns.PlaceSprite(frame.crest, centre, 0, -44)
		frame.portrait = centre:CreateTexture(nil, "ARTWORK", nil, 2)
		frame.portrait:SetSize(84, 84)
		frame.portrait:SetPoint("TOP", centre, "TOP", 0, -10)
		frame.crestLabel = ns.ArtText(centre, "Crest")
		frame.crestLabel:SetPoint("CENTER", centre, "TOP", 0, -117)
		frame.text = ns.ArtText(frame, "TitleGilt")
		frame.extras = CreateFrame("Frame", nil, frame)
		frame.stamps = {}
		for i = 1, STAMP_SLOTS do
			frame.stamps[i] = newLabel(frame.extras)
		end
		frame.coins = newCoins(frame.extras, "BanAmt")
		return frame
	end,
	-- Full screen for a Legend, until clicked: the screen darkens behind slow rays, the Legend crest holds the item's
	-- icon, and a torn page carries its title and name.
	splash = function()
		local frame = CreateFrame("Button", nil, UIParent) --[[@as PagleAnnouncementFrame]]
		frame:SetAllPoints(UIParent)
		frame:SetFrameStrata("FULLSCREEN_DIALOG")
		frame:EnableMouse(true)
		local dim = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
		dim:SetAllPoints()
		dim:SetColorTexture(0.016, 0.012, 0.008, 0.82)
		local rays = ns.ArtSprite(frame, "Splash", "rays", "BACKGROUND", 1)
		rays:SetSize(1300, 1300)
		rays:ClearAllPoints()
		rays:SetPoint("CENTER", frame, "TOP", 0, -205)
		local crest = layer(frame, 3)
		crest:ClearAllPoints()
		crest:SetSize(250, 275)
		crest:SetPoint("TOP", frame, "TOP", 0, -70)
		ns.PlaceSprite(ns.ArtSprite(crest, "Splash", "crest-legend", "ARTWORK", 0), crest, 0, 0)
		frame.icon = crest:CreateTexture(nil, "ARTWORK", nil, 1)
		frame.icon:SetSize(150, 150)
		frame.icon:SetPoint("TOP", crest, "TOP", 0, -50)
		local mask = crest:CreateMaskTexture()
		mask:SetTexture(
			"Interface\\CharacterFrame\\TempPortraitAlphaMask",
			"CLAMPTOBLACKADDITIVE",
			"CLAMPTOBLACKADDITIVE"
		)
		mask:SetAllPoints(frame.icon)
		frame.icon:AddMaskTexture(mask)
		local page = layer(frame, 1)
		page:ClearAllPoints()
		page:SetSize(880, 250)
		page:SetPoint("TOP", crest, "BOTTOM", 0, 46)
		ns.PlaceSprite(ns.ArtSprite(page, "Splash", "splash-page", "ARTWORK", 0), page, 0, 0)
		frame.title = ns.ArtText(page, "SplashWhat")
		frame.title:SetPoint("TOP", page, "TOP", 0, -62)
		frame.text = ns.ArtText(page, "SplashName")
		frame.text:SetPoint("TOP", frame.title, "BOTTOM", 0, -10)
		frame.extras = CreateFrame("Frame", nil, page)
		frame.stamps = {}
		for i = 1, STAMP_SLOTS do
			frame.stamps[i] = newLabel(frame.extras)
		end
		frame.coins = newCoins(frame.extras, "Amt")
		local hint = ns.ArtText(frame, "AnyClick")
		hint:SetPoint("BOTTOM", frame, "BOTTOM", 0, 44)
		hint:SetText(ns.SpacedCaps(L.ANNOUNCEMENT_SPLASH_HINT))
		frame:SetScript("OnClick", function(self)
			if self.display then
				ns.lanes:Dismiss(self.display)
			end
		end)
		return frame
	end,
}

local DRAW = { toast = drawToast, nod = drawNod, banner = drawBanner, splash = drawSplash }

--- Draws a display in a frame of its form, the toast and Nod in the toast style it carries (a sample's) or else the
--- equipped one (ANN-R80). Drawn again with the same display, as when the style changes, its ruler carries on where it
--- was; a new display starts it.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
function ns.DrawAnnouncement(frame, display)
	local style = ns.DisplayStyle(display)
	DRAW[display.form](frame, display, style)
	local ruler = frame.ruler
	if not ruler then
		return
	end
	local headline = display.announcement.headline
	local ruled = headline.ruler and (display.form == "nod" or ns.ToastPage(display.announcement).ruled)
	if frame.drawnRuler ~= display or not ruled then
		frame.drawnRuler = display
		startRuler(ruler, ruled and headline.ruler or nil)
	else
		drawRuler(ruler, ns.RulerAt(ruler.ruler, ruler.elapsed, ruler.lengthUnit))
	end
end

--- A toast frame on `parent`, for a sample toast (wallet-and-shop.md › UI, the preview stage).
---@param parent Frame
---@return PagleAnnouncementFrame
function ns.NewToastFrame(parent)
	local frame = BUILD.toast(parent)
	frame:Hide()
	return frame
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
	ns.DrawAnnouncement(frame, display)
	frame:Show()
end

-- The lanes' hide: off screen, its ruler stopped, if the frame still shows this display.
---@param display PagleDisplay
local function hide(display)
	local frame = ns.announcementFrames[display.form]
	if frame and frame.display == display then
		frame.display, frame.drawnRuler = nil, nil
		if frame.ruler then
			frame.ruler:SetScript("OnUpdate", nil)
		end
		frame:Hide()
	end
end

--- Core's three lanes (ANN-R20) on the client. Each form has its own frame, so a banner and a toast show together.
ns.lanes = ns.NewLanes({
	-- GetTime() reads the same all frame, which is how the lanes tell a toast appears with a banner (ANN-R24).
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
	-- The equipped sound set (ANN-R70, ANN-R72), read as each sound is picked, so it follows AppearanceChanged
	-- (SHOP-R33).
	soundSet = function()
		return ns.SoundSetOf(ns.goods:GetEquipped(ns.SOUND_SET_SLOT))
	end,
	show = show,
	hide = hide,
	play = function(path)
		PlaySoundFile(path, "SFX")
	end,
	-- Both lanes freed with nothing waiting: a card may show (ANN-R21). adapter/Cards.lua's, looked up when called.
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
