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

		-- The block's "Angler Level" line's right text for a tooltip card at prestige rank `rank`.
		local function levelText(rank)
			for _, line in ipairs(ns.AnglerTooltipLines(tooltipCard({ prestige = rank }))) do
				if line.left == "Angler Level" then
					return line.right
				end
			end
		end

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
				{ left = "Angler Level", leftColor = "parchment", right = "23 · Prestige I", rightColor = "white" },
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
					right = "60 · Master Prestige 2",
					rightColor = "white",
				},
				{ left = "Ledger", leftColor = "parchment", right = "100%", rightColor = "white" },
				{ left = "Legends", leftColor = "parchment", right = "7 of 12", rightColor = "white" },
				{ left = "Hardcore Angler", leftColor = "red" },
			}, ns.AnglerTooltipLines(card))
		end)

		it("writes Prestige I to X, then Master Prestige rank − 10 in words (VIEW-R21, LED-R34, LED-R146)", function()
			assert.are.same({
				"60",
				"60 · Prestige I",
				"60 · Prestige V",
				"60 · Prestige X",
				"60 · Master Prestige 1",
				"60 · Master Prestige 13",
			}, { levelText(0), levelText(1), levelText(5), levelText(10), levelText(11), levelText(23) })
		end)

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
end)
