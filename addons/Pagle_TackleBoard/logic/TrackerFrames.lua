if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The Curio Shop expansion's tracker frames sliced in three down (TKB-R125): Fishing Net, Bamboo Slats, Tackle Tin,
-- Bobber and Live Embers, each a sprite of the expansion kit's TrackerFrames2 atlas (adapter/TrackerBlock.lua) with the
-- kit's three-slice. Pure logic (CORE-R7): it works out the pieces, and adapter/BoardArt.lua's ns.SetKitSlice draws
-- them. Unlike the board art kit's two frames (ns.SetVSlice), a kit frame scales evenly with its width, so the
-- ornaments in its top and foot (the net's floats, the bobber, the tin's hinge) keep their shape.

--- How a kit frame is sliced (the expansion kit's goods.json `slice`): its top and foot, in UI units of its drawn
--- element at the kit's size, keep their shape; its middle stretches, or repeats every `period` units with "tile".
---@class TackleFrameSlice
---@field top number
---@field foot number
---@field mode "stretch"|"tile"
---@field period number?

--- One piece of a sliced frame, top to bottom: its top `y` units down from the drawn element's top (above it, in the
--- sprite's margin, when negative), its height, and its texture's top and bottom coordinates.
---@class TackleFramePiece
---@field y number
---@field height number
---@field top number
---@field bottom number

--- A kit frame cut to size: every piece spans the sprite's full width, `width` wide from `x` units of the drawn
--- element's left (negative: the sprite's margin), its texture from `left` to `right`.
---@class TackleFrameCut
---@field x number
---@field width number
---@field left number
---@field right number
---@field pieces TackleFramePiece[]

--- Sprite `sprite` of `atlas` sliced as `slice` for a drawn element `width` × `height` (TKB-R125): scaled evenly to
--- `width` from the element's own; the top and the foot at that scale, squeezed together evenly when `height` is
--- shorter than both; the middle stretched over the rest, or with "tile" repeated every `period` units at that scale,
--- the last repeat cut short.
---@param atlas TackleAtlas
---@param sprite TackleAtlasSprite
---@param slice TackleFrameSlice
---@param width number
---@param height number
---@return TackleFrameCut
function ns.FrameSlices(atlas, sprite, slice, width, height)
	local scale, box = atlas.scale, sprite.box
	local k = width / box[3]
	local spriteHeight = sprite.h / scale
	local marginTop = box[2]
	local caps = (slice.top + slice.foot) * k
	local squeeze = caps > height and height / caps or 1
	local function coord(v)
		return (sprite.y + v * scale) / atlas.height
	end
	local pieces = {}
	-- `span` units of the sprite from `from`, drawn `drawn` high at `y`.
	local function add(y, drawn, from, span)
		pieces[#pieces + 1] = { y = y, height = drawn, top = coord(from), bottom = coord(from + span) }
	end
	local top, foot = slice.top * k * squeeze, slice.foot * k * squeeze
	add(-marginTop * k * squeeze, (marginTop + slice.top) * k * squeeze, 0, marginTop + slice.top)
	local from, middle = marginTop + slice.top, height - top - foot
	if middle > 0 then
		if slice.mode == "tile" and slice.period then
			local period = slice.period * k
			local y = top
			while y < top + middle do
				local drawn = math.min(period, top + middle - y)
				add(y, drawn, from, drawn / k)
				y = y + drawn
			end
		else
			add(top, middle, from, box[4] - slice.top - slice.foot)
		end
	end
	local footFrom = marginTop + box[4] - slice.foot
	add(height - foot, (spriteHeight - footFrom) * k * squeeze, footFrom, spriteHeight - footFrom)
	return {
		x = -box[1] * k,
		width = sprite.w / scale * k,
		left = sprite.x / atlas.width,
		right = (sprite.x + sprite.w) / atlas.width,
		pieces = pieces,
	}
end
