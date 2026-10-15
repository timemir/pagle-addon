-- The display queue, the Interruption budget and Announcement sounds (announcements.md › The display queue,
-- › Interruption budget, › Sounds): logic/Announcements.lua fed Announcements and a clock.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newClock = dofile("spec/support/timers.lua").newClock

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"

-- Lanes over a fake clock. `world.on` is what is on screen now, by form ("toast", "nod", "banner", "splash");
-- `world.log` every show and hide as "show <form> <title>" / "hide <form> <title>"; `world.played` each sound path.
-- `world.budget` is the player's Interruption budget setting, `world.cozy` Cozy mode and `world.serverTime` the
-- server time expiry reads.
local function newWorld()
	local clock = newClock()
	local world = {
		on = {},
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
			return ns.SOUND_SETS.driftwood
		end,
		show = function(display)
			world.on[display.form] = display
			world.shown[#world.shown + 1] = display
			world.log[#world.log + 1] = "show " .. display.form .. " " .. display.announcement.headline.title
		end,
		hide = function(display)
			if world.on[display.form] == display then
				world.on[display.form] = nil
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

-- The title of the toast, banner or splash on screen, or nil, where at most one of them is.
local function slot(world)
	local display = world.on.toast or world.on.banner or world.on.splash
	return display and display.announcement.headline.title
end

-- The titles on screen in the centre (a banner or splash) and as a toast, either nil when there is none.
local function places(world)
	local centre = world.on.banner or world.on.splash
	return {
		centre = centre and centre.announcement.headline.title,
		toast = world.on.toast and world.on.toast.announcement.headline.title,
	}
end

describe("the display queue", function()
	it("shows a toast at once when the slot is free, for 6 s (ANN-R20)", function()
		local world = newWorld()

		world.lanes:Push(announcement("toast", "New Species"))

		assert.are.equal("New Species", slot(world))
		world.advance(5.9)
		assert.are.equal("New Species", slot(world))
		world.advance(0.1)
		assert.is_nil(slot(world))
		assert.are.same({ "show toast New Species", "hide toast New Species" }, world.log)
	end)

	it(
		"shows a banner and a toast on screen together, each lane waiting only for its own; a third waiting toast"
			.. " isn't shown, and the next toast to show reads +1 more (ANN-R20)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "Toast 1"))
			world.lanes:Push(announcement("toast", "Toast 2"))
			world.lanes:Push(announcement("toast", "Toast 3"))

			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("banner", "Zone Master"))
			world.lanes:Push(announcement("toast", "Toast 4"))
			assert.are.same({ centre = "Level 12", toast = "Toast 1" }, places(world))
			assert.are.equal("banner", world.on.banner.form)

			world.advance(4)
			assert.are.same({ centre = "Zone Master", toast = "Toast 1" }, places(world))
			world.advance(2)
			assert.are.same({ centre = "Zone Master", toast = "Toast 2" }, places(world))
			assert.are.equal(1, world.on.toast.overflow)
			world.advance(6)
			assert.are.same({ "Toast 3", 0 }, { slot(world), world.on.toast.overflow })
			world.advance(6)

			assert.is_nil(slot(world))
			assert.are.same({ "Toast 1", "Level 12", "Zone Master", "Toast 2", "Toast 3" }, titles(world.shown))
		end
	)

	it("shows waiting splashes before waiting banners, and banners in the order raised (ANN-R20)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Banner 1"))
		world.lanes:Push(announcement("banner", "Banner 2"))
		world.lanes:Push(announcement("splash", "Splash 1"))
		world.lanes:Push(announcement("banner", "Banner 3"))
		world.lanes:Push(announcement("splash", "Splash 2"))

		world.advance(60)

		assert.are.same({ "Banner 1", "Splash 1", "Splash 2", "Banner 2", "Banner 3" }, titles(world.shown))
	end)

	it(
		"lets a splash wait for the toast on screen to end, and starts no toast while a splash waits or shows"
			.. " (ANN-R20)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("splash", "Legend"))
			world.lanes:Push(announcement("toast", "Hunt completed"))
			assert.are.same({ toast = "New Species" }, places(world))

			world.advance(6)
			assert.are.same({ centre = "Legend" }, places(world))
			world.lanes:Push(announcement("toast", "Size record"))
			world.advance(7.9)
			assert.are.same({ centre = "Legend" }, places(world))
			world.advance(0.1)

			assert.are.same({ toast = "Hunt completed" }, places(world))
			assert.are.same({ "New Species", "Legend", "Hunt completed" }, titles(world.shown))
		end
	)

	it("keeps a splash up until clicked or 8 s, and a banner 4 s (ANN-R20)", function()
		local world = newWorld()
		world.lanes:Push(announcement("splash", "Legend"))
		world.lanes:Push(announcement("splash", "Another Legend"))
		world.lanes:Push(announcement("banner", "Level 12"))

		world.advance(2)
		world.lanes:Dismiss(world.on.splash)
		assert.are.equal("Another Legend", slot(world))
		world.advance(7.9)
		assert.are.equal("Another Legend", slot(world))
		world.advance(0.1)
		assert.are.equal("Level 12", slot(world))
		world.advance(3.9)
		assert.are.equal("Level 12", slot(world))
		world.advance(0.1)
		assert.is_nil(slot(world))
	end)

	it(
		"shows a Nod for 3 s under the toast, but never while a toast, a splash or another Nod is showing (ANN-R20)",
		function()
			local world = newWorld()

			world.lanes:Push(announcement("nod", "New here"))
			world.lanes:Push(announcement("nod", "Uncharted"))
			world.lanes:Push(announcement("toast", "New Species"))
			assert.are.same({ "New here", "New Species" }, { world.on.nod.announcement.headline.title, slot(world) })
			world.advance(3)
			assert.is_nil(world.on.nod)
			world.lanes:Push(announcement("nod", "★★"))
			world.advance(3)
			world.lanes:Push(announcement("splash", "Legend"))
			world.lanes:Push(announcement("nod", "★★★"))
			world.lanes:Dismiss(world.on.splash)
			world.lanes:Push(announcement("nod", "Trophy ★★"))

			assert.are.same({ "New here", "New Species", "Legend", "Trophy ★★" }, titles(world.shown))
		end
	)

	it("shows a Nod while a banner is on screen (ANN-R20)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Level 12"))

		world.lanes:Push(announcement("nod", "New here"))

		assert.are.same({ "Level 12", "New here" }, titles(world.shown))
		assert.are.equal("New here", world.on.nod.announcement.headline.title)
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
		world.advance(6)
		assert.is_false(world.lanes:IsEmpty())
		world.advance(2)
		assert.is_true(world.lanes:IsEmpty())
	end)

	it(
		"tells the cards each time both lanes free with nothing waiting, never while the other shows, never for a Nod"
			.. " (ANN-R21)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("toast", "Toast 1"))
			world.lanes:Push(announcement("toast", "Toast 2"))
			world.lanes:Push(announcement("banner", "Level 12"))

			world.advance(6)
			assert.are.equal(0, world.emptied)
			world.advance(6)
			assert.are.equal(1, world.emptied)

			world.lanes:Push(announcement("splash", "Legend"))
			world.lanes:Dismiss(world.on.splash)
			assert.are.equal(2, world.emptied)
			world.lanes:Push(announcement("nod", "Uncharted"))
			world.advance(3)
			assert.are.equal(2, world.emptied)
		end
	)
end)

describe("the Interruption budget", function()
	-- Pushes `n` toasts at `rung`, each shown in full before the next.
	local function interrupt(world, n, rung)
		for i = 1, n do
			world.lanes:Push(announcement(rung or "toast", "Interruption " .. i))
			world.advance(6)
		end
	end

	it("steps the 5th toast.low in 5 minutes down to a Nod, while a toast gets through (ANN-R30, ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 2, "toast")
		interrupt(world, 1, "banner")
		interrupt(world, 1, "toast.low")

		world.lanes:Push(announcement("toast.low", "Size record"))
		assert.is_nil(slot(world))
		assert.are.same({ "nod", "Size record" }, { world.on.nod.form, world.on.nod.announcement.headline.title })
		world.advance(3)
		world.lanes:Push(announcement("toast", "New Species"))

		assert.are.equal("New Species", slot(world))
	end)

	it("counts a Cast's banner and its toast, shown together, as 2 interruptions (ANN-R30, ANN-R31)", function()
		local world = newWorld()
		world.budget = { on = true, count = 2, window = 300 }
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("toast", "New Species"))
		world.advance(6)

		world.lanes:Push(announcement("toast.low", "Size record"))

		assert.are.same({ "nod", "Size record" }, { world.on.nod.form, world.on.nod.announcement.headline.title })
	end)

	it("counts only the interruptions of the last window (ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 4)
		world.advance(300 - 24)

		world.lanes:Push(announcement("toast.low", "Size record"))

		assert.are.same({ "Size record", "toast" }, { slot(world), world.on.toast.form })
	end)

	it("steps a waiting toast.low down when it reaches the front, then shows the next (ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 3)
		world.lanes:Push(announcement("toast", "Toast"))
		world.lanes:Push(announcement("toast.low", "Size record"))
		world.lanes:Push(announcement("toast.high", "Hunt completed"))

		world.advance(6)

		assert.are.same({ "Hunt completed", "Size record" }, { slot(world), world.on.nod.announcement.headline.title })
	end)

	it("follows the Nod lane's rules once stepped down: not shown while a Nod shows (ANN-R31)", function()
		local world = newWorld()
		interrupt(world, 4)
		world.lanes:Push(announcement("nod", "New here"))

		world.lanes:Push(announcement("toast.low", "Size record"))

		assert.are.same({ "New here" }, { world.on.nod.announcement.headline.title })
		assert.is_nil(slot(world))
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

		assert.are.same({ "Size record", "toast" }, { slot(world), world.on.toast.form })
	end)
end)

describe("the combat hold", function()
	-- The text of the "While you were fighting" toast on screen: its held headlines, in order.
	local function fighting(world)
		local held = {}
		for i, headline in ipairs(world.on.toast.announcement.fighting) do
			held[i] = headline.title
		end
		return held
	end

	it("hides the banner and the toast on screen and holds them, with the Nod showing too (ANN-R35)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("nod", "New here"))
		world.lanes:Push(announcement("toast", "New Species"))

		world.lanes:Hold()

		assert.are.same({}, places(world))
		assert.is_nil(world.on.nod)
		assert.is_true(world.lanes:IsHeld())
		world.lanes:Release()
		world.advance(2)
		assert.are.same({ centre = "Level 12", toast = "While you were fighting" }, places(world))
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
		"2 s after combat shows held splashes then banners as themselves, and with the first banner one While you"
			.. " were fighting toast with every held toast headline (ANN-R36)",
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
			assert.are.same({ "New Species" }, titles(world.shown))
			world.advance(0.1)
			assert.are.same({ centre = "Legend" }, places(world))
			world.lanes:Dismiss(world.on.splash)

			assert.are.same({ centre = "Level 12", toast = "While you were fighting" }, places(world))
			assert.are.same({ "New Species", "Size record", "Hunt completed" }, fighting(world))
			world.advance(6)
			assert.are.same({}, places(world))
		end
	)

	it(
		"shows a held Cast's banner and its toast together after combat, playing only the banner's sound"
			.. " (ANN-R24, ANN-R36)",
		function()
			local world = newWorld()
			world.lanes:Hold()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("toast", "New Species"))

			world.lanes:Release()
			world.advance(2)

			assert.are.same({ centre = "Level 12", toast = "While you were fighting" }, places(world))
			assert.are.same({ SOUNDS .. "driftwood\\banner.ogg" }, world.played)
			assert.is_nil(world.on.toast.sound)
		end
	)

	it("plays the toast sound once for the While you were fighting toast, which never steps down (ANN-R36)", function()
		local world = newWorld()
		world.budget = { on = true, count = 1, window = 300 }
		world.lanes:Push(announcement("toast.low", "Size record"))
		world.lanes:Hold()
		world.lanes:Push(announcement("toast.low", "New junk"))
		world.played = {}

		world.lanes:Release()
		world.advance(2)

		assert.are.same({ "toast", "While you were fighting" }, { world.on.toast.form, slot(world) })
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

			assert.are.same({ centre = "Level 12", toast = "While you were fighting" }, places(world))
			assert.is_false(world.lanes:IsHeld())
			assert.are.same({ "New Species" }, fighting(world))
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
			world.advance(6)
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
		world.advance(8)

		world.lanes:Push(announcement("toast.low", "Size record"))
		assert.are.same({ "Size record", "toast" }, { slot(world), world.on.toast.form })
		world.advance(6)
		world.lanes:Push(announcement("toast.low", "New junk"))

		assert.are.equal("nod", world.on.nod.form)
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

		assert.are.equal("Legend", slot(world))
		assert.is_nil(world.on.splash.sound)
		assert.are.same({}, world.played)
	end)

	it("drops what waits once turned on, and replays nothing once turned off (ANN-R40, ANN-R42)", function()
		local world = newWorld()
		world.lanes:Push(announcement("toast", "Toast 1"))
		world.lanes:Push(announcement("toast", "Toast 2"))
		world.cozy = true
		world.lanes:Push(announcement("toast", "Toast 3"))
		world.advance(6)
		world.cozy = false
		world.advance(60)

		assert.are.same({ "Toast 1" }, titles(world.shown))
		world.lanes:Push(announcement("toast", "Toast 4"))
		assert.are.same({ "Toast 4", 0 }, { slot(world), world.on.toast.overflow })
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

	it("drops an expired headline as it is about to show, and the next-ranked moment headlines (ANN-R45)", function()
		local world = newWorld()
		world.lanes:Push(announcement("toast", "Toast"))
		world.lanes:Push(cast({
			{ rung = "toast.high", title = "Window open", expiresAt = SERVER_TIME + 10 },
			{ rung = "toast", title = "New Species", stamp = "New!" },
			{ rung = "nod", title = "Uncharted" },
		}))
		world.serverTime = SERVER_TIME + 10

		world.advance(6)

		assert.are.equal("New Species", slot(world))
		assert.are.same({ "Uncharted" }, world.on.toast.announcement.stamps)
	end)

	it("drops an expired stamp, and shows nothing when every moment expired (ANN-R45)", function()
		local world = newWorld()
		world.lanes:Push(announcement("toast", "Toast"))
		world.lanes:Push(announcement("banner", "Banner"))
		world.lanes:Push(cast({
			{ rung = "toast", title = "New Species" },
			{ rung = "nod", title = "Window open", expiresAt = SERVER_TIME + 10 },
		}))
		world.lanes:Push(cast({ { rung = "banner", title = "Window open", expiresAt = SERVER_TIME + 10 } }))
		world.serverTime = SERVER_TIME + 10

		world.advance(60)

		assert.are.same({ "Toast", "Banner", "New Species" }, titles(world.shown))
		assert.are.same({}, world.shown[3].announcement.stamps)
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

		assert.are.same({ "While you were fighting" }, titles(world.shown))
		assert.are.same({ "New Species" }, { world.on.toast.announcement.fighting[1].title })
	end)
end)

describe("Announcement sounds", function()
	local DRIFTWOOD = SOUNDS .. "driftwood\\"

	it(
		"cycles the toast sound through toast_1, toast_2 and toast_3, playing a waiting toast's only when it shows"
			.. " (ANN-R24, ANN-R71, ANN-R72)",
		function()
			local world = newWorld()
			for i = 1, 4 do
				world.lanes:Push(announcement("toast", "Toast " .. i))
			end
			assert.are.same({ DRIFTWOOD .. "toast_1.ogg" }, world.played)

			world.advance(6 * 4)

			assert.are.same({
				DRIFTWOOD .. "toast_1.ogg",
				DRIFTWOOD .. "toast_2.ogg",
				DRIFTWOOD .. "toast_3.ogg",
			}, world.played)
			world.lanes:Push(announcement("toast.high", "Toast 5"))
			assert.are.equal(DRIFTWOOD .. "toast_1.ogg", world.played[4])
			assert.are.equal(DRIFTWOOD .. "toast_1.ogg", world.on.toast.sound)
		end
	)

	it("plays the banner sound for a banner and the Legend sting for a splash (ANN-R70, ANN-R72)", function()
		local world = newWorld()
		world.lanes:Push(announcement("banner", "Level 12"))
		world.lanes:Push(announcement("splash", "Legend"))
		assert.are.same({ DRIFTWOOD .. "banner.ogg" }, world.played)

		world.advance(4)

		assert.are.same({ DRIFTWOOD .. "banner.ogg", SOUNDS .. "legend.ogg" }, world.played)
	end)

	it(
		"plays only the banner's sound when a toast appears in the same frame, and the next toast plays the variant"
			.. " that one would have (ANN-R24, ANN-R71)",
		function()
			local world = newWorld()
			world.lanes:Push(announcement("banner", "Level 12"))
			world.lanes:Push(announcement("toast", "New Species"))
			world.lanes:Push(announcement("toast", "Hunt completed"))

			assert.are.same({ centre = "Level 12", toast = "New Species" }, places(world))
			assert.are.same({ DRIFTWOOD .. "banner.ogg" }, world.played)
			world.advance(6)

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
			world.advance(6)
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
			world.advance(6)
			world.lanes:Push(announcement("toast.low", "Size record"))
			world.advance(6)
			world.lanes:Push(announcement("toast", "Loud"))

			assert.are.same({ "New here", "Quiet", "Size record", "Loud" }, titles(world.shown))
			assert.are.same({ DRIFTWOOD .. "toast_1.ogg" }, world.played)
			assert.is_nil(world.shown[2].sound)
		end
	)

	it("plays only files Pagle ships under addons/Pagle/media/sounds/ (ANN-R72, ANN-R74)", function()
		local paths = { ns.LEGEND_STING }
		for _, set in pairs(ns.SOUND_SETS) do
			paths[#paths + 1] = set.banner
			for _, path in ipairs(set.toast) do
				paths[#paths + 1] = path
			end
		end
		assert.are.equal(3, #ns.SOUND_SETS.driftwood.toast)

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
