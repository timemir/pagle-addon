-- The Field guide on the client, through the real TOC and the fake client (core/onboarding.md › The Field guide): the
-- book (ONB-R20, ONB-R27), the steps Core and fixture Modules register (ONB-R21, ONB-R90), opening and moving (ONB-R22
-- –R24, ONB-R26), the ribbons (ONB-R24), the hold and the restriction (ONB-R25, ONB-R70), the entry points (ONB-R80,
-- ONB-R83), the events (CORE-R20), motion and sound (core/onboarding.md › Motion, › Sounds).

local SOUND_OPEN, SOUND_CLOSE, SOUND_TURN = "829 SFX", "830 SFX", "836 SFX"

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- The fixture Modules and their steps (ONB-R21's orders), by roster name: { def.order, { id, step order } … }.
local FIXTURES = {
	{
		"QoL",
		50,
		{ { "casting", 30 }, { "clothes", 40, { skipLabel = "I don’t keep fishing clothes", skipTo = "next" } } },
	},
	{ "Ledger", 10, { { "ledger", 60 } } },
	{ "TackleBoard", 40, { { "board", 70, { skipLabel = "Not now", skipTo = "next" } } } },
}

-- Core logged in with every login frame run and the fixture Modules registered, each but `without`, each step's build
-- noting its two pages in `built[id]`. Returns the client load and `built`.
local function withGuide(without, saved)
	local loaded = loadCore({ BUILD_ENTRY }, saved)
	local built = {}
	for _, fixture in ipairs(FIXTURES) do
		local name = fixture[1]
		if name ~= without then
			loaded.client.addons["Pagle_" .. name] = { metadata = { ["X-Pagle-API"] = "1" } }
			local M = loaded.env.Pagle.RegisterModule({ name = name, title = name, order = fixture[2] })
			for _, step in ipairs(fixture[3]) do
				local id = step[1]
				local registered = {
					id = id,
					order = step[2],
					ribbon = "Ribbon " .. id,
					build = function(left, right, nav)
						built[id] = { left = left, right = right, nav = nav }
					end,
				}
				for key, value in pairs(step[3] or {}) do
					registered[key] = value
				end
				M:RegisterGuideStep(registered)
			end
		end
	end
	enterWorld(loaded, 3)
	return loaded, built
end

-- PagleDB.global.onboarding as the client holds it.
local function state(loaded)
	return loaded.env.PagleDB.global.onboarding
end

-- The guide's book frame.
local function bookOf(loaded)
	return loaded.env.PagleGuide
end

-- The descendant of `widget` holding a shown font string reading `text`, depth first; nil if none.
local function holding(widget, text)
	for _, child in ipairs(widget.children) do
		for _, region in ipairs(child.children) do
			if region.kind == "FontString" and region.text == text then
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

-- Clicks the control reading `text` on step `id`'s `side` page.
local function click(loaded, id, side, text)
	local page = loaded.ns.guideBook.sides[id][side].content
	local control = holding(page, text) or error(("no %s on %s's %s page"):format(text, id, side))
	control:Click()
end

-- The step on the pages now: the id whose pages show.
local function shownStep(loaded)
	for id, sides in pairs(loaded.ns.guideBook.sides) do
		if sides.left.clip.shown and sides.right.clip.shown then
			return id
		end
	end
	return nil
end

-- Each ribbon as "<label> <state> <length>".
local function ribbons(loaded)
	local list = {}
	for i, ribbon in ipairs(bookOf(loaded).ribbons) do
		list[i] = ("%s %s %d"):format(ribbon.label.text, ribbon.state, ribbon.length)
	end
	return list
end

-- Plays `seconds` of frames at 60 a second, each moving the clock on and running every OnUpdate (Core's motion driver).
local function play(loaded, seconds)
	for _ = 1, math.ceil(seconds * 60 - 1e-9) do
		loaded.client.nextFrame(1 / 60)
	end
end

-- Turns Animations off (SET-R30).
local function stillness(loaded)
	loaded.ns.db.profile.announcements.motion = false
end

describe("the Field guide's book (ONB-R20, ONB-R27)", function()
	it(
		"is PagleGuide, 920 x 600 in DIALOG over the world's dim at 0.58, closed until opened, in UISpecialFrames",
		function()
			local loaded = withGuide()
			assert.is_nil(bookOf(loaded))

			pagle(loaded, "guide")

			local book = bookOf(loaded)
			assert.are.same({ 920, 600 }, { book.width, book.height })
			assert.are.equal("DIALOG", book:GetFrameStrata())
			assert.is_true(book.dim:IsShown())
			assert.are.equal(0.58, book.dim.children[1].color[4])
			assert.are.equal("HIGH", book.dim:GetFrameStrata())
			local listed = false
			for _, name in ipairs(loaded.env.UISpecialFrames) do
				listed = listed or name == "PagleGuide"
			end
			assert.is_true(listed)
		end
	)

	it("reads 'Pagle · A field guide' on its strip, with '{n} of {m}' at its right (ONB-R20)", function()
		local loaded = withGuide()

		pagle(loaded, "guide")

		local book = bookOf(loaded)
		assert.are.same({ "Pagle", "A field guide" }, { book.crumbs[1].text, book.crumbs[2].text })
		assert.are.equal("|cfff6e3a81|r of 8", book.count.text)
	end)

	it("closes with Esc and with its wax close, keeping guideStep (ONB-R20, ONB-R22)", function()
		local loaded = withGuide()
		stillness(loaded)
		pagle(loaded, "guide")
		loaded.ns.guide:GoTo("ledger")

		loaded.client.pressEscape()
		assert.is_false(bookOf(loaded):IsShown())
		assert.is_false(loaded.ns.guide:IsOpen())
		assert.is_false(bookOf(loaded).dim:IsShown())
		assert.are.equal("ledger", state(loaded).guideStep)

		pagle(loaded, "guide")
		assert.are.equal("ledger", shownStep(loaded))
		bookOf(loaded).close:Click()
		assert.is_false(loaded.ns.guide:IsOpen())
	end)

	it(
		"fits the screen with its ribbons and wax close: shrinks, never grows, refits on UI_SCALE_CHANGED (ONB-R27)",
		function()
			local loaded = withGuide()

			pagle(loaded, "guide")
			assert.are.equal(1, bookOf(loaded):GetScale())

			loaded.env.UIParent:SetSize(1188, 668)
			loaded.client.fire("UI_SCALE_CHANGED")

			assert.are.near((668 - 48) / 760, bookOf(loaded):GetScale(), 1e-9)
		end
	)
end)

describe("the Field guide's steps (ONB-R21, ONB-R90)", function()
	it("shows Core's and the fixture Modules' steps in order, n of 8, each built once on 442 x 546 pages", function()
		local loaded, built = withGuide()
		stillness(loaded)
		pagle(loaded, "guide")

		local walked = {}
		for _ = 1, 8 do
			walked[#walked + 1] = shownStep(loaded) .. " " .. bookOf(loaded).count.text:gsub("|c%x%x%x%x%x%x%x%x", "")
			loaded.ns.guide:Next()
		end

		assert.are.same({
			"welcome 1|r of 8",
			"box 2|r of 8",
			"casting 3|r of 8",
			"clothes 4|r of 8",
			"moments 5|r of 8",
			"ledger 6|r of 8",
			"board 7|r of 8",
			"off 8|r of 8",
		}, walked)
		assert.are.same({ 442, 546 }, { built.ledger.left:GetWidth(), built.ledger.right:GetHeight() })
	end)

	it("drops a Module's steps when it is off: seven ribbons, n of 7 (ONB-R21, ONB-R102)", function()
		local loaded = withGuide("TackleBoard")
		pagle(loaded, "guide")

		assert.are.equal(7, #bookOf(loaded).ribbons)
		assert.are.equal("|cfff6e3a81|r of 7", bookOf(loaded).count.text)
	end)

	it("raises an error at the Module's call for a step missing its build, adding nothing (ONB-R90)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })

		local ok, problem = pcall(function()
			M:RegisterGuideStep({ id = "ledger", order = 60, ribbon = "Your Ledger" })
		end)

		assert.is_false(ok)
		assert.matches("Guide_spec%.lua:%d+: RegisterGuideStep: step ledger needs build", tostring(problem))
		assert.are.equal(4, loaded.ns.guideSteps:Count())
	end)

	it("reports a step registered after ModulesChanged through geterrorhandler() and drops it (ONB-R21)", function()
		local loaded = loadCore({ BUILD_ENTRY })
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		enterWorld(loaded)

		M:RegisterGuideStep({ id = "ledger", order = 60, ribbon = "Your Ledger", build = function() end })

		assert.are.equal(1, #loaded.client.errors)
		assert.matches("Ledger's RegisterGuideStep came after ModulesChanged", loaded.client.errors[1])
		loaded.client.errors = {}
		assert.is_nil(loaded.ns.guideSteps:Index("ledger"))
	end)

	it("hands a build the nav: Next, Back, Close and Core's widgets (Contracts)", function()
		local loaded, built = withGuide()
		stillness(loaded)
		pagle(loaded, "dev on")
		pagle(loaded, "dev onboarding step ledger")
		local nav = built.ledger.nav

		local card = nav.ChoiceCard(built.ledger.right, "Lively", "Every Catch gets its Nod.", "as it comes")
		local note = nav.Note(built.ledger.right, "A *double right-click* casts too.", 56, 400, 300, nil, 1)
		local part = nav.Part(built.ledger.left, "disc")
		local field = nav.BindingField(built.ledger.right, "PAGLE_FISHING_KEY", "Fishing key")

		assert.are.same({ "Lively", "Every Catch gets its Nod.", "as it comes" }, {
			card.title.text,
			card.line.text,
			card.tag.text,
		})
		assert.are.equal("A |cff9a2a1adouble right-click|r casts too.", note.text.text)
		assert.are.equal("1", note.number.text)
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\guide\\GuideParts", part.texture)
		assert.are.equal("PAGLE_FISHING_KEY", field.action)
		nav.Next()
		assert.are.equal("board", shownStep(loaded))
		nav.Back()
		assert.are.equal("ledger", shownStep(loaded))
		nav.Close()
		assert.is_false(loaded.ns.guide:IsOpen())
	end)
end)

describe("moving through the Field guide (ONB-R22–R24, ONB-R26)", function()
	it(
		"turns with Next » and « back, setting guideStep and stepsSeen; a reopen resumes (ONB-R22, ONB-R23)",
		function()
			local loaded = withGuide()
			stillness(loaded)
			pagle(loaded, "guide")

			click(loaded, "welcome", "right", "Show me around »")
			click(loaded, "box", "right", "Next »")
			click(loaded, "casting", "left", "« back")

			assert.are.equal("box", shownStep(loaded))
			assert.are.equal("box", state(loaded).guideStep)
			assert.are.same({ welcome = true, box = true, casting = true }, state(loaded).stepsSeen)
			loaded.client.pressEscape()
			pagle(loaded, "guide")
			assert.are.equal("box", shownStep(loaded))
		end
	)

	it("has no « back on the first step, and Off to the water instead of Next on the last (ONB-R23)", function()
		local loaded = withGuide()
		stillness(loaded)
		pagle(loaded, "guide")
		local welcome = loaded.ns.guideBook.sides.welcome

		assert.is_nil(holding(welcome.left.content, "« back"))
		assert.is_nil(holding(welcome.right.content, "Next »"))
		loaded.ns.guide:GoTo("off")
		local off = loaded.ns.guideBook.sides.off
		assert.is_nil(holding(off.right.content, "Next »"))
		assert.is_nil(holding(off.right.content, "Skip the rest"))
		assert.is_not_nil(holding(off.right.content, "Off to the water"))
	end)

	it("skips to the last step from 'Skip the rest', and to the next from a step's own skip (ONB-R23)", function()
		local loaded = withGuide()
		stillness(loaded)
		pagle(loaded, "guide")
		loaded.ns.guide:GoTo("box")

		click(loaded, "box", "right", "Skip the rest")
		assert.are.equal("off", shownStep(loaded))

		loaded.ns.guide:GoTo("clothes")
		click(loaded, "clothes", "right", "I don’t keep fishing clothes")
		assert.are.equal("moments", shownStep(loaded))
		assert.is_nil(state(loaded).stepsSeen.casting)
	end)

	it("closes and sets skipped from the Welcome step's 'I’ll find my own way' (ONB-R26)", function()
		local loaded = withGuide()
		stillness(loaded)
		pagle(loaded, "guide")

		click(loaded, "welcome", "right", "I’ll find my own way")

		assert.is_false(loaded.ns.guide:IsOpen())
		assert.is_true(state(loaded).skipped)
		assert.is_false(state(loaded).guideDone)
	end)

	it("sets guideDone with Off to the water, closes, then calls its hook (ONB-R26, ONB-R38)", function()
		local loaded = withGuide()
		stillness(loaded)
		local calls = 0
		loaded.ns.guide:SetOffToTheWater(function()
			calls = calls + 1
		end)
		pagle(loaded, "guide")
		loaded.ns.guide:GoTo("off")

		click(loaded, "off", "right", "Off to the water")

		assert.is_true(state(loaded).guideDone)
		assert.is_false(loaded.ns.guide:IsOpen())
		assert.are.equal(1, calls)
	end)

	it(
		"hangs a ribbon per step: the current 110 long, seen ones ticked, the rest not; a click turns (ONB-R24)",
		function()
			local loaded = withGuide()
			stillness(loaded)
			pagle(loaded, "guide")
			loaded.ns.guide:Next()

			assert.are.same({
				"Welcome done 92",
				"What’s in the box on 110",
				"Ribbon casting plain 92",
				"Ribbon clothes plain 92",
				"Moments plain 92",
				"Ribbon ledger plain 92",
				"Ribbon board plain 92",
				"Off you go plain 92",
			}, ribbons(loaded))
			local book = bookOf(loaded)
			local first, second = book.ribbons[1].points[1], book.ribbons[2].points[1]
			assert.are.same({ 40, -586 }, { first[4], first[5] })
			assert.are.equal(98 + 8, second[4] - first[4])
			assert.are.equal(98, book.ribbons[1].width)
			assert.is_true(book.ribbons[1]:GetFrameLevel() < book.leather.band:GetFrameLevel())

			book.ribbons[6]:Click()
			assert.are.equal("ledger", shownStep(loaded))
			book.ribbons[1]:Click()
			assert.are.equal("welcome", shownStep(loaded))
		end
	)

	it(
		"opens at a step with /pagle dev onboarding step <id>, and lists the steps for an unknown one (ONB-R83)",
		function()
			local loaded = withGuide()
			pagle(loaded, "dev on")

			pagle(loaded, "dev onboarding step nowhere")
			assert.is_false(loaded.ns.guide:IsOpen())
			assert.are.equal(
				"Pagle dev: no guide step nowhere; the steps are welcome, box, casting, clothes, moments, ledger, board, off.",
				loaded.printed[#loaded.printed]
			)

			pagle(loaded, "dev onboarding step board")
			assert.are.equal("board", shownStep(loaded))
		end
	)

	it("fires GuideOpened, then GuideClosed with the step it was on (CORE-R20)", function()
		local loaded = withGuide()
		stillness(loaded)
		local fired = {}
		loaded.env.Pagle.RegisterCallback("spec", "GuideOpened", function(event)
			fired[#fired + 1] = event
		end)
		loaded.env.Pagle.RegisterCallback("spec", "GuideClosed", function(event, stepId)
			fired[#fired + 1] = event .. " " .. stepId
		end)

		pagle(loaded, "guide")
		loaded.ns.guide:GoTo("moments")
		loaded.client.pressEscape()

		assert.are.same({ "GuideOpened", "GuideClosed moments" }, fired)
	end)
end)

describe("the world while the Field guide is open (ONB-R25, ONB-R70, ONB-R71)", function()
	it("holds Announcements under guide while open and releases them as it closes (ONB-R70)", function()
		local loaded = withGuide()
		stillness(loaded)

		pagle(loaded, "guide")
		assert.is_true(loaded.ns.lanes:IsHeld("guide"))
		loaded.client.pressEscape()

		assert.is_false(loaded.ns.lanes:IsHeld("guide"))
	end)

	it("closes as combat starts, setting reopen, and reopens at the same step when it ends (ONB-R25)", function()
		local loaded = withGuide()
		stillness(loaded)
		pagle(loaded, "guide")
		loaded.ns.guide:GoTo("clothes")

		setCombat(loaded, true)
		assert.is_false(bookOf(loaded):IsShown())
		assert.is_true(state(loaded).reopen)
		assert.is_false(loaded.ns.lanes:IsHeld("guide"))

		setCombat(loaded, false)
		assert.is_true(bookOf(loaded):IsShown())
		assert.are.equal("clothes", shownStep(loaded))
		assert.is_false(state(loaded).reopen)
	end)

	it("opens after combat when asked for during it, saying so (ONB-R25)", function()
		local loaded = withGuide()
		setCombat(loaded, true)

		pagle(loaded, "guide")
		assert.is_nil(bookOf(loaded))
		assert.are.same({ "Pagle: the Field guide opens after combat." }, loaded.printed)

		setCombat(loaded, false)
		assert.is_true(bookOf(loaded):IsShown())
	end)

	it("takes no clicks from the world on its dim (ONB-R71)", function()
		local loaded = withGuide()
		pagle(loaded, "guide")

		assert.is_falsy(bookOf(loaded).dim.mouseEnabled)
	end)
end)

describe("the Field guide's motion and sound (core/onboarding.md › Motion, › Sounds)", function()
	it("fades in over 0.16 s with bookOpen, and out over 0.12 s with bookClose", function()
		local loaded = withGuide()
		loaded.client.sounds = {}

		pagle(loaded, "guide")
		local book = bookOf(loaded)
		assert.are.equal(0, book.alpha)
		play(loaded, 0.2)
		assert.are.equal(1, book.alpha)
		loaded.ns.guide:Close()
		assert.is_true(book:IsShown())
		play(loaded, 0.13)

		assert.is_false(book:IsShown())
		assert.are.same({ SOUND_OPEN, SOUND_CLOSE }, loaded.client.sounds)
	end)

	it("turns the page with the books' turn and pageTurn, the old page gone once it lands", function()
		local loaded = withGuide()
		pagle(loaded, "guide")
		play(loaded, 0.2)
		loaded.client.sounds = {}

		loaded.ns.guide:Next()
		local sides = loaded.ns.guideBook.sides
		assert.is_true(sides.welcome.left.clip.shown)
		assert.is_true(bookOf(loaded).turnFold.shown)
		play(loaded, 0.6)

		assert.are.equal("box", shownStep(loaded))
		assert.is_false(sides.welcome.left.clip.shown)
		assert.is_false(sides.welcome.right.clip.shown)
		assert.is_false(bookOf(loaded).turnFold.shown)
		assert.are.same({ SOUND_TURN }, loaded.client.sounds)
	end)

	it("drops the new current ribbon from 92 to 110 as the old one draws up, over 0.2 s", function()
		local loaded = withGuide()
		pagle(loaded, "guide")
		play(loaded, 0.2)

		loaded.ns.guide:Next()
		local ribbonsNow = bookOf(loaded).ribbons
		assert.are.same({ 110, 92 }, { ribbonsNow[1].length, ribbonsNow[2].length })
		play(loaded, 0.1)
		assert.is_true(ribbonsNow[2].length > 92 and ribbonsNow[2].length < 110)
		play(loaded, 0.15)

		assert.are.same({ 92, 110 }, { ribbonsNow[1].length, ribbonsNow[2].length })
	end)

	it("appears settled with Animations off: whole at once, page turns at once and silent", function()
		local loaded = withGuide()
		stillness(loaded)
		loaded.client.sounds = {}

		pagle(loaded, "guide")
		local book = bookOf(loaded)
		assert.are.equal(1, book.alpha)
		loaded.ns.guide:Next()
		assert.are.equal("box", shownStep(loaded))
		assert.is_false(loaded.ns.guideBook.sides.welcome.left.clip.shown)
		assert.are.same({ 92, 110 }, { book.ribbons[1].length, book.ribbons[2].length })
		loaded.ns.guide:Close()

		assert.is_false(book:IsShown())
		assert.are.same({ SOUND_OPEN, SOUND_CLOSE }, loaded.client.sounds)
	end)
end)

describe("the Field guide's tour stops (ONB-R84)", function()
	it("show each step and leave guideStep, stepsSeen and the screen as they were", function()
		local loaded = withGuide()
		stillness(loaded)
		state(loaded).guideStep = "box"
		state(loaded).stepsSeen = { welcome = true, box = true }
		local stop
		for _, listed in ipairs(loaded.ns.tourStops:List(loaded.ns.Modules:Modules(), "core")) do
			if listed.name == "core.onboarding.step.board" then
				stop = listed
			end
		end

		stop.show()
		assert.are.equal("board", shownStep(loaded))
		stop.hide()

		assert.is_false(bookOf(loaded):IsShown())
		assert.are.equal("box", state(loaded).guideStep)
		assert.are.same({ welcome = true, box = true }, state(loaded).stepsSeen)
		assert.is_false(loaded.ns.lanes:IsHeld("guide"))
	end)
end)
