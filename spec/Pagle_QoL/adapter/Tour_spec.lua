-- QoL's tour stop with Core (CORE-R65, CORE-R68): the Fishing page, where QoL's rows are, opened through
-- Pagle.OpenSettings and closed after its screenshot.

-- Types `/pagle <msg>` in chat.
local function pagle(loaded, msg)
	loaded.env.SlashCmdList.PAGLE(msg)
end

-- QoL and Core loaded and logged in, with dev on and the chat read.
local function loggedIn()
	local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	pagle(loaded, "dev on")
	for i = #loaded.printed, 1, -1 do
		loaded.printed[i] = nil
	end
	return loaded
end

describe("QoL's tour stop (CORE-R65, CORE-R68)", function()
	it("is the Fishing page with QoL's rows", function()
		local loaded = loggedIn()

		pagle(loaded, "dev tour list qol")

		assert.are.same({
			"Pagle dev: 1 tour stop:",
			"  qol.settings: QoL's rows on the Fishing page",
		}, loaded.printed)
	end)

	it("opens the Fishing page for its screenshot and closes the panel after (QOL-R2, SET-R12)", function()
		local loaded = loggedIn()
		local panel = loaded.client.settings.panel
		local shownAtShot
		loaded.env.Screenshot = function()
			shownAtShot = panel.shown
		end

		pagle(loaded, "dev tour qol")
		loaded.client.advance(60)

		assert.are.same({ "Fishing" }, openedNames(loaded))
		assert.is_true(shownAtShot)
		assert.is_false(panel.shown)
	end)
end)
