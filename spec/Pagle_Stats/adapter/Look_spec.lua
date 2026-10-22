-- The Stats book's First look and its "?" on FakePagle (core/onboarding.md › First looks: ONB-R55–R59, ONB-R90,
-- ONB-R91; board 14): its five notes on the place spread of Where I am with an entry chosen, the spread the book opens
-- on when the set shows, each note's region there, the wax "?" beside the close, and Stats' line for What's in the box.
-- FakePagle runs Core's own First looks wiring: fake.looksShown is each set Core would show, fake.firstLooks:Showing()
-- what is on screen now.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, SMALLFISH, FIREFIN = I.DARKSHORE, I.AUBERDINE, I.SMALLFISH, I.FIREFIN

local LOOK = "stats.book"

-- The five notes, verbatim from the canvas (board "First look · Stats") and the probe's Stats set, in order.
local NOTES = {
	"Every fish of this water: your odds, and how many Casts since you last caught it.",
	"*Your odds* come only from your own Casts, and always say how many.",
	"A *Dry spell* is how long you’ve waited. Unlucky isn’t broken: nothing is owed.",
	"*Watch* up to three fish to keep their Dry spells on your tracker.",
	"Stats *never pops up* and never announces. It’s here when you ask.",
}

-- Stats on a fake logged in with the worked Darkshore history, the player in Darkshore's Auberdine at skill 200 (side
-- hi, as the history's Casts). `options` are
-- support.start's; `options.onboarding` changes fake.global.onboarding's fields before login.
local function ready(options)
	options = options or {}
	local fake = newFakePagle()
	if options.onboarding then
		local state = fake.ns.NewOnboardingState("declined")
		for key, value in pairs(options.onboarding) do
			state[key] = value
		end
		fake.global.onboarding = state
	end
	local loaded, _, book = stats.start({
		fake = fake,
		firstLook = true,
		records = options.records or stats.darkshore(),
		prepare = options.prepare,
		updating = options.updating,
		at = options.at or { zone = DARKSHORE, subzone = AUBERDINE, skillRank = 200, skillMod = 0 },
	})
	return loaded, fake, book
end

-- The texts of each set Core showed, in order, each note as "n. text".
local function shownLooks(fake)
	local out = {}
	for i, look in ipairs(fake.looksShown) do
		local notes = {}
		for j, note in ipairs(look.notes) do
			notes[j] = note.n .. ". " .. note.text
		end
		out[i] = { id = look.id, title = look.title, notes = notes }
	end
	return out
end

-- The set registered as `id`, as Core holds it.
local function setOf(fake, id)
	for _, record in ipairs(fake.firstLooks:List()) do
		if record.set.id == id then
			return record.set
		end
	end
	error("no set " .. id)
end

-- What each of the set's notes points at now: its target region, or false for none.
local function targetsOf(fake)
	local out = {}
	for i, note in ipairs(setOf(fake, LOOK).notes) do
		out[i] = note.target() or false
	end
	return out
end

-- The entry drawn on the place page's right side (adapter/Entry.lua keeps its view on its frame).
local function entryView(book)
	for _, child in ipairs(book.pages["place:right"].content.children) do
		if child.entryView and child.shown then
			return child.entryView
		end
	end
	error("no entry drawn")
end

-- The first row drawn on the place page's left side.
local function firstRow(book)
	for _, child in ipairs(book.pages["place:left"].content.children) do
		if child.isBookRow and child.shown then
			return child
		end
	end
	error("no row drawn")
end

-- The five notes as the set showed them, numbered 1 to 5.
local function allFive()
	local notes = {}
	for i, text in ipairs(NOTES) do
		notes[i] = i .. ". " .. text
	end
	return { { id = LOOK, title = "Stats", notes = notes } }
end

describe("the Stats book's First look (ONB-R55, ONB-R57)", function()
	it(
		"is registered once at OnInitialize as stats.book, five notes in the book's margins (ONB-R56, ONB-R58)",
		function()
			local _, fake = ready()

			local set = setOf(fake, LOOK)
			assert.are.equal("Stats", set.title)
			local texts, places = {}, {}
			for i, note in ipairs(set.notes) do
				texts[i] = note.text
				-- each in a margin: left of the book's left edge, or past its 980 units' width
				places[i] = (note.x + note.w <= 0 and "left") or (note.x >= 980 and "right") or "over"
			end
			assert.are.same(NOTES, texts)
			assert.are.same({ "left", "right", "right", "right", "left" }, places)
			assert.are.equal(1, #fake.firstLooks:List())
		end
	)

	it("joins Off you go's list of windows with a set, as Stats (ONB-R38, ONB-R55)", function()
		local _, fake = ready()

		assert.are.same({ "Stats" }, fake.ns.GuideLookWindows(fake.registry:Modules(), fake.firstLooks:List()))
	end)

	it(
		"shows its five notes the first time the book opens, on Where I am with a fish's entry chosen, marking it seen",
		function()
			local loaded, fake, book = ready()

			loaded.ns.ToggleBook()

			assert.are.same(allFive(), shownLooks(fake))
			assert.are.same({ page = "place", area = AUBERDINE, item = SMALLFISH }, book.router:Place())
			assert.is_true(fake.global.onboarding.looksSeen[LOOK])
			assert.are.same({
				id = LOOK,
				notes = {
					{ index = 1, n = 1 },
					{ index = 2, n = 2 },
					{ index = 3, n = 3 },
					{ index = 4, n = 4 },
					{ index = 5, n = 5 },
				},
			}, fake.firstLooks:Showing())
		end
	)

	it(
		"points at the list's odds, Your odds, the ruler's \"nothing is owed\", the watch toggle and the nameplate",
		function()
			local loaded, fake, book = ready()

			loaded.ns.ToggleBook()

			local entry = entryView(book)
			local expected = { firstRow(book).odds, entry.headline, entry.ruler.owed, entry.toggle, book.frame.plate }
			local targets = targetsOf(fake)
			for i, region in ipairs(expected) do
				assert.are.equal(region, targets[i], "note " .. i)
			end
			assert.are.equal("Every Cast is its own roll; nothing is owed.", entry.ruler.owed.text)
			for _, region in ipairs(targetsOf(fake)) do
				assert.is_true(region:IsVisible())
			end
		end
	)

	it("points at the Dry spell's heading when no fish has a luck ruler, the first row's chosen (STA-R54)", function()
		-- Firefin alone, caught on the last Cast: a Dry spell of 0, which has no ruler, and the rest never caught
		local records = {}
		for i = 1, 150 do
			records[i] =
				stats.cast({ time = stats.T0 + 10 * i, rank = 150, mod = 25, items = i == 150 and { FIREFIN } or nil })
		end
		local loaded, fake, book = ready({ records = records })

		loaded.ns.ToggleBook()

		local entry = entryView(book)
		assert.is_true(firstRow(book).shade.shown) -- the first row, chosen
		assert.is_false(entry.ruler.shown)
		assert.are.equal(entry.dryHeading, targetsOf(fake)[3])
		assert.are.equal(5, #fake.looksShown[1].notes)
	end)

	it("points at nothing off its spread, so its notes drop there (ONB-R56)", function()
		local loaded, fake, book = ready()
		loaded.ns.ToggleBook()

		book.frame.ribbons[3]:Click() -- Lifetime

		assert.are.same({ false, false, false, false, false }, targetsOf(fake))
	end)

	it("goes as the book closes, and doesn't show again as it opens again (ONB-R55)", function()
		local loaded, fake, book = ready()
		loaded.ns.ToggleBook()

		book.frame.close:Click()
		assert.is_nil(fake.firstLooks:Showing())
		loaded.ns.OpenBook({ page = "home" })
		loaded.ns.ToggleBook()
		loaded.ns.ToggleBook()

		assert.are.equal(1, #fake.looksShown)
		assert.are.same({ page = "home" }, book.router:Place())
	end)

	it("leaves the book on the home spread once seen: a later login opens there, as STA-R70 has it", function()
		local loaded, fake, book = ready({ onboarding = { looksSeen = { [LOOK] = true } } })

		loaded.ns.ToggleBook()

		assert.are.same({}, fake.looksShown)
		assert.are.same({ page = "home" }, book.router:Place())
	end)

	it("never shows with Margin notes off, and the book opens on the home spread", function()
		local loaded, fake, book = ready({ onboarding = { notesOn = false } })

		loaded.ns.ToggleBook()

		assert.are.same({}, fake.looksShown)
		assert.is_nil(fake.global.onboarding.looksSeen[LOOK])
		assert.are.same({ page = "home" }, book.router:Place())
	end)

	it("turns for it once a login: after Core showed nothing, the book opens on the home spread at once", function()
		local loaded, fake, book = ready({ onboarding = { notesOn = false } })
		loaded.ns.ToggleBook()
		loaded.ns.ToggleBook()
		fake.global.onboarding.notesOn = true
		local requests = #loaded.client.itemRequests

		loaded.ns.ToggleBook()
		assert.are.same({ page = "home" }, book.router:Place())
		assert.are.same({}, fake.looksShown)
		assert.are.equal(requests, #loaded.client.itemRequests) -- nothing else drawn
		loaded.ns.ToggleBook()

		-- opened on a fish's entry, it shows there
		loaded.ns.OpenBook({ page = "place", area = AUBERDINE, item = SMALLFISH })
		assert.are.same(allFive(), shownLooks(fake))
	end)

	it("waits while the projection updates, and while I can't tell where I am, marking nothing (ONB-R56)", function()
		local loaded, fake, book = ready({ updating = true })
		loaded.ns.ToggleBook()
		assert.are.same({}, fake.looksShown)
		assert.are.same({ page = "home" }, book.router:Place())
		loaded.ns.ToggleBook()

		fake.enterWorld()
		stats.move(fake, { zone = 0, subzone = 0 })
		loaded.ns.ToggleBook()
		assert.are.same({}, fake.looksShown)
		assert.are.same({ page = "home" }, book.router:Place())
		loaded.ns.ToggleBook()

		stats.move(fake, { zone = DARKSHORE, subzone = AUBERDINE })
		loaded.ns.ToggleBook()
		assert.are.same(allFive(), shownLooks(fake))
	end)

	it("shows on the spread it is opened on when that is a fish's entry, keeping its choice", function()
		local loaded, fake, book = ready()

		loaded.ns.OpenBook({ page = "place", area = DARKSHORE, item = FIREFIN })

		assert.are.same({ page = "place", area = DARKSHORE, item = FIREFIN }, book.router:Place())
		assert.are.equal(1, #fake.looksShown)
	end)

	it("leaves a book opened elsewhere where it was opened, the set waiting", function()
		local loaded, fake, book = ready()

		loaded.ns.OpenBook({ page = "lifetime" })

		assert.are.same({ page = "lifetime" }, book.router:Place())
		assert.are.same({}, fake.looksShown)
		assert.is_nil(fake.global.onboarding.looksSeen[LOOK])
	end)

	it("opens the book on its spread for the tour stop (ONB-R84)", function()
		local loaded, fake, book = ready()

		setOf(fake, LOOK).open()

		assert.is_true(book:IsShown())
		assert.are.same({ page = "place", area = AUBERDINE, item = SMALLFISH }, book.router:Place())
		assert.are.equal(loaded.ns.book.frame, fake.firstLooks:Window(LOOK))
	end)

	it("runs on a Core without First looks, registering and showing nothing (ONB-R90)", function()
		local loaded, _, book = ready({
			-- Core's records are immutable (CORE-R18): Stats is handed a Pagle, and a handle, without the two calls
			prepare = function(loaded)
				local Pagle = loaded.env.Pagle
				local function without(real)
					return setmetatable({ RegisterFirstLook = false, ShowFirstLook = false }, {
						__index = function(_, key)
							local value = real[key]
							if type(value) == "function" then
								return function(_, ...)
									return value(real, ...)
								end
							end
							return value
						end,
					})
				end
				loaded.env.Pagle = setmetatable({
					RegisterModule = function(def)
						local M = Pagle.RegisterModule(def)
						return M and without(M)
					end,
				}, { __index = Pagle })
			end,
		})

		assert.has_no_error(function()
			loaded.ns.ToggleBook()
		end)
		assert.are.same({ page = "home" }, book.router:Place())
		local frame = book.frame --[[@as table]] -- read through the fake's widget fields (spec/support/widgets.lua)
		assert.is_false(frame.help.shown)
	end)
end)

describe('the Stats book\'s "?" (ONB-R59)', function()
	it('sits left of the wax close, a wax seal with a gilt "?", its tooltip the book\'s dark slip', function()
		local loaded, _, book = ready()
		loaded.ns.ToggleBook()
		local frame = book.frame --[[@as table]] -- read through the fake's widget fields (spec/support/widgets.lua)
		local help = frame.help

		assert.is_true(help.shown)
		assert.are.same({ "RIGHT", frame.close, "LEFT", -4, 0 }, help.points[1])
		assert.are.same({ 26, 26 }, { help.width, help.height })
		assert.are.equal("?", help.label.text)
		assert.are.equal("Interface\\AddOns\\Pagle\\media\\books\\BookAtlas", help.wax.texture)
		help.scripts.OnEnter(help)
		assert.is_true(help.tip.shown)
		assert.are.equal("Show the notes for this page again", help.tip.text.text)
		help.scripts.OnLeave(help)
		assert.is_false(help.tip.shown)
	end)

	it("shows the set again, seen and with Margin notes off, and hides it on a second press", function()
		local loaded, fake, book = ready()
		loaded.ns.ToggleBook()
		book.frame.close:Click()
		fake.global.onboarding.notesOn = false
		loaded.ns.ToggleBook()

		book.frame.help:Click()
		assert.are.same(allFive()[1], shownLooks(fake)[2])
		assert.are.equal(LOOK, fake.firstLooks:Showing().id)

		book.frame.help:Click()
		assert.is_nil(fake.firstLooks:Showing())
	end)

	it("turns to Where I am with a fish's entry from another spread, and shows the notes there", function()
		local loaded, fake, book = ready({ onboarding = { looksSeen = { [LOOK] = true } } })
		loaded.ns.ToggleBook()
		book.frame.ribbons[3]:Click() -- Lifetime

		book.frame.help:Click()

		assert.are.same({ page = "place", area = AUBERDINE, item = SMALLFISH }, book.router:Place())
		assert.are.same(allFive(), shownLooks(fake))
	end)

	it("chooses a fish on the place page it is pressed on, when no entry is chosen there", function()
		local loaded, fake, book = ready({ onboarding = { looksSeen = { [LOOK] = true } } })
		loaded.ns.OpenBook({ page = "place", area = DARKSHORE })

		book.frame.help:Click()

		assert.are.equal(DARKSHORE, book.router:Place().area)
		assert.is_number(book.router:Place().item)
		assert.are.equal(5, #fake.looksShown[1].notes)
	end)
end)

describe("Stats' line on What's in the box (ONB-R91)", function()
	it("is def.guideBlurb, with no guide step and no First evening item", function()
		local _, fake = ready()

		assert.are.equal(
			"Your own numbers: your odds, from your own Casts, and how long you’ve waited. It never pops up.",
			fake.registry:Modules()[1].def.guideBlurb
		)
		assert.is_nil(fake.guideSteps:FirstOf("Stats"))
	end)
end)
