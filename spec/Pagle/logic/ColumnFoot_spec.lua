-- Where the Toast column's foot is (announcements.md › Data, ANN-R98): logic/ColumnFoot.lua's saved-point reading and
-- its clamp to the screen.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

describe("where the Toast column's foot is (ANN-R98)", function()
	local SCREEN_WIDTH, SCREEN_HEIGHT = 1920, 1080

	it("is the middle of the screen's bottom, 156 up, with nothing saved", function()
		assert.are.same({ x = 0, y = 156 }, ns.ColumnFoot(nil))
	end)

	it("is the saved point, as a copy", function()
		local saved = { x = -300, y = 480.5 }

		local foot = ns.ColumnFoot(saved)

		assert.are.same({ x = -300, y = 480.5 }, foot)
		assert.are_not.equal(saved, foot)
	end)

	it("counts a saved value that isn't two finite numbers as none", function()
		local default = { x = 0, y = 156 }

		for _, bad in ipairs({
			"garbage",
			42,
			true,
			{},
			{ x = 10 },
			{ y = 10 },
			{ x = "10", y = 10 },
			{ x = 10, y = {} },
			{ x = 0 / 0, y = 10 },
			{ x = 10, y = math.huge },
			{ x = -math.huge, y = 10 },
		}) do
			assert.are.same(default, ns.ColumnFoot(bad))
		end
	end)

	it("keeps a foot where a full column fits the screen", function()
		assert.are.same({ x = 200, y = 400 }, ns.ClampColumnFoot({ x = 200, y = 400 }, SCREEN_WIDTH, SCREEN_HEIGHT))
		assert.are.same({ x = 0, y = 156 }, ns.ClampColumnFoot(ns.ColumnFoot(nil), SCREEN_WIDTH, SCREEN_HEIGHT))
	end)

	it("keeps the foot off the bottom edge, and the column's top, bookmark included, under the top edge", function()
		assert.are.same({ x = 0, y = 0 }, ns.ClampColumnFoot({ x = 0, y = -50 }, SCREEN_WIDTH, SCREEN_HEIGHT))
		assert.are.same(
			{ x = 0, y = SCREEN_HEIGHT - 300 - 22 },
			ns.ClampColumnFoot({ x = 0, y = 5000 }, SCREEN_WIDTH, SCREEN_HEIGHT)
		)
		assert.are.same({ x = 0, y = 758 }, ns.ClampColumnFoot({ x = 0, y = 758 }, SCREEN_WIDTH, SCREEN_HEIGHT))
	end)

	it("keeps the widest entry, a Nod's 662 units, on screen to either side", function()
		local room = SCREEN_WIDTH / 2 - 662 / 2

		assert.are.same({ x = -room, y = 100 }, ns.ClampColumnFoot({ x = -5000, y = 100 }, SCREEN_WIDTH, SCREEN_HEIGHT))
		assert.are.same({ x = room, y = 100 }, ns.ClampColumnFoot({ x = 5000, y = 100 }, SCREEN_WIDTH, SCREEN_HEIGHT))
		assert.are.same({ x = room, y = 100 }, ns.ClampColumnFoot({ x = room, y = 100 }, SCREEN_WIDTH, SCREEN_HEIGHT))
	end)

	it("keeps the widest toast page on screen too, if it is wider than a Nod", function()
		assert.is_true(ns.TOAST_WIDTH_MAX <= 22 + ns.NOD_WIDTH) -- the digest's 560 is the widest toast page
		assert.are.equal(560, ns.TOAST_WIDTH_MAX)
	end)

	it(
		"puts the foot at the bottom edge on a screen too short for a full column, and centres it on one too narrow",
		function()
			assert.are.same({ x = 40, y = 0 }, ns.ClampColumnFoot({ x = 40, y = 156 }, 1366, 300))
			assert.are.same({ x = 0, y = 156 }, ns.ClampColumnFoot({ x = 90, y = 156 }, 600, 768))
			assert.are.same({ x = 0, y = 0 }, ns.ClampColumnFoot({ x = 90, y = 156 }, 600, 300))
		end
	)

	it("leaves a foot as it is when the screen's size isn't known", function()
		assert.are.same({ x = 5000, y = 5000 }, ns.ClampColumnFoot({ x = 5000, y = 5000 }, nil, nil))
		assert.are.same({ x = 5000, y = 5000 }, ns.ClampColumnFoot({ x = 5000, y = 5000 }, 0, 0))
	end)
end)
