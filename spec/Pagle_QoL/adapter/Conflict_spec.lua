-- Coexisting with Angleur and Fishing Buddy: the conflict check at PLAYER_LOGIN, the popup, its two choices, Esc,
-- and standing down (QOL-R33, QOL-R80–R84, QOL-R97), driven through FakePagle and the fake client's popups
-- (spec/support/fake_popup.lua).

local CAST = "SPELL Fishing"
local ANGLEUR = { metadata = { Title = "Angleur" } }
local FISHING_BUDDY = { metadata = { Title = "Fishing Buddy (Forever)" } }

-- QoL loaded against FakePagle with F bound to the Fishing key and `others` installed, then logged in.
---@param others table<string, FakeAddOn>
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(others)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.boundKeys.PAGLE_FISHING_KEY = { "F" }
	for name, addon in pairs(others) do
		client.addons[name] = addon
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

describe("The conflict check", function()
	it("shows no popup and arms at login when no other fishing-key addon is loaded (QOL-R80, QOL-R33)", function()
		local _, client = start({ Details = { metadata = { Title = "Details!" } } })

		assert.is_nil(client.popup)
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	it("ignores an other fishing-key addon that is installed but not loaded (QOL-R80)", function()
		local _, client = start({ Angleur = { enabled = false, metadata = { Title = "Angleur" } } })

		assert.is_nil(client.popup)
		assert.are.equal(CAST, client.overrideAction("F"))
	end)

	it("asks with Use Pagle and Use {Angleur's title} when Angleur is loaded (QOL-R81)", function()
		local _, client = start({ Angleur = ANGLEUR })

		assert.are.equal("Two addons want your fishing key.", client.popup.text)
		assert.are.same({ [1] = "Use Pagle", [3] = "Use Angleur" }, client.popup.buttons)
	end)

	it("offers Use the others when several are loaded (QOL-R81)", function()
		local _, client = start({ Angleur = ANGLEUR, FishingBuddy = FISHING_BUDDY })

		assert.are.same({ [1] = "Use Pagle", [3] = "Use the others" }, client.popup.buttons)
	end)

	it("runs before the first arm, so QoL never arms and then stands down (QOL-R33, QOL-R82)", function()
		local _, client = start({ Angleur = ANGLEUR })

		assert.is_nil(client.overrideAction("F"))
		assert.are.same({}, client.bindingCalls)
	end)
end)

describe("The conflict popup's choices", function()
	it("Use Pagle turns each other addon off for all characters and names them (QOL-R83)", function()
		local _, client, loaded = start({ Angleur = ANGLEUR, FishingBuddy = FISHING_BUDDY })

		client.clickPopup(1)

		assert.are.same({ { name = "Angleur" }, { name = "FishingBuddy" } }, client.disabledAddOns)
		assert.are.same(
			{ "Pagle: turned off Angleur, Fishing Buddy (Forever). Type /reload to finish." },
			loaded.printed
		)
		assert.are.equal(0, client.reloads)
	end)

	it("Use {other} turns off Pagle QoL alone, for all characters (QOL-R83)", function()
		local _, client, loaded = start({ Angleur = ANGLEUR })

		client.clickPopup(3)

		assert.are.same({ { name = "Pagle_QoL" } }, client.disabledAddOns)
		assert.are.same({
			"Pagle: turned off Pagle QoL. Type /reload to finish. Pagle keeps recording your Catches.",
		}, loaded.printed)
		assert.are.equal(0, client.reloads)
	end)

	it("Esc chooses nothing (QOL-R81, QOL-R84)", function()
		local _, client, loaded = start({ Angleur = ANGLEUR })

		client.pressEscape()

		assert.is_nil(client.popup)
		assert.are.same({}, client.disabledAddOns)
		assert.are.same({}, loaded.printed)
		assert.are.equal(0, client.reloads)
	end)

	it("asks again at the next login after Esc (QOL-R84)", function()
		local _, client = start({ Angleur = ANGLEUR })
		client.pressEscape()

		local _, nextLogin = start({ Angleur = ANGLEUR })

		assert.are.same({ [1] = "Use Pagle", [3] = "Use Angleur" }, nextLogin.popup.buttons)
	end)
end)

describe("The Reload now popup", function()
	-- Each choice, by the popup button that makes it (QOL-R81).
	local CHOICES = { ["Use Pagle"] = 1, ["Use {other}"] = 3 }

	for choice, button in pairs(CHOICES) do
		it(("follows %s, in place of the conflict popup (QOL-R83)"):format(choice), function()
			local _, client = start({ Angleur = ANGLEUR })

			client.clickPopup(button)

			assert.are.equal("Reload the interface now to finish?", client.popup.text)
			assert.are.same({ [1] = "Reload now", [2] = "Later" }, client.popup.buttons)
			assert.are.equal(0, client.reloads)
		end)

		it(("reloads on a click on Reload now after %s (QOL-R6, QOL-R83)"):format(choice), function()
			local _, client = start({ Angleur = ANGLEUR })
			client.clickPopup(button)

			client.clickPopup(1)

			assert.are.equal(1, client.reloads)
			assert.is_nil(client.popup)
		end)

		it(("doesn't reload on Later or Esc after %s (QOL-R6, QOL-R83)"):format(choice), function()
			local _, client = start({ Angleur = ANGLEUR })
			client.clickPopup(button)
			client.clickPopup(2)
			local _, again = start({ Angleur = ANGLEUR })
			again.clickPopup(button)
			again.pressEscape()

			assert.is_nil(client.popup)
			assert.is_nil(again.popup)
			assert.are.equal(0, client.reloads + again.reloads)
		end)
	end

	it("never reloads on its own: not at load, on events, restriction or time (QOL-R6)", function()
		local fake, client = start({ Angleur = ANGLEUR })
		client.clickPopup(1)

		fake.fireGameEvent("UPDATE_BINDINGS")
		fake.fire("CastStarted")
		fake.fire("CastEnded")
		fake.setRestricted(true)
		fake.setRestricted(false)
		client.update(60)

		assert.are.equal(0, client.reloads)
	end)

	it("isn't offered when no other fishing-key addon is loaded, nor on Esc (QOL-R83, QOL-R84)", function()
		local _, client = start({})
		local _, escaped = start({ Angleur = ANGLEUR })
		escaped.pressEscape()

		assert.is_nil(client.popup)
		assert.is_nil(escaped.popup)
		assert.are.equal(0, client.reloads + escaped.reloads)
	end)
end)

describe("Standing down", function()
	-- Every way the popup can end: unanswered, either choice (which waits for /reload), or Esc.
	local ENDINGS = {
		unanswered = function() end,
		["Use Pagle"] = function(client)
			client.clickPopup(1)
		end,
		["Use {other}"] = function(client)
			client.clickPopup(3)
		end,
		Esc = function(client)
			client.pressEscape()
		end,
	}

	for ending, finish in pairs(ENDINGS) do
		it(("binds nothing and doesn't tick for the session: %s (QOL-R82, QOL-R97)"):format(ending), function()
			local fake, client = start({ Angleur = ANGLEUR })
			finish(client)

			client.boundKeys.PAGLE_FISHING_KEY = { "G" }
			fake.fireGameEvent("UPDATE_BINDINGS")
			fake.fire("CastStarted")
			fake.setRestricted(true)
			fake.setRestricted(false)
			client.update(0.5)

			assert.are.same({}, client.bindingCalls)
			for _, frame in ipairs(client.frames) do
				assert.is_nil(frame.scripts.OnUpdate)
			end
		end)
	end

	it("keeps QoL registered with Core and its saved settings, which still save (QOL-R82)", function()
		local fake, _, loaded = start({ Angleur = ANGLEUR })

		assert.are.equal("on", fake.moduleState("QoL"))
		loaded.ns.db.global.someSetting = true
		assert.is_true(loaded.env.PagleQoLDB.global.someSetting)
	end)
end)
