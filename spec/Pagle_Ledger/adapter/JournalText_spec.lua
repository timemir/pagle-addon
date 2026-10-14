-- The Journal's words on FakePagle (LED-R126, LED-R127, LED-R161): the client's names and item loading, the Angler's
-- characters, live window lines over Pagle.NextWindow, and lore, as a spread reads them through `context.text`.

local MACKEREL = 6303 -- Raw Slitherskin Mackerel
local SNAPPER, SPRINGSCALE = 6362, 6358
local MINUTE = 60

-- A Ledger on a fake that has logged in and built its projection (login step 3).
local function loggedIn()
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_Ledger")
	fake.login()
	fake.enterWorld()
	return fake, loaded
end

-- Registers a test spread, "words", whose left page shows `line(text)` and counts its draws, and opens it.
---@param loaded LoadedAddon
---@param line fun(text: LedgerJournalText): string
---@return { draws: integer }
local function openWords(loaded, line)
	local counter = { draws = 0 }
	loaded.ns.RegisterJournalSpread("words", {
		crumbs = function()
			return {}
		end,
		draw = function(_, context)
			counter.draws = counter.draws + 1
			return { left = { { kind = "text", text = line(context.text) } }, right = {} }
		end,
	})
	loaded.ns.journal:Open("words")
	return counter
end

-- What the open spread's left page shows first.
local function shown(loaded)
	return loaded.ns.journal.pages.left[1].text
end

describe("the Journal's words on the client", function()
	describe("item names", function()
		it('show an uncached item as "…" and ask the client to load it (LED-R126)', function()
			local _, loaded = loggedIn()

			openWords(loaded, function(text)
				return text:Item(SPRINGSCALE)
			end)

			assert.are.equal("…", shown(loaded))
			assert.are.same({ SPRINGSCALE }, loaded.client.itemRequests)
		end)

		it("show a cached item's name and ask for nothing (LED-R126)", function()
			local _, loaded = loggedIn()
			loaded.client.itemNames[MACKEREL] = "Raw Slitherskin Mackerel"

			openWords(loaded, function(text)
				return text:Item(MACKEREL)
			end)

			assert.are.equal("Raw Slitherskin Mackerel", shown(loaded))
			assert.are.same({}, loaded.client.itemRequests)
		end)

		it("redraw once on the next frame however many asked-for items arrive in it (LED-R126, LED-R123)", function()
			local fake, loaded = loggedIn()
			local counter = openWords(loaded, function(text)
				return text:Item(SPRINGSCALE) .. " / " .. text:Item(SNAPPER)
			end)
			assert.are.equal(1, counter.draws)

			loaded.client.itemNames[SPRINGSCALE] = "Raw Spinefin Halibut"
			loaded.client.itemNames[SNAPPER] = "Raw Rainbow Fin Albacore"
			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", SPRINGSCALE, true)
			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", SNAPPER, true)
			assert.are.equal(1, counter.draws, "the redraw waits for the next frame")
			loaded.client.runTimers()

			assert.are.equal(2, counter.draws)
			assert.are.equal("Raw Spinefin Halibut / Raw Rainbow Fin Albacore", shown(loaded))
		end)

		it("redraw nothing for an item the Journal didn't ask for (LED-R126)", function()
			local fake, loaded = loggedIn()
			local counter = openWords(loaded, function(text)
				return text:Item(SPRINGSCALE)
			end)

			fake.fireGameEvent("GET_ITEM_INFO_RECEIVED", 2589, true)
			loaded.client.runTimers()

			assert.are.equal(1, counter.draws)
		end)

		it('read "Item {id}" in the Uncharted form (LED-R126)', function()
			local _, loaded = loggedIn()

			openWords(loaded, function(text)
				return text:Item(9999, true)
			end)

			assert.are.equal("Item 9999", shown(loaded))
			assert.are.same({ 9999 }, loaded.client.itemRequests)
		end)
	end)

	it("name zones from GetAreaInfo and fill lore's {zone} with them (LED-R126, LED-R161, DATA-R108)", function()
		local _, loaded = loggedIn()
		loaded.client.areaNames[148] = "Darkshore"
		loaded.ns.L["title.zonemaster.text"] = "Master of {zone}"
		local text = loaded.ns.journalText

		assert.are.equal("Darkshore", text:Zone(148))
		assert.are.equal("…", text:Zone(1519))
		assert.are.equal("Master of Darkshore", text:Lore("title.zonemaster.text", 148))
	end)

	it("leave a lore key with no text out (LED-R161)", function()
		local _, loaded = loggedIn()

		assert.is_nil(loaded.ns.journalText:Lore("line.neverwritten.text"))
	end)

	it('label continent tabs from GetMapInfo, and any other continent "Other waters" (LED-R126, LED-R130)', function()
		local _, loaded = loggedIn()
		loaded.client.mapNames = { [1414] = "Kalimdor", [1415] = "Eastern Kingdoms" }
		local text = loaded.ns.journalText

		assert.are.same(
			{ "Eastern Kingdoms", "Kalimdor", "Other waters" },
			{ text:Continent(0), text:Continent(1), text:Continent(2) }
		)
	end)

	it("name characters from Pagle.GetAngler().characters (LED-R126)", function()
		local _, loaded = loggedIn()

		assert.are.equal("Angler", loaded.ns.journalText:Character(1))
		assert.are.equal("…", loaded.ns.journalText:Character(2))
	end)

	it("print dates against the realm year read from GetGameTime and GetServerTime (LED-R126)", function()
		local _, loaded = loggedIn()
		local text = loaded.ns.journalText

		assert.are.equal("3 Mar", text:Date({ year = 2026, month = 3, day = 3 }))
		assert.are.equal("3 Mar 2025", text:Date({ year = 2025, month = 3, day = 3 }))
	end)

	describe("window lines", function()
		-- A catalogue whose night is 20:00 to 06:00, realm time.
		local function nightCatalogue()
			return {
				fingerprint = "0123456789abcdef",
				items = {},
				areas = {},
				aliases = {},
				pools = {},
				windows = { night = { spec = { time = { { 1200, 360 } } }, confirmed = false } },
				events = {},
				fishingSpells = {},
				auras = {},
			}
		end

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

		it(
			"read a night-only window's state live from Pagle.NextWindow at each draw, never cached (LED-R127, LOG-R50)",
			function()
				local fake, loaded = loggedIn()
				fake.setCatalogue(nightCatalogue())
				local counter = openWords(loaded, function(text)
					return text:WindowLine("night")
				end)

				-- Realm 08:15: night opens at 20:00, 11 h 45 min away.
				assert.are.equal("night, back in 12 h", shown(loaded))

				-- Realm 20:15, in the night.
				moveClocks(fake, loaded, 12 * 60)
				loaded.ns.journal:Draw()

				assert.are.equal(2, counter.draws)
				assert.are.equal("night, biting now", shown(loaded))
			end
		)

		it("read the generated day and night both biting in their overlap (LED-R127, #175)", function()
			-- The generated day is 06:00-24:00 and night 18:00-12:00 (Classic's four 6-hour fishing periods), so a
			-- Sunscale and a Nightfin row both read "biting now" in the morning and evening, and each reads "back in"
			-- only in the 6 hours its fish never bites.
			local fake, loaded = loggedIn()
			openWords(loaded, function(text)
				return text:WindowLine("day") .. " / " .. text:WindowLine("night")
			end)
			local function at(minutes)
				moveClocks(fake, loaded, minutes)
				loaded.ns.journal:Draw()
				return shown(loaded)
			end

			-- Realm 08:15.
			assert.are.equal("day, biting now / night, biting now", shown(loaded))
			-- Realm 14:15: night opens at 18:00, 3 h 45 min away.
			assert.are.equal("day, biting now / night, back in 4 h", at(6 * 60))
			-- Realm 20:15.
			assert.are.equal("day, biting now / night, biting now", at(6 * 60))
			-- Realm 02:15: day opens at 06:00, 3 h 45 min away.
			assert.are.equal("day, back in 4 h / night, biting now", at(6 * 60))
		end)

		it("read the label alone for a window GetWindowSpec doesn't know (LED-R127)", function()
			local fake, loaded = loggedIn()
			fake.setCatalogue(nightCatalogue())

			assert.are.equal("event", loaded.ns.journalText:WindowLine("event.999"))
			assert.are.equal("Extravaganza", loaded.ns.journalText:WindowLine("event.301"))
		end)
	end)
end)
