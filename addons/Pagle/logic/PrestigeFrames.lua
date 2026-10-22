---@class PagleNS
local ns = select(2, ...)

-- The Prestige frames and Prestige emblems (ledger.md › LED-R152, LED-R153; announcements.md › ANN-R83): which frame
-- and emblem a prestige rank shows, what the frame's label reads, and the emblem as a texture or in a line of text.
-- Core's, since the Ledger's bookplate and Core's Prestige banner both draw them (data/PrestigeArt.lua); a frame is
-- drawn as well art (logic/LayeredArt.lua) holding the Angler's likeness. Pagle.NewPrestigeFrame, SetPrestigeEmblem,
-- PrestigeEmblemMarkup and GetPrestigeFrame publish them (adapter/PrestigeFrames.lua).

--- A rank's Prestige frame (data/PrestigeArt.lua): its key (its lore's, `prestigeframe.<key>`), its atlas, its label
--- plaque's words' top and ink, its crest's pin and its layers.
---@class PaglePrestigeFrameArt: PagleWellArtSpec
---@field key string

-- The ranks with a frame and emblem of their own, I to X (LED-R34); past X, the Master's, the frame art's 11th.
local OWN = 10
local MASTER = 11
-- The star stamps a Master's label shows before the rest go as "+n" (LED-R152).
local LABEL_STARS = 5

--- The frame prestige rank `rank` shows (LED-R152): No Prestige's below 1, its own for I to X, the Master's past X
--- (a rank with no frame of its own, ANN-R83).
---@param rank integer
---@return PaglePrestigeFrameArt
function ns.PrestigeFrameArt(rank)
	if rank <= 0 then
		return ns.PRESTIGE_FRAME_ART[0]
	end
	return ns.PRESTIGE_FRAME_ART[math.min(math.floor(rank), MASTER)]
end

--- What a frame's label plaque reads (LED-R152): the rank's numeral, "I" to "X", or past X "Master" with a star stamp
--- for each Master Prestige, at most five and then "+{n}"; nothing at rank 0.
---@param rank integer
---@return PagleWellArtLabel?
function ns.PrestigeFrameLabel(rank)
	local L = ns.L
	if rank <= 0 then
		return nil
	elseif rank <= OWN then
		return { text = L.PRESTIGE_NUMERALS[rank], stars = 0, more = 0 }
	end
	local stars = rank - OWN
	return {
		text = L.PRESTIGE_FRAME_MASTER,
		stars = math.min(stars, LABEL_STARS),
		more = math.max(0, stars - LABEL_STARS),
	}
end

--- Draws prestige rank `rank`'s frame on well art at `scale` of the kit's box, its label as ns.PrestigeFrameLabel.
---@param art PagleWellArt
---@param rank integer
---@param scale number
function ns.DrawPrestigeFrame(art, rank, scale)
	local frame = ns.PrestigeFrameArt(rank)
	art:DrawArt(frame, scale, ns.PrestigeFrameLabel(rank), frame.key)
end

--- A Prestige frame (LED-R152; announcements.md › Contracts, Pagle.NewPrestigeFrame): well art with `SetRank(rank,
--- scale)`, which draws the rank's frame at `scale` of the kit's 260 × 280 box, resting, its label the rank's numeral
--- or "Master" and its stars. Its caller fills `GetWell()` with the likeness (SetPortraitTexture), pins a crest at
--- `GetPin()`, and calls `Play()` while it should move and `Stop()` when not; hidden, it stops by itself.
---@class PaglePrestigeFrame: PagleWellArt
---@field SetRank fun(self: PaglePrestigeFrame, rank: integer, scale: number)

--- Makes Prestige frames from well art made by `makeWellArt` (Core's client's, or FakePagle's).
---@param makeWellArt fun(parent: Frame): PagleWellArt
---@return fun(parent: Frame): PaglePrestigeFrame
function ns.PrestigeFrameMaker(makeWellArt)
	return function(parent)
		local frame = makeWellArt(parent) --[[@as PaglePrestigeFrame]]
		function frame.SetRank(self, rank, scale)
			ns.DrawPrestigeFrame(self, rank, scale)
		end
		return frame
	end
end

--- What a Module knows of a rank's frame (Pagle.GetPrestigeFrame): its key, for its lore, and whether it moves.
---@param rank integer
---@return { key: string, moving: boolean }
function ns.PrestigeFrameInfo(rank)
	local frame = ns.PrestigeFrameArt(rank)
	local moving = false
	for _, layer in ipairs(frame.layers) do
		moving = moving or layer.motion ~= nil
	end
	return { key = frame.key, moving = moving }
end

--- The emblem sprite of prestige rank `rank` (LED-R153): I to X, the Master's past X, none at 0.
---@param rank integer
---@return string?
function ns.PrestigeEmblemSprite(rank)
	if rank <= 0 then
		return nil
	end
	return ns.PRESTIGE_EMBLEMS[math.floor(rank)] or "emblem-master"
end

--- Shows prestige rank `rank`'s emblem in `texture`, `size` units square (LED-R153: 64 on the Prestige confirm, 34
--- beside the Angler Level, 22 in lists and tooltips); at rank 0 hides it. Returns whether it shows.
---@param texture Texture
---@param rank integer
---@param size number
---@return boolean
function ns.SetPrestigeEmblem(texture, rank, size)
	local sprite = ns.PrestigeEmblemSprite(rank)
	if not sprite then
		texture:Hide()
		return false
	end
	local atlas = ns.ATLASES.PrestigeEmblems
	local tc = ns.SpriteCoords(atlas, sprite)
	ns.ArtCrisp(texture)
	texture:SetTexture(atlas.file)
	texture:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
	texture:SetSize(size, size)
	texture:Show()
	return true
end

--- Prestige rank `rank`'s emblem as an inline texture for a line of text (a tooltip's), `size` units square; "" at
--- rank 0.
---@param rank integer
---@param size number
---@return string
function ns.PrestigeEmblemMarkup(rank, size)
	local name = ns.PrestigeEmblemSprite(rank)
	if not name then
		return ""
	end
	local atlas = ns.ATLASES.PrestigeEmblems
	local sprite = atlas.sprites[name]
	return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
		atlas.file,
		size,
		size,
		atlas.width,
		atlas.height,
		sprite.x,
		sprite.x + sprite.w,
		sprite.y,
		sprite.y + sprite.h
	)
end
