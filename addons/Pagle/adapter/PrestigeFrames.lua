---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Prestige frames and emblems on the client (ledger.md › LED-R152, LED-R153; announcements.md › ANN-R83): well
-- art (logic/LayeredArt.lua) over the client's frames, Core's art fonts and its motion driver, for Core's Prestige
-- banner and, through Pagle's API, the Ledger's bookplate (ADR 0001: the art is Core's, media/prestige/).

--- Makes well art on `parent` (logic/LayeredArt.lua's ns.WellArtMaker): the Prestige frames' renderer, and the
--- Legend crests'.
---@type fun(parent: Frame): PagleWellArt
ns.NewWellArt = ns.WellArtMaker({
	createFrame = function(parent)
		return CreateFrame("Frame", nil, parent)
	end,
	setInk = ns.SetInkFont,
	motion = { animate = ns.Animate, stop = ns.StopMotion, isOn = ns.MotionOn },
})

--- Makes a Prestige frame on `parent` (logic/PrestigeFrames.lua's ns.PrestigeFrameMaker).
---@type fun(parent: Frame): PaglePrestigeFrame
ns.NewPrestigeFrame = ns.PrestigeFrameMaker(ns.NewWellArt)

Pagle.NewPrestigeFrame = ns.NewPrestigeFrame
Pagle.GetPrestigeFrame = ns.PrestigeFrameInfo
Pagle.SetPrestigeEmblem = ns.SetPrestigeEmblem
Pagle.PrestigeEmblemMarkup = ns.PrestigeEmblemMarkup
