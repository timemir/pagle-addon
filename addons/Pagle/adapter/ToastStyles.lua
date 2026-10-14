---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Following the equipped toast style (ANN-R80, SHOP-R33) and the sample toast for the Curio Shop's preview stage
-- (wallet-and-shop.md › UI). The frames read the style each time they show; AppearanceChanged repaints the ones
-- already built, a frame on screen included, at once.
local L = ns.L

-- Its own owner on Core's bus, so no other Core file's registration replaces its AppearanceChanged listener.
local OWNER = "Pagle toast styles"

--- Repaints every Announcement frame and the card frame built so far in the style each shows now: a sample's own,
--- else the equipped one (ANN-R80). One on screen stays there, repainted.
function ns.RepaintToastFrames()
	for _, frame in pairs(ns.announcementFrames) do
		local style = frame.display and frame.display.announcement.style
		ns.PaintSkin(frame.skin, style and ns.ToastStyleOf(style) or ns.EquippedToastStyle())
	end
	if ns.cardFrame then
		ns.PaintSkin(ns.cardFrame.skin, ns.EquippedToastStyle())
	end
end

-- SHOP-R33: Core redraws its frames when its toast style slot's look changes.
Pagle.RegisterCallback(OWNER, "AppearanceChanged", function(_, slot)
	if slot == ns.TOAST_STYLE_SLOT then
		ns.RepaintToastFrames()
	end
end)