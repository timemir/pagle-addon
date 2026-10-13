-- The unsaved-Casts reminder and the root's Saving section, driven through the fake client: Casts from the client's
-- fishing signals, combat from PLAYER_REGEN_*, the option from its checkbox on the Settings root (catch-log.md
-- LOG-R85, LOG-R86; settings.md SET-R10 row 5, SET-R13).

local FISHING = 7731 -- Fishing (Classic Journeyman), on the catalogue's fishing-spell list
local OILY_BLACKMOUTH = "|cffffffff|Hitem:6358::::::::15:::::::::|h[Oily Blackmouth]|h|r"

local LABEL = "Remind me to /reload when Casts are unsaved"
local TOOLTIP = "A chat line every 50 Casts not yet saved. WoW saves only on /reload or logout, so a crash loses them."

-- Core, logged in on the fake client, with its Settings registered.
local function core()
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The reminder's checkbox row on the root, and the root.
local function reminderRow(loaded)
	local root = loaded.client.settings.category("Pagle")
	for _, initializer in ipairs(root.layout.initializers) do
		if initializer:GetName() == LABEL then
			return initializer, root
		end
	end
	error("no reminder row on the root")
end

-- Ticks the reminder's checkbox, as the panel does.
local function turnOn(loaded)
	reminderRow(loaded):GetSetting():SetValue(true)
end

-- Presses a page's Defaults button: every setting registered on it goes back to its default (SET-R60).
local function pressDefaults(loaded, category)
	for _, setting in pairs(loaded.client.settings.variables) do
		if setting.category == category then
			setting:SetValue(setting:GetDefaultValue())
		end
	end
end

local function channel(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_START", "player", "Cast-3-4618-1-1-7731-000000AAAA", FISHING)
end

local function stop(loaded)
	loaded.client.fire("UNIT_SPELLCAST_CHANNEL_STOP", "player", "Cast-3-4618-1-1-7731-000000AAAA", FISHING)
end

-- `n` caught Casts, each with auto-loot on (LOG-R3).
local function catch(loaded, n)
	for _ = 1, n do
		channel(loaded)
		loaded.client.loot = { fishing = true, slots = { { link = OILY_BLACKMOUTH, quantity = 1 } } }
		loaded.client.fire("LOOT_READY", true)
		stop(loaded)
		loaded.client.fire("LOOT_CLOSED")
		loaded.client.loot = { fishing = false, slots = {} }
	end
end

-- `n` got-away Casts (LOG-R6).
local function lose(loaded, n)
	for _ = 1, n do
		channel(loaded)
		loaded.client.fire("UI_ERROR_MESSAGE", 397, "Your fish got away!")
		stop(loaded)
	end
end

-- `n` interrupted Casts: the channel stops and nothing follows within the grace time (LOG-R7).
local function interrupt(loaded, n)
	for _ = 1, n do
		channel(loaded)
		stop(loaded)
		loaded.client.advance(5)
	end
end

-- The reminder lines printed, in order.
local function reminders(loaded)
	local lines = {}
	for _, line in ipairs(loaded.printed) do
		if line:find("not yet saved", 1, true) then
			lines[#lines + 1] = line
		end
	end
	return lines
end

describe("The root's Saving section", function()
	it("shows the reminder checkbox under a Saving header, after the note, with its tooltip (SET-R10)", function()
		local loaded = core()
		local row, root = reminderRow(loaded)
		local initializers = root.layout.initializers
		local header = initializers[#initializers - 1]

		assert.are.equal(row, initializers[#initializers])
		assert.are.equal("Saving", header:GetName())
		assert.are.equal("SettingsListSectionHeaderTemplate", header.template)
		assert.are.equal("SettingsCheckboxControlTemplate", row.template)
		assert.are.equal(TOOLTIP, row.data.tooltip)
	end)

	it("keeps the option in PagleDB.profile.reloadReminder, off by default (LOG-R86, SET-R10)", function()
		local loaded = core()
		local setting = reminderRow(loaded):GetSetting()

		assert.is_false(setting:GetDefaultValue())
		assert.is_false(setting:GetValue())
		assert.is_false(loaded.env.PagleDB.profiles.Default.reloadReminder or false)

		setting:SetValue(true)

		assert.is_true(loaded.env.PagleDB.profiles.Default.reloadReminder)
		assert.is_true(setting:GetValue())
	end)

	it("turns the reminder off with the root's Defaults button (SET-R13)", function()
		local loaded = core()
		turnOn(loaded)
		local row, root = reminderRow(loaded)

		pressDefaults(loaded, root)

		assert.is_false(row:GetSetting():GetValue())
	end)
end)

describe("The unsaved-Casts reminder", function()
	it("prints nothing while the option is off (LOG-R86)", function()
		local loaded = core()

		catch(loaded, 100)

		assert.are.same({}, reminders(loaded))
	end)

	it("prints one line at 50 and at 100 Casts recorded since load, caught or got away (LOG-R86)", function()
		local loaded = core()
		turnOn(loaded)

		catch(loaded, 30)
		lose(loaded, 19)
		assert.are.same({}, reminders(loaded))
		catch(loaded, 1)
		assert.are.same({ "Pagle: 50 Casts not yet saved. /reload to keep them safe." }, reminders(loaded))
		lose(loaded, 50)
		assert.are.same({
			"Pagle: 50 Casts not yet saved. /reload to keep them safe.",
			"Pagle: 100 Casts not yet saved. /reload to keep them safe.",
		}, reminders(loaded))
	end)

	it("doesn't count interrupted Casts, which record nothing (LOG-R7, LOG-R86)", function()
		local loaded = core()
		turnOn(loaded)

		catch(loaded, 49)
		interrupt(loaded, 10)
		assert.are.same({}, reminders(loaded))
		catch(loaded, 1)

		assert.are.same({ "Pagle: 50 Casts not yet saved. /reload to keep them safe." }, reminders(loaded))
	end)

	it("prints a line that falls due in combat once, when combat ends (LOG-R86, LOG-R93)", function()
		local loaded = core()
		turnOn(loaded)
		catch(loaded, 49)

		loaded.client.fire("PLAYER_REGEN_DISABLED")
		catch(loaded, 1)
		assert.are.same({}, reminders(loaded))
		loaded.client.fire("PLAYER_REGEN_ENABLED")
		loaded.client.fire("PLAYER_REGEN_DISABLED")
		loaded.client.fire("PLAYER_REGEN_ENABLED")

		assert.are.same({ "Pagle: 50 Casts not yet saved. /reload to keep them safe." }, reminders(loaded))
	end)

	it("counts from this load only: a /reload saves, so the count starts again (LOG-R85, LOG-R86)", function()
		local first = core()
		turnOn(first)
		catch(first, 40)

		-- The next load reads the SavedVariables the reload wrote.
		-- AceDB checks the stored profile key's length with the client's strlenutf8; the key is ASCII.
		local globals = { PagleLog = first.env.PagleLog, PagleDB = first.env.PagleDB, strlenutf8 = string.len }
		local second = loadAddon("Pagle", foreverWith(globals))
		second.client.fire("PLAYER_LOGIN")
		catch(second, 49)
		assert.are.same({}, reminders(second))
		catch(second, 1)

		assert.are.same({ "Pagle: 50 Casts not yet saved. /reload to keep them safe." }, reminders(second))
	end)
end)
