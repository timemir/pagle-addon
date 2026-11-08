-- Party toasts' messages, pure (announcements.md › Party toasts and cheers, › Contracts › Party messages; ANN-R103–R105,
-- ANN-R108, from 1.5.2, #640): adapter/PartyMessages.lua's format, its strict reading of what arrives, the limits on
-- what is taken, a shared moment as sent, and the lines a party toast and a cheer's Nod read. Loaded through the real
-- TOC, which lists it from 1.6 (adapter/Settings.xml's <Script> lines loaded it in 1.5.2 and 1.5.3).

local function ns()
	return loadAddon("Pagle", FOREVER_GLOBALS).ns
end

describe("party messages", function()
	it("register the prefix Pagle at load and load through the TOC (ANN-R103)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		assert.is_true(loaded.client.prefixes.Pagle)
		local files = addonFiles("Pagle")
		local listed = {}
		for _, file in ipairs(files) do
			listed[file] = true
		end
		for _, file in ipairs({ "PartyMessages", "Party", "PartyToast", "PartySettings" }) do
			assert(listed["adapter/" .. file .. ".lua"], file)
		end
	end)

	it("write a hello, a moment of every kind and a cheer as the contract has them (ANN-R103, ANN-R104)", function()
		local n = ns()
		assert.are.equal("1:H:1", n.PartyHelloText(true))
		assert.are.equal("1:H:0", n.PartyHelloText(false))
		assert.are.equal("1:C:k3x91", n.PartyCheerText("k3x91"))
		local cases = {
			{ { kind = "legend", item = 19803 }, "1:M:k3x91:legend:19803" },
			{ { kind = "colour", item = 6291, rarity = "rare", place = 8 }, "1:M:k3x91:colour:6291:r:8" },
			{ { kind = "colour", item = 6291, rarity = "epic", place = 0 }, "1:M:k3x91:colour:6291:e:0" },
			{ { kind = "monster", item = 6303, length = 612 }, "1:M:k3x91:monster:6303:612" },
			{ { kind = "gold", item = 6303, hunt = "mackerel_run" }, "1:M:k3x91:gold:6303:mackerelZrun" },
			{ { kind = "gold", item = 6303 }, "1:M:k3x91:gold:6303:0" },
			{ { kind = "gold" }, "1:M:k3x91:gold:0:0" },
			{ { kind = "zone", area = 357 }, "1:M:k3x91:zone:357" },
			{ { kind = "zone" }, "1:M:k3x91:zone:0" },
			{ { kind = "prestige", rank = 3 }, "1:M:k3x91:prestige:3" },
			{ { kind = "ledger" }, "1:M:k3x91:ledger" },
		}
		for _, case in ipairs(cases) do
			assert.are.equal(case[2], n.PartyMomentText("k3x91", case[1]))
		end
	end)

	it("write nothing for a moment out of range or of a kind it doesn't know (ANN-R104)", function()
		local n = ns()
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "legend" }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "legend", item = 0 }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "monster", item = 6303, length = 100000 }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "colour", item = 6291, rarity = "common", place = 1 }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "prestige", rank = 1.5 }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "catch", item = 6303 }))
		assert.is_nil(n.PartyMomentText("K3X91", { kind = "zone" }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "gold", item = 6303, hunt = "Mackerel_Run" }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "gold", item = 6303, hunt = string.rep("a", 33) }))
		assert.is_nil(n.PartyMomentText("k3x91", { kind = "zone", area = 10000000 }))
	end)

	it("read back every message it writes (ANN-R105)", function()
		local n = ns()
		assert.are.same({ type = "hello", ask = true }, n.ParsePartyText("1:H:1"))
		assert.are.same({ type = "hello", ask = false }, n.ParsePartyText("1:H:0"))
		assert.are.same({ type = "cheer", id = "k3x91" }, n.ParsePartyText("1:C:k3x91"))
		assert.are.same(
			{ type = "moment", id = "k3x91", kind = "colour", item = 6291, rarity = "rare", place = 8 },
			n.ParsePartyText("1:M:k3x91:colour:6291:r:8")
		)
		assert.are.same(
			{ type = "moment", id = "k3x91", kind = "monster", item = 6303, length = 612 },
			n.ParsePartyText("1:M:k3x91:monster:6303:612")
		)
		assert.are.same(
			{ type = "moment", id = "k3x91", kind = "gold", item = 0 },
			n.ParsePartyText("1:M:k3x91:gold:0:0")
		)
		assert.are.same(
			{ type = "moment", id = "k3x91", kind = "gold", item = 6303, hunt = "mackerel_run" },
			n.ParsePartyText("1:M:k3x91:gold:6303:mackerelZrun")
		)
		assert.are.same({ type = "moment", id = "k3x91", kind = "zone" }, n.ParsePartyText("1:M:k3x91:zone:0"))
		assert.are.same(
			{ type = "moment", id = "k3x91", kind = "zone", area = 357 },
			n.ParsePartyText("1:M:k3x91:zone:357")
		)
		-- The longest a moment gets, a Hunt of 32 in a 12-character id, fits the 64 bytes.
		local longest = "1:M:" .. string.rep("z", 12) .. ":gold:999999999:" .. string.rep("a", 32)
		assert.are.equal(64, #longest)
		assert.is_not_nil(n.ParsePartyText(longest))
		assert.are.same(
			{ type = "moment", id = "k3x91", kind = "prestige", rank = 3 },
			n.ParsePartyText("1:M:k3x91:prestige:3")
		)
	end)

	it(
		"ignore anything malformed: another version, an unknown type or kind, a field too many or too few, a number out"
			.. " of range, an escape sequence, a byte outside letters, digits and colons, or past 64 bytes (ANN-R105)",
		function()
			local n = ns()
			local bad = {
				"",
				"2:H:1",
				"1:X:1",
				"1:H:2",
				"1:H",
				"1:H:1:1",
				"1:C:",
				"1:C:ab",
				"1:C:k3x91:1",
				"1:C:K3X91",
				"1:M:k3x91",
				"1:M:k3x91:catch:6303",
				"1:M:k3x91:legend",
				"1:M:k3x91:legend:0",
				"1:M:k3x91:legend:6303:1",
				"1:M:k3x91:legend:-5",
				"1:M:k3x91:legend:1e3",
				"1:M:k3x91:legend:1234567890",
				"1:M:k3x91:colour:6291:c:1",
				"1:M:k3x91:colour:6291:r:11",
				"1:M:k3x91:monster:6303:0",
				"1:M:k3x91:prestige:1000",
				"1:M:k3x91:zone",
				"1:M:k3x91:zone:357:1",
				"1:M:k3x91:gold:6303",
				"1:M:k3x91:gold:6303:mackerel_run",
				"1:M:k3x91:gold:6303:" .. string.rep("a", 33),
				"1:M:k3x91:legend:19803|r",
				"1:M:k3x91:legend:|cff0000ff",
				"1:M:k3x91:legend:19803 ",
				"1:M:k3x91:legend:19803\n",
				"1:M:k3x91:legend::19803",
				"1:M:" .. string.rep("a", 13) .. ":zone",
				"1:H:1" .. string.rep(":", 60),
				string.rep("1", 65),
			}
			for _, text in ipairs(bad) do
				assert(n.ParsePartyText(text) == nil, text)
			end
			assert.is_nil(n.ParsePartyText(nil))
			assert.is_nil(n.ParsePartyText(5))
		end
	)

	it("take a groupmate's messages up to the burst, then one each period (ANN-R105)", function()
		local n = ns()
		local limit = n.NewPartyLimit(3, 20)
		assert.is_true(limit:Take(0))
		assert.is_true(limit:Take(0))
		assert.is_true(limit:Take(1))
		assert.is_false(limit:Take(2))
		assert.is_false(limit:Take(19))
		assert.is_true(limit:Take(21))
		assert.is_false(limit:Take(22))
		-- A long quiet fills it back to the burst, never past.
		assert.is_true(limit:Take(1000))
		assert.is_true(limit:Take(1000))
		assert.is_true(limit:Take(1000))
		assert.is_false(limit:Take(1000))
	end)

	it("name a sender by the first word of its name, with no realm or surname (ANN-R105)", function()
		local n = ns()
		assert.are.equal("Kukli", n.PartySenderName("Kukli"))
		assert.are.equal("Kukli", n.PartySenderName("Kukli-Testrealm"))
		assert.are.equal("Kukli", n.PartySenderName("Kukli Stonebrew"))
		assert.is_nil(n.PartySenderName(""))
		assert.is_nil(n.PartySenderName(nil))
	end)

	it("make ids from a nonce and a counter, both base 36 (ANN-R104)", function()
		local n = ns()
		local ids = n.NewPartyIds("k3x9")
		assert.are.equal("k3x91", ids:Next())
		assert.are.equal("k3x92", ids:Next())
		for _ = 3, 35 do
			ids:Next()
		end
		assert.are.equal("k3x910", ids:Next())
		local nonce = n.PartyNonce(function()
			return 35
		end)
		assert.are.equal("zzzz", nonce)
	end)

	it(
		"read what a Module's marked moment shares: the item, a variety's rarity and place, a record's length, a"
			.. " Prestige's rank, and nothing of a Zone Master's zone (ANN-R104)",
		function()
			local n = ns()
			local varieties = function(species)
				if species == 6291 then
					local list = {}
					for i = 1, 10 do
						list[i] = { name = "Variety " .. i }
					end
					return list
				end
			end
			assert.are.same(
				{ kind = "legend", item = 19803 },
				n.PartyShareOf({ party = "legend", icon = 19803, title = "Legend" }, varieties)
			)
			assert.are.same(
				{ kind = "colour", item = 6291, rarity = "rare", place = 8 },
				n.PartyShareOf(
					{ party = "colour", icon = 6291, variety = { name = "Variety 8", rarity = "rare" } },
					varieties
				)
			)
			assert.are.same(
				{ kind = "colour", item = 6303, rarity = "epic", place = 0 },
				n.PartyShareOf(
					{ party = "colour", icon = 6303, variety = { name = "Gold", rarity = "epic" } },
					varieties
				)
			)
			assert.are.same(
				{ kind = "monster", item = 6303, length = 612 },
				n.PartyShareOf({ party = "monster", icon = 6303, ruler = { old = 500, new = 612.4, unit = "length" } })
			)
			assert.are.same({ kind = "gold", item = 6303 }, n.PartyShareOf({ party = "gold", icon = 6303 }))
			assert.are.same(
				{ kind = "gold", item = 6303, hunt = "mackerel_run" },
				n.PartyShareOf({ party = "gold", icon = 6303, partyHunt = "mackerel_run" })
			)
			assert.are.same(
				{ kind = "gold", item = 0 },
				n.PartyShareOf({ party = "gold", icon = "Interface\\Icons\\X" })
			)
			assert.are.same({ kind = "zone" }, n.PartyShareOf({ party = "zone", icon = 1, text = "Elwynn Forest" }))
			assert.are.same(
				{ kind = "zone", area = 12 },
				n.PartyShareOf({ party = "zone", icon = 1, text = "Elwynn Forest", partyArea = 12 })
			)
			assert.are.same({ kind = "prestige", rank = 3 }, n.PartyShareOf({ party = "prestige", frameRank = 3 }))
			assert.are.same({ kind = "ledger" }, n.PartyShareOf({ party = "ledger" }))
			assert.is_nil(n.PartyShareOf({ party = "catch", icon = 6303 }))
			assert.is_nil(
				n.PartyShareOf({ party = "colour", icon = 6303, variety = { name = "X", rarity = "common" } })
			)
			assert.is_nil(n.PartyShareOf({ kind = "legend", icon = 19803 }))
		end
	)

	it("read a party toast's line for each kind, leaving off what it can't name (UI › Party toast)", function()
		local n = ns()
		local lookups = {
			itemName = function(itemID)
				return ({ [19805] = "Keefer's Angelfish", [6303] = "Raw Slitherskin Mackerel" })[itemID]
			end,
			varieties = function(species)
				return species == 6291 and { [8] = { name = "Coral" } } or nil
			end,
			formatLength = function(mm)
				return ("%.1f cm"):format(mm / 10)
			end,
			areaName = function(areaID)
				return areaID == 357 and "Feralas" or nil
			end,
			huntName = function(huntID)
				return huntID == "darkshore_moonlight" and "Grouper by Moonlight" or nil
			end,
		}
		local function line(message)
			return n.PartyMomentLine(message, lookups)
		end
		assert.are.equal("Caught a Legend · Keefer's Angelfish", line({ kind = "legend", item = 19805 }))
		assert.are.equal("Caught a Legend", line({ kind = "legend", item = 1 }))
		assert.are.equal(
			"Caught a rare colour · Coral",
			line({ kind = "colour", item = 6291, rarity = "rare", place = 8 })
		)
		assert.are.equal(
			"Caught an epic colour · Raw Slitherskin Mackerel",
			line({ kind = "colour", item = 6303, rarity = "epic", place = 0 })
		)
		assert.are.equal(
			"Monster-size record · Raw Slitherskin Mackerel · 61.2 cm",
			line({ kind = "monster", item = 6303, length = 612 })
		)
		assert.are.equal("Monster-size record · 61.2 cm", line({ kind = "monster", item = 1, length = 612 }))
		assert.are.equal("Took gold in a Hunt", line({ kind = "gold", item = 6303 }))
		assert.are.equal("Took gold in a Hunt", line({ kind = "gold", item = 6303, hunt = "nowhere" }))
		assert.are.equal(
			"Took gold in Grouper by Moonlight",
			line({ kind = "gold", item = 6303, hunt = "darkshore_moonlight" })
		)
		assert.are.equal("Zone Master", line({ kind = "zone" }))
		assert.are.equal("Zone Master", line({ kind = "zone", area = 1 }))
		assert.are.equal("Became Master of Feralas", line({ kind = "zone", area = 357 }))
		assert.are.equal("Prestige 3", line({ kind = "prestige", rank = 3 }))
		assert.are.equal("Ledger 100%", line({ kind = "ledger" }))
	end)

	it("merge a moment's cheers into one line: one name, two, then a count (ANN-R108)", function()
		local n = ns()
		assert.are.equal("Kukli raised a mug", n.PartyCheerTitle({ "Kukli" }))
		assert.are.equal("Kukli and Arwen raised a mug", n.PartyCheerTitle({ "Kukli", "Arwen" }))
		assert.are.equal("3 raised a mug", n.PartyCheerTitle({ "Kukli", "Arwen", "Bram" }))
		assert.are.equal("4 raised a mug", n.PartyCheerTitle({ "Kukli", "Arwen", "Bram", "Dela" }))
	end)

	-- "Completed for the party" (ANN-R111, from 1.6): the hp message, on the party catch prefix PagleCatch in the
	-- `<kind>|<v>|` form, not this envelope (catch-log.md LOG-R110).
	describe("the hp message (ANN-R111)", function()
		-- A groupmate's source Catch ID (LOG-R116): <guid>-<time>-<tie>:<n>.
		local SOURCE = "Player-4701-0A1B2C3D-1793750400-0:1"

		it(
			"writes a Hunt completed and a run settled for the party: hp, 1, h or w, the ID, the source Catch ID",
			function()
				local n = ns()
				assert.are.equal(
					"hp|1|h|mackerel_run|" .. SOURCE,
					n.PartyHuntText({ what = "hunt", id = "mackerel_run", source = SOURCE })
				)
				assert.are.equal(
					"hp|1|w|darkshore_moonlight|" .. SOURCE,
					n.PartyHuntText({ what = "run", id = "darkshore_moonlight", source = SOURCE })
				)
			end
		)

		it("keeps to the addon message limit, the longest IDs included", function()
			local n = ns()
			local longest = n.PartyHuntText({
				what = "run",
				id = string.rep("a", 64),
				source = "Player-99999-0A1B2C3D-1793750400-12:4",
			})
			assert.is_not_nil(longest)
			---@cast longest string
			assert.is_true(#longest <= 255)
		end)

		it("writes nothing for an ID or a source Catch ID it can't write", function()
			local n = ns()
			assert.is_nil(n.PartyHuntText({ what = "hunt", id = "Mackerel_Run", source = SOURCE }))
			assert.is_nil(n.PartyHuntText({ what = "hunt", id = string.rep("a", 65), source = SOURCE }))
			assert.is_nil(n.PartyHuntText({ what = "hunt", id = "", source = SOURCE }))
			assert.is_nil(n.PartyHuntText({ what = "hunt", id = "a|b", source = SOURCE }))
			assert.is_nil(n.PartyHuntText({ what = "tier", id = "mackerel_run", source = SOURCE }))
			assert.is_nil(
				n.PartyHuntText({ what = "hunt", id = "mackerel_run", source = "Player-4701-0A1B2C3D-1793750400-0" })
			)
			assert.is_nil(n.PartyHuntText({ what = "hunt", id = "mackerel_run", source = "Creature-0-1-2-3:1" }))
			assert.is_nil(n.PartyHuntText({ what = "hunt", id = "mackerel_run" }))
		end)

		it("reads one back: a Hunt or a run, its ID, the source Catch ID and the GUID it opens with", function()
			local n = ns()
			assert.are.same(
				{ what = "hunt", id = "mackerel_run", source = SOURCE, catcher = "Player-4701-0A1B2C3D" },
				n.ParsePartyHuntText("hp|1|h|mackerel_run|" .. SOURCE)
			)
			assert.are.same(
				{ what = "run", id = "darkshore_moonlight", source = SOURCE, catcher = "Player-4701-0A1B2C3D" },
				n.ParsePartyHuntText("hp|1|w|darkshore_moonlight|" .. SOURCE)
			)
		end)

		it("ignores one that isn't exactly an hp message, a later version among them (LOG-R110)", function()
			local n = ns()
			for _, text in ipairs({
				"hp|2|h|mackerel_run|" .. SOURCE,
				"hp|1|x|mackerel_run|" .. SOURCE,
				"hp|1|h|Mackerel_Run|" .. SOURCE,
				"hp|1|h||" .. SOURCE,
				"hp|1|h|mackerel_run|Player-4701-0A1B2C3D-1793750400-0",
				"hp|1|h|mackerel_run|Player-4701-0A1B2C3D-1793750400-0:0",
				"hp|1|h|mackerel_run|" .. SOURCE .. "|more",
				"hp|1|h|mackerel_run",
				"HP|1|h|mackerel_run|" .. SOURCE,
				"PC|1|h|mackerel_run|" .. SOURCE,
				"1:hp:h:mackerelZrun",
				"hp|1|h|mackerel_run|" .. SOURCE .. string.rep(" ", 255),
			}) do
				assert.is_nil(n.ParsePartyHuntText(text))
			end
		end)

		it(
			"reads what a moment carries: partyCatch with partyHunt a Hunt, with partyEvent a run, and nothing else",
			function()
				local n = ns()
				assert.are.same(
					{ what = "hunt", id = "mackerel_run", source = SOURCE },
					n.PartyHuntShareOf({ kind = "huntCompleted", partyCatch = SOURCE, partyHunt = "mackerel_run" })
				)
				assert.are.same(
					{ what = "run", id = "darkshore_moonlight", source = SOURCE },
					n.PartyHuntShareOf({
						kind = "wagerSettled",
						partyCatch = SOURCE,
						partyEvent = "darkshore_moonlight",
					})
				)
				-- A Hunt gold of the player's own carries partyHunt, but no partyCatch.
				assert.is_nil(n.PartyHuntShareOf({ kind = "huntTier", party = "gold", partyHunt = "mackerel_run" }))
				assert.is_nil(n.PartyHuntShareOf({ kind = "huntCompleted", partyCatch = SOURCE }))
			end
		)

		it("names the Hunt or the run from the player's own lore, then every groupmate it was for", function()
			local n = ns()
			local lookups = {
				huntName = function(id)
					return id == "mackerel_run" and "Mackerel Run" or nil
				end,
				eventName = function(id)
					return id == "darkshore_moonlight" and "Grouper by Moonlight" or nil
				end,
			}
			local hunt = { what = "hunt", id = "mackerel_run", source = SOURCE }
			local run = { what = "run", id = "darkshore_moonlight", source = SOURCE }
			assert.are.equal("Mackerel Run · for Kukli Emnabi", n.PartyHuntLine(hunt, { "Kukli Emnabi" }, lookups))
			assert.are.equal(
				"Grouper by Moonlight settled · for Kukli Emnabi and Bram",
				n.PartyHuntLine(run, { "Kukli Emnabi", "Bram" }, lookups)
			)
			assert.are.equal(
				"Mackerel Run · for Kukli Emnabi, Bram and 1 more",
				n.PartyHuntLine(hunt, { "Kukli Emnabi", "Bram", "Dela Marsh" }, lookups)
			)
			assert.are.equal(
				"Mackerel Run · for Kukli Emnabi, Bram and 2 more",
				n.PartyHuntLine(hunt, { "Kukli Emnabi", "Bram", "Dela Marsh", "Arwen Tull" }, lookups)
			)
			-- An event the player doesn't know (a pushed one it never logged) is a Pagle Wager; a Hunt, a Hunt.
			assert.are.equal(
				"a Pagle Wager settled · for Kukli Emnabi",
				n.PartyHuntLine({ what = "run", id = "p_elsewhere", source = SOURCE }, { "Kukli Emnabi" }, lookups)
			)
			assert.are.equal(
				"a Hunt · for Kukli Emnabi",
				n.PartyHuntLine({ what = "hunt", id = "nowhere", source = SOURCE }, { "Kukli Emnabi" }, lookups)
			)
		end)
	end)
end)
