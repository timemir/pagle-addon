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
	"SetAllPoints",
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetClampedToScreen",
	"SetFrameStrata",
	"SetUserPlaced",
	"SetScrollChild",
	"EnableMouseWheel",
	"SetRotation",
	"SetAutoFocus",
	"ClearFocus",
	"SetTextInsets",
	"SetMaxLetters",
	"SetMultiLine",
	"SetCursorPosition",
}

--- A widget (frame, button, font string or texture) that keeps what specs read back: its text, whether it's shown,
--- its scripts and the widgets created on it, its parent, anchors (`points`, each SetPoint's arguments, emptied by
--- ClearAllPoints), size (`width`, `height`, as SetSize, SetWidth and SetHeight set them), alpha, text colour
--- (`textColor`, { r, g, b[, a] }), a font string's font object (`fontObject`, CreateFontString's template or
--- SetFontObject's) or SetFont's `font`, a texture's file (`texture`), whether it's desaturated (`desaturated`), its
--- tint (`vertexColor`, { r, g, b[, a] }), blend mode (`blendMode`) and coordinates (`texCoord`), a button's attributes
--- (`attributes`), click registration (`clicks`, RegisterForClicks's arguments) and locked highlight
--- (`highlightLocked`), and a frame's mouse and moving state: `mouseEnabled`, `movable`, `dragButtons`
--- (RegisterForDrag's arguments) and `moving`; also whether it takes clicks (`enabled`) and a scroll frame's
--- `verticalScroll`.
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
	function widget:SetPoint(...)
		self.points[#self.points + 1] = { ... }
	end
	function widget:SetSize(width, height)
		self.width, self.height = width, height
	end
	function widget:ClearAllPoints()
		self.points = {}
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
	function widget:GetAlpha()
		return self.alpha
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
	-- A texture's tint, as { r, g, b[, a] }.
	function widget:SetVertexColor(r, g, b, a)
		self.vertexColor = { r, g, b, a }
	end
	-- Its size as set, for layout code that reads it back (SetSize above sets both).
	function widget:SetWidth(width)
		self.width = width
	end
	function widget:SetHeight(height)
		self.height = height
	end
	function widget:GetWidth()
		return self.width or 0
	end
	function widget:GetHeight()
		return self.height or 0
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
	function widget:Show()
		self.shown = true
	end
	function widget:Hide()
		self.shown = false
	end
	function widget:SetShown(shown)
		self.shown = not not shown
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
	-- As a mouse click does: OnClick with the button, not down. A disabled button ignores it.
	function widget:Click()
		local onClick = self.scripts.OnClick
		if onClick and self.enabled ~= false then
			onClick(self, "LeftButton", false)
		end
	end
	function widget:CreateFontString(_, _, template)
		local fontString = widgets.newWidget("FontString", self)
		fontString.fontObject = template
		return fontString
	end
	-- A texture that keeps its layer and what it shows: `texture` (SetTexture's file ID or path) or `color`
	-- ({ r, g, b, a }).
	function widget:CreateTexture(_, layer)
		local texture = widgets.newWidget("Texture", self)
		texture.layer = layer
		texture.SetTexture = function(region, file)
			region.texture = file
		end
		texture.SetColorTexture = function(region, r, g, b, a)
			region.color = { r, g, b, a }
		end
		return texture
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

--- Adds the children and methods a FrameXML template gives a frame, as far as Pagle reads them. Gethe/wow-ui-source
--- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/:
--- ButtonFrameTemplate (Mainline/SharedUIPanelTemplates.xml) has an `Inset` frame, a `CloseButton` whose click hides
--- its parent (UIPanelCloseButton_OnClick, HideUIPanel), the title (PortraitFrame.lua's TitledPanelMixin:SetTitle)
--- and a portrait (PortraitFrameMixin:SetPortraitToAsset); SearchBoxTemplate (Shared/InputBox/InputBoxTemplates.xml)
--- has its `Instructions` hint and its `clearButton`; UICheckButtonTemplate (Shared/Button/CheckButtonTemplates.xml)
--- has its label, `Text`. Other templates add nothing here.
---@param client FakeClient
---@param frame table
---@param template string?
function widgets.applyTemplate(client, frame, template)
	if template == "ButtonFrameTemplate" then
		frame.Inset = widgets.newFrame(client, "Frame", frame)
		frame.CloseButton = widgets.newFrame(client, "Button", frame)
		frame.CloseButton:SetScript("OnClick", function()
			if frame:IsShown() then
				frame:Hide()
				local onHide = frame:GetScript("OnHide")
				if onHide then
					onHide(frame)
				end
			end
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
	end
end

return widgets
