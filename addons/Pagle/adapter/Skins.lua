---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Painting the toast, Nod, banner, splash and card frames in a toast style (ANN-R80): each frame keeps a skin, the
-- textures and font strings it drew with the colour role each takes, and ns.PaintSkin paints them all in a style
-- from logic/ToastStyles.lua. A frame is built once and repainted whenever its style changes; a style changes only
-- the look, never timing or rules.

--- Trade_Fishing, for a moment with no icon.
ns.DEFAULT_ICON = 136245

--- A texture or font string a skin paints: the colour role it takes, and a font string's own font object (a texture
--- has none) and whether it is a title (a style's title face replaces its font).
---@class PaglePainted: Region
---@field paintRole string
---@field paintTemplate string?
---@field paintTitle boolean?

--- What a frame was drawn with, to paint it in a style.
---@class PagleSkin
---@field style PagleToastStyle the style it is painted in
---@field painted PaglePainted[]
---@field background Texture? the main background, under the style's backdrop
---@field edges Texture[] its edge lines
---@field backdrop Texture? the style's backdrop texture over the background, hidden when the style has none
---@field glow Texture[] the style's rings around the icon, hidden when the style has none
---@field glowAt { frame: Frame, x: number, y: number, size: number }? the icon's centre from its frame's top left

--- The toast style equipped in Core's slot (SHOP-R32), or Timber when none is (ANN-R80).
---@return PagleToastStyle
function ns.EquippedToastStyle()
	return ns.ToastStyleOf(Pagle.GetEquipped(ns.TOAST_STYLE_SLOT))
end

--- A new skin for a frame, in the equipped style, as `frame.skin`.
---@param frame Frame
---@return PagleSkin
function ns.NewSkin(frame)
	local skin = { style = ns.EquippedToastStyle(), painted = {}, edges = {}, glow = {} }
	---@diagnostic disable-next-line: inject-field -- every skinned frame keeps its skin
	frame.skin = skin
	return skin
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

--- Paints one texture or font string of a skin in the skin's style: a texture in its role's colour, a font string in
--- its font (a title in the style's title face, if it has one) and its role's colour.
---@param skin PagleSkin
---@param region PaglePainted
function ns.PaintRegion(skin, region)
	local color = skin.style.colors[region.paintRole]
	if region.paintTemplate then
		local fontString = region --[[@as FontString]]
		local face = region.paintTitle and skin.style.titleFace
		local size = face and face.sizes[region.paintTemplate]
		if face and size then
			fontString:SetFont(face.file, size, "")
		else
			fontString:SetFontObject(region.paintTemplate)
		end
		fontString:SetTextColor(color[1], color[2], color[3])
	else
		local texture = region --[[@as Texture]]
		texture:SetColorTexture(color[1], color[2], color[3], color[4])
	end
end

-- Lays the style's rings around the skin's icon, each cropped to the frame (prototypes/curio-shop/'s rings and glow
-- stay inside the toast).
---@param skin PagleSkin
local function paintGlow(skin)
	local glow, at = skin.style.glow, skin.glowAt
	if not at then
		return
	end
	local rings = glow and glow.rings or {}
	for i = #skin.glow + 1, #rings do
		skin.glow[i] = at.frame:CreateTexture(nil, "BACKGROUND", nil, 2)
	end
	for i, texture in ipairs(skin.glow) do
		local ring = rings[i]
		local crop = ring
			and ns.CroppedSquare(at.x, at.y, at.size * ring.scale, at.frame:GetWidth(), at.frame:GetHeight())
		if glow and ring and crop then
			texture:SetTexture(glow.file)
			texture:SetBlendMode(glow.blend)
			texture:SetVertexColor(glow.tint[1], glow.tint[2], glow.tint[3], ring.alpha)
			texture:SetTexCoord(crop.left, crop.right, crop.top, crop.bottom)
			texture:ClearAllPoints()
			texture:SetPoint("TOPLEFT", at.frame, "TOPLEFT", crop.x, -crop.y)
			texture:SetSize(crop.width, crop.height)
			texture:Show()
		else
			texture:Hide()
		end
	end
end

--- Paints a whole skin in `style`: every texture and font string, the backdrop and the rings (ANN-R80). Call it once
--- the frame has its size.
---@param skin PagleSkin
---@param style PagleToastStyle
function ns.PaintSkin(skin, style)
	skin.style = style
	for _, region in ipairs(skin.painted) do
		ns.PaintRegion(skin, region)
	end
	local backdrop, look = skin.backdrop, style.backdrop
	if backdrop and look then
		backdrop:SetTexture(look.file)
		backdrop:SetVertexColor(look.tint[1], look.tint[2], look.tint[3], look.tint[4])
		backdrop:Show()
	elseif backdrop then
		backdrop:Hide()
	end
	paintGlow(skin)
end

--- Marks a texture or font string as painted in `role` (and a font string in `template`), and paints it.
---@param skin PagleSkin
---@param region Region
---@param role string
---@param template string?
---@param title boolean?
---@return PaglePainted
function ns.Painted(skin, region, role, template, title)
	local painted = region --[[@as PaglePainted]]
	painted.paintRole, painted.paintTemplate, painted.paintTitle = role, template, title
	skin.painted[#skin.painted + 1] = painted
	ns.PaintRegion(skin, painted)
	return painted
end

--- Puts a painted texture or font string in another colour role (and font object, if given), and paints it.
---@param skin PagleSkin
---@param region Region
---@param role string
---@param template string?
function ns.PaintAs(skin, region, role, template)
	local painted = region --[[@as PaglePainted]]
	painted.paintRole, painted.paintTemplate = role, template or painted.paintTemplate
	ns.PaintRegion(skin, painted)
end

--- A texture on `frame` in a colour role, filling it unless placed afterwards.
---@param skin PagleSkin
---@param frame Frame
---@param role string
---@param layer DrawLayer?
---@return Texture
function ns.SolidTexture(skin, frame, role, layer)
	local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
	texture:SetAllPoints()
	return ns.Painted(skin, texture, role) --[[@as Texture]]
end

--- The skin's main background on `frame` in `background`'s role, the style's backdrop over it, and a `size`-pixel
--- edge in `edge`'s role on `sides` (default all four): "top", "bottom", "left", "right".
---@param skin PagleSkin
---@param frame Frame
---@param background string
---@param edge string
---@param size number
---@param sides string[]?
function ns.Framed(skin, frame, background, edge, size, sides)
	skin.background = ns.SolidTexture(skin, frame, background)
	skin.backdrop = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
	skin.backdrop:SetAllPoints()
	skin.backdrop:Hide()
	local SIDES = {
		top = { "TOPLEFT", "TOPRIGHT", "SetHeight" },
		bottom = { "BOTTOMLEFT", "BOTTOMRIGHT", "SetHeight" },
		left = { "TOPLEFT", "BOTTOMLEFT", "SetWidth" },
		right = { "TOPRIGHT", "BOTTOMRIGHT", "SetWidth" },
	}
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
		skin.edges[#skin.edges + 1] = ns.Painted(skin, line, edge) --[[@as Texture]]
	end
end

--- Where the style's rings go: around the icon centred `x`, `y` from `frame`'s top left, `size` across.
---@param skin PagleSkin
---@param frame Frame
---@param x number
---@param y number
---@param size number
function ns.GlowAround(skin, frame, x, y, size)
	skin.glowAt = { frame = frame, x = x, y = y, size = size }
end

--- A font string on `frame` in `template`, in a colour role; a title takes the style's title face.
---@param skin PagleSkin
---@param frame Frame
---@param template string
---@param role string
---@param title boolean?
---@return FontString
function ns.Text(skin, frame, template, role, title)
	local fontString = frame:CreateFontString(nil, "OVERLAY", template)
	return ns.Painted(skin, fontString, role, template, title) --[[@as FontString]]
end
