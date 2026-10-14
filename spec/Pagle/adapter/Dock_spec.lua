-- The tracker dock as Core runs it, through the real TOC, over fixture Modules that dock plain frames (CORE-R17,
-- CORE-R70–R72; core/README.md › Data, Settings, Tunables; settings.md SET-R1, SET-R40, SET-R93): M:RegisterTracker,
-- the stack under the minimap, Shift-drag, dock.point and the Trackers page's Reset.

-- Core over a saved PagleDB (`saved`, if given) with the Ledger, Hunts, Stats and the Tackle Board installed, before
-- PLAYER_LOGIN.
---@param saved table?
---@return LoadedAddon
local function session(saved)
	local loaded = loadCore(nil, saved)
	for _, name in ipairs({ "Stats", "TackleBoard" }) do
		loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
	end
	return loaded
end

-- Registers a fixture Module and docks a plain frame, `height` px tall and 200 wide, as tracker `id` at `order`.
-- Returns the handle and the frame.
---@param loaded LoadedAddon
---@param name string a roster name
---@param order number
---@param height number
---@param id string?
local function dockFixture(loaded, name, order, height, id)
	local env = loaded.env
	local handle = env.Pagle.RegisterModule({ name = name, title = name, order = order })
	local frame = env.CreateFrame("Frame", nil, env.UIParent)
	frame:SetSize(200, height)
	handle:RegisterTracker({ id = id or name:lower(), order = order, frame = frame })
	return handle, frame
end

-- Shows or hides a docked frame as the client does: the frame changes, then its OnShow or OnHide runs.
local function setShown(frame, shown)
	frame:SetShown(shown)
	local script = frame:GetScript(shown and "OnShow" or "OnHide")
	if script then
		script(frame)
	end
end

-- Resizes a docked frame as the client does: the frame changes, then its OnSizeChanged runs.
local function setHeight(frame, height)
	frame:SetHeight(height)
	local script = frame:GetScript("OnSizeChanged")
	if script then
		script(frame, frame:GetWidth(), height)
	end
end

-- A frame's first anchor, as { point, relativeTo, relativePoint, x, y }.
local function anchorOf(frame)
	return { frame:GetPoint(1) }
end

-- Starts a drag on a docked frame (OnDragStart), as the client does when the player drags it with the left button.
local function startDrag(frame)
	frame:GetScript("OnDragStart")(frame, "LeftButton")
end

-- The client moving the dock under the cursor to (right, top), then the player letting go (OnDragStop).
local function dropAt(loaded, frame, right, top)
	local dock = loaded.ns.dockFrame
	dock.screenRight, dock.screenTop = right, top
	frame:GetScript("OnDragStop")(frame)
end

-- The point Core saves for a dock dropped with its top right edge at (right, top) on the screen.
local function savedAt(right, top)
	return { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = right, y = top }
end

describe("The tracker dock", function()
	it(
		"stacks orders 10 above 20 with 8 px between, 10 px under the minimap cluster at its right edge (CORE-R70)",
		function()
			local loaded = session()
			local _, stats = dockFixture(loaded, "Stats", 20, 60)
			local _, hunts = dockFixture(loaded, "Hunts", 10, 40)

			loaded.client.fire("PLAYER_LOGIN")

			local dock = loaded.ns.dockFrame
			local env = loaded.env
			assert.are.same({ "TOPRIGHT", env.MinimapCluster, "BOTTOMRIGHT", 0, -10 }, anchorOf(dock))
			assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(hunts))
			assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, -48 }, anchorOf(stats))
			-- The anchor spans the stack, so it can be kept on screen as one.
			assert.are.same({ 200, 108 }, { dock:GetWidth(), dock:GetHeight() })
		end
	)

	it("moves the next tracker up when one hides, and back down when it shows (CORE-R70, CORE-R72)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		local _, stats = dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")
		local dock = loaded.ns.dockFrame

		setShown(hunts, false)

		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(stats))
		assert.is_false(hunts:IsShown()) -- the dock only stacks; the Module shows and hides its own (CORE-R72)

		setShown(hunts, true)

		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, -48 }, anchorOf(stats))
	end)

	it("reflows when a docked frame resizes (CORE-R70)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		local _, stats = dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")

		setHeight(hunts, 90)

		assert.are.same({ "TOPRIGHT", loaded.ns.dockFrame, "TOPRIGHT", 0, -98 }, anchorOf(stats))
	end)

	it("shows nothing with no tracker visible, and shows no tracker itself (CORE-R72)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		setShown(hunts, false)

		loaded.client.fire("PLAYER_LOGIN")

		assert.is_false(hunts:IsShown())
		-- The anchor is invisible and keeps a 1 px size with nothing in it (core/README.md › UI).
		assert.are.same({ 1, 1 }, { loaded.ns.dockFrame:GetWidth(), loaded.ns.dockFrame:GetHeight() })
	end)

	it("stacks a tie in order by Module name (CORE-R70)", function()
		local loaded = session()
		local _, board = dockFixture(loaded, "TackleBoard", 30, 50)
		local _, stats = dockFixture(loaded, "Stats", 30, 20)
		loaded.client.fire("PLAYER_LOGIN")
		local dock = loaded.ns.dockFrame

		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(stats))
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, -28 }, anchorOf(board))
	end)

	it("never holds a disabled Module's tracker: it registers nothing (CORE-R17, CORE-R70)", function()
		local loaded = session()
		loaded.client.addons.Pagle_Stats = { enabled = false, metadata = { ["X-Pagle-API"] = "1" } }
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)

		loaded.client.fire("PLAYER_LOGIN")

		local trackers = loaded.ns.dock:Trackers()
		assert.are.equal(1, #trackers)
		assert.are.equal(hunts, trackers[1].frame)
		assert.are.same({ "TOPRIGHT", loaded.ns.dockFrame, "TOPRIGHT", 0, 0 }, anchorOf(hunts))
	end)
end)

describe("M:RegisterTracker", function()
	local mistakes = {
		{ "a missing id", { order = 10 }, "the id must be a string, got nil" },
		{ "a non-string id", { id = 10, order = 10 }, "the id must be a string, got 10" },
		{ "a non-number order", { id = "hunts", order = "first" }, "hunts's order must be a number, got string" },
		{ "a missing frame", { id = "hunts", order = 10, noFrame = true }, "hunts has no frame" },
	}
	for _, case in ipairs(mistakes) do
		it("raises an error at the Module's call for " .. case[1] .. ", docking nothing (CORE-R70)", function()
			local loaded = session()
			local env = loaded.env
			local hunts = env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
			local tracker = { id = case[2].id, order = case[2].order }
			if not case[2].noFrame then
				tracker.frame = env.CreateFrame("Frame", nil, env.UIParent)
			end

			local ok, err = pcall(function()
				hunts:RegisterTracker(tracker)
			end)

			assert.is_false(ok)
			assert.matches("Dock_spec.lua:%d+: M:RegisterTracker: " .. case[3]:gsub("%p", "%%%0"), tostring(err))
			assert.are.same({}, loaded.ns.dock:Trackers())
			if tracker.frame then
				assert.are.equal(0, tracker.frame:GetNumPoints())
			end
		end)
	end

	it("raises an error for an id already docked by any Module, keeping the first (CORE-R70)", function()
		local loaded = session()
		local _, first = dockFixture(loaded, "Hunts", 10, 40, "pins")
		local stats = loaded.env.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
		local second = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)

		local ok, err = pcall(function()
			stats:RegisterTracker({ id = "pins", order = 20, frame = second })
		end)

		assert.is_false(ok)
		assert.matches("Dock_spec.lua:%d+: M:RegisterTracker: pins is already docked", tostring(err))
		local trackers = loaded.ns.dock:Trackers()
		assert.are.equal(1, #trackers)
		assert.are.equal(first, trackers[1].frame)
		assert.are.equal(0, second:GetNumPoints())
	end)

	it("is a handle method: called on anything else, it raises an error (CORE-R12)", function()
		local loaded = session()
		local hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })

		assert.has_error(function()
			hunts.RegisterTracker({}, { id = "hunts", order = 10, frame = {} })
		end, "RegisterTracker is a Module handle method: call M:RegisterTracker({ id, order, frame })")
	end)
end)

describe("Moving the dock", function()
	it("Shift-dragging any docked frame moves the whole stack and saves dock.point (CORE-R71)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		local _, stats = dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")
		local dock = loaded.ns.dockFrame
		loaded.client.shiftDown = true

		startDrag(stats)

		assert.is_true(dock.moving)
		assert.is_true(dock:IsMovable())
		dropAt(loaded, stats, 812, 640)

		assert.is_false(dock.moving)
		assert.are.same(savedAt(812, 640), loaded.ns.db.profile.dock.point)
		-- The anchor keeps its top right where it was dropped, so the stack grows down from there.
		assert.are.same({ "TOPRIGHT", loaded.env.UIParent, "BOTTOMLEFT", 812, 640 }, anchorOf(dock))
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(hunts))
	end)

	it("anchors the dock at dock.point at the next login (CORE-R71, core/README.md › Data)", function()
		local first = session()
		local _, stats = dockFixture(first, "Stats", 20, 60)
		first.client.fire("PLAYER_LOGIN")
		first.client.shiftDown = true
		startDrag(stats)
		dropAt(first, stats, 812, 640)

		local loaded = session(first.env.PagleDB)
		dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({ "TOPRIGHT", loaded.env.UIParent, "BOTTOMLEFT", 812, 640 }, anchorOf(loaded.ns.dockFrame))
	end)

	it("starts no move on a drag without Shift (CORE-R71)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")

		startDrag(hunts)
		dropAt(loaded, hunts, 812, 640)

		assert.is_falsy(loaded.ns.dockFrame.moving)
		assert.is_nil(loaded.ns.db.profile.dock.point)
	end)

	it("never moves while restricted: a Shift-drag does nothing (CORE-R71)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)
		loaded.client.shiftDown = true

		startDrag(hunts)
		dropAt(loaded, hunts, 812, 640)

		assert.is_falsy(loaded.ns.dockFrame.moving)
		assert.is_nil(loaded.ns.db.profile.dock.point)
		assert.are.same({ "TOPRIGHT", loaded.env.MinimapCluster, "BOTTOMRIGHT", 0, -10 }, anchorOf(loaded.ns.dockFrame))
	end)

	it("stops a drag where it is when restriction starts, and saves it (CORE-R71, drafted default)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.shiftDown = true
		startDrag(hunts)
		local dock = loaded.ns.dockFrame
		dock.screenRight, dock.screenTop = 700, 500

		setCombat(loaded, true)

		assert.is_false(dock.moving)
		assert.are.same(savedAt(700, 500), loaded.ns.db.profile.dock.point)
		-- Letting go later changes nothing.
		dropAt(loaded, hunts, 300, 300)
		assert.are.same(savedAt(700, 500), loaded.ns.db.profile.dock.point)
	end)

	it("stops a drag where it is when the dragged tracker hides, and saves it (CORE-R71)", function()
		local loaded = session()
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.shiftDown = true
		startDrag(hunts)
		local dock = loaded.ns.dockFrame
		dock.screenRight, dock.screenTop = 700, 500

		setShown(hunts, false)

		assert.is_false(dock.moving)
		assert.are.same(savedAt(700, 500), loaded.ns.db.profile.dock.point)
	end)
end)

-- The rows of a shown page, as { label, button caption } for a button row and { label } for any other.
local function rowsOf(loaded, category)
	local rows = {}
	for i, row in ipairs(loaded.client.settings.show(category)) do
		local buttons = loaded.client.settings.buttonsOf(row.frame)
		rows[i] = { row.initializer:GetName(), buttons[1] and buttons[1]:GetText() }
	end
	return rows
end

-- The Reset button on the shown Trackers page.
local function resetButton(loaded)
	local rows = loaded.client.settings.show(loaded.client.settings.category("Trackers"))
	return loaded.client.settings.buttonsOf(rows[1].frame)[1]
end

describe("The Trackers page", function()
	it(
		"isn't registered with no tracker Module's row: Core's row never registers it alone (SET-R1, SET-R40)",
		function()
			local loaded = session()
			dockFixture(loaded, "Hunts", 10, 40)

			loaded.client.fire("PLAYER_LOGIN")

			assert.is_nil(loaded.client.settings.category("Trackers"))
		end
	)

	it("starts with Core's Tracker position row, then the Module's section (CORE-R42, SET-R1, SET-R40)", function()
		local loaded = session()
		local hunts = dockFixture(loaded, "Hunts", 10, 40)
		hunts:AddSetting("trackers", {
			kind = "checkbox",
			label = "Show the Hunts tracker",
			get = function()
				return true
			end,
			set = function() end,
			default = true,
		})

		loaded.client.fire("PLAYER_LOGIN")

		local trackers = assert(loaded.client.settings.category("Trackers"))
		assert.are.same({
			{ "Tracker position", "Reset" },
			{ "Hunts" },
			{ "Show the Hunts tracker" },
		}, rowsOf(loaded, trackers))
		local reset = trackers.layout.initializers[1]
		assert.are.equal(
			"Shift-drag any Pagle tracker to move them all. This puts them back under the minimap.",
			reset:GetTooltip()
		)
		assert.are.same({}, reset.modifyPredicates) -- never greyed out
		-- After Announcements, as SET-R1 orders the pages (no Fishing here: QoL isn't On).
		assert.are.equal("Announcements", loaded.client.settings.categories[2].name)
		assert.are.equal("Trackers", loaded.client.settings.categories[3].name)
	end)

	-- Core with Hunts docked and given a Trackers row, logged in, the dock Shift-dragged to (812, 640).
	local function movedDock()
		local loaded = session()
		local hunts, frame = dockFixture(loaded, "Hunts", 10, 40)
		hunts:AddSetting("trackers", { kind = "header", label = "Hunts" })
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.shiftDown = true
		startDrag(frame)
		dropAt(loaded, frame, 812, 640)
		return loaded, frame
	end

	it("Reset clears dock.point and puts the dock back under the minimap (CORE-R71, SET-R40)", function()
		local loaded, frame = movedDock()

		resetButton(loaded):Click()

		assert.is_nil(loaded.ns.db.profile.dock.point)
		local dock = loaded.ns.dockFrame
		assert.are.same({ "TOPRIGHT", loaded.env.MinimapCluster, "BOTTOMRIGHT", 0, -10 }, anchorOf(dock))
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(frame))
	end)

	it("Reset does nothing while restricted, though it isn't greyed out (SET-R40, SET-R93)", function()
		local loaded = movedDock()
		setCombat(loaded, true)

		local reset = resetButton(loaded)
		assert.is_true(reset:IsEnabled())
		reset:Click()

		assert.are.same(savedAt(812, 640), loaded.ns.db.profile.dock.point)
		assert.are.same({ "TOPRIGHT", loaded.env.UIParent, "BOTTOMLEFT", 812, 640 }, anchorOf(loaded.ns.dockFrame))
	end)
end)
