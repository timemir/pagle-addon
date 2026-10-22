if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The varieties spread's own widgets (VAR-R24, VAR-R27; core/varieties.md › UI): a variety's row, its art large and
-- the fish crest at the page's foot, drawn from the blocks logic/JournalVarieties.lua makes, in the varieties kit's
-- look (its PagleArtVarieties/Varieties.lua: the rows with their dotted rules, the rarity pills, the crest and its
-- words over a rule). An uncaught variety's art is only ever drawn as its silhouette: desaturated and tinted black at
-- 28%, a soft shadow of the fish.

local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB

-- Where Core keeps a fish crest's texture, and its good's ID (VAR-R12): the crest is drawn from its texture whether
-- or not Core has registered its good yet; its name only once it has.
local FISH_CREST_ICON = "Interface\\AddOns\\Pagle\\media\\crests\\fish\\%d"
local FISH_CREST_GOOD = "core.crest.fish.%d"

--- A Species' fish crest (VAR-R12, VAR-R24): the icon and name Core cached for its good (Pagle.GetGood), or the
--- crest's own texture and no name while Core has no such good.
---@param speciesID integer
---@return LedgerFishCrest
function ns.FishCrest(speciesID)
	local good = Pagle.GetGood(FISH_CREST_GOOD:format(speciesID))
	return { icon = good and good.icon or FISH_CREST_ICON:format(speciesID), name = good and good.name or nil }
end

--- Shows variety art `art` on `texture` (VAR-R11): in its own colours, or (`look` "silhouette", VAR-R27) desaturated
--- and tinted black at 28%; hidden without art.
---@param texture Texture
---@param art PagleVarietyArt?
---@param look ("silhouette"|"sepia")?
function ns.JournalVarietyArt(texture, art, look)
	texture:SetShown(art ~= nil)
	if not art then
		texture:SetTexture(nil)
		return
	end
	texture:SetTexture(art.texture)
	texture:SetTexCoord(art.left, art.right, art.top, art.bottom)
	if look == "silhouette" then
		texture:SetDesaturated(true)
		texture:SetVertexColor(0, 0, 0, 0.28)
	else
		texture:SetDesaturated(false)
		texture:SetVertexColor(1, 1, 1, 1)
	end
end

-- A row's height (the kit's 41, a little less so the ten fit the left page under its head), the art's size in it, the
-- pill's size and where the pill and the name sit.
local ROW_H, ART_W, ART_H = 38, 76, 38
local PILL_W, PILL_H = 70, 15
local NAME_X, PILL_FROM_RIGHT = 88, 144
-- The words on a filled pill: the parchment's own light.
local PILL_LIGHT = "f8f0dc"

--- A rarity pill (VAR-R24): square-cornered, filled in the rarity's ink when caught, outlined in it when not, its
--- name in small capitals.
---@class LedgerVarietyPill: Frame
---@field fill Texture
---@field edges Texture[]
---@field label FontString

---@param parent Frame
---@return LedgerVarietyPill
local function newPill(parent)
	local pill = CreateFrame("Frame", nil, parent) --[[@as LedgerVarietyPill]]
	pill:SetSize(PILL_W, PILL_H)
	pill.fill = ns.JournalTint(pill, "000000", 1, "ARTWORK", 0)
	pill.fill:SetAllPoints()
	pill.edges = ns.JournalOutline(pill, 0, 0, PILL_W, PILL_H, "000000", 0.75, "ARTWORK")
	pill.label = ns.JournalLabel(pill, "sc", 11, PILL_LIGHT, "", { justify = "CENTER" })
	pill.label:SetPoint("CENTER", 0, 0.5)
	return pill
end

-- Draws `pill` for `rarity`, filled when `filled`.
---@param pill LedgerVarietyPill
---@param rarity LedgerVarietyRarity
---@param filled boolean
local function setPill(pill, rarity, filled)
	local r, g, b = unpack(rarity.ink)
	pill.fill:SetColorTexture(r, g, b, 1)
	pill.fill:SetShown(filled)
	for _, edge in ipairs(pill.edges) do
		edge:SetColorTexture(r, g, b, 0.75)
		edge:SetShown(not filled)
	end
	pill.label:SetText(rarity.name)
	if filled then
		pill.label:SetTextColor(rgb(PILL_LIGHT))
	else
		pill.label:SetTextColor(r, g, b)
	end
end

---@class LedgerVarietyRowView: LedgerJournalWidget
---@field art Texture
---@field name FontString
---@field pill LedgerVarietyPill
---@field count FontString
---@field band Texture
---@field hover Texture
---@field dots LedgerDotLine

-- A variety's row (VAR-R24): its art 76 x 38 at the left, its name (or "Undiscovered" in ghost ink, VAR-R27), its
-- rarity pill and "{count} caught" in the hand at the right, a dotted rule under it; the selected one on a pale band,
-- a faint wash under the mouse. A click opens it on the right page. A variety caught since the page was last drawn has
-- its name written in.
ns.RegisterJournalWidget("variety", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerVarietyRowView]]
	ns.JournalClickable(widget)
	widget.band = ns.JournalTint(widget, "fff0c8", 0.6, "BACKGROUND", 1)
	widget.band:SetAllPoints()
	widget.hover = ns.JournalTint(widget, "784614", 0.08, "BACKGROUND", 0)
	widget.hover:SetAllPoints()
	widget.hover:Hide()
	widget.art = ns.JournalCrisp(widget:CreateTexture(nil, "ARTWORK"))
	widget.art:SetSize(ART_W, ART_H)
	widget.art:SetPoint("LEFT", 2, 0)
	widget.texture = widget.art
	widget.name = ns.JournalLabel(widget, "print", 16, INK.body)
	widget.label = widget.name
	widget.name:SetPoint("LEFT", NAME_X, 0)
	widget.pill = newPill(widget)
	widget.count = ns.JournalLabel(widget, "hand", 17, INK.hand, "", { justify = "RIGHT" })
	widget.count:SetPoint("RIGHT", -6, 0)
	widget.dots = ns.JournalDotLine(widget, INK.rule, 1, 3)
	widget:SetScript("OnEnter", function(self)
		if self.place then
			self.hover:Show()
		end
	end)
	widget:SetScript("OnLeave", function(self)
		self.hover:Hide()
	end)
	function widget.Fill(self, block, width, open, draw)
		self.place, self.open = block.place, open
		local unknown = block.look == "silhouette"
		self.band:SetShown(block.selected == true)
		ns.JournalVarietyArt(self.art, block.art, block.look)
		ns.JournalRestyle(self.name, "print", 16, unknown and INK.ghost or INK.body)
		self.name:SetText(block.text)
		local pillX = width - PILL_FROM_RIGHT
		ns.JournalBound(self.name, math.max(10, pillX - NAME_X - 6))
		self.pill:ClearAllPoints()
		self.pill:SetPoint("LEFT", self, "LEFT", pillX, 0)
		local rarity = block.rarity
		self.pill:SetShown(rarity ~= nil)
		if rarity then
			setPill(self.pill, rarity, block.inked == true)
		end
		self.count:SetShown(block.value ~= nil)
		self.count:SetText(block.value or "")
		ns.JournalBound(self.count, math.max(10, PILL_FROM_RIGHT - PILL_W - 10))
		self.dots:Lay(0, ROW_H - 1, width)
		-- a variety caught since the page was last drawn: its name written in
		local key = block.place and tostring(block.place.args and block.place.args.variety) or block.text or ""
		local same, wasUnknown = ns.JournalRemember(self, draw, "variety:" .. key, unknown)
		if same and wasUnknown and not unknown and ns.MotionOn() then
			ns.JournalSound("write")
			self.name:SetAlpha(0)
			ns.JournalInk(self.name, 0.1)
			ns.JournalInk(self.art, 0.1)
		end
		return ROW_H
	end
	return widget
end)

-- The selected variety's art on the right page (VAR-R24): 340 x 170, centred, and the gap under it.
local LARGE_W, LARGE_H, LARGE_GAP = 340, 170, 6

---@class LedgerVarietyArtWidget: LedgerJournalWidget
---@field art Texture

-- The selected variety's art large (VAR-R24), centred on the page: in its colours, or its silhouette while uncaught
-- (VAR-R27).
ns.RegisterJournalWidget("varietyArt", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerVarietyArtWidget]]
	widget.art = ns.JournalCrisp(widget:CreateTexture(nil, "ARTWORK"))
	widget.texture = widget.art
	function widget.Fill(self, block, width)
		local w = math.min(LARGE_W, width)
		local h = w * LARGE_H / LARGE_W
		self.art:SetSize(w, h)
		self.art:ClearAllPoints()
		self.art:SetPoint("TOP", self, "TOPLEFT", width / 2, -LARGE_GAP)
		ns.JournalVarietyArt(self.art, block.art, block.look)
		return h + 2 * LARGE_GAP
	end
	return widget
end)

-- The fish crest at the foot (VAR-R24): its shield 51 tall, the rule over it, and where its words sit beside it.
local CREST_H, CREST_TOP, WORDS_X = 51, 10, 56

---@class LedgerFishCrestWidget: LedgerJournalWidget
---@field rule Texture
---@field crest Texture
---@field name FontString
---@field toGo FontString

-- The fish crest at the varieties spread's foot (VAR-R24): over a rule, the crest small, cropped to its shield as
-- every crest is drawn (SHOP-R25), its name in small capitals beside it (none before Core has its good) and, in the
-- hand under it, "All ten." or "{n} to go.".
ns.RegisterJournalWidget("fishCrest", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerFishCrestWidget]]
	widget.rule = ns.JournalTint(widget, INK.rule, 1)
	widget.rule:SetHeight(1)
	widget.rule:SetPoint("TOPLEFT")
	widget.rule:SetPoint("TOPRIGHT")
	widget.crest = ns.JournalCrisp(widget:CreateTexture(nil, "ARTWORK"))
	widget.crest:SetSize(CREST_H * 120 / 140, CREST_H)
	-- the shield, 120:140, fills the crest texture's height (SHOP-R25)
	widget.crest:SetTexCoord(0.5 - 60 / 140, 0.5 + 60 / 140, 0, 1)
	ns.JournalAt(widget.crest, widget, 0, CREST_TOP)
	widget.texture = widget.crest
	widget.name = ns.JournalLabel(widget, "sc", 14, INK.kicker)
	widget.label = widget.name
	widget.toGo = ns.JournalLabel(widget, "hand", 20, INK.hand, "", { wrap = true })
	function widget.Fill(self, block, width)
		self.crest:SetTexture(block.icon)
		self.name:SetShown(block.text ~= nil)
		self.name:SetText(block.text or "")
		ns.JournalAt(self.name, self, WORDS_X, CREST_TOP + 6)
		ns.JournalBound(self.name, width - WORDS_X)
		self.toGo:SetWidth(width - WORDS_X)
		self.toGo:SetText(block.value or "")
		ns.JournalAt(self.toGo, self, WORDS_X, block.text and CREST_TOP + 24 or CREST_TOP + 14)
		local words = (block.text and 24 or 14) + self.toGo:GetStringHeight()
		return CREST_TOP + math.max(CREST_H, words) + 4
	end
	return widget
end)
