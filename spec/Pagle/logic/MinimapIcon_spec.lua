-- The minimap icon's place round the minimap's edge (CORE-R53): pure logic over angles, which
-- adapter/MinimapIcon.lua draws (spec/Pagle/adapter/MinimapIcon_spec.lua).

describe("ns.MinimapAngle", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("reads a point's angle round the centre in degrees, counterclockwise from the right (CORE-R53)", function()
		local read = {}
		for i, point in ipairs({ { 10, 0 }, { 0, 10 }, { -10, 0 }, { 0, -10 }, { -5, -5 }, { 5, 5 } }) do
			read[i] = ns.MinimapAngle(100 + point[1], 200 + point[2], 100, 200)
		end

		assert.are.same({ 0, 90, 180, 270, 225, 45 }, read)
	end)

	it("is the same however far out the point is, so a drag keeps the icon on the edge (CORE-R53)", function()
		assert.are.equal(ns.MinimapAngle(3, 3, 0, 0), ns.MinimapAngle(900, 900, 0, 0))
	end)
end)

describe("ns.MinimapIconOffset", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- The offset at `angle`, rounded to 0.001.
	local function offset(angle, radius)
		local x, y = ns.MinimapIconOffset(angle, radius)
		return { math.floor(x * 1000 + 0.5) / 1000, math.floor(y * 1000 + 0.5) / 1000 }
	end

	it("puts the icon's centre on a circle of the given radius, at the angle (CORE-R53)", function()
		assert.are.same({ 104, 0 }, offset(0, 104))
		assert.are.same({ 0, 104 }, offset(90, 104))
		assert.are.same({ -73.539, -73.539 }, offset(225, 104))
	end)

	it("starts at 225 degrees, the minimap's bottom left (CORE-R53)", function()
		assert.are.equal(225, ns.MINIMAP_ICON_ANGLE)
	end)
end)
