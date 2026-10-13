-- Restriction types as Enum.AddOnRestrictionType numbers them (forever dump's LuaEnum.lua at BIR_COMMIT).
local COMBAT, ENCOUNTER = 0, 1

describe("ns.NewRestriction", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	it("starts restricted when it starts in combat or with a restriction active (CORE-R30)", function()
		assert.is_false(ns.NewRestriction(false, {}):IsRestricted())
		assert.is_true(ns.NewRestriction(true, {}):IsRestricted())
		assert.is_true(ns.NewRestriction(false, { [ENCOUNTER] = true }):IsRestricted())
		assert.is_false(ns.NewRestriction(false, { [COMBAT] = false }):IsRestricted())
	end)

	it("is restricted while either combat or a restriction is active, and says when that flips (CORE-R30)", function()
		local state = ns.NewRestriction(false, {})
		-- Each step: whether it flipped, then whether it's restricted after it.
		local function step(changed)
			return { changed, state:IsRestricted() }
		end

		assert.are.same({ true, true }, step(state:SetCombat(true))) -- combat starts
		assert.are.same({ false, true }, step(state:SetRestriction(COMBAT, true))) -- its restriction joins
		assert.are.same({ false, true }, step(state:SetCombat(false))) -- combat ends, the restriction holds
		assert.are.same({ false, true }, step(state:SetRestriction(ENCOUNTER, true))) -- another joins
		assert.are.same({ false, true }, step(state:SetRestriction(COMBAT, false))) -- one ends
		assert.are.same({ true, false }, step(state:SetRestriction(ENCOUNTER, false))) -- the last one ends
	end)

	it("doesn't flip when told what it already knows (CORE-R30)", function()
		local state = ns.NewRestriction(true, {})

		assert.is_false(state:SetCombat(true))
		assert.is_false(state:SetRestriction(COMBAT, false))
		assert.is_true(state:IsRestricted())
	end)
end)
