---@class PagleNS
local ns = select(2, ...)

-- The Legend crests (ledger.md › LED-R153; announcements.md › UI › Splash): which crest a Legend shows and what sits
-- in its well, its layers' motion, and a crest's SetLegend, Play and Stop over the host that draws it. Pure logic over
-- data/LegendCrestArt.lua: adapter/LegendCrests.lua draws a crest on the client (the Legend splash, and a Module's
-- through Pagle.NewLegendCrest), FakePagle records one.

--- The plaque's word on a crest: the key of its label in ns.L (ns.LegendCrestLabel), where its line's top sits in the
--- crest's box, and its ink.
---@class PagleLegendCrestLabel
---@field word "legend"|"unwritten"
---@field top number
---@field ink PagleToastInk

--- A crest's art: its atlas in ns.ATLASES, its plaque's label, and its layers in draw order, each at its box in the
--- crest's 260 x 280 box (ns.LEGEND_CREST_BOX), with its z and any motion as a toast style's layer has it.
---@class PagleLegendCrestArt
---@field atlas string
---@field label PagleLegendCrestLabel
---@field layers PagleLayeredPieceLayer[]

--- What a crest shows: its key in ns.LEGEND_CREST_ART, its art, and the item whose icon sits in its well in sepia, or
--- nil for the crest's own (the Unwritten crest's plain fish).
---@class PagleLegendCrestLook
---@field key string
---@field art PagleLegendCrestArt
---@field icon any

--- The crest a Legend shows (LED-R153): caught, its own crest (ns.LEGEND_CRESTS) with its icon in the well, or the
--- Unwritten crest with its icon when it has none of its own (a Legend added after 1.0); not caught, the Unwritten
--- crest with its own plain fish and nothing of the Legend, the same for every Legend (LED-R124).
---@param itemID any the Legend's item ID; any other icon stands in for one with no crest of its own
---@param caught boolean
---@return PagleLegendCrestLook
function ns.LegendCrestLook(itemID, caught)
	local key = caught and ns.LEGEND_CRESTS[itemID] or "unwritten"
	return { key = key, art = ns.LEGEND_CREST_ART[key], icon = caught and itemID or nil }
end

--- Whether a crest's layer is drawn for `look`: all of them, but the Unwritten crest's own well (its plain fish) while
--- an icon sits there instead.
---@param look PagleLegendCrestLook
---@param layer { name: string }
---@return boolean
function ns.LegendCrestLayerShown(look, layer)
	return not (layer.name == "well" and look.icon ~= nil)
end

local LABELS = { legend = "LEGEND_CREST_LEGEND", unwritten = "LEGEND_CREST_UNWRITTEN" }

--- A crest plaque's word (LED-R153): "Legend" on a Legend's own crest, "Unwritten" on the Unwritten crest.
---@param word "legend"|"unwritten"
---@return string
function ns.LegendCrestLabel(word)
	return ns.L[LABELS[word]]
end

--- A crest's motion as animations for the motion player (logic/Motion.lua): each moving layer's (every crest has some,
--- LED-R153) as a toast style's layer moves (ns.ToastLayerAnimations), from the start and looping, `apply(i, kind,
--- values)` with `i` the layer's place in `art.layers`. Their settled values (ns.MotionSettled) are the resting frame:
--- each motion's first, so a glint that only flashes is unseen.
---@param art PagleLegendCrestArt
---@param apply fun(i: integer, kind: string, values: number[])
---@return PagleAnimation[]
function ns.LegendCrestAnimations(art, apply)
	local animations = {}
	for i, layer in ipairs(art.layers) do
		if layer.motion then
			local moved = ns.ToastLayerAnimations(layer.motion, 0, function(kind, values)
				apply(i, kind, values)
			end)
			for _, animation in ipairs(moved) do
				animations[#animations + 1] = animation
			end
		end
	end
	return animations
end

--- What draws a crest: its look's layers in their resting frame with its icon and label (`draw`), a layer where its
--- motion has it now (`move`), and the motion driver (`animate`, `stop`): Core's on the client, the fake's in specs.
---@class PagleLegendCrestHost
---@field draw fun(look: PagleLegendCrestLook)
---@field move fun(i: integer, kind: string, values: number[])
---@field animate fun(owner: table, animations: PagleAnimation[], onDone: fun())
---@field stop fun(owner: table)

--- A Legend's crest (LED-R153), as Pagle.NewLegendCrest hands it out.
---@class PagleLegendCrest
---@field look PagleLegendCrestLook? what it shows, once SetLegend has drawn it
---@field moving true? while its motion plays
---@field SetLegend fun(self: PagleLegendCrest, itemID: any, caught: boolean)
---@field Play fun(self: PagleLegendCrest)
---@field Stop fun(self: PagleLegendCrest)

-- Puts every moving layer of `look` in its resting frame.
---@param look PagleLegendCrestLook
---@param host PagleLegendCrestHost
local function rest(look, host)
	for _, animation in ipairs(ns.LegendCrestAnimations(look.art, host.move)) do
		animation.apply(ns.MotionSettled(animation))
	end
end

--- Gives `crest` (the motion driver's owner of its motion) its SetLegend, Play and Stop, drawn through `host`:
--- - `SetLegend(itemID, caught)` shows ns.LegendCrestLook's crest in its resting frame, stopping any motion; drawn again
---   with the same look it changes nothing, so a crest that moves carries on.
--- - `Play()` sets its layers moving, looping until it stops; played again while it moves, it carries on. With
---   Animations off the driver keeps it in its resting frame. The driver settles it once it is no longer visible (its
---   window closed, its page turned), and it plays again only when played.
--- - `Stop()` stops it, back in its resting frame.
---@param crest table
---@param host PagleLegendCrestHost
function ns.AttachLegendCrest(crest, host)
	---@cast crest PagleLegendCrest
	function crest.SetLegend(self, itemID, caught)
		local look = ns.LegendCrestLook(itemID, caught)
		local shown = self.look
		if shown and shown.key == look.key and shown.icon == look.icon then
			return
		end
		host.stop(self)
		self.moving = nil
		self.look = look
		host.draw(look)
		rest(look, host)
	end
	function crest.Play(self)
		local look = self.look
		if self.moving or not look then
			return
		end
		self.moving = true
		host.animate(self, ns.LegendCrestAnimations(look.art, host.move), function()
			self.moving = nil
		end)
	end
	function crest.Stop(self)
		host.stop(self)
		self.moving = nil
		local look = self.look
		if look then
			rest(look, host)
		end
	end
end
