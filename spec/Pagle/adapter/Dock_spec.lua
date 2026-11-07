-- The tracker dock as Core runs it, through the real TOC, over fixture Modules that dock plain frames (CORE-R17,
-- CORE-R70–R72; core/README.md › Data, Settings, Tunables; settings.md SET-R1, SET-R40, SET-R93): M:RegisterTracker,
-- the stack under the minimap, Shift-drag, dock.point and the Trackers page's Reset.

-- The roster beyond the Ledger and Hunts that the fixture Modules dock under (coreWithTrackers).
local ROSTER = { "Stats", "TackleBoard" }

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

-- The trackers the Modules docked, in stack order: every docked one but Core's own First evening list (ONB-R60).
local function modulesTrackers(loaded)
	local list = {}
	for _, tracker in ipairs(loaded.ns.dock:Trackers()) do
		if tracker.module ~= "Core" then
			list[#list + 1] = tracker
		end
	end
	return list
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
			local loaded = coreWithTrackers(nil, ROSTER)
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
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		local _, stats = dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")
		local dock = loaded.ns.dockFrame

		hunts:SetShown(false)

		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(stats))
		assert.is_false(hunts:IsShown()) -- the dock only stacks; the Module shows and hides its own (CORE-R72)

		hunts:SetShown(true)

		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, -48 }, anchorOf(stats))
	end)

	it("reflows when a docked frame resizes (CORE-R70)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		local _, stats = dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")

		hunts:SetHeight(90)

		assert.are.same({ "TOPRIGHT", loaded.ns.dockFrame, "TOPRIGHT", 0, -98 }, anchorOf(stats))
	end)

	it("shows nothing with no tracker visible, and shows no tracker itself (CORE-R72)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		hunts:SetShown(false)

		loaded.client.fire("PLAYER_LOGIN")

		assert.is_false(hunts:IsShown())
		-- The anchor is invisible and keeps a 1 px size with nothing in it (core/README.md › UI).
		assert.are.same({ 1, 1 }, { loaded.ns.dockFrame:GetWidth(), loaded.ns.dockFrame:GetHeight() })
	end)

	it("stacks a tie in order by Module name (CORE-R70)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, board = dockFixture(loaded, "TackleBoard", 30, 50)
		local _, stats = dockFixture(loaded, "Stats", 30, 20)
		loaded.client.fire("PLAYER_LOGIN")
		local dock = loaded.ns.dockFrame

		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, anchorOf(stats))
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, -28 }, anchorOf(board))
	end)

	it("never holds a disabled Module's tracker: it registers nothing (CORE-R17, CORE-R70)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		loaded.client.addons.Pagle_Stats = { enabled = false, metadata = { ["X-Pagle-API"] = "1" } }
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)

		loaded.client.fire("PLAYER_LOGIN")

		local trackers = modulesTrackers(loaded)
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
			local loaded = coreWithTrackers(nil, ROSTER)
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
			assert.are.same({}, modulesTrackers(loaded))
			if tracker.frame then
				assert.are.equal(0, tracker.frame:GetNumPoints())
			end
		end)
	end

	it("raises an error for an id already docked by any Module, keeping the first (CORE-R70)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, first = dockFixture(loaded, "Hunts", 10, 40, "pins")
		local stats = loaded.env.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
		local second = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)

		local ok, err = pcall(function()
			stats:RegisterTracker({ id = "pins", order = 20, frame = second })
		end)

		assert.is_false(ok)
		assert.matches("Dock_spec.lua:%d+: M:RegisterTracker: pins is already docked", tostring(err))
		local trackers = modulesTrackers(loaded)
		assert.are.equal(1, #trackers)
		assert.are.equal(first, trackers[1].frame)
		assert.are.equal(0, second:GetNumPoints())
	end)

	it("is a handle method: called on anything else, it raises an error (CORE-R12)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local hunts = loaded.env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })

		assert.has_error(function()
			hunts.RegisterTracker({}, { id = "hunts", order = 10, frame = {} })
		end, "RegisterTracker is a Module handle method: call M:RegisterTracker({ id, order, frame })")
	end)
end)

describe("Moving the dock", function()
	it("Shift-dragging any docked frame moves the whole stack and saves dock.point (CORE-R71)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		local _, stats = dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")
		local dock = loaded.ns.dockFrame
		loaded.client.keysDown.SHIFT = true

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
		local first = coreWithTrackers(nil, ROSTER)
		local _, stats = dockFixture(first, "Stats", 20, 60)
		first.client.fire("PLAYER_LOGIN")
		first.client.keysDown.SHIFT = true
		startDrag(stats)
		dropAt(first, stats, 812, 640)

		local loaded = coreWithTrackers(first.env.PagleDB, ROSTER)
		dockFixture(loaded, "Stats", 20, 60)
		loaded.client.fire("PLAYER_LOGIN")

		assert.are.same({ "TOPRIGHT", loaded.env.UIParent, "BOTTOMLEFT", 812, 640 }, anchorOf(loaded.ns.dockFrame))
	end)

	it("starts no move on a drag without Shift (CORE-R71)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")

		startDrag(hunts)
		dropAt(loaded, hunts, 812, 640)

		assert.is_falsy(loaded.ns.dockFrame.moving)
		assert.is_nil(loaded.ns.db.profile.dock.point)
	end)

	it("never moves while restricted: a Shift-drag does nothing (CORE-R71)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")
		setCombat(loaded, true)
		loaded.client.keysDown.SHIFT = true

		startDrag(hunts)
		dropAt(loaded, hunts, 812, 640)

		assert.is_falsy(loaded.ns.dockFrame.moving)
		assert.is_nil(loaded.ns.db.profile.dock.point)
		assert.are.same({ "TOPRIGHT", loaded.env.MinimapCluster, "BOTTOMRIGHT", 0, -10 }, anchorOf(loaded.ns.dockFrame))
	end)

	it("stops a drag where it is when restriction starts, and saves it (CORE-R71)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.keysDown.SHIFT = true
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
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.keysDown.SHIFT = true
		startDrag(hunts)
		local dock = loaded.ns.dockFrame
		dock.screenRight, dock.screenTop = 700, 500

		hunts:SetShown(false)

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
			local loaded = coreWithTrackers(nil, ROSTER)
			dockFixture(loaded, "Hunts", 10, 40)

			loaded.client.fire("PLAYER_LOGIN")

			assert.is_nil(loaded.client.settings.category("Trackers"))
		end
	)

	it("starts with Core's two rows, then the Module's section (CORE-R42, SET-R1, SET-R40, SET-R46)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
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
			{ "Show trackers only while fishing" }, -- from 1.3 (SET-R46)
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
		local loaded = coreWithTrackers(nil, ROSTER)
		local hunts, frame = dockFixture(loaded, "Hunts", 10, 40)
		hunts:AddSetting("trackers", { kind = "header", label = "Hunts" })
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.keysDown.SHIFT = true
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

-- The Trackers page's "Show trackers only while fishing" setting (SET-R46), by its variable.
local WHILE_FISHING = "Pagle_Core_trackers_onlyWhileFishing"

-- Puts `itemID` in the main hand (nil empties it) and fires PLAYER_EQUIPMENT_CHANGED for it, as the client does.
-- 6256 is a Fishing Pole and 25 a Worn Shortsword in the fake client's items.
local function wield(loaded, itemID)
	loaded.client.mainHand = itemID
	loaded.client.fire("PLAYER_EQUIPMENT_CHANGED", 16, itemID == nil)
end

-- Core with Hunts and Stats docked, Hunts with a Trackers row, logged in and in the world, with "Show trackers only
-- while fishing" on, no pole in hand and no Cast yet. Returns Hunts' handle last.
local function whileFishing()
	local loaded = coreWithTrackers(nil, ROSTER)
	local handle, hunts = dockFixture(loaded, "Hunts", 10, 40)
	local _, stats = dockFixture(loaded, "Stats", 20, 60)
	-- A tracker Module's row, so the Trackers page and Core's rows on it register (SET-R1).
	handle:AddSetting("trackers", { kind = "header", label = "Hunts" })
	enterWorld(loaded)
	loaded.client.settings.variables[WHILE_FISHING]:SetValue(true)
	return loaded, hunts, stats, handle
end

describe("Only while fishing (CORE-R88, SET-R46)", function()
	it("is off by default: the dock shows with no pole in hand and no Cast, as before 1.3 (CORE-R88)", function()
		local loaded = coreWithTrackers(nil, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		enterWorld(loaded)

		assert.is_false(loaded.ns.db.profile.dock.onlyWhileFishing)
		assert.is_true(hunts:IsVisible())
	end)

	it("hides the whole dock at once when turned on with no pole in hand and no Cast (CORE-R88)", function()
		local _, hunts, stats = whileFishing()

		assert.is_false(hunts:IsVisible())
		assert.is_false(stats:IsVisible())
		-- The trackers' own shown state is the Modules' and stays as they set it (CORE-R72).
		assert.is_true(hunts:IsShown())
		assert.is_true(stats:IsShown())
	end)

	it(
		"shows the dock at once when turned off again, and saves the setting (CORE-R88, core/README.md › Data)",
		function()
			local loaded, hunts = whileFishing()
			assert.is_true(loaded.ns.db.profile.dock.onlyWhileFishing)

			loaded.client.settings.variables[WHILE_FISHING]:SetValue(false)

			assert.is_false(loaded.ns.db.profile.dock.onlyWhileFishing)
			assert.is_true(hunts:IsVisible())
		end
	)

	it(
		"shows the dock at once when a fishing pole goes in hand, and hides it at once when it comes off (CORE-R88)",
		function()
			local loaded, hunts = whileFishing()

			wield(loaded, 6256)
			assert.is_true(hunts:IsVisible())

			wield(loaded, 25)
			assert.is_false(hunts:IsVisible())
		end
	)

	it("shows the dock at login with a pole already in hand (CORE-R88)", function()
		local first = whileFishing()
		local loaded = coreWithTrackers(first.env.PagleDB, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)
		loaded.client.mainHand = 6256

		enterWorld(loaded)

		assert.is_true(hunts:IsVisible())
	end)

	it("hides the dock at login with the setting on and no pole in hand (CORE-R88)", function()
		local first = whileFishing()
		local loaded = coreWithTrackers(first.env.PagleDB, ROSTER)
		local _, hunts = dockFixture(loaded, "Hunts", 10, 40)

		enterWorld(loaded)

		assert.is_false(hunts:IsVisible())
		assert.is_true(hunts:IsShown())
	end)

	it("shows the dock from a Cast with no pole in hand, until 60 s after its end (CORE-R88, Tunables)", function()
		local loaded, hunts = whileFishing()

		loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
		assert.is_true(hunts:IsVisible())
		catchOne(loaded)
		loaded.client.advance(59)
		assert.is_true(hunts:IsVisible())

		loaded.client.advance(1)
		assert.is_false(hunts:IsVisible())
	end)

	it("keeps the dock up through a weapon swap mid-stretch, hiding it at the stretch's end (CORE-R88)", function()
		local loaded, hunts = whileFishing()
		wield(loaded, 6256)
		catchOne(loaded)

		wield(loaded, 25)
		assert.is_true(hunts:IsVisible())
		loaded.client.advance(30)
		wield(loaded, 6256)
		wield(loaded, 25)
		assert.is_true(hunts:IsVisible())

		loaded.client.advance(30)
		assert.is_false(hunts:IsVisible())
	end)

	it("counts the 60 s again from each Cast's end (CORE-R88)", function()
		local loaded, hunts = whileFishing()
		catchOne(loaded)
		loaded.client.advance(50)

		catchOne(loaded)
		loaded.client.advance(50)
		assert.is_true(hunts:IsVisible())

		loaded.client.advance(10)
		assert.is_false(hunts:IsVisible())
	end)

	it("keeps the dock up at the stretch's end while a pole is in hand (CORE-R88)", function()
		local loaded, hunts = whileFishing()
		catchOne(loaded)
		wield(loaded, 6256)

		loaded.client.advance(60)

		assert.is_true(hunts:IsVisible())
	end)

	it("shows and hides the dock in combat too: no docked tracker is a secure frame (CORE-R88)", function()
		local loaded, hunts = whileFishing()
		setCombat(loaded, true)

		wield(loaded, 6256)
		assert.is_true(hunts:IsVisible())
		wield(loaded, nil)
		assert.is_false(hunts:IsVisible())
	end)

	it("leaves a tracker its Module hid hidden when the dock shows (CORE-R72, CORE-R88)", function()
		local loaded, hunts, stats = whileFishing()
		hunts:SetShown(false)

		wield(loaded, 6256)

		assert.is_false(hunts:IsVisible())
		assert.is_true(stats:IsVisible())
		-- The stack is laid out as before: Stats moves up into Hunts' place.
		assert.are.same({ "TOPRIGHT", loaded.ns.dockFrame, "TOPRIGHT", 0, 0 }, anchorOf(stats))
	end)

	it("shows the dock while a dev tour runs, and hides it again once the tour is done (CORE-R88, CORE-R66)", function()
		local loaded, hunts, _, handle = whileFishing()
		local seen
		handle:RegisterTourStop("tracker", "the tracker", function()
			seen = hunts:IsVisible()
		end, function() end)
		loaded.env.SlashCmdList.PAGLE("dev on")

		loaded.env.SlashCmdList.PAGLE("dev tour hunts")
		assert.is_true(seen)
		assert.is_true(hunts:IsVisible())

		loaded.client.advance(60)
		assert.is_false(hunts:IsVisible())
	end)

	it(
		"is the Trackers page's second row, a native checkbox, off, with its tooltip, restored by Defaults (SET-R46)",
		function()
			local loaded = coreWithTrackers(nil, ROSTER)
			local hunts = dockFixture(loaded, "Hunts", 10, 40)
			hunts:AddSetting("trackers", { kind = "header", label = "Hunts" })
			enterWorld(loaded)
			local trackers = loaded.client.settings.page("Trackers")

			assert.are.same({
				{ "Tracker position", "Reset" },
				{ "Show trackers only while fishing" },
				{ "Hunts" },
			}, rowsOf(loaded, trackers))
			local row = trackers.layout.initializers[2]
			assert.are.equal(
				"Hides every Pagle tracker until a fishing pole is in hand or you cast. They stay up for a minute"
					.. " after your last Cast, so a quick weapon swap doesn't hide them.",
				row:GetTooltip()
			)
			local setting = loaded.client.settings.variables[WHILE_FISHING]
			assert.is_false(setting:GetValue())
			setting:SetValue(true)

			loaded.client.settings.defaults(trackers)

			assert.is_false(loaded.ns.db.profile.dock.onlyWhileFishing)
		end
	)
end)
