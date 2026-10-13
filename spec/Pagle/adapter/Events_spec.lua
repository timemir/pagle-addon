-- WoW event registration through Core: Pagle.RegisterEvent, RegisterUnitEvent and UnregisterEvent (CORE-R23).

describe("Pagle.RegisterEvent", function()
	it("calls the handler with the event name, then the event's arguments (CORE-R23)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local got
		loaded.env.Pagle.RegisterEvent("Ledger", "BAG_UPDATE", function(...)
			got = { ... }
		end)

		loaded.client.fire("BAG_UPDATE", 0)

		assert.are.same({ "BAG_UPDATE", 0 }, got)
	end)

	it("calls every owner registered for the event (CORE-R23)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local reached = {}
		for _, owner in ipairs({ "Ledger", "Hunts" }) do
			loaded.env.Pagle.RegisterEvent(owner, "BAG_UPDATE", function()
				reached[#reached + 1] = owner
			end)
		end

		loaded.client.fire("BAG_UPDATE", 0)

		table.sort(reached)
		assert.are.same({ "Hunts", "Ledger" }, reached)
	end)

	it("stops calling an owner's handler after UnregisterEvent, and only that owner's (CORE-R23)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local Pagle = loaded.env.Pagle
		local reached = {}
		for _, owner in ipairs({ "Ledger", "Hunts" }) do
			Pagle.RegisterEvent(owner, "BAG_UPDATE", function()
				reached[#reached + 1] = owner
			end)
		end

		Pagle.UnregisterEvent("Ledger", "BAG_UPDATE")
		loaded.client.fire("BAG_UPDATE", 0)

		assert.are.same({ "Hunts" }, reached)
	end)

	it("reports an event the client doesn't know and carries on (CORE-R23)", function()
		local loaded, errors = loadCollectingErrors()
		loaded.client.missingEvents.NOT_ON_FOREVER = true
		local Pagle = loaded.env.Pagle
		local fine = 0

		Pagle.RegisterEvent("Ledger", "NOT_ON_FOREVER", function() end) -- returns: an error here fails the spec
		Pagle.RegisterEvent("Ledger", "BAG_UPDATE", function()
			fine = fine + 1
		end)
		loaded.client.fire("BAG_UPDATE", 0)

		assert.are.equal(1, fine)
		assert.are.equal(1, #errors)
		assert.matches("Ledger", errors[1])
		assert.matches("NOT_ON_FOREVER", errors[1])
	end)

	it("reports a handler's error once per owner and event per login, however often it fails (CORE-R23)", function()
		local loaded, errors = loadCollectingErrors()
		local Pagle = loaded.env.Pagle
		local hunts = 0
		Pagle.RegisterEvent("Ledger", "BAG_UPDATE", function()
			error("Ledger broke")
		end)
		Pagle.RegisterEvent("Ledger", "LOOT_OPENED", function()
			error("Ledger broke again")
		end)
		Pagle.RegisterEvent("Hunts", "BAG_UPDATE", function()
			hunts = hunts + 1
		end)

		for _ = 1, 3 do
			loaded.client.fire("BAG_UPDATE", 0)
			loaded.client.fire("LOOT_OPENED")
		end

		assert.are.equal(3, hunts)
		assert.are.equal(2, #errors)
		assert.matches("BAG_UPDATE", errors[1])
		assert.matches("Ledger broke", errors[1])
		assert.matches("LOOT_OPENED", errors[2])
	end)
end)

describe("Pagle.RegisterUnitEvent", function()
	it("calls the handler only for the unit it names (CORE-R23)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local units = {}
		loaded.env.Pagle.RegisterUnitEvent("Ledger", "UNIT_AURA", "player", function(event, unit)
			units[#units + 1] = event .. " " .. unit
		end)

		loaded.client.fire("UNIT_AURA", "target")
		loaded.client.fire("UNIT_AURA", "player")

		assert.are.same({ "UNIT_AURA player" }, units)
	end)

	it("keeps each owner's unit apart (CORE-R23)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local reached = {}
		for owner, unit in pairs({ Ledger = "player", Hunts = "target" }) do
			loaded.env.Pagle.RegisterUnitEvent(owner, "UNIT_AURA", unit, function(_, firedFor)
				reached[#reached + 1] = owner .. " " .. firedFor
			end)
		end

		loaded.client.fire("UNIT_AURA", "player")
		loaded.client.fire("UNIT_AURA", "target")

		table.sort(reached)
		assert.are.same({ "Hunts target", "Ledger player" }, reached)
	end)

	it("reports an event the client doesn't know and carries on (CORE-R23)", function()
		local loaded, errors = loadCollectingErrors()
		loaded.client.missingEvents.NOT_ON_FOREVER = true

		loaded.env.Pagle.RegisterUnitEvent("Ledger", "NOT_ON_FOREVER", "player", function() end) -- returns

		assert.are.equal(1, #errors)
		assert.matches("NOT_ON_FOREVER", errors[1])
	end)
end)
