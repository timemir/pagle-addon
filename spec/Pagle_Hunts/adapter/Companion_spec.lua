-- The companion hint and its weekly Nod on FakePagle (HNT-R161, HNT-R162, HNT-R170–R172, HNT-R176, HNT-R86, SET-R32,
-- SET-R33, ANN-R12, ANN-R20, PUSH-R15, PUSH-R16): with the hint switch on, as it ships at 1.0, each state's hint under
-- the wager strip, as the dashed hint slip and as the tracker's line with no run on, Get it's box, Dismiss, the
-- Nod at login and the Settings row; turned off, nothing shows anywhere whatever the companion state. The lines' pure
-- parts are in spec/Pagle_Hunts/logic/Companion_spec.lua.
--
-- Each companion state comes from ticket #293's fake.setPushedContent, set before login: its check ends on the frame
-- after login, when PushedContentReady fires; with none set, as with no Pagle_Content, it ends "missing" at login
-- itself. The rotation's starting point is put far ahead, so no fallback run is logged or ahead (HNT-R204): the run on,
-- when a spec wants one, is fixture_shore ("Shore Wager"), logged in the Catch log from a day before now to two days on.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local bounds = dofile("spec/support/bounds.lua")

local DAY = 86400
local NOW = SERVER_TIME
local SHORE_START, SHORE_END = NOW - DAY, NOW + 2 * DAY

local MISSING = {
	"New wagers are out there. The Pagle companion brings them: more XP, more Coins, and the Sonar Scope toast style.",
	"Installed it just now? Log out to character select once.",
}
local NOT_RUNNING = { "The Pagle companion isn't running. Start it to get this week's wagers." }
local SETTING = "Remind me about the Pagle companion"
local TOOLTIP = "A line on the Hunts board, and a Nod once a week, while the Pagle companion isn't bringing you new "
	.. "wagers."
local URL = "https://pagle.app/download"

-- The saved PagleHuntsDB with `profile` as its one profile's fields.
local function saved(profile)
	return { profileKeys = { ["Angler - Testrealm"] = "Default" }, profiles = { Default = profile } }
end

--- Hunts logged in at NOW, the companion state from `options.state` (nil: none set, so "missing" at login), the hint
--- switch as it ships (on) or turned off with `options.off`, fixture_shore on with `options.runOn`, `options.saved` as
--- PagleHuntsDB; then the frame where the pushed content's check ends and the run log's step runs.
---@param options { state: string?, off: boolean?, runOn: boolean?, saved: table? }?
---@return HuntsRun
local function start(options)
	options = options or {}
	local r = hunts.start({
		names = true,
		saved = options.saved,
		prepare = function(loaded)
			loaded.ns.ROTATION_ORIGIN = NOW + 365 * DAY
			if options.off then
				loaded.ns.COMPANION_HINT_ON = false
			end
		end,
		history = function(fake)
			if options.runOn then
				local payload = hunts.runPayload("fixture_shore", SHORE_START, SHORE_END)
				hunts.append(fake, { hunts.record("run", payload, SHORE_START) })
			end
		end,
		beforeLogin = function(r)
			if options.state then
				r.fake.setPushedContent({ state = options.state, items = {} })
			end
		end,
	})
	r.fake.nextFrame()
	r.loaded.client.runTimers()
	r.fake.nextFrame()
	return r
end

--- The board's place now.
local function place(r)
	return r.ns.board.router:Place()
end

--- The shown widgets under `widget` that carry `field`.
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

--- The hint's shown buttons on a page, by role: { getIt = …, dismiss = … }.
local function hintButtons(page)
	local out = {}
	for _, button in ipairs(shownWith(page, "hintRole")) do
		out[button.hintRole] = button
	end
	return out
end

--- Whether `texts` holds every one of `lines`, and whether it holds any.
local function holdsAll(texts, lines)
	for _, line in ipairs(lines) do
		if not hunts.has(texts, line) then
			return false
		end
	end
	return true
end
local function holdsAny(texts, lines)
	for _, line in ipairs(lines) do
		if hunts.has(texts, line) then
			return true
		end
	end
	return false
end

--- The Board's left page, the board opened on the Board ribbon.
local function boardPage(r)
	r.ns.OpenBoard()
	return r.ns.board:Page(place(r), "left")
end

--- The Pagle Wagers spread's left page, the board opened on it.
local function spreadPage(r)
	r.ns.OpenWagers()
	return r.ns.board:Page(place(r), "left")
end

--- The tracker's companion hint line as the player reads it, "{line} · {why}", or nil when it doesn't show.
local function trackerHint(r)
	local wagers = r.ns.tracker.wagers
	if not (wagers.header:IsShown() and wagers.hint:IsShown()) then
		return nil
	end
	return wagers.hint.text:GetText() .. " · " .. wagers.hint.why.text:GetText()
end

--- The labels on the Announcements page, in order.
local function announcementLabels(r)
	local labels = {}
	for _, row in ipairs(r.fake.settingsPage("announcements") or {}) do
		labels[#labels + 1] = row.label
	end
	return labels
end

--- The Announcements page's row labelled `label`, or nil.
local function announcementRow(r, label)
	for _, row in ipairs(r.fake.settingsPage("announcements") or {}) do
		if row.label == label then
			return row
		end
	end
	return nil
end

--- The companion Nods Core was handed (fake.announcements).
local function nods(r)
	local out = {}
	for _, announcement in ipairs(r.fake.announcements) do
		if announcement.headline.kind == "companionHint" then
			out[#out + 1] = announcement
		end
	end
	return out
end

local STATES = { "missing", "notRunning", "connected", "checking" }

it("ships with the hint switch on at 1.0 (HNT-R172)", function()
	local r = start({ runOn = true })

	assert.is_true(r.ns.COMPANION_HINT_ON)
end)

describe("with the hint switch turned off (HNT-R172)", function()
	for _, state in ipairs(STATES) do
		describe(("and the companion %s"):format(state), function()
			it("shows no hint under the wager strip, no Get it or Dismiss", function()
				local r = start({ off = true, state = state, runOn = true })

				local page = boardPage(r)

				assert.is_true(hunts.has(shownTexts(page), "Shore Wager")) -- the strip itself shows
				assert.is_false(holdsAny(shownTexts(page), MISSING) or holdsAny(shownTexts(page), NOT_RUNNING))
				assert.are.same({}, hintButtons(page))
			end)

			it("shows no hint slip on the Pagle Wagers spread", function()
				local r = start({ off = true, state = state, runOn = true })

				local page = spreadPage(r)

				assert.is_false(holdsAny(shownTexts(page), MISSING) or holdsAny(shownTexts(page), NOT_RUNNING))
				assert.are.same({}, hintButtons(page))
				assert.is_nil(r.ns.BoardWagersSpread().hint)
			end)

			it("shows no tracker line with no run on: no Pagle Wagers block at all", function()
				local r = start({ off = true, state = state })

				assert.is_nil(trackerHint(r))
				assert.is_false(r.ns.tracker.wagers.header:IsShown())
			end)

			it("raises no Nod at login, and stores none", function()
				local r = start({ off = true, state = state })
				r.fake.nextFrame()

				assert.are.same({}, nods(r))
				assert.are.equal(0, r.ns.db.profile.lastHintNod)
			end)

			it("adds no Settings row: Announcements ends at the window moments' row", function()
				local r = start({ off = true, state = state })

				assert.is_nil(announcementRow(r, SETTING))
				local labels = announcementLabels(r)
				assert.are.equal("Tell me when a pinned Hunt's window opens", labels[#labels])
			end)
		end)
	end
end)

describe("with the hint switch on (HNT-R170)", function()
	describe("and the companion missing", function()
		it("shows both lines under the wager strip, with Get it and Dismiss (HNT-R161)", function()
			local r = start({ state = "missing", runOn = true })

			local page = boardPage(r)

			assert.is_true(holdsAll(shownTexts(page), MISSING))
			local buttons = hintButtons(page)
			assert.are.equal("Get it", buttons.getIt.label:GetText())
			assert.are.equal("Dismiss", buttons.dismiss.label:GetText())
		end)

		it("pushes the ruler down by the hint's lines (HNT-R161)", function()
			local off = start({ off = true, state = "missing", runOn = true })
			local on = start({ state = "missing", runOn = true })
			local function shift(r)
				local page = boardPage(r)
				return r.ns.DrawWagerStrip(page, r.ns.BuildWagerStrip(r.ns.BoardWagersInput()))
			end

			assert.are.equal(off.ns.WAGER_STRIP_ROOM, shift(off))
			assert.is_true(shift(on) >= on.ns.WAGER_STRIP_ROOM + 2 * 14)
		end)

		it("shows both lines as a dashed hint slip on the spread, with Get it and Dismiss (HNT-R162)", function()
			local r = start({ state = "missing", runOn = true })

			local page = spreadPage(r)

			assert.are.same(MISSING, r.ns.BoardWagersSpread().hint)
			assert.is_true(holdsAll(shownTexts(page), MISSING))
			local buttons = hintButtons(page)
			assert.is_not_nil(buttons.getIt)
			assert.is_not_nil(buttons.dismiss)
			assert.is_true(page.spread.hint:IsShown())
			assert.is_true(#page.spread.hintOutline.dashes > 0) -- dashed
		end)

		it("shows the hint slip with no run on too, over the empty box (HNT-R162, HNT-R204)", function()
			local r = start({ state = "missing" })

			local texts = shownTexts(spreadPage(r))

			assert.is_true(
				hunts.has(
					texts,
					"No wagers on the table, and none posted ahead. The rotation puts one on at the next turn."
				)
			)
			assert.is_true(holdsAll(texts, MISSING))
		end)

		it(
			'reads "New wagers with the Pagle companion" on the tracker with no run on, with "why?" (HNT-R176)',
			function()
				local r = start({ state = "missing" })

				assert.are.equal("New wagers with the Pagle companion · why?", trackerHint(r))
				assert.are.equal("Pagle Wagers", r.ns.tracker.wagers.title:GetText())
				for _, line in ipairs(r.ns.tracker.wagers.lines) do
					assert.is_false(line:IsShown())
				end
			end
		)

		it('opens the Pagle Wagers spread from the tracker\'s "why?" (HNT-R176)', function()
			local r = start({ state = "missing" })

			r.ns.tracker.wagers.hint.why:Click()

			assert.is_true(r.ns.board:IsShown())
			assert.are.same({ mode = "wagers" }, place(r))
		end)

		it("shows the runs, not the hint line, on the tracker while a run is on (HNT-R175, HNT-R176)", function()
			local r = start({ state = "missing", runOn = true })

			assert.is_nil(trackerHint(r))
			assert.is_true(r.ns.tracker.wagers.lines[1]:IsShown())
		end)

		it("folds the tracker's hint line away with the block's header (HNT-R177)", function()
			local r = start({ state = "missing" })

			r.ns.tracker.wagers.header:Click()

			assert.is_true(r.ns.tracker.wagers.header:IsShown())
			assert.is_false(r.ns.tracker.wagers.hint:IsShown())
			r.ns.tracker.wagers.header:Click()
			assert.are.equal("New wagers with the Pagle companion · why?", trackerHint(r))
		end)
	end)

	describe("and the companion not running", function()
		it("shows its own line on the strip and the hint slip, with Get it and Dismiss", function()
			local r = start({ state = "notRunning", runOn = true })

			local board = boardPage(r)
			assert.is_true(holdsAll(shownTexts(board), NOT_RUNNING))
			assert.is_false(holdsAny(shownTexts(board), MISSING))
			assert.is_not_nil(hintButtons(board).getIt)

			local spread = spreadPage(r)
			assert.are.same(NOT_RUNNING, r.ns.BoardWagersSpread().hint)
			assert.is_true(holdsAll(shownTexts(spread), NOT_RUNNING))
			assert.is_not_nil(hintButtons(spread).dismiss)
		end)

		it('reads "Pagle companion not running" on the tracker with no run on (HNT-R176)', function()
			local r = start({ state = "notRunning" })

			assert.are.equal("Pagle companion not running · why?", trackerHint(r))
		end)
	end)

	for _, state in ipairs({ "connected", "checking" }) do
		it(("shows nothing while the companion is %s"):format(state), function()
			local r = start({ state = state, runOn = true })

			local board = boardPage(r)
			assert.are.same({}, hintButtons(board))
			assert.is_false(holdsAny(shownTexts(board), MISSING) or holdsAny(shownTexts(board), NOT_RUNNING))
			spreadPage(r)
			assert.is_nil(r.ns.BoardWagersSpread().hint)
			local quiet = start({ state = state })
			assert.is_nil(trackerHint(quiet))
			assert.is_false(quiet.ns.tracker.wagers.header:IsShown())
		end)
	end

	it('shows nothing while "checking", then the hint once PushedContentReady fires (PUSH-R16)', function()
		local r = hunts.start({
			names = true,
			prepare = function(loaded)
				loaded.ns.ROTATION_ORIGIN = NOW + 365 * DAY
			end,
			beforeLogin = function(run)
				run.fake.setPushedContent({ state = "notRunning", items = {} })
			end,
		})
		assert.is_nil(trackerHint(r))

		r.fake.nextFrame() -- the check ends: PushedContentReady("notRunning")

		assert.are.equal("Pagle companion not running · why?", trackerHint(r))
	end)
end)

describe("the hint's words stay on the board's pages (HNT-R60)", function()
	it("under the strip and on the hint slip, with Get it and Dismiss, and in Get it's box", function()
		local r = start({ state = "missing", runOn = true })

		local board = boardPage(r)
		assert.are.same({}, bounds.overflows(board))
		hintButtons(board).getIt:Click()
		assert.are.same({}, bounds.overflows(r.ns.CompanionAddressBox()))
		assert.are.same({}, bounds.overflows(spreadPage(r)))
	end)
end)

describe("Get it (HNT-R170)", function()
	it("shows the companion's address selected in a copyable box, focused for Ctrl+C (REP-R40)", function()
		local r = start({ state = "missing", runOn = true })

		hintButtons(boardPage(r)).getIt:Click()

		local box = r.ns.CompanionAddressBox()
		assert.is_true(box:IsShown())
		assert.are.equal(URL, r.ns.COMPANION_URL)
		assert.are.equal(URL, box.address:GetText())
		assert.are.same({ 0, -1 }, box.address.highlight)
		assert.are.equal(box.address, r.loaded.client.focus)
		assert.is_true(hunts.has(shownTexts(box), "Ctrl+C to copy"))
	end)

	it("puts the address back, selected, whatever is typed in it", function()
		local r = start({ state = "missing", runOn = true })
		hintButtons(spreadPage(r)).getIt:Click()
		local box = r.ns.CompanionAddressBox()

		box.address:Type("oops")

		assert.are.equal(URL, box.address:GetText())
		assert.are.same({ 0, -1 }, box.address.highlight)
	end)

	it("closes with Esc in the box, and with Close", function()
		local r = start({ state = "notRunning", runOn = true })
		hintButtons(boardPage(r)).getIt:Click()
		local box = r.ns.CompanionAddressBox()

		box.address.scripts.OnEscapePressed(box.address)
		assert.is_false(box:IsShown())
		assert.is_nil(r.loaded.client.focus)

		hintButtons(boardPage(r)).getIt:Click()
		box.close:Click()
		assert.is_false(box:IsShown())
	end)
end)

describe("Dismiss (HNT-R170)", function()
	it("hides the hint on the strip, the hint slip and the tracker, and saves it", function()
		local r = start({ state = "missing", runOn = true })
		local page = boardPage(r)

		hintButtons(page).dismiss:Click()

		assert.is_false(r.ns.db.profile.companionHint)
		assert.is_false(holdsAny(shownTexts(page), MISSING))
		assert.are.same({}, hintButtons(page))
		local spread = spreadPage(r)
		assert.is_false(holdsAny(shownTexts(spread), MISSING))
		assert.are.same({}, hintButtons(spread))
	end)

	it("takes the tracker's line away with no run on", function()
		local r = start({ state = "missing" })
		hintButtons(spreadPage(r)).dismiss:Click()

		assert.is_nil(trackerHint(r))
		assert.is_false(r.ns.tracker.wagers.header:IsShown())
	end)

	it("stops the Nod at the next login", function()
		local r = start({ state = "missing", saved = saved({ companionHint = false }) })

		assert.are.same({}, nods(r))
		assert.are.equal(0, r.ns.db.profile.lastHintNod)
	end)

	it("is undone by the Settings row: the hint shows again everywhere (SET-R32)", function()
		local r = start({ state = "missing", runOn = true })
		local page = boardPage(r)
		hintButtons(page).dismiss:Click()

		announcementRow(r, SETTING).setting.set(true)

		assert.is_true(r.ns.db.profile.companionHint)
		assert.is_true(holdsAll(shownTexts(page), MISSING))
		assert.is_not_nil(hintButtons(page).getIt)
	end)

	it("is undone for the Nod too: turned back on, the next login raises it again", function()
		local r = start({ state = "missing", saved = saved({ companionHint = false }) })
		announcementRow(r, SETTING).setting.set(true)
		local again = start({ state = "missing", saved = saved({ companionHint = true }) })

		assert.are.equal(1, #nods(again))
	end)
end)

describe("the weekly Nod (HNT-R171, HNT-R86)", function()
	it("is raised once at login, after PushedContentReady, as HNT-R86's companionHint nod", function()
		local r = start({ state = "missing" })

		local raised = nods(r)
		assert.are.equal(1, #raised)
		local nod = raised[1].headline
		assert.are.same(
			{ "nod", "companionHint", "Pagle Wagers", MISSING[1], MISSING[1], "Interface\\Icons\\Trade_Fishing" },
			{ nod.rung, nod.kind, nod.title, nod.text, nod.pastText, nod.icon }
		)
		assert.is_nil(nod.cast) -- an Announcement of its own (ANN-R12)
		assert.are.equal(0, raised[1].coins)
		assert.are.equal(NOW, r.ns.db.profile.lastHintNod)
		r.fake.nextFrame()
		r.loaded.client.runTimers()
		assert.are.equal(1, #nods(r)) -- once a login
	end)

	it("waits for the first PLAYER_ENTERING_WORLD when PushedContentReady comes first", function()
		local r = hunts.start({ -- no Pagle_Content: "missing" at login itself, before the world
			names = true,
			prepare = function(loaded)
				loaded.ns.ROTATION_ORIGIN = NOW + 365 * DAY
			end,
			world = false,
		})
		r.fake.nextFrame()
		assert.are.same({}, nods(r))

		r.fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
		r.fake.nextFrame()

		assert.are.equal(1, #nods(r))
		assert.are.equal(MISSING[1], nods(r)[1].headline.text)
	end)

	it("waits for PushedContentReady when the world comes first", function()
		local r = hunts.start({
			names = true,
			prepare = function(loaded)
				loaded.ns.ROTATION_ORIGIN = NOW + 365 * DAY
			end,
			beforeLogin = function(run)
				run.fake.setPushedContent({ state = "notRunning", items = {} })
			end,
		})
		r.loaded.client.runTimers()
		assert.are.same({}, nods(r))

		r.fake.nextFrame() -- PushedContentReady("notRunning")
		r.fake.nextFrame() -- Core flushes a moment of its own on the next frame (ANN-R12)

		assert.are.equal(1, #nods(r))
		assert.are.equal(NOT_RUNNING[1], nods(r)[1].headline.text)
	end)

	it("is not raised again within 7 days, and is at 7 days (Tunables)", function()
		local within = start({ state = "missing", saved = saved({ lastHintNod = NOW - 7 * DAY + 60 }) })
		local after = start({ state = "missing", saved = saved({ lastHintNod = NOW - 7 * DAY }) })

		assert.are.same({}, nods(within))
		assert.are.equal(NOW - 7 * DAY + 60, within.ns.db.profile.lastHintNod)
		assert.are.equal(1, #nods(after))
		assert.are.equal(NOW, after.ns.db.profile.lastHintNod)
	end)

	it("is not raised while the companion is connected or the check never ends", function()
		for _, state in ipairs({ "connected", "checking" }) do
			local r = start({ state = state })
			r.fake.nextFrame()

			assert.are.same({}, nods(r))
			assert.are.equal(0, r.ns.db.profile.lastHintNod)
		end
	end)

	it("opens the board on the Pagle Wagers spread when clicked", function()
		local r = start({ state = "notRunning" })

		nods(r)[1].headline.onClick()

		assert.is_true(r.ns.board:IsShown())
		assert.are.same({ mode = "wagers" }, place(r))
	end)
end)

describe('the Settings row "Remind me about the Pagle companion" (SET-R32, SET-R33)', function()
	it("sits on Announcements under Hunts' header, after the window moments' row, on by default", function()
		local r = start({ state = "missing" })

		local rows = r.fake.settingsPage("announcements")
		local labels = announcementLabels(r)
		assert.are.same(
			{ "Hunts", "Tell me when a pinned Hunt's window opens", SETTING },
			{ labels[#labels - 2], labels[#labels - 1], labels[#labels] }
		)
		assert.are.equal("header", rows[#rows - 2].kind)
		local row = rows[#rows]
		assert.are.same({ "checkbox", TOOLTIP, true }, { row.kind, row.setting.tooltip, row.setting.default })
		assert.is_true(row.setting.get())
		assert.is_nil(row.setting.isEnabled) -- not greyed in Cozy mode (SET-R32)
	end)

	it("reads and writes profile.companionHint (hunts.md › Data)", function()
		local r = start({ state = "missing" })
		local row = assert(announcementRow(r, SETTING))

		row.setting.set(false)
		assert.is_false(r.ns.db.profile.companionHint)
		assert.is_false(row.setting.get())
		assert.is_nil(trackerHint(r))

		row.setting.set(true)
		assert.is_true(r.ns.db.profile.companionHint)
		assert.are.equal("New wagers with the Pagle companion · why?", trackerHint(r))
	end)
end)
