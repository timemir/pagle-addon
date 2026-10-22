---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Showing Announcements on the client (announcements.md › The display queue, › Interruption budget, › Sounds,
-- › Toast styles, › UI; ADR 0007): logic/Announcements.lua's lanes on GetTime and C_Timer.After, reading the budget
-- from PagleDB.profile.announcements, drawing the toast, Nod, banner and splash in the announcements art kit
-- (adapter/Art.lua), the toast and Nod in the equipped toast style (ANN-R80), moving as the kit's motion has them
-- (announcements.md › Motion, adapter/Motion.lua), and playing the sounds with PlaySoundFile on the SFX channel
-- (ANN-R73). A toast is a fresh entry in the Angler's ledger: a torn page on a
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
-- Held headlines "While you were fighting" lists, a row each; "+N more" under them counts the rest.
local DIGEST_ROWS = 3
-- Its icon: crossed blades.
local FIGHTING_ICON = "Interface\\Icons\\Ability_DualWield"
-- A banner's top below the screen's (ANN-R20).
local BANNER_TOP = 120
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
---@field slammed boolean? its New record stamp has slammed down
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
---@field moved PagleDisplay? the display whose motion has played
---@field lanes boolean? one of the lanes' own frames, not a sample's: it moves
---@field inUse boolean? showing a display, or still leaving
---@field slot number? a column frame's place above the column's foot
---@field ribbon number? how far a toast.high's bookmark hangs below its page
---@field body Frame? a toast's page and words, which slide in under the frame the lanes anchor
---@field nameClip Frame? the clip a toast's name is written out in
---@field pivots Frame[]? the points a toast's stamps grow about
---@field recordPivot Frame? the point the ruler's New record stamp grows about
---@field rays PagleSprite? a banner's or the splash's
---@field sealFrame Frame? a banner's seal or crest, which drops in
---@field tools { sprite: PagleSprite, x: number, y: number, outward: boolean }[]? a banner's gilt tooling
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

-- The motion's timeline: the canvas loops each animation over 7 s; in game each plays once.
local TIMELINE = 7
local SLIDE = ns.Bezier(0.2, 1.2, 0.4, 1)
local SLAM = ns.Bezier(0.3, 1.6, 0.5, 1)
local DROP = ns.Bezier(0.3, 1.5, 0.5, 1)

-- A stamp slamming down at `at` of the timeline: from 2.6x and unseen to a little under its size, then settled.
---@param stamp Frame
---@param at number
---@return PagleAnimation
local function slam(stamp, at)
	return {
		dur = TIMELINE,
		ease = SLAM,
		keys = {
			{ 0, { 2.6, 0 } },
			{ at, { 2.6, 0 } },
			{ at + 0.04, { 0.95, 0.95 } },
			{ at + 0.06, { 1, 0.9 } },
			{ 1, { 1, 0.9 } },
		},
		apply = function(v)
			stamp:SetScale(math.max(0.01, v[1]))
			stamp:SetAlpha(math.max(0, v[2]))
		end,
	}
end

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
	ns.CenterSpriteAt(coin, coins, coinFirst and size / 2 or width - size / 2, size / 2)
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
		if not ruler.slammed then
			ruler.slammed = true
			ns.Animate(ruler.record, { slam(ruler.record, 0) })
		end
	else
		ruler.record:Hide()
	end
end

-- Shows a headline's ruler and starts its animation, or hides the ruler when it has none (ANN-R22). With Animations
-- off it appears as it settles: the number counted up, the margin in and the stamp down.
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
	view.ruler, view.elapsed, view.lengthUnit, view.slammed = ruler, 0, ns.LengthUnit(), false
	if not ns.MotionOn() then
		drawRuler(view, ns.RulerAt(ruler, ns.RULER_SECONDS + ns.RULER_STAMP_DELAY, view.lengthUnit))
		view:Show()
		return
	end
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
-- Angler's hand; or, with no text, the title alone in the hand. Each is held to `width`, the hand shrinking to fit
-- first. `fonts` and `inks` give the printed and handwritten fonts and inks.
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
		ns.ShrinkToFit(text, fonts.name, width)
		text:Show()
	else
		ns.SetArtFont(title, fonts.name)
		ns.Ink(title, inks.name)
		title:SetText(headline.title)
		ns.ShrinkToFit(title, fonts.name, width)
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

-- Lists the held headlines a row each under the title (ANN-R36), up to DIGEST_ROWS.
---@param frame PagleAnnouncementFrame
---@param held PagleRaisedMoment[]
---@param style PagleToastStyle
---@param width number
local function drawDigest(frame, held, style, width)
	local shown = math.min(#held, DIGEST_ROWS)
	for i = 1, shown do
		local row = digestRow(frame, i)
		local moment = held[i]
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", i == 1 and frame.title or frame.rows[i - 1], "BOTTOMLEFT", 0, i == 1 and -8 or -6)
		ns.SetBezel(row.bezel, 22, style.trim, textureOf(moment.icon))
		ns.Ink(row.what, style.what)
		ns.SetArtFont(row.name, "DigestName")
		ns.Ink(row.name, style.name)
		row.what:SetText(ns.Capitals(moment.title))
		row.name:SetText(moment.text or "")
		ns.ShrinkToFit(row.name, "DigestName", width - 150)
		row:Show()
	end
	for i = shown + 1, #frame.rows do
		frame.rows[i]:Hide()
	end
end

-- The words, stamps and parts every toast and Nod has: the medallion, the title and text, the stamps and the Coins.
-- They sit on `host`, the frame itself or a toast's body. With `clipName`, the name is in a clip that its motion
-- widens to write it out.
---@param frame PagleAnnouncementFrame
---@param coinsFont string
---@param host Frame?
---@param clipName boolean?
local function addWords(frame, coinsFont, host, clipName)
	host = host or frame
	frame.bezel = ns.NewBezel(layer(host, 2))
	frame.icon = frame.bezel.Icon
	frame.words = layer(host, 3)
	frame.title = ns.ArtText(frame.words, "What")
	local nameParent = frame.words
	if clipName then
		frame.nameClip = CreateFrame("Frame", nil, frame.words)
		frame.nameClip:SetClipsChildren(true)
		nameParent = CreateFrame("Frame", nil, frame.nameClip)
		nameParent:SetAllPoints(frame.words)
	end
	frame.text = ns.ArtText(nameParent, "Name")
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
	local body = frame.body --[[@as Frame]]
	frame:SetSize(page.w, page.h)
	body:SetSize(page.w, page.h)
	ns.SetSprite(frame.page, style.atlas, "toast-" .. page.page)
	ns.PlaceSprite(frame.page, body, 0, 0)
	local bezel = frame.bezel --[[@as PagleBezel]]
	local icon = announcement.fighting and FIGHTING_ICON or textureOf(headline.icon)
	ns.SetBezel(bezel, page.bezel, page.high and style.highTrim or style.trim, icon)
	bezel:ClearAllPoints()
	bezel:SetPoint("TOPLEFT", body, "TOPLEFT", page.bx, -(page.h - page.bezel) / 2)

	local width = page.w - page.tx - 34 - (announcement.coins > 0 and 34 or 0)
	local inks = {
		what = page.low and "pencil" or page.high and "giltDeep" or style.what,
		name = page.low and "pencilName" or style.name,
	}
	local fonts = { what = "What", name = page.low and "NameLow" or page.high and "NameHigh" or "Name" }
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", body, "TOPLEFT", page.tx, -page.ty)
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
	-- The clip the name is written out in, round the name as written.
	local clip = frame.nameClip --[[@as Frame]]
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", frame.text, "TOPLEFT", -4, 8)
	clip:SetSize(frame.text:GetWidth() + 8, ns.ArtFontSize(fonts.name) + 22)
	clip:SetShown(frame.text:IsShown())

	local ruler = frame.ruler --[[@as PagleRulerView]]
	ruler.style = style
	ruler:ClearAllPoints()
	if page.ruled then
		local nameSize = ns.ArtFontSize(fonts.name)
		local top = page.ty + (frame.text:IsShown() and 18 or 0) + nameSize + 4
		ruler:SetPoint("TOPLEFT", body, "TOPLEFT", page.tx, -top)
		layRuler(ruler, width - 6, headline.ruler.label)
	end

	local more = frame.more --[[@as FontString]]
	-- "While you were fighting" counts the held headlines past its rows (ANN-R36).
	local beyond = announcement.fighting and #announcement.fighting - DIGEST_ROWS or 0
	more:SetText(L.ANNOUNCEMENT_MORE:format(beyond))
	more:SetShown(beyond > 0)
	more:ClearAllPoints()
	if page.ruled or announcement.fighting then
		more:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", page.tx, 6)
	else
		more:SetPoint("TOPLEFT", nameLine(frame), "BOTTOMLEFT", 2, 2)
	end

	frame.wax:SetShown(page.high == true)
	local x = page.high and page.w - 96 or page.w - 30
	local drops = { 2, 8, 4, 6, 3 }
	local stamps = fillStamps(frame, announcement, function(stamp, text)
		ns.SetStamp(stamp, text, style)
	end)
	-- Each stamp hangs by its centre from a pivot, so it slams down about its middle (adapter/Art.lua's ns.Pivot).
	local pivots = frame.pivots --[[@as Frame[] ]]
	for i, stamp in ipairs(stamps) do
		local stampWidth = stamp:GetWidth()
		pivots[i]:SetPoint("CENTER", body, "TOPLEFT", x - stampWidth / 2, -(drops[i] + 13))
		stamp:SetPoint("CENTER", pivots[i], "CENTER")
		x = x - stampWidth - 4
	end
	-- The New record stamp lands to their left once the ruler fills: measured now to hang it by its centre.
	ns.SetStamp(ruler.record, L.ANNOUNCEMENT_NEW_RECORD, style)
	local record = ruler.record:GetWidth()
	ruler.record:Hide()
	frame.recordPivot:SetPoint("CENTER", body, "TOPLEFT", x - record / 2, -19)
	ruler.record:ClearAllPoints()
	ruler.record:SetPoint("CENTER", frame.recordPivot, "CENTER")

	frame.coins:ClearAllPoints()
	if setCoins(frame.coins, announcement.coins, page.coin, false) > 0 then
		frame.coins:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, page.low and 4 or -2)
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
	ns.SetArtFont(frame.text, "SplashName")
	frame.text:SetText(headline.text or "")
	ns.ShrinkToFit(frame.text, "SplashName", 820)
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
		frame:SetSize(464, 92)
		frame:SetFrameStrata("HIGH")
		-- The page and its words slide in on a body under the frame the lanes anchor.
		local body = CreateFrame("Frame", nil, frame)
		body:SetPoint("TOPLEFT")
		body:SetSize(464, 92)
		frame.body = body
		frame.page = ns.ArtSprite(body, "ToastsLedger", "toast-toast", "BACKGROUND")
		addWords(frame, "Amt", body, true)
		frame.more = ns.ArtText(frame.words, "More")
		frame.wax = ns.ArtSprite(frame.words, "Announce", "wax-hunt", "OVERLAY", 2)
		ns.PlaceSprite(frame.wax, body, 524 - 26 - 58, -14)
		frame.ruler = newRuler(frame.words, false)
		frame.rows = {}
		frame.pivots = {}
		for i = 1, STAMP_SLOTS do
			frame.pivots[i] = ns.Pivot(frame.words, body, 0, 0)
		end
		frame.recordPivot = ns.Pivot(frame.words, body, 0, 0)
		return frame
	end,
	-- One line under the toast. On `parent` instead, for a still sample.
	nod = function(parent)
		local frame = CreateFrame("Frame", nil, parent or UIParent) --[[@as PagleAnnouncementFrame]]
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
	-- either side of the red wax seal, the text, then the labels and Coins. On `parent` instead, for a still sample,
	-- placed by its parent.
	banner = function(parent)
		local frame = CreateFrame("Frame", nil, parent or UIParent) --[[@as PagleAnnouncementFrame]]
		if not parent then
			frame:SetPoint("TOP", UIParent, "TOP", 0, -BANNER_TOP)
		end
		frame:SetSize(980, 330)
		frame:SetFrameStrata("HIGH")
		ns.PlaceSprite(ns.ArtSprite(frame, "Splash", "glow", "BACKGROUND", 0), frame, 0, 40)
		frame.rays = ns.ArtSprite(frame, "Splash", "rays", "BACKGROUND", 1)
		frame.rays:ClearAllPoints()
		frame.rays:SetPoint("CENTER", frame, "TOP", 0, -128)
		frame.title = ns.ArtText(frame, "Kick")
		frame.title:SetPoint("TOP")
		local row = CreateFrame("Frame", nil, frame)
		row:SetSize(802, 150)
		row:SetPoint("TOP", 0, -29)
		-- The tooling draws out from the seal: the left's seal end is its right, the right's its left.
		frame.tools = {
			{ sprite = ns.ArtSprite(row, "Announce", "tool-left", "ARTWORK"), x = 0, y = 45, outward = false },
			{ sprite = ns.ArtSprite(row, "Announce", "tool-right", "ARTWORK"), x = 462, y = 45, outward = true },
		}
		for _, tool in ipairs(frame.tools) do
			ns.PlaceSprite(tool.sprite, row, tool.x, tool.y)
			tool.sprite.w0 = tool.sprite:GetWidth()
		end
		-- The seal hangs by its centre from the row's, so it drops in about its middle.
		local centre = CreateFrame("Frame", nil, row)
		centre:SetSize(150, 150)
		centre:SetPoint("CENTER", ns.Pivot(row, row, 401, 75), "CENTER")
		frame.sealFrame = centre
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
		frame.rays = ns.ArtSprite(frame, "Splash", "rays", "BACKGROUND", 1)
		frame.rays:SetSize(1300, 1300)
		frame.rays:ClearAllPoints()
		frame.rays:SetPoint("CENTER", frame, "TOP", 0, -205)
		local crest = layer(frame, 3)
		crest:ClearAllPoints()
		crest:SetSize(250, 275)
		crest:SetPoint("TOP", frame, "TOP", 0, -70)
		ns.PlaceSprite(ns.ArtSprite(crest, "Splash", "crest-legend", "ARTWORK", 0), crest, 0, 0)
		frame.icon = crest:CreateTexture(nil, "ARTWORK", nil, 1)
		-- A little over the crest's window, centred on it, so the ring covers the icon's edge; its own border cut off.
		frame.icon:SetSize(160, 160)
		frame.icon:SetPoint("TOP", crest, "TOP", 0, -45)
		frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
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

-- A share `k` of a placed gilt tooling: its seal end first, cut, not squashed (the canvas's clip-path).
---@param tool { sprite: PagleSprite, x: number, y: number, outward: boolean }
---@param k number
local function reveal(tool, k)
	local sprite, tc = tool.sprite, tool.sprite.tc
	k = math.max(0.001, k)
	local hidden = sprite.w0 * (1 - k)
	sprite:SetWidth(sprite.w0 * k)
	local box = sprite.box
	sprite:ClearAllPoints()
	if tool.outward then
		sprite:SetTexCoord(tc[1], tc[1] + (tc[2] - tc[1]) * k, tc[3], tc[4])
		sprite:SetPoint("TOPLEFT", sprite:GetParent() --[[@as Frame]], "TOPLEFT", tool.x - box[1], -(tool.y - box[2]))
	else
		sprite:SetTexCoord(tc[1] + (tc[2] - tc[1]) * (1 - k), tc[2], tc[3], tc[4])
		sprite:SetPoint(
			"TOPLEFT",
			sprite:GetParent() --[[@as Frame]],
			"TOPLEFT",
			tool.x - box[1] + hidden,
			-(tool.y - box[2])
		)
	end
end

-- A toast's beats (announcements.md › Sounds): the client's own sounds, by id, each with the second it plays at,
-- landing on the motion: the name starting to write, the stamps landing, the coin turning in.
local BEATS = { write = { id = 3093, at = 0.98 }, stamp = { id = 1204, at = 2.17 }, coin = { id = 120, at = 2.66 } }

-- Plays beat `name` on the SFX channel (ANN-R73).
---@param name string
---@return fun()
local function beat(name)
	return function()
		PlaySound(BEATS[name].id, "SFX")
	end
end

-- The kit's motion for each form (announcements.md › Motion), on the canvas's 7 s timeline; each plays once.
---@type table<PagleAnnouncementForm, fun(frame: PagleAnnouncementFrame)>
local MOTION = {
	-- It slides up and fades in, its name writes itself out, its stamps slam and its coin turns in edge-on: settled
	-- by 2.66 s. The record ruler keeps its own count (ANN-R22), its stamp slamming as it lands.
	toast = function(frame)
		local body = frame.body --[[@as Frame]]
		local animations = {
			{
				dur = TIMELINE,
				ease = SLIDE,
				keys = { { 0, { 26, 0 } }, { 0.08, { 26, 0 } }, { 0.14, { 0, 1 } }, { 1, { 0, 1 } } },
				apply = function(v)
					body:ClearAllPoints()
					body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -v[1])
					frame:SetAlpha(math.max(0, math.min(1, v[2])))
				end,
			},
		}
		local clip = frame.nameClip --[[@as Frame]]
		if clip:IsShown() then
			local width = clip:GetWidth()
			animations[#animations + 1] = {
				dur = TIMELINE,
				keys = { { 0, { 0 } }, { 0.14, { 0 }, ease = ns.Steps(16) }, { 0.26, { 1 } }, { 1, { 1 } } },
				apply = function(v)
					clip:SetWidth(math.max(0.01, width * v[1]))
				end,
			}
		end
		for _, stamp in ipairs(frame.stamps) do
			if stamp:IsShown() then
				animations[#animations + 1] = slam(stamp, 0.27)
			end
		end
		-- Its beats, each on its moment, for a toast that played its sound (announcements.md › Sounds).
		if frame.display and frame.display.sound then
			if clip:IsShown() then
				ns.Cue(frame, BEATS.write.at, beat("write"))
			end
			for _, stamp in ipairs(frame.stamps) do
				if stamp:IsShown() then
					ns.Cue(frame, BEATS.stamp.at, beat("stamp"))
					break
				end
			end
			if frame.coins:IsShown() then
				ns.Cue(frame, BEATS.coin.at, beat("coin"))
			end
		end
		if frame.coins:IsShown() then
			local coin = frame.coins.coin
			animations[#animations + 1] = {
				dur = TIMELINE,
				ease = ns.EASE.out,
				keys = { { 0, { 90, 0 } }, { 0.33, { 90, 0 } }, { 0.38, { 0, 1 } }, { 1, { 0, 1 } } },
				apply = function(v)
					coin:SetWidth(math.max(0.01, coin.w0 * math.cos(math.rad(v[1]))))
					coin:SetAlpha(v[2])
				end,
			}
		end
		ns.Animate(frame, animations)
	end,
	-- It fades in (0.3 s).
	nod = function(frame)
		ns.Animate(frame, {
			{
				dur = ns.SETTLE_SECONDS.nod,
				ease = ns.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					frame:SetAlpha(v[1])
				end,
			},
		})
	end,
	-- The seal drops in, the gilt tooling draws out from it and the rays turn in: settled by 1.4 s.
	banner = function(frame)
		local seal = frame.sealFrame --[[@as Frame]]
		local rays = frame.rays --[[@as PagleSprite]]
		local animations = {
			{
				dur = TIMELINE,
				ease = DROP,
				keys = { { 0, { 2.2, 0 } }, { 0.06, { 0.94, 1 } }, { 0.09, { 1, 1 } }, { 1, { 1, 1 } } },
				apply = function(v)
					seal:SetScale(math.max(0.01, v[1]))
					seal:SetAlpha(math.min(1, v[2]))
				end,
			},
			{
				dur = TIMELINE,
				ease = ns.EASE.out,
				keys = { { 0, { 0, -8 } }, { 0.05, { 0, -8 } }, { 0.2, { 1, 0 } }, { 1, { 1, 0 } } },
				apply = function(v)
					rays:SetAlpha(v[1])
					rays:SetRotation(math.rad(-v[2]))
				end,
			},
		}
		for _, tool in ipairs(frame.tools) do
			animations[#animations + 1] = {
				dur = TIMELINE,
				ease = ns.EASE.out,
				keys = { { 0, { 0 } }, { 0.05, { 0 } }, { 0.16, { 1 } }, { 1, { 1 } } },
				apply = function(v)
					reveal(tool, v[1])
				end,
			}
		end
		ns.Animate(frame, animations)
	end,
	-- The rays turn clockwise once a minute for as long as it shows.
	splash = function(frame)
		local rays = frame.rays --[[@as PagleSprite]]
		ns.Animate(frame, {
			{
				dur = 60,
				ease = ns.EASE.linear,
				iter = "infinite",
				keys = { { 0, { 0 } }, { 1, { 360 } } },
				apply = function(v)
					rays:SetRotation(math.rad(-v[1]))
				end,
			},
		})
	end,
}

--- Draws a display in a frame of its form, the toast and Nod in the toast style it carries (a sample's) or else the
--- equipped one (ANN-R80), and plays its form's motion. Drawn again with the same display, as when the style changes,
--- its motion and its ruler carry on where they were; a new display starts both. A sample on the Curio Shop's stage
--- stands still: only what the lanes show moves.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
function ns.DrawAnnouncement(frame, display)
	local style = ns.DisplayStyle(display)
	DRAW[display.form](frame, display, style)
	local motion = MOTION[display.form]
	if motion and frame.moved ~= display and frame.lanes then
		frame.moved = display
		ns.StopMotion(frame)
		motion(frame)
	end
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

--- The forms an Announcement can be drawn in standing still, on a frame of the caller's: the Curio Shop's stage, the
--- Field guide's Moments page (ONB-R34). The splash is full-screen, so it has none.
local STILL_FORMS = { toast = true, nod = true, banner = true }

--- A frame of `form` on `parent`, hidden, for an Announcement drawn standing still (wallet-and-shop.md › UI, the
--- preview stage; ONB-R34): in its parent's strata, so it draws on its parent, and never one of the lanes' frames, so
--- ns.DrawAnnouncement draws it settled, with no motion, no sound and no clock; nothing reaches the lanes or the
--- Session summary. Its parent places and scales it.
---@param parent Frame
---@param form "toast"|"nod"|"banner"
---@return PagleAnnouncementFrame
function ns.NewStillAnnouncementFrame(parent, form)
	assert(STILL_FORMS[form], "no still frame for the form " .. tostring(form))
	local frame = BUILD[form](parent)
	frame:SetFrameStrata(parent:GetFrameStrata())
	frame:Hide()
	return frame
end

--- A toast frame on `parent`, for a sample toast (wallet-and-shop.md › UI, the preview stage).
---@param parent Frame
---@return PagleAnnouncementFrame
function ns.NewToastFrame(parent)
	return ns.NewStillAnnouncementFrame(parent, "toast")
end

--- A Nod frame on `parent`, for a sample Nod standing still (ONB-R34).
---@param parent Frame
---@return PagleAnnouncementFrame
function ns.NewNodFrame(parent)
	return ns.NewStillAnnouncementFrame(parent, "nod")
end

--- A banner frame on `parent`, for a sample banner standing still (ONB-R34).
---@param parent Frame
---@return PagleAnnouncementFrame
function ns.NewBannerFrame(parent)
	return ns.NewStillAnnouncementFrame(parent, "banner")
end

-- Each parent's still frames, by form, made the first time one draws there. Weak, so a parent dropped goes.
---@type table<Frame, table<string, PagleAnnouncementFrame>>
local stills = setmetatable({}, { __mode = "k" })

--- Draws `announcement` as a `form` ("toast", "nod" or "banner") standing still on `parent` (ONB-R34, as the Curio
--- Shop's stage draws its toast): a frame of that form there, made on the first call and redrawn on each, in the
--- toast style the announcement carries or else the equipped one (ANN-R80), shown. It doesn't move or expire, and
--- nothing reaches the lanes, the sounds or the Session summary. Its parent places and scales it.
---@param parent Frame
---@param form "toast"|"nod"|"banner"
---@param announcement PagleAnnouncement
---@return PagleAnnouncementFrame
function ns.DrawStillAnnouncement(parent, form, announcement)
	local byForm = stills[parent]
	if not byForm then
		byForm = {}
		stills[parent] = byForm
	end
	local frame = byForm[form]
	if not frame then
		frame = ns.NewStillAnnouncementFrame(parent, form)
		byForm[form] = frame
	end
	ns.DrawAnnouncement(frame, { announcement = announcement, form = form, overflow = 0 })
	frame:Show()
	return frame
end

-- The column's foot above the screen's bottom, where the canvas's board puts its toast (ANN-R20).
local COLUMN_FOOT = 156
--- The toast column's foot, in UI units above the screen's bottom (ANN-R20): the Letter sits there too (ONB-R11).
ns.ANNOUNCE_COLUMN_FOOT = COLUMN_FOOT
-- How a leaving toast or Nod eases: slow, then away.
local EASE_IN = ns.Bezier(0.42, 0, 1, 1)

-- Every frame made, by form, showing or free: the column shows as many toasts and Nods as fit at once.
---@type table<PagleAnnouncementForm, PagleAnnouncementFrame[]>
local made = { toast = {}, nod = {}, banner = {}, splash = {} }

--- The toasts and Nods in the column, the newest first (ANN-R20).
---@type PagleAnnouncementFrame[]
ns.columnFrames = {}

--- Every lanes frame showing an Announcement now, as an AppearanceChanged repaint needs them.
---@return PagleAnnouncementFrame[]
function ns.AnnouncementFramesShowing()
	local showing = {}
	for _, frames in pairs(made) do
		for _, frame in ipairs(frames) do
			if frame.display then
				showing[#showing + 1] = frame
			end
		end
	end
	return showing
end

-- A frame of `form` not in use, made if none is. The column's take the pointer: on one, its clock stands still, and a
-- click sends it away (ANN-R20).
---@param form PagleAnnouncementForm
---@return PagleAnnouncementFrame
local function acquire(form)
	for _, frame in ipairs(made[form]) do
		if not frame.inUse then
			return frame
		end
	end
	local frame = BUILD[form]()
	frame.lanes = true
	if form == "toast" or form == "nod" then
		frame:EnableMouse(true)
		frame:SetScript("OnEnter", function(self)
			if self.display then
				ns.lanes:Pause(self.display)
			end
		end)
		frame:SetScript("OnLeave", function(self)
			if self.display then
				ns.lanes:Resume(self.display)
			end
		end)
		frame:SetScript("OnMouseUp", function(self)
			if self.display then
				ns.lanes:Dismiss(self.display)
			end
		end)
	end
	made[form][#made[form] + 1] = frame
	return frame
end

-- Puts a column frame `y` above the column's foot; a toast.high hangs its bookmark below that.
---@param frame PagleAnnouncementFrame
---@param y number
local function placeAt(frame, y)
	frame.slot = y
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, COLUMN_FOOT + y + (frame.ribbon or 0))
end

-- Stacks the column, the newest at its foot; one that moves glides to its place (0.3 s).
local function restack()
	local y = 0
	for _, frame in ipairs(ns.columnFrames) do
		local from, to = frame.slot, y
		if from and from ~= to and ns.MotionOn() then
			ns.Animate(frame, {
				{
					dur = 0.3,
					ease = ns.EASE.out,
					keys = { { 0, { from } }, { 1, { to } } },
					apply = function(v)
						placeAt(frame, v[1])
					end,
				},
			})
		else
			placeAt(frame, to)
		end
		y = y + frame.display.height
	end
end

-- How each form leaves (announcements.md › Motion): a toast or Nod fades out drifting up 12 units, a banner fades and
-- shrinks to 96% about its top.
---@type table<PagleAnnouncementForm, fun(frame: PagleAnnouncementFrame, seconds: number): PagleAnimation[]>
local LEAVING = {
	toast = function(frame, seconds)
		local from, alpha = frame.slot or 0, frame:GetAlpha()
		return {
			{
				dur = seconds,
				ease = EASE_IN,
				keys = { { 0, { 0, alpha } }, { 1, { 12, 0 } } },
				apply = function(v)
					placeAt(frame, from + v[1])
					frame:SetAlpha(v[2])
				end,
			},
		}
	end,
	banner = function(frame, seconds)
		return {
			{
				dur = seconds,
				ease = EASE_IN,
				keys = { { 0, { 1, 1 } }, { 1, { 0, 0.96 } } },
				apply = function(v)
					frame:SetAlpha(v[1])
					-- Its offset scales with it: dividing it out keeps its top where it was.
					frame:SetScale(v[2])
					frame:SetPoint("TOP", UIParent, "TOP", 0, -BANNER_TOP / v[2])
				end,
			},
		}
	end,
}
LEAVING.nod = LEAVING.toast

-- The lanes' show: a frame of its form, drawn and on screen; a toast or Nod at the column's foot, the others moving up.
---@param display PagleDisplay
local function show(display)
	local form = display.form
	local frame = acquire(form)
	frame.inUse, frame.display = true, display
	ns.announcementFrames[form] = frame
	frame:SetAlpha(1)
	frame:SetScale(1)
	if form == "banner" then
		frame:SetPoint("TOP", UIParent, "TOP", 0, -BANNER_TOP)
	end
	if form == "toast" or form == "nod" then
		local page = form == "toast" and ns.ToastPage(display.announcement)
		frame.ribbon = page and page.high and ns.RIBBON_HEIGHT or 0
		frame.slot = nil
		table.insert(ns.columnFrames, 1, frame)
		restack()
	end
	ns.DrawAnnouncement(frame, display)
	frame:Show()
end

-- The frame a display shows in, if any does.
---@param display PagleDisplay
---@return PagleAnnouncementFrame?
local function frameOf(display)
	for _, frame in ipairs(made[display.form]) do
		if frame.display == display then
			return frame
		end
	end
	return nil
end

-- The lanes' hide: the display's frame leaves, its ruler stopped, and the column closes up under it. It goes as its
-- form leaves, then is free again; at once `atOnce` (the combat hold hides what is on screen, ANN-R35), with
-- Animations off, or off screen.
---@param display PagleDisplay
---@param atOnce boolean?
local function hide(display, atOnce)
	local frame = frameOf(display)
	if not frame then
		return
	end
	frame.display, frame.drawnRuler, frame.moved = nil, nil, nil
	ns.StopMotion(frame)
	if frame.ruler then
		frame.ruler:SetScript("OnUpdate", nil)
	end
	for i, entry in ipairs(ns.columnFrames) do
		if entry == frame then
			table.remove(ns.columnFrames, i)
			restack()
			break
		end
	end
	local seconds, leaving = ns.LEAVE_SECONDS[display.form], LEAVING[display.form]
	if atOnce or not (seconds and leaving and ns.MotionOn() and frame:IsVisible()) then
		frame:Hide()
		frame.inUse = false
		return
	end
	ns.Animate(frame, leaving(frame, seconds))
	-- On the clock, so it goes even if nothing draws (a frame drawn again meanwhile stays).
	C_Timer.After(seconds, function()
		if not frame.display then
			ns.StopMotion(frame)
			frame:Hide()
			frame.inUse = false
		end
	end)
end

--- Core's lanes (ANN-R20) on the client: the centre's banner or splash, and the column's toasts and Nods, each on
--- frames of its own, so they show together.
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

--- Holds Announcements for `reason` (ANN-R38): the lanes hold it (ns.lanes:Hold) and the card on screen goes off it
--- unclosed (ns.cards:Hold); cards wait while any reason holds (ANN-R55). The Field guide holds for "guide" while it
--- is open (ONB-R70); a second hold for a reason already holding changes nothing.
---@param reason PagleHoldReason
function ns.HoldAnnouncements(reason)
	ns.lanes:Hold(reason)
	ns.cards:Hold()
end

--- Ends the hold for `reason` (ANN-R38): once no reason holds, what was held shows, then the cards. After "guide"
--- alone it shows at once, toasts as themselves; after a hold combat was part of, as ANN-R36 says. A release for a
--- reason not holding does nothing.
---@param reason PagleHoldReason
function ns.ReleaseAnnouncements(reason)
	ns.lanes:Release(reason)
end

-- The combat hold (ANN-R35, ANN-R36): a restriction holds for "combat"; its end starts the wait after which the
-- lanes show what they held, then the cards. A load while restricted (a /reload in combat) starts held:
-- RestrictionChanged never fires for the starting state (CORE-R30).
if Pagle.IsRestricted() then
	ns.lanes:Hold("combat")
end
Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
	if isRestricted then
		ns.HoldAnnouncements("combat")
	else
		ns.ReleaseAnnouncements("combat")
	end
end)
