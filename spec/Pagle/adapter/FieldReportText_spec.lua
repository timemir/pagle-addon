-- ns.FieldReportText: the Field report's text on the client, logic/FieldReportText.lua over the client's lookups
-- (REP-R30, REP-R35, REP-R36), through the real TOC.

describe("ns.FieldReportText (REP-R30, REP-R35, REP-R36)", function()
	-- A fixture Angler: two characters on the fake client's realm, and REP-R36's logId (savedLog's).
	local CHARACTERS = {
		characterRecord(),
		characterRecord("Player-4618-0B2C3D4E", "Brindlewick", 8, 7),
	}
	local ITEM_NAMES = { [6362] = "Raw Spotted Yellowtail" }
	local AREA_NAMES = { [33] = "Stranglethorn Vale", [1519] = "Stormwind City" }

	-- Core loaded with the fixture Angler's PagleLog, on a client that knows the names above.
	local function load()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({}, 4, CHARACTERS) }))
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

	-- One row of each kind as ns.FieldReportRows() hands it over (PagleReportRow).
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
			loaded.client.addons.Pagle.metadata.Version = "1.60.1"

			local parts = loaded.ns.FieldReportText(ROWS)

			assert.are.equal(1, #parts)
			assert.are.equal(
				"PAGLE-REPORT 1\naddon 1.60.1 data "
					.. fingerprint:sub(1, 8)
					.. " locale enUS reporter f38e76b0 part 1/1\n",
				parts[1]:match("^[^\n]*\n[^\n]*\n")
			)
		end
	)

	it("writes addon dev for a checkout whose TOC still says @project-version@, never the token (REP-R30)", function()
		local loaded = load()
		assert.are.equal("@project-version@", loaded.client.addons.Pagle.metadata.Version)

		local parts = loaded.ns.FieldReportText(ROWS)

		assert.truthy(parts[1]:find("^PAGLE%-REPORT 1\naddon dev data %x+ locale enUS reporter f38e76b0 part 1/1\n"))
	end)

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

describe("the Field report from a fixture Angler's log, rows to text (REP-R20–R22, REP-R30, REP-R35)", function()
	local ADA, BRINDLEWICK = "Player-4618-0A1B2C3D", "Player-4618-0B2C3D4E"
	local FIRST = SERVER_TIME - 4000
	-- A fixture Angler: two characters on the fake client's realm, and REP-R36's logId (savedLog's).
	local CHARACTERS = { characterRecord(), characterRecord(BRINDLEWICK, "Brindlewick", 8, 7) }

	-- Ada catches an Oily Blackmouth in The Long Wash (453), whose zone Darkshore (148) has an unconfirmed skill base;
	-- Brindlewick catches an Uncharted item (9999) in Darkshore, hovering a school first.
	local function report()
		local log = savedLog({
			BUILD_ENTRY,
			castEntry(FIRST + 1),
			castEntry(FIRST + 2, 9999, 0, 2),
		}, 4, CHARACTERS)
		local loaded = loadCore(log, {
			global = {
				diagnostics = {
					{
						id = BRINDLEWICK .. "-" .. FIRST + 2 .. "-0",
						zone = 148,
						subzone = 0,
						locale = "enUS",
						texts = { "Oily Blackmouth School" },
					},
				},
			},
		})
		loaded.client.itemNames[6358] = "Oily Blackmouth"
		loaded.client.areaNames[148] = "Darkshore"
		loaded.client.areaNames[453] = "The Long Wash"
		enterWorld(loaded)
		return loaded, table.concat(loaded.ns.FieldReportText(assert(loaded.ns.FieldReportRows())))
	end

	it(
		"writes the rows ns.FieldReportRows builds from the log and the diagnostics buffer (REP-R20–R23, REP-R30)",
		function()
			local _, text = report()

			local rows = {}
			for line in text:gmatch("([^\n]*)\n") do
				if line:match("^[IKP] ") then
					rows[#rows + 1] = line
				end
			end
			assert.are.same({
				-- Brindlewick's Uncharted Catch: timed, at realm 08:14 in October (REP-R10, REP-R20).
				"I 9999 148 70338 1 t=08:00 m=10 # Darkshore",
				-- Ada's: Oily Blackmouth is on Darkshore's list, unconfirmed, so untimed (REP-R10, REP-R20).
				"I 6358 453 70338 1              # Oily Blackmouth, The Long Wash",
				-- Darkshore's skill base is unconfirmed: both Casts, and Ada's 86+25 landed a known item (REP-R21).
				"K 148 70338 casts=2 away=0 land=111 # Darkshore",
				-- Brindlewick's buffered Cast, with what it caught (REP-R22).
				'P 148 enUS "Oily Blackmouth School" casts=1 9999x1 # Darkshore',
			}, rows)
		end
	)

	it("holds none of the Angler's character names, GUIDs, realm, faction or logId (REP-R35)", function()
		local loaded, text = report()

		local found = {}
		for _, secret in ipairs({
			"Ada",
			"Brindlewick",
			ADA,
			BRINDLEWICK,
			"0A1B2C3D",
			"0B2C3D4E",
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
