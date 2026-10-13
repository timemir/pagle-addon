-- ns.FieldReportText: the Field report's text on the client, logic/FieldReportText.lua over the client's lookups
-- (REP-R30, REP-R35, REP-R36), through the real TOC.

describe("ns.FieldReportText", function()
	-- A fixture Angler: two characters on the fake client's realm, and REP-R36's logId (savedLog's).
	local CHARACTERS = {
		{
			guid = "Player-4618-0A1B2C3D",
			name = "Ada",
			classID = 1,
			raceID = 1,
			faction = "Alliance",
			realmID = 4618,
			firstSeen = 1791700000,
			lastSeen = 1791700000,
		},
		{
			guid = "Player-4618-0B2C3D4E",
			name = "Brindlewick",
			classID = 8,
			raceID = 7,
			faction = "Alliance",
			realmID = 4618,
			firstSeen = 1791700000,
			lastSeen = 1791700000,
		},
	}
	local ITEM_NAMES = { [6362] = "Raw Spotted Yellowtail" }
	local AREA_NAMES = { [33] = "Stranglethorn Vale", [1519] = "Stormwind City" }

	-- Core loaded with the fixture Angler's PagleLog, on a client that knows the names above.
	local function load()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({}, 1, CHARACTERS) }))
		loaded.env.C_Item = loaded.env.C_Item or {}
		loaded.env.C_Item.GetItemInfo = function(itemID)
			-- The name first, as the client returns it, then the rest of GetItemInfo's values.
			return ITEM_NAMES[itemID], "|Hitem:" .. itemID .. "|h", 1
		end
		loaded.env.C_Map.GetAreaInfo = function(areaID)
			return AREA_NAMES[areaID]
		end
		return loaded
	end

	-- One row of each kind in ticket #121's shape.
	local ROWS = {
		{ kind = "I", item = 6362, area = 33, build = 70338, count = 2, auras = {}, events = {} },
		{ kind = "I", item = 6359, area = 1519, build = 70338, count = 1, auras = {}, events = {} },
		{ kind = "K", area = 1519, build = 70338, casts = 40, away = 6, land = 75 },
		{
			kind = "P",
			area = 1519,
			locale = "enUS",
			text = "Oily Blackmouth School",
			casts = 5,
			items = { { item = 6358, count = 5 } },
		},
	}

	it(
		"writes the header from the client: addon version, fingerprint, locale and reporter key (REP-R30, REP-R36)",
		function()
			local loaded = load()
			local fingerprint = loaded.env.Pagle.CONTENT_FINGERPRINT

			local parts = loaded.ns.FieldReportText(ROWS)

			assert.are.equal(1, #parts)
			local version = loaded.client.addons.Pagle.metadata.Version
			assert.are.equal(
				"PAGLE-REPORT 1\naddon "
					.. version
					.. " data "
					.. fingerprint:sub(1, 8)
					.. " locale enUS reporter f38e76b0 part 1/1\n",
				parts[1]:match("^[^\n]*\n[^\n]*\n")
			)
		end
	)

	it(
		"names the item from C_Item.GetItemInfo and the area from C_Map.GetAreaInfo, leaving out an uncached one (REP-R30)",
		function()
			local parts = load().ns.FieldReportText(ROWS)

			assert.truthy(parts[1]:find("\nI 6362 33 70338 2 *# Raw Spotted Yellowtail, Stranglethorn Vale\n"))
			assert.truthy(parts[1]:find("\nI 6359 1519 70338 1 *# Stormwind City\n"))
			assert.truthy(parts[1]:find("\nK 1519 70338 casts=40 away=6 land=75 # Stormwind City\n"))
		end
	)

	it("holds no character name, GUID, realm, faction or logId (REP-R35)", function()
		local loaded = load()

		local text = table.concat(loaded.ns.FieldReportText(ROWS))

		local found = {}
		for _, secret in ipairs({
			"Ada",
			"Brindlewick",
			"Player-4618-0A1B2C3D",
			"Player-4618-0B2C3D4E",
			loaded.env.GetRealmName(),
			"Alliance",
			"3f9a2c1e7b0d4a65",
		}) do
			if text:find(secret, 1, true) then
				found[#found + 1] = secret
			end
		end
		assert.are.same({}, found)
	end)
end)
