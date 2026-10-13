-- scripts/read-wtf.lua against fixture WTF folders under spec/scripts/fixtures/WTF/, written the way the client
-- writes them (CRLF line ends, the client's SavedVariables layout). M1#1 holds a Catch log and a !BugGrabber file
-- with several sessions, M0#1 a client where Pagle saves nothing yet, Code#1 files that must not run as code. M2#1
-- and M2-Stale#1 hold a Pagle_Ledger.lua as well, for the Ledger, Wallet and Cards sections the M2 exit check reads
-- (#103, #104).

local ACCOUNTS = "spec/scripts/fixtures/WTF/Account/"

--- Runs the script as `lua scripts/read-wtf.lua <args>` would, and returns its output lines, what it wrote to
--- stderr, and its exit code.
---@return string[] out, string err, integer code
local function run(...)
	local out, err, code = {}, {}, nil
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
	local chunk = assert(loadfile("scripts/read-wtf.lua"))
	local env = setmetatable({
		arg = { [0] = "scripts/read-wtf.lua", ... },
		print = function(line)
			out[#out + 1] = line
		end,
		io = setmetatable({
			stderr = {
				write = function(_, text)
					err[#err + 1] = text
				end,
			},
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		}, { __index = io }),
		os = setmetatable({
			exit = function(status)
				code = status
			end,
		}, { __index = os }),
	}, { __index = _G })
	setfenv(chunk, env)
	chunk(...)
	return out, table.concat(err), code
end

--- The output lines from the one that starts with `heading` up to the next `==` heading.
local function section(out, heading)
	local lines
	for _, line in ipairs(out) do
		if lines and line:sub(1, 2) == "==" then
			break
		end
		if line:sub(1, #heading) == heading then
			lines = {}
		end
		if lines then
			lines[#lines + 1] = line
		end
	end
	return lines
end

describe("scripts/read-wtf.lua", function()
	describe("on an account after an M1 stretch", function()
		local out, err, code = run(
			ACCOUNTS .. "M1#1",
			"--character",
			"70/Ada-Brook",
			"--cvar",
			"SoftTargetInteract",
			"--cvar",
			"softtargetinteractarc",
			"--cvar",
			"autoLootDefault",
			"--cvar",
			"cameraSavedDistance",
			"--cvar",
			"nameplateShowAll",
			"--addon",
			"Pagle",
			"--addon",
			"pagle_qol",
			"--addon",
			"BugSack"
		)

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("prints only the latest !BugGrabber session's errors, each with its count and stack", function()
			assert.are.same({
				"== Lua errors (!BugGrabber, latest session 5): 2 errors",
				"1. Interface/AddOns/Pagle/adapter/Core.lua:40: attempt to index local 'cast' (a nil value) (x3)",
				"   [Interface/AddOns/Pagle/adapter/Core.lua]:40: in function 'OnCastEnd'",
				"   [Interface/AddOns/Pagle/adapter/Core.lua]:88: in function <Interface/AddOns/Pagle/adapter/Core.lua:80>",
				"2. LUA_WARNING: Interface/AddOns/Pagle_QoL/Pagle_QoL.lua:1 a warning with no stack",
				"   (no stack)",
			}, section(out, "== Lua errors"))
		end)

		it("prints the PagleLog and PagleDB facts the M1 exit check asks for, read with Core's codec (#75)", function()
			-- A1 is a tag M1's codec doesn't read yet, so it counts as undecodable with the line that has no tag
			-- (LOG-R16).
			assert.are.same({
				"== Catch log (PagleLog): format 1, logId 3f9a2c1e7b0d4a65, 1 character, 11 entries",
				"PagleDB.global.decodeErrors: 0",
				"entries by tag: (no tag) 1, A1 1, B1 1, C1 6, S1 2",
				"entries Core's codec can't decode: 2",
				"repeated entry IDs: Player-4618-0A1B2C3D-1791731900-0",
				"C1: 6 Casts, from 2026-10-11 15:15:47 UTC to 2026-10-11 15:45:47 UTC (30 min)",
				"C1 outcomes: caught 5, got away 1",
				"C1 by character:",
				"  1 Ada Brook (Player-4618-0A1B2C3D): caught 5, got away 1",
				"C1 by zone areaID:",
				"  0: caught 2",
				"  148: caught 2, got away 1",
				"  1519: caught 1",
				"zone areaID 0: 2 Casts, seq 7, 8",
				"B1: 1 entry, the last build 70338 (1.60.1)",
				"S1: 2 entries, the last rank 86, max 150, mod 25 (character 1)",
			}, section(out, "== Catch log"))
		end)

		it("prints each named CVar from every file that sets it, ignoring the name's case", function()
			assert.are.same({
				"== CVars, from Config.wtf, account config-cache.wtf, 70/Ada-Brook/config-cache.wtf",
				'SoftTargetInteract: "3" in account config-cache.wtf',
				'softtargetinteractarc: "2" in account config-cache.wtf',
				'autoLootDefault: "0" in Config.wtf, "1" in account config-cache.wtf',
				'cameraSavedDistance: "19.879097" in 70/Ada-Brook/config-cache.wtf',
				"nameplateShowAll: not set (the client's default applies)",
			}, section(out, "== CVars"))
		end)

		it("prints each named addon's state from the character's AddOns.txt, ignoring the name's case", function()
			assert.are.same({
				"== Addons (70/Ada-Brook/AddOns.txt)",
				"Pagle: enabled",
				"pagle_qol: disabled",
				"BugSack: not listed (its TOC's default state applies)",
			}, section(out, "== Addons"))
		end)
	end)

	-- M2#1 holds the three files the M2 exit check reads (#104): Pagle.lua, Pagle_Ledger.lua and the character's
	-- AddOns.txt, with a Ledger built over the whole Catch log, Coins reported, and a Write-up and cards waiting.
	describe("on an account after the M2 exit check's steps", function()
		local out, err, code = run(ACCOUNTS .. "M2#1", "--character", "70/Ada-Brook")

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("prints the Ledger's projection, state and celebrated set, with the level from its own logic", function()
			-- LOG-R70's stored values; LED-R30's level: 2,310 XP = 1,080 (1→2) + 1,160 (2→3) + 70 into level 3,
			-- whose step costs 1,000 + 80 × 3 = 1,240. ledger.md › Data for the state and the celebrated set.
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 8, logId 5d2e8a0c4b1f7e93, fingerprint a1b2c3d4, rulesVersion 100",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (8 entries)",
				"state: 5 Casts, 4 Catches, 2310 XP (Angler Level 3, 70 into it, next step 1240), 30 Coins, 2 Species",
				"celebrated: highest level 3, 30 Coins",
				"celebrated Species: 2 (6303, 6358)",
				"celebrated Species × zone pairs: 2 (6303:1519, 6358:148)",
				"celebrated zones: 2 (148 rank 0, 1519 rank 0)",
				"celebrated Skill Milestones: 1 (75)",
			}, section(out, "== Ledger"))
		end)

		it("prints each Module's reported total and the balance (SHOP-R3, SHOP-R12)", function()
			-- Nothing spends before the Curio Shop (M4), so the balance is 30 + 12.
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 42",
				"Hunts: 12",
				"Ledger: 30",
			}, section(out, "== Wallet"))
		end)

		it("prints the waiting Write-up, the cards, and the open summary and pending moments", function()
			-- announcements.md › Data. A card from a whileAway SessionEnded is titled "Your last session" (ANN-R54).
			assert.are.same({
				"== Cards (PagleDB.global)",
				"writeUp: 1 section",
				"  Ledger: Your Ledger was written up from 5 Casts",
				"    Angler Level 3",
				"    2 Species",
				"    Pagle Coins +30",
				"cards: 2",
				"  1. Session summary: 4 Casts, 3 Catches, 1 got away, 1800 s, 10 Coins",
				"    line: Ledger: Angler Level 3",
				"    Ledger moments: New Species, New here",
				"  2. Your last session: 1 Cast, 1 Catch, 0 got away, 0 s, 0 Coins",
				"    Ledger moments: Skill Milestone",
				"summary: 1 moment",
				"  line: Ledger: Angler Level 3",
				"pending: 1 moment",
			}, section(out, "== Cards"))
		end)
	end)

	-- M2-Stale#1: PagleLog was started anew (LOG-R18) after the Ledger last stored its projection, and AceDB left the
	-- defaults out of both files (no celebrated set, no Coins, no cards).
	describe("on an account whose Ledger was built over another log", function()
		local out, _, code = run(ACCOUNTS .. "M2-Stale#1")

		it("flags the logId and the length that differ from PagleLog's (LOG-R72)", function()
			assert.are.equal(0, code)
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 8, logId 5d2e8a0c4b1f7e93, fingerprint a1b2c3d4, rulesVersion 100",
				"logId: DIFFERS from PagleLog's 7c0b19e4d3a2f658, so Core rebuilds it at login (LOG-R72)",
				"lastSeq: differs from PagleLog's length (1 entry)",
				"state: 0 Casts, 0 Catches, 0 XP (Angler Level 1, 0 into it, next step 1080), 0 Coins, 0 Species",
				"celebrated: highest level none, 0 Coins",
				"celebrated Species: none",
				"celebrated Species × zone pairs: none",
				"celebrated zones: none",
				"celebrated Skill Milestones: none",
			}, section(out, "== Ledger"))
		end)

		it("reads a PagleDB with no coins as no Module having reported (AceDB leaves out the empty default)", function()
			assert.are.same(
				{ "== Wallet (PagleDB.global.coins.earned): balance 0, no Module has reported Coins" },
				section(out, "== Wallet")
			)
		end)

		it("reads a PagleDB with no Write-up, cards, summary or pending as having none", function()
			assert.are.same({
				"== Cards (PagleDB.global)",
				"writeUp: none",
				"cards: none",
				"summary: 0 moments",
				"pending: 0 moments",
			}, section(out, "== Cards"))
		end)
	end)

	it("says in one line that Pagle_Ledger.lua is missing", function()
		local out = run(ACCOUNTS .. "M1#1")
		assert.are.same(
			{ "== Ledger: can't read " .. ACCOUNTS .. "M1#1/SavedVariables/Pagle_Ledger.lua: missing" },
			section(out, "== Ledger")
		)
	end)

	describe("with only an account folder", function()
		local out, _, code = run(ACCOUNTS .. "M0#1/")

		it("says the latest session has no errors, ignoring older sessions' errors", function()
			assert.are.equal(0, code)
			assert.are.same(
				{ "== Lua errors (!BugGrabber, latest session 9): 0 errors" },
				section(out, "== Lua errors")
			)
		end)

		it("says Pagle.lua is missing when Pagle has saved nothing", function()
			assert.are.same(
				{ "== Catch log: can't read " .. ACCOUNTS .. "M0#1/SavedVariables/Pagle.lua: missing" },
				section(out, "== Catch log")
			)
		end)

		it("reads SoftTargetInteract by default, and says the character's files need --character", function()
			assert.are.same({
				"== CVars, from Config.wtf, account config-cache.wtf; the character's config-cache.wtf needs --character",
				"SoftTargetInteract: not set (the client's default applies)",
			}, section(out, "== CVars"))
			assert.are.same(
				{ "== Addons: enable state needs --character <realm folder>/<Name-Surname>" },
				section(out, "== Addons")
			)
		end)
	end)

	it("reads Pagle, Pagle_Ledger and Pagle_QoL's enable state by default", function()
		local out = run(ACCOUNTS .. "M2#1", "--character", "70/Ada-Brook/")
		assert.are.same({
			"== Addons (70/Ada-Brook/AddOns.txt)",
			"Pagle: enabled",
			"Pagle_Ledger: enabled",
			"Pagle_QoL: disabled",
		}, section(out, "== Addons"))
	end)

	describe("on SavedVariables files that hold code", function()
		local out, _, code = run(ACCOUNTS .. "Code#1")

		it("runs a file with no globals, so a call fails instead of running", function()
			assert.are.equal(0, code)
			assert.are.same({
				"== Lua errors: can't read "
					.. ACCOUNTS
					.. "Code#1/SavedVariables/!BugGrabber.lua: !BugGrabber.lua:1: attempt to call global 'print' (a nil value)",
			}, section(out, "== Lua errors"))
		end)

		it("refuses a precompiled chunk", function()
			assert.are.same({
				"== Catch log: can't read "
					.. ACCOUNTS
					.. "Code#1/SavedVariables/Pagle.lua: a precompiled chunk, not data",
			}, section(out, "== Catch log"))
		end)
	end)

	describe("on a usage error", function()
		for case, args in pairs({
			["no account folder"] = {},
			["an unknown option"] = { ACCOUNTS .. "M1#1", "--bogus" },
			["an option with no value"] = { ACCOUNTS .. "M1#1", "--cvar" },
			["two account folders"] = { ACCOUNTS .. "M1#1", ACCOUNTS .. "M0#1" },
		}) do
			it("exits 2, prints nothing and writes the usage to stderr, given " .. case, function()
				local out, err, code = run(unpack(args))
				assert.are.equal(2, code)
				assert.are.same({}, out)
				assert.matches("^read%-wtf: .+\nusage: lua scripts/read%-wtf%.lua ", err)
			end)
		end
	end)

	it("prints the usage on --help and exits 0", function()
		local out, err, code = run("--help")
		assert.are.equal(0, code)
		assert.are.equal("", err)
		assert.matches("^usage: lua scripts/read%-wtf%.lua ", out[1])
	end)
end)
