-- The board's motion and sounds (hunts.md › UI, HNT-R60, HNT-R62, HNT-R70; the books art kit v2's MOTION.md and
-- SOUND.md): adapter/Motion.lua's driver run by the fake client's frames, the book fading in and out with its sounds,
-- the page turn between spreads with the ribbons' lengths easing, the live timeline's rows sliding and a Hunt just
-- opened flashing with its sound, the cover's dip, the ink running on, fitting the screen, and the realm-minute
-- refresh; and Core's Animations setting, off, drawing everything settled and silencing the motion's beats.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- Two imposed Hunts of set fixture_extra: extra_1 open 10:00–11:00 realm, extra_2 08:00–12:00 (Now from the start).
local LIST = {
	{ class = "fixed.oddity", conditions = { time = { { 600, 660 } } } },
	{ class = "fixed.oddity", conditions = { time = { { 480, 720 } } } },
}

--- Hunts logged in and grouped with Core's Animations setting on (or `motion` as given), its server time on the
--- client's clock from `from` seconds after realm 08:15.
---@param options { motion: boolean?, from: integer?, list: any }?
---@return HuntsRun
local function start(options)
	options = options or {}
	local motion = options.motion
	if motion == nil then
		motion = true
	end
	return hunts.start({
		motion = motion,
		from = options.from,
		names = true,
		list = options.list
			and hunts.extraList(options.list, { ["fixed.oddity"] = { [6522] = true, [251524] = true } }),
	})
end

-- Runs the client's frames for `seconds`, 60 a second: the timers come due and the motion driver plays.
---@param run HuntsRun
---@param seconds number
local function play(run, seconds)
	for _ = 1, math.floor(seconds * 60 + 0.5) do
		run.loaded.client.nextFrame(1 / 60)
	end
end

-- The sounds played since the last call, as "<sound kit id> <channel>".
---@param run HuntsRun
---@return string[]
local function heard(run)
	local sounds = run.loaded.client.sounds
	local out = { unpack(sounds) }
	for i = #sounds, 1, -1 do
		sounds[i] = nil
	end
	return out
end

-- The shown row of Hunt `huntID` on the Board's left page.
---@param run HuntsRun
---@param huntID string
local function rowOf(run, huntID)
	local found
	local function walk(widget)
		for _, child in ipairs(widget.children) do
			if child.huntID == huntID and child.shown then
				found = child
			end
			walk(child)
		end
	end
	walk(run.ns.board:Page({ mode = "board" }, "left"))
	return found
end

local function near(expected, actual, slack)
	assert.are.equal(
		true,
		math.abs(expected - actual) <= (slack or 0.02),
		("%s, not about %s"):format(actual, expected)
	)
end

describe("the board opening and closing", function()
	it("opens with the book's sound, fading in over 0.16 s", function()
		local run = start()
		local frame

		run.ns.ToggleBoard()
		frame = run.ns.board.frame
		assert.are.same({ "829 SFX" }, heard(run))
		assert.are.equal(0, frame:GetAlpha())
		play(run, 0.2)

		assert.are.equal(1, frame:GetAlpha())
	end)

	it("closes with the book's sound, fading out over 0.12 s before it hides, and counts as closed at once", function()
		local run = start()
		run.ns.ToggleBoard()
		play(run, 0.2)
		heard(run)
		local frame = run.ns.board.frame

		frame.close:Click()
		assert.are.same({ "830 SFX" }, heard(run))
		assert.is_false(run.ns.board:IsShown())
		assert.is_true(frame:IsShown())
		play(run, 0.15)

		assert.is_false(frame:IsShown())
		assert.are.equal(1, frame:GetAlpha())
	end)

	it("plays the closing sound once when Esc hides it", function()
		local run = start()
		run.ns.ToggleBoard()
		heard(run)

		run.loaded.client.pressEscape()

		assert.are.same({ "830 SFX" }, heard(run))
	end)

	it("opens and closes at once with Animations off, its sounds still playing", function()
		local run = start({ motion = false })

		run.ns.ToggleBoard()
		assert.are.equal(1, run.ns.board.frame:GetAlpha())
		run.ns.ToggleBoard()

		assert.is_false(run.ns.board.frame:IsShown())
		assert.are.same({ "829 SFX", "830 SFX" }, heard(run))
	end)
end)

describe("the page turn (MOTION.md › Turning to another spread)", function()
	it(
		"turns forward to a set's page in half a second, the right page lifting first, the crumbs changing halfway",
		function()
			local run = start()
			local board = run.ns.board
			run.ns.ToggleBoard()
			play(run, 0.2)
			heard(run)
			local crumbs = board.frame.anchors.crumbs.crumbs
			local before = crumbs[2].label:GetText()
			local set = { mode = "set", set = "fixture_dusk" }

			board:Open(set)
			assert.are.same({ "836 SFX" }, heard(run))
			play(run, 0.1)
			-- lifting: the old right page narrows from its outer edge, the new one shows beside it; the old left page stays
			assert.is_true(board:Page({ mode = "board" }, "right").clip:IsShown())
			assert.is_true(board:Page(set, "right").clip:IsShown())
			assert.is_false(board:Page(set, "left").clip:IsShown())
			assert.is_true(board:Page({ mode = "board" }, "left").clip:IsShown())
			assert.is_true(board.frame.fold:IsShown())
			assert.are.equal(before, crumbs[2].label:GetText())
			play(run, 0.45)

			assert.is_false(board:Page({ mode = "board" }, "right").clip:IsShown())
			assert.is_false(board:Page({ mode = "board" }, "left").clip:IsShown())
			assert.are.equal(board.frame.paperFrames.left:GetWidth(), board:Page(set, "left").clip:GetWidth())
			assert.is_false(board.frame.fold:IsShown())
			assert.are.equal("Dusk", crumbs[2].label:GetText())
		end
	)

	it("turns back to the Board the other way: the left page lifts first", function()
		local run = start()
		local board = run.ns.board
		local set = { mode = "set", set = "fixture_dusk" }
		run.ns.ToggleBoard()
		board:Open(set)
		play(run, 0.6)

		board:Open({ mode = "board" })
		play(run, 0.1)

		assert.is_true(board:Page({ mode = "board" }, "left").clip:IsShown())
		assert.is_false(board:Page({ mode = "board" }, "right").clip:IsShown())
		assert.is_true(board:Page(set, "right").clip:IsShown())
	end)

	it("eases the chosen ribbon longer and the old one shorter over 0.2 s", function()
		local run = start()
		local board = run.ns.board
		local sizes = run.ns.BOARD_RIBBON
		run.ns.ToggleBoard()
		play(run, 0.2)
		local ribbons = board.frame.anchors.ribbons.ribbons
		assert.are.same({ sizes.lengthChosen, sizes.length }, { ribbons[1].height, ribbons[2].height })

		board:Open({ mode = "set", set = "fixture_dusk" })
		assert.are.same({ sizes.lengthChosen, sizes.length }, { ribbons[1].height, ribbons[2].height })
		play(run, 0.25)

		assert.are.same({ sizes.length, sizes.lengthChosen }, { ribbons[1].height, ribbons[2].height })
	end)

	it("turns at once and silently with Animations off", function()
		local run = start({ motion = false })
		local board = run.ns.board
		local set = { mode = "set", set = "fixture_dusk" }
		run.ns.ToggleBoard()
		heard(run)

		board:Open(set)

		assert.are.same({}, heard(run))
		assert.is_false(board:Page({ mode = "board" }, "right").clip:IsShown())
		assert.is_true(board:Page(set, "right").clip:IsShown())
		assert.are.same(
			{ run.ns.BOARD_RIBBON.length, run.ns.BOARD_RIBBON.lengthChosen },
			{ board.frame.anchors.ribbons.ribbons[1].height, board.frame.anchors.ribbons.ribbons[2].height }
		)
	end)
end)

describe("the live timeline (MOTION.md › The live Hunts timeline)", function()
	it("refreshes on each realm minute while the board shows (HNT-R42)", function()
		local run = start({ from = 30 })
		local regroups = 0
		run.ns.OnRegroup(function()
			regroups = regroups + 1
		end)
		run.ns.tracker.header:Click() -- the tracker collapsed: only the board asks for the refresh

		run.ns.ToggleBoard()
		hunts.wait(run, 29)
		assert.are.equal(0, regroups)
		hunts.wait(run, 1)
		assert.are.equal(1, regroups)
		hunts.wait(run, 60)

		assert.are.equal(2, regroups)
	end)

	it("slides a Hunt that opens up into Now, flashing green under its row, with the board's sound", function()
		local run = start({ from = hunts.untilRealm(9, 58), list = LIST })
		run.ns.ToggleBoard()
		play(run, 0.3)
		heard(run)
		local row = rowOf(run, "extra_1")
		local was = row.y
		assert.are.equal("soon", run.ns.groups:Row("extra_1").group)

		hunts.wait(run, 120) -- realm 10:00: its window opens
		assert.are.equal("now", run.ns.groups:Row("extra_1").group)
		assert.are.same({ "3175 SFX" }, heard(run))
		assert.are.equal(was, row.y) -- it starts from where it was
		assert.are.equal(0, row.flash:GetAlpha())
		play(run, 0.35)
		near(0.22, row.flash:GetAlpha())
		play(run, 1.1)

		assert.are_not.equal(was, row.y)
		assert.are.equal(0, row.flash:GetAlpha())
	end)

	it("moves it into place at once, with the sound but no flash, with Animations off", function()
		local run = start({ motion = false, from = hunts.untilRealm(9, 58), list = LIST })
		run.ns.ToggleBoard()
		local row = rowOf(run, "extra_1")
		local was = row.y
		heard(run)

		hunts.wait(run, 120)

		assert.are.same({ "3175 SFX" }, heard(run))
		assert.are_not.equal(was, row.y)
		assert.are.equal(0, row.flash:GetAlpha())
	end)
end)

describe("the leather's motion", function()
	it("dips the open board's binding while a new cover goes on underneath (HNT-R70)", function()
		local run = start()
		run.ns.ToggleBoard()
		play(run, 0.2)
		heard(run)
		local cover = run.ns.board.frame.cover

		run.fake.setPurchased({ ["hunts.notebookcover.oilcloth"] = true })
		assert.is_true(run.fake.Pagle.SetEquipped("hunts.notebookcover", "hunts.notebookcover.oilcloth"))
		assert.are.same({ "836 SFX" }, heard(run))
		assert.are.equal(run.ns.BOOK_FILES.leather, cover.fill.texture)
		play(run, 0.21)
		near(0.25, cover.fill:GetAlpha(), 0.05)
		assert.are.equal(run.ns.COVER_FILES.oilcloth, cover.fill.texture)
		play(run, 0.25)

		assert.are.equal(1, cover.fill:GetAlpha())
	end)

	it('plays the checkbox\'s sounds as "show completed" is ticked and unticked', function()
		local run = start()
		run.ns.ToggleBoard()
		heard(run)
		local box = run.ns.board.frame.anchors.completed.children[1]

		box:Click()
		box:Click()

		assert.are.same({ "856 SFX", "857 SFX" }, heard(run))
	end)
end)

describe("the ink bar", function()
	it("runs on to a grown count over 0.6 s, its words fading up from 30%", function()
		local run = start()
		local parent = run.loaded.env.CreateFrame("Frame", nil, run.loaded.env.UIParent)
		local bar = run.ns.NewBoardInkBar(parent, 200)
		bar:SetBar(0.25, "1 / 4")

		bar:SetBar(0.5, "2 / 4", true)
		assert.are.equal(50, bar.fill.width)
		near(0.3, bar.label:GetAlpha())
		play(run, 0.3)
		assert.is_true(bar.fill.width > 50 and bar.fill.width < 100)
		play(run, 0.35)

		assert.are.equal(100, bar.fill.width)
		assert.are.equal(1, bar.label:GetAlpha())
	end)
end)

describe("fitting the screen", function()
	it("shrinks the board, ribbons and all, to a short screen, and keeps it centred 40 up", function()
		local run = start()
		local env = run.loaded.env
		env.UIParent:SetSize(1188, 668) -- 1366 × 768 at UI scale 1.15

		run.ns.ToggleBoard()

		local frame = run.ns.board.frame
		-- 600 high, the close button 10 over it, the chosen ribbon hanging 86 under: 696, in 668 less 24 each side
		near((668 - 48) / 696, frame:GetScale(), 0.001)
		assert.are.same({ { "CENTER", env.UIParent, "CENTER", 0, 40 } }, frame.points)
	end)
end)
