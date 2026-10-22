if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The zone spread's own widgets (LED-R135–R137; ledger.md › UI): Zone Mastery's rank ladder and the list rows of
-- Species, trophy families and Legends, drawn from the blocks logic/JournalZone.lua makes, in the Ledger art kit's
-- look (its LedgerKit.lua: P.Ladder, P.Row), with the kit's moments of change (MOTION.md): the ladder's circle moving
-- to a new rank, a fish logged on its row.

local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB

-- The ladder's rung words and dots, and its height.
local RUNG_SIZE, LADDER_HEIGHT = 15, 24

-- The kit's circle for a rank's words, by the words lowercased.
---@param words string
---@return string?
local function ringOf(words)
	local name = "rank-" .. words:lower():gsub("[^a-z0-9]+", "-")
	return ns.JOURNAL_ATLASES.Parts.sprites[name] and name or nil
end

---@class LedgerLadderRungView
---@field text FontString
---@field ring LedgerSpriteTexture?
---@field dot FontString?

---@class LedgerLadderWidget: LedgerJournalWidget
---@field rungs LedgerLadderRungView[]

-- Zone Mastery's ladder (LED-R135): the ranks side by side in small capitals between dots, those reached inked, the
-- shown one red in the kit's drawn circle, the rest in ghost ink. Drawn again on the same page with a new rank, the
-- new circle settles from 130% (MOTION.md › A zone's rank goes up).
ns.RegisterJournalWidget("ladder", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerLadderWidget]]
	widget.rungs = {}
	local function rungAt(i)
		local rung = widget.rungs[i]
		if not rung then
			rung = { text = ns.JournalLabel(widget, "sc", RUNG_SIZE, INK.ghost, "", { justify = "CENTER" }) }
			if i > 1 then
				rung.dot = ns.JournalLabel(widget, "sc", RUNG_SIZE, INK.rule, ns.L.ZONE_LADDER_SEPARATOR)
			end
			widget.rungs[i] = rung
		end
		return rung
	end
	function widget.Fill(self, block, width, _, draw)
		local list = block.rungs or {}
		local circled
		for i, data in ipairs(list) do
			if data.circled then
				circled = i
			end
		end
		local same, before = ns.JournalRemember(self, draw, "ladder", circled)
		local x = 0
		for i, data in ipairs(list) do
			local rung = rungAt(i)
			if rung.dot then
				rung.dot:ClearAllPoints()
				rung.dot:SetPoint("TOPLEFT", x + 6, -2)
				rung.dot:Show()
				x = x + 6 + 3.4 + 6
			end
			rung.text:SetText(data.text)
			local ringName = data.circled and ringOf(data.text)
			if ringName then
				if not rung.ring then
					rung.ring = ns.JournalSprite(self, "Parts", ringName, "ARTWORK")
				end
				local sprite = ns.JOURNAL_ATLASES.Parts.sprites[ringName]
				local atlas = ns.JOURNAL_ATLASES.Parts
				ns.JournalSetSprite(rung.ring, "Parts", ringName)
				rung.ring:SetSize(sprite.w / atlas.scale, sprite.h / atlas.scale)
				rung.ring.box = sprite.box
				ns.JournalBoxAt(rung.ring, self, x, 0)
				rung.ring:Show()
				rung.text:SetTextColor(rgb(INK.red))
				rung.text:SetWidth(sprite.box[3])
				rung.text:ClearAllPoints()
				rung.text:SetPoint("TOPLEFT", x, -2)
				local ring = rung.ring --[[@as LedgerSpriteTexture]]
				Pagle.StopMotion(ring)
				if same and before ~= nil and before ~= i and ns.MotionOn() then
					-- the new circle settles from 130% (0.35 s from 0.2 s)
					local w0, h0 = ring:GetSize()
					local cx, cy = x + sprite.box[3] / 2, sprite.box[4] / 2
					Pagle.Animate(ring, {
						{
							dur = 0.35,
							delay = 0.2,
							ease = Pagle.Bezier(0.3, 1.4, 0.5, 1),
							keys = { { 0, { 1.3, 0 } }, { 0.3, { 1.15, 1 } }, { 1, { 1, 1 } } },
							apply = function(v)
								ring:SetSize(w0 * v[1], h0 * v[1])
								ring:SetAlpha(v[2])
								ring:ClearAllPoints()
								ring:SetPoint("CENTER", self, "TOPLEFT", cx, -cy)
							end,
						},
					})
				end
				x = x + sprite.box[3]
			else
				if rung.ring then
					rung.ring:Hide()
				end
				rung.text:SetTextColor(rgb(data.circled and INK.red or data.inked and INK.title or INK.ghost))
				rung.text:SetWidth(0)
				rung.text:ClearAllPoints()
				rung.text:SetPoint("TOPLEFT", x, -2)
				x = x + rung.text:GetStringWidth()
			end
			rung.text:Show()
		end
		for i = #list + 1, #self.rungs do
			self.rungs[i].text:Hide()
			if self.rungs[i].dot then
				self.rungs[i].dot:Hide()
			end
			if self.rungs[i].ring then
				self.rungs[i].ring:Hide()
			end
		end
		self:SetWidth(math.max(1, math.min(width, x)))
		return LADDER_HEIGHT
	end
	return widget
end)

---@class LedgerJournalRowView: LedgerJournalWidget
---@field medal LedgerMedal
---@field name FontString
---@field margin FontString
---@field stars LedgerStarsView
---@field value FontString
---@field wash Texture
---@field hover Texture
---@field dashes Frame?
---@field dashW number?
---@field dashH number?
---@field glow Texture
---@field stamp LedgerRowStamp

--- A row's ink stamp after its words (a Followed Angler's "HC", LED-R151): small capitals in the red ink in a ruled
--- red box, as the kit draws its stamps.
---@class LedgerRowStamp: Frame
---@field label FontString

-- A row's height with a medallion and without (the kit's 32 and 25).
local ROW_H, ROW_H_PLAIN = 32, 25
-- A row stamp's height, and the room round its words.
local STAMP_H, STAMP_PAD = 14, 8

-- A row's stamp on `parent`, hidden: its words and a 1.5-unit red rule round them that follows its size.
---@param parent Frame
---@return LedgerRowStamp
local function newStamp(parent)
	local stamp = CreateFrame("Frame", nil, parent) --[[@as LedgerRowStamp]]
	stamp.label = ns.JournalLabel(stamp, "sc", 11, INK.red, "", { justify = "CENTER" })
	stamp.label:SetPoint("CENTER", 0, 0)
	for _, edge in ipairs({
		{ "TOPLEFT", "TOPRIGHT", nil, 1.5 },
		{ "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1.5 },
		{ "TOPLEFT", "BOTTOMLEFT", 1.5, nil },
		{ "TOPRIGHT", "BOTTOMRIGHT", 1.5, nil },
	}) do
		local rule = ns.JournalTint(stamp, INK.red, 0.85)
		rule:SetPoint(edge[1])
		rule:SetPoint(edge[2])
		if edge[3] then
			rule:SetWidth(edge[3])
		else
			rule:SetHeight(edge[4])
		end
	end
	stamp:Hide()
	return stamp
end

-- A list row (LED-R136, LED-R137, LED-R143, LED-R147, LED-R151): the kit's P.Row. Its medallion (the item's icon
-- round in sepia, or the unknown fish's for what isn't caught, LED-R124), its words (in italic, faded, for what is
-- unknown), its margin notes in the hand at the right, its stars as textures and a value at the right, and a stamp
-- after its words; a faint wash under the mouse; selected, a deeper wash in a dashed outline. A click opens its place.
-- A fish caught since the page was last drawn is logged on its row: the unknown medallion gives way to the fish's
-- own, a green wash swells and fades, and its name is written in with the write sound (MOTION.md › A new fish logged).
ns.RegisterJournalWidget("row", function(parent)
	local widget = ns.NewJournalWidget(parent) --[[@as LedgerJournalRowView]]
	ns.JournalClickable(widget)
	widget.wash = ns.JournalTint(widget, "784614", 0.13, "BACKGROUND", 1)
	widget.wash:SetAllPoints()
	widget.hover = ns.JournalTint(widget, "784614", 0.08, "BACKGROUND", 0)
	widget.hover:SetAllPoints()
	widget.hover:Hide()
	widget.glow = ns.JournalTint(widget, "2a6a2a", 1, "BACKGROUND", 2)
	widget.glow:SetAllPoints()
	widget.glow:SetAlpha(0)
	widget.medal = ns.JournalMedal(widget, 26)
	widget.name = ns.JournalLabel(widget, "print", 15, INK.body)
	widget.label = widget.name
	widget.stamp = newStamp(widget)
	widget.margin = ns.JournalLabel(widget, "hand", 17, INK.note, "", { justify = "RIGHT" })
	widget.stars = ns.JournalStarRow(widget, 12)
	widget.value = ns.JournalLabel(widget, "print", 13.5, INK.small, "", { justify = "RIGHT" })
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
		local icon = block.icon ~= nil
		local h = icon and ROW_H or ROW_H_PLAIN
		local unknown = block.look == "silhouette"
		-- the selection's wash and dashed outline
		self.wash:SetShown(block.selected == true)
		if self.dashes and (self.dashW ~= width or self.dashH ~= h) then
			self.dashes:Hide()
			self.dashes = nil
		end
		if block.selected and not self.dashes then
			self.dashes = ns.JournalDashes(self, 0, 0, width, h, INK.kicker, 1)
			self.dashW, self.dashH = width, h
		end
		if self.dashes then
			self.dashes:SetShown(block.selected == true)
		end
		self.medal:SetShown(icon)
		local left = 5
		if icon then
			ns.JournalSetMedal(self.medal, block.icon, block.look)
			ns.JournalAt(self.medal, self, 5, (h - 26) / 2)
			left = 40
		end
		-- the right: the value, then the stars before it, then the margin before them
		local right = width - 5
		self.value:SetShown(block.value ~= nil)
		if block.value then
			self.value:SetText(block.value)
			-- room for a Followed Angler's "Lv 60 · VIII · 100%" (LED-R151) as for a count
			ns.JournalBound(self.value, math.max(80, (right - left) * 0.45))
			self.value:ClearAllPoints()
			self.value:SetPoint("TOPRIGHT", self, "TOPLEFT", right, -(h - 18) / 2)
			right = right - self.value:GetWidth() - 9
		end
		self.stars:SetShown(block.stars ~= nil)
		if block.stars then
			ns.JournalSetStars(self.stars, block.stars)
			ns.JournalAt(self.stars, self, right - 37.6, (h - 16) / 2)
			right = right - 37.6 - 9
		end
		local margin = block.margin and table.concat(block.margin, ns.L.ZONE_MARGIN_SEPARATOR) or nil
		self.margin:SetShown(margin ~= nil)
		if margin then
			self.margin:SetText(margin)
			ns.JournalBound(self.margin, (right - left) * 0.55)
			self.margin:ClearAllPoints()
			self.margin:SetPoint("TOPRIGHT", self, "TOPLEFT", right, -(h - 22) / 2)
			right = right - self.margin:GetWidth() - 8
		end
		local faded = block.color == "faded"
		ns.JournalRestyle(self.name, faded and "italic" or "print", 15, faded and INK.noteLight or INK.body)
		self.name:SetText(block.text)
		-- the stamp after the words, the words cut short before it when the row is narrow
		local stamp = self.stamp
		stamp:SetShown(block.stamp ~= nil)
		local stampW = 0
		if block.stamp then
			stamp.label:SetText(block.stamp)
			stampW = stamp.label:GetStringWidth() + STAMP_PAD
			stamp:SetSize(stampW, STAMP_H)
		end
		ns.JournalBound(self.name, math.max(10, right - left - (stampW > 0 and stampW + 6 or 0)))
		self.name:ClearAllPoints()
		self.name:SetPoint("TOPLEFT", left, -(h - 19) / 2)
		if block.stamp then
			ns.JournalAt(stamp, self, left + self.name:GetWidth() + 6, (h - STAMP_H) / 2)
		end
		-- a fish logged since the page was last drawn
		local key = block.place and (block.place.id .. ":" .. tostring(block.place.args and block.place.args.species))
			or block.text
			or ""
		local same, wasUnknown = ns.JournalRemember(self, draw, key, unknown)
		Pagle.StopMotion(self)
		self.glow:SetAlpha(0)
		self.name:SetAlpha(1)
		if same and wasUnknown and not unknown and icon and ns.MotionOn() then
			ns.JournalSound("write")
			local medal = self.medal
			Pagle.Animate(self, {
				{
					dur = 0.35,
					delay = 0.1,
					ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
					keys = { { 0, { 1.4, 0 } }, { 0.6, { 0.95, 1 } }, { 1, { 1, 1 } } },
					apply = function(v)
						medal:SetAlpha(v[2])
						medal:SetScale(v[1])
						medal:ClearAllPoints()
						medal:SetPoint("CENTER", self, "TOPLEFT", 18 / v[1], -(h / 2) / v[1])
					end,
				},
				{
					dur = 1.2,
					delay = 0.1,
					ease = Pagle.EASE.inOut,
					keys = { { 0, { 0 } }, { 0.3, { 0.16 } }, { 1, { 0 } } },
					apply = function(v)
						self.glow:SetAlpha(v[1])
					end,
				},
			}, function()
				medal:SetScale(1)
				ns.JournalAt(medal, self, 5, (h - 26) / 2)
			end)
			self.name:SetAlpha(0)
			ns.JournalInk(self.name, 0.3)
		end
		return h
	end
	return widget
end)
