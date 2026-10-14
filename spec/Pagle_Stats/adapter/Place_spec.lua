-- A place's page in the Stats book on FakePagle (STA-R17, STA-R18, STA-R42, STA-R96; stats.md › UI › Place spread): the
-- left page's kicker, title, Casts, no-junk sentence, no-chart line, *Its waters*, row groups and the across-the-zone
-- line; each row's ★, short odds and margin Dry spell; the right page before an item is chosen; and choosing a row.
-- A history goes into the Catch log before login, so the projection's first build counts it.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local DARKSHORE, AUBERDINE, BASHAL_ARAN, STRANGLETHORN, STORMWIND = 148, 442, 446, 33, 1519
local UNCHARTED_SUBZONE = 9999
local MACKEREL, BLACKMOUTH, FIREFIN, NIGHTFIN, SMALLFISH = 6303, 6358, 6359, 13759, 6291
local UNCHARTED = 77777 -- an item the catalogue lacks
local T0 = 1791731000 -- 11 October 2026: not summer
local DAY = 600 -- realm 10:00: the fixture's day is 06:00–18:00

local NAMES = {
	[MACKEREL] = "Mackerel",
	[BLACKMOUTH] = "Blackmouth",
	[FIREFIN] = "Firefin",
	[NIGHTFIN] = "Nightfin",
	[SMALLFISH] = "Smallfish",
	[UNCHARTED] = "Odd Fish",
}

-- A Cast record for fake.catchLog:Append, by day at skill 175 (Darkshore's line is 170: side hi) unless `c` says
-- otherwise. `c.items` are item IDs (none: got away).
---@param c { time: integer, zone: integer?, subzone: integer?, items: integer[]? }
local function cast(c)
	local items = {}
	for i, itemID in ipairs(c.items or {}) do
		items[i] = { itemID = itemID, quantity = 1 }
	end
	return {
		kind = "cast",
		char = 1,
		time = c.time,
		outcome = c.items and "caught" or "gotAway",
		conditions = {
			minute = DAY,
			zone = c.zone or DARKSHORE,
			subzone = c.subzone or 0,
			skillRank = 150,
			skillMod = 25,
			events = {},
			auras = {},
		},
		items = items,
	}
end

-- 150 Casts in Darkshore by day, at skill 175, 10 s apart, catching (STA-R43, STA-R50–R52 worked by hand):
--   Smallfish on Casts 1–5: 1 in 30, 145 since, P = (1 − 5/150)^145 ≈ 0.0073: unlucky
--   Blackmouth on Casts 10 and 20: 1 in 75, 130 since, P ≈ 0.17: normal
--   the Uncharted item on Cast 100: 1 in 150, 50 since
--   Firefin on Cast 150, the last: 1 in 150, just now
-- Mackerel is never caught (not seen yet); Nightfin's `night` window holds no Cast (learning 0/100). 141 got away.
local function darkshore()
	local catches = { [10] = BLACKMOUTH, [20] = BLACKMOUTH, [100] = UNCHARTED, [150] = FIREFIN }
	for i = 1, 5 do
		catches[i] = SMALLFISH
	end
	local records = {}
	for i = 1, 150 do
		records[i] = cast({ time = T0 + 10 * i, items = catches[i] and { catches[i] } })
	end
	return records
end

-- A new FakePagle whose log has the player's character and `records`.
local function withHistory(records)
	local fake = newFakePagle()
	fake.catchLog.data.characters[1] = { guid = PLAYER_GUID }
	for _, record in ipairs(records) do
		fake.catchLog:Append(record)
	end
	return fake
end

-- Moves the player to `zone` and `subzone` with Fishing `rank` (no modifier; nil: secret).
local function moveTo(fake, zone, subzone, rank)
	local conditions = {}
	for key, value in pairs(fake.conditions) do
		conditions[key] = value
	end
	conditions.zone, conditions.subzone, conditions.skillRank, conditions.skillMod = zone, subzone, rank, 0
	fake.setConditions(conditions)
end

-- Stats on `fake` (a new one over `records` if a table of records), logged in with its projection built, the areas
-- and items named, the player in Darkshore's Auberdine at skill 200 (side hi). `options` go to stats.load.
local function ready(records, options)
	local fake = records and records.catchLog and records or withHistory(records or {})
	local loaded = stats.load(fake, options)
	local client = loaded.client
	client.areaNames[DARKSHORE] = "Darkshore"
	client.areaNames[AUBERDINE] = "Auberdine"
	client.areaNames[BASHAL_ARAN] = "Bashal'Aran"
	client.areaNames[STRANGLETHORN] = "Stranglethorn Vale"
	client.areaNames[STORMWIND] = "Stormwind City"
	for itemID, name in pairs(NAMES) do
		client.itemNames[itemID] = name
	end
	fake.login()
	fake.enterWorld()
	moveTo(fake, DARKSHORE, AUBERDINE, 200)
	return loaded.ns, loaded, fake
end

-- Opens the book on `area`'s page (with `item` chosen) and returns the left and right content frames.
local function open(ns, area, item)
	ns.OpenBook({ page = "place", area = area, item = item })
	return ns.book.pages["place:left"].content, ns.book.pages["place:right"].content
end

-- Every text under `widget`, shown, depth first in the order the widgets were made.
local function allTexts(widget, texts)
	texts = texts or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text ~= nil and child.text ~= "" then
				texts[#texts + 1] = child.text
			end
			allTexts(child, texts)
		end
	end
	return texts
end

-- How far down its parent a block sits: every line of a page is anchored by its top left, SetPoint("TOPLEFT", x, -y).
local function topOf(widget)
	local anchor = widget.points[1]
	if anchor and anchor[1] == "TOPLEFT" and type(anchor[2]) == "number" then
		return -anchor[3]
	end
end

-- The shown blocks under `frame` (lines anchored by their top left; frames without such an anchor are looked into),
-- top to bottom.
local function blocksOf(frame)
	local blocks = {}
	local function walk(widget)
		for _, child in ipairs(widget.children) do
			if child.shown then
				if topOf(child) then
					blocks[#blocks + 1] = child
				else
					walk(child)
				end
			end
		end
	end
	walk(frame)
	table.sort(blocks, function(a, b)
		return topOf(a) < topOf(b)
	end)
	return blocks
end

-- The texts of a page, top to bottom: each block's own text, then those inside it.
local function textsOf(frame)
	local texts = {}
	for _, block in ipairs(blocksOf(frame)) do
		if block.text ~= nil and block.text ~= "" then
			texts[#texts + 1] = block.text
		end
		allTexts(block, texts)
	end
	return texts
end

-- Whether `list` holds `value`.
local function has(list, value)
	for _, item in ipairs(list) do
		if item == value then
			return true
		end
	end
	return false
end

-- The shown rows of a page, top to bottom.
local function rowsOf(content)
	local rows = {}
	for _, block in ipairs(blocksOf(content)) do
		if block.isBookRow then
			rows[#rows + 1] = block
		end
	end
	return rows
end

-- The rows' item names, in order.
local function namesOf(content)
	local out = {}
	for i, row in ipairs(rowsOf(content)) do
		out[i] = row.name.text
	end
	return out
end

-- The shown row whose name is `name`.
local function rowNamed(content, name)
	for _, row in ipairs(rowsOf(content)) do
		if row.name.text == name then
			return row
		end
	end
	error("no row " .. name)
end

-- The group headings (in small caps) and row names down the left page, in order.
local function layoutOf(content)
	local out = {}
	for _, block in ipairs(blocksOf(content)) do
		if block.isBookRow then
			out[#out + 1] = block.name.text
		elseif block.label and block.note and block.rule and block.label.text ~= "ITS WATERS" then -- a group heading
			out[#out + 1] = block.label.text
		end
	end
	return out
end

-- The shown line of a page whose label reads `text`.
local function lineNamed(content, text)
	for _, block in ipairs(blocksOf(content)) do
		if block.label and block.label.text == text then
			return block
		end
	end
	error("no line " .. text)
end

describe("a place's page (stats.md › UI › Place spread)", function()
	describe("its rows (STA-R17)", function()
		it("lists a zone's GetZoneCatches and its catches, without Noise or removed items", function()
			local ns = ready(darkshore())

			local left = open(ns, DARKSHORE)

			-- Rusted Lure (removed) is on Darkshore's list but never a row.
			assert.are.same({ "Smallfish", "Firefin", "Mackerel", "Blackmouth", "Nightfin", "Odd Fish" }, namesOf(left))
			left = open(ns, STRANGLETHORN)
			assert.are.same({ "Mackerel" }, namesOf(left)) -- not the Noise Minor Mana Potion
		end)

		it("lists a subzone's own list, or its zone's own when it has none", function()
			local ns = ready()

			assert.are.same({ "Smallfish", "Firefin" }, namesOf((open(ns, AUBERDINE))))
			-- Darkshore's own list: Mackerel, Blackmouth, Firefin, Nightfin (all learning: by item ID in each group)
			assert.are.same({ "Mackerel", "Firefin", "Blackmouth", "Nightfin" }, namesOf((open(ns, BASHAL_ARAN))))
		end)

		it("asks the client for an item whose name isn't loaded and shows it as Item {id} meanwhile", function()
			local ns, loaded = ready()
			loaded.client.itemNames[SMALLFISH] = nil

			local left = open(ns, AUBERDINE)

			assert.are.same({ "Item 6291", "Firefin" }, namesOf(left))
			assert.is_true(has(loaded.client.itemRequests, SMALLFISH))
		end)
	end)

	describe("its groups (STA-R18)", function()
		it("puts each row in its group under its heading, an empty group left out, sorted by Your odds", function()
			local ns = ready(darkshore())

			assert.are.same({
				"ANY TIME",
				"Smallfish", -- 1 in 30
				"Firefin", -- 1 in 150
				"Mackerel", -- not seen yet
				"POOLS",
				"Blackmouth",
				"IN THEIR WINDOW",
				"Nightfin",
				"ALSO CAUGHT HERE",
				"Odd Fish",
			}, layoutOf((open(ns, DARKSHORE))))
			assert.are.same({ "ANY TIME", "Smallfish", "Firefin" }, layoutOf((open(ns, AUBERDINE))))
		end)

		it("writes each group's small note", function()
			local ns = ready(darkshore())

			local texts = textsOf((open(ns, DARKSHORE)))

			assert.is_true(has(texts, "Your odds · Dry spell"))
			assert.is_true(has(texts, "open water and pools combined"))
			assert.is_true(has(texts, "only Casts in their window"))
			assert.is_true(has(texts, "not on Pagle's chart for these waters"))
		end)
	end)

	describe("its rows' words (STA-R43, STA-R50; UI › Place spread)", function()
		it("show the short odds, learning in handwriting, and the Dry spell in the margin", function()
			local ns = ready(darkshore())
			local left = open(ns, DARKSHORE)
			local hand = ns.BookFonts().hand

			local smallfish = rowNamed(left, "Smallfish")
			assert.are.equal("1 in 30", smallfish.odds.text)
			assert.are.equal("145 since", smallfish.margin.text)
			assert.are.equal(", unlucky", smallfish.band.text)
			assert.is_true(smallfish.band.shown)
			assert.are.same(ns.BOOK_LOOK.red, { unpack(smallfish.band.textColor, 1, 3) })

			local blackmouth = rowNamed(left, "Blackmouth")
			assert.are.same({ "1 in 75", "130 since" }, { blackmouth.odds.text, blackmouth.margin.text })
			assert.is_false(blackmouth.band.shown) -- normal: no band word

			local firefin = rowNamed(left, "Firefin")
			assert.are.same({ "1 in 150", "just now" }, { firefin.odds.text, firefin.margin.text })

			local mackerel = rowNamed(left, "Mackerel")
			assert.are.equal("not seen yet", mackerel.odds.text)
			assert.is_false(mackerel.margin.shown) -- never caught here: nothing in the margin

			local nightfin = rowNamed(left, "Nightfin")
			assert.are.equal("learning 0/100", nightfin.odds.text)
			assert.are.equal(hand, nightfin.odds.fontObject)
			assert.are_not.equal(hand, smallfish.odds.fontObject)

			assert.are.same(
				{ "1 in 150", "50 since" },
				{ rowNamed(left, "Odd Fish").odds.text, rowNamed(left, "Odd Fish").margin.text }
			)
		end)

		it("stars a row watched from this place, and only from this place (STA-R60)", function()
			local ns = ready(darkshore())
			ns.db.profile.watched = { { item = SMALLFISH, area = DARKSHORE }, { item = FIREFIN, area = AUBERDINE } }

			local left = open(ns, DARKSHORE)

			assert.is_true(rowNamed(left, "Smallfish").star.shown)
			assert.is_false(rowNamed(left, "Firefin").star.shown)
			left = open(ns, AUBERDINE)
			assert.is_true(rowNamed(left, "Firefin").star.shown)
			assert.is_false(rowNamed(left, "Smallfish").star.shown)
		end)

		it("names each row in an ink of its quality", function()
			local ns = ready(darkshore())

			local left = open(ns, DARKSHORE)

			assert.are.same(ns.BookQualityInk(1), { unpack(rowNamed(left, "Smallfish").name.textColor, 1, 3) })
			-- The Uncharted item has no catalogue quality and the client gives none: plain ink.
			assert.are.same(ns.BOOK_LOOK.ink, { unpack(rowNamed(left, "Odd Fish").name.textColor, 1, 3) })
		end)
	end)

	describe("an Uncharted Catch (STA-R96)", function()
		it("shows under Also caught here in each place it was caught", function()
			local records = darkshore()
			records[#records + 1] = cast({ time = T0 + 2000, subzone = AUBERDINE, items = { UNCHARTED } })
			local ns = ready(records)

			assert.are.same(
				{ "ANY TIME", "Smallfish", "Firefin", "ALSO CAUGHT HERE", "Odd Fish" },
				layoutOf((open(ns, AUBERDINE)))
			)
			assert.is_nil(ns.State().places[BASHAL_ARAN])
			assert.is_false(has(namesOf((open(ns, BASHAL_ARAN))), "Odd Fish"))
		end)

		it("moves to its group once a catalogue change classifies it and the projection rebuilds (STA-R91)", function()
			local fake = withHistory(darkshore())
			local ns, loaded = ready(fake)
			local log, global = fake.catchLog.data, loaded.env.PagleStatsDB.global
			local before = layoutOf((open(ns, DARKSHORE)))
			assert.are.same({ "ALSO CAUGHT HERE", "Odd Fish" }, { before[9], before[10] })

			-- The next release lists it in Darkshore by night.
			local catalogue = stats.catalogue()
			catalogue.fingerprint = "0123456789abcdef"
			catalogue.items[UNCHARTED] = {
				category = "fish",
				species = UNCHARTED,
				quality = 1,
				legend = false,
				noise = false,
				removed = false,
				pool = false,
			}
			local entries = catalogue.areas[DARKSHORE].catches
			entries[#entries + 1] = {
				itemID = UNCHARTED,
				confirmed = false,
				window = "night",
				gate = { time = { { 1080, 360 } } },
				gateConfirmed = false,
			}
			local later = newFakePagle()
			later.catchLog.data = log
			later.globals.PagleStatsDB = { global = global }
			ns = ready(later, { catalogue = catalogue })

			local layout = layoutOf((open(ns, DARKSHORE)))
			assert.are.same({ "IN THEIR WINDOW", "Nightfin", "Odd Fish" }, { layout[7], layout[8], layout[9] })
			assert.are.equal(9, #layout) -- no Also caught here
			assert.are.equal("learning 0/100", rowNamed((open(ns, DARKSHORE)), "Odd Fish").odds.text)
		end)
	end)

	describe("its left page (UI › Place spread)", function()
		it("reads a zone's kicker, its name with I'm here, my Casts and the no-junk sentence", function()
			local ns = ready(darkshore())

			local texts = textsOf((open(ns, DARKSHORE)))

			assert.are.same({ "WATERS", "Darkshore", "I'm here" }, { texts[1], texts[2], texts[3] })
			assert.are.equal(
				"150 of my Casts here. No junk from 170; at 200 I'm past it, so only those Casts count.",
				texts[4]
			)
		end)

		it("reads a subzone's zone as its kicker, and I'm here only in the place I'm in", function()
			local ns, _, fake = ready(darkshore())

			local texts = textsOf((open(ns, AUBERDINE)))
			assert.are.same({ "DARKSHORE", "Auberdine", "I'm here" }, { texts[1], texts[2], texts[3] })

			texts = textsOf((open(ns, BASHAL_ARAN)))
			assert.are.same({ "DARKSHORE", "Bashal'Aran" }, { texts[1], texts[2] })
			assert.are.equal(
				"0 of my Casts here. No junk from 170; at 200 I'm past it, so only those Casts count.",
				texts[3]
			)

			moveTo(fake, STRANGLETHORN, 0, 200)
			assert.is_false(has(textsOf((open(ns, DARKSHORE))), "I'm here"))
		end)

		it("writes the no-junk sentence below the line, with an unknown skill, and none without a line", function()
			local ns, _, fake = ready(darkshore())

			moveTo(fake, DARKSHORE, AUBERDINE, 120)
			assert.is_true(
				has(
					textsOf((open(ns, DARKSHORE))),
					"150 of my Casts here. No junk from 170; at 120 I'm below it, so only my Casts below it count."
				)
			)
			moveTo(fake, DARKSHORE, AUBERDINE, nil)
			assert.is_true(has(textsOf((open(ns, DARKSHORE))), "150 of my Casts here. No junk from 170."))
			assert.is_true(has(textsOf((open(ns, STORMWIND))), "0 of my Casts here."))
		end)

		it("says Pagle has no chart for an area with hasData false or one the catalogue lacks", function()
			local ns = ready()

			assert.is_true(has(textsOf((open(ns, STORMWIND))), "Pagle has no chart of these waters yet."))
			assert.is_true(has(textsOf((open(ns, UNCHARTED_SUBZONE))), "Pagle has no chart of these waters yet."))
			assert.is_false(has(textsOf((open(ns, DARKSHORE))), "Pagle has no chart of these waters yet."))
		end)

		it("lists a zone's waters with my Casts, — for none and I'm here, each opening its page", function()
			local records = darkshore()
			for i = 1, 3 do
				records[#records + 1] = cast({ time = T0 + 2000 + 10 * i, subzone = BASHAL_ARAN })
			end
			local ns = ready(records)

			local left = open(ns, DARKSHORE)
			local texts = textsOf(left)

			local at = 0
			for i, text in ipairs(texts) do
				if text == "ITS WATERS" then
					at = i
				end
			end
			assert.are.same(
				{ "ITS WATERS", "my Casts", "Auberdine", "I'm here", "—", "Bashal'Aran", "3" },
				{ unpack(texts, at, at + 6) }
			)
			assert.is_false(has(textsOf((open(ns, AUBERDINE))), "ITS WATERS")) -- a subzone has none

			lineNamed((open(ns, DARKSHORE)), "Bashal'Aran"):Click()
			assert.are.same({ page = "place", area = BASHAL_ARAN }, ns.book.router:Place())
		end)

		it("says a subzone under 100 Casts reads across its zone, until it holds them (STA-R42)", function()
			local records = darkshore()
			for i = 1, 99 do
				records[#records + 1] = cast({ time = T0 + 2000 + 10 * i, subzone = AUBERDINE })
			end
			local line = "Fish with fewer than 100 Casts in Auberdine use all of Darkshore until then."
			local ns = ready(records)

			assert.is_true(has(textsOf((open(ns, AUBERDINE))), line))
			assert.is_false(has(textsOf((open(ns, DARKSHORE))), line))

			records[#records + 1] = cast({ time = T0 + 3000, subzone = AUBERDINE })
			ns = ready(records)
			assert.is_false(has(textsOf((open(ns, AUBERDINE))), line))
		end)
	end)

	describe("its right page with no item chosen (UI › Place spread)", function()
		it("reads About these waters, the place's Casts, Catches and Got away with its rate", function()
			local ns = ready(darkshore())

			local _, right = open(ns, DARKSHORE)

			assert.are.same({
				"ABOUT THESE WATERS",
				"Darkshore",
				"Casts",
				"150",
				"Catches",
				"9",
				"Got away",
				"141 (94%)",
				"Pick a fish on the left for its odds and its Dry spell.",
			}, textsOf(right))
		end)

		it("reads 0 and — where I haven't fished", function()
			local ns = ready()

			local _, right = open(ns, AUBERDINE)

			assert.are.same({ "Casts", "0", "Catches", "0", "Got away", "—" }, { unpack(textsOf(right), 3, 8) })
		end)
	end)

	describe("choosing a row (STA-R74)", function()
		it("chooses its item, shades its row, and the breadcrumbs gain the item", function()
			local ns = ready(darkshore())
			local left = open(ns, DARKSHORE)

			rowNamed(left, "Blackmouth"):Click()

			assert.are.same({ page = "place", area = DARKSHORE, item = BLACKMOUTH }, ns.book.router:Place())
			left = ns.book.pages["place:left"].content
			assert.is_true(rowNamed(left, "Blackmouth").shade.shown)
			assert.is_false(rowNamed(left, "Smallfish").shade.shown)
			local crumbs = {}
			for _, crumb in ipairs(ns.book.frame.crumbButtons) do
				if crumb.shown then
					crumbs[#crumbs + 1] = crumb.label.text
				end
			end
			assert.are.same({ "Stats", "Darkshore", "Blackmouth" }, crumbs)
		end)

		it("fills the right page with the item's entry from its registered renderer", function()
			local ns = ready(darkshore())
			local drawn = {}
			ns.RegisterPlaceEntry(function(frame, place)
				drawn[#drawn + 1] = place
				frame.words = frame.words or frame:CreateFontString()
				frame.words:SetText("entry " .. place.item)
				return 300
			end)

			local _, right = open(ns, DARKSHORE, SMALLFISH)

			assert.are.same({ { page = "place", area = DARKSHORE, item = SMALLFISH } }, drawn)
			assert.are.same({ "entry 6291" }, allTexts(right))
			_, right = open(ns, DARKSHORE)
			assert.are.equal("ABOUT THESE WATERS", textsOf(right)[1])
		end)
	end)
end)
