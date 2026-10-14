-- The Journal's Species on FakePagle (LED-R124, LED-R140–R142, LED-R148, DATA-R112): a fixture catalogue and Catch
-- log, the Ledger's projection built at login, and the fish spread's pages and the search box's results as data.

local MACKEREL, NIGHTFISH, SECRET, STRAY, GONE = 6303, 13759, 6522, 6291, 6299
local DUSKWOOD, ELWYNN, WESTFALL, DARKSHORE = 10, 12, 40, 148
local NAMES = {
	[MACKEREL] = "Raw Slitherskin Mackerel",
	[NIGHTFISH] = "Raw Nightfin Snapper",
	[SECRET] = "Deviate Fish",
	[STRAY] = "Raw Brilliant Smallfish",
	[GONE] = "Sickly Looking Fish",
}
local ZONES =
	{ [DUSKWOOD] = "Duskwood", [ELWYNN] = "Elwynn Forest", [WESTFALL] = "Westfall", [DARKSHORE] = "Darkshore" }
local T0 = 1791000000
local MINUTE = 60
-- Realm minutes of day: 08:14, and 21:40, inside the fixture's night (20:00 to 06:00).
local DAY_MINUTE, NIGHT_MINUTE = 494, 1300

-- A catalogue in the shape of ns.catalogue (DATA-R76). MACKEREL any time in Duskwood, Elwynn and Westfall; NIGHTFISH
-- by night in Duskwood, from pools; SECRET by night in all three, from pools; STRAY in Darkshore; GONE
-- removed, on no list. Skill bases: Elwynn 25, Westfall 55, Duskwood 150; Darkshore none.
local function fixture()
	local night = { time = { { 1200, 360 } } }
	local function fish(id, fields)
		local record = { category = "fish", species = id, legend = false, noise = false, removed = false, pool = false }
		for key, value in pairs(fields or {}) do
			record[key] = value
		end
		return record
	end
	local function area(skillBase, catches)
		return {
			parent = 0,
			continent = 0,
			hasData = true,
			skillBase = skillBase,
			skillBaseConfirmed = false,
			catches = catches,
		}
	end
	local function entry(itemID, window)
		return { itemID = itemID, confirmed = false, window = window, gate = window and night, gateConfirmed = false }
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {
			[MACKEREL] = fish(MACKEREL),
			[NIGHTFISH] = fish(NIGHTFISH, { pool = true }),
			[SECRET] = fish(SECRET, { pool = true }),
			[STRAY] = fish(STRAY),
			[GONE] = fish(GONE, { removed = true }),
		},
		areas = {
			[ELWYNN] = area(25, { entry(MACKEREL), entry(SECRET, "night") }),
			[WESTFALL] = area(55, { entry(MACKEREL), entry(SECRET, "night") }),
			[DUSKWOOD] = area(150, { entry(MACKEREL), entry(NIGHTFISH, "night"), entry(SECRET, "night") }),
			[DARKSHORE] = area(nil, { entry(STRAY) }),
		},
		aliases = {},
		pools = {},
		windows = { night = { spec = night, confirmed = false } },
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- A caught Cast of one `itemID` by character 1 in `zone` at realm `minute`. The log works its realm date out from the
-- time and minute (LOG-R49): 3 Oct 2026 by day, 2 Oct by night.
local function cast(time, itemID, zone, minute)
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = "caught",
		conditions = { minute = minute, zone = zone, subzone = 0, events = {}, auras = {} },
		items = { { itemID = itemID, quantity = 1 } },
	}
end

-- The fixture's log: MACKEREL first in Westfall on 3 March, then in Elwynn; NIGHTFISH at night in Elwynn; STRAY in
-- zone 0; GONE in Elwynn. SECRET is never caught.
local function log()
	return {
		cast(T0, MACKEREL, WESTFALL, DAY_MINUTE),
		cast(T0 + 60, MACKEREL, ELWYNN, DAY_MINUTE),
		cast(T0 + 120, NIGHTFISH, ELWYNN, NIGHT_MINUTE),
		cast(T0 + 180, STRAY, 0, DAY_MINUTE),
		cast(T0 + 240, GONE, ELWYNN, DAY_MINUTE),
	}
end

-- A Ledger on a fake over the fixture and its log, logged in with the projection built, every name loaded, and lore
-- for MACKEREL and SECRET only.
local function loggedIn()
	local fake = newFakePagle()
	fake.setCatalogue(fixture())
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(log()) do
		fake.catchLog:Append(record)
	end
	local loaded = fake.load("Pagle_Ledger")
	for id, name in pairs(NAMES) do
		loaded.client.itemNames[id] = name
	end
	for zone, name in pairs(ZONES) do
		loaded.client.areaNames[zone] = name
	end
	local L = loaded.ns.L
	for key in pairs(L) do
		if type(key) == "string" and key:find("^species%.") then
			L[key] = nil
		end
	end
	L["species.6303.blurb"] = "Slippery enough to earn the name."
	L["species.6522.riddle"] = "Strange schools out on the dry plains."
	fake.login()
	fake.enterWorld()
	return fake, loaded
end

-- Opens the fish spread on Species `id` (with the plain hint open when `hint`).
local function openFish(loaded, id, hint)
	assert.is_true(loaded.ns.journal:Open("fish", { species = id, hint = hint }))
	return loaded.ns.journal.pages
end

-- The texts of a page's text blocks, in order.
local function textsOf(blocks)
	local texts = {}
	for _, block in ipairs(blocks) do
		if block.kind == "text" then
			texts[#texts + 1] = block.text
		end
	end
	return texts
end

-- A page's first block of `kind`.
local function first(blocks, kind)
	for _, block in ipairs(blocks) do
		if block.kind == kind then
			return block
		end
	end
	return nil
end

describe("a caught Species' entry (LED-R140)", function()
	it("shows its sepia icon, name, stamps, first Catch, blurb and listed zones (LED-R140)", function()
		local _, loaded = loggedIn()

		local left = openFish(loaded, MACKEREL).left

		assert.are.same({ kind = "icon", icon = MACKEREL, look = "sepia", large = true }, first(left, "icon"))
		assert.are.equal("Raw Slitherskin Mackerel", first(left, "title").text)
		assert.are.same({
			{ text = "Caught", inked = true },
			{ text = "In its element", inked = false },
			{ text = "Regular", inked = false },
		}, first(left, "stamps").stamps)
		assert.are.same({
			"First landed 3 Oct in Westfall, by Angler. 2 caught.",
			"Slippery enough to earn the name.",
			"Found in Duskwood, Elwynn Forest and Westfall.",
		}, textsOf(left))
	end)

	it('adds " Only by night." for a night-only fish, and leaves a missing blurb out (LED-R140, LED-R161)', function()
		local _, loaded = loggedIn()

		assert.are.same({
			"First landed 2 Oct in Elwynn Forest, by Angler. 1 caught.",
			"Found in Duskwood. Only by night.",
		}, textsOf(openFish(loaded, NIGHTFISH).left))
	end)

	it("drops the zone part for a first Catch in zone 0 (LED-R140, LED-R6)", function()
		local _, loaded = loggedIn()

		assert.are.equal("First landed 3 Oct, by Angler. 1 caught.", textsOf(openFish(loaded, STRAY).left)[1])
	end)

	it("shows the removed line, and no listed zones, for a removed one (LED-R140, LED-R12)", function()
		local _, loaded = loggedIn()

		assert.are.same({
			"First landed 3 Oct in Elwynn Forest, by Angler. 1 caught.",
			"No longer found in Forever's waters.",
		}, textsOf(openFish(loaded, GONE).left))
	end)
end)

describe("an uncaught Species' entry (LED-R141)", function()
	it('shows a silhouette, "An unknown fish", its riddle in quotes and the hint link (LED-R141, LED-R124)', function()
		local _, loaded = loggedIn()

		local left = openFish(loaded, SECRET).left

		assert.are.same({
			{ kind = "icon", icon = SECRET, look = "silhouette", large = true },
			{ kind = "title", text = "An unknown fish" },
			{ kind = "text", text = "“Strange schools out on the dry plains.”" },
			{
				kind = "link",
				text = "Read the plain hint ▸",
				place = { id = "fish", args = { species = SECRET, hint = true } },
			},
		}, left)
	end)

	it("replaces the link with the plain hint, open until the spread changes (LED-R141, DATA-R112)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		openFish(loaded, SECRET)

		journal.frame.left.drawn.link[1]:Click()

		local hint =
			{ kind = "text", hand = true, text = "night · pools · Elwynn Forest · Westfall +1 · skill ~25" }
		assert.are.same(hint, journal.pages.left[4])
		journal:Draw()
		assert.are.same(hint, journal.pages.left[4])

		journal:Open("home")
		openFish(loaded, SECRET)
		assert.are.equal("link", journal.pages.left[4].kind)
	end)
end)

describe("the fish spread (LED-R142)", function()
	-- The realm's clock and the server's both move on `minutes`: fake.conditions through setConditions, and the
	-- client's GetServerTime and GetGameTime.
	local function moveClocks(fake, loaded, minutes)
		local snapshot = {}
		for key, value in pairs(fake.conditions) do
			snapshot[key] = value
		end
		snapshot.time = snapshot.time + minutes * MINUTE
		snapshot.minute = (snapshot.minute + minutes) % 1440
		fake.setConditions(snapshot)
		loaded.env.GetServerTime = function()
			return snapshot.time
		end
		loaded.env.GetGameTime = function()
			return math.floor(snapshot.minute / 60), snapshot.minute % 60
		end
	end

	-- The zone spread's place for `zone` with Species `id` selected.
	local function zonePlace(zone, id)
		return { id = "zone", args = { zone = zone, species = id } }
	end

	it("reads Home ❧ {fish} in its crumbs (LED-R125, LED-R142)", function()
		local _, loaded = loggedIn()

		local crumbs = openFish(loaded, MACKEREL).crumbs

		assert.are.same({ "Home", "Raw Slitherskin Mackerel" }, { crumbs[1].label, crumbs[2].label })
	end)

	it(
		'shows its listed zones as tiles by skill base, with "caught ✓", and its checklist (LED-R142, LED-R131)',
		function()
			local _, loaded = loggedIn()

			local right = openFish(loaded, MACKEREL).right

			assert.are.same({
				{ kind = "kicker", text = "Where to find it" },
				{ kind = "title", text = "Its waters" },
				{
					kind = "tiles",
					tiles = {
						{
							name = "Elwynn Forest",
							line = "Local · 50%",
							line2 = "caught ✓",
							bar = 0.5,
							place = zonePlace(ELWYNN, MACKEREL),
						},
						{
							name = "Westfall",
							line = "Local · 50%",
							line2 = "caught ✓",
							bar = 0.5,
							place = zonePlace(WESTFALL, MACKEREL),
						},
						{
							name = "Duskwood",
							line = "unfished · skill ~150",
							faded = true,
							place = zonePlace(DUSKWOOD, MACKEREL),
						},
					},
				},
				{ kind = "text", text = "☐ In its element (2/3)" },
				{ kind = "text", text = "☐ Regular (2/50)" },
			}, right)
		end
	)

	it(
		'counts windows for ★★ by windows, and shows each element window\'s line under "When" (LED-R142, LED-R45)',
		function()
			local _, loaded = loggedIn()

			local right = openFish(loaded, NIGHTFISH).right

			assert.are.same({ kind = "kicker", text = "When" }, right[4])
			assert.are.same({ kind = "text", text = "☑ In its element (1/1)" }, right[6])
			assert.are.same({ kind = "text", text = "☐ Regular (1/50)" }, right[7])
		end
	)

	it("reads a night-only fish's window state live each time it is drawn (LED-R142, LED-R127, LOG-R50)", function()
		local fake, loaded = loggedIn()

		-- The fake's realm 08:15: night opens at 20:00, 11 h 45 min away.
		assert.are.same(
			{ kind = "text", hand = true, text = "night, back in 12 h" },
			openFish(loaded, NIGHTFISH).right[5]
		)

		-- Realm 21:15, in the night.
		moveClocks(fake, loaded, 13 * 60)
		loaded.ns.journal:Draw()

		assert.are.equal("night, biting now", loaded.ns.journal.pages.right[5].text)
	end)

	it("opens the zone spread with the fish selected from a tile (LED-R142)", function()
		local _, loaded = loggedIn()
		local opened
		loaded.ns.RegisterJournalSpread("zone", {
			crumbs = function()
				return {}
			end,
			draw = function(args)
				opened = args
				return { left = {}, right = {} }
			end,
		})
		openFish(loaded, MACKEREL)

		local tiles = loaded.ns.journal.frame.right.drawn.tiles[1]
		tiles.children[2]:Click()

		assert.are.same({ zone = WESTFALL, species = MACKEREL }, opened)
	end)
end)

describe("the Journal's search box (LED-R148)", function()
	-- Types `query` into the open book's search box, as the player does: its text changes.
	local function typeInto(loaded, query)
		local search = loaded.ns.journal.frame.search
		search:SetText(query)
		search:GetScript("OnTextChanged")(search, true)
	end

	-- The dropdown's shown lines, in order.
	local function dropdown(loaded)
		local frame = loaded.ns.journal.frame
		local lines = {}
		if not frame.searchDrop:IsShown() then
			return lines
		end
		for _, row in ipairs(frame.searchDrop.rows) do
			if row:IsShown() then
				lines[#lines + 1] = row.label:GetText()
			end
		end
		return lines
	end

	it(
		"finds a zone and caught Species from two letters, zones first, never an uncaught one (LED-R148, LED-R124)",
		function()
			local _, loaded = loggedIn()
			loaded.ns.journal:Toggle()

			typeInto(loaded, "sH")

			assert.are.same({ "Darkshore", "Raw Brilliant Smallfish", "Sickly Looking Fish" }, dropdown(loaded))
		end
	)

	it("opens the fish spread picked, and closes the dropdown (LED-R148, LED-R125)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		journal:Toggle()
		typeInto(loaded, "sh")

		journal.frame.searchDrop.rows[2]:Click()

		assert.are.same({ id = "fish", args = { species = STRAY } }, journal.router:Place())
		assert.are.same(
			{ "Home", "Raw Brilliant Smallfish" },
			{ journal.pages.crumbs[1].label, journal.pages.crumbs[2].label }
		)
		assert.are.same({}, dropdown(loaded))
		assert.are.equal("", journal.frame.search:GetText())
	end)

	it("shows the no-match line for a string matching nothing, and nothing for an empty box (LED-R148)", function()
		local _, loaded = loggedIn()
		loaded.ns.journal:Toggle()

		typeInto(loaded, "deviate")
		assert.are.same({ "Nothing by that name in the Ledger yet." }, dropdown(loaded))

		typeInto(loaded, "")
		assert.are.same({}, dropdown(loaded))
	end)
end)

-- Every spread registered stays under this spec: a spread that lands later is swept with the others.
describe("never named until caught (LED-R124)", function()
	-- The args every spread is drawn with: the uncaught Species chosen, its plain hint shut and open, in a zone that
	-- lists it, on the first continent tab. A spread ignores the args it doesn't take.
	local ARGS = {
		{ species = SECRET, zone = DUSKWOOD, tab = 0 },
		{ species = SECRET, zone = ELWYNN, tab = 0, hint = true },
	}

	-- Every text the open book shows, depth first: crumbs, both pages, the back link and the search box's dropdown.
	local function drawnTexts(widget, texts)
		texts = texts or {}
		for _, child in ipairs(widget.children) do
			if child.shown then
				if type(child.text) == "string" and child.text ~= "" then
					texts[#texts + 1] = child.text
				end
				drawnTexts(child, texts)
			end
		end
		return texts
	end

	-- The first text the book shows with `name` in it, as "{spread}: {text}", on any registered spread drawn with each
	-- of ARGS and Species `species` chosen; nil if none.
	local function anywhere(loaded, name, species)
		local journal = loaded.ns.journal
		local spreads = {}
		for id in pairs(loaded.ns.journalSpreads) do
			spreads[#spreads + 1] = id
		end
		table.sort(spreads)
		assert.is_true(#spreads >= 2)
		for _, id in ipairs(spreads) do
			for _, args in ipairs(ARGS) do
				local copy = {}
				for key, value in pairs(args) do
					copy[key] = value
				end
				copy.species = species
				journal:Open(id, copy)
				for _, text in ipairs(drawnTexts(journal.frame)) do
					if text:lower():find(name:lower(), 1, true) then
						return id .. ": " .. text
					end
				end
			end
		end
		return nil
	end

	it("names an uncaught Species nowhere on any registered spread (LED-R124)", function()
		local _, loaded = loggedIn()

		assert.is_nil(anywhere(loaded, NAMES[SECRET], SECRET))
	end)

	it("would find a caught Species' name, so the sweep reads what is drawn (LED-R124)", function()
		local _, loaded = loggedIn()

		assert.is_not_nil(anywhere(loaded, NAMES[MACKEREL], MACKEREL))
	end)
end)
