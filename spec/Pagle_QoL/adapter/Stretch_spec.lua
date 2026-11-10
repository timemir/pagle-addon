-- The Fishing stretch and the soft-interact lease in M1 (QOL-R61–R64, QOL-R66, QOL-R31's stretch half), driven
-- through FakePagle and the fake client's game side (spec/support/fake_game.lua).

local FISHING_POLE, SWORD = 6256, 25

-- The player's own soft-interact values, none at what QoL leases (QOL-R62).
local function playerValues()
	return { SoftTargetInteract = "1", SoftTargetInteractRange = "10", SoftTargetInteractRangeIsHard = "1" }
end

-- The soft-interact values a stretch leases (QOL-R62, qol.md › Tunables).
local LEASED = { SoftTargetInteract = "3", SoftTargetInteractRange = "15", SoftTargetInteractRangeIsHard = "0" }

-- QoL loaded against FakePagle and logged in, holding a fishing pole, with the player's own CVar values.
-- `before(fake, client, loaded)` runs after the load and before PLAYER_LOGIN.
---@param before fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
---@return FakePagle fake
---@return FakeClient client
---@return LoadedAddon loaded
local function start(before)
	local fake = newFakePagle()
	local loaded = fake.load("Pagle_QoL")
	local client = loaded.client
	client.mainHand = FISHING_POLE
	client.cvars = playerValues()
	if before then
		before(fake, client, loaded)
	end
	fake.login()
	fake.fireGameEvent("PLAYER_LOGIN")
	return fake, client, loaded
end

-- Makes the client's InCombatLockdown() read what the returned setter was last given; false until then.
---@param loaded LoadedAddon
---@return fun(locked: boolean)
local function lockdownOf(loaded)
	local locked = false
	loaded.env.InCombatLockdown = function()
		return locked
	end
	return function(value)
		locked = value
	end
end

-- PagleQoLDB.global.lease as saved.
---@param loaded LoadedAddon
local function leaseOf(loaded)
	return loaded.env.PagleQoLDB.global.lease
end

describe("The Fishing stretch", function()
	describe("starting", function()
		it("leases the soft-interact CVars at the first CastStarted while armed (QOL-R61, QOL-R62)", function()
			local fake, client, loaded = start()

			fake.fire("CastStarted")

			assert.are.same(LEASED, client.cvars)
			assert.are.same({
				{ name = "SoftTargetInteract", orig = "1", set = "3" },
				{ name = "SoftTargetInteractRange", orig = "10", set = "15" },
				{ name = "SoftTargetInteractRangeIsHard", orig = "1", set = "0" },
			}, leaseOf(loaded))
		end)

		it("leases once per stretch: a later CastStarted changes nothing (QOL-R61, QOL-R63)", function()
			local fake, client = start()
			fake.fire("CastStarted")
			fake.fire("CastEnded", "caught")
			client.cvarCalls = {}

			fake.fire("CastStarted")

			assert.are.same({}, client.cvarCalls)
		end)

		it("starts no stretch while restricted, so leases nothing (QOL-R61, QOL-R30)", function()
			local fake, client, loaded = start()
			fake.setRestricted(true)

			fake.fire("CastStarted")

			assert.are.same({}, client.cvarCalls)
			assert.are.same({}, leaseOf(loaded))
		end)

		it("starts no stretch before PLAYER_LOGIN, when QoL hasn't armed yet (QOL-R61, QOL-R33)", function()
			local fake = newFakePagle()
			local loaded = fake.load("Pagle_QoL")
			loaded.client.cvars = playerValues()

			fake.fire("CastStarted")

			assert.are.same(playerValues(), loaded.client.cvars)
		end)

		it("leases a CVar only away from its leased value; the range only below 15 (QOL-R62)", function()
			local fake, client, loaded = start(function(_, client)
				client.cvars =
					{ SoftTargetInteract = "3.0", SoftTargetInteractRange = "40", SoftTargetInteractRangeIsHard = "1" }
			end)

			fake.fire("CastStarted")

			assert.are.same({ "set SoftTargetInteractRangeIsHard 0" }, client.cvarCalls)
			assert.are.same({ { name = "SoftTargetInteractRangeIsHard", orig = "1", set = "0" } }, leaseOf(loaded))
		end)
	end)

	describe("ending", function()
		-- A stretch running, then `cause(fake, client)`: each must end it and restore the player's values.
		local CAUSES = {
			["the pole comes off"] = function(fake, client)
				client.mainHand = SWORD
				fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, true)
			end,
			["the pole comes off, leaving the hand empty"] = function(fake, client)
				client.mainHand = nil
				fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 16, false)
			end,
			["the player mounts"] = function(fake, client)
				client.mounted = true
				fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
			end,
			["PLAYER_REGEN_DISABLED, before lockdown (QOL-R31)"] = function(fake)
				fake.fireGameEvent("PLAYER_REGEN_DISABLED")
			end,
			["RestrictionChanged(true), out of lockdown (QOL-R31)"] = function(fake)
				fake.setRestricted(true)
			end,
			["logout or /reload"] = function(fake)
				fake.fireGameEvent("PLAYER_LOGOUT")
			end,
			["60 s after the last CastEnded"] = function(fake, client)
				fake.fire("CastEnded", "gotAway")
				client.update(30)
				client.update(30)
			end,
		}
		for cause, happen in pairs(CAUSES) do
			it(("ends when %s, restoring the lease (QOL-R61, QOL-R63)"):format(cause), function()
				local fake, client, loaded = start()
				fake.fire("CastStarted")

				happen(fake, client)

				assert.are.same(playerValues(), client.cvars)
				assert.are.same({}, leaseOf(loaded))
			end)
		end

		it("goes on through an equipment change that keeps the pole, and a dismount (QOL-R61)", function()
			local fake, client = start()
			fake.fire("CastStarted")

			fake.fireGameEvent("PLAYER_EQUIPMENT_CHANGED", 1, true)
			client.mounted = false
			fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

			assert.are.same(LEASED, client.cvars)
		end)

		it("counts the 60 s from the last CastEnded of any outcome, reset by a new channel (QOL-R61)", function()
			local fake, client = start()
			fake.fire("CastStarted")
			fake.fire("CastEnded", "caught")
			client.update(50)

			fake.fire("CastStarted")
			client.update(50)
			assert.are.same(LEASED, client.cvars)
			fake.fire("CastEnded", "interrupted")
			client.update(59.5)
			assert.are.same(LEASED, client.cvars)

			client.update(0.5)
			assert.are.same(playerValues(), client.cvars)
		end)

		it("leaves a value the player changed during the stretch as theirs (QOL-R63)", function()
			local fake, client, loaded = start()
			fake.fire("CastStarted")
			client.cvars.SoftTargetInteractRange = "25"

			fake.fireGameEvent("PLAYER_LOGOUT")

			assert.are.same(
				{ SoftTargetInteract = "1", SoftTargetInteractRange = "25", SoftTargetInteractRangeIsHard = "1" },
				client.cvars
			)
			assert.are.same({}, leaseOf(loaded))
		end)

		it("starts a new stretch, and leases again, at the next CastStarted (QOL-R61)", function()
			local fake, client = start()
			fake.fire("CastStarted")
			client.mounted = true
			fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
			client.mounted = false

			fake.fire("CastStarted")

			assert.are.same(LEASED, client.cvars)
		end)
	end)

	describe("restores under lockdown", function()
		it("waits for RestrictionChanged(false) when the stretch ends in lockdown (QOL-R31, QOL-R66)", function()
			local fake, client, loaded = start()
			local setLockdown = lockdownOf(loaded)
			fake.fire("CastStarted")
			client.cvarCalls = {}

			setLockdown(true)
			fake.setRestricted(true)
			-- The stretch has ended: nothing restored yet, and no new stretch starts.
			fake.fire("CastStarted")
			assert.are.same({}, client.cvarCalls)
			assert.are.same(LEASED, client.cvars)
			assert.are.equal(3, #leaseOf(loaded))

			setLockdown(false)
			fake.setRestricted(false)
			assert.are.same(playerValues(), client.cvars)
			assert.are.same({}, leaseOf(loaded))
		end)

		it(
			"waits at PLAYER_LOGOUT in lockdown, leaving the lease saved for the next load (QOL-R66, QOL-R64)",
			function()
				local fake, client, loaded = start()
				fake.fire("CastStarted")
				lockdownOf(loaded)(true)

				fake.fireGameEvent("PLAYER_LOGOUT")

				assert.are.same(LEASED, client.cvars)
				assert.are.equal(3, #leaseOf(loaded))
			end
		)
	end)

	describe("the leftover restore", function()
		-- QoL loaded against FakePagle with `lease` left in PagleQoLDB and the client's CVars at `values`, up to just
		-- before its ADDON_LOADED. `inCombat` makes it a load in combat: restricted, InCombatLockdown() true. Returns
		-- the lockdown setter too.
		---@return FakePagle fake
		---@return LoadedAddon loaded
		---@return fun(locked: boolean) setLockdown
		local function loadWithLease(lease, values, inCombat)
			local fake = newFakePagle()
			if inCombat then
				fake.setRestricted(true)
			end
			local loaded = fake.load("Pagle_QoL", { holdAddonLoaded = true })
			loaded.env.PagleQoLDB = { global = { schemaVersion = 1, lease = lease } }
			local setLockdown = lockdownOf(loaded)
			setLockdown(inCombat == true)
			loaded.client.cvars = values
			return fake, loaded, setLockdown
		end

		local function leftover()
			return {
				{ name = "SoftTargetInteract", orig = "1", set = "3" },
				{ name = "SoftTargetInteractRange", orig = "10", set = "15" },
			}
		end

		it("restores what was left in global.lease at ADDON_LOADED, before PLAYER_LOGIN (QOL-R64)", function()
			local _, loaded = loadWithLease(leftover(), { SoftTargetInteract = "3", SoftTargetInteractRange = "30" })

			loaded.client.fire("ADDON_LOADED", "Pagle_QoL")

			-- The range was changed since, so it is the player's (QOL-R63).
			assert.are.same({ SoftTargetInteract = "1", SoftTargetInteractRange = "30" }, loaded.client.cvars)
			assert.are.same({}, leaseOf(loaded))
		end)

		it("waits for RestrictionChanged(false) after a load in lockdown (QOL-R64, QOL-R66)", function()
			local fake, loaded, setLockdown =
				loadWithLease(leftover(), { SoftTargetInteract = "3", SoftTargetInteractRange = "15" }, true)

			loaded.client.fire("ADDON_LOADED", "Pagle_QoL")
			assert.are.same({}, loaded.client.cvarCalls)
			assert.are.same(leftover(), leaseOf(loaded))

			setLockdown(false)
			fake.setRestricted(false)
			assert.are.same({ SoftTargetInteract = "1", SoftTargetInteractRange = "10" }, loaded.client.cvars)
			assert.are.same({}, leaseOf(loaded))
		end)

		it("still runs while QoL stands down, which starts no stretch and leases nothing (QOL-R82, QOL-R64)", function()
			local fake, loaded = loadWithLease(leftover(), { SoftTargetInteract = "3", SoftTargetInteractRange = "15" })
			local client = loaded.client
			client.addons.Angleur = { metadata = { Title = "Angleur" } }
			client.mainHand = FISHING_POLE

			client.fire("ADDON_LOADED", "Pagle_QoL")
			fake.login()
			fake.fireGameEvent("PLAYER_LOGIN")
			assert.is_true(loaded.ns.IsStandingDown())
			assert.are.same({ SoftTargetInteract = "1", SoftTargetInteractRange = "10" }, client.cvars)

			client.cvarCalls = {}
			fake.fire("CastStarted")
			assert.are.same({}, client.cvarCalls)
			assert.are.same({}, leaseOf(loaded))
		end)

		it("leaves the lease alone while QoL is inert: it runs no code (QOL-R90, CORE-R13)", function()
			local fake, loaded = loadWithLease(leftover(), { SoftTargetInteract = "3", SoftTargetInteractRange = "15" })
			fake.addons.Pagle_QoL.metadata["X-Pagle-API"] = "4"

			loaded.client.fire("ADDON_LOADED", "Pagle_QoL")

			assert.are.same({}, loaded.client.cvarCalls)
			assert.are.same(leftover(), loaded.env.PagleQoLDB.global.lease)
		end)
	end)
end)

describe("The audio mix and auto-loot leases", function()
	-- The player's own values, none at what the soft-interact, audio mix, background and auto-loot rows lease.
	local function allValues()
		local values = playerValues()
		values.Sound_EnableSFX = "0"
		values.Sound_SFXVolume = "0.4"
		values.Sound_EnableMusic = "1"
		values.Sound_EnableAmbience = "1"
		values.Sound_EnableDialog = "1"
		values.Sound_EnableSoundWhenGameIsInBG = "0"
		values.autoLootDefault = "0"
		-- Never leased (QOL-R62).
		values.Sound_MasterVolume = "0.8"
		values.Sound_EnableAllSound = "1"
		return values
	end

	-- What a stretch under the defaults leases: soft-interact, the audio mix and auto-loot (QOL-R62).
	local function leasedValues()
		local values = allValues()
		for name, value in pairs(LEASED) do
			values[name] = value
		end
		values.Sound_EnableSFX = "1"
		values.Sound_SFXVolume = "1.0"
		values.Sound_EnableMusic = "0"
		values.Sound_EnableAmbience = "0"
		values.Sound_EnableDialog = "0"
		values.autoLootDefault = "1"
		return values
	end

	-- `start` with the player's values from allValues(); `after(fake, client, loaded)` runs once logged in, when the
	-- Fishing page's rows exist, and before any stretch.
	---@param after fun(fake: FakePagle, client: FakeClient, loaded: LoadedAddon)?
	local function startAll(after)
		local fake, client, loaded = start(function(_, client)
			client.cvars = allValues()
		end)
		if after then
			after(fake, client, loaded)
		end
		return fake, client, loaded
	end

	-- Sets a QoL row on the Fishing page by its label, as the native row's set does: a checkbox ticked, a dropdown's
	-- value, or a channel's box and then its slider's volume, given as { ticked, volume }.
	---@param fake FakePagle
	---@param label string
	---@param value boolean|string|table
	local function tick(fake, label, value)
		for _, row in ipairs(assert(fake.settingsPage("fishing"))) do
			if row.label == label then
				if type(value) == "table" then
					row.setting.set(value[1])
					row.setting.slider.set(value[2])
				else
					row.setting.set(value)
				end
				return
			end
		end
		error("no row " .. label)
	end

	-- The names in PagleQoLDB.global.lease, as a set.
	local function leasedNames(loaded)
		local names = {}
		for _, entry in ipairs(leaseOf(loaded)) do
			names[entry.name] = true
		end
		return names
	end

	-- The client's SetCVar calls on any of the CVars named.
	---@param client FakeClient
	---@return string[]
	local function callsOn(client, ...)
		local names = {}
		for _, name in ipairs({ ... }) do
			names[name] = true
		end
		local calls = {}
		for _, call in ipairs(client.cvarCalls) do
			if names[call:match("^set (%S+)")] then
				calls[#calls + 1] = call
			end
		end
		return calls
	end

	local AUDIO_NAMES =
		{ "Sound_EnableSFX", "Sound_SFXVolume", "Sound_EnableMusic", "Sound_EnableAmbience", "Sound_EnableDialog" }

	it(
		"leases the audio mix and auto-loot with the defaults, and restores them at the end (QOL-R62, QOL-R63)",
		function()
			local fake, client, loaded = startAll()

			fake.fire("CastStarted")
			assert.are.same(leasedValues(), client.cvars)
			assert.are.equal(9, #leaseOf(loaded))

			client.mounted = true
			fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
			assert.are.same(allValues(), client.cvars)
			assert.are.same({}, leaseOf(loaded))
		end
	)

	it("skips a CVar already at the leased value, compared as numbers: auto-loot already on (QOL-R62)", function()
		local fake, client, loaded = startAll(function(_, client)
			client.cvars.autoLootDefault = "1"
			client.cvars.Sound_SFXVolume = "1"
			client.cvars.Sound_EnableAmbience = "0.0"
		end)

		fake.fire("CastStarted")

		local names = leasedNames(loaded)
		assert.is_nil(names.autoLootDefault)
		assert.is_nil(names.Sound_SFXVolume)
		assert.is_nil(names.Sound_EnableAmbience)
		assert.is_true(names.Sound_EnableMusic)
		assert.are.same({}, callsOn(client, "autoLootDefault", "Sound_SFXVolume", "Sound_EnableAmbience"))
	end)

	it("never touches master volume or Sound_EnableAllSound (QOL-R62)", function()
		local fake, client = startAll(function(fake)
			tick(fake, "Keep sound in the background", true)
		end)

		fake.fire("CastStarted")
		fake.fireGameEvent("PLAYER_LOGOUT")

		assert.is_true(#client.cvarCalls > 0)
		assert.are.same({}, callsOn(client, "Sound_MasterVolume", "Sound_EnableAllSound"))
	end)

	it("keeps music on after the stretch if the player turned it on during it (QOL-R63)", function()
		local fake, client = startAll()
		fake.fire("CastStarted")
		client.cvars.Sound_EnableMusic = "1"
		client.cvars.Sound_EnableAmbience = "1"

		fake.fireGameEvent("PLAYER_LOGOUT")

		assert.are.same(allValues(), client.cvars)
	end)

	it("leases the background CVar only with the background option and the audio mix both on (QOL-R62)", function()
		-- Each case: the audio mix, the background option, then whether the background CVar is leased.
		for _, case in ipairs({ { true, true, true }, { true, false, false }, { false, true, false } }) do
			local fake, client = startAll(function(fake)
				tick(fake, "Fishing audio mix", case[1])
				tick(fake, "Keep sound in the background", case[2])
			end)

			fake.fire("CastStarted")

			assert.are.equal(case[3] and "1" or "0", client.cvars.Sound_EnableSoundWhenGameIsInBG)
			assert.are.equal(case[1] and "0" or "1", client.cvars.Sound_EnableMusic)
		end
	end)

	it("leases no auto-loot while Auto-loot while fishing is off (QOL-R62)", function()
		local fake, client = startAll(function(fake)
			tick(fake, "Auto-loot while fishing", false)
		end)

		fake.fire("CastStarted")

		assert.are.equal("0", client.cvars.autoLootDefault)
		assert.are.equal("0", client.cvars.Sound_EnableMusic)
	end)

	describe("a setting turned mid-stretch", function()
		it(
			"restores the audio mix and background CVars at once when the mix turns off, keeping soft-interact (QOL-R65)",
			function()
				local fake, client, loaded = startAll(function(fake)
					tick(fake, "Keep sound in the background", true)
				end)
				fake.fire("CastStarted")
				assert.are.equal("1", client.cvars.Sound_EnableSoundWhenGameIsInBG)

				tick(fake, "Fishing audio mix", false)

				for _, name in ipairs(AUDIO_NAMES) do
					assert.are.equal(allValues()[name], client.cvars[name], name)
				end
				assert.are.equal("0", client.cvars.Sound_EnableSoundWhenGameIsInBG)
				for name, value in pairs(LEASED) do
					assert.are.equal(value, client.cvars[name], name)
				end
				assert.are.equal("1", client.cvars.autoLootDefault)
				assert.are.same({
					SoftTargetInteract = true,
					SoftTargetInteractRange = true,
					SoftTargetInteractRangeIsHard = true,
					autoLootDefault = true,
				}, leasedNames(loaded))
			end
		)

		it("leases them again at once when the mix turns back on (QOL-R65)", function()
			local fake, client = startAll(function(fake)
				tick(fake, "Keep sound in the background", true)
			end)
			fake.fire("CastStarted")
			tick(fake, "Fishing audio mix", false)

			tick(fake, "Fishing audio mix", true)

			assert.are.equal("0", client.cvars.Sound_EnableMusic)
			assert.are.equal("1", client.cvars.Sound_EnableSoundWhenGameIsInBG)
			fake.fireGameEvent("PLAYER_LOGOUT")
			assert.are.same(allValues(), client.cvars)
		end)

		it("restores or leases the background CVar alone when its option turns (QOL-R65)", function()
			local fake, client, loaded = startAll()
			fake.fire("CastStarted")

			tick(fake, "Keep sound in the background", true)
			assert.are.equal("1", client.cvars.Sound_EnableSoundWhenGameIsInBG)

			tick(fake, "Keep sound in the background", false)
			assert.are.equal("0", client.cvars.Sound_EnableSoundWhenGameIsInBG)
			assert.are.equal("0", client.cvars.Sound_EnableMusic)
			assert.is_nil(leasedNames(loaded).Sound_EnableSoundWhenGameIsInBG)
		end)

		it("restores or leases auto-loot alone when it turns (QOL-R65)", function()
			local fake, client = startAll()
			fake.fire("CastStarted")

			tick(fake, "Auto-loot while fishing", false)
			assert.are.equal("0", client.cvars.autoLootDefault)
			assert.are.equal("0", client.cvars.Sound_EnableMusic)

			tick(fake, "Auto-loot while fishing", true)
			assert.are.equal("1", client.cvars.autoLootDefault)
		end)

		it("leaves a value the player changed mid-stretch when its feature turns off (QOL-R63, QOL-R65)", function()
			local fake, client = startAll()
			fake.fire("CastStarted")
			client.cvars.Sound_EnableMusic = "1"

			tick(fake, "Fishing audio mix", false)

			assert.are.equal("1", client.cvars.Sound_EnableMusic)
		end)

		it("doesn't lease soft-interact again when a feature turns on (QOL-R61, QOL-R65)", function()
			local fake, client = startAll(function(fake)
				tick(fake, "Auto-loot while fishing", false)
			end)
			fake.fire("CastStarted")
			client.cvars.SoftTargetInteract = "1"
			client.cvarCalls = {}

			tick(fake, "Auto-loot while fishing", true)

			assert.are.same({ "set autoLootDefault 1" }, client.cvarCalls)
		end)
	end)

	it("changes no CVar when a setting turns with no stretch running (QOL-R65)", function()
		local fake, client = startAll()

		tick(fake, "Fishing audio mix", false)
		tick(fake, "Keep sound in the background", true)
		tick(fake, "Auto-loot while fishing", false)
		tick(fake, "Fishing audio mix", true)

		assert.are.same({}, client.cvarCalls)
	end)

	it("waits for RestrictionChanged(false) with every row when the stretch ends in lockdown (QOL-R66)", function()
		local fake, client, loaded = startAll()
		local setLockdown = lockdownOf(loaded)
		fake.fire("CastStarted")

		setLockdown(true)
		fake.setRestricted(true)
		assert.are.same(leasedValues(), client.cvars)

		setLockdown(false)
		fake.setRestricted(false)
		assert.are.same(allValues(), client.cvars)
		assert.are.same({}, leaseOf(loaded))
	end)

	it("restores the audio and auto-loot rows left in global.lease at ADDON_LOADED (QOL-R64)", function()
		local fake = newFakePagle()
		local loaded = fake.load("Pagle_QoL", { holdAddonLoaded = true })
		loaded.env.PagleQoLDB = {
			global = {
				schemaVersion = 1,
				lease = {
					{ name = "Sound_EnableMusic", orig = "1", set = "0" },
					{ name = "Sound_EnableSoundWhenGameIsInBG", orig = "0", set = "1" },
					{ name = "autoLootDefault", orig = "0", set = "1" },
				},
			},
		}
		loaded.client.cvars = { Sound_EnableMusic = "0", Sound_EnableSoundWhenGameIsInBG = "1", autoLootDefault = "1" }

		loaded.client.fire("ADDON_LOADED", "Pagle_QoL")

		assert.are.same(
			{ Sound_EnableMusic = "1", Sound_EnableSoundWhenGameIsInBG = "0", autoLootDefault = "0" },
			loaded.client.cvars
		)
		assert.are.same({}, leaseOf(loaded))
	end)
	describe("each channel's level and the output device", function()
		local DEVICES = { "System Default", "Speakers", "Headset" }

		-- startAll with the client's devices as DEVICES, the speakers (index 1) playing, and the players' own volumes
		-- for the channels the defaults don't lease.
		local function startDevices(after)
			return startAll(function(fake, client, loaded)
				client.outputDevices = DEVICES
				client.cvars.Sound_OutputDriverIndex = "1"
				client.cvars.Sound_MusicVolume = "0.25"
				client.cvars.Sound_AmbienceVolume = "0.6"
				client.cvars.Sound_DialogVolume = "0.75"
				if after then
					after(fake, client, loaded)
				end
			end)
		end

		-- The sound system's restarts among the client's calls.
		local function restarts(client)
			local count = 0
			for _, call in ipairs(client.cvarCalls) do
				if call == "restart sound" then
					count = count + 1
				end
			end
			return count
		end

		it(
			"leases 1.1's mix under the defaults, and neither master nor the device, with no restart (QOL-R62, QOL-R68)",
			function()
				local fake, client = startDevices()

				fake.fire("CastStarted")

				assert.are.same({
					"set SoftTargetInteract 3",
					"set SoftTargetInteractRange 15",
					"set SoftTargetInteractRangeIsHard 0",
					"set Sound_EnableSFX 1",
					"set Sound_SFXVolume 1.0",
					"set Sound_EnableMusic 0",
					"set Sound_EnableAmbience 0",
					"set Sound_EnableDialog 0",
					"set autoLootDefault 1",
				}, client.cvarCalls)
			end
		)

		it(
			"leases each channel's state: nothing unticked, Off at 0%, or its switch on and its volume (QOL-R62)",
			function()
				local fake, client = startDevices(function(fake)
					tick(fake, "Master volume", { true, 60 })
					tick(fake, "Effects", { false, 100 })
					tick(fake, "Music", { true, 30 })
					tick(fake, "Ambience", { true, 0 })
					tick(fake, "Dialog", { true, 100 })
				end)

				fake.fire("CastStarted")

				-- The player's music and dialog are on already, so only their volumes change.
				assert.are.same(
					{
						"set Sound_MasterVolume 0.6",
						"set Sound_MusicVolume 0.3",
						"set Sound_EnableAmbience 0",
						"set Sound_DialogVolume 1.0",
					},
					callsOn(
						client,
						"Sound_MasterVolume",
						"Sound_EnableSFX",
						"Sound_SFXVolume",
						"Sound_EnableMusic",
						"Sound_MusicVolume",
						"Sound_EnableAmbience",
						"Sound_AmbienceVolume",
						"Sound_EnableDialog",
						"Sound_DialogVolume"
					)
				)
				fake.fireGameEvent("PLAYER_LOGOUT")
				assert.are.same("0.8", client.cvars.Sound_MasterVolume)
				assert.are.same("0.25", client.cvars.Sound_MusicVolume)
				assert.are.same("1", client.cvars.Sound_EnableMusic)
				assert.are.same("0.75", client.cvars.Sound_DialogVolume)
			end
		)

		it(
			"switches to the chosen device and restarts the sound system, then back with a restart at the end (QOL-R68)",
			function()
				local fake, client, loaded = startDevices(function(fake)
					tick(fake, "Output device", "Headset")
				end)

				fake.fire("CastStarted")
				assert.are.equal("2", client.cvars.Sound_OutputDriverIndex)
				assert.are.same({ "set Sound_OutputDriverIndex 2" }, callsOn(client, "Sound_OutputDriverIndex"))
				assert.are.equal("restart sound", client.cvarCalls[#client.cvarCalls])
				assert.are.equal(1, restarts(client))

				client.cvarCalls = {}
				client.mounted = true
				fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
				assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
				assert.are.equal("restart sound", client.cvarCalls[#client.cvarCalls])
				assert.are.equal(1, restarts(client))
				assert.are.same({}, leaseOf(loaded))
			end
		)

		it("doesn't restart the sound system when the chosen device is already playing (QOL-R68)", function()
			local fake, client = startDevices(function(fake)
				tick(fake, "Output device", "Speakers")
			end)

			fake.fire("CastStarted")
			fake.fireGameEvent("PLAYER_LOGOUT")

			assert.are.same({}, callsOn(client, "Sound_OutputDriverIndex"))
			assert.are.equal(0, restarts(client))
		end)

		it(
			"leases no device and restarts nothing while the chosen one is unplugged, leasing the rest (QOL-R68)",
			function()
				local fake, client, loaded = startDevices(function(fake, client)
					tick(fake, "Output device", "Headset")
					client.outputDevices = { "System Default", "Speakers" }
				end)

				assert.has_no_error(function()
					fake.fire("CastStarted")
				end)

				assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
				assert.are.equal(0, restarts(client))
				assert.are.equal("0", client.cvars.Sound_EnableMusic)
				assert.is_nil(leasedNames(loaded).Sound_OutputDriverIndex)
			end
		)

		it("leases nothing for the device on a client without the device calls (QOL-R68)", function()
			local fake, client, loaded = startDevices(function(fake, _, loaded)
				tick(fake, "Output device", "Headset")
				loaded.env.Sound_GameSystem_GetNumOutputDrivers = nil
			end)

			fake.fire("CastStarted")

			assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
			assert.is_nil(leasedNames(loaded).Sound_OutputDriverIndex)
		end)

		it(
			"leaves the device the player picked mid-stretch, restarting nothing at the end (QOL-R63, QOL-R68)",
			function()
				local fake, client = startDevices(function(fake)
					tick(fake, "Output device", "Headset")
				end)
				fake.fire("CastStarted")
				client.cvars.Sound_OutputDriverIndex = "0"
				client.cvarCalls = {}

				fake.fireGameEvent("PLAYER_LOGOUT")

				assert.are.equal("0", client.cvars.Sound_OutputDriverIndex)
				assert.are.equal(0, restarts(client))
			end
		)

		describe("changed mid-stretch", function()
			it(
				"leases a channel's new volume at once and still restores the player's own at the end (QOL-R65)",
				function()
					local fake, client, loaded = startDevices()
					fake.fire("CastStarted")
					client.cvarCalls = {}

					tick(fake, "Effects", { true, 50 })

					assert.are.same({ "set Sound_SFXVolume 0.5" }, client.cvarCalls)
					assert.are.same(
						{ name = "Sound_SFXVolume", orig = "0.4", set = "0.5" },
						(function()
							for _, entry in ipairs(leaseOf(loaded)) do
								if entry.name == "Sound_SFXVolume" then
									return entry
								end
							end
						end)()
					)
					fake.fireGameEvent("PLAYER_LOGOUT")
					assert.are.same(allValues().Sound_SFXVolume, client.cvars.Sound_SFXVolume)
					assert.are.same(allValues().Sound_EnableSFX, client.cvars.Sound_EnableSFX)
				end
			)

			it("turns a channel from a volume to 0% (Off), then unticks it, at once (QOL-R65)", function()
				local fake, client = startDevices(function(fake)
					tick(fake, "Music", { true, 30 })
				end)
				fake.fire("CastStarted")

				tick(fake, "Music", { true, 0 })
				assert.are.equal("0", client.cvars.Sound_EnableMusic)
				assert.are.equal("0.25", client.cvars.Sound_MusicVolume)

				tick(fake, "Music", { false, 0 })
				assert.are.equal("1", client.cvars.Sound_EnableMusic)
			end)

			it(
				"switches to a newly chosen device with one restart, and back for Don't change with one (QOL-R65, QOL-R68)",
				function()
					local fake, client = startDevices(function(fake)
						tick(fake, "Output device", "Headset")
					end)
					fake.fire("CastStarted")
					client.cvarCalls = {}

					tick(fake, "Output device", "System Default")
					assert.are.equal("0", client.cvars.Sound_OutputDriverIndex)
					assert.are.equal(1, restarts(client))

					client.cvarCalls = {}
					tick(fake, "Output device", "")
					assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
					assert.are.same({ "set Sound_OutputDriverIndex 1", "restart sound" }, client.cvarCalls)

					client.cvarCalls = {}
					fake.fireGameEvent("PLAYER_LOGOUT")
					assert.are.equal(0, restarts(client))
				end
			)

			it("puts the device back with one restart when the audio mix turns off (QOL-R65, QOL-R68)", function()
				local fake, client = startDevices(function(fake)
					tick(fake, "Output device", "Headset")
				end)
				fake.fire("CastStarted")
				client.cvarCalls = {}

				tick(fake, "Fishing audio mix", false)

				assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
				assert.are.equal(1, restarts(client))
			end)
		end)

		it("waits for RestrictionChanged(false) to put the device back and restart (QOL-R66, QOL-R68)", function()
			local fake, client, loaded = startDevices(function(fake)
				tick(fake, "Output device", "Headset")
			end)
			local setLockdown = lockdownOf(loaded)
			fake.fire("CastStarted")
			client.cvarCalls = {}

			setLockdown(true)
			fake.setRestricted(true)
			assert.are.equal("2", client.cvars.Sound_OutputDriverIndex)
			assert.are.same({}, client.cvarCalls)

			setLockdown(false)
			fake.setRestricted(false)
			assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
			assert.are.same({ "restart sound" }, { client.cvarCalls[#client.cvarCalls] })
			assert.are.equal(1, restarts(client))
		end)

		it(
			"puts a device left in global.lease back at ADDON_LOADED, restarting the sound system (QOL-R64, QOL-R68)",
			function()
				local fake = newFakePagle()
				local loaded = fake.load("Pagle_QoL", { holdAddonLoaded = true })
				loaded.env.PagleQoLDB = {
					global = {
						schemaVersion = 1,
						lease = { { name = "Sound_OutputDriverIndex", orig = "1", set = "2" } },
					},
				}
				loaded.client.cvars = { Sound_OutputDriverIndex = "2" }

				loaded.client.fire("ADDON_LOADED", "Pagle_QoL")

				assert.are.same({ "set Sound_OutputDriverIndex 1", "restart sound" }, loaded.client.cvarCalls)
				assert.are.same({}, leaseOf(loaded))
			end
		)

		it(
			"puts the device back without a restart at logout or /reload, as the client reloads sound (QOL-R68)",
			function()
				local fake, client = startDevices(function(fake)
					tick(fake, "Output device", "Headset")
				end)
				fake.fire("CastStarted")
				client.cvarCalls = {}

				fake.fireGameEvent("PLAYER_LOGOUT")

				assert.are.equal("1", client.cvars.Sound_OutputDriverIndex)
				assert.are.same({ "set Sound_OutputDriverIndex 1" }, callsOn(client, "Sound_OutputDriverIndex"))
				assert.are.equal(0, restarts(client))
			end
		)

		it("puts the player's own device back by name after the devices reordered (QOL-R68)", function()
			local fake, client, loaded = startDevices(function(fake)
				tick(fake, "Output device", "Headset")
			end)
			fake.fire("CastStarted")
			local named
			for _, entry in ipairs(leaseOf(loaded)) do
				if entry.name == "Sound_OutputDriverIndex" then
					named = entry.origName
				end
			end
			assert.are.equal("Speakers", named)
			-- A monitor's speakers appear before the player's, which move from index 1 to 2.
			client.outputDevices = { "System Default", "Monitor", "Speakers", "Headset" }
			client.cvars.Sound_OutputDriverIndex = "2"
			client.cvarCalls = {}

			client.mounted = true
			fake.fireGameEvent("PLAYER_MOUNT_DISPLAY_CHANGED")

			assert.are.equal("2", client.cvars.Sound_OutputDriverIndex)
		end)

		it(
			"puts a leftover device back by name at ADDON_LOADED, or by its index when it's gone (QOL-R64, QOL-R68)",
			function()
				for _, case in ipairs({
					{ { "System Default", "Monitor", "Speakers", "Headset" }, "2" },
					{ { "System Default", "Headset" }, "1" },
				}) do
					local fake = newFakePagle()
					local loaded = fake.load("Pagle_QoL", { holdAddonLoaded = true })
					loaded.env.PagleQoLDB = {
						global = {
							schemaVersion = 1,
							lease = {
								{ name = "Sound_OutputDriverIndex", orig = "1", set = "3", origName = "Speakers" },
							},
						},
					}
					loaded.client.outputDevices = case[1]
					loaded.client.cvars = { Sound_OutputDriverIndex = "3" }

					loaded.client.fire("ADDON_LOADED", "Pagle_QoL")

					assert.are.equal(case[2], loaded.client.cvars.Sound_OutputDriverIndex)
					assert.are.same({}, leaseOf(loaded))
				end
			end
		)

		it("leases no device while QoL stands down (QOL-R82, QOL-R68)", function()
			local fake, client = startDevices(function(fake, _, loaded)
				tick(fake, "Output device", "Headset")
				loaded.ns.IsArmed = function()
					return false
				end
			end)

			fake.fire("CastStarted")

			assert.are.same({}, client.cvarCalls)
		end)
	end)
end)

describe("The Fishing stretch with Core", function()
	-- QoL on the real Core, logged in and holding a pole, with the player's own CVar values.
	local function startWithCore(values)
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		loaded.client.mainHand = FISHING_POLE
		loaded.client.cvars = values
		loaded.client.fire("PLAYER_LOGIN")
		return loaded, loaded.client
	end

	it("restores at PLAYER_LOGOUT, whichever frame hears it first (QOL-R61, QOL-R63)", function()
		local loaded, client = startWithCore(playerValues())
		loaded.namespaces.Pagle.Fire("CastStarted")
		assert.are.same(LEASED, client.cvars)

		client.fire("PLAYER_LOGOUT")

		assert.are.same(playerValues(), client.cvars)
		assert.are.same({}, loaded.env.PagleQoLDB.global.lease or {})
	end)

	it("handles PLAYER_LOGOUT with nothing leased, after AceDB has dropped the empty lease (QOL-R61)", function()
		local loaded, client = startWithCore({
			SoftTargetInteract = "3",
			SoftTargetInteractRange = "60",
			SoftTargetInteractRangeIsHard = "0",
		})
		loaded.namespaces.Pagle.Fire("CastStarted")

		assert.has_no_error(function()
			client.fire("PLAYER_LOGOUT")
		end)
		assert.are.same({}, client.cvarCalls)
	end)
end)

-- The client names output devices in the Windows code page, not UTF-8: "Kopfhörer" comes as "Kopfh\246rer", a lone
-- 0xF6 the font draws as a box (#597). The dropdown shows each name readable; its value stays the client's bytes, so
-- the saved choice and the match by name (ns.OutputDeviceIndex) don't change (QOL-R68).
describe("A device name as the dropdown shows it (QOL-R68, #597)", function()
	local function readable(text)
		return newFakePagle().load("Pagle_QoL").ns.ReadableText(text)
	end

	it("leaves valid UTF-8 byte for byte: ASCII, Latin, Cyrillic, CJK and four-byte characters", function()
		for _, text in ipairs({
			"Speakers (Realtek(R) Audio)",
			"Kopfh\195\182rer (2- ATH-M50xSTS-USB)",
			"\208\157\208\176\209\131\209\136\208\189\208\184\208\186\208\184",
			"\232\128\179\230\156\186",
			"Headset \240\159\142\167",
		}) do
			assert.are.equal(text, readable(text))
		end
	end)

	it("reads a name that isn't UTF-8 as Windows-1252", function()
		assert.are.equal("Kopfh\195\182rer (2- ATH-M50xSTS-USB)", readable("Kopfh\246rer (2- ATH-M50xSTS-USB)"))
		assert.are.equal("Haut-parleurs \195\169t\195\169", readable("Haut-parleurs \233t\233"))
		-- 0x80–0x9F are Windows-1252's own: € – ™
		assert.are.equal("\226\130\172 \226\128\147 \226\132\162", readable("\128 \150 \153"))
	end)

	it("keeps the valid UTF-8 of a mixed name and reads only the bytes outside it as Windows-1252", function()
		-- ruRU's "(not found)" around a Windows-1252 name, as the missing device's label is
		local missing = "Kopfh\246rer (\208\189\208\181\209\130)"
		assert.are.equal("Kopfh\195\182rer (\208\189\208\181\209\130)", readable(missing))
		-- a cut-off, an overlong and a surrogate sequence aren't UTF-8 either: Ã, À€, í €
		assert.are.equal("a\195\131", readable("a\195"))
		assert.are.equal("\195\128\226\130\172", readable("\192\128"))
		assert.are.equal("\195\173\194\160\226\130\172", readable("\237\160\128"))
	end)

	it("shows a byte Windows-1252 leaves undefined as ?", function()
		assert.are.equal("a?b?", readable("a\129b\157"))
	end)

	it("leaves an empty name empty", function()
		assert.are.equal("", readable(""))
	end)

	it("labels each device readable in QoL's Output device row, keeping the client's bytes as its value", function()
		local loaded = loadAddon("Pagle_QoL", FOREVER_GLOBALS)
		local raw = "Kopfh\246rer (2- ATH-M50xSTS-USB)"
		loaded.client.outputDevices = { "System Default", raw }
		loaded.client.fire("PLAYER_LOGIN")
		local settings = loaded.client.settings
		local function deviceRow()
			return settings.rowNamed(settings.show(assert(settings.category("Fishing"))), "Output device")
		end

		local row = deviceRow()
		row.initializer:GetSetting():SetValue(raw)

		local shown = {}
		for i, option in ipairs(row.initializer:GetOptions()()) do
			shown[i] = { option.value, option.label }
		end
		assert.are.same({
			{ "", "Don't change" },
			{ "System Default", "System Default" },
			{ raw, "Kopfh\195\182rer (2- ATH-M50xSTS-USB)" },
		}, shown)
		assert.are.equal(raw, loaded.ns.db.profile.audio.device)

		-- unplugged, it stays chosen and is listed as not found, readable too
		loaded.client.outputDevices = { "System Default" }
		local options = deviceRow().initializer:GetOptions()()
		assert.are.same(
			{ raw, "Kopfh\195\182rer (2- ATH-M50xSTS-USB) (not found)" },
			{ options[#options].value, options[#options].label }
		)
		assert.are.equal(raw, loaded.ns.db.profile.audio.device)
	end)
end)
