---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- A Legend's crest on the client (ledger.md › LED-R153; announcements.md › UI › Splash): its crest's sprites from
-- Core's media/legends/Legend<Key> stacked as the kit stacks them (adapter/ToastLayers.lua's layered piece, in the
-- crest's 260 x 280 box scaled to its width), the Legend's icon in sepia masked round in the well, the plaque's word,
-- and its motion on the motion driver (logic/LegendCrests.lua decides what shows and how it moves). The Legend splash
-- draws one at full size; a Module draws its own through Pagle.NewLegendCrest (the Journal's Legends spread).

local BOX, WELL = ns.LEGEND_CREST_BOX, ns.LEGEND_CREST_WELL
-- The plaque's word is never smaller than this on screen, however small the crest is drawn.
local LABEL_MIN = 9
-- The icon reaches a little under the well's ring, so no gap shows at its edge.
local ICON_BLEED = 2
-- The icon's sublevel on the ARTWORK layer: the well's z, 3 (adapter/ToastLayers.lua puts z 4 at 0).
local ICON_SUBLEVEL = -1

---@class PagleLegendCrestFrame: Frame, PagleLegendCrest
---@field box PagleLayeredHost the crest's box, BOX's size, scaled to the crest's width
---@field icon Texture
---@field label FontString

-- Puts `look` on the crest: its sprites, its icon or none, and its plaque's word at its ink, kept legible.
---@param crest PagleLegendCrestFrame
---@param look PagleLegendCrestLook
local function draw(crest, look)
	local art = look.art
	ns.DrawLayeredPiece(crest.box, art.atlas, art.layers, function(layer)
		return ns.LegendCrestLayerShown(look, layer)
	end)
	local icon = crest.icon
	icon:SetShown(look.icon ~= nil)
	if look.icon ~= nil then
		icon:SetTexture(ns.TextureOf(look.icon))
		icon:SetTexCoord(ns.ICON_CROP, 1 - ns.ICON_CROP, ns.ICON_CROP, 1 - ns.ICON_CROP)
		-- sepia, as the Journal's medallions
		if icon.SetDesaturation then
			icon:SetDesaturation(0.6)
		else
			icon:SetDesaturated(true)
		end
		icon:SetVertexColor(1, 0.94, 0.82)
	end
	local label, ink = crest.label, art.label.ink
	local size = math.max(ink.size, LABEL_MIN / crest.box:GetScale())
	ns.SetInkFont(label, ink, math.floor(size * 2 + 0.5) / 2)
	label:SetText(ns.Capitals(ns.LegendCrestLabel(art.label.word)))
	label:ClearAllPoints()
	label:SetPoint("TOP", crest.box, "TOPLEFT", BOX.w / 2, -art.label.top)
end

--- A Legend's crest on `parent`, `width` units wide (its height the crest box's at that width), showing nothing until
--- its SetLegend (LED-R153; logic/LegendCrests.lua's ns.AttachLegendCrest: SetLegend, Play, Stop). Its parent places
--- it.
---@param parent Frame
---@param width number
---@return PagleLegendCrestFrame
function ns.NewLegendCrest(parent, width)
	local crest = CreateFrame("Frame", nil, parent) --[[@as PagleLegendCrestFrame]]
	local scale = width / BOX.w
	crest:SetSize(width, BOX.h * width / BOX.w)
	local box = CreateFrame("Frame", nil, crest) --[[@as PagleLayeredHost]]
	box:SetSize(BOX.w, BOX.h)
	box:SetScale(scale)
	box:SetPoint("TOPLEFT")
	crest.box = box
	local icon = ns.ArtCrisp(box:CreateTexture(nil, "ARTWORK", nil, ICON_SUBLEVEL))
	local side = 2 * (WELL.r + ICON_BLEED)
	icon:SetSize(side, side)
	icon:SetPoint("CENTER", box, "TOPLEFT", WELL.x, -WELL.y)
	local mask = box:CreateMaskTexture()
	mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	mask:SetAllPoints(icon)
	icon:AddMaskTexture(mask)
	icon:Hide()
	crest.icon = icon
	crest.label = box:CreateFontString(nil, "OVERLAY")
	ns.AttachLegendCrest(crest, {
		draw = function(look)
			draw(crest, look)
		end,
		move = function(i, kind, values)
			ns.MoveLayeredPiece(box, i, kind, values)
		end,
		animate = ns.Animate,
		stop = ns.StopMotion,
	})
	return crest
end

--- A Legend's crest for a Module's frame (core/README.md › Contracts; LED-R153).
Pagle.NewLegendCrest = ns.NewLegendCrest
