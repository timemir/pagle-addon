---@diagnostic disable-next-line: undefined-global -- fixture JSON is read by stock Lua 5.1 specs, never the client
local json = require("dkjson")
---@diagnostic disable-next-line: undefined-global -- TEST ONLY public key fixtures run on stock Lua 5.1
local signing = dofile("spec/Pagle/fixtures/Signing.lua")
---@diagnostic disable-next-line: undefined-global -- specs execute the generated data file on stock Lua 5.1
local fixtureFile = loadfile
local vectors = assert(json.decode(readFile("spec/fixtures/recovery-snapshot-v1.json"))).vectors
local function original()
	return {
		logId = "0123456789abcdef",
		format = 3,
		characters = {
			{
				guid = "Player-4618-0A1B2C3D",
				name = "Ada",
				surname = "Brook",
				classID = 1,
				raceID = 1,
				faction = "Alliance",
				realmID = 4618,
				hardcore = false,
				firstSeen = 1792422000,
				lastSeen = 1793000000,
				selfFound = false,
			},
		},
		entries = { "B1|1|1792422000|0|70338|1.60.1|pagle-2026a" },
	}
end

describe("Recovery through the addon", function()
	it("exports the full local snapshot using the independent backend byte vectors", function()
		local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
		for _, vector in ipairs(vectors) do
			local log = original()
			if vector.name == "nil-selfFound" then
				log.characters[1].selfFound = nil
			end
			if vector.name == "false-test" then
				log.test = false
			end
			if vector.name == "unicode" then
				log.characters[1].name = "Bé"
			end
			local snapshot = loaded.ns.RecoverySnapshot(log)
			assert.are.equal(assert(loaded.ns.Base64Decode(vector.snapshot)), snapshot)
			assert.are.equal("PGLR1|1|1|" .. vector.snapshot, loaded.ns.RecoveryExport(log))
		end
	end)
	it("loads staged Recovery before opening the log and preserves the original branch", function()
		local fixture = assert(json.decode(readFile("spec/fixtures/recovery-signed-v1.json")))
		local log = original()
		log.entries[2] = "S1|1|1793000001|0|80|150|0"
		log.entries[3] = "U1|1|1793000002|0|some.good|25"
		log.futureField = { nested = { "keep me" } }
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), { holdAddonLoaded = true })
		loaded.ns.PUSHED_KEYS.testKey = signing.testKey
		loaded.client.addons.Pagle_Recovery = {
			loaded = false,
			load = function()
				assert.is_nil(loaded.ns.db)
				loaded.env.PagleRecoveryData =
					{ v = 1, keyId = fixture.good.keyId, payload = fixture.good.payload, sig = fixture.good.sig }
			end,
		}
		loaded.client.fire("ADDON_LOADED", "Pagle")
		assert.are.same({ "Pagle_Recovery" }, loaded.client.loads)
		assert.are.equal(2, loaded.ns.loginSeq)
		assert.are.equal(
			assert(loaded.ns.Base64Decode(fixture.replacement)),
			loaded.ns.RecoverySnapshot(loaded.env.PagleLog)
		)
		local archive = loaded.env.PagleRecovery.archives[fixture.good.applicationId]
		assert.are.same(log, archive.original)
		assert.are_not.equal(log, archive.original)
		assert.are.same({ { seq = 3, reason = "action_requires_review" } }, archive.staged)
		assert.are.equal(fixture.good.applicationId, loaded.env.PagleRecovery.completed.applicationId)
		assert.are.equal(fixture.replacementDigest, loaded.env.PagleRecovery.completed.resultDigest)
	end)

	it("offers complete numbered snapshots and staged original records through the manual command", function()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = original() }))
		loaded.env.SlashCmdList.PAGLE("recovery export")
		local window = loaded.ns.recoveryWindow
		assert.is_true(window:IsShown())
		assert.are.equal("PGLR1|1|1|" .. vectors[1].snapshot, window.paste:GetText())
		loaded.env.PagleRecovery = {
			completed = { applicationId = "example" },
			archives = {
				example = {
					original = { entries = { "raw|original|record" } },
					staged = { { seq = 1, reason = "source_invalid" } },
				},
			},
		}
		loaded.env.SlashCmdList.PAGLE("recovery inspect")
		assert.are.equal("Record 1 · source_invalid", window.line:GetText())
		assert.are.equal("raw|original|record", window.paste:GetText())
	end)

	it("reads the independent backend-generated Recovery.lua through the explicit addon load", function()
		local fixture = assert(json.decode(readFile("spec/fixtures/recovery-backend-v1.json")))
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = original() }), { holdAddonLoaded = true })
		loaded.ns.PUSHED_KEYS.testKey = signing.testKey
		loaded.client.addons.Pagle_Recovery = {
			loaded = false,
			load = function()
				local file = assert(fixtureFile("spec/Pagle/fixtures/Recovery.lua"))
				setfenv(file, loaded.env)
				file()
			end,
		}
		loaded.client.fire("ADDON_LOADED", "Pagle")
		assert.are.equal(fixture.applicationId, loaded.env.PagleRecovery.completed.applicationId)
		assert.are.equal(1, loaded.ns.loginSeq)
	end)

	it("refuses changed full snapshots before normal startup can alter the log", function()
		local fixture = assert(json.decode(readFile("spec/fixtures/recovery-backend-v1.json")))
		for _, change in ipairs({
			function(log)
				log.characters[1].selfFound = nil
			end,
			function(log)
				log.test = false
			end,
			function(log)
				log.characters[1].name = "Another name"
			end,
			function(log)
				log.entries[2] = "S1|1|1793000001|0|80|150|0"
			end,
		}) do
			local log = original()
			change(log)
			local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), { holdAddonLoaded = true })
			loaded.ns.PUSHED_KEYS.testKey = signing.testKey
			loaded.client.addons.Pagle_Recovery = {
				loaded = false,
				load = function()
					loaded.env.PagleRecoveryData =
						{ v = 1, keyId = fixture.keyId, payload = fixture.payload, sig = fixture.signature }
				end,
			}
			loaded.client.fire("ADDON_LOADED", "Pagle")
			loaded.client.fire("PLAYER_LOGIN")
			loaded.client.fire("PLAYER_ENTERING_WORLD")
			loaded.client.fire("PLAYER_LOGOUT")
			assert.is_nil(loaded.ns.db)
			assert.is_nil(loaded.env.PagleRecovery)
			assert.are.equal(log, loaded.env.PagleLog)
			assert.is_true(loaded.ns.recoveryBlocked)
			assert.are.same({}, loaded.client.errors)
			loaded.env.SlashCmdList.PAGLE("recovery export")
			assert.is_true(loaded.ns.recoveryWindow:IsShown())
		end
	end)

	it("refuses signed invalid domains, targets, digests, checkpoints and staged reasons without mutation", function()
		local fixture = assert(json.decode(readFile("spec/fixtures/recovery-signed-v1.json")))
		for _, name in ipairs({
			"wrongDomain",
			"wrongTarget",
			"wrongDigest",
			"wrongCheckpoint",
			"trailing",
			"unknownReason",
		}) do
			local log = original()
			log.entries[2] = "S1|1|1793000001|0|80|150|0"
			log.entries[3] = "U1|1|1793000002|0|some.good|25"
			local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), { holdAddonLoaded = true })
			loaded.ns.PUSHED_KEYS.testKey = signing.testKey
			loaded.client.addons.Pagle_Recovery = {
				loaded = false,
				load = function()
					local data = fixture[name]
					loaded.env.PagleRecoveryData = { v = 1, keyId = data.keyId, payload = data.payload, sig = data.sig }
				end,
			}
			loaded.client.fire("ADDON_LOADED", "Pagle")
			assert.is_true(loaded.ns.recoveryBlocked)
			assert.are.equal(log, loaded.env.PagleLog)
			assert.is_nil(loaded.env.PagleRecovery)
		end
	end)

	it("keeps a completed plan harmless after normal login entries and later reloads", function()
		local fixture = assert(json.decode(readFile("spec/fixtures/recovery-backend-v1.json")))
		local function boot(globals)
			local loaded = loadAddon("Pagle", foreverWith(globals), { holdAddonLoaded = true })
			loaded.ns.PUSHED_KEYS.testKey = signing.testKey
			loaded.client.addons.Pagle_Recovery = {
				loaded = false,
				load = function()
					loaded.env.PagleRecoveryData =
						{ v = 1, keyId = fixture.keyId, payload = fixture.payload, sig = fixture.signature }
				end,
			}
			loaded.client.fire("ADDON_LOADED", "Pagle")
			loaded.client.fire("PLAYER_LOGIN")
			loaded.client.fire("PLAYER_ENTERING_WORLD")
			loaded.client.advance(1)
			return loaded
		end
		local first = boot({ PagleLog = original() })
		assert.is_true(#first.env.PagleLog.entries > 1)
		local archive = first.env.PagleRecovery.archives[fixture.applicationId]
		local second = boot({
			PagleLog = first.env.PagleLog,
			PagleDB = first.env.PagleDB,
			PagleRecovery = first.env.PagleRecovery,
		})
		assert.is_nil(second.ns.recoveryBlocked)
		assert.are.equal(archive, second.env.PagleRecovery.archives[fixture.applicationId])
		assert.are.same(original(), archive.original)
		assert.are.same({}, first.client.errors)
		assert.are.same({}, second.client.errors)
	end)

	it("restores Refresh totals and Collection ownership from the restored history before Modules load", function()
		local seeded = original()
		seeded.entries[2] = "U1|1|1792422001|0|core.toaststyle.ripple|30"
		local first = loadAddon("Pagle", foreverWith({ PagleLog = seeded }))
		first.client.fire("PLAYER_LOGIN")
		first.client.fire("PLAYER_ENTERING_WORLD")
		first.client.advance(5)
		assert.is_true(first.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.are.equal(1792422001, first.env.Pagle.GetGood("core.toaststyle.ripple").ownedAt)
		local saved = first.env.PagleDB
		saved.global.tickets = { logId = seeded.logId, earned = { absentModule = 9 }, spent = { absentModule = 4 } }
		local restored = loadAddon("Pagle", foreverWith({ PagleLog = original(), PagleDB = saved }), {
			beforeLoaded = {
				Pagle = function(ns, client, env)
					ns.PUSHED_KEYS.testKey = signing.testKey
					client.addons.Pagle_Recovery = {
						loaded = false,
						load = function()
							local file = assert(fixtureFile("spec/Pagle/fixtures/Recovery.lua"))
							setfenv(file, env)
							file()
						end,
					}
				end,
			},
		})
		assert.are.same({ tickets = 0, earned = 0, spent = 0 }, restored.env.Pagle.GetTickets())
		assert.is_false(restored.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.is_nil(restored.env.Pagle.GetGood("core.toaststyle.ripple").ownedAt)
		restored.client.fire("PLAYER_LOGIN")
		restored.client.fire("PLAYER_ENTERING_WORLD")
		restored.client.advance(5)
		assert.are.same({ tickets = 0, earned = 0, spent = 0 }, restored.env.Pagle.GetTickets())
		assert.is_false(restored.env.Pagle.IsOwned("core.toaststyle.ripple"))
		assert.is_nil(restored.env.Pagle.GetGood("core.toaststyle.ripple").ownedAt)
		assert.are.same({}, first.client.errors)
		assert.are.same({}, restored.client.errors)
	end)

	it("rebuilds every enabled Module and invalidates caches for Modules enabled on a later login", function()
		local modules = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_Stats" }
		local seeded = original()
		seeded.entries[2] = castEntry(1792422001)
		local first = loadAddon("Pagle", foreverWith({ PagleLog = seeded }), { also = modules })
		first.client.fire("PLAYER_LOGIN")
		first.client.fire("PLAYER_ENTERING_WORLD")
		first.client.advance(5)
		assert.are.equal(1, first.namespaces.Pagle_Ledger.projection:GetState().catches)
		assert.are.equal(1, first.namespaces.Pagle_Hunts.projection:GetState().casts)
		assert.is_truthy(next(first.namespaces.Pagle_TackleBoard.projection:GetState().caught))
		assert.are.equal(1, first.namespaces.Pagle_Stats.projection:GetState().totals.catches)
		local cached = {}
		for _, name in ipairs({ "PagleDB", "PagleLedgerDB", "PagleHuntsDB", "PagleTackleBoardDB", "PagleStatsDB" }) do
			cached[name] = first.env[name]
		end
		cached.PagleLog = original()
		cached.PagleDB.global.catchCounts = { stale = true }
		cached.PagleDB.global.sessionBreaks = { stale = true }
		cached.PagleDB.global.lastBuild = { logId = cached.PagleLog.logId, build = 99999, rules = "old" }
		cached.PagleDB.global.lastEndedSession = "old session"
		cached.PagleDB.global.coins.earned.absentModule = 9999
		cached.PagleDB.global.activityXP.earned.absentModule = 9999
		local rebuilt = loadAddon("Pagle", foreverWith(cached), {
			also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_TackleBoard" },
			beforeLoaded = {
				Pagle = function(ns, client, env)
					ns.PUSHED_KEYS.testKey = signing.testKey
					client.addons.Pagle_Recovery = {
						loaded = false,
						load = function()
							local file = assert(fixtureFile("spec/Pagle/fixtures/Recovery.lua"))
							setfenv(file, env)
							file()
						end,
					}
				end,
			},
		})
		assert.is_nil(rebuilt.env.PagleDB.global.lastBuild)
		assert.is_nil(rebuilt.env.PagleDB.global.lastEndedSession)
		rebuilt.client.fire("PLAYER_LOGIN")
		rebuilt.client.fire("PLAYER_ENTERING_WORLD")
		rebuilt.client.advance(5)
		assert.are.equal(0, rebuilt.namespaces.Pagle_Ledger.projection:GetState().catches)
		assert.are.equal(0, rebuilt.namespaces.Pagle_Hunts.projection:GetState().casts)
		assert.is_nil(next(rebuilt.namespaces.Pagle_TackleBoard.projection:GetState().caught))
		assert.is_nil(rebuilt.env.PagleDB.global.catchCounts.stale)
		assert.is_nil(rebuilt.env.PagleDB.global.sessionBreaks)
		assert.is_nil(rebuilt.env.PagleDB.global.coins.earned.absentModule)
		assert.is_nil(rebuilt.env.PagleDB.global.activityXP.earned.absentModule)
		for _, name in ipairs({ "PagleLedgerDB", "PagleHuntsDB", "PagleTackleBoardDB" }) do
			local store = rebuilt.env[name].global
			store = store.board or store.projection
			assert.is_truthy(store.fingerprint:find("|recovery:", 1, true))
		end
		assert.is_nil(cached.PagleStatsDB.global.projection.fingerprint:find("|recovery:", 1, true))
		local again = { PagleLog = rebuilt.env.PagleLog, PagleRecovery = rebuilt.env.PagleRecovery }
		for _, name in ipairs({ "PagleDB", "PagleLedgerDB", "PagleHuntsDB", "PagleTackleBoardDB", "PagleStatsDB" }) do
			again[name] = rebuilt.env[name] or cached[name]
		end
		local later = loadAddon("Pagle", foreverWith(again), { also = modules })
		later.client.fire("PLAYER_LOGIN")
		later.client.fire("PLAYER_ENTERING_WORLD")
		later.client.advance(5)
		assert.are.equal(0, later.namespaces.Pagle_Stats.projection:GetState().totals.catches)
		assert.are.same({}, first.client.errors)
		assert.are.same({}, rebuilt.client.errors)
		assert.are.same({}, later.client.errors)
	end)
	it("refuses invalid character text rather than emitting a snapshot the website cannot read", function()
		local log = original()
		log.characters[1].name = "Ada" .. string.char(255)
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
		loaded.env.SlashCmdList.PAGLE("recovery export")
		assert.is_true(loaded.ns.recoveryWindow == nil)
		assert.is_truthy(loaded.printed[#loaded.printed]:find("export unavailable", 1, true))
	end)

	it("stops before opening SavedVariables when discovery or a partially installed data addon fails", function()
		local log = original()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), { holdAddonLoaded = true })
		loaded.client.addons.Pagle_Recovery = {
			loaded = false,
			load = function()
				error("interrupted data file")
			end,
		}
		loaded.client.fire("ADDON_LOADED", "Pagle")
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD")
		assert.is_true(loaded.ns.recoveryBlocked == true)
		assert.are.equal(log, loaded.env.PagleLog)
		assert.is_nil(loaded.env.PagleRecovery)
		assert.is_nil(loaded.ns.db)
		assert.are.same({}, loaded.client.errors)
	end)

	it("keeps an old completed package harmless after a different Recovery", function()
		local fixtures = assert(json.decode(readFile("spec/fixtures/recovery-signed-v1.json")))
		local function boot(log, archive, name)
			local loaded =
				loadAddon("Pagle", foreverWith({ PagleLog = log, PagleRecovery = archive }), { holdAddonLoaded = true })
			loaded.ns.PUSHED_KEYS.testKey = signing.testKey
			local data = fixtures[name]
			loaded.client.addons.Pagle_Recovery = {
				loaded = false,
				load = function()
					loaded.env.PagleRecoveryData = { v = 1, keyId = data.keyId, payload = data.payload, sig = data.sig }
				end,
			}
			loaded.client.fire("ADDON_LOADED", "Pagle")
			return loaded
		end
		local log = original()
		log.entries[2] = "S1|1|1793000001|0|80|150|0"
		log.entries[3] = "U1|1|1793000002|0|some.good|25"
		local first = boot(log, nil, "good")
		local second = boot(first.env.PagleLog, first.env.PagleRecovery, "second")
		assert.are.equal(fixtures.second.applicationId, second.env.PagleRecovery.completed.applicationId)
		local later = boot(second.env.PagleLog, second.env.PagleRecovery, "good")
		assert.is_true(later.ns.recoveryBlocked == nil)
		assert.are.equal(fixtures.second.applicationId, later.env.PagleRecovery.completed.applicationId)
		assert.are.same(original(), later.env.PagleLog)
	end)

	it("lets a Mac player copy every numbered part of a full snapshot", function()
		local fixture = assert(json.decode(readFile("spec/fixtures/recovery-signed-v1.json")))
		local log = original()
		for i = 1, 1500 do
			log.entries[i] = log.entries[1]
		end
		local loaded = loadAddon(
			"Pagle",
			foreverWith({
				PagleLog = log,
				IsMacClient = function()
					return true
				end,
			})
		)
		loaded.env.SlashCmdList.PAGLE("recovery export")
		local window, fragments = loaded.ns.recoveryWindow, {}
		local total
		repeat
			local part, count, bytes = window.paste:GetText():match("^PGLR1|(%d+)|(%d+)|(.+)$")
			total = tonumber(count)
			assert.is_true(#bytes <= 65536)
			fragments[tonumber(part)] = bytes
			if window.part < total then
				window.next:Click()
			else
				break
			end
		until false
		assert.is_true(total > 1)
		local decoded = assert(loaded.ns.Base64Decode(table.concat(fragments)))
		assert.are.equal(fixture.multipartSha256, loaded.ns.RecoveryDigest(decoded))
		assert.are.same({}, loaded.ns.db.global.pasteExports)
	end)
	it("keeps enabled Modules inert when the full snapshot guard refuses Recovery", function()
		local log = original()
		log.test = false
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), {
			also = { "Pagle_Ledger", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_Stats", "Pagle_QoL" },
			beforeLoaded = {
				Pagle = function(ns, client, env)
					ns.PUSHED_KEYS.testKey = signing.testKey
					client.addons.Pagle_Recovery = {
						loaded = false,
						load = function()
							local file = assert(fixtureFile("spec/Pagle/fixtures/Recovery.lua"))
							setfenv(file, env)
							file()
						end,
					}
				end,
			},
		})
		loaded.client.fire("PLAYER_LOGIN")
		loaded.client.fire("PLAYER_ENTERING_WORLD")
		loaded.client.advance(5)
		assert.is_true(loaded.ns.recoveryBlocked)
		assert.are.equal(log, loaded.env.PagleLog)
		for _, module in ipairs({ "Ledger", "Hunts", "TackleBoard", "Stats", "QoL" }) do
			assert.is_nil(loaded.namespaces["Pagle_" .. module].db)
		end
		assert.are.same({}, loaded.client.errors)
	end)

	it("rejects oversized local logs without offering a partial Recovery export", function()
		local log = original()
		for i = 2, 100001 do
			log.entries[i] = log.entries[1]
		end
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
		loaded.env.SlashCmdList.PAGLE("recovery export")
		assert.is_true(loaded.ns.recoveryWindow == nil)
		assert.is_truthy(loaded.printed[#loaded.printed]:find("export unavailable", 1, true))
	end)
	it("rejects a 16 MiB entry when the complete source or replacement snapshot exceeds the byte limit", function()
		local log = original()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
		local entry = string.rep("x", 16 * 1024 * 1024)
		local prefix = loaded.ns.RecoverySnapshot(log):match("^(.*)" .. #log.entries[1] .. ":")
		local snapshot = assert(prefix) .. #entry .. ":" .. entry .. ","
		log.entries[1] = entry
		assert.has_error(function()
			loaded.ns.RecoverySnapshot(log)
		end, "snapshot too large")
		assert.has_error(function()
			loaded.ns.RecoveryReadSnapshot(snapshot)
		end, "snapshot too large")
		assert.are.equal(log, loaded.env.PagleLog)
	end)
	it("rejects packages above the 24 MiB DATA allowance before decoding or checking their signature", function()
		local log = original()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
		local data = {
			v = 1,
			keyId = "testKey",
			payload = string.rep("!", 32 * 1024 * 1024 + 4),
			sig = string.rep("!", 344),
		}
		assert.has_error(function()
			loaded.ns.RecoveryPrepare(data, { testKey = signing.testKey }, log, nil, nil)
		end, "Recovery payload too large")
		assert.are.equal(log, loaded.env.PagleLog)
		assert.is_nil(loaded.env.PagleRecovery)
	end)
	it("preserves records held by the backend's recovery capacity limit", function()
		local fixtures = assert(json.decode(readFile("spec/fixtures/recovery-signed-v1.json")))
		local log = original()
		log.entries[2] = "S1|1|1793000001|0|80|150|0"
		log.entries[3] = "U1|1|1793000002|0|some.good|25"
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }), { holdAddonLoaded = true })
		loaded.ns.PUSHED_KEYS.testKey = signing.testKey
		local data = fixtures.capacity
		loaded.client.addons.Pagle_Recovery = {
			loaded = false,
			load = function()
				loaded.env.PagleRecoveryData = { v = 1, keyId = data.keyId, payload = data.payload, sig = data.sig }
			end,
		}
		loaded.client.fire("ADDON_LOADED", "Pagle")
		assert.is_true(loaded.ns.recoveryBlocked == nil)
		local archive = loaded.env.PagleRecovery.archives[data.applicationId]
		assert.are.equal("capacity_limit", archive.staged[1].reason)
		assert.are.equal(log.entries[3], archive.original.entries[3])
	end)

	it("exports exact opaque local record bytes for backend staging", function()
		local fixtures = assert(json.decode(readFile("spec/fixtures/recovery-signed-v1.json")))
		local log = original()
		log.entries[2] = "Unknown|bad bytes"
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = log }))
		loaded.env.SlashCmdList.PAGLE("recovery export")
		local encoded = assert(loaded.ns.recoveryWindow.paste:GetText():match("^PGLR1|1|1|(.+)$"))
		local snapshot = assert(loaded.ns.Base64Decode(encoded))
		assert.are.equal(fixtures.opaqueSnapshotSha256, loaded.ns.RecoveryDigest(snapshot))
		assert.are.equal("Unknown|bad bytes", loaded.ns.RecoveryReadSnapshot(snapshot).entries[2])
	end)
end)
