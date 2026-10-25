-- The Pagle Wagers ribbon and spread (HNT-R60, HNT-R61, HNT-R69, HNT-R143, HNT-R148, HNT-R156, HNT-R160, HNT-R162,
-- HNT-R163, HNT-R164, HNT-R165, HNT-R166, HNT-R167, HNT-R204): the ribbon hanging second with "{n} on", its spread's
-- note, closing note, wager tickets, rows ahead and ladder rail on the left and the chosen run's entry on the right (the
-- Wagers redesign's variant A), its motion, the breadcrumbs through "Pagle Wagers", and the nameplate's ladder titles,
-- as data (ns.BoardRibbons, ns.BoardWagersSpread) and as drawn, on FakePagle over the fixture Hunt list and catalogue,
-- a fixed clock and live conditions.
--
-- As spec/Pagle_Hunts/adapter/Wagers_spec.lua: the fixture pool with fixture_vale moved to the mid band, so the fallback
-- rotation (HNT-R152) runs slot 0 fixture_shore (low), slot 1 fixture_vale (mid). fixture_shore ("Shore Wager",
-- Darkshore) has three Hunts: a Haul (2 / 4), a Named fish (Raw Nightfin Snapper, 1) and a Timed oddity (1). The clock:
-- Thursday 15 October 2026 11:00 UTC, so slot 0 ending Saturday 17 October 15:00 UTC closes in 2d 4h and reads
-- "Sat 17:00" on a realm two hours ahead of UTC (HNT-R203).

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
--- The realm clock at THU_11 on a realm two hours ahead of UTC (13:00).
local AHEAD = { time = THU_11, minute = 13 * 60, date = { year = 2026, month = 10, day = 15, weekday = 5 } }

local UPDATING = "Updating from your Catch log…"

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

--- Hunts logged in at `options.now` (THU_11) with the rotation's origin at `options.origin`, the live conditions at
--- `options.clock` (AHEAD), names loaded, `options.history` (records) in the Catch log before login, `options.pushed`
--- as the pushed content, and `options.list` and `options.motion` to hunts.start; then the frames where the pushed
--- content's check ends and the run log's step runs (HNT-R151).
---@return HuntsRun
local function start(options)
	local now, origin = options.now or THU_11, options.origin
	local r = hunts.start({
		from = now - SERVER_TIME,
		names = true,
		events = pool,
		list = options.list,
		motion = options.motion,
		prepare = function(loaded)
			if origin then
				loaded.ns.ROTATION_ORIGIN = origin
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
local function onHistory()
	return {
		hunts.record("run", hunts.runPayload("fixture_shore", O, SAT_15), O),
		castAt(O + HOUR, C.DARKSHORE, { C.NIGHTFIN }),
	}
end

local function oneOn(options)
	options = options or {}
	options.origin, options.history = O, options.history or onHistory()
	return start(options)
end

-- A pushed run of fixture_vale, on from an hour before THU_11 to a day after it: it closes before the shore's.
local VALE_PUSHED = "fixture_vale@" .. THU_11 - HOUR
local TWO_ON = {
	state = "notRunning",
	items = {
		{ kind = "huntRun", v = 1, event = "fixture_vale", start = THU_11 - HOUR, ["end"] = THU_11 + DAY },
	},
}

--- The board's place now.
local function place(r)
	return r.ns.board.router:Place()
end

--- The texts shown on a page of the board, "left" or "right", in the mode shown.
local function pageTexts(r, side)
	return shownTexts(r.ns.board:Page(place(r), side))
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

--- The shown wager ticket of run `runKey` on the spread's left page.
local function ticketOf(r, runKey)
	for _, ticket in ipairs(shownWith(r.ns.board:Page(place(r), "left"), "ticketRun")) do
		if ticket.ticketRun == runKey then
			return ticket
		end
	end
end

--- The shown row ahead of run `runKey` on the spread's left page.
local function aheadOf(r, runKey)
	for _, row in ipairs(shownWith(r.ns.board:Page(place(r), "left"), "aheadRun")) do
		if row.aheadRun == runKey then
			return row
		end
	end
end

--- The ladder's line as drawn: its runs of words, left to right, joined.
local function ladderLine(r)
	local ladder = r.ns.board:Page(place(r), "left").spread.ladder
	local words = {}
	for _, text in ipairs(ladder.line) do
		if text.shown then
			words[#words + 1] = text.text
		end
	end
	return table.concat(words)
end

--- Asserts `actual` is `expected` within a rounding error.
local function near(expected, actual)
	assert(math.abs(expected - actual) < 1e-9, ("%s, not %s"):format(expected, actual))
end

--- The Wagers sprite a texture shows, read back from its texture coordinates; nil for another atlas's.
local function spriteOf(r, texture)
	local atlas = r.ns.ATLASES.Wagers
	if texture.texture ~= atlas.file then
		return nil
	end
	for name, sprite in pairs(atlas.sprites) do
		local c = texture.texCoord
		if math.abs(c[1] - sprite.x / atlas.width) < 1e-9 and math.abs(c[3] - sprite.y / atlas.height) < 1e-9 then
			return name
		end
	end
end

--- The breadcrumbs' words.
local function crumbWords(r)
	local words = {}
	for i, crumb in ipairs(r.ns.BoardCrumbs()) do
		words[i] = crumb.text
	end
	return words
end

--- The shown crumb button reading `text`.
local function crumbButton(r, text)
	for _, crumb in ipairs(r.ns.board.frame.crumbButtons) do
		if crumb:IsShown() and crumb.label:GetText() == text then
			return crumb
		end
	end
end

--- Serves `state` as the projection's, not updating, or updating with `updating`.
local function serve(r, state, updating)
	r.ns.projection = {
		GetState = function()
			return state
		end,
		IsUpdating = function()
			return updating == true
		end,
	}
end

describe("the Pagle Wagers ribbon (HNT-R61, HNT-R162)", function()
	it('hangs second, after Board and before the set ribbons, reading "1 on" with one run on', function()
		local r = oneOn()

		local ribbons = r.ns.BoardRibbons({ mode = "board" })

		local words = {}
		for i, ribbon in ipairs(ribbons) do
			words[i] = ribbon.name or ribbon.text
		end
		assert.are.same({ "Board", "Pagle Wagers", "Dusk", "Wagers", "fixture_pair", "fixture_tide" }, words)
		assert.are.same({ true, "1 on", false }, { ribbons[2].wagers, ribbons[2].count, ribbons[2].chosen })
		assert.are.same({ mode = "wagers" }, ribbons[2].place)
		assert.is_nil(ribbons[1].count)
	end)

	it("is drawn in oxblood with its count under its name, and #333 finds its frame", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		local ribbon = r.ns.BoardWagersRibbon()

		assert.are.equal(r.ns.board.frame.ribbons[2], ribbon)
		assert.are.same({ "Pagle Wagers", "1 on" }, shownTexts(ribbon))
		assert.are.same(r.ns.BOARD_LOOK.oxblood, ribbon.color)
	end)

	it("reads no count with no run on, and hangs still before the rotation starts (HNT-R204)", function()
		local r = start({ now = SERVER_TIME, clock = hunts.SUNDAY })
		r.ns.ToggleBoard()

		assert.is_nil(r.ns.BoardRibbons({ mode = "board" })[2].count)
		assert.are.same({ "Pagle Wagers" }, shownTexts(r.ns.BoardWagersRibbon()))
	end)

	it("counts every run on, not the runs ahead", function()
		local r = oneOn({ pushed = TWO_ON })

		assert.are.equal("2 on", r.ns.BoardRibbons({ mode = "board" })[2].count)
	end)

	it("turns the page to the spread when chosen, and hangs chosen there", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		r.ns.BoardWagersRibbon():Click()

		assert.are.same({ mode = "wagers" }, place(r))
		local ribbons = r.ns.BoardRibbons(place(r))
		assert.are.same({ false, true }, { ribbons[1].chosen, ribbons[2].chosen })
		assert.is_true(r.ns.BoardWagersRibbon().chosen)
	end)
end)

describe("the Pagle Wagers spread (HNT-R162)", function()
	it("shows the note, one ticket with its dial, mark, line and first marks, and the ladder at 0 of 25", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		r.ns.BoardWagersRibbon():Click()

		local texts = pageTexts(r, "left")
		for _, text in ipairs({
			"PAGLE WAGERS",
			"On the table",
			"One wager on. Land every Hunt's first mark before it closes.",
			"ON NOW",
			"1",
			"Shore Wager",
			"Darkshore · until Sat 17:00",
			"2d 4h",
			"1 of 3 first marks",
			"THE LADDER",
			"25",
			"50",
			"100",
			"Bookmaker's Bane",
		}) do
			assert(has(texts, text), "the spread's left page lacks " .. text)
		end
		assert.are.equal("0 wagers settled · 25 more for Bookmaker's Bane", ladderLine(r))
		local ticket = ticketOf(r, SHORE)
		assert.is_true(ticket.selected)
		-- its pips, as the strip's: the Haul at 1 of 2, the Snapper's first mark, the oddity none
		local pips = shownWith(ticket, "pip")
		assert.are.same({ false, true, false }, { pips[1].inked, pips[2].inked, pips[3].inked })
		-- the chosen ticket's paper, its dial 26 steps of 36 in oxblood, and its mark from its tags (coast, no time)
		assert.are.equal("ticket-sel", spriteOf(r, ticket.paper.left))
		assert.are.equal("dial-fill-26", spriteOf(r, ticket.dial.fill))
		assert.are.same(r.ns.BOARD_LOOK.oxblood, ticket.dial.ink)
		assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-water-coast", "mark-ring" }, ticket.mark.names)
		assert.is_false(ticket.stampFrame.shown)
		-- no run closes within three hours: no closing note
		assert.is_false(has(texts, "Shore Wager closes in 2d 4h!"))
		assert.is_false(r.ns.board:Page(place(r), "left").spread.arrow.shown)
	end)

	it("puts the token at the count on the rail and presses no post before its step", function()
		local r = oneOn()
		local state = r.ns.State()
		state.settled = 17
		serve(r, state)

		r.ns.OpenWagers()

		local ladder = r.ns.board:Page(place(r), "left").spread.ladder
		near(17 / 75, ladder.share)
		assert.are.equal("17 wagers settled · 8 more for Bookmaker's Bane", ladderLine(r))
		assert.are.equal("post", spriteOf(r, ladder.posts[1]))
		assert.is_true(ladder.token.shown)
		assert.are.equal("rail-fill", spriteOf(r, ladder.fill))
		near(445 * 17 / 75, ladder.fill.width)
	end)

	it("shows the first run's entry on the right page, with the crumbs stopping at Pagle Wagers", function()
		local r = oneOn()

		r.ns.OpenWagers()

		assert.are.same({ mode = "wagers" }, place(r))
		local texts = pageTexts(r, "right")
		for _, text in ipairs({
			"FROM THE ROTATION · LOW WATERS",
			"Shore Wager",
			"closes in 2d 4h",
			"until Sat 17:00 · 3d in all",
			"Darkshore",
			"1 Cast in these waters this run · 1 of 3 first marks",
			"PAID SO FAR",
			"+150 XP · 8 Coins",
			"SETTLE IT",
			"+250 XP · 25 Coins",
		}) do
			assert(has(texts, text), "the run's entry lacks " .. text)
		end
		assert.are.same({ "Hunts", "Pagle Wagers" }, crumbWords(r))
	end)

	it("opens on the strip's run from the wager strip (HNT-R161)", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		shownWith(r.ns.board:Page(place(r), "left"), "stripRun")[1]:Click()

		assert.are.same({ mode = "wagers", run = SHORE }, place(r))
		assert.is_true(has(pageTexts(r, "left"), "On the table"))
	end)

	it("chooses a ticket when clicked: its entry on the right, the crumbs through its event (HNT-R164)", function()
		local r = oneOn({ pushed = TWO_ON })
		r.ns.OpenWagers()
		-- on, by end: the pushed vale closes first (HNT-R160)
		assert.is_true(ticketOf(r, VALE_PUSHED).selected)
		assert.is_true(has(pageTexts(r, "left"), "2 wagers on. Land every Hunt's first mark before its wager closes."))

		ticketOf(r, SHORE):Click()

		assert.are.same({ mode = "wagers", run = SHORE }, place(r))
		assert.is_true(ticketOf(r, SHORE).selected)
		assert.is_false(ticketOf(r, VALE_PUSHED).selected)
		assert.are.equal("ticket", spriteOf(r, ticketOf(r, VALE_PUSHED).paper.left))
		assert.is_true(has(pageTexts(r, "right"), "Shore Wager"))
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, crumbWords(r))
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, shownTexts(r.ns.board.frame.crumbs))
	end)

	it("marks the companion's run and its skill short in pencil (HNT-R156)", function()
		local r = oneOn({ pushed = TWO_ON })

		r.ns.OpenWagers()

		local ticket = ticketOf(r, VALE_PUSHED)
		-- fixture_vale is in the mid band here, its skill from 175; the Angler's best is 150
		assert.is_true(has(shownTexts(ticket), "needs skill 175"))
		assert.are.same(r.ns.BOARD_LOOK.pencil, { unpack(ticket.need.textColor, 1, 3) })
		assert.are.equal("src-companion", spriteOf(r, ticket.src))
		assert.is_true(ticket.srcSeal.shown)
		assert.is_false(has(shownTexts(ticketOf(r, SHORE)), "needs skill 175"))
	end)

	it('goes back to the tickets from the "Pagle Wagers" crumb, and to the Board from "Hunts"', function()
		local r = oneOn({ pushed = TWO_ON })
		r.ns.OpenWagers(SHORE)

		crumbButton(r, "Pagle Wagers"):Click()

		assert.are.same({ mode = "wagers" }, place(r))
		assert.are.same({ "Hunts", "Pagle Wagers" }, crumbWords(r))
		assert.is_true(ticketOf(r, VALE_PUSHED).selected)

		crumbButton(r, "Hunts"):Click()
		assert.are.equal("board", place(r).mode)
	end)

	it('turns to the spread on the run from the Board\'s "Pagle Wagers" crumb (HNT-R164)', function()
		local r = oneOn()
		r.ns.OpenBoard({ run = SHORE })
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, crumbWords(r))

		crumbButton(r, "Pagle Wagers"):Click()

		assert.are.same({ mode = "wagers", run = SHORE }, place(r))
		assert.is_true(ticketOf(r, SHORE).selected)
	end)

	it('gives a run ahead a dashed row under "Ahead", which a click chooses', function()
		-- Ten hours before SAT_15: the shore is on, and slot 1's fixture_vale is ahead.
		local r = oneOn({
			now = SAT_15 - 10 * HOUR,
			clock = {
				time = SAT_15 - 10 * HOUR,
				minute = 7 * 60,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})
		local vale = "fixture_vale@" .. SAT_15
		r.ns.OpenWagers()

		local row = aheadOf(r, vale)
		assert.are.same(
			{ "fixture_vale", "Ashenvale & Elwynn Forest", "needs skill 175", "opens Sat 17:00", "for 3d" },
			shownTexts(row)
		)
		assert.is_nil(ticketOf(r, vale))
		local texts = pageTexts(r, "left")
		assert.is_true(has(texts, "AHEAD"))
		assert.is_true(has(texts, "posted, and may change before it opens"))
		assert.is_true(#row.outline.dashes > 0) -- dashed

		row:Click()

		assert.are.same({ mode = "wagers", run = vale }, place(r))
		assert.is_true(aheadOf(r, vale).selected)
		local right = pageTexts(r, "right")
		assert.is_true(has(right, "opens Sat 17:00"))
		assert.is_true(has(right, "until Tue 17:00 · 3d on the table"))
		assert.is_false(has(right, "PAID SO FAR"))
		assert.are.equal("dial-ahead", spriteOf(r, r.ns.RunEntryView(r.ns.board:Page(place(r), "right")).dial.face))
	end)

	it("says when the next opens with only a run ahead, the entry its own (HNT-R162)", function()
		-- Slot 2 (the high band) has no event: nothing is on, and slot 3's fixture_shore starts at SAT_15.
		local r = start({
			origin = SAT_15 - 3 * SLOT,
			clock = { time = THU_11, minute = 11 * 60, date = { year = 2026, month = 10, day = 15, weekday = 5 } },
		})

		r.ns.OpenWagers()

		local texts = pageTexts(r, "left")
		assert.is_true(has(texts, "Nothing on just now. The next wager opens Sat 15:00."))
		assert.is_false(has(texts, "ON NOW"))
		assert.is_true(has(texts, "AHEAD"))
		assert.is_true(has(pageTexts(r, "right"), "opens Sat 15:00"))
	end)

	it("stamps a settled run's ticket and presses the entry's seal, the ladder 1 of 25 (HNT-R146, HNT-R148)", function()
		-- A Deviate Fish on Wednesday evening, realm 18:30: the oddity's hours, and the Haul's second fish.
		local history = onHistory()
		history[#history + 1] = castAt(O + 3 * HOUR + 30 * 60, C.DARKSHORE, { C.DEVIATE })
		history[#history].conditions.minute = 18 * 60 + 30
		local r = oneOn({ history = history })

		r.ns.OpenWagers()

		local ticket = ticketOf(r, SHORE)
		assert.is_true(ticket.stampFrame.shown)
		assert.are.equal("stamp-settled", spriteOf(r, ticket.stamp))
		assert.are.same({}, shownWith(ticket, "pip"))
		assert.is_false(has(shownTexts(ticket), "3 of 3 first marks"))
		assert.is_true(has(shownTexts(ticket), "2d 4h")) -- the dial stays, in grey
		assert.are.same(r.ns.BOARD_LOOK.spent, ticket.dial.ink)
		assert.are.equal("1 wager settled · 24 more for Bookmaker's Bane", ladderLine(r))
		local right = pageTexts(r, "right")
		for _, text in ipairs({ "SETTLED", "14 Oct", "settled, and still open", "PAID SO FAR", "paid out" }) do
			assert(has(right, text), "the settled entry lacks " .. text)
		end
	end)

	it("puts the closing note in the margin within 3 hours of a run's end, its dial and words in red", function()
		local r = oneOn({
			now = SAT_15 - 42 * 60,
			clock = {
				time = SAT_15 - 42 * 60,
				minute = 16 * 60 + 18,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})

		r.ns.OpenWagers()

		local spread = r.ns.board:Page(place(r), "left").spread
		assert.is_true(has(pageTexts(r, "left"), "Shore Wager closes in 42m!"))
		assert.are.equal("arrow", spriteOf(r, spread.arrow))
		assert.is_true(spread.arrow.shown)
		local ticket = ticketOf(r, SHORE)
		assert.are.same(r.ns.BOARD_LOOK.nowLine, ticket.dial.ink)
		assert.are.equal("dial-fill-01", spriteOf(r, ticket.dial.fill))
		assert.are.same(r.ns.BOARD_LOOK.nowLine, { unpack(ticket.left.textColor, 1, 3) })
	end)

	it(
		"shows the empty box with a plain mark, and the entry's own words, with nothing on or ahead (HNT-R204)",
		function()
			local r = start({ now = SERVER_TIME, clock = hunts.SUNDAY })

			r.ns.OpenWagers()

			local texts = pageTexts(r, "left")
			assert.is_true(has(texts, "Nothing on the table, and nothing posted yet."))
			assert.is_true(
				has(texts, "No wagers on the table, and none posted ahead. The rotation puts one on at the next turn.")
			)
			assert.are.equal("0 wagers settled · 25 more for Bookmaker's Bane", ladderLine(r))
			assert.are.same({}, shownWith(r.ns.board:Page(place(r), "left"), "ticketRun"))
			local spread = r.ns.board:Page(place(r), "left").spread
			assert.are.same({ "mark-shadow", "mark-sky-plain", "mark-ring" }, spread.emptyMark.names)
			assert.is_true(spread.emptyMark.layers[1].desaturated)
			local right = pageTexts(r, "right")
			assert.is_true(has(right, "Nothing to read yet"))
			assert.is_true(
				has(right, "When a wager goes up it will be written here: its waters, its Hunts and what it pays.")
			)
			assert.is_true(has(right, r.ns.RunPayRule()))
		end
	)

	it(
		"reads the updating line for the marks, the rows and the ladder while the projection updates (HNT-R69)",
		function()
			local r = oneOn()
			serve(r, r.ns.State(), true)

			r.ns.OpenWagers()

			local texts = pageTexts(r, "left")
			assert.is_true(has(texts, "Shore Wager"))
			assert.is_false(has(texts, "1 of 3 first marks"))
			assert.is_true(has(texts, "updating…"))
			assert.are.equal(UPDATING, ladderLine(r))
			assert.are.same({}, shownWith(ticketOf(r, SHORE), "pip"))
			assert.is_false(r.ns.board:Page(place(r), "left").spread.ladder.token.shown)
			local right = pageTexts(r, "right")
			assert.is_true(has(right, UPDATING))
			assert.is_false(has(right, "PAID SO FAR"))
			assert.is_false(has(right, "1 / 2"))
		end
	)

	it('lays as many rows as fit above the ladder, then "+{n} more on the table" in the last one\'s place', function()
		-- Seven pushed runs of fixture_vale ahead, a day each, after the shore's; the companion connected, so no hint.
		local items = {}
		for i = 1, 7 do
			local from = SAT_15 + (i - 1) * DAY
			items[i] = { kind = "huntRun", v = 1, event = "fixture_vale", start = from, ["end"] = from + DAY }
		end
		local r = oneOn({ pushed = { state = "connected", items = items } })

		r.ns.OpenWagers()

		local page = r.ns.board:Page(place(r), "left")
		assert.are.equal(1, #shownWith(page, "ticketRun"))
		assert.are.equal(5, #shownWith(page, "aheadRun"))
		assert.is_true(has(pageTexts(r, "left"), "+2 more on the table"))
		assert.are.same({}, bounds.overflows(page))
	end)
end)

describe("a run that ends while the board is open (HNT-R143, HNT-R162)", function()
	-- Ten minutes before the shore closes, on a realm two hours ahead: Saturday 16:50.
	local function nearEnd()
		return oneOn({
			now = SAT_15 - 10 * 60,
			clock = {
				time = SAT_15 - 10 * 60,
				minute = 16 * 60 + 50,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})
	end

	it("stays on the spread, greyed, struck through and closed, until the board closes; then nothing shows", function()
		local r = nearEnd()
		r.ns.OpenWagers()
		assert.is_true(ticketOf(r, SHORE).selected)
		assert.is_true(has(pageTexts(r, "left"), "Shore Wager closes in 10m!"))

		hunts.wait(r, 11 * 60)

		local ticket = ticketOf(r, SHORE)
		assert.is_true(ticket.closed)
		assert.is_false(ticket.selected)
		local texts = shownTexts(ticket)
		assert.is_true(has(texts, "closed"))
		assert.is_true(has(texts, "Shore Wager"))
		assert.is_true(has(texts, "Darkshore · closed Sat 17:00"))
		assert.is_true(ticket.strike.shown)
		assert.are.equal(0.5, ticket.alpha)
		assert.is_true(ticket.paper.left.desaturated)
		assert.is_false(ticket.dial.fill.shown)
		-- The next slot's run is on, and the right page shows it in the closed one's place.
		assert.is_true(ticketOf(r, "fixture_vale@" .. SAT_15).selected)
		assert.is_false(has(pageTexts(r, "right"), "Shore Wager"))

		r.ns.board:Hide()
		r.ns.OpenWagers()

		assert.is_nil(ticketOf(r, SHORE))
		assert.is_false(has(pageTexts(r, "left"), "Shore Wager"))
	end)

	it("closes on the spread though the board showed the Board ribbon as it ended", function()
		local r = nearEnd()
		r.ns.ToggleBoard()

		hunts.wait(r, 11 * 60)
		r.ns.OpenWagers()

		assert.is_true(ticketOf(r, SHORE).closed)
	end)

	it("doesn't take a click: a closed ticket is never chosen", function()
		local r = nearEnd()
		r.ns.OpenWagers()
		hunts.wait(r, 11 * 60)

		ticketOf(r, SHORE):Click()

		assert.are.same({ mode = "wagers" }, place(r))
	end)
end)

describe("the run's entry on the spread (HNT-R163)", function()
	it("draws each Hunt's glyph, count, diamonds, ink bar and the Timed Hunt's window", function()
		local r = oneOn()

		r.ns.OpenWagers()

		local view = r.ns.RunEntryView(r.ns.board:Page(place(r), "right"))
		local haul, snapper, oddity = view.rows[1], view.rows[2], view.rows[3]
		assert.are.same({ "shape-haul", "shape-namedfish", "shape-timed" }, {
			spriteOf(r, haul.glyph),
			spriteOf(r, snapper.glyph),
			spriteOf(r, oddity.glyph),
		})
		assert.are.same(r.ns.BOARD_LOOK.oxblood, { unpack(snapper.glyph.vertexColor, 1, 3) })
		assert.are.same(r.ns.BOARD_LOOK.legend, { unpack(haul.glyph.vertexColor, 1, 3) })
		assert.are.same({ "1", " / 2" }, { haul.count.text, haul.rest.text })
		assert.are.same({ "1", " caught" }, { snapper.count.text, snapper.rest.text })
		assert.are.equal(2, #shownWith({ children = haul.diamonds }, "texCoord"))
		assert.are.equal((r.ns.board:Page(place(r), "right"):GetWidth() - 26) / 2, haul.fill.width)
		-- the oddity's 18:00–21:00: at realm 13:00 it opens at 18:00, in 5h
		assert.is_true(oddity.window.shown)
		assert.are.equal("opens at 18:00, in 5h", oddity.window.text)
		assert.are.equal("mark-water-coast", view.mark.names[3])
		assert.is_false(view.seal.shown)
	end)

	it("shows the Refreshes a box pays beside its label, and nothing where none are paid (HNT-R117)", function()
		local r = oneOn()
		r.ns.OpenWagers()
		local page = r.ns.board:Page(place(r), "right")
		local view = r.ns.RunEntryView(page)

		-- Nothing is paid so far; settling the run pays TICKETS_RUN.
		assert.is_false(view.pay[1].refresh.shown)
		assert.is_true(view.pay[2].refresh.shown)
		assert.are.equal("+1 Refresh", view.pay[2].refresh.text)
		assert.are.same({}, bounds.overflows(page))
	end)

	it("keeps to the page by the fit rule: the pay rule first, its words the boxes' tooltip", function()
		local r = oneOn()
		r.ns.OpenWagers()
		local page = r.ns.board:Page(place(r), "right")
		local view = r.ns.RunEntryView(page)
		assert.are.same({ rule = false, casts = false, windows = false }, view.dropped)
		assert.is_true(view.payRule.shown)
		assert.is_nil(view.pay[1].tooltip)

		-- a note some six lines long: the entry would end 8 units too low
		view.note.GetStringHeight = function()
			return 110
		end
		r.ns.board:Draw()

		assert.are.same({ rule = true, casts = false, windows = false }, view.dropped)
		assert.is_false(view.payRule.shown)
		assert.are.same({ "Paid so far", r.ns.RunPayRule() }, view.pay[1].tooltip)
		assert.is_true(view.casts.shown)
		assert.is_true(view.rows[3].window.shown)
		assert.are.same({}, bounds.overflows(page))
	end)

	it("leaves out the Casts line, then the window lines, when the pay rule isn't enough", function()
		local r = oneOn()
		r.ns.OpenWagers()
		local page = r.ns.board:Page(place(r), "right")
		local view = r.ns.RunEntryView(page)

		view.note.GetStringHeight = function()
			return 200
		end
		r.ns.board:Draw()

		assert.are.same({ rule = true, casts = true, windows = true }, view.dropped)
		assert.is_false(view.casts.shown)
		assert.is_false(view.rows[3].window.shown)
		assert.is_true(view.pay[1].shown)
	end)
end)

describe("the spread's motion (HNT-R162)", function()
	-- The shore settles while the spread shows: the projection's state with the run completed and counted.
	local function settle(r)
		local state = r.ns.State()
		local copy = hunts.deepCopy(state)
		copy.runs[SHORE].completedAt = O + 2 * HOUR
		copy.settled = (state.settled or 0) + 1
		serve(r, copy)
		r.ns.board:Draw()
	end

	it("presses the stamp from larger and clear, then the ticket nudges down and back, with Animations on", function()
		local r = oneOn({ motion = true })
		r.ns.OpenWagers()
		for _ = 1, 40 do
			r.loaded.client.nextFrame(1 / 60)
		end

		settle(r)

		local ticket = ticketOf(r, SHORE)
		assert.is_true(ticket.stampFrame.shown)
		assert.is_true(ticket.stamp.width > 96) -- at 1.6 times its size, and clear
		assert.is_true(ticket.stamp.alpha < 0.5)
		for _ = 1, 30 do
			r.loaded.client.nextFrame(1 / 60)
		end
		assert.are.equal(96, ticket.stamp.width)
		assert.are.equal(1, ticket.stamp.alpha)
		assert.are.same({ "TOPLEFT", ticket.top }, { ticket.points[1][1], -ticket.points[1][5] })
	end)

	it("slides the token to the new count, with Animations on", function()
		local r = oneOn({ motion = true })
		r.ns.OpenWagers()
		local ladder = r.ns.board:Page(place(r), "left").spread.ladder
		assert.are.equal(0, ladder.share)

		settle(r)
		r.loaded.client.nextFrame(0.1)

		assert.is_true(ladder.share > 0 and ladder.share < 1 / 75)
		for _ = 1, 40 do
			r.loaded.client.nextFrame(1 / 60)
		end
		near(1 / 75, ladder.share)
	end)

	it("settles at once with Animations off: every state reads without motion", function()
		local r = oneOn()
		r.ns.OpenWagers()

		settle(r)

		local ticket = ticketOf(r, SHORE)
		assert.are.same({ 96, 1 }, { ticket.stamp.width, ticket.stamp.alpha })
		near(1 / 75, r.ns.board:Page(place(r), "left").spread.ladder.share)
	end)
end)

describe("the nameplate with the ladder's titles (HNT-R165)", function()
	it("counts Bookmaker's Bane among its titles at 25 settled runs, and the ladder marks it", function()
		local r = oneOn()
		local state = r.ns.State()
		state.settled = 25
		state.ladder[25] = O
		serve(r, state)

		r.ns.OpenWagers()

		-- The Snapper caught an hour into the run is a Standing Hunt's first tier too: two Hunts done.
		assert.are.equal("1 title · 2 Hunts done", r.ns.BoardNameplate().text)
		assert.are.same({ "Bookmaker's Bane, earned 14 Oct 2026" }, r.ns.BoardNameplate().titles)
		local ruin = r.ns.LadderTitle(50)
		assert.are.equal("25 wagers settled · 25 more for " .. ruin, ladderLine(r))
		assert.are.same({ "1 title · 2 Hunts done" }, shownTexts(r.ns.board.frame.plate))
	end)
end)

describe("the spread's motion and fit (HNT-R60)", function()
	it("turns the page forward from the Board to the spread, with the page-turn sound", function()
		local r = oneOn({ motion = true })
		r.ns.ToggleBoard()
		for _ = 1, 30 do
			r.loaded.client.nextFrame(1 / 60)
		end
		local sounds = r.loaded.client.sounds
		for i = #sounds, 1, -1 do
			sounds[i] = nil
		end

		r.ns.OpenWagers()

		assert.is_true(r.ns.board.book.motion.turn.forward)
		assert.are.same({ "836 SFX" }, { unpack(sounds) }) -- IG_ABILITY_PAGE_TURN, the shell's (BOOK-R31)
	end)

	it("keeps its size with the Pagle Wagers ribbon and five set ribbons hanging, all under the board", function()
		-- A fifth set with a current Hunt: Board, Pagle Wagers and five set ribbons run 176 + 7 × 108 - 12 = 920 units
		-- from the board's left, in the shell's one geometry (BOOK-R17): no further than its right edge.
		local r = oneOn({
			list = function(fixture)
				return hunts.withExtra(fixture, { { id = "fixture_more" } }, {
					{
						id = "fixture_more_hunt",
						set = "fixture_more",
						kind = "natural",
						since = hunts.JAN_1,
						species = 13760,
						window = "day",
						tiers = { 1 },
					},
				})
			end,
		})
		local env = r.loaded.env
		env.UIParent:SetSize(1000, 2000)

		r.ns.ToggleBoard()

		assert.are.equal(7, #r.ns.BoardRibbons({ mode = "board" }))
		local last = r.ns.board.frame.ribbons[7]
		assert.are.equal(920, last.points[1][4] + last.width)
		assert.are.equal(1, r.ns.board.frame:GetScale())
	end)

	it("keeps its size on the same screen with the fixture's four set ribbons", function()
		local r = oneOn()
		r.loaded.env.UIParent:SetSize(1000, 2000)

		r.ns.ToggleBoard()

		assert.are.equal(1, r.ns.board.frame:GetScale())
	end)
end)

describe("the spread's words stay on its pages (HNT-R60)", function()
	it("with long names and several tickets", function()
		local long = "The Longest Wager Anyone Has Laid On These Waters Yet"
		local r = oneOn({
			pushed = TWO_ON,
			now = SAT_15 - 10 * HOUR,
			clock = {
				time = SAT_15 - 10 * HOUR,
				minute = 7 * 60,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})
		local L = r.ns.L
		L["event.fixture_shore.name"] = long
		L["event.fixture_vale.name"] = long
		L["ladder.25.title"] = long

		r.ns.OpenWagers()

		local page = r.ns.board:Page(place(r), "left")
		assert.are.same({ 1, 1 }, { #shownWith(page, "ticketRun"), #shownWith(page, "aheadRun") })
		for _, side in ipairs({ "left", "right" }) do
			assert.are.same({}, bounds.overflows(r.ns.board:Page(place(r), side)))
		end
	end)
end)
