-- The generated catalogue's areas on Pagle (LOG-R55's area part): each area's catch list, gates, skill base and
-- hasData as the committed data gives them (DATA-R26–R31, DATA-R78), through GetArea, GetZones, GetZoneOf and
-- GetZoneCatches.

-- Brownell's Blue Striped Racer, Keefer's Angelfish, Dezian Queenfish and Speckled Tastyfish (DATA-R28).
local EXTRAVAGANZA = { 19803, 19805, 19806, 19807 }

describe("the generated catalogue's areas on Pagle", function()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	local Pagle, data = loaded.env.Pagle, loaded.ns.catalogue

	-- The entry for itemID in a list, or nil.
	local function entryFor(catches, itemID)
		for _, entry in ipairs(catches) do
			if entry.itemID == itemID then
				return entry
			end
		end
		return nil
	end

	it("give Thieves Camp an empty list (DATA-R27)", function()
		local area = Pagle.GetArea(53)
		assert.are.same({}, area.catches)
		assert.are.equal(12, area.parent)
		assert.is_true(area.hasData) -- a subzone takes its zone's hasData (DATA-R31)
	end)

	it("list the Extravaganza fish in Stranglethorn Vale, gated by event.301 (DATA-R28, DATA-R78)", function()
		local area = Pagle.GetArea(33)
		local spec = data.windows["event.301"].spec
		assert.are.same({ events = { 301 } }, spec)
		for _, itemID in ipairs(EXTRAVAGANZA) do
			local entry = entryFor(area.catches, itemID) or {}
			assert.are.same({ itemID = itemID, confirmed = false, window = "event.301", gateConfirmed = false }, {
				itemID = entry.itemID,
				confirmed = entry.confirmed,
				window = entry.window,
				gateConfirmed = entry.gateConfirmed,
			})
			-- The gate is windows["event.301"]'s own spec table, W["event.301"], not a copy (Contracts).
			assert(rawequal(spec, entry.gate), ("item %d's gate"):format(itemID))
		end
		assert.are.equal(130, area.skillBase)
		assert.is_false(area.skillBaseConfirmed)
	end)

	it("list each item once per area, by item ID, every entry unconfirmed (DATA-R26, DATA-R56)", function()
		for areaID, area in pairs(data.areas) do
			for i, entry in ipairs(area.catches) do
				assert(i == 1 or area.catches[i - 1].itemID < entry.itemID, ("area %d's list"):format(areaID))
				assert.is_false(entry.confirmed)
			end
		end
	end)

	it("never list a Noise or removed item (DATA-R26)", function()
		for _, area in pairs(data.areas) do
			for _, entry in ipairs(area.catches) do
				local item = Pagle.GetItem(entry.itemID) or {}
				assert(item.noise == false and item.removed == false, ("item %d ships and counts"):format(entry.itemID))
			end
		end
	end)

	it("carry window, gate and gateConfirmed together, the gate being its window's spec (LOG-R55)", function()
		local gated = 0
		for _, area in pairs(data.areas) do
			for _, entry in ipairs(area.catches) do
				local fields = (entry.window ~= nil and 1 or 0)
					+ (entry.gate ~= nil and 1 or 0)
					+ (entry.gateConfirmed ~= nil and 1 or 0)
				assert(fields == 0 or fields == 3, ("item %d: window, gate and gateConfirmed"):format(entry.itemID))
				if entry.window then
					gated = gated + 1
					-- The window's shared spec table, whose condition GetWindowSpec hands out with its confirmed.
					assert(rawequal(data.windows[entry.window].spec, entry.gate), entry.window)
					local named = Pagle.GetWindowSpec(entry.window) or {}
					for field, values in pairs(entry.gate) do
						assert(named[field] == values, ("%s.%s"):format(entry.window, field))
					end
				end
			end
		end
		assert.is_true(gated > 0)
	end)

	it("give alias sources no data and no catches (DATA-R31)", function()
		for source in pairs(data.aliases) do
			local area = Pagle.GetArea(source)
			if area then
				assert.are.same({ hasData = false, catches = {} }, { hasData = area.hasData, catches = area.catches })
			end
		end
		assert.is_false(Pagle.GetArea(16521).hasData)
	end)

	it("give the new Forever zones no data (DATA-R31)", function()
		-- Riverglades, Shen'dralas, Gilneas, Mount Hyjal
		for _, areaID in ipairs({ 16591, 16651, 17065, 616 }) do
			assert(Pagle.GetArea(areaID).hasData == false, ("area %d"):format(areaID))
		end
	end)

	it("give a subzone of a zone with data hasData, though its own list is empty (DATA-R31)", function()
		-- 16005 sits in Winterspring (618), which has a list.
		assert.are.same({}, Pagle.GetArea(16005).catches)
		assert.are.equal(618, Pagle.GetZoneOf(16005))
		assert.is_true(Pagle.GetArea(618).hasData)
		assert.is_true(Pagle.GetArea(16005).hasData)
	end)

	it("give a zone's skill base from the baseline, and a subzone only the one areas.toml sets (DATA-R30)", function()
		assert.are.equal(-70, Pagle.GetArea(14).skillBase) -- Durotar
		assert.are.equal(205, Pagle.GetArea(297).skillBase) -- Jaguero Isle, set in areas.toml
		assert.is_nil(Pagle.GetArea(453).skillBase) -- The Long Wash
	end)

	it("list Stranglethorn Vale among the zones, and its subzones under it (LOG-R55)", function()
		local isZone = {}
		for _, areaID in ipairs(Pagle.GetZones()) do
			isZone[areaID] = true
		end
		assert.is_true(isZone[33])
		assert.is_nil(isZone[297])
		assert.are.equal(33, Pagle.GetZoneOf(297))
		assert.are.equal(33, Pagle.GetZoneOf(33))
	end)

	it("give GetZoneCatches(33) its subzones' entries, each with its areaID, once per area (LOG-R55)", function()
		local catches = Pagle.GetZoneCatches(33)
		local seen, fromSubzone, expected = {}, false, 0
		for areaID, area in pairs(data.areas) do
			if Pagle.GetZoneOf(areaID) == 33 then
				expected = expected + #area.catches
			end
		end
		for _, entry in ipairs(catches) do
			assert.are.equal(33, Pagle.GetZoneOf(entry.areaID))
			local key = entry.areaID .. ":" .. entry.itemID
			assert(seen[key] == nil, key .. " is listed twice")
			seen[key] = true
			fromSubzone = fromSubzone or entry.areaID ~= 33
			assert.is_table(entryFor(Pagle.GetArea(entry.areaID).catches, entry.itemID))
		end
		assert.are.equal(expected, #catches)
		assert.is_true(fromSubzone)
		for _, itemID in ipairs(EXTRAVAGANZA) do
			assert(seen["33:" .. itemID], ("item %d at 33"):format(itemID))
		end
		-- Jaguero Isle (297) lists Raw Spotted Yellowtail (13756), gated by summer.
		assert.is_true(seen["297:13756"])
	end)
end)
