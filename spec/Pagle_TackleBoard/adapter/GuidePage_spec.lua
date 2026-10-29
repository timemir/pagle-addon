-- The Tackle Board's step in the Field guide on FakePagle (ONB-R21, ONB-R23, ONB-R37, ONB-R90; TKB-R5, TKB-R108): its
-- place among the steps, its skip link, its two pages (the sample strip drawn by the board's own art, standing still,
-- and the four facts) and Start my board, which starts the board through TKB-R5 and then reads "Your board is up".

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Stranglethorn Vale's area ID, the sample Haul's zone.
local STRANGLETHORN = 33

-- Pagle_TackleBoard on a fake whose log holds `records`, logged in and its projection built, the client naming the
-- sample's zone; `prepare` runs on the fake before the board loads.
local function loggedIn(records, prepare)
	local fake = board.withHistory(records or {})
	if prepare then
		prepare(fake)
	end
	local loaded = board.load(fake)
	loaded.client.areaNames[STRANGLETHORN] = "Stranglethorn Vale"
	fake.login()
	fake.enterWorld()
	return loaded, fake
end

-- The guide opened at the Tackle Board's step, and its two pages as the step's build drew them.
local function atStep(loaded, fake)
	fake.guide:Open("board")
	return fake.guidePages.board, loaded.ns.guidePage
end

-- The texts of every shown widget under `widget`, depth first.
local function textsOf(widget, texts)
	texts = texts or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text ~= nil and child.text ~= "" then
				texts[#texts + 1] = child.text
			end
			textsOf(child, texts)
		end
	end
	return texts
end

-- `value` if `list` holds it, else nil.
local function holding(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return value
		end
	end
	return nil
end

-- Every widget under `widget` that takes the mouse, depth first.
local function mouseTakers(widget, found)
	found = found or {}
	for _, child in ipairs(widget.children) do
		if child.mouseEnabled then
			found[#found + 1] = child
		end
		mouseTakers(child, found)
	end
	return found
end

-- The ids of the steps the guide showed, in order.
local function shownIds(fake)
	local ids = {}
	for i, page in ipairs(fake.guideShown) do
		ids[i] = page.id
	end
	return ids
end

describe("the Tackle Board's step in the Field guide (ONB-R21, ONB-R37)", function()
	it("is the step board at 70, its ribbon Tackle Board, between Core's Moments and Off you go (ONB-R21)", function()
		local _, fake = loggedIn()

		local entry = fake.guideSteps:List()[fake.guideSteps:Index("board")]
		assert.are.same(
			{ "board", 70, "Tackle Board", "Not now", "next" },
			{ entry.step.id, entry.step.order, entry.step.ribbon, entry.step.skipLabel, entry.step.skipTo }
		)
		assert.are.equal(5, fake.guideSteps:Count())
		assert.are.equal(fake.guideSteps:Index("off") - 1, fake.guideSteps:Index("board"))
	end)

	it("leaves the guide a step shorter when the Tackle Board isn't loaded: 7 of the full 8 (ONB-R21)", function()
		local fake = newFakePagle()
		fake.login()

		assert.are.equal(4, fake.guideSteps:Count())
		assert.is_nil(fake.guideSteps:Index("board"))
	end)

	it('skips with "Not now" to the next step, not to the last (ONB-R23, ONB-R37)', function()
		local _, fake = loggedIn(nil, function(fake)
			local M = fake.Pagle.RegisterModule({ name = "Stats", title = "Stats", order = 30 })
			M:RegisterGuideStep({ id = "later", order = 80, ribbon = "Later", build = function() end })
		end)
		fake.guide:Open("board")

		fake.guide:Skip()

		assert.are.same({ "board", "later" }, shownIds(fake))
	end)

	it("registers nothing, and loads, on a Core without M:RegisterGuideStep (ONB-R90)", function()
		local loaded, fake = loggedIn(nil, function(fake)
			fake.ns.ModuleHandle.RegisterGuideStep = nil
		end)

		assert.is_table(loaded.ns.Module)
		assert.are.equal(4, fake.guideSteps:Count())
	end)
end)

describe("the Tackle Board's guide pages (ONB-R37)", function()
	it("reads its kicker, title and paragraph, and the lines by the Campfire and the Fly Box, on the left", function()
		local loaded, fake = loggedIn()
		local pages = atStep(loaded, fake)

		local texts = textsOf(pages.left)
		for _, text in ipairs({
			"The Tackle Board",
			"Goals that wait for you",
			"Small Notices pinned to a cork board: a fish to find, a water to visit. Fish when you like; "
				.. "they’ll still be there.",
			"|cff3e220cYour Campfire|r grows with each day you finish a Notice. Miss a day and |cff3e220cKindling|r "
				.. "burns instead; it isn’t put out.",
			"Each Notice you finish ties one fly for your |cff3e220cFly Box|r.",
		}) do
			assert.are.equal(text, holding(texts, text))
		end
	end)

	it(
		"draws the sample strip with the board's own art: two Notices, a Campfire and a Fly Box, in its words",
		function()
			local loaded, fake = loggedIn()
			local pages, page = atStep(loaded, fake)
			local atlases = loaded.ns.BOARD_ATLASES

			-- Two of the board's own Notice papers (adapter/Pins.lua), with their kind, text, progress and where.
			assert.are.equal(2, #page.notices)
			for _, slip in ipairs(page.notices) do
				assert.are.equal(atlases.Board.file, slip.paper.texture)
			end
			local texts = textsOf(pages.left)
			for _, text in ipairs({
				"HAUL",
				"30 Catches in Stranglethorn Vale",
				"12 of 30",
				"I'm here",
				"COLLECTOR",
				"A junk item and a container today",
				"1 of 2 today",
				"anywhere",
			}) do
				assert.are.equal(text, holding(texts, text))
			end
			-- The Campfire on a cut of the ledge, its fire and its days; the Fly Box with its count.
			assert.are.equal(atlases.Frame.file, page.fire.ledge.texture)
			assert.are.equal("7", page.fire.burning.stage)
			assert.are.equal("13", holding(texts, "13"))
			assert.are.equal("days", holding(texts, "days"))
			assert.are.equal("longest 13", holding(texts, "longest 13"))
			assert.are.equal(atlases.Frame.file, page.box.ledge.texture)
			assert.are.equal("F L Y   B O X", holding(texts, "F L Y   B O X"))
			assert.are.equal("26 of 30 tied", holding(texts, "26 of 30 tied"))
			-- Each sample framed in the guide's window edge, over it.
			local frames = {}
			local function framed(widget)
				for _, child in ipairs(widget.children) do
					if child.panel then
						frames[#frames + 1] = child.panel .. " " .. child.panelCap
					end
					framed(child)
				end
			end
			framed(pages.left)
			assert.are.same({ "win 6", "win 6", "win 6" }, frames)
		end
	)

	it("stands still: nothing on the left page takes the mouse, and no motion plays there (ONB-R37)", function()
		local loaded, fake = loggedIn()
		local pages = atStep(loaded, fake)

		assert.are.same({}, mouseTakers(pages.left))
		assert.is_nil(loaded.ns.board.frame)
	end)

	it("reads the four facts by their coin bullets, and the line under Start my board, on the right", function()
		local loaded, fake = loggedIn()
		local pages, page = atStep(loaded, fake)

		local texts = textsOf(pages.right)
		for _, text in ipairs({
			"Only if you want one",
			"Shall I put up a board?",
			"Three Notices a day, and one bigger Expedition a week.",
			"None of them expire. Away a while? Up to six Notices and two Expeditions wait for you.",
			"Don’t fancy one? Each can be taken down for a fresh one, once a day.",
			"They pay Pagle Coins, |cff6a4a28which buy looks in the Curio Shop.|r",
			"Or leave it for now. The board waits under Tackle Board in the Pagle menu, and in Settings.",
		}) do
			assert.are.equal(text, holding(texts, text))
		end
		assert.are.equal(4, #page.bullets)
		for _, bullet in ipairs(page.bullets) do
			assert.are.equal("coin", bullet.sprite)
		end
	end)
end)

describe("the Tackle Board's step on Core's own guide (ONB-R21, ONB-R37, ONB-R92)", function()
	it("is 4 of 5 with Core alone beside it, and draws its pages in Core's book with the guide's coin", function()
		local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
		enterWorld(loaded, 3)
		local core = loaded.namespaces.Pagle
		core.db.profile.announcements.motion = false
		loaded.env.SlashCmdList.PAGLE("dev on")

		loaded.env.SlashCmdList.PAGLE("dev onboarding step board")

		assert.are.equal(5, core.guideSteps:Count())
		assert.are.equal(4, core.guideSteps:Index("board"))
		local page = loaded.ns.guidePage
		assert.are.equal("Start my board", page.start.label:GetText())
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\guide\\GuideParts", page.bullets[1].texture)
		assert.are.same({}, loaded.client.errors)
	end)
end)

describe("Start my board on the guide's page (ONB-R37, TKB-R5)", function()
	it('starts the board through TKB-R5, then reads "Your board is up", disabled, with a pin sound', function()
		local loaded, fake = loggedIn()
		local _, page = atStep(loaded, fake)
		assert.are.equal("Start my board", page.start.label:GetText())
		assert.is_true(page.start:IsEnabled())
		loaded.client.sounds = {}

		page.start:Click()

		assert.is_true(loaded.ns.IsStarted())
		assert.are.equal("Your board is up", page.start.label:GetText())
		assert.is_false(page.start:IsEnabled())
		assert.are.same({ "1212 SFX" }, loaded.client.sounds)
		-- Next stays: the guide is still at this step.
		assert.are.same({ "board" }, shownIds(fake))
	end)

	it('reads "Your board is up", disabled, from the first on a board already started', function()
		local loaded, fake = loggedIn({ board.start(board.DAY0 + 60) })
		local _, page = atStep(loaded, fake)

		assert.are.equal("Your board is up", page.start.label:GetText())
		assert.is_false(page.start:IsEnabled())
	end)

	it("is disabled while the projection is updating, and usable once it's done (TKB-R5, TKB-R108)", function()
		local loaded, fake = loggedIn()
		local _, page = atStep(loaded, fake)
		local updating = true
		loaded.ns.IsUpdating = function()
			return updating
		end
		fake.guide:Close()
		fake.guide:Open("board")
		assert.are.equal("Start my board", page.start.label:GetText())
		assert.is_false(page.start:IsEnabled())

		updating = false
		loaded.ns.Redraw("projection")

		assert.is_true(page.start:IsEnabled())
	end)

	it("reads the board afresh each time the step shows: started from Settings meanwhile, it's up", function()
		local loaded, fake = loggedIn()
		local _, page = atStep(loaded, fake)
		fake.guide:Close()

		loaded.ns.Start()
		fake.guide:Open("board")

		assert.are.equal("Your board is up", page.start.label:GetText())
		assert.is_false(page.start:IsEnabled())
	end)
end)
