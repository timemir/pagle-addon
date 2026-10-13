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

local widgets = {}

-- Widget methods that only lay out or colour: nothing for a spec to read back.
local LAYOUT_METHODS = {
	"SetPoint",
	"ClearAllPoints",
	"SetAllPoints",
	"SetSize",
	"SetWidth",
	"SetHeight",
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetTextColor",
	"SetFontObject",
	"SetEnabled",
	"SetAlpha",
	"SetFrameStrata",
	"EnableMouse",
	"SetTexCoord",
	"SetScrollChild",
	"EnableMouseWheel",
	"SetRotation",
	"SetAutoFocus",
	"ClearFocus",
	"SetTextInsets",
	"SetMaxLetters",
}

--- A widget (frame, button or font string) that keeps what specs read back: its text, whether it's shown, its
--- scripts and the widgets created on it.
---@param kind string "Frame", "Button", "FontString", …
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
	-- A texture's tint, as { r, g, b }, and whether it is drawn in greys.
	function widget:SetVertexColor(r, g, b)
		self.vertexColor = { r, g, b }
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
	-- As a mouse click does: OnClick with the button, not down.
	function widget:Click()
		local onClick = self.scripts.OnClick
		if onClick then
			onClick(self, "LeftButton", false)
		end
	end
	function widget:CreateFontString()
		return widgets.newWidget("FontString", self)
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
