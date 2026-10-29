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

-- Stamp slots on a frame: the 4 stamps shown, the "+N" for the rest (ANN-R11) and the "Refresh +N" (REF-R7).
local STAMP_SLOTS = ns.MOMENT_STAMPS + 2
-- Held headlines "While you were fighting" lists, a row each; "+N more" under them counts the rest.
local DIGEST_ROWS = 3
-- Its icon: crossed blades.
local FIGHTING_ICON = "Interface\\Icons\\Ability_DualWield"
-- A banner's top below the screen's (ANN-R20).
local BANNER_TOP = 120
-- A Nod's line at most, and the track of its compact ruler, which the number and the margin follow.
local NOD_WIDTH, COMPACT_TRACK = ns.NOD_WIDTH, 90
-- A Nod's words: its title alone, and a stepped-down catch toast's whole line naming a variety (VAR-R26), whose first
-- half is cut short before it passes.
local NOD_TITLE, NOD_VARIETY_LINE = 300, 400
-- A variety's gem (VAR-R26): its box, the side of its rim and of its fill (each a square turned to a diamond), and
-- the gaps before it and between it and the name; then the gap between the name and the line's second half.
local GEM_BOX, GEM_RIM, GEM_FILL, GEM_GAP, GEM_NAME_GAP, NAME_GAP = 10, 7, 5, 6, 3, 6
-- A Rare or Epic variety Nod's gleam (VAR-R26): a soft glow stretched tall and leaning, swept once across the strip
-- from just past the medallion: its size and lean, when it starts and how long it takes, and its brightest.
local GLEAM_WIDTH, GLEAM_HEIGHT, GLEAM_LEAN = 30, 64, math.rad(-20)
local GLEAM_DELAY, GLEAM_SECONDS, GLEAM_PEAK = 0.1, 0.6, 0.9
local GLEAM_INSET = 14
-- A Rare or Epic variety's toast's gleam (VAR-R26) is the same glow as tall as the page, from where its medallion
-- ends, starting as the page rises into place.
local TOAST_GLEAM_DELAY = 0.7
-- A toast's name line, "{fish} ◆ {variety}", steps its font down to this share of its size to fit (22 of the Name
-- font's 31); if it still doesn't, the variety's name is cut short to a floor of VARIETY_FLOOR units, and only then the
-- fish's, to a floor of FISH_FLOOR (VAR-R28).
local NAME_FLOOR = 0.7
local VARIETY_FLOOR, FISH_FLOOR = 48, 40
-- A composed style's kicker is set this much larger than its kit draws it, as the ledger's grew from 13 to 16 (#467).
local KICKER_SCALE = 16 / 13
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
---@field stampScale number? the New record stamp's scale when the toast's stamp row is squeezed (1: none)
---@field style PagleToastStyle
---@field ruler { old: number, new: number, unit: string, label: string }
---@field elapsed number
---@field lengthUnit PagleLengthUnit

-- A variety's gem (VAR-R26): a rim in the rarity's ink round a fill in its colour, both squares turned 45°.
---@class PagleNodGem: Frame
---@field rim Texture
---@field fill Texture

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
---@field sealFrame Frame? a banner's seal, Prestige frame or crest, which drops in
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
---@field nameParent Frame? a toast's frame its name line's parts are written out on, in the name clip
---@field gem PagleNodGem? a toast's or Nod's gem before the variety's name (VAR-R26)
---@field variety FontString? a toast's or Nod's variety name, in the rarity's ink (VAR-R26)
---@field tail FontString? a Nod's line after the variety's name (VAR-R26)
---@field gleamClip Frame? the part of a Nod's strip or a toast's page its gleam sweeps across (VAR-R26)
---@field gleam PagleSprite? a Rare or Epic variety Nod's or toast's gleam (VAR-R26)
---@field gleams boolean? the Nod or toast drawn gleams as it enters
---@field gleamFrom number? where a toast's gleam starts from the page's left, and how far it travels
---@field gleamAcross number?
---@field bezel PagleBezel?
---@field wax PagleSprite? toast.high's wax
---@field rows PagleDigestRow[]? "While you were fighting"'s
---@field seal PagleSprite? a banner's
---@field sealNumber FontString?
---@field prestige PaglePrestigeFrame? a banner's Prestige frame, in the seal's place (ANN-R83)
---@field crestIcon Texture? a banner's crest good's icon, in the seal's place (VAR-R25)
---@field ribbonArt Texture? a banner's headline art on its seal's ribbon (VAR-R25)
---@field extras Frame? a banner's or the splash's row of labels and Coins
---@field composed boolean? drawn last in a composed toast style (ANN-R82)
---@field toastLayers PagleToastLayers? a composed style's layers (adapter/ToastLayers.lua)
---@field legendCrest PagleLegendCrestFrame? the splash's Legend crest (LED-R153, adapter/LegendCrests.lua)
---@field reload FontString? the splash's "/reload to keep it safe" (ANN-R97)

-- The motion's timeline: the canvas loops each animation over 7 s; in game each plays once.
local TIMELINE = 7
local SLIDE = ns.Bezier(0.2, 1.2, 0.4, 1)
local SLAM = ns.Bezier(0.3, 1.6, 0.5, 1)
local DROP = ns.Bezier(0.3, 1.5, 0.5, 1)
-- A banner's Prestige frame (ANN-R83): drawn at this share of the kit's box (156 × 168 units), its own motion playing
-- once the seal has dropped in (0.09 of the timeline, 0.63 s).
local BANNER_FRAME_SCALE = 0.6
local SEAL_LANDED = 0.09 * TIMELINE

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

-- The Refresh ticket's icon (#466) as an inline texture `height` units tall, the stamp's own copy of the art (a Module
-- reaches none of Core's files, ADR 0001): it leads the "Refresh +N" stamp's words, which Capitals leaves as they are.
local STAMP_TICKET = 14
---@param height integer
---@return string
local function ticketMarkup(height)
	local atlas = ns.ATLASES.Ticket
	local sprite = atlas.sprites.ticket
	return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
		atlas.file,
		height,
		math.floor(height * sprite.w / sprite.h + 0.5),
		atlas.width,
		atlas.height,
		sprite.x,
		sprite.x + sprite.w,
		sprite.y,
		sprite.y + sprite.h
	)
end

-- Fills a frame's stamps from an Announcement: its stamp texts from the `from`th (the first), "+N" for those beyond 4
-- (ANN-R11) and "Refresh +N" for its tickets (REF-R7), each set by `set`. Returns the ones showing, in order, for the
-- frame to place.
---@param frame PagleAnnouncementFrame
---@param announcement PagleAnnouncement
---@param set fun(stamp: PagleStamp, text: string)
---@param from integer?
---@return PagleStamp[]
local function fillStamps(frame, announcement, set, from)
	local showing = {}
	local labels = { unpack(announcement.stamps, from or 1) }
	if announcement.more > 0 then
		labels[#labels + 1] = L.ANNOUNCEMENT_STAMPS_MORE:format(announcement.more)
	end
	if (announcement.tickets or 0) > 0 then
		labels[#labels + 1] = ticketMarkup(STAMP_TICKET)
			.. " "
			.. L.ANNOUNCEMENT_STAMP_REFRESH:format(announcement.tickets)
	end
	for i, stamp in ipairs(frame.stamps) do
		stamp:ClearAllPoints()
		local label = labels[i]
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

-- Room a full ruler keeps at its right for the margin, and how far along its track the landed number stands: the track
-- is 1.1 times the new record long (logic/Announcements.lua's ns.RulerAt).
local RULER_TAIL, RULER_LANDED = 74, 1 / 1.1
-- How far the ruler's label (a size record's band) stands from the toast's bottom edge.
local LABEL_PAD = 8

-- How wide a ruled toast's name line may be: it ends where the landed number stands on a full ruler `rulerWidth` wide,
-- so the number, the margin and the band never sit under the words.
---@param rulerWidth number
---@return number
local function rulerNameLimit(rulerWidth)
	return math.floor(math.max(60, rulerWidth - RULER_TAIL) * RULER_LANDED) - 6
end

-- Lays a full ruler `width` wide: the track from its left, room for the margin at the right, and its label (a size
-- record's band, "Tiddler") in the toast's bottom left corner, `x` from the left of `body`, the toast's body, under the
-- ruler's row rather than beside the track.
---@param ruler PagleRulerView
---@param width number
---@param label string
---@param body Frame
---@param x number
local function layRuler(ruler, width, label, body, x)
	ruler:SetSize(width, 28)
	ruler.label:SetText(ns.Capitals(label))
	ruler.label:ClearAllPoints()
	ruler.label:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", x, LABEL_PAD)
	local trackWidth = math.max(60, width - RULER_TAIL)
	ruler.trackWidth = trackWidth
	ruler.bar:ClearAllPoints()
	ruler.bar:SetPoint("TOPLEFT", ruler, "TOPLEFT", 0, -16)
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
		ns.SetStamp(ruler.record, L.ANNOUNCEMENT_NEW_RECORD, ruler.style, nil, ruler.stampScale)
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

-- A toast's or Nod's font: the art's font key, or a composed style's ink (ANN-R82: its face, size and shadow).
---@alias PagleWordsFont string|PagleToastInk

-- The heights a toast's kicker and name line measure at their fonts' own sizes (a font's line is taller than its size).
---@class PagleWordsHeights
---@field kicker number
---@field name number

---@param fontString FontString
---@param font PagleWordsFont
local function setFont(fontString, font)
	if type(font) == "table" then
		ns.SetInkFont(fontString, font)
	else
		ns.SetArtFont(fontString, font --[[@as string]])
	end
end

---@param font PagleWordsFont
---@return number
local function fontSize(font)
	return type(font) == "table" and font.size or ns.ArtFontSize(font --[[@as string]])
end

-- A printed title as a font sets it: in capitals, as the art prints them, unless a composed style's ink sets it as
-- written (its small caps are the face's own).
---@param font PagleWordsFont
---@param text string
---@return string
local function printed(font, text)
	return (type(font) ~= "table" or font.caps) and ns.Capitals(text) or text
end

-- ns.ShrinkToFit for either kind of font.
---@param fontString FontString
---@param font PagleWordsFont
---@param width number
local function shrink(fontString, font, width)
	if type(font) ~= "table" then
		ns.ShrinkToFit(fontString, font --[[@as string]], width)
		return
	end
	fontString:SetWidth(0)
	local natural = fontString:GetStringWidth()
	if natural > width then
		ns.SetInkFont(fontString, font, math.max(math.ceil(font.size * 0.7), math.floor(font.size * width / natural)))
	end
	fontString:SetWidth(math.min(fontString:GetStringWidth(), width))
end

-- A toast's or Nod's font at `size` units, as the art's font `key` or a composed style's ink.
---@param fontString FontString
---@param font PagleWordsFont
---@param size number
local function setFontAt(fontString, font, size)
	if type(font) == "table" then
		ns.SetInkFont(fontString, font, size)
	else
		local key = font --[[@as string]]
		ns.SetArtFontScaled(fontString, key, size / ns.ArtFontSize(key))
	end
end

-- The headline's words at `x`, `y` from the frame's top left: its title printed in capitals, its text under it in the
-- Angler's hand; or, with no text, the title alone in the hand. Each is held to `width`, the hand shrinking to fit
-- first. `fonts` and `inks` give the printed and handwritten fonts and inks. Returns the heights the kicker and the name
-- line measure at their fonts' own sizes, before any shrink or step down (a toast's words are placed by them, see
-- blockTop), or nothing for a title alone.
---@param frame PagleAnnouncementFrame
---@param headline { title: string, text: string? }
---@param fonts { what: PagleWordsFont, name: PagleWordsFont }
---@param inks { what: string, name: string }
---@param width number
---@return PagleWordsHeights?
local function writeHeadline(frame, headline, fonts, inks, width)
	local title, text = frame.title, frame.text
	if headline.text then
		setFont(title, fonts.what)
		ns.Ink(title, inks.what)
		title:SetText(printed(fonts.what, headline.title))
		local kicker = title:GetStringHeight()
		fit(title, width)
		setFont(text, fonts.name)
		ns.Ink(text, inks.name)
		text:SetText(headline.text)
		local name = text:GetStringHeight()
		shrink(text, fonts.name, width)
		text:Show()
		return { kicker = kicker, name = name }
	else
		setFont(title, fonts.name)
		ns.Ink(title, inks.name)
		title:SetText(headline.title)
		shrink(title, fonts.name, width)
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
		ns.SetBezel(row.bezel, 22, ns.BezelRing(style, 22), textureOf(moment.icon))
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

-- A gem on `parent` for a variety's name (VAR-R26): a rim in the rarity's ink round a fill in its colour, hidden until
-- one is written.
---@param parent Frame
---@return PagleNodGem
local function newGem(parent)
	local gem = CreateFrame("Frame", nil, parent) --[[@as PagleNodGem]]
	gem:SetSize(GEM_BOX, GEM_BOX)
	gem.rim = gem:CreateTexture(nil, "OVERLAY", nil, 0)
	gem.fill = gem:CreateTexture(nil, "OVERLAY", nil, 1)
	for texture, side in pairs({ [gem.rim] = GEM_RIM, [gem.fill] = GEM_FILL }) do
		texture:SetSize(side, side)
		texture:SetPoint("CENTER")
		texture:SetRotation(math.rad(45))
	end
	gem:Hide()
	return gem
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
	frame.nameParent = nameParent
	frame.text = ns.ArtText(nameParent, "Name")
	frame.stamps = {}
	for i = 1, STAMP_SLOTS do
		frame.stamps[i] = ns.NewStamp(frame.words)
	end
	frame.coins = newCoins(frame.words, coinsFont)
end

-- Sets a headline's medallion: `art` cropped to the fish's head when it has one (a variety's, VAR-R25; the headline's
-- own unless the toast announces a variety on another moment's, VAR-R26), else its icon.
---@param bezel PagleBezel
---@param size integer
---@param ring PagleBezelRing
---@param headline PagleRaisedMoment
---@param art PagleMomentArt?
---@param backing number[]? the disc behind art (ns.ArtBacking): its look's, else the plain one
local function setMedallion(bezel, size, ring, headline, art, backing)
	art = art or headline.art
	if art then
		ns.SetBezel(bezel, size, ring, art.texture, { ns.HeadCrop(art) }, backing or ns.ArtBacking())
	else
		ns.SetBezel(bezel, size, ring, textureOf(headline.icon))
	end
end

-- Tints toast.high's wax as its style has it (ANN-R81): over its grey, or shaded, or, with no tint, its own red.
---@param wax PagleSprite
---@param style PagleToastStyle
local function tintWax(wax, style)
	local tint = style.wax and ns.ANNOUNCE_COLORS[style.wax] or { 1, 1, 1 }
	wax:SetDesaturated(style.waxDesaturated == true)
	wax:SetVertexColor(tint[1], tint[2], tint[3])
end

-- A composed style's medallion (ANN-R82): its ring and gloss are the style's layers, so only the icon shows here,
-- `size` across, `art` or else a headline's art cropped to the fish's head, or its icon, or `icon`.
---@param bezel PagleBezel
---@param size number
---@param headline PagleRaisedMoment?
---@param icon (integer|string)?
---@param art PagleMomentArt?
---@param backing number[]? the disc behind art (ns.ArtBacking): its look's, else the plain one
local function setComposedMedallion(bezel, size, headline, icon, art, backing)
	bezel:SetSize(size, size)
	bezel.Ring:Hide()
	bezel.Gloss:Hide()
	bezel.Icon:SetSize(size, size)
	art = art or headline and headline.art
	ns.SetBezelBacking(bezel, size, art and (backing or ns.ArtBacking()) or nil)
	if art then
		bezel.Icon:SetTexture(art.texture)
		bezel.Icon:SetTexCoord(ns.HeadCrop(art))
	else
		bezel.Icon:SetTexture(icon or textureOf((headline --[[@as PagleRaisedMoment]]).icon))
		bezel.Icon:SetTexCoord(ns.ICON_CROP, 1 - ns.ICON_CROP, ns.ICON_CROP, 1 - ns.ICON_CROP)
	end
end

-- A font string a composed style inked, back in its art font (the Coins' label is set only when its frame is made).
---@param fontString FontString
local function restoreFont(fontString)
	local art = fontString --[[@as PagleArtFontString]]
	if art.inked and art.artKey then
		ns.SetArtFont(fontString, art.artKey)
	end
end

-- The brass coin's side inside its box on a composed rung: the canvas turns it 8°, so its box is its side times
-- cos 8° + sin 8°.
local COIN_TURN = math.cos(math.rad(8)) + math.sin(math.rad(8))

-- Tints a medallion's ring in `color` (a variety's rarity, VAR-R26), its metal greyed first so the colour shows true;
-- or, with none, leaves it the style's own.
---@param bezel PagleBezel
---@param color number[]?
local function tintRing(bezel, color)
	local ring = bezel.Ring
	ring:SetDesaturated(color ~= nil)
	if color then
		ring:SetVertexColor(color[1], color[2], color[3])
	else
		ring:SetVertexColor(1, 1, 1)
	end
end

-- Writes a toast's name line when the toast announces a variety on it (VAR-R26, ANN-R80): the line's first half (the
-- fish's name) in the style's ink `ink`, then a gem in the rarity's colour rimmed in its ink and the variety's name in
-- its ink (the rarity replaces the style's ink there alone). The fish's name has priority over the variety's: when the
-- whole line is wider than `width`, its font first steps down a unit at a time to NAME_FLOOR of its size; if it still
-- doesn't fit, the variety's name is cut short with "..." (to VARIETY_FLOOR at least), and only then the fish's. The
-- gem grows and shrinks with the font. Hides the gem and name for a toast with no such line. Returns the line's width,
-- nil for none.
---@param frame PagleAnnouncementFrame
---@param look PagleToastVarietyLook?
---@param font PagleWordsFont the name line's
---@param ink string the style's name ink, a role in ns.ANNOUNCE_COLORS
---@param width number
---@return number?
local function writeToastVariety(frame, look, font, ink, width)
	local text = frame.text
	local name = frame.variety --[[@as FontString]]
	local gem = frame.gem --[[@as PagleNodGem]]
	if not (look and look.before) then
		gem:Hide()
		name:Hide()
		return nil
	end
	name:SetText(look.name)
	text:SetText(look.before)
	local lead = look.before ~= "" and GEM_GAP or 0
	-- The two names whole at `size`: the fish's width, the gem and its gaps, the variety's width, and the gem's scale
	-- (its 10 units go with NodName's size).
	local function measure(size)
		setFontAt(text, font, size)
		setFontAt(name, font, size)
		text:SetWidth(0)
		name:SetWidth(0)
		local k = size / ns.ArtFontSize("NodName")
		return text:GetStringWidth(), lead + GEM_BOX * k + GEM_NAME_GAP, name:GetStringWidth(), k
	end
	local size, least = fontSize(font), math.ceil(fontSize(font) * NAME_FLOOR)
	local fish, fixed, variety, k = measure(size)
	while fish + fixed + variety > width and size > least do
		size = math.max(least, size - 1)
		fish, fixed, variety, k = measure(size)
	end
	local over = fish + fixed + variety - width
	local varietyWidth = over > 0 and math.max(variety - over, math.min(variety, VARIETY_FLOOR)) or variety
	over = over - (variety - varietyWidth)
	local fishWidth = over > 0 and math.max(fish - over, math.min(fish, FISH_FLOOR)) or fish
	ns.Ink(text, ink)
	name:SetTextColor(look.ink[1], look.ink[2], look.ink[3])
	fit(text, fishWidth)
	fit(name, varietyWidth)
	text:Show()
	gem:SetSize(GEM_BOX * k, GEM_BOX * k)
	gem.rim:SetSize(GEM_RIM * k, GEM_RIM * k)
	gem.fill:SetSize(GEM_FILL * k, GEM_FILL * k)
	gem.rim:SetColorTexture(look.ink[1], look.ink[2], look.ink[3], 1)
	gem.fill:SetColorTexture(look.color[1], look.color[2], look.color[3], 1)
	gem:ClearAllPoints()
	gem:SetPoint("LEFT", text, "RIGHT", lead, 0)
	name:ClearAllPoints()
	name:SetPoint("LEFT", gem, "RIGHT", GEM_NAME_GAP, 0)
	gem:Show()
	name:Show()
	return text:GetWidth() + lead + GEM_BOX * k + GEM_NAME_GAP + name:GetWidth()
end

-- The gap between a toast's kicker and its name line.
local TOAST_LINE_GAP = 5
-- The scales a toast's stamp row is squeezed through, largest first, to fit right of its kicker.
local STAMP_SCALES = { 1, 0.9, 0.8, 0.7 }
-- The gap between a toast's kicker and the stamp row.
local STAMP_KICKER_GAP = 10

-- The smallest a toast's kicker steps down to, to leave its stamp row room: the size it had before #467 (a composed
-- style's own kit size).
local KICKER_FLOOR = 13

-- Sets a toast's stamps, and its New record stamp when a ruled toast has one, at the largest of STAMP_SCALES at which
-- the row, hung right to left from `x` with `gap` between them, still ends right of the kicker's right edge and a gap
-- (the kicker starting `left` from the body's left): the stamps' words and padding shrink together. If the row at the
-- smallest scale still reaches the kicker (the larger 16 kicker of a size band and length, "TROPHY · 123.4 CM", beside
-- a second stamp, or the New record stamp), the kicker's font steps down a unit at a time to `kicker.floor`, the size
-- it had before #467, and the row is fitted again at each, `placeBlock` setting the words' block again for the
-- kicker's new height. At that floor it stays as it is, which only a row of four or more can need. `set` sets a
-- stamp, `setRecord` the New record stamp, each at a scale. Returns the stamps showing and the New record stamp's
-- width.
---@param frame PagleAnnouncementFrame
---@param announcement PagleAnnouncement
---@param set fun(stamp: PagleStamp, text: string, scale: number)
---@param setRecord fun(scale: number)
---@param x number
---@param gap number
---@param left number
---@param withRecord boolean
---@param kicker { font: PagleWordsFont, floor: number, ink: string }
---@param placeBlock fun()
---@return PagleStamp[]
---@return number
local function setStampRow(frame, announcement, set, setRecord, x, gap, left, withRecord, kicker, placeBlock)
	local ruler = frame.ruler --[[@as PagleRulerView]]
	local stamps
	local size = fontSize(kicker.font)
	while true do
		local limit = left + frame.title:GetWidth() + STAMP_KICKER_GAP
		local fits
		for _, scale in ipairs(STAMP_SCALES) do
			stamps = fillStamps(frame, announcement, function(stamp, text)
				set(stamp, text, scale)
			end)
			setRecord(scale)
			ruler.stampScale = scale
			local total = withRecord and ruler.record:GetWidth() + gap or 0
			for _, stamp in ipairs(stamps) do
				total = total + stamp:GetWidth() + gap
			end
			fits = x - (total - gap) >= limit
			if fits then
				break
			end
		end
		if fits or size <= kicker.floor then
			break
		end
		size = math.max(kicker.floor, size - 1)
		setFontAt(frame.title, kicker.font, size)
		ns.Ink(frame.title, kicker.ink)
		fit(frame.title, math.huge)
		placeBlock()
	end
	return stamps, ruler.record:GetWidth()
end

-- Where a toast's kicker and name block is laid down its page: `top`, the page's own, if it is ruled or the digest's,
-- else centred, as the medallion is. The block is the kicker, the gap and the name line, or the name line alone for a
-- headline with no text, as the font strings measure after they are written (not by their fonts' nominal sizes: a
-- font's line is taller than its size). Returns the block's top as it is written, and the kicker's top: the same on a
-- ruled page, but on a centred one the block centred as it would be with the name line at its font's own size and the
-- kicker at its own, `natural`'s, so that the kicker stays where it is whether the name line stepped down to fit its
-- width or the kicker stepped down for the stamps, and clear of the page's ruling line (the name line stays where the
-- block as written puts it, a little below the kicker then).
---@param page { h: number, ruled: boolean? }
---@param frame PagleAnnouncementFrame
---@param headline { text: string? }
---@param top number
---@param fighting PagleRaisedMoment[]?
---@param natural PagleWordsHeights?
---@return number block
---@return number kicker
local function blockTop(page, frame, headline, top, fighting, natural)
	if page.ruled or fighting then
		return top, top
	end
	local block = frame.title:GetStringHeight()
	if not headline.text then
		local laid = (page.h - block) / 2
		return laid, laid
	end
	local line = frame.text
	local height = line:GetStringHeight()
	local variety = frame.variety --[[@as FontString]]
	if variety:IsShown() then
		height = math.max(height, variety:GetStringHeight())
	end
	block = block + TOAST_LINE_GAP + height
	local laid = (page.h - block) / 2
	if not natural then
		return laid, laid
	end
	return laid, math.min(laid, (page.h - (natural.kicker + TOAST_LINE_GAP + natural.name)) / 2)
end

-- Places a toast's kicker and its name line by blockTop: the kicker's top left at `x` and the kicker's top, the name
-- line under it, the same gap below the block's own kicker as ever, or lower by what the kicker is lifted above it.
---@param frame PagleAnnouncementFrame
---@param body Frame
---@param x number
---@param page { h: number, ruled: boolean? }
---@param headline { text: string? }
---@param top number
---@param fighting PagleRaisedMoment[]?
---@param natural PagleWordsHeights?
local function placeWords(frame, body, x, page, headline, top, fighting, natural)
	local laid, kicker = blockTop(page, frame, headline, top, fighting, natural)
	frame.title:ClearAllPoints()
	frame.title:SetPoint("TOPLEFT", body, "TOPLEFT", x, -kicker)
	frame.text:ClearAllPoints()
	frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -(TOAST_LINE_GAP + laid - kicker))
end

-- Readies a toast's gleam for `look` (VAR-R26): unseen, and swept as the toast enters when the variety is Rare or Epic,
-- in the rarity's colour, across the page from just past its medallion.
---@param frame PagleAnnouncementFrame
---@param look PagleToastVarietyLook?
---@param page PagleToastPage
local function readyToastGleam(frame, look, page)
	local gleam = frame.gleam --[[@as PagleSprite]]
	gleam:SetAlpha(0)
	frame.gleams = look ~= nil and look.gleam
	if look and look.gleam then
		local from = page.bx + page.bezel - GLEAM_WIDTH / 2
		gleam:SetSize(GLEAM_WIDTH, page.h)
		gleam:SetVertexColor(look.color[1], look.color[2], look.color[3])
		frame.gleamFrom, frame.gleamAcross = from, page.w - from
	end
end

-- A composed style's kicker ink, set KICKER_SCALE larger than its kit's (the same face), or nil for a style with none.
---@param ink PagleToastInk?
---@return PagleToastInk?
local function kickerInk(ink)
	if not ink then
		return nil
	end
	local larger = {}
	for key, value in pairs(ink) do
		larger[key] = value
	end
	larger.size = math.floor(ink.size * KICKER_SCALE + 0.5)
	return larger
end

-- Draws a toast in a composed style (ANN-R82): its rung's layers (adapter/ToastLayers.lua) for the page, laid as
-- drawToast lays a page but from the rung's boxes fitted to the page (logic/ToastStyles.lua's ns.FitToastBox): the
-- medallion's icon in its box, the words in the text box in the rung's inks, the ruler or held headlines under them,
-- the style's own stamp plates right to left from its stamp's place, and the Coins at the coin's and amount's. No wax:
-- toast.high's seal is the style's art.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
---@param style PagleToastStyle
local function drawComposedToast(frame, display, style)
	local announcement = display.announcement
	local headline = announcement.headline
	local page = ns.ToastPage(announcement)
	local rung = ns.ToastRungArt(style, page) --[[@as PagleToastRung]]
	local body = frame.body --[[@as Frame]]
	local function place(box, centred)
		return ns.FitToastBox(box, rung, page.w, page.h, centred)
	end
	frame.composed = true
	frame:SetSize(page.w, page.h)
	body:SetSize(page.w, page.h)
	frame.page:Hide()
	frame.wax:Hide()
	ns.DrawToastLayers(frame, body, style, page)
	-- A toast announcing a variety shows its art and takes its rarity's colour (VAR-R26).
	local look = not announcement.fighting and ns.ToastVarietyLook(announcement) or nil
	ns.TintToastMedallion(frame, look and look.ring)
	readyToastGleam(frame, look, page)

	local bezel = frame.bezel --[[@as PagleBezel]]
	local icon = place(rung.icon, true)
	if announcement.fighting then
		setComposedMedallion(bezel, icon.w, nil, FIGHTING_ICON)
	else
		setComposedMedallion(bezel, icon.w, headline, nil, look and look.art, look and look.backing)
	end
	bezel:ClearAllPoints()
	bezel:SetPoint("TOPLEFT", body, "TOPLEFT", icon.x, -icon.y)

	-- The words start at the rung's own top on a taller page (a ruled one, the digest's): a text box whose middle is past
	-- the rung's would else ride down with its lower half and leave the ruler no room (fitAxis, for the stamp or the lure).
	local box = place(rung.text)
	box.y = rung.text.y
	local amt = rung.amt and place(rung.amt)
	local width = box.w
	if announcement.coins > 0 and amt then
		width = math.min(width, amt.x - box.x - 4)
	end
	local inks = ns.ToastInks(style, page)
	local fonts = {
		what = kickerInk(ns.ToastInk(style, page, "what")) or "What",
		name = ns.ToastInk(style, page, "name") or "Name",
	}
	-- A ruled toast's name line ends before the ruler's numbers.
	local lineWidth = page.ruled and math.min(width, rulerNameLimit(width - 6)) or width
	frame.text:ClearAllPoints()
	frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -TOAST_LINE_GAP)
	local natural
	if announcement.fighting then
		writeHeadline(frame, { title = headline.title, text = "" }, fonts, inks, width)
		frame.text:Hide()
		drawDigest(frame, announcement.fighting, style, page.w - box.x - 34)
	else
		natural =
			writeHeadline(frame, { title = ns.ToastKicker(headline), text = headline.text }, fonts, inks, lineWidth)
		drawDigest(frame, {}, style, 0)
	end
	local line = writeToastVariety(frame, look, fonts.name, inks.name, lineWidth)
	-- The block is placed once written, by what the words measure (and again if the kicker steps down).
	local function placeBlock()
		placeWords(frame, body, box.x, page, headline, box.y, announcement.fighting, natural)
	end
	placeBlock()
	local clip = frame.nameClip --[[@as Frame]]
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", frame.text, "TOPLEFT", -4, 8)
	clip:SetSize((line or frame.text:GetWidth()) + 8, fontSize(fonts.name) + 22)
	clip:SetShown(frame.text:IsShown())

	local ruler = frame.ruler --[[@as PagleRulerView]]
	ruler.style = style
	ns.Ink(ruler.label, inks.label)
	ns.Ink(ruler.value, inks.value)
	ruler:ClearAllPoints()
	if page.ruled then
		local top = box.y
			+ (frame.text:IsShown() and fontSize(fonts.what) + TOAST_LINE_GAP or 0)
			+ fontSize(fonts.name)
			+ 4
		ruler:SetPoint("TOPLEFT", body, "TOPLEFT", box.x, -top)
		layRuler(ruler, width - 6, headline.ruler.label, body, box.x)
	end

	local more = frame.more --[[@as FontString]]
	local beyond = announcement.fighting and #announcement.fighting - DIGEST_ROWS or 0
	more:SetText(L.ANNOUNCEMENT_MORE:format(beyond))
	more:SetShown(beyond > 0)
	more:ClearAllPoints()
	if page.ruled or announcement.fighting then
		more:SetPoint("BOTTOMLEFT", body, "BOTTOMLEFT", box.x, 6)
	else
		more:SetPoint("TOPLEFT", nameLine(frame), "BOTTOMLEFT", 2, 2)
	end

	-- The stamps hang right to left from the style's stamp's top right, each by its centre from a pivot.
	local spot = place(ns.ToastStampArt(style, page))
	local x, y = spot.x + spot.w, spot.y + spot.h / 2
	local stamps, record = setStampRow(
		frame,
		announcement,
		function(stamp, text, scale)
			ns.SetStamp(stamp, text, style, page, scale)
			ns.TintStamp(stamp, look and look.stamp == text and look.ink or nil)
		end,
		function(scale)
			ns.SetStamp(ruler.record, L.ANNOUNCEMENT_NEW_RECORD, style, page, scale)
		end,
		x,
		2,
		box.x,
		page.ruled == true,
		{
			font = fonts.what,
			floor = (ns.ToastInk(style, page, "what") or { size = KICKER_FLOOR }).size,
			ink = inks.what,
		},
		placeBlock
	)
	local pivots = frame.pivots --[[@as Frame[] ]]
	for i, stamp in ipairs(stamps) do
		local stampWidth = stamp:GetWidth()
		pivots[i]:SetPoint("CENTER", body, "TOPLEFT", x - stampWidth / 2, -y)
		stamp:SetPoint("CENTER", pivots[i], "CENTER")
		x = x - stampWidth - 2
	end
	ruler.record:Hide()
	frame.recordPivot:SetPoint("CENTER", body, "TOPLEFT", x - record / 2, -y)
	ruler.record:ClearAllPoints()
	ruler.record:SetPoint("CENTER", frame.recordPivot, "CENTER")

	-- The Coins: the brass coin centred in the coin's box, the amount ending at the amount's right.
	local coins = frame.coins
	local label = coins.label
	local amtInk = ns.ToastInk(style, page, "amt")
	if amtInk then
		ns.SetInkFont(label, amtInk)
	end
	coins:ClearAllPoints()
	local coin = rung.coin and place(rung.coin)
	local size = coin and coin.w / COIN_TURN or page.coin
	if setCoins(coins, announcement.coins, size, false) > 0 then
		ns.Ink(label, inks.amt)
		if coin then
			coins:SetPoint("RIGHT", body, "TOPLEFT", coin.x + coin.w / 2 + size / 2, -(coin.y + coin.h / 2))
		else
			coins:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, -2)
		end
		if amt then
			label:ClearAllPoints()
			label:SetPoint("RIGHT", body, "TOPLEFT", amt.x + amt.w, -(amt.y + amt.h / 2))
		end
	end
end

-- Draws a toast: its page by rung (logic/ToastStyles.lua's ns.ToastPage), the medallion, the words, the ruler or the
-- held headlines, the stamps right to left from the top right corner, "+N more" and the Coins at the bottom right. A
-- composed style draws its own way (drawComposedToast).
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
---@param style PagleToastStyle
local function drawToast(frame, display, style)
	if style.layered then
		drawComposedToast(frame, display, style)
		return
	end
	-- After a composed style: its layers off, the page back, the Coins' label in its own font.
	if frame.composed then
		frame.composed = nil
		ns.ClearToastLayers(frame)
		frame.page:Show()
		restoreFont(frame.coins.label)
	end
	local announcement = display.announcement
	local headline = announcement.headline
	local page = ns.ToastPage(announcement)
	local body = frame.body --[[@as Frame]]
	frame:SetSize(page.w, page.h)
	body:SetSize(page.w, page.h)
	ns.SetSprite(frame.page, style.atlas, "toast-" .. page.page)
	ns.PlaceSprite(frame.page, body, 0, 0)
	local bezel = frame.bezel --[[@as PagleBezel]]
	local ring = ns.BezelRing(style, page.bezel, page.high)
	-- A toast announcing a variety shows its art and takes its rarity's colour (VAR-R26).
	local look = not announcement.fighting and ns.ToastVarietyLook(announcement) or nil
	if announcement.fighting then
		ns.SetBezel(bezel, page.bezel, ring, FIGHTING_ICON)
	else
		setMedallion(bezel, page.bezel, ring, headline, look and look.art, look and look.backing)
	end
	tintRing(bezel, look and look.ring)
	readyToastGleam(frame, look, page)
	bezel:ClearAllPoints()
	bezel:SetPoint("TOPLEFT", body, "TOPLEFT", page.bx, -(page.h - page.bezel) / 2)

	local width = page.w - page.tx - 34 - (announcement.coins > 0 and 34 or 0)
	local inks = ns.ToastInks(style, page)
	local fonts = { what = "What", name = page.high and "NameHigh" or "Name" }
	-- A ruled toast's name line ends before the ruler's numbers.
	local lineWidth = page.ruled and math.min(width, rulerNameLimit(width - 6)) or width
	frame.text:ClearAllPoints()
	frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -TOAST_LINE_GAP)
	local natural
	if announcement.fighting then
		writeHeadline(frame, { title = headline.title, text = "" }, fonts, inks, width)
		frame.text:Hide()
		drawDigest(frame, announcement.fighting, style, page.w - page.tx - 34)
	else
		natural =
			writeHeadline(frame, { title = ns.ToastKicker(headline), text = headline.text }, fonts, inks, lineWidth)
		drawDigest(frame, {}, style, 0)
	end
	local line = writeToastVariety(frame, look, fonts.name, inks.name, lineWidth)
	-- The block is placed once written, by what the words measure (and again if the kicker steps down).
	local function placeBlock()
		placeWords(frame, body, page.tx, page, headline, page.ty, announcement.fighting, natural)
	end
	placeBlock()
	-- The clip the name is written out in, round the name as written.
	local clip = frame.nameClip --[[@as Frame]]
	clip:ClearAllPoints()
	clip:SetPoint("TOPLEFT", frame.text, "TOPLEFT", -4, 8)
	clip:SetSize((line or frame.text:GetWidth()) + 8, ns.ArtFontSize(fonts.name) + 22)
	clip:SetShown(frame.text:IsShown())

	local ruler = frame.ruler --[[@as PagleRulerView]]
	ruler.style = style
	ns.Ink(ruler.label, inks.label)
	ns.Ink(ruler.value, inks.value)
	ruler:ClearAllPoints()
	if page.ruled then
		local nameSize = ns.ArtFontSize(fonts.name)
		local top = page.ty + (frame.text:IsShown() and ns.ArtFontSize(fonts.what) + TOAST_LINE_GAP or 0) + nameSize + 4
		ruler:SetPoint("TOPLEFT", body, "TOPLEFT", page.tx, -top)
		layRuler(ruler, width - 6, headline.ruler.label, body, page.tx)
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
	tintWax(frame.wax --[[@as PagleSprite]], style)
	local x = page.high and page.w - 96 or page.w - 30
	local drops = { 2, 8, 4, 6, 3, 7 }
	local stamps, record = setStampRow(frame, announcement, function(stamp, text, scale)
		ns.SetStamp(stamp, text, style, nil, scale)
		ns.TintStamp(stamp, look and look.stamp == text and look.ink or nil)
	end, function(scale)
		ns.SetStamp(ruler.record, L.ANNOUNCEMENT_NEW_RECORD, style, nil, scale)
	end, x, 4, page.tx, page.ruled == true, { font = fonts.what, floor = KICKER_FLOOR, ink = inks.what }, placeBlock)
	-- Each stamp hangs by its centre from a pivot, so it slams down about its middle (adapter/Art.lua's ns.Pivot).
	local pivots = frame.pivots --[[@as Frame[] ]]
	for i, stamp in ipairs(stamps) do
		local stampWidth = stamp:GetWidth()
		pivots[i]:SetPoint("CENTER", body, "TOPLEFT", x - stampWidth / 2, -(drops[i] + 13))
		stamp:SetPoint("CENTER", pivots[i], "CENTER")
		x = x - stampWidth - 4
	end
	-- The New record stamp lands to their left once the ruler fills: measured now to hang it by its centre.
	ruler.record:Hide()
	frame.recordPivot:SetPoint("CENTER", body, "TOPLEFT", x - record / 2, -19)
	ruler.record:ClearAllPoints()
	ruler.record:SetPoint("CENTER", frame.recordPivot, "CENTER")

	frame.coins:ClearAllPoints()
	if setCoins(frame.coins, announcement.coins, page.coin, false) > 0 then
		frame.coins:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", -2, -2)
		ns.Ink(frame.coins.label, inks.amt)
	end
end

-- Writes a Nod's line naming its variety (a stepped-down catch toast's, VAR-R26) in the hand: the line's first half
-- in the style's ink, a gem in the rarity's colour rimmed in its ink, the name in the rarity's ink (the rarity
-- replaces the style's ink there alone, ANN-R80), then the second half in the style's ink. The first half is cut
-- short with "..." when the whole line would pass NOD_VARIETY_LINE. The line starts `left` from the frame's left, in `font` and the ink role `ink`.
-- Returns the line's right edge from the frame's left, and its last part.
---@param frame PagleAnnouncementFrame
---@param look PagleNodVarietyLook
---@param ink string
---@param left number
---@param font PagleWordsFont
---@return number
---@return Region
local function writeVariety(frame, look, ink, left, font)
	local title = frame.title
	local name = frame.variety --[[@as FontString]]
	local tail = frame.tail --[[@as FontString]]
	local gem = frame.gem --[[@as PagleNodGem]]
	frame.text:SetText("")
	frame.text:Hide()
	for _, part in ipairs({ title, name, tail }) do
		setFont(part, font)
	end
	ns.Ink(title, ink)
	ns.Ink(tail, ink)
	name:SetTextColor(look.ink[1], look.ink[2], look.ink[3])
	title:SetText(look.before)
	name:SetText(look.name)
	tail:SetText(look.after)
	fit(name, NOD_TITLE)
	fit(tail, NOD_TITLE)
	local rest = GEM_GAP + GEM_BOX + GEM_NAME_GAP + name:GetWidth() + NAME_GAP + tail:GetWidth()
	fit(title, math.max(NOD_VARIETY_LINE - rest, 60))
	gem.rim:SetColorTexture(look.ink[1], look.ink[2], look.ink[3], 1)
	gem.fill:SetColorTexture(look.color[1], look.color[2], look.color[3], 1)
	gem:ClearAllPoints()
	gem:SetPoint("LEFT", title, "RIGHT", GEM_GAP, 0)
	name:ClearAllPoints()
	name:SetPoint("LEFT", gem, "RIGHT", GEM_NAME_GAP, 1)
	tail:ClearAllPoints()
	tail:SetPoint("LEFT", name, "RIGHT", NAME_GAP, -1)
	gem:Show()
	name:Show()
	tail:Show()
	return left + title:GetWidth() + rest, tail
end

-- Draws a Nod: the medallion, then on a torn strip its words, a compact ruler, its stamps and its Coins, in a line
-- the strip is three-sliced to fit. A catch toast stepped down to a Nod reads as its old one line (ANN-R31); one naming
-- a variety writes that line in parts, with the variety's art in the medallion, its ring in the rarity's colour, and
-- for a Rare or Epic one a gleam ready to sweep it (VAR-R26). A composed style (ANN-R82) draws its Nod rung's layers
-- instead of the strip, its body three-sliced to the line, the icon in its icon box, the words from its text box in
-- its inks, and its medallion tinted for a rarity.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
---@param style PagleToastStyle
local function drawNod(frame, display, style)
	local announcement = display.announcement
	local headline = announcement.headline
	local look = ns.CatchToastNodLook(headline)
	-- A catch toast's words are its one line, not its kicker and name (ANN-R13, ANN-R31).
	local words = headline.catchToast and {
		title = headline.nodLine --[[@as string]],
	} or headline
	local bezel = frame.bezel --[[@as PagleBezel]]
	local strip = frame.strip --[[@as PagleThreeSlice]]
	local rung = style.layered and ns.ToastRungArt(style, nil)
	-- Where the line starts, and its fonts.
	local left, fonts = 72, { what = "NodWhat", name = "NodName" }
	if rung then
		frame.composed = true
		for _, slice in ipairs({ strip.left, strip.middle, strip.right }) do
			slice:Hide()
		end
		setComposedMedallion(bezel, rung.icon.w, headline, nil, nil, look and look.backing)
		bezel:ClearAllPoints()
		bezel:SetPoint("TOPLEFT", frame, "TOPLEFT", rung.icon.x, -rung.icon.y)
		left = rung.text.x
		fonts = {
			what = ns.ToastInk(style, nil, "what") or fonts.what,
			name = ns.ToastInk(style, nil, "name") or fonts.name,
		}
		frame.title:SetPoint("LEFT", frame, "LEFT", left, 0)
	else
		-- After a composed style: its layers off, the strip, the medallion and the line back where they were.
		if frame.composed then
			frame.composed = nil
			ns.ClearToastLayers(frame)
			for _, slice in ipairs({ strip.left, strip.middle, strip.right }) do
				slice:Show()
			end
			bezel:ClearAllPoints()
			bezel:SetPoint("LEFT")
			frame.title:SetPoint("LEFT", frame, "LEFT", left, 0)
		end
		setMedallion(bezel, 34, ns.BezelRing(style, 34), headline, nil, look and look.backing)
		tintRing(bezel, look and look.ring)
	end
	local gleam = frame.gleam --[[@as PagleSprite]]
	gleam:SetAlpha(0)
	frame.gleams = false
	if look and look.gleam then
		frame.gleams = true
		gleam:SetVertexColor(look.color[1], look.color[2], look.color[3])
	end
	local x
	---@type Region
	local last
	frame.text:ClearAllPoints()
	if look then
		x, last = writeVariety(frame, look, ns.ToastInks(style).name, left, fonts.name)
	else
		for _, part in ipairs({ frame.gem, frame.variety, frame.tail }) do
			part:Hide()
		end
		writeHeadline(frame, words, fonts, ns.ToastInks(style), NOD_TITLE)
		x = left + frame.title:GetWidth()
		last = frame.title
		if frame.text:IsShown() then
			frame.text:SetPoint("LEFT", frame.title, "RIGHT", 9, 1)
			x = x + 9 + frame.text:GetWidth()
			last = frame.text
		end
	end
	local ruler = frame.ruler --[[@as PagleRulerView]]
	ruler.style = style
	ns.Ink(ruler.value, ns.ToastInks(style).value)
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
	-- A variety's own stamp (VAR-R28) is a toast's, the first: its Nod reads as it always did.
	local stamps = fillStamps(frame, announcement, function(stamp, text)
		ns.SetStamp(stamp, text, style)
	end, headline.ownStamp and 2 or 1)
	for _, stamp in ipairs(stamps) do
		stamp:SetPoint("LEFT", last, "RIGHT", 6, 0)
		x = x + 6 + stamp:GetWidth()
		last = stamp
	end
	frame.coins:ClearAllPoints()
	local coins = setCoins(frame.coins, announcement.coins, 22, true)
	if coins > 0 then
		ns.Ink(frame.coins.label, ns.ToastInks(style).amt)
		frame.coins:SetPoint("LEFT", last, "RIGHT", 9, 0)
		x = x + 9 + coins
	end
	if rung then
		-- The body as long as the line, with the rung's margin after its words.
		local width = math.min(x + rung.w - rung.text.x - rung.text.w, 22 + NOD_WIDTH)
		ns.DrawToastLayers(frame, frame, style, nil, width)
		ns.TintToastMedallion(frame, look and look.ring)
		strip:SetSize(width - 22, 26)
		frame:SetWidth(width)
		return
	end
	local length = math.min(x, NOD_WIDTH)
	ns.SetThreeSlice(strip, style.atlas, "nod-strip", length, 26, "BACKGROUND")
	frame:SetWidth(22 + length)
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

-- Draws a banner: the spaced gilt title, the seal (a number, a mark, the Prestige frame of its rank with the Angler's
-- portrait, ANN-R83, or a crest good's icon in its place, VAR-R25) with the headline's art on its ribbon when it has
-- one, the text in gilt handwriting, then the labels and Coins.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
local function drawBanner(frame, display)
	local announcement = display.announcement
	local headline = announcement.headline
	frame.title:SetText(ns.SpacedCaps(headline.title))
	local seal = ns.BannerSeal(headline)
	local wax = frame.seal --[[@as PagleSprite]]
	local number = frame.sealNumber --[[@as FontString]]
	local prestige = frame.prestige --[[@as PaglePrestigeFrame]]
	local pressed = seal.frame == nil and seal.icon == nil
	wax:SetShown(pressed)
	prestige:SetShown(seal.frame ~= nil)
	frame.crestIcon:SetShown(seal.icon ~= nil)
	number:SetShown(seal.number ~= nil)
	if seal.icon then
		frame.crestIcon:SetTexture(seal.icon)
	elseif seal.frame then
		prestige:SetRank(seal.frame, BANNER_FRAME_SCALE)
		SetPortraitTexture(prestige:GetWell(), "player")
	else
		ns.SetSprite(wax, "Announce", seal.mark and "seal-" .. seal.mark or "seal")
		ns.PlaceSprite(wax, wax:GetParent() --[[@as Frame]], 0, 0)
	end
	if seal.number then
		local digits = BreakUpLargeNumbers(seal.number)
		ns.SetArtFont(number, #digits > 2 and "SealSmall" or "SealNumber")
		number:SetText(digits)
	end
	local art = headline.art
	local ribbon = frame.ribbonArt --[[@as Texture]]
	ribbon:SetShown(art ~= nil)
	if art then
		ribbon:SetTexture(art.texture)
		ribbon:SetTexCoord(art.left, art.right, art.top, art.bottom)
	end
	local y = -29 - 150 - ((seal.frame or seal.icon or art) and 26 or 4)
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

-- Draws the splash: the Legend's own crest (the Unwritten crest for one with none) with its icon in the well, by the
-- headline's `icon`, the Legend's item ID (LED-R153); its title printed over its name on the torn page, the labels and
-- Coins under them.
---@param frame PagleAnnouncementFrame
---@param display PagleDisplay
local function drawSplash(frame, display)
	local announcement = display.announcement
	local headline = announcement.headline
	local crest = frame.legendCrest --[[@as PagleLegendCrestFrame]]
	crest:SetLegend(headline.icon, true)
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
		-- An announced variety's gem and name, on the line the name is written out in (VAR-R26).
		frame.gem = newGem(frame.nameParent --[[@as Frame]])
		frame.variety = ns.ArtText(frame.nameParent, "Name")
		frame.variety:Hide()
		-- Its gleam, on the page under the medallion and the words, clipped to the page.
		local clip = layer(body, 1)
		clip:SetClipsChildren(true)
		frame.gleamClip = clip
		local gleam = ns.ArtSprite(clip, "Announce", "halo", "ARTWORK")
		gleam:SetSize(GLEAM_WIDTH, GLEAM_HEIGHT)
		gleam:SetRotation(GLEAM_LEAN)
		gleam:SetDesaturated(true)
		gleam:SetBlendMode("ADD")
		gleam:SetAlpha(0)
		frame.gleam = gleam
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
		-- A Nod's variety (VAR-R26): the gem, the name and the line after it, hidden until one names a variety.
		frame.gem = newGem(frame.words)
		frame.variety = ns.ArtText(frame.words, "NodName")
		frame.variety:Hide()
		frame.tail = ns.ArtText(frame.words, "NodName")
		frame.tail:Hide()
		-- Its gleam, on the strip past the medallion and under the words, clipped to the strip.
		local clip = CreateFrame("Frame", nil, frame.strip)
		clip:SetPoint("TOPLEFT", frame.strip, "TOPLEFT", GLEAM_INSET, 0)
		clip:SetPoint("BOTTOMRIGHT", frame.strip, "BOTTOMRIGHT")
		clip:SetClipsChildren(true)
		frame.gleamClip = clip
		local gleam = ns.ArtSprite(clip, "Announce", "halo", "ARTWORK")
		gleam:SetSize(GLEAM_WIDTH, GLEAM_HEIGHT)
		gleam:SetRotation(GLEAM_LEAN)
		gleam:SetDesaturated(true)
		gleam:SetBlendMode("ADD")
		gleam:SetAlpha(0)
		frame.gleam = gleam
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
		-- The Prestige frame in the seal's place (ANN-R83), its likeness's centre on the seal's, so it drops in with
		-- the seal and about its middle.
		local prestige = ns.NewPrestigeFrame(centre)
		prestige:SetRank(1, BANNER_FRAME_SCALE)
		local well = ns.PRESTIGE_WELL
		prestige:SetPoint("TOPLEFT", centre, "CENTER", -well.cx * BANNER_FRAME_SCALE, well.cy * BANNER_FRAME_SCALE)
		prestige:Hide()
		frame.prestige = prestige
		-- A crest good's icon in the seal's place (VAR-R25: a fish crest), a shield as the zone crests are.
		frame.crestIcon = centre:CreateTexture(nil, "ARTWORK", nil, 1)
		frame.crestIcon:SetSize(150, 150)
		frame.crestIcon:SetPoint("TOP", centre, "TOP", 0, 20)
		-- The headline's art across the seal's foot, its ribbon (VAR-R25: an Epic variety), 2:1 as the art is.
		frame.ribbonArt = centre:CreateTexture(nil, "ARTWORK", nil, 3)
		frame.ribbonArt:SetSize(132, 66)
		frame.ribbonArt:SetPoint("CENTER", centre, "BOTTOM", 0, 6)
		frame.text = ns.ArtText(frame, "TitleGilt")
		frame.extras = CreateFrame("Frame", nil, frame)
		frame.stamps = {}
		for i = 1, STAMP_SLOTS do
			frame.stamps[i] = newLabel(frame.extras)
		end
		frame.coins = newCoins(frame.extras, "BanAmt")
		return frame
	end,
	-- Full screen for a Legend, until clicked: the screen darkens behind slow rays, the Legend's crest at its full size
	-- holds the item's icon (LED-R153), and a torn page carries its title and name, the crest's plaque over its top.
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
		crest:SetSize(ns.LEGEND_CREST_BOX.w, ns.LEGEND_CREST_BOX.h)
		crest:SetPoint("TOP", frame, "TOP", 0, -70)
		local legendCrest = ns.NewLegendCrest(crest, ns.LEGEND_CREST_BOX.w)
		legendCrest:SetPoint("TOPLEFT")
		frame.legendCrest = legendCrest
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
		-- Always, in Cozy mode too (ANN-R97): a hint to save the Legend's Catch, not a button, as ReloadUI() is
		-- protected.
		frame.reload = ns.ArtText(frame, "SplashReload")
		frame.reload:SetPoint("BOTTOM", hint, "TOP", 0, 14)
		frame.reload:SetText(L.ANNOUNCEMENT_SPLASH_RELOAD)
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
		-- A Rare or Epic variety's gleam sweeps the page once as it rises (VAR-R26), under the words.
		if frame.gleams then
			local gleam = frame.gleam --[[@as PagleSprite]]
			local gleamClip = frame.gleamClip --[[@as Frame]]
			local from, across = frame.gleamFrom or 0, frame.gleamAcross or 0
			animations[#animations + 1] = {
				dur = GLEAM_SECONDS,
				delay = TOAST_GLEAM_DELAY,
				ease = ns.EASE.inOut,
				keys = {
					{ 0, { -GLEAM_WIDTH, 0 } },
					{ 0.5, { (across - GLEAM_WIDTH) / 2, GLEAM_PEAK } },
					{ 1, { across, 0 } },
				},
				apply = function(v)
					gleam:ClearAllPoints()
					gleam:SetPoint("LEFT", gleamClip, "LEFT", from + v[1], 0)
					gleam:SetAlpha(math.max(0, v[2]))
				end,
			}
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
	-- It fades in (0.3 s). A Rare or Epic variety Nod's gleam sweeps across its strip once as it does, left to right,
	-- brightest midway and gone at the far end (VAR-R26); it plays nothing and holds nothing up.
	nod = function(frame)
		local animations = {
			{
				dur = ns.SETTLE_SECONDS.nod,
				ease = ns.EASE.out,
				keys = { { 0, { 0 } }, { 1, { 1 } } },
				apply = function(v)
					frame:SetAlpha(v[1])
				end,
			},
		}
		if frame.gleams then
			local gleam = frame.gleam --[[@as PagleSprite]]
			local clip = frame.gleamClip --[[@as Frame]]
			local across = frame.strip:GetWidth() - GLEAM_INSET
			animations[#animations + 1] = {
				dur = GLEAM_SECONDS,
				delay = GLEAM_DELAY,
				ease = ns.EASE.inOut,
				keys = {
					{ 0, { -GLEAM_WIDTH, 0 } },
					{ 0.5, { (across - GLEAM_WIDTH) / 2, GLEAM_PEAK } },
					{ 1, { across, 0 } },
				},
				apply = function(v)
					gleam:ClearAllPoints()
					gleam:SetPoint("LEFT", clip, "LEFT", v[1], 0)
					gleam:SetAlpha(math.max(0, v[2]))
				end,
			}
		end
		ns.Animate(frame, animations)
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
	-- The rays turn clockwise once a minute for as long as it shows, and the Legend's crest moves (LED-R153).
	splash = function(frame)
		local rays = frame.rays --[[@as PagleSprite]]
		local crest = frame.legendCrest --[[@as PagleLegendCrestFrame]]
		crest:Play()
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
	local form = display.form
	DRAW[form](frame, display, style)
	local motion = MOTION[form]
	if motion and frame.moved ~= display and frame.lanes then
		frame.moved = display
		ns.StopMotion(frame)
		motion(frame)
	end
	-- A composed style's own motion (ANN-R82), beside the form's.
	if style.layered and (form == "toast" or form == "nod") then
		local page = form == "toast" and ns.ToastPage(display.announcement) or nil
		ns.PlayToastLayers(frame, display, style, page, form --[[@as "toast"|"nod"]])
	end
	-- A banner's Prestige frame's own motion, once its seal has dropped in, while the banner holds (ANN-R83).
	local prestige = frame.prestige
	if prestige and prestige:IsShown() and frame.lanes then
		prestige:Play(SEAL_LANDED)
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

-- The Toast column's foot (ANN-R98): one invisible anchor frame on UIParent, at the saved `announcements.point` or by
-- default the middle of the screen's bottom (ANN-R20), that every toast and Nod is anchored to, so a Shift-drag of
-- one moves the anchor and with it the whole column. Unnamed, so the client's layout cache never saves or restores
-- it: `announcements.point` is the one place its position is kept.
local columnAnchor = CreateFrame("Frame", nil, UIParent)
columnAnchor:SetSize(1, 1)
columnAnchor:SetMovable(true)
columnAnchor:SetClampedToScreen(true)
ns.columnAnchor = columnAnchor

---@type table? the toast or Nod whose Shift-drag is moving the column, while one is
local movingColumn
-- The drag that moved the column ends with a mouse-up on the toast or Nod, which mustn't click it away (ANN-R20).
local dragEndsClick = false

--- The Toast column's foot now, in UI units from UIParent's bottom centre (ANN-R98): the saved one, or the default,
--- moved to where a full column fits the screen as it is. The Letter sits there too (ONB-R11).
---@return PagleColumnFoot
function ns.AnnounceColumnFoot()
	local saved = ns.db and ns.db.profile.announcements.point
	return ns.ClampColumnFoot(ns.ColumnFoot(saved), UIParent:GetWidth(), UIParent:GetHeight())
end

-- Puts the anchor at the column's foot (ANN-R98), and keeps it there when the screen changes. Leaves it to the
-- pointer during a drag.
local function placeColumn()
	if movingColumn then
		return
	end
	local foot = ns.AnnounceColumnFoot()
	columnAnchor:ClearAllPoints()
	columnAnchor:SetPoint("BOTTOM", UIParent, "BOTTOM", foot.x, foot.y)
end
UIParent:HookScript("OnSizeChanged", placeColumn)

-- A Shift-drag of `frame`, a toast or Nod, moves the column (ANN-R98): with Shift held and outside restriction, the
-- lanes hold the column (every clock stops, nothing enters or leaves) and the anchor follows the pointer.
---@param frame table
local function startColumnMove(frame)
	if movingColumn or not IsShiftKeyDown() or Pagle.IsRestricted() then
		return
	end
	movingColumn, dragEndsClick = frame, true
	ns.lanes:HoldColumn()
	columnAnchor:StartMoving()
end

-- Ends a move in progress where the column is now: its foot kept, within where a full column fits (ANN-R98), is saved
-- to `announcements.point`, and the lanes let go of the column. Nothing with no move in progress.
local function endColumnMove()
	if not movingColumn then
		return
	end
	movingColumn = nil
	columnAnchor:StopMovingOrSizing()
	local x, bottom = columnAnchor:GetCenter(), columnAnchor:GetBottom()
	if x and bottom then
		local foot = ns.ClampColumnFoot(
			{ x = x - UIParent:GetWidth() / 2, y = bottom },
			UIParent:GetWidth(),
			UIParent:GetHeight()
		)
		ns.db.profile.announcements.point = foot
	end
	placeColumn()
	ns.lanes:ReleaseColumn()
end

--- The Announcements page's Reset (SET-R30, ANN-R98): clears `announcements.point` and puts the column back at the
--- bottom of the screen, the toasts and Nods on screen with it. While restricted it does nothing. True when it did.
---@return boolean
function ns.ResetToastColumn()
	if Pagle.IsRestricted() then
		return false
	end
	ns.db.profile.announcements.point = nil
	placeColumn()
	return true
end
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
-- click sends it away, then runs its headline's `onClick` if it has one (ANN-R20), under securecallfunction so a
-- Module's failure is reported, not raised; a Shift-drag moves the column instead (ANN-R98).
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
		-- Shift with the left button held and dragged moves the whole column (ANN-R98).
		frame:RegisterForDrag("LeftButton")
		frame:SetScript("OnDragStart", function(self)
			startColumnMove(self)
		end)
		frame:SetScript("OnDragStop", function()
			endColumnMove()
		end)
		frame:SetScript("OnMouseDown", function()
			dragEndsClick = false
		end)
		frame:SetScript("OnMouseUp", function(self)
			local display = self.display
			if dragEndsClick then
				dragEndsClick = false
				return
			end
			if display then
				ns.lanes:Dismiss(display)
				local onClick = display.announcement.headline.onClick
				if onClick then
					securecallfunction(onClick)
				end
			end
		end)
	end
	made[form][#made[form] + 1] = frame
	return frame
end

-- Puts a column frame `y` above the column's foot (the anchor); a toast.high hangs its bookmark below that.
---@param frame PagleAnnouncementFrame
---@param y number
local function placeAt(frame, y)
	frame.slot = y
	frame:ClearAllPoints()
	frame:SetPoint("BOTTOM", columnAnchor, "BOTTOM", 0, y + (frame.ribbon or 0))
end

-- Stacks the column, the newest at its foot; one that moves glides to its place (0.3 s).
local function restack()
	placeColumn()
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
	-- ONB-R52, ONB-R53: Core's first-moment notes, adapter/MarginNotes.lua's, looked up when called.
	if ns.NoteAnnouncement then
		securecallfunction(ns.NoteAnnouncement, display, frame)
	end
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
	if movingColumn == frame then
		endColumnMove()
	end
	frame.display, frame.drawnRuler, frame.moved = nil, nil, nil
	ns.StopMotion(frame)
	-- A composed style's layers stop looping as their toast goes (ANN-R82), and the splash's crest as it goes (LED-R153).
	ns.StopToastLayers(frame)
	if frame.legendCrest then
		frame.legendCrest:Stop()
	end
	if frame.ruler then
		frame.ruler:SetScript("OnUpdate", nil)
	end
	-- A banner's Prestige frame stops moving as the banner goes (ANN-R83).
	if frame.prestige then
		frame.prestige:Stop()
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
--- unclosed (ns.cards:Hold); cards wait while any reason holds (ANN-R55); a Shift-drag of the toast column in progress
--- ends where it is and is saved (ANN-R98). The Field guide holds for "guide" while it is open (ONB-R70); a second
--- hold for a reason already holding changes nothing.
---@param reason PagleHoldReason
function ns.HoldAnnouncements(reason)
	ns.lanes:Hold(reason)
	-- Taking the column off screen already ended a move of it (hide); this is for a move whose frames were gone.
	endColumnMove()
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
