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
-- button, the leather Close and the slip's scroll thumb, drawn with the parts the export window shares
-- (adapter/FieldKit.lua). Every position is the kit's canvas pixel, a UI unit, from the box's top left. It fades in
-- as it opens and out as it closes, on Core's motion driver (adapter/Motion.lua), and plays the kit's open, close and
-- click sounds (the kit's MOTION.md and SOUND.md).
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

---@class PagleFieldReportBox: PagleFieldWindow
---@field view PagleFieldReportView the view on show, built when it opened
---@field part integer the part shown
---@field message FontString REP-R41's or REP-R42's line, in place of the text
---@field scroll ScrollFrame the slip
---@field text EditBox the part shown, read-only and selected
---@field thumb PagleFieldThumb the slip's scroll thumb, shown while the part is longer than the slip
---@field partLabel FontString
---@field previous PagleFieldBrassButton
---@field next PagleFieldBrassButton
---@field postAt FontString
---@field url EditBox the issue form's URL, read-only
---@field close Button

--- The box, made the first time it opens.
---@type PagleFieldReportBox?
ns.fieldReportBox = nil

--- The slip's scroll thumb: a slider whose thumb is the kit's brass bar.
---@class PagleFieldThumb: Slider
---@field art PagleSprite

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
	ns.FieldSetArrow(frame.previous, n > 1)
	ns.FieldSetArrow(frame.next, n < #parts)
end

-- The slip: the report typed in a read-only edit box (REP-R40) in a scroll frame, which the mouse wheel and the thumb
-- scroll, and which follows the cursor.
---@param frame PagleFieldReportBox
local function buildSlip(frame)
	frame.scroll = CreateFrame("ScrollFrame", nil, frame) --[[@as ScrollFrame]]
	frame.scroll:SetPoint("TOPLEFT", SLIP_X, -SLIP_Y)
	frame.scroll:SetSize(SLIP_WIDTH, SLIP_HEIGHT)
	frame.text = ns.FieldTypedBox(frame.scroll, "Type")
	frame.text:SetMultiLine(true)
	frame.text:SetMaxLetters(0)
	frame.text:SetWidth(SLIP_WIDTH)
	frame.scroll:SetScrollChild(frame.text)
	ns.FieldKeepText(frame, frame.text, function()
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

-- The box: the kit's sea chart window titled Help chart the waters, with the privacy line and the copy hint
-- (adapter/FieldKit.lua), the slip, the issue form's URL in a second read-only edit box, the part controls, and Close.
-- Centred; Esc closes it (REP-R47).
---@return PagleFieldReportBox
local function build()
	local frame =
		ns.NewFieldWindow(FRAME_NAME, WIDTH, HEIGHT, L.HELP_CHART, L.FIELD_REPORT_PRIVACY, L.FIELD_REPORT_COPY_HINT) --[[@as PagleFieldReportBox]]
	frame.message = ns.FieldText(frame, "Message")
	frame.message:SetWordWrap(true)
	frame.message:SetJustifyH("CENTER")
	frame.message:SetWidth(WIDTH - 80)
	frame.message:SetPoint("CENTER", frame, "TOPLEFT", WIDTH / 2, -170)

	buildSlip(frame)

	frame.postAt = ns.FieldText(frame, "PostAt")
	frame.postAt:SetPoint("LEFT", frame, "TOPLEFT", 22, -URL_Y)
	frame.postAt:SetText(L.FIELD_REPORT_POST_AT)
	frame.url = ns.FieldTypedBox(frame, "Url")
	frame.url:SetHeight(20)
	ns.FieldKeepText(frame, frame.url, function()
		return ns.FIELD_REPORT_URL
	end, true)
	frame.boxes = { frame.text, frame.url }

	frame.previous = ns.FieldBrassButton(frame, "arrow-prev")
	frame.previous:SetPoint("LEFT", frame, "TOPLEFT", 22, -FOOT_Y)
	frame.previous:SetScript("OnClick", function()
		PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
		showPart(frame, frame.part - 1)
	end)
	frame.partLabel = ns.FieldText(frame, "Part")
	frame.partLabel:SetPoint("LEFT", frame.previous, "RIGHT", 4, 0)
	frame.next = ns.FieldBrassButton(frame, "arrow-next")
	frame.next:SetPoint("LEFT", frame.partLabel, "RIGHT", 4, 0)
	frame.next:SetScript("OnClick", function()
		PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
		showPart(frame, frame.part + 1)
	end)

	-- At the bottom centre, clear of the part controls on the left.
	frame.close = ns.FieldLeatherButton(frame, L.FIELD_REPORT_CLOSE)
	frame.close:SetPoint("CENTER", frame, "TOP", 0, -FOOT_Y)
	frame.close:SetScript("OnClick", function()
		if not frame.closing then
			PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
			ns.FieldFadeClose(frame)
		end
	end)
	return frame
end

-- Lays out the URL line (ns.FieldReportUrlLine): "POST IT AT" at its font's size, set smaller if the client draws it
-- too wide to end before the chart's URL field, and the URL edit box after it, so the two never overlap.
---@param frame PagleFieldReportBox
local function layOutUrlLine(frame)
	local label = frame.postAt
	label:SetFontObject(ns.FieldFont("PostAt"))
	local scale, urlX = ns.FieldReportUrlLine(label:GetStringWidth())
	if scale < 1 then
		ns.FieldScaleFont(label, "PostAt", scale)
	end
	frame.url:ClearAllPoints()
	frame.url:SetPoint("LEFT", frame, "TOPLEFT", urlX, -URL_Y)
	frame.url:SetWidth(WIDTH - 42 - urlX)
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
	frame.url:SetCursorPosition(0) -- from "https://", not scrolled to its end
	-- Opening, or opened again while it fades out: it fades in. Already open, it stays as it is.
	ns.FieldShowWindow(frame)
	layOutUrlLine(frame)
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
