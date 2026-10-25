-- scripts/read-wtf.lua against fixture WTF folders under spec/scripts/fixtures/WTF/, written the way the client
-- writes them (CRLF line ends, the client's SavedVariables layout). M1#1 holds a Catch log and a !BugGrabber file
-- with several sessions, M0#1 a client where Pagle saves nothing yet, Code#1 files that must not run as code. M2#1
-- and M2-Stale#1 hold a Pagle_Ledger.lua as well, for the Ledger, Wallet and Cards sections the M2 exit check reads
-- (#103, #104). M3#1 holds an M3 Ledger and a Field report projection, for what the M3 exit check reads (#145,
-- #146). M4#1 holds what the M4 exit check reads (#173, #174). M5#1 and M5-Stale#1 hold a Pagle_Hunts.lua, for what
-- the M5 exit check reads (#199, #200). M6#1, M6-Stale#1 and M6-New#1 hold a Pagle_Stats.lua, for what the M6 exit
-- check reads (#219, #221), and M6-Break#1 a Session break (#258). M7#1, M7-Stale#1 and M7-New#1 hold a Pagle_TackleBoard.lua, for what the M7 exit check
-- reads (#242, #245). M8#1 holds a test log for the Simulated Size gate (#267), and M8-Probe#1 a `/pagle dev probe` with a miss in most checks, for the Probe section (#261), and M8-Reverify#1 what the Re-verification section reads (#262), and M8.5#1 an onboarding state for the Onboarding section (#320), and M8-XP#1 Activity XP totals and a P1 with its snapshot, for the Activity XP section (#291), and M8-Wagers#1 Hunts' runs, records and ladder, a Ledger climb past a Prestige snapshot and a pushed seq, for what the M8 Hunt Events exit check reads (#309). The Ledger, Stats and Tackle Board runs read their catalogue from
-- spec/scripts/fixtures/Catalogue.lua (--catalogue) and the Hunts runs their Hunt list from
-- spec/scripts/fixtures/HuntList.lua (--huntlist), so the lines the Modules' logic computes are counted by hand, and
-- don't move with the generated data.

local ACCOUNTS = "spec/scripts/fixtures/WTF/Account/"
local CATALOGUE = "spec/scripts/fixtures/Catalogue.lua"
local HUNTLIST = "spec/scripts/fixtures/HuntList.lua"
local EVENTLIST = "spec/scripts/fixtures/EventList.lua"

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local script = dofile("spec/support/script.lua")

--- The content fingerprint a generated data file in the repo carries (DATA-R70, DATA-R72): its `fingerprint = "…"`.
---@param path string
---@return string
local function repoFingerprint(path)
	return (assert(readFile(path):match('fingerprint = "(%x+)"'), path .. " carries no fingerprint"))
end

--- Runs the script as `lua scripts/read-wtf.lua <args>` would, and returns its output lines, what it wrote to
--- stderr, and its exit code.
---@return string[] out, string err, integer code
local function run(...)
	return script.run("scripts/read-wtf.lua", { ... })
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

--- The first of `lines` that starts with `prefix`, or nil.
local function lineStarting(lines, prefix)
	for _, line in ipairs(lines or {}) do
		if line:sub(1, #prefix) == prefix then
			return line
		end
	end
	return nil
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
			-- The A1 is a Module record Core's codec reads (LOG-R40): it counts by its tag, and only the line that has
			-- no tag is undecodable (LOG-R16).
			assert.are.same({
				"== Catch log (PagleLog): format 2, logId 3f9a2c1e7b0d4a65, 1 character, 11 entries",
				"PagleDB.global.decodeErrors: 0",
				"entries by tag: (no tag) 1, A1 1, B1 1, C1 6, S1 2",
				"entries Core's codec can't decode: 1",
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
				-- The latest Cast: realm minute 524 (08:44) at 15:45:47 UTC, a US Pacific realm (LOG-R49).
				"realm clock: UTC-07:00 (from the latest Cast)",
				"B1: 1 entry, the last build 70338 (1.60.1)",
				"S1: 2 entries, the last rank 86, max 150, mod 25 (character 1)",
				"P1: none",
				"U1: none",
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
		local out, err, code = run(ACCOUNTS .. "M2#1", "--character", "70/Ada-Brook", "--catalogue", CATALOGUE)

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("prints the Ledger's projection, state and celebrated set, with the level from its own logic", function()
			-- LOG-R70's stored values; LED-R30's level: 2,310 XP = 1,080 (1→2) + 1,160 (2→3) + 70 into level 3,
			-- whose step costs 1,000 + 80 × 3 = 1,240. ledger.md › Data for the state and the celebrated set. An M2
			-- state has no items, Uncharted list or zone ranks, and M2's rules version, 100, isn't the Ledger's 1002 (LED-R2:
			-- LEDGER_RULES_VERSION 9 × 100 + Core's SIZE_RULES_VERSION 2, LOG-R68).
			-- Completion over the fixture catalogue's world (LED-R70, LED-R71): Species 6303 and 6358 caught, of 6291,
			-- 6299, 6303 and 13759 listed and 6358 caught; nothing else; 2 of 11 is 18%. 148 and 1519 aren't charted.
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 8, logId 5d2e8a0c4b1f7e93, fingerprint a1b2c3d4, rulesVersion 100",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (8 entries)",
				"rulesVersion: 100 DIFFERS from the Ledger's 1002, so Core rebuilds it at login (LED-R2, LOG-R72)",
				"world: "
					.. CATALOGUE
					.. ", fingerprint 0123456789abcdef (NOT the projection's: the lines computed below use it), 2 charted zones",
				"state: 5 Casts, 4 Catches, 2310 XP (Angler Level 3, 70 into it, next step 1240), 30 Coins, 2 Species",
				"state curio items: none",
				"state trophy items: none",
				"state Uncharted: none",
				"state zones: 2",
				"  148: rank none, not charted, shown 0",
				"  1519: rank none, not charted, shown 0",
				"completion: 18% (2 of 11): Species 2 of 5, varieties 0 of 0, junk 0 of 1, treasure 0 of 1, trophy 0 of 2, zones 0 of 2;"
					.. " Legends 0 of 1",
				"celebrated: highest level 3, 30 Coins",
				"celebrated Species: 2 (6303, 6358)",
				"celebrated Species × zone pairs: 2 (6303:1519, 6358:148)",
				"celebrated zones: 2 (148 rank 0, 1519 rank 0)",
				"celebrated Species stars: none",
				"celebrated family stars: none",
				"celebrated curio items: none",
				"celebrated trophy items: none",
				"celebrated Uncharted: none",
				"celebrated Skill Milestones: 1 (75)",
			}, section(out, "== Ledger"))
		end)

		it("prints each Module's reported total and the balance (SHOP-R3, SHOP-R12)", function()
			-- Nothing spends before the Curio Shop (M4), so the balance is 30 + 12, and there's no wallet projection
			-- (SHOP-R11) yet. SHOP-R3: a PagleDB from before M8 stores no logId with its totals.
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 42",
				"Hunts: 12",
				"Ledger: 30",
				"logId: none stored (a fresh log's, or no Module has reported since PagleLog had one)",
				"wallet projection: none stored (no build has finished, LOG-R72)",
			}, section(out, "== Wallet"))
		end)

		it("says in one line that no variety projection is stored yet (VAR-R10)", function()
			assert.are.same({
				"== Varieties (PagleDB.global.projections.varieties): none stored (no build has finished, LOG-R72)",
			}, section(out, "== Varieties"))
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
		local out, _, code = run(ACCOUNTS .. "M2-Stale#1", "--catalogue", CATALOGUE)

		it("flags the logId and the length that differ from PagleLog's (LOG-R72)", function()
			assert.are.equal(0, code)
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 8, logId 5d2e8a0c4b1f7e93, fingerprint a1b2c3d4, rulesVersion 100",
				"logId: DIFFERS from PagleLog's 7c0b19e4d3a2f658, so Core rebuilds it at login (LOG-R72)",
				"lastSeq: differs from PagleLog's length (1 entry)",
				"rulesVersion: 100 DIFFERS from the Ledger's 1002, so Core rebuilds it at login (LED-R2, LOG-R72)",
				"world: "
					.. CATALOGUE
					.. ", fingerprint 0123456789abcdef (NOT the projection's: the lines computed below use it), 2 charted zones",
				"state: 0 Casts, 0 Catches, 0 XP (Angler Level 1, 0 into it, next step 1080), 0 Coins, 0 Species",
				"state curio items: none",
				"state trophy items: none",
				"state Uncharted: none",
				"state zones: none",
				"completion: 0% (0 of 10): Species 0 of 4, varieties 0 of 0, junk 0 of 1, treasure 0 of 1, trophy 0 of 2, zones 0 of 2;"
					.. " Legends 0 of 1",
				"celebrated: highest level none, 0 Coins",
				"celebrated Species: none",
				"celebrated Species × zone pairs: none",
				"celebrated zones: none",
				"celebrated Species stars: none",
				"celebrated family stars: none",
				"celebrated curio items: none",
				"celebrated trophy items: none",
				"celebrated Uncharted: none",
				"celebrated Skill Milestones: none",
			}, section(out, "== Ledger"))
		end)

		it("reads a PagleDB with no coins as no Module having reported (AceDB leaves out the empty default)", function()
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 0, no Module has reported Coins",
				"logId: none stored (a fresh log's, or no Module has reported since PagleLog had one)",
				"wallet projection: none stored (no build has finished, LOG-R72)",
			}, section(out, "== Wallet"))
		end)

		it("reads a PagleDB with no goods, looks or length unit as all defaults (AceDB leaves them out)", function()
			-- SHOP-R32: no stored pick is the default look; LOG-R69: no stored unit is the region's.
			assert.are.same({
				"== Looks (PagleDB.profile.appearance, PagleDB.global.goods)",
				"slots: none cached or stored, so every look is its slot's default",
				"goods cached: 0",
				"earned goods: none",
				"length unit: region default",
			}, section(out, "== Looks"))
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

	-- M3#1 holds what the M3 exit check reads (#146): a Ledger built with M3's fold (curio and trophy items, the
	-- Uncharted list, zone ranks) and its celebrated set, and Core's Field report projection. Its Ledger is read
	-- against spec/scripts/fixtures/Catalogue.lua, a world small enough to count by hand.
	describe("on an account after the M3 exit check's steps (#146)", function()
		local out, err, code = run(ACCOUNTS .. "M3#1", "--catalogue", CATALOGUE)

		it("exits 0 and writes nothing to stderr (LED-R2, REP-R25: every M3 section reads)", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it(
			"prints M3's state and celebrated set, with ranks and completion from the Ledger's logic (LED-R4, LED-R5, LED-R30,"
				.. " LED-R50, LED-R52, LED-R54, LED-R63, LED-R70, LED-R71, LED-R92)",
			function()
				-- ledger.md › Data for the state and the celebrated set; LED-R4: M3's rules version, 200, isn't the Ledger's 1002.
				-- LED-R30: 4,560 XP = 1,080 + 1,160 + 1,240 to level 4, 1,080 into it, whose step costs
				-- 1,000 + 80 × 4 = 1,320. LED-R5: 6309 is junk, a curio; 13901 a trophy; 999001 is in no catalogue.
				-- LED-R50, LED-R54: Duskwood (10) has no data, so it isn't charted and shows rank 0; Elwynn (12) is computed Local (3) but celebrated Expert (4), and the
				-- shown rank is the higher (LED-R52, LED-R92). LED-R70, LED-R71: Species 6291 and 6303 of 6291, 6299, 6303
				-- and 13759; junk 6309 of 6309; treasure none of 6351; trophy 13901 of 13901 and 13902; no zone at Master
				-- of 12 and 40; 4 of 10 is 40%; Legend 19803 beside it (LED-R63).
				assert.are.same({
					"== Ledger (PagleLedgerDB)",
					"projection: lastSeq 11, logId 3f9a2c1e7b0d4a65, fingerprint 0123456789abcdef, rulesVersion 200",
					"logId: matches PagleLog's",
					"lastSeq: equals PagleLog's length (11 entries)",
					"rulesVersion: 200 DIFFERS from the Ledger's 1002, so Core rebuilds it at login (LED-R2, LOG-R72)",
					"world: " .. CATALOGUE .. ", fingerprint 0123456789abcdef (the projection's), 2 charted zones",
					"state: 9 Casts, 8 Catches, 4560 XP (Angler Level 4, 1080 into it, next step 1320), 44 Coins, 2 Species",
					"state curio items: 1 (6309 ×2)",
					"state trophy items: 1 (13901 ×1)",
					"state Uncharted: 1 item",
					"  999001: 2 Catches, zones 10 ×1, 12 ×1",
					"state zones: 3",
					"  10: rank 0, not charted, shown 0",
					"  12: rank 3, charted, shown 4",
					"  40: rank 1, charted, shown 1",
					"completion: 40% (4 of 10): Species 2 of 4, varieties 0 of 0, junk 1 of 1, treasure 0 of 1, trophy 1 of 2, zones 0 of 2;"
						.. " Legends 0 of 1",
					"celebrated: highest level 4, 44 Coins",
					"celebrated Species: 2 (6291, 6303)",
					"celebrated Species × zone pairs: 3 (6291:12, 6303:12, 6303:40)",
					"celebrated zones: 3 (10 rank 0, 12 rank 4, 40 rank 1)",
					"celebrated Species stars: 3 on 2 Species (6291 ★1, 6303 ★1 ★2)",
					"celebrated family stars: 1 on 1 family (1 ★1)",
					"celebrated curio items: 1 (6309)",
					"celebrated trophy items: 1 (13901)",
					"celebrated Uncharted: 1 (999001)",
					"celebrated Skill Milestones: 1 (75)",
				}, section(out, "== Ledger"))
			end
		)

		it("reads the repo's catalogue by default, and flags one that isn't the projection's (DATA-R70)", function()
			-- DATA-R70: the generated file carries the content fingerprint the client's projections are built against.
			local fingerprint = repoFingerprint("addons/Pagle/data/Catalogue.lua")
			local world = section(run(ACCOUNTS .. "M3#1"), "== Ledger")[6]
			local prefix = "world: the repo's addons/Pagle/data/Catalogue.lua, fingerprint "
				.. fingerprint
				.. " (NOT the projection's: the lines computed below use it), "
			assert.are.equal(prefix, world:sub(1, #prefix))
			assert.matches("^%d+ charted zones$", world:sub(#prefix + 1))
		end)

		it("says so and prints the stored lines alone when the catalogue can't be loaded (LED-R10, LED-R5)", function()
			local missing = "spec/scripts/fixtures/no-such-Catalogue.lua"
			local lines = section(run(ACCOUNTS .. "M3#1", "--catalogue", missing), "== Ledger")
			assert.are.equal("world: can't load " .. missing, lines[6]:sub(1, #missing + 18))
			-- Without a world (LED-R10) nothing classes the items (LED-R5), and no zone has a charted flag or a shown rank,
			-- and there's no completion; the stored values and the celebrated set are all still there.
			assert.are.same({
				"state: 9 Casts, 8 Catches, 4560 XP (Angler Level 4, 1080 into it, next step 1320), 44 Coins, 2 Species",
				"state items, not classed: 2 (6309 ×2, 13901 ×1)",
				"state Uncharted: 1 item",
				"  999001: 2 Catches, zones 10 ×1, 12 ×1",
				"state zones: 3",
				"  10: rank 0",
				"  12: rank 3",
				"  40: rank 1",
				"celebrated: highest level 4, 44 Coins",
			}, { unpack(lines, 7, 15) })
			assert.are.equal("celebrated items, not classed: 2 (6309, 13901)", lines[21])
		end)

		it("prints the Field report projection, its count and reporter key (REP-R25, REP-R26, REP-R36)", function()
			-- REP-R36's test vector: logId 3f9a2c1e7b0d4a65 gives f38e76b0. REP-R22, REP-R26: the buffer holds three
			-- Casts, so 2 P rows: Floating Wreckage in Elwynn (12), and Oily Blackmouth School in Westfall (40), whose
			-- two Casts (one got away) make one row. The menu's count is the 3 stored rows plus those 2.
			assert.are.same({
				"== Field report (PagleDB.global.projections.fieldReport): reporter key f38e76b0",
				"projection: lastSeq 11, logId 3f9a2c1e7b0d4a65, fingerprint 0123456789abcdef, rulesVersion 1",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (11 entries)",
				'count: 3 I and K rows stored + 2 P rows from the buffer = 5 (the menu\'s "(5)", REP-R26)',
			}, section(out, "== Field report"))
		end)
	end)

	-- M4#1 holds what the M4 exit check reads (#173, #174): a log with a Prestige (P1) and two purchases (U1), a
	-- Ledger one Prestige in with a Catch Milestone, a Legend, size records and titles, the wallet projection, the
	-- goods cache and the equipped looks. Read against spec/scripts/fixtures/Catalogue.lua, where 19803 is a Legend.
	describe("on an account after the M4 exit check's steps", function()
		local out, err, code = run(ACCOUNTS .. "M4#1", "--catalogue", CATALOGUE, "--item", "6303", "--item", "19803")

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("counts and lists the Prestige and purchase entries (LOG-R38, LOG-R39)", function()
			-- catch-log.md › Entry formats: P1 carries the new rank and Activity XP (none in this pre-1.0 P1, so 0,
			-- AXP-R5), U1 the good and the price paid. Two U1s, each listed.
			local log = section(out, "== Catch log")
			assert.are.same({
				"P1: 1 entry",
				"  rank 1, 0 Activity XP, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-12 10:20:00 UTC",
				"U1: 2 entries",
				"  core.toaststyle.ripple for 150 Coins, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-12 10:21:40 UTC",
				"  core.soundset.gilded for 400 Coins, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-12 10:23:20 UTC",
			}, { unpack(log, #log - 4) })
			assert.are.equal("entries by tag: B1 1, C1 4, P1 1, S1 1, U1 2", log[3])
			assert.are.equal("entries Core's codec can't decode: none", log[4])
		end)

		it(
			"prints an M4 projection as one to rebuild, and leaves its Legend out of the curio and trophy items",
			function()
				-- LED-R2: 401 = LEDGER_RULES_VERSION 4 × 100 + Core's SIZE_RULES_VERSION 1 (LOG-R68), and the Ledger's is
				-- 1002 since the Reach, the varieties caught, the second round's counts, the crest times and the rise times, the fish of each race and faction (LED-R164, LED-R4, ADR 0014, VAR-R20, LED-R118, LED-R155, LED-R158). LED-R30 at prestige rank 1,
				-- the Ledger's logic at the full cost: 1,080 to level 2, 920 into it, whose step costs 1,160. LED-R5:
				-- 19803 is a Legend, neither curio nor trophy (LED-R63). LED-R70: Species 6291 and 6303 of 6291, 6299, 6303
				-- and 13759 (19803, a Legend, is outside it), junk 1 of 1, treasure 0 of 1, trophy 1 of 2, no zone at
				-- Master: 4 of 10 is 40%; Legends 1 of 1.
				local ledger = section(out, "== Ledger (PagleLedgerDB)")
				assert.are.same({
					"== Ledger (PagleLedgerDB)",
					"projection: lastSeq 9, logId 8e1d4b7a2c6f0935, fingerprint 0123456789abcdef, rulesVersion 401",
					"logId: matches PagleLog's",
					"lastSeq: equals PagleLog's length (9 entries)",
					"rulesVersion: 401 DIFFERS from the Ledger's 1002, so Core rebuilds it at login (LED-R2, LOG-R72)",
					"world: " .. CATALOGUE .. ", fingerprint 0123456789abcdef (the projection's), 2 charted zones",
					"state: 1004 Casts, 1003 Catches, 2000 XP (Angler Level 2, 920 into it, next step 1160), 900 Coins,"
						.. " 2 Species",
					"state curio items: 1 (6309 ×3)",
					"state trophy items: 1 (13901 ×1)",
					"state Uncharted: none",
					"state zones: 2",
					"  12: rank 3, charted, shown 3",
					"  40: rank 1, charted, shown 1",
					"completion: 40% (4 of 10): Species 2 of 4, varieties 0 of 0, junk 1 of 1, treasure 0 of 1, trophy 1 of 2, zones 0 of 2;"
						.. " Legends 1 of 1",
				}, { unpack(ledger, 1, 14) })
			end
		)

		it("prints the climb, milestones, Legends, records, --item's records and titles (LED-R30–R85)", function()
			-- LED-R30, LED-R35: level 2 at rank 1 (above), peak level 60 once ranked. LED-R42: the 1,000 milestone.
			-- LED-R63, LED-R80: the Legend's first Catch and its record on its items entry; 6303's record, and 6291 has
			-- none. LOG-R67: band 3 is Hefty, band 4 Whopper. LED-R75, LED-R76: computed (peak 60's seven level
			-- titles, prestige1, the Legend's, complete.junk with 6309 of 6309) plus the celebrated keys, in LED-R75's
			-- order. LED-R77: the stored key is earned, so it's the active title. LED-R90: the celebrated set's M4 keys.
			assert.are.same({
				"== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles",
				"climb: prestige rank 1, 2000 XP of its own, Prestige snapshot 0, the climb's Activity XP 0 (Core's stored"
					.. " total 0 − 0, LED-R37), computed level 2, peak level 60",
				"Catch Milestones: 1 (1000 at 2026-10-12 10:22:40 UTC), 1003 lifetime Catches",
				"Legends caught: 1 (19803 ×1, first at 2026-10-12 10:15:20 UTC by character 1 in zone 40)",
				"records: 1 of 2 Species, 1 Legend",
				"record of 6303 (Species): 342 mm, band 3 Hefty, Catch Player-4618-0A1B2C3D-1791800560-0:1, since 4",
				"record of 19803 (Legend): 1820 mm, band 4 Whopper, Catch Player-4618-0A1B2C3D-1791800120-0:1, since 0",
				"titles earned: 10 (title:level1, title:level10, title:level20, title:level30, title:level40,"
					.. " title:level50, title:level60, title:prestige1, legend:19803, title:complete.junk)",
				"active title: legend:19803 (profile.activeTitle)",
				"celebrated levels: prestige rank 0 level 60, prestige rank 1 level 4",
				"celebrated prestige: 1",
				"celebrated Catch Milestones: 1 (1000)",
				"celebrated titles: 8 (title:level10, title:level20, title:level30, title:level40, title:level50,"
					.. " title:level60, title:prestige1, legend:19803)",
				"celebrated Legend items: 1 (19803)",
				-- LOG-R65: the fixture catalogue gives no Species a typical length, so nothing is sized.
				"sizes: no Catch has a Simulated Size (LOG-R65), from PagleLog over " .. CATALOGUE,
			}, section(out, "== Ledger M4"))
		end)

		it("prints the wallet projection and a balance held while earned < spent (SHOP-R11, SHOP-R12)", function()
			-- 500 earned − (150 + 400) spent is −50: the balance shows 0, held (SHOP-R12). Each good counted once, the
			-- wallet rules version 1 is Core's (wallet-and-shop.md › Data), and the projection is current (LOG-R72).
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 0, held (500 earned − 550 spent = -50, SHOP-R12)",
				"Ledger: 500",
				"logId: none stored (a fresh log's, or no Module has reported since PagleLog had one)",
				"projection: lastSeq 9, logId 8e1d4b7a2c6f0935, fingerprint 0123456789abcdef, rulesVersion 1",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (9 entries)",
				"rulesVersion: Core's wallet rules, 1",
				"spent: 550",
				"purchased: 2 (core.soundset.gilded, core.toaststyle.ripple)",
			}, section(out, "== Wallet"))
		end)

		it(
			"prints Core's variety projection: the Species with all ten and each one's positions caught (VAR-R10)",
			function()
				-- The Oily Blackmouth (6358) in all ten, the Firefin Snapper (6359) in positions 1, 3 and 10: 13
				-- varieties, one Species with all ten (its fish crest's, VAR-R12). The variety rules version 1 is
				-- Core's (varieties.md › Data), and the projection is current (LOG-R72).
				assert.are.same({
					"== Varieties (PagleDB.global.projections.varieties): 1 Species with all ten, 13 varieties caught",
					"projection: lastSeq 9, logId 8e1d4b7a2c6f0935, fingerprint 0123456789abcdef, rulesVersion 1",
					"logId: matches PagleLog's",
					"lastSeq: equals PagleLog's length (9 entries)",
					"rulesVersion: Core's variety rules, 1",
					"caught: 2 (6358 10 of 10 (1 2 3 4 5 6 7 8 9 10), 6359 3 of 10 (1 3 10))",
				}, section(out, "== Varieties"))
			end
		)

		it("prints each slot's look, the goods cache and the length unit (SHOP-R26, SHOP-R32, LOG-R69)", function()
			-- SHOP-R32: a slot with no stored pick shows its default; the slots are the cached goods' and the stored
			-- picks'. SHOP-R26: 8 goods cached, two of them earned goods, one cached as earned. LOG-R69: "in" stored.
			assert.are.same({
				"== Looks (PagleDB.profile.appearance, PagleDB.global.goods)",
				"core.crest: default (core.crest.plain)",
				"core.soundset: default (core.soundset.driftwood)",
				"core.toaststyle: core.toaststyle.ripple",
				"ledger.binding: ledger.binding.level10",
				"goods cached: 8",
				"earned goods: 2, cached as earned: 1 (ledger.binding.level10)",
				"length unit: in",
			}, section(out, "== Looks"))
		end)

		it("prints the stored M4 lines and the celebrated titles alone when the catalogue can't be loaded", function()
			-- Without a world (LED-R10) nothing classes an item as a Legend (LED-R5) or computes a title (LED-R75); the
			-- celebrated titles are still earned (LED-R76), so the stored active title is too (LED-R77).
			local missing = "spec/scripts/fixtures/no-such-Catalogue.lua"
			local lines = section(run(ACCOUNTS .. "M4#1", "--catalogue", missing, "--item", "19803"), "== Ledger M4")
			local celebratedTitles = "8 (title:level10, title:level20, title:level30, title:level40, title:level50,"
				.. " title:level60, title:prestige1, legend:19803)"
			assert.are.same({
				"== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles",
				"climb: prestige rank 1, 2000 XP of its own, Prestige snapshot 0, the climb's Activity XP 0 (Core's stored"
					.. " total 0 − 0, LED-R37), computed level 2, peak level 60",
				"Catch Milestones: 1 (1000 at 2026-10-12 10:22:40 UTC), 1003 lifetime Catches",
				"Legends caught: can't be told from the other items without the world (see world: above)",
				"records: 1 of 2 Species, 1 Legend",
				"record of 19803 (item): 1820 mm, band 4 Whopper, Catch Player-4618-0A1B2C3D-1791800120-0:1, since 0",
				"titles earned: "
					.. celebratedTitles
					.. ", the celebrated ones only (no state or no world to compute from)",
				"active title: legend:19803 (profile.activeTitle)",
				"celebrated levels: prestige rank 0 level 60, prestige rank 1 level 4",
				"celebrated prestige: 1",
				"celebrated Catch Milestones: 1 (1000)",
				"celebrated titles: " .. celebratedTitles,
				"celebrated Legend items: can't be told from the other items without the world (see world: above)",
				("sizes: can't load %s: cannot open %s: No such file or directory"):format(missing, missing),
			}, lines)
		end)
	end)

	-- M8#1 holds a test log for the Simulated Size gate (#267): make-test-log's catches1000 preset over M4#1 and
	-- spec/scripts/fixtures/TestLogCatalogue.lua, whose Species carry typical lengths, beside a Ledger that has never
	-- built. Its 995 Casts catch three Species, 569 times in all.
	describe("on a test log's account, for the Simulated Size gate (#267)", function()
		local TEST_CATALOGUE = "spec/scripts/fixtures/TestLogCatalogue.lua"

		it("prints the sized Catches by band and per Species, from Core's Size.lua (LOG-R65–R67)", function()
			-- Counted by an independent reading of LOG-R65–R67 over the log's C1 and S1 entries (FNV-1a, fmix32, each
			-- Cast's skill rank and its item's earlier Catches, the Reach, the band edges): a test log of 995 Casts at
			-- skill 150 never reaches past Hefty. The draw is frozen (ADR 0014), so these counts never move.
			local out, err, code = run(ACCOUNTS .. "M8#1", "--catalogue", TEST_CATALOGUE)
			assert.are.equal(0, code)
			assert.are.equal("", err)
			local m4 = section(out, "== Ledger M4")
			local first
			for i, line in ipairs(m4) do
				first = first or (line:sub(1, 6) == "sizes:" and i or nil)
			end
			assert.are.same({
				"sizes: 569 Catches with a Simulated Size, of 3 Species (LOG-R65), from PagleLog over "
					.. TEST_CATALOGUE,
				"sizes by band: Catches (their share), each bounded by its Reach (LOG-R67)",
				"  1 Tiddler: 166 (29.2%)",
				"  2 Decent: 382 (67.1%)",
				"  3 Hefty: 21 (3.7%)",
				"  4 Whopper: 0 (0.0%)",
				"  5 Monster: 0 (0.0%)",
				"sizes per Species: Catches, shortest–longest, typical length (DATA-R20)",
				"  6291: 142 Catches, 165–301 mm, typical 300 mm",
				"  6299: 142 Catches, 138–253 mm, typical 250 mm",
				"  6303: 285 Catches, 193–411 mm, typical 350 mm",
			}, { unpack(m4, first) })
		end)

		it("says in one line when no LuaBitOp is there to hash the Catch IDs with (LOG-R66)", function()
			local function noBit(name)
				if name == "bit" then
					error("module 'bit' not found")
				end
				return require(name)
			end
			local out = script.run(
				"scripts/read-wtf.lua",
				{ ACCOUNTS .. "M8#1", "--catalogue", TEST_CATALOGUE },
				{ globals = { require = noBit } }
			)
			local m4 = section(out, "== Ledger M4")
			assert.are.equal(
				"sizes: no LuaBitOp to hash the Catch IDs with (LOG-R66): run scripts/setup.sh, then this through"
					.. " scripts/read-wtf.sh",
				m4[#m4]
			)
		end)

		it("says in one line when the catalogue can't be loaded", function()
			local missing = "spec/scripts/fixtures/no-such-Catalogue.lua"
			local m4 = section(run(ACCOUNTS .. "M8#1", "--catalogue", missing), "== Ledger M4")
			assert.matches("^sizes: can't load " .. missing:gsub("%p", "%%%0") .. ": ", m4[#m4])
		end)
	end)

	-- M5#1 holds what the M5 exit check reads (#199, #200): a Hunts projection with tiers, a title from a Catch and
	-- one from a retirement, a celebrated set behind the state, pins (one on a Retired Hunt), saved profile settings,
	-- a moved tracker dock, the Hunts slots' goods and Hunts' lines in the wallet and the cards. Read against
	-- spec/scripts/fixtures/HuntList.lua (--huntlist) and spec/scripts/fixtures/Catalogue.lua at --now 1792000000,
	-- 2026-10-14 17:46:40 UTC.
	describe("on an account after the M5 exit check's steps (#199, in-game-verification.md › Hunts)", function()
		local NOW = "1792000000"
		local out, err, code = run(
			ACCOUNTS .. "M5#1",
			"--catalogue",
			CATALOGUE,
			"--huntlist",
			HUNTLIST,
			"--eventlist",
			EVENTLIST,
			"--now",
			NOW,
			"--hunt",
			"night_run"
		)

		it("exits 0 and writes nothing to stderr (#199, in-game-verification.md › Hunts)", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it(
			"prints the projection, state, titles, celebrated set, pins and profile (LOG-R70, HNT-R89, HNT-R136, DATA-R72)",
			function()
				-- LOG-R70's stored values; HNT-R136: Hunts' rules version is 2 with Hunt Events (Tunables); DATA-R72,
				-- DATA-R98: the stored fingerprint is the catalogue's plus the Hunt list's and the event pool's (the
				-- --eventlist fixture's). hunts.md › Projection state for the state.
				-- HNT-R2, HNT-R3: at --now night_run, first_light, rack_hour and dawn_trout are current, grouper_by_moonlight
				-- is retired, witching_hour isn't out (so it has no line). HNT-R89: 3 of the 4 current Hunts are done
				-- (HNT-R17), 2 titles earned. HNT-R18: tier 1 bronze, tier 2 silver. HNT-R23: camp_hours came from a Catch,
				-- pagles_wagers from grouper_by_moonlight's retirement (dated its UTC day). HNT-R90: night_run's tier 2 and
				-- pagles_wagers aren't celebrated yet. HNT-R81: the pin on the Retired Hunt is dropped at load. hunts.md ›
				-- PagleHuntsDB: tracker.shown and showCompleted are left out at their defaults (AceDB), and so are Hunt
				-- Events' settings. An M5 state has no runs, ladder or Activity XP (HNT-R148, HNT-R150), and its PagleDB
				-- no Activity XP totals (AXP-R3); --now is before the rotation's starting point (HNT-R152).
				assert.are.same({
					"== Hunts (PagleHuntsDB)",
					"records: no Hunts A1 entries in PagleLog",
					"projection: lastSeq 6, logId 6c2f9e0a1b3d5e77, fingerprint"
						.. " 0123456789abcdef+5eed5eed5eed5eed+e7e7e7e7e7e7e7e7, rulesVersion 2",
					"logId: matches PagleLog's",
					"lastSeq: equals PagleLog's length (6 entries)",
					"rulesVersion: Hunts', 2 (HNT-R136)",
					"Hunt list: " .. HUNTLIST .. ", fingerprint 5eed5eed5eed5eed, 6 Hunts in 3 sets",
					"fingerprint: the catalogue's plus the Hunt list's and the event pool's (DATA-R72, DATA-R98)",
					"summary line: Hunts: 3 of 4 done · 2 titles, at 2026-10-14 17:46:40 UTC (--now) (HNT-R89)",
					"state: 120 Casts, 305 Coins, 5 Hunts with progress, 2 titles",
					"  night_run: current, count 12, effort 80, sinceLast 3, tiers 2 of 3 (1 / 10 / 40)",
					"    tier 1 bronze: 2026-10-12 (realm date), zone 12, item 13759",
					"    tier 2 silver: 2026-10-13 (realm date), zone 12, item 13759",
					"  first_light: current, count 0, effort 5, sinceLast 5, tiers 0 of 3 (1 / 10 / 40)",
					"  rack_hour: current, count 1, effort 7, sinceLast 2, tiers 1 of 3 (1 / 10 / 25)",
					"    tier 1 bronze: 2026-10-12 (realm date), zone 40, item 6643",
					"  dawn_trout: current, count 1, effort 4, sinceLast 0, tiers 1 of 3 (1 / 10 / 25)",
					"    tier 1 bronze: 2026-08-29 (realm date), zone 1519, item 8365",
					"  grouper_by_moonlight: retired 2026-09-01, count 0, effort 2, sinceLast 2, tiers 0 of 3 (1 / 5 / 20)",
					"titles earned: 2",
					"  camp_hours: 2026-10-12, earned at 2026-10-12 13:00:00 UTC, from a Catch",
					"  pagles_wagers: 2026-09-01, earned at 2026-09-01 00:00:00 UTC, from a retirement",
					"settled: 0 (HNT-R148)",
					"ladder: 0 of 3 steps (25 / 50 / 100) (HNT-R148)",
					"coins: 305 (HNT-R110), xp: 0 (HNT-R115), Core stores no Hunts total (AXP-R3)",
					"runs: none known (HNT-R150)",
					"rotation: no slot before its starting point, 2026-10-19 15:00:00 UTC (HNT-R152, HNT-R204)",
					"celebrated tiers: 3 (dawn_trout 1, night_run 1, rack_hour 1)",
					"celebrated titles: 1 (camp_hours)",
					"celebrated runs: none",
					"celebrated ladder: none",
					"celebrated: every reached mark, settled run and ladder step is in it (HNT-R90)",
					"pins: 2 (grouper_by_moonlight, night_run); not current, so Hunts drops the pin at load (HNT-R81):"
						.. " grouper_by_moonlight",
					"tracker.shown: true (not saved: the default)",
					"tracker.collapsed: true",
					"windowMoments: true",
					"showCompleted: false (not saved: the default)",
					"tracker.wagersCollapsed: false (not saved: the default)",
					"companionHint: true (not saved: the default)",
					"lastHintNod: 0 (not saved: the default)",
				}, section(out, "== Hunts"))
			end
		)

		it("prints one Hunt's full progress with --hunt (HNT-R15–R18, HNT-R26)", function()
			-- HNT-R15: each reached tier's Catch, item, zone, realm date and time; HNT-R17: done, not finished; the next
			-- threshold, 40, is 28 away; HNT-R81, HNT-R90: pinned, celebrated up to tier 1.
			assert.are.same({
				"== Hunt night_run (--hunt)",
				"set round_the_clock, natural, species 13759, window night, tiers 1 / 10 / 40,"
					.. " since 2026-01-01 00:00:00 UTC",
				"current, pinned, celebrated up to tier 1",
				"progress: count 12, effort 80, sinceLast 3, caught true, done, not finished",
				"tier 1 (1, bronze): Catch Player-4618-0A1B2C3D-1791800060-0:1, item 13759, zone 12,"
					.. " realm date 2026-10-12, at 2026-10-12 10:14:20 UTC",
				"tier 2 (10, silver): Catch Player-4618-0A1B2C3D-1791900000-0:1, item 13759, zone 12,"
					.. " realm date 2026-10-13, at 2026-10-13 14:00:00 UTC",
				"next: tier 3 at 40, 28 to go",
			}, section(out, "== Hunt night_run"))
		end)

		it(
			"prints a Retired Hunt, an imposed one with no progress, and an unknown ID with --hunt (HNT-R2, HNT-R3, HNT-R5)",
			function()
				-- HNT-R3: retired from its date; HNT-R5: an imposed Hunt's conditions; hunts.md › Projection state: a Hunt
				-- has no entry until it has effort or a Catch; witching_hour's since is still ahead (HNT-R2).
				local lines = run(
					ACCOUNTS .. "M5#1",
					"--catalogue",
					CATALOGUE,
					"--huntlist",
					HUNTLIST,
					"--now",
					NOW,
					"--hunt",
					"grouper_by_moonlight",
					"--hunt",
					"witching_hour",
					"--hunt",
					"no_such_hunt"
				)
				assert.are.same({
					"== Hunt grouper_by_moonlight (--hunt)",
					"set pagles_wagers, imposed, species 12238, conditions areas, time, tiers 1 / 5 / 20,"
						.. " since 2026-01-01 00:00:00 UTC, retired 2026-09-01 00:00:00 UTC",
					"retired, pinned, nothing celebrated",
					"progress: count 0, effort 2, sinceLast 2, caught false, not done, not finished",
					"next: tier 1 at 1, 1 to go",
				}, section(lines, "== Hunt grouper_by_moonlight"))
				assert.are.same({
					"== Hunt witching_hour (--hunt)",
					"set pagles_wagers, imposed, class species.any, conditions areas, time, tiers 1 / 10 / 30,"
						.. " since 2026-11-04 00:00:00 UTC",
					"not out yet, not pinned, nothing celebrated",
					"progress: none stored (no effort Cast or qualifying Catch yet)",
				}, section(lines, "== Hunt witching_hour"))
				assert.are.same(
					{ "== Hunt no_such_hunt (--hunt): not in the Hunt list, and no progress stored" },
					section(lines, "== Hunt no_such_hunt")
				)
			end
		)

		it(
			"reads the repo's Hunt list by default, and flags a fingerprint that isn't the expected one (DATA-R72, LOG-R72)",
			function()
				-- DATA-R72, DATA-R98: the generated list and pool carry their own fingerprints; LOG-R72: a different one
				-- rebuilds Hunts.
				local fingerprint = repoFingerprint("addons/Pagle_Hunts/data/HuntList.lua")
				local pool = repoFingerprint("addons/Pagle_Hunts/data/EventList.lua")
				local lines = section(run(ACCOUNTS .. "M5#1", "--catalogue", CATALOGUE, "--now", NOW), "== Hunts")
				local prefix = "Hunt list: the repo's addons/Pagle_Hunts/data/HuntList.lua, fingerprint " .. fingerprint
				assert.are.equal(prefix, lines[7]:sub(1, #prefix))
				assert.are.equal(
					"fingerprint: DIFFERS from the catalogue's plus the Hunt list's and the event pool's, 0123456789abcdef+"
						.. fingerprint
						.. "+"
						.. pool
						.. ", so Core rebuilds it at login (DATA-R72, DATA-R98, LOG-R72)",
					lines[8]
				)
			end
		)

		it("prints the stored lines alone when the Hunt list can't be loaded (HNT-R2, HNT-R15)", function()
			-- Without the Hunt list nothing tells current from retired (HNT-R2) or the thresholds (HNT-R15), and no
			-- summary line or stale pin is computed; the stored values are all still there.
			local missing = "spec/scripts/fixtures/no-such-HuntList.lua"
			local lines = section(run(ACCOUNTS .. "M5#1", "--catalogue", CATALOGUE, "--huntlist", missing), "== Hunts")
			assert.are.equal("Hunt list: can't load " .. missing, lines[7]:sub(1, #missing + 22))
			assert.are.same({
				"fingerprint: can't be checked without the Hunt list",
				"summary line: can't be computed without the Hunt list",
				"state: 120 Casts, 305 Coins, 5 Hunts with progress, 2 titles",
				"  dawn_trout: count 1, effort 4, sinceLast 0, 1 tier reached",
				"    tier 1 bronze: 2026-08-29 (realm date), zone 1519, item 8365",
				"  first_light: count 0, effort 5, sinceLast 5, 0 tiers reached",
			}, { unpack(lines, 8, 13) })
			assert.are.equal("pins: 2 (grouper_by_moonlight, night_run)", lines[#lines - 7])
		end)

		it("prints the moved tracker dock (CORE-R70, CORE-R71)", function()
			-- core/README.md › Data: dock.point, relative to UIParent.
			assert.are.same({
				"== Tracker dock (PagleDB.profile.dock.point)",
				"dock.point: TOPRIGHT of UIParent's TOPRIGHT, x -180, y -260 (moved by the player, CORE-R71)",
			}, section(out, "== Tracker dock"))
		end)

		it("prints the Hunts slots' looks, Hunts' Coins and Hunts' card lines (HNT-R89, HNT-R110, HNT-R120)", function()
			-- SHOP-R32: the cover has no stored pick, so its default; the tracker frame's pick is stored. SHOP-R3:
			-- Hunts' last reported total. HNT-R111: a "While Hunts was off" Write-up section.
			local looks = section(out, "== Looks")
			assert.are.same({
				"hunts.notebookcover: default (hunts.notebookcover.leather)",
				"hunts.trackerframe: hunts.trackerframe.inkwash",
			}, { unpack(looks, 2, 3) })
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 345",
				"Hunts: 305",
				"Ledger: 40",
				"logId: none stored (a fresh log's, or no Module has reported since PagleLog had one)",
				"wallet projection: none stored (no build has finished, LOG-R72)",
			}, section(out, "== Wallet"))
			assert.are.same({
				"== Cards (PagleDB.global)",
				"writeUp: 1 section",
				"  Hunts: While Hunts was off",
				"    1 Hunts completed",
				"    Pagle Coins +30",
				"cards: 1",
				"  1. Session summary: 2 Casts, 1 Catch, 1 got away, 60 s, 15 Coins",
				"    line: Hunts: 3 of 4 done · 2 titles",
				"    Hunts moments: Silver tier",
				"summary: 0 moments",
				"  line: Hunts: 3 of 4 done · 2 titles",
				"pending: 0 moments",
			}, section(out, "== Cards"))
		end)

		it("reads Pagle_Hunts' enable state by default (#199, in-game-verification.md › Hunts)", function()
			local lines = section(run(ACCOUNTS .. "M5#1", "--character", "70/Ada-Brook"), "== Addons")
			assert.are.same({
				"== Addons (70/Ada-Brook/AddOns.txt)",
				"Pagle: enabled",
				"Pagle_Ledger: enabled",
				"Pagle_QoL: disabled",
				"Pagle_Hunts: enabled",
				"Pagle_Stats: not listed (its TOC's default state applies)",
				"Pagle_TackleBoard: not listed (its TOC's default state applies)",
			}, lines)
		end)
	end)

	-- M5-Stale#1: a Hunts projection built under another rules version and Hunt list, and AceDB left every default out
	-- (no celebrated set, no profile settings); the dock point saved isn't one Core can read.
	describe("on an account whose Hunts projection is stale (#199, in-game-verification.md › Hunts)", function()
		local out, _, code = run(
			ACCOUNTS .. "M5-Stale#1",
			"--catalogue",
			CATALOGUE,
			"--huntlist",
			HUNTLIST,
			"--eventlist",
			EVENTLIST,
			"--now",
			"1792000000"
		)

		it(
			"flags the rulesVersion and the fingerprint, and reads the left-out defaults (HNT-R136, DATA-R72)",
			function()
				assert.are.equal(0, code)
				-- AXP-R3: Core stores 150 for Hunts, which the stale state doesn't hold.
				assert.are.same({
					"== Hunts (PagleHuntsDB)",
					"records: no Hunts A1 entries in PagleLog",
					"projection: lastSeq 6, logId 6c2f9e0a1b3d5e77, fingerprint 0123456789abcdef+0000000000000000,"
						.. " rulesVersion 3",
					"logId: matches PagleLog's",
					"lastSeq: equals PagleLog's length (6 entries)",
					"rulesVersion: 3 DIFFERS from Hunts' 2, so Core rebuilds it at login (HNT-R138, LOG-R72)",
					"Hunt list: " .. HUNTLIST .. ", fingerprint 5eed5eed5eed5eed, 6 Hunts in 3 sets",
					"fingerprint: DIFFERS from the catalogue's plus the Hunt list's and the event pool's,"
						.. " 0123456789abcdef+5eed5eed5eed5eed+e7e7e7e7e7e7e7e7, so Core rebuilds it at login"
						.. " (DATA-R72, DATA-R98, LOG-R72)",
					"summary line: Hunts: 0 of 4 done · 0 titles, at 2026-10-14 17:46:40 UTC (--now) (HNT-R89)",
					"state: 0 Casts, 0 Coins, 0 Hunts with progress, 0 titles",
					"titles earned: none",
					"settled: 0 (HNT-R148)",
					"ladder: 0 of 3 steps (25 / 50 / 100) (HNT-R148)",
					"coins: 0 (HNT-R110), xp: 0 (HNT-R115), DIFFERS from Core's stored Hunts total 150: the next report"
						.. " sets it (AXP-R3)",
					"runs: none known (HNT-R150)",
					"rotation: no slot before its starting point, 2026-10-19 15:00:00 UTC (HNT-R152, HNT-R204)",
					"celebrated tiers: none",
					"celebrated titles: none",
					"celebrated runs: none",
					"celebrated ladder: none",
					"celebrated: every reached mark, settled run and ladder step is in it (HNT-R90)",
					"pins: none",
					"tracker.shown: true (not saved: the default)",
					"tracker.collapsed: false (not saved: the default)",
					"windowMoments: false (not saved: the default)",
					"showCompleted: false (not saved: the default)",
					"tracker.wagersCollapsed: false (not saved: the default)",
					"companionHint: true (not saved: the default)",
					"lastHintNod: 0 (not saved: the default)",
				}, section(out, "== Hunts"))
			end
		)

		it("reads a dock point Core can't read as the default (CORE-R70)", function()
			assert.are.same({
				"== Tracker dock (PagleDB.profile.dock.point)",
				"dock.point: saved but not one Core reads, so the default: TOPRIGHT of MinimapCluster's BOTTOMRIGHT,"
					.. " x 0, y -10 (CORE-R70)",
			}, section(out, "== Tracker dock"))
		end)
	end)

	-- M6#1 holds what the M6 exit check reads (#219, #221). Its PagleLog: Ada Brook (skill 150+25) and Bram Reed
	-- (120+0) on a realm at UTC−7, six Sessions (LOG-R60: 900 s apart or more): 120 Casts by Ada in Elwynn (12) from
	-- realm 22:00, 30 s apart (Nightfin 13759 on the first three, a got-away on every 10th from the 5th, Smallfish 6303
	-- otherwise); Bram's two in Westfall (40); then Ada's one each at realm 01:20 (12), 03:00 (12) and 04:40 (40); and
	-- the last, three Casts from realm 08:00 with a Skill Reading (151) between them. Its PagleStatsDB.global.projection
	-- is that log folded by Stats' own fold (STA-R21–R31) over spec/scripts/fixtures/Catalogue.lua: Elwynn's no-junk
	-- line is 25 + 95 = 120 and Westfall's 55 + 95 = 150 (STA-R12), and Nightfin keeps the `night` window (21:00–06:00)
	-- in Elwynn (STA-R14). Its profile has the tracker on and three watches; PagleDB keeps the book moved (profile.books,
	-- BOOK-R5) and caches Stats' three tracker frames with Logbook picked. Read at --now 1792000000, 2026-10-14 17:46:40 UTC.
	describe("on an account after the M6 exit check's steps (#219, in-game-verification.md › Stats)", function()
		local NOW = "1792000000"
		local out, err, code = run(
			ACCOUNTS .. "M6#1",
			"--catalogue",
			CATALOGUE,
			"--now",
			NOW,
			"--stats-item",
			"13759",
			"--area",
			"12",
			"--skill",
			"175"
		)

		it("exits 0 and writes nothing to stderr (#219, in-game-verification.md › Stats)", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("prints the projection, totals, margins, characters, last Sessions (STA-R20–R31, LOG-R70/R98)", function()
			-- LOG-R70's stored values; STA-R20: 100 × STATS_RULES_VERSION 1 + Core's SESSION_RULES_VERSION 2 = 102, and
			-- the stored fingerprint is the catalogue's content fingerprint (no extra). STA-R22: 120 + 1 + 1 + 1 + 3 of
			-- Ada's Casts and Bram's 2; 12 + 1 + 1 of Ada's and 1 of Bram's got away; Elwynn and Westfall are zones.
			-- STA-R23: 12:hi (124), 12:hi:night (122: the realm 08:00 Casts are by day), 40:hi and 40:lo (2 each).
			-- STA-R24: Nightfin and Smallfish in Elwynn, Bram's 6291 on lo, 6299 and 13902 on hi in Westfall. STA-R26:
			-- Ada is 55 and 25–26 above her lines (hi25), Bram 30 below Westfall's (lo1). STA-R27: last ranks 151, 120.
			-- STA-R30: the last five Sessions, each starting at its first Cast's ID; realm times are server time less 7 h
			-- (LOG-R49); Session 6 gained 1 skill (STA-R27, STA-R31). LOG-R98: every Cast carries its Session's ID.
			assert.are.same({
				"== Stats (PagleStatsDB)",
				"projection: lastSeq 132, logId 7a3e5c1b9d0f2468, fingerprint 0123456789abcdef, rulesVersion 102",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (132 entries)",
				"rulesVersion: Stats', 102 (STA-R20)",
				"fingerprint: the catalogue's, " .. CATALOGUE .. " (LOG-R70)",
				"totals: 128 Casts, 113 Catches, 15 got away",
				"places: 2 (2 zones, 0 subzones), 4 scopes, 5 hits",
				"margins: lo50 0 Casts, lo1 2 Casts (1 got away), hi0 0 Casts, hi25 126 Casts (14 got away)",
				"characters: 2",
				"  1 Ada Brook (Player-4618-0A1B2C3D): 126 Casts, 112 Catches, 14 got away, last rank 151",
				"  2 Bram Reed (Player-4618-0F0E0D0C): 2 Casts, 1 Catch, 1 got away, last rank 120",
				"Sessions: 6 stored, the log's Casts carry 6 Session IDs; the last 5, oldest first:",
				"  2. Player-4618-0F0E0D0C-1791960000-0: realm 2026-10-13 23:40 to 2026-10-13 23:40,"
					.. " server 2026-10-14 06:40:00 UTC to 2026-10-14 06:40:30 UTC",
				"     2 Casts, 1 Catch, 1 got away, zones 40 ×2, skill +0; the log tags 2 Casts with it (matches)",
				"  3. Player-4618-0A1B2C3D-1791966000-0: realm 2026-10-14 01:20 to 2026-10-14 01:20,"
					.. " server 2026-10-14 08:20:00 UTC to 2026-10-14 08:20:00 UTC",
				"     1 Cast, 1 Catch, 0 got away, zones 12 ×1, skill +0; the log tags 1 Cast with it (matches)",
				"  4. Player-4618-0A1B2C3D-1791972000-0: realm 2026-10-14 03:00 to 2026-10-14 03:00,"
					.. " server 2026-10-14 10:00:00 UTC to 2026-10-14 10:00:00 UTC",
				"     1 Cast, 0 Catches, 1 got away, zones 12 ×1, skill +0; the log tags 1 Cast with it (matches)",
				"  5. Player-4618-0A1B2C3D-1791978000-0: realm 2026-10-14 04:40 to 2026-10-14 04:40,"
					.. " server 2026-10-14 11:40:00 UTC to 2026-10-14 11:40:00 UTC",
				"     1 Cast, 1 Catch, 0 got away, zones 40 ×1, skill +0; the log tags 1 Cast with it (matches)",
				"  6. Player-4618-0A1B2C3D-1791990000-0: realm 2026-10-14 08:00 to 2026-10-14 08:05,"
					.. " server 2026-10-14 15:00:00 UTC to 2026-10-14 15:05:00 UTC",
				"     3 Casts, 2 Catches, 1 got away, zones 12 ×2, 40 ×1, skill +1; the log tags 3 Casts with it (matches)",
				-- #221 step 2: the latest Cast's areaIDs and rank + mod (STA-R11), for --area and --skill
				"latest Cast: zone 40, no subzone, skill 151 + 25 = 176 (for --area and --skill)",
				"tracker: true",
				"watched: 3, oldest first, read at --skill 175",
				-- STA-R64: each watch read as any reading. Nightfin: 3 of 122 by night, last caught at 3, so 119 since,
				-- P = (1 − 3/122)^119 ≈ 0.052 (STA-R51, STA-R52: normal). Smallfish: 107 of 124, 1 since, P ≈ 0.14.
				-- Bram's 6291 was caught below Westfall's line: 2 Casts at or above it, none caught (STA-R43, STA-R50).
				"  1. item 13759 in area 12: 1 in 41, Dry spell 119, normal (12:hi:night)",
				"  2. item 6303 in area 12: 1 in 1, Dry spell 1, normal (12:hi)",
				"  3. item 6291 in area 40: learning 2/100, Dry spell 2, no luck reading (40:hi)",
			}, section(out, "== Stats (PagleStatsDB)"))
		end)

		it("prints each movable book's saved place from Core's profile.books (BOOK-R5)", function()
			assert.are.same({
				"== Books (PagleDB.profile.books)",
				"stats: TOPLEFT of UIParent's TOPLEFT, x 312, y -140 (moved by the player, BOOK-R5)",
			}, section(out, "== Books"))
		end)

		it("prints --stats-item's reading in --area at --skill with Stats' own logic (STA-R41–R54)", function()
			-- STA-R41: 175 is at or above Elwynn's line, 120. STA-R42: Nightfin's night window. STA-R43: 122 ≥ 100, k 3,
			-- so known, 122 / 3 = 40.7 → 41 (STA-R44). STA-R45: Wilson's bounds for 3 of 122 are 0.0084 and 0.0698, 1 in
			-- 120 and 1 in 14. STA-R46: the fixture's entries, gate and line are all unconfirmed. STA-R50: 122 − 3 = 119
			-- since; STA-R51–R53: P ≈ 0.0517, about 5 in 100. The last Nightfin was at 05:01 UTC, 12.76 h before --now,
			-- "13h ago" rounded half up (STA-R44, STA-R59).
			assert.are.same({
				"== Stats item 13759 in area 12 (--stats-item, --area)",
				"side: hi, --skill 175 against the line 120 (STA-R41)",
				"scope: 12:hi:night, 122 Casts, 3 caught (STA-R42)",
				"state: known (STA-R43)",
				"Your odds: about 1 in 41 (short: 1 in 41)",
				"range: Likely between 1 in 14 and 1 in 120 (95%).",
				"sentence: From 122 of my Casts here by night, at or above 120 skill; 3 caught.",
				"note: Pagle hasn't confirmed it bites here yet.",
				"note: The window isn't confirmed yet.",
				"note: The no-junk line isn't confirmed yet.",
				"Dry spell: 119 Casts since the last, at 3, last caught 2026-10-14 05:01:00 UTC; P 0.0517, band normal"
					.. " (STA-R50–R52)",
				"Dry spell text: 119 Casts since my last one, 13h ago. About 5 anglers in 100 wait this long."
					.. " Nothing unusual.",
				"short: 1 in 41 · 119 since",
			}, section(out, "== Stats item"))
		end)

		it("reads the other side with --skill, and the side with the most Casts without it (STA-R41)", function()
			-- STA-R41: 100 is below Elwynn's line; Ada never fished there below it, so the scope is empty: learning
			-- (STA-R43) and never caught, a bare count (STA-R50). Without --skill, 12:hi's 124 Casts beat lo's and na's 0.
			local below = run(
				ACCOUNTS .. "M6#1",
				"--catalogue",
				CATALOGUE,
				"--now",
				NOW,
				"--stats-item",
				"13759",
				"--area",
				"12",
				"--skill",
				"100"
			)
			assert.are.same({
				"== Stats item 13759 in area 12 (--stats-item, --area)",
				"side: lo, --skill 100 against the line 120 (STA-R41)",
				"scope: 12:lo:night, 0 Casts, 0 caught (STA-R42)",
				"state: learning (STA-R43)",
				"Your odds: Learning… (short: learning 0/100)",
				"range: none until known (STA-R45)",
				"sentence: 0 of the 100 Casts I need here by night, below 120 skill before Your odds show a number.",
				"note: Pagle hasn't confirmed it bites here yet.",
				"note: The window isn't confirmed yet.",
				"note: The no-junk line isn't confirmed yet.",
				"Dry spell: 0 Casts, never caught in this scope (STA-R50)",
				"Dry spell text: 0 Casts here, none yet.",
				"short: learning 0/100",
			}, section(below, "== Stats item"))
			local unknown =
				run(ACCOUNTS .. "M6#1", "--catalogue", CATALOGUE, "--now", NOW, "--stats-item", "13759", "--area", "12")
			assert.are.equal(
				"side: hi, the most Casts here (hi 124, lo 0, na 0), no --skill (STA-R41)",
				section(unknown, "== Stats item")[2]
			)
			assert.are.equal(
				"watched: 3, oldest first, read on the side with the most Casts in each place (no --skill, STA-R41)",
				lineStarting(section(unknown, "== Stats (PagleStatsDB)"), "watched:")
			)
		end)

		it("reads the repo's catalogue by default, and flags a fingerprint that isn't it (LOG-R70, LOG-R72)", function()
			local fingerprint = repoFingerprint("addons/Pagle/data/Catalogue.lua")
			local lines = section(run(ACCOUNTS .. "M6#1", "--now", NOW), "== Stats (PagleStatsDB)")
			assert.are.equal(
				"fingerprint: DIFFERS from the catalogue's "
					.. fingerprint
					.. ", the repo's addons/Pagle/data/Catalogue.lua, so Core rebuilds it at login (LOG-R70, LOG-R72)",
				lines[6]
			)
		end)

		it("reads side na in a place with no no-junk line (STA-R12, STA-R41)", function()
			-- Duskwood (10) has no skillBase in the fixture catalogue, so no line, and Nightfin no window there (STA-R14).
			local lines = section(
				run(ACCOUNTS .. "M6#1", "--catalogue", CATALOGUE, "--stats-item", "13759", "--area", "10"),
				"== Stats item"
			)
			assert.are.same({
				"side: na, no no-junk line (STA-R41)",
				"scope: 10:na, 0 Casts, 0 caught (STA-R42)",
			}, { lines[2], lines[3] })
		end)

		it("prints the stored lines alone when the catalogue can't be loaded (STA-R12, STA-R14)", function()
			-- Without the catalogue there are no lines or windows (STA-R12, STA-R14), so no reading is computed.
			local missing = "spec/scripts/fixtures/no-such-Catalogue.lua"
			local out2 = run(ACCOUNTS .. "M6#1", "--catalogue", missing, "--stats-item", "13759", "--area", "12")
			local lines = section(out2, "== Stats (PagleStatsDB)")
			local prefix = "fingerprint: can't be checked: " .. missing .. " can't load: "
			assert.are.equal(prefix, lines[6]:sub(1, #prefix))
			assert.are.equal("totals: 128 Casts, 113 Catches, 15 got away", lines[7])
			assert.are.equal(
				"  1. item 13759 in area 12 (no reading without a projection and the catalogue)",
				lineStarting(lines, "  1. item")
			)
			assert.are.same({
				"== Stats item 13759 in area 12 (--stats-item, --area): can't be read without the catalogue"
					.. " (see fingerprint: above)",
			}, section(out2, "== Stats item"))
		end)

		it(
			"prints the Stats tracker frame's pick, and Pagle_Stats' enable state by default (SHOP-R32, STA-R88)",
			function()
				-- SHOP-R32: the slot's stored pick; STA-R88: Stats' one slot.
				assert.are.same({ "stats.trackerframe: stats.trackerframe.logbook" }, { section(out, "== Looks")[2] })
				local lines = section(run(ACCOUNTS .. "M6#1", "--character", "70/Ada-Brook"), "== Addons")
				assert.are.same({
					"== Addons (70/Ada-Brook/AddOns.txt)",
					"Pagle: enabled",
					"Pagle_Ledger: enabled",
					"Pagle_QoL: disabled",
					"Pagle_Hunts: enabled",
					"Pagle_Stats: enabled",
					"Pagle_TackleBoard: not listed (its TOC's default state applies)",
				}, lines)
			end
		)
	end)

	-- M6-Stale#1: a Stats projection built under another rules version and catalogue, one Cast behind its log, and
	-- AceDB left the profile's defaults out of the file (stats.md › Data).
	it("flags a stale projection and a Session behind the log, and reads the left-out defaults (STA-R20)", function()
		local out, _, code =
			run(ACCOUNTS .. "M6-Stale#1", "--catalogue", CATALOGUE, "--stats-item", "13759", "--area", "12")
		assert.are.equal(0, code)
		assert.are.same({
			"== Stats (PagleStatsDB)",
			"projection: lastSeq 4, logId 4b1d7e9a2c6f3058, fingerprint fedcba9876543210, rulesVersion 100",
			"logId: matches PagleLog's",
			"lastSeq: differs from PagleLog's length (5 entries)",
			"rulesVersion: 100 DIFFERS from Stats' 102 (100 × 1 + Core's SESSION_RULES_VERSION 2), so Core rebuilds it"
				.. " at login (STA-R20, LOG-R72)",
			"fingerprint: DIFFERS from the catalogue's 0123456789abcdef, "
				.. CATALOGUE
				.. ", so Core rebuilds it at login (LOG-R70, LOG-R72)",
			"totals: 2 Casts, 2 Catches, 0 got away",
			"places: 1 (1 zone, 0 subzones), 2 scopes, 2 hits",
			"margins: lo50 0 Casts, lo1 0 Casts, hi0 0 Casts, hi25 2 Casts",
			"characters: 1",
			"  1 Ada Brook (Player-4618-0A1B2C3D): 2 Casts, 2 Catches, 0 got away, last rank 150",
			"Sessions: 1 stored, the log's Casts carry 1 Session ID; the last 1, oldest first:",
			"  1. Player-4618-0A1B2C3D-1791954000-0: realm 2026-10-13 22:00 to 2026-10-13 22:00,"
				.. " server 2026-10-14 05:00:00 UTC to 2026-10-14 05:00:30 UTC",
			"     2 Casts, 2 Catches, 0 got away, zones 12 ×2, skill +0; the log tags 3 Casts with it (DIFFERS)",
			"latest Cast: zone 12, no subzone, skill 150 + 25 = 175 (for --area and --skill)",
			"tracker: false (not saved: the default)",
			"watched: none (not saved: the default)",
		}, section(out, "== Stats (PagleStatsDB)"))
		-- STA-R41: 2 Casts on hi; STA-R43: learning; the first Nightfin was the first Cast, so 1 since.
		assert.are.equal(
			"Dry spell: 1 Cast since the last, at 1, last caught 2026-10-14 05:00:00 UTC (STA-R50)",
			lineStarting(section(out, "== Stats item"), "Dry spell:")
		)
	end)

	-- M6-Break#1: M6-Stale#1's files, with `/pagle dev endsession` noted after the second Cast (LOG-R99).
	it("tags the log's Casts with the Session breaks PagleDB.global keeps, as Core does (#258, LOG-R99)", function()
		local out = run(ACCOUNTS .. "M6-Break#1", "--catalogue", CATALOGUE)
		local lines = section(out, "== Stats (PagleStatsDB)")

		assert.are.equal(
			"Sessions: 1 stored, the log's Casts carry 2 Session IDs; the last 1, oldest first:",
			lineStarting(lines, "Sessions:")
		)
		assert.are.equal(
			"     2 Casts, 2 Catches, 0 got away, zones 12 ×2, skill +0; the log tags 2 Casts with it (matches)",
			lineStarting(lines, "     2 Casts")
		)
	end)

	it(
		"says no Stats projection is stored before the first build, none is read, and names the latest Cast's place (LOG-R72, #221)",
		function()
			local out = run(ACCOUNTS .. "M6-New#1", "--stats-item", "13759", "--area", "12")
			assert.are.same({
				"== Stats (PagleStatsDB)",
				"projection: none stored (no build has finished, LOG-R72)",
				-- its log's one Cast, in The Long Wash (148/453) at 86 + 25 (#221 step 2)
				"latest Cast: zone 148, subzone 453, skill 86 + 25 = 111 (for --area and --skill)",
				"tracker: false (not saved: the default)",
				"watched: none (not saved: the default)",
			}, section(out, "== Stats (PagleStatsDB)"))
			assert.are.same(
				{ "== Stats item 13759 in area 12 (--stats-item, --area): no projection stored to read" },
				section(out, "== Stats item")
			)
		end
	)

	it("says in one line that Pagle_Stats.lua is missing (#219, in-game-verification.md › Stats)", function()
		local out = run(ACCOUNTS .. "M5#1", "--catalogue", CATALOGUE, "--huntlist", HUNTLIST)
		assert.are.same(
			{ "== Stats: can't read " .. ACCOUNTS .. "M5#1/SavedVariables/Pagle_Stats.lua: missing" },
			section(out, "== Stats")
		)
	end)

	it("says in one line that Pagle_Hunts.lua is missing, and reads no dock point as the default (CORE-R70)", function()
		local out = run(ACCOUNTS .. "M4#1", "--catalogue", CATALOGUE)
		assert.are.same(
			{ "== Hunts: can't read " .. ACCOUNTS .. "M4#1/SavedVariables/Pagle_Hunts.lua: missing" },
			section(out, "== Hunts")
		)
		-- core/README.md › Data: dock.point is nil until the player moves the dock.
		assert.are.same({
			"== Tracker dock (PagleDB.profile.dock.point)",
			"dock.point: default (none saved): TOPRIGHT of MinimapCluster's BOTTOMRIGHT, x 0, y -10 (CORE-R70)",
		}, section(out, "== Tracker dock"))
	end)

	it("prints an M3 Ledger's M4 lines as none yet, with the automatic title (LED-R35, LED-R77, LED-R80)", function()
		-- M3#1 has no prestige rank, milestones, Legends, records, titles or activeTitle. Level 4 (4,560 XP at rank
		-- 0) earns level1, the automatic title; 6309 of the fixture's one junk item earns complete.junk (LED-R75). 6291
		-- is a Species with no record; 6299 isn't in the state.
		local out = run(ACCOUNTS .. "M3#1", "--catalogue", CATALOGUE, "--item", "6291", "--item", "6299")
		assert.are.same({
			"== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles",
			"climb: prestige rank 0, 4560 XP of its own, Prestige snapshot 0, the climb's Activity XP 0 (Core's stored"
				.. " total 0 − 0, LED-R37), computed level 4, peak level 4",
			"Catch Milestones: none, 8 lifetime Catches",
			"Legends caught: none",
			"records: 0 of 2 Species, 0 Legends",
			"record of 6291 (Species): none (no sized Catch yet)",
			"record of 6299: not in the state (no Species or item 6299 caught)",
			"titles earned: 2 (title:level1, title:complete.junk)",
			"active title: automatic, so title:level1",
			"celebrated levels: prestige rank 0 level 4",
			"celebrated prestige: 0",
			"celebrated Catch Milestones: none",
			"celebrated titles: none",
			"celebrated Legend items: none",
			"sizes: no Catch has a Simulated Size (LOG-R65), from PagleLog over " .. CATALOGUE,
		}, section(out, "== Ledger M4"))
	end)

	it("says in one line that no Field report projection is stored yet (REP-R25)", function()
		local out = run(ACCOUNTS .. "M2#1")
		-- 90f8ce52 is FNV-1a 32 of M2#1's logId 5d2e8a0c4b1f7e93, worked out apart from Core (REP-R36).
		assert.are.same({
			"== Field report (PagleDB.global.projections.fieldReport): reporter key "
				.. "90f8ce52, projection: none stored (no build has finished, LOG-R72)",
		}, section(out, "== Field report"))
	end)

	it("says in one line that Pagle_Ledger.lua is missing", function()
		local out = run(ACCOUNTS .. "M1#1")
		assert.are.same(
			{ "== Ledger: can't read " .. ACCOUNTS .. "M1#1/SavedVariables/Pagle_Ledger.lua: missing" },
			section(out, "== Ledger")
		)
	end)

	describe("on an account after the M7 exit check's steps (in-game-verification.md › Tackle Board)", function()
		-- M7#1: Ada started her board on Wednesday 14 October 2026 (day 0, realm UTC−7, daily reset 15:00 UTC, weekly
		-- Tuesday) and played days 0–6 and 8; on day 9 she fished with the board disabled. The projection is its log
		-- folded by the Tackle Board's own logic over spec/scripts/fixtures/Catalogue.lua, so every count is real.
		-- --now is Saturday 24 October 17:00 UTC, board day 10.
		local NOW = "1792861200"
		local out, err, code = run(ACCOUNTS .. "M7#1", "--catalogue", CATALOGUE, "--now", NOW)
		local lines = section(out, "== Tackle Board")
		local GUID = "Player-4618-0A1B2C3D-"

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("counts the board's records by kind and decodes the last 10, flagging those it skips (TKB-R80)", function()
			-- LOG-R40: 28 A1 entries name TackleBoard; seq 51 is Hunts', never the board's. TKB-R80: seq 49's tier 7 is
			-- out of range and issue2 is a kind the board doesn't know. LOG-R49: the latest Cast, 16:00 UTC at realm
			-- 09:00, puts the realm at UTC−7. Data: payloads decoded with the board's own codec, the goal text from
			-- TKB-R36's templates with area and item IDs for the client's names.
			assert.are.same({
				"== Tackle Board (PagleTackleBoardDB)",
				"records: 28 TackleBoard A1 entries in PagleLog: start 1, day 7, issue 18, reroll 1, issue2 1",
				"records the board skips: 2 (seq 49, 50) (TKB-R80)",
				"the last 10, oldest first, realm time at the log's realm clock (UTC-07:00):",
				"  seq 37, realm 2026-10-19 08:05, server 2026-10-19 15:05:00 UTC: day, dayStart 2026-10-19 15:00:00 UTC,"
					.. " weekStart 2026-10-13 15:00:00 UTC",
				"  seq 38, realm 2026-10-19 08:05, server 2026-10-19 15:05:01 UTC: issue, Notice species tier 2, pays 15,"
					.. ' need 2, target 6303 ("2 Item 6303")',
				"  seq 41, realm 2026-10-20 08:05, server 2026-10-20 15:05:00 UTC: day, dayStart 2026-10-20 15:00:00 UTC,"
					.. " weekStart 2026-10-20 15:00:00 UTC",
				"  seq 42, realm 2026-10-20 08:05, server 2026-10-20 15:05:01 UTC: issue, Expedition haul tier 0, pays 60,"
					.. ' need 20, target 12 ("20 Catches in Area 12")',
				"  seq 43, realm 2026-10-20 08:05, server 2026-10-20 15:05:02 UTC: issue, Notice haul tier 1, pays 10,"
					.. ' need 2, target 12 ("2 Catches in Area 12")',
				"  seq 46, realm 2026-10-22 08:05, server 2026-10-22 15:05:00 UTC: day, dayStart 2026-10-22 15:00:00 UTC,"
					.. " weekStart 2026-10-20 15:00:00 UTC",
				"  seq 47, realm 2026-10-22 08:05, server 2026-10-22 15:05:01 UTC: issue, Notice haul tier 1, pays 10,"
					.. ' need 3, target 40 ("3 Catches in Area 40")',
				"  seq 48, realm 2026-10-22 08:05, server 2026-10-22 15:05:10 UTC: issue, Notice haul tier 1, pays 10,"
					.. ' need 2, target 12 ("2 Catches in Area 12")',
				"  seq 49, realm 2026-10-22 08:05, server 2026-10-22 15:05:11 UTC: issue, SKIPPED: the board can't decode"
					.. ' "n;haul;7;10;3;12" (TKB-R80)',
				"  seq 50, realm 2026-10-22 08:05, server 2026-10-22 15:05:12 UTC: issue2, SKIPPED: the board can't decode"
					.. ' "n;haul;1;10;3;12" (TKB-R80)',
			}, { unpack(lines, 1, 14) })
		end)

		it(
			"prints the projection's bookkeeping, current against the log, its rules version and the catalogue (LOG-R70, TKB-R81)",
			function()
				-- LOG-R70's stored values. TKB-R81: 1000 × TKB_RULES_VERSION 5 + Core's SESSION_RULES_VERSION 2 = 5002; the
				-- fingerprint is the catalogue's content fingerprint, with no extra.
				assert.are.same({
					"projection: lastSeq 54, logId 3c9e1a7f5b2d8046, fingerprint 0123456789abcdef, rulesVersion 5002",
					"logId: matches PagleLog's",
					"lastSeq: equals PagleLog's length (54 entries)",
					"rulesVersion: the Tackle Board's, 5002 (TKB-R81)",
					"fingerprint: the catalogue's, " .. CATALOGUE .. " (LOG-R70)",
				}, { unpack(lines, 15, 19) })
			end
		)

		it(
			"prints the days, the owed goals, the pins and the overflow strip with each goal's progress (TKB-R12, TKB-R14,"
				.. " TKB-R20, TKB-R40, TKB-R41, TKB-R44, TKB-R55, TKB-R101)",
			function()
				-- TKB-R12: seq 46 numbered day 8 (8 resets after the start's), week 1 (the weekly reset of the 20th); the
				-- Cast of the 23rd advanced the projection to day 9 (TKB-R14), and --now is 2 resets after day 8's.
				-- TKB-R20: each reset owed what the pins could take, and the live steps issued it all. TKB-R101: seq 47 took
				-- pin 1, freed on day 0; seq 48 found every Notice pin taken. TKB-R40: the Expedition counted day 6's two
				-- Catches and day 8's junk in Elwynn; 6291 three times since seq 8. TKB-R44: item 999001 is Uncharted.
				-- TKB-R41: the Collector counts only day 8's Catches, its junk. TKB-R55: seq 34 re-posted pin 3. TKB-R22:
				-- each open goal's tier, pay and need are its record's.
				assert.are.same({
					"started: seq 5, realm 2026-10-14 08:10, server 2026-10-14 15:10:00 UTC (TKB-R6)",
					"boundary: seq 46, day 8, week 1, dayStart 2026-10-22 15:00:00 UTC, weekStart 2026-10-20 15:00:00 UTC",
					"processed: day 9, week 1 (TKB-R14)",
					"today: day 10 at 2026-10-24 17:00:00 UTC (--now), 1 day after the processed day: the next live step"
						.. " advances to it (TKB-R12, TKB-R13)",
					"owed: 0 Notices, 0 Expeditions (TKB-R20)",
					"Expedition pins:",
					"  1. "
						.. GUID
						.. '1792508701-0: Expedition haul, "20 Catches in Area 12", 3 of 20, tier 0, pays 60,'
						.. " need 20",
					"  2. empty",
					"Notice pins:",
					"  1. "
						.. GUID
						.. '1792681501-0: Notice haul, "3 Catches in Area 40", 0 of 3, tier 1, pays 10, need 3',
					"  2. " .. GUID .. '1791990603-0: Notice species, "4 Item 6291", 3 of 4, tier 2, pays 15, need 4',
					"  3. "
						.. GUID
						.. '1792336000-0: Notice haul, "5 Catches in Area 40", 0 of 5, tier 2, pays 15, need 5, re-posted'
						.. " (TKB-R55)",
					"  4. "
						.. GUID
						.. '1792076703-0: Notice species, "2 Item 999001", 0 of 2, tier 2, pays 15, need 2, STRANDED'
						.. " (TKB-R44)",
					"  5. "
						.. GUID
						.. '1792163102-0: Notice collector, "A junk item and a container today", 1 of 2, tier 2,'
						.. " pays 15, need 2, day-bound, its board day 8 (TKB-R41)",
					"  6. "
						.. GUID
						.. '1792163103-0: Notice lure, "3 Catches with a lure on", 1 of 3, tier 1, pays 10, need 3',
					"overflow strip: 1 (TKB-R101)",
					"  "
						.. GUID
						.. '1792681510-0: Notice haul, "2 Catches in Area 12", 1 of 2, tier 1, pays 10, need 2',
				}, { unpack(lines, 20, 36) })
			end
		)

		it(
			"prints the completed goals, tally, Coins, flies, titles, Campfire, zones and caught items (TKB-R30, TKB-R46,"
				.. " TKB-R60–R64, TKB-R70–R73)",
			function()
				-- TKB-R60: each completion's day and fly; TKB-R61: 8 Notices and the Expedition; TKB-R63: 10 + 20 + 10 + 10
				-- + 10 + 60 + 10 + 15 + 10 pay and the 7-day milestone's 25 = 180. TKB-R62: the flies in pattern order (Data),
				-- the Expedition's rare. TKB-R70–R73: days 0–6 lit, the seventh earning a Kindling (2 + 1) and campfire_7;
				-- days 7 and 8 unlit, each burning one. TKB-R30, TKB-R46: every Cast's zone and caught item, from the first.
				assert.are.same({
					"completed: 9 in the last 28 board days, by doneDay",
					"  day 0: "
						.. GUID
						.. '1791990602-0, Notice haul, "3 Catches in Area 12", pays 10, fly duskwood_shadow',
					"  day 0: "
						.. GUID
						.. '1791990604-0, Notice wanderer, "Catches in 2 zones today", pays 20, fly kodo_hair_caddis',
					"  day 1: "
						.. GUID
						.. '1792076701-0, Notice haul, "2 Catches in Area 40", pays 10, fly feralas_fern',
					"  day 2: "
						.. GUID
						.. '1792163101-0, Notice haul, "2 Catches in Area 12", pays 10, fly swamp_midge',
					"  day 3: "
						.. GUID
						.. '1792249501-0, Notice haul, "2 Catches in Area 40", pays 10, fly redridge_ember',
					"  day 3: "
						.. GUID
						.. '1791990601-0, Expedition variety, "Every Species of Area 40", pays 60, fly nats_golden_doctor',
					"  day 4: "
						.. GUID
						.. '1792335901-0, Notice haul, "2 Catches in Area 12", pays 10, fly bloodsail_streamer',
					"  day 5: " .. GUID .. '1792422301-0, Notice species, "2 Item 6303", pays 15, fly goldshire_gnat',
					"  day 6: "
						.. GUID
						.. '1792508702-0, Notice haul, "2 Catches in Area 12", pays 10, fly elwynn_royal',
					"tally: 8 Notices, 1 Expedition (TKB-R61)",
					"coins: 180 (TKB-R63), xp: 1550 (TKB-R65), Refreshes spent: 0 (TKB-R58),"
						.. " equals Core's stored TackleBoard total (AXP-R3)",
					"flies: 9 of 30 tied, in pattern order (TKB-R62):",
					"  goldshire_gnat: day 5, goal " .. GUID .. "1792422301-0",
					"  duskwood_shadow: day 0, goal " .. GUID .. "1791990602-0",
					"  redridge_ember: day 3, goal " .. GUID .. "1792249501-0",
					"  kodo_hair_caddis: day 0, goal " .. GUID .. "1791990604-0",
					"  elwynn_royal: day 6, goal " .. GUID .. "1792508702-0",
					"  swamp_midge: day 2, goal " .. GUID .. "1792163101-0",
					"  bloodsail_streamer: day 4, goal " .. GUID .. "1792335901-0",
					"  feralas_fern: day 1, goal " .. GUID .. "1792076701-0",
					"  nats_golden_doctor: day 3, goal " .. GUID .. "1791990601-0",
					"titles: 1 (TKB-R64)",
					"  campfire_7: day 6, Cast " .. GUID .. "1792512030-0",
					"fire: count 7, Kindling 1, longest 7 (TKB-R70–R72)",
					"fire milestones: 7 days on day 6, Cast " .. GUID .. "1792512030-0 (TKB-R73)",
					"fire log: day 0 lit, day 1 lit, day 2 lit, day 3 lit, day 4 lit, day 5 lit, day 6 lit, day 7 burned,"
						.. " day 8 burned",
					"zones: 2 (12 last at 2026-10-22 16:00:30 UTC, 40 last at 2026-10-23 16:00:00 UTC)",
					"caught: 4 (6291, 6299, 6303, 6309)",
				}, { unpack(lines, 37, 65) })
			end
		)

		it("prints the celebrated set, flags a completed goal missing from it, and the profile (TKB-R83)", function()
			-- TKB-R83: day 5's Species Notice completed but isn't in the set, so a rebuild would raise its moment
			-- (TKB-R84). tackle-board.md › Data: tracker is left out of the file at its default, true. #242: the set's
			-- goal IDs, sorted.
			local ids = {}
			for i, at in ipairs({ 1791990601, 1791990602, 1791990604, 1792076701, 1792163101, 1792249501 }) do
				ids[i] = GUID .. at .. "-0"
			end
			ids[#ids + 1] = GUID .. "1792335901-0"
			ids[#ids + 1] = GUID .. "1792508702-0"
			assert.are.same({
				"celebrated goals: 8 (" .. table.concat(ids, ", ") .. "), titles: 1 (campfire_7)",
				"celebrated: MISSING 1 completed goal: " .. GUID .. "1792422301-0 (day 5) (TKB-R83)",
				"celebrated: every earned title is in it",
				"tracker: true (not saved: the default)",
				"trackerCollapsed: true",
			}, { unpack(lines, 66) })
		end)

		it(
			"prints the Tackle Board's frame pick, Coins, Write-up and card naming it (SHOP-R32, SHOP-R3, ANN-R60, ANN-R53)",
			function()
				-- SHOP-R32: the slot's stored pick; SHOP-R3: the Module's last report; ANN-R60, ANN-R53: Core's stored title.
				assert.are.same(
					{ "tackleboard.trackerframe: tackleboard.trackerframe.corkboard" },
					{ section(out, "== Looks")[2] }
				)
				assert.are.equal("TackleBoard: 180", lineStarting(section(out, "== Wallet"), "TackleBoard:"))
				local cards = section(out, "== Cards")
				assert.are.equal("  Tackle Board: While Tackle Board was off", cards[3])
				assert.are.equal("    line: Tackle Board: 1 done today · Campfire 7 days", cards[7])
				assert.are.equal("    Tackle Board moments: Notice complete, Campfire 7 days", cards[8])
			end
		)

		it("reads today at the file's write time without --now (TKB-R12)", function()
			local today =
				lineStarting(section(run(ACCOUNTS .. "M7#1", "--catalogue", CATALOGUE), "== Tackle Board"), "today:")
			assert.truthy(today:match("^today: day %d+ at %d+%-%d+%-%d+ %d+:%d+:%d+ UTC %(the file's write time%)"))
		end)

		it(
			"prints each goal's need from its record, without stranded flags, when the catalogue can't be loaded (TKB-R44)",
			function()
				local missing = "spec/scripts/fixtures/no-such-Catalogue.lua"
				local stored = section(run(ACCOUNTS .. "M7#1", "--catalogue", missing, "--now", NOW), "== Tackle Board")
				local prefix = "fingerprint: can't be checked: " .. missing .. " can't load: "
				assert.are.equal(prefix, stored[19]:sub(1, #prefix))
				assert.are.equal(
					"  4. "
						.. GUID
						.. '1792076703-0: Notice species, "2 Item 999001", 0 of 2 (need from the record), tier 2, pays 15,'
						.. " need 2",
					lineStarting(stored, "  4. ")
				)
			end
		)
	end)

	-- M7-Stale#1: an unstarted board's projection built under another rules version and catalogue, one Cast behind
	-- its log; AceDB left the celebrated set and trackerCollapsed out of the file.
	it(
		"flags a stale Tackle Board projection, and reads an unstarted board and the left-out defaults (TKB-R2, TKB-R81, LOG-R72)",
		function()
			local out, _, code = run(ACCOUNTS .. "M7-Stale#1", "--catalogue", CATALOGUE)
			assert.are.equal(0, code)
			assert.are.same({
				"== Tackle Board (PagleTackleBoardDB)",
				"records: no TackleBoard A1 entries in PagleLog",
				"projection: lastSeq 3, logId 6f2a9c4e1b7d3580, fingerprint fedcba9876543210, rulesVersion 1000",
				"logId: matches PagleLog's",
				"lastSeq: differs from PagleLog's length (4 entries)",
				"rulesVersion: 1000 DIFFERS from the Tackle Board's 5002 (1000 × TKB_RULES_VERSION 5 + Core's"
					.. " SESSION_RULES_VERSION 2), so Core rebuilds it at login (TKB-R81, LOG-R72)",
				"fingerprint: DIFFERS from the catalogue's 0123456789abcdef, "
					.. CATALOGUE
					.. ", so Core rebuilds it at login (LOG-R70, LOG-R72)",
				-- TKB-R2, TKB-R81: unstarted, it still learns zones and items from every Cast.
				"started: no, the board isn't started (TKB-R2)",
				"zones: 1 (12 last at 2026-10-14 16:00:00 UTC)",
				"caught: 1 (6303)",
				"celebrated goals: none, titles: none",
				"celebrated: every completed goal is in it",
				"celebrated: every earned title is in it",
				"tracker: false",
				"trackerCollapsed: false (not saved: the default)",
			}, section(out, "== Tackle Board"))
		end
	)

	it("says no Tackle Board projection is stored before the first build (LOG-R72)", function()
		assert.are.same({
			"== Tackle Board (PagleTackleBoardDB)",
			"records: no PagleLog to read",
			"projection: none stored (no build has finished, LOG-R72)",
			"celebrated goals: none, titles: none",
			"tracker: true (not saved: the default)",
			"trackerCollapsed: false (not saved: the default)",
		}, section(run(ACCOUNTS .. "M7-New#1"), "== Tackle Board"))
	end)

	it("says in one line that Pagle_TackleBoard.lua is missing (in-game-verification.md › Tackle Board)", function()
		assert.are.same(
			{ "== Tackle Board: can't read " .. ACCOUNTS .. "M6#1/SavedVariables/Pagle_TackleBoard.lua: missing" },
			section(run(ACCOUNTS .. "M6#1", "--catalogue", CATALOGUE), "== Tackle Board")
		)
	end)

	describe("on an account after a /pagle dev probe (#261, in-game-verification.md › Probe)", function()
		local out, err, code = run(ACCOUNTS .. "M8-Probe#1")

		it("prints each check's facts and an ok or FAIL line naming the rule a miss changes", function()
			assert.are.equal("", err)
			assert.are.equal(0, code)
			assert.are.same({
				"== Probe (PagleDB.global.probe): 2026-11-04 11:00:00 UTC, build 1.61.0 71002 (Nov  3 2026),"
					.. " interface 16100, enUS",
				"check 3: C_Weather keys GetCurrentWeather; GetCurrentWeather() = 0, 0 in Darkshore",
				"    zone Darkshore, map 1439",
				"  FAIL  only zeros or nothing: probe again while it rains; LOG-R21 keeps weather unrecorded",
				'check 8: quest 6607 by C_QuestLog.GetTitleForQuestID: none at once, "Nat Pagle, Angler Extreme" 2 s'
					.. " later",
				"  ok    quest 6607 exists: DATA-R22 may make Nat Pagle's quest fish Legends",
				"check 11: 173 inventory names checked, 2 missing: C_GameRules.IsHardcoreActive, GetCurrentRegion",
				"  FAIL  C_GameRules.IsHardcoreActive, GetCurrentRegion missing: each rule that uses them changes"
					.. " (CORE-R23)",
				"check 12: GetBuildInfo() = 1.61.0, 71002, Nov  3 2026, 16100; WOW_PROJECT_ID 18, WOW_PROJECT_CAMELOT 18",
				"  ok    CORE-R4's check passes",
				"  FAIL  interface 16100, but a TOC says 16001: bump ## Interface in every TOC (CORE-R2)",
				"check 16: MAX_EQUIPMENT_SETS_PER_PLAYER = 10; 2 sets: Pagle Fishing, Pagle Previous",
				"  ok    8 free of 10: QOL-R42 needs 2, for Pagle Fishing and Pagle Previous (QOL-R103)",
				"check 18: GetSecondsUntilDailyReset() = 3600, GetSecondsUntilWeeklyReset is missing;"
					.. " GetServerTime() = 1793790000, GetGameTime() = 11:00; TKB-R11's fallback day starts at"
					.. " 1793750400",
				"  FAIL  GetSecondsUntilWeeklyReset is missing: TKB-R11's fallback runs (TKB-R10, TKB-R11)",
				"check 19: GetCurrentRegion is missing",
				"  FAIL  no GetCurrentRegion: LOG-R69's default length unit is always cm",
				"check 20: bit is missing; 4 of 4 LOG-R66 vectors match",
				"    Player-4395-0A1B2C3D-1791731747-0:1: h 2657620567 band 2, LOG-R66 says h 2657620567 band 2",
				"    Player-4395-0A1B2C3D-1791731747-0:2: h 4227872046 band 4, LOG-R66 says h 4227872046 band 4",
				"    Player-4395-0A1B2C3D-1791731762-1:1: h 1190098033 band 2, LOG-R66 says h 1190098033 band 2",
				"    Player-1-00000001-1700000000-0:1: h 3063819173 band 3, LOG-R66 says h 3063819173 band 3",
				"  FAIL  no bit library: LOG-R66's Simulated Size hash can't run",
				'check 21: 7620 is "Fishing", icon 136245; 2 listed spells, known 7620 (by C_SpellBook.IsSpellKnown);'
					.. " channels seen 7620 x3",
				"    spell 7620: Fishing, icon 136245, known true",
				"    spell 1240948: Fishing Rank 5, icon 136245, known false",
				"  FAIL  1240948's name isn't 7620's (DATA-R39, QOL-R24)",
				"probe: 7 of 9 checks FAIL: 3, 11, 12, 18, 19, 20, 21",
			}, section(out, "== Probe"))
		end)
	end)

	it("says so when no probe is stored, or Pagle.lua can't be read (#261)", function()
		assert.are.same(
			{ "== Probe (PagleDB.global.probe)", "probe: none stored (/pagle dev probe, then /reload)" },
			section(run(ACCOUNTS .. "M1#1"), "== Probe")
		)
		assert.are.same({ "== Probe: can't read Pagle.lua: missing" }, section(run(ACCOUNTS .. "M0#1"), "== Probe"))
	end)

	-- M8-XP#1 holds Activity XP totals of PagleLog's logId, a Prestige whose P1 carries their sum, and Coins totals of
	-- another log's logId, as a PagleDB carried over to a new log holds them before its first login (#291).
	describe("on an account with Activity XP (#291, core/activity-xp.md › Data)", function()
		local out, err, code = run(ACCOUNTS .. "M8-XP#1")

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it(
			"prints each Module's total, their sum and whose logId each store of totals has (AXP-R3, SHOP-R3)",
			function()
				-- AXP-R3: the Activity XP totals are PagleLog's; PUSH-R13: no pushed file accepted yet, so no seq.
				assert.are.same({
					"== Activity XP (PagleDB.global.activityXP.earned): total 850",
					"Hunts: 600",
					"TackleBoard: 250",
					"logId: 5c2e9a7b1d3f4068, PagleLog's",
					"pushed seq: none accepted (PUSH-R13)",
				}, section(out, "== Activity XP"))
				-- SHOP-R3: the Coins totals belong to another log, so Core empties them at the next login.
				assert.are.same({
					"== Wallet (PagleDB.global.coins.earned): balance 40",
					"Ledger: 40",
					"logId: 0000000000000001, DIFFERS from PagleLog's 5c2e9a7b1d3f4068, so Core empties these totals at"
						.. " login (SHOP-R3)",
					"wallet projection: none stored (no build has finished, LOG-R72)",
				}, section(out, "== Wallet"))
			end
		)

		it("lists the P1 entry with its Activity XP snapshot (AXP-R5, LOG-R38)", function()
			assert.are.equal(
				"  rank 1, 850 Activity XP, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-11-03 10:06:40 UTC",
				lineStarting(section(out, "== Catch log"), "  rank 1,")
			)
		end)

		it("reads a PagleDB from before M8, with no Activity XP or logIds, as none stored", function()
			assert.are.same({
				"== Activity XP (PagleDB.global.activityXP.earned): total 0, no Module has reported Activity XP",
				"logId: none stored (a fresh log's, or no Module has reported since PagleLog had one)",
				"pushed seq: none accepted (PUSH-R13)",
			}, section(run(ACCOUNTS .. "M4#1", "--catalogue", CATALOGUE), "== Activity XP"))
		end)
	end)

	-- M8-Wagers#1 holds what the M8 Hunt Events exit check reads (#309, roadmap.md › M8 Hunt Events, steps 2, 5 and 7):
	-- a PagleLog on a realm at UTC−7 with two fallback runs of darkshore_moonlight logged, in slots 0 and 3 (from
	-- ROTATION_ORIGIN 2026-10-19 15:00 UTC, 72 h each, HNT-R152), a `def` part of a pushed definition, a `run` record
	-- whose end is before its start and a `wager` record (both of which Hunts' codec skips), a Tackle Board record, Casts
	-- in Darkshore in both runs, and a P1 snapshot of 15000 Activity XP; PagleDB with Activity XP and Coins totals of
	-- PagleLog's logId and pushed seq 7; a Ledger at prestige rank 1 with 1500 XP of its own; and Hunts' state, written
	-- by hand: the first run ended with only its Timed Hunt's mark, the second settled, and 25 runs settled in all with
	-- ladder step 25 reached (the 23 earlier settled runs are left out of `runs` to keep the fixture short; the reader
	-- reads the state as stored and never folds the log). Its celebrated set holds the second run without its Timed
	-- mark, and no ladder step. Read against spec/scripts/fixtures/HuntList.lua and EventList.lua (one low-band event,
	-- darkshore_moonlight) at --now 1795600000, 2026-11-25 09:46:40 UTC, in slot 12: the first run ended 33 days
	-- before, the second 25.
	describe(
		"on an account after the M8 Hunt Events exit check's steps (#309, roadmap.md › M8 Hunt Events)",
		function()
			local NOW = "1795600000"
			local function read(now)
				return run(
					ACCOUNTS .. "M8-Wagers#1",
					"--catalogue",
					CATALOGUE,
					"--huntlist",
					HUNTLIST,
					"--eventlist",
					EVENTLIST,
					"--now",
					now
				)
			end
			local out, err, code = read(NOW)
			local SECOND = "  darkshore_moonlight@1793199600: darkshore_moonlight, source r (the rotation), "
			local SETTLED = ", settled realm 2026-10-29 22:30, server 2026-10-30 05:30:00 UTC (HNT-R146)"

			it("exits 0 and writes nothing to stderr", function()
				assert.are.equal(0, code)
				assert.are.equal("", err)
			end)

			it(
				"prints Hunts' records, runs, rotation, ladder, Activity XP and celebrated runs (HNT-R89–R92, HNT-R142–R153)",
				function()
					-- LOG-R40, HNT-R150, HNT-R154: Hunts' A1 entries by kind, the TackleBoard one not counted; Hunts'
					-- codec skips a run whose end isn't after its start, and a kind it doesn't append.
					-- HNT-R136: rules version 2; DATA-R72, DATA-R98: the fingerprint joins the Hunt list's and the pool's.
					-- HNT-R89: " · 25 wagers settled", the ladder title counted among the titles (HNT-R148, HNT-R165).
					-- HNT-R148: 25 settled, step 25 earned at the second run's completion. HNT-R110, HNT-R115, AXP-R3:
					-- Hunts' Coins and Activity XP, and Core's stored total for Hunts the same.
					-- HNT-R142, HNT-R143, HNT-R145, HNT-R146, HNT-R150: each known run by start, its bounds in realm time
					-- (LOG-R49, UTC−7 from the latest Cast) and server time, ended at --now, each Hunt's count and tiers
					-- within it, and the second's completion.
					-- HNT-R152, HNT-R153: slot 12 is low, its pick the band's one event, no run logged over it, 2 d 5 h
					-- 13 min to its end.
					-- HNT-R90: the celebrated runs and ladder; HNT-R91: the second run's Timed mark and step 25 were never
					-- shown; HNT-R92: the first run ended more than 30 days ago, so its mark isn't flagged.
					-- hunts.md › PagleHuntsDB: wagersCollapsed and lastHintNod saved, companionHint left out at its default.
					assert.are.same({
						"== Hunts (PagleHuntsDB)",
						"records: 5 Hunts A1 entries in PagleLog: run 3, def 1, wager 1",
						"records Hunts skips: 2 (seq 8, 9) (HNT-R150, HNT-R154)",
						"projection: lastSeq 14, logId 9a4c2e6b8d1f3057, fingerprint"
							.. " 0123456789abcdef+5eed5eed5eed5eed+e7e7e7e7e7e7e7e7, rulesVersion 2",
						"logId: matches PagleLog's",
						"lastSeq: equals PagleLog's length (14 entries)",
						"rulesVersion: Hunts', 2 (HNT-R136)",
						"Hunt list: " .. HUNTLIST .. ", fingerprint 5eed5eed5eed5eed, 6 Hunts in 3 sets",
						"fingerprint: the catalogue's plus the Hunt list's and the event pool's (DATA-R72, DATA-R98)",
						"summary line: Hunts: 0 of 5 done · 1 title · 25 wagers settled, at 2026-11-25 09:46:40 UTC (--now)"
							.. " (HNT-R89)",
						"state: 6 Casts, 2390 Coins, 0 Hunts with progress, 0 titles",
						"titles earned: none",
						"settled: 25 (HNT-R148)",
						"ladder: 1 of 3 steps (25 / 50 / 100) (HNT-R148)",
						"  25: realm 2026-10-29 22:30, server 2026-10-30 05:30:00 UTC",
						"coins: 2390 (HNT-R110), xp: 17650 (HNT-R115), equals Core's stored Hunts total (AXP-R3)",
						"runs: 2 known, by start, at 2026-11-25 09:46:40 UTC (--now), realm time at the log's realm clock"
							.. " (UTC-07:00) (HNT-R150)",
						"  darkshore_moonlight@1792422000: darkshore_moonlight, source r (the rotation), ended (HNT-R143)",
						"    start realm 2026-10-19 08:00, server 2026-10-19 15:00:00 UTC;"
							.. " end realm 2026-10-22 08:00, server 2026-10-22 15:00:00 UTC",
						"    darkshore_moonlight_haul: count 2, tiers 0 of 3 (20 / 50 / 100)",
						"    darkshore_moonlight_grouper: count 2, tiers 0 of 2 (3 / 8)",
						"    darkshore_moonlight_timed: count 1, tiers 1 of 1 (1)",
						SECOND .. "ended (HNT-R143)" .. SETTLED,
						"    start realm 2026-10-28 08:00, server 2026-10-28 15:00:00 UTC;"
							.. " end realm 2026-10-31 08:00, server 2026-10-31 15:00:00 UTC",
						"    darkshore_moonlight_haul: count 20, tiers 1 of 3 (20 / 50 / 100)",
						"    darkshore_moonlight_grouper: count 3, tiers 1 of 2 (3 / 8)",
						"    darkshore_moonlight_timed: count 1, tiers 1 of 1 (1)",
						"rotation: slot 12 (low), 2026-11-24 15:00:00 UTC to 2026-11-27 15:00:00 UTC, pick darkshore_moonlight,"
							.. " no logged run covers it, ends in 2 d 5 h 13 min (HNT-R152, HNT-R153)",
						"celebrated tiers: none",
						"celebrated titles: none",
						"celebrated runs: 1",
						"  darkshore_moonlight@1793199600: tiers darkshore_moonlight_grouper 1, darkshore_moonlight_haul 1,"
							.. " settled, endsAt 2026-10-31 15:00:00 UTC",
						"celebrated ladder: none",
						"celebrated: MISSING darkshore_moonlight@1793199600 darkshore_moonlight_timed tier 1 (HNT-R90, HNT-R91)",
						"celebrated: MISSING ladder step 25 (HNT-R90, HNT-R91)",
						"celebrated: 1 run ended more than 30 days ago left out (HNT-R92): darkshore_moonlight@1792422000",
						"pins: none",
						"tracker.shown: true (not saved: the default)",
						"tracker.collapsed: true",
						"windowMoments: false (not saved: the default)",
						"showCompleted: false (not saved: the default)",
						"tracker.wagersCollapsed: true",
						"companionHint: true (not saved: the default)",
						"lastHintNod: 1793200000 (2026-10-28 15:06:40 UTC)",
					}, section(out, "== Hunts"))
				end
			)

			it(
				"reads the run as on or ahead, and the slot then, at an earlier --now (HNT-R143, HNT-R152, HNT-R153)",
				function()
					-- 2026-10-29 18:53:20 UTC: the second run is on, and covers slot 3, its own slot (HNT-R153: nothing is
					-- logged over a covered slot). The first run ended 7 days before, so its uncelebrated mark is flagged now
					-- (HNT-R92).
					local on = section(read("1793300000"), "== Hunts")
					assert.are.equal(SECOND .. "on (HNT-R143)" .. SETTLED, lineStarting(on, SECOND))
					assert.are.equal(
						"rotation: slot 3 (low), 2026-10-28 15:00:00 UTC to 2026-10-31 15:00:00 UTC, pick darkshore_moonlight,"
							.. " covered by darkshore_moonlight@1793199600, ends in 1 d 20 h 6 min (HNT-R152, HNT-R153)",
						lineStarting(on, "rotation:")
					)
					assert.are.equal(
						"celebrated: MISSING darkshore_moonlight@1792422000 darkshore_moonlight_timed tier 1 (HNT-R90, HNT-R91)",
						lineStarting(on, "celebrated: MISSING darkshore_moonlight@1792422000")
					)
					assert.is_nil(lineStarting(on, "celebrated: 1 run ended"))
					-- 2026-10-27 11:20 UTC: the second run is still ahead; slot 2 is high, and the pool has no high event.
					local ahead = section(read("1793100000"), "== Hunts")
					assert.are.equal(SECOND .. "ahead (HNT-R143)" .. SETTLED, lineStarting(ahead, SECOND))
					assert.are.equal(
						"rotation: slot 2 (high), 2026-10-25 15:00:00 UTC to 2026-10-28 15:00:00 UTC, pick none (no high event"
							.. " in the pool), no logged run covers it, ends in 1 d 3 h 40 min (HNT-R152, HNT-R153)",
						lineStarting(ahead, "rotation:")
					)
					-- Before the rotation's starting point there is no slot (HNT-R152, HNT-R204).
					assert.are.equal(
						"rotation: no slot before its starting point, 2026-10-19 15:00:00 UTC (HNT-R152, HNT-R204)",
						lineStarting(section(read("1792000000"), "== Hunts"), "rotation:")
					)
				end
			)

			it(
				"prints the climb's Activity XP since the latest Prestige snapshot, and the level with it (LED-R31, LED-R37)",
				function()
					-- LED-R37: the climb's Activity XP is Core's stored total, 17650 + 300, less the latest P1's 15000.
					-- LED-R30, LED-R31: 1500 + 2950 = 4450 XP climbs steps of 1080, 1160 and 1240 to level 4 (1500 alone
					-- reaches level 2); LED-R35: the peak is 60 after a Prestige. LED-R2: the Ledger's rules version 10.
					local ledger = section(out, "== Ledger (")
					assert.are.equal("rulesVersion: the Ledger's, 1002 (LED-R2)", ledger[5])
					assert.are.equal(
						"climb: prestige rank 1, 1500 XP of its own, Prestige snapshot 15000, the climb's Activity XP 2950"
							.. " (Core's stored total 17950 − 15000, LED-R37), computed level 4, peak level 60",
						lineStarting(section(out, "== Ledger M4"), "climb:")
					)
				end
			)

			it(
				"prints the Activity XP totals, the P1 snapshot, the Coins logId and the pushed seq (AXP-R3, PUSH-R13)",
				function()
					assert.are.same({
						"== Activity XP (PagleDB.global.activityXP.earned): total 17950",
						"Hunts: 17650",
						"TackleBoard: 300",
						"logId: 9a4c2e6b8d1f3057, PagleLog's",
						"pushed seq: 7 (PUSH-R13)",
					}, section(out, "== Activity XP"))
					assert.are.equal(
						"logId: 9a4c2e6b8d1f3057, PagleLog's",
						lineStarting(section(out, "== Wallet"), "logId:")
					)
					-- LOG-R38, AXP-R5: the P1 carries the total at the Prestige.
					assert.are.equal(
						"  rank 1, 15000 Activity XP, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-27 11:20:00 UTC",
						lineStarting(section(out, "== Catch log"), "  rank 1,")
					)
				end
			)
		end
	)

	-- M8.5#1 holds an onboarding state partway through (core/onboarding.md › Data): the Letter put off once, the guide
	-- left at Moments with a restriction to reopen it after, two notes and one First look seen, two First evening items
	-- done before the list docked, and three characters, one of them not in PagleLog's (#320).
	describe("on an account partway through onboarding (#320, core/onboarding.md › Data)", function()
		it("prints the Onboarding section from PagleDB.global.onboarding (ONB-R1–R3, Data)", function()
			local out, _, code = run(ACCOUNTS .. "M8.5#1")

			assert.are.equal(0, code)
			assert.are.same({
				"== Onboarding (PagleDB.global.onboarding)",
				"schemaVersion: 2",
				"letter: later (Later pressed once: the Letter shows once more, ONB-R12)",
				"guideStep: moments",
				"stepsSeen: 3 (box, moments, welcome)",
				"guideDone: false, skipped: false, reopen: true",
				"notesOn: true",
				"notesSeen: 2 (core.nod, core.toast)",
				"looksSeen: 1 (ledger.journal)",
				"evening: shown false, closed false, done 2 (cast, catch)",
				"characters: 3",
				"  Player-4618-0A1B2C3D: Ada Brook",
				"  Player-4618-0B2C3D4E: Bram Reed",
				"  Player-4618-0C3D4E5F: not in PagleLog's characters",
			}, section(out, "== Onboarding"))
		end)

		it("says so when no state is stored yet, or Pagle.lua can't be read (ONB-R1)", function()
			assert.are.same({
				"== Onboarding (PagleDB.global.onboarding)",
				"schemaVersion: 1",
				"onboarding: none stored, so the next login adds it (ONB-R1)",
			}, section(run(ACCOUNTS .. "M1#1"), "== Onboarding"))
			assert.are.same(
				{ "== Onboarding: can't read Pagle.lua: missing" },
				section(run(ACCOUNTS .. "M0#1"), "== Onboarding")
			)
		end)
	end)

	-- M8-Reverify#1 holds what launch re-verification checks 2, 4-7 and 10 read (#262): Ada's Casts by day and night
	-- (a realm 7 hours behind UTC; one Cast's realm minute reads 8 hours behind), one with no realm minute, one each in
	-- zone 0, an alias source (16510) and a zone with no catch data (10); a diagnostics buffer with hovered pool texts
	-- and two deDE entries whose texts didn't resolve; and hand-written load timings in PagleDB.global.probe.timings
	-- (a /reload's, with two addons loaded after Core), with no probe beside them. Its catalogue is
	-- spec/scripts/fixtures/ReverifyCatalogue.lua.
	describe("on an account for launch re-verification checks 2, 4-7 and 10 (#262)", function()
		local account = ACCOUNTS .. "M8-Reverify#1"
		local out, err, code = run(account, "--catalogue", "spec/scripts/fixtures/ReverifyCatalogue.lua")
		local reverify = section(out, "== Re-verification")

		it("exits 0, and reads the timings alone as no probe", function()
			assert.are.equal("", err)
			assert.are.equal(0, code)
			assert.are.same(
				{ "== Probe (PagleDB.global.probe)", "probe: none stored (/pagle dev probe, then /reload)" },
				section(out, "== Probe")
			)
		end)

		it("prints PagleLog's entry count and Pagle.lua's size in bytes (check 2)", function()
			local bytes = #readFile(account .. "/SavedVariables/Pagle.lua")
			assert.are.same({
				"== Re-verification (launch re-verification checks 2, 4-7 and 10)",
				("check 2: PagleLog 14 entries, Pagle.lua %s bytes (0.00 MiB)"):format(
					tostring(bytes):gsub("^(%d)(%d%d%d)$", "%1,%2")
				),
			}, { unpack(reverify, 1, 2) })
		end)

		it(
			"prints the load timings after Core's files loaded, the /reload's logout before them, each addon loaded"
				.. " after Core, and each projection on its own line, against the budget"
				.. " (checks 2 and 10, LOG-R71)",
			function()
				assert.are.same({
					"check 2, 10: load timings of the login at 2026-10-12 16:45:00 UTC (dev mode on), 14 entries at load,"
						.. " after Core's files loaded:",
					"  Core's files loaded    0.0 ms",
					"  ADDON_LOADED           849.8 ms",
					"  log opened             850.5 ms",
					"  PLAYER_LOGIN           2099.5 ms",
					"  PLAYER_ENTERING_WORLD  3200.2 ms",
					"  projections idle       3950.0 ms",
					"  the /reload's PLAYER_LOGOUT 2500.0 ms before Core's files loaded: every addon's logout, the"
						.. " SavedVariables written, and the addons before Core loaded",
					"  addons loaded after Core, until PLAYER_LOGIN, each with the time since the one before:",
					"    Pagle_Ledger             1100.1 ms (+250.4 ms)",
					"    Leatrix_Plus             1899.9 ms (+799.8 ms)",
					"    then PLAYER_LOGIN        2099.5 ms (+199.6 ms)",
					"  fieldReport: rebuild of 14 entries, 3200.5 ms to 3204.0 ms (3.5 ms), 1 frame, at once, longest"
						.. " 3.50 ms (LOG-R71: 500 pending entries or fewer)",
					"  wallet: rebuild of 14 entries, 3204.1 ms to 3204.5 ms (0.4 ms), 1 frame, at once, longest 0.40 ms"
						.. " (LOG-R71: 500 pending entries or fewer)",
					"  Ledger: replay of 2 entries, 3204.6 ms to 3205.0 ms (0.4 ms), 1 frame, at once, longest 0.40 ms"
						.. " (LOG-R71: 500 pending entries or fewer)",
					"  Stats: rebuild of 14 entries, 3205.1 ms to 3949.5 ms (744.4 ms), 3 frames, longest frame 5.25 ms of"
						.. " the 4 ms budget (LOG-R71): OVER",
					"check 10: every projection caught up 749.8 ms after PLAYER_ENTERING_WORLD",
				}, { unpack(reverify, 3, 19) })
			end
		)

		it(
			"prints the night Casts with their first and last realm minute, the Casts with no realm minute, and the"
				.. " realm offsets (check 4, LOG-R49, DATA-R36)",
			function()
				assert.are.same({
					"check 4: 3 Casts at night (realm 21:00 to 06:00, the catalogue's night window, DATA-R36), realm"
						.. " minutes 21:03 to 05:58",
					"check 4: 1 Cast with no realm minute, seq 8",
					"check 4: the realm's UTC offset, from each Cast's realm minute (LOG-R49): UTC-08:00: 1 Cast,"
						.. " UTC-07:00: 10 Casts: more than one, so a clock change or a wrong realm minute",
				}, { unpack(reverify, 20, 22) })
			end
		)

		it(
			"prints each hovered text and locale as the P rows group them, and each unresolved text with its locale"
				.. " (checks 5 and 7, LOG-R81, REP-R22)",
			function()
				assert.are.same({
					"check 5, 7: the diagnostics buffer (PagleDB.global.diagnostics, LOG-R81): 6 entries, deDE 2, enUS 4",
					"check 5: hovered texts, as the Field report's P rows group them (REP-R22): 3",
					'  enUS "Floating Wreckage": 1 Cast in area 12 (1); 6303x1',
					'  enUS "Oily Blackmouth School": 3 Casts in area 12 (2), 87 (1); 6291x1, 6303x2',
					'  enUS "School of Whimsyfin": 1 Cast in area 40 (1); nothing caught',
					"check 7: entries whose zone or subzone text didn't resolve (LOG-R22): 2",
					'  Player-4618-0A1B2C3D-1791820000-0 deDE: zone "Dunkelküste", subzone "Die lange Bucht", stored as'
						.. " 0/0",
					'  Player-4618-0A1B2C3D-1791821200-0 deDE: zone "Dämmerwald", subzone "Rabenflucht", stored as 10/0',
				}, { unpack(reverify, 23, 30) })
			end
		)

		it(
			"prints the Casts per zone and subzone, flagging zone 0, an alias source and no catch data (check 6,"
				.. " LOG-R22, DATA-R31, DATA-R32)",
			function()
				assert.are.same({
					"check 6: Casts per zone/subzone areaID (catalogue: spec/scripts/fixtures/ReverifyCatalogue.lua):",
					"  0/0: 1 Cast  FLAGGED: zone 0, unresolved (LOG-R22)",
					"  10/0: 1 Cast  FLAGGED: 10 has no catch data (hasData = false, DATA-R31)",
					"  12/0: 6 Casts",
					"  12/87: 1 Cast",
					"  40/0: 2 Casts",
					"  16510/0: 1 Cast  FLAGGED: 16510 is an alias source of 12, never stored (LOG-R22, DATA-R32); 16510"
						.. " has no catch data (hasData = false, DATA-R31)",
					"check 6: 3 of 6 places flagged",
				}, { unpack(reverify, 31) })
			end
		)
	end)

	it("says when no load timings are stored, or Pagle.lua can't be read (#262)", function()
		local reverify = section(run(ACCOUNTS .. "M1#1", "--catalogue", CATALOGUE), "== Re-verification")
		assert.are.equal(
			"check 2, 10: no load timings (PagleDB.global.probe.timings): /pagle dev on, then log in; that login's"
				.. " are saved at the next /reload or logout",
			reverify[3]
		)
		assert.are.same(
			{ "== Re-verification: can't read Pagle.lua: missing" },
			section(run(ACCOUNTS .. "M0#1"), "== Re-verification")
		)
	end)

	describe("on a Pagle.lua too large for Lua 5.1 to load in one piece (#262)", function()
		-- A PagleLog whose entries run past SPLIT_RUN (1,000) string items, in the client's layout.
		local lines = { "", "PagleLog = {", '["entries"] = {' }
		for i = 1, 1500 do
			lines[#lines + 1] = ('"C1|1|%d|0|c|494|1439|1|12|0|86|25||||6303x1", -- [%d]'):format(1791731000 + i, i)
		end
		lines[#lines + 1] = "},"
		lines[#lines + 1] = '["logId"] = "3f9a2c1e7b0d4a65",'
		lines[#lines + 1] = "}"
		lines[#lines + 1] = "PagleDB = {"
		lines[#lines + 1] = '["global"] = {'
		lines[#lines + 1] = '["texts"] = {'
		lines[#lines + 1] = '"a", -- [1]'
		lines[#lines + 1] = "},"
		lines[#lines + 1] = "},"
		lines[#lines + 1] = "}"
		local text = table.concat(lines, "\r\n") .. "\r\n"

		it("loads each long run of strings apart, to the same globals a load in one piece gives", function()
			local whole = assert(script.wtf.loadSavedVariables(text, "Pagle.lua"))
			local split, runs = script.wtf.loadSplit(text, "Pagle.lua")
			assert.are.equal(1, runs)
			assert.are.same(whole, split)
			assert.are.equal(1500, #split.PagleLog.entries)
		end)

		it("still runs each part as data: a call in it fails instead of running", function()
			local planted = text:gsub('"C1|1|1791731700|', '"x", print("ran"), "C1|1|1791731700|', 1)
			local split, err = script.wtf.loadSplit(planted, "Pagle.lua")
			assert.is_nil(split)
			assert.matches("attempt to call global 'print'", err, 1, true)
		end)
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

	it(
		"reads Pagle, Pagle_Ledger, Pagle_QoL, Pagle_Hunts, Pagle_Stats and Pagle_TackleBoard's state by default"
			.. " (in-game-verification.md › Addons)",
		function()
			local out = run(ACCOUNTS .. "M2#1", "--character", "70/Ada-Brook/")
			assert.are.same({
				"== Addons (70/Ada-Brook/AddOns.txt)",
				"Pagle: enabled",
				"Pagle_Ledger: enabled",
				"Pagle_QoL: disabled",
				"Pagle_Hunts: not listed (its TOC's default state applies)",
				"Pagle_Stats: not listed (its TOC's default state applies)",
				"Pagle_TackleBoard: not listed (its TOC's default state applies)",
			}, section(out, "== Addons"))
			local m7 = run(ACCOUNTS .. "M7#1", "--character", "70/Ada-Brook")
			assert.are.equal("Pagle_TackleBoard: enabled", section(m7, "== Addons")[7])
		end
	)

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
			["an --item that isn't an ID"] = { ACCOUNTS .. "M1#1", "--item", "6303a" },
			["a --now that isn't a server time"] = { ACCOUNTS .. "M1#1", "--now", "today" },
			["a --hunt with no ID"] = { ACCOUNTS .. "M1#1", "--hunt" },
			["a --stats-item with no --area"] = { ACCOUNTS .. "M6#1", "--stats-item", "13759" },
			["an --area with no --stats-item"] = { ACCOUNTS .. "M6#1", "--area", "12" },
			["a --skill that isn't a number"] = { ACCOUNTS .. "M6#1", "--skill", "high" },
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
