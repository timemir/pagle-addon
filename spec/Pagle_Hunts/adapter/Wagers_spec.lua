-- Pagle Wagers on the Board spread (HNT-R50, HNT-R51, HNT-R53–R55, HNT-R60–R64, HNT-R67, HNT-R69, HNT-R160,
-- HNT-R161, HNT-R163–R165, HNT-R203, HNT-R204): the wager strip above the timeline's ruler, the WAGERS group at the top
-- of the timeline, and a run's entry on the right page, as data (ns.BoardTimeline, ns.BoardRunEntry) and as drawn, on
-- FakePagle over the fixture Hunt list and catalogue, a fixed clock and live conditions.
--
-- The event pool is the fixture's (spec/Pagle_Hunts/fixtures/EventList.lua) with fixture_vale moved to the mid band,
-- so the fallback rotation (HNT-R152) runs slot 0 fixture_shore (low), slot 1 fixture_vale (mid), slot 2 nothing (no
-- high event), slot 3 fixture_shore again. fixture_shore ("Shore Wager", Darkshore) has a Haul of any fish (2 / 4), a
-- Named fish (Raw Nightfin Snapper, 1) and a Timed oddity at 18:00–21:00 realm time (1).
--
-- The clock: Thursday 15 October 2026 11:00 UTC, so a slot ending Saturday 17 October 15:00 UTC closes in 2d 4h, and
-- reads "Sat 17:00" on a realm two hours ahead of UTC (HNT-R203).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

local C = hunts.catalogue
local HOUR, DAY = hunts.HOUR, 86400
local SLOT = 3 * DAY
local has = hunts.has

--- Thursday 15 October 2026 11:00 UTC, and Saturday 17 October 15:00 UTC, 2d 4h later.
local THU_11 = SERVER_TIME + 3 * DAY + 19 * HOUR + 45 * 60
local SAT_15 = THU_11 + 2 * DAY + 4 * HOUR
--- The realm clock at THU_11 on a realm two hours ahead of UTC (13:00), and on one at UTC (11:00).
local AHEAD = { time = THU_11, minute = 13 * 60, date = { year = 2026, month = 10, day = 15, weekday = 5 } }
local UTC = { time = THU_11, minute = 11 * 60, date = { year = 2026, month = 10, day = 15, weekday = 5 } }

local RULE = "Each Hunt's first mark pays +150 XP and 8 Coins, each tier after it +100 XP and 5 Coins, and settling "
	.. "the wager +250 XP and 25 Coins more. A Hunt's third mark also pays 1 Refresh, and settling the wager 1 more."

-- The fixture pool with fixture_vale in the mid band (the header).
local function pool(fixture)
	local copy = hunts.deepCopy(fixture)
	for _, event in ipairs(copy.events) do
		if event.id == "fixture_vale" then
			event.band, event.skill = "mid", { 175, 275 }
		end
	end
	return copy
end

-- A Cast at exactly server time `time` in `zone`, catching `itemIDs`.
local function castAt(time, zone, itemIDs)
	local entry = hunts.cast(0, hunts.NIGHT, { zone = zone }, itemIDs)
	entry.time = time
	return entry
end

--- Hunts logged in at `now` with the rotation's origin at `origin`, the live conditions at `clock` (a realm snapshot
--- at `now`), names loaded, and `history` (records) in the Catch log before login; then the frames where the
--- pushed-content check ends and the run log's step runs (HNT-R151). `pushed` goes to fake.setPushedContent. The
--- companion hint's switch is off unless `options.hint`, so the strip is the runs' alone (HNT-R172, HNT-R176).
---@return HuntsRun
local function start(options)
	local now, origin = options.now or THU_11, options.origin
	local r = hunts.start({
		from = now - SERVER_TIME,
		names = true,
		events = pool,
		caughtUp = options.caughtUp,
		prepare = function(loaded)
			loaded.ns.COMPANION_HINT_ON = options.hint == true
			if origin then
				loaded.ns.ROTATION_ORIGIN = origin
			end
			if options.prepare then
				options.prepare(loaded)
			end
		end,
		history = options.history and function(fake)
			hunts.append(fake, options.history)
		end,
		beforeLogin = function(r)
			if options.pushed then
				r.fake.setPushedContent(options.pushed)
			end
		end,
		-- the realm's clock before the first grouping, so the groups are the realm's (HNT-R40)
		beforeGrouping = function(r)
			hunts.setConditions(r.fake, options.clock or AHEAD)
		end,
	})
	r.fake.nextFrame()
	r.loaded.client.runTimers()
	return r
end

-- Slot 0 is the run on: fixture_shore from Wednesday 15:00 UTC to SAT_15, logged at its start, with one Cast in
-- Darkshore catching a Raw Nightfin Snapper an hour in: the Named fish's first mark, the Haul at 1 of 2.
local O = SAT_15 - SLOT
local SHORE = "fixture_shore@" .. O
local VALE = "fixture_vale@" .. SAT_15
local function onHistory()
	return {
		hunts.record("run", hunts.runPayload("fixture_shore", O, SAT_15), O),
		castAt(O + HOUR, C.DARKSHORE, { C.NIGHTFIN }),
	}
end

local function oneOn(options)
	options = options or {}
	options.origin, options.history = O, onHistory()
	return start(options)
end

--- The board's place now.
local function place(r)
	return r.ns.board.router:Place()
end

--- The texts shown on a page of the board, "left" or "right", in the mode shown.
local function pageTexts(r, side)
	return shownTexts(r.ns.board:Page(place(r), side))
end

--- A group of a timeline by its HuntGroup, or nil.
local function groupIn(timeline, name)
	for _, group in ipairs(timeline.groups) do
		if group.group == name then
			return group
		end
	end
end

--- The drawn widgets under `widget` that show and carry `field`.
local function shownWith(widget, field, out)
	out = out or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child[field] ~= nil then
				out[#out + 1] = child
			end
			shownWith(child, field, out)
		end
	end
	return out
end

--- The shown font string under `widget` reading `words`, or nil.
local function textOf(widget, words)
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text == words then
				return child
			end
			local found = textOf(child, words)
			if found then
				return found
			end
		end
	end
end

--- A bar as { from, to, style }, positions rounded to 4 places.
local function rounded(bar)
	return { math.floor(bar.from * 1e4 + 0.5) / 1e4, math.floor(bar.to * 1e4 + 0.5) / 1e4, bar.style }
end

describe("the wager strip (HNT-R161)", function()
	it(
		"names the first run on: its mark, dial, zones, closes in 2d 4h, and a pip per Hunt inked at its first mark",
		function()
			local r = oneOn()

			local strip = r.ns.BoardTimeline({ mode = "board" }).strip

			assert.are.same({
				run = SHORE,
				on = true,
				mark = { "mark-shadow", "mark-sky-plain", "mark-water-coast", "mark-ring" },
				dial = { kind = "on", step = 26, urgent = false }, -- 2d 4h of 3d to go, without words (HNT-R167)
				name = "Shore Wager",
				zones = "Darkshore",
				settled = false,
				closes = "closes in 2d 4h", -- HNT-R50, HNT-R203: a server-time duration
				urgent = false,
				pips = { false, true, false }, -- the Haul at 1 of 2, the Snapper at its first mark, the oddity none
			}, strip)
		end
	)

	it(
		"draws the one-line ticket above the ruler: no kicker, its dial and mark, its pips inked at a first mark",
		function()
			local r = oneOn()
			r.ns.ToggleBoard()

			local texts = pageTexts(r, "left")
			assert.is_false(has(texts, "PAGLE WAGERS"))
			assert.is_true(has(texts, "Shore Wager"))
			assert.is_true(has(texts, "Darkshore"))
			assert.is_true(has(texts, "closes in 2d 4h"))
			assert.is_false(has(texts, "2d 4h")) -- the dial has no words
			local page = r.ns.board:Page(place(r), "left")
			local pips = shownWith(page, "pip")
			assert.are.equal(3, #pips)
			assert.are.same({ false, true, false }, { pips[1].inked, pips[2].inked, pips[3].inked })
			local strip = shownWith(page, "stripRun")[1]
			assert.are.same({ 26, false, false }, { shownWith(strip, "step")[1].step, strip.settled, strip.urgent })
			assert.are.same(
				{ "mark-shadow", "mark-sky-plain", "mark-water-coast", "mark-ring" },
				shownWith(strip, "names")[1].names
			)
		end
	)

	it('reddens "closes in …" within the closing-note time, and stamps SETTLED in place of the pips', function()
		local r = oneOn({
			now = SAT_15 - 42 * 60,
			clock = {
				time = SAT_15 - 42 * 60,
				minute = 16 * 60 + 18,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})
		r.ns.ToggleBoard()

		local strip = shownWith(r.ns.board:Page(place(r), "left"), "stripRun")[1]
		local closes = textOf(strip, "closes in 42m")
		local red, now = r.ns.BOARD_LOOK.nowLine, shownWith(strip, "step")[1]
		assert.is_true(strip.urgent)
		assert.are.same({ red[1], red[2], red[3] }, { closes.textColor[1], closes.textColor[2], closes.textColor[3] })
		assert.are.same({ 1, red }, { now.step, now.ink }) -- the dial's last step, in the same red (HNT-R167)
		assert.are.equal(3, #shownWith(strip, "pip"))

		-- the run settles: the stamp in place of the pips, and the words back in the margin's red
		local copy = hunts.deepCopy(r.ns.State())
		copy.runs[SHORE].completedAt = SAT_15 - HOUR
		r.ns.projection = {
			GetState = function()
				return copy
			end,
			IsUpdating = function()
				return false
			end,
		}
		r.ns.board:Draw()

		strip = shownWith(r.ns.board:Page(place(r), "left"), "stripRun")[1]
		closes = textOf(strip, "closes in 42m")
		local margin = r.ns.BOARD_LOOK.red
		assert.are.same({ true, false }, { strip.settled, strip.urgent })
		assert.are.same({}, shownWith(strip, "pip"))
		assert.are.same(
			{ margin[1], margin[2], margin[3] },
			{ closes.textColor[1], closes.textColor[2], closes.textColor[3] }
		)
	end)

	it('leaves out the zones, then "+{n} more", before it cuts a long name', function()
		-- The fake client measures 6 units a character: "Shore Wager", "Darkshore" and "+1 more on the table" don't
		-- all fit beside "closes in 2d 4h" and the pips.
		local function texts(r)
			r.ns.board:Draw()
			local all = pageTexts(r, "left")
			return { has(all, "Darkshore"), has(all, "+1 more on the table") }
		end
		local alone = oneOn()
		alone.ns.ToggleBoard()
		local two = oneOn({
			pushed = {
				state = "notRunning",
				items = {
					{ kind = "huntRun", v = 1, event = "fixture_vale", start = THU_11 - HOUR, ["end"] = SAT_15 + HOUR },
				},
			},
		})
		two.ns.ToggleBoard()

		assert.are.same({ true, false }, texts(alone))
		assert.are.same({ false, true }, texts(two)) -- the zones go first

		two.ns.L["event.fixture_shore.name"] = string.rep("A long wager name ", 3)
		assert.are.same({ false, false }, texts(two)) -- then "+1 more", before the name is cut
		local strip = shownWith(two.ns.board:Page(place(two), "left"), "stripRun")[1]
		local name = textOf(strip, string.rep("A long wager name ", 3))
		assert.is_true(name:GetWidth() < #name.text * 6)
	end)

	it('adds "+1 more on the table" with a second run on, naming the one that closes first', function()
		-- A pushed run of fixture_vale, on from an hour ago to tomorrow (HNT-R151): it ends before the shore's.
		local r = oneOn({
			pushed = {
				state = "notRunning",
				items = {
					{ kind = "huntRun", v = 1, event = "fixture_vale", start = THU_11 - HOUR, ["end"] = THU_11 + DAY },
				},
			},
		})

		local strip = r.ns.BoardTimeline({ mode = "board" }).strip

		assert.are.same(
			{ "fixture_vale@" .. THU_11 - HOUR, "fixture_vale", "closes in 1d", "+1 more on the table" },
			{ strip.run, strip.name, strip.closes, strip.more }
		)
	end)

	it("is the spread's dashed row for the run ahead with none on, and the WAGERS group is left out", function()
		-- Slot 2 (the high band) has no event: nothing is on, and slot 3's fixture_shore starts at SAT_15.
		local r = start({ origin = SAT_15 - 3 * SLOT, clock = UTC })
		local asked = {}
		r.ns.OpenWagers = function(key)
			asked[#asked + 1] = key
		end

		local timeline = r.ns.BoardTimeline({ mode = "board" })

		assert.are.same({ "fixture_shore@" .. SAT_15, false }, { timeline.strip.run, timeline.strip.on })
		assert.are.same({ "Shore Wager", "Darkshore", "opens Sat 15:00", "for 3d" }, {
			timeline.strip.ahead.name,
			timeline.strip.ahead.zones,
			timeline.strip.ahead.opens,
			timeline.strip.ahead.length,
		})
		assert.is_nil(groupIn(timeline, "wagers")) -- it starts after the ruler's end: an empty group is left out
		r.ns.ToggleBoard()
		local texts = pageTexts(r, "left")
		assert.is_true(has(texts, "opens Sat 15:00"))
		assert.is_true(has(texts, "for 3d"))
		local page = r.ns.board:Page(place(r), "left")
		assert.are.same({}, shownWith(page, "stripRun"))
		shownWith(page, "aheadRun")[1]:Click()
		assert.are.same({ "fixture_shore@" .. SAT_15 }, asked)
	end)

	it("is left out before the rotation's starting point with no pushed run, and so is the group (HNT-R204)", function()
		local r = start({ now = SERVER_TIME, clock = hunts.SUNDAY })

		local timeline = r.ns.BoardTimeline({ mode = "board" })

		assert.is_nil(timeline.strip)
		assert.is_nil(groupIn(timeline, "wagers"))
		r.ns.ToggleBoard()
		assert.are.same({}, shownWith(r.ns.board:Page(place(r), "left"), "stripRun"))
		assert.are.same({}, shownWith(r.ns.board:Page(place(r), "left"), "aheadRun"))
		assert.are.same({}, shownWith(r.ns.board:Page(place(r), "left"), "runKey"))
	end)

	it("asks for the Pagle Wagers spread on its run when clicked, through ns.OpenWagers (HNT-R161)", function()
		local r = oneOn()
		local asked = {}
		r.ns.OpenWagers = function(key)
			asked[#asked + 1] = key
		end
		r.ns.ToggleBoard()

		shownWith(r.ns.board:Page(place(r), "left"), "stripRun")[1]:Click()

		assert.are.same({ SHORE }, asked)
		assert.are.same({ mode = "board", hunt = "fixture_eel" }, place(r))
	end)
end)

describe("the WAGERS group (HNT-R161, HNT-R62, HNT-R63)", function()
	it("sits above Now with a run row whose bar spans the ruler and ends in a mark, and a red hatch", function()
		local r = oneOn()

		local timeline = r.ns.BoardTimeline({ mode = "board" })

		assert.are.equal("wagers", timeline.groups[1].group)
		assert.are.equal("now", timeline.groups[2].group)
		local group = timeline.groups[1]
		assert.are.same(
			{ "Wagers: on for days, not hours", "Wagers", "on for days, not hours", 1 },
			{ group.heading, group.name, group.note, group.count }
		)
		local row = group.rows[1]
		assert.are.same({ SHORE, SHORE, "Shore Wager", "until Sat 17:00", "wagers", true }, {
			row.id,
			row.run,
			row.name,
			row.margin, -- HNT-R203: a 15:00 UTC end on a realm two hours ahead
			row.tone,
			row.more, -- it outlasts the ruler: the mark at its end
		})
		-- The run across the whole ruler, then the oddity's 18:00–21:00 hatched in red: the ruler starts at realm 11:00.
		local bars = {}
		for i, bar in ipairs(row.bars) do
			bars[i] = rounded(bar)
		end
		assert.are.same({ { 0, 1, "run" }, rounded({ from = 7 / 24, to = 10 / 24, style = "wager" }) }, bars)
		-- Its event mark, in place of its first Hunt's icon (HNT-R166).
		assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-water-coast", "mark-ring" }, row.mark)
		assert.is_nil(row.icon)
	end)

	it("shows a run ahead within the ruler from its start, its margin its weekday and time", function()
		-- Ten hours before SAT_15: the shore closes on the ruler, vale starts on it and runs past its end.
		local r = oneOn({
			now = SAT_15 - 10 * HOUR,
			clock = {
				time = SAT_15 - 10 * HOUR,
				minute = 5 * 60,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})

		local rows = groupIn(r.ns.BoardTimeline({ mode = "board" }), "wagers").rows

		assert.are.same({ SHORE, VALE }, hunts.ids(rows))
		assert.are.same({ "until Sat 15:00", false }, { rows[1].margin, rows[1].more })
		assert.are.same({ 0, 0.5, "run" }, rounded(rows[1].bars[1]))
		assert.are.same({ "Sat 15:00", true }, { rows[2].margin, rows[2].more })
		assert.are.same({ 0.5, 1, "run" }, rounded(rows[2].bars[1]))
	end)

	it("ignores show completed and pins, and moves with the live timeline at each regroup", function()
		local r = oneOn()
		r.ns.SetPinned("fixture_snapper", true)
		r.ns.SetShowCompleted(false)
		local before = groupIn(r.ns.BoardTimeline({ mode = "board" }), "wagers").rows[1]

		hunts.wait(r, HOUR)
		r.ns.Redraw("groups")

		local after = groupIn(r.ns.BoardTimeline({ mode = "board" }), "wagers").rows[1]
		assert.are.equal(SHORE, after.id)
		-- The hatch drifts an hour to the left with the hours (HNT-R62).
		assert.are.same(rounded({ from = 6 / 24, to = 9 / 24, style = "wager" }), rounded(after.bars[2]))
		assert.are.same(rounded({ from = 7 / 24, to = 10 / 24, style = "wager" }), rounded(before.bars[2]))
	end)

	it("draws the run's row with the mark at the ruler's end, as a texture", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		local row = shownWith(r.ns.board:Page(place(r), "left"), "runKey")[1]

		assert.are.same({ SHORE, "Shore Wager", "until Sat 17:00" }, { row.runKey, row.name.text, row.margin.text })
		assert.is_true(row.mark.shown) -- the event mark, 22 across in the icon's place
		assert.are.same({ 22, false }, { row.mark.size, row.icon.shown })
		assert.is_true(row.more.shown)
		assert.are.equal("Interface\\ChatFrame\\ChatFrameExpandArrow", row.more.texture)
		local texts = pageTexts(r, "left")
		assert.is_true(has(texts, "WAGERS"))
		assert.is_true(has(texts, "on for days, not hours"))
	end)
end)

describe("selecting a run (HNT-R67, HNT-R164)", function()
	it("still selects the first Hunt under Now when the board opens", function()
		local r = oneOn()

		r.ns.ToggleBoard()

		assert.are.same({ mode = "board", hunt = "fixture_eel" }, place(r))
	end)

	it("shows the run's entry when its row is clicked, with the breadcrumbs through Pagle Wagers", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		shownWith(r.ns.board:Page(place(r), "left"), "runKey")[1]:Click()

		assert.are.same({ mode = "board", run = SHORE }, place(r))
		local crumbs = {}
		for i, crumb in ipairs(r.ns.BoardCrumbs()) do
			crumbs[i] = crumb.text
		end
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, crumbs)
		local texts = pageTexts(r, "right")
		for _, text in ipairs({
			"FROM THE ROTATION · LOW WATERS",
			"Shore Wager",
			"Darkshore",
			"you're here",
			"closes in 2d 4h",
			"until Sat 17:00 · 3d in all",
			"Darkshore's tide, three days long.",
			"fixture_shore_haul",
			"Haul · Any fish",
			"Shore Snapper",
			"Named fish · Raw Nightfin Snapper",
			"fixture_shore_oddity",
			"Timed · Deviate Fish or Whimsyfin, 18:00–21:00",
			"opens at 18:00, in 5h", -- the oddity's window, at realm 13:00
			" / 2",
			" caught",
			" / 1",
			"1 Cast in these waters this run · 1 of 3 first marks",
			"PAID SO FAR",
			"+150 XP · 8 Coins",
			"SETTLE IT",
			"+250 XP · 25 Coins",
			"+1 Refresh", -- what settling pays (HNT-R117)
			RULE,
		}) do
			assert(has(texts, text), "the run's entry lacks " .. text)
		end
		assert.is_false(has(texts, "Pin"))
		assert.is_false(has(texts, "Pinned"))
		assert.is_false(has(texts, "not yet")) -- no seal before the run settles
	end)

	it("opens on a run from OpenBoard({ run = key }), turning to the Board ribbon from a set's page", function()
		local r = oneOn()
		r.ns.board:Open({ mode = "set", set = "fixture_dusk" })

		r.ns.OpenBoard({ run = SHORE })

		assert.are.same({ mode = "board", run = SHORE }, place(r))
		assert.is_true(has(pageTexts(r, "right"), "Shore Wager"))
		-- A Hunt row's click selects the Hunt again.
		for _, row in ipairs(shownWith(r.ns.board:Page(place(r), "left"), "huntID")) do
			if row.huntID == "fixture_eel" then
				row:Click()
			end
		end
		assert.are.same({ mode = "board", hunt = "fixture_eel" }, place(r))
	end)

	it("picks the first Now Hunt for a run no longer shown (HNT-R143)", function()
		local r = oneOn()

		r.ns.OpenBoard({ run = "fixture_vale@" .. O - SLOT })

		assert.are.same({ mode = "board", hunt = "fixture_eel" }, place(r))
	end)

	it("still takes a Hunt ID from the tracker (HNT-R77)", function()
		local r = oneOn()

		r.ns.OpenBoard("fixture_snapper")

		assert.are.same({ mode = "board", hunt = "fixture_snapper" }, place(r))
	end)
end)

describe("a run's entry (HNT-R163)", function()
	it(
		"is the run's data: kicker, name, time block, chips, note, each Hunt in order, the Casts, the boxes, the rule",
		function()
			local r = oneOn()

			local entry = r.ns.BoardRunEntry(SHORE)

			assert.are.same({
				"From the rotation · low waters",
				"Shore Wager",
				"closes in 2d 4h",
				"until Sat 17:00 · 3d in all",
				"Darkshore's tide, three days long.",
				"1 Cast in these waters this run · 1 of 3 first marks",
				RULE,
			}, {
				entry.kicker,
				entry.name,
				entry.time.hand,
				entry.time.small,
				entry.note,
				entry.casts,
				entry.payRule,
			})
			assert.is_nil(entry.seal)
			assert.are.same({
				{ label = "Paid so far", amount = "+150 XP · 8 Coins" },
				{ label = "Settle it", amount = "+250 XP · 25 Coins", refresh = "+1 Refresh" },
			}, entry.pay)
			assert.are.same({ { kind = "zone", text = "Darkshore", here = true, badge = "you're here" } }, entry.chips)
			local lines = {}
			for i, hunt in ipairs(entry.hunts) do
				lines[i] = { hunt.name, hunt.line, hunt.count.count .. hunt.count.rest }
			end
			assert.are.same({
				{ "fixture_shore_haul", "Haul · Any fish", "1 / 2" },
				{ "Shore Snapper", "Named fish · Raw Nightfin Snapper", "1 caught" },
				{ "fixture_shore_oddity", "Timed · Deviate Fish or Whimsyfin, 18:00–21:00", "0 / 1" },
			}, lines)
			assert.are.same({ true }, { entry.hunts[2].tiers[1].reached })
			-- the oddity's window from its time condition alone, in realm time (HNT-R50)
			assert.are.same({ open = false, text = "opens at 18:00, in 5h" }, entry.hunts[3].window)
		end
	)

	it('presses the seal, "Settled" over its short date, once completed, and pays the run on top', function()
		-- A Deviate Fish on Wednesday evening, realm 18:30: the oddity's hours.
		local history = onHistory()
		history[#history + 1] = castAt(O + 3 * HOUR + 30 * 60, C.DARKSHORE, { C.DEVIATE })
		history[#history].conditions.minute = 18 * 60 + 30
		local r = start({ origin = O, history = history })

		local entry = r.ns.BoardRunEntry(SHORE)

		assert.are.same({ word = "Settled", date = "14 Oct" }, entry.seal)
		-- Three first marks (the Deviate Fish is the Haul's second fish and the oddity's first) and the settled run:
		-- 3 × 150 + 250 XP, 3 × 8 + 25 Coins, and the run's Refresh.
		assert.are.same({ label = "Paid so far", amount = "+700 XP · 49 Coins", refresh = "+1 Refresh" }, entry.pay[1])
		assert.are.same({ label = "Settled", amount = "paid out" }, entry.pay[2])
		r.ns.OpenBoard({ run = SHORE })
		local texts = pageTexts(r, "right")
		assert.is_true(has(texts, "SETTLED"))
		assert.is_true(has(texts, "14 Oct"))
	end)

	it("reads the companion's kicker for a pushed run", function()
		local r = oneOn({
			pushed = {
				state = "notRunning",
				items = {
					{ kind = "huntRun", v = 1, event = "fixture_vale", start = THU_11 - HOUR, ["end"] = THU_11 + DAY },
				},
			},
		})

		local entry = r.ns.BoardRunEntry("fixture_vale@" .. THU_11 - HOUR)

		assert.are.same({ "Sent by the companion", "companion" }, { entry.kicker, entry.source })
	end)

	it(
		"reads the updating line over its rows, with no seal, counts, Casts or boxes, while updating (HNT-R69)",
		function()
			local r = oneOn()
			local state = r.ns.State()
			r.ns.projection = {
				GetState = function()
					return state
				end,
				IsUpdating = function()
					return true
				end,
			}
			local updating = "Updating from your Catch log…"

			local entry = r.ns.BoardRunEntry(SHORE)
			local timeline = r.ns.BoardTimeline({ mode = "board" })

			assert.are.equal(updating, entry.updating)
			assert.is_nil(entry.seal)
			assert.is_nil(entry.casts)
			assert.is_nil(entry.pay)
			for _, hunt in ipairs(entry.hunts) do
				assert.is_nil(hunt.count)
				assert.is_nil(hunt.tiers)
			end
			-- The strip and the WAGERS rows still show from the known runs; the pips read "updating…", as the tickets'
			-- marks do (HNT-R163).
			assert.are.same(
				{ nil, "updating…", "Shore Wager" },
				{ timeline.strip.pips, timeline.strip.updating, timeline.strip.name }
			)
			assert.are.equal(SHORE, groupIn(timeline, "wagers").rows[1].id)
		end
	)
end)

describe("the nameplate (HNT-R165)", function()
	it("counts ladder titles with the set titles", function()
		local r = oneOn()
		local state = r.ns.NewHuntsState()
		state.ladder[25] = O
		r.ns.projection = {
			GetState = function()
				return state
			end,
			IsUpdating = function()
				return false
			end,
		}

		assert.are.equal("1 title · 0 Hunts done", r.ns.BoardNameplate().text)
		assert.are.same({ "Bookmaker's Bane, earned 14 Oct 2026" }, r.ns.BoardNameplate().titles)
	end)
end)

describe("Pagle Wagers' words stay on the Board's pages (HNT-R60)", function()
	it("on the strip, the WAGERS rows and the run's entry, with long names", function()
		local long = "The Longest Wager Anyone Has Laid On These Waters Yet"
		local r = oneOn({
			prepare = function(loaded)
				local L = loaded.ns.L
				L["event.fixture_shore.name"] = long
				L["event.fixture_shore.note"] = long .. ", and its note runs on longer still, past the page's edge."
				for _, id in ipairs({ "fixture_shore_haul", "fixture_shore_snapper", "fixture_shore_oddity" }) do
					L["hunt." .. id .. ".name"] = long
				end
			end,
		})
		r.ns.OpenBoard({ run = SHORE })

		for _, side in ipairs({ "left", "right" }) do
			assert.are.same({}, bounds.overflows(r.ns.board:Page(place(r), side)))
		end
	end)
end)
