-- The fake client's widgets: frames, buttons and font strings that keep what specs read back, and frames that keep
-- the events they register, so client.fire reaches them. spec/support/addon.lua loads this file once; client.lua
-- builds CreateFrame on newFrame, and settings.lua draws its pages with newWidget.
--
--   local widgets = dofile("spec/support/widgets.lua")
--   local frame = widgets.newFrame(client, "Frame")   -- listed in client.frames
--   local label = widgets.newWidget("FontString", frame)

---@class FakeClient
---@field missingEvents table<string, true> Events this client doesn't know: registering one raises an error, as the
--- client does. Specs add to it.
---@field frames table[] Every frame CreateFrame made, in order. A named one is also the load's global of that name.
---@field focus table? The edit box with the keyboard focus, if any: the one SetFocus was called on last, until its
--- ClearFocus or another one's SetFocus.

local widgets = {}

-- Widget methods that only lay out or colour: nothing for a spec to read back.
local LAYOUT_METHODS = {
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetClampedToScreen",
	"SetFrameStrata",
	"EnableMouseWheel",
	"SetRotation",
	"SetAutoFocus",
	"ClearFocus",
	"SetTextInsets",
	"SetMaxLetters",
	"SetMultiLine",
	"SetCursorPosition",
	"SetClipsChildren",
	"SetShadowColor",
	"SetShadowOffset",
	"SetSpacing",
	"SetGradient",
}

-- One anchor of `widget` as relativeTo, relativePoint, x, y: SetPoint(point, x, y) and SetPoint(point) are relative
-- to the same point of its parent, as the client's.
---@param widget table
---@param anchor table SetPoint's arguments
---@return table relativeTo
---@return string relativePoint
---@return number x
---@return number y
local function resolveAnchor(widget, anchor)
	if type(anchor[2]) == "number" then
		return widget.parent, anchor[1], anchor[2], anchor[3] or 0
	end
	return anchor[2] or widget.parent, anchor[3] or anchor[1], anchor[4] or 0, anchor[5] or 0
end

-- `widget`'s extent along one axis (`low` and `high` its edges: "LEFT" and "RIGHT", or "BOTTOM" and "TOP"), as the
-- client lays it out: anchors on both edges stretch it between them, whatever its size; otherwise it is as wide or
-- as tall as SetSize, SetWidth or SetHeight made it.
---@param widget table
---@param low string
---@param high string
---@return number?
local function extent(widget, low, high)
	local axis = low == "LEFT" and "width" or "height"
	local lowAnchor, highAnchor
	for _, anchor in ipairs(widget.points) do
		if anchor[1]:find(low) then
			lowAnchor = anchor
		elseif anchor[1]:find(high) then
			highAnchor = anchor
		end
	end
	if not (lowAnchor and highAnchor) then
		return widget[axis]
	end
	-- Where an anchor puts that edge along its relative frame: 0 at the frame's low edge, its extent at the high one.
	local function edge(anchor)
		local relativeTo, relativePoint, x, y = resolveAnchor(widget, anchor)
		local size = assert(extent(relativeTo, low, high), "FakeClient: anchored to a frame with no size")
		local at = relativePoint:find(high) and size or relativePoint:find(low) and 0 or size / 2
		return at + (axis == "width" and x or y)
	end
	assert(resolveAnchor(widget, lowAnchor) == resolveAnchor(widget, highAnchor), "FakeClient: edges on two frames")
	return edge(highAnchor) - edge(lowAnchor)
end

--- A widget (frame, button, font string or texture) that keeps what specs read back: its text, whether it's shown,
--- its scripts and the widgets created on it, its parent, anchors (`points`, each SetPoint's arguments, emptied by
--- ClearAllPoints, replaced by SetAllPoints), size (`width`, `height`, as SetSize, SetWidth and SetHeight set them;
--- GetWidth, GetHeight and GetSize lay it out from its anchors as the client does), alpha, text colour (`textColor`,
--- { r, g, b[, a] }), a font string's font object (`fontObject`, CreateFontString's template or SetFontObject's) or
--- SetFont's `font`, a texture's file (`texture`), whether it's desaturated (`desaturated`), its tint (`vertexColor`,
--- { r, g, b[, a] }), blend mode (`blendMode`) and coordinates (`texCoord`), a button's attributes (`attributes`),
--- click registration (`clicks`, RegisterForClicks's arguments) and locked highlight (`highlightLocked`), and a
--- frame's mouse and moving state: `mouseEnabled`, `movable`, `dragButtons` (RegisterForDrag's arguments) and
--- `moving`, and `userPlaced` (SetUserPlaced's, or true from StartMoving); also whether it takes clicks (`enabled`)
--- and key presses (`keyboardEnabled`), and a scroll frame's `verticalScroll` and `scrollChild`. As the client's,
--- Show, Hide and SetShown run OnShow or OnHide when the shown state changes, and SetSize, SetWidth and SetHeight run
--- OnSizeChanged when the size does.
---@param kind string "Frame", "Button", "FontString", "Texture", …
---@param parent table?
---@return table
function widgets.newWidget(kind, parent)
	---@type table<string, any>
	local widget = {
		kind = kind,
		parent = parent,
		shown = true,
		alpha = 1,
		scripts = {},
		children = {},
		points = {},
		attributes = {},
	}
	-- As the client's: a second SetPoint of the same point replaces the first.
	function widget:SetPoint(point, ...)
		for i, anchor in ipairs(self.points) do
			if anchor[1] == point then
				table.remove(self.points, i)
				break
			end
		end
		self.points[#self.points + 1] = { point, ... }
	end
	-- As the client's: a change of size runs OnSizeChanged(width, height), after the change.
	local function resized(self, width, height)
		local before = { self.width, self.height }
		self.width, self.height = width, height
		local script = self.scripts.OnSizeChanged
		if script and (before[1] ~= width or before[2] ~= height) then
			script(self, width, height)
		end
	end
	function widget:SetSize(width, height)
		resized(self, width, height)
	end
	function widget:ClearAllPoints()
		self.points = {}
	end
	-- As the client's: anchored over all of `relativeTo` (its parent by default), in place of any earlier anchors.
	function widget:SetAllPoints(relativeTo)
		relativeTo = relativeTo or self.parent
		self.points = { { "TOPLEFT", relativeTo, "TOPLEFT", 0, 0 }, { "BOTTOMRIGHT", relativeTo, "BOTTOMRIGHT", 0, 0 } }
	end
	function widget:SetWidth(width)
		resized(self, width, self.height)
	end
	function widget:SetHeight(height)
		resized(self, self.width, height)
	end
	-- Its laid-out size: stretched between anchors on opposite edges when it has them, else as set (see extent), 0
	-- with neither, as the client's for a frame with no size.
	function widget:GetWidth()
		return extent(self, "LEFT", "RIGHT") or 0
	end
	function widget:GetHeight()
		return extent(self, "BOTTOM", "TOP") or 0
	end
	function widget:GetSize()
		return self:GetWidth(), self:GetHeight()
	end
	function widget:SetScrollChild(child)
		self.scrollChild = child
	end
	-- point, relativeTo, relativePoint, x, y of the anchor at `index` (default 1).
	function widget:GetPoint(index)
		return unpack(self.points[index or 1] or {})
	end
	function widget:SetTexture(texture)
		self.texture = texture
	end
	function widget:GetTexture()
		return self.texture
	end
	-- Its scale (1 until set).
	function widget:SetScale(scale)
		self.scale = scale
	end
	function widget:GetScale()
		return self.scale or 1
	end
	-- A mask texture, and the masks a texture is drawn through (`masks`).
	function widget:CreateMaskTexture()
		local mask = widgets.newWidget("MaskTexture", self)
		mask.SetTexture = function(region, file)
			region.texture = file
		end
		return mask
	end
	function widget:AddMaskTexture(mask)
		self.masks = self.masks or {}
		self.masks[#self.masks + 1] = mask
	end
	function widget:SetDesaturated(desaturated)
		self.desaturated = not not desaturated
	end
	function widget:IsDesaturated()
		return self.desaturated == true
	end
	function widget:EnableMouse(enabled)
		self.mouseEnabled = not not enabled
	end
	function widget:SetMovable(movable)
		self.movable = not not movable
	end
	function widget:RegisterForDrag(...)
		self.dragButtons = { ... }
	end
	-- As the client's: only a movable frame moves.
	function widget:StartMoving()
		assert(self.movable, "FakeClient: StartMoving on a frame that isn't movable")
		self.moving = true
		self.userPlaced = true -- as the client does
	end
	function widget:StopMovingOrSizing()
		if self.moving and self.movedTo then
			self.points = { self.movedTo }
		end
		self.moving, self.movedTo = false, nil
	end
	-- As a left-button drag with the mouse does: OnDragStart if the frame registered for it, then, if that started
	-- moving it, the frame ends up anchored as `to` ({ point, relativeTo, relativePoint, x, y }, as GetPoint reads it
	-- after StopMovingOrSizing), then OnDragStop.
	function widget:Drag(to)
		local registered = false
		for _, button in ipairs(self.dragButtons or {}) do
			registered = registered or button == "LeftButton" or button == "AnyUp" or button == "AnyDown"
		end
		if not registered then
			return
		end
		if self.scripts.OnDragStart then
			self.scripts.OnDragStart(self, "LeftButton")
		end
		if self.moving then
			self.movedTo = to
		end
		if self.scripts.OnDragStop then
			self.scripts.OnDragStop(self)
		end
	end
	function widget:SetAlpha(alpha)
		self.alpha = alpha
	end
	-- A region's opacity (1 until set, as the client).
	function widget:GetAlpha()
		return self.alpha or 1
	end
	function widget:SetTextColor(r, g, b, a)
		self.textColor = { r, g, b, a }
	end
	function widget:SetAttribute(name, value)
		self.attributes[name] = value
	end
	function widget:GetAttribute(name)
		return self.attributes[name]
	end
	function widget:RegisterForClicks(...)
		self.clicks = { ... }
	end
	function widget:SetText(text)
		self.text = text
	end
	function widget:GetText()
		return self.text
	end
	-- 6 pixels a character: enough for layout code to size around a text.
	function widget:GetStringWidth()
		return #(self.text or "") * 6
	end
	-- One 14-pixel line, as a text that doesn't wrap.
	function widget.GetStringHeight()
		return 14
	end
	-- Whether SetMovable(true) let the player drag it.
	function widget:IsMovable()
		return self.movable == true
	end
	-- Whether the client would save where the player moved it (SetUserPlaced; StartMoving sets it, as the client
	-- does).
	function widget:SetUserPlaced(userPlaced)
		self.userPlaced = userPlaced
	end
	function widget:IsUserPlaced()
		return self.userPlaced == true
	end
	function widget:GetNumPoints()
		return #self.points
	end
	-- Its right and top edges on the screen: a spec plays the client moving it during a drag by setting
	-- `screenRight` and `screenTop` (nil until set: the fake lays out no screen position).
	function widget:GetRight()
		return self.screenRight
	end
	function widget:GetTop()
		return self.screenTop
	end
	-- A texture's tint, as { r, g, b[, a] }.
	function widget:SetVertexColor(r, g, b, a)
		self.vertexColor = { r, g, b, a }
	end
	-- A font string's font: `fontObject` (its template or SetFontObject's name), or `font` ({ file, size, flags })
	-- after SetFont, until the next SetFontObject.
	function widget:SetFontObject(fontObject)
		self.fontObject, self.font = fontObject, nil
	end
	function widget:SetFont(file, size, flags)
		self.font = { file, size, flags }
		return true
	end
	-- A texture's blend mode and texture coordinates ({ left, right, top, bottom }).
	function widget:SetBlendMode(mode)
		self.blendMode = mode
	end
	function widget:SetTexCoord(left, right, top, bottom)
		self.texCoord = { left, right, top, bottom }
	end
	-- Its frame level: one above its parent's (0 for a frame with none) until SetFrameLevel sets it, as the client
	-- stacks children over their parent.
	function widget:SetFrameLevel(level)
		self.frameLevel = level
	end
	function widget:GetFrameLevel()
		return self.frameLevel or (parent and parent:GetFrameLevel() + 1 or 0)
	end
	-- A button's text width, 6 pixels a character as GetStringWidth; and whether its highlight is locked on.
	function widget:GetTextWidth()
		return #(self.text or "") * 6
	end
	function widget:LockHighlight()
		self.highlightLocked = true
	end
	function widget:UnlockHighlight()
		self.highlightLocked = false
	end
	-- A scroll frame's offset; nothing overflows here, so its range is 0.
	function widget:SetVerticalScroll(offset)
		self.verticalScroll = offset
	end
	function widget:GetVerticalScroll()
		return self.verticalScroll or 0
	end
	function widget.GetVerticalScrollRange()
		return 0
	end
	-- As the client's: a change of shown state runs OnShow or OnHide, after the change; no change runs neither.
	function widget:SetShown(shown)
		shown = not not shown
		if self.shown == shown then
			return
		end
		self.shown = shown
		local script = self.scripts[shown and "OnShow" or "OnHide"]
		if script then
			script(self)
		end
	end
	function widget:Show()
		self:SetShown(true)
	end
	function widget:Hide()
		self:SetShown(false)
	end
	function widget:IsShown()
		return self.shown
	end
	function widget:SetScript(script, fn)
		self.scripts[script] = fn
	end
	function widget:GetScript(script)
		return self.scripts[script]
	end
	-- Runs `fn` after the script already set, as the client's HookScript does.
	function widget:HookScript(script, fn)
		local before = self.scripts[script]
		self.scripts[script] = function(...)
			if before then
				before(...)
			end
			fn(...)
		end
	end
	-- Whether it takes clicks: SetEnabled(false) greys a button, and a click on it does nothing.
	function widget:SetEnabled(enabled)
		self.enabled = not not enabled
	end
	function widget:IsEnabled()
		return self.enabled ~= false
	end
	-- As a mouse click does: OnClick with the mouse button (default "LeftButton", as Button:Click's), not down. A
	-- disabled button ignores it.
	function widget:Click(button)
		local onClick = self.scripts.OnClick
		if onClick and self.enabled ~= false then
			onClick(self, button or "LeftButton", false)
		end
	end
	-- Whether it takes key presses: client.pressKey gives a press to a shown keyboard-enabled frame first.
	function widget:EnableKeyboard(enabled)
		self.keyboardEnabled = not not enabled
	end
	function widget:IsKeyboardEnabled()
		return self.keyboardEnabled == true
	end
	-- Whether the key press its OnKeyDown is taking goes on to the bindings too (`propagatesKeys`), as
	-- Frame:SetPropagateKeyboardInput sets it.
	function widget:SetPropagateKeyboardInput(propagates)
		self.propagatesKeys = not not propagates
	end
	function widget:CreateFontString(_, layer, template)
		local fontString = widgets.newWidget("FontString", self)
		fontString.fontObject = template
		fontString.layer, fontString.sublevel = layer or "ARTWORK", 0
		return fontString
	end
	-- A texture that keeps its draw layer and sublevel, and what it shows: `texture` (SetTexture's file ID or path)
	-- or `color` ({ r, g, b, a }).
	function widget:CreateTexture(_, layer, _, sublevel)
		local texture = widgets.newWidget("Texture", self)
		texture.layer, texture.sublevel = layer or "ARTWORK", sublevel or 0
		texture.SetTexture = function(region, file)
			region.texture = file
		end
		texture.SetColorTexture = function(region, r, g, b, a)
			region.color = { r, g, b, a }
		end
		return texture
	end
	-- A texture's or font string's draw layer and sublevel, as the client's Region:GetDrawLayer/SetDrawLayer: later
	-- layers draw over earlier ones, and in one layer a higher sublevel draws over a lower.
	function widget:GetDrawLayer()
		return self.layer, self.sublevel
	end
	function widget:SetDrawLayer(layer, sublevel)
		self.layer, self.sublevel = layer, sublevel or 0
	end
	for _, method in ipairs(LAYOUT_METHODS) do
		widget[method] = function() end
	end
	function widget.GetParent()
		return parent
	end
	if parent then
		parent.children[#parent.children + 1] = widget
	end
	return widget
end

--- A frame that records the events it registers and its scripts, so client.fire can reach it.
---@param client FakeClient
---@param kind string?
---@param parent table?
---@return table
function widgets.newFrame(client, kind, parent)
	local frame = widgets.newWidget(kind or "Frame", parent)
	frame.events = {}
	local function known(event)
		if client.missingEvents[event] then
			error(('Frame:RegisterEvent(): Attempt to register unknown event "%s"'):format(event), 3)
		end
	end
	function frame:RegisterEvent(event)
		known(event)
		self.events[event] = true
	end
	function frame:RegisterUnitEvent(event, ...)
		known(event)
		local units = {}
		for i = 1, select("#", ...) do
			units[(select(i, ...))] = true
		end
		self.events[event] = units
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:UnregisterAllEvents()
		self.events = {}
	end
	if frame.kind == "EditBox" then
		widgets.editBox(client, frame)
	elseif frame.kind == "CheckButton" then
		widgets.checkButton(frame)
	elseif frame.kind == "Slider" then
		widgets.slider(frame)
	end
	client.frames[#client.frames + 1] = frame
	return frame
end

--- Makes `box` an edit box, as the client's EditBox behaves for what Pagle calls: SetText runs OnTextChanged with
--- userInput false and drops the selection; HighlightText keeps the selection in `highlight` ({ start, stop }, the
--- client's defaults 0 and -1 for all of it); SetFocus and ClearFocus move `client.focus`, SetFocus running
--- OnEditFocusGained. A spec plays the player with `box:Type(text)`: what the box holds after typing replaces its text
--- and selection, and OnTextChanged runs with userInput true.
---@param client FakeClient
---@param box table
function widgets.editBox(client, box)
	local function run(script, ...)
		local fn = box.scripts[script]
		if fn then
			fn(box, ...)
		end
	end
	function box:SetText(text)
		self.text = text
		self.highlight = nil
		run("OnTextChanged", false)
	end
	function box:HighlightText(start, stop)
		self.highlight = { start or 0, stop or -1 }
	end
	function box:SetFocus()
		if client.focus ~= self then
			client.focus = self
			run("OnEditFocusGained")
		end
	end
	function box:ClearFocus()
		if client.focus == self then
			client.focus = nil
		end
	end
	function box:HasFocus()
		return client.focus == self
	end
	function box:Type(text)
		self.text = text
		self.highlight = nil
		run("OnTextChanged", true)
	end
end

--- Makes `button` a check button, as the client's CheckButton behaves for what Pagle calls: SetChecked and GetChecked
--- keep its state, and a click (enabled) toggles it before OnClick runs.
---@param button table
function widgets.checkButton(button)
	button.checked = false
	function button:SetChecked(checked)
		self.checked = not not checked
	end
	function button:GetChecked()
		return self.checked
	end
	local click = button.Click
	function button:Click()
		if self.enabled ~= false then
			self.checked = not self.checked
		end
		click(self)
	end
end

--- Makes `slider` a Slider, as the client's behaves for what Pagle calls: its range (`minValue`, `maxValue`), its
--- value, clamped to the range, with SetValue running OnValueChanged(value, userInput false) when the value changes,
--- its orientation and its thumb texture (`thumb`).
---@param slider table
function widgets.slider(slider)
	slider.minValue, slider.maxValue, slider.value = 0, 0, 0
	function slider:SetMinMaxValues(min, max)
		self.minValue, self.maxValue = min, max
		self:SetValue(self.value)
	end
	function slider:GetMinMaxValues()
		return self.minValue, self.maxValue
	end
	function slider:SetValue(value)
		value = math.max(self.minValue, math.min(self.maxValue, value))
		if value == self.value then
			return
		end
		self.value = value
		local script = self.scripts.OnValueChanged
		if script then
			script(self, value, false)
		end
	end
	function slider:GetValue()
		return self.value
	end
	function slider:SetOrientation(orientation)
		self.orientation = orientation
	end
	function slider:SetThumbTexture(texture)
		self.thumb = texture
	end
	slider.SetValueStep = function() end
	slider.SetObeyStepOnDrag = function() end
end

--- Adds the children and methods a FrameXML template gives a frame, as far as Pagle reads them. Gethe/wow-ui-source
--- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/:
--- ButtonFrameTemplate (Mainline/SharedUIPanelTemplates.xml) has an `Inset` frame, a `CloseButton` whose click hides
--- its parent (UIPanelCloseButton_OnClick, HideUIPanel), the title (PortraitFrame.lua's TitledPanelMixin:SetTitle)
--- and a portrait (PortraitFrameMixin:SetPortraitToAsset); SearchBoxTemplate (Shared/InputBox/InputBoxTemplates.xml)
--- has its `Instructions` hint and its `clearButton`; UICheckButtonTemplate (Shared/Button/CheckButtonTemplates.xml)
--- has its label, `Text`; WowStyle1DropdownTemplate (Blizzard_Menu/DropdownButton.lua, DropdownButtonMixin and
--- DropdownSelectionTextMixin) builds its menu from SetupMenu's generator, at SetupMenu and GenerateMenu and each
--- time it opens, and shows its selected radio's text (fake: `selected`, that radio's data; `choices()` opens it and
--- returns its radios as "<data>=<text>"; `pick(choice)` opens it and clicks the radio with that text or data). Other templates add nothing
--- here.
---@param client FakeClient
---@param frame table
---@param template string?
function widgets.applyTemplate(client, frame, template)
	if template == "ButtonFrameTemplate" then
		frame.Inset = widgets.newFrame(client, "Frame", frame)
		frame.CloseButton = widgets.newFrame(client, "Button", frame)
		frame.CloseButton:SetScript("OnClick", function()
			frame:Hide()
		end)
		function frame:SetTitle(title)
			self.title = title
		end
		function frame:SetPortraitToAsset(texture)
			self.portrait = texture
		end
	elseif template == "SearchBoxTemplate" then
		frame.Instructions = widgets.newWidget("FontString", frame)
		frame.clearButton = widgets.newFrame(client, "Button", frame)
	elseif template == "UICheckButtonTemplate" then
		frame.Text = widgets.newWidget("FontString", frame)
	elseif template == "WowStyle1DropdownTemplate" then
		widgets.dropdownButton(frame)
	end
end

--- Makes `dropdown` a DropdownButton with a radio menu, as far as Pagle uses one (see applyTemplate).
---@param dropdown table
function widgets.dropdownButton(dropdown)
	local radios = {}
	function dropdown:GenerateMenu()
		radios = {}
		local root = {}
		function root.CreateRadio(_, text, isSelected, setSelected, data)
			radios[#radios + 1] = { text = text, isSelected = isSelected, setSelected = setSelected, data = data }
		end
		self.generator(self, root)
		self.text, self.selected = nil, nil
		for _, radio in ipairs(radios) do
			if radio.isSelected(radio.data) then
				self.text, self.selected = radio.text, radio.data
			end
		end
	end
	function dropdown:SetupMenu(generator)
		self.generator = generator
		self:GenerateMenu()
	end
	function dropdown:choices()
		self:GenerateMenu()
		local list = {}
		for i, radio in ipairs(radios) do
			list[i] = radio.data .. "=" .. radio.text
		end
		return list
	end
	-- As a click on a radio: its setSelected, then the menu closes and the button shows what is selected now.
	function dropdown:pick(choice)
		self:GenerateMenu()
		for _, radio in ipairs(radios) do
			if radio.text == choice or radio.data == choice then
				radio.setSelected(radio.data)
				self:GenerateMenu()
				return
			end
		end
		error("no choice " .. tostring(choice))
	end
end

return widgets
