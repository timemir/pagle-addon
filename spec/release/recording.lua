-- Run by scripts/package.sh against the unpacked committed release, never against development sources.
---@diagnostic disable-next-line: undefined-global -- this release check runs in busted on stock Lua 5.1
local addonRoot = assert(os.getenv("PAGLE_RELEASE_ADDONS"), "set PAGLE_RELEASE_ADDONS to an unpacked release")

local function release()
	local log = savedLog({ BUILD_ENTRY })
	log.test = true -- even a locally changed test flag must not enable release recording commands
	return enterWorld(
		loadAddon("Pagle", foreverWith({ PagleLog = log }), {
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
		local before = { unpack(loaded.env.PagleLog.entries) }

		loaded.env.SlashCmdList.PAGLE("dev catch 6358")
		loaded.env.SlashCmdList.PAGLE("dev catch 6358 453")
		loaded.env.SlashCmdList.PAGLE("DEV CATCH 6303")

		assert.are.same(before, loaded.env.PagleLog.entries)
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
		local before = { unpack(loaded.env.PagleLog.entries) }

		loaded.env.SlashCmdList.PAGLE("dev content")

		assert.matches("Pagle dev: pushed content is missing:", loaded.printed[2], 1, true)
		assert.are.same(before, loaded.env.PagleLog.entries)
		assert.are.same({}, loaded.client.errors)
	end)
end)
