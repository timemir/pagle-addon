-- The combat hold, Cozy mode and expiry on the client, through the real TOC (announcements.md › Combat hold, › Cozy
-- mode, › Expiry; core/README.md CORE-R51): what a restriction holds and shows after, what Cozy mode silences and
-- counts on the compartment entry, and moments that expire before they show.

local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"

-- A stored summary card for PagleDB.global.cards, titled "Fishing session".
local function storedCard()
	return {
		title = "Fishing session",
		numbers = { casts = 2, catches = 2, gotAway = 0, seconds = 600 },
		coins = 0,
		lines = {},
		moments = {},
	}
end

-- Core logged in on Forever over a log of two old Casts and PagleDB `saved`, if given, its server time SERVER_TIME
-- plus the client's clock, with the Ledger registered and every login frame run. Returns the Ledger's handle too.
local function loggedIn(saved)
	local loaded = loadCore(history(2), saved)
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	enterWorld(loaded, 3)
	return loaded, M
end

-- Raises each moment, then runs the next frame, where Core flushes them (ANN-R10, ANN-R12).
local function raise(loaded, M, ...)
	for i = 1, select("#", ...) do
		M:RaiseMoment((select(i, ...)))
	end
	loaded.client.advance(0)
end

-- The headline's title of what the frame for `form` shows, if it is on screen, else nil. Read from the display, not
-- the drawn words, which the art may set in capitals.
local function showing(loaded, form)
	local frame = loaded.ns.announcementFrames[form]
	return frame and frame.display and frame.display.announcement.headline.title or nil
end

-- What "While you were fighting" lists: each row's title and text, as "TITLE: text".
local function fightingRows(toast)
	local rows = {}
	for _, row in ipairs(toast.rows) do
		if row.shown then
			rows[#rows + 1] = row.what:GetText() .. ": " .. row.name:GetText()
		end
	end
	return rows
end

-- The title of the card on screen, or nil.
local function card(loaded)
	local frame = loaded.ns.cardFrame
	return frame and frame.shown and frame.title:GetText() or nil
end

describe("the combat hold", function()
	it(
		"hides the toast and card on screen in combat, then shows the held banner together with one While you were"
			.. " fighting toast with the three held toast headlines, only the banner's sound playing, and the card again"
			.. " (ANN-R24, ANN-R35, ANN-R36, ANN-R55, ANN-R93)",
		function()
			local loaded, M = loggedIn({ global = { cards = { storedCard() } } })
			assert.are.equal("Fishing session", card(loaded))
			raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species", text = "Nightfin Snapper" })
			assert.are.equal("New Species", showing(loaded, "toast"))

			setCombat(loaded, true)
			assert.is_nil(showing(loaded, "toast"))
			assert.is_nil(card(loaded))
			loaded.client.sounds = {}
			raise(loaded, M, { rung = "banner", kind = "spec", title = "Level 12" })
			raise(loaded, M, { rung = "toast.low", kind = "spec", title = "Size record" })
			raise(loaded, M, { rung = "toast.high", kind = "spec", title = "Hunt completed" })
			loaded.client.advance(30)
			assert.are.same({}, loaded.client.sounds)

			setCombat(loaded, false)
			loaded.client.advance(1.9)
			assert.is_nil(showing(loaded, "banner"))
			loaded.client.advance(0.1)
			assert.are.equal("Level 12", showing(loaded, "banner"))
			local toast = loaded.ns.announcementFrames.toast
			assert.are.same({
				"While you were fighting",
				{ "NEW SPECIES: Nightfin Snapper", "SIZE RECORD: ", "HUNT COMPLETED: " },
			}, { showing(loaded, "toast"), fightingRows(toast) })
			assert.is_nil(card(loaded))
			loaded.client.advance(5.9) -- the banner's stay
			assert.are.same({ nil, "While you were fighting" }, { showing(loaded, "banner"), showing(loaded, "toast") })
			assert.is_nil(card(loaded))
			loaded.client.advance(10.7 - 5.9 + 0.01) -- the rest of the digest's

			assert.are.equal("Fishing session", card(loaded))
			assert.are.same({ SOUNDS .. "driftwood\\banner.ogg SFX" }, loaded.client.sounds)
		end
	)

	it(
		"restarts the 2 s wait when a restriction starts inside it, shows a lone held toast as itself, and never shows a"
			.. " held Nod (ANN-R35, ANN-R36)",
		function()
			local loaded, M = loggedIn()
			raise(loaded, M, { rung = "nod", kind = "spec", title = "New here" })
			setCombat(loaded, true)
			assert.is_nil(showing(loaded, "nod"))
			raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species" })
			setCombat(loaded, false)
			loaded.client.advance(1.5)

			setCombat(loaded, true)
			setCombat(loaded, false)
			loaded.client.advance(1.9)
			assert.is_nil(showing(loaded, "toast"))
			loaded.client.advance(0.1)

			assert.are.equal("New Species", showing(loaded, "toast"))
			loaded.client.advance(60)
			assert.is_nil(showing(loaded, "nod"))
		end
	)

	it("starts held after a load in combat (ANN-R35)", function()
		local loaded = loadAddon(
			"Pagle",
			foreverWith({
				PagleLog = savedLog(),
				InCombatLockdown = function()
					return true
				end,
			})
		)
		loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
		local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)

		raise(loaded, M, { rung = "banner", kind = "spec", title = "Level 12" })
		assert.is_nil(showing(loaded, "banner"))
		setCombat(loaded, false)
		loaded.client.advance(2)

		assert.are.equal("Level 12", showing(loaded, "banner"))
	end)
end)

describe("the guide's hold", function()
	it(
		"hides the toast and card on screen while the guide holds, then shows the held toasts as themselves at once,"
			.. " never the held Nod, and the card again (ANN-R35, ANN-R38, ONB-R70)",
		function()
			local loaded, M = loggedIn({ global = { cards = { storedCard() } } })
			raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species" })

			loaded.ns.HoldAnnouncements("guide")
			assert.are.same({ nil, nil }, { showing(loaded, "toast"), card(loaded) })
			raise(loaded, M, { rung = "nod", kind = "spec", title = "New here" })
			raise(loaded, M, { rung = "toast.low", kind = "spec", title = "Size record" })
			loaded.client.advance(30)
			assert.is_nil(showing(loaded, "nod"))

			loaded.ns.ReleaseAnnouncements("guide")

			local titles = {}
			for _, frame in ipairs(loaded.ns.columnFrames) do
				titles[#titles + 1] = frame.display.announcement.headline.title
			end
			table.sort(titles)
			assert.are.same({ "New Species", "Size record" }, titles)
			assert.is_nil(card(loaded))
			loaded.client.advance(60)
			assert.is_nil(showing(loaded, "nod"))
			assert.are.equal("Fishing session", card(loaded))
		end
	)

	it(
		"stays held through combat when the guide closes for a restriction, then shows by combat's rules (ANN-R36,"
			.. " ANN-R38, ONB-R25)",
		function()
			local loaded, M = loggedIn()
			loaded.ns.HoldAnnouncements("guide")
			raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species" })
			setCombat(loaded, true)
			loaded.ns.ReleaseAnnouncements("guide")
			raise(loaded, M, { rung = "toast.low", kind = "spec", title = "Size record" })
			raise(loaded, M, { rung = "toast.high", kind = "spec", title = "Hunt completed" })
			loaded.client.advance(30)
			assert.is_nil(showing(loaded, "toast"))

			setCombat(loaded, false)
			loaded.client.advance(2)

			assert.are.equal("While you were fighting", showing(loaded, "toast"))
		end
	)
end)

describe("Cozy mode", function()
	it(
		"shows no toast or banner and plays nothing, shows a splash silently, and counts both on the compartment"
			.. " entry until the summary card shows (ANN-R40–R42, CORE-R51)",
		function()
			local loaded, M = loggedIn()
			loaded.ns.db.profile.announcements.cozy = true
			catchAndFlush(loaded)

			raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species" })
			raise(loaded, M, { rung = "banner", kind = "spec", title = "Level 12" })
			assert.is_nil(showing(loaded, "toast"))
			assert.is_nil(showing(loaded, "banner"))
			assert.are.equal("Pagle · 2 waiting", loaded.client.compartment[1].text)
			raise(loaded, M, { rung = "splash", kind = "spec", title = "Legend" })
			assert.are.equal("Legend", showing(loaded, "splash"))
			assert.are.same({}, loaded.client.sounds)
			loaded.client.advance(8)
			loaded.ns.db.profile.announcements.cozy = false
			assert.are.equal("Pagle · 3 waiting", loaded.client.compartment[1].text)
			loaded.client.advance(300)

			assert.are.equal("Fishing session", card(loaded))
			assert.are.equal("Pagle", loaded.client.compartment[1].text)
			assert.is_nil(showing(loaded, "toast"))
		end
	)
end)

describe("expiry", function()
	it(
		"gives an expired headline's place to the next-ranked moment, shows nothing with none left, and shows its"
			.. " pastText on the summary card (ANN-R45)",
		function()
			local loaded, M = loggedIn()
			catchAndFlush(loaded)
			-- Three toasts fill the column, so what comes next waits until they leave.
			for i = 1, 3 do
				raise(loaded, M, { rung = "toast", kind = "spec", title = "Toast " .. i })
			end
			local id = PLAYER_GUID .. "-" .. SERVER_TIME .. "-0"
			raise(loaded, M, {
				rung = "toast.high",
				kind = "window",
				title = "Window open",
				cast = id,
				expiresAt = SERVER_TIME + 3,
				pastText = "Window opened 21:00–06:00",
			}, { rung = "toast", kind = "spec", title = "New Species", cast = id })
			raise(loaded, M, { rung = "banner", kind = "window", title = "Window banner", expiresAt = SERVER_TIME + 3 })
			loaded.client.advance(8.7) -- the three settle, stay their 6 s and leave
			assert.are.equal("New Species", showing(loaded, "toast"))
			loaded.client.advance(9)
			assert.is_nil(showing(loaded, "banner"))
			loaded.client.advance(300)

			local rows = {}
			for _, row in ipairs(loaded.ns.cardFrame.rows) do
				if row.shown then
					rows[#rows + 1] = row.text:GetText()
				end
			end
			assert.are.same({
				"Ledger",
				"Window banner",
				"Window opened 21:00–06:00",
				"Toast 1",
				"Toast 2",
				"Toast 3",
				"New Species",
			}, rows)
		end
	)
end)
