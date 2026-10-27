---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- A good's look on a stage (wallet-and-shop.md › UI, the preview stage; SHOP-R36): the one path the Curio Shop's stage
-- and `Pagle.DrawGoodPreview` draw by. A good's preview (or its slot's) is handed a frame of its own through
-- securecallfunction, so one that raises is reported and the rest still shows; a good with none shows its icon in a
-- medallion.

--- What a stage draws: a good's look.
---@class PagleLook
---@field id string
---@field preview? fun(stage: Frame)  -- draws the look; nil for a good with none, or put away
---@field icon? integer|string        -- the medallion's icon, for a good with no preview
---@field greyed? boolean             -- the medallion greyed: a good put away
---@field shield? boolean             -- a crest's icon: drawn as its shield (SHOP-R25)

--- Draws `look` on `area`: its own frame in `previews` (made at its first drawing, filling `area`, the same each time),
--- handed to its preview when `fresh`; or `swatch`, the medallion, with its icon. The caller hides what it showed
--- before.
---@param area Frame
---@param previews table<string, Frame> each good's own frame on `area`, kept by the caller
---@param swatch PagleShopBezel `area`'s medallion
---@param look { id: string, preview: (fun(stage: Frame))?, icon: (integer|string)?, greyed: boolean?, shield: boolean? }
--- the good's look (PagleLook; the shop's stage has these fields too)
---@param fresh boolean the preview draws again
function ns.DrawLook(area, previews, swatch, look, fresh)
	local preview = look.preview
	if not preview then
		ns.SetShopBezel(swatch, look.icon, look.greyed, look.shield)
		swatch:Show()
		return
	end
	local own = previews[look.id]
	if not own then
		own = CreateFrame("Frame", nil, area)
		own:SetAllPoints()
		previews[look.id] = own
		fresh = true
	end
	own:Show()
	if fresh then
		securecallfunction(preview, own)
	end
end

--- The stage's size (SHOP-R36), the shop's well: `Pagle.DrawGoodPreview`'s "stage" draws at it, and a "card" scales it
--- to the frame.
ns.GOOD_PREVIEW_W, ns.GOOD_PREVIEW_H = 370, 132

---@class PagleGoodPreviewBox: Frame
---@field previews table<string, Frame>
---@field swatch PagleShopBezel

-- Each frame's box, made at its first drawing. Weak, so a frame that goes takes its box.
---@type table<Frame, PagleGoodPreviewBox>
local boxes = setmetatable({}, { __mode = "k" })

-- The box on `frame`: a stage-sized frame centred in it, with its own medallion.
---@param frame Frame
---@return PagleGoodPreviewBox
local function boxOf(frame)
	local box = boxes[frame]
	if box then
		return box
	end
	box = CreateFrame("Frame", nil, frame) --[[@as PagleGoodPreviewBox]]
	box:SetSize(ns.GOOD_PREVIEW_W, ns.GOOD_PREVIEW_H)
	box:SetPoint("CENTER")
	box.previews = {}
	box.swatch = ns.NewShopBezel(box, 64)
	box.swatch:SetPoint("CENTER")
	boxes[frame] = box
	return box
end

-- The look of `goodID` as the stage draws it, or nil for a good never cached: its preview or its slot's from the
-- registry, else its cached icon.
---@param goodID any
---@return PagleLook?
local function lookOf(goodID)
	local info = ns.goods:GetGood(goodID)
	if not info then
		return nil
	end
	local registered = ns.goods:Good(goodID)
	return {
		id = goodID,
		preview = ns.goods:PreviewOf(goodID),
		icon = info.icon,
		greyed = registered == nil,
		shield = info.slot == ns.CREST_SLOT,
	}
end

--- `Pagle.DrawGoodPreview` (SHOP-R36): draws the look of `goodID` into `frame`, as the Curio Shop's stage does, at
--- `size`: "stage" (370 x 132, centred) or "card" (that, scaled to fit the frame). A preview that stands still draws
--- as it does in the shop. Draws nothing for a good never cached.
---@param frame Frame
---@param goodID string
---@param size PagleGoodPreviewSize
function ns.DrawGoodPreview(frame, goodID, size)
	local box = boxOf(frame)
	for _, own in pairs(box.previews) do
		own:Hide()
	end
	box.swatch:Hide()
	local scale = 1
	if size == "card" then
		local fit = math.min(frame:GetWidth() / ns.GOOD_PREVIEW_W, frame:GetHeight() / ns.GOOD_PREVIEW_H)
		scale = fit > 0 and fit or 1
	end
	box:SetScale(scale)
	local look = lookOf(goodID)
	if look then
		ns.DrawLook(box, box.previews, box.swatch, look, true)
	end
end
