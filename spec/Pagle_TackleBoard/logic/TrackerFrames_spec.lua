-- The Curio Shop expansion's tracker frames sliced in three down (TKB-R125; logic/TrackerFrames.lua): the kit's sprite
-- scaled to the frame's width, its top and foot keeping their shape, its middle stretched or repeated, as pieces the
-- tracker block draws. Every expected value is worked out by hand from a small atlas.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- A 512 × 512 atlas at 2 texels per UI unit, with one sprite 60 × 50 UI units at texel (4, 8): its drawn element 50 ×
-- 40 inside it, 5 units in from its left and top, 5 units of margin under it.
local ATLAS = { file = "atlas", width = 512, height = 512, scale = 2, sprites = {} }
local SPRITE = { x = 4, y = 8, w = 120, h = 100, box = { 5, 5, 50, 40 } }

-- A texel row of the sprite as a texture coordinate: `v` UI units down from its top.
local function row(v)
	return (8 + v * 2) / 512
end

-- A piece as { y, height, its texture's top and bottom }.
local function piece(y, height, from, to)
	return { y = y, height = height, top = row(from), bottom = row(to) }
end

describe("a kit tracker frame's slices (TKB-R125)", function()
	local ns = board.load().ns

	it("scale the sprite to the frame's width, its margin outside, across the sprite's full width", function()
		-- 100 wide: twice the element's 50
		local cut = ns.FrameSlices(ATLAS, SPRITE, { top = 10, foot = 6, mode = "stretch" }, 100, 120)

		assert.are.same({ -10, 120, 4 / 512, 124 / 512 }, { cut.x, cut.width, cut.left, cut.right })
	end)

	it("keep the top and foot at their shape, scaled with the width, and stretch the middle between them", function()
		local cut = ns.FrameSlices(ATLAS, SPRITE, { top = 10, foot = 6, mode = "stretch" }, 100, 120)

		assert.are.same({
			piece(-10, 30, 0, 15), -- the margin above and the top, 15 units at twice the size
			piece(20, 88, 15, 39), -- the middle, 24 units stretched to what is left
			piece(108, 22, 39, 50), -- the foot and the margin under it
		}, cut.pieces)
	end)

	it("repeat a tiled middle every period, at the frame's scale, the last one cut short", function()
		local cut = ns.FrameSlices(ATLAS, SPRITE, { top = 10, foot = 6, mode = "tile", period = 8 }, 100, 120)

		-- 88 units of middle: five whole periods of 16, then 8, half a period
		assert.are.same({
			piece(-10, 30, 0, 15),
			piece(20, 16, 15, 23),
			piece(36, 16, 15, 23),
			piece(52, 16, 15, 23),
			piece(68, 16, 15, 23),
			piece(84, 16, 15, 23),
			piece(100, 8, 15, 19),
			piece(108, 22, 39, 50),
		}, cut.pieces)
	end)

	it("squeeze the top and foot together, with no middle, in a frame shorter than both", function()
		-- 16 high, half the 32 the top and foot take
		local cut = ns.FrameSlices(ATLAS, SPRITE, { top = 10, foot = 6, mode = "tile", period = 8 }, 100, 16)

		assert.are.same({ piece(-5, 15, 0, 15), piece(10, 11, 39, 50) }, cut.pieces)
	end)

	it("draw no middle when the top and foot just fill the frame", function()
		local cut = ns.FrameSlices(ATLAS, SPRITE, { top = 10, foot = 6, mode = "stretch" }, 100, 32)

		assert.are.same({ piece(-10, 30, 0, 15), piece(20, 22, 39, 50) }, cut.pieces)
	end)
end)
