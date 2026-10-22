-- The Stats book's motion and sounds (stats.md › UI › Motion and sound; the books art kit v2's MOTION.md and
-- SOUND.md): its moves on Core's one driver (Pagle.Animate), the open and close fades and their sounds and the page
-- turn between spreads with its crumbs, ribbons and sound (Core's shell's, BOOK-R4, BOOK-R31, read on the Stats book;
-- the shell keeps each page's side as its views["page:side:1"]), the fit to a small screen, and the readings moving when a Cast
-- changes the entry shown: the ink fading up, the "me" mark sliding, the ruler fading at a catch with its "write" sound, the
-- live line and its breathing dot. Core's Animations setting (Pagle.IsAnimationsOn) is on here; with it off, all of it
-- draws settled at once. The fake client runs the driver's OnUpdate with client.update.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, SMALLFISH, BLACKMOUTH = I.DARKSHORE, I.AUBERDINE, I.SMALLFISH, I.BLACKMOUTH

-- The page's width (the book's 980 less its two 18-unit sides, halved).
local PAGE_WIDTH = (980 - 2 * 18) / 2

-- Stats logged in over `records` with Core's Animations setting `motion` (on by default), the player in Darkshore's
-- Auberdine at skill 200 (side hi, as the worked history's Casts).
local function ready(records, motion)
	local loaded, fake, book = stats.start({
		records = records,
		motion = motion ~= false,
		at = { zone = DARKSHORE, subzone = AUBERDINE, skillRank = 200, skillMod = 0 },
	})
	return loaded, fake, book --[[@as table]] -- the fake client's frames, read by the fields it keeps
end

-- What the breadcrumbs read now.
local function crumbsOf(book)
	local out = {}
	for _, crumb in ipairs(book.frame.crumbButtons) do
		if crumb.shown then
			out[#out + 1] = crumb.label.text
		end
	end
	return out
end

-- A page view's clip: shown, and its visible strip's left edge and width across the paper.
local function strip(view)
	local clip = view.clip
	local point = clip.points[1]
	return { clip.shown, point and point[4] or 0, clip:GetWidth() }
end

-- Runs `seconds` of frames, a tenth of a second at a time.
local function run(loaded, seconds)
	local steps = math.floor(seconds / 0.05 + 0.5)
	for _ = 1, steps do
		loaded.client.update(0.05)
	end
end

describe("the book's motion seam (ns.MotionOn, on Core's Pagle.Animate)", function()
	it("reads Core's Animations setting each time, never a copy of its own", function()
		local loaded, fake = stats.load(nil, { motion = true })
		local ns = loaded.ns

		local on = ns.MotionOn()
		stats.animations(fake, false)
		local off = ns.MotionOn()
		stats.animations(fake, true)

		assert.are.same({ true, false, true }, { on, off, ns.MotionOn() })
		assert.is_nil(rawget(ns, "Animate"))
		assert.is_nil(rawget(ns, "motion"))
	end)
end)

describe("the Stats book opening and closing", function()
	it("fades in over 0.16 s with the spellbook's open sound, on the SFX channel", function()
		local loaded, _, book = ready()

		loaded.ns.ToggleBook()
		assert.are.same({ "829 SFX" }, loaded.client.sounds)
		assert.are.equal(0, book.frame:GetAlpha())
		run(loaded, 0.2)

		assert.are.equal(1, book.frame:GetAlpha())
	end)

	it("fades out over 0.12 s from its close button, then hides with the close sound, once", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		run(loaded, 0.2)

		book.frame.close:Click()
		assert.is_true(book.frame.shown) -- still fading
		run(loaded, 0.15)

		assert.is_false(book.frame.shown)
		assert.are.equal(1, book.frame:GetAlpha())
		assert.are.same({ "829 SFX", "830 SFX" }, loaded.client.sounds)
	end)

	it("hides at once with the motion off, its sounds still playing", function()
		local loaded, _, book = ready(nil, false)

		loaded.ns.ToggleBook()
		assert.are.equal(1, book.frame:GetAlpha())
		book.frame.close:Click()

		assert.is_false(book.frame.shown)
		assert.are.same({ "829 SFX", "830 SFX" }, loaded.client.sounds)
	end)

	it("shrinks to fit a small screen, never grows, and re-fits when the UI scale changes", function()
		local loaded, _, book = ready()
		local screen = loaded.env.UIParent
		screen:SetSize(1188, 668) -- a 1366 × 768 screen at UI scale 1.15

		loaded.ns.ToggleBook()
		-- the book with its close button and its ribbons: 1010 × 740 units, in 668 less 24 above and below
		assert.is_true(math.abs(book.frame:GetScale() - (668 - 48) / 740) < 1e-9)
		screen:SetSize(2560, 1440)
		loaded.client.fireGameEvent("UI_SCALE_CHANGED")

		assert.are.equal(1, book.frame:GetScale())
	end)
end)

describe("the Stats book's page turn", function()
	it(
		"turns forward to a later ribbon: the right page lifts, then it lands on the left, the crumbs at the spine",
		function()
			local loaded, _, book = ready(stats.darkshore())
			loaded.ns.ToggleBook()
			run(loaded, 0.2)
			local home = { left = book.shell.views["home:left:1"], right = book.shell.views["home:right:1"] }

			book.frame.ribbons[3]:Click() -- Lifetime
			local life = { left = book.shell.views["lifetime:left:1"], right = book.shell.views["lifetime:right:1"] }
			assert.are.equal("836 SFX", loaded.client.sounds[#loaded.client.sounds])
			assert.are.same({ "Stats" }, crumbsOf(book))
			run(loaded, 0.1)
			-- the old right page narrows from its outer edge, the new one shows beside it; the left page is still home's
			local old, new = strip(home.right), strip(life.right)
			assert.is_true(old[1] and new[1])
			assert.is_true(old[3] < PAGE_WIDTH and new[3] > 0)
			assert.is_true(math.abs(old[3] + new[3] - PAGE_WIDTH) < 1e-6)
			assert.are.same({ true, 0, PAGE_WIDTH }, strip(home.left))
			assert.is_false(life.left.clip.shown)
			assert.is_true(book.frame.turnFold.shown)
			run(loaded, 0.15)
			assert.are.same({ "Stats", "Lifetime" }, crumbsOf(book))
			run(loaded, 0.3)

			assert.are.same({ true, 0, PAGE_WIDTH }, strip(life.left))
			assert.are.same({ true, 0, PAGE_WIDTH }, strip(life.right))
			assert.is_false(home.left.clip.shown)
			assert.is_false(home.right.clip.shown)
			assert.is_false(book.frame.turnFold.shown)
		end
	)

	it("turns backward to an earlier ribbon or home: the left page lifts first", function()
		local loaded, _, book = ready(stats.darkshore())
		loaded.ns.OpenBook({ page = "lifetime" })
		run(loaded, 0.2)

		loaded.ns.OpenBook({ page = "home" })
		run(loaded, 0.1)
		local home = { left = book.shell.views["home:left:1"], right = book.shell.views["home:right:1"] }

		local new = strip(home.left)
		assert.is_true(new[1] and new[2] == 0 and new[3] > 0 and new[3] < PAGE_WIDTH)
		assert.is_false(home.right.clip.shown)
		run(loaded, 0.5)
		assert.are.same({ true, 0, PAGE_WIDTH }, strip(home.right))
	end)

	it("runs the ribbons' lengths with the turn: the old one draws up as the new one drops", function()
		local loaded, _, book = ready(stats.darkshore())
		loaded.ns.OpenBook({ page = "lifetime" })
		run(loaded, 0.2)
		local ribbons, sizes = book.frame.ribbons, { length = 75, lengthChosen = 86 } -- Core's (BOOK-R17)
		assert.are.same({ sizes.length, sizes.lengthChosen }, { ribbons[4].height, ribbons[3].height })

		ribbons[4]:Click()
		run(loaded, 0.1)
		assert.is_true(ribbons[4].height > sizes.length and ribbons[4].height < sizes.lengthChosen)
		assert.is_true(ribbons[3].height < sizes.lengthChosen and ribbons[3].height > sizes.length)
		run(loaded, 0.2)

		assert.are.same({ sizes.lengthChosen, sizes.length }, { ribbons[4].height, ribbons[3].height })
	end)

	it("settles a turn still running when the next one starts, and when the book closes", function()
		local loaded, _, book = ready(stats.darkshore())
		loaded.ns.ToggleBook()
		book.frame.ribbons[3]:Click()
		run(loaded, 0.1)

		book.frame.ribbons[4]:Click()
		run(loaded, 0.6)
		for key, view in pairs(book.shell.views) do
			assert.are.equal(key:find("^sessions:") ~= nil, view.clip.shown, key)
		end
		book.frame.ribbons[2]:Click()
		run(loaded, 0.1)
		book.frame:Hide()

		for key, view in pairs(book.shell.views) do
			assert.are.equal(key:find("^session:") ~= nil, view.clip.shown, key)
		end
	end)

	it("turns at once, silently, with the motion off", function()
		local loaded, _, book = ready(stats.darkshore(), false)
		loaded.ns.ToggleBook()

		book.frame.ribbons[3]:Click()

		assert.are.same({ "829 SFX" }, loaded.client.sounds)
		assert.are.same({ "Stats", "Lifetime" }, crumbsOf(book))
		assert.are.same({ true, 0, PAGE_WIDTH }, strip(book.shell.views["lifetime:left:1"]))
		assert.is_false(book.shell.views["home:left:1"].clip.shown)
		assert.are.equal(86, book.frame.ribbons[3].height) -- the chosen length (BOOK-R17)
	end)
end)

describe("the Stats book's readings moving (the kit's MOTION.md)", function()
	-- The book open on Darkshore with Smallfish chosen: known and unlucky (stats.darkshore), its ruler showing.
	local function onSmallfish()
		local loaded, fake, book = ready(stats.darkshore())
		loaded.ns.OpenBook({ page = "place", area = DARKSHORE, item = SMALLFISH })
		run(loaded, 0.2)
		local view
		for _, child in ipairs(book.shell.views["place:right:1"].content.children) do
			view = view or (child.shown and child.entryView)
		end
		return loaded, fake, book, assert(view)
	end

	it("slides the me mark to the new reading over 0.6 s after a Cast, the rewritten lines fading up", function()
		local loaded, fake, _, view = onSmallfish()
		local before = view.ruler.position
		assert.is_true(view.ruler.shown)

		stats.fish(fake, 1)
		loaded.client.runTimers()
		assert.are.equal(before, view.ruler.position) -- it starts where it was
		assert.is_true(view.dryFirst:GetAlpha() < 0.5) -- 145 since becomes 146 since: rewritten
		run(loaded, 0.7)

		local reading = loaded.ns.Reading(loaded.ns.State(), SMALLFISH, DARKSHORE, 200)
		local P = loaded.ns.DrySpell(reading).P
		assert.is_true(math.abs(view.ruler.position - loaded.ns.RulerPosition(P)) < 1e-9)
		assert.is_true(view.ruler.position > before) -- a longer wait sits further right
		assert.are.equal(1, view.dryFirst:GetAlpha())
	end)

	it("fades the ruler out at a catch, writing it in with the write sound, and back with the next Cast", function()
		local loaded, fake, _, view = onSmallfish()

		stats.fish(fake, 1, SMALLFISH)
		loaded.client.runTimers()
		assert.are.equal("3093 SFX", loaded.client.sounds[#loaded.client.sounds])
		run(loaded, 0.1)
		assert.is_true(view.ruler.shown and view.ruler:GetAlpha() < 1)
		run(loaded, 0.3)
		assert.is_false(view.ruler.shown)

		stats.fish(fake, 1)
		loaded.client.runTimers()
		assert.is_true(view.ruler.shown)
		assert.is_true(view.ruler:GetAlpha() < 0.5)
		run(loaded, 0.4)

		assert.are.equal(1, view.ruler:GetAlpha())
	end)

	it("draws settled on reopening after a catch while it was closed: no write sound, no ink fading up", function()
		local loaded, fake, book, view = onSmallfish()
		stats.fish(fake, 1) -- a Session is live, its line drawn
		loaded.client.runTimers()
		run(loaded, 0.7)
		book:Hide()
		run(loaded, 0.2)
		assert.is_false(book.frame.shown)

		stats.fish(fake, 1, SMALLFISH)
		loaded.client.runTimers()
		local heard = #loaded.client.sounds
		loaded.ns.OpenBook({ page = "place", area = DARKSHORE, item = SMALLFISH })
		loaded.client.runTimers()

		for i = heard + 1, #loaded.client.sounds do
			assert.are_not.equal("3093 SFX", loaded.client.sounds[i])
		end
		assert.are.equal(1, view.dryFirst:GetAlpha())
		assert.are.equal(1, view.ruler:GetAlpha())
		assert.are.equal(1, book.frame.live.label:GetAlpha())
	end)

	it("fades a row's rewritten Dry spell up after a Cast", function()
		local loaded, fake, book = onSmallfish()
		local margin
		local function find(widget)
			for _, child in ipairs(widget.children) do
				if child.isBookRow and child.shown and child.name.text == "Raw Brilliant Smallfish" then
					margin = child.margin
				end
				find(child)
			end
		end
		find(book.shell.views["place:left:1"].content)

		stats.fish(fake, 1)
		loaded.client.runTimers()

		assert.are.equal("146 since", margin.text)
		assert.is_true(margin:GetAlpha() < 0.5)
	end)

	it("fades the live line up at each Cast, its dot breathing between 35% and 80%", function()
		local loaded, fake, book = ready()
		loaded.ns.ToggleBook()
		stats.fish(fake, 1, BLACKMOUTH)
		loaded.client.runTimers()
		local live = book.frame.live
		run(loaded, 0.6)
		assert.are.equal(1, live.label:GetAlpha())

		stats.fish(fake, 1)
		loaded.client.runTimers()
		assert.is_true(live.label:GetAlpha() < 0.5)
		local low, high = 1, 0
		for _ = 1, 60 do
			loaded.client.update(0.05)
			low, high = math.min(low, live.glow:GetAlpha()), math.max(high, live.glow:GetAlpha())
		end

		assert.is_true(low < 0.4 and high > 0.75)
	end)
end)
