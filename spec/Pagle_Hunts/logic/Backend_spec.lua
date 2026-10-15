-- Hunts' projection for Pagle's backend (#223): ns.BindProjections and ns.CoinsEarned (logic/Projection.lua), on
-- FakePagle over the fixture Hunt list and catalogue. The backend's driver folds the Catch log through logic/ alone
-- (spec/logic_alone_spec.lua), so the binding must fold the Hunts as the client's projection does.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local C = hunts.catalogue
local NIGHT, DAY, DUSK, JUNE_1 = hunts.NIGHT, hunts.DAY, hunts.DUSK, hunts.JUN_1
local cast, append, login = hunts.cast, hunts.append, hunts.login

local AUBERDINE = { zone = C.DARKSHORE, subzone = C.AUBERDINE }
local DARKSHORE = { zone = C.DARKSHORE }
local WESTFALL = { zone = C.WESTFALL }

-- Three Hunts completed (a night Nightfin, a Deviate Fish at dusk, uncommon items under the Rack's aura), the Rack's
-- second tier reached with five of them, and the fixture_dusk set's title.
---@param fake table
local function history(fake)
	append(fake, {
		cast(0, NIGHT, AUBERDINE, { C.NIGHTFIN }),
		cast(0, NIGHT + 30, AUBERDINE),
		cast(1, DAY, DARKSHORE, { C.NIGHTFIN }),
		cast(1, NIGHT + 60, WESTFALL),
		cast(2, DUSK, DARKSHORE, { C.DEVIATE }),
		cast(2, DUSK + 30, DARKSHORE, { C.UNCOMMON }, { C.RACK_AURA }),
		cast(3, DAY, WESTFALL, { C.UNCOMMON, C.UNCOMMON }, { C.RACK_AURA }),
		cast(3, DAY + 1, WESTFALL, { C.UNCOMMON, C.UNCOMMON }, { C.RACK_AURA }),
	})
end

-- Hunts logged in over `history`, its OnInitialize replaced by what the backend's driver does: register, then
-- ns.BindProjections. `prepare(loaded)` runs first, before Hunts' ADDON_LOADED.
---@param prepare fun(loaded: LoadedAddon)?
---@return PagleProjection bound
---@return PagleHuntsNS ns
local function boundByBackend(prepare)
	local bound
	local loaded = login(history, {
		prepare = function(loaded)
			if prepare then
				prepare(loaded)
			end
			local ns = loaded.ns
			ns.Hunts.OnInitialize = function()
				local fake = loaded.env.Pagle
				bound = ns.BindProjections(fake.RegisterModule(ns.ModuleDef(function() end)))
			end
		end,
	})
	return bound, loaded.ns
end

describe("Hunts' projection for the backend (#223)", function()
	it("folds the Hunts to the state the client's projection holds", function()
		local client = login(history)
		local bound = boundByBackend()

		assert.are.same(client.ns.State(), bound:GetState())
	end)

	it("gives the lifetime Coins earned: 30 per completion, 15 per further tier, 100 per title (HNT-R110)", function()
		local bound, ns = boundByBackend()

		assert.are.equal(3 * 30 + 15 + 100, ns.CoinsEarned(bound:GetState() --[[@as HuntsState]]))
	end)

	it("counts a title a retirement completed by the server time, as the client's done does (HNT-R23)", function()
		-- From 2026-06-01, fixture_dusk's only Hunt is fixture_snapper, which is done: its title a second time is no
		-- new title, so only fixture_hefty_blackmouth's retirement can change the set.
		local function retire(loaded)
			loaded.ns.huntList.hunts[4].retired = JUNE_1
		end
		local client = login(history, { prepare = retire })
		local bound = boundByBackend(retire)

		assert.are.same(client.ns.State(), bound:GetState())
		assert.is_true(bound:GetState().sets.fixture_dusk.fromRetirement)
	end)
end)
