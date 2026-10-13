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
	"ClearAllPoints",
	"SetAllPoints",
	"SetSize",
	"SetWidth",
	"SetHeight",
	"SetJustifyH",
	"SetJustifyV",
	"SetWordWrap",
	"SetFontObject",
	"SetEnabled",
}

--- A widget (frame, button or font string) that keeps what specs read back: its text, whether it's shown, its
--- scripts and the widgets created on it, its parent, anchors (`points`, each SetPoint's arguments), alpha, text
--- colour (`textColor`, { r, g, b }), a font string's font object (`fontObject`, CreateFontString's template), and
--- a button's attributes (`attributes`) and click registration (`clicks`, RegisterForClicks's arguments).
---@param kind string "Frame", "Button", "FontString", …
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
