-- The Pagle Wagers ribbon and spread (HNT-R60, HNT-R61, HNT-R69, HNT-R143, HNT-R148, HNT-R160, HNT-R162, HNT-R164,
-- HNT-R165, HNT-R204): the ribbon hanging second with "{n} on", its spread's wager slips and ladder on the left and the
-- chosen run's entry on the right, the breadcrumbs through "Pagle Wagers", and the nameplate's ladder titles, as data
-- (ns.BoardRibbons, ns.BoardWagersSpread) and as drawn, on FakePagle over the fixture Hunt list and catalogue, a fixed
-- clock and live conditions.
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

--- The shown wager slip of run `runKey` on the spread's left page.
local function slipOf(r, runKey)
	for _, slip in ipairs(shownWith(r.ns.board:Page(place(r), "left"), "slipRun")) do
		if slip.slipRun == runKey then
			return slip
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
	it('shows "On the table" with one slip, its countdown, its first marks and the ladder at 0 of 25', function()
		local r = oneOn()
		r.ns.ToggleBoard()

		r.ns.BoardWagersRibbon():Click()

		local texts = pageTexts(r, "left")
		for _, text in ipairs({
			"PAGLE WAGERS",
			"On the table",
			"Three days each. Land every Hunt's first mark before it closes.",
			"Shore Wager",
			"Darkshore · until Sat 17:00",
			"closes in 2d 4h",
			"1 of 3 first marks",
			"25",
			"50",
			"100",
			"Bookmaker's Bane",
			"0 wagers settled · 25 more for Bookmaker's Bane",
		}) do
			assert(has(texts, text), "the spread's left page lacks " .. text)
		end
		-- The slip's pips, as the strip's: the Haul at 1 of 2, the Snapper's first mark, the oddity none.
		local pips = shownWith(slipOf(r, SHORE), "pip")
		assert.are.same({ false, true, false }, { pips[1].inked, pips[2].inked, pips[3].inked })
		assert.is_true(slipOf(r, SHORE).selected)
	end)

	it("shows the first slip's run's entry on the right page, with the crumbs stopping at Pagle Wagers", function()
		local r = oneOn()

		r.ns.OpenWagers()

		assert.are.same({ mode = "wagers" }, place(r))
		local texts = pageTexts(r, "right")
		assert.is_true(has(texts, "FROM THE ROTATION · LOW WATERS"))
		assert.is_true(has(texts, "Shore Wager"))
		assert.is_true(has(texts, "So far +150 XP · 15 Coins"))
		assert.are.same({ "Hunts", "Pagle Wagers" }, crumbWords(r))
	end)

	it("opens on the strip's run from the wager strip (HNT-R161)", function()
		local r = oneOn()
		r.ns.ToggleBoard()

		shownWith(r.ns.board:Page(place(r), "left"), "stripRun")[1]:Click()

		assert.are.same({ mode = "wagers", run = SHORE }, place(r))
		assert.is_true(has(pageTexts(r, "left"), "On the table"))
	end)

	it("chooses a slip when clicked: its entry on the right, the crumbs through its event (HNT-R164)", function()
		local r = oneOn({ pushed = TWO_ON })
		r.ns.OpenWagers()
		-- on, by end: the pushed vale closes first (HNT-R160)
		assert.is_true(slipOf(r, VALE_PUSHED).selected)

		slipOf(r, SHORE):Click()

		assert.are.same({ mode = "wagers", run = SHORE }, place(r))
		assert.is_true(slipOf(r, SHORE).selected)
		assert.is_false(slipOf(r, VALE_PUSHED).selected)
		assert.is_true(has(pageTexts(r, "right"), "Shore Wager"))
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, crumbWords(r))
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, shownTexts(r.ns.board.frame.crumbs))
	end)

	it('goes back to the slips from the "Pagle Wagers" crumb, and to the Board from "Hunts"', function()
		local r = oneOn({ pushed = TWO_ON })
		r.ns.OpenWagers(SHORE)

		crumbButton(r, "Pagle Wagers"):Click()

		assert.are.same({ mode = "wagers" }, place(r))
		assert.are.same({ "Hunts", "Pagle Wagers" }, crumbWords(r))
		assert.is_true(slipOf(r, VALE_PUSHED).selected)

		crumbButton(r, "Hunts"):Click()
		assert.are.equal("board", place(r).mode)
	end)

	it('turns to the spread on the run from the Board\'s "Pagle Wagers" crumb (HNT-R164)', function()
		local r = oneOn()
		r.ns.OpenBoard({ run = SHORE })
		assert.are.same({ "Hunts", "Pagle Wagers", "Shore Wager" }, crumbWords(r))

		crumbButton(r, "Pagle Wagers"):Click()

		assert.are.same({ mode = "wagers", run = SHORE }, place(r))
		assert.is_true(slipOf(r, SHORE).selected)
	end)

	it("gives a run ahead its slip, opening in place of a countdown", function()
		-- Ten hours before SAT_15: the shore is on, and slot 1's fixture_vale is ahead.
		local r = oneOn({
			now = SAT_15 - 10 * HOUR,
			clock = {
				time = SAT_15 - 10 * HOUR,
				minute = 7 * 60,
				date = { year = 2026, month = 10, day = 17, weekday = 7 },
			},
		})

		r.ns.OpenWagers()

		local texts = shownTexts(slipOf(r, "fixture_vale@" .. SAT_15))
		assert.is_true(has(texts, "fixture_vale"))
		assert.is_true(has(texts, "opens Sat 17:00"))
		assert.is_true(has(texts, "0 of 3 first marks"))
	end)

	it('stamps a completed run\'s slip "settled", and the ladder reads 1 of 25 (HNT-R146, HNT-R148)', function()
		-- A Deviate Fish on Wednesday evening, realm 18:30: the oddity's hours, and the Haul's second fish.
		local history = onHistory()
		history[#history + 1] = castAt(O + 3 * HOUR + 30 * 60, C.DARKSHORE, { C.DEVIATE })
		history[#history].conditions.minute = 18 * 60 + 30
		local r = oneOn({ history = history })

		r.ns.OpenWagers()

		local slip = slipOf(r, SHORE)
		assert.is_true(has(shownTexts(slip), "SETTLED"))
		assert.is_false(has(shownTexts(slip), "closes in 2d 4h"))
		assert.is_true(has(pageTexts(r, "left"), "1 wager settled · 24 more for Bookmaker's Bane"))
		assert.is_true(has(pageTexts(r, "right"), "Settled 14 Oct"))
	end)

	it('reads "No wagers on the table yet." before the rotation starts, the ladder at its foot (HNT-R204)', function()
		local r = start({ now = SERVER_TIME, clock = hunts.SUNDAY })

		r.ns.OpenWagers()

		local texts = pageTexts(r, "left")
		assert.is_true(has(texts, "No wagers on the table yet."))
		assert.is_true(has(texts, "0 wagers settled · 25 more for Bookmaker's Bane"))
		assert.are.same({}, shownWith(r.ns.board:Page(place(r), "left"), "slipRun"))
		assert.are.same({}, pageTexts(r, "right"))
	end)

	it("reads the updating line for its marks and ladder while the projection updates (HNT-R69)", function()
		local r = oneOn()
		serve(r, r.ns.State(), true)

		r.ns.OpenWagers()

		local texts = pageTexts(r, "left")
		assert.is_true(has(texts, "Shore Wager"))
		assert.is_false(has(texts, "1 of 3 first marks"))
		assert.is_true(has(texts, UPDATING))
		assert.are.same({}, shownWith(slipOf(r, SHORE), "pip"))
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

	it("stays on the spread, greyed and closed, until the board closes; then nothing of it shows", function()
		local r = nearEnd()
		r.ns.OpenWagers()
		assert.is_true(slipOf(r, SHORE).selected)

		hunts.wait(r, 11 * 60)

		local slip = slipOf(r, SHORE)
		assert.is_true(slip.closed)
		assert.is_false(slip.selected)
		assert.is_true(has(shownTexts(slip), "closed"))
		assert.is_true(has(shownTexts(slip), "Shore Wager"))
		-- The next slot's run is on, and the right page shows it in the closed one's place.
		assert.is_true(slipOf(r, "fixture_vale@" .. SAT_15).selected)
		assert.is_false(has(pageTexts(r, "right"), "Shore Wager"))

		r.ns.board:Hide()
		r.ns.OpenWagers()

		assert.is_nil(slipOf(r, SHORE))
		assert.is_false(has(pageTexts(r, "left"), "Shore Wager"))
	end)

	it("closes on the spread though the board showed the Board ribbon as it ended", function()
		local r = nearEnd()
		r.ns.ToggleBoard()

		hunts.wait(r, 11 * 60)
		r.ns.OpenWagers()

		assert.is_true(slipOf(r, SHORE).closed)
	end)

	it("doesn't take a click: a closed slip is never chosen", function()
		local r = nearEnd()
		r.ns.OpenWagers()
		hunts.wait(r, 11 * 60)

		slipOf(r, SHORE):Click()

		assert.are.same({ mode = "wagers" }, place(r))
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
		assert.is_true(has(pageTexts(r, "left"), "25 wagers settled · 25 more for " .. ruin))
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
	it("with long names and several slips", function()
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

		assert.is_true(#shownWith(r.ns.board:Page(place(r), "left"), "slipRun") >= 2)
		for _, side in ipairs({ "left", "right" }) do
			assert.are.same({}, bounds.overflows(r.ns.board:Page(place(r), side)))
		end
	end)
end)
