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

local widgets = {}

-- Widget methods that only lay out or colour: nothing for a spec to read back.
local LAYOUT_METHODS = {
	"SetAllPoints",
	"SetWidth",
	"SetHeight",
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetFontObject",
	"SetEnabled",
	"SetTexCoord",
	"SetClampedToScreen",
	"SetFrameStrata",
	"SetUserPlaced",
}

--- A widget (frame, button, font string or texture) that keeps what specs read back: its text, whether it's shown,
--- its scripts and the widgets created on it, its parent, anchors (`points`, each SetPoint's arguments, emptied by
--- ClearAllPoints), size (`width`, `height`, as SetSize set them), alpha, text colour (`textColor`, { r, g, b }), a font string's font object (`fontObject`,
--- CreateFontString's template), a texture's file (`texture`) and whether it's desaturated (`desaturated`), a
--- button's attributes (`attributes`) and click registration (`clicks`, RegisterForClicks's arguments), and a frame's
--- mouse and moving state: `mouseEnabled`, `movable`, `dragButtons` (RegisterForDrag's arguments) and `moving`.
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
	function widget:SetTextColor(r, g, b)
		self.textColor = { r, g, b }
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
	-- As a mouse click does: OnClick with the button, not down.
	function widget:Click()
		local onClick = self.scripts.OnClick
		if onClick then
			onClick(self, "LeftButton", false)
		end
	end
	function widget:CreateFontString(_, _, template)
		local fontString = widgets.newWidget("FontString", self)
		fontString.fontObject = template
		return fontString
	end
	function widget:CreateTexture(_, layer)
		local texture = widgets.newWidget("Texture", self)
		texture.layer = layer
		return texture
	end
	for _, method in ipairs(LAYOUT_METHODS) do
		widget[method] = function() end
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
	client.frames[#client.frames + 1] = frame
	return frame
end

return widgets
