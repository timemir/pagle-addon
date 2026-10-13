-- The catalogue as Core publishes it (LOG-R55–R57, DATA-R80), the runtime area index Core builds at login (LOG-R1
-- step 2, LOG-R23), and the zone and subzone areaIDs Core reads from the client (LOG-R22).

local NAMES = {
	[148] = "Darkshore",
	[453] = "The Long Wash",
	[16200] = "Riverglades",
}

-- A catalogue in the M1 shape (DATA-R79): Darkshore (148) with The Long Wash (453) on Kalimdor (1).
local function fixture()
	local function area(parent, continent)
		return { parent = parent, continent = continent, hasData = false, skillBaseConfirmed = false, catches = {} }
	end
	return {
		fingerprint = "0123456789abcdef",
		items = {},
		areas = { [148] = area(0, 1), [453] = area(148, 1) },
		aliases = {},
		pools = {},
		windows = {},
		events = { [301] = { weekday = 1, start = 840, duration = 120, confirmed = false } },
		fishingSpells = { 7620 },
		auras = { 1265220 },
	}
end

-- FOREVER_GLOBALS plus `extra`.
local function foreverWith(extra)
	local globals = {}
	for key, value in pairs(FOREVER_GLOBALS) do
		globals[key] = value
	end
	for key, value in pairs(extra) do
		globals[key] = value
	end
	return globals
end

-- A client standing in `zone`/`subzone` on `continent`, whose C_Map.GetAreaInfo answers from NAMES and counts each
-- ID it's asked for in `asked`.
local function client(zone, subzone, continent)
	local asked = {}
	local globals = foreverWith({
		C_Map = {
			GetAreaInfo = function(id)
				asked[#asked + 1] = id
				return NAMES[id]
			end,
		},
		GetRealZoneText = function()
			return zone
		end,
		GetSubZoneText = function()
			return subzone
		end,
		GetInstanceInfo = function()
			return "Kalimdor", "none", 0, "", 0, 0, false, continent, 0, nil, false
		end,
	})
	return globals, asked
end

-- Loads Core over `data` in place of the generated catalogue, as if Catalogue.lua had set it, then fires
-- ADDON_LOADED.
local function loadOver(data, globals)
	local loaded = loadAddon("Pagle", globals or FOREVER_GLOBALS, { holdAddonLoaded = true })
	loaded.ns.catalogue = data
	loaded.client.fire("ADDON_LOADED", "Pagle")
	return loaded
end

describe("the catalogue on Pagle", function()
	it("is published at ADDON_LOADED over ns.catalogue (LOG-R1, LOG-R55)", function()
		local data = fixture()
		local Pagle = loadOver(data).env.Pagle

		assert.are.same({ 148 }, Pagle.GetZones())
		assert.are.equal(data.areas[453], Pagle.GetArea(453))
		assert.are.equal(148, Pagle.GetZoneOf(453))
		assert.are.same({}, Pagle.GetZoneCatches(148))
		assert.is_nil(Pagle.GetItem(6358))
		assert.is_nil(Pagle.GetWindowSpec("night"))
		assert.are.equal("0123456789abcdef", Pagle.CONTENT_FINGERPRINT)
	end)

	it("gives Core the fishing spells, auras, events and aliases (LOG-R56)", function()
		local catalogue = loadOver(fixture()).ns.Catalogue

		assert.is_true(catalogue.IsFishingSpell(7620))
		assert.are.same({ 1265220 }, catalogue.GetFishingAuras())
		assert.are.same({ 301 }, catalogue.GetEventIDs())
		assert.are.equal(453, catalogue.Unalias(453))
	end)
end)

describe("the generated catalogue on Pagle", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	local Pagle, data = loaded.env.Pagle, loaded.ns.catalogue

	it("carries the generated fingerprint (LOG-R55, DATA-R70)", function()
		assert.are.equal(data.fingerprint, Pagle.CONTENT_FINGERPRINT)
	end)

	it("lists each zone of the generated slice once, ascending, and nothing else (LOG-R55)", function()
		local zones = Pagle.GetZones()
		for i, areaID in ipairs(zones) do
			assert.are.equal(0, data.areas[areaID].parent)
			assert.is_true(i == 1 or zones[i - 1] < areaID)
		end
		local count = 0
		for _, area in pairs(data.areas) do
			count = count + (area.parent == 0 and 1 or 0)
		end
		assert.are.equal(count, #zones)
	end)

	-- Items are charted from #90 (DATA-R77; spec/Pagle/data/Catalogue_spec.lua covers GetItem's records).
	it("charts no catch and no window before their M2 tickets (LOG-R57, DATA-R79)", function()
		for _, areaID in ipairs(Pagle.GetZones()) do
			assert.are.same({}, Pagle.GetZoneCatches(areaID))
		end
		for _, window in ipairs({ "day", "night", "spring", "summer", "autumn", "winter", "event.301" }) do
			assert.is_nil(Pagle.GetWindowSpec(window))
		end
	end)

	it("puts every area of the generated slice under its zone, unless its parents leave the slice (LOG-R55)", function()
		for areaID in pairs(data.areas) do
			local zone = Pagle.GetZoneOf(areaID)
			if zone then
				assert.are.equal(0, data.areas[zone].parent)
			else
				-- e.g. 17845, whose parent 16597 isn't in areas.csv
				local top = areaID
				while data.areas[top] and data.areas[top].parent ~= 0 do
					top = data.areas[top].parent
				end
				assert(data.areas[top] == nil, ("area %d belongs to no zone"):format(areaID))
			end
		end
		-- The probe's Catch at The Long Wash, Darkshore (probes/fishing-signals/results/2026-10-11-build70338-report.md).
		assert.are.equal(148, Pagle.GetZoneOf(453))
	end)

	it("resolves the probe's Catch at The Long Wash, Darkshore, on Kalimdor (LOG-R22)", function()
		local live = loadAddon("Pagle", client("Darkshore", "The Long Wash", 1))
		live.client.fire("PLAYER_LOGIN")

		assert.are.same({ 148, 453 }, { live.ns.ReadAreas() })
	end)

	it("knows the Fishing spell and the Extravaganza's weekly rule (LOG-R56, DATA-R38, DATA-R39)", function()
		assert.is_true(loaded.ns.Catalogue.IsFishingSpell(7620))
		assert.are.equal(1, loaded.ns.Catalogue.GetEventRule(301).weekday)
	end)
end)

describe("the runtime area index", function()
	it("is built at PLAYER_LOGIN over IDs 1 to 40,000, once per login (LOG-R1, LOG-R23)", function()
		local globals, asked = client("Darkshore", "", 1)
		local loaded = loadOver(fixture(), globals)
		assert.are.equal(0, #asked)

		loaded.client.fire("PLAYER_LOGIN")
		assert.are.equal(40000, #asked)
		assert.are.equal(1, asked[1])
		assert.are.equal(40000, asked[40000])

		loaded.client.fire("PLAYER_LOGIN")
		assert.are.equal(40000, #asked)
	end)
end)

describe("ns.ReadAreas", function()
	-- Core over the fixture, logged in, in `zone`/`subzone` on `continent`.
	local function readIn(zone, subzone, continent, extra)
		local globals = client(zone, subzone, continent)
		for key, value in pairs(extra or {}) do
			globals[key] = value
		end
		local loaded = loadOver(fixture(), globals)
		loaded.client.fire("PLAYER_LOGIN")
		return { loaded.ns.ReadAreas() }
	end

	it("resolves the client's zone and subzone texts on its continent (LOG-R22)", function()
		assert.are.same({ 148, 453 }, readIn("Darkshore", "The Long Wash", 1))
	end)

	it("hands back the texts of a name that didn't resolve (LOG-R22, LOG-R81)", function()
		assert.are.same({ 148, 0, { zone = "Darkshore", subzone = "Nowhere" } }, readIn("Darkshore", "Nowhere", 1))
	end)

	it("treats a secret text or continent as unknown, never as a name (LOG-R22, CORE-R31)", function()
		local secret = {}
		local secrets = {
			issecretvalue = function(value)
				return value == secret
			end,
		}

		assert.are.same({ 0, 0 }, readIn(secret, secret, 1, secrets))
		assert.are.same({ 148, 0 }, readIn("Darkshore", secret, 1, secrets))
		assert.are.same({ 0, 0, { zone = "Darkshore", subzone = "" } }, readIn("Darkshore", "", secret, secrets))
	end)
end)

describe("the catalogue and SavedVariables", function()
	-- Every table reachable from `root`, as a set.
	local function reachable(root, seen)
		seen = seen or {}
		if type(root) == "table" and not seen[root] then
			seen[root] = true
			for key, value in pairs(root) do
				reachable(key, seen)
				reachable(value, seen)
			end
		end
		return seen
	end

	-- The SavedVariables names Pagle.toc declares.
	local function savedVariables()
		local names = {}
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		for line in io.lines("addons/Pagle/Pagle.toc") do
			local list = line:match("^##%s*SavedVariables[%w]*:%s*(.-)%s*$")
			for name in (list or ""):gmatch("[^,%s]+") do
				names[#names + 1] = name
			end
		end
		return names
	end

	it("leaves no catalogue table in a SavedVariable after login (DATA-R80)", function()
		local loaded = loadAddon("Pagle", client("Darkshore", "The Long Wash", 1))
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		local catalogueTables = reachable(loaded.ns.catalogue)
		for _, name in ipairs(savedVariables()) do
			for saved in pairs(reachable(loaded.env[name])) do
				assert(catalogueTables[saved] == nil, name .. " holds a catalogue table")
			end
		end
	end)
end)
