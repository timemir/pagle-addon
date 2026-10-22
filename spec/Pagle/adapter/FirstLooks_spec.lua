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

-- Lays out every region made from now on where the Curio Shop's case would sit on a 1920 x 1080 screen, so the
-- shop's targets count as on screen (ONB-R56: one not laid out drops its note).
local function layOutFromNow(loaded)
	local create = loaded.env.CreateFrame
	local function lay(region)
		return layOut(region, 470, 220, 980, 640)
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
