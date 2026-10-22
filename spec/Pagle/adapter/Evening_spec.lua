-- The First evening list on the client, through the real TOC and the fake client (core/onboarding.md › The First
-- evening list): docked as Core's own tracker above a fixture Hunts' (ONB-R60, CORE-R70, ONB-R107), its lines on the
-- kit's paper (ONB-R61, ONB-R62), its items ticking on a real Cast, Catch, Session's end and the shop opening, and a
-- fixture Module's call (ONB-R61), the fold after the last (ONB-R62), the close mark (ONB-R63), a returning Angler
-- (ONB-R2), the dev command and the tour stop (ONB-R83, ONB-R84), motion and sounds (› Motion, › Sounds).

local TICK, LIST_DONE = "856 SFX", "878 SFX"

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- Core over a log holding `entries` (the build entry alone: a new Angler), with Animations off unless `moving`, and a
-- fixture Ledger and a fixture Hunts docking a 200 x 40 tracker at order 10, logged in and in the world. Returns the
-- client load, the two handles and Hunts' tracker frame.
local function withList(entries, moving)
	local loaded = loadCore(entries or { BUILD_ENTRY })
	local env = loaded.env
	local ledger = env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	local hunts = env.Pagle.RegisterModule({ name = "Hunts", title = "Hunts", order = 20 })
	local tracker = env.CreateFrame("Frame", nil, env.UIParent)
	tracker:SetSize(200, 40)
	hunts:RegisterTracker({ id = "hunts", order = 10, frame = tracker })
	loaded.ns.db.profile.announcements.motion = moving == true
	-- An Angler who opened the Letter, as one who reached Off to the water has, so it doesn't arrive mid-spec
	-- (ONB-R12).
	if loaded.ns.db.global.onboarding.letter == "waiting" then
		loaded.ns.db.global.onboarding.letter = "opened"
	end
	enterWorld(loaded, 3)
	return loaded, ledger, hunts, tracker
end

-- PagleDB.global.onboarding.evening as the client holds it.
local function evening(loaded)
	return loaded.env.PagleDB.global.onboarding.evening
end

-- The descendant of `widget` holding a shown font string reading `text`, depth first; nil if none.
local function holding(widget, text)
	for _, child in ipairs(widget.children) do
		for _, region in ipairs(child.children) do
			if region.kind == "FontString" and region.text == text and region.shown then
				return child
			end
		end
		local found = holding(child, text)
		if found then
			return found
		end
	end
	return nil
end

-- Off to the water, pressed on the guide's last step.
local function offToTheWater(loaded)
	loaded.ns.guide:Open("off")
	local page = loaded.ns.guideBook.sides.off.right.content
	assert(holding(page, "Off to the water"), "no Off to the water on the off step"):Click()
end

-- The sounds since `from`, in order.
local function soundsSince(loaded, from)
	return { unpack(loaded.client.sounds, from + 1) }
end

describe("The First evening list on the client", function()
	it("docks after Off to the water as the top tracker, above Hunts' (ONB-R60, CORE-R70)", function()
		local loaded, _, _, hunts = withList()
		local frame = loaded.ns.eveningFrame
		local dock = loaded.ns.dockFrame
		assert.is_false(frame:IsShown())
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, { hunts:GetPoint(1) })

		offToTheWater(loaded)

		assert.is_true(frame:IsShown())
		assert.is_true(evening(loaded).shown)
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, 0 }, { frame:GetPoint(1) })
		assert.are.same({ "TOPRIGHT", dock, "TOPRIGHT", 0, -(frame:GetHeight() + 8) }, { hunts:GetPoint(1) })
	end)

	it("reads the header, its count, its close mark and every line, the next one's hint under it (ONB-R61)", function()
		local loaded = withList()

		offToTheWater(loaded)

		assert.are.same({
			"First evening",
			"×",
			"0 of 6",
			"Make a Cast",
			"right-click the water with Fishing", -- QoL isn't registered here (ONB-R101)
			"Land a Catch",
			"Open the Fish Journal",
			"See what’s biting on Hunts",
			"Finish a Session",
			"Peek into the Curio Shop",
		}, shownTexts(loaded.ns.eveningFrame))
		-- The kit's tracker: 274 wide, the header 30, a line 21.6 or 34.6 with its hint, 12 under the last.
		assert.are.equal(274, loaded.ns.eveningFrame:GetWidth())
		assert.is_true(math.abs(loaded.ns.eveningFrame:GetHeight() - (30 + 34.6 + 5 * 21.6 + 12)) < 0.01)
	end)

	it("ticks a real Cast and Catch, a Session ending without a card and the shop opening (ONB-R61)", function()
		local loaded = withList()
		offToTheWater(loaded)
		local from = #loaded.client.sounds

		catchAndFlush(loaded)
		loaded.client.advance(300) -- an ordinary Catch raises no moment, so its Session ends with no card (ANN-R53)
		pagle(loaded, "shop")

		local done = evening(loaded).done
		assert.are.same({ cast = true, catch = true, session = true, shop = true }, done)
		local ticks = 0
		for _, sound in ipairs(soundsSince(loaded, from)) do
			ticks = ticks + (sound == TICK and 1 or 0)
		end
		assert.are.equal(4, ticks)
		assert.are.equal("4 of 6", shownTexts(loaded.ns.eveningFrame)[3])
		assert.is_true(holding(loaded.ns.eveningFrame, "Open the Fish Journal") ~= nil)
	end)

	it('ticks a fixture Module\'s item through M:CompleteEveningItem("journal") (ONB-R61)', function()
		local loaded, ledger = withList()
		offToTheWater(loaded)

		ledger:CompleteEveningItem("journal")

		assert.is_true(evening(loaded).done.journal)
		assert.are.equal("1 of 6", shownTexts(loaded.ns.eveningFrame)[3])
	end)

	it("keeps items done before it docks, ticked (ONB-R61)", function()
		local loaded = withList()

		catchAndFlush(loaded)
		assert.is_false(loaded.ns.eveningFrame:IsShown())
		offToTheWater(loaded)

		assert.are.equal("2 of 6", shownTexts(loaded.ns.eveningFrame)[3])
	end)

	it("plays listDone at the last tick, folds away 2.5 s later and never returns (ONB-R62, ONB-R64)", function()
		local loaded, ledger, hunts, tracker = withList()
		offToTheWater(loaded)
		ledger:CompleteEveningItem("journal")
		hunts:CompleteEveningItem("hunts")
		pagle(loaded, "shop")
		pagle(loaded, "shop")
		catchAndFlush(loaded)
		local from = #loaded.client.sounds

		loaded.client.advance(300)

		assert.are.same({ TICK, LIST_DONE }, soundsSince(loaded, from))
		assert.is_true(loaded.ns.eveningFrame:IsShown())
		loaded.client.advance(2.5)

		assert.is_false(loaded.ns.eveningFrame:IsShown())
		assert.is_true(evening(loaded).closed)
		assert.are.same({ "TOPRIGHT", loaded.ns.dockFrame, "TOPRIGHT", 0, 0 }, { tracker:GetPoint(1) })
		assert.are.equal(0, loaded.env.PagleDB.global.coins and #loaded.env.PagleDB.global.coins or 0)
	end)

	it("inks a tick in, its box popping from 0.6x over 0.3 s, with Animations on (MOTION.md)", function()
		local loaded, ledger = withList(nil, true)
		offToTheWater(loaded)
		local tick = loaded.ns.eveningFrame.rows[3].tick

		ledger:CompleteEveningItem("journal")

		assert.is_true(tick:IsShown())
		assert.are.same({ 0.6, 0.6 }, { tick:GetWidth() / 16, tick:GetHeight() / 18 })
		loaded.client.update(0.3)
		assert.are.same({ 16, 18 }, { tick:GetWidth(), tick:GetHeight() })
	end)

	it("folds rising 14 units as it fades (0.4 s), then hides, with Animations on (MOTION.md)", function()
		local loaded, ledger, hunts = withList(nil, true)
		offToTheWater(loaded)
		ledger:CompleteEveningItem("journal")
		hunts:CompleteEveningItem("hunts")
		pagle(loaded, "shop")
		catchAndFlush(loaded)
		loaded.client.advance(300)
		local body = loaded.ns.eveningFrame.body

		loaded.client.advance(2.5)
		loaded.client.update(0.2)

		assert.is_true(loaded.ns.eveningFrame:IsShown())
		assert.is_true(body:GetAlpha() < 1 and body:GetAlpha() > 0)
		assert.is_true(select(5, body:GetPoint(1)) > 0)
		loaded.client.update(0.3)

		assert.is_false(loaded.ns.eveningFrame:IsShown())
	end)

	it("closes with its close mark, and plays no tick in Cozy mode (ONB-R63, SOUND.md)", function()
		local loaded = withList()
		offToTheWater(loaded)
		loaded.ns.db.profile.announcements.cozy = true
		local from = #loaded.client.sounds
		catchAndFlush(loaded)
		assert.are.same({}, soundsSince(loaded, from))

		loaded.ns.eveningFrame.close:Click()

		assert.is_false(loaded.ns.eveningFrame:IsShown())
		assert.is_true(evening(loaded).closed)
	end)

	it("shows again after a /reload while unfinished (ONB-R60)", function()
		local saved
		do
			local loaded = withList()
			offToTheWater(loaded)
			saved = loaded.env.PagleDB
		end

		local loaded = loadCore({ BUILD_ENTRY }, saved)
		enterWorld(loaded, 3)

		assert.is_true(loaded.ns.eveningFrame:IsShown())
	end)

	it("never docks for a returning Angler (ONB-R60, ONB-R2)", function()
		local loaded = withList({ BUILD_ENTRY, castEntry(SERVER_TIME - 4000) })

		offToTheWater(loaded)

		assert.are.equal("returning", loaded.env.PagleDB.global.onboarding.letter)
		assert.is_false(loaded.ns.eveningFrame:IsShown())
	end)

	it("docks with /pagle dev onboarding evening (ONB-R83)", function()
		local loaded = withList()
		pagle(loaded, "dev on")

		pagle(loaded, "dev onboarding evening")

		assert.is_true(loaded.ns.eveningFrame:IsShown())
		assert.is_true(evening(loaded).shown)
	end)

	it("has the tour stop core.onboarding.evening: a sample with two items done, writing nothing (ONB-R84)", function()
		local loaded = withList()
		local stop
		for _, listed in ipairs(loaded.ns.tourStops:List(loaded.ns.Modules:Modules(), "core")) do
			if listed.name == "core.onboarding.evening" then
				stop = listed
			end
		end
		local before = loaded.env.PagleDB.global.onboarding.evening

		stop.show()

		assert.is_true(loaded.ns.eveningFrame:IsShown())
		assert.are.equal("2 of 6", shownTexts(loaded.ns.eveningFrame)[3])
		stop.hide()

		assert.is_false(loaded.ns.eveningFrame:IsShown())
		assert.are.same({ shown = false, closed = false, done = {} }, before)
	end)
end)
