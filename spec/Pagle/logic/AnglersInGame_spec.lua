-- Core's reads of the Companion's two data files (core/anglers-in-game.md): Pagle_Following and Pagle_Anglers read,
-- absent or expired as pagle-backend's IGV-R44 and IGV-R45 say (VIEW-R1, VIEW-R2), over IGV Contracts' examples
-- (anglerFileExamples).

local DAY = 24 * 3600
-- The examples' generatedAt: Pagle_Following's and Pagle_Anglers'.
local FOLLOWING_AT, ANGLERS_AT = 1791735100, 1791734400

describe("the Companion's data files", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- A copy of `data` with `changes` made at its top; NONE removes a field.
	local NONE = {}
	local function with(data, changes)
		local copy = {}
		for key, value in pairs(data) do
			copy[key] = value
		end
		for key, value in pairs(changes) do
			copy[key] = value ~= NONE and value or nil
		end
		return copy
	end

	describe("Pagle_Following", function()
		it("reads IGV Contracts' example live until it's 24 h old, then expired (VIEW-R1, IGV-R45)", function()
			local file = ns.ReadFollowingFile(anglerFileExamples().following)

			assert.are.equal("live", ns.ViewFileState(file, FOLLOWING_AT))
			assert.are.equal("live", ns.ViewFileState(file, FOLLOWING_AT + DAY - 1))
			assert.are.same({ "expired", DAY }, { ns.ViewFileState(file, FOLLOWING_AT + DAY) })
			assert.are.same({ "expired", DAY + 3600 }, { ns.ViewFileState(file, FOLLOWING_AT + DAY + 3600) })
		end)

		it("reads a file written before a server time it's ahead of live (VIEW-R1)", function()
			local file = ns.ReadFollowingFile(anglerFileExamples().following)

			assert.are.equal("live", ns.ViewFileState(file, FOLLOWING_AT - 600))
		end)

		-- Each of IGV-R44's conditions, in its order, and the reason /pagle dev views gives (VIEW-R12).
		local ABSENT = {
			{ "no global", nil, "PagleFollowingData isn't a table" },
			{ "a global that isn't a table", "Ada", "PagleFollowingData isn't a table" },
			{ "no ok", { ok = NONE }, "ok isn't true" },
			{ "an ok that isn't true", { ok = 1 }, "ok isn't true" },
			{ "an unknown v", { v = 2 }, "an unknown file format, v 2" },
			{ "no v", { v = NONE }, "an unknown file format, v none" },
			{ "a generatedAt that isn't a number", { generatedAt = "1791735100" }, "generatedAt isn't a number" },
			{ "no count", { count = NONE }, "count isn't a number" },
			{ "a count that isn't the Anglers'", { count = 2 }, "count is 2, but anglers holds 1" },
			{ "no anglers", { anglers = NONE, count = 0 }, "anglers isn't a table" },
			{ "both a missing ok and an unknown v, the first", { ok = NONE, v = 2 }, "ok isn't true" },
		}
		for _, case in ipairs(ABSENT) do
			local name, changes, reason = case[1], case[2], case[3]
			it(("reads a file with %s absent, at any time (VIEW-R1, IGV-R44)"):format(name), function()
				local data = changes
				if type(changes) == "table" then
					data = with(anglerFileExamples().following, changes)
				end

				local file = ns.ReadFollowingFile(data)

				assert.are.equal(reason, file.reason)
				assert.are.equal("absent", ns.ViewFileState(file, FOLLOWING_AT))
				assert.are.equal("absent", ns.ViewFileState(file, FOLLOWING_AT + 2 * DAY))
			end)
		end

		it("gives a file the client didn't load the reason it's handed (VIEW-R1, IGV-R44)", function()
			local file = ns.ReadFollowingFile(nil, "no file (Pagle_Following isn't installed)")

			assert.are.equal("no file (Pagle_Following isn't installed)", file.reason)
			assert.are.equal("absent", ns.ViewFileState(file, FOLLOWING_AT))
		end)
	end)

	describe("Pagle_Anglers", function()
		it("reads IGV Contracts' example live until it's 24 h old, then expired (VIEW-R1, IGV-R45)", function()
			local file = ns.ReadAnglersFile(anglerFileExamples().anglers)

			assert.is_nil(file.reason)
			assert.are.equal("live", ns.ViewFileState(file, ANGLERS_AT + DAY - 1))
			assert.are.same({ "expired", DAY }, { ns.ViewFileState(file, ANGLERS_AT + DAY) })
		end)

		-- A copy of the example with `changes` made to its one block.
		local function block(changes)
			local data = anglerFileExamples().anglers
			data.blocks[1] = with(data.blocks[1], changes)
			return data
		end

		local ABSENT = {
			{ "no global", nil, "PagleAnglersData isn't a table" },
			{ "no ok", { ok = NONE }, "ok isn't true" },
			{ "an unknown v", { v = 0 }, "an unknown file format, v 0" },
			{ "no generatedAt", { generatedAt = NONE }, "generatedAt isn't a number" },
			{ "a count that isn't a number", { count = "1" }, "count isn't a number" },
			{ "a count that isn't the blocks'", { count = 0 }, "count is 0, but blocks holds 1" },
			{ "blocks that aren't a table", { blocks = "", count = 0 }, "blocks isn't a table" },
			{ "a block that isn't a table", { blocks = { "eu" } }, "block 1 isn't a table" },
		}
		local BLOCK_ABSENT = {
			{ "no cardCount", { cardCount = NONE }, "block 1's cardCount isn't a number" },
			{ "a keyCount that isn't a number", { keyCount = "3" }, "block 1's keyCount isn't a number" },
			{ "no titles", { titles = NONE }, "block 1's titles isn't a table" },
			{ "cards one byte short", { cards = ("0"):rep(31) }, "block 1's cards isn't 32 bytes long" },
			{ "cards for a card more", { cardCount = 3 }, "block 1's cards isn't 48 bytes long" },
			{ "no cards", { cards = NONE }, "block 1's cards isn't 32 bytes long" },
			{ "keys one key long", { keys = ("0"):rep(19) }, "block 1's keys isn't 57 bytes long" },
			{ "keys that aren't a string", { keys = 57 }, "block 1's keys isn't 57 bytes long" },
		}
		for _, case in ipairs(ABSENT) do
			local name, changes, reason = case[1], case[2], case[3]
			it(("reads a file with %s absent (VIEW-R1, IGV-R44)"):format(name), function()
				local data = changes and with(anglerFileExamples().anglers, changes) or nil

				local file = ns.ReadAnglersFile(data)

				assert.are.equal(reason, file.reason)
				assert.are.equal("absent", ns.ViewFileState(file, ANGLERS_AT))
			end)
		end
		for _, case in ipairs(BLOCK_ABSENT) do
			local name, changes, reason = case[1], case[2], case[3]
			it(("reads a file whose block has %s absent (VIEW-R1, IGV-R44)"):format(name), function()
				local file = ns.ReadAnglersFile(block(changes))

				assert.are.equal(reason, file.reason)
				assert.are.equal("absent", ns.ViewFileState(file, ANGLERS_AT))
			end)
		end

		it("checks every block, reading a file absent for its second (VIEW-R1, IGV-R44)", function()
			local data = anglerFileExamples().anglers
			data.blocks[2] = with(data.blocks[1], { titles = "Seeker of the Deep" })
			data.count = 2

			assert.are.equal("block 2's titles isn't a table", ns.ReadAnglersFile(data).reason)
		end)
	end)

	describe("looking up a unit", function()
		-- Ada's full card, as IGV Contracts' Pagle_Following example holds it, found as a Followed Angler.
		local ADA = {
			followed = true,
			name = "Ada",
			more = 1,
			hardcore = false,
			title = "Warden of Feralas Waters",
			level = 23,
			prestige = 1,
			ledger = 37,
			legends = 3,
			legendsTotal = 12,
			waters = 4,
			catches = 5120,
			asOf = 20261012,
			guids = { "Player-4618-0A1B2C3D", "Player-4618-0A1B2C3E" },
		}
		-- IGV Contracts' Pagle_Anglers cards, as its prose reads them: card 1 is title 2, Angler Level 23, prestige
		-- rank 1, Ledger 37%, Legends 3 of 12, not Hardcore; card 2 is title 1, Angler Level 60, prestige rank 12,
		-- Ledger 100%, Legends 7 of 12, a Hardcore Angler.
		local CARD_1 = {
			followed = false,
			title = "Warden of Feralas Waters",
			level = 23,
			prestige = 1,
			ledger = 37,
			legends = 3,
			legendsTotal = 12,
			hardcore = false,
		}
		local CARD_2 = {
			followed = false,
			title = "Seeker of the Deep",
			level = 60,
			prestige = 12,
			ledger = 100,
			legends = 7,
			legendsTotal = 12,
			hardcore = true,
		}
		-- A time both examples are live at.
		local NOW = FOLLOWING_AT + 60

		local function files(examples)
			examples = examples or anglerFileExamples()
			return ns.ReadFollowingFile(examples.following), ns.ReadAnglersFile(examples.anglers)
		end
		local function absent()
			return ns.ReadFollowingFile(nil)
		end

		it(
			"finds Ada in Pagle_Following by either of her GUIDs, as a Followed Angler's full card (VIEW-R10, IGV-R46)",
			function()
				local following = ns.ReadFollowingFile(anglerFileExamples().following)
				local anglers = ns.ReadAnglersFile(nil)

				assert.are.same(ADA, ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", NOW))
				assert.are.same(ADA, ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3E", NOW))
				assert.is_nil(ns.LookUpAngler(following, anglers, "Player-4395-01234567", NOW))
			end
		)

		it("compares Pagle_Following's GUIDs as strings, exactly (VIEW-R10, IGV-R46)", function()
			local following = ns.ReadFollowingFile(anglerFileExamples().following)

			assert.is_nil(ns.LookUpAngler(following, absent(), "Player-4618-0a1b2c3d", NOW))
			assert.is_nil(ns.LookUpAngler(following, absent(), "Player-4618-0A1B2C3", NOW))
		end)

		it("finds IGV Contracts' three keys in Pagle_Anglers, card 2 and card 1 twice (VIEW-R10, IGV-R46)", function()
			local anglers = ns.ReadAnglersFile(anglerFileExamples().anglers)

			assert.are.same(CARD_2, ns.LookUpAngler(absent(), anglers, "Player-4395-01234567", NOW))
			assert.are.same(CARD_1, ns.LookUpAngler(absent(), anglers, "Player-4618-0A1B2C3D", NOW))
			assert.are.same(CARD_1, ns.LookUpAngler(absent(), anglers, "Player-4618-0A1B2C3E", NOW))
		end)

		it(
			"forms the search key from the GUID as text: serverID and UID padded, the UID upper-cased (IGV-R46)",
			function()
				local anglers = ns.ReadAnglersFile(anglerFileExamples().anglers)

				assert.are.equal("046180A1B2C3D", ns.AnglerSearchKey("Player-4618-0A1B2C3D"))
				assert.are.equal("0000100000001", ns.AnglerSearchKey("Player-1-1"))
				assert.are.same(CARD_1, ns.LookUpAngler(absent(), anglers, "Player-4618-a1b2c3d", NOW))
				assert.are.same(CARD_2, ns.LookUpAngler(absent(), anglers, "Player-04395-1234567", NOW))
			end
		)

		-- GUIDs no file holds: 13-character search keys that aren't there, and GUIDs with no 13-character key.
		local NOT_THERE = {
			"Player-4618-0A1B2C3F",
			"Player-4618-0A1B2C3C",
			"Player-4395-01234566",
			"Player-4395-01234568",
			"Player-1-00000001",
			"Player-99999-FFFFFFFF",
			"Player-4618",
			"Player-4618-",
			"Player--0A1B2C3D",
			"Player-46180-A1B2C3D0",
			"Player-104618-0A1B2C3D",
			"Player-4618-00A1B2C3D",
			"Creature-0-4618-0-0-0-0A1B2C3D",
			"",
		}
		for _, guid in ipairs(NOT_THERE) do
			it(("finds nothing for %q (VIEW-R10, IGV-R46)"):format(guid), function()
				local following, anglers = files()

				assert.is_nil(ns.LookUpAngler(following, anglers, guid, NOW))
			end)
		end

		it("never looks up a nil GUID, or one that isn't a string (VIEW-R10)", function()
			local following, anglers = files()

			assert.is_nil(ns.LookUpAngler(following, anglers, nil, NOW))
			assert.is_nil(ns.LookUpAngler(following, anglers, 4618, NOW))
			assert.is_nil(ns.AnglerSearchKey(nil))
		end)

		it(
			"looks in Pagle_Following first, so a Followed Angler in both files is found there (VIEW-R10, VIEW-R93)",
			function()
				local following, anglers = files()

				assert.are.same(ADA, ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", NOW))
				assert.are.same(CARD_2, ns.LookUpAngler(following, anglers, "Player-4395-01234567", NOW))
			end
		)

		it("uses each file only while it's live, telling expiry at each lookup (VIEW-R2, VIEW-R10, IGV-R45)", function()
			local following, anglers = files()

			-- Pagle_Anglers was generated 700 s before Pagle_Following, so it expires first.
			local anglersExpired, followingExpired = ANGLERS_AT + DAY, FOLLOWING_AT + DAY
			assert.are.same(CARD_2, ns.LookUpAngler(following, anglers, "Player-4395-01234567", anglersExpired - 1))
			assert.is_nil(ns.LookUpAngler(following, anglers, "Player-4395-01234567", anglersExpired))
			assert.are.same(ADA, ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", followingExpired - 1))
			assert.is_nil(ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", followingExpired))
		end)

		it("finds a Followed Angler's card in Pagle_Anglers once Pagle_Following has expired (VIEW-R10)", function()
			local examples = anglerFileExamples()
			examples.anglers.generatedAt = FOLLOWING_AT + 3600
			local following, anglers = files(examples)

			assert.are.same(CARD_1, ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", FOLLOWING_AT + DAY))
		end)

		it("finds nothing in absent files (VIEW-R10, IGV-R44)", function()
			assert.is_nil(ns.LookUpAngler(absent(), ns.ReadAnglersFile(nil), "Player-4618-0A1B2C3D", NOW))
		end)

		it("reads title index 0, and one above the number of titles, as no title (IGV-R46)", function()
			local examples = anglerFileExamples()
			local block = examples.anglers.blocks[1]
			-- Card 1 at title index 0, card 2 at 3, one above the block's two titles.
			block.cards = "0002300103703120" .. "0036001210007121"
			local anglers = ns.ReadAnglersFile(examples.anglers)

			assert.are.equal("", ns.LookUpAngler(absent(), anglers, "Player-4618-0A1B2C3D", NOW).title)
			assert.are.equal("", ns.LookUpAngler(absent(), anglers, "Player-4395-01234567", NOW).title)
		end)

		it(
			"doubles every | in a Pagle_Anglers title, so the client draws it as written (VIEW-R10, VIEW-R13)",
			function()
				local examples = anglerFileExamples()
				examples.anglers.blocks[1].titles[2] = "Warden |cff00ff00of Feralas"
				local anglers = ns.ReadAnglersFile(examples.anglers)

				assert.are.equal(
					"Warden ||cff00ff00of Feralas",
					ns.LookUpAngler(absent(), anglers, "Player-4618-0A1B2C3D", NOW).title
				)
			end
		)

		-- A block of `cards` (each 16 characters) and `keys` (search key and card number each), its titles `titles`.
		local function packed(titles, cards, keys)
			local text = {}
			for i, key in ipairs(keys) do
				text[i] = key[1] .. ("%06d"):format(key[2])
			end
			return {
				region = "us",
				builtAt = ANGLERS_AT,
				cardCount = #cards,
				keyCount = #keys,
				titles = titles,
				cards = table.concat(cards),
				keys = table.concat(text),
			}
		end

		it("takes the first block with a match (VIEW-R10, IGV-R46)", function()
			local examples = anglerFileExamples()
			-- A second block whose one card, title 1 at Angler Level 5, Player-4618-0A1B2C3D also names.
			table.insert(
				examples.anglers.blocks,
				packed({ "Angler of the Shallows" }, { "0010500000000120" }, {
					{ "046180A1B2C3D", 1 },
					{ "4618000000001", 1 },
				})
			)
			examples.anglers.count = 2
			local anglers = ns.ReadAnglersFile(examples.anglers)

			assert.are.same(CARD_1, ns.LookUpAngler(absent(), anglers, "Player-4618-0A1B2C3D", NOW))
			assert.are.same({
				followed = false,
				title = "Angler of the Shallows",
				level = 5,
				prestige = 0,
				ledger = 0,
				legends = 0,
				legendsTotal = 12,
				hardcore = false,
			}, ns.LookUpAngler(absent(), anglers, "Player-46180-00000001", NOW))
		end)

		it(
			"stops at the first block with a match, even one whose card number isn't digits (VIEW-R10, IGV-R46)",
			function()
				local examples = anglerFileExamples()
				local first = examples.anglers.blocks[1]
				-- Player-4618-0A1B2C3D's key in the first block, its card number spoilt; the second block names it too.
				first.keys = first.keys:gsub("046180A1B2C3D000001", "046180A1B2C3D00000X")
				table.insert(
					examples.anglers.blocks,
					packed({ "Angler of the Shallows" }, { "0010500000000120" }, { { "046180A1B2C3D", 1 } })
				)
				examples.anglers.count = 2

				assert.is_nil(
					ns.LookUpAngler(absent(), ns.ReadAnglersFile(examples.anglers), "Player-4618-0A1B2C3D", NOW)
				)
			end
		)

		it("binary-searches a block's keys, finding each of them and nothing between (IGV-R46)", function()
			-- Seven keys, ascending, naming cards 1 to 7 in a shuffled order; card n is at Angler Level 10 + n.
			local order = { 4, 7, 1, 6, 2, 5, 3 }
			local keys, cards = {}, {}
			for n = 1, 7 do
				cards[n] = ("000%02d00000000120"):format(10 + n)
				keys[n] = { ("%05d%08X"):format(n * 2, 255 + n), order[n] }
			end
			local examples = anglerFileExamples()
			examples.anglers.blocks = { packed({}, cards, keys) }
			local anglers = ns.ReadAnglersFile(examples.anglers)

			for n = 1, 7 do
				local guid = ("Player-%d-%X"):format(n * 2, 255 + n)
				assert.are.equal(10 + order[n], ns.LookUpAngler(absent(), anglers, guid, NOW).level, guid)
				assert.is_nil(ns.LookUpAngler(absent(), anglers, ("Player-%d-%X"):format(n * 2 + 1, 255 + n), NOW))
			end
			assert.is_nil(ns.LookUpAngler(absent(), anglers, "Player-1-FF", NOW))
			assert.is_nil(ns.LookUpAngler(absent(), anglers, "Player-99-FF", NOW))
		end)

		it("hands out a fresh card each lookup, which the caller may change (VIEW-R10)", function()
			local following, anglers = files()

			local first = ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", NOW)
			first.guids[1], first.name = nil, "Changed"
			local card = ns.LookUpAngler(following, anglers, "Player-4395-01234567", NOW)
			card.level = 1

			assert.are.same(ADA, ns.LookUpAngler(following, anglers, "Player-4618-0A1B2C3D", NOW))
			assert.are.same(CARD_2, ns.LookUpAngler(following, anglers, "Player-4395-01234567", NOW))
		end)
	end)

	describe("the Followed Anglers", function()
		-- Ada as Pagle.GetFollowedAnglers hands her out: Pagle_Following's line, field for field.
		local ADA = {
			name = "Ada",
			more = 1,
			hardcore = false,
			title = "Warden of Feralas Waters",
			level = 23,
			prestige = 1,
			ledger = 37,
			legends = 3,
			legendsTotal = 12,
			waters = 4,
			catches = 5120,
			asOf = 20261012,
			guids = { "Player-4618-0A1B2C3D", "Player-4618-0A1B2C3E" },
		}

		it("are ok with IGV Contracts' example, Ada with her full card (VIEW-R11)", function()
			local file = ns.ReadFollowingFile(anglerFileExamples().following)

			assert.are.same({ state = "ok", anglers = { ADA } }, ns.FollowedAnglers(file, FOLLOWING_AT))
		end)

		it(
			"floor a Ledger percent the file pushes with a fraction, as %d did, and leave one that isn't a number (VIEW-R11)",
			function()
				local data = anglerFileExamples().following
				data.anglers[1].ledger = 99.6
				data.anglers[2] = { name = "Bea", ledger = "37", guids = {} }
				data.count = 2

				local anglers = ns.FollowedAnglers(ns.ReadFollowingFile(data), FOLLOWING_AT).anglers

				assert.are.equal(99, anglers[1].ledger)
				assert.are.equal("37", anglers[2].ledger)
			end
		)

		it("keep the file's order (VIEW-R11, IGV-R31)", function()
			local data = anglerFileExamples().following
			data.anglers[2] = { name = "Bea", more = 0, title = "", guids = {} }
			data.anglers[3] = { name = "Cy", guids = { "Player-1-00000002" } }
			data.count = 3

			local anglers = ns.FollowedAnglers(ns.ReadFollowingFile(data), FOLLOWING_AT).anglers

			assert.are.same({ "Ada", "Bea", "Cy" }, { anglers[1].name, anglers[2].name, anglers[3].name })
			assert.are.same({ name = "Bea", more = 0, title = "", guids = {} }, anglers[2])
		end)

		it("double every | in a name and a title, so the client draws them as written (VIEW-R11, VIEW-R13)", function()
			local data = anglerFileExamples().following
			data.anglers[1].name = "A|cffff0000da"
			data.anglers[1].title = "Warden |TInterface\\Icons\\X:0|t"

			local ada = ns.FollowedAnglers(ns.ReadFollowingFile(data), FOLLOWING_AT).anglers[1]

			assert.are.same({ "A||cffff0000da", "Warden ||TInterface\\Icons\\X:0||t" }, { ada.name, ada.title })
		end)

		it("are fresh copies at each call, which the caller may keep and change (VIEW-R11)", function()
			local data = anglerFileExamples().following
			local file = ns.ReadFollowingFile(data)

			local first = ns.FollowedAnglers(file, FOLLOWING_AT)
			first.anglers[1].name = "Changed"
			first.anglers[1].guids[1] = nil
			table.insert(first.anglers, { name = "Extra" })
			data.anglers[1].level = 99
			local second = ns.FollowedAnglers(file, FOLLOWING_AT)

			assert.are_not.equal(first.anglers, second.anglers)
			assert.are.same({ state = "ok", anglers = { ADA } }, second)
		end)

		it("are none for a live file with no Anglers (VIEW-R11)", function()
			local data = anglerFileExamples().following
			data.anglers, data.count = {}, 0

			assert.are.same(
				{ state = "none", anglers = {} },
				ns.FollowedAnglers(ns.ReadFollowingFile(data), FOLLOWING_AT)
			)
		end)

		it("are expired from the file's 24th hour, read again at each call (VIEW-R2, VIEW-R11)", function()
			local file = ns.ReadFollowingFile(anglerFileExamples().following)

			assert.are.equal("ok", ns.FollowedAnglers(file, FOLLOWING_AT + DAY - 1).state)
			assert.are.same({ state = "expired", anglers = {} }, ns.FollowedAnglers(file, FOLLOWING_AT + DAY))
		end)

		it("are absent for an absent file, whatever its reason (VIEW-R11, IGV-R44)", function()
			local data = anglerFileExamples().following
			data.ok = false

			assert.are.same(
				{ state = "absent", anglers = {} },
				ns.FollowedAnglers(ns.ReadFollowingFile(data), FOLLOWING_AT)
			)
			assert.are.same(
				{ state = "absent", anglers = {} },
				ns.FollowedAnglers(ns.ReadFollowingFile(nil, "not read yet"), FOLLOWING_AT)
			)
		end)
	end)

	describe("the Pagle block", function()
		-- A tooltip card as Pagle_Anglers gives it (IGV-R10), `fields` over it.
		local function tooltipCard(fields)
			local card = {
				followed = false,
				title = "Seeker of the Deep",
				level = 60,
				prestige = 0,
				ledger = 37,
				legends = 3,
				legendsTotal = 12,
				hardcore = false,
			}
			for key, value in pairs(fields or {}) do
				card[key] = value
			end
			return card
		end

		-- Prestige rank `rank`'s emblem in a line, at the 22 of lists and tooltips (LED-R152).
		local function emblem(rank)
			return ns.PrestigeEmblemMarkup(rank, 22)
		end

		-- The block's "Angler Level" line's right text for a tooltip card at prestige rank `rank`.
		local function levelText(rank)
			for _, line in ipairs(ns.AnglerTooltipLines(tooltipCard({ prestige = rank }))) do
				if line.left == "Angler Level" then
					return line.right
				end
			end
		end

		it("writes a pushed Ledger percent of 99.6 as 99%, not 100% (VIEW-R21)", function()
			local data = anglerFileExamples().following
			data.anglers[1].ledger = 99.6
			local card = ns.LookUpAngler(
				ns.ReadFollowingFile(data),
				ns.ReadAnglersFile(anglerFileExamples().anglers),
				"Player-4618-0A1B2C3D",
				FOLLOWING_AT
			)

			local shown
			for _, line in ipairs(ns.AnglerTooltipLines(card)) do
				if line.left == "Ledger" then
					shown = line.right
				end
			end

			assert.are.equal("99%", shown)
		end)

		it("writes a Followed Angler's lines, Following at the header's right (VIEW-R21, VIEW-R93)", function()
			local card = ns.LookUpAngler(
				ns.ReadFollowingFile(anglerFileExamples().following),
				ns.ReadAnglersFile(anglerFileExamples().anglers),
				"Player-4618-0A1B2C3D",
				FOLLOWING_AT
			)

			assert.are.same({
				{ left = " " },
				{
					left = "|TInterface\\AddOns\\Pagle\\media\\minimap\\Pagle:0|t Pagle Angler",
					leftColor = "teal",
					right = "Following",
					rightColor = "green",
				},
				{ left = "Warden of Feralas Waters", leftColor = "gold" },
				{
					left = "Angler Level",
					leftColor = "parchment",
					right = "23 · " .. emblem(1) .. " Prestige I",
					rightColor = "white",
				},
				{ left = "Ledger", leftColor = "parchment", right = "37%", rightColor = "white" },
				{ left = "Legends", leftColor = "parchment", right = "3 of 12", rightColor = "white" },
			}, ns.AnglerTooltipLines(card))
		end)

		it("writes a tooltip card's lines, nothing at the header's right and no region (VIEW-R21, IGV-R6)", function()
			local card = ns.LookUpAngler(
				ns.ReadFollowingFile(anglerFileExamples().following),
				ns.ReadAnglersFile(anglerFileExamples().anglers),
				"Player-4395-01234567",
				ANGLERS_AT
			)

			assert.are.same({
				{ left = " " },
				{ left = "|TInterface\\AddOns\\Pagle\\media\\minimap\\Pagle:0|t Pagle Angler", leftColor = "teal" },
				{ left = "Seeker of the Deep", leftColor = "gold" },
				{
					left = "Angler Level",
					leftColor = "parchment",
					right = "60 · " .. emblem(12) .. " Master Prestige 2",
					rightColor = "white",
				},
				{ left = "Ledger", leftColor = "parchment", right = "100%", rightColor = "white" },
				{ left = "Legends", leftColor = "parchment", right = "7 of 12", rightColor = "white" },
				{ left = "Hardcore Angler", leftColor = "red" },
			}, ns.AnglerTooltipLines(card))
		end)

		it(
			"writes Prestige I to X, then Master Prestige rank − 10 in words, each after its emblem (VIEW-R21, LED-R34, LED-R146, LED-R152)",
			function()
				assert.are.same({
					"60",
					"60 · " .. emblem(1) .. " Prestige I",
					"60 · " .. emblem(5) .. " Prestige V",
					"60 · " .. emblem(10) .. " Prestige X",
					"60 · " .. emblem(11) .. " Master Prestige 1",
					"60 · " .. emblem(23) .. " Master Prestige 13",
				}, { levelText(0), levelText(1), levelText(5), levelText(10), levelText(11), levelText(23) })
			end
		)

		it(
			"draws the rank's own emblem at 22, the Master's from rank 11, and none at rank 0 (VIEW-R21, LED-R152)",
			function()
				local atlas = ns.ATLASES.PrestigeEmblems
				-- The sprite a line's emblem shows, by its pixel box in Core's emblems atlas, and its size.
				local function emblemIn(text)
					local size, left, top = text:match(
						"^%d+ · |TInterface\\AddOns\\Pagle\\media\\prestige\\Emblems:"
							.. "(%d+):%d+:0:0:512:1024:(%d+):%d+:(%d+):%d+|t "
					)
					for name, sprite in pairs(atlas.sprites) do
						if sprite.x == tonumber(left) and sprite.y == tonumber(top) then
							return name, tonumber(size)
						end
					end
					return nil
				end

				assert.are.same({ "emblem-i", 22 }, { emblemIn(levelText(1)) })
				assert.are.same({ "emblem-vii", 22 }, { emblemIn(levelText(7)) })
				assert.are.same({ "emblem-x", 22 }, { emblemIn(levelText(10)) })
				assert.are.same({ "emblem-master", 22 }, { emblemIn(levelText(11)) })
				assert.are.same({ "emblem-master", 22 }, { emblemIn(levelText(23)) })
				assert.are.equal("60", levelText(0))
				assert.is_nil(levelText(0):find("|T", 1, true))
			end
		)

		it("leaves the title line out when there's none (VIEW-R21, IGV-R14)", function()
			local lines = ns.AnglerTooltipLines(tooltipCard({ title = "" }))

			assert.are.same({
				" ",
				"|TInterface\\AddOns\\Pagle\\media\\minimap\\Pagle:0|t Pagle Angler",
				"Angler Level",
				"Ledger",
				"Legends",
			}, {
				lines[1].left,
				lines[2].left,
				lines[3].left,
				lines[4].left,
				lines[5].left,
			})
			assert.are.equal(5, #lines)
		end)

		it("ends with Hardcore Angler, in red, for a Hardcore Angler (VIEW-R21)", function()
			local lines = ns.AnglerTooltipLines(tooltipCard({ hardcore = true }))

			assert.are.equal(7, #lines)
			assert.are.same(
				{ left = "Legends", leftColor = "parchment", right = "3 of 12", rightColor = "white" },
				lines[6]
			)
			assert.are.same({ left = "Hardcore Angler", leftColor = "red" }, lines[7])
		end)

		it(
			"writes no block for a card with a number that isn't one, and no title line for a title that isn't text (VIEW-R20)",
			function()
				local written = {}
				for _, field in ipairs({ "level", "prestige", "ledger", "legends", "legendsTotal" }) do
					written[field] = ns.AnglerTooltipLines(tooltipCard({ [field] = "7" })) ~= nil
				end
				assert.are.same(
					{ level = false, prestige = false, ledger = false, legends = false, legendsTotal = false },
					written
				)
				assert.are.equal(5, #ns.AnglerTooltipLines(tooltipCard({ title = 7 })))
			end
		)

		it("draws no glyph outside CORE-R9's set, at any rank (VIEW-R21, CORE-R9)", function()
			for _, rank in ipairs({ 0, 1, 10, 11, 23 }) do
				local card = tooltipCard({ prestige = rank, hardcore = true })
				for _, followed in ipairs({ false, true }) do
					card.followed = followed
					for _, line in ipairs(ns.AnglerTooltipLines(card)) do
						assert.are.same({}, glyphsOutside(line.left .. (line.right or "")))
					end
				end
			end
		end)

		it("names each colour it uses (VIEW-R21, IGV-R81)", function()
			assert.are.same({
				teal = "5FD3C4",
				green = "1EFF00",
				gold = "FFD100",
				parchment = "E9D8AE",
				white = "FFFFFF",
				red = "FF4B3A",
			}, ns.ANGLER_TIP_COLORS)
		end)
	end)

	-- From 1.6: the news block of a news-aware Companion's Pagle_Following (IGV-R60–R66), over IGV Contracts' second
	-- example (anglerFileExamples().news): Ada Brook's Monster record, her Hunt gold and Grimtusk's region headline.
	describe("the news", function()
		local MONSTER, HUNT, REGION = "3f9a0c1d2e4b5a69", "a01b2c3d4e5f6071", "77c0e1f2a3b4c5d6"
		-- The example's three lines as Pagle.GetNews hands them out, field for field, with `new`.
		local function lines(new)
			new = new or {}
			return {
				{
					id = MONSTER,
					kind = "monster",
					time = 1791733000,
					angler = 1,
					name = "Ada Brook",
					region = "",
					item = 6291,
					rank = 0,
					key = "",
					text = "",
					zone = 0,
					length = 544,
					new = new[MONSTER] == true,
				},
				{
					id = HUNT,
					kind = "hunt",
					time = 1791702000,
					angler = 1,
					name = "Ada Brook",
					region = "",
					item = 0,
					rank = 0,
					key = "night_run",
					text = "The Night Run",
					zone = 0,
					length = 0,
					new = new[HUNT] == true,
				},
				{
					id = REGION,
					kind = "region",
					time = 1791690000,
					angler = 0,
					name = "Grimtusk",
					region = "eu",
					item = 6358,
					rank = 0,
					key = "",
					text = "",
					zone = 0,
					length = 0,
					new = new[REGION] == true,
				},
			}
		end
		-- A time the example is live at.
		local NOW = FOLLOWING_AT + 60

		-- Core's reads over `data` as Pagle_Following's global, PagleDB.global `global` and a clock a spec moves
		-- (`clock.now`), started as login step 2 starts them (VIEW-R1).
		local function views(data, global, clock)
			global, clock = global or {}, clock or { now = NOW }
			local read = ns.NewAnglerViews({
				following = function()
					return data
				end,
				presence = function()
					return { installed = data ~= nil, loaded = data ~= nil }
				end,
				load = function()
					return false, "MISSING"
				end,
				anglers = function()
					return nil
				end,
				serverTime = function()
					return clock.now
				end,
				isRestricted = function()
					return false
				end,
				tooltips = function()
					return true
				end,
				isSecret = function()
					return false
				end,
				global = function()
					return global
				end,
			})
			read:Start()
			return read, global, clock
		end

		-- The ids of `items`, in order.
		local function ids(items)
			local out = {}
			for i, item in ipairs(items) do
				out[i] = item.id
			end
			return out
		end

		-- The keys of `set`, sorted.
		local function sortedKeys(set)
			local keys = {}
			for key in pairs(set) do
				keys[#keys + 1] = key
			end
			table.sort(keys)
			return keys
		end

		-- A PagleDB.global whose floor is `since` and whose seen items are `seen`.
		local function saved(since, seen)
			return { news = { since = since, seen = seen or {} } }
		end

		describe("reading the block", function()
			it(
				"reads IGV Contracts' example: every line, in the file's order, with its fields (VIEW-R40–R42, IGV-R64)",
				function()
					local read = views(anglerFileExamples().news)

					assert.are.same({ state = "ok", items = lines() }, read:News())
				end
			)

			it(
				"reads a file with no news block as before: the same Anglers and lookups, the news none, nothing kept (VIEW-R40, VIEW-R96, IGV-R65)",
				function()
					local old = ns.ReadFollowingFile(anglerFileExamples().following)
					local read, global = views(anglerFileExamples().following)

					assert.is_nil(old.news)
					assert.are.same(
						{ state = "ok", anglers = { anglerFileExamples().following.anglers[1] } },
						read:FollowedAnglers()
					)
					assert.are.equal("Ada", read:HoverPlayer("Player-4618-0A1B2C3E").name)
					assert.are.same({ state = "none", items = {} }, read:News())
					read:MarkNewsSeen()
					assert.are.same({}, global)
				end
			)

			it("reads the news example's Anglers as the file without its block reads them (VIEW-R40)", function()
				local withBlock = anglerFileExamples().news
				local without = anglerFileExamples().news
				without.news = nil

				assert.are.same(
					ns.FollowedAnglers(ns.ReadFollowingFile(without), NOW),
					ns.FollowedAnglers(ns.ReadFollowingFile(withBlock), NOW)
				)
			end)

			it("reads a news that isn't a table as no block, never an absent file (VIEW-R40)", function()
				local data = anglerFileExamples().news
				data.news = "news"

				local read = views(data)

				assert.are.same({ state = "none", items = {} }, read:News())
				assert.are.equal("ok", read:FollowedAnglers().state)
			end)

			it("reads an empty block ok, with no items (VIEW-R42, IGV-R65)", function()
				local data = anglerFileExamples().news
				data.news = {}

				assert.are.same({ state = "ok", items = {} }, views(data):News())
			end)

			-- VIEW-R41's checks, each breaking the first line alone: it is skipped, and the other two are used.
			local NOT_USED = {
				{ "a line that isn't a table", "line" },
				{ "no id", { id = NONE } },
				{ "an id in capitals", { id = "3F9A0C1D2E4B5A69" } },
				{ "an id of 15 digits", { id = "3f9a0c1d2e4b5a6" } },
				{ "an id of 17 digits", { id = "3f9a0c1d2e4b5a690" } },
				{ "an id that isn't hexadecimal", { id = "3f9a0c1d2e4b5a6g" } },
				{ "an id that is a number", { id = 3 } },
				{ "a kind a later server sends", { kind = "weather" } },
				{ "a kind in capitals", { kind = "Monster" } },
				{ "no kind", { kind = NONE } },
				{ "a name that isn't a string", { name = 7 } },
				{ "no region", { region = NONE } },
				{ "a key that isn't a string", { key = false } },
				{ "no text", { text = NONE } },
				{ "a time that is a string", { time = "1791733000" } },
				{ "a time below 0", { time = -1 } },
				{ "a time with a fraction", { time = 1791733000.5 } },
				{ "an angler past the Anglers", { angler = 2 } },
				{ "an angler below 0", { angler = -1 } },
				{ "no item", { item = NONE } },
				{ "a rank with a fraction", { rank = 0.5 } },
				{ "an infinite zone", { zone = math.huge } },
				{ "a length that isn't a number", { length = 0 / 0 } },
			}
			for _, case in ipairs(NOT_USED) do
				local name, changes = case[1], case[2]
				it(("skips a line with %s on its own, never the file (VIEW-R41, VIEW-R98)"):format(name), function()
					local data = anglerFileExamples().news
					data.news[1] = type(changes) == "table" and with(data.news[1], changes) or changes

					local read = views(data)
					local news = read:News()

					assert.are.same({ "ok", { HUNT, REGION } }, { news.state, ids(news.items) })
					assert.are.equal("ok", read:FollowedAnglers().state)
					assert.are.same({ used = 2, skipped = 1 }, {
						used = ns.ReadFollowingFile(data).news.used,
						skipped = ns.ReadFollowingFile(data).news.skipped,
					})
				end)
			end

			it("uses every one of SIGN-R10's nine kinds (VIEW-R41)", function()
				local data = anglerFileExamples().news
				data.news = {}
				for i, kind in ipairs(ns.NEWS_KINDS) do
					data.news[i] = with(anglerFileExamples().news.news[1], { id = ("%016x"):format(i), kind = kind })
				end

				local news = views(data):News()

				assert.are.equal(9, #news.items)
				assert.are.same(
					{ "first", "legend", "prestige", "ledger", "colour", "hunt", "zone", "monster", "region" },
					ns.NEWS_KINDS
				)
			end)

			it("skips a line repeating an earlier line's id, keeping the first (VIEW-R41)", function()
				local data = anglerFileExamples().news
				data.news[3].id = MONSTER

				local file = ns.ReadFollowingFile(data)

				assert.are.same({ MONSTER, HUNT }, ids(views(data):News().items))
				assert.are.same({ 2, 1 }, { file.news.used, file.news.skipped })
			end)

			it("copies only news-line's fields, and allows a headline's Angler not followed (VIEW-R41)", function()
				local data = anglerFileExamples().news
				data.news[1].guid = "Player-4618-0A1B2C3D"
				data.news[1].publicId = "ada"

				local item = views(data):News().items[1]

				assert.are.same(lines()[1], item)
				assert.are.equal(0, views(data):News().items[3].angler)
			end)

			it(
				"doubles every | in a name and a text, so the client draws them as written (VIEW-R41, VIEW-R13)",
				function()
					local data = anglerFileExamples().news
					data.news[2].name = "A|cffff0000da"
					data.news[2].text = "The |TInterface\\Icons\\X:0|t Run"

					local item = views(data):News().items[2]

					assert.are.same(
						{ "A||cffff0000da", "The ||TInterface\\Icons\\X:0||t Run" },
						{ item.name, item.text }
					)
				end
			)

			it("is expired from the file's 24th hour, read again at each call (VIEW-R42, VIEW-R2, IGV-R45)", function()
				local read, _, clock = views(anglerFileExamples().news, saved(1791700000))

				clock.now = FOLLOWING_AT + DAY - 1
				assert.are.equal(3, #read:News().items)
				clock.now = FOLLOWING_AT + DAY
				assert.are.same({ state = "expired", items = {} }, read:News())
			end)

			it("is absent while Pagle_Following is, whatever its news (VIEW-R42, IGV-R44)", function()
				local data = anglerFileExamples().news
				data.ok = nil

				assert.are.same({ state = "absent", items = {} }, views(data):News())
				assert.are.same({ state = "absent", items = {} }, views(nil):News())
			end)

			it("hands out fresh copies, which the caller may keep and change (VIEW-R42)", function()
				local data = anglerFileExamples().news
				local read = views(data)

				local first = read:News()
				first.items[1].name = "Changed"
				table.remove(first.items, 2)
				data.news[1].length = 9999
				local second = read:News()

				assert.are_not.equal(first.items, second.items)
				assert.are.same(lines(), second.items)
			end)
		end)

		describe("seen and the floor", function()
			it(
				"calls nothing new at the first login with news, and leaves its floor to the sign's decision (VIEW-R42, SIGN-R18)",
				function()
					local read, global = views(anglerFileExamples().news)

					assert.are.same(lines(), read:News().items)
					assert.are.same({ seen = {} }, global.news)
					-- The decision sets the floor after reading; the session still calls nothing new.
					global.news.since = NOW
					assert.are.same(lines(), read:News().items)
				end
			)

			it("sets no floor, and keeps nothing, while the news isn't ok (SIGN-R14, VIEW-R44)", function()
				local none = anglerFileExamples().news
				none.news = nil
				local absent = anglerFileExamples().news
				absent.v = 2
				for _, data in ipairs({ none, absent }) do
					local read, global = views(data)
					read:News()
					assert.are.same({}, global)
				end
				local read, global, clock = views(anglerFileExamples().news)
				clock.now = FOLLOWING_AT + DAY
				read:News()
				assert.are.same({}, global)
			end)

			it("keeps a floor once set: a later login sets none (SIGN-R18)", function()
				local global = saved(1791700000)

				views(anglerFileExamples().news, global):News()

				assert.are.equal(1791700000, global.news.since)
			end)

			it(
				"calls an item new while it wasn't seen and was timed at or after the floor, for the whole session (VIEW-R42)",
				function()
					local global = saved(1791702000, { [MONSTER] = 1791733000 })
					local read = views(anglerFileExamples().news, global)

					assert.are.same(lines({ [HUNT] = true }), read:News().items)
					read:MarkNewsSeen()
					assert.are.same(lines({ [HUNT] = true }), read:News().items)
					-- The next login, the hunt is seen.
					assert.are.same(lines(), views(anglerFileExamples().news, global):News().items)
				end
			)

			it("never calls an item timed before the floor new, though it wasn't seen (SIGN-R18)", function()
				local read = views(anglerFileExamples().news, saved(1791733001))

				assert.are.same(lines(), read:News().items)
			end)

			it(
				"sets the floor to the server time when the sign is turned on, over an older one, whatever the news (SET-R37, SIGN-R18)",
				function()
					local global = saved(1791600000, { [HUNT] = 1791702000 })
					local read, _, clock = views(nil, global)
					clock.now = NOW + 30

					read:SetNewsFloor()

					assert.are.same({ since = NOW + 30, seen = { [HUNT] = 1791702000 } }, global.news)
					local fresh = {}
					views(nil, fresh):SetNewsFloor()
					assert.are.same({ since = NOW, seen = {} }, fresh.news)
				end
			)

			it("leaves nothing new at the next login after the floor is set again (SIGN-R18)", function()
				local global = saved(1791600000)
				local read = views(anglerFileExamples().news, global)
				read:SetNewsFloor()

				assert.are.same(lines(), views(anglerFileExamples().news, global):News().items)
			end)

			it("marks each id given seen with its item's time, ignoring ids not in the block (VIEW-R43)", function()
				local read, global = views(anglerFileExamples().news, saved(1791600000))

				read:MarkNewsSeen({ HUNT, "0000000000000000", 7 })

				assert.are.same({ [HUNT] = 1791702000 }, global.news.seen)
				assert.is_true(read:NewsSeen(HUNT))
				assert.is_false(read:NewsSeen(MONSTER))
			end)

			it(
				"marks every item seen with no argument, whatever its kind's or the headlines' switch (VIEW-R43, SIGN-R17)",
				function()
					local global = saved(1791600000)
					global.newsSign = { show = false, kinds = { monster = false, hunt = false }, headlines = false }
					local read = views(anglerFileExamples().news, global)

					read:MarkNewsSeen()

					assert.are.same(
						{ [MONSTER] = 1791733000, [HUNT] = 1791702000, [REGION] = 1791690000 },
						global.news.seen
					)
				end
			)

			it("marks nothing while the news isn't ok: absent, expired or none (VIEW-R43)", function()
				local none = anglerFileExamples().news
				none.news = nil
				for _, data in ipairs({ none, nil }) do
					local global = saved(1791600000)
					views(data, global):MarkNewsSeen()
					assert.are.same(saved(1791600000), global)
				end
				local global = saved(1791600000)
				local read, _, clock = views(anglerFileExamples().news, global)
				clock.now = FOLLOWING_AT + DAY
				read:MarkNewsSeen({ HUNT })
				assert.are.same(saved(1791600000), global)
			end)

			it(
				"drops seen entries older than the seen age at the session's first read, and only then (VIEW-R44)",
				function()
					local age = 31 * DAY
					local global = saved(1791600000, {
						old = NOW - age - 1,
						edge = NOW - age,
						recent = NOW - DAY,
						broken = "x",
						[HUNT] = 1791702000,
					})
					local read, _, clock = views(anglerFileExamples().news, global)

					read:News()
					assert.are.same({ edge = NOW - age, recent = NOW - DAY, [HUNT] = 1791702000 }, global.news.seen)
					clock.now = NOW + 2 * DAY
					read:News()
					assert.are.same({ edge = NOW - age, recent = NOW - DAY, [HUNT] = 1791702000 }, global.news.seen)
					assert.are.equal(age, ns.NEWS_SEEN_AGE)
				end
			)

			it("prunes nothing while the news isn't ok (VIEW-R44)", function()
				local global = saved(1791600000, { old = 1 })
				local data = anglerFileExamples().news
				data.news = nil

				views(data, global):News()

				assert.are.same({ old = 1 }, global.news.seen)
			end)

			it(
				"keeps only the floor and each seen id with its time: no name, kind, Angler or text (VIEW-R4, VIEW-R44, IGV-R47)",
				function()
					local read, global = views(anglerFileExamples().news, saved(1791600000))

					read:MarkNewsSeen()

					assert.are.same({ "news" }, sortedKeys(global))
					assert.are.same({ "seen", "since" }, sortedKeys(global.news))
					for id, time in pairs(global.news.seen) do
						assert.is_truthy(id:find("^%x+$") and #id == 16)
						assert.are.equal("number", type(time))
					end
				end
			)
		end)

		describe("the words", function()
			-- The client and Core as Pagle.NewsWords reads them: an enUS client's item names, a Species' varieties
			-- (Spotted Yellowtail's All-gold, position 8, Rare; its Wavecrest, position 10, Epic) and which are caught,
			-- zone names, a length, whether the Ledger is on, and which Species have a fish crest. `changes` over them.
			local function lookups(changes)
				local names = {
					[19805] = "Keefer's Angelfish",
					[4603] = "Raw Spotted Yellowtail",
					[13422] = "Stonescale Eel",
				}
				local base = {
					itemName = function(itemID)
						return names[itemID]
					end,
					dropPrefix = "Raw ",
					varieties = function(species)
						if species ~= 4603 then
							return nil
						end
						local list = {}
						for i = 1, 10 do
							list[i] =
								{ id = "4603.v" .. i, key = "v" .. i, index = i, rarity = "common", name = "V" .. i }
						end
						list[8] =
							{ id = "4603.allgold", key = "allgold", index = 8, rarity = "rare", name = "All-gold" }
						list[10] = { id = "4603.wave", key = "wave", index = 10, rarity = "epic", name = "Wavecrest" }
						return list
					end,
					caught = function(species)
						return species == 4603 and { [8] = true } or {}
					end,
					areaName = function(areaID)
						return areaID == 12 and "Elwynn Forest" or nil
					end,
					formatLength = function(mm)
						return ("%d mm"):format(mm)
					end,
					ledgerOn = function()
						return true
					end,
					fishCrest = function(species)
						return species == 13422
					end,
				}
				for key, value in pairs(changes or {}) do
					base[key] = value
				end
				return base
			end

			-- A news item of `kind` about Ada Brook, `fields` over it.
			local function item(kind, fields)
				local out = {
					id = "0123456789abcdef",
					kind = kind,
					time = 1791733000,
					angler = 1,
					name = "Ada Brook",
					region = "",
					item = 0,
					rank = 0,
					key = "",
					text = "",
					zone = 0,
					length = 0,
					new = false,
				}
				for key, value in pairs(fields or {}) do
					out[key] = value
				end
				return out
			end

			local LAUREL, MEDAL = { sign = "laurel" }, { sign = "medal" }
			local WORDS = {
				{
					"first",
					item("first", { region = "eu", item = 19805 }),
					{
						kind = "first",
						kicker = "First report",
						head = "First in EU to land Keefer's Angelfish",
						detail = "Ada Brook",
						emblem = LAUREL,
					},
				},
				{
					"legend",
					item("legend", { item = 19805 }),
					{
						kind = "legend",
						kicker = "Legend",
						head = "Ada Brook landed a Legend",
						detail = "Keefer's Angelfish",
						emblem = { legend = "angelfish", item = 19805 },
					},
				},
				{
					"legend without a crest of its own",
					item("legend", { item = 19807 }),
					{
						kind = "legend",
						kicker = "Legend",
						head = "Ada Brook landed a Legend",
						detail = "a fish",
						emblem = { legend = "unwritten", item = 19807 },
					},
				},
				{
					"prestige",
					item("prestige", { rank = 3 }),
					{
						kind = "prestige",
						kicker = "Prestige",
						head = "Ada Brook reached Prestige III",
						emblem = { atlas = "PrestigeEmblems", sprite = "emblem-iii" },
					},
				},
				{
					"Master Prestige",
					item("prestige", { rank = 12 }),
					{
						kind = "prestige",
						kicker = "Prestige",
						head = "Ada Brook reached Master Prestige 2",
						emblem = { atlas = "PrestigeEmblems", sprite = "emblem-master" },
					},
				},
				{
					"ledger",
					item("ledger"),
					{
						kind = "ledger",
						kicker = "The Ledger",
						head = "Ada Brook completed the Ledger",
						emblem = { file = "Interface\\AddOns\\Pagle\\media\\minimap\\Ledger-Book", fill = 1.25 },
					},
				},
				{
					"a caught rare colour",
					item("colour", { item = 4603, key = "allgold", rank = 8 }),
					{
						kind = "colour",
						kicker = "Rare colour",
						head = "Ada Brook caught a rare colour",
						detail = "All-gold Spotted Yellowtail",
						emblem = { variety = { species = 4603, position = 8 } },
					},
				},
				{
					"an epic colour not caught",
					item("colour", { item = 4603, key = "wave", rank = 10 }),
					{
						kind = "colour",
						kicker = "Rare colour",
						head = "Ada Brook caught a rare colour",
						detail = "Epic Spotted Yellowtail",
						emblem = { variety = { species = 4603, position = 10, silhouette = true } },
					},
				},
				{
					"a colour whose key the client doesn't know",
					item("colour", { item = 4603, key = "later", rank = 9 }),
					{
						kind = "colour",
						kicker = "Rare colour",
						head = "Ada Brook caught a rare colour",
						detail = "Rare Spotted Yellowtail",
						emblem = { variety = { species = 4603, position = 9, silhouette = true } },
					},
				},
				{
					"hunt",
					item("hunt", { key = "night_run", text = "The Night Run" }),
					{
						kind = "hunt",
						kicker = "Hunt gold",
						head = "Ada Brook took gold",
						detail = "The Night Run",
						emblem = MEDAL,
					},
				},
				{
					"zone",
					item("zone", { zone = 12, key = "elwynn" }),
					{
						kind = "zone",
						kicker = "Zone Master",
						head = "Ada Brook became Master of Elwynn Forest",
						emblem = { file = "Interface\\AddOns\\Pagle_Ledger\\media\\crests\\elwynn", fill = 0.92 },
					},
				},
				{
					"a zone with no crest, and a name the client hasn't",
					item("zone", { zone = 9999, key = "" }),
					{
						kind = "zone",
						kicker = "Zone Master",
						head = "Ada Brook became Master of Zone 9999",
						emblem = LAUREL,
					},
				},
				{
					"monster",
					item("monster", { item = 13422, length = 544 }),
					{
						kind = "monster",
						kicker = "Monster",
						head = "Ada Brook landed a Monster",
						detail = "Stonescale Eel, 544 mm",
						emblem = {
							file = "Interface\\AddOns\\Pagle\\media\\crests\\fish\\13422",
							fill = 0.92,
							tape = true,
						},
					},
				},
				{
					"a Monster of a Species with no crest",
					item("monster", { item = 6291, length = 120 }),
					{
						kind = "monster",
						kicker = "Monster",
						head = "Ada Brook landed a Monster",
						detail = "a fish, 120 mm",
						emblem = { sign = "laurel", tape = true },
					},
				},
				{
					"region",
					item("region", { angler = 0, name = "Grimtusk", region = "eu", item = 19805 }),
					{
						kind = "region",
						kicker = "Region news · EU",
						head = "First in EU this month to land Keefer's Angelfish",
						detail = "Grimtusk",
						emblem = LAUREL,
					},
				},
			}
			for _, case in ipairs(WORDS) do
				local name, news, words = case[1], case[2], case[3]
				it(
					("words %s as the sign draws it, with no more line (VIEW-R45, SIGN-R12, SIGN-R13, SIGN-R19)"):format(
						name
					),
					function()
						assert.are.same(words, ns.NewsWords(news, lookups()))
					end
				)
			end

			it("says a fish for an item the client hasn't loaded yet, and names it once it has (VIEW-R45)", function()
				local names = {}
				local look = lookups({
					itemName = function(itemID)
						return names[itemID]
					end,
				})
				local legend = item("legend", { item = 19805 })

				assert.are.equal("a fish", ns.NewsWords(legend, look).detail)
				names[19805] = "Keefer's Angelfish"
				assert.are.equal("Keefer's Angelfish", ns.NewsWords(legend, look).detail)
			end)

			it("draws the laurel for a zone while the Ledger is off, as its crests aren't there (SIGN-R13)", function()
				local look = lookups({
					ledgerOn = function()
						return false
					end,
				})

				assert.are.same(LAUREL, ns.NewsWords(item("zone", { zone = 12, key = "elwynn" }), look).emblem)
			end)

			it("keeps an enUS fish's Raw only on another client (SIGN-R19, VAR-R12)", function()
				local colour = item("colour", { item = 4603, key = "allgold", rank = 8 })

				assert.are.equal(
					"All-gold Raw Spotted Yellowtail",
					ns.NewsWords(colour, lookups({ dropPrefix = false })).detail
				)
			end)

			it(
				"names an item's Angler by its line's name, never its card's or a character's (SIGN-R11, VIEW-R41, IGV-R61)",
				function()
					local data = anglerFileExamples().news
					data.anglers[1].name = "Kukli"
					data.anglers[1].guids = { "Player-4618-0A1B2C3D" }

					local news = views(data):News()
					local words = ns.NewsWords(news.items[1], lookups())

					assert.are.equal("Ada Brook", news.items[1].name)
					assert.is_nil(news.items[1].guids)
					assert.are.equal("Ada Brook landed a Monster", words.head)
					for _, text in pairs({ words.kicker, words.head, words.detail }) do
						assert.is_nil(text:find("Kukli", 1, true))
						assert.is_nil(text:find("Player-", 1, true))
					end
				end
			)

			it("draws no glyph outside CORE-R9's set (VIEW-R45, CORE-R9)", function()
				for _, case in ipairs(WORDS) do
					local words = ns.NewsWords(case[2], lookups())
					for _, text in pairs({ words.kicker, words.head, words.detail or "" }) do
						assert.are.same({}, glyphsOutside(text))
					end
				end
			end)
		end)

		it(
			"reports the news state, the lines used and skipped, the seen items and the floor under /pagle dev views (VIEW-R12)",
			function()
				local data = anglerFileExamples().news
				data.news[4] = { id = "bad" }
				local read = views(data, saved(1791600000, { [HUNT] = 1791702000 }))

				local report = read:Report()

				assert.are.equal(
					"Pagle dev: news ok: lines used 3, skipped 1; seen 1, floor 1791600000.",
					report[#report]
				)
				local none = views(anglerFileExamples().following):Report()
				assert.are.equal(
					"Pagle dev: news none: lines used none, skipped none; seen 0, floor none.",
					none[#none]
				)
			end
		)
	end)
end)
