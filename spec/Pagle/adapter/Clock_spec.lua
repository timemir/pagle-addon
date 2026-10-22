-- Pagle.FormatClock on the client (CORE-R87): a time of day in the clock format, PagleDB.profile.clockFormat, or by
-- default the game's clock (the CVar timeMgrUseMilitaryTime); the Settings root's Clock row (SET-R10); and
-- ClockFormatChanged, when the format a time was written in changes.

-- Core logged in on the fake client, with its Settings registered, its game clock's CVar `military` ("0", "1", or
-- nil for a client without it).
local function core(military)
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	loaded.client.cvars.timeMgrUseMilitaryTime = military
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The Units section's Clock row, after the Length unit: the root's last row but the Pagle menu section's two
-- (spec/Pagle/adapter/MinimapIcon_spec.lua) and the Pagle website section's two
-- (spec/Pagle/adapter/AnglersInGame_spec.lua); the Length unit's row before it; and the root.
local function clockRow(loaded)
	local root = loaded.client.settings.category("Pagle")
	local initializers = root.layout.initializers
	local n = #initializers - 4
	return initializers[n], initializers[n - 1], root
end

-- Every ClockFormatChanged's format, in order, from now on.
local function heard(loaded)
	local formats = {}
	loaded.env.Pagle.RegisterCallback("spec", "ClockFormatChanged", function(_, format)
		formats[#formats + 1] = format
	end)
	return formats
end

describe("Pagle.FormatClock", function()
	it(
		"writes 18:30 in the stored 24-hour and 6:30 pm in the stored 12-hour, whatever the game's (CORE-R87)",
		function()
			local loaded = core("0")
			local profile = loaded.ns.db.profile

			profile.clockFormat = "24h"
			local twentyFour = loaded.env.Pagle.FormatClock(18, 30)
			profile.clockFormat = "12h"

			assert.are.same({ "18:30", "6:30 pm" }, { twentyFour, loaded.env.Pagle.FormatClock(18, 30) })
		end
	)

	it(
		"follows the game's clock with none stored: 12-hour when its 24-hour mode is off, else 24-hour, as Pagle"
			.. " wrote before (CORE-R87)",
		function()
			local read = {}
			for i, military in ipairs({ "0", "1", false }) do
				local loaded = core(military or nil)
				assert.is_nil(loaded.ns.db.profile.clockFormat)
				read[i] = loaded.env.Pagle.FormatClock(0, 5)
			end

			assert.are.same({ "12:05 am", "00:05", "00:05" }, read)
		end
	)
end)

describe("ClockFormatChanged", function()
	it("fires when the game's clock changes while Pagle follows it, after a time was written (CORE-R87)", function()
		local loaded = core("1")
		local formats = heard(loaded)
		loaded.env.Pagle.FormatClock(8, 15)

		loaded.env.SetCVar("timeMgrUseMilitaryTime", "0") -- CVAR_UPDATE, as the minimap clock's checkbox does
		loaded.env.SetCVar("ActionButtonUseKeyDown", "0") -- another CVar: the format is the same
		loaded.env.Pagle.FormatClock(8, 15)
		loaded.env.SetCVar("timeMgrUseMilitaryTime", "1")

		assert.are.same({ "12h", "24h" }, formats)
	end)

	it("doesn't fire for the game's clock while a format is stored, nor before any time is written", function()
		local loaded = core("1")
		local formats = heard(loaded)

		loaded.env.SetCVar("timeMgrUseMilitaryTime", "0") -- nothing written yet: nothing to redraw
		loaded.ns.db.profile.clockFormat = "12h"
		loaded.env.Pagle.FormatClock(8, 15)
		loaded.env.SetCVar("timeMgrUseMilitaryTime", "1")

		assert.are.same({}, formats)
	end)
end)

describe("The root's Clock row", function()
	it("shows the Clock dropdown under Units, after the Length unit, with its tooltip and choices (SET-R10)", function()
		local row, lengthUnit = clockRow(core("1"))

		assert.are.equal("Length unit", lengthUnit:GetName())
		assert.are.same({ "Clock", "SettingsDropdownControlTemplate" }, { row:GetName(), row.template })
		assert.are.equal(
			"How Pagle writes a time of day, such as the realm time at the top of the Hunts board. Following the game"
				.. " uses the minimap clock's 24-hour mode.",
			row.data.tooltip
		)
		local options = {}
		for i, option in ipairs(row.data.options()) do
			options[i] = option.value .. " " .. option.label
		end
		assert.are.same({
			"game Follow the game's clock",
			"24h 24-hour (18:30)",
			"12h 12-hour (6:30 pm)",
		}, options)
	end)

	it("defaults to following the game's clock, and shows it while none is stored (SET-R10, CORE-R87)", function()
		local setting = clockRow(core("0")):GetSetting()

		assert.are.same({ "game", "game" }, { setting:GetDefaultValue(), setting:GetValue() })
	end)

	it(
		"stores a pick in PagleDB.profile.clockFormat, Pagle.FormatClock and ClockFormatChanged with it, and the game's"
			.. " clock as none (SET-R10, CORE-R87)",
		function()
			local loaded = core("1")
			local row = clockRow(loaded)
			local formats = heard(loaded)
			local profile = loaded.env.PagleDB.profiles.Default
			loaded.env.Pagle.FormatClock(18, 30) -- a book drew its clock

			row:GetSetting():SetValue("12h")
			local twelve = { profile.clockFormat, loaded.env.Pagle.FormatClock(18, 30) }
			row:GetSetting():SetValue("24h")
			local twentyFour = { profile.clockFormat, loaded.env.Pagle.FormatClock(18, 30) }
			row:GetSetting():SetValue("game")

			assert.are.same({ "12h", "6:30 pm" }, twelve)
			assert.are.same({ "24h", "18:30" }, twentyFour)
			assert.are.same({ "game", "18:30" }, { row:GetSetting():GetValue(), loaded.env.Pagle.FormatClock(18, 30) })
			assert.is_nil(profile.clockFormat)
			assert.are.same({ "12h", "24h" }, formats) -- the game's clock is 24-hour too: no change to tell
		end
	)

	it("goes back to following the game's clock with the root's Defaults button (SET-R13, SET-R60)", function()
		local loaded = core("1")
		local row, _, root = clockRow(loaded)
		row:GetSetting():SetValue("12h")

		loaded.client.settings.defaults(root) -- the page's Defaults button (SET-R60)

		assert.is_nil(loaded.env.PagleDB.profiles.Default.clockFormat)
		assert.are.same({ "game", "18:30" }, { row:GetSetting():GetValue(), loaded.env.Pagle.FormatClock(18, 30) })
	end)
end)
