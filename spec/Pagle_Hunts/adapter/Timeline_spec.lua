-- The board's left page, "What's biting, and when" (HNT-R61–R63, HNT-R66, HNT-R67, HNT-R69): the timeline as data
-- (ns.BoardTimeline, logic/Timeline.lua) and as drawn on the board, on FakePagle over the fixture Hunt list and
-- catalogue, with a server time on the client's clock (as adapter/Groups_spec.lua runs it) and live conditions.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local catalogue = hunts.catalogue
local C = catalogue
local JAN_1, RACK_AURA, HOUR = hunts.JAN_1, C.RACK_AURA, hunts.HOUR
local untilRealm, realm, wait, has = hunts.untilRealm, hunts.realm, hunts.wait, hunts.has
local useState, setConditions = hunts.useState, hunts.setConditions
local RULER = 24 * HOUR -- 2 h before now to 22 h after (Tunables)

-- Hunts the fixture list lacks, over imposed Hunts of set fixture_extra (DATA-R93), with the fixture's oddity class.
local function extraList(huntFields)
	return hunts.extraList(huntFields, { ["fixed.oddity"] = { [6522] = true, [251524] = true } })
end

--- Hunts on a FakePagle after the first PLAYER_ENTERING_WORLD, its server time on the client's clock: loaded with
--- `options.list` (if given) as the Hunt list, `options.catalogue` (the fixture's by default), Fishing at
--- `options.skill` (150; false for none).
---@param options { list: HuntListData?, catalogue: table?, skill: integer|false|nil, saved: table? }?
---@return HuntsRun
local function start(options)
	options = options or {}
	return hunts.start({
		list = options.list,
		catalogue = options.catalogue,
		skill = options.skill,
		saved = options.saved,
	})
end

--- A Hunt's progress with its first `tiers` tiers reached (hunts.md › Projection state), by Deviate Fish in Elwynn.
local function reached(tiers)
	return hunts.progress({ tiers = tiers, itemID = C.DEVIATE, zone = C.ELWYNN })
end

--- Server time `t` on a ruler whose now is `now`: 0 at its start, 1 at its end (HNT-R62).
local function at(t, now)
	return (t - (now - 2 * HOUR)) / RULER
end

--- The timeline's row for a Hunt, or nil when no group shows it.
local function rowIn(timeline, huntID)
	for _, group in ipairs(timeline.groups) do
		for _, row in ipairs(group.rows) do
			if row.id == huntID then
				return row
			end
		end
	end
end

--- A row's bars as { from, to, style }, positions rounded to 4 places.
local function bars(row)
	local out = {}
	for i, bar in ipairs(row.bars) do
		out[i] = { math.floor(bar.from * 1e4 + 0.5) / 1e4, math.floor(bar.to * 1e4 + 0.5) / 1e4, bar.style }
	end
	return out
end

--- `{ from, to, style }` for times on the ruler of `now`, rounded as bars() rounds.
local function bar(from, to, style)
	return { math.floor(from * 1e4 + 0.5) / 1e4, math.floor(to * 1e4 + 0.5) / 1e4, style }
end

describe("the timeline's bars (HNT-R63)", function()
	it("draws a night Hunt at realm 23:00 hatched from the ruler's start to 06:00 and from 20:00 to the end", function()
		-- The fixture's night is 20:00–06:00: open at the ruler's start (21:00), it draws from there; the next opening,
		-- 20:00 tomorrow, runs past the ruler's end (21:00 tomorrow).
		local run = start()
		wait(run, untilRealm(23))
		local now = realm(23)

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "fixture_snapper")

		assert.are.same({ bar(0, at(realm(30), now), "hatched"), bar(at(realm(44), now), 1, "hatched") }, bars(row))
	end)
end)

local ALWAYS = { class = "fixed.oddity", conditions = { areas = { C.ELWYNN } } }

describe("the timeline's rows (HNT-R63)", function()
	it("puts a night Hunt under Later at 14:00 with its margin label", function()
		local run = start()
		wait(run, untilRealm(14))

		local timeline = run.ns.BoardTimeline({ mode = "board" })
		local row = rowIn(timeline, "fixture_snapper")

		assert.are.equal("20:00", row.margin) -- HNT-R51: Later, opening on the same realm day
		assert.are.equal("later", row.tone)
		local later
		for _, group in ipairs(timeline.groups) do
			if group.group == "later" then
				later = group
			end
		end
		assert.is_true(has(hunts.ids(later.rows), "fixture_snapper"))
	end)

	it("dashes an unconfirmed Hunt's bars (HNT-R34)", function()
		-- fixture_eel bites in the day window, whose spec is unconfirmed: 06:00–20:00, open at the ruler's start.
		local run = start()
		local now = SERVER_TIME

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "fixture_eel")

		assert.are.same({ bar(0, at(realm(20), now), "dashed"), bar(at(realm(30), now), 1, "dashed") }, bars(row))
	end)

	it("draws a short-of-skill Hunt in pencil, which wins over dashed (HNT-R33, HNT-R34)", function()
		-- Sunscale in the unconfirmed day window, in Elwynn (skill 25), with no Fishing known.
		local list = extraList({ { kind = "natural", species = C.SUNSCALE, window = "day" } })
		local run = start({ list = list, skill = false })
		local now = SERVER_TIME

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1")

		assert.are.same({ bar(0, at(realm(20), now), "pencil"), bar(at(realm(30), now), 1, "pencil") }, bars(row))
		assert.are.same({ "need 25", "short" }, { row.margin, row.tone })
	end)

	it("fills the ruler for an always-open Hunt", function()
		local run = start({ list = extraList({ ALWAYS }) })

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1")

		assert.are.same({ bar(0, 1, "hatched") }, bars(row))
		assert.are.equal("any time", row.margin)
	end)

	it("gives an On demand Hunt no bar, and while its aura is up a blue bar to the aura's expiry", function()
		local run = start()
		local now = SERVER_TIME
		local expires
		run.loaded.env.C_UnitAuras = {
			GetPlayerAuraBySpellID = function(spellID)
				if spellID == RACK_AURA and expires then
					return { spellId = spellID, expirationTime = expires }
				end
			end,
		}
		assert.are.same({}, bars(rowIn(run.ns.BoardTimeline({ mode = "board" }), "fixture_rack")))

		setConditions(run.fake, { auras = { RACK_AURA } }) -- the camp is up
		expires = run.loaded.env.GetTime() + 1800 -- for half an hour more

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "fixture_rack")
		assert.are.same({ bar(at(now, now), at(now + 1800, now), "camp") }, bars(row))
		assert.are.equal("up now", row.margin)
	end)

	it("runs the blue bar to the ruler's end when the aura's expiry is unknown", function()
		local run = start()
		local now = SERVER_TIME
		run.loaded.env.C_UnitAuras = {
			GetPlayerAuraBySpellID = function(spellID)
				return { spellId = spellID, expirationTime = 0 } -- an aura without a duration
			end,
		}
		setConditions(run.fake, { auras = { RACK_AURA } })

		assert.are.same(
			{ bar(at(now, now), 1, "camp") },
			bars(rowIn(run.ns.BoardTimeline({ mode = "board" }), "fixture_rack"))
		)
	end)

	it('reads "out of season" for a season Hunt with no span on the ruler', function()
		-- 20 March to 19 September, in October.
		local spring = { season = { { from = { 3, 20 }, to = { 9, 19 } } } }
		local run = start({ list = extraList({ { class = "fixed.oddity", conditions = spring } }) })

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1")

		assert.are.same({}, bars(row))
		assert.are.equal("out of season", row.note)
		assert.are.equal("back in March", row.margin)
	end)

	it("draws no bars for a Hunt without a board spec (HNT-R7)", function()
		local run = start({ list = extraList({ { kind = "natural", species = C.NIGHTFIN, window = "nowhere" } }) })

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1")

		assert.are.same({}, bars(row))
		assert.is_nil(row.note)
		assert.are.equal("no date known", row.margin)
	end)

	it("draws an event the live calendar shows open across the now line to the ruler's end (HNT-R41)", function()
		local run = start({ list = extraList({ { class = "fixed.oddity", conditions = { events = { 301 } } } }) })
		local now = SERVER_TIME
		setConditions(run.fake, { events = { 301 } }) -- on now, says the calendar

		local drawn = bars(rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1"))

		local last = drawn[#drawn]
		assert.is_true(last[1] <= bar(at(now, now), 1)[1])
		assert.are.equal(1, last[2])
	end)

	it("draws it from the now line when the weekly forecast gives no span at now", function()
		-- Event 302 has no weekly rule: forecast from the ruler's start, the calendar opens it at now and never
		-- before (LOG-R46, LOG-R50).
		local run = start({ list = extraList({ { class = "fixed.oddity", conditions = { events = { 302 } } } }) })
		local now = SERVER_TIME
		setConditions(run.fake, { events = { 302 } })

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1")

		assert.are.same({ bar(at(now, now), 1, "hatched") }, bars(row))
		assert.are.equal("while the event runs", row.margin)
	end)

	it("draws a live occurrence from its weekly opening to its end (HNT-R63, LOG-R50)", function()
		-- Sunday 15:00, the Extravaganza live in its 14:00–16:00 occurrence: the ruler starts at 13:00, before it.
		local run = start({ list = extraList({ { class = "fixed.oddity", conditions = { events = { 301 } } } }) })
		run.loaded.client.advance(untilRealm(15))
		setConditions(run.fake, { events = { 301 } })
		local now = realm(15)

		local row = rowIn(run.ns.BoardTimeline({ mode = "board" }), "extra_1")

		-- The fixture's weekly rule is unconfirmed (HNT-R34).
		assert.are.same({ bar(at(realm(14), now), at(realm(16), now), "dashed") }, bars(row))
		assert.are.equal("until 16:00", row.margin)
	end)
end)

describe("an event's conditions line while it runs (HNT-R53)", function()
	it("keeps its weekly wording, from its next forecast opening after closesAt", function()
		local spec = { events = { 301 } }
		local run = start({ list = extraList({ { class = "fixed.oddity", conditions = spec } }) })
		run.loaded.client.advance(untilRealm(15))
		setConditions(run.fake, { events = { 301 } })

		local line = run.ns.HuntConditionsLine(spec, nil, realm(15), run.fake.conditions, run.ns.names)

		assert.are.equal("Sundays 14:00 for 2h", line:match("Sundays .*$"))
	end)
end)

describe("the timeline's ruler and washes (HNT-R62)", function()
	it("runs from 2 h before now to 22 h after, a tick each realm hour, every 6 hours labelled", function()
		local run = start()
		local ruler = run.ns.BoardTimeline({ mode = "board" }).ruler

		assert.are.same({ SERVER_TIME - 2 * HOUR, SERVER_TIME + 22 * HOUR }, { ruler.from, ruler.to })
		assert.are.equal(bar(at(SERVER_TIME, SERVER_TIME), 1)[1], bar(ruler.now, 1)[1])
		-- 06:15 to 06:15 tomorrow: whole hours 07:00 … 06:00, 24 of them; 12:00, 18:00, 00:00 and 06:00 labelled.
		assert.are.equal(24, #ruler.ticks)
		local labels = {}
		for _, tick in ipairs(ruler.ticks) do
			labels[#labels + 1] = tick.label
		end
		assert.are.same({ "12:00", "18:00", "00:00", "06:00" }, labels)
		assert.are.equal(bar(at(realm(7), SERVER_TIME), 1)[1], bar(ruler.ticks[1].x, 1)[1])
	end)

	it("leaves a tick within the hour of now unlabelled, where the now line says now", function()
		local run = start()
		wait(run, untilRealm(11, 30))

		local labels = {}
		for _, tick in ipairs(run.ns.BoardTimeline({ mode = "board" }).ruler.ticks) do
			labels[#labels + 1] = tick.label
		end

		assert.are.same({ "18:00", "00:00", "06:00" }, labels) -- 12:00 is half an hour off
	end)

	it("washes the next 3 hours (Soon) and the spans the night window holds", function()
		local run = start()
		local now = SERVER_TIME

		local washes = run.ns.BoardTimeline({ mode = "board" }).washes

		local drawn = {}
		for i, wash in ipairs(washes) do
			drawn[i] = { wash.kind, bar(wash.from, wash.to)[1], bar(wash.from, wash.to)[2] }
		end
		assert.are.same({
			{ "soon", bar(at(now, now), 1)[1], bar(0, at(now + 3 * HOUR, now))[2] },
			{ "night", bar(at(realm(20), now), 1)[1], bar(0, at(realm(30), now))[2] },
		}, drawn)
	end)
end)

describe("the timeline's groups (HNT-R62, HNT-R44, HNT-R82)", function()
	-- extra_1 and extra_4 are always open (Now), extra_2 opens at 10:00 (Soon), extra_3 waits for its aura.
	local LIST = {
		ALWAYS,
		{ class = "fixed.oddity", conditions = { time = { { 600, 660 } } } },
		{ class = "fixed.oddity", conditions = { auras = { RACK_AURA } } },
		ALWAYS,
	}

	it("come in board order under their headings with their counts, an empty group left out", function()
		local run = start({ list = extraList(LIST) })

		local timeline = run.ns.BoardTimeline({ mode = "board" })

		local headings = {}
		for i, group in ipairs(timeline.groups) do
			headings[i] = { group.heading, group.count, #group.rows }
		end
		assert.are.same({
			{ "Now: open right now", 2, 2 },
			{ "Soon: opens within 3 hours", 1, 1 },
			{ "On demand: starts when you do", 1, 1 },
		}, headings)
		assert.are.equal("What's biting, and when", timeline.title)
		assert.are.equal(
			"Hatched: open · Dashed: window unconfirmed · Pencil: needs more skill · Blue: your camp is up",
			timeline.legend
		)
	end)

	it("put a pinned row first in its group, with its pin mark (HNT-R80)", function()
		local run = start({ list = extraList(LIST) })
		run.ns.SetPinned("extra_4", true)

		local now = run.ns.BoardTimeline({ mode = "board" }).groups[1]

		assert.are.same({ "extra_4", "extra_1" }, hunts.ids(now.rows))
		assert.are.same({ true, false }, { now.rows[1].pinned, now.rows[2].pinned })
	end)

	it("leave out a finished Hunt with show completed off, and show it again with it on", function()
		local run = start({ list = extraList({ ALWAYS, ALWAYS }) })
		useState(run, { extra_1 = reached(1) })

		assert.are.same({ "extra_2" }, hunts.ids(run.ns.BoardTimeline({ mode = "board" }).groups[1].rows))

		run.ns.SetShowCompleted(true)
		local now = run.ns.BoardTimeline({ mode = "board" }).groups[1]
		assert.are.same({ "extra_1", "extra_2" }, hunts.ids(now.rows))
		assert.are.same({ "bronze" }, { now.rows[1].trim, now.rows[2].trim }) -- HNT-R18's trim, none for extra_2
	end)

	it("hide nothing and show no trim while the projection is updating (HNT-R69)", function()
		local run = start({ list = extraList({ ALWAYS, ALWAYS }) })
		useState(run, { extra_1 = reached(1) }, {}, true)

		local now = run.ns.BoardTimeline({ mode = "board" }).groups[1]

		assert.are.same({ "extra_1", "extra_2" }, hunts.ids(now.rows))
		assert.is_nil(now.rows[1].trim)
	end)
end)

describe("a set's page, its left side (HNT-R66)", function()
	it("shows only the set's current Hunts, headed with the title it earns", function()
		local run = start()

		local timeline = run.ns.BoardTimeline({ mode = "set", set = "fixture_dusk" })

		local shown = {}
		for _, group in ipairs(timeline.groups) do
			for _, id in ipairs(hunts.ids(group.rows)) do
				shown[#shown + 1] = id
			end
		end
		table.sort(shown)
		assert.are.same({ "fixture_hefty_blackmouth", "fixture_snapper" }, shown) -- not the Retired Sunscale
		assert.are.equal("Dusk: earns the Duskwatcher", timeline.title)
		assert.is_nil(timeline.selected) -- only the Board picks a Hunt (HNT-R67)
	end)

	it("heads it with the title alone once earned, and so does an entry opened from it", function()
		local run = start()
		useState(run, {}, { fixture_dusk = { earnedAt = JAN_1, date = { year = 2026, month = 1, day = 1 } } })

		assert.are.equal("Dusk: the Duskwatcher", run.ns.BoardTimeline({ mode = "set", set = "fixture_dusk" }).title)
		local entry = run.ns.BoardTimeline({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" })
		assert.are.equal("Dusk: the Duskwatcher", entry.title)
		assert.are.equal("fixture_snapper", entry.selected)
	end)

	it("keeps the filter: a finished Hunt of the set is left out", function()
		local run = start()
		useState(run, { fixture_hefty_blackmouth = reached(2) })

		local timeline = run.ns.BoardTimeline({ mode = "set", set = "fixture_dusk" })

		assert.is_nil(rowIn(timeline, "fixture_hefty_blackmouth"))
		assert.is_not_nil(rowIn(timeline, "fixture_snapper"))
	end)
end)

--- The board's place now.
local function place(run)
	return run.ns.board.router:Place()
end

--- The texts shown on a page of the board: "left" or "right", as the mode shown draws them.
local function pageTexts(run, side)
	return shownTexts(run.ns.board.frame.bodies[side])
end

--- The drawn rows of the Board's left page that show, top to bottom, as { huntID, name, margin }.
local function drawnRows(run)
	local rows = {}
	local function walk(widget)
		for _, child in ipairs(widget.children) do
			if child.shown then
				if child.huntID then
					rows[#rows + 1] = child
				end
				walk(child)
			end
		end
	end
	walk(run.ns.board.pages["board:left"])
	return rows
end

local ALL_DONE = 'Every Hunt here is done. Tick "show completed" to see them again.'

describe("opening the board (HNT-R67)", function()
	it("selects the first Hunt under Now", function()
		-- At 08:15 the day window is open: fixture_eel is the only Hunt under Now.
		local run = start()

		run.ns.ToggleBoard()

		assert.are.same({ mode = "board", hunt = "fixture_eel" }, place(run))
	end)

	it("selects the first row when Now is empty", function()
		local run = start({
			list = extraList({
				{ class = "fixed.oddity", conditions = { time = { { 1200, 1260 } } } }, -- 20:00, Later
				{ class = "fixed.oddity", conditions = { time = { { 600, 660 } } } }, -- 10:00, Soon
			}),
		})

		run.ns.ToggleBoard()

		assert.are.equal("extra_2", place(run).hunt)
	end)

	it("selects the Hunt OpenBoard asks for, and a clicked row's Hunt (HNT-R77)", function()
		local run = start()
		run.ns.SetPinned("fixture_snapper", true)

		run.ns.OpenBoard("fixture_snapper")
		assert.are.same({ mode = "board", hunt = "fixture_snapper" }, place(run))

		for _, row in ipairs(drawnRows(run)) do
			if row.huntID == "fixture_oddity" then
				row:Click()
			end
		end
		assert.are.same({ mode = "board", hunt = "fixture_oddity" }, place(run))
	end)

	it("keeps a current Hunt asked for though the filter hides its row, and picks for a Hunt not current", function()
		local run = start()
		useState(run, { fixture_hefty_blackmouth = reached(2) }) -- finished: show completed off hides its row

		run.ns.OpenBoard("fixture_hefty_blackmouth")
		assert.are.equal("fixture_hefty_blackmouth", place(run).hunt)

		run.ns.OpenBoard("fixture_sunscale") -- Retired: the first Hunt under Now instead
		assert.are.equal("fixture_eel", place(run).hunt)
	end)

	it("draws each shown row with its name and margin label", function()
		local run = start()
		wait(run, untilRealm(14))
		run.ns.ToggleBoard()

		local snapper
		for _, row in ipairs(drawnRows(run)) do
			if row.huntID == "fixture_snapper" then
				snapper = row
			end
		end
		assert.are.same({ "Snapper Run", "20:00" }, { snapper.name.text, snapper.margin.text })
		local texts = pageTexts(run, "left")
		assert.is_true(has(texts, "What's biting, and when"))
		assert.is_true(has(texts, "Later: opens after that, or needs more skill"))
	end)

	it("reads HNT-R67's line on the right page when every Hunt is hidden, and selects none", function()
		local run = start({ list = extraList({ ALWAYS }) })
		useState(run, { extra_1 = reached(1) })

		run.ns.ToggleBoard()

		assert.is_nil(place(run).hunt)
		assert.is_true(has(pageTexts(run, "right"), ALL_DONE))

		run.ns.SetShowCompleted(true) -- the redraw shows it again, selected
		assert.are.equal("extra_1", place(run).hunt)
		assert.is_false(has(pageTexts(run, "right"), ALL_DONE))
	end)

	it('reads "No Hunts yet." on the left page before any since, and leaves the right page empty', function()
		local later = { class = "fixed.oddity", conditions = { areas = { C.ELWYNN } }, since = 1793750400 }
		local run = start({ list = extraList({ later }) })

		run.ns.ToggleBoard()

		-- Under the page's title, and nothing else: no ruler, groups or legend.
		assert.are.same({ "What's biting, and when", "No Hunts yet." }, pageTexts(run, "left"))
		assert.are.same({}, pageTexts(run, "right"))
		assert.is_nil(place(run).hunt)
	end)
end)

describe("countdowns on the right page, an hour after the last regroup (HNT-R42, HNT-R43, HNT-R52)", function()
	-- At 08:15 the day window (06:00–20:00) is open: fixture_eel closes at 20:00. The tracker is collapsed and the
	-- board shut, so nothing refreshes the grouping for an hour; the countdowns still count from now.
	local function anHourLater()
		local run = start()
		run.ns.tracker.header:Click() -- collapsed: no 60 s refresh (HNT-R42)
		local grouped = run.ns.groups:Time()
		wait(run, HOUR)
		assert.are.equal(grouped, run.ns.groups:Time())
		return run
	end

	it("counts the entry's window line down from now (HNT-R52)", function()
		local run = anHourLater()

		run.ns.OpenBoard("fixture_eel")

		assert.is_true(has(pageTexts(run, "right"), "Open now. Closes in 10h 45m, at 20:00."))
	end)

	it("counts a set page's tracker labels down from now (HNT-R51, HNT-R66)", function()
		local run = anHourLater()

		local eel = run.ns.BoardSetPage("fixture_pair").hunts[1] -- fixture_eel, first in Hunt list order

		assert.are.equal("ends in 10h 45m", eel.when)
	end)
end)

describe("the leather's clock and checkbox (HNT-R61)", function()
	-- The fixture catalogue with season windows: autumn from 22 September to 20 December (LOG-R55).
	local function withSeasons()
		local data = catalogue.base()
		data.windows.summer = { spec = { season = { { from = { 6, 21 }, to = { 9, 21 } } } }, confirmed = true }
		data.windows.autumn = { spec = { season = { { from = { 9, 22 }, to = { 12, 20 } } } }, confirmed = true }
		return data
	end

	it("shows the realm time, the short date with its weekday and the season", function()
		local run = start({ catalogue = withSeasons() })

		run.ns.ToggleBoard()

		assert.are.same({ "08:15 · Sun 11 Oct · Autumn" }, shownTexts(run.ns.board.frame.anchors.clock))
	end)

	it("shows no season when no season window matches", function()
		local run = start()
		wait(run, untilRealm(14, 5))

		run.ns.ToggleBoard()

		assert.are.same({ "14:05 · Sun 11 Oct" }, shownTexts(run.ns.board.frame.anchors.clock))
	end)

	it('adds "(paused in combat)" while restricted, and freezes with the grouping (HNT-R43)', function()
		local run = start({ catalogue = withSeasons() })
		run.ns.ToggleBoard()

		run.fake.setRestricted(true)
		wait(run, 600)
		run.ns.board:Draw()

		assert.are.same(
			{ "08:15 · Sun 11 Oct · Autumn (paused in combat)" },
			shownTexts(run.ns.board.frame.anchors.clock)
		)

		run.fake.setRestricted(false)
		assert.are.same({ "08:25 · Sun 11 Oct · Autumn" }, shownTexts(run.ns.board.frame.anchors.clock))
	end)

	it('saves "show completed" from its checkbox and redraws (HNT-R82)', function()
		local run = start({ list = extraList({ ALWAYS, ALWAYS }) })
		useState(run, { extra_1 = reached(1) })
		run.ns.ToggleBoard()
		local box = run.ns.board.frame.anchors.completed.children[1]
		assert.are.same({ "show completed" }, shownTexts(run.ns.board.frame.anchors.completed))
		assert.is_false(box:GetChecked())

		box:Click()

		assert.is_true(run.ns.db.profile.showCompleted)
		local shown = {}
		for _, row in ipairs(drawnRows(run)) do
			shown[#shown + 1] = row.huntID
		end
		assert.are.same({ "extra_1", "extra_2" }, shown)
	end)
end)

describe("a set's page, drawn (HNT-R66)", function()
	it("draws the set's timeline on the left and opens an entry from a clicked row", function()
		local run = start()
		run.ns.board:Open({ mode = "set", set = "fixture_dusk" })

		local texts = pageTexts(run, "left")
		assert.is_true(has(texts, "Dusk: earns the Duskwatcher"))
		assert.is_false(has(texts, "Oddity Hour"))

		local function walk(widget)
			for _, child in ipairs(widget.children) do
				if child.shown and child.huntID == "fixture_snapper" then
					child:Click()
					return
				end
				walk(child)
			end
		end
		walk(run.ns.board.pages["set:left"])

		assert.are.same({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }, place(run))
	end)
end)
