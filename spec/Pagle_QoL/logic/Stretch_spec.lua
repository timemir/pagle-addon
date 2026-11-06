-- The Fishing stretch's pure logic: when a stretch starts and ends (QOL-R61), and the lease and restore protocol
-- for its CVars (QOL-R62, QOL-R63, QOL-R64).

describe("QoL's Fishing stretch logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	describe("ns.NewStretch", function()
		it("starts at the first CastStarted while armed, and not again while running (QOL-R61)", function()
			local stretch = ns.NewStretch()

			assert.is_true(stretch:CastStarted(true))
			assert.is_true(stretch:IsRunning())
			assert.is_false(stretch:CastStarted(true))
		end)

		it("never starts while disarmed: restricted or standing down (QOL-R61, QOL-R30, QOL-R82)", function()
			local stretch = ns.NewStretch()

			assert.is_false(stretch:CastStarted(false))
			assert.is_false(stretch:IsRunning())
		end)

		it("ends 60 s after the last CastEnded, of any outcome (QOL-R61, qol.md › Tunables)", function()
			local stretch = ns.NewStretch()
			stretch:CastStarted(true)
			stretch:CastEnded()

			assert.is_false(stretch:Elapse(59.5))
			assert.is_true(stretch:IsRunning())
			assert.is_true(stretch:Elapse(0.5))
			assert.is_false(stretch:IsRunning())
		end)

		it("doesn't count while a channel runs, and a new channel restarts the count (QOL-R61)", function()
			local stretch = ns.NewStretch()
			stretch:CastStarted(true)
			assert.is_false(stretch:IsCounting())
			assert.is_false(stretch:Elapse(120))

			stretch:CastEnded()
			assert.is_true(stretch:IsCounting())
			stretch:Elapse(50)
			stretch:CastStarted(true)
			assert.is_false(stretch:IsCounting())
			assert.is_false(stretch:Elapse(120))

			stretch:CastEnded()
			assert.is_false(stretch:Elapse(59))
			assert.is_true(stretch:Elapse(1))
		end)

		it("ends at once on any other cause, and only once (QOL-R61)", function()
			local stretch = ns.NewStretch()
			assert.is_false(stretch:End())

			stretch:CastStarted(true)
			stretch:CastEnded()
			assert.is_true(stretch:End())
			assert.is_false(stretch:IsRunning())
			assert.is_false(stretch:IsCounting())
			assert.is_false(stretch:End())
		end)

		it("ignores a CastEnded outside a stretch, so a later stretch counts from its own Casts (QOL-R61)", function()
			local stretch = ns.NewStretch()
			stretch:CastEnded()
			assert.is_false(stretch:IsCounting())

			stretch:CastStarted(true)
			assert.is_false(stretch:Elapse(60))
		end)

		it("numbers each stretch it starts, so a Nudge can show once per stretch (QOL-R53, QOL-R61)", function()
			local stretch = ns.NewStretch()
			assert.is_nil(stretch:Number())

			stretch:CastStarted(true)
			stretch:CastStarted(true)
			assert.are.equal(1, stretch:Number())
			stretch:End()
			assert.is_nil(stretch:Number())

			stretch:CastStarted(true)
			assert.are.equal(2, stretch:Number())
		end)
	end)

	describe("ns.SameCVarValue", function()
		-- Each row: two values as GetCVar returns them, then whether they're the same (QOL-R62, QOL-R63).
		local ROWS = {
			{ "15", "15", true },
			{ "15", "15.000000", true },
			{ "1", "1.0", true },
			{ "0", "-0", true },
			{ "3", "0", false },
			{ "14.5", "15", false },
			{ "abc", "abc", true },
			{ "abc", "ABC", false },
			{ "1", "on", false },
			{ "", "0", false },
		}
		for _, row in ipairs(ROWS) do
			it(
				("reads %q and %q as %s: as numbers when both parse, else as strings (QOL-R63)"):format(
					row[1],
					row[2],
					row[3] and "the same" or "different"
				),
				function()
					assert.are.equal(row[3], ns.SameCVarValue(row[1], row[2]))
					assert.are.equal(row[3], ns.SameCVarValue(row[2], row[1]))
				end
			)
		end
	end)

	-- CVars as a client holds them, for ns.Lease and ns.RestoreLease. `stores` turns what SetCVar is given into what
	-- GetCVar reads back (the client may normalise it); `log` gets "set NAME VALUE" for each SetCVar.
	---@param values table<string, string>
	---@param stores (fun(name: string, value: string): string)?
	local function newCVars(values, stores)
		local cvars = { values = values, log = {} }
		function cvars.get(name)
			return cvars.values[name]
		end
		function cvars.set(name, value)
			cvars.log[#cvars.log + 1] = ("set %s %s"):format(name, value)
			cvars.values[name] = stores and stores(name, value) or value
		end
		return cvars
	end

	-- The player's values before any lease: nothing at the soft-interact values.
	local function playerValues()
		return { SoftTargetInteract = "1", SoftTargetInteractRange = "10", SoftTargetInteractRangeIsHard = "1" }
	end

	describe("ns.Lease", function()
		it("leases the soft-interact row: interact 3, range 15, range not hard (QOL-R62)", function()
			local lease, cvars = {}, newCVars(playerValues())

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({
				SoftTargetInteract = "3",
				SoftTargetInteractRange = "15",
				SoftTargetInteractRangeIsHard = "0",
			}, cvars.values)
			assert.are.same({
				{ name = "SoftTargetInteract", orig = "1", set = "3" },
				{ name = "SoftTargetInteractRange", orig = "10", set = "15" },
				{ name = "SoftTargetInteractRangeIsHard", orig = "1", set = "0" },
			}, lease)
		end)

		it("writes { name, orig } before SetCVar, then set as GetCVar reads it back (QOL-R63)", function()
			local lease = {}
			local seen = {}
			local cvars = newCVars(playerValues(), function(_, value)
				return value .. ".000000"
			end)
			local set = cvars.set
			function cvars.set(name, value)
				local entry = lease[#lease]
				seen[#seen + 1] = { name = entry.name, orig = entry.orig, set = entry.set }
				set(name, value)
			end

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({ name = "SoftTargetInteract", orig = "1" }, seen[1])
			assert.are.same({ name = "SoftTargetInteract", orig = "1", set = "3.000000" }, lease[1])
		end)

		it("leases no CVar that already holds its leased value, compared as numbers (QOL-R62)", function()
			local lease = {}
			local cvars = newCVars({
				SoftTargetInteract = "3.0",
				SoftTargetInteractRange = "10",
				SoftTargetInteractRangeIsHard = "0",
			})

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({ "set SoftTargetInteractRange 15" }, cvars.log)
			assert.are.same({ { name = "SoftTargetInteractRange", orig = "10", set = "15" } }, lease)
		end)

		it("leases SoftTargetInteractRange only while the player's value is below 15 (QOL-R62)", function()
			for _, row in ipairs({
				{ "60", false },
				{ "15", false },
				{ "15.5", false },
				{ "14.9", true },
				{ "0", true },
			}) do
				local values = playerValues()
				values.SoftTargetInteractRange = row[1]
				local lease, cvars = {}, newCVars(values)

				ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

				assert.are.equal(row[2] and "15" or row[1], cvars.values.SoftTargetInteractRange, row[1])
				assert.are.equal(row[2] and 3 or 2, #lease, row[1])
			end
		end)

		it(
			"leases the audio mix and auto-loot, skipping each CVar already at its value as numbers (QOL-R62)",
			function()
				local lease = {}
				local cvars = newCVars({
					Sound_EnableSFX = "1",
					Sound_SFXVolume = "1",
					Sound_EnableMusic = "1",
					Sound_EnableAmbience = "0",
					Sound_EnableDialog = "1",
					autoLootDefault = "1",
				})

				ns.Lease(lease, ns.LeaseRows({ audio = { on = true, background = false }, autoLoot = true }), cvars)

				assert.are.same({ "set Sound_EnableMusic 0", "set Sound_EnableDialog 0" }, cvars.log)
				assert.are.same({
					{ name = "Sound_EnableMusic", orig = "1", set = "0" },
					{ name = "Sound_EnableDialog", orig = "1", set = "0" },
				}, lease)
			end
		)

		it("leases no CVar the client doesn't know (GetCVar returns nil)", function()
			local lease, cvars = {}, newCVars({ SoftTargetInteract = "1" })

			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)

			assert.are.same({ { name = "SoftTargetInteract", orig = "1", set = "3" } }, lease)
		end)

		it(
			"keeps a waiting entry whose CVar still holds the leased value, so orig stays the player's (QOL-R63)",
			function()
				local values = playerValues()
				values.SoftTargetInteract = "3"
				local lease = { { name = "SoftTargetInteract", orig = "1", set = "3" } }

				ns.Lease(lease, { ns.SOFT_INTERACT_LEASE[1] }, newCVars(values))

				assert.are.same({ { name = "SoftTargetInteract", orig = "1", set = "3" } }, lease)
			end
		)

		it("replaces a waiting entry the player has overruled since, leasing from their new value (QOL-R63)", function()
			local values = playerValues()
			values.SoftTargetInteract = "2"
			local lease = { { name = "SoftTargetInteract", orig = "1", set = "3" } }

			ns.Lease(lease, { ns.SOFT_INTERACT_LEASE[1] }, newCVars(values))

			assert.are.same({ { name = "SoftTargetInteract", orig = "2", set = "3" } }, lease)
		end)

		it(
			"leases a CVar again at a new value keeping the player's orig, so the restore is theirs (QOL-R63, QOL-R65)",
			function()
				local lease, cvars = {}, newCVars({ Sound_SFXVolume = "0.4" })
				ns.Lease(lease, { { name = "Sound_SFXVolume", value = "1.0" } }, cvars)

				ns.Lease(lease, { { name = "Sound_SFXVolume", value = "0.5" } }, cvars)

				assert.are.same({ { name = "Sound_SFXVolume", orig = "0.4", set = "0.5" } }, lease)
				ns.RestoreLease(lease, cvars)
				assert.are.equal("0.4", cvars.values.Sound_SFXVolume)
				assert.are.same({}, lease)
			end
		)

		it(
			"stores the value it set when GetCVar reads nothing back, as while the sound system restarts (QOL-R68)",
			function()
				local lease, cvars = {}, newCVars({ Sound_OutputDriverIndex = "0" })
				local set = cvars.set
				function cvars.set(name, value)
					set(name, value)
					cvars.values[name] = nil
				end

				ns.Lease(lease, { { name = "Sound_OutputDriverIndex", value = "2" } }, cvars)

				assert.are.same({ { name = "Sound_OutputDriverIndex", orig = "0", set = "2" } }, lease)
			end
		)
	end)

	describe("ns.LeaseRows", function()
		-- The CVar names and values of a row list, in order, as "name=value".
		local function named(rows)
			local list = {}
			for i, row in ipairs(rows) do
				list[i] = row.name .. "=" .. row.value
			end
			return list
		end

		local SOFT = { "SoftTargetInteract=3", "SoftTargetInteractRange=15", "SoftTargetInteractRangeIsHard=0" }
		local AUDIO = {
			"Sound_EnableSFX=1",
			"Sound_SFXVolume=1.0",
			"Sound_EnableMusic=0",
			"Sound_EnableAmbience=0",
			"Sound_EnableDialog=0",
		}
		local BACKGROUND = { "Sound_EnableSoundWhenGameIsInBG=1" }
		local AUTO_LOOT = { "autoLootDefault=1" }

		-- Each row: the While you fish settings, then the rows a stretch leases under them (QOL-R62).
		local ROWS = {
			{
				"the defaults",
				{ audio = { on = true, background = false }, autoLoot = true },
				{ SOFT, AUDIO, AUTO_LOOT },
			},
			{
				"everything on",
				{ audio = { on = true, background = true }, autoLoot = true },
				{ SOFT, AUDIO, BACKGROUND, AUTO_LOOT },
			},
			{ "everything off", { audio = { on = false, background = false }, autoLoot = false }, { SOFT } },
			{
				"the background option without the audio mix",
				{ audio = { on = false, background = true }, autoLoot = false },
				{ SOFT },
			},
			{ "auto-loot alone", { audio = { on = false, background = false }, autoLoot = true }, { SOFT, AUTO_LOOT } },
		}
		for _, row in ipairs(ROWS) do
			it(
				("leases soft-interact always, then each feature that is on, under %s (QOL-R62)"):format(row[1]),
				function()
					local want = {}
					for _, part in ipairs(row[3]) do
						for _, entry in ipairs(part) do
							want[#want + 1] = entry
						end
					end

					assert.are.same(want, named(ns.LeaseRows(row[2])))
				end
			)
		end

		it("leaves master volume and Sound_EnableAllSound alone (QOL-R62)", function()
			for _, row in ipairs(ns.LeaseRows({ audio = { on = true, background = true }, autoLoot = true })) do
				assert.are_not.equal("Sound_MasterVolume", row.name)
				assert.are_not.equal("Sound_EnableAllSound", row.name)
			end
		end)
	end)

	describe("the Fishing audio mix's rows", function()
		-- The CVar names and values of a row list, in order, as "name=value".
		local function named(rows)
			local list = {}
			for i, row in ipairs(rows) do
				list[i] = row.name .. "=" .. row.value
			end
			return list
		end

		-- The defaults' audio settings, with `changes` over them.
		local function audio(changes)
			local settings = {}
			for key, value in pairs(ns.DB_DEFAULTS.profile.audio) do
				settings[key] = value
			end
			for key, value in pairs(changes or {}) do
				settings[key] = value
			end
			return settings
		end

		local DEVICES = { "System Default", "Speakers", "Headset" }

		it("reproduces 1.1's mix under the defaults, byte for byte and in order (QOL-R62)", function()
			assert.are.same({
				"Sound_EnableSFX=1",
				"Sound_SFXVolume=1.0",
				"Sound_EnableMusic=0",
				"Sound_EnableAmbience=0",
				"Sound_EnableDialog=0",
			}, named(ns.AudioMixRows(audio(), DEVICES)))
			assert.are.same(
				named(ns.LeaseRows({ audio = { on = true, background = true }, autoLoot = true })),
				named(ns.LeaseRows({ audio = audio({ background = true }), autoLoot = true }, DEVICES))
			)
		end)

		-- A channel's setting: ticked or not, at a volume in percent.
		local function at(on, volume)
			return { on = on, volume = volume }
		end
		local UNTICKED = at(false, 100)

		-- Each case: a channel, its setting, then the rows the mix leases for it (QOL-R62).
		local CASES = {
			{ "master", UNTICKED, {} },
			{ "master", at(true, 80), { "Sound_MasterVolume=0.8" } },
			{ "master", at(true, 100), { "Sound_MasterVolume=1.0" } },
			{ "master", at(true, 0), { "Sound_MasterVolume=0.1" } },
			{ "effects", UNTICKED, {} },
			{ "effects", at(false, 0), {} },
			{ "effects", at(true, 0), { "Sound_EnableSFX=0" } },
			{ "effects", at(true, 50), { "Sound_EnableSFX=1", "Sound_SFXVolume=0.5" } },
			{ "music", UNTICKED, {} },
			{ "music", at(true, 0), { "Sound_EnableMusic=0" } },
			{ "music", at(true, 30), { "Sound_EnableMusic=1", "Sound_MusicVolume=0.3" } },
			{ "ambience", UNTICKED, {} },
			{ "ambience", at(true, 0), { "Sound_EnableAmbience=0" } },
			{ "ambience", at(true, 100), { "Sound_EnableAmbience=1", "Sound_AmbienceVolume=1.0" } },
			{ "dialog", UNTICKED, {} },
			{ "dialog", at(true, 0), { "Sound_EnableDialog=0" } },
			{ "dialog", at(true, 5), { "Sound_EnableDialog=1", "Sound_DialogVolume=0.05" } },
		}
		for _, case in ipairs(CASES) do
			it(
				(
					"leases %s for %s %s at %d%%: nothing unticked, its switch off at 0, else its switch on and its volume"
					.. " (QOL-R62)"
				):format(
					#case[3] == 0 and "nothing" or table.concat(case[3], ", "),
					case[1],
					case[2].on and "ticked" or "unticked",
					case[2].volume
				),
				function()
					local settings = {
						master = UNTICKED,
						effects = UNTICKED,
						music = UNTICKED,
						ambience = UNTICKED,
						dialog = UNTICKED,
						device = "",
					}
					settings[case[1]] = case[2]

					assert.are.same(case[3], named(ns.AudioMixRows(audio(settings), DEVICES)))
				end
			)
		end

		it("never turns master off or below 10%, and never leases Sound_EnableAllSound (QOL-R62)", function()
			local rows = ns.AudioMixRows(audio({ master = at(true, 5), music = at(true, 0) }), DEVICES)

			assert.are.same("Sound_MasterVolume=0.1", named(rows)[1])
			for _, row in ipairs(rows) do
				assert.are_not.equal("Sound_EnableAllSound", row.name)
			end
		end)

		it("leases the chosen output device by its index from 0, after the channels (QOL-R68)", function()
			assert.are.same({
				"Sound_EnableSFX=1",
				"Sound_SFXVolume=1.0",
				"Sound_EnableMusic=0",
				"Sound_EnableAmbience=0",
				"Sound_EnableDialog=0",
				"Sound_OutputDriverIndex=2",
			}, named(ns.AudioMixRows(audio({ device = "Headset" }), DEVICES)))
			assert.are.same(
				{ "Sound_OutputDriverIndex=0" },
				named(ns.AudioMixRows(
					audio({
						effects = UNTICKED,
						music = UNTICKED,
						ambience = UNTICKED,
						dialog = UNTICKED,
						device = "System Default",
					}),
					DEVICES
				))
			)
		end)

		it("leases no device for Don't change, nor while the one chosen isn't there: unplugged (QOL-R68)", function()
			local function deviceRows(device, devices)
				local list = {}
				for _, row in ipairs(ns.AudioMixRows(audio({ device = device }), devices)) do
					if row.name == "Sound_OutputDriverIndex" then
						list[#list + 1] = row.value
					end
				end
				return list
			end

			assert.are.same({}, deviceRows("", DEVICES))
			assert.are.same({}, deviceRows("USB Headset", DEVICES))
			assert.are.same({}, deviceRows("Headset", { "System Default", "Speakers" }))
			assert.are.same({}, deviceRows("Headset", {}))
			assert.are.same({}, deviceRows("Headset", nil))
			assert.are.same({ "1" }, deviceRows("Headset", { "System Default", "Headset", "Headset" }))
		end)

		it("leases no device and no channel while the audio mix is off (QOL-R62)", function()
			local rows = ns.LeaseRows(
				{ audio = audio({ on = false, master = at(true, 50), device = "Headset" }), autoLoot = false },
				DEVICES
			)

			assert.are.same(
				{ "SoftTargetInteract=3", "SoftTargetInteractRange=15", "SoftTargetInteractRangeIsHard=0" },
				named(rows)
			)
		end)
	end)

	describe("ns.LeaseChange", function()
		local ON = { audio = { on = true, background = true }, autoLoot = true }
		local OFF = { audio = { on = false, background = true }, autoLoot = true }

		-- The names of a row list, in order.
		local function names(rows)
			local list = {}
			for i, row in ipairs(rows) do
				list[i] = row.name
			end
			return list
		end

		it("restores the audio mix's CVars and the background one when the mix turns off (QOL-R65)", function()
			local lease, restore = ns.LeaseChange(ns.LeaseRows(ON), ns.LeaseRows(OFF))

			assert.are.same({}, lease)
			assert.are.same({
				Sound_EnableSFX = true,
				Sound_SFXVolume = true,
				Sound_EnableMusic = true,
				Sound_EnableAmbience = true,
				Sound_EnableDialog = true,
				Sound_EnableSoundWhenGameIsInBG = true,
			}, restore)
		end)

		it("leases them again when the mix turns back on, and nothing that stayed on (QOL-R65)", function()
			local lease, restore = ns.LeaseChange(ns.LeaseRows(OFF), ns.LeaseRows(ON))

			assert.are.same({
				"Sound_EnableSFX",
				"Sound_SFXVolume",
				"Sound_EnableMusic",
				"Sound_EnableAmbience",
				"Sound_EnableDialog",
				"Sound_EnableSoundWhenGameIsInBG",
			}, names(lease))
			assert.are.same({}, restore)
		end)

		it("restores or leases auto-loot alone when only it changes (QOL-R65)", function()
			local noLoot = { audio = ON.audio, autoLoot = false }

			local lease, restore = ns.LeaseChange(ns.LeaseRows(ON), ns.LeaseRows(noLoot))
			assert.are.same({}, lease)
			assert.are.same({ autoLootDefault = true }, restore)

			lease, restore = ns.LeaseChange(ns.LeaseRows(noLoot), ns.LeaseRows(ON))
			assert.are.same({ "autoLootDefault" }, names(lease))
			assert.are.same({}, restore)
		end)

		it("leases a CVar again when its value changes: Effects from 100% to 50% (QOL-R65)", function()
			local half =
				{ audio = { on = true, background = true, effects = { on = true, volume = 50 } }, autoLoot = true }

			local lease, restore = ns.LeaseChange(ns.LeaseRows(ON), ns.LeaseRows(half))

			assert.are.same({ { name = "Sound_SFXVolume", value = "0.5" } }, lease)
			assert.are.same({}, restore)
		end)

		it(
			"leases the switch off and restores the volume when a channel goes from a volume to 0%, Off (QOL-R65)",
			function()
				local half =
					{ audio = { on = true, background = true, music = { on = true, volume = 50 } }, autoLoot = true }
				local off =
					{ audio = { on = true, background = true, music = { on = true, volume = 0 } }, autoLoot = true }

				local lease, restore = ns.LeaseChange(ns.LeaseRows(half), ns.LeaseRows(off))

				assert.are.same({ { name = "Sound_EnableMusic", value = "0" } }, lease)
				assert.are.same({ Sound_MusicVolume = true }, restore)
			end
		)

		it("restores a channel's CVars when it's unticked (QOL-R65)", function()
			local keep =
				{ audio = { on = true, background = true, effects = { on = false, volume = 100 } }, autoLoot = true }

			local lease, restore = ns.LeaseChange(ns.LeaseRows(ON), ns.LeaseRows(keep))

			assert.are.same({}, lease)
			assert.are.same({ Sound_EnableSFX = true, Sound_SFXVolume = true }, restore)
		end)

		it("leases a new device, and restores the device for Don't change (QOL-R65, QOL-R68)", function()
			local devices = { "System Default", "Speakers", "Headset" }
			local function on(device)
				return { audio = { on = true, background = true, device = device }, autoLoot = true }
			end

			local lease, restore =
				ns.LeaseChange(ns.LeaseRows(on("Headset"), devices), ns.LeaseRows(on("Speakers"), devices))
			assert.are.same({ { name = "Sound_OutputDriverIndex", value = "1" } }, lease)
			assert.are.same({}, restore)

			lease, restore = ns.LeaseChange(ns.LeaseRows(on("Speakers"), devices), ns.LeaseRows(on(""), devices))
			assert.are.same({}, lease)
			assert.are.same({ Sound_OutputDriverIndex = true }, restore)
		end)

		it("changes nothing when the background option turns while the mix is off (QOL-R62, QOL-R65)", function()
			local lease, restore = ns.LeaseChange(
				ns.LeaseRows(OFF),
				ns.LeaseRows({ audio = { on = false, background = false }, autoLoot = true })
			)

			assert.are.same({}, lease)
			assert.are.same({}, restore)
		end)
	end)

	describe("the output device's name in the lease", function()
		-- A lease holding the device's entry, and one other.
		local function leased(entry)
			return { { name = "Sound_EnableMusic", orig = "1", set = "0" }, entry }
		end

		it("notes the name of the player's own device, by orig's index, on a new entry only (QOL-R68)", function()
			local lease = leased({ name = "Sound_OutputDriverIndex", orig = "1", set = "2" })

			ns.NameLeasedDevice(lease, { "System Default", "Speakers", "Headset" })
			assert.are.equal("Speakers", lease[2].origName)
			assert.is_nil(lease[1].origName)

			ns.NameLeasedDevice(lease, { "System Default", "Headset", "Speakers" })
			assert.are.equal("Speakers", lease[2].origName)
		end)

		it("notes no name when orig's index names no device (QOL-R68)", function()
			local lease = leased({ name = "Sound_OutputDriverIndex", orig = "5", set = "2" })

			ns.NameLeasedDevice(lease, { "System Default", "Speakers", "Headset" })

			assert.is_nil(lease[2].origName)
		end)

		it("points orig at the player's device where it is now, after the devices reordered (QOL-R68)", function()
			local lease = leased({ name = "Sound_OutputDriverIndex", orig = "1", set = "3", origName = "Speakers" })

			ns.ResolveLeasedDevice(lease, { "System Default", "Monitor", "Speakers", "Headset" })

			assert.are.same(
				{ name = "Sound_OutputDriverIndex", orig = "2", set = "3", origName = "Speakers" },
				lease[2]
			)
		end)

		it("keeps the raw orig index when the player's device is gone (QOL-R68)", function()
			local lease = leased({ name = "Sound_OutputDriverIndex", orig = "1", set = "2", origName = "Speakers" })

			ns.ResolveLeasedDevice(lease, { "System Default", "Headset" })

			assert.are.equal("1", lease[2].orig)
		end)
	end)

	describe("ns.RestoreLease", function()
		it("restores each CVar that still reads set to orig, and removes its entry (QOL-R63)", function()
			local lease, cvars = {}, newCVars(playerValues())
			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)
			cvars.log = {}

			ns.RestoreLease(lease, cvars)

			assert.are.same(playerValues(), cvars.values)
			assert.are.same({}, lease)
			assert.are.equal(3, #cvars.log)
		end)

		it("leaves a value the player changed during the stretch, and removes its entry (QOL-R63)", function()
			local lease, cvars = {}, newCVars(playerValues())
			ns.Lease(lease, ns.SOFT_INTERACT_LEASE, cvars)
			cvars.values.SoftTargetInteractRange = "30"
			cvars.log = {}

			ns.RestoreLease(lease, cvars)

			assert.are.equal("30", cvars.values.SoftTargetInteractRange)
			assert.are.same({ "set SoftTargetInteract 1", "set SoftTargetInteractRangeIsHard 1" }, cvars.log)
			assert.are.same({}, lease)
		end)

		it("compares with set as numbers when both parse, else as strings (QOL-R63)", function()
			local cvars = newCVars({ A = "15.000000", B = "on", C = "ON" })
			local lease = {
				{ name = "A", orig = "10", set = "15" },
				{ name = "B", orig = "off", set = "on" },
				{ name = "C", orig = "off", set = "on" },
			}

			ns.RestoreLease(lease, cvars)

			assert.are.same({ A = "10", B = "off", C = "ON" }, cvars.values)
			assert.are.same({}, lease)
		end)

		it("keeps an entry whose restore didn't take, for the leftover restore (QOL-R63, QOL-R64)", function()
			local cvars = newCVars({ A = "3" }, function()
				return "3"
			end)
			local lease = { { name = "A", orig = "1", set = "3" } }

			ns.RestoreLease(lease, cvars)

			assert.are.same({ { name = "A", orig = "1", set = "3" } }, lease)
		end)

		it("removes an entry whose CVar the client no longer knows (QOL-R63)", function()
			local cvars = newCVars({})
			local lease = { { name = "Gone", orig = "1", set = "3" } }

			ns.RestoreLease(lease, cvars)

			assert.are.same({}, cvars.log)
			assert.are.same({}, lease)
		end)

		it("restores only the named entries when given names, keeping the rest leased (QOL-R65)", function()
			local cvars = newCVars({ A = "3", B = "0", C = "1" })
			local lease = {
				{ name = "A", orig = "1", set = "3" },
				{ name = "B", orig = "1", set = "0" },
				{ name = "C", orig = "0", set = "1" },
			}

			ns.RestoreLease(lease, cvars, { B = true, C = true })

			assert.are.same({ A = "3", B = "1", C = "0" }, cvars.values)
			assert.are.same({ { name = "A", orig = "1", set = "3" } }, lease)
		end)

		it("keeps a named entry whose restore didn't take, beside the unnamed ones (QOL-R65, QOL-R64)", function()
			local cvars = newCVars({ A = "3", B = "0" }, function(name, value)
				return name == "B" and "0" or value
			end)
			local lease = { { name = "A", orig = "1", set = "3" }, { name = "B", orig = "1", set = "0" } }

			ns.RestoreLease(lease, cvars, { B = true })

			assert.are.same({ "set B 1" }, cvars.log)
			assert.are.same({ { name = "A", orig = "1", set = "3" }, { name = "B", orig = "1", set = "0" } }, lease)
		end)
	end)
end)
