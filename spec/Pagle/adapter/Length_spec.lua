-- Pagle.FormatLength on the client (LOG-R69): a length in the Angler's length unit, PagleDB.profile.lengthUnit, or by
-- default the unit GetCurrentRegion() gives.

-- Core logged in on the fake client, with its Settings registered, whose GetCurrentRegion() returns `region` from
-- PagleDB's opening on (nil: the call doesn't exist).
local function core(region)
	local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
	loaded.env.GetCurrentRegion = region and function()
		return region
	end
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The root's last rows: the Saving section's reminder, then the Units section's header and Length unit row.
local function lastRows(loaded)
	local root = loaded.client.settings.category("Pagle")
	local initializers = root.layout.initializers
	local n = #initializers
	return initializers[n - 2], initializers[n - 1], initializers[n], root
end

-- Presses a page's Defaults button: every setting registered on it goes back to its default (SET-R60).
local function pressDefaults(loaded, category)
	for _, setting in pairs(loaded.client.settings.variables) do
		if setting.category == category then
			setting:SetValue(setting:GetDefaultValue())
		end
	end
end

describe("Pagle.FormatLength", function()
	it("reads 342 mm in the stored unit: 34.2 cm in centimetres, 13.5 in in inches (LOG-R69)", function()
		local loaded = core(1)
		local profile = loaded.ns.db.profile

		profile.lengthUnit = "cm"
		local cm = loaded.env.Pagle.FormatLength(342)
		profile.lengthUnit = "in"

		assert.are.same({ "34.2 cm", "13.5 in" }, { cm, loaded.env.Pagle.FormatLength(342) })
	end)

	it(
		"follows GetCurrentRegion() with no stored unit: 1 inches, 3 centimetres, missing centimetres (LOG-R69)",
		function()
			local read = {}
			for i, region in ipairs({ 1, 3, false }) do
				local loaded = core(region or nil)
				assert.is_nil(loaded.ns.db.profile.lengthUnit)
				read[i] = loaded.env.Pagle.FormatLength(342)
			end

			assert.are.same({ "13.5 in", "34.2 cm", "34.2 cm" }, read)
		end
	)
end)

describe("The root's Units section", function()
	it("shows the Length unit dropdown under a Units header right after Saving, with its tooltip (SET-R10)", function()
		local loaded = core(1)

		local reminder, header, row = lastRows(loaded)

		assert.are.equal("Remind me to /reload when Casts are unsaved", reminder:GetName())
		assert.are.same({ "Units", "SettingsListSectionHeaderTemplate" }, { header:GetName(), header.template })
		assert.are.same({ "Length unit", "SettingsDropdownControlTemplate" }, { row:GetName(), row.template })
		assert.are.equal(
			"How Pagle shows the length of your Catches. Records are kept in millimetres, so switching changes only what"
				.. " you see.",
			row.data.tooltip
		)
		local options = {}
		for i, option in ipairs(row.data.options()) do
			options[i] = option.value .. " " .. option.label
		end
		assert.are.same({ "cm Centimetres", "in Inches" }, options)
	end)

	it("defaults to the region's unit and shows the unit in use (SET-R10, LOG-R69)", function()
		local read = {}
		for i, region in ipairs({ 1, 3, false }) do
			local setting = select(3, lastRows(core(region or nil))):GetSetting()
			read[i] = setting:GetDefaultValue() .. " " .. setting:GetValue()
		end

		assert.are.same({ "in in", "cm cm", "cm cm" }, read)
	end)

	it("switches PagleDB.profile.lengthUnit, and Pagle.FormatLength with it (SET-R10, LOG-R69)", function()
		local loaded = core(1)
		local _, _, row, root = lastRows(loaded)
		local rows = loaded.client.settings.show(root)
		local frame = rows[#rows].frame
		assert.are.equal("Inches", frame.valueLabel)

		row:GetSetting():SetValue("cm")

		assert.are.same({ "cm", "Centimetres" }, { loaded.env.PagleDB.profiles.Default.lengthUnit, frame.valueLabel })
		assert.are.equal("34.2 cm", loaded.env.Pagle.FormatLength(342))
	end)

	it("goes back to no stored unit, the region default, with the root's Defaults button (SET-R13, SET-R60)", function()
		local loaded = core(1)
		local _, _, row, root = lastRows(loaded)
		row:GetSetting():SetValue("cm")

		pressDefaults(loaded, root)

		assert.is_nil(loaded.env.PagleDB.profiles.Default.lengthUnit)
		assert.are.same({ "in", "13.5 in" }, { row:GetSetting():GetValue(), loaded.env.Pagle.FormatLength(342) })
	end)
end)
