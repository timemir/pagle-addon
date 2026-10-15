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

-- Runs the tour of QoL's stops, calling `atShot(n)` at each stop's screenshot.
---@param loaded LoadedAddon
---@param atShot fun(n: integer)
local function tour(loaded, atShot)
	local n = 0
	loaded.env.Screenshot = function()
		n = n + 1
		atShot(n)
	end
	pagle(loaded, "dev tour qol")
	loaded.client.advance(60)
end

-- The frame named `name`'s shown state, or nil when there is none.
local function shownNamed(loaded, name)
	local frame = loaded.env[name]
	return frame and frame.shown
end

describe("QoL's tour stops (CORE-R65, CORE-R68)", function()
	it("are the Fishing page with QoL's rows, a sample Nudge and the two notes", function()
		local loaded = loggedIn()

		pagle(loaded, "dev tour list qol")

		assert.are.same({
			"Pagle dev: 3 tour stops:",
			"  qol.settings: QoL's rows on the Fishing page",
			"  qol.nudge: a sample swap-back Nudge",
			"  qol.notes: samples of the conflict note and the Reload now note",
		}, loaded.printed)
	end)

	it("show the swap-back Nudge with its key, and both notes, inert, then take them away (CORE-R68)", function()
		local loaded = loggedIn()
		local seen = {}

		tour(loaded, function(n)
			local nudge
			for _, frame in ipairs(loaded.client.frames) do
				if frame.message and frame.shown then
					nudge = frame.message
				end
			end
			seen[n] = {
				nudge = nudge,
				conflict = shownNamed(loaded, "PagleQoLConflictNotePreview"),
				reload = shownNamed(loaded, "PagleQoLReloadNotePreview"),
			}
		end)

		assert.are.same({ nudge = "Still holding your pole. Press G to swap back." }, seen[2])
		assert.are.same({ conflict = true, reload = true }, seen[3])
		assert.is_false(shownNamed(loaded, "PagleQoLConflictNotePreview"))
		assert.is_false(shownNamed(loaded, "PagleQoLReloadNotePreview"))
		for _, frame in ipairs(loaded.client.frames) do
			assert.is_falsy(frame.message and frame.shown)
		end
		-- Inert: a click on either choice of the samples turns nothing off and reloads nothing.
		loaded.ns.PreviewNotes(true)
		loaded.env.PagleQoLConflictNotePreview.primary:Click()
		loaded.env.PagleQoLReloadNotePreview.primary:Click()
		assert.are.same({}, loaded.client.disabledAddOns)
		assert.are.equal(0, loaded.client.reloads)
	end)

	it("opens the Fishing page for its screenshot and closes the panel after (QOL-R2, SET-R12)", function()
		local loaded = loggedIn()
		local panel = loaded.client.settings.panel
		local shownAtShot

		tour(loaded, function(n)
			if n == 1 then
				shownAtShot = panel.shown
			end
		end)

		assert.are.same({ "Fishing" }, openedNames(loaded))
		assert.is_true(shownAtShot)
		assert.is_false(panel.shown)
	end)
end)
