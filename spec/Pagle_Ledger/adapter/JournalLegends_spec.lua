-- The Journal's Legends on FakePagle (LED-R147, LED-R148, LED-R132, LED-R124, LED-R12, LED-R161): the Legends
-- spread, its plate, Legends in search and Home's contents line, over a fixture catalogue of three Legends and a log
-- catching one. The Legends use their real item IDs, so their blurbs and titles are the committed lore's
-- (data/Lore.lua).

local RACER, ANGELFISH, QUEENFISH = 19803, 19805, 19806
-- A fourth Legend, removed (DATA-R26), with no lore and no typical length: caught only in the removed case.
local GONE = 777100
local MACKEREL = 6303
local FERALAS, STV, ELWYNN = 357, 33, 12
local T0 = 1791731000 -- Sunday 11 October 2026, 15:03 UTC; realm minute 494 makes it 11 Oct on the realm too

local NAMES = {
	[RACER] = "Brownell's Blue Striped Racer",
	[ANGELFISH] = "Keefer's Angelfish",
	[QUEENFISH] = "Dezian Queenfish",
	[GONE] = "Gilded Gonefish",
	[MACKEREL] = "Raw Slitherskin Mackerel",
}
local ZONES = { [FERALAS] = "Feralas", [STV] = "Stranglethorn Vale", [ELWYNN] = "Elwynn Forest" }

-- A catalogue in the shape of ns.catalogue (DATA-R76): Stranglethorn lists the Racer and the Angelfish, Feralas the
-- Queenfish and the Mackerel, Elwynn the Mackerel. The removed Legend is on no list. Legends carry typical lengths, so Core sizes them
-- (LOG-R65); the removed one has none.
local function catalogue()
	local function item(fields)
		local record = { category = "fish", legend = false, noise = false, removed = false, pool = false }
		for key, value in pairs(fields) do
			record[key] = value
		end
		return record
	end
	local function area(skillBase, ...)
		local catches = {}
		for i, itemID in ipairs({ ... }) do
			catches[i] = { itemID = itemID, confirmed = false }
		end
		return {
			parent = 0,
			continent = 1,
			hasData = true,
			skillBase = skillBase,
			skillBaseConfirmed = false,
			catches = catches,
		}
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {
			[RACER] = item({ species = RACER, legend = true, typicalLength = 2200 }),
			[ANGELFISH] = item({ species = ANGELFISH, legend = true, typicalLength = 1800 }),
			[QUEENFISH] = item({ species = QUEENFISH, legend = true, typicalLength = 2000 }),
			[GONE] = item({ species = GONE, legend = true, removed = true }),
			[MACKEREL] = item({ species = MACKEREL, typicalLength = 300 }),
		},
		areas = {
			[STV] = area(225, RACER, ANGELFISH),
			[FERALAS] = area(205, QUEENFISH, MACKEREL),
			[ELWYNN] = area(25, MACKEREL),
		},
		aliases = {},
		pools = {},
		windows = {},
		events = {},
		fishingSpells = {},
		auras = {},
	}
end

-- A caught Cast of `itemID` in `zone` at `time`, by character 1.
local function cast(time, zone, itemID)
	return {
		kind = "cast",
		char = 1,
		time = time,
		outcome = "caught",
		conditions = { minute = 494, zone = zone, subzone = 0, events = {}, auras = {} },
		items = { { itemID = itemID, quantity = 1 } },
	}
end

-- The fixture log: the Angelfish in Stranglethorn, twice, and a Mackerel in Elwynn.
local FIXTURE = {
	cast(T0, STV, ANGELFISH),
	cast(T0 + 60, STV, ANGELFISH),
	cast(T0 + 120, ELWYNN, MACKEREL),
}

-- A Ledger on a fake over the catalogue and `log` (the fixture by default), logged in, in the world, every name
-- loaded, with the Journal open on spread `id` with `args`.
---@param id string
---@param args table?
---@param log table[]?
---@return FakePagle fake
---@return LoadedAddon loaded
local function spread(id, args, log)
	local fake = newFakePagle()
	fake.setCatalogue(catalogue())
	fake.catchLog.data.characters = {
		{ guid = PLAYER_GUID, name = "Angler", classID = 1, raceID = 1, faction = "Alliance", realmID = 4618 },
	}
	for _, record in ipairs(log or FIXTURE) do
		fake.catchLog:Append(record)
	end
	fake.globals.BreakUpLargeNumbers = breakUpLargeNumbers
	local loaded = fake.load("Pagle_Ledger")
	for itemID, name in pairs(NAMES) do
		loaded.client.itemNames[itemID] = name
	end
	for areaID, name in pairs(ZONES) do
		loaded.client.areaNames[areaID] = name
	end
	fake.login()
	fake.enterWorld()
	assert.is_true(loaded.ns.journal:Open(id, args))
	return fake, loaded
end

-- The texts of a page's blocks, in order (a block without text as its kind in brackets).
---@param blocks LedgerBlock[]
---@return string[]
local function texts(blocks)
	local list = {}
	for i, block in ipairs(blocks) do
		list[i] = block.text or ("[" .. block.kind .. "]")
	end
	return list
end

-- The first block of `kind` on a page.
---@param blocks LedgerBlock[]
---@param kind string
---@return LedgerBlock?
local function first(blocks, kind)
	for _, block in ipairs(blocks) do
		if block.kind == kind then
			return block
		end
	end
	return nil
end

-- Every word a drawn widget shows, depth first.
---@param widget table
---@param list string[]?
---@return string[]
local function drawnTexts(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if type(child.text) == "string" and child.text ~= "" then
				list[#list + 1] = child.text
			end
			drawnTexts(child, list)
		end
	end
	return list
end

describe("the Journal's Legends spread (LED-R147)", function()
	it("reads Home ❧ Legends in its crumbs, with the back link to Home (LED-R125, LED-R147)", function()
		local _, loaded = spread("legends")
		local pages = loaded.ns.journal.pages

		assert.are.same({ "Home", "Legends" }, { pages.crumbs[1].label, pages.crumbs[2].label })
		assert.are.same({ id = "home" }, pages.back)
	end)

	it(
		'lists each Legend in item ID order, caught by name, uncaught as "an unwritten legend", under x of N (LED-R147, LED-R63)',
		function()
			local _, loaded = spread("legends")
			local left = loaded.ns.journal.pages.left

			assert.are.same({
				"Legends",
				"1 of 3. These sit outside the Ledger's hundred.",
				"an unwritten legend",
				"Keefer's Angelfish",
				"an unwritten legend",
			}, texts(left))
			assert.are.same({ id = "legends", args = { legend = ANGELFISH } }, left[4].place)
			assert.are.same({ id = "legends", args = { legend = QUEENFISH } }, left[5].place)
		end
	)

	it("chooses the first Legend by default, and the one its args name (LED-R147)", function()
		local _, loaded = spread("legends")
		local journal = loaded.ns.journal
		assert.is_true(journal.pages.left[3].selected)
		assert.is_falsy(journal.pages.left[4].selected)

		journal:Open("legends", { legend = ANGELFISH })

		assert.is_falsy(journal.pages.left[3].selected)
		assert.is_true(journal.pages.left[4].selected)
		assert.are.equal("Keefer's Angelfish", first(journal.pages.right, "title").text)
	end)

	it("keeps the index's scroll as another Legend opens, starting its page at the top (LED-R129, LED-R147)", function()
		local _, loaded = spread("legends")
		local journal = loaded.ns.journal
		scrollPage(loaded, "left", 120)
		scrollPage(loaded, "right", 80)

		journal.frame.left.drawn.row[2]:Click()

		assert.are.equal("Keefer's Angelfish", first(journal.pages.right, "title").text)
		assert.are.same({ 120, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
		scrollPage(loaded, "right", 40)
		journal:Draw()
		assert.are.same({ 120, 40 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
	end)

	it("starts both pages at the top as the plate opens, which fills both (LED-R129, LED-R147)", function()
		local _, loaded = spread("legends", { legend = ANGELFISH })
		scrollPage(loaded, "left", 120)
		scrollPage(loaded, "right", 80)

		loaded.ns.journal.frame.right.drawn.link[1]:Click()

		assert.are.equal("plate", loaded.ns.journal.pages.left[1].kind)
		assert.are.same({ 0, 0 }, { pageScroll(loaded, "left"), pageScroll(loaded, "right") })
	end)

	it("shows a caught Legend's sepia icon, name, first Catch, blurb, title and the plate button (LED-R147)", function()
		local _, loaded = spread("legends", { legend = ANGELFISH })
		local right = loaded.ns.journal.pages.right

		assert.are.same({
			"Legend",
			"[icon]",
			"Keefer's Angelfish",
			"11 Oct, Stranglethorn Vale, Angler",
			"Far too handsome for a contest table, and it seems to know it.",
			"Title: Keefer's Rival",
			"Open the plate",
		}, texts(right))
		assert.are.same({ kind = "icon", icon = ANGELFISH, look = "sepia", large = true }, right[2])
		assert.are.same({ id = "legends", args = { legend = ANGELFISH, plate = true } }, right[7].place)
	end)

	it("leaves out a caught Legend's blurb and title while they have no text (LED-R161)", function()
		local _, loaded = spread("legends", { legend = ANGELFISH })
		local L = loaded.ns.L
		L["legend.19805.blurb"], L["legend.19805.title"] = nil, nil

		loaded.ns.journal:Draw()

		assert.are.same({
			"Legend",
			"[icon]",
			"Keefer's Angelfish",
			"11 Oct, Stranglethorn Vale, Angler",
			"Open the plate",
		}, texts(loaded.ns.journal.pages.right))
	end)

	it(
		"shows an uncaught Legend as a plain fish silhouette, never its icon, with the shared line (LED-R147, LED-R124)",
		function()
			local _, loaded = spread("legends", { legend = QUEENFISH })
			local right = loaded.ns.journal.pages.right

			assert.are.same({
				"Legend",
				"[icon]",
				"An unwritten legend",
				"Some fish are only caught once in a long while. This page waits for one.",
			}, texts(right))
			local icon = right[2]
			assert.are.equal("silhouette", icon.look)
			assert.are.equal("string", type(icon.icon))
			-- The same plain fish for every uncaught Legend: nothing about the Legend shows through.
			loaded.ns.journal:Open("legends", { legend = RACER })
			assert.are.equal(icon.icon, loaded.ns.journal.pages.right[2].icon)
		end
	)

	it("shows no line under an uncaught Legend while the shared line has no text (LED-R161)", function()
		local _, loaded = spread("legends", { legend = QUEENFISH })
		loaded.ns.L["line.uncaughtlegend.text"] = nil

		loaded.ns.journal:Draw()

		assert.are.same({ "Legend", "[icon]", "An unwritten legend" }, texts(loaded.ns.journal.pages.right))
	end)

	it("never opens the plate of an uncaught Legend (LED-R124)", function()
		local _, loaded = spread("legends", { legend = QUEENFISH, plate = true })

		assert.are.equal("An unwritten legend", first(loaded.ns.journal.pages.right, "title").text)
	end)

	it(
		"keeps a removed Legend's page with the removed line, out of both sides of x of N (LED-R12, LED-R147)",
		function()
			local log = { cast(T0, STV, ANGELFISH), cast(T0 + 60, 0, GONE) }
			local _, loaded = spread("legends", { legend = GONE }, log)
			local pages = loaded.ns.journal.pages

			assert.are.same({
				"Legends",
				"1 of 3. These sit outside the Ledger's hundred.",
				"an unwritten legend",
				"Keefer's Angelfish",
				"an unwritten legend",
				"Gilded Gonefish",
			}, texts(pages.left))
			-- Caught in zone 0: the first Catch's line has no zone (LED-R6).
			assert.are.same({
				"Legend",
				"[icon]",
				"Gilded Gonefish",
				"11 Oct, Angler",
				"Open the plate",
				"No longer found in Forever's waters.",
			}, texts(pages.right))
		end
	)

	it("draws the index, the page and the plate button on the book (LED-R147)", function()
		local _, loaded = spread("legends", { legend = ANGELFISH })
		local frame = loaded.ns.journal.frame

		local left, right = drawnTexts(frame.left), drawnTexts(frame.right)

		assert.is_truthy(table.concat(left, "\n"):find("an unwritten legend", 1, true))
		assert.is_truthy(table.concat(right, "\n"):find("Title: Keefer's Rival", 1, true))
		frame.right.drawn.link[1]:Click()
		assert.are.same(
			{ id = "legends", args = { legend = ANGELFISH, plate = true } },
			loaded.ns.journal.router:Place()
		)
	end)
end)

describe("a Legend's plate (LED-R147)", function()
	it(
		"fills both pages with the icon, name, first Catch, record size and title (LED-R147, LED-R80, LED-R81)",
		function()
			local fake, loaded = spread("legends", { legend = ANGELFISH, plate = true })
			local pages = loaded.ns.journal.pages
			local record = loaded.ns.projection:GetState().items[ANGELFISH].record
			-- The record's size as Core prints it: "{band} · {length}" in the Angler's unit (LED-R81, LOG-R69).
			local size = fake.Pagle.SIZE_BANDS[record.band].name .. " · " .. fake.Pagle.FormatLength(record.length)

			assert.are.equal(1, #pages.left)
			assert.are.equal(1, #pages.right)
			assert.are.same({
				kind = "plate",
				icon = ANGELFISH,
				text = "Keefer's Angelfish",
				place = { id = "legends", args = { legend = ANGELFISH } },
			}, pages.left[1])
			assert.are.same({
				kind = "plate",
				lines = { "11 Oct, Stranglethorn Vale, Angler", size, "Title: Keefer's Rival" },
				value = "Click anywhere to return.",
				place = { id = "legends", args = { legend = ANGELFISH } },
			}, pages.right[1])
			assert.is_truthy(size:find("^%a+ · [%d.]+ %a+$"))
		end
	)

	it("leaves the size out when the Legend's Catches have none (LED-R147, LED-R80)", function()
		local log = { cast(T0, 0, GONE) }
		local _, loaded = spread("legends", { legend = GONE, plate = true }, log)

		assert.is_nil(loaded.ns.projection:GetState().items[GONE].record)
		assert.are.same({ "11 Oct, Angler" }, loaded.ns.journal.pages.right[1].lines)
	end)

	it("returns to the Legend's page at a click anywhere on either page (LED-R147)", function()
		local _, loaded = spread("legends", { legend = ANGELFISH, plate = true })
		local journal = loaded.ns.journal
		local frame = journal.frame
		assert.is_truthy(table.concat(drawnTexts(frame.left), "\n"):find("Keefer's Angelfish", 1, true))
		assert.is_truthy(table.concat(drawnTexts(frame.right), "\n"):find("Title: Keefer's Rival", 1, true))

		frame.left.drawn.plate[1]:Click()
		assert.are.same({ id = "legends", args = { legend = ANGELFISH } }, journal.router:Place())

		journal:Open("legends", { legend = ANGELFISH, plate = true })
		frame.right.drawn.plate[1]:Click()
		assert.are.same({ id = "legends", args = { legend = ANGELFISH } }, journal.router:Place())
		assert.are.equal("Open the plate", first(journal.pages.right, "link").text)
	end)
end)

describe("Legends in the Journal's search (LED-R148)", function()
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

	it("finds a caught Legend by name beside the caught Species, sorted by name (LED-R148)", function()
		local _, loaded = spread("home")

		typeInto(loaded, "S")

		-- Zones first, then fish, each part sorted by name; both uncaught Legends have an "s" too.
		assert.are.same({
			"Elwynn Forest",
			"Feralas",
			"Stranglethorn Vale",
			"Keefer's Angelfish",
			"Raw Slitherskin Mackerel",
		}, dropdown(loaded))
	end)

	it("opens the Legends spread with the Legend picked chosen (LED-R148)", function()
		local _, loaded = spread("home")
		local journal = loaded.ns.journal
		typeInto(loaded, "keefer")

		journal.frame.searchDrop.rows[1]:Click()

		assert.are.same({ id = "legends", args = { legend = ANGELFISH } }, journal.router:Place())
		assert.are.equal("Keefer's Angelfish", first(journal.pages.right, "title").text)
	end)

	it("never matches an uncaught Legend (LED-R148, LED-R124)", function()
		local _, loaded = spread("home")

		typeInto(loaded, "queenfish")
		assert.are.same({ "Nothing by that name in the Ledger yet." }, dropdown(loaded))

		typeInto(loaded, "racer")
		assert.are.same({ "Nothing by that name in the Ledger yet." }, dropdown(loaded))
	end)
end)

describe("Home's Legends line (LED-R132)", function()
	it("reads Legends x / N between Curios and the Angler, and opens the Legends spread (LED-R132, LED-R63)", function()
		local _, loaded = spread("home")
		local journal = loaded.ns.journal
		local leaders = {}
		for _, block in ipairs(journal.pages.right) do
			if block.kind == "leader" then
				leaders[#leaders + 1] = block.text
			end
		end
		assert.are.same({
			"The Trophy Room",
			"Curios: junk, treasure, uncharted",
			"Legends",
			"The Angler: hands, titles, bindings",
		}, leaders)

		local line = journal.frame.right.drawn.leader[3]
		assert.are.same({ "Legends", "1 / 3" }, drawnTexts(line))
		line:Click()

		assert.are.same({ id = "legends" }, journal.router:Place())
		assert.are.same({ "Home", "Legends" }, { journal.pages.crumbs[1].label, journal.pages.crumbs[2].label })
	end)
end)

describe("never naming an uncaught Legend (LED-R124)", function()
	-- The args every spread is drawn with: an uncaught Legend chosen, plain and as a plate, beside the args other
	-- spreads take. A spread ignores the args it doesn't take.
	local ARGS = {
		{ legend = QUEENFISH, species = QUEENFISH, zone = FERALAS, tab = 1 },
		{ legend = QUEENFISH, plate = true, species = QUEENFISH, zone = FERALAS, tab = 1, hint = true },
	}

	-- The first text the book shows with `name` in it, as "{spread}: {text}", on any registered spread drawn with each
	-- of ARGS and Legend `legend` chosen; nil if none.
	local function anywhere(loaded, name, legend)
		local journal = loaded.ns.journal
		local spreads = {}
		for id in pairs(loaded.ns.journalSpreads) do
			spreads[#spreads + 1] = id
		end
		table.sort(spreads)
		for _, id in ipairs(spreads) do
			for _, args in ipairs(ARGS) do
				local copy = {}
				for key, value in pairs(args) do
					copy[key] = value
				end
				copy.legend, copy.species = legend, legend
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

	it("names an uncaught Legend, or its title, nowhere on any registered spread (LED-R124)", function()
		local _, loaded = spread("home")

		assert.is_nil(anywhere(loaded, NAMES[QUEENFISH], QUEENFISH))
		assert.is_nil(anywhere(loaded, "Queen-Catcher", QUEENFISH))
		assert.is_nil(anywhere(loaded, NAMES[RACER], RACER))
	end)

	it("would find a caught Legend's name, so the sweep reads what is drawn (LED-R124)", function()
		local _, loaded = spread("home")

		assert.is_not_nil(anywhere(loaded, NAMES[ANGELFISH], ANGELFISH))
	end)
end)
