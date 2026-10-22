-- The Journal's fish varieties with no Core (VAR-R23, VAR-R24, VAR-R27): the fish spread's Varieties lines and the
-- varieties spread's pages as data, over a hand-made Ledger state, a Species' ten as Pagle.GetVarieties lists them and
-- the rarities as Pagle.VARIETY_RARITIES does.

describe("the Journal's fish varieties", function()
	local ns = loadAddon("Pagle_Ledger", FOREVER_GLOBALS).ns

	local FISH, PLAIN, UNCAUGHT = 6359, 6358, 6522
	local WESTFALL = 40
	-- The rarities as Core publishes them (VAR-R11): weights per 10,000, colours and parchment inks.
	local RARITIES = {
		{ key = "common", name = "Common", weight = 1750, color = { 1, 1, 1 }, ink = { 0.4, 0.35, 0.27 } },
		{ key = "uncommon", name = "Uncommon", weight = 733, color = { 0.12, 1, 0 }, ink = { 0.18, 0.42, 0.16 } },
		{ key = "rare", name = "Rare", weight = 350, color = { 0, 0.44, 0.87 }, ink = { 0.14, 0.25, 0.48 } },
		{ key = "epic", name = "Epic", weight = 100, color = { 0.64, 0.21, 0.93 }, ink = { 0.48, 0.18, 0.54 } },
	}
	local RARITY_OF = { 1, 1, 1, 1, 2, 2, 2, 3, 3, 4 }

	-- Variety `index` of `species` as Pagle.GetVarieties lists it: "Colour {index}", its words and its art.
	local function variety(species, index)
		return {
			id = species .. ".k" .. index,
			key = "k" .. index,
			index = index,
			rarity = RARITIES[RARITY_OF[index]].key,
			name = "Colour " .. index,
			description = "Words of colour " .. index .. ".",
			art = { texture = "Varieties1", left = index / 100, right = index / 100 + 0.09, top = 0, bottom = 0.05 },
		}
	end
	local function ten(species)
		local list = {}
		for index = 1, 10 do
			list[index] = variety(species, index)
		end
		return list
	end

	-- A first Catch on 14 Oct of SERVER_TIME's year in `zone`, by character 1.
	local function first(zone)
		return {
			entryId = "e",
			date = { year = ns.RealmDateAt(SERVER_TIME, 0).year, month = 10, day = 14 },
			zone = zone,
			char = 1,
		}
	end

	-- What the Journal reads (LedgerSpreadContext), as far as the varieties do: FISH caught with its varieties at
	-- `caught` ({ [position] = count }, positions 1, 2 and 8 by default) caught in Westfall; PLAIN caught with no
	-- varieties; UNCAUGHT never caught, with ten.
	local function contextWith(caught)
		caught = caught or { [1] = 6, [2] = 3, [8] = 2 }
		local varieties = {}
		for index, count in pairs(caught) do
			varieties[index] = { count = count, first = first(WESTFALL) }
		end
		local names = { [FISH] = "Raw Firefin Snapper", [PLAIN] = "Raw Plain Fish", [UNCAUGHT] = "Deviate Fish" }
		return {
			updating = false,
			now = SERVER_TIME,
			formatNumber = breakUpLargeNumbers,
			text = ns.NewJournalText({
				ItemName = function(itemID)
					return names[itemID]
				end,
				RequestItem = function() end,
				AreaName = function(areaID)
					return areaID == WESTFALL and "Westfall" or nil
				end,
				Characters = function()
					return { { name = "Thalindra" } }
				end,
				ServerTime = function()
					return SERVER_TIME
				end,
				RealmMinute = function()
					return nil
				end,
			}),
			state = {
				species = { [FISH] = { n = 11, zones = {} }, [PLAIN] = { n = 1, zones = {} } },
				varieties = { [FISH] = varieties },
			},
			getVarieties = function(species)
				if species == FISH or species == UNCAUGHT then
					return ten(species)
				end
				return nil
			end,
			rarities = RARITIES,
			fishCrest = function(species)
				return { icon = "crest-" .. species, name = species == FISH and "The Firefin Crest" or nil }
			end,
		}
	end

	-- The varieties spread's pages for `args`.
	local function spread(args, context)
		return ns.journalSpreads[ns.JOURNAL_VARIETIES].draw(args, context or contextWith())
	end

	-- Every string anywhere in `value`, nested tables included.
	local function strings(value, found)
		found = found or {}
		if type(value) == "string" then
			found[#found + 1] = value
		elseif type(value) == "table" then
			for _, item in pairs(value) do
				strings(item, found)
			end
		end
		return found
	end

	describe("on the fish spread (VAR-R23)", function()
		it('adds "Varieties" with "{n} of 10" and the link to the varieties spread, on the first caught', function()
			assert.are.same({
				{ kind = "kicker", text = "Varieties", value = "3 of 10" },
				{ kind = "link", text = "See all ten »", place = ns.JournalPlace.varieties(FISH, 1) },
			}, ns.JournalFishVarieties(FISH, contextWith()))
		end)

		it("opens the varieties spread on the first caught variety, in order", function()
			local lines = ns.JournalFishVarieties(FISH, contextWith({ [9] = 1, [5] = 2 }))

			assert.are.same(ns.JournalPlace.varieties(FISH, 5), lines[2].place)
		end)

		it("shows nothing for a Species without varieties, nor for one never caught", function()
			assert.are.same({}, ns.JournalFishVarieties(PLAIN, contextWith()))
			assert.are.same({}, ns.JournalFishVarieties(UNCAUGHT, contextWith()))
		end)
	end)

	describe("the varieties spread (VAR-R24)", function()
		it("reads Home ❧ {fish} ❧ Its colours, back to the fish spread (LED-R125)", function()
			local crumbs = ns.journalSpreads[ns.JOURNAL_VARIETIES].crumbs({ species = FISH }, contextWith())

			assert.are.same({
				{ label = "Raw Firefin Snapper", place = ns.JournalPlace.fish(FISH) },
				{ label = "Its colours", place = ns.JournalPlace.varieties(FISH) },
			}, crumbs)
		end)

		it("keeps the left page's scroll as a variety is picked, and starts the right page anew (LED-R129)", function()
			local router = ns.NewJournalRouter(ns.journalSpreads)
			local context = contextWith()
			router:Open(ns.JOURNAL_VARIETIES, { species = FISH, variety = 1 })
			local before = router:Pages(context).subjects
			router:Open(ns.JOURNAL_VARIETIES, { species = FISH, variety = 8 })
			local after = router:Pages(context).subjects

			assert.are.equal(before.left, after.left)
			assert.are_not.equal(before.right, after.right)
			assert.are.same(ns.JournalPlace.fish(FISH), router:Pages(context).back)
		end)

		it("heads its left page with the fish, Its colours and the varieties caught in the hand", function()
			local left = spread({ species = FISH }).left

			assert.are.same({
				{ kind = "kicker", text = "Raw Firefin Snapper" },
				{ kind = "title", text = "Its colours" },
				{ kind = "text", hand = true, text = "3 of 10 caught" },
			}, { left[1], left[2], left[3] })
			assert.are.equal(13, #left)
		end)

		it("lists a caught variety with its art, name, filled pill and count, opening it on the right", function()
			local row = spread({ species = FISH }).left[4 + 7]

			assert.are.same({
				kind = "variety",
				art = variety(FISH, 8).art,
				text = "Colour 8",
				rarity = { name = "Rare", color = RARITIES[3].color, ink = RARITIES[3].ink },
				inked = true,
				value = "2 caught",
				selected = false,
				place = ns.JournalPlace.varieties(FISH, 8),
			}, row)
		end)

		it('lists an uncaught one as a silhouette, "Undiscovered", its pill outlined and no count (VAR-R27)', function()
			local row = spread({ species = FISH }).left[4 + 9]

			assert.are.same({
				kind = "variety",
				art = variety(FISH, 10).art,
				look = "silhouette",
				text = "Undiscovered",
				rarity = { name = "Epic", color = RARITIES[4].color, ink = RARITIES[4].ink },
				inked = false,
				selected = false,
				place = ns.JournalPlace.varieties(FISH, 10),
			}, row)
		end)

		it("selects the variety asked for, else the first caught, else position 1", function()
			local function selected(args, context)
				local found = {}
				for _, block in ipairs(spread(args, context).left) do
					if block.selected then
						found[#found + 1] = block.place.args.variety
					end
				end
				return found
			end

			assert.are.same({ 9 }, selected({ species = FISH, variety = 9 }))
			assert.are.same({ 2 }, selected({ species = FISH }, contextWith({ [2] = 1, [5] = 1 })))
			assert.are.same({ 1 }, selected({ species = FISH }, contextWith({})))
			assert.are.same({ 1 }, selected({ species = FISH, variety = 11 }, contextWith({})))
		end)

		it(
			"shows a caught one on the right: its rarity's kicker in its ink, name, art large, words in italic, first Catch and count",
			function()
				local right = spread({ species = FISH, variety = 8 }).right

				assert.are.same({
					{ kind = "kicker", text = "A rare colour", ink = RARITIES[3].ink },
					{ kind = "title", text = "Colour 8" },
					{ kind = "varietyArt", art = variety(FISH, 8).art },
					{ kind = "text", style = "italic", text = "Words of colour 8." },
					{ kind = "text", text = "First landed 14 Oct in Westfall, by Thalindra. 2 caught." },
					{
						kind = "fishCrest",
						icon = "crest-" .. FISH,
						text = "The Firefin Crest",
						value = "7 to go.",
						foot = true,
					},
				}, right)
			end
		)

		it("leaves a first Catch's zone out at zone 0, and counts in the client's number format (LED-R126)", function()
			local context = contextWith({ [1] = 1234 })
			context.state.varieties[FISH][1].first.zone = 0

			assert.are.equal(
				"First landed 14 Oct, by Thalindra. 1,234 caught.",
				spread({ species = FISH, variety = 1 }, context).right[5].text
			)
		end)

		it(
			'shows an uncaught one as "Not yet discovered", its silhouette and its odds, no words (VAR-R24, VAR-R27)',
			function()
				local right = spread({ species = FISH, variety = 10 }).right

				assert.are.same({
					{ kind = "kicker", text = "An epic colour", ink = RARITIES[4].ink },
					{ kind = "title", text = "Not yet discovered" },
					{ kind = "varietyArt", art = variety(FISH, 10).art, look = "silhouette" },
					{ kind = "text", text = "Not landed yet. About one Catch in 100." },
					{
						kind = "fishCrest",
						icon = "crest-" .. FISH,
						text = "The Firefin Crest",
						value = "7 to go.",
						foot = true,
					},
				}, right)
				assert.are.equal(
					"Not landed yet. About one Catch in 14.",
					spread({ species = FISH, variety = 6 }).right[4].text
				)
				assert.are.equal(
					"Not landed yet. About one Catch in 29.",
					spread({ species = FISH, variety = 9 }).right[4].text
				)
			end
		)

		it(
			'reads "All ten." at the foot once every variety is caught, and the crest without a name before Core has it',
			function()
				local all = {}
				for index = 1, 10 do
					all[index] = 1
				end
				local context = contextWith(all)
				context.fishCrest = function(species)
					return { icon = "crest-" .. species }
				end

				assert.are.same(
					{ kind = "fishCrest", icon = "crest-" .. FISH, value = "All ten.", foot = true },
					spread({ species = FISH }, context).right[6]
				)
			end
		)

		it("never names an uncaught variety, nor shows its words, whichever is selected (VAR-R27)", function()
			local context = contextWith()
			for selected = 1, 10 do
				local pages = spread({ species = FISH, variety = selected }, context)
				local shown = table.concat(strings(pages), " / ")
				for _, index in ipairs({ 3, 4, 5, 6, 7, 9, 10 }) do
					assert.is_nil(shown:find("Colour " .. index .. "$"))
					assert.is_nil(shown:find("Colour " .. index .. " ", 1, true))
					assert.is_nil(shown:find("Words of colour " .. index, 1, true))
				end
			end
		end)

		it("never names an uncaught Species: its kicker is the unknown fish's (LED-R124)", function()
			local pages = spread({ species = UNCAUGHT })
			local crumbs = ns.journalSpreads[ns.JOURNAL_VARIETIES].crumbs({ species = UNCAUGHT }, contextWith())

			assert.are.same({ kind = "kicker", text = "An unknown fish" }, pages.left[1])
			assert.are.equal("An unknown fish", crumbs[1].label)
			assert.is_nil(table.concat(strings({ pages, crumbs }), " / "):find("Deviate", 1, true))
		end)
	end)
end)
