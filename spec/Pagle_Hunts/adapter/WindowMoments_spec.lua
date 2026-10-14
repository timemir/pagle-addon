-- Window moments at runtime (HNT-R88, HNT-R190, SET-R32, ANN-R12): Hunts on FakePagle over a Hunt list of its own
-- (hunts.md › Data), with the live conditions (its calendar's events), the restriction state and a server time that
-- runs on the client's clock (fake.globals.GetServerTime), so the grouping's timers and "now" move together, as in
-- spec/Pagle_Hunts/adapter/Groups_spec.lua. The pure comparison is in spec/Pagle_Hunts/logic/WindowMoments_spec.lua.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local JAN_1 = 1767225600 -- 2026-01-01
local OCT_12 = 1791763200 -- 2026-10-12 00:00 UTC: realm 17:00 on Sunday 11 October
local AURA = 1280341 -- on the catalogue's aura list
local EXTRAVAGANZA = 301 -- the catalogue's event: Sundays 14:00 for 2h
local REALM_START = 8 * 60 + 15 -- FakePagle's realm clock at SERVER_TIME: 08:15 on Sunday 11 October 2026

--- The server time at realm `hour`:`minute`, counted from Sunday (hour 29 is Monday 05:00).
local function realm(hour, minute)
	return SERVER_TIME + (hour * 60 + (minute or 0) - REALM_START) * 60
end

-- The spec's Hunts, by ID: imposed Hunts on the catalogue's Blackmouth (DATA-R86), each with its own conditions.
local HUNTS = {
	dawn_trout = { conditions = { time = { { 300, 480 } } } }, -- 05:00–08:00
	morning = { conditions = { time = { { 480, 600 } } } }, -- 08:00–10:00: open at login
	fair = { conditions = { events = { EXTRAVAGANZA } } },
	rack = { conditions = { auras = { AURA } } },
	deep = { conditions = { time = { { 300, 480 } }, skill = { min = 400 } } }, -- short of skill at 300
	newcomer = { since = OCT_12, conditions = { time = { { 1000, 1200 } } } }, -- 16:40–20:00, current from 17:00
}
local ORDER = { "dawn_trout", "morning", "fair", "rack", "deep", "newcomer" }
local NAMES = { dawn_trout = "Dawn Trout", morning = "Morning Rise", fair = "Fair Trade" }

-- The Hunt list: every Hunt above in set spec_set.
local function huntList()
	local list = { fingerprint = "w", sets = { { id = "spec_set" } }, hunts = {}, classes = {} }
	for i, id in ipairs(ORDER) do
		local hunt = { id = id, set = "spec_set", kind = "imposed", since = JAN_1, species = 6358, tiers = { 1 } }
		for key, value in pairs(HUNTS[id]) do
			hunt[key] = value
		end
		list.hunts[i] = hunt
	end
	for _, class in ipairs({ "quality.uncommon", "quality.rare", "species.any" }) do
		list.classes[class] = {}
	end
	return list
end

---@class WindowRun
---@field loaded LoadedAddon
---@field fake table
---@field ns table

--- Hunts on a FakePagle with the spec's Hunt list, `options.pins` pinned and the setting `options.on` saved, logged
--- in with Fishing at 300, through its first PLAYER_ENTERING_WORLD at realm 08:15.
---@param options { pins: string[]?, on: boolean? }?
---@return WindowRun
local function start(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue.base())
	local clock
	fake.globals.GetServerTime = function()
		return SERVER_TIME + math.floor(clock and clock() or 0)
	end
	local pins = {}
	for _, id in ipairs(options.pins or {}) do
		pins[id] = true
	end
	fake.globals.PagleHuntsDB = {
		profileKeys = { ["Angler - Testrealm"] = "Default" },
		profiles = { Default = { pins = pins, windowMoments = options.on } },
	}
	local loaded = hunts.load(fake, {
		prepare = function(l)
			l.ns.huntList = huntList()
			for id, name in pairs(NAMES) do
				l.ns.L["hunt." .. id .. ".name"] = name
			end
		end,
	})
	clock = loaded.client.time
	fake.login()
	fake.readSkill(300, 300, 0)
	fake.enterWorld()
	fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
	return { loaded = loaded, fake = fake, ns = loaded.ns }
end

--- Moves the clock on to server time `t`, running each regroup timer that comes due.
local function waitUntil(run, t)
	run.loaded.client.advance(t - run.fake.globals.GetServerTime())
end

--- A regroup now, as a SkillChanged makes one (HNT-R42).
local function regroup(run)
	run.fake.fire("SkillChanged")
end

--- The live conditions with `changes` made, as the next snapshot: setConditions fires ConditionsChanged.
local function setConditions(run, changes)
	local conditions = {}
	for key, value in pairs(run.fake.conditions) do
		conditions[key] = value
	end
	for key, value in pairs(changes) do
		conditions[key] = value
	end
	run.fake.setConditions(conditions)
end

--- The window moments Core kept (fake.summarized: every moment kept, shown or not, ANN-R25).
local function windowMoments(run)
	local out = {}
	for _, moment in ipairs(run.fake.summarized) do
		if moment.kind == "huntWindow" then
			out[#out + 1] = moment
		end
	end
	return out
end

describe("A pinned Hunt's window opening (HNT-R88)", function()
	it("raises one Nod at 05:00 after a regroup at 04:59: name, tracker label, icon, expiresAt and pastText", function()
		local run = start({ pins = { "dawn_trout" }, on = true })
		waitUntil(run, realm(28, 59)) -- Monday 04:59
		regroup(run)
		assert.are.same({}, windowMoments(run))

		waitUntil(run, realm(29)) -- 05:00: the window's edge timer regroups (HNT-R42)

		local moments = windowMoments(run)
		assert.are.equal(1, #moments)
		local moment = moments[1]
		assert.are.equal("nod", moment.rung)
		assert.are.equal("Dawn Trout is open", moment.title)
		assert.are.equal("ends in 3h", moment.text) -- its tracker label (HNT-R51)
		assert.are.equal(6358, moment.icon) -- its Species item (HNT-R55)
		assert.are.equal(realm(32), moment.expiresAt) -- Monday 08:00
		assert.are.equal("Dawn Trout window opened 05:00–08:00", moment.pastText)
		assert.is_nil(moment.cast)
		assert.is_nil(moment.coins)

		-- No cast: its own Announcement, on the next frame (ANN-R12).
		run.fake.nextFrame()
		local shown = run.fake.announcements[#run.fake.announcements]
		assert.are.equal("Dawn Trout is open", shown.headline.title)
		assert.are.equal(1, #shown.moments)
	end)

	it("raises one for an event starting on the live calendar, with no '–{to}' while closesAt is unknown", function()
		local run = start({ pins = { "fair" }, on = true })
		waitUntil(run, realm(8, 20))
		-- The calendar shows the Extravaganza on before its weekly 14:00: open, with no end in sight (LOG-R50).
		setConditions(run, { events = { EXTRAVAGANZA } })

		local moments = windowMoments(run)
		assert.are.equal(1, #moments)
		assert.are.equal("Fair Trade is open", moments[1].title)
		assert.are.equal("now", moments[1].text) -- the tracker label with no closesAt (HNT-R51)
		assert.is_nil(moments[1].expiresAt)
		assert.are.equal("Fair Trade window opened 08:20", moments[1].pastText)
	end)

	it("compares the first regroup after a restriction against the last regroup before it (HNT-R43)", function()
		local run = start({ pins = { "dawn_trout" }, on = true })
		waitUntil(run, realm(28, 30))
		run.fake.setRestricted(true)
		waitUntil(run, realm(29, 30)) -- the 05:00 edge passes in combat: no regroup
		assert.are.same({}, windowMoments(run))

		run.fake.setRestricted(false)

		local moments = windowMoments(run)
		assert.are.equal(1, #moments)
		assert.are.equal("Dawn Trout window opened 05:30–08:00", moments[1].pastText)
	end)
end)

describe("No window moment (HNT-R88)", function()
	it("at the first grouping, though a pinned Hunt is open: it only sets the baseline (HNT-R190)", function()
		-- Morning Rise is open at 08:15; a Module just enabled loads like this, raising nothing for windows that
		-- opened while it was off.
		local run = start({ pins = { "morning" }, on = true })
		regroup(run)
		assert.are.same({}, windowMoments(run))
		assert.are.same({}, run.fake.announcements)
	end)

	it("for an unpinned Hunt", function()
		local run = start({ on = true })
		waitUntil(run, realm(29, 30))
		assert.are.same({}, windowMoments(run))
	end)

	it("for a Hunt short of skill (HNT-R33)", function()
		local run = start({ pins = { "deep" }, on = true })
		waitUntil(run, realm(29, 30))
		assert.is_true(run.ns.groups:Row("deep").short)
		assert.are.same({}, windowMoments(run))
	end)

	it("for an aura starting (HNT-R40)", function()
		local run = start({ pins = { "rack" }, on = true })
		setConditions(run, { auras = { AURA } })
		assert.are.equal("now", run.ns.groups:Row("rack").group)
		assert.are.same({}, windowMoments(run))
	end)

	it("for a Hunt that just became current, with no record at the previous regroup", function()
		local run = start({ on = true })
		waitUntil(run, realm(16, 59))
		-- Written straight to the profile: SetPinned refuses a Hunt not yet out (HNT-R81).
		run.ns.db.profile.pins.newcomer = true
		waitUntil(run, realm(17)) -- its since: the list timer regroups (HNT-R42)
		assert.is_not_nil(run.ns.groups:Row("newcomer"))
		assert.is_true(run.ns.groups:Row("newcomer").window.openNow)
		assert.are.same({}, windowMoments(run))
	end)

	it("when pinning a Hunt that is already open", function()
		local run = start({ on = true })
		waitUntil(run, realm(29, 30))
		assert.is_true(run.ns.SetPinned("dawn_trout", true))
		regroup(run)
		assert.are.same({}, windowMoments(run))
	end)

	it("with the setting off, and turning it on later raises nothing for a window already open (SET-R32)", function()
		local run = start({ pins = { "dawn_trout" } })
		waitUntil(run, realm(29, 30))
		assert.are.same({}, windowMoments(run))

		run.ns.db.profile.windowMoments = true
		regroup(run) -- the baseline was kept while off: Dawn Trout was open already
		assert.are.same({}, windowMoments(run))
	end)
end)

describe("The setting (SET-R32, CORE-R42)", function()
	-- The Announcements page's rows from Hunts.
	local function huntsRows(run)
		local rows = {}
		for _, entry in ipairs(run.fake.settingsPage("announcements") or {}) do
			if entry.module == "Hunts" then
				rows[#rows + 1] = entry
			end
		end
		return rows
	end

	it("is a checkbox under a Hunts header on the Announcements page, off by default, with its tooltip", function()
		local run = start()
		local rows = huntsRows(run)
		assert.are.same({ "header", "checkbox" }, { rows[1].kind, rows[2].kind })
		assert.are.equal("Hunts", rows[1].label)
		local setting = rows[2].setting
		assert.are.equal("Tell me when a pinned Hunt's window opens", setting.label)
		assert.are.equal(
			"A quiet Nod when a pinned Hunt's window opens. It fades when the window closes.",
			setting.tooltip
		)
		assert.is_false(setting.default)
		assert.is_false(setting.get())
		assert.is_false(rows[2].indented)
	end)

	it("stores PagleHuntsDB.profile.windowMoments, and turned on, a Nod follows", function()
		local run = start({ pins = { "dawn_trout" } })
		local setting = huntsRows(run)[2].setting
		setting.set(true)
		assert.is_true(run.ns.db.profile.windowMoments)
		assert.is_true(setting.get())

		waitUntil(run, realm(29))
		assert.are.equal(1, #windowMoments(run))

		setting.set(false)
		assert.is_false(run.ns.db.profile.windowMoments)
	end)

	it("isn't greyed out in Cozy mode, where the Nod goes to the Session summary (ANN-R40)", function()
		local run = start({ pins = { "dawn_trout" }, on = true })
		run.fake.profile.announcements.cozy = true
		local setting = huntsRows(run)[2].setting
		assert.is_true(setting.isEnabled == nil or setting.isEnabled())

		waitUntil(run, realm(29))
		assert.are.equal(1, #windowMoments(run)) -- kept for the summary (ANN-R25)
	end)
end)
