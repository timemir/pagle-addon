-- The whole `/pagle dev tour` on the package as shipped (CORE-R65–R68): Core and every roster Module loaded on the
-- fake client, for a new Angler, every stop shown and hidden in turn. Each Module's own tour specs check its stops on
-- FakePagle; this one checks that the tour as a whole writes nothing of the onboarding state (CORE-R68, #349).

-- The roster Modules' folders, in CORE-R1 order.
local ROSTER = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" }

-- A deep copy of `value`.
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, field in pairs(value) do
		result[key] = copy(field)
	end
	return result
end

-- The whole package for a new Angler (no Catch log, so `letter = "waiting"`, ONB-R2), in the world and settled, with
-- dev on and the chat read.
---@return LoadedAddon
local function package()
	local loaded = enterWorld(loadAddon("Pagle", foreverWith(), { also = ROSTER }), 3)
	loaded.env.SlashCmdList.PAGLE("dev on")
	loaded.client.advance(30)
	for i = #loaded.printed, 1, -1 do
		loaded.printed[i] = nil
	end
	return loaded
end

describe("The whole dev tour, every Module loaded (CORE-R66, CORE-R68)", function()
	it("leaves a new Angler's onboarding state as it was: no item ticked, no look or note seen (#349)", function()
		local loaded = package()
		local core = loaded.namespaces.Pagle
		local onboarding = loaded.env.PagleDB.global.onboarding
		assert.are.equal("waiting", onboarding.letter)
		local before = copy(onboarding)

		loaded.env.SlashCmdList.PAGLE("dev tour")
		local count = #core.tourStops:List(core.Modules:Modules())
		for _ = 1, count * 4 do
			loaded.client.advance(1)
		end

		assert.is_false(core.tour:IsRunning())
		assert(count > 40, "the tour ran " .. count .. " stops")
		assert.are.equal(count, loaded.client.screenshots)
		assert.are.same(before, loaded.env.PagleDB.global.onboarding)
	end)
end)
