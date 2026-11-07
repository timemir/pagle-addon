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

describe("Only while fishing (CORE-R88)", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- The rule's input with the setting on and nothing holding the dock up; `fields` overrides.
	local function input(fields)
		local base = { onlyWhileFishing = true, poleInHand = false, stretch = false, touring = false }
		for key, value in pairs(fields or {}) do
			base[key] = value
		end
		return base
	end

	describe("ns.IsFishingPole", function()
		it("is a weapon (class 2) of the fishing pole subclass (20), as QoL's pole test reads it (CORE-R88)", function()
			assert.is_true(ns.IsFishingPole(2, 20))
			assert.is_false(ns.IsFishingPole(2, 7)) -- a one-handed sword
			assert.is_false(ns.IsFishingPole(4, 20))
			assert.is_false(ns.IsFishingPole(nil, nil)) -- an empty main hand, or an item the client doesn't know
		end)
	end)

	describe("ns.DockShown", function()
		it("is always true with the setting off, as before 1.3 (CORE-R88)", function()
			assert.is_true(ns.DockShown(input({ onlyWhileFishing = false })))
		end)

		it("with the setting on, is true while a fishing pole is in hand (CORE-R88)", function()
			assert.is_true(ns.DockShown(input({ poleInHand = true })))
		end)

		it("with the setting on, is true while the dock's fishing stretch runs (CORE-R88)", function()
			assert.is_true(ns.DockShown(input({ stretch = true })))
		end)

		it("with the setting on, is false with neither a pole in hand nor a stretch (CORE-R88)", function()
			assert.is_false(ns.DockShown(input()))
		end)

		it(
			"with the setting on, is true while a dev tour or the trailer runs, whatever else holds (CORE-R88)",
			function()
				assert.is_true(ns.DockShown(input({ touring = true })))
			end
		)
	end)

	describe("ns.NewDockStretch", function()
		it("isn't running until a Cast starts (CORE-R88)", function()
			assert.is_false(ns.NewDockStretch():IsRunning())
		end)

		it("runs from CastStarted, through the Cast and its CastEnded (CORE-R88)", function()
			local stretch = ns.NewDockStretch()

			stretch:CastStarted()
			assert.is_true(stretch:IsRunning())
			stretch:CastEnded()
			assert.is_true(stretch:IsRunning())
		end)

		it("ends when the idle count that CastEnded starts runs out with no Cast since (CORE-R88)", function()
			local stretch = ns.NewDockStretch()
			stretch:CastStarted()

			local count = stretch:CastEnded()

			assert.is_number(count)
			assert.is_true(stretch:Elapsed(count))
			assert.is_false(stretch:IsRunning())
			-- Ending twice ends nothing.
			assert.is_false(stretch:Elapsed(count))
		end)

		it("keeps running when an old count runs out after a new Cast started (CORE-R88)", function()
			local stretch = ns.NewDockStretch()
			stretch:CastStarted()
			local first = stretch:CastEnded()

			stretch:CastStarted()

			assert.is_false(stretch:Elapsed(first))
			assert.is_true(stretch:IsRunning())
			-- The new Cast's own CastEnded starts the count again, and that count ends it.
			local second = stretch:CastEnded()
			assert.is_false(stretch:Elapsed(first))
			assert.is_true(stretch:Elapsed(second))
			assert.is_false(stretch:IsRunning())
		end)

		it("starts no count at a CastEnded with no stretch running (CORE-R88)", function()
			assert.is_nil(ns.NewDockStretch():CastEnded())
		end)

		it(
			"counts DOCK_STRETCH_SECONDS, the 60 s QoL's Fishing stretch also waits (core/README.md › Tunables)",
			function()
				assert.are.equal(60, ns.DOCK_STRETCH_SECONDS)
			end
		)
	end)
end)
