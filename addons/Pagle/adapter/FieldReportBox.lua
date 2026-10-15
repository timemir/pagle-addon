---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field report box (field-report.md › The box and its entry points, › UI): a sea chart the Angler copies the
-- report from, its text typed on a slip pinned to the chart, opened only by Pagle.OpenFieldReport, never on its own
-- (REP-R45). What it shows is logic/FieldReportBox.lua's view, built when it opens and kept while it stays open
-- (REP-R40). The art is the field art kit's (data/FieldArt.lua): the chart, the compass, the brass arrows and close
-- button, the leather Close and the slip's scroll thumb. Every position is the kit's canvas pixel, a UI unit, from the
-- box's top left.
local L = ns.L

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleFieldReport"
-- Fixed, whatever the report's length: the text scrolls inside it (REP-R47).
local WIDTH, HEIGHT = 520, 360
-- The slip the report is typed on: its text's top left, and the text's size; the scroll thumb runs down its right.
local SLIP_X, SLIP_Y, SLIP_WIDTH, SLIP_HEIGHT = 34, 92, 426, 156
-- How far one turn of the mouse wheel scrolls the slip: about two typed lines.
local WHEEL_STEP = 36
-- The line of the URL, and of the part controls and Close, as distances down from the top.
local URL_Y, FOOT_Y = 279, 324

-- The kit's inks, from its canvas.
local INKS = {
	sea = { 0x1E, 0x2E, 0x44 }, -- the chart's title, the part line
	note = { 0x4A, 0x30, 0x18 }, -- the privacy line
	hint = { 0x6A, 0x5A, 0x48 }, -- "Ctrl+C to copy"
	type = { 0x1A, 0x1A, 0x24 }, -- the typed report and URL
	red = { 0x7A, 0x2A, 0x1A }, -- "POST IT AT"
	gilt = { 0xF0, 0xCD, 0x6A }, -- Close on the leather
}
local FONT_DIR = "Interface\\AddOns\\Pagle\\media\\fonts\\"
-- What draws if a bundled face won't load: the client's own.
local FALLBACK = "Fonts\\FRIZQT__.TTF"
-- Each font: its face (media/fonts/OFL-*.txt), size and ink, and whether it has a shadow (Close on the leather does;
-- what is on the chart doesn't). Cutive Mono types the report, as a typewriter would.
local FONTS = {
	Title = { "IMFeENrm28P.ttf", 26, "sea" },
	Privacy = { "IMFeENit28P.ttf", 14, "note" },
	CopyHint = { "Caveat-Medium.ttf", 18, "hint" },
	Type = { "CutiveMono-Regular.ttf", 12, "type" },
	PostAt = { "IMFeENrm28P.ttf", 13, "red" },
	Url = { "CutiveMono-Regular.ttf", 11.5, "type" },
	Part = { "Caveat-SemiBold.ttf", 21, "sea" },
	Message = { "Caveat-Bold.ttf", 32, "sea" },
	Button = { "Marcellus-Regular.ttf", 17, "gilt", true },
}
-- The font objects, made the first time the box is built: PagleField<key>.
---@type table<string, table>
local fonts = {}

-- The font object for `key`, made the first time it is asked for.
---@param key string
---@return table
local function font(key)
	if not fonts[key] then
		local def = FONTS[key]
		local made = CreateFont("PagleField" .. key)
		if made:SetFont(FONT_DIR .. def[1], def[2], "") == false then
			made:SetFont(FALLBACK, def[2], "")
		end
		local ink = INKS[def[3]]
		made:SetTextColor(ink[1] / 255, ink[2] / 255, ink[3] / 255)
		if def[4] then
			made:SetShadowColor(0, 0, 0, 0.95)
			made:SetShadowOffset(0, -1)
		else
			made:SetShadowOffset(0, 0)
		end
		fonts[key] = made
	end
	return fonts[key]
end

-- A one-line font string on `frame` in the font `key`.
---@param frame Frame
---@param key string
---@return FontString
local function text(frame, key)
	local made = frame:CreateFontString(nil, "OVERLAY")
	made:SetFontObject(font(key))
	made:SetWordWrap(false)
	made:SetJustifyH("LEFT")
	return made
end

---@class PagleFieldReportBox: Frame
---@field view PagleFieldReportView the view on show, built when it opened
---@field part integer the part shown
---@field chart PagleSprite the sea chart: with the slip for a report, without it for a message
---@field title FontString
---@field privacy FontString
---@field copyHint FontString
---@field message FontString REP-R41's or REP-R42's line, in place of the text
---@field scroll ScrollFrame the slip
---@field text EditBox the part shown, read-only and selected
---@field thumb PagleFieldThumb the slip's scroll thumb, shown while the part is longer than the slip
---@field partLabel FontString
---@field previous PagleFieldBrassButton
---@field next PagleFieldBrassButton
---@field postAt FontString
---@field url EditBox the issue form's URL, read-only
---@field closeCorner PagleFieldBrassButton the brass X
---@field close Button

--- The box, made the first time it opens.
---@type PagleFieldReportBox?
ns.fieldReportBox = nil

-- Closes the box, giving back the keyboard: a hidden edit box would keep it.
---@param frame PagleFieldReportBox
local function close(frame)
	frame.text:ClearFocus()
	frame.url:ClearFocus()
	frame:Hide()
end

-- Keeps `box` showing `read()`: whatever the player types is put back, selected again, so the report stays as
-- built and Ctrl+C still copies all of it. It is selected whenever it gets the focus, and Esc in it closes the box,
-- since a focused edit box takes Esc before UISpecialFrames does.
---@param frame PagleFieldReportBox
---@param box EditBox
---@param read fun(): string
local function keepText(frame, box, read)
	box:SetAutoFocus(false)
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(read())
			self:HighlightText()
		end
	end)
	box:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	box:SetScript("OnEscapePressed", function()
		close(frame)
	end)
end

-- A read-only edit box on `parent`, typed in the font `key`, its selection the kit's blue.
---@param parent Frame
---@param key string
---@return EditBox
local function typedBox(parent, key)
	local box = CreateFrame("EditBox", nil, parent) --[[@as EditBox]]
	box:SetFontObject(font(key))
	box:SetHighlightColor(0.275, 0.47, 0.745, 0.28)
	box:SetTextInsets(0, 0, 0, 0)
	return box
end

--- The slip's scroll thumb: a slider whose thumb is the kit's brass bar.
---@class PagleFieldThumb: Slider
---@field art PagleSprite

--- A brass button: the X, or an arrow.
---@class PagleFieldBrassButton: Button
---@field art PagleSprite

-- A brass button 44 square, drawn as sprite `name` of the Field atlas.
---@param frame Frame
---@param name string
---@return PagleFieldBrassButton
local function brassButton(frame, name)
	local made = CreateFrame("Button", nil, frame) --[[@as PagleFieldBrassButton]]
	made:SetSize(44, 44)
	made.art = ns.ArtSprite(made, "Field", name)
	ns.PlaceSprite(made.art, made, 0, 0)
	return made
end

-- Greys an arrow that can't page further, and stops it taking clicks.
---@param arrow PagleFieldBrassButton
---@param enabled boolean
local function setArrow(arrow, enabled)
	arrow:SetEnabled(enabled)
	arrow.art:SetDesaturated(not enabled)
	if enabled then
		arrow.art:SetVertexColor(1, 1, 1)
	else
		arrow.art:SetVertexColor(0.85, 0.85, 0.85)
	end
end

-- The leather Close: the kit's button, three-sliced to fit its word.
---@param frame Frame
---@return Button
local function leatherButton(frame)
	local made = CreateFrame("Button", nil, frame) --[[@as Button]]
	local leather = CreateFrame("Frame", nil, made)
	leather:SetPoint("TOPLEFT")
	-- The word on a frame above the leather's.
	local words = CreateFrame("Frame", nil, made)
	words:SetAllPoints()
	words:SetFrameLevel(leather:GetFrameLevel() + 1)
	local label = text(words, "Button")
	label:SetJustifyH("CENTER")
	label:SetText(L.FIELD_REPORT_CLOSE)
	label:SetPoint("CENTER", made, "CENTER")
	local width = math.floor(label:GetStringWidth() + 52 + 0.5)
	ns.SetThreeSlice(leather, "Field", "button", width, 12, "ARTWORK")
	made:SetSize(width, 40)
	return made
end

-- Sets the slip's scroll range: the thumb shows while the part is longer than the slip, and it runs the whole slip's
-- height, as long as the part's share of it.
---@param frame PagleFieldReportBox
---@param range number how far the slip can scroll
local function setRange(frame, range)
	range = math.max(0, range or 0)
	frame.thumb:SetMinMaxValues(0, range)
	frame.thumb:SetShown(range > 0)
	local thumbHeight = math.max(20, SLIP_HEIGHT * SLIP_HEIGHT / (SLIP_HEIGHT + range))
	frame.thumb.art:SetSize(5, thumbHeight)
end

-- Shows part `n` of the view's parts on the slip, selected and focused, and the part controls when there is more than
-- one part (REP-R40).
---@param frame PagleFieldReportBox
---@param n integer
local function showPart(frame, n)
	local parts = frame.view.parts
	frame.part = n
	frame.text:SetText(parts[n])
	frame.text:SetCursorPosition(0)
	frame.thumb:SetValue(0)
	frame.scroll:SetVerticalScroll(0)
	setRange(frame, frame.scroll:GetVerticalScrollRange())
	frame.text:SetFocus()
	frame.text:HighlightText()
	local label = ns.FieldReportPartLabel(n, #parts)
	frame.partLabel:SetText(label or "")
	frame.partLabel:SetShown(label ~= nil)
	frame.previous:SetShown(label ~= nil)
	frame.next:SetShown(label ~= nil)
	setArrow(frame.previous, n > 1)
	setArrow(frame.next, n < #parts)
end

-- The slip: the report typed in a read-only edit box (REP-R40) in a scroll frame, which the mouse wheel and the thumb
-- scroll, and which follows the cursor.
---@param frame PagleFieldReportBox
local function buildSlip(frame)
	frame.scroll = CreateFrame("ScrollFrame", nil, frame) --[[@as ScrollFrame]]
	frame.scroll:SetPoint("TOPLEFT", SLIP_X, -SLIP_Y)
	frame.scroll:SetSize(SLIP_WIDTH, SLIP_HEIGHT)
	frame.text = typedBox(frame.scroll, "Type")
	frame.text:SetMultiLine(true)
	frame.text:SetMaxLetters(0)
	frame.text:SetWidth(SLIP_WIDTH)
	frame.scroll:SetScrollChild(frame.text)
	keepText(frame, frame.text, function()
		return frame.view.parts[frame.part]
	end)

	frame.thumb = CreateFrame("Slider", nil, frame) --[[@as PagleFieldThumb]]
	frame.thumb:SetOrientation("VERTICAL")
	frame.thumb:SetPoint("TOPRIGHT", -22, -SLIP_Y)
	frame.thumb:SetSize(14, SLIP_HEIGHT)
	frame.thumb.art = ns.ArtSprite(frame.thumb, "Field", "scroll-thumb", "OVERLAY")
	frame.thumb:SetThumbTexture(frame.thumb.art)
	frame.thumb:SetValueStep(1)
	frame.thumb:SetObeyStepOnDrag(true)
	frame.thumb:SetScript("OnValueChanged", function(_, value)
		frame.scroll:SetVerticalScroll(value)
	end)
	frame.scroll:SetScript("OnScrollRangeChanged", function(_, _, yRange)
		setRange(frame, yRange)
	end)
	frame.scroll:EnableMouseWheel(true)
	frame.scroll:SetScript("OnMouseWheel", function(_, delta)
		frame.thumb:SetValue(frame.thumb:GetValue() - delta * WHEEL_STEP)
	end)
	-- Keeps the cursor's line on the slip, as the player moves it with the keys.
	frame.text:SetScript("OnCursorChanged", function(_, _, y, _, height)
		local top, shown = frame.scroll:GetVerticalScroll(), frame.scroll:GetHeight()
		if -y < top then
			frame.thumb:SetValue(-y)
		elseif -y + height > top + shown then
			frame.thumb:SetValue(-y + height - shown)
		end
	end)
end

-- The box: the sea chart and its compass, the title, the brass X, the privacy line and the copy hint, the slip, the
-- issue form's URL in a second read-only edit box, the part controls, and Close. Centred; Esc closes it. Its own frame,
-- with no template, so it is the chart's size and nothing anchors it over the screen (#250, REP-R47).
---@return PagleFieldReportBox
local function build()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent) --[[@as PagleFieldReportBox]]
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)

	frame.chart = ns.ArtSprite(frame, "Chart", "chart", "BACKGROUND")
	local compass = ns.ArtSprite(frame, "Field", "compass")
	ns.PlaceSprite(compass, frame, 22, 16)
	frame.title = text(frame, "Title")
	frame.title:SetPoint("LEFT", frame, "TOPLEFT", 66, -33)
	frame.title:SetText(L.HELP_CHART)
	frame.closeCorner = brassButton(frame, "close")
	frame.closeCorner:SetPoint("TOPRIGHT", -12, -10)
	frame.closeCorner:SetScript("OnClick", function()
		close(frame)
	end)
	frame.privacy = text(frame, "Privacy")
	frame.privacy:SetPoint("TOPLEFT", 22, -58)
	frame.privacy:SetText(L.FIELD_REPORT_PRIVACY)
	frame.copyHint = text(frame, "CopyHint")
	frame.copyHint:SetPoint("TOPRIGHT", -22, -56)
	frame.copyHint:SetText(L.FIELD_REPORT_COPY_HINT)
	frame.message = text(frame, "Message")
	frame.message:SetWordWrap(true)
	frame.message:SetJustifyH("CENTER")
	frame.message:SetWidth(WIDTH - 80)
	frame.message:SetPoint("CENTER", frame, "TOPLEFT", WIDTH / 2, -170)

	buildSlip(frame)

	frame.postAt = text(frame, "PostAt")
	frame.postAt:SetPoint("LEFT", frame, "TOPLEFT", 22, -URL_Y)
	frame.postAt:SetText(L.FIELD_REPORT_POST_AT)
	frame.url = typedBox(frame, "Url")
	frame.url:SetPoint("LEFT", frame, "TOPLEFT", 98, -URL_Y)
	frame.url:SetSize(WIDTH - 44 - 76 - 20, 20)
	keepText(frame, frame.url, function()
		return ns.FIELD_REPORT_URL
	end)

	frame.previous = brassButton(frame, "arrow-prev")
	frame.previous:SetPoint("LEFT", frame, "TOPLEFT", 22, -FOOT_Y)
	frame.previous:SetScript("OnClick", function()
		showPart(frame, frame.part - 1)
	end)
	frame.partLabel = text(frame, "Part")
	frame.partLabel:SetPoint("LEFT", frame.previous, "RIGHT", 4, 0)
	frame.next = brassButton(frame, "arrow-next")
	frame.next:SetPoint("LEFT", frame.partLabel, "RIGHT", 4, 0)
	frame.next:SetScript("OnClick", function()
		showPart(frame, frame.part + 1)
	end)

	frame.close = leatherButton(frame)
	frame.close:SetPoint("RIGHT", frame, "TOPRIGHT", -22, -FOOT_Y)
	frame.close:SetScript("OnClick", function()
		close(frame)
	end)
	-- Esc with no edit box focused hides it through UISpecialFrames (CloseSpecialWindows).
	frame:SetScript("OnHide", function()
		close(frame)
	end)
	table.insert(UISpecialFrames, FRAME_NAME)
	frame:Hide()
	return frame
end

-- Opens the box with `view`, at part 1 (REP-R40), or with REP-R41's or REP-R42's line on the bare chart, and no text.
---@param view PagleFieldReportView
local function show(view)
	local frame = ns.fieldReportBox
	if not frame then
		frame = build()
		ns.fieldReportBox = frame
	end
	frame.view = view
	local hasText = view.message == nil
	ns.SetSprite(frame.chart, "Chart", hasText and "chart" or "chart-empty")
	ns.PlaceSprite(frame.chart, frame, 0, 0)
	frame.message:SetText(view.message or "")
	frame.message:SetShown(not hasText)
	for _, part in ipairs({ frame.privacy, frame.copyHint, frame.scroll, frame.text }) do
		part:SetShown(hasText)
	end
	frame.postAt:SetShown(view.url ~= nil)
	frame.url:SetShown(view.url ~= nil)
	frame.url:SetText(view.url or "")
	frame:Show()
	if hasText then
		showPart(frame, 1)
	else
		for _, part in ipairs({ frame.partLabel, frame.previous, frame.next, frame.thumb }) do
			part:Hide()
		end
	end
end

--- Opens the Field report box (REP-R40–R44): at part 1, its text built now from the Field report's rows; REP-R41's
--- line with no row, REP-R42's while the projection updates. While restricted it prints "Pagle: the Field report
--- opens after combat." instead, and a box already open stays open. Every entry point calls it: /pagle report, the
--- compartment entry, the Settings root's button and the Ledger's Journal (REP-R43).
Pagle.OpenFieldReport = ns.OpenFieldReportFunction({
	isRestricted = function()
		return Pagle.IsRestricted()
	end,
	print = function(line)
		print(line)
	end,
	rows = function()
		return ns.FieldReportRows()
	end,
	text = function(rows)
		return ns.FieldReportText(rows)
	end,
	show = show,
})
