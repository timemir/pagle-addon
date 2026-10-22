-- The Tackle Board's frame on FakePagle (TKB-R100, TKB-R101, TKB-R107, TKB-R108, TKB-R109, TKB-R193): the leather frame,
-- how it opens, moves and closes, the empty board with Start, the updating state, the parts and their redraws. Its
-- entry points through Core's real logic are in TackleBoard_spec.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

-- Pagle_TackleBoard on a fake that has logged in, its board as the shell alone (no part renderers), and seams for the
-- board's two flags that a spec sets: `flags.started` (ns.IsStarted) and `flags.updating` (ns.IsUpdating).
local function loggedIn()
	local loaded, fake = board.load()
	fake.login()
	local flags = { started = false, updating = false }
	loaded.ns.IsStarted = function()
		return flags.started
	end
	loaded.ns.IsUpdating = function()
		return flags.updating
	end
	local tackle = loaded.ns.board
	tackle.parts = loaded.ns.NewBoardParts()
	return loaded, fake, tackle, flags
end

-- Hides `frame` as the client does, running its OnHide (the fake's Hide runs no script).
local function hide(frame)
	if frame:IsShown() then
		frame:Hide()
		local onHide = frame:GetScript("OnHide")
		if onHide then
			onHide(frame)
		end
	end
end

-- Presses Esc: CloseSpecialWindows hides every shown frame named in UISpecialFrames.
local function escape(loaded)
	for _, name in ipairs(loaded.env.UISpecialFrames) do
		for _, frame in ipairs(loaded.client.frames) do
			if frame.name == name then
				hide(frame)
			end
		end
	end
end

-- Whether `widget` and every parent up to `top` are shown.
local function visible(widget, top)
	while widget do
		if not widget:IsShown() then
			return false
		end
		if widget == top then
			return true
		end
		widget = widget:GetParent()
	end
	return true
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

-- A renderer that writes `label` on its part's frame, once per frame, and records each draw.
local function writer(label, draws)
	return function(frame, draw)
		draws[#draws + 1] = { label = label, frame = frame, draw = draw }
		frame.note = frame.note or frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		frame.note:SetText(label)
	end
end

-- The texts shown on the cork, then on the ledge: what the board says under its plaque.
local function boardTexts(frame)
	return textsOf(frame.ledge, textsOf(frame.cork))
end

local EMPTY_SLIP = "Three Notices go up each day and an Expedition each week. Fish as you like: they fill in as you go. "
	.. "Nothing is ever taken down for being late."

describe("the Tackle Board's frame (TKB-R100)", function()
	it("is PagleTackleBoard, 1000 × 660 as the board art kit's, and closed until opened", function()
		local _, _, tackle = loggedIn()

		assert.is_false(tackle:IsShown())
		tackle:Toggle()

		local frame = tackle.frame
		assert.are.equal("PagleTackleBoard", frame.name)
		assert.are.same({ 1000, 660 }, { frame.width, frame.height })
		assert.is_true(frame:IsShown())
	end)

	it('wears the kit frame with a brass plaque reading "Tackle Board", round the cork, with a ledge below', function()
		local loaded, _, tackle = loggedIn()
		tackle:Toggle()
		local frame = tackle.frame

		assert.are.equal("T A C K L E   B O A R D", frame.plaque.label:GetText())
		assert.are.equal(loaded.ns.BOARD_ATLASES.Frame.file, frame.art.texture)
		assert.are.same({ 952, 466 }, { frame.cork.width, frame.cork.height })
		assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 24, -34 }, frame.cork.points[1])
		assert.are.same({ 1000, 160 }, { frame.ledge.width, frame.ledge.height })
		assert.are.same({ "TOPLEFT", frame, "TOPLEFT", 0, -500 }, frame.ledge.points[1])
	end)

	it("lays one cork tile across the cork, and the Campfire's glow faintly over it before Start", function()
		local loaded, _, tackle = loggedIn()
		tackle:Toggle()
		local frame = tackle.frame

		assert.are.equal("ADD", frame.glow.blendMode)
		assert.is_true(frame.glow:IsShown())
		assert.is_true(math.abs(frame.glow:GetAlpha() - 0.25 * 0.9) < 1e-6) -- its breath starts at 0.9
		local tiles = 0
		for _, region in ipairs(frame.cork.children) do
			if region.texture == loaded.ns.CORK_TEXTURE then
				tiles = tiles + 1
				assert.are.same({ 0, 952 / 384, 0, 466 / 384 }, region.texCoord)
			end
		end
		assert.are.equal(1, tiles)
	end)

	it("toggles open and closed through ns.ToggleBoard, Registration's view (TKB-R1)", function()
		local loaded, _, tackle = loggedIn()

		loaded.ns.ToggleBoard()
		assert.is_true(tackle:IsShown())
		loaded.ns.ToggleBoard()
		assert.is_false(tackle:IsShown())
	end)

	it("closes with Esc, being in UISpecialFrames, and with its close button", function()
		local loaded, _, tackle = loggedIn()
		tackle:Toggle()

		assert.are.equal("PagleTackleBoard", loaded.env.UISpecialFrames[#loaded.env.UISpecialFrames])
		escape(loaded)
		assert.is_false(tackle:IsShown())

		tackle:Toggle()
		tackle.frame.close:Click()
		assert.is_false(tackle:IsShown())
	end)

	it("moves by dragging, and the client saves no position", function()
		local _, _, tackle = loggedIn()
		tackle:Toggle()
		local frame = tackle.frame

		assert.is_true(frame:IsMovable())
		frame:GetScript("OnDragStart")(frame)
		assert.is_true(frame:IsUserPlaced())
		frame:GetScript("OnDragStop")(frame)

		assert.is_false(frame:IsUserPlaced())
	end)

	it("opens centred each time, wherever it was dragged to", function()
		local loaded, _, tackle = loggedIn()
		tackle:Toggle()
		local frame = tackle.frame
		-- Core's fit (Pagle.FitToScreen): its centre 10 under the screen's, with the plaque over its top edge.
		local centred = { { "CENTER", loaded.env.UIParent, "CENTER", 0, -10 } }
		assert.are.same(centred, frame.points)

		-- Where a drag leaves it: the client re-anchors a moved frame by its top left.
		frame:GetScript("OnDragStart")(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", 40, -60)
		frame:GetScript("OnDragStop")(frame)
		tackle:Toggle()
		tackle:Toggle()

		assert.are.same(centred, frame.points)
	end)

	it("never closes from ns.OpenBoard, and stays where it was dragged while open", function()
		local loaded, _, tackle = loggedIn()
		tackle:Toggle()
		local frame = tackle.frame
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", 40, -60)

		loaded.ns.OpenBoard()
		loaded.ns.OpenBoard("goal")

		assert.is_true(tackle:IsShown())
		assert.are.same({ { "TOPLEFT", 40, -60 } }, frame.points)
	end)

	it("opens and stays open while restricted, and its Start button works there (TKB-R193)", function()
		local loaded, fake, tackle = loggedIn()
		local started = 0
		loaded.ns.Start = function()
			started = started + 1
		end
		fake.setRestricted(true)

		loaded.ns.ToggleBoard()
		assert.is_true(tackle:IsShown())
		tackle.frame.start:Click()
		fake.setRestricted(false)
		fake.setRestricted(true)

		assert.is_true(tackle:IsShown())
		assert.are.equal(1, started)
	end)
end)

describe("the empty board (TKB-R107)", function()
	it("shows one pinned slip on bare cork, with an enabled Start my board below its words", function()
		local _, _, tackle = loggedIn()
		tackle:Toggle()
		local frame = tackle.frame

		assert.are.same({ EMPTY_SLIP, "Start my board" }, textsOf(frame.cork))
		assert.is_true(visible(frame.start, frame))
		assert.is_true(frame.start:IsEnabled())
		assert.is_false(visible(frame.updating, frame))
	end)

	it("calls ns.Start() from Start my board as it is when clicked, then redraws (TKB-R5)", function()
		local loaded, _, tackle, flags = loggedIn()
		tackle:Toggle()
		loaded.ns.Start = function()
			flags.started = true
		end

		tackle.frame.start:Click()

		assert.is_false(visible(tackle.frame.start, tackle.frame))
		assert.is_false(visible(tackle.frame.empty, tackle.frame))
	end)

	it("draws no part before Start, even one with a renderer: the cork and the ledge stay bare", function()
		local _, _, tackle = loggedIn()
		local draws = {}
		for _, part in ipairs({ "pins", "overflow", "spike", "ledge" }) do
			tackle:RegisterPart(part, writer(part, draws))
		end

		tackle:Toggle()

		assert.are.same({}, draws)
		for _, part in ipairs({ "pins", "overflow", "spike", "ledge" }) do
			assert.is_false(tackle.frame.parts[part]:IsShown())
		end
	end)
end)

describe("the updating board (TKB-R108)", function()
	it('shows "Updating…" over the cork and disables Start my board before Start (TKB-R5)', function()
		local loaded, _, tackle, flags = loggedIn()
		local started = 0
		loaded.ns.Start = function()
			started = started + 1
		end
		flags.updating = true

		tackle:Toggle()
		local frame = tackle.frame

		assert.is_true(visible(frame.updating, frame))
		assert.are.equal("Updating…", frame.updating.label:GetText())
		assert.is_true(frame.updating:GetFrameLevel() > frame.empty:GetFrameLevel())
		assert.is_true(visible(frame.start, frame))
		assert.is_false(frame.start:IsEnabled())
		frame.start:Click()
		assert.are.equal(0, started)
	end)

	it("tells the parts through ns.board:IsUpdating() and their draw, and still draws them once started", function()
		local _, _, tackle, flags = loggedIn()
		local draws = {}
		tackle:RegisterPart("pins", writer("pins", draws))
		flags.started, flags.updating = true, true

		tackle:Toggle()

		assert.is_true(tackle:IsUpdating())
		assert.is_true(draws[1].draw.updating)
		assert.is_true(visible(tackle.frame.updating, tackle.frame))
		assert.is_false(visible(tackle.frame.start, tackle.frame))
	end)

	it('takes "Updating…" away and enables Start at the redraw after the update', function()
		local loaded, _, tackle, flags = loggedIn()
		flags.updating = true
		tackle:Toggle()

		flags.updating = false
		loaded.ns.Redraw("projection")

		assert.is_false(tackle:IsUpdating())
		assert.is_false(visible(tackle.frame.updating, tackle.frame))
		assert.is_true(tackle.frame.start:IsEnabled())
	end)
end)

describe("a started board while its projection rebuilds in chunks (TKB-R6, TKB-R108, LOG-R72)", function()
	-- A board started an hour ago with its four goals, built; then a rebuild that runs over later frames, whose state
	-- hasn't applied the `start` record yet; the Campfire card was open.
	local function rebuilding()
		local fake = board.withHistory({
			board.skill(SERVER_TIME - 3600),
			board.start(SERVER_TIME - 600),
			board.issue(SERVER_TIME - 599, "e;quality;0;60;3;3"),
			board.issue(SERVER_TIME - 598, "n;haul;2;15;30;14"),
		})
		local ns, loaded = board.built(fake)
		ns.OpenBoard()
		local ledge = (ns.board.frame --[[@as TackleBoardFrame]]).parts.ledge --[[@as TackleLedgeFrame]]
		ledge.fire:Click()
		assert.is_true(ledge.card:IsShown())
		board.updating(fake, true)
		ns.projection:Rebuild()
		ns.Redraw("projection")
		return ns, loaded, fake
	end

	it('shows "Updating…" over the bare cork, with no slip, no Start and the card closed', function()
		local ns = rebuilding()
		local frame = ns.board.frame --[[@as TackleBoardFrame]]

		assert.is_true(ns.IsUpdating())
		assert.is_false(ns.IsStarted()) -- the rebuild's state, not yet past the start record
		assert.is_true(ns.KnownStarted())
		assert.is_true(visible(frame.updating, frame))
		assert.is_false(visible(frame.empty, frame))
		assert.is_false(visible(frame.start, frame))
		for _, part in ipairs(ns.BOARD_PARTS) do
			assert.is_false(frame.parts[part]:IsShown())
		end
		assert.is_false((frame.parts.ledge --[[@as TackleLedgeFrame]]).card:IsShown())
	end)

	it("draws its parts again once the rebuild is done", function()
		local ns, _, fake = rebuilding()
		local frames = 0
		while ns.IsUpdating() and frames < 50 do
			fake.nextFrame()
			frames = frames + 1
		end
		local frame = ns.board.frame --[[@as TackleBoardFrame]]

		assert.is_false(ns.IsUpdating())
		assert.is_false(visible(frame.updating, frame))
		assert.is_false(visible(frame.empty, frame))
		for _, part in ipairs(ns.BOARD_PARTS) do
			-- the overflow strip shows only while a goal hangs in it, and none does here (TKB-R101)
			assert.are.equal(part ~= "overflow", frame.parts[part]:IsShown(), part)
		end
	end)

	it('keeps "Open Tackle Board" on the Settings root and the Trackers checkbox live (TKB-R1, SET-R43)', function()
		local ns, _, fake = rebuilding()

		assert.are.equal("Open Tackle Board", ns.ModuleDef().settingsAction.label())
		local enabled = {}
		for _, row in ipairs(fake.settingsPage("trackers")) do
			if row.label == "Show goals workable here" then
				enabled[#enabled + 1] = row.setting.isEnabled()
			end
		end
		assert.are.same({ true }, enabled)
	end)
end)

describe("the started board's parts (TKB-R101, TKB-R103, TKB-R106)", function()
	it("has no Start button and no slip once started (TKB-R5)", function()
		local _, _, tackle, flags = loggedIn()
		flags.started = true

		tackle:Toggle()

		assert.is_false(visible(tackle.frame.start, tackle.frame))
		assert.are.same({}, boardTexts(tackle.frame))
	end)

	it("draws each registered part on its own frame, in its place, in drawing order", function()
		local _, _, tackle, flags = loggedIn()
		flags.started = true
		local draws = {}
		for _, part in ipairs({ "ledge", "spike", "overflow", "pins" }) do
			tackle:RegisterPart(part, writer(part, draws))
		end

		tackle:Toggle()

		local frame, parts = tackle.frame, tackle.frame.parts
		local order = {}
		for i, draw in ipairs(draws) do
			order[i] = draw.label
			assert.are.equal(parts[draw.label], draw.frame)
		end
		assert.are.same({ "pins", "overflow", "spike", "ledge" }, order)
		-- The kit's places: the pins at the cork's top left, the strip under the Notice rows, the spike on the right
		-- and the ledge's contents on the ledge.
		assert.are.same({ "TOPLEFT", frame.cork, "TOPLEFT", 0, 0 }, parts.pins.points[1])
		assert.are.same({ "TOPLEFT", frame.cork, "TOPLEFT", 24, -424 }, parts.overflow.points[1])
		assert.are.same({ "TOPLEFT", frame.cork, "TOPLEFT", 792, -14 }, parts.spike.points[1])
		assert.are.equal(frame.ledge, parts.ledge:GetParent())
		assert.are.same({ "pins", "overflow", "spike", "ledge" }, boardTexts(frame))
	end)

	it("gives the pins part a slot per pin, as the kit pins them: 2 Expedition posters, 6 Notice papers", function()
		local _, _, tackle, flags = loggedIn()
		flags.started = true
		tackle:Toggle()
		local slots = tackle.frame.parts.pins.slots

		local function places(list)
			local out = {}
			for i, slot in ipairs(list) do
				local point = slot.points[1]
				out[i] = { point[4], point[5], slot.width, slot.height }
			end
			return out
		end
		assert.are.same({ { 26, -22, 360, 156 }, { 412, -26, 360, 156 } }, places(slots.expeditions))
		assert.are.same({
			{ 26, -208, 236, 116 },
			{ 284, -212, 236, 116 },
			{ 542, -206, 236, 116 },
			{ 26, -334, 236, 116 },
			{ 286, -338, 236, 116 },
			{ 544, -336, 236, 116 },
		}, places(slots.notices))
	end)

	it("leaves a part with no renderer bare", function()
		local _, _, tackle, flags = loggedIn()
		flags.started = true
		local draws = {}
		tackle:RegisterPart("spike", writer("spike", draws))

		tackle:Toggle()

		assert.are.same({ "spike" }, boardTexts(tackle.frame))
		assert.are.equal(1, #draws)
	end)

	it("refuses a part the board doesn't have", function()
		local _, _, tackle = loggedIn()

		assert.has_error(function()
			tackle:RegisterPart("drawer", function() end)
		end, "the Tackle Board has no part drawer")
	end)
end)

describe("opening on a goal (TKB-R109)", function()
	it("hands ns.OpenBoard's goal ID to the parts on the draw that opens it, and only on that one", function()
		local loaded, _, tackle, flags = loggedIn()
		flags.started = true
		local draws = {}
		tackle:RegisterPart("pins", writer("pins", draws))

		loaded.ns.OpenBoard("Player-4618-0A1B2C3D-1791731747-0")
		loaded.ns.Redraw("projection")

		assert.are.same(
			{ "open", "Player-4618-0A1B2C3D-1791731747-0" },
			{ draws[1].draw.reason, draws[1].draw.highlight }
		)
		assert.are.same({ "projection", nil }, { draws[2].draw.reason, draws[2].draw.highlight })
	end)

	it("hands it on when the board is already open, too, and none from a plain toggle", function()
		local loaded, _, tackle, flags = loggedIn()
		flags.started = true
		local draws = {}
		tackle:RegisterPart("pins", writer("pins", draws))

		loaded.ns.ToggleBoard()
		loaded.ns.OpenBoard("goal-2")

		assert.is_nil(draws[1].draw.highlight)
		assert.are.equal("goal-2", draws[2].draw.highlight)
	end)
end)

describe("the board's redraws (ns.OnRedraw; TKB-R101, TKB-R107)", function()
	it("redraws every part at each ns.Redraw while open, with its reason and detail, and not while closed", function()
		local loaded, _, tackle, flags = loggedIn()
		flags.started = true
		local draws = {}
		for _, part in ipairs({ "pins", "overflow", "spike", "ledge" }) do
			tackle:RegisterPart(part, writer(part, draws))
		end
		tackle:Toggle()

		loaded.ns.Redraw("completed", "goal-1")
		assert.are.equal(8, #draws)
		for i = 5, 8 do
			assert.are.same({ "completed", "goal-1" }, { draws[i].draw.reason, draws[i].draw.detail })
		end

		tackle:Toggle()
		loaded.ns.Redraw("names")
		loaded.ns.Redraw("step")
		assert.are.equal(8, #draws)
	end)

	it("shows the started board at the redraw after Start, with no Start button", function()
		local loaded, _, tackle, flags = loggedIn()
		tackle:Toggle()
		assert.is_true(visible(tackle.frame.start, tackle.frame))

		flags.started = true
		loaded.ns.Redraw("step")

		assert.is_false(visible(tackle.frame.start, tackle.frame))
		assert.is_true(tackle.frame.parts.pins:IsShown())
	end)
end)
