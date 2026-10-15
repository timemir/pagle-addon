-- The tracker dock's stacking rules as pure logic (CORE-R70–R72; core/README.md › Data, Tunables): which trackers
-- dock, their order, each visible frame's offset in the stack, and where the stack's anchor sits.

describe("ns.NewDock", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- A plain stand-in for a tracker frame: its height, width and whether it is shown, read as a frame's.
	local function frame(height, shown, width)
		return {
			height = height,
			width = width or 200,
			shown = shown ~= false,
			IsShown = function(self)
				return self.shown
			end,
			GetWidth = function(self)
				return self.width
			end,
			GetHeight = function(self)
				return self.height
			end,
		}
	end

	-- The ids of a layout's placements, top to bottom.
	local function ids(layout)
		local list = {}
		for i, placement in ipairs(layout.placements) do
			list[i] = placement.tracker.id
		end
		return list
	end

	it("stacks trackers top to bottom by order, 8 px apart, right-aligned to the anchor (CORE-R70)", function()
		local dock = ns.NewDock()
		local stats, hunts = frame(60), frame(40)
		assert.are.equal(stats, dock:Add("Stats", { id = "stats", order = 20, frame = stats }).frame)
		assert.are.equal(hunts, dock:Add("Hunts", { id = "hunts", order = 10, frame = hunts }).frame)

		local layout = dock:Layout()

		assert.are.same({ "hunts", "stats" }, ids(layout))
		assert.are.same({ point = "TOPRIGHT", relativePoint = "TOPRIGHT", x = 0, y = 0 }, {
			point = layout.placements[1].point,
			relativePoint = layout.placements[1].relativePoint,
			x = layout.placements[1].x,
			y = layout.placements[1].y,
		})
		-- Hunts is 40 px tall, then the 8 px between frames (Tunables).
		assert.are.equal(-48, layout.placements[2].y)
		assert.are.equal(108, layout.height)
		assert.are.equal(200, layout.width)
	end)

	it("leaves a hidden tracker out, so the next one moves up (CORE-R70, CORE-R72)", function()
		local dock = ns.NewDock()
		local hunts, stats = frame(40, false), frame(60)
		dock:Add("Hunts", { id = "hunts", order = 10, frame = hunts })
		dock:Add("Stats", { id = "stats", order = 20, frame = stats })

		local layout = dock:Layout()

		assert.are.same({ "stats" }, ids(layout))
		assert.are.equal(0, layout.placements[1].y)
		assert.are.equal(60, layout.height)
	end)

	it("shows nothing with no tracker visible (CORE-R72)", function()
		local dock = ns.NewDock()
		dock:Add("Hunts", { id = "hunts", order = 10, frame = frame(40, false) })

		local layout = dock:Layout()

		assert.are.same({}, layout.placements)
		assert.are.same({ 0, 0 }, { layout.width, layout.height })
	end)

	it("stacks a tie in order by Module name (CORE-R70)", function()
		local dock = ns.NewDock()
		dock:Add("TackleBoard", { id = "board", order = 30, frame = frame(10) })
		dock:Add("Stats", { id = "live", order = 30, frame = frame(10) })

		assert.are.same({ "live", "board" }, ids(dock:Layout()))
	end)

	it("follows a frame's new height at the next layout (CORE-R70: it reflows when one resizes)", function()
		local dock = ns.NewDock()
		local hunts = frame(40)
		dock:Add("Hunts", { id = "hunts", order = 10, frame = hunts })
		dock:Add("Stats", { id = "stats", order = 20, frame = frame(60, true, 260) })

		hunts.height = 100

		local layout = dock:Layout()
		assert.are.equal(-108, layout.placements[2].y)
		assert.are.equal(260, layout.width)
	end)

	local mistakes = {
		{ "a tracker that isn't a table", "nope", "takes a tracker table, got string" },
		{ "a missing id", { order = 10, frame = {} }, "the id must be a string, got nil" },
		{ "a non-string id", { id = 7, order = 10, frame = {} }, "the id must be a string, got 7" },
		{
			"a non-number order",
			{ id = "hunts", order = "10", frame = {} },
			"hunts's order must be a number, got string",
		},
		{ "a missing frame", { id = "hunts", order = 10 }, "hunts has no frame" },
	}
	for _, case in ipairs(mistakes) do
		it("refuses " .. case[1] .. ", docking nothing (CORE-R70)", function()
			local dock = ns.NewDock()

			local docked, problem = dock:Add("Hunts", case[2])

			assert.is_nil(docked)
			assert.are.equal("M:RegisterTracker: " .. case[3], problem)
			assert.are.same({}, dock:Trackers())
		end)
	end

	it("refuses an id already docked, by any Module, keeping the first (CORE-R70)", function()
		local dock = ns.NewDock()
		local first = frame(10)
		dock:Add("Hunts", { id = "hunts", order = 10, frame = first })

		assert.are.equal(
			"M:RegisterTracker: hunts is already docked",
			select(2, dock:Add("Stats", { id = "hunts", order = 20, frame = frame(10) }))
		)
		local trackers = dock:Trackers()
		assert.are.equal(1, #trackers)
		assert.are.equal(first, trackers[1].frame)
		assert.are.equal("Hunts", trackers[1].module)
	end)
end)

describe("ns.DockAnchor", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("is 10 px below the minimap cluster, right-aligned to it, with no point saved (CORE-R70, Tunables)", function()
		assert.are.same({
			point = "TOPRIGHT",
			relativeTo = "MinimapCluster",
			relativePoint = "BOTTOMRIGHT",
			x = 0,
			y = -10,
		}, ns.DockAnchor(nil))
	end)

	it("is the saved dock.point once moved (CORE-R71, core/README.md › Data)", function()
		local saved = { point = "TOPLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 812.5, y = 640 }

		assert.are.same(saved, ns.DockAnchor(saved))
	end)

	it("falls back to the default for a saved point it can't read (CORE-R70)", function()
		local default = ns.DockAnchor(nil)

		assert.are.same(default, ns.DockAnchor({ point = "TOPLEFT", relativeTo = "UIParent" }))
		assert.are.same(default, ns.DockAnchor("TOPLEFT"))
	end)
end)
