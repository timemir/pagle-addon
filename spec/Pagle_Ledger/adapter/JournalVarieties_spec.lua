-- The Journal's fish varieties on FakePagle (VAR-R23, VAR-R24, VAR-R27; core/varieties.md › UI): a fixture catalogue
-- whose Mackerel has its ten varieties (Core's own keys, so its lore names them) and a Catch log whose Catches Core
-- decodes into chosen varieties, the Ledger's projection built at login, and the fish and varieties spreads drawn.

local MACKEREL, NIGHTFISH, SECRET = 6303, 13759, 6522
local WESTFALL = 40
local NAMES =
	{ [MACKEREL] = "Raw Slitherskin Mackerel", [NIGHTFISH] = "Raw Nightfin Snapper", [SECRET] = "Deviate Fish" }
local MACKEREL_KEYS = {
	"tiger-backed",
	"blueback",
	"spotted",
	"shallow-water",
	"emerald",
	"bronze",
	"plainback",
	"golden",
	"pearl",
	"sea-witch",
}
local SECRET_KEYS = {
	"misshapen",
	"purple-finned",
	"two-tailed",
	"spined",
	"many-eyed",
	"glowgill",
	"lizard-scaled",
	"pale-nightmare",
	"crimson",
	"dreamers-spawn",
}
local T0 = 1791000000
local DAY_MINUTE = 494
local CREST = "Interface\\AddOns\\Pagle\\media\\crests\\fish\\6303"

-- Core's own variety hash (VAR-R3), to find a Cast time whose one Catch is a chosen variety.
local core = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- A caught Cast of one Mackerel in Westfall by character 1, at the first time from `from` (whole seconds) whose Catch,
-- the Cast's first, is variety `index` (VAR-R3): its Catch ID is the player's GUID, the time and tie 0, then ":1".
local function castOfVariety(index, from)
	local time = from
	while core.VarietyIndex(("%s-%d-0:1"):format(PLAYER_GUID, time)) ~= index do
		time = time + 1
	end
	return castRecord({ time = time, zone = WESTFALL, minute = DAY_MINUTE, items = { MACKEREL } })
end

-- The fixture: Mackerel sized (so its Catches have varieties, VAR-R1) with its ten, any time in Westfall; Nightfin
-- caught, with none; SECRET listed with its ten and never caught.
local function fixture()
	return catalogueWith({
		items = {
			[MACKEREL] = fishRecord(MACKEREL, { typicalLength = 300, varieties = MACKEREL_KEYS }),
			[NIGHTFISH] = fishRecord(NIGHTFISH),
			[SECRET] = fishRecord(SECRET, { typicalLength = 300, varieties = SECRET_KEYS }),
		},
		areas = {
			[WESTFALL] = areaRecord(0, {
				skillBase = 55,
				catches = { catchEntry(MACKEREL), catchEntry(NIGHTFISH), catchEntry(SECRET) },
			}),
		},
	})
end

-- Mackerel's Catches by variety: Tiger-backed twice, Blueback once, Golden (Rare) once; and one Nightfin.
local function log()
	local records, from = {}, T0
	for _, index in ipairs({ 1, 1, 2, 8 }) do
		local record = castOfVariety(index, from)
		records[#records + 1] = record
		from = record.time + 60
	end
	records[#records + 1] = castRecord({ time = from, zone = WESTFALL, minute = DAY_MINUTE, items = { NIGHTFISH } })
	return records
end

-- A Ledger on a fake over the fixture and its log, logged in, every name loaded, open at `place` when given (else
-- closed). `crestName`, if given, is the name Core gives Mackerel's fish crest good (VAR-R12); none by default, as
-- before Core registers it.
local function loggedIn(place, crestName)
	return openJournal({
		catalogue = fixture(),
		log = log(),
		itemNames = NAMES,
		areaNames = { [WESTFALL] = "Westfall" },
		modules = function(fake)
			local getGood = fake.Pagle.GetGood
			fake.Pagle.GetGood = function(goodID)
				if crestName and goodID == "core.crest.fish.6303" then
					return { name = crestName, icon = CREST }
				end
				return getGood(goodID)
			end
		end,
		place = place,
		id = not place and false or nil,
	})
end

-- The variety rows drawn on the open book's left page, in order.
local function rows(loaded)
	local list = {}
	for _, row in ipairs(loaded.ns.journal.frame.left.drawn.variety or {}) do
		list[#list + 1] = row
	end
	return list
end

describe("the varieties spread (VAR-R24)", function()
	it("lists the ten from Core's lore: names caught, the rest Undiscovered, counts in the hand", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL })

		local left = loaded.ns.journal.pages.left
		local names, counts = {}, {}
		for i, row in ipairs(rows(loaded)) do
			names[i] = row.name:GetText()
			counts[i] = row.count:IsShown() and row.count:GetText() or false
		end

		assert.are.same({ "Raw Slitherskin Mackerel", "Its colours", "3 of 10 caught" }, {
			left[1].text,
			left[2].text,
			left[3].text,
		})
		assert.are.same({
			"Tiger-backed",
			"Blueback",
			"Undiscovered",
			"Undiscovered",
			"Undiscovered",
			"Undiscovered",
			"Undiscovered",
			"Golden",
			"Undiscovered",
			"Undiscovered",
		}, names)
		assert.are.same({ "2 caught", "1 caught", false, false, false, false, false, "1 caught", false, false }, counts)
	end)

	it(
		"draws a caught variety's art in its colours, and an uncaught one's as its silhouette (core/varieties.md › UI)",
		function()
			local _, loaded = loggedIn({ "varieties", MACKEREL })
			local list = rows(loaded)

			local caught, uncaught = list[8].art, list[10].art

			assert.are.equal("Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1", caught.texture:sub(1, 52))
			assert.are.equal(4, #caught.texCoord)
			assert.are.same({ false, { 1, 1, 1, 1 } }, { caught.desaturated, caught.vertexColor })
			assert.are.same({ true, { 0, 0, 0, 0.28 } }, { uncaught.desaturated, uncaught.vertexColor })
			assert.are.same({ 76, 38 }, { caught:GetWidth(), caught:GetHeight() })
		end
	)

	it("fills a caught variety's pill in its rarity's ink and outlines an uncaught one's", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL })
		local list = rows(loaded)

		local rare, epic = list[8].pill, list[10].pill
		local ink = loaded.env.Pagle.VARIETY_RARITIES[3].ink

		assert.are.same({ "Rare", true, false }, { rare.label:GetText(), rare.fill:IsShown(), rare.edges[1]:IsShown() })
		assert.are.same({ ink[1], ink[2], ink[3], 1 }, rare.fill.color)
		assert.are.same({ "Epic", false, true }, { epic.label:GetText(), epic.fill:IsShown(), epic.edges[1]:IsShown() })
	end)

	it(
		"bands the first caught at first, and opens a row on the right, keeping the left page's scroll (LED-R129)",
		function()
			local _, loaded = loggedIn({ "varieties", MACKEREL })
			local journal = loaded.ns.journal
			assert.is_true(rows(loaded)[1].band:IsShown())
			scrollPage(loaded, "left", 30)

			rows(loaded)[8]:Click()

			assert.are.equal(30, pageScroll(loaded, "left"))
			assert.are.same({ false, true }, { rows(loaded)[1].band:IsShown(), rows(loaded)[8].band:IsShown() })
			assert.are.same({
				"A rare colour",
				"Golden",
				"[varietyArt]",
				"Gold bars on gold. Looks expensive. Fries like a mackerel.",
				"First landed 3 Oct in Westfall, by Angler. 1 caught.",
				"[fishCrest]",
			}, blockTexts(journal.pages.right))
		end
	)

	it("shows an uncaught variety's silhouette large, its odds and never its name (VAR-R27)", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL, 10 })
		local journal = loaded.ns.journal

		local art = journal.frame.right.drawn.varietyArt[1].art

		assert.are.same(
			{ "An epic colour", "Not yet discovered", "[varietyArt]", "Not landed yet. About one Catch in 100." },
			{
				journal.pages.right[1].text,
				journal.pages.right[2].text,
				"[" .. journal.pages.right[3].kind .. "]",
				journal.pages.right[4].text,
			}
		)
		assert.are.same(
			{ 340, 170, true, { 0, 0, 0, 0.28 } },
			{ art:GetWidth(), art:GetHeight(), art.desaturated, art.vertexColor }
		)
	end)

	it("draws the rarity's kicker in its ink", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL, 8 })

		local kicker = loaded.ns.journal.frame.right.drawn.kicker[1].label
		local ink = loaded.env.Pagle.VARIETY_RARITIES[3].ink

		assert.are.same({ ink[1], ink[2], ink[3] }, { kicker.textColor[1], kicker.textColor[2], kicker.textColor[3] })
	end)

	it("puts the fish crest, its shield, at the right page's foot with what is left to go", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL })

		local foot = loaded.ns.journal.frame.right.drawn.fishCrest[1]

		assert.are.same({ CREST, false, "7 to go." }, { foot.crest.texture, foot.name:IsShown(), foot.toGo:GetText() })
		assert.are.same({ 0.5 - 60 / 140, 0.5 + 60 / 140, 0, 1 }, foot.crest.texCoord)
		local page = loaded.ns.journal.frame.right
		-- its anchor's last figure is how far down the page it sits: at the foot, the page's margin under it, so the
		-- page needs no scrolling
		local anchor = { foot:GetPoint(1) }
		assert.are.equal(page.height - 8, -anchor[#anchor] + foot:GetHeight())
		assert.is_false(page.thumb:IsShown())
	end)

	it("names the crest once Core has its good (VAR-R12)", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL }, "The Mackerel Crest")

		local foot = loaded.ns.journal.frame.right.drawn.fishCrest[1]

		assert.are.same({ true, "The Mackerel Crest" }, { foot.name:IsShown(), foot.name:GetText() })
	end)

	it("writes in a variety caught while the spread is open, on the next frame (LED-R123)", function()
		local fake, loaded = loggedIn({ "varieties", MACKEREL })

		fake.live(fake.catchLog:Append(castOfVariety(10, T0 + 3600)))
		loaded.client.runTimers()

		assert.are.equal("Sea-witch", rows(loaded)[10].name:GetText())
		assert.are.equal("4 of 10 caught", loaded.ns.journal.pages.left[3].text)
	end)
end)

describe("discovery in the Journal (VAR-R27)", function()
	-- Each uncaught variety's name and words, from Core's lore.
	local function uncaughtWords(loaded, species, caught)
		local words = {}
		local list = loaded.env.Pagle.GetVarieties(species)
		for index = 1, 10 do
			local entry = list[index]
			if not caught[index] then
				words[#words + 1] = entry.name
				words[#words + 1] = entry.description
			end
		end
		return words
	end

	-- The first shown text on the open book holding any of `words`, else nil.
	local function shownAny(loaded, words)
		for _, text in ipairs(shownTexts(loaded.ns.journal.frame)) do
			for _, word in ipairs(words) do
				if text:find(word, 1, true) then
					return text
				end
			end
		end
		return nil
	end

	it(
		"names no uncaught variety, nor shows its words, on the fish or varieties spread, whichever is selected",
		function()
			local _, loaded = loggedIn({ "fish", MACKEREL })
			local words = uncaughtWords(loaded, MACKEREL, { [1] = true, [2] = true, [8] = true })
			assert.are.equal(14, #words)

			assert.is_nil(shownAny(loaded, words))
			for index = 1, 10 do
				loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.varieties(MACKEREL, index))
				assert.is_nil(shownAny(loaded, words))
			end
		end
	)

	it("never names an uncaught Species, nor any of its varieties, on its varieties spread (LED-R124)", function()
		local _, loaded = loggedIn({ "varieties", SECRET })
		local words = uncaughtWords(loaded, SECRET, {})
		words[#words + 1] = "Deviate"

		for index = 1, 10 do
			loaded.ns.journal:OpenPlace(loaded.ns.JournalPlace.varieties(SECRET, index))
			assert.is_nil(shownAny(loaded, words))
		end
		assert.are.equal("An unknown fish", loaded.ns.journal.pages.crumbs[2].label)
	end)

	it("would find a caught variety's name, so the sweep reads what is drawn", function()
		local _, loaded = loggedIn({ "varieties", MACKEREL })

		assert.is_not_nil(shownAny(loaded, { "Golden" }))
	end)
end)
