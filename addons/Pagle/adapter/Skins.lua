---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Which toast style a frame is drawn in (ANN-R80), a moment's icon as a texture, and the plain pieces Core's other
-- frames are drawn from: solid textures, edges, font strings and native buttons. The announcement frames' own art is
-- adapter/Art.lua's.

--- The toast style equipped in Core's slot (SHOP-R32), or Timber when none is (ANN-R80).
---@return PagleToastStyle
function ns.EquippedToastStyle()
	return ns.ToastStyleOf(ns.goods:GetEquipped(ns.TOAST_STYLE_SLOT))
end

--- The toast style a display is drawn in (ANN-R80): the one it carries (a sample's), else the equipped one.
---@param display PagleDisplay?
---@return PagleToastStyle
function ns.DisplayStyle(display)
	local style = display and display.announcement.style
	return style and ns.ToastStyleOf(style) or ns.EquippedToastStyle()
end

--- A moment's icon as a texture (announcements.md › Contracts): an item ID's icon, else the number as a file ID, or a
--- texture path. Item IDs and icon file IDs don't overlap in practice: the client's item table answers only items.
---@param icon integer|string|nil
---@return integer|string
function ns.TextureOf(icon)
	if type(icon) == "number" then
		local _, _, _, _, fileID = C_Item.GetItemInfoInstant(icon)
		return fileID or icon
	end
	return icon or ns.DEFAULT_ICON
end

-- A `size`-pixel line on each of `sides` of `frame` (default all four): "top", "bottom", "left", "right".
---@param frame Frame
---@param size number
---@param sides string[]?
---@return Texture[]
local function edgeLines(frame, size, sides)
	local SIDES = {
		top = { "TOPLEFT", "TOPRIGHT", "SetHeight" },
		bottom = { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
		left = { "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
		right = { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
	}
	local lines = {}
	for _, name in ipairs(sides or { "top", "bottom", "left", "right" }) do
		local side = SIDES[name]
		local line = frame:CreateTexture(nil, "BORDER")
		line:SetPoint(side[1])
		line:SetPoint(side[2])
		if side[3] == "SetHeight" then
			line:SetHeight(size)
		else
			line:SetWidth(size)
		end
		lines[#lines + 1] = line
	end
	return lines
end

--- A solid texture on `frame` in `color`, filling it unless placed afterwards.
---@param frame Frame
---@param color number[]
---@param layer DrawLayer?
---@return Texture
function ns.SolidTexture(frame, color, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetColorTexture(color[1], color[2], color[3], color[4])
	texture:SetAllPoints()
	return texture
end

--- A frame's background in `background` and a `size`-pixel edge in `edge` on `sides` (default all four).
---@param frame Frame
---@param background number[]
---@param edge number[]
---@param size number
---@param sides string[]?
function ns.Framed(frame, background, edge, size, sides)
	ns.SolidTexture(frame, background)
	for _, line in ipairs(edgeLines(frame, size, sides)) do
		line:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
	end
end

--- A font string on `frame` in `template`, in `color` if given.
---@param frame Frame
---@param template string
---@param color number[]?
---@return FontString
function ns.Text(frame, template, color)
	local fontString = frame:CreateFontString(nil, "OVERLAY", template)
	if color then
		fontString:SetTextColor(color[1], color[2], color[3])
	end
	return fontString
end

--- A button with the native look (UIPanelButtonTemplate) on `parent` reading `label`, `width` wide (or as wide as its
--- text and 10 pixels each side) and `height` high (22), running `onClick` when clicked, if given.
---@param parent Frame
---@param label string
---@param width number?
---@param height number?
---@param onClick fun()?
---@return Button
function ns.PanelButton(parent, label, width, height, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate") --[[@as Button]]
	button:SetText(label)
	button:SetSize(width or button:GetTextWidth() + 20, height or 22)
	if onClick then
		button:SetScript("OnClick", onClick)
	end
	return button
end
