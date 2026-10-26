---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The export window (paste-string.md › The export window, › UI): the sea chart the Angler copies a Paste string from,
-- part by part, to paste on the Pagle website, opened only by Pagle.OpenPasteExport and `/pagle dev pastetest`, never
-- on its own (PST-R2). What it shows is logic/PasteExport.lua's view, built when it opens and when a choice is picked
-- (PST-R52); each part's Paste string is built with the vendored LibDeflate the first time the part shows (PST-R33).
-- It is drawn with the field art kit's parts the Field report box shares (adapter/FieldKit.lua): every position is the
-- kit's canvas pixel, a UI unit, from the window's top left.
local L = ns.L

-- The frame's global name: UISpecialFrames takes names, and Esc hides the frames it lists.
local FRAME_NAME = "PaglePasteExport"
-- Fixed, whatever the string's length (PST-R53).
local WIDTH, HEIGHT = 520, 360
-- The slip: where its lines start across, and how wide they run.
local SLIP_X, SLIP_WIDTH = 34, 426
-- On the slip, as distances down from the top: the choices, the string's box and the two lines under it.
local CHOICES_Y, STRING_Y, LINE_Y, NOTE_Y = 104, 140, 168, 188
-- Between the two choices.
local CHOICE_GAP = 28
-- The line of the URL, and of the part controls and Close, as on the Field report box.
local URL_Y, FOOT_Y = 279, 324

---@class PaglePasteChoiceButton: Button
---@field label FontString

---@class PaglePasteWindow: PagleFieldWindow
---@field view PaglePasteView the view on show (PST-R52)
---@field part integer the part shown
---@field pastes table<integer, string> each part's Paste string built so far for this view (PST-R33)
---@field choices table<string, PaglePasteChoiceButton> "New since last export" and "Everything", by choice
---@field paste EditBox the part's Paste string, read-only, selected, on one line (PST-R31)
---@field line FontString its entries and size, under it
---@field note FontString "Paste each part on its own, in order.", with more than one part
---@field message FontString PST-R15's or PST-R21's line, in place of the string
---@field pasteAt FontString
---@field url EditBox the Paste upload page's URL, read-only
---@field partLabel FontString
---@field previous PagleFieldBrassButton
---@field next PagleFieldBrassButton
---@field close Button

--- The window, made the first time it opens.
---@type PaglePasteWindow?
ns.pasteExportWindow = nil

-- The view for `choice` now: an export of the Catch log as it is, against PagleDB's marks (PST-R20, PST-R21).
---@param choice PaglePasteChoice
---@return PaglePasteView
local function viewFor(choice)
	local asOf, deadline = GetServerTime(), debugprofilestop() + 4
	local pending = coroutine.create(function()
		return ns.PasteView(ns.catchLog.data, ns.db.global.pasteExports, choice, asOf, function()
			if debugprofilestop() >= deadline then
				coroutine.yield()
				deadline = debugprofilestop() + 4
			end
		end)
	end)
	local ok, view = coroutine.resume(pending)
	assert(ok, view)
	if coroutine.status(pending) == "dead" then
		return view
	end
	return { choice = choice, message = L.PASTE_PREPARING, pending = pending }
end

-- Part `n`'s Paste string, built the first time it is asked for and kept while the view shows (PST-R30, PST-R33).
---@param frame PaglePasteWindow
---@param n integer
---@return string
local function pasteOf(frame, n)
	local view = frame.view
	if view.test then
		return view.test
	end
	if not frame.pastes[n] then
		local export = assert(view.export)
		frame.pastes[n] = ns.PasteString(ns.PasteDocument(export, n), LibStub("LibDeflate") --[[@as PaglePasteCodec]])
	end
	return frame.pastes[n]
end

-- Shows each choice as it reads now: the one the view was built for after a bullet in the sea's ink, the other in
-- the hint's; the copy test's view picks neither.
---@param frame PaglePasteWindow
local function showChoices(frame)
	for _, choice in ipairs(ns.PASTE_CHOICES) do
		local button = frame.choices[choice]
		local word = choice == "new" and L.PASTE_CHOICE_NEW or L.PASTE_CHOICE_EVERYTHING
		local picked = frame.view.choice == choice
		button.label:SetText(picked and L.PASTE_CHOICE_PICKED:format(word) or word)
		button.label:SetTextColor(ns.FieldInk(picked and "sea" or "hint"))
		button:SetSize(button.label:GetStringWidth(), 24)
	end
end

-- Shows part `n`: its Paste string selected and focused, the lines under it, and the part controls when there is more
-- than one part (PST-R51).
---@param frame PaglePasteWindow
---@param n integer
local function showPart(frame, n)
	frame.part = n
	local paste = pasteOf(frame, n)
	frame.paste:SetText(paste)
	frame.paste:SetCursorPosition(0)
	frame.paste:SetFocus()
	frame.paste:HighlightText()
	local lines = ns.PastePartLines(frame.view, n, #paste, BreakUpLargeNumbers)
	frame.line:SetText(lines[1])
	frame.note:SetText(lines[2] or "")
	frame.note:SetShown(lines[2] ~= nil)
	local count = ns.PastePartCount(frame.view)
	local label = ns.PastePartLabel(n, count)
	frame.partLabel:SetText(label or "")
	frame.partLabel:SetShown(label ~= nil)
	frame.previous:SetShown(label ~= nil)
	frame.next:SetShown(label ~= nil)
	ns.FieldSetArrow(frame.previous, n > 1)
	ns.FieldSetArrow(frame.next, n < count)
end

-- Shows `view` in the window, at part 1 (PST-R51), or its message in the string's place with no lines or parts.
---@param frame PaglePasteWindow
---@param view PaglePasteView
local function showView(frame, view)
	frame:SetScript("OnUpdate", nil)
	frame.view, frame.pastes = view, {}
	showChoices(frame)
	local hasString = view.message == nil
	frame.message:SetText(view.message or "")
	frame.message:SetShown(not hasString)
	for _, part in ipairs({ frame.paste, frame.line, frame.copyHint, frame.pasteAt, frame.url }) do
		part:SetShown(hasString)
	end
	if hasString then
		showPart(frame, 1)
	else
		frame.paste:ClearFocus()
		for _, part in ipairs({ frame.note, frame.partLabel, frame.previous, frame.next }) do
			part:Hide()
		end
	end
	if view.pending then
		frame:SetScript("OnUpdate", function()
			local ok, ready = coroutine.resume(view.pending)
			assert(ok, ready)
			if coroutine.status(view.pending) == "dead" then
				showView(frame, ready)
			end
		end)
	end
end

-- Marks the part shown as copied when Ctrl+C, or Cmd+C on a Mac, is pressed in the string's box (PST-R40): its
-- last seq becomes the log's last exported seq, unless it is lower. The copy test marks nothing.
---@param frame PaglePasteWindow
---@param key string
local function onKey(frame, key)
	local export = frame.view.export
	if key == "C" and export and (IsControlKeyDown() or IsMetaKeyDown()) then
		ns.MarkPasteCopied(ns.db.global.pasteExports, export.logId, export.parts[frame.part])
	end
end

-- A choice on the slip: picking the one not shown makes a new export and shows its part 1 (PST-R51).
---@param frame PaglePasteWindow
---@param choice PaglePasteChoice
---@return PaglePasteChoiceButton
local function choiceButton(frame, choice)
	local button = CreateFrame("Button", nil, frame) --[[@as PaglePasteChoiceButton]]
	button.label = ns.FieldText(button, "Choice")
	button.label:SetPoint("LEFT")
	button:SetScript("OnClick", function()
		PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
		if frame.view.choice ~= choice then
			showView(frame, viewFor(choice))
		end
	end)
	return button
end

-- The window: the kit's sea chart with its slip, titled Export for the website, with the privacy line and the copy
-- hint (adapter/FieldKit.lua); on the slip the two choices, the string's one-line box, the lines under it and the
-- message; the Paste upload page's URL; the part controls; and Close. Centred; Esc closes it (PST-R53).
---@return PaglePasteWindow
local function build()
	local frame = ns.NewFieldWindow(FRAME_NAME, WIDTH, HEIGHT, L.PASTE_TITLE, L.PASTE_PRIVACY, L.PASTE_COPY_HINT) --[[@as PaglePasteWindow]]
	ns.SetSprite(frame.chart, "Chart", "chart")
	ns.PlaceSprite(frame.chart, frame, 0, 0)
	frame.pastes = {}

	frame.choices = { new = choiceButton(frame, "new"), everything = choiceButton(frame, "everything") }
	frame.choices.new:SetPoint("LEFT", frame, "TOPLEFT", SLIP_X, -CHOICES_Y)
	frame.choices.everything:SetPoint("LEFT", frame.choices.new, "RIGHT", CHOICE_GAP, 0)

	-- One line, never wrapped (PST-R31): a single-line edit box scrolls sideways instead.
	frame.paste = ns.FieldTypedBox(frame, "Type")
	frame.paste:SetMultiLine(false)
	frame.paste:SetMaxLetters(0)
	frame.paste:SetSize(SLIP_WIDTH, 20)
	frame.paste:SetPoint("LEFT", frame, "TOPLEFT", SLIP_X, -STRING_Y)
	ns.FieldKeepText(frame, frame.paste, function()
		return pasteOf(frame, frame.part)
	end)
	frame.paste:SetScript("OnKeyDown", function(_, key)
		onKey(frame, key)
	end)
	-- A click in it would leave part of it selected: all of it is, always, so Ctrl+C copies the whole string.
	frame.paste:SetScript("OnMouseUp", function(self)
		self:HighlightText()
	end)
	frame.line = ns.FieldText(frame, "Type")
	frame.line:SetPoint("LEFT", frame, "TOPLEFT", SLIP_X, -LINE_Y)
	frame.note = ns.FieldText(frame, "Type")
	frame.note:SetPoint("LEFT", frame, "TOPLEFT", SLIP_X, -NOTE_Y)
	frame.message = ns.FieldText(frame, "Choice")
	frame.message:SetPoint("LEFT", frame, "TOPLEFT", SLIP_X, -STRING_Y)

	frame.pasteAt = ns.FieldText(frame, "PostAt")
	frame.pasteAt:SetPoint("LEFT", frame, "TOPLEFT", 22, -URL_Y)
	frame.pasteAt:SetText(L.PASTE_AT)
	frame.url = ns.FieldTypedBox(frame, "Url")
	frame.url:SetHeight(20)
	ns.FieldKeepText(frame, frame.url, function()
		return ns.PASTE_URL
	end, true)
	frame.boxes = { frame.paste, frame.url }

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

	frame.close = ns.FieldLeatherButton(frame, L.PASTE_CLOSE)
	frame.close:SetPoint("CENTER", frame, "TOP", 0, -FOOT_Y)
	frame.close:SetScript("OnClick", function()
		if not frame.closing then
			PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
			ns.FieldFadeClose(frame)
		end
	end)
	return frame
end

-- Lays out the URL line as the Field report box does (ns.FieldReportUrlLine): "PASTE IT AT" at its font's size, set
-- smaller if the client draws it too wide to end before the chart's URL field, and the URL's box after it.
---@param frame PaglePasteWindow
local function layOutUrlLine(frame)
	local label = frame.pasteAt
	label:SetFontObject(ns.FieldFont("PostAt"))
	local scale, urlX = ns.FieldReportUrlLine(label:GetStringWidth())
	if scale < 1 then
		ns.FieldScaleFont(label, "PostAt", scale)
	end
	frame.url:ClearAllPoints()
	frame.url:SetPoint("LEFT", frame, "TOPLEFT", urlX, -URL_Y)
	frame.url:SetWidth(WIDTH - 42 - urlX)
end

--- Opens the export window with `view` (PST-R51): opening, it fades in; already open, it shows `view` in place.
---@param view PaglePasteView
function ns.ShowPasteExport(view)
	local frame = ns.pasteExportWindow
	if not frame then
		frame = build()
		ns.pasteExportWindow = frame
	end
	ns.FieldShowWindow(frame)
	layOutUrlLine(frame)
	showView(frame, view)
	frame.url:SetText(ns.PASTE_URL)
	frame.url:SetCursorPosition(0) -- from "https://", not scrolled to its end
end

--- Opens the export window (PST-R50–R53): an export made now of the Catch log, on "New since last export", at part
--- 1. While restricted it prints "Pagle: the export window opens after combat." instead, and a window already open
--- stays open. Every entry point calls it: /pagle export and the Settings root's button.
Pagle.OpenPasteExport = ns.OpenPasteExportFunction({
	isRestricted = function()
		return Pagle.IsRestricted()
	end,
	print = function(line)
		print(line)
	end,
	view = viewFor,
	show = ns.ShowPasteExport,
})
