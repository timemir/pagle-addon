-- The combat hold, Cozy mode and expiry on the client, through the real TOC (announcements.md › Combat hold, › Cozy
-- mode, › Expiry; core/README.md CORE-R51): what a restriction holds and shows after, what Cozy mode silences and
-- counts on the compartment entry, and moments that expire before they show.

local OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"
local FISHING = 7731
local SOUNDS = "Interface\\AddOns\\Pagle\\media\\sounds\\"

-- The build entry the fake client's build matches, so login appends no B1.
local BUILD = ("B1|1|%d|0|70338|1.60.1"):format(SERVER_TIME - 5000)

-- Ada's caught Cast of one Oily Blackmouth at server time `time`.
local function cast(time)
	return ("C1|1|%d|0|c|494|1439|1|148|453|86|25|263|||6358x1"):format(time)
end

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
local function loadCore(saved)
	local clock
	local loaded = loadAddon(
		"Pagle",
		foreverWith({
			PagleLog = savedLog({ cast(SERVER_TIME - 90000), cast(SERVER_TIME - 89990), BUILD }),
			PagleDB = saved,
			GetServerTime = function()
				return SERVER_TIME + math.floor(clock and clock() or 0)
			end,
		})
	)
	clock = loaded.client.time
	loaded.client.addons.Pagle_Ledger = { metadata = { ["X-Pagle-API"] = "1" } }
	local M = loaded.env.Pagle.RegisterModule({ name = "Ledger", title = "Ledger", order = 10 })
	loaded.client.fire("PLAYER_LOGIN")
	loaded.client.fire("PLAYER_ENTERING_WORLD", true, false)
	for _ = 1, 3 do
		loaded.client.advance(0)
	end
	return loaded, M
end

-- Raises each moment, then runs the next frame, where Core flushes them (ANN-R10, ANN-R12).
local function raise(loaded, M, ...)
	for i = 1, select("#", ...) do
		M:RaiseMoment((select(i, ...)))
	end
	loaded.client.advance(0)
end

-- The title on the frame for `form` if it is on screen, else nil.
local function showing(loaded, form)
	local frame = loaded.ns.announcementFrames[form]
	return frame and frame.shown and frame.title:GetText() or nil
end

-- The title of the card on screen, or nil.
local function card(loaded)
	local frame = loaded.ns.cardFrame
	return frame and frame.shown and frame.title:GetText() or nil
end

-- Plays a caught Cast of one Oily Blackmouth on the fake client, then lets the next frame flush its moments.
local function catchOne(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-1", FISHING)
	loaded.client.loot = { fishing = true, slots = { { link = OILY_BLACKMOUTH, quantity = 1 } } }
	loaded.client.fire("LOOT_READY", true)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-1", FISHING)
	loaded.client.fire("LOOT_CLOSED")
	loaded.client.advance(0)
end

describe("the combat hold", function()
	it(
		"hides the toast and card on screen in combat, then shows the held banner, one While you were fighting toast"
			.. " with both held toast headlines, and the card again (ANN-R35, ANN-R36, ANN-R55, ANN-R93)",
		function()
			local loaded, M = loadCore({ global = { cards = { storedCard() } } })
			assert.are.equal("Fishing session", card(loaded))
			raise(loaded, M, { rung = "toast", kind = "spec", title = "New Species", text = "Nightfin Snapper" })
			assert.are.equal("New Species", showing(loaded, "toast"))

			setCombat(loaded, true)
			assert.is_nil(showing(loaded, "toast"))
			assert.is_nil(card(loaded))
			loaded.client.sounds = {}
			raise(loaded, M, { rung = "banner", kind = "spec", title = "Level 12" })
			raise(loaded, M, { rung = "toast.low", kind = "spec", title = "Size record" })
			loaded.client.advance(30)
			assert.are.same({}, loaded.client.sounds)

			setCombat(loaded, false)
			loaded.client.advance(1.9)
			assert.is_nil(showing(loaded, "banner"))
			loaded.client.advance(0.1)
			assert.are.equal("Level 12", showing(loaded, "banner"))
			assert.is_nil(card(loaded))
			loaded.client.advance(4)
			local toast = loaded.ns.announcementFrames.toast
			assert.are.same(
				{ "While you were fighting", "New Species: Nightfin Snapper\nSize record" },
				{ showing(loaded, "toast"), toast.text:GetText() }
			)
			assert.is_nil(card(loaded))
			loaded.client.advance(6)

			assert.are.equal("Fishing session", card(loaded))
			assert.are.same(
				{ SOUNDS .. "driftwood\\banner.ogg SFX", SOUNDS .. "driftwood\\toast_2.ogg SFX" },
				loaded.client.sounds
			)
		end
	)

	it(
		"restarts the 2 s wait when a restriction starts inside it, and never shows a held Nod (ANN-R35, ANN-R36)",
		function()
			local loaded, M = loadCore()
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

			assert.are.equal("While you were fighting", showing(loaded, "toast"))
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

describe("Cozy mode", function()
	it(
		"shows no toast or banner and plays nothing, shows a splash silently, and counts both on the compartment"
			.. " entry until the summary card shows (ANN-R40–R42, CORE-R51)",
		function()
			local loaded, M = loadCore()
			loaded.ns.db.profile.announcements.cozy = true
			catchOne(loaded)

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
			loaded.client.advance(900)

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
			local loaded, M = loadCore()
			catchOne(loaded)
			raise(loaded, M, { rung = "toast", kind = "spec", title = "Toast" })
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
			loaded.client.advance(6)
			assert.are.equal("New Species", showing(loaded, "toast"))
			loaded.client.advance(6)
			assert.is_nil(showing(loaded, "banner"))
			loaded.client.advance(900)

			local rows = {}
			for _, row in ipairs(loaded.ns.cardFrame.rows) do
				if row.shown then
					rows[#rows + 1] = row.text:GetText()
				end
			end
			assert.are.same({ "Ledger", "Window banner", "Window opened 21:00–06:00", "Toast", "New Species" }, rows)
		end
	)
end)
