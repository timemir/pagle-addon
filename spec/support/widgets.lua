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
---@field frames table[] Every frame CreateFrame made, in order.
---@field focus table? The edit box with the keyboard focus, if any: the one SetFocus was called on last, until its
--- ClearFocus or another one's SetFocus.

local widgets = {}

-- Widget methods that only lay out or colour: nothing for a spec to read back.
local LAYOUT_METHODS = {
	"SetAllPoints",
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetFrameStrata",
	"SetClampedToScreen",
	"RegisterForDrag",
	"EnableMouse",
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

--- A widget (frame, button or font string) that keeps what specs read back: its text, whether it's shown, its
--- scripts and the widgets created on it.
---@param kind string "Frame", "Button", "FontString", â€¦
---@param parent table?
---@return table
function widgets.newWidget(kind, parent)
	---@type table<string, any>
	local widget = { kind = kind, shown = true, scripts = {}, children = {} }
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
	function widget:SetMovable(movable)
		self.movable = movable
	end
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
	-- Its anchors as SetPoint gave them, in order, each { point, relativeTo, relativePoint, x, y } as passed; a second
	-- SetPoint of the same point replaces the first, and ClearAllPoints drops them all. The fake lays nothing out.
	widget.points = {}
	function widget:SetPoint(point, ...)
		for i, anchor in ipairs(self.points) do
			if anchor[1] == point then
				table.remove(self.points, i)
				break
			end
		end
		self.points[#self.points + 1] = { point, ... }
	end
	function widget:ClearAllPoints()
		self.points = {}
	end
	function widget:GetNumPoints()
		return #self.points
	end
	function widget:GetPoint(index)
		local anchor = self.points[index or 1]
		if anchor then
			return anchor[1], anchor[2], anchor[3], anchor[4], anchor[5]
		end
	end
	-- Whether the player is dragging it, from StartMoving to StopMovingOrSizing; while they are, a spec plays the
	-- client moving it by setting `screenRight` and `screenTop`, its right and top edges as GetRight and GetTop read
	-- them (nil until set: the fake lays nothing out).
	function widget:StartMoving()
		self.moving = true
		self.userPlaced = true -- as the client does
	end
	function widget:StopMovingOrSizing()
		self.moving = false
	end
	function widget:GetRight()
		return self.screenRight
	end
	function widget:GetTop()
		return self.screenTop
	end
	-- A texture's tint, as { r, g, b[, a] }, and whether it is drawn in greys.
	function widget:SetVertexColor(r, g, b, a)
		self.vertexColor = { r, g, b, a }
	end
	-- Its size as set, for layout code that reads it back.
	function widget:SetSize(width, height)
		self.width, self.height = width, height
	end
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
	-- A font string's colour ({ r, g, b[, a] }), and its font: `fontObject` (its template or SetFontObject's name), or
	-- `font` ({ file, size, flags }) after SetFont, until the next SetFontObject.
	function widget:SetTextColor(r, g, b, a)
		self.textColor = { r, g, b, a }
	end
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
	-- A region's opacity (1 until set).
	function widget:SetAlpha(alpha)
		self.alpha = alpha
	end
	function widget:GetAlpha()
		return self.alpha or 1
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
	function widget:SetDesaturated(desaturated)
		self.desaturated = desaturated
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
	-- A texture that keeps what it shows: `texture` (SetTexture's file ID or path) or `color` ({ r, g, b, a }).
	function widget:CreateTexture()
		local texture = widgets.newWidget("Texture", self)
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

--- Adds the children and methods a FrameXML template gives a frame, as far as Pagle reads them. Gethe/wow-ui-source
--- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"), Interface/AddOns/Blizzard_SharedXML/:
--- ButtonFrameTemplate (Mainline/SharedUIPanelTemplates.xml) has an `Inset` frame, a `CloseButton` whose click hides
--- its parent (UIPanelCloseButton_OnClick, HideUIPanel), the title (PortraitFrame.lua's TitledPanelMixin:SetTitle)
--- and a portrait (PortraitFrameMixin:SetPortraitToAsset); SearchBoxTemplate (Shared/InputBox/InputBoxTemplates.xml)
--- has its `Instructions` hint and its `clearButton`. Other templates add nothing here.
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
	end
end

return widgets
