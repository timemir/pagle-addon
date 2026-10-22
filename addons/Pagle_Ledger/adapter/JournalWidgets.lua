if not Pagle then
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Fish Journal's page widgets (ledger.md › UI): one widget per kind of LedgerBlock (logic/Journal.lua), drawn
-- down a page in the Ledger art kit's look (its LedgerKit.lua: kickers and group headings in small capitals, zone
-- tiles, medallions, the ink bar, stamps, seals, the contents' dotted leaders, notes to self in the hand), and the page
-- body they are drawn on, which scrolls with the mouse wheel under an ink scrollbar. A widget drawn again for the same
-- subject (LED-R129) plays the kit's moments of change where its contents moved on (MOTION.md): a count rewritten in
-- ink, the ink bar running on, a stamp pressed on, a fish logged. adapter/JournalZone.lua, JournalCollections.lua and
-- JournalAngler.lua add the kinds only their spreads draw.

local INK = ns.JOURNAL_INK
local rgb = ns.JournalRGB

--- A button that opens a place in the Journal (LED-R125): whoever fills it sets `place` and `open`, the Journal's
--- opener, or `action` to call instead (a link to the Field report, REP-R43).
---@class LedgerJournalClickable: Button
---@field place LedgerJournalPlace?
---@field open fun(place: LedgerJournalPlace)?
---@field action fun()?

--- Makes `button` take clicks as a LedgerJournalClickable: it calls its `action`, or opens its `place`, or with
--- neither does nothing.
---@param button LedgerJournalClickable
function ns.JournalClickable(button)
	---@param self LedgerJournalClickable
	button:SetScript("OnClick", function(self)
		if self.action then
			self.action()
		elseif self.place and self.open then
			self.open(self.place)
		end
	end)
end

--- How a widget is drawn this time, from the page (ns.DrawJournalPage): `same` while the page's subject is the one
--- last drawn (LED-R129), so a change is a moment of change; `group` for a kicker that heads a group rather than a
--- page; `float` for an icon or crest the next blocks sit beside; `center` for words centred under one.
---@class LedgerWidgetDraw
---@field same boolean
---@field first boolean?   -- a title, the page's first
---@field group boolean?
---@field float boolean?
---@field center boolean?

--- A widget drawing one kind of block: `Fill` draws the block across `width` and returns the height it takes;
--- `open` opens a place in the Journal. The kinds that open a place take clicks (ns.JournalClickable). `floatW` and
--- `floatH`, set by a widget drawn as a float, are the room it takes at the page's left.
---@class LedgerJournalWidget: LedgerJournalClickable
---@field Fill fun(self: LedgerJournalWidget, block: LedgerBlock, width: number, open: fun(place: LedgerJournalPlace), draw: LedgerWidgetDraw): number
---@field label FontString?
---@field texture Texture?
---@field floatW number?
---@field floatH number?
---@field lastKey string?   -- what it showed last, for a moment of change on the same subject
---@field lastState any

--- Each block kind's widget maker.
---@type table<string, fun(parent: Frame): LedgerJournalWidget>
local makers = {}

--- Registers `maker` as the widget of block kind `kind`: a spread's own adapter file adds the kinds only it draws.
---@param kind string
---@param maker fun(parent: Frame): LedgerJournalWidget
function ns.RegisterJournalWidget(kind, maker)
	makers[kind] = maker
end

--- A widget of block kind `kind` on `parent`, outside any page: the Field guide's Your Ledger step draws the Angler
--- page's crest with it (ONB-R36, LED-R146).
---@param kind string
---@param parent Frame
---@return LedgerJournalWidget
function ns.NewJournalWidgetOf(kind, parent)
	return makers[kind](parent)
end

-- A widget on `parent`: a Button, so the kinds that open a place take clicks.
---@param parent Frame
---@return LedgerJournalWidget
local function newWidget(parent)
	return CreateFrame("Button", nil, parent) --[[@as LedgerJournalWidget]]
end
ns.NewJournalWidget = newWidget

--- Holds a one-line label within `room`: no text past its page's edge.
---@param label FontString
---@param room number
function ns.JournalBound(label, room)
	label:SetWidth(0)
	label:SetWidth(math.max(1, math.min(label:GetStringWidth() + 1, room)))
end
local bound = ns.JournalBound

--- A figure rewritten in ink: it fades up from 30% (0.3 s), as the kit's moments write a count.
---@param region Region
---@param delay number?
function ns.JournalInk(region, delay)
	Pagle.Animate(region, {
		{
			dur = 0.3,
			delay = delay or 0,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0.3 } }, { 1, { 1 } } },
			apply = function(v)
				region:SetAlpha(v[1])
			end,
		},
	})
end

-- Whether a widget drawn with `key` on the same subject showed the same thing before, so a change in it is a moment;
-- notes `key` and `state` for next time. Returns the state it had.
---@param widget LedgerJournalWidget
---@param draw LedgerWidgetDraw
---@param key string
---@param state any
---@return boolean same
---@return any before
function ns.JournalRemember(widget, draw, key, state)
	local same = draw.same and widget.lastKey == key
	local before = widget.lastState
	widget.lastKey, widget.lastState = key, state
	return same, before
end
local remember = ns.JournalRemember

-- ---------------------------------------------------------------- text

-- The faces and inks a text block is drawn in (the kit's type styles).
---@param block LedgerBlock
---@return LedgerArtFace face
---@return number size
---@return string hex
local function textStyle(block)
	if block.hand then
		if block.color == "red" then
			return "hand", 19, INK.red
		end
		return "hand", 20, INK.hand
	elseif block.color == "faded" then
		return "italic", 13.5, INK.noteLight
	elseif block.color == "red" then
		return "print", 15, INK.red
	elseif block.color == "blue" then
		return "print", 15, INK.hand
	elseif block.style == "italic" then
		-- a variety's words (VAR-R24)
		return "italic", 16, INK.body
	end
	return "print", 15, INK.body
end

-- A kicker: the small capitals over a page's title, in the kicker's ink or the block's own (`ink`: a variety's rarity,
-- VAR-R24); or, heading a group, larger small capitals over a rule with an italic note at the right (`value`: a
-- group's "x / N").
---@class LedgerKickerWidget: LedgerJournalWidget
---@field note FontString
---@field rule Texture

makers.kicker = function(parent)
	local widget = newWidget(parent) --[[@as LedgerKickerWidget]]
	widget.label = ns.JournalLabel(widget, "sc", 14, INK.kicker)
	widget.label:SetPoint("TOPLEFT")
	widget.note = ns.JournalLabel(widget, "italic", 13, INK.noteLight, "", { justify = "RIGHT" })
	widget.note:SetPoint("TOPRIGHT", 0, -2)
	widget.rule = ns.JournalTint(widget, INK.rule, 1)
	widget.rule:SetHeight(1)
	widget.rule:SetPoint("TOPLEFT", 0, -21)
	widget.rule:SetPoint("TOPRIGHT", 0, -21)
	function widget.Fill(self, block, width, _, draw)
		local group = draw.group == true
		ns.JournalRestyle(self.label, "sc", group and 15 or 14, INK.kicker)
		if block.ink then
			self.label:SetTextColor(unpack(block.ink))
		end
		self.label:SetText(block.text)
		self.note:SetText(block.value or "")
		self.note:SetShown(group and block.value ~= nil)
		local noteW = block.value and group and math.min(self.note:GetStringWidth() + 1, width * 0.6) or 0
		self.note:SetWidth(math.max(1, noteW))
		bound(self.label, width - noteW - (noteW > 0 and 8 or 0))
		self.rule:SetShown(group)
		local same, before = remember(self, draw, block.text, block.value)
		if same and before ~= nil and block.value ~= nil and before ~= block.value then
			-- a count ticked over is rewritten in ink (the kit's "3 / 5" to "4 / 5")
			ns.JournalInk(self.note)
		end
		return group and 24 or 17
	end
	return widget
end

-- A title: the print face's large size in the title ink, wrapping; a page's first title larger than its later ones.
makers.title = function(parent)
	local widget = newWidget(parent)
	widget.label = ns.JournalLabel(widget, "print", 27, INK.title, "", { wrap = true, spacing = 1 })
	widget.label:SetPoint("TOPLEFT")
	function widget.Fill(self, block, width, _, draw)
		local size = draw.center and 27 or (draw.first and 29 or 25)
		ns.JournalRestyle(self.label, "print", size, INK.title)
		self.label:SetJustifyH(draw.center and "CENTER" or "LEFT")
		self.label:SetWidth(width)
		self.label:SetText(block.text)
		return math.max(size + 2, self.label:GetStringHeight() + 3)
	end
	return widget
end

-- Text: printed, in the hand (blue, or red for a note that matters), faded italic, wrapping across the width.
makers.text = function(parent)
	local widget = newWidget(parent)
	widget.label = ns.JournalLabel(widget, "print", 15, INK.body, "", { wrap = true, spacing = 5 })
	widget.label:SetPoint("TOPLEFT")
	function widget.Fill(self, block, width, _, draw)
		local face, size, hex = textStyle(block)
		ns.JournalRestyle(self.label, face, size, hex)
		self.label:SetSpacing(block.hand and 2 or 5)
		self.label:SetJustifyH(draw.center and "CENTER" or "LEFT")
		self.label:SetWidth(width)
		self.label:SetText(block.text)
		local same, before = remember(self, draw, "text", block.text)
		if same and before and before ~= block.text then
			ns.JournalInk(self.label)
		end
		return self.label:GetStringHeight() + 2
	end
	return widget
end

-- ---------------------------------------------------------------- links and buttons

---@class LedgerLinkWidget: LedgerJournalWidget
---@field style string?
---@field pen LedgerSpriteTexture
---@field dots LedgerDotLine
---@field radio LedgerSpriteTexture
---@field button LedgerButton
---@field prompt FontString
---@field rule Texture
---@field ink string

-- A link (LED-R125): a note to self in the hand after the blue pencil, turning red under the mouse (LED-R133); a
-- radio in a pick list (`style` "radio", `on` the pick, LED-R146's Signed As); the kit's leather button (`style`
-- "button"); "Help chart the waters" as the kit's chart bar, a rule, its prompt and the button (`style` "chart",
-- LED-R138, LED-R144); else words in the link's red over a dotted underline. It opens its place or calls its action.
makers.link = function(parent)
	local widget = newWidget(parent) --[[@as LedgerLinkWidget]]
	ns.JournalClickable(widget)
	widget.label = ns.JournalLabel(widget, "print", 15, INK.link, "", { wrap = true, spacing = 2 })
	widget.pen = ns.JournalSprite(widget, "Parts", "pen", "ARTWORK")
	widget.radio = ns.JournalSprite(widget, "Parts", "radio-off", "ARTWORK")
	widget.button = ns.JournalButton(widget)
	widget.rule = ns.JournalTint(widget, INK.rule, 1)
	widget.rule:SetHeight(1)
	widget.prompt = ns.JournalLabel(widget, "print", 13.5, INK.small, ns.L.JOURNAL_CHART_PROMPT, { wrap = true })
	widget.dots = ns.JournalDotLine(widget, INK.link, 0.5, 2)
	widget:SetScript("OnEnter", function(self)
		if self.style ~= "button" and self.style ~= "chart" then
			self.label:SetTextColor(rgb(INK.red))
		end
	end)
	widget:SetScript("OnLeave", function(self)
		self.label:SetTextColor(rgb(self.ink or INK.link))
	end)
	function widget.Fill(self, block, width, open)
		self.place, self.action, self.open = block.place, block.action, open
		local style = block.style or (block.hand and "note") or "ink"
		self.style = style
		self.pen:SetShown(style == "note")
		self.radio:SetShown(style == "radio")
		self.button:SetShown(style == "button" or style == "chart")
		self.rule:SetShown(style == "chart")
		self.prompt:SetShown(style == "chart")
		self.label:SetShown(style ~= "button" and style ~= "chart")
		self.dots:Hide()
		self.label:ClearAllPoints()
		if style == "button" or style == "chart" then
			-- the button calls the block's own action, or opens its place
			self.button.action = function()
				if block.action then
					block.action()
				elseif block.place then
					open(block.place)
				end
			end
			self.label:SetText(block.text)
			if style == "button" then
				ns.JournalSetButton(self.button, block.text)
				self.button:ClearAllPoints()
				self.button:SetPoint("TOP", self, "TOPLEFT", width / 2, -2)
				return 38
			end
			-- the chart bar: a rule, "Seen something Pagle doesn't know?" and the button at the right
			self.rule:ClearAllPoints()
			self.rule:SetPoint("TOPLEFT", 0, -4)
			self.rule:SetPoint("TOPRIGHT", 0, -4)
			ns.JournalSetButton(self.button, block.text)
			local buttonW = self.button:GetWidth()
			self.button:ClearAllPoints()
			self.button:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -17)
			self.prompt:SetWidth(math.max(40, width - buttonW - 12))
			self.prompt:ClearAllPoints()
			self.prompt:SetPoint("TOPLEFT", 0, -17)
			return 17 + math.max(36, self.prompt:GetStringHeight())
		end
		local left = 0
		if style == "note" then
			ns.JournalBoxAt(self.pen, self, 0, 5)
			ns.JournalRestyle(self.label, "hand", 21, INK.hand)
			self.ink = INK.hand
			left = 24
		elseif style == "radio" then
			ns.JournalSetSprite(self.radio, "Parts", block.on and "radio-on" or "radio-off")
			ns.JournalBoxAt(self.radio, self, 0, 4.5)
			ns.JournalRestyle(self.label, "print", 15, block.on and INK.title or INK.body)
			self.ink = block.on and INK.title or INK.body
			left = 18
		else
			ns.JournalRestyle(self.label, "print", 14, INK.link)
			self.ink = INK.link
		end
		self.label:SetPoint("TOPLEFT", left, 0)
		self.label:SetWidth(width - left)
		self.label:SetText(block.text)
		local height = self.label:GetStringHeight()
		if style == "ink" then
			-- the dotted underline under a one-line link
			bound(self.label, width)
			self.dots:Lay(0, height + 1, self.label:GetWidth())
			return height + 4
		end
		return math.max(style == "note" and 23 or 19, height + 2)
	end
	return widget
end

---@class LedgerButtonWidget: LedgerJournalWidget
---@field face LedgerButton

-- A button (the Angler page's Prestige, LED-R146): the kit's leather page button, centred on the page, calling the
-- block's `action`.
makers.button = function(parent)
	local widget = newWidget(parent) --[[@as LedgerButtonWidget]]
	widget.face = ns.JournalButton(widget)
	widget.label = widget.face.label
	function widget.Fill(self, block, width)
		self.face.action = block.action
		ns.JournalSetButton(self.face, block.text)
		self.face:ClearAllPoints()
		self.face:SetPoint("TOP", self, "TOPLEFT", width / 2, -4)
		return 42
	end
	return widget
end

---@class LedgerLeaderWidget: LedgerJournalWidget
---@field numeral FontString
---@field value FontString
---@field state FontString
---@field swatch LedgerSpriteTexture
---@field dots LedgerDotLine

-- A contents line (LED-R132): its numeral in small capitals, its words, a dotted leader and its value, the words
-- turning red under the mouse; or a binding's line (LED-R146): its closed book, its name and its state at the right
-- ("In use" in the hand, "Use" and "In the Curio Shop" as ink links calling `action`, "Angler Level {L}" in italic);
-- or with `style` "pair", words and a value with no leader (a hand on the rod, LED-R146). It opens its place or calls
-- its action.
makers.leader = function(parent)
	local widget = newWidget(parent) --[[@as LedgerLeaderWidget]]
	ns.JournalClickable(widget)
	widget.numeral = ns.JournalLabel(widget, "sc", 14, INK.kicker)
	widget.numeral:SetPoint("TOPLEFT", 0, -4)
	widget.label = ns.JournalLabel(widget, "print", 16, INK.body)
	widget.value = ns.JournalLabel(widget, "print", 16, INK.small, "", { justify = "RIGHT" })
	widget.value:SetPoint("TOPRIGHT", 0, -3)
	widget.swatch = ns.JournalSprite(widget, "Bindings", "binding-field-leather", "ARTWORK", 0, 11)
	widget.dots = ns.JournalDotLine(widget, INK.noteLight, 1)
	widget:SetScript("OnEnter", function(self)
		if self.place or self.action then
			self.label:SetTextColor(rgb(INK.hover))
		end
	end)
	widget:SetScript("OnLeave", function(self)
		self.label:SetTextColor(rgb(INK.body))
	end)
	function widget.Fill(self, block, width, open)
		self.place, self.action, self.open = block.place, block.action, open
		local binding = block.binding ~= nil
		local pair = block.style == "pair"
		self.swatch:SetShown(binding)
		self.numeral:SetShown(block.numeral ~= nil)
		self.numeral:SetText(block.numeral or "")
		local left = block.numeral and 28 or (binding and 22 or 0)
		local size = (binding or pair) and 14.5 or 16
		ns.JournalRestyle(self.label, "print", size, INK.body)
		self.label:ClearAllPoints()
		self.label:SetPoint("TOPLEFT", left, -3)
		self.label:SetText(block.text)
		-- the value: a state on a binding's line, a count or a mark on a contents line
		local face, valueSize, hex = "print", size, INK.small
		if binding then
			ns.JournalResprite(self.swatch, block.bindingAtlas or "Bindings", block.binding, 11)
			ns.JournalBoxAt(self.swatch, self, 1, 1)
			if block.state == "inUse" then
				face, valueSize, hex = "hand", 17, INK.green
			elseif block.state == "level" then
				face, valueSize, hex = "italic", 13, INK.note
			else
				face, valueSize, hex = "print", 13, INK.link
			end
		end
		ns.JournalRestyle(self.value, face, valueSize, hex)
		self.value:SetText(block.value or "")
		bound(self.value, width * 0.5)
		local valueW = block.value and self.value:GetWidth() or 0
		bound(self.label, width - left - valueW - 12)
		self.dots:Hide()
		if not binding and not pair then
			local from = left + self.label:GetWidth() + 6
			local to = width - valueW - 6
			if to > from then
				self.dots:Lay(from, 15, to - from)
			end
		end
		return (binding or pair) and 22 or 26
	end
	return widget
end

---@class LedgerXpSourceWidget: LedgerJournalWidget
---@field climb FontString
---@field total FontString
---@field strikes Texture[]

-- The width of each of "Where your XP came from"'s two figure columns, at the line's right.
local XP_COLUMN_W = 84

-- A line of "Where your XP came from" (LED-R150): its source's name, then this climb's XP and all told's in two
-- columns at the right; with `header`, the columns' heads in small capitals; with `off` (its Module is off, AXP-R90),
-- greyed and struck through in red ink, as the Curio Shop's purse strikes a Module that is off.
makers.xpSource = function(parent)
	local widget = newWidget(parent) --[[@as LedgerXpSourceWidget]]
	widget.label = ns.JournalLabel(widget, "print", 14.5, INK.body)
	widget.label:SetPoint("TOPLEFT", 0, -3)
	widget.climb = ns.JournalLabel(widget, "print", 14.5, INK.small, "", { justify = "RIGHT" })
	widget.total = ns.JournalLabel(widget, "print", 14.5, INK.small, "", { justify = "RIGHT" })
	widget.strikes = {}
	for i, region in ipairs({ widget.label, widget.climb, widget.total }) do
		local strike = ns.JournalTint(widget, INK.red, 0.8, "OVERLAY")
		strike:SetHeight(1.5)
		strike:SetPoint("LEFT", region, "LEFT", 0, -1)
		strike:SetPoint("RIGHT", region, "RIGHT", 0, -1)
		widget.strikes[i] = strike
	end
	function widget.Fill(self, block, width, _, draw)
		local header = block.header == true
		local off = block.off == true
		local face, size = "print", 14.5
		if header then
			face, size = "sc", 12.5
		end
		local name = off and INK.faded or INK.body
		local figure = header and INK.kicker or (off and INK.faded or INK.small)
		ns.JournalRestyle(self.label, "print", 14.5, name)
		ns.JournalRestyle(self.climb, face, size, figure)
		ns.JournalRestyle(self.total, face, size, figure)
		self.label:SetText(block.text or "")
		self.climb:SetText(block.value or "")
		self.total:SetText(block.total or "")
		-- the columns from the right: all told at the edge, this climb before it, the name in what is left
		local column = math.min(XP_COLUMN_W, width / 4)
		self.total:ClearAllPoints()
		self.total:SetPoint("TOPRIGHT", self, "TOPLEFT", width, header and -4 or -3)
		self.climb:ClearAllPoints()
		self.climb:SetPoint("TOPRIGHT", self, "TOPLEFT", width - column, header and -4 or -3)
		bound(self.total, column - 6)
		bound(self.climb, column - 6)
		bound(self.label, math.max(1, width - 2 * column - 6))
		for _, strike in ipairs(self.strikes) do
			strike:SetShown(off)
		end
		local same, before = remember(self, draw, "xpSource:" .. (block.text or ""), block.value)
		if same and before and before ~= block.value then
			ns.JournalInk(self.climb)
		end
		return header and 20 or 22
	end
	return widget
end

-- ---------------------------------------------------------------- the bookplate summary

---@class LedgerBookplateWidget: LedgerJournalWidget
---@field numerals FontString
---@field caption FontString
---@field signature FontString
---@field seal LedgerSeal
---@field emblem LedgerSpriteTexture
---@field emblemText FontString
---@field emblemNote FontString
---@field stars LedgerSpriteTexture[]

-- The bookplate's row (LED-R132, LED-R146), as the kit's Home and Angler page: the shown level in large numerals; beside
-- them "Angler Level" in small capitals and the active title in the hand under it; the Prestige emblem, a gilt shield
-- with its numeral and a Master Prestige's stars, with its words at the right (`note`: "Prestige VII", or "No
-- Prestige seals yet" with no emblem); and on Home a wax seal with Ledger completion.
makers.bookplate = function(parent)
	local widget = newWidget(parent) --[[@as LedgerBookplateWidget]]
	widget.numerals = ns.JournalLabel(widget, "print", 56, INK.title)
	widget.numerals:SetPoint("TOPLEFT", 0, -6)
	widget.caption = ns.JournalLabel(widget, "sc", 14, INK.kicker)
	widget.signature = ns.JournalLabel(widget, "hand", 27, INK.hand)
	widget.seal = ns.JournalSeal(widget, 76, 13)
	widget.emblem = ns.JournalSprite(widget, "Parts", "emblem", "ARTWORK", 0, 26)
	widget.emblemText = ns.JournalLabel(widget, "sc", 11.5, INK.brass, "", { justify = "CENTER" })
	widget.emblemText:SetPoint("CENTER", widget.emblem, "CENTER", 0, 1)
	widget.emblemNote = ns.JournalLabel(widget, "italic", 13, INK.note, "", { justify = "RIGHT" })
	widget.stars = {}
	function widget.Fill(self, block, width, _, draw)
		local home = block.seal ~= nil
		local numeralSize = home and 56 or 44
		ns.JournalRestyle(self.numerals, "print", numeralSize, INK.title)
		self.numerals:SetText(block.text)
		local x = self.numerals:GetStringWidth() + 12
		self.caption:ClearAllPoints()
		self.caption:SetPoint("TOPLEFT", x, -(home and 15 or 6))
		self.caption:SetText(block.value or "")
		ns.JournalRestyle(self.signature, "hand", home and 27 or 24, INK.hand)
		self.signature:ClearAllPoints()
		self.signature:SetPoint("TOPLEFT", x, -(home and 31 or 19))
		self.signature:SetText(block.signature or "")
		self.signature:SetShown(block.signature ~= nil)
		-- the right of the row: the seal on Home, the emblem and its words on the Angler page
		local right = width
		self.seal:SetShown(home)
		if home then
			self.seal:ClearAllPoints()
			self.seal:SetPoint("CENTER", self, "TOPLEFT", width - 38, -38)
			ns.JournalSetSeal(self.seal, ns.L.HOME_SEAL_WORD .. "\n" .. block.seal, true)
			right = width - 80
		end
		local mark = block.mark
		local numeral = mark and mark.emblem
		local emblem = numeral ~= nil
		self.emblem:SetShown(emblem)
		self.emblemText:SetShown(emblem)
		self.emblemText:SetText(numeral or "")
		self.emblemNote:SetShown(block.note ~= nil)
		self.emblemNote:SetText(block.note or "")
		bound(self.emblemNote, width * 0.45)
		self.emblemNote:ClearAllPoints()
		self.emblemNote:SetPoint("TOPRIGHT", self, "TOPLEFT", right, -11)
		local noteW = block.note and self.emblemNote:GetWidth() + 8 or 0
		-- a Master Prestige's stars, one per rank past X, in a row under the emblem
		local stars = emblem and mark and mark.stars or 0
		for i = 1, math.max(stars, #self.stars) do
			local star = self.stars[i] or ns.JournalSprite(self, "Parts", "star", "ARTWORK", 0, 10)
			self.stars[i] = star
			star:SetShown(i <= stars)
			ns.JournalBoxAt(star, self, right - noteW - 4 - i * 11, 44)
		end
		if emblem then
			ns.JournalBoxAt(self.emblem, self, right - noteW - 30, 4)
			right = right - noteW - 34
		else
			right = right - noteW
		end
		bound(self.caption, math.max(20, right - x - 4))
		bound(self.signature, math.max(20, right - x - 4))
		local same, before = remember(self, draw, "bookplate", block.text)
		if same and before and before ~= block.text then
			ns.JournalInk(self.numerals)
		end
		return home and 80 or 56
	end
	return widget
end

-- The ink XP bar (LED-R145): the striped ink cut to the climb's progress, Fresh Water's blue stretch ahead of it, and
-- the words under it, Fresh Water's in blue. Drawn again on the same page with more XP, the ink runs on to its new
-- length, the blue moving with it (0.6 s).
---@class LedgerXpBarWidget: LedgerJournalWidget
---@field bar LedgerInkBar
---@field fresh FontString
---@field tip LedgerXpTip?

-- The bar's tooltip (LED-R145): "Where this climb's XP came from", each source's line with this climb's XP at the
-- right (greyed for a Module that is off), and "by source, roughly" under them.
---@param widget LedgerXpBarWidget
local function showXpTip(widget)
	local tip = widget.tip
	if not tip then
		return
	end
	GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
	GameTooltip:SetText(tip.title)
	for _, line in ipairs(tip.lines) do
		local r, g, b = 1, 1, 1
		if line.off then
			r, g, b = 0.5, 0.5, 0.5
		end
		GameTooltip:AddDoubleLine(line.text, line.value, r, g, b, r, g, b)
	end
	GameTooltip:AddLine(tip.note, 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

makers.xpBar = function(parent)
	local widget = newWidget(parent) --[[@as LedgerXpBarWidget]]
	widget:SetScript("OnEnter", showXpTip)
	widget:SetScript("OnLeave", function(self)
		if GameTooltip:IsOwned(self) then
			GameTooltip:Hide()
		end
	end)
	widget.bar = ns.JournalInkBar(widget, 382)
	widget.bar:SetPoint("TOPLEFT")
	widget.label = ns.JournalLabel(widget, "print", 13.5, INK.small)
	widget.label:SetPoint("TOPLEFT", 0, -16)
	widget.fresh = ns.JournalLabel(widget, "print", 13.5, INK.hand)
	widget.fresh:SetPoint("LEFT", widget.label, "RIGHT", 0, 0)
	function widget.Fill(self, block, width, _, draw)
		local data = block.bar --[[@as LedgerInkXpBar]]
		ns.JournalInkBarWidth(self.bar, width)
		local fresh = data.fresh and (data.fresh.to - data.fresh.from) or 0
		local same, before = remember(self, draw, "xp", { data.fill, fresh })
		Pagle.StopMotion(self.bar)
		if same and before and (before[1] ~= data.fill or before[2] ~= fresh) and ns.MotionOn() then
			local p0, f0 = before[1], before[2]
			if data.fill < p0 then
				p0 = 0 -- a level gained: the ink runs on from the bar's start
			end
			Pagle.Animate(self.bar, {
				{
					dur = 0.6,
					ease = Pagle.EASE.out,
					keys = { { 0, { p0, f0 } }, { 1, { data.fill, fresh } } },
					apply = function(v)
						self.bar:Set(v[1], v[2])
					end,
				},
			})
		else
			self.bar:Set(data.fill, fresh)
		end
		self.label:SetText(data.text)
		self.fresh:SetText(data.freshText or "")
		bound(self.label, width)
		bound(self.fresh, math.max(1, width - self.label:GetWidth()))
		-- the tooltip, shown again with the new figures while the mouse is over the bar as it redraws
		self.tip = block.tip
		if GameTooltip:IsOwned(self) then
			if self.tip then
				showXpTip(self)
			else
				GameTooltip:Hide()
			end
		end
		return 36
	end
	return widget
end

-- ---------------------------------------------------------------- marks

---@class LedgerSealWidget: LedgerJournalWidget
---@field seal LedgerSeal

-- A wax seal with its words (LED-R135: a zone's shown rank), at the page's top right beside the title: pressed when
-- `inked`, the empty ring otherwise. It takes no room down the page. Drawn again with a new rank on the same page, the
-- old seal lifts away and the new one is pressed on with the stamp sound (MOTION.md › A zone's rank goes up).
makers.seal = function(parent)
	local widget = newWidget(parent) --[[@as LedgerSealWidget]]
	widget.seal = ns.JournalSeal(widget, 64, 11.5)
	widget.label = widget.seal.label
	function widget.Fill(self, block, width, _, draw)
		local seal = self.seal
		seal:ClearAllPoints()
		seal:SetPoint("CENTER", self:GetParent(), "TOPLEFT", width - 28, -26)
		local same, before = remember(self, draw, "seal", block.text)
		Pagle.StopMotion(seal)
		seal:SetSize(64, 64)
		seal:SetAlpha(1)
		if same and before and before ~= block.text and block.inked and ns.MotionOn() then
			-- the old seal lifts away (grows to 115% and fades, 0.15 s), then the new one is pressed on: 1.8x to 0.94x,
			-- settling at 1x (0.3 s), the stamp sounding as it lands
			Pagle.Animate(seal, {
				{
					dur = 0.15,
					ease = Pagle.Bezier(0.42, 0, 1, 1),
					keys = { { 0, { 1, 1 } }, { 1, { 1.15, 0 } } },
					apply = function(v)
						seal:SetSize(64 * v[1], 64 * v[1])
						seal:SetAlpha(v[2])
					end,
				},
				{
					dur = 0.3,
					delay = 0.15,
					ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
					keys = { { 0, { 1.8, 0 } }, { 0.7, { 0.94, 1 } }, { 1, { 1, 1 } } },
					apply = function(v)
						seal:SetSize(64 * v[1], 64 * v[1])
						seal:SetAlpha(v[2])
					end,
				},
			})
			ns.JournalSetSeal(seal, before, true)
			Pagle.Cue(seal, 0.15, function()
				ns.JournalSetSeal(seal, block.text, true)
			end)
			Pagle.Cue(seal, 0.38, function()
				ns.JournalSound("stamp")
			end)
		else
			ns.JournalSetSeal(seal, block.text, block.inked ~= false)
		end
		return 0
	end
	return widget
end

---@class LedgerStampsWidget: LedgerJournalWidget
---@field stamps LedgerSpriteTexture[]
---@field words FontString[]

-- Ink stamps side by side (★ marks, LED-R140, LED-R143): the kit's stamps, red when inked and in ghost ink when not,
-- tilted as the canvas tilts them. A stamp newly inked on the same page is pressed on, 1.6x to 1x, with the stamp
-- sound (MOTION.md › A trophy weight landed).
makers.stamps = function(parent)
	local widget = newWidget(parent) --[[@as LedgerStampsWidget]]
	widget.stamps, widget.words = {}, {}
	function widget.Fill(self, block, _, _, draw)
		local list = block.stamps or {}
		local inked = {}
		for i, data in ipairs(list) do
			inked[i] = data.inked
		end
		local same, before = remember(self, draw, "stamps:" .. #list .. ":" .. (list[1] and list[1].text or ""), inked)
		local x = 0
		for i, data in ipairs(list) do
			local name = ns.JournalStampSprite(data.text, data.inked)
			local stamp = self.stamps[i]
			if not stamp then
				stamp = ns.JournalSprite(self, "Parts", "stamp-caught", "ARTWORK")
				self.stamps[i] = stamp
				self.words[i] = ns.JournalLabel(self, "sc", 13, INK.red, "", { justify = "CENTER" })
			end
			local words = self.words[i]
			words:SetShown(name == nil)
			stamp:SetShown(name ~= nil)
			local w
			if name then
				local sprite = ns.JOURNAL_ATLASES.Parts.sprites[name]
				local atlas = ns.JOURNAL_ATLASES.Parts
				ns.JournalSetSprite(stamp, "Parts", name)
				stamp.sprite = name
				stamp:SetSize(sprite.w / atlas.scale, sprite.h / atlas.scale)
				stamp.box = sprite.box
				ns.JournalBoxAt(stamp, self, x, 0)
				w = sprite.box[3]
				Pagle.StopMotion(stamp)
				stamp:SetAlpha(1)
				if same and before and data.inked and not before[i] and ns.MotionOn() then
					local w0, h0 = stamp:GetSize()
					local cx, cy = x + sprite.box[3] / 2, sprite.box[4] / 2
					Pagle.Animate(stamp, {
						{
							dur = 0.35,
							delay = 0.2,
							ease = Pagle.Bezier(0.3, 1.6, 0.5, 1),
							keys = { { 0, { 1.6, 0 } }, { 0.7, { 0.95, 1 } }, { 1, { 1, 1 } } },
							apply = function(v)
								stamp:SetSize(w0 * v[1], h0 * v[1])
								stamp:SetAlpha(v[2])
								stamp:ClearAllPoints()
								stamp:SetPoint("CENTER", self, "TOPLEFT", cx, -cy)
							end,
						},
					}, function()
						ns.JournalBoxAt(stamp, self, cx - sprite.box[3] / 2, 0)
					end)
					Pagle.Cue(stamp, 0.45, function()
						ns.JournalSound("stamp")
					end)
				end
			else
				words:SetTextColor(rgb(data.inked and INK.red or INK.ghost))
				words:SetText(data.text)
				words:ClearAllPoints()
				words:SetPoint("TOPLEFT", x, -6)
				w = words:GetStringWidth() + 8
			end
			x = x + w + 10
		end
		for i = #list + 1, #self.stamps do
			self.stamps[i]:Hide()
			self.words[i]:Hide()
		end
		return 30
	end
	return widget
end

---@class LedgerEmblemWidget: LedgerJournalWidget
---@field shield LedgerSpriteTexture
---@field stars LedgerSpriteTexture[]

-- A Prestige emblem on its own line (LED-R34): the gilt shield with its numeral and a Master Prestige's stars.
-- Nothing at all before the first Prestige.
makers.emblem = function(parent)
	local widget = newWidget(parent) --[[@as LedgerEmblemWidget]]
	widget.shield = ns.JournalSprite(widget, "Parts", "emblem", "ARTWORK", 0, 34)
	ns.JournalBoxAt(widget.shield, widget, 0, 0)
	widget.label = ns.JournalLabel(widget, "sc", 15, INK.brass, "", { justify = "CENTER" })
	widget.label:SetPoint("CENTER", widget.shield, "CENTER", 0, 1)
	widget.stars = {}
	function widget.Fill(self, block)
		local mark = block.mark or { stars = 0 }
		local shown = mark.emblem ~= nil
		self.shield:SetShown(shown)
		self.label:SetShown(shown)
		self.label:SetText(mark.emblem or "")
		local stars = shown and mark.stars or 0
		for i = 1, math.max(stars, #self.stars) do
			local star = self.stars[i] or ns.JournalSprite(self, "Parts", "star", "ARTWORK", 0, 12)
			self.stars[i] = star
			ns.JournalBoxAt(star, self, 40 + (i - 1) * 14, 14)
			star:SetShown(i <= stars)
		end
		return shown and 40 or 0
	end
	return widget
end

---@class LedgerRuleWidget: LedgerJournalWidget
---@field rule Frame?
---@field ruleW number?

-- The fleuron rule across the page (the kit's divider between a page's parts).
makers.rule = function(parent)
	local widget = newWidget(parent) --[[@as LedgerRuleWidget]]
	function widget.Fill(self, _, width)
		if not self.rule or self.ruleW ~= width then
			if self.rule then
				self.rule:Hide()
			end
			self.rule = ns.JournalRule(self, 0, 4, width)
			self.ruleW = width
		end
		return 22
	end
	return widget
end

---@class LedgerMapWidget: LedgerJournalWidget
---@field texture LedgerSpriteTexture

-- Uncharted waters' blank chart (LED-R138): the kit's map, a coastline and a compass with no names on it.
makers.map = function(parent)
	local widget = newWidget(parent) --[[@as LedgerMapWidget]]
	widget.texture = ns.JournalSprite(widget, "Parts", "map", "ARTWORK", 0, 380)
	function widget.Fill(self, _, width)
		local w = math.min(380, width)
		local atlas = ns.JOURNAL_ATLASES.Parts
		local sprite = atlas.sprites.map
		local k = w / sprite.box[3]
		self.texture:SetSize(sprite.w / atlas.scale * k, sprite.h / atlas.scale * k)
		self.texture.box = { sprite.box[1] * k, sprite.box[2] * k, w, sprite.box[4] * k }
		ns.JournalBoxAt(self.texture, self, 0, 4)
		return sprite.box[4] * k + 8
	end
	return widget
end

-- ---------------------------------------------------------------- tiles and tabs

--- One zone tile (LED-R131): the paper tile with its name, its rank line, a thin ink bar, a seal at Master and a red
--- note; a charted zone never fished, or one not charted, in a dashed outline instead. It opens its place.
---@class LedgerZoneTileView: LedgerJournalClickable
---@field face LedgerThreeSlice
---@field hover LedgerThreeSlice
---@field dashes Frame?
---@field name FontString
---@field line FontString
---@field line2 FontString
---@field barCase LedgerThreeSlice
---@field barFill Texture
---@field seal Texture
---@field note FontString
---@field tileW number
---@field dashed boolean?

local TILE_H, TILE_GAP, TILE_ROW = 76, 8, 84

---@param parent Frame
---@param width number
---@return LedgerZoneTileView
local function newTile(parent, width)
	local tile = CreateFrame("Button", nil, parent) --[[@as LedgerZoneTileView]]
	ns.JournalClickable(tile)
	tile.tileW = width
	tile:SetSize(width, TILE_H)
	tile.face = ns.JournalThreeSlice(tile, "Parts", "tile", width, 6, "BACKGROUND")
	tile.face:SetPoint("TOPLEFT")
	tile.hover = ns.JournalThreeSlice(tile, "Parts", "tile-hover", width, 6, "BACKGROUND")
	tile.hover:SetPoint("TOPLEFT")
	tile.hover:Hide()
	tile.name = ns.JournalLabel(tile, "print", 15.5, INK.title, "", { wrap = true, spacing = 0.8 })
	tile.name:SetPoint("TOPLEFT", 10, -8)
	tile.line = ns.JournalLabel(tile, "italic", 13, INK.tileInk)
	-- "caught ✓" sits at the right of the line's row, over the bar, so a long zone name never runs under it
	tile.line2 = ns.JournalLabel(tile, "hand", 17, INK.green, "", { justify = "RIGHT" })
	tile.line2:SetPoint("TOPRIGHT", -8, -37)
	tile.barCase = ns.JournalThreeSlice(tile, "Parts", "tbar", width - 20, 3, "ARTWORK")
	ns.JournalAt(tile.barCase, tile, 10, 62)
	tile.barFill = ns.JournalTint(tile, "5a3a14", 1, "ARTWORK", 1)
	tile.barFill:SetHeight(4)
	ns.JournalAt(tile.barFill, tile, 11, 63)
	tile.seal = ns.JournalPiece(tile, "Book", "seal", "ARTWORK", 2)
	tile.seal:SetSize(32, 32)
	tile.seal:SetPoint("CENTER", tile, "TOPLEFT", width - 20, -19)
	tile.seal:SetRotation(math.rad(10))
	tile.note = ns.JournalLabel(tile, "hand", 18, INK.red, "", { justify = "RIGHT" })
	tile.note:SetPoint("TOPRIGHT", -7, -4)
	tile:SetScript("OnEnter", function(self)
		if not self.dashed then
			self.hover:Show()
			self.face:Hide()
		end
	end)
	tile:SetScript("OnLeave", function(self)
		if not self.dashed then
			self.hover:Hide()
			self.face:Show()
		end
	end)
	return tile
end

-- Fills a tile with `data` (LedgerZoneTile).
---@param tile LedgerZoneTileView
---@param data LedgerZoneTile
---@param open fun(place: LedgerJournalPlace)
local function fillTile(tile, data, open)
	local w = tile.tileW
	local dashed = data.bar == nil
	tile.dashed = dashed
	tile.face:SetShown(not dashed)
	tile.hover:Hide()
	if tile.dashes then
		tile.dashes:SetShown(dashed)
	elseif dashed then
		tile.dashes = ns.JournalDashes(tile, 0, 0, w, TILE_H, INK.tileInk, 0.45, "BACKGROUND")
	end
	local mark = data.seal or data.note
	local line2 = data.line2 ~= nil and mark == nil
	ns.JournalRestyle(tile.name, "print", 15.5, dashed and INK.tileInk or INK.title)
	tile.name:SetWidth(w - 20 - (mark and 30 or 0))
	tile.name:SetText(data.name)
	ns.JournalRestyle(tile.line, "italic", 13, dashed and INK.noteLight or INK.tileInk)
	tile.line:ClearAllPoints()
	tile.line:SetPoint("TOPLEFT", 10, -(dashed and 49 or 42))
	tile.line:SetText(data.line or "")
	bound(tile.line, w - 20 - (line2 and 80 or 0))
	tile.barCase:SetShown(not dashed)
	tile.barFill:SetShown(not dashed and (data.bar or 0) > 0)
	tile.barFill:SetWidth(math.max(0.01, (w - 22) * (data.bar or 0)))
	tile.seal:SetShown(data.seal ~= nil)
	-- the red note at the top right, or under the seal at Master
	tile.note:SetShown(data.note ~= nil)
	tile.note:ClearAllPoints()
	tile.note:SetPoint("TOPRIGHT", -7, data.seal and -36 or -4)
	tile.note:SetText(data.note or "")
	tile.line2:SetShown(line2)
	tile.line2:SetText(data.line2 or "")
	tile:SetAlpha(data.faded and 0.85 or 1)
	tile.place, tile.open = data.place, open
	tile:Show()
end

---@class LedgerTilesWidget: LedgerJournalWidget
---@field tiles LedgerZoneTileView[]
---@field tileW number?

-- Zone tiles in a grid (LED-R130, LED-R131, LED-R142): three across on Home, `columns` across where a spread asks.
makers.tiles = function(parent)
	local widget = newWidget(parent) --[[@as LedgerTilesWidget]]
	widget.tiles = {}
	function widget.Fill(self, block, width, open)
		local columns = block.columns or 3
		local tileW = (width - (columns - 1) * TILE_GAP) / columns
		if self.tileW ~= tileW then
			-- a new width: the tiles are made again at it
			for _, tile in ipairs(self.tiles) do
				tile:Hide()
			end
			self.tiles, self.tileW = {}, tileW
		end
		local list = block.tiles or {}
		for i, data in ipairs(list) do
			local tile = self.tiles[i] or newTile(self, tileW)
			self.tiles[i] = tile
			local column, row = (i - 1) % columns, math.floor((i - 1) / columns)
			ns.JournalAt(tile, self, column * (tileW + TILE_GAP), row * TILE_ROW)
			fillTile(tile, data, open)
		end
		for i = #list + 1, #self.tiles do
			self.tiles[i]:Hide()
		end
		local rows = math.ceil(#list / columns)
		return math.max(0, rows * TILE_ROW - TILE_GAP)
	end
	return widget
end

---@class LedgerTabView: LedgerJournalClickable
---@field label FontString
---@field underline Texture

---@class LedgerTabsWidget: LedgerJournalWidget
---@field tabs LedgerTabView[]
---@field rule Texture

-- The continent tabs (LED-R130): small capitals side by side over a rule, the chosen one in the title's ink and
-- underlined in red, the others faded; each opens its place.
makers.tabs = function(parent)
	local widget = newWidget(parent) --[[@as LedgerTabsWidget]]
	widget.tabs = {}
	widget.rule = ns.JournalTint(widget, INK.rule, 1)
	widget.rule:SetHeight(1)
	widget.rule:SetPoint("TOPLEFT", 0, -24)
	widget.rule:SetPoint("TOPRIGHT", 0, -24)
	function widget.Fill(self, block, width, open)
		local x = 0
		for i, data in ipairs(block.tabs or {}) do
			local tab = self.tabs[i]
			if not tab then
				tab = CreateFrame("Button", nil, self) --[[@as LedgerTabView]]
				tab.label = ns.JournalLabel(tab, "sc", 15, INK.noteLight)
				tab.label:SetPoint("TOPLEFT", 0, -2)
				tab.underline = ns.JournalTint(tab, INK.red, 1, "ARTWORK", 1)
				tab.underline:SetHeight(2)
				tab.underline:SetPoint("TOPLEFT", 0, -23)
				tab.underline:SetPoint("TOPRIGHT", 0, -23)
				ns.JournalClickable(tab)
				self.tabs[i] = tab
			end
			tab.label:SetTextColor(rgb(data.on and INK.title or INK.noteLight))
			tab.label:SetText(data.text)
			bound(tab.label, math.max(1, width - x))
			tab.underline:SetShown(data.on)
			tab.place, tab.open = data.place, open
			local tabW = tab.label:GetWidth()
			tab:SetSize(tabW, 25)
			ns.JournalAt(tab, self, x, 0)
			tab:Show()
			x = x + tabW + 22
		end
		for i = #(block.tabs or {}) + 1, #self.tabs do
			self.tabs[i]:Hide()
		end
		return 26
	end
	return widget
end

-- ---------------------------------------------------------------- icons

---@class LedgerIconWidget: LedgerJournalWidget
---@field medal LedgerMedal
---@field medalLarge LedgerMedal
---@field crest LedgerSpriteTexture
---@field crestIcon Texture

-- An icon (LED-R140, LED-R141, LED-R147): an entry's medallion, the item's icon round in sepia in its double ink ring
-- (a caught fish's 60 units, beside its title), or the unknown fish's dashed medallion, centred, for one never caught
-- (LED-R124); with `style` "legend", the Legend's crest, its icon in the crest's well, or the crest's own plain fish
-- for one uncaught.
makers.icon = function(parent)
	local widget = newWidget(parent) --[[@as LedgerIconWidget]]
	widget.medal = ns.JournalMedal(widget, 60)
	widget.medalLarge = ns.JournalMedal(widget, 88)
	widget.crest = ns.JournalSprite(widget, "Crests", "crest-legend", "ARTWORK", 1, 150, 165)
	widget.crestIcon = ns.JournalCrisp(widget:CreateTexture(nil, "ARTWORK", nil, 2))
	local mask = widget:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(widget.crestIcon)
	widget.crestIcon:AddMaskTexture(mask)
	widget.texture = widget.medal.icon
	function widget.Fill(self, block, width, _, draw)
		local legend = block.style == "legend"
		local unknown = block.look == "silhouette"
		self.medal:SetShown(not legend and not unknown)
		self.medalLarge:SetShown(not legend and unknown)
		self.crest:SetShown(legend)
		self.crestIcon:SetShown(legend and not unknown)
		self.floatW, self.floatH = nil, nil
		if legend then
			-- the crest centred, 150 wide; its well, where the icon sits, a little above its middle
			ns.JournalBoxAt(self.crest, self, (width - 150) / 2, 2)
			local well = 92
			self.crestIcon:SetSize(well, well)
			self.crestIcon:ClearAllPoints()
			self.crestIcon:SetPoint("CENTER", self, "TOPLEFT", width / 2, -(2 + 74))
			if not unknown then
				ns.JournalItemIcon(self.crestIcon, block.icon, "sepia")
			end
			return 170
		end
		if unknown then
			self.medalLarge:ClearAllPoints()
			self.medalLarge:SetPoint("TOP", self, "TOPLEFT", width / 2, -8)
			ns.JournalSetMedal(self.medalLarge, nil, "silhouette")
			return 100
		end
		ns.JournalSetMedal(self.medal, block.icon, "sepia")
		self.medal:ClearAllPoints()
		self.medal:SetPoint("TOPLEFT")
		if draw.float then
			self.floatW, self.floatH = 76, 62
			return 0
		end
		return 62
	end
	return widget
end

-- ---------------------------------------------------------------- the page body

-- The space before a block, by its kind and the one before it (the kit's rhythm): rows and contents lines run on
-- without a gap, a group heading stands clear of what came before.
---@param before LedgerBlock?
---@param block LedgerBlock
---@param group boolean
---@return number
local function spaceBefore(before, block, group)
	if not before then
		return 0
	end
	local kind, prior = block.kind, before.kind
	if kind == "kicker" then
		return group and 16 or 8
	elseif kind == "title" then
		return prior == "kicker" and 1 or 10
	elseif (kind == "row" or kind == "leader" or kind == "plinth" or kind == "variety") and prior == kind then
		return 0
	elseif kind == "row" or kind == "leader" then
		return prior == "kicker" and 6 or 8
	elseif kind == "link" and prior == "link" then
		return block.style == "radio" and 2 or 6
	elseif kind == "text" and prior == "text" and block.hand and before.hand then
		return 2
	elseif kind == "seal" then
		return 0
	end
	return 8
end

-- The room left under a page's last block.
local PAGE_END = 8
-- Kinds a float (an entry's medallion) leaves room beside; any other kind starts under it.
local BESIDE = { kicker = true, title = true }
-- Kinds drawn two to a row (the Junk Museum's plinths, Signed As' radios), and the gap between the two.
local PAIRED = { plinth = true }

--- A page body: a frame whose contents scroll vertically when they overflow (LED-R123), the mouse wheel moving them
--- 26 units a notch, eased over 0.12 s, under the kit's ink scrollbar; each kind's widgets pooled and `drawn` naming
--- those in use, by kind, in page order.
---@class LedgerJournalPage: Frame
---@field scroll ScrollFrame
---@field content Frame
---@field width number
---@field height number
---@field pools table<string, LedgerJournalWidget[]>
---@field drawn table<string, LedgerJournalWidget[]>
---@field rail Texture
---@field thumb Texture
---@field contentH number?   -- the content's height as last drawn

-- Moves the ink scrollbar's thumb to the page's scroll.
---@param page LedgerJournalPage
local function placeThumb(page)
	local range = math.max(0, (page.contentH or 0) - page.height)
	local overflow = range > 0.5
	page.rail:SetShown(overflow)
	page.thumb:SetShown(overflow)
	if not overflow then
		return
	end
	local contentH = page.height + range
	local thumbH = math.max(20, page.height * page.height / contentH)
	page.thumb:SetHeight(thumbH)
	local at = (page.scroll:GetVerticalScroll() or 0) / range
	page.thumb:ClearAllPoints()
	page.thumb:SetPoint("TOPRIGHT", page, "TOPRIGHT", 12, -at * (page.height - thumbH))
end

--- A page body on `parent`, `width` × `height`, that scrolls with the mouse wheel.
---@param parent Frame
---@param width number
---@param height number
---@return LedgerJournalPage
function ns.NewJournalPage(parent, width, height)
	local page = CreateFrame("Frame", nil, parent) --[[@as LedgerJournalPage]]
	page:SetSize(width, height)
	page.width, page.height = width, height
	page.pools, page.drawn = {}, {}
	page.scroll = CreateFrame("ScrollFrame", nil, page) --[[@as ScrollFrame]]
	page.scroll:SetAllPoints()
	page.content = CreateFrame("Frame", nil, page.scroll)
	page.content:SetWidth(width)
	page.content:SetHeight(1)
	page.scroll:SetScrollChild(page.content)
	page.rail = ns.JournalTint(page, INK.tileInk, 0.15)
	page.rail:SetWidth(4)
	page.rail:SetPoint("TOPRIGHT", page, "TOPRIGHT", 12, 0)
	page.rail:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 12, 0)
	page.thumb = ns.JournalTint(page, INK.kicker, 1)
	page.thumb:SetWidth(4)
	page.scroll:EnableMouseWheel(true)
	page.scroll:SetScript("OnMouseWheel", function(self, delta)
		local range = math.max(0, (page.contentH or 0) - page.height)
		local from = self:GetVerticalScroll() or 0
		local to = math.max(0, math.min(range, from - delta * 26))
		Pagle.StopMotion(page.content)
		Pagle.Animate(page.content, {
			{
				dur = 0.12,
				ease = Pagle.EASE.out,
				keys = { { 0, { from } }, { 1, { to } } },
				apply = function(v)
					self:SetVerticalScroll(v[1])
					placeThumb(page)
				end,
			},
		})
	end)
	placeThumb(page)
	return page
end

--- Draws `blocks` down `page`, top to bottom, reusing its widgets and hiding the ones left over; a block with `foot`
--- drops to the page's foot when there is room above it (the varieties spread's fish crest, VAR-R24). `open` opens a
--- place in the Journal; `resetScroll` scrolls back to the top (the page's subject changed, LED-R129), and only a page
--- drawn again on its own subject plays its widgets' moments of change.
---@param page LedgerJournalPage
---@param blocks LedgerBlock[]
---@param open fun(place: LedgerJournalPlace)
---@param resetScroll boolean
function ns.DrawJournalPage(page, blocks, open, resetScroll)
	local drawn = {}
	local y = 0
	local float ---@type { w: number, bottom: number }?
	local pair ---@type { kind: string, top: number, height: number, column: integer }?
	local firstTitle = true
	for i, block in ipairs(blocks) do
		local kind = block.kind
		local before, after = blocks[i - 1], blocks[i + 1]
		local nextKind = after and after.kind
		local group = kind == "kicker" and not (nextKind == "title" or nextKind == "icon")
		local draw = {
			same = not resetScroll,
			group = group,
			first = kind == "title" and firstTitle,
			float = kind == "icon" and nextKind == "title" and block.look ~= "silhouette" and block.style == nil,
			center = kind == "title"
				and before ~= nil
				and before.kind == "icon"
				and (before.style == "legend" or before.look == "silhouette"),
		}
		if kind == "title" then
			firstTitle = false
		end
		local pool = page.pools[kind] or {}
		page.pools[kind] = pool
		local used = drawn[kind] or {}
		drawn[kind] = used
		local widget = pool[#used + 1]
		if not widget then
			widget = makers[kind](page.content)
			pool[#pool + 1] = widget
		end
		used[#used + 1] = widget
		-- a float ends at a kind that can't sit beside it
		if float and not BESIDE[kind] then
			y = math.max(y, float.bottom)
			float = nil
		end
		local x, width = 0, page.width
		if float then
			x, width = float.w, page.width - float.w
		end
		local paired = PAIRED[kind] and pair and pair.kind == kind and pair.column == 1
		if paired then
			-- the second of two side by side: beside the first, in the right half
			---@cast pair -nil
			width = (page.width - 16) / 2
			x = width + 16
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", x, -pair.top)
		else
			if pair then
				y = pair.top + pair.height
				pair = nil
			end
			y = y + spaceBefore(before, block, group)
			if PAIRED[kind] then
				width = (page.width - 16) / 2
			end
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", x, -y)
		end
		widget:SetWidth(width)
		local height = widget:Fill(block, width, open, draw)
		if block.foot and not paired and y + height + PAGE_END < page.height then
			-- at the foot, where there is room for it
			y = page.height - PAGE_END - height
			widget:ClearAllPoints()
			widget:SetPoint("TOPLEFT", x, -y)
		end
		widget:SetHeight(math.max(1, height))
		widget:Show()
		if widget.floatW then
			float = { w = widget.floatW, bottom = y + widget.floatH }
		end
		if paired then
			---@cast pair -nil
			pair.height = math.max(pair.height, height)
			pair.column = 2
		elseif PAIRED[kind] then
			pair = { kind = kind, top = y, height = height, column = 1 }
		else
			y = y + height
		end
	end
	if pair then
		y = pair.top + pair.height
	end
	if float then
		y = math.max(y, float.bottom)
	end
	for kind, pool in pairs(page.pools) do
		for i = #(drawn[kind] or {}) + 1, #pool do
			pool[i]:Hide()
		end
	end
	page.drawn = drawn
	page.contentH = y + PAGE_END
	page.content:SetHeight(math.max(1, page.contentH))
	if resetScroll then
		Pagle.StopMotion(page.content)
		page.scroll:SetVerticalScroll(0)
	end
	placeThumb(page)
end
