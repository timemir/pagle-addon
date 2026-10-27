-- The Journal's Home on FakePagle (LED-R130–R133, LED-R149, LED-R4's M3 stage), over a fixture catalogue and log:
-- the zone tiles under their continent tabs, the bookplate summary, Notes to self, the contents and the brass plate,
-- as the page data the open book shows (ns.journal.pages) and as drawn.

local MACKEREL, BLACKMOUTH, NIGHTFISH, SNAPPER = 6303, 6358, 13759, 6362
local TROPHY, SKULL, CHEST = 13901, 6297, 6351
local ELWYNN, WESTFALL, DUSKWOOD, REDRIDGE, DARKSHORE, ASHENVALE, ISLE = 12, 40, 10, 44, 148, 331, 3500
-- A zone the catalogue doesn't know at all: GetArea returns nil for it.
local NOWHERE = 7777
local T0 = SERVER_TIME - 700

-- The names the fake client's C_Item and C_Map know.
local ITEM_NAMES = {
	[MACKEREL] = "Raw Slitherskin Mackerel",
	[BLACKMOUTH] = "Oily Blackmouth",
	[NIGHTFISH] = "Raw Nightfin Snapper",
	[SNAPPER] = "Raw Rockscale Cod",
}
local ZONE_NAMES = {
	[ELWYNN] = "Elwynn Forest",
	[WESTFALL] = "Westfall",
	[DUSKWOOD] = "Duskwood",
	[REDRIDGE] = "Redridge Mountains",
	[DARKSHORE] = "Darkshore",
	[ASHENVALE] = "Ashenvale",
	[ISLE] = "Isle of Dread",
	[NOWHERE] = "Nowhere",
}
local MAP_NAMES = { [1415] = "Eastern Kingdoms", [1414] = "Kalimdor" }

-- A catalogue in the shape of ns.catalogue (DATA-R76), without the zones in `without`:
-- - Eastern Kingdoms (0): Elwynn (skill 25) lists the Mackerel alone; Westfall (75) the Mackerel and Blackmouth, the
--   night-gated Nightfish and a junk Skull; Duskwood (150) the Blackmouth; Redridge, without a skill base, the
--   Blackmouth
-- - Kalimdor (1): Darkshore (75) lists the Blackmouth, the Rockscale Cod and a chest; Ashenvale (75) the Blackmouth
--   and a trophy of family 1
-- - the Isle (continent 2, skill 300) lists the Cod
---@param without integer[]?
local function fixture(without)
	local night = NIGHT_WINDOW
	local function area(continent, skillBase, catches)
		return areaRecord(0, { continent = continent, skillBase = skillBase, catches = catches })
	end
	local function on(itemID)
		return { itemID = itemID, confirmed = false }
	end
	local areas = {
		[ELWYNN] = area(0, 25, { on(MACKEREL) }),
		[WESTFALL] = area(0, 75, {
			on(MACKEREL),
			on(BLACKMOUTH),
			{ itemID = NIGHTFISH, confirmed = false, window = "night", gate = night, gateConfirmed = false },
			on(SKULL),
		}),
		[DUSKWOOD] = area(0, 150, { on(BLACKMOUTH) }),
		[REDRIDGE] = area(0, nil, { on(BLACKMOUTH) }),
		[DARKSHORE] = area(1, 75, { on(BLACKMOUTH), on(SNAPPER), on(CHEST) }),
		[ASHENVALE] = area(1, 75, { on(BLACKMOUTH), on(TROPHY) }),
		[ISLE] = area(2, 300, { on(SNAPPER) }),
	}
	for _, zone in ipairs(without or {}) do
		areas[zone] = nil
	end
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[BLACKMOUTH] = fishRecord(BLACKMOUTH),
			[NIGHTFISH] = fishRecord(NIGHTFISH),
			[SNAPPER] = fishRecord(SNAPPER),
			[TROPHY] = itemRecord("trophy", { family = 1, weight = 19 }),
			[SKULL] = itemRecord("junk"),
			[CHEST] = itemRecord("container"),
		},
		areas = areas,
		windows = { night = { spec = night, confirmed = false } },
	})
end

-- A caught Cast record for fake.catchLog:Append, by the player's character (char 1), one of each item.
---@param zone integer
---@param ... integer item IDs
local function cast(zone, ...)
	return castRecord({ time = T0, zone = zone, items = { ... } })
end

-- A Ledger on FakePagle over the fixture catalogue with `history` in its log, logged in and in the world, its
-- client knowing the names above. `before`, if given, runs before the book opens (e.g. to seed the celebrated set).
---@param history table[]?
---@param before fun(loaded: LoadedAddon, fake: FakePagle)?
---@param catalogue table? the catalogue, fixture() by default
---@return FakePagle fake
---@return LoadedAddon loaded
local function openHome(history, before, catalogue)
	return openJournal({
		catalogue = catalogue or fixture(),
		log = history,
		itemNames = ITEM_NAMES,
		areaNames = ZONE_NAMES,
		mapNames = MAP_NAMES,
		before = before,
	})
end

-- The open book's page data.
---@param loaded LoadedAddon
---@return LedgerJournalPages
local function pages(loaded)
	return loaded.ns.journal.pages
end

-- The tiles the left page shows.
local function tiles(loaded)
	return (blockOfKind(pages(loaded).left, "tiles") or {}).tiles
end

-- The tabs' labels, and the one chosen.
local function tabs(loaded)
	local labels, chosen = {}, nil
	for i, tab in ipairs((blockOfKind(pages(loaded).left, "tabs") or { tabs = {} }).tabs) do
		labels[i] = tab.text
		if tab.on then
			chosen = tab.text
		end
	end
	return labels, chosen
end

-- The tiles' names.
local function tileNames(loaded)
	local names = {}
	for i, tile in ipairs(tiles(loaded)) do
		names[i] = tile.name
	end
	return names
end

-- Opens Home on tab `tab` (0, 1 or "other") as clicking it does.
local function chooseTab(loaded, tab)
	loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.home(tab))
end

describe("the Journal's Home, left page", function()
	it("reads The Waters, Where I've Fished, then the tabs and the chosen tab's tiles (LED-R130)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) })

		local left = pages(loaded).left
		assert.are.same({ kind = "kicker", text = "The Waters" }, left[1])
		assert.are.same({ kind = "title", text = "Where I've Fished" }, left[2])
		assert.are.equal("tabs", left[3].kind)
		assert.are.equal("tiles", left[4].kind)
		assert.are.equal(4, #left)
	end)

	it(
		"puts a tile under its continent's tab, in skill base then areaID order, with each kind's text (LED-R131)",
		function()
			-- Elwynn's one Species makes it Master; Westfall's Mackerel makes it Regular (1 of 4 parts, 25%).
			local _, loaded = openHome({ cast(ELWYNN, MACKEREL), cast(WESTFALL, MACKEREL), cast(NOWHERE, SKULL) })

			local labels, chosen = tabs(loaded)
			assert.are.same({ "Eastern Kingdoms", "Kalimdor", "Other waters" }, labels)
			assert.are.equal("Eastern Kingdoms", chosen)
			assert.are.same({
				{
					name = "Elwynn Forest",
					line = "Master · 100%",
					bar = 1,
					seal = "Master",
					place = { id = "zone", args = { zone = ELWYNN } },
				},
				{
					name = "Westfall",
					line = "Regular · 25%",
					bar = 0.25,
					place = { id = "zone", args = { zone = WESTFALL } },
				},
				{
					name = "Duskwood",
					line = "unfished · skill ~150",
					faded = true,
					place = { id = "zone", args = { zone = DUSKWOOD } },
				},
				{
					name = "Redridge Mountains",
					line = "unfished",
					faded = true,
					place = { id = "zone", args = { zone = REDRIDGE } },
				},
			}, tiles(loaded))

			chooseTab(loaded, 1)
			assert.are.same({ "Darkshore", "Ashenvale" }, tileNames(loaded))
			assert.are.equal("unfished · skill ~75", tiles(loaded)[1].line)

			chooseTab(loaded, "other")
			assert.are.same({ "Isle of Dread", "Nowhere" }, tileNames(loaded))
			assert.are.same(
				{ name = "Nowhere", line = "uncharted waters", place = { id = "zone", args = { zone = NOWHERE } } },
				tiles(loaded)[2]
			)
		end
	)

	it("shows a red {N} new! note while the shown rank is above the computed one (LED-R131, LED-R52)", function()
		-- Westfall is Regular by its Catches, but Expert was celebrated before the data grew: the Blackmouth (Local),
		-- the Nightfish and the junk (Expert) are new to find.
		local _, loaded = openHome({ cast(WESTFALL, MACKEREL) }, function(loaded)
			loaded.ns.db.global.celebrated.zones[WESTFALL] = 4
		end)

		local westfall = tiles(loaded)[2]
		assert.are.equal("Expert · 25%", westfall.line)
		assert.are.equal("3 new!", westfall.note)
		assert.is_nil(westfall.seal)
	end)

	it("puts a zone GetArea doesn't know under Other waters, and shows no tab without a tile (LED-R130)", function()
		local catalogue = fixture({ DARKSHORE, ASHENVALE, ISLE })
		local _, loaded = openHome({ cast(NOWHERE, SKULL) }, nil, catalogue)

		local labels = tabs(loaded)
		assert.are.same({ "Eastern Kingdoms", "Other waters" }, labels)
		chooseTab(loaded, "other")
		assert.are.same({ "Nowhere" }, tileNames(loaded))
	end)

	it("chooses the first tab shown at the first opening, and keeps the tab chosen after (LED-R130)", function()
		local catalogue = fixture({ ELWYNN, WESTFALL, DUSKWOOD, REDRIDGE })
		local _, loaded = openHome({}, nil, catalogue)
		local _, chosen = tabs(loaded)
		assert.are.equal("Kalimdor", chosen)

		-- Clicking the Other waters tab, then a tile's zone and back Home by the Home crumb.
		local journal = loaded.ns.journal
		journal.shown.left.drawn.tabs[1].tabs[2]:Click()
		assert.are.same({ "Isle of Dread" }, tileNames(loaded))
		loaded.ns.RegisterJournalSpread("zone", {
			crumbs = function()
				return { { label = "Zone", place = { id = "zone" } } }
			end,
			draw = function()
				return { left = {}, right = {} }
			end,
		})
		journal.shown.left.drawn.tiles[1].children[1]:Click()
		assert.are.same({ id = "zone", args = { zone = ISLE } }, loaded.ns.journal.router:Place())
		journal.frame.crumbButtons[1]:Click()

		_, chosen = tabs(loaded)
		assert.are.equal("Other waters", chosen)
	end)

	it(
		"starts the left page at the top on another tab, keeping the right page's scroll (LED-R129, LED-R130)",
		function()
			local _, loaded = openHome({}, nil, fixture({ ELWYNN, WESTFALL, DUSKWOOD, REDRIDGE }))
			scrollPage(loaded, "left", 120)
			scrollPage(loaded, "right", 80)

			-- The Other waters tab.
			loaded.ns.journal.shown.left.drawn.tabs[1].tabs[2]:Click()

			assert.are.same({ "Isle of Dread" }, tileNames(loaded))
			assert.are.same({ 0, 80 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
		end
	)
end)

-- Seeds the celebrated set: level 12 celebrated in this climb, so the shown level is 12 (LED-R36).
local function level12(loaded)
	loaded.ns.db.global.celebrated.levels[0] = 12
end

describe("the Journal's Home, right page", function()
	it("reads the bookplate summary, the ink XP bar, Notes to self and In this Ledger (LED-R132, LED-R163)", function()
		-- Of 14 parts (4 Species, a junk, a chest, a trophy, 7 charted zones), the Mackerel and Elwynn are done: 14%.
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) }, level12)

		local right = pages(loaded).right
		assert.are.same({
			kind = "bookplate",
			text = "12",
			value = "Angler Level",
			seal = "14%",
			mark = { stars = 0, rank = 0 },
			signature = "Minnow",
		}, right[1])
		assert.are.equal("xpBar", right[2].kind)
		assert.are.equal("0 of 1,960.", right[2].bar.text)
		assert.are.same({ kind = "rule" }, right[3])
		assert.are.same({ kind = "kicker", text = "Notes to self" }, right[4])
		assert.are.same({
			kind = "link",
			text = drawnSymbols("Raw Slitherskin Mackerel: 4 to ★"),
			hand = true,
			place = { id = "fish", args = { species = MACKEREL } },
		}, right[5])
		assert.are.same({ kind = "kicker", text = "In this Ledger" }, right[6])
		assert.are.same({
			{ kind = "leader", numeral = "i.", text = "The Trophy Room", value = "0 / 1", place = { id = "trophy" } },
			{
				kind = "leader",
				numeral = "ii.",
				text = "Curios: junk, treasure, uncharted",
				value = "0 / 2",
				place = { id = "curios" },
			},
			{ kind = "leader", numeral = "iii.", text = "Legends", value = "0 / 0", place = { id = "legends" } },
			-- the Collection's line (LED-R132, LED-R174): nothing is new on a first opening (LED-R171)
			{
				kind = "leader",
				numeral = "iv.",
				text = "The Collection: looks and titles",
				value = right[10].value,
				place = { id = "collection" },
			},
			{
				kind = "leader",
				numeral = "v.",
				text = "The Angler: hands, titles, bindings",
				value = "»",
				place = { id = "angler" },
			},
			-- Track V's line, last: no Pagle_Following here, so greyed (LED-R163)
			{
				kind = "leader",
				numeral = "vi.",
				text = "Following",
				value = "no Companion",
				color = "faded",
				place = { id = "following" },
			},
		}, { right[7], right[8], right[9], right[10], right[11], right[12] })
		assert.are.equal(12, #right)
	end)

	it(
		"counts the weights landed, and the junk and treasure collected, as Ledger completion does (LED-R132, LED-R71)",
		function()
			-- The Skull counts though caught in waters nobody charted: a collection counts an item caught anywhere.
			local _, loaded = openHome({ cast(NOWHERE, SKULL), cast(DARKSHORE, CHEST), cast(ASHENVALE, TROPHY) })

			local right = pages(loaded).right
			assert.are.equal("1 / 1", right[7].value)
			assert.are.equal("2 / 2", right[8].value)
		end
	)

	it('reads "Go fishing!" as its one note when nothing applies (LED-R133)', function()
		local _, loaded = openHome()

		local right = pages(loaded).right
		assert.are.same({ kind = "kicker", text = "Notes to self" }, right[4])
		assert.are.same({ kind = "text", text = "Go fishing!", hand = true }, right[5])
		assert.are.same({ kind = "kicker", text = "In this Ledger" }, right[6])
	end)

	it(
		"opens a note's or a contents line's spread once it is registered, and does nothing before (LED-R133, LED-R125)",
		function()
			local _, loaded = openHome({ cast(ELWYNN, MACKEREL) })
			local journal = loaded.ns.journal
			local function spread(label)
				return {
					crumbs = function()
						return { { label = label, place = { id = label } } }
					end,
					draw = function()
						return { left = {}, right = {} }
					end,
				}
			end

			-- The Trophy Room (#143) registers itself; take it away to see a link to a spread not yet registered.
			loaded.ns.journalSpreads.trophy = nil
			journal.shown.right.drawn.leader[1]:Click()
			assert.are.same({ id = "home" }, journal.router:Place())

			loaded.ns.RegisterJournalSpread("trophy", spread("trophy"))
			journal.shown.right.drawn.leader[1]:Click()
			assert.are.same({ id = "trophy" }, journal.router:Place())
		end
	)

	it("opens the fish spread from the next-star note, Home ❧ {fish} (LED-R133, LED-R125, LED-R142)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) })
		local journal = loaded.ns.journal

		journal.shown.right.drawn.link[1]:Click()

		assert.are.same({ id = "fish", args = { species = MACKEREL } }, journal.router:Place())
		local labels = {}
		for i, crumb in ipairs(journal.pages.crumbs) do
			labels[i] = crumb.label
		end
		assert.are.same({ "Home", "Raw Slitherskin Mackerel" }, labels)
	end)

	it("is where the fish spread's back link returns from a note (LED-R125)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) })
		local journal = loaded.ns.journal
		journal.shown.right.drawn.link[1]:Click()

		journal.frame.back:Click()

		assert.are.same({ id = "home" }, journal.router:Place())
		assert.are.equal("Where I've Fished", pages(loaded).left[2].text)
	end)

	it("opens the Angler page from its contents line, Home ❧ The Angler (LED-R132, LED-R125, LED-R146)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) })
		local journal = loaded.ns.journal

		journal.shown.right.drawn.leader[5]:Click()

		assert.are.same({ id = "angler" }, journal.router:Place())
		local labels = {}
		for i, crumb in ipairs(journal.pages.crumbs) do
			labels[i] = crumb.label
		end
		assert.are.same({ "Home", "The Angler" }, labels)
	end)
end)

-- The fixture's Mackerel in Elwynn, then character 1's Prestige to `rank` (LOG-R38): rank `rank` from the entry
-- (LED-R32).
---@param rank integer
---@return table[]
local function prestiged(rank)
	return { cast(ELWYNN, MACKEREL), { kind = "prestige", char = 1, time = T0 + 60, rank = rank } }
end

-- The drawn bookplate row's widget (LED-R132).
local function drawnBookplate(loaded)
	return loaded.ns.journal.shown.right.drawn.bookplate[1]
end

describe("the Journal's Home, the bookplate's title and Prestige (LED-R132, LED-R4's M4 stage)", function()
	it("shows no emblem at rank 0, and the active title in handwriting (LED-R132, LED-R34, LED-R77)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) }, level12)

		-- Automatic: the highest level title earned, level1's Minnow from the start (LED-R75, LED-R77).
		assert.are.same({
			kind = "bookplate",
			text = "12",
			value = "Angler Level",
			seal = "14%",
			mark = { stars = 0, rank = 0 },
			signature = "Minnow",
		}, pages(loaded).right[1])
		-- the seal reads the Ledger's completion under its word
		local texts = shownTexts(drawnBookplate(loaded))
		assert.are.same({ "12", "Angler Level", "Minnow", "Ledger\n14%" }, texts)
	end)

	it(
		"shows Core's emblem III beside the level at rank 3, its numeral in its art, and the active title under it"
			.. " (LED-R132, LED-R34, LED-R152)",
		function()
			local _, loaded = openHome(prestiged(3), level12)

			-- A Prestige means a climb reached 60, so the peak level is 60 and automatic signs with level60 (LED-R35).
			local bookplate = pages(loaded).right[1]
			assert.are.same({ emblem = "III", stars = 0, rank = 3 }, bookplate.mark)
			assert.are.equal("Nat's Peer", bookplate.signature)
			local texts = shownTexts(drawnBookplate(loaded))
			assert.are.same({ bookplate.text, "Angler Level", "Nat's Peer", "Ledger\n14%" }, texts)
			local emblem = drawnBookplate(loaded).emblem
			assert.are.same({ true, 34 }, { emblem:IsShown(), emblem.width })
		end
	)

	it("shows a Master Prestige's stars beside the Master's emblem (LED-R34, LED-R152)", function()
		local _, loaded = openHome(prestiged(12), level12)

		local bookplate = pages(loaded).right[1]
		assert.are.same({ emblem = "X", stars = 2, rank = 12 }, bookplate.mark)
		local widget = drawnBookplate(loaded)
		assert.are.same({ bookplate.text, "Angler Level", "Nat's Peer", "Ledger\n14%" }, shownTexts(widget))
		assert.is_true(widget.emblem:IsShown())
		-- two stars, as the kit's star sprite
		local shown = 0
		for _, star in ipairs(widget.stars) do
			shown = shown + (star:IsShown() and 1 or 0)
		end
		assert.are.equal(2, shown)
	end)

	it("signs with the stored active title once it is earned (LED-R77)", function()
		local _, loaded = openHome(prestiged(1), function(ledger)
			level12(ledger)
			ledger.ns.db.profile.activeTitle = "title:prestige1"
		end)

		assert.are.equal("Returning Tide", pages(loaded).right[1].signature)
	end)

	it("leaves the title out while the active title has no lore text (LED-R161)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) }, function(ledger)
			level12(ledger)
			ledger.ns.L["title.level1.text"] = nil
		end)

		assert.is_nil(pages(loaded).right[1].signature)
		assert.are.same({ "12", "Angler Level", "Ledger\n14%" }, shownTexts(drawnBookplate(loaded)))
	end)
end)

describe("the Journal's Home and what isn't caught", function()
	it("names no uncaught Species anywhere on Home (LED-R124)", function()
		-- Only the Mackerel is caught; the client knows every fixture Species' name.
		local _, loaded = openHome({ cast(WESTFALL, MACKEREL) })
		loaded.ns.journal:Draw()

		for _, text in ipairs(shownTexts(loaded.ns.journal.frame)) do
			for id, name in pairs(ITEM_NAMES) do
				if id ~= MACKEREL then
					assert.is_nil(text:find(name, 1, true))
				end
			end
		end
	end)
end)

describe("the brass plate (LED-R149)", function()
	it('reads "Lv {L} · {active title} · Ledger {p}%" on the cover, on every spread (LED-R149, LED-R77)', function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) }, level12)
		local journal = loaded.ns.journal

		assert.are.equal("Lv 12 · Minnow · Ledger 14%", journal.plate)
		assert.are.equal("Lv 12 · Minnow · Ledger 14%", journal.frame.plate.label.text)
		assert.is_true(journal.frame.plate:IsShown())

		loaded.ns.RegisterJournalSpread("trophy", {
			crumbs = function()
				return {}
			end,
			draw = function()
				return { left = {}, right = {} }
			end,
		})
		journal:Open("trophy")
		assert.is_true(journal.frame.plate:IsShown())
		assert.are.equal("Lv 12 · Minnow · Ledger 14%", journal.frame.plate.label.text)
	end)

	it("names the stored active title once earned (LED-R149, LED-R77)", function()
		local _, loaded = openHome(prestiged(1), function(ledger)
			level12(ledger)
			ledger.ns.db.profile.activeTitle = "title:prestige1"
		end)

		assert.matches("^Lv %d+ · Returning Tide · Ledger 14%%$", loaded.ns.journal.plate)
	end)

	it('reads "Lv {L} · Ledger {p}%" while the active title has no lore text (LED-R149, LED-R161)', function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) }, function(ledger)
			level12(ledger)
			ledger.ns.L["title.level1.text"] = nil
		end)

		assert.are.equal("Lv 12 · Ledger 14%", loaded.ns.journal.plate)
		assert.are.equal("Lv 12 · Ledger 14%", loaded.ns.journal.frame.plate.label.text)
	end)

	it("keeps its last words while the projection updates, where LED-R122 hides only the pages' (LED-R149)", function()
		local _, loaded = openHome({ cast(ELWYNN, MACKEREL) }, level12)
		local journal = loaded.ns.journal

		-- The projection starts updating with the book open (LOG-R74): there is no state to read until it finishes.
		loaded.ns.projection.IsUpdating = function()
			return true
		end
		journal:Draw()

		assert.is_true(journal.pages.updating)
		assert.is_true(journal.frame.plate:IsShown())
		assert.are.equal("Lv 12 · Minnow · Ledger 14%", journal.frame.plate.label.text)
	end)
end)

describe("the Journal's Home, live", function()
	it(
		"updates a tile, its seal and the plate on the frame after a live Catch raises the zone's rank (LED-R123)",
		function()
			local fake, loaded = openHome({ cast(ELWYNN, MACKEREL) }, level12)
			local function duskwood()
				return tiles(loaded)[3]
			end
			assert.are.equal("unfished · skill ~150", duskwood().line)

			local conditions = {}
			for key, value in pairs(fake.conditions) do
				conditions[key] = value
			end
			conditions.zone, conditions.subzone = DUSKWOOD, 0
			fake.setConditions(conditions)
			fake.playCast("caught", { { itemID = BLACKMOUTH, quantity = 1 } })
			assert.are.equal("unfished · skill ~150", duskwood().line, "the redraw waits for the next frame")
			loaded.client.runTimers()

			assert.are.equal("Master · 100%", duskwood().line)
			assert.are.equal("Master", duskwood().seal)
			assert.is_nil(duskwood().faded)
			-- The Blackmouth and Duskwood join the Mackerel and Elwynn: 4 of 14.
			assert.are.equal("Lv 12 · Minnow · Ledger 28%", loaded.ns.journal.plate)
		end
	)
end)
