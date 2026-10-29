-- Run by scripts/package.sh against the unpacked committed release, never against development sources.
---@diagnostic disable-next-line: undefined-global -- this release check runs in busted on stock Lua 5.1
local addonRoot = assert(os.getenv("PAGLE_RELEASE_ADDONS"), "set PAGLE_RELEASE_ADDONS to an unpacked release")

local function release(saved)
	local log = savedLog({ BUILD_ENTRY })
	log.test = true -- even a locally changed test flag must not enable release recording commands
	return enterWorld(
		loadAddon("Pagle", foreverWith({ PagleLog = log, PagleDB = saved }), {
			addonRoot = addonRoot,
			also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_Stats", "Pagle_TackleBoard", "Pagle_QoL" },
		}),
		3
	)
end

describe("the packaged release", function()
	it("cannot synthesize Catches through slash commands, even on a test log with dev mode on", function()
		local loaded = release()
		loaded.env.SlashCmdList.PAGLE("dev on")
		local before = { unpack(logEntries(loaded.env.PagleLog)) }

		loaded.env.SlashCmdList.PAGLE("dev catch 6358")
		loaded.env.SlashCmdList.PAGLE("dev catch 6358 453")
		loaded.env.SlashCmdList.PAGLE("DEV CATCH 6303")

		assert.are.same(before, logEntries(loaded.env.PagleLog))
	end)

	it("starts every shipped Module and records genuine fishing signals", function()
		local loaded = release()
		local seen = {}
		loaded.env.Pagle.RegisterCallback(seen, "Catch", function(_, caught)
			seen[#seen + 1] = caught.itemID
		end)

		catchOne(loaded)
		loaded.client.advance(0)

		assert.are.same({ 6358 }, seen)
		local catches = {}
		for record in loaded.env.Pagle.IterateCatches() do
			if record.kind == "cast" then
				catches[#catches + 1] = record.items[1].itemID
			end
		end
		assert.are.same({ 6358 }, catches)
		assert.are.same({}, loaded.client.errors)
	end)

	it("retains pushed-content diagnostics without changing the Catch log", function()
		local loaded = release()
		loaded.env.SlashCmdList.PAGLE("dev on")
		local before = { unpack(logEntries(loaded.env.PagleLog)) }

		loaded.env.SlashCmdList.PAGLE("dev content")

		assert.matches("Pagle dev: pushed content is missing:", loaded.printed[2], 1, true)
		assert.are.same(before, logEntries(loaded.env.PagleLog))
		assert.are.same({}, loaded.client.errors)
	end)

	-- The fake client's Fishing reads 75/150 with no modifier (spec/support/client.lua).
	local CLIENT_SKILL = { 75, 150 }

	local function conditionsSkill(loaded)
		local conditions = loaded.env.Pagle.GetConditions()
		return { conditions.skillRank, conditions.skillMod }
	end

	local function skillReading(loaded)
		local angler = loaded.env.Pagle.GetAngler()
		local latest = angler.skill[angler.current]
		return { latest.rank, latest.max }
	end

	it("cannot override Fishing skill with /pagle dev skill, even with dev mode on (#465)", function()
		local loaded = release()
		loaded.env.SlashCmdList.PAGLE("dev on")
		local before = { unpack(logEntries(loaded.env.PagleLog)) }
		local printed = #loaded.printed

		loaded.env.SlashCmdList.PAGLE("dev skill 1")
		loaded.env.SlashCmdList.PAGLE("dev skill 40 300")
		loaded.env.SlashCmdList.PAGLE("dev skill off")
		loaded.env.SlashCmdList.PAGLE("DEV SKILL")

		-- The unknown-subcommand usage line, four times, and nothing that names the skill command or its override.
		assert.are.equal(printed + 4, #loaded.printed)
		for i = printed + 1, #loaded.printed do
			assert.are.equal(loaded.printed[printed + 1], loaded.printed[i])
			assert.is_nil(loaded.printed[i]:find("skill", 1, true))
		end
		assert.is_nil(loaded.env.PagleDB.global.devSkill)
		assert.are.same(CLIENT_SKILL, skillReading(loaded))
		assert.are.same({ 75, 0 }, conditionsSkill(loaded))
		assert.are.same(before, logEntries(loaded.env.PagleLog))
		assert.are.same({}, loaded.client.errors)
	end)

	it(
		"reads Fishing skill as the client says, whatever a saved devSkill holds, and says nothing at login (#465)",
		function()
			local loaded = release({ global = { dev = true, devSkill = { rank = 1, max = 300 } } })
			loaded.client.advance(0)

			assert.are.same(CLIENT_SKILL, skillReading(loaded))
			assert.are.same({ 75, 0 }, conditionsSkill(loaded))
			assert.are.same({}, loaded.printed)
			catchOne(loaded)
			loaded.client.advance(0)
			local cast
			for record in loaded.env.Pagle.IterateCatches() do
				cast = record
			end
			assert.are.equal(75, cast.conditions.skillRank)
			for _, entry in ipairs(loaded.env.PagleDB.global.diagnostics) do
				assert.is_nil(entry.devSkill)
			end
			assert.are.same({}, loaded.client.errors)
		end
	)

	it("leaves a saved devSkill alone when dev mode goes off, since nothing in the release reads it (#465)", function()
		local loaded = release({ global = { dev = true, devSkill = { rank = 1, max = 300 } } })

		loaded.env.SlashCmdList.PAGLE("dev off")

		assert.are.same({ "Pagle dev: dev commands are off." }, loaded.printed)
		assert.are.same({}, loaded.client.errors)
	end)
end)
