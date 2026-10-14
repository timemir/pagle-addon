---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Timber, the free default toast style (ANN-R80), the one style the toast, Nod, banner, splash and card frames are
-- drawn in: dark planks with a worn brass edge, gold headings, and stamps coloured like prototypes/catch-feedback/
-- (variant A)'s. Only Timber exists in M2; the other styles come as Curio Shop goods (M4), which swap this one
-- style. A style changes only the look, never timing or rules.

--- Timber's colours, each { r, g, b[, a] }.
ns.TIMBER = {
	wood = { 0.16, 0.11, 0.07, 0.94 },
	edge = { 0.54, 0.42, 0.25, 1 },
	band = { 0, 0, 0, 0.6 }, -- the banner's band
	titleBand = { 0.18, 0.15, 0.12, 1 }, -- a card's title band
	well = { 0, 0, 0, 0.42 }, -- a card's numbers
	gold = { 1, 0.82, 0 },
	dim = { 0.66, 0.62, 0.55 },
	more = { 0.62, 0.82, 1 },
	stamp = { 0.70, 0.13, 0.10, 1 },
	stampsMore = { 0.33, 0.33, 0.33, 1 },
	coins = { 0.63, 0.47, 0, 1 },
	record = { 0.82, 0.46, 0.10, 1 },
	track = { 0.10, 0.08, 0.05, 1 },
	fill = { 1, 0.75, 0.30, 1 },
	mark = { 0.81, 0.78, 0.70, 1 },
	passed = { 1, 0.35, 0.23, 1 },
	shade = { 0, 0, 0, 0.8 },
	parchment = { 0.93, 0.87, 0.72, 1 },
	parchmentEdge = { 0.54, 0.35, 0.10, 1 },
	ink = { 0.23, 0.15, 0.06 },
	legend = { 0.63, 0.29, 0 },
}

--- Trade_Fishing, for a moment with no icon.
ns.DEFAULT_ICON = 136245

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

--- A solid texture on `frame`, filling it unless placed afterwards.
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

--- A frame's background and a `size`-pixel edge on `sides` (default all four): "top", "bottom", "left", "right".
---@param frame Frame
---@param background number[]
---@param edge number[]
---@param size number
---@param sides string[]?
function ns.Framed(frame, background, edge, size, sides)
	ns.SolidTexture(frame, background)
	local SIDES = {
		top = { "TOPLEFT", "TOPRIGHT", "SetHeight" },
		bottom = { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
		left = { "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
		right = { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
	}
	for _, name in ipairs(sides or { "top", "bottom", "left", "right" }) do
		local side = SIDES[name]
		local line = frame:CreateTexture(nil, "BORDER")
		line:SetColorTexture(edge[1], edge[2], edge[3], edge[4])
		line:SetPoint(side[1])
		line:SetPoint(side[2])
		if side[3] == "SetHeight" then
			line:SetHeight(size)
		else
			line:SetWidth(size)
		end
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
