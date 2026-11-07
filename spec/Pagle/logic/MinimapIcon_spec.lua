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

-- From 1.5, "Detach from the minimap" (CORE-R53, SET-R10 row 10a): the detached icon's place on the screen, kept as
-- fractions of the screen's width and height, and kept on it.
describe("ns.ClampMinimapIcon", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("leaves a centre that keeps the whole button on the screen where it is (CORE-R53)", function()
		assert.are.same({ 400, 300 }, { ns.ClampMinimapIcon(400, 300, 1920, 1080, 31) })
		assert.are.same({ 15.5, 1064.5 }, { ns.ClampMinimapIcon(15.5, 1064.5, 1920, 1080, 31) })
	end)

	it("pulls a centre past any edge back until the whole button shows (CORE-R53)", function()
		assert.are.same({ 15.5, 15.5 }, { ns.ClampMinimapIcon(-200, 3, 1920, 1080, 31) })
		assert.are.same({ 1904.5, 1064.5 }, { ns.ClampMinimapIcon(5000, 1080, 1920, 1080, 31) })
	end)

	it("centres the button on a screen narrower than it (CORE-R53)", function()
		assert.are.same({ 10, 540 }, { ns.ClampMinimapIcon(900, 540, 20, 1080, 31) })
	end)
end)

describe("ns.DetachedIconPoint", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("keeps the centre as fractions of the screen, so it means the same spot at any UI scale (CORE-R53)", function()
		assert.are.same({ x = 0.25, y = 0.75 }, ns.DetachedIconPoint(480, 810, 1920, 1080, 31))
	end)

	it("keeps the centre on the screen first (CORE-R53)", function()
		assert.are.same({ x = 1904.5 / 1920, y = 15.5 / 1080 }, ns.DetachedIconPoint(2500, -40, 1920, 1080, 31))
	end)
end)

describe("ns.DetachedIconCenter", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("puts a saved point's centre on the screen as it is now (CORE-R53)", function()
		assert.are.same({ 480, 810 }, { ns.DetachedIconCenter({ x = 0.25, y = 0.75 }, 1920, 1080, 31) })
		-- UI scale 1.4 on the same screen: fewer units across, the same spot.
		local x, y = ns.DetachedIconCenter({ x = 0.25, y = 0.75 }, 1920 / 1.4, 1080 / 1.4, 31)
		assert.are.same({ 1920 / 1.4 / 4, 1080 / 1.4 * 0.75 }, { x, y })
	end)

	it("keeps it on the screen however the point was saved (CORE-R53)", function()
		assert.are.same({ 1904.5, 15.5 }, { ns.DetachedIconCenter({ x = 1.3, y = -2 }, 1920, 1080, 31) })
	end)

	it("reads nothing from a point that isn't one (CORE-R53)", function()
		local nan = 0 / 0
		for _, point in ipairs({ "corner", {}, { x = 0.5 }, { x = "0.5", y = 0.5 }, { x = nan, y = 0.5 }, { x = 0.5, y = math.huge } }) do
			assert.is_nil(ns.DetachedIconCenter(point, 1920, 1080, 31))
		end
		assert.is_nil(ns.DetachedIconCenter(nil, 1920, 1080, 31))
	end)
end)
