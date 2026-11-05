---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The field art kit's parts that the Field report box (adapter/FieldReportBox.lua, field-report.md › UI) and the
-- export window (adapter/PasteExport.lua, paste-string.md › UI) share: the sea chart window with its compass, title,
-- brass X, privacy line and copy hint; the kit's fonts and inks; read-only edit boxes that keep their text; the brass
-- buttons and the leather one; and the window's motion and sounds (the kit's MOTION.md and SOUND.md), on Core's motion
-- driver (adapter/Motion.lua). Every position is the kit's canvas pixel, a UI unit, from the window's top left.

-- The kit's inks, from its canvas.
local INKS = {
	sea = { 0x1E, 0x2E, 0x44 }, -- the chart's title, the part line, a choice picked
	note = { 0x4A, 0x30, 0x18 }, -- the privacy line
	hint = { 0x6A, 0x5A, 0x48 }, -- "Ctrl+C to copy", a choice not picked
	type = { 0x1A, 0x1A, 0x24 }, -- typed text and URLs
	red = { 0x7A, 0x2A, 0x1A }, -- "POST IT AT", "PASTE IT AT"
	gilt = { 0xF0, 0xCD, 0x6A }, -- Close on the leather
}
-- Each font: its face (a bundled file in media/fonts, OFL-*.txt; ns.faces gives the file that draws it, CORE-R9), size
-- and ink, and whether it has a shadow (Close on the leather does; what is on the chart doesn't). Cutive Mono types the
-- text, as a typewriter would.
local FONTS = {
	Title = { "IMFeENrm28P.ttf", 26, "sea" },
	Privacy = { "IMFeENit28P.ttf", 14, "note" },
	CopyHint = { "Caveat-Medium.ttf", 18, "hint" },
	Type = { "CutiveMono-Regular.ttf", 12, "type" },
	PostAt = { "IMFeENrm28P.ttf", 13, "red" },
	Url = { "CutiveMono-Regular.ttf", 11.5, "type" },
	Part = { "Caveat-SemiBold.ttf", 21, "sea" },
	Choice = { "Caveat-SemiBold.ttf", 20, "sea" },
	Message = { "Caveat-Bold.ttf", 32, "sea" },
	Button = { "Marcellus-Regular.ttf", 17, "gilt", true },
}
-- The window's edges' margin, the title's start, the brass X's inset and size, and the gap kept between texts.
local MARGIN, TITLE_X, CORNER_X, CORNER_SIZE, GAP = 22, 66, 12, 44, 10
-- How small the title and the privacy line may be set to fit, as a share of their fonts' sizes.
local TITLE_FLOOR, PRIVACY_FLOOR = 0.75, 0.8
-- The least gap between a URL line's label and its URL box.
local URL_GAP = 8

-- The font objects, made the first time each is asked for: PagleField<key>.
---@type table<string, table>
local fonts = {}
-- The file each font object loaded: its face in the Pagle language applied, or the fallback.
---@type table<string, string>
local fontFiles = {}

--- The kit's ink `name` as r, g, b from 0 to 1.
---@param name string
---@return number r
---@return number g
---@return number b
function ns.FieldInk(name)
	local ink = INKS[name]
	return ink[1] / 255, ink[2] / 255, ink[3] / 255
end

--- The kit's font object for `key`, made the first time it is asked for.
---@param key string
---@return table
function ns.FieldFont(key)
	if not fonts[key] then
		local def = FONTS[key]
		local made = CreateFont("PagleField" .. key)
		fontFiles[key] = ns.faces:Set(made, def[1], def[2])
		made:SetTextColor(ns.FieldInk(def[3]))
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

--- Sets `label`, in the kit's font `key`, to `scale` of that font's size, in its file and ink.
---@param label FontString
---@param key string
---@param scale number
function ns.FieldScaleFont(label, key, scale)
	ns.FieldFont(key)
	local def = FONTS[key]
	label:SetFont(fontFiles[key], def[2] * scale, "")
	label:SetTextColor(ns.FieldInk(def[3]))
end

--- Fits `label`, in the kit's font `key` with its text set, to `room`: measured unbounded at the font's size, a text
--- too wide is set smaller, down to `floor` of that size, and one still too wide is held to `room`, where the client
--- cuts it with "...", or, given `lines` above 1, wraps it on up to that many lines. Returns the scale it is set at.
---@param label FontString
---@param key string
---@param room number
---@param floor number
---@param lines integer?
---@return number
function ns.FieldFitText(label, key, room, floor, lines)
	label:SetFontObject(ns.FieldFont(key))
	label:SetWidth(0) -- measured unbounded
	local natural = label:GetStringWidth()
	local scale = 1
	if natural > room then
		scale = math.max(floor, room / natural)
		ns.FieldScaleFont(label, key, scale)
	end
	local wraps = (lines or 1) > 1
	label:SetWordWrap(wraps)
	if wraps then
		label:SetMaxLines(lines)
	end
	label:SetWidth(room)
	return scale
end

--- Lays out a window's URL line `y` down (ns.FieldReportUrlLine, field-report.md › UI): `label` ("POST IT AT", "PASTE
--- IT AT") at its font's size, set smaller if the client draws it too wide to end before the chart's URL field, and the
--- `url` box after it. The label is measured again as drawn at that size, so a face drawn wider than its share still
--- ends URL_GAP before the URL, and the two never touch.
---@param frame Frame
---@param label FontString
---@param url EditBox
---@param width number the window's
---@param y number
function ns.FieldUrlLine(frame, label, url, width, y)
	label:SetFontObject(ns.FieldFont("PostAt"))
	label:SetWidth(0) -- measured unbounded
	local scale, urlX = ns.FieldReportUrlLine(label:GetStringWidth())
	if scale < 1 then
		ns.FieldScaleFont(label, "PostAt", scale)
	end
	urlX = math.max(urlX, MARGIN + label:GetStringWidth() + URL_GAP)
	url:ClearAllPoints()
	url:SetPoint("LEFT", frame, "TOPLEFT", urlX, -y)
	url:SetWidth(width - 42 - urlX)
end

--- A one-line font string on `frame` in the kit's font `key`.
---@param frame Frame
---@param key string
---@return FontString
function ns.FieldText(frame, key)
	local made = frame:CreateFontString(nil, "OVERLAY")
	made:SetFontObject(ns.FieldFont(key))
	made:SetWordWrap(false)
	made:SetJustifyH("LEFT")
	return made
end

--- A read-only edit box on `parent`, typed in the kit's font `key`, its selection the kit's blue.
---@param parent Frame
---@param key string
---@return EditBox
function ns.FieldTypedBox(parent, key)
	local box = CreateFrame("EditBox", nil, parent) --[[@as EditBox]]
	box:SetFontObject(ns.FieldFont(key))
	box:SetHighlightColor(0.275, 0.47, 0.745, 0.28)
	box:SetTextInsets(0, 0, 0, 0)
	return box
end

--- A sea chart window: its chart, compass, title, brass X, privacy line and copy hint, and the edit boxes it gives
--- back the keyboard from as it closes.
---@class PagleFieldWindow: Frame
---@field chart PagleSprite the sea chart: with the slip, or the bare chart
---@field title FontString
---@field privacy FontString
---@field copyHint FontString
---@field closeCorner PagleFieldBrassButton the brass X
---@field boxes EditBox[] its edit boxes, each given back the keyboard as it closes
---@field closing boolean? fading out after Close or the X, so it takes no more clicks

--- A brass button: the X, or an arrow.
---@class PagleFieldBrassButton: Button
---@field art PagleSprite

-- The window's sounds (the field art kit's SOUND.md): the client's own sound kits, by id, on the SFX channel, so the
-- player's SFX volume and mute rule them. UI foley, the same in every sound set (announcements.md › Sounds owns only
-- an Announcement's): IG_MAINMENU_OPEN as a window opens, IG_MAINMENU_CLOSE as it closes, IG_MAINMENU_OPTION for a
-- click on Close, an arrow or a choice.
ns.FIELD_SOUND_OPEN, ns.FIELD_SOUND_CLOSE, ns.FIELD_SOUND_CLICK = 850, 851, 852

--- Closes `frame` at once, giving back the keyboard: a hidden edit box would keep it.
---@param frame PagleFieldWindow
function ns.FieldCloseNow(frame)
	for _, box in ipairs(frame.boxes) do
		box:ClearFocus()
	end
	frame:Hide()
end

-- The window opening (the kit's MOTION.md): the open sound, and the window fading in over 0.2 s (ease-out), from
-- `from` (0, or where a fade out had got to). With the Animations setting off it shows at once (adapter/Motion.lua).
---@param frame PagleFieldWindow
---@param from number
local function fadeIn(frame, from)
	frame.closing = false
	PlaySound(ns.FIELD_SOUND_OPEN, "SFX")
	ns.StopMotion(frame)
	ns.Animate(frame, {
		{
			dur = 0.2,
			ease = ns.EASE.out,
			keys = { { 0, { from } }, { 1, { 1 } } },
			apply = function(values)
				frame:SetAlpha(values[1])
			end,
		},
	})
end

--- Shows `frame`: opening, or opened again while it fades out, it fades in; already open, it stays as it is.
---@param frame PagleFieldWindow
function ns.FieldShowWindow(frame)
	local from ---@type number?
	if frame.closing then
		from = frame:GetAlpha()
	elseif not frame:IsShown() then
		from = 0
	end
	frame:Show()
	if from then
		fadeIn(frame, from)
	end
end

--- Closes `frame` from Close or the X (the kit's MOTION.md): the keyboard given back at once, the close sound, and the
--- window fading out over 0.15 s (ease-in) from where it is, then hiding. Esc hides it at once, from an edit box or
--- through UISpecialFrames, with the close sound (its OnHide).
---@param frame PagleFieldWindow
function ns.FieldFadeClose(frame)
	if frame.closing then
		return
	end
	frame.closing = true
	for _, box in ipairs(frame.boxes) do
		box:ClearFocus()
	end
	PlaySound(ns.FIELD_SOUND_CLOSE, "SFX")
	ns.StopMotion(frame)
	ns.Animate(frame, {
		{
			dur = 0.15,
			ease = ns.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { frame:GetAlpha() } }, { 1, { 0 } } },
			apply = function(values)
				frame:SetAlpha(values[1])
			end,
		},
	}, function()
		ns.FieldCloseNow(frame)
	end)
end

--- Keeps `box` showing `read()`: whatever the player types is put back, selected again, so the text stays as built
--- and Ctrl+C still copies all of it. It is selected whenever it gets the focus, and Esc in it closes `frame`, since a
--- focused edit box takes Esc before UISpecialFrames does. With `fromStart`, its cursor goes back to the start whenever
--- its text is put back and when it loses the focus, so a line too long for it reads from its beginning: SetText
--- leaves the cursor at the end, and the box scrolled there.
---@param frame PagleFieldWindow
---@param box EditBox
---@param read fun(): string
---@param fromStart boolean?
function ns.FieldKeepText(frame, box, read, fromStart)
	box:SetAutoFocus(false)
	box:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(read())
			if fromStart then
				self:SetCursorPosition(0)
			end
			self:HighlightText()
		end
	end)
	box:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	if fromStart then
		box:SetScript("OnEditFocusLost", function(self)
			self:SetCursorPosition(0)
		end)
	end
	box:SetScript("OnEscapePressed", function()
		ns.FieldCloseNow(frame)
	end)
end

--- A brass button 44 square on `frame`, drawn as sprite `name` of the Field atlas.
---@param frame Frame
---@param name string
---@return PagleFieldBrassButton
function ns.FieldBrassButton(frame, name)
	local made = CreateFrame("Button", nil, frame) --[[@as PagleFieldBrassButton]]
	made:SetSize(CORNER_SIZE, CORNER_SIZE)
	made.art = ns.ArtSprite(made, "Field", name)
	ns.PlaceSprite(made.art, made, 0, 0)
	return made
end

--- Greys an arrow that can't page further, and stops it taking clicks.
---@param arrow PagleFieldBrassButton
---@param enabled boolean
function ns.FieldSetArrow(arrow, enabled)
	arrow:SetEnabled(enabled)
	arrow.art:SetDesaturated(not enabled)
	if enabled then
		arrow.art:SetVertexColor(1, 1, 1)
	else
		arrow.art:SetVertexColor(0.85, 0.85, 0.85)
	end
end

--- The leather button on `frame`, reading `word`: the kit's button, three-sliced to fit it.
---@param frame Frame
---@param word string
---@return Button
function ns.FieldLeatherButton(frame, word)
	local made = CreateFrame("Button", nil, frame) --[[@as Button]]
	local leather = CreateFrame("Frame", nil, made)
	leather:SetPoint("TOPLEFT")
	-- The word on a frame above the leather's.
	local words = CreateFrame("Frame", nil, made)
	words:SetAllPoints()
	words:SetFrameLevel(leather:GetFrameLevel() + 1)
	local label = ns.FieldText(words, "Button")
	label:SetJustifyH("CENTER")
	label:SetText(word)
	label:SetPoint("CENTER", made, "CENTER")
	local width = math.floor(label:GetStringWidth() + 52 + 0.5)
	ns.SetThreeSlice(leather, "Field", "button", width, 12, "ARTWORK")
	made:SetSize(width, 40)
	return made
end

--- A sea chart window named `name` (UISpecialFrames takes names, and Esc hides the frames it lists), `width` by
--- `height`, centred: the chart, the compass and `title` beside it, the brass X, and `privacy` with `copyHint` beside
--- it. Its own frame, with no template, so it is the chart's size and nothing anchors it over the screen (#250). It is
--- hidden until it first shows, and Esc with no edit box focused hides it at once, with the close sound unless a fade
--- already played it, leaving it at rest for its next opening.
---@param name string
---@param width number
---@param height number
---@param title string
---@param privacy string
---@param copyHint string
---@return PagleFieldWindow
function ns.NewFieldWindow(name, width, height, title, privacy, copyHint)
	local frame = CreateFrame("Frame", name, UIParent) --[[@as PagleFieldWindow]]
	frame:SetSize(width, height)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:SetClampedToScreen(true)
	frame.boxes = {}

	frame.chart = ns.ArtSprite(frame, "Chart", "chart", "BACKGROUND")
	local compass = ns.ArtSprite(frame, "Field", "compass")
	ns.PlaceSprite(compass, frame, 22, 16)
	-- The title ends before the brass X, set smaller if it must (down to TITLE_FLOOR), then cut by the client.
	frame.title = ns.FieldText(frame, "Title")
	frame.title:SetPoint("LEFT", frame, "TOPLEFT", TITLE_X, -33)
	frame.title:SetText(title)
	ns.FieldFitText(frame.title, "Title", width - CORNER_X - CORNER_SIZE - GAP - TITLE_X, TITLE_FLOOR)
	frame.closeCorner = ns.FieldBrassButton(frame, "close")
	frame.closeCorner:SetPoint("TOPRIGHT", -CORNER_X, -10)
	frame.closeCorner:SetScript("OnClick", function()
		ns.FieldFadeClose(frame)
	end)
	-- The copy hint at the right, whole; the privacy line before it, set smaller if it must (down to PRIVACY_FLOOR),
	-- then on two lines, so the two never overprint.
	frame.copyHint = ns.FieldText(frame, "CopyHint")
	frame.copyHint:SetPoint("TOPRIGHT", -MARGIN, -56)
	frame.copyHint:SetText(copyHint)
	frame.copyHint:SetWidth(0) -- measured unbounded
	local hintWidth = frame.copyHint:GetStringWidth()
	frame.privacy = ns.FieldText(frame, "Privacy")
	frame.privacy:SetPoint("TOPLEFT", MARGIN, -58)
	frame.privacy:SetText(privacy)
	ns.FieldFitText(frame.privacy, "Privacy", width - 2 * MARGIN - hintWidth - GAP, PRIVACY_FLOOR, 2)

	-- Hidden until it first opens, before its OnHide is set, so building it plays nothing.
	frame:Hide()
	frame:SetScript("OnHide", function()
		if not frame.closing then
			PlaySound(ns.FIELD_SOUND_CLOSE, "SFX")
		end
		frame.closing = false
		ns.StopMotion(frame)
		frame:SetAlpha(1)
		ns.FieldCloseNow(frame)
	end)
	table.insert(UISpecialFrames, name)
	return frame
end
