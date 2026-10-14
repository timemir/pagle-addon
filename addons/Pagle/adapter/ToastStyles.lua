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
-- Each parent's sample toast, made the first time one draws on it. Weak, so a stage the shop drops goes.
---@type table<Frame, PagleAnnouncementFrame>
local samples = setmetatable({}, { __mode = "k" })
-- Each preview panel's Show on screen button.
---@type table<Frame, Button>
local buttons = setmetatable({}, { __mode = "k" })

--- Draws a sample toast in a toast style on `parent` (wallet-and-shop.md › UI, the preview stage; ANN-R80): a toast
--- frame of its own there, made on the first call and redrawn on each, Timber for an ID that isn't a style. Nothing
--- reaches the lanes, the sounds or the Session summary.
---@param parent Frame
---@param styleID string
---@return PagleAnnouncementFrame
function ns.DrawSampleToast(parent, styleID)
	local frame = samples[parent]
	if not frame then
		frame = ns.NewToastFrame(parent)
		frame:SetPoint("TOP", parent, "TOP", 0, -24)
		samples[parent] = frame
	end
	ns.DrawAnnouncement(frame, { announcement = ns.SampleAnnouncement(styleID), form = "toast", overflow = 0 })
	frame:Show()
	return frame
end

--- "Show on screen": the sample toast in a style, pushed through the real lanes (ANN-R20) as any toast is, its sound
--- and the Interruption budget with it, but raised by no Module, so the Session summary never gets it (ANN-R25).
---@param styleID string
function ns.ShowSampleToast(styleID)
	ns.lanes:Push(ns.SampleAnnouncement(styleID))
end

--- A toast style good's `preview(stage)` (wallet-and-shop.md › Contracts, › UI): on Core's preview panel for the slot
--- (adapter/CoreGoods.lua), the sample toast in that style and a Show on screen button under it.
---@param styleID string
---@return fun(stage: Frame)
function ns.ToastStylePreview(styleID)
	return function(stage)
		local panel = ns.CorePreviewPanel(stage, ns.TOAST_STYLE_SLOT, function(panel)
			local sample = ns.DrawSampleToast(panel, styleID)
			local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate") --[[@as Button]]
			button:SetSize(140, 22)
			button:SetPoint("TOP", sample, "BOTTOM", 0, -16)
			button:SetText(L.TOAST_SHOW_ON_SCREEN)
			buttons[panel] = button
		end)
		ns.DrawSampleToast(panel, styleID)
		buttons[panel]:SetScript("OnClick", function()
			ns.ShowSampleToast(styleID)
		end)
	end
end

-- Each toast style good's preview on the Curio Shop's stage (logic/CoreGoods.lua registers the goods).
ns.CORE_PREVIEWS[ns.TOAST_STYLE_SLOT] = function(stage, good)
	ns.ToastStylePreview(good.id)(stage)
end
