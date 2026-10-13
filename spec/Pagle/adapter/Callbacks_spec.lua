-- Core's event bus: Pagle.RegisterCallback and friends, fired by Core through ns.Fire.

describe("Core's event bus", function()
	it("calls each listener with the event name, then the payload (CORE-R20)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local got
		loaded.env.Pagle.RegisterCallback("Ledger", "TestEvent", function(...)
			got = { ... }
		end)

		loaded.ns.Fire("TestEvent", 1, "two")

		assert.are.same({ "TestEvent", 1, "two" }, got)
	end)

	it("stops calling a listener after UnregisterCallback and UnregisterAllCallbacks (CORE-R20)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local Pagle = loaded.env.Pagle
		local calls = 0
		local function count()
			calls = calls + 1
		end
		Pagle.RegisterCallback("Ledger", "TestEvent", count)
		Pagle.RegisterCallback("Hunts", "TestEvent", count)
		Pagle.RegisterCallback("Hunts", "OtherEvent", count)

		Pagle.UnregisterCallback("Ledger", "TestEvent")
		Pagle.UnregisterAllCallbacks("Hunts")
		loaded.ns.Fire("TestEvent")
		loaded.ns.Fire("OtherEvent")

		assert.are.equal(0, calls)
	end)

	it("sends a listener's error to geterrorhandler() and still calls the next listener (CORE-R21)", function()
		local loaded, errors = loadCollectingErrors()
		local Pagle = loaded.env.Pagle
		local reached = {}
		for _, owner in ipairs({ "Ledger", "Hunts", "Stats" }) do
			Pagle.RegisterCallback(owner, "TestEvent", function()
				reached[#reached + 1] = owner
				error(owner .. " broke")
			end)
		end

		loaded.ns.Fire("TestEvent")

		table.sort(reached)
		assert.are.same({ "Hunts", "Ledger", "Stats" }, reached)
		assert.are.equal(3, #errors)
		assert.matches("Hunts broke", table.concat(errors, "\n"))
	end)

	it("gives Modules no way to fire an event (CORE-R22)", function()
		local Pagle = loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle

		local firing = {}
		for key, value in pairs(Pagle) do
			if type(value) == "function" and key:match("Fire") then
				firing[#firing + 1] = key
			end
		end
		assert.are.same({}, firing)
		assert.is_nil(rawget(Pagle, "callbacks"))
	end)

	it("hands listeners nil for each secret value in a payload (CORE-R31)", function()
		local secret = {}
		local loaded = loadAddon("Pagle", {
			WOW_PROJECT_ID = PROJECT_IDS.CAMELOT,
			WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT,
			issecretvalue = function(value)
				return value == secret
			end,
		})
		local got
		loaded.env.Pagle.RegisterCallback("Ledger", "TestEvent", function(...)
			got = { n = select("#", ...), ... }
		end)

		loaded.ns.Fire("TestEvent", secret, 2, secret)

		assert.are.same({ n = 4, "TestEvent", nil, 2, nil }, got)
	end)
end)
