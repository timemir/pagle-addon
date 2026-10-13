-- Restriction state: Pagle.IsRestricted, RestrictionChanged and the restricted-work queue (CORE-R30, CORE-R32).

-- Enum.AddOnRestrictionType.Combat and Enum.AddOnRestrictionState (forever dump's LuaEnum.lua at BIR_COMMIT).
local COMBAT, ENCOUNTER = 0, 1
local INACTIVE, ACTIVATING, ACTIVE = 0, 1, 2

-- Loads Core and records every RestrictionChanged it fires after load, as a list of isRestricted values.
local function loadWatching(extra)
	local loaded = loadAddon("Pagle", foreverWith(extra or {}))
	local fired = {}
	loaded.env.Pagle.RegisterCallback("Spec", "RestrictionChanged", function(_, isRestricted)
		fired[#fired + 1] = isRestricted
	end)
	return loaded, fired
end

describe("Pagle.IsRestricted", function()
	it("is false out of combat with no restriction active (CORE-R30)", function()
		assert.is_false(loadAddon("Pagle", FOREVER_GLOBALS).env.Pagle.IsRestricted())
	end)

	it("starts true after a load in combat (CORE-R30)", function()
		local loaded = loadAddon(
			"Pagle",
			foreverWith({
				InCombatLockdown = function()
					return true
				end,
			})
		)

		assert.is_true(loaded.env.Pagle.IsRestricted())
	end)

	it("starts true after a load with an addon restriction active or activating (CORE-R30)", function()
		local restricted = {}
		for _, state in ipairs({ ACTIVE, ACTIVATING }) do
			local loaded = loadAddon(
				"Pagle",
				foreverWith({
					C_RestrictedActions = {
						GetAddOnRestrictionState = function(restrictionType)
							return restrictionType == ENCOUNTER and state or INACTIVE
						end,
					},
				})
			)
			restricted[#restricted + 1] = loaded.env.Pagle.IsRestricted()
		end

		assert.are.same({ true, true }, restricted)
	end)

	it("reads the starting state at ADDON_LOADED and fires nothing for it (CORE-R30)", function()
		local inCombat = false
		local loaded = loadAddon(
			"Pagle",
			foreverWith({
				InCombatLockdown = function()
					return inCombat
				end,
			}),
			{ holdAddonLoaded = true }
		)
		local fired = {}
		loaded.env.Pagle.RegisterCallback("Spec", "RestrictionChanged", function(_, isRestricted)
			fired[#fired + 1] = isRestricted
		end)

		inCombat = true
		loaded.client.fire("ADDON_LOADED", "Pagle")

		assert.is_true(loaded.env.Pagle.IsRestricted())
		assert.are.same({}, fired)
	end)

	it("follows combat, firing RestrictionChanged on each change (CORE-R30)", function()
		local loaded, fired = loadWatching()
		local Pagle = loaded.env.Pagle

		loaded.client.fire("PLAYER_REGEN_DISABLED")
		assert.is_true(Pagle.IsRestricted())
		loaded.client.fire("PLAYER_REGEN_ENABLED")
		assert.is_false(Pagle.IsRestricted())

		assert.are.same({ true, false }, fired)
	end)

	it("follows addon restrictions, from the event's payload (CORE-R30)", function()
		local loaded, fired = loadWatching()
		local Pagle = loaded.env.Pagle

		-- As the 70338 QoL probe saw it: (0, 1) at combat start, (0, 0) after (probes/qol/results/).
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, ACTIVATING)
		assert.is_true(Pagle.IsRestricted())
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, ACTIVE)
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, INACTIVE)
		assert.is_false(Pagle.IsRestricted())

		assert.are.same({ true, false }, fired)
	end)

	it("stays true until both combat and every restriction have ended, firing once each way (CORE-R30)", function()
		local loaded, fired = loadWatching()
		local Pagle = loaded.env.Pagle

		loaded.client.fire("PLAYER_REGEN_DISABLED")
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, ACTIVE)
		loaded.client.fire("PLAYER_REGEN_ENABLED")
		assert.is_true(Pagle.IsRestricted())
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, INACTIVE)

		assert.is_false(Pagle.IsRestricted())
		assert.are.same({ true, false }, fired)
	end)
end)

describe("restricted work (ns.RunWhenUnrestricted)", function()
	it("runs work at once while unrestricted (CORE-R32)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local ran = false

		loaded.ns.RunWhenUnrestricted(function()
			ran = true
		end)

		assert.is_true(ran)
	end)

	it("holds work while restricted and runs it in order at RestrictionChanged(false) (CORE-R32)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local ran = {}
		loaded.client.fire("PLAYER_REGEN_DISABLED")
		for i = 1, 3 do
			loaded.ns.RunWhenUnrestricted(function()
				ran[#ran + 1] = i
			end)
		end

		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, ACTIVE)
		loaded.client.fire("PLAYER_REGEN_ENABLED")
		assert.are.same({}, ran) -- combat is over, but the restriction isn't
		loaded.client.fire("ADDON_RESTRICTION_STATE_CHANGED", COMBAT, INACTIVE)

		assert.are.same({ 1, 2, 3 }, ran)
	end)

	it("holds work queued after a load in combat until combat ends (CORE-R32)", function()
		local loaded = loadAddon(
			"Pagle",
			foreverWith({
				InCombatLockdown = function()
					return true
				end,
			})
		)
		local ran = false
		loaded.ns.RunWhenUnrestricted(function()
			ran = true
		end)

		assert.is_false(ran)
		loaded.client.fire("PLAYER_REGEN_ENABLED")

		assert.is_true(ran)
	end)

	it("sends a failing piece of work to geterrorhandler() and still runs the rest (CORE-R32)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local errors, ran = {}, {}
		loaded.env.geterrorhandler = function()
			return function(err)
				errors[#errors + 1] = tostring(err)
			end
		end
		loaded.client.fire("PLAYER_REGEN_DISABLED")
		loaded.ns.RunWhenUnrestricted(function()
			error("settings broke")
		end)
		loaded.ns.RunWhenUnrestricted(function()
			ran[#ran + 1] = "after"
		end)

		loaded.client.fire("PLAYER_REGEN_ENABLED")

		assert.are.same({ "after" }, ran)
		assert.are.equal(1, #errors)
		assert.matches("settings broke", errors[1])
	end)

	it("has run the queue by the time RestrictionChanged(false) reaches listeners (CORE-R32)", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		local order = {}
		loaded.env.Pagle.RegisterCallback("Spec", "RestrictionChanged", function(_, isRestricted)
			order[#order + 1] = "RestrictionChanged " .. tostring(isRestricted)
		end)
		loaded.client.fire("PLAYER_REGEN_DISABLED")
		loaded.ns.RunWhenUnrestricted(function()
			order[#order + 1] = "work"
		end)

		loaded.client.fire("PLAYER_REGEN_ENABLED")

		assert.are.same({ "RestrictionChanged true", "work", "RestrictionChanged false" }, order)
	end)
end)
