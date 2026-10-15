-- The Journal's Species on FakePagle (LED-R124, LED-R140–R142, LED-R148, DATA-R112): a fixture catalogue and Catch
-- log, the Ledger's projection built at login, and the fish spread's pages and the search box's results as data.

local MACKEREL, NIGHTFISH, SECRET, STRAY, GONE = 6303, 13759, 6522, 6291, 6299
-- A junk item and a trophy weight, listed in Darkshore and never caught.
local SKULL, CATFISH_17 = 6297, 6309
local DUSKWOOD, ELWYNN, WESTFALL, DARKSHORE = 10, 12, 40, 148
local NAMES = {
	[MACKEREL] = "Raw Slitherskin Mackerel",
	[NIGHTFISH] = "Raw Nightfin Snapper",
	[SECRET] = "Deviate Fish",
	[STRAY] = "Raw Brilliant Smallfish",
	[GONE] = "Sickly Looking Fish",
	[SKULL] = "Old Skull",
	[CATFISH_17] = "17 Pound Catfish",
}
local ZONES =
	{ [DUSKWOOD] = "Duskwood", [ELWYNN] = "Elwynn Forest", [WESTFALL] = "Westfall", [DARKSHORE] = "Darkshore" }
local T0 = 1791000000
local MINUTE = 60
-- Realm minutes of day: 08:14, and 21:40, inside the fixture's night (20:00 to 06:00).
local DAY_MINUTE, NIGHT_MINUTE = 494, 1300

-- A catalogue in the shape of ns.catalogue (DATA-R76). MACKEREL any time in Duskwood, Elwynn and Westfall; NIGHTFISH
-- by night in Duskwood, from pools; SECRET by night in all three, from pools; STRAY, a junk SKULL and a trophy
-- CATFISH_17 (family 2) in Darkshore; GONE removed, on no list. Skill bases: Elwynn 25, Westfall 55, Duskwood 150;
-- Darkshore none.
local function fixture()
	local night = { time = { { 1200, 360 } } }
	local function area(skillBase, catches)
		return areaRecord(0, { skillBase = skillBase, catches = catches })
	end
	local function entry(itemID, window)
		return { itemID = itemID, confirmed = false, window = window, gate = window and night, gateConfirmed = false }
	end
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL),
			[NIGHTFISH] = fishRecord(NIGHTFISH, { pool = true }),
			[SECRET] = fishRecord(SECRET, { pool = true }),
			[STRAY] = fishRecord(STRAY),
			[GONE] = fishRecord(GONE, { removed = true }),
			[SKULL] = itemRecord("junk"),
			[CATFISH_17] = itemRecord("trophy", { family = 2, weight = 17 }),
		},
		areas = {
			[ELWYNN] = area(25, { entry(MACKEREL), entry(SECRET, "night") }),
			[WESTFALL] = area(55, { entry(MACKEREL), entry(SECRET, "night") }),
			[DUSKWOOD] = area(150, { entry(MACKEREL), entry(NIGHTFISH, "night"), entry(SECRET, "night") }),
			[DARKSHORE] = area(nil, { entry(STRAY), entry(SKULL), entry(CATFISH_17) }),
		},
		windows = { night = { spec = night, confirmed = false } },
	})
end

-- A caught Cast of one `itemID` by character 1 in `zone` at realm `minute`. The log works its realm date out from the
-- time and minute (LOG-R49): 3 Oct 2026 by day, 2 Oct by night.
local function cast(time, itemID, zone, minute)
	return castRecord({ time = time, zone = zone, minute = minute, items = { itemID } })
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

-- A Ledger on a fake over the fixture and its log (with `extra` records after it), logged in with the projection
-- built, every name loaded, and lore for MACKEREL and SECRET only. `typicalLength`, if given, is MACKEREL's typical
-- length (mm), so Core sizes its Catches.
---@param extra table[]?
---@param typicalLength integer?
local function loggedIn(extra, typicalLength)
	local records = log()
	for _, record in ipairs(extra or {}) do
		records[#records + 1] = record
	end
	local catalogue = fixture()
	catalogue.items[MACKEREL].typicalLength = typicalLength
	return openJournal({
		catalogue = catalogue,
		log = records,
		itemNames = NAMES,
		areaNames = ZONES,
		before = function(loaded)
			local L = loaded.ns.L
			for key in pairs(L) do
				if type(key) == "string" and key:find("^species%.") then
					L[key] = nil
				end
			end
			L["species.6303.blurb"] = "Slippery enough to earn the name."
			L["species.6522.riddle"] = "Strange schools out on the dry plains."
		end,
		id = false,
	})
end

-- Opens the fish spread on Species `id` (with the plain hint open when `hint`).
local function openFish(loaded, id, hint)
	assert.is_true(loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.fish(id, hint)))
	return loaded.ns.journal.pages
end

-- The texts of a page's `text` blocks alone, in order (blockTexts has every block's).
local function textBlockTexts(blocks)
	local texts = {}
	for _, block in ipairs(blocks) do
		if block.kind == "text" then
			texts[#texts + 1] = block.text
		end
	end
	return texts
end

describe("a caught Species' entry (LED-R140)", function()
	it("shows its sepia icon, name, stamps, first Catch, blurb and listed zones (LED-R140)", function()
		local _, loaded = loggedIn()

		local left = openFish(loaded, MACKEREL).left

		assert.are.same({ kind = "icon", icon = MACKEREL, look = "sepia", large = true }, blockOfKind(left, "icon"))
		assert.are.equal("Raw Slitherskin Mackerel", blockOfKind(left, "title").text)
		assert.are.same({
			{ text = "Caught", inked = true },
			{ text = "In its element", inked = false },
			{ text = "Regular", inked = false },
		}, blockOfKind(left, "stamps").stamps)
		assert.are.same({
			"First landed 3 Oct in Westfall, by Angler. 2 caught.",
			"Slippery enough to earn the name.",
			"Found in Duskwood, Elwynn Forest and Westfall.",
		}, textBlockTexts(left))
	end)

	it('adds " Only by night." for a night-only fish, and leaves a missing blurb out (LED-R140, LED-R161)', function()
		local _, loaded = loggedIn()

		assert.are.same({
			"First landed 2 Oct in Elwynn Forest, by Angler. 1 caught.",
			"Found in Duskwood. Only by night.",
		}, textBlockTexts(openFish(loaded, NIGHTFISH).left))
	end)

	it("drops the zone part for a first Catch in zone 0 (LED-R140, LED-R6)", function()
		local _, loaded = loggedIn()

		assert.are.equal("First landed 3 Oct, by Angler. 1 caught.", textBlockTexts(openFish(loaded, STRAY).left)[1])
	end)

	it("shows the removed line, and no listed zones, for a removed one (LED-R140, LED-R12)", function()
		local _, loaded = loggedIn()

		assert.are.same({
			"First landed 3 Oct in Elwynn Forest, by Angler. 1 caught.",
			"No longer found in Forever's waters.",
		}, textBlockTexts(openFish(loaded, GONE).left))
	end)
end)

-- The size line's form (LED-R140), with the size text's "{band} · {length}" (LED-R81).
local SIZE_LINE = "^Largest by my own measure: %a+ · %d+%.%d cm %(Pagle's measure, not the game's%)$"

-- Gives Species `id` the record `record` on the projection's state (LED-R80), as a sized Catch leaves it.
local function seedRecord(loaded, id, length, band)
	local species = loaded.ns.projection:GetState().species[id]
	species.record = { length = length, band = band, catchId = "1-1", time = T0, char = 1, zone = ELWYNN }
	species.since = 0
end

describe("a caught Species' size line (LED-R140, LED-R80, LED-R85)", function()
	it("reads its record by Pagle's measure, in centimetres when set, after Found in (LED-R140, LOG-R69)", function()
		local fake, loaded = loggedIn()
		fake.profile.lengthUnit = "cm"
		seedRecord(loaded, MACKEREL, 342, 3)

		assert.are.same({
			"First landed 3 Oct in Westfall, by Angler. 2 caught.",
			"Slippery enough to earn the name.",
			"Found in Duskwood, Elwynn Forest and Westfall.",
			"Largest by my own measure: Hefty · 34.2 cm (Pagle's measure, not the game's)",
		}, textBlockTexts(openFish(loaded, MACKEREL).left))
	end)

	it("reads it in the Angler's unit, inches by default in the Americas (LED-R85, LOG-R69)", function()
		local _, loaded = loggedIn()
		seedRecord(loaded, MACKEREL, 342, 3)

		local texts = textBlockTexts(openFish(loaded, MACKEREL).left)
		assert.are.equal("Largest by my own measure: Hefty · 13.5 in (Pagle's measure, not the game's)", texts[4])
	end)

	it("comes before the removed line (LED-R140, LED-R12)", function()
		local fake, loaded = loggedIn()
		fake.profile.lengthUnit = "cm"
		seedRecord(loaded, GONE, 1205, 5)

		assert.are.same({
			"First landed 3 Oct in Elwynn Forest, by Angler. 1 caught.",
			"Largest by my own measure: Monster · 120.5 cm (Pagle's measure, not the game's)",
			"No longer found in Forever's waters.",
		}, textBlockTexts(openFish(loaded, GONE).left))
	end)

	it("shows none for a Species without a sized Catch (LED-R140, LED-R80)", function()
		-- The fixture gives no Species a typical length, so Core sizes none of its Catches (LOG-R65).
		local _, loaded = loggedIn()

		assert.is_nil(loaded.ns.projection:GetState().species[MACKEREL].record)
		for _, text in ipairs(textBlockTexts(openFish(loaded, MACKEREL).left)) do
			assert.is_nil(text:find("Largest", 1, true))
		end
	end)

	it("reads the record Core's sizes leave once the Species has a typical length (LED-R140, LOG-R65)", function()
		local fake, loaded = loggedIn(nil, 300)
		fake.profile.lengthUnit = "cm"

		assert.is_not_nil(loaded.ns.projection:GetState().species[MACKEREL].record)
		assert.matches(SIZE_LINE, textBlockTexts(openFish(loaded, MACKEREL).left)[4])
	end)

	it("is the same line on the zone spread's entry (LED-R140, LED-R136)", function()
		local fake, loaded = loggedIn()
		fake.profile.lengthUnit = "cm"
		seedRecord(loaded, MACKEREL, 342, 3)

		assert.is_true(loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.zone(ELWYNN, MACKEREL)))
		local texts = textBlockTexts(loaded.ns.journal.pages.right)
		assert.are.equal("Largest by my own measure: Hefty · 34.2 cm (Pagle's measure, not the game's)", texts[#texts])
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

		journal:OpenPlace(loaded.ns.JournalPlace.home())
		openFish(loaded, SECRET)
		assert.are.equal("link", journal.pages.left[4].kind)
	end)

	it("keeps both pages' scroll on the fish spread as its hint opens (LED-R129, LED-R141)", function()
		local _, loaded = loggedIn()
		local journal = loaded.ns.journal
		openFish(loaded, SECRET)
		scrollPage(loaded, "left", 120)
		scrollPage(loaded, "right", 80)

		journal.frame.left.drawn.link[1]:Click()

		assert.are.equal("night · pools · Elwynn Forest · Westfall +1 · skill ~25", journal.pages.left[4].text)
		assert.are.same({ 120, 80 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
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

-- Types `query` into the open book's search box, as the player does: its text changes.
local function typeInto(loaded, query)
	local search = loaded.ns.journal.frame.search
	search:SetText(query)
	search:GetScript("OnTextChanged")(search, true)
end

-- The search dropdown's shown lines, in order.
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

describe("the Journal's search box (LED-R148)", function()
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
	-- An uncharted zone, fished: GetArea doesn't know it (LED-R138).
	local NOWHERE = 9999
	-- What is never caught, by its full name and the words of it that name it alone: an uncaught Species and curio
	-- item (LED-R124). A trophy weight is swept by its full name only: its pounds are shown, and its family by its
	-- lore name (LED-R143).
	local SWEPT = {
		{ name = NAMES[SECRET], words = { "Deviate" } },
		{ name = NAMES[SKULL], words = { "Skull" } },
		{ name = NAMES[CATFISH_17], words = {} },
	}

	-- The args every spread is drawn with: the uncaught Species chosen (nil where `species` is false), its plain hint
	-- shut and open, in zones that list it, an uncharted fished zone, the first continent tab and family 2. A spread
	-- ignores the args it doesn't take.
	local ARGS = {
		{ species = SECRET, zone = DUSKWOOD, tab = 0, family = 2 },
		{ species = SECRET, zone = ELWYNN, tab = 0, hint = true },
		{ species = false, zone = DARKSHORE, tab = "other" },
		{ species = false, zone = NOWHERE },
		{ species = SECRET, zone = NOWHERE },
	}

	-- A Ledger whose log also fishes the uncharted zone: STRAY and an Uncharted item there.
	local function swept()
		local _, loaded = loggedIn({
			cast(T0 + 300, STRAY, NOWHERE, DAY_MINUTE),
			cast(T0 + 360, 99999, NOWHERE, DAY_MINUTE),
		})
		loaded.ns.journal:Toggle()
		return loaded
	end

	-- `text` if it contains any of `names` (case-insensitive), else nil.
	local function naming(text, names)
		for _, name in ipairs(names) do
			if text:lower():find(name:lower(), 1, true) then
				return text
			end
		end
		return nil
	end

	-- Each shown widget under `widget` with an OnEnter script, depth first.
	local function hoverable(widget, found)
		found = found or {}
		for _, child in ipairs(widget.children) do
			if child.shown then
				if child.scripts.OnEnter then
					found[#found + 1] = child
				end
				hoverable(child, found)
			end
		end
		return found
	end

	-- The first text the book shows, or a tooltip on it holds, with any of `names` in it, as "{spread}: {text}", on
	-- any registered spread drawn with each of ARGS and Species `species` chosen; nil if none.
	local function anywhere(loaded, names, species)
		local journal = loaded.ns.journal
		local spreads = {}
		for id in pairs(loaded.ns.journalSpreads) do
			spreads[#spreads + 1] = id
		end
		table.sort(spreads)
		assert.is_true(#spreads >= 6)
		for _, id in ipairs(spreads) do
			for _, args in ipairs(ARGS) do
				-- The fish spread always has a Species: no place opens it without one.
				if args.species ~= false or id ~= loaded.ns.JOURNAL_FISH then
					local copy = {}
					for key, value in pairs(args) do
						copy[key] = value
					end
					copy.species = args.species ~= false and species or nil
					journal:Open(id, copy)
					for _, text in ipairs(shownTexts(journal.frame)) do
						if naming(text, names) then
							return id .. ": " .. text
						end
					end
					for _, widget in ipairs(hoverable(journal.frame)) do
						widget.scripts.OnEnter(widget)
						for _, line in ipairs(loaded.client.tooltipLines()) do
							if naming(line, names) then
								return id .. " (tooltip): " .. line
							end
						end
						if widget.scripts.OnLeave then
							widget.scripts.OnLeave(widget)
						end
					end
				end
			end
		end
		return nil
	end

	-- The names and words of `swept`, flat.
	local function namesOf(list)
		local names = {}
		for _, entry in ipairs(list) do
			names[#names + 1] = entry.name
			for _, word in ipairs(entry.words) do
				names[#names + 1] = word
			end
		end
		return names
	end

	it(
		"names an uncaught Species or curio item nowhere, in full or in part, on any spread or tooltip (LED-R124)",
		function()
			local loaded = swept()

			assert.is_nil(anywhere(loaded, namesOf(SWEPT), SECRET))
		end
	)

	it("finds none of them by search, in full or in part: only the no-match line (LED-R124, LED-R148)", function()
		local loaded = swept()

		for _, name in ipairs(namesOf(SWEPT)) do
			typeInto(loaded, name)
			assert.are.same({ "Nothing by that name in the Ledger yet." }, dropdown(loaded), name)
		end
	end)

	it("would find a caught Species' name, so the sweep reads what is drawn (LED-R124)", function()
		local loaded = swept()

		assert.is_not_nil(anywhere(loaded, { NAMES[MACKEREL] }, MACKEREL))
	end)

	it("would find a name a tooltip shows on hover, so the sweep reads tooltips (LED-R124)", function()
		local loaded = swept()
		local tooltip = loaded.env.GameTooltip
		loaded.ns.journal.frame.close:SetScript("OnEnter", function(self)
			tooltip:SetOwner(self, "ANCHOR_RIGHT")
			tooltip:SetText(NAMES[SECRET])
			tooltip:Show()
		end)

		assert.are.equal("angler (tooltip): Deviate Fish", anywhere(loaded, namesOf(SWEPT), SECRET))
	end)

	it("sweeps the uncharted zone's page: it shows what was caught there (LED-R138)", function()
		local loaded = swept()

		loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.zone(NOWHERE))

		assert.is_not_nil(naming(table.concat(shownTexts(loaded.ns.journal.frame), " / "), { NAMES[STRAY] }))
	end)
end)
