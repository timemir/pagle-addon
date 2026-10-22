-- The display queue, the Interruption budget and Announcement sounds (announcements.md › The display queue,
-- › Interruption budget, › Sounds): logic/Announcements.lua fed Announcements and a clock.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newClock = dofile("spec/support/timers.lua").newClock

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"
-- How long each entry stays from when it appears (its motion settles, then its hold): a toast on its page, a Nod and
-- a banner, whose place frees LEAVE once it has left.
local TOAST, LOW, HIGH, NOD, BANNER, LEAVE = 8.7, 6.7, 10.7, 3.3, 5.9, 0.5

-- Lanes over a fake clock. `world.visible` is what is on screen now, in the order it appeared; `world.log` every show
-- and hide as "show <form> <title>" / "hide <form> <title>"; `world.played` each sound path. `world.budget` is the
-- player's Interruption budget setting, `world.cozy` Cozy mode and `world.serverTime` the server time expiry reads.
local function newWorld()
	local clock = newClock()
	local world = {
		visible = {},
		log = {},
		played = {},
		shown = {},
		budget = { on = true, count = 4, window = 300 },
		cozy = false,
		serverTime = SERVER_TIME,
	}
	world.lanes = ns.NewLanes({
		now = clock.time,
		after = clock.after,
		budget = function()
			return world.budget
		end,
		cozy = function()
			return world.cozy
		end,
		serverTime = function()
			return world.serverTime
		end,
		soundSet = function()
			return ns.SOUND_SETS["core.soundset.driftwood"]
		end,
		show = function(display)
			world.visible[#world.visible + 1] = display
			world.shown[#world.shown + 1] = display
			world.log[#world.log + 1] = "show " .. display.form .. " " .. display.announcement.headline.title
		end,
		hide = function(display)
			for i, shown in ipairs(world.visible) do
				if shown == display then
					table.remove(world.visible, i)
					break
				end
			end
			world.log[#world.log + 1] = "hide " .. display.form .. " " .. display.announcement.headline.title
		end,
		play = function(path)
			world.played[#world.played + 1] = path
		end,
		empty = function()
			world.emptied = world.emptied + 1
		end,
	})
	world.advance = clock.advance
	world.emptied = 0
	return world
end

-- An Announcement whose headline is a moment on `rung` titled `title`, with other headline fields from `fields`.
local function announcement(rung, title, fields)
	local headline = { rung = rung, kind = "spec", title = title, module = "Ledger", moduleOrder = 10, raised = 1 }
	for key, value in pairs(fields or {}) do
		headline[key] = value
	end
	return {
		headline = headline,
		rung = rung,
		stamps = {},
		more = 0,
		coins = headline.coins or 0,
		moments = { headline },
	}
end

-- The headline titles of `displays`, in order.
local function titles(displays)
	local list = {}
	for i, display in ipairs(displays) do
		list[i] = display.announcement.headline.title
	end
	return list
end

-- The column on screen, the newest first, each as "<form> <title>".
local function column(world)
	local list = {}
	for _, display in ipairs(world.visible) do
		if display.form == "toast" or display.form == "nod" then
			table.insert(list, 1, display.form .. " " .. display.announcement.headline.title)
		end
	end
	return list
end

-- The centre's banner or splash on screen, or nil.
local function centreOf(world)
	for _, display in ipairs(world.visible) do
		if display.form == "banner" or display.form == "splash" then
			return display
		end
	end
	return nil
end

-- The title in the centre, or nil.
local function centre(world)
	local display = centreOf(world)
	return display and display.announcement.headline.title
end

-- The display on screen titled `title`.
local function displayOf(world, title)
	for _, display in ipairs(world.visible) do
		if display.announcement.headline.title == title then
			return display
		end
	end
	error("nothing on screen titled " .. title)
end

describe("the display queue", function()
	it("shows a toast at once, which stays until it has settled and then its page's hold (ANN-R20)", function()
		local world = newWorld()

		world.lanes:Push(announcement("toast", "New Species"))

		assert.are.same({ "toast New Species" }, column(world))
		world.advance(TOAST - 0.01)
		assert.are.same({ "toast New Species" }, column(world))
		world.advance(0.01)
		assert.are.same({}, column(world))
		assert.are.same({ "show toast New Species", "hide toast New Species" }, world.log)
	end)

	it(
		"holds a toast.low 4 s, a ruled one 5 s and a toast.high 8 s, ruled or not, once each has settled at 2.7 s"
			.. " (ANN-R20)",
		function()
			local RULER = { old = 1, new = 2, unit = "lb", label = "weight" }
			local stays = {}
			local cases = {
				{ "toast.low", LOW },
				{ "toast.low", LOW + 1, RULER },
				{ "toast.high", HIGH },
				{ "toast.high", HIGH, RULER }, -- drawn on the ruled toast page, held as its rung
			}
			for _, case in ipairs(cases) do
				local world = newWorld()
				world.lanes:Push(announcement(case[1], "Toast", { ruler = case[3] }))
				world.advance(case[2] - 0.01)
				local before = #column(world)
				world.advance(0.01)
				stays[#stays + 1] = { before, #column(world) }
			end

			assert.are.same({ { 1, 0 }, { 1, 0 }, { 1, 0 }, { 1, 0 } }, stays)
		end
	)

	it(
		"stacks at most 3 toasts in the column, the newest at its foot; the rest wait in order, a Nod too, and come"
			.. " in as room frees (ANN-R20)",
		function()
			local world = newWorld()
			for i = 1, 5 do
				world.lanes:Push(announcement("toast", "Toast " .. i))
			end
			world.lanes:Push(announcement("nod", "New here"))

			assert.are.same({ "toast Toast 3", "toast Toast 2", "toast Toast 1" }, column(world))
			world.advance(TOAST)

			assert.are.same({ "nod New here", "toast Toast 5", "toast Toast 4" }, column(world))
		end
	)

	it("keeps the column under 300 units: a third toast.high waits for room (ANN-R20)", function()
		local world = newWorld()
		for i = 1, 3 do
			world.lanes:Push(announcement("toast.high", "Hunt " .. i))
		end

		assert.are.same({ "toast Hunt 2", "toast Hunt 1" }, column(world))
		world.advance(HIGH)
		assert.are.same({ "toast Hunt 3" }, column(world))
	end)

	it(
		"holds a toast's clock while the pointer is on it, going on from where it stood, and sends it away when"
			.. " clicked (ANN-R20)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "Paused"))
			world.advance(3)

			world.lanes:Pause(displayOf(world, "Paused"))
			world.advance(60)
			assert.are.same({ "toast Paused" }, column(world))
			world.lanes:Resume(displayOf(world, "Paused"))
			world.advance(TOAST - 3 - 0.01)
			assert.are.same({ "toast Paused" }, column(world))
			world.advance(0.01)
			assert.are.same({}, column(world))

			world.lanes:Push(announcement("nod", "Clicked"))
			world.lanes:Dismiss(displayOf(world, "Clicked"))
			assert.are.same({}, column(world))
		end
	)

	it(
		"shows banners one at a time, each until it has settled and stayed 4.5 s, the next once it has left;"
			.. " waiting splashes first (ANN-R20)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("banner", "Banner 1"))
			world.lanes:Push(announcement("banner", "Banner 2"))
			world.lanes:Push(announcement("splash", "Splash 1"))
			world.lanes:Push(announcement("banner", "Banner 3"))
			world.lanes:Push(announcement("splash", "Splash 2"))

			world.advance(BANNER - 0.01)
			assert.are.equal("Banner 1", centre(world))
			world.advance(0.01)
			assert.is_nil(centre(world))
			world.advance(LEAVE)
			assert.are.equal("Splash 1", centre(world))
			world.advance(60)

			assert.are.same({ "Banner 1", "Splash 1", "Splash 2", "Banner 2", "Banner 3" }, titles(world.shown))
		end
	)

	it(
		"lets a splash wait for the column's toasts to leave, and starts no toast or Nod while it waits or shows"
			.. " (ANN-R20)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("splash", "Legend"))
			world.lanes:Push(announcement("toast", "Hunt completed"))
			assert.are.same({ { "toast New Species" }, nil }, { column(world), centre(world) })

			world.advance(TOAST)
			assert.are.same({ {}, "Legend" }, { column(world), centre(world) })
			world.lanes:Push(announcement("nod", "New here"))
			world.advance(7.9)
			assert.are.same({ {}, "Legend" }, { column(world), centre(world) })
			world.advance(0.1)

			assert.are.same({ "nod New here", "toast Hunt completed" }, column(world))
			assert.are.same({ "New Species", "Legend", "Hunt completed", "New here" }, titles(world.shown))
		end
	)

	it("keeps a splash up until clicked or 8 s (ANN-R20)", function()
		local world = newWorld()
		world.lanes:Push(announcement("splash", "Legend"))
		world.lanes:Push(announcement("splash", "Another Legend"))

		world.advance(2)
		world.lanes:Dismiss(centreOf(world) --[[@as table]])
		assert.are.equal("Another Legend", centre(world))
		world.advance(7.9)
		assert.are.equal("Another Legend", centre(world))
		world.advance(0.1)
		assert.is_nil(centre(world))
	end)

	it("shows a Nod in the column for 3.3 s, beside a banner (ANN-R20)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Level 12"))

		world.lanes:Push(announcement("nod", "New here"))

		assert.are.same({ { "nod New here" }, "Level 12" }, { column(world), centre(world) })
		world.advance(NOD)
		assert.are.same({}, column(world))
	end)
end)

describe("the lanes' empty state, for the cards", function()
	it("is empty only while no toast, banner or splash is on screen or waits; a Nod doesn't count (ANN-R21)", function()
		local world = newWorld()
		assert.is_true(world.lanes:IsEmpty())
		world.lanes:Push(announcement("nod", "Uncharted"))
		assert.is_true(world.lanes:IsEmpty())

		world.lanes:Push(announcement("toast", "New Species"))
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("banner", "Zone Master"))
		assert.is_false(world.lanes:IsEmpty())
		world.advance(TOAST)
		assert.is_false(world.lanes:IsEmpty())
		world.advance(2 * BANNER + 2 * LEAVE - TOAST)
		assert.is_true(world.lanes:IsEmpty())
	end)

	it(
		"tells the cards each time the toasts and the centre free with nothing waiting, never for a Nod (ANN-R21)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "Toast 1"))
			world.lanes:Push(announcement("toast", "Toast 2"))
			world.lanes:Push(announcement("banner", "Level 12"))

			world.advance(BANNER + LEAVE)
			assert.are.equal(0, world.emptied)
			world.advance(TOAST - BANNER - LEAVE)
			assert.are.equal(1, world.emptied)

			world.lanes:Push(announcement("splash", "Legend"))
			world.lanes:Dismiss(centreOf(world) --[[@as table]])
			assert.are.equal(2, world.emptied)
			world.lanes:Push(announcement("nod", "Uncharted"))
			world.advance(NOD)
			assert.are.equal(2, world.emptied)
		end
	)
end)

describe("the Interruption budget", function()
	-- Pushes `n` toasts at `rung`, each shown in full before the next.
	local function interrupt(world, n, rung)
		for i = 1, n do
			world.lanes:Push(announcement(rung or "toast", "Interruption " .. i))
			world.advance(rung == "banner" and BANNER + LEAVE or TOAST)
		end
	end

	it("steps the 5th toast.low in 5 minutes down to a Nod, while a toast gets through (ANN-R30, ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 2, "toast")
		interrupt(world, 1, "banner")
		interrupt(world, 1, "toast.low")

		world.lanes:Push(announcement("toast.low", "Size record"))
		assert.are.same({ "nod Size record" }, column(world))
		world.advance(NOD)
		world.lanes:Push(announcement("toast", "New Species"))

		assert.are.same({ "toast New Species" }, column(world))
	end)

	it("counts a Cast's banner and its toast, shown together, as 2 interruptions (ANN-R30, ANN-R31)", function()
		local world = newWorld()
		world.budget = { on = true, count = 2, window = 300 }
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("toast", "New Species"))
		world.advance(TOAST)

		world.lanes:Push(announcement("toast.low", "Size record"))

		assert.are.same({ "nod Size record" }, column(world))
	end)

	it("counts only the interruptions of the last window (ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 4)
		world.advance(300 - 4 * TOAST)

		world.lanes:Push(announcement("toast.low", "Size record"))

		assert.are.same({ "toast Size record" }, column(world))
	end)

	it("steps a waiting toast.low down when it reaches the front (ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 3)
		for i = 1, 3 do
			world.lanes:Push(announcement("toast", "Toast " .. i))
		end
		world.lanes:Push(announcement("toast.low", "Size record"))

		world.advance(TOAST)

		assert.are.same({ "nod Size record" }, column(world))
	end)

	it("reads the count and window from the player's setting (ANN-R32)", function()
		local world = newWorld()
		world.budget = { on = true, count = 1, window = 60 }
		interrupt(world, 1)

		world.lanes:Push(announcement("toast.low", "Size record"))
		world.advance(60)
		world.lanes:Push(announcement("toast.low", "New junk"))

		assert.are.same({ "Interruption 1", "Size record", "New junk" }, titles(world.shown))
		assert.are.same({ "toast", "nod", "toast" }, { world.shown[1].form, world.shown[2].form, world.shown[3].form })
	end)

	it("steps nothing down with the budget off (ANN-R32)", function()
		local world = newWorld()
		world.budget = { on = false, count = 4, window = 300 }
		interrupt(world, 4)

		world.lanes:Push(announcement("toast.low", "Size record"))

		assert.are.same({ "toast Size record" }, column(world))
	end)
end)

describe("the combat hold", function()
	-- The "While you were fighting" toast on screen's held headlines, in order.
	local function fighting(world)
		local held = {}
		for i, headline in ipairs(displayOf(world, "While you were fighting").announcement.fighting) do
			held[i] = headline.title
		end
		return held
	end

	it("hides the banner and the column's toasts and holds them, dropping the Nods (ANN-R35)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("nod", "New here"))
		world.lanes:Push(announcement("toast", "New Species"))

		world.lanes:Hold()

		assert.are.same({}, world.visible)
		assert.is_true(world.lanes:IsHeld())
		world.lanes:Release()
		world.advance(2)
		assert.are.same({ { "toast New Species" }, "Level 12" }, { column(world), centre(world) })
	end)

	it("holds every new Announcement and plays nothing while restricted (ANN-R35)", function()
		local world = newWorld()
		world.lanes:Hold()

		world.lanes:Push(announcement("toast", "New Species"))
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("splash", "Legend"))
		world.lanes:Push(announcement("nod", "New here"))
		world.advance(60)

		assert.are.same({}, world.shown)
		assert.are.same({}, world.played)
	end)

	it(
		"2 s after combat shows held splashes then banners as themselves, and 3 or more held toasts as one While you"
			.. " were fighting toast listing them all (ANN-R36)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("toast.low", "Size record"))
			world.lanes:Hold()
			world.lanes:Push(announcement("toast.high", "Hunt completed"))
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("splash", "Legend"))

			world.lanes:Release()
			world.advance(1.9)
			assert.are.same({ "New Species", "Size record" }, titles(world.shown))
			world.advance(0.1)
			assert.are.same({ {}, "Legend" }, { column(world), centre(world) })
			world.lanes:Dismiss(centreOf(world) --[[@as table]])

			assert.are.same({ { "toast While you were fighting" }, "Level 12" }, { column(world), centre(world) })
			assert.are.same({ "New Species", "Size record", "Hunt completed" }, fighting(world))
		end
	)

	it(
		"shows 1 or 2 held toasts as themselves, a held Cast's toast with its banner, playing only the banner's sound"
			.. " (ANN-R24, ANN-R36)",
		function()
			local world = newWorld()
			world.lanes:Hold()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("toast.low", "Size record"))

			world.lanes:Release()
			world.advance(2)

			assert.are.same(
				{ { "toast Size record", "toast New Species" }, "Level 12" },
				{ column(world), centre(world) }
			)
			assert.are.same({ SOUNDS .. "driftwood\\banner.ogg" }, world.played)
		end
	)

	it("plays the toast sound once for the While you were fighting toast, which never steps down (ANN-R36)", function()
		local world = newWorld()
		world.budget = { on = true, count = 1, window = 300 }
		world.lanes:Push(announcement("toast.low", "Size record"))
		world.lanes:Hold()
		world.lanes:Push(announcement("toast.low", "New junk"))
		world.lanes:Push(announcement("toast.low", "New curio"))
		world.played = {}

		world.lanes:Release()
		world.advance(2)

		assert.are.same({ "toast While you were fighting" }, column(world))
		assert.are.same({ SOUNDS .. "driftwood\\toast_2.ogg" }, world.played)
	end)

	it(
		"restarts the 2 s wait when a restriction starts inside it, holding what arrives meanwhile (ANN-R35, ANN-R36)",
		function()
			local world = newWorld()
			world.lanes:Hold()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Release()
			world.advance(1.5)
			world.lanes:Push(announcement("toast", "New Species"))
			assert.is_true(world.lanes:IsHeld())

			world.lanes:Hold()
			world.lanes:Release()
			world.advance(1.9)
			assert.are.same({}, world.shown)
			world.advance(0.1)

			assert.are.same({ { "toast New Species" }, "Level 12" }, { column(world), centre(world) })
			assert.is_false(world.lanes:IsHeld())
		end
	)

	it("never shows a held Nod again (ANN-R36)", function()
		local world = newWorld()
		world.lanes:Push(announcement("nod", "New here"))
		world.lanes:Hold()
		world.lanes:Push(announcement("nod", "Uncharted"))

		world.lanes:Release()
		world.advance(60)

		assert.are.same({ "New here" }, titles(world.shown))
	end)

	it(
		"tells the cards the lanes are empty once what it held has shown, or at once with nothing held (ANN-R36)",
		function()
			local world = newWorld()
			world.lanes:Hold()
			world.lanes:Release()
			world.advance(2)
			assert.are.equal(1, world.emptied)

			world.lanes:Hold()
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Release()
			world.advance(2)
			assert.are.equal(1, world.emptied)
			world.advance(TOAST)
			assert.are.equal(2, world.emptied)
		end
	)

	it("counts held Announcements toward the budget only when they show (ANN-R37)", function()
		local world = newWorld()
		world.budget = { on = true, count = 2, window = 300 }
		world.lanes:Hold()
		for i = 1, 3 do
			world.lanes:Push(announcement("toast.low", "Held " .. i))
		end
		world.lanes:Push(announcement("nod", "New here"))
		world.lanes:Release()
		world.advance(2)
		world.advance(HIGH) -- the digest holds as long as a toast.high

		world.lanes:Push(announcement("toast.low", "Size record"))
		assert.are.same({ "toast Size record" }, column(world))
		world.advance(LOW)
		world.lanes:Push(announcement("toast.low", "New junk"))

		assert.are.same({ "nod New junk" }, column(world))
	end)
end)

describe("hold reasons", function()
	it(
		"holds for the guide as for combat: what is on screen hidden, everything new held, Nods dropped (ANN-R38)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("nod", "New here"))
			world.lanes:Push(announcement("toast", "New Species"))

			world.lanes:Hold("guide")
			world.lanes:Push(announcement("toast", "Size record"))
			world.lanes:Push(announcement("nod", "Uncharted"))
			world.advance(60)

			assert.are.same({}, world.visible)
			assert.are.same({ true, true, false }, {
				world.lanes:IsHeld(),
				world.lanes:IsHeld("guide"),
				world.lanes:IsHeld("combat"),
			})
			assert.are.same({ "Level 12", "New here", "New Species" }, titles(world.shown))
		end
	)

	it(
		"shows what the guide alone held at once on its release: Nods dropped, toasts as themselves in order (ANN-R38,"
			.. " ONB-R70)",
		function()
			local world = newWorld()
			world.lanes:Hold("guide")
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("nod", "New here"))
			world.lanes:Push(announcement("toast.low", "Size record"))

			world.lanes:Release("guide")

			assert.are.same({ "toast Size record", "toast New Species" }, column(world))
			assert.is_false(world.lanes:IsHeld())
			world.advance(60)
			assert.are.same({ "New Species", "Size record" }, titles(world.shown))
		end
	)

	it(
		"never folds what the guide alone held into While you were fighting: 3 or more toasts show as themselves, in"
			.. " turn, with the banner (ANN-R38)",
		function()
			local world = newWorld()
			world.lanes:Hold("guide")
			world.lanes:Push(announcement("banner", "Level 12"))
			for i = 1, 4 do
				world.lanes:Push(announcement("toast", "Toast " .. i))
			end

			world.lanes:Release("guide")

			assert.are.same(
				{ { "toast Toast 3", "toast Toast 2", "toast Toast 1" }, "Level 12" },
				{ column(world), centre(world) }
			)
			world.advance(TOAST + LEAVE)
			assert.are.same({ "toast Toast 4" }, column(world))
		end
	)

	it(
		"stays held for combat when the guide is released inside a combat hold, then shows by combat's rules (ANN-R36,"
			.. " ANN-R38, ONB-R25)",
		function()
			local world = newWorld()
			world.lanes:Hold("guide")
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Hold("combat")
			world.lanes:Push(announcement("toast", "Size record"))
			world.lanes:Push(announcement("toast.high", "Hunt completed"))

			world.lanes:Release("guide")
			assert.are.same({ true, false }, { world.lanes:IsHeld(), world.lanes:IsHeld("guide") })
			world.advance(60)
			assert.are.same({}, world.shown)

			world.lanes:Release("combat")
			world.advance(1.9)
			assert.are.same({}, world.shown)
			world.advance(0.1)
			assert.are.same({ "toast While you were fighting" }, column(world))
		end
	)

	it(
		"shows by combat's rules, at once, when the guide reopened inside the wait after combat ends last (ANN-R36,"
			.. " ANN-R38, ONB-R25)",
		function()
			local world = newWorld()
			world.lanes:Hold("combat")
			for i = 1, 3 do
				world.lanes:Push(announcement("toast", "Toast " .. i))
			end
			world.lanes:Release("combat")
			world.lanes:Hold("guide")
			world.advance(2)
			assert.are.same({ true, false }, { world.lanes:IsHeld(), world.lanes:IsHeld("combat") })
			world.advance(60)
			assert.are.same({}, world.shown)

			world.lanes:Release("guide")

			assert.are.same({ "toast While you were fighting" }, column(world))
		end
	)

	it("leaves combat's 2 s wait as it runs when the guide holds and releases inside it (ANN-R36, ANN-R38)", function()
		local world = newWorld()
		world.lanes:Hold("combat")
		world.lanes:Push(announcement("toast", "New Species"))
		world.lanes:Release("combat")
		world.advance(1)
		world.lanes:Hold("guide")
		world.lanes:Release("guide")
		assert.are.same({}, world.shown)

		world.advance(1)

		assert.are.same({ "toast New Species" }, column(world))
		assert.is_false(world.lanes:IsHeld())
	end)

	it("takes a release for a reason not holding as nothing (ANN-R38)", function()
		local world = newWorld()
		world.lanes:Push(announcement("toast", "New Species"))
		world.lanes:Hold("combat")

		world.lanes:Release("guide")
		world.advance(60)

		assert.are.same({ {}, true, 0 }, { column(world), world.lanes:IsHeld(), world.emptied })
	end)

	it("holds for combat when no reason is given (ANN-R35, ANN-R38)", function()
		local world = newWorld()
		world.lanes:Hold()

		assert.is_true(world.lanes:IsHeld("combat"))
		world.lanes:Release()
		world.advance(2)
		assert.is_false(world.lanes:IsHeld())
	end)
end)

describe("Cozy mode in the lanes", function()
	it("shows no toast, banner or Nod and plays nothing (ANN-R40)", function()
		local world = newWorld()
		world.cozy = true

		world.lanes:Push(announcement("toast", "New Species"))
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("nod", "New here"))
		world.advance(60)

		assert.are.same({}, world.shown)
		assert.are.same({}, world.played)
		assert.are.equal(0, world.emptied)
	end)

	it("still shows a splash, silently (ANN-R41)", function()
		local world = newWorld()
		world.cozy = true

		world.lanes:Push(announcement("splash", "Legend"))

		assert.are.equal("Legend", centre(world))
		assert.is_nil((centreOf(world) --[[@as table]]).sound)
		assert.are.same({}, world.played)
	end)

	it("drops what waits once turned on, and replays nothing once turned off (ANN-R40, ANN-R42)", function()
		local world = newWorld()
		for i = 1, 4 do
			world.lanes:Push(announcement("toast", "Toast " .. i))
		end
		world.cozy = true
		world.lanes:Push(announcement("toast", "Toast 5"))
		world.advance(TOAST)
		world.cozy = false
		world.advance(60)

		assert.are.same({ "Toast 1", "Toast 2", "Toast 3" }, titles(world.shown))
		world.lanes:Push(announcement("toast", "Toast 6"))
		assert.are.same({ "toast Toast 6" }, column(world))
	end)
end)

describe("expiry in the lanes", function()
	-- A Cast's Announcement: `headline` with `stamps` riding on it, as logic/Moments.lua makes one.
	local function cast(moments)
		for i, moment in ipairs(moments) do
			moment.kind, moment.module, moment.moduleOrder, moment.raised = "spec", "Hunts", 20, i
		end
		return ns.MakeAnnouncement(moments)
	end

	-- Fills the column with three toasts, so what comes next waits.
	local function fill(world)
		for i = 1, 3 do
			world.lanes:Push(announcement("toast", "Toast " .. i))
		end
	end

	it("drops an expired headline as it is about to show, and the next-ranked moment headlines (ANN-R45)", function()
		local world = newWorld()
		fill(world)
		world.lanes:Push(cast({
			{ rung = "toast.high", title = "Window open", expiresAt = SERVER_TIME + 10 },
			{ rung = "toast", title = "New Species", stamp = "New!" },
			{ rung = "nod", title = "Uncharted" },
		}))
		world.serverTime = SERVER_TIME + 10

		world.advance(TOAST)

		assert.are.same({ "toast New Species" }, column(world))
		assert.are.same({ "Uncharted" }, displayOf(world, "New Species").announcement.stamps)
	end)

	it("drops an expired stamp, and shows nothing when every moment expired (ANN-R45)", function()
		local world = newWorld()
		fill(world)
		world.lanes:Push(announcement("banner", "Banner"))
		world.lanes:Push(cast({
			{ rung = "toast", title = "New Species" },
			{ rung = "nod", title = "Window open", expiresAt = SERVER_TIME + 10 },
		}))
		world.lanes:Push(cast({ { rung = "banner", title = "Window open", expiresAt = SERVER_TIME + 10 } }))
		world.serverTime = SERVER_TIME + 10

		world.advance(60)

		assert.are.same({ "Toast 1", "Toast 2", "Toast 3", "Banner", "New Species" }, titles(world.shown))
		assert.are.same({}, world.shown[5].announcement.stamps)
	end)

	it("never shows a moment already expired when raised (ANN-R45)", function()
		local world = newWorld()

		world.lanes:Push(cast({ { rung = "nod", title = "Window open", expiresAt = SERVER_TIME } }))
		world.lanes:Push(cast({ { rung = "toast", title = "Window open", expiresAt = SERVER_TIME - 60 } }))

		assert.are.same({}, world.shown)
	end)

	it("drops held moments that expired during combat (ANN-R36, ANN-R45)", function()
		local world = newWorld()
		world.lanes:Hold()
		world.lanes:Push(cast({ { rung = "toast", title = "Window open", expiresAt = SERVER_TIME + 10 } }))
		world.lanes:Push(announcement("toast", "New Species"))
		world.lanes:Push(cast({ { rung = "banner", title = "Hunt window", expiresAt = SERVER_TIME + 10 } }))
		world.serverTime = SERVER_TIME + 10

		world.lanes:Release()
		world.advance(2)

		assert.are.same({ "New Species" }, titles(world.shown))
	end)
end)

describe("Announcement sounds", function()
	local DRIFTWOOD = SOUNDS .. "driftwood\\"

	it(
		"are a set for each of Core's sound set goods and the three the Ledger and Hunts earn in Core's slot, each"
			.. " three toast variants and a banner in its folder, Gilded's one (ANN-R72, ANN-R74, SHOP-R25, Tunables)",
		function()
			local sets = {}
			for id, set in pairs(ns.SOUND_SETS) do
				local folder = SOUNDS .. id:match("[^.]+$") .. "\\"
				local expected = { toast = {}, banner = folder .. "banner.ogg" }
				for i = 1, #set.toast do
					expected.toast[i] = ("%stoast_%d.ogg"):format(folder, i)
				end
				assert.are.same(expected, set, id)
				sets[#sets + 1] = id .. " " .. #set.toast
			end
			table.sort(sets)

			assert.are.same({
				"core.soundset.driftwood 3",
				"core.soundset.dulcimer 3",
				"core.soundset.frost 3",
				"core.soundset.gilded 1",
				"core.soundset.gizmo 3",
				"core.soundset.glass 3",
				"core.soundset.harp 3",
				"core.soundset.kalimba 3",
				"core.soundset.marimba 3",
				"core.soundset.musicbox 3",
				"core.soundset.rain 3",
				"core.soundset.shipbell 3",
				"core.soundset.steelpan 3",
				"core.soundset.wardrums 3",
				"hunts.soundset.nightwatch 3",
				"ledger.soundset.choir 3",
				"ledger.soundset.concertina 3",
			}, sets)
		end
	)

	it(
		"come from the sound set keyed by the equipped good's ID, Driftwood for any other ID or none (ANN-R72)",
		function()
			assert.are.same({
				SOUNDS .. "gilded\\banner.ogg",
				DRIFTWOOD .. "banner.ogg",
				DRIFTWOOD .. "banner.ogg",
				DRIFTWOOD .. "banner.ogg",
			}, {
				ns.SoundSetOf("core.soundset.gilded").banner,
				ns.SoundSetOf("core.soundset.driftwood").banner,
				ns.SoundSetOf("core.toaststyle.ripple").banner,
				ns.SoundSetOf(nil).banner,
			})
			assert.are.equal(ns.SOUND_SETS[ns.SOUND_SET_DEFAULT], ns.SoundSetOf("hunts.soundset.unknown"))
		end
	)

	it(
		"cycles the toast sound through toast_1, toast_2 and toast_3, playing a waiting toast's only when it shows"
			.. " (ANN-R24, ANN-R71, ANN-R72)",
		function()
			local world = newWorld()
			for i = 1, 4 do
				world.lanes:Push(announcement("toast", "Toast " .. i))
			end
			assert.are.same(
				{ DRIFTWOOD .. "toast_1.ogg", DRIFTWOOD .. "toast_2.ogg", DRIFTWOOD .. "toast_3.ogg" },
				world.played
			)

			world.advance(TOAST)

			assert.are.equal(DRIFTWOOD .. "toast_1.ogg", world.played[4])
			assert.are.equal(DRIFTWOOD .. "toast_1.ogg", displayOf(world, "Toast 4").sound)
		end
	)

	it("plays the banner sound for a banner and the Legend sting for a splash (ANN-R70, ANN-R72)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("splash", "Legend"))
		assert.are.same({ DRIFTWOOD .. "banner.ogg" }, world.played)

		world.advance(BANNER + LEAVE)

		assert.are.same({ DRIFTWOOD .. "banner.ogg", SOUNDS .. "legend\\19803.ogg" }, world.played)
	end)

	it(
		"plays each Legend's own sting, picked by the splash's icon, the Legend's item ID, and 19803's for any other"
			.. " (ANN-R70, ANN-R72)",
		function()
			local world = newWorld()
			for _, icon in ipairs({ 19806, 19805, 19803, 6292, "Interface\\Icons\\INV_Misc_Fish_02" }) do
				world.lanes:Push(announcement("splash", "Legend", { icon = icon }))
			end
			for _ = 1, 5 do
				world.advance(ns.SPLASH_SECONDS + LEAVE)
			end

			assert.are.same({
				SOUNDS .. "legend\\19806.ogg",
				SOUNDS .. "legend\\19805.ogg",
				SOUNDS .. "legend\\19803.ogg",
				SOUNDS .. "legend\\19803.ogg",
				SOUNDS .. "legend\\19803.ogg",
			}, world.played)
			assert.are.same(
				{ SOUNDS .. "legend\\19803.ogg", SOUNDS .. "legend\\19803.ogg" },
				{ ns.LegendSting(), ns.LegendSting(19804) }
			)
		end
	)

	it(
		"plays only the banner's sound when toasts appear in the same frame, and the next toast plays the variant"
			.. " the first would have (ANN-R24, ANN-R71)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("toast", "Hunt completed"))

			assert.are.same({ "toast Hunt completed", "toast New Species" }, column(world))
			assert.are.same({ DRIFTWOOD .. "banner.ogg" }, world.played)
			world.advance(1)
			world.lanes:Push(announcement("toast", "Size record"))

			assert.are.same({ DRIFTWOOD .. "banner.ogg", DRIFTWOOD .. "toast_1.ogg" }, world.played)
		end
	)

	it(
		"plays a toast's sound when it appears in a later frame than the banner, or with a silent banner"
			.. " (ANN-R24, ANN-R71)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.advance(1)
			world.lanes:Push(announcement("toast", "New Species"))
			world.advance(TOAST)
			world.lanes:Push(announcement("banner", "Quiet", { sound = false }))
			world.lanes:Push(announcement("toast", "Hunt completed"))

			assert.are.same(
				{ DRIFTWOOD .. "banner.ogg", DRIFTWOOD .. "toast_1.ogg", DRIFTWOOD .. "toast_2.ogg" },
				world.played
			)
		end
	)

	it(
		"plays nothing for a Nod, a stepped-down toast.low or a headline with sound = false (ANN-R70, ANN-R71)",
		function()
			local world = newWorld()
			world.budget.count = 1
			world.lanes:Push(announcement("nod", "New here"))
			world.lanes:Push(announcement("toast", "Quiet", { sound = false }))
			world.advance(TOAST)
			world.lanes:Push(announcement("toast.low", "Size record"))
			world.advance(NOD)
			world.lanes:Push(announcement("toast", "Loud"))

			assert.are.same({ "New here", "Quiet", "Size record", "Loud" }, titles(world.shown))
			assert.are.same({ DRIFTWOOD .. "toast_1.ogg" }, world.played)
			assert.is_nil(world.shown[2].sound)
		end
	)

	it("plays only files Pagle ships under addons/Pagle/media/sounds/ (ANN-R72, ANN-R74)", function()
		local paths = {}
		for _, sting in pairs(ns.LEGEND_STINGS) do
			paths[#paths + 1] = sting
		end
		assert.are.equal(3, #paths)
		for _, set in pairs(ns.SOUND_SETS) do
			paths[#paths + 1] = set.banner
			for _, path in ipairs(set.toast) do
				paths[#paths + 1] = path
			end
		end
		assert.are.equal(3, #ns.SOUND_SETS["core.soundset.driftwood"].toast)

		for _, path in ipairs(paths) do
			local file = path:match("^Interface\\AddOns\\Pagle\\(media\\sounds\\.+%.ogg)$")
			assert.is_string(file)
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
			local handle = io.open("addons/Pagle/" .. file:gsub("\\", "/"), "rb")
			assert.is_truthy(handle)
			handle:close()
		end
	end)
end)

describe("the record ruler", function()
	local RULER = { old = 10, new = 12, unit = "lb", label = "weight" }

	it("fills past the old mark while the number counts up over 1.5 s, then lands the margin (ANN-R22)", function()
		local start = ns.RulerAt(RULER, 0)
		assert.are.same(
			{ 0, "0.0 lb", false, false, false },
			{ start.fill, start.value, start.passed, start.done, start.stamped }
		)
		assert.is_near(10 / 13.2, start.mark, 1e-9)
		assert.are.same({ "+2.0 lb", "weight" }, { start.margin, start.label })

		local late = ns.RulerAt(RULER, 1.4)
		assert.is_true(late.passed)
		assert.is_false(late.done)

		local landed = ns.RulerAt(RULER, 1.5)
		assert.is_near(12 / 13.2, landed.fill, 1e-9)
		assert.are.same({ "12.0 lb", true, true }, { landed.value, landed.passed, landed.done })
	end)

	it("lands the New record stamp a beat after the margin, not with it (ANN-R22)", function()
		assert.is_false(ns.RulerAt(RULER, 1.5).stamped)
		assert.is_false(ns.RulerAt(RULER, 1.5 + ns.RULER_STAMP_DELAY / 2).stamped)

		local stamped = ns.RulerAt(RULER, 1.5 + ns.RULER_STAMP_DELAY)

		assert.are.same({ true, true }, { stamped.done, stamped.stamped })
		assert.is_true(ns.RULER_STAMP_DELAY > 0)
	end)

	it("shows a unit other than length as given (ANN-R22)", function()
		assert.are.equal("+0.3 kg", ns.RulerAt({ old = 1.2, new = 1.5, unit = "kg", label = "weight" }, 2).margin)
	end)

	it("shows the old record's number by its mark, in the ruler's unit (ANN-R22)", function()
		assert.are.equal("10.0 lb", ns.RulerAt(RULER, 0).old)
	end)

	it("shows a Simulated Size's millimetres and margin in the Angler's length unit (ANN-R22, LOG-R69)", function()
		local size = { old = 300, new = 342, unit = "length", label = "length" }

		local cm, inches = ns.RulerAt(size, 2, "cm"), ns.RulerAt(size, 2, "in")

		assert.are.same({ "30.0 cm", "34.2 cm", "+4.2 cm", "length" }, { cm.old, cm.value, cm.margin, cm.label })
		assert.are.same({ "11.8 in", "13.5 in", "+1.7 in" }, { inches.old, inches.value, inches.margin })
		assert.are.equal("0.0 cm", ns.RulerAt(size, 0, "cm").value)
	end)

	it("shows a size margin that rounds to zero in the unit as +<0.1 (ANN-R22)", function()
		local size = { old = 300, new = 300.2, unit = "length", label = "length" }

		assert.are.same(
			{ "+<0.1 in", "+<0.1 cm" },
			{ ns.RulerAt(size, 2, "in").margin, ns.RulerAt(size, 2, "cm").margin }
		)
	end)
end)
