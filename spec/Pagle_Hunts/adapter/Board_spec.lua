-- The Hunts board's notebook on FakePagle (HNT-R60, HNT-R61, HNT-R67, HNT-R68, HNT-R70): the frame, how it opens,
-- moves and closes, the pages the router gives each mode, the leather's anchors, the binding, and its redraws. Its entry
-- points through Core's real logic are in Hunts_spec.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- Pagle_Hunts on a fake that has logged in, and its board as the shell alone: a router with no page renderers and a
-- leather whose anchors draw nothing, so the pages' own renderers (adapter/Timeline.lua, Entry.lua and Sets.lua) stay
-- out of these specs.
local function loggedIn()
	local loaded, fake = hunts.load()
	fake.login()
	local board = loaded.ns.board
	board.router = loaded.ns.NewBoardRouter()
	for _, part in ipairs({ "crumbs", "clock", "completed", "nameplate", "ribbons" }) do
		board:RegisterLeather(part, function() end)
	end
	return loaded, fake, board
end

-- The texts shown on the board's two papers, the left page's then the right's: what the renderers wrote, without the
-- leather's (the "?" beside the close, ONB-R59).
local function pageTexts(board)
	local texts = {}
	for _, side in ipairs({ "left", "right" }) do
		for _, text in ipairs(shownTexts(board.frame.paperFrames[side])) do
			texts[#texts + 1] = text
		end
	end
	return texts
end

-- A renderer that writes `label` and the place it was given on its page, once per page frame, and counts its draws.
local function writer(label, draws)
	return function(page, place)
		draws[#draws + 1] = { label = label, page = page, place = place }
		page.note = page.note or page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		page.note:SetText(("%s %s %s %s"):format(label, place.mode, place.set or "-", place.hunt or "-"))
	end
end

describe("the Hunts board's frame (HNT-R60)", function()
	it("is PagleHuntsBoard, about 920 × 600 (Tunables), and closed until opened", function()
		local _, _, board = loggedIn()

		assert.is_false(board:IsShown())
		board:Toggle()

		local frame = board.frame
		assert.are.equal("PagleHuntsBoard", frame.name)
		assert.are.same({ 920, 600 }, { frame.width, frame.height })
		assert.is_true(frame:IsShown())
	end)

	it("toggles open and closed through ns.ToggleBoard, Registration's view (HNT-R68)", function()
		local loaded, _, board = loggedIn()

		loaded.ns.ToggleBoard()
		assert.is_true(board:IsShown())
		loaded.ns.ToggleBoard()
		assert.is_false(board:IsShown())
	end)

	it("closes with Esc, being in UISpecialFrames, and with its close button", function()
		local loaded, _, board = loggedIn()
		board:Toggle()

		assert.is_true(loaded.env.UISpecialFrames[#loaded.env.UISpecialFrames] == "PagleHuntsBoard")
		loaded.client.pressEscape()
		assert.is_false(board:IsShown())

		board:Toggle()
		board.frame.close:Click()
		assert.is_false(board:IsShown())
	end)

	it("moves by dragging the leather, and the client saves no position", function()
		local _, _, board = loggedIn()
		board:Toggle()
		local frame = board.frame

		assert.is_true(frame:IsMovable())
		frame:GetScript("OnDragStart")(frame)
		assert.is_true(frame:IsUserPlaced())
		frame:GetScript("OnDragStop")(frame)

		assert.is_false(frame:IsUserPlaced())
	end)

	it("opens centred each time, wherever it was dragged to", function()
		local loaded, _, board = loggedIn()
		local centred = { { "CENTER", loaded.env.UIParent, "CENTER", 0, 40 } } -- 40 up, fitted to the screen
		board:Toggle()
		local frame = board.frame
		assert.are.same(centred, frame.points)

		-- Where a drag leaves it: the client re-anchors a moved frame by its top left.
		frame:GetScript("OnDragStart")(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", 40, -60)
		frame:GetScript("OnDragStop")(frame)
		board:Toggle()
		board:Toggle()

		assert.are.same(centred, frame.points)
	end)

	it("opens and stays open while restricted (HNT-R68)", function()
		local loaded, fake, board = loggedIn()
		fake.setRestricted(true)

		loaded.ns.ToggleBoard()
		assert.is_true(board:IsShown())
		fake.setRestricted(false)
		fake.setRestricted(true)

		assert.is_true(board:IsShown())
	end)
end)

describe("the Hunts board's pages, by the page router (HNT-R61, HNT-R66, HNT-R67)", function()
	it("draws each page of the mode shown with the renderer registered for it, on that page's own frame", function()
		local loaded, _, board = loggedIn()
		local draws = {}
		board:RegisterPage("board", "left", writer("timeline", draws))
		board:RegisterPage("board", "right", writer("entry", draws))

		loaded.ns.ToggleBoard()

		assert.are.same({ "timeline", "entry" }, { draws[1].label, draws[2].label })
		assert.are_not.equal(draws[1].page, draws[2].page)
		assert.are.same({ "timeline board - -", "entry board - -" }, pageTexts(board))
	end)

	it("leaves a page blank in a mode with no renderer for it", function()
		local _, _, board = loggedIn()
		local draws = {}
		board:RegisterPage("board", "left", writer("timeline", draws))
		board:RegisterPage("board", "right", writer("entry", draws))
		board:RegisterPage("set", "right", writer("set page", draws))

		board:Open({ mode = "set", set = "fixture_dusk" })

		assert.are.same({ "set page set fixture_dusk -" }, pageTexts(board))
		board:Open({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" })
		assert.are.same({}, pageTexts(board))
	end)

	it("gives each set's page its own frames, so a page can turn from one to the next", function()
		local _, _, board = loggedIn()
		local draws = {}
		board:RegisterPage("set", "right", writer("set page", draws))

		board:Open({ mode = "set", set = "fixture_dusk" })
		board:Open({ mode = "set", set = "fixture_wagers" })
		board:Open({ mode = "set", set = "fixture_dusk" })

		assert.are_not.equal(draws[1].page, draws[2].page)
		assert.are.equal(draws[1].page, draws[3].page)
		assert.are.same({ "set page set fixture_dusk -" }, pageTexts(board))
	end)

	it("gives a renderer registered on two modes a frame for each", function()
		local _, _, board = loggedIn()
		local draws = {}
		local timeline = writer("timeline", draws)
		board:RegisterPage("board", "left", timeline)
		board:RegisterPage("set", "left", timeline)

		board:Toggle()
		board:Open({ mode = "set", set = "fixture_wagers" })

		assert.are_not.equal(draws[1].page, draws[2].page)
		assert.are.same({ "timeline set fixture_wagers -" }, pageTexts(board))
	end)

	it("opens on the Board mode each time, whatever mode it closed on (HNT-R67)", function()
		local _, _, board = loggedIn()
		board:Open({ mode = "set", set = "fixture_dusk" })
		board:Toggle()

		board:Toggle()

		assert.are.same({ mode = "board" }, board.router:Place())
	end)

	it("opens on the Board mode with that Hunt asked for, from ns.OpenBoard(huntID) (HNT-R67, HNT-R77)", function()
		local loaded, _, board = loggedIn()
		local draws = {}
		board:RegisterPage("board", "right", writer("entry", draws))

		loaded.ns.OpenBoard("fixture_snapper")

		assert.is_true(board:IsShown())
		assert.are.same({ mode = "board", hunt = "fixture_snapper" }, draws[1].place)
	end)

	it("never closes from ns.OpenBoard: open on a set, it turns to the Board on that Hunt in place", function()
		local loaded, _, board = loggedIn()
		board:Open({ mode = "set", set = "fixture_dusk" })
		local frame = board.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", 40, -60)

		loaded.ns.OpenBoard("fixture_rack")
		loaded.ns.OpenBoard()

		assert.is_true(board:IsShown())
		assert.are.same({ mode = "board" }, board.router:Place())
		assert.are.same({ { "TOPLEFT", 40, -60 } }, frame.points)
	end)

	it("hands a renderer a copy of the place, so changing it moves nothing", function()
		local _, _, board = loggedIn()
		board:RegisterPage("board", "left", function(_, place)
			place.mode = "set"
		end)

		board:Toggle()

		assert.are.same({ mode = "board" }, board.router:Place())
	end)
end)

describe("the Hunts board's leather (HNT-R61)", function()
	it("has an anchor for the crumbs, the clock, the checkbox, the nameplate and the ribbons", function()
		local _, _, board = loggedIn()
		board:Toggle()

		local missing = {}
		for _, part in ipairs({ "crumbs", "clock", "completed", "nameplate", "ribbons" }) do
			if type(board.frame.anchors[part]) ~= "table" then
				missing[#missing + 1] = part
			end
		end
		assert.are.same({}, missing)
	end)

	it("draws each anchor's renderer after the pages, so it sees the Hunt the timeline selected", function()
		local _, _, board = loggedIn()
		local order, seen = {}, nil
		board:RegisterPage("board", "left", function()
			order[#order + 1] = "left"
			board:Select("fixture_snapper")
		end)
		board:RegisterPage("board", "right", function()
			order[#order + 1] = "right"
		end)
		board:RegisterLeather("crumbs", function(anchor, place)
			order[#order + 1] = "crumbs"
			assert.are.equal(board.frame.anchors.crumbs, anchor)
			seen = place
		end)

		board:Toggle()

		assert.are.same({ "left", "right", "crumbs" }, order)
		assert.are.same({ mode = "board", hunt = "fixture_snapper" }, seen)
		assert.are.equal(2, #board.router:Trail())
	end)

	it("refuses an anchor it doesn't have", function()
		local _, _, board = loggedIn()

		assert.has_error(function()
			board:RegisterLeather("bookmark", function() end)
		end, "the Hunts board's leather has no anchor bookmark")
	end)
end)

describe("the Hunts board's binding (HNT-R70)", function()
	it("wears Core's binding on its frame, following the equipped one, and tints its pages' paper", function()
		local _, _, board = loggedIn()
		board:Toggle()

		local binding = board.frame.binding
		assert.is_nil(binding.pinned) -- it follows the equipped binding (BIND-R1)
		assert.are.equal(binding:Look(), board:Look())
		for _, side in ipairs({ "left", "right" }) do
			assert.are.same(binding:Look().paperTint, board.frame.papers[side].paper.vertexColor)
		end
	end)

	it("inks its crumbs and nameplate again from each new look while open (BIND-R3)", function()
		local _, _, board = loggedIn()
		local inked = {}
		board:RegisterLeather("crumbs", function()
			inked[#inked + 1] = { "crumbs", board:Look().id }
		end)
		board:RegisterLeather("nameplate", function()
			inked[#inked + 1] = { "nameplate", board:Look().id }
		end)
		board:Toggle()
		inked = {}

		board.frame.binding:SetLook("hunts.binding.fiveseal")

		assert.are.same({ { "crumbs", "hunts.binding.fiveseal" }, { "nameplate", "hunts.binding.fiveseal" } }, inked)
		assert.are.same({ 0.95, 0.97, 1 }, board.frame.papers.left.paper.vertexColor)
	end)

	it("keeps a binding pinned before the board was first opened, and follows the equipped one again after", function()
		local _, _, board = loggedIn()

		board:SetBinding("hunts.binding.pathfinder")
		board:Toggle()
		assert.are.equal("hunts.binding.pathfinder", board.frame.binding.pinned)
		assert.are.equal("hunts.binding.pathfinder", board:Look().id)

		board:SetBinding(nil)
		assert.is_nil(board.frame.binding.pinned)
	end)

	it("hangs the ribbons' tops under the binding's band, whatever the binding", function()
		local loaded, _, board = loggedIn()
		board:Toggle()
		local ribbons = board.frame.anchors.ribbons
		local tuck = loaded.ns.BOARD_RIBBON.tuck
		assert.are.same({ "TOPLEFT", board.frame, "TOPLEFT", 176, -(600 - tuck) }, ribbons.points[1])

		board:SetBinding("hunts.binding.wagersilk")

		assert.are.same({ "TOPLEFT", board.frame, "TOPLEFT", 176, -(600 - tuck) }, ribbons.points[1])
	end)
end)

describe("the Hunts board's redraws (HNT-R42)", function()
	it("redraws the mode shown at each ns.Redraw while shown, and not while closed", function()
		local loaded, _, board = loggedIn()
		local draws = {}
		board:RegisterPage("set", "left", writer("timeline", draws))
		board:Open({ mode = "set", set = "fixture_dusk" })

		loaded.ns.Redraw("groups")
		loaded.ns.Redraw("projection")
		assert.are.equal(3, #draws)
		assert.are.same({ mode = "set", set = "fixture_dusk" }, draws[3].place)

		board:Toggle()
		loaded.ns.Redraw("names")
		assert.are.equal(3, #draws)
	end)

	it("tells the grouping when it shows and hides, once each, however it closes (HNT-R42's refresh)", function()
		local loaded, _, board = loggedIn()
		local told = {}
		loaded.ns.SetViewShown = function(view, shown)
			told[#told + 1] = view .. " " .. tostring(shown)
		end

		board:Toggle()
		board:Toggle()
		board:Toggle()
		board.frame.close:Click()
		loaded.ns.OpenBoard("fixture_snapper")
		loaded.ns.OpenBoard("fixture_rack")
		loaded.client.pressEscape()

		assert.are.same({
			"board true",
			"board false",
			"board true",
			"board false",
			"board true",
			"board false",
		}, told)
	end)
end)
