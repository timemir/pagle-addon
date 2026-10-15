---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field report box (field-report.md › The box and its entry points, › UI): a native dialog the Angler copies the
-- report from, opened only by Pagle.OpenFieldReport, never on its own (REP-R45). What it shows is logic/
-- FieldReportBox.lua's view, built when it opens and kept while it stays open (REP-R40).
local L = ns.L

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PagleFieldReport"
-- Fixed, whatever the report's length: the text scrolls inside it (REP-R47).
local WIDTH, HEIGHT = 520, 360
-- The report text's area: from under the privacy line down to the part controls.
local TEXT_TOP, TEXT_BOTTOM = -70, 110

---@class PagleFieldReportBox: Frame
---@field view PagleFieldReportView the view on show, built when it opened
---@field part integer the part shown
---@field title FontString
---@field privacy FontString
---@field message FontString REP-R41's or REP-R42's line, in place of the text
---@field scroll ScrollFrame
---@field text EditBox the part shown, read-only and selected
---@field partLabel FontString
---@field previous Button
---@field next Button
---@field url EditBox the issue form's URL, read-only
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

-- A button with the native look, `width` wide, reading `label`.
---@param frame Frame
---@param label string
---@param width number
---@return Button
local function button(frame, label, width)
	local made = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate") --[[@as Button]]
	made:SetSize(width, 22)
	made:SetText(label)
	return made
end

-- Shows part `n` of the view's parts in the text box, selected and focused, and the part controls when there is more
-- than one part (REP-R40).
---@param frame PagleFieldReportBox
---@param n integer
local function showPart(frame, n)
	local parts = frame.view.parts
	frame.part = n
	frame.text:SetText(parts[n])
	frame.text:SetCursorPosition(0)
	frame.scroll:SetVerticalScroll(0)
	frame.text:SetFocus()
	frame.text:HighlightText()
	local label = ns.FieldReportPartLabel(n, #parts)
	frame.partLabel:SetText(label or "")
	frame.partLabel:SetShown(label ~= nil)
	frame.previous:SetShown(label ~= nil)
	frame.next:SetShown(label ~= nil)
	frame.previous:SetEnabled(n > 1)
	frame.next:SetEnabled(n < #parts)
end

-- The box: a native dialog border, the title, the privacy line, the report text in a scrolling read-only edit box,
-- the part controls, the issue form's URL in a second read-only edit box, and Close. Centred; Esc closes it. The
-- templates are FrameXML's at Gethe/wow-ui-source branch forever, 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/: DialogBorderTemplate (Shared/Dialog/DialogTemplates.xml),
-- UIPanelScrollFrameTemplate (SecureScrollTemplates.xml) and InputBoxTemplate (Shared/InputBox/InputBoxTemplates.xml),
-- which Blizzard_SharedXML.toc loads for every game type, and UIPanelButtonTemplate, as Core's cards use it.
-- DialogBorderTemplate inherits NineSlicePanelTemplate's setAllPoints="true" (Mainline/SharedUIPanelTemplates.xml,
-- line 381), so the frame starts anchored over all of UIParent: those anchors go before it takes its own size, or
-- it fills the screen (#250, REP-R47).
---@return PagleFieldReportBox
local function build()
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "DialogBorderTemplate") --[[@as PagleFieldReportBox]]
	frame:ClearAllPoints()
	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)

	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	frame.title:SetPoint("TOP", 0, -20)
	frame.title:SetText(L.HELP_CHART)
	frame.privacy = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.privacy:SetPoint("TOP", 0, -46)
	frame.privacy:SetText(L.FIELD_REPORT_PRIVACY)
	frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.message:SetPoint("CENTER", 0, 20)

	frame.scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate") --[[@as ScrollFrame]]
	frame.scroll:SetPoint("TOPLEFT", 24, TEXT_TOP)
	frame.scroll:SetPoint("BOTTOMRIGHT", -44, TEXT_BOTTOM)
	frame.text = CreateFrame("EditBox", nil, frame.scroll) --[[@as EditBox]]
	frame.text:SetMultiLine(true)
	frame.text:SetMaxLetters(0)
	frame.text:SetFontObject("ChatFontNormal")
	frame.text:SetWidth(WIDTH - 68)
	frame.scroll:SetScrollChild(frame.text)
	keepText(frame, frame.text, function()
		return frame.view.parts[frame.part]
	end)

	frame.previous = button(frame, L.FIELD_REPORT_PREVIOUS, 100)
	frame.previous:SetPoint("BOTTOMLEFT", 24, 76)
	frame.previous:SetScript("OnClick", function()
		showPart(frame, frame.part - 1)
	end)
	frame.next = button(frame, L.FIELD_REPORT_NEXT, 100)
	frame.next:SetPoint("BOTTOMRIGHT", -24, 76)
	frame.next:SetScript("OnClick", function()
		showPart(frame, frame.part + 1)
	end)
	frame.partLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	frame.partLabel:SetPoint("BOTTOM", 0, 80)

	frame.url = CreateFrame("EditBox", nil, frame, "InputBoxTemplate") --[[@as EditBox]]
	frame.url:SetPoint("BOTTOMLEFT", 30, 46)
	frame.url:SetPoint("BOTTOMRIGHT", -30, 46)
	frame.url:SetHeight(20)
	keepText(frame, frame.url, function()
		return ns.FIELD_REPORT_URL
	end)

	frame.close = button(frame, L.FIELD_REPORT_CLOSE, 100)
	frame.close:SetPoint("BOTTOM", 0, 16)
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

-- Opens the box with `view`, at part 1 (REP-R40), or with REP-R41's or REP-R42's line and no text.
---@param view PagleFieldReportView
local function show(view)
	local frame = ns.fieldReportBox
	if not frame then
		frame = build()
		ns.fieldReportBox = frame
	end
	frame.view = view
	local hasText = view.message == nil
	frame.message:SetText(view.message or "")
	frame.message:SetShown(not hasText)
	frame.privacy:SetShown(hasText)
	frame.scroll:SetShown(hasText)
	frame.text:SetShown(hasText)
	frame.url:SetShown(view.url ~= nil)
	frame.url:SetText(view.url or "")
	frame:Show()
	if hasText then
		showPart(frame, 1)
	else
		for _, part in ipairs({ frame.partLabel, frame.previous, frame.next }) do
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
