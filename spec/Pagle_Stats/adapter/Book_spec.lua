-- The Stats book on FakePagle (STA-R70–R75, STA-R93; stats.md › UI › On the leather): the frame, how it opens, moves
-- and closes, the pages the router gives each target, the leather (breadcrumbs, ribbons, nameplate, live line), the
-- updating state and the redraws. Its entry points through Core's real logic are in Stats_spec.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, ELWYNN = I.DARKSHORE, I.AUBERDINE, I.ELWYNN
local NIGHTFIN, BLACKMOUTH = I.NIGHTFIN, I.BLACKMOUTH

-- Pagle_Stats on a fake that has logged in, its projection built (not updating), and its book. The areas have their
-- names and the items don't; the player fishes Auberdine.
---@return LoadedAddon loaded
---@return table fake
---@return table book the book as the fake client drew it: its frame and widgets carry the fake's fields (`name`,
--- `points`, `shown`, `text`, …, spec/support/widgets.lua), which StatsBook's WoW widget types don't declare
local function ready()
	return stats.start({ items = {}, at = { zone = DARKSHORE, subzone = AUBERDINE } })
end

-- Presses Esc: CloseSpecialWindows hides every shown frame named in UISpecialFrames (the fake's Hide runs its
-- OnHide, as the client's does).
local function escape(loaded)
	for _, name in ipairs(loaded.env.UISpecialFrames) do
		for _, frame in ipairs(loaded.client.frames) do
			if frame.name == name and frame:IsShown() then
				frame:Hide()
			end
		end
	end
end

local textsOf = stats.textsOf

-- A renderer that writes `label` and the place it was given on its content frame, and counts its draws.
local function writer(label, draws, height)
	return function(content, place)
		draws[#draws + 1] = { label = label, content = content, place = place }
		content.note = content.note or content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		content.note:SetText(("%s %s %s"):format(label, place.page, tostring(place.area or place.item or "-")))
		return height
	end
end

-- What the breadcrumbs read now: each shown crumb's words.
local function crumbsOf(book)
	local out = {}
	for _, crumb in ipairs(book.frame.crumbButtons) do
		if crumb.shown then
			out[#out + 1] = crumb.label.text
		end
	end
	return out
end

-- The shown crumb whose words are `text`.
local function crumbNamed(book, text)
	for _, crumb in ipairs(book.frame.crumbButtons) do
		if crumb.shown and crumb.label.text == text then
			return crumb
		end
	end
	error("no crumb " .. text)
end

describe("the Stats book's frame (STA-R70, STA-R71)", function()
	it("is PagleStatsBook, about 980 × 640 (Tunables), closed until opened, toggled by ns.ToggleBook", function()
		local loaded, _, book = ready()

		assert.is_false(book:IsShown())
		loaded.ns.ToggleBook()

		local frame = book.frame
		assert.are.equal("PagleStatsBook", frame.name)
		assert.are.same({ 980, 640 }, { frame.width, frame.height })
		assert.is_true(book:IsShown())
		loaded.ns.ToggleBook()
		assert.is_false(book:IsShown())
	end)

	it("closes with Esc, being in UISpecialFrames, and with its close button", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()

		assert.are.equal("PagleStatsBook", loaded.env.UISpecialFrames[#loaded.env.UISpecialFrames])
		escape(loaded)
		assert.is_false(book:IsShown())

		loaded.ns.ToggleBook()
		book.frame.close:Click()
		assert.is_false(book:IsShown())
	end)

	it("is a plain frame: it opens and works while restricted (STA-R71, STA-R93)", function()
		local loaded, fake, book = ready()
		fake.setRestricted(true)
		local draws = {}
		book:RegisterPage("lifetime", "left", writer("lifetime", draws))

		loaded.ns.ToggleBook()
		book.frame.ribbons[3]:Click()

		assert.is_true(book:IsShown())
		assert.are.same({ page = "lifetime" }, draws[1].place)
	end)

	it("opens centred, lifted 40, while it has no saved position (BOOK-R5)", function()
		local loaded, fake, book = ready()

		loaded.ns.ToggleBook()

		assert.is_nil(fake.profile.books.stats)
		assert.are.same({ { "CENTER", loaded.env.UIParent, "CENTER", 0, 40 } }, book.frame.points)
	end)

	it(
		"moves by dragging the leather, saves where it was left in Core's profile.books, and opens there next",
		function()
			local loaded, fake, book = ready()
			loaded.ns.ToggleBook()
			local frame = book.frame
			assert.is_true(frame:IsMovable())

			-- Where a drag leaves it: the client re-anchors a moved frame by its top left.
			frame:GetScript("OnDragStart")(frame)
			frame:ClearAllPoints()
			frame:SetPoint("TOPLEFT", loaded.env.UIParent, "BOTTOMLEFT", 120, 700)
			frame:GetScript("OnDragStop")(frame)

			assert.are.same({ "TOPLEFT", "BOTTOMLEFT", 120, 700 }, fake.profile.books.stats)
			assert.is_false(frame:IsUserPlaced()) -- the client saves nothing itself
			loaded.ns.ToggleBook()
			frame:ClearAllPoints()
			loaded.ns.ToggleBook()
			assert.are.same({ { "TOPLEFT", loaded.env.UIParent, "BOTTOMLEFT", 120, 700 } }, frame.points)
		end
	)

	it("opens where its saved position puts it after a /reload (STA-R71, BOOK-R5)", function()
		local fake = newFakePagle()
		fake.profile.books = { stats = { "TOPLEFT", "BOTTOMLEFT", 40, 600 } }
		local loaded = stats.load(fake)
		fake.login()

		loaded.ns.ToggleBook()

		assert.are.same({ { "TOPLEFT", loaded.env.UIParent, "BOTTOMLEFT", 40, 600 } }, loaded.ns.book.frame.points)
	end)

	-- The book's first anchor, in UIParent's units: its offsets times its scale.
	local function onScreen(frame)
		local point = frame.points[1]
		local scale = frame:GetScale()
		return { point[1], point[3], math.floor(point[4] * scale + 0.5), math.floor(point[5] * scale + 0.5) }
	end

	it("saves its place in UIParent's units, so it opens there after the UI scale changes (STA-R71)", function()
		local loaded, fake, book = ready()
		local screen = loaded.env.UIParent
		screen:SetSize(2560, 1440)
		loaded.ns.ToggleBook()
		local frame = book.frame
		frame:GetScript("OnDragStart")(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 120, 700)
		frame:GetScript("OnDragStop")(frame)
		loaded.ns.ToggleBook()

		screen:SetSize(1188, 668) -- a 1366 × 768 screen at UI scale 1.15
		loaded.client.fireGameEvent("UI_SCALE_CHANGED")
		loaded.ns.ToggleBook()

		assert.is_true(frame:GetScale() < 1)
		assert.are.same({ "TOPLEFT", "BOTTOMLEFT", 120, 700 }, onScreen(frame))
		frame:GetScript("OnDragStart")(frame)
		frame:GetScript("OnDragStop")(frame) -- left where it is: saved as it was
		local window = fake.profile.books.stats
		assert.are.same(
			{ "TOPLEFT", "BOTTOMLEFT", 120, 700 },
			{ window[1], window[2], math.floor(window[3] + 0.5), math.floor(window[4] + 0.5) }
		)
	end)

	it("keeps its place on the screen when it is fitted again while open (STA-R71)", function()
		local loaded, fake, book = ready()
		local screen = loaded.env.UIParent
		screen:SetSize(2560, 1440)
		loaded.ns.ToggleBook()
		local frame = book.frame
		frame:GetScript("OnDragStart")(frame)
		frame:ClearAllPoints()
		frame:SetPoint("TOPLEFT", screen, "BOTTOMLEFT", 120, 700)
		frame:GetScript("OnDragStop")(frame)

		screen:SetSize(1188, 668)
		loaded.client.fireGameEvent("DISPLAY_SIZE_CHANGED")

		assert.is_true(frame:GetScale() < 1)
		assert.are.same({ "TOPLEFT", "BOTTOMLEFT", 120, 700 }, onScreen(frame))
		assert.are.same({ "TOPLEFT", "BOTTOMLEFT", 120, 700 }, fake.profile.books.stats)
	end)
end)

describe("the Stats book's pages (STA-R70, STA-R74)", function()
	it(
		"draws each side of the page shown with its renderer, on its own frame, and leaves a side with none blank",
		function()
			local loaded, fake, book = ready()
			-- without the page tickets' renderers
			book.shell.router = fake.ns.NewBookRouter(loaded.ns.BOOK_PAGES, { page = "home" })
			local draws = {}
			book:RegisterPage("home", "left", writer("waters", draws))
			book:RegisterPage("home", "right", writer("right now", draws))
			book:RegisterPage("lifetime", "right", writer("every fish", draws))

			loaded.ns.ToggleBook()
			assert.are.same({ "waters home -" }, textsOf(book.frame.papers.left))
			assert.are.same({ "right now home -" }, textsOf(book.frame.papers.right))
			assert.are_not.equal(draws[1].content, draws[2].content)
			loaded.ns.OpenBook({ page = "lifetime" })

			assert.are.same({}, textsOf(book.frame.papers.left))
			assert.are.same({ "every fish lifetime -" }, textsOf(book.frame.papers.right))
		end
	)

	it("opens on the home spread at the first opening, then where it was left, with its choice (STA-R70)", function()
		local loaded, _, book = ready()

		loaded.ns.ToggleBook()
		assert.are.same({ page = "home" }, book:Place())
		loaded.ns.OpenBook({ page = "place", area = AUBERDINE, item = NIGHTFIN })
		loaded.ns.ToggleBook()
		loaded.ns.ToggleBook()
		assert.are.same({ page = "place", area = AUBERDINE, item = NIGHTFIN }, book:Place())
		loaded.ns.OpenBook({ page = "sessions", session = "S-2", ledgerPage = 3 })
		escape(loaded)
		loaded.ns.ToggleBook()

		assert.are.same({ page = "sessions", session = "S-2", ledgerPage = 3 }, book:Place())
	end)

	it("opens on the home spread again after a /reload, whatever it was left on (STA-R70)", function()
		local loaded = ready()
		loaded.ns.OpenBook({ page = "lifetime" })

		local reloaded = ready()
		reloaded.ns.ToggleBook()

		assert.are.same({ page = "home" }, reloaded.ns.book:Place())
	end)

	it("never closes from ns.OpenBook: open, it turns to the target in place; with none, where it was left", function()
		local loaded, _, book = ready()
		loaded.ns.OpenBook({ page = "lifetime" })
		assert.is_true(book:IsShown())

		loaded.ns.OpenBook({ page = "item", item = NIGHTFIN })
		loaded.ns.OpenBook()

		assert.is_true(book:IsShown())
		assert.are.same({ page = "item", item = NIGHTFIN }, book:Place())
	end)

	it("hands a renderer a copy of the place, so changing it moves nothing", function()
		local loaded, _, book = ready()
		book:RegisterPage("home", "left", function(_, place)
			place.page = "lifetime"
		end)

		loaded.ns.ToggleBook()

		assert.are.same({ page = "home" }, book:Place())
	end)

	it("scrolls a side whose contents overflow, back to the top on a new target, kept on a redraw (STA-R70)", function()
		local loaded, _, book = ready()
		local draws = {}
		book:RegisterPage("place", "left", writer("rows", draws, 1400))
		loaded.ns.OpenBook({ page = "place", area = DARKSHORE })
		local content = draws[1].content
		local scroll = content:GetParent()

		assert.are.equal(1400, content.height)
		scroll:SetVerticalScroll(300)
		loaded.ns.Redraw("projection")
		loaded.client.runTimers()
		assert.are.equal(300, scroll:GetVerticalScroll())
		loaded.ns.OpenBook({ page = "place", area = AUBERDINE })

		assert.are.equal(0, scroll:GetVerticalScroll())
	end)

	it("glides a side a third of its 524-high body a wheel notch, stopping at its foot (STA-R70)", function()
		local loaded, _, book = ready()
		local draws = {}
		book:RegisterPage("place", "left", writer("rows", draws, 1400))
		loaded.ns.OpenBook({ page = "place", area = DARKSHORE })
		local scroll = draws[1].content:GetParent()
		-- The client lays the 1400 out under the body.
		scroll.GetVerticalScrollRange = function()
			return 1400 - 524
		end
		local wheel = scroll:GetScript("OnMouseWheel")
		-- Where it has scrolled, to 3 places.
		local function at()
			return math.floor(scroll:GetVerticalScroll() * 1000 + 0.5) / 1000
		end

		wheel(scroll, -1)
		wheel(scroll, -1)
		loaded.client.update(0.2)
		assert.are.equal(349.333, at())
		for _ = 1, 6 do
			wheel(scroll, -1)
		end
		loaded.client.update(0.2)
		assert.are.equal(876, at(), "it stops at the body's foot")
		wheel(scroll, 1)
		loaded.client.update(0.2)
		assert.are.equal(701.333, at())
	end)
end)

describe("the Stats book's binding (STA-R70, ADR 0015)", function()
	it(
		"wears the equipped binding through Core's renderer, inking its crumbs, nameplate and paper in each look",
		function()
			local loaded, _, book = ready()
			stats.nameAll(loaded, { NIGHTFIN })
			loaded.ns.OpenBook({ page = "place", area = AUBERDINE, item = NIGHTFIN })
			local frame = book.frame
			local binding = frame.binding

			assert.is_nil(binding.pinned) -- it follows the equipped binding
			local look = binding:Look()
			for _, crumb in ipairs(frame.crumbButtons) do
				assert.are.same(look.gilt, { unpack(crumb.label.textColor, 1, 3) })
			end
			for _, side in ipairs({ "left", "right" }) do
				assert.are.same(look.paperTint, { unpack(frame.parchments[side].paper.vertexColor, 1, 3) })
			end

			-- another binding: silver plate, its own gilt, a warmer paper
			binding.onLook({
				gilt = { 0.8, 0.82, 0.86 },
				giltShadow = { 0, 0, 0, 0.9, 1, -1 },
				silver = true,
				paperTint = { 1, 0.97, 0.93 },
			})
			for _, crumb in ipairs(frame.crumbButtons) do
				if crumb.shown then
					assert.are.same({ 0.8, 0.82, 0.86 }, { unpack(crumb.label.textColor, 1, 3) })
					if crumb.fleuron then
						assert.are.same({ 0.8 / 0.91, 1, 1 }, { unpack(crumb.fleuron.vertexColor, 1, 3) })
					end
				end
			end
			assert.is_true(frame.plate.brass.left.desaturated)
			for _, side in ipairs({ "left", "right" }) do
				assert.are.same({ 1, 0.97, 0.93 }, { unpack(frame.parchments[side].paper.vertexColor, 1, 3) })
			end
			loaded.ns.OpenBook({ page = "lifetime" }) -- crumbs drawn later take the binding's gilt too
			for _, crumb in ipairs(frame.crumbButtons) do
				if crumb.shown then
					assert.are.same({ 0.8, 0.82, 0.86 }, { unpack(crumb.label.textColor, 1, 3) })
				end
			end
		end
	)
end)

describe("the Stats book's breadcrumbs (STA-R74)", function()
	it('read "Stats" on the home spread, and "Stats ❧ {zone} ❧ {subzone} ❧ {item}" on a place page', function()
		local loaded, _, book = ready()
		stats.nameAll(loaded, { NIGHTFIN })

		loaded.ns.ToggleBook()
		assert.are.same({ "Stats" }, crumbsOf(book))
		loaded.ns.OpenBook({ page = "place", area = AUBERDINE, item = NIGHTFIN })

		assert.are.same({ "Stats", "Darkshore", "Auberdine", "Raw Nightfin Snapper" }, crumbsOf(book))
		local marks = 0
		for _, crumb in ipairs(book.frame.crumbButtons) do
			if crumb.shown and crumb.fleuron and crumb.fleuron.shown then
				marks = marks + 1
				assert.are.equal(loaded.ns.ATLASES.Book.file, crumb.fleuron.texture) -- the kit's fleuron
			end
		end
		assert.are.equal(3, marks)
	end)

	it("open what they name, and the item's crumb on a place page does nothing", function()
		local loaded, _, book = ready()
		loaded.ns.OpenBook({ page = "place", area = AUBERDINE, item = NIGHTFIN })

		crumbNamed(book, "Item 13759"):Click()
		assert.are.same({ page = "place", area = AUBERDINE, item = NIGHTFIN }, book:Place())
		crumbNamed(book, "Auberdine"):Click()
		assert.are.same({ page = "place", area = AUBERDINE }, book:Place())
		crumbNamed(book, "Darkshore"):Click()
		assert.are.same({ page = "place", area = DARKSHORE }, book:Place())
		crumbNamed(book, "Stats"):Click()

		assert.are.same({ page = "home" }, book:Place())
	end)

	it('read "Stats ❧ {item}" on an item page and "Stats ❧ {kicker}" on a ribbon page', function()
		local loaded, fake, book = ready()

		loaded.ns.OpenBook({ page = "item", item = NIGHTFIN })
		assert.are.same({ "Stats", "Item 13759" }, crumbsOf(book))
		loaded.ns.OpenBook({ page = "lifetime" })
		assert.are.same({ "Stats", "Lifetime" }, crumbsOf(book))
		loaded.ns.OpenBook({ page = "sessions" })
		assert.are.same({ "Stats", "Sessions" }, crumbsOf(book))
		loaded.ns.OpenBook({ page = "session" })
		assert.are.same({ "Stats", "This Session" }, crumbsOf(book)) -- no Sessions yet
		stats.fish(fake, 1, BLACKMOUTH)
		loaded.client.runTimers()
		assert.are.same({ "Stats", "This Session" }, crumbsOf(book))
		fake.wait(3600)
		loaded.client.runTimers()

		assert.are.same({ "Stats", "My last Session" }, crumbsOf(book))
	end)

	it("ask for an item not loaded yet, and redraw with its name once it loads", function()
		local loaded, _, book = ready()

		loaded.ns.OpenBook({ page = "item", item = NIGHTFIN })
		assert.are.same({ NIGHTFIN }, loaded.client.itemRequests)
		stats.loadItem(loaded, NIGHTFIN)
		loaded.client.runTimers()

		assert.are.same({ "Stats", "Raw Nightfin Snapper" }, crumbsOf(book))
	end)
end)

describe("the Stats book's ribbons (STA-R74, stats.md › UI › On the leather)", function()
	it("hang Where I am (green), This Session, Lifetime and Sessions, left to right under the leather", function()
		local loaded, fake, book = ready()

		loaded.ns.ToggleBook()

		local ribbons = {}
		for i, ribbon in ipairs(book.frame.ribbons) do
			ribbons[i] = ribbon.label.text:gsub("\n", "")
		end
		assert.are.same({ "Where I am", "This Session", "Lifetime", "Sessions" }, ribbons)
		assert.are.same(loaded.ns.BOOK_LOOK.ribbons.here, { unpack(book.frame.ribbons[1].body.vertexColor, 1, 3) })
		-- each a ribbon's width and gap further right, hanging from under the foot, its top tucked under the band
		local sizes = fake.ns.BOOK_RIBBON
		for i, ribbon in ipairs(book.frame.ribbons) do
			local x = 456 + (i - 1) * (sizes.width + sizes.gap)
			assert.are.same({ "TOPLEFT", book.frame, "TOPLEFT", x, -(640 - sizes.tuck) }, ribbon.points[1])
		end
	end)

	it("open This Session, Lifetime and Sessions, the one shown standing out", function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		local ribbons = book.frame.ribbons

		ribbons[2]:Click()
		assert.are.same({ page = "session" }, book:Place())
		ribbons[4]:Click()
		assert.are.same({ page = "sessions" }, book:Place())
		assert.are.same({ false, false, false, true }, {
			ribbons[1].chosen,
			ribbons[2].chosen,
			ribbons[3].chosen,
			ribbons[4].chosen,
		})
		ribbons[3]:Click()

		assert.are.same({ page = "lifetime" }, book:Place())
	end)

	it("open Where I am on the subzone's page, the zone's with subzone 0, the home spread with zone 0", function()
		local loaded, fake, book = ready()
		loaded.ns.OpenBook({ page = "lifetime" })
		local here = book.frame.ribbons[1]

		here:Click()
		assert.are.same({ page = "place", area = AUBERDINE }, book:Place())
		assert.is_true(here.chosen)
		stats.move(fake, { zone = ELWYNN, subzone = 0 })
		here:Click()
		assert.are.same({ page = "place", area = ELWYNN }, book:Place())
		stats.move(fake, { zone = 0, subzone = 0 })
		here:Click()

		assert.are.same({ page = "home" }, book:Place())
	end)
end)

describe("the Stats book's nameplate and live line (stats.md › UI › On the leather, STA-R75)", function()
	it('reads "No Casts yet" with none in the log (STA-R97)', function()
		local loaded, _, book = ready()

		loaded.ns.ToggleBook()

		assert.are.equal("No Casts yet", book.frame.plate.label.text)
	end)

	it('reads "{Casts} Casts · {Sessions} Sessions · since {first Cast\'s date}" from the state', function()
		local loaded, fake, book = ready()
		stats.fish(fake, 1, BLACKMOUTH)
		loaded.ns.ToggleBook()
		assert.are.equal("1 Cast · 1 Session · since 11 Oct 2026", book.frame.plate.label.text)

		stats.fish(fake, 1, BLACKMOUTH)
		fake.wait(3600)
		stats.fish(fake, 1, BLACKMOUTH)
		loaded.client.runTimers()

		assert.are.equal("3 Casts · 2 Sessions · since 11 Oct 2026", book.frame.plate.label.text)
	end)

	it("shows the gilt live line only during a current Session, opening This Session", function()
		local loaded, fake, book = ready()
		loaded.ns.ToggleBook()
		local live = book.frame.live
		assert.is_false(live.shown)

		stats.fish(fake, 2, BLACKMOUTH)
		fake.playCast("gotAway")
		loaded.client.runTimers()
		assert.is_true(live.shown)
		assert.are.equal("Session: 3 Casts · 2 Catches · under 1m", live.label.text)
		assert.are.equal(loaded.ns.BOOK_TEXTURES.disc, live.dot.texture)
		live:Click()
		assert.are.same({ page = "session" }, book:Place())
		fake.wait(3600)
		loaded.client.runTimers()

		assert.is_false(live.shown)
	end)
end)

describe("the Stats book while the projection is updating (STA-R72)", function()
	-- Logged in, but the projection waits for the first PLAYER_ENTERING_WORLD to build: it reads as updating.
	---@return LoadedAddon loaded
	---@return table fake
	---@return table book as ready()'s: the fake's widget fields
	local function updating()
		return stats.start({ items = {}, updating = true })
	end

	it('writes "Updating my records…" on the nameplate and both pages instead of their contents', function()
		local loaded, _, book = updating()
		local draws = {}
		book:RegisterPage("home", "left", writer("waters", draws))

		loaded.ns.ToggleBook()

		assert.is_true(loaded.ns.IsUpdating())
		assert.are.equal("Updating my records…", book.frame.plate.label.text)
		assert.are.same({ "Updating my records…" }, textsOf(book.frame.papers.left))
		assert.are.same({ "Updating my records…" }, textsOf(book.frame.papers.right))
		assert.are.same({}, draws)
	end)

	it("keeps the breadcrumbs and ribbons working, and tells the search box's anchor it is updating", function()
		local loaded, fake, book = updating()
		local told = {}
		book:RegisterLeather("search", function(anchor, place, isUpdating)
			told[#told + 1] = { anchor = anchor, page = place.page, updating = isUpdating }
		end)
		loaded.ns.ToggleBook()

		book.frame.ribbons[3]:Click()
		assert.are.same({ page = "lifetime" }, book:Place())
		assert.are.same({ "Stats", "Lifetime" }, crumbsOf(book))
		crumbNamed(book, "Stats"):Click()
		assert.are.same({ page = "home" }, book:Place())
		assert.are.equal(book.shell.anchors.search, told[1].anchor)
		assert.is_true(told[#told].updating)
		fake.enterWorld()
		loaded.client.runTimers()

		assert.is_false(told[#told].updating)
		assert.is_false(loaded.ns.IsUpdating())
	end)

	it("shows the live line from Pagle.GetSession() alone", function()
		local loaded, fake, book = updating()
		local live = { id = "S-live", startTime = SERVER_TIME - 125, endTime = SERVER_TIME - 5, casts = 4, catches = 3 }
		fake.Pagle.GetSession = function()
			return live
		end

		loaded.ns.ToggleBook()

		assert.are.equal("Session: 4 Casts · 3 Catches · 2m", book.frame.live.label.text)
	end)
end)

describe("the Stats book's redraws (STA-R73)", function()
	-- A ready book open on `target`, with a counting renderer on its left side; returns the draws after the opening.
	local function counting(target)
		local loaded, fake, book = ready()
		local draws = {}
		book:RegisterPage(target.page, "left", writer("left", draws))
		loaded.ns.OpenBook(target)
		loaded.client.runTimers()
		return loaded, fake, book, draws
	end

	it("redraws the open page on the next frame after a Cast ends, once however many ask in that frame", function()
		local loaded, fake, _, draws = counting({ page = "lifetime" })

		stats.fish(fake, 1, BLACKMOUTH)
		fake.playCast("gotAway")
		assert.are.equal(1, #draws)
		loaded.client.runTimers()

		assert.are.equal(2, #draws)
	end)

	it("doesn't redraw for an interrupted Cast", function()
		local loaded, fake, _, draws = counting({ page = "lifetime" })

		fake.fire("CastEnded", "interrupted", nil)
		loaded.client.runTimers()

		assert.are.equal(1, #draws)
	end)

	it("redraws on SessionEnded, ns.Redraw (projection and watches) and ConditionsChanged for area or skill", function()
		local loaded, fake, _, draws = counting({ page = "lifetime" })
		local function step(fire)
			fire()
			loaded.client.runTimers()
			return #draws
		end

		assert.are.same({ 2, 3, 4, 5, 6, 6 }, {
			step(function()
				fake.fire("SessionEnded", { id = "S-1" })
			end),
			step(function()
				loaded.ns.Redraw("projection")
			end),
			step(function()
				loaded.ns.Redraw("watches")
			end),
			step(function()
				fake.fire("ConditionsChanged", { "area" })
			end),
			step(function()
				fake.fire("ConditionsChanged", { "lure", "skill" })
			end),
			step(function()
				fake.fire("ConditionsChanged", { "lure", "auras" })
			end),
		})
	end)

	it("draws nothing while closed", function()
		local loaded, fake, book, draws = counting({ page = "lifetime" })
		book.frame.close:Click()

		stats.fish(fake, 1, BLACKMOUTH)
		loaded.ns.Redraw("watches")
		loaded.client.runTimers()

		assert.are.equal(1, #draws)
	end)

	it("asks for item data once per item, and redraws once per frame however many of its items load", function()
		local loaded, fake, book, draws = counting({ page = "lifetime" })

		book:RequestItem(NIGHTFIN)
		book:RequestItem(BLACKMOUTH)
		book:RequestItem(NIGHTFIN)
		assert.are.same({ NIGHTFIN, BLACKMOUTH }, loaded.client.itemRequests)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", NIGHTFIN, true)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", BLACKMOUTH, true)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", 2455, true) -- one it didn't ask for
		loaded.client.runTimers()
		assert.are.equal(2, #draws)
		fake.fireGameEvent("ITEM_DATA_LOAD_RESULT", 2455, true)
		loaded.client.runTimers()

		assert.are.equal(2, #draws)
	end)

	it(
		"ticks every 30 s while open: the live line refreshes on any page, the whole home spread when it shows",
		function()
			local loaded, fake, book, draws = counting({ page = "lifetime" })
			stats.fish(fake, 1, BLACKMOUTH)
			loaded.client.runTimers()
			local homeDraws = {}
			book:RegisterPage("home", "right", writer("right now", homeDraws))
			loaded.env.GetServerTime = function()
				return SERVER_TIME + 300
			end

			loaded.client.advance(30)
			assert.are.equal(2, #draws)
			assert.are.equal("Session: 1 Cast · 1 Catch · 5m", book.frame.live.label.text)
			loaded.ns.OpenBook({ page = "home" })
			loaded.client.advance(30)
			loaded.client.advance(30)
			assert.are.equal(3, #homeDraws)
			book.frame.close:Click()
			loaded.client.advance(90)

			assert.are.equal(3, #homeDraws)
		end
	)
end)
