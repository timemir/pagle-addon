---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's own tour stops (CORE-R65, CORE-R68), in ns.tourStops with the Modules' (logic/Wiring.lua's ns.WireDev): each
-- Announcement form with `/pagle dev preview`'s sample, the two cards, the Curio Shop, the Field report box and the
-- glyph panel. adapter/Settings.lua adds the Settings pages as it registers them. Each hide puts back what its show
-- changed: a window open before its stop stays open.

-- Adds one of Core's stops; a mistake here is Core's own, so it's raised.
---@param id string
---@param label string
---@param show fun()
---@param hide fun()
local function add(id, label, show, hide)
	local problem = ns.tourStops:Add(ns.TOUR_CORE, id, label, show, hide)
	if problem then
		error(problem)
	end
end

-- Each Announcement form, through the real lanes with the equipped look (`/pagle dev preview <kind>`'s sample); its
-- hide takes it back off screen.
for _, kind in ipairs({ "toast", "nod", "banner", "splash" }) do
	local sample
	add("announce." .. kind, ns.L.DEV_TOUR_ANNOUNCE:format(kind), function()
		sample = ns.DevPreviewAnnouncement(kind) --[[@as PagleAnnouncement]]
		ns.lanes:Push(sample)
	end, function()
		ns.lanes:Withdraw(sample)
	end)
end

-- Each card, in the card frame: a Session summary card and a Write-up, closed as the player would. Closing a sample
-- removes nothing stored, and a card it replaced shows again (ns.cards:Close).
for _, card in ipairs({ { "card.session", ns.DevPreviewCard }, { "card.writeup", ns.DevPreviewWriteUp } }) do
	local shown
	add(card[1], ns.L.DEV_TOUR_CARD:format(card[1]:match("%.(.+)")), function()
		shown = card[2]()
		ns.cards:Preview(shown)
	end, function()
		ns.CloseCardOnScreen(shown)
	end)
end

-- A window stop: `open` shows it, and the hide closes it with `close` unless `isShown` said it was open already.
---@param id string
---@param label string
---@param isShown fun(): boolean
---@param open fun()
---@param close fun()
local function window(id, label, isShown, open, close)
	local wasShown
	add(id, label, function()
		wasShown = isShown()
		open()
	end, function()
		if not wasShown and isShown() then
			close()
		end
	end)
end

window("shop", ns.L.DEV_TOUR_SHOP, function()
	return ns.shopFrame ~= nil and ns.shopFrame:IsShown()
end, function()
	Pagle.OpenShop()
end, function()
	ns.shop.Toggle()
end)

window("fieldreport", ns.L.DEV_TOUR_FIELD_REPORT, function()
	return ns.fieldReportBox ~= nil and ns.fieldReportBox:IsShown()
end, function()
	Pagle.OpenFieldReport()
end, function()
	ns.fieldReportBox:Hide()
end)

window("glyphs", ns.L.DEV_TOUR_GLYPHS, function()
	return ns.glyphProbeFrame ~= nil and ns.glyphProbeFrame:IsShown()
end, function()
	ns.ShowGlyphProbe(ns.DEV_GLYPH_FONTS, ns.DevGlyphProbe())
end, function()
	ns.glyphProbeFrame:Hide()
end)
