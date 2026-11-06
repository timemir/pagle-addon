-- First looks on the client, through the real TOC and the fake client (core/onboarding.md › First looks, › UI,
-- › Motion): the Curio Shop's set and its "?" (ONB-R55, ONB-R57, ONB-R59), the coach bar (ONB-R55), a Module's set
-- through M:RegisterFirstLook and M:ShowFirstLook (ONB-R56, ONB-R90), its notes beside the window (ONB-R58), the tour
-- stop (ONB-R84) and `/pagle dev onboarding look` (ONB-R83).

local NOTE_IN = "827 SFX"

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- PagleDB.global.onboarding as the client holds it.
local function state(loaded)
	return loaded.env.PagleDB.global.onboarding
end

-- Puts `region` on the fake screen at `left`, `bottom`, `width` x `height` (the fake lays nothing out itself).
local function layOut(region, left, bottom, width, height)
	region.screenLeft, region.screenBottom = left, bottom
	region.screenRight, region.screenTop = left + width, bottom + height
	return region
end

-- Where the client lays out a region hung by its top from another's foot (the coach bar under its window, ONB-R55):
-- centred under that foot, its anchor's offsets added, and kept inside the screen's foot, as SetClampedToScreen keeps
-- the bar. Nil for a region hung otherwise, or from one not laid out.
---@return { left: number, right: number, bottom: number, top: number }?
local function hungRect(region)
	local anchor = region.points[1]
	local above = anchor and anchor[1] == "TOP" and anchor[3] == "BOTTOM" and anchor[2]
	if not (type(above) == "table" and above.screenBottom) then
		return nil
	end
	local width, height = region:GetWidth(), region:GetHeight()
	local middle = (above.screenLeft + above.screenRight) / 2 + (anchor[4] or 0)
	local top = math.max(height, above.screenBottom + (anchor[5] or 0))
	return { left = middle - width / 2, right = middle + width / 2, top = top, bottom = top - height }
end

-- Lays out every region made from now on where the Curio Shop's case would sit on a 1920 x 1080 screen, so the
-- shop's targets count as on screen (ONB-R56: one not laid out drops its note); one hung under another's foot where
-- the client puts it (hungRect).
local function layOutFromNow(loaded)
	local create = loaded.env.CreateFrame
	local function lay(region)
		layOut(region, 470, 220, 980, 640)
		for method, edge in pairs({ GetLeft = "left", GetRight = "right", GetTop = "top", GetBottom = "bottom" }) do
			local laid = region[method]
			region[method] = function(self)
				local hung = hungRect(self)
				if hung then
					return hung[edge]
				end
				return laid(self)
			end
		end
		return region
	end
	loaded.env.CreateFrame = function(...)
		local frame = lay(create(...))
		for _, method in ipairs({ "CreateFontString", "CreateTexture" }) do
			local make = frame[method]
			frame[method] = function(self, ...)
				return lay(make(self, ...))
			end
		end
		return frame
	end
end

-- Core logged in on Forever for an Angler who answered the Letter, Animations off so each note settles at once, every
-- region made from now on laid out. `register` runs before login, with Pagle.
local function core(register)
	local loaded = loadCore({ BUILD_ENTRY })
	loaded.ns.db.global.onboarding.letter = "declined"
	layOutFromNow(loaded)
	local handles = register and register(loaded.env.Pagle, loaded) or nil
	enterWorld(loaded, 3)
	loaded.ns.db.profile.announcements.motion = false
	return loaded, handles
end

-- The notes on screen, by number: each as "n. text".
local function onScreen(loaded)
	local read = {}
	for _, frame in ipairs(loaded.ns.lookNoteFrames) do
		if frame.entry and frame.shown then
			read[#read + 1] = { frame.entry.n, frame.number:GetText() .. ". " .. frame.text:GetText() }
		end
	end
	table.sort(read, function(a, b)
		return a[1] < b[1]
	end)
	for i, note in ipairs(read) do
		read[i] = note[2]
	end
	return read
end

-- The note frame numbered `n` on screen.
local function noteFrame(loaded, n)
	for _, frame in ipairs(loaded.ns.lookNoteFrames) do
		if frame.entry and frame.shown and frame.entry.n == n then
			return frame
		end
	end
	error("no note " .. n)
end

-- The coach bar's three parts as they read, or nil while it's hidden.
local function bar(loaded)
	local coach = loaded.ns.coachBar
	if not (coach and coach.shown) then
		return nil
	end
	return { coach.title:GetText(), coach.count:GetText(), coach.doneLabel:GetText() }
end

-- How many times noteIn played.
local function noteIns(loaded)
	local n = 0
	for _, sound in ipairs(loaded.client.sounds) do
		if sound == NOTE_IN then
			n = n + 1
		end
	end
	return n
end

local SHOP_NOTES = {
	"1. Coins come only from things you’ve done. The bar shows what paid them.",
	"2. Everything here is a |cff9a2a1alook|r: toasts, sounds, bindings, crests. Nothing makes you fish better.",
	"3. |cff9a2a1aShow on screen|r plays it for real before you buy.",
	"4. The stock |cff9a2a1anever rotates|r. What’s here today is here next month.",
}
local SHOP_BAR = { "First look · the Curio Shop", "4 notes, shown once", "Got it, put the notes away" }

describe("the Curio Shop's First look (ONB-R55, ONB-R57)", function()
	it("shows its 4 notes and the coach bar the first time it opens, playing noteIn once, marking looksSeen", function()
		local loaded = core()

		pagle(loaded, "shop")

		assert.are.same(SHOP_NOTES, onScreen(loaded))
		assert.are.same(SHOP_BAR, bar(loaded))
		assert.are.equal(1, noteIns(loaded))
		assert.is_true(state(loaded).looksSeen["core.shop"])
	end)

	it("points at the purse's Coins, a good's medallion, the showcase card and the description card", function()
		local loaded = core()

		pagle(loaded, "shop")

		local frame = loaded.ns.shopFrame
		local targets = {}
		for n = 1, 4 do
			targets[n] = noteFrame(loaded, n).arrow.to()
		end
		assert.are.equal(frame.purse.label, targets[1])
		assert.are.equal(frame.lines[2].bezel, targets[2])
		assert.are.equal(frame.stage.area, targets[3])
		assert.are.equal(frame.stage.info, targets[4])
	end)

	it("sits in the margins beside the case, the bar under it (ONB-R55, ONB-R58)", function()
		local loaded = core()

		pagle(loaded, "shop")

		local frame = loaded.ns.shopFrame
		assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -214, -120 }, noteFrame(loaded, 1).points[1])
		assert.are.same({ "TOPLEFT", frame, "TOPLEFT", -214, -360 }, noteFrame(loaded, 2).points[1])
		assert.are.same({ "TOPLEFT", frame, "TOPRIGHT", 12, -270 }, noteFrame(loaded, 3).points[1])
		assert.are.same({ "TOPLEFT", frame, "TOPRIGHT", 12, -450 }, noteFrame(loaded, 4).points[1])
		assert.are.equal(200, noteFrame(loaded, 1).width)
		assert.are.same({ "TOP", frame, "BOTTOM", 0, -8 }, loaded.ns.coachBar.points[1])
	end)

	it("goes as the shop closes, and doesn't show again as it opens again (ONB-R55)", function()
		local loaded = core()
		pagle(loaded, "shop")

		loaded.ns.shopFrame.CloseButton:Click()
		assert.are.same({}, onScreen(loaded))
		assert.is_nil(bar(loaded))

		pagle(loaded, "shop")
		assert.are.same({}, onScreen(loaded))
		assert.is_nil(bar(loaded))
		assert.are.equal(1, noteIns(loaded))
	end)

	it("goes with the coach bar's link, and with Esc closing the shop (ONB-R55)", function()
		local loaded = core()
		pagle(loaded, "shop")

		loaded.ns.coachBar.done:Click()
		assert.are.same({}, onScreen(loaded))
		assert.is_nil(bar(loaded))
		assert.is_true(loaded.ns.shopFrame.shown)

		loaded.ns.firstLooks:Show("core.shop", true)
		loaded.ns.shopFrame:Hide()
		assert.are.same({}, onScreen(loaded))
	end)

	it("never shows with Margin notes off", function()
		local loaded = core()
		state(loaded).notesOn = false

		pagle(loaded, "shop")

		assert.are.same({}, onScreen(loaded))
		assert.is_nil(state(loaded).looksSeen["core.shop"])
	end)
end)

describe('the Curio Shop\'s "?" (ONB-R59)', function()
	it("sits left of the brass close in the shop's brass, its tooltip in the shop's voice", function()
		local loaded = core()
		state(loaded).notesOn = false
		pagle(loaded, "shop")
		local frame = loaded.ns.shopFrame
		local help = frame.HelpButton

		assert.are.same({ "RIGHT", frame.CloseButton, "LEFT", -6, 0 }, help.points[1])
		assert.are.equal("?", help.label:GetText())
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\shop\\Shop", help.bezel.Ring.texture)
		help.scripts.OnEnter(help)
		assert.is_true(frame.purse.tip.shown)
		assert.are.equal("Show the notes for this page again", frame.purse.tip.head:GetText())
		help.scripts.OnLeave(help)
		assert.is_false(frame.purse.tip.shown)
	end)

	it("shows the set again, seen and with Margin notes off, and hides it on a second press", function()
		local loaded = core()
		pagle(loaded, "shop")
		loaded.ns.shopFrame.CloseButton:Click()
		state(loaded).notesOn = false
		pagle(loaded, "shop")

		loaded.ns.shopFrame.HelpButton:Click()
		assert.are.same(SHOP_NOTES, onScreen(loaded))
		assert.are.same(SHOP_BAR, bar(loaded))
		assert.are.equal(2, noteIns(loaded))

		loaded.ns.shopFrame.HelpButton:Click()
		assert.are.same({}, onScreen(loaded))
		assert.is_nil(bar(loaded))
	end)
end)

describe("a Module's First look (ONB-R56, ONB-R58, ONB-R90)", function()
	-- The Ledger with a window laid out at 600, 200 (900 x 700) and a set of three notes on three targets in it, the
	-- first two in the left margin, the third in the right. Returns the client load and { M, window, targets }.
	---@return table loaded
	---@return { M: table, window: table, targets: table[] } ledgerOf
	local function ledger()
		local loaded, ledgerOf = core(function(Pagle, loaded)
			local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local window = layOut(loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent), 600, 200, 900, 700)
			window:SetSize(900, 700)
			window:Hide()
			local targets = {}
			local notes = {}
			for i = 1, 3 do
				targets[i] = layOut(loaded.env.CreateFrame("Frame", nil, window), 650 + 100 * i, 500, 40, 40)
				notes[i] = {
					text = "Note " .. i .. ", with a *term*.",
					target = function()
						return targets[i]
					end,
					x = i < 3 and -190 or 916,
					y = 100 * i,
					w = 176,
				}
			end
			M:RegisterFirstLook({ id = "ledger.journal", window = window, title = "the Fish Journal", notes = notes })
			window:SetScript("OnShow", function()
				M:ShowFirstLook("ledger.journal")
			end)
			return { M = M, window = window, targets = targets }
		end)
		return loaded, assert(ledgerOf)
	end

	it("shows from its window's OnShow, a hidden target's note dropped and the rest numbered 1 to n", function()
		local loaded, ledgerOf = ledger()
		ledgerOf.targets[2]:Hide()

		ledgerOf.window:Show()

		assert.are.same(
			{ "1. Note 1, with a |cff9a2a1aterm|r.", "2. Note 3, with a |cff9a2a1aterm|r." },
			onScreen(loaded)
		)
		assert.are.same(
			{ "First look · the Fish Journal", "2 notes, shown once", "Got it, put the notes away" },
			bar(loaded)
		)
	end)

	it("drops a note as its target hides, renumbering the rest at once", function()
		local loaded, ledgerOf = ledger()
		ledgerOf.window:Show()

		ledgerOf.targets[1]:Hide()
		loaded.client.update(0)

		assert.are.same(
			{ "1. Note 2, with a |cff9a2a1aterm|r.", "2. Note 3, with a |cff9a2a1aterm|r." },
			onScreen(loaded)
		)
		assert.are.equal("2 notes, shown once", bar(loaded)[2])
		ledgerOf.targets[2]:Hide()
		loaded.client.update(0)
		assert.are.equal("1 note, shown once", bar(loaded)[2])
	end)

	it("places its notes again as the window moves, overlapping its edge with less than 210 free (ONB-R58)", function()
		local loaded, ledgerOf = ledger()
		local window = ledgerOf.window
		window:Show()
		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -190, -100 }, noteFrame(loaded, 1).points[1])

		layOut(window, 100, 200, 900, 700)
		loaded.client.update(0)

		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -92, -100 }, noteFrame(loaded, 1).points[1])
		assert.are.same({ "TOPLEFT", window, "TOPRIGHT", 16, -300 }, noteFrame(loaded, 3).points[1])
	end)

	it("redraws an arrow at once as its target moves, without motion (ONB-R56)", function()
		local loaded, ledgerOf = ledger()
		ledgerOf.window:Show()
		local note = layOut(noteFrame(loaded, 1), 400, 700, 176, 60)
		loaded.client.update(0)
		local before = noteFrame(loaded, 1).arrow.lines[14].endPoint

		layOut(ledgerOf.targets[1], 900, 300, 40, 40)
		loaded.client.update(0)

		local after = note.arrow.lines[14].endPoint
		assert.are_not.same(before, after)
		assert.is_true(after[3] >= 900 and after[3] <= 940 and after[4] >= 300 and after[4] <= 340)
		assert.are.equal(1, note.alpha)
	end)

	-- The Ledger with a window laid out at `left`, 200 (900 x 700) and a set of `places` ({ x, y } each, 176 wide),
	-- each note on its own 40 x 40 target, in the window's middle or at the place's third and fourth values; `dress` lays out what the window carries (its close,
	-- its "?", its ribbons) before it shows. Returns the client load and the window.
	local function lookAt(left, places, dress)
		local loaded, window = core(function(Pagle, loaded)
			local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local window = layOut(loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent), left, 200, 900, 700)
			window:SetSize(900, 700)
			window:Hide()
			local notes = {}
			for i, at in ipairs(places) do
				local targetLeft, targetBottom = at[3] or left + 400 + 10 * i, at[4] or 500
				local target = layOut(loaded.env.CreateFrame("Frame", nil, window), targetLeft, targetBottom, 40, 40)
				notes[i] = {
					text = "Note " .. i .. ".",
					target = function()
						return target
					end,
					x = at[1],
					y = at[2],
					w = 176,
				}
			end
			if dress then
				dress(loaded, window)
			end
			M:RegisterFirstLook({ id = "ledger.journal", window = window, title = "the Fish Journal", notes = notes })
			window:SetScript("OnShow", function()
				M:ShowFirstLook("ledger.journal")
			end)
			return window
		end)
		return loaded, assert(window)
	end

	it("stacks a note under the one above it when their words would overlap, never over it (ONB-R58)", function()
		-- each note is 35 tall at the fake's one line: the second, 10 under the first's top, starts 8 under its foot
		-- with its badge, which reaches 12 above its paper
		local loaded, window = lookAt(600, { { -190, 100 }, { -190, 110 }, { -190, 300 } })

		window:Show()

		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -190, -100 }, noteFrame(loaded, 1).points[1])
		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -190, -155 }, noteFrame(loaded, 2).points[1])
		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -190, -300 }, noteFrame(loaded, 3).points[1])
	end)

	it('slides a note held over the window\'s edge off its close and its "?" (ONB-R58, BOOK-R15)', function()
		-- 120 free on the right: the note overlaps the edge, from 1736, where the close and the "?" sit at the top
		local loaded, window = lookAt(900, { { 916, 0 } }, function(loaded, window)
			window.close = layOut(loaded.env.CreateFrame("Button", nil, window), 1785, 885, 30, 30)
			window.help = layOut(loaded.env.CreateFrame("Button", nil, window), 1750, 880, 30, 30)
		end)

		window:Show()

		-- under the "?", the lower of the two, 8 clear of its foot at 880 with its badge, 12 above its paper
		assert.are.same({ "TOPLEFT", window, "TOPRIGHT", -64, -40 }, noteFrame(loaded, 1).points[1])
	end)

	it(
		"slides a note whose badge would sit on the window's close off it, once the close is laid out (ONB-R58)",
		function()
			-- 420 free on the right: the note sits 16 past the edge, its paper clear of the close (centred 3 in from the
			-- window's corner at 1500, 900, as the shell's wax close), its badge reaching 12 left of and above the paper
			local close
			local loaded, window = lookAt(600, { { 916, 0 } }, function(loaded, window)
				close = loaded.env.CreateFrame("Button", nil, window)
				close.screenLeft = nil -- not laid out yet as the set first shows
			end)

			window:Show()
			assert.are.same({ "TOPLEFT", window, "TOPRIGHT", 16, 0 }, noteFrame(loaded, 1).points[1])
			window.close = layOut(close, 1481, 881, 32, 32)
			-- where the note is, its badge (1504 to 1530 across, 874 to 900 up) is on the close
			assert.is_true(1516 - 12 < 1513 and 900 + 12 > 881)

			loaded.client.update(0)

			-- under the close, 8 clear of its foot at 881 with its badge: its paper's top 12 lower
			assert.are.same(
				{ "TOPLEFT", window, "TOPRIGHT", 16, -(900 - (881 - 8 - 12)) },
				noteFrame(loaded, 1).points[1]
			)
		end
	)

	it("rings a word it points at beside the word, not on its letters (ONB-R56)", function()
		local label
		local loaded = core(function(Pagle, loaded)
			local M = Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
			local window = layOut(loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent), 600, 200, 900, 700)
			window:Hide()
			label = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			label:SetText("PAGLE-MÜNZEN")
			layOut(label, 1500, 500, #"PAGLE-MÜNZEN" * 6, 14)
			M:RegisterFirstLook({
				id = "ledger.journal",
				window = window,
				title = "the Fish Journal",
				notes = {
					{
						text = "Coins.",
						target = function()
							return label
						end,
						x = -190,
						y = 100,
						w = 176,
					},
				},
			})
			window:SetScript("OnShow", function()
				M:ShowFirstLook("ledger.journal")
			end)
			return window
		end)
		loaded.ns.firstLooks:Window("ledger.journal"):Show()
		loaded.client.update(0)

		local arrow = noteFrame(loaded, 1).arrow
		local finish = arrow.lines[14].endPoint
		-- the note is left of the word: its arrow ends left of the word's first letter, the 12-unit ring 2 clear of it
		assert.is_true(finish[3] + 6 <= 1500 - 2)
		assert.is_true(finish[4] >= 500 - 8 and finish[4] <= 514 + 8)
		assert.are.same({ "CENTER", loaded.env.UIParent, "BOTTOMLEFT", finish[3], finish[4] }, arrow.ring.points[1])
	end)

	it("slides a note held over the window's edge off what another note points at (ONB-R56, ONB-R58)", function()
		-- 100 free on the left: both notes overlap the edge from 8 to 184, and the second's target sits by the first,
		-- 800 down to 765 on screen: it slides up off it, the shorter way, 8 clear of its top at 800
		local loaded, window = lookAt(100, { { -190, 100 }, { -190, 400, 150, 760 } })

		window:Show()

		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -92, -57 }, noteFrame(loaded, 1).points[1])
		assert.are.same({ "TOPLEFT", window, "TOPLEFT", -92, -400 }, noteFrame(loaded, 2).points[1])
	end)

	it(
		"slides a note set over the window off what the window keeps clear, leaving margin notes be (ONB-R58)",
		function()
			-- the first note over the window, 700 to 876 across and 800 down to 765; the second in the left margin
			local loaded, window = lookAt(600, { { 100, 100 }, { -190, 100 } }, function(loaded, window)
				local paper = layOut(loaded.env.CreateFrame("Frame", nil, window), 690, 740, 100, 70)
				local margin = layOut(loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent), 400, 740, 100, 70)
				window.lookKeepClear = function()
					return { paper, margin }
				end
			end)

			window:Show()

			-- up over the paper (to 8 above its top at 810) is shorter than down under it
			assert.are.same({ "TOPLEFT", window, "TOPLEFT", 100, -47 }, noteFrame(loaded, 1).points[1])
			assert.are.same({ "TOPLEFT", window, "TOPLEFT", -190, -100 }, noteFrame(loaded, 2).points[1])
		end
	)

	it(
		"slides a note off the coach bar where the client draws it, clamped above the screen's foot (ONB-R55, ONB-R58)",
		function()
			-- the window's foot 10 above the screen's: the bar's anchor would put it from 2 down past the screen, so the
			-- client keeps it from 0 to its 40 units' top. The note over the window, its foot at 44, would sit 4 above it:
			-- it slides up 4, to 8 clear of the bar's top
			local loaded, window = lookAt(600, { { 300, 631 } }, function(_, window)
				layOut(window, 600, 10, 900, 700)
			end)

			window:Show()

			local coach = loaded.ns.coachBar
			assert.are.same({ 0, 40 }, { coach:GetBottom(), coach:GetTop() })
			assert.are.same({ "TOPLEFT", window, "TOPLEFT", 300, -627 }, noteFrame(loaded, 1).points[1])
		end
	)

	it("hangs the coach bar under a book's ribbons, not over them (ONB-R55, BOOK-R17)", function()
		local loaded, window = lookAt(600, { { -190, 100 } }, function(loaded, window)
			window.ribbons = {
				layOut(loaded.env.CreateFrame("Button", nil, window), 700, 176, 40, 60),
				layOut(loaded.env.CreateFrame("Button", nil, window), 800, 170, 40, 60),
			}
		end)

		window:Show()

		-- the lower ribbon ends 30 under the window's foot at 200
		assert.are.same({ "TOP", window, "BOTTOM", 0, -38 }, loaded.ns.coachBar.points[1])
	end)

	it("raises an error at the Module's call for a set with a missing field, adding nothing (ONB-R90)", function()
		local loaded = core(function(Pagle)
			return Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		end)
		local M = loaded.ns.Modules:Modules()[1].handle

		local ok, err = pcall(function()
			M:RegisterFirstLook({ id = "ledger.journal", window = loaded.env.UIParent, title = "the Fish Journal" })
		end)

		assert.is_false(ok)
		assert.matches(
			"FirstLooks_spec%.lua:%d+: RegisterFirstLook: set ledger%.journal needs its notes",
			tostring(err)
		)
		assert.are.equal(1, #loaded.ns.firstLooks:List())
	end)
end)

describe("the First looks' tour stops (ONB-R84, CORE-R68)", function()
	it("open the Curio Shop and show its set, marking nothing, and close it again", function()
		local loaded = core()
		local stop
		for _, each in ipairs(loaded.ns.tourStops:List({}, "core")) do
			if each.name == "core.onboarding.look.core.shop" then
				stop = each
			end
		end

		stop.show()
		assert.is_true(loaded.ns.shopFrame.shown)
		assert.are.same(SHOP_NOTES, onScreen(loaded))
		stop.hide()

		assert.is_false(loaded.ns.shopFrame.shown)
		assert.are.same({}, onScreen(loaded))
		assert.is_nil(state(loaded).looksSeen["core.shop"])
	end)
end)

describe("/pagle dev onboarding look (ONB-R83)", function()
	it("shows a set whose window is open, seen or not, and names why not otherwise", function()
		local loaded = core()
		state(loaded).notesOn = false
		pagle(loaded, "dev on")

		pagle(loaded, "dev onboarding look core.shop")
		pagle(loaded, "dev onboarding look ledger.journal")
		pagle(loaded, "shop")
		pagle(loaded, "dev onboarding look core.shop")

		assert.are.same({
			"Pagle dev: dev commands are on.",
			"Pagle dev: First look core.shop's window isn't open; open it first.",
			"Pagle dev: no First look ledger.journal; the sets are core.shop.",
		}, loaded.printed)
		assert.are.same(SHOP_NOTES, onScreen(loaded))
		assert.is_nil(state(loaded).looksSeen["core.shop"])
	end)
end)
