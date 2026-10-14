-- scripts/read-wtf.lua against fixture WTF folders under spec/scripts/fixtures/WTF/, written the way the client
-- writes them (CRLF line ends, the client's SavedVariables layout). M1#1 holds a Catch log and a !BugGrabber file
-- with several sessions, M0#1 a client where Pagle saves nothing yet, Code#1 files that must not run as code. M2#1
-- and M2-Stale#1 hold a Pagle_Ledger.lua as well, for the Ledger, Wallet and Cards sections the M2 exit check reads
-- (#103, #104). M3#1 holds an M3 Ledger and a Field report projection, for what the M3 exit check reads (#145,
-- #146). M4#1 holds what the M4 exit check reads (#173, #174). The Ledger runs read their world from
-- spec/scripts/fixtures/Catalogue.lua (--catalogue), so the lines the Ledger's logic computes are counted by hand,
-- and don't move with the generated catalogue.

local ACCOUNTS = "spec/scripts/fixtures/WTF/Account/"
local CATALOGUE = "spec/scripts/fixtures/Catalogue.lua"

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
			-- state has no items, Uncharted list or zone ranks, and M2's rules version, 100, isn't M4's 301 (LED-R2:
			-- LEDGER_RULES_VERSION 3 × 100 + Core's SIZE_RULES_VERSION 1, LOG-R68).
			-- Completion over the fixture catalogue's world (LED-R70, LED-R71): Species 6303 and 6358 caught, of 6291,
			-- 6299, 6303 and 13759 listed and 6358 caught; nothing else; 2 of 11 is 18%. 148 and 1519 aren't charted.
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 8, logId 5d2e8a0c4b1f7e93, fingerprint a1b2c3d4, rulesVersion 100",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (8 entries)",
				"rulesVersion: 100 DIFFERS from the Ledger's 301, so Core rebuilds it at login (LED-R2, LOG-R72)",
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
				"completion: 18% (2 of 11): Species 2 of 5, junk 0 of 1, treasure 0 of 1, trophy 0 of 2, zones 0 of 2;"
					.. " Legends 0 of 1",
				"celebrated: highest level 3, 30 Coins",
				"celebrated Species: 2 (6303, 6358)",
				"celebrated Species × zone pairs: 2 (6303:1519, 6358:148)",
				"celebrated zones: 2 (148 rank 0, 1519 rank 0)",
				"celebrated Species stars: none",
				"celebrated family stars: none",
				"celebrated items: none",
				"celebrated Uncharted: none",
				"celebrated Skill Milestones: 1 (75)",
			}, section(out, "== Ledger"))
		end)

		it("prints each Module's reported total and the balance (SHOP-R3, SHOP-R12)", function()
			-- Nothing spends before the Curio Shop (M4), so the balance is 30 + 12, and there's no wallet projection
			-- (SHOP-R11) yet.
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 42",
				"Hunts: 12",
				"Ledger: 30",
				"wallet projection: none stored (no build has finished, LOG-R72)",
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
		local out, _, code = run(ACCOUNTS .. "M2-Stale#1", "--catalogue", CATALOGUE)

		it("flags the logId and the length that differ from PagleLog's (LOG-R72)", function()
			assert.are.equal(0, code)
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 8, logId 5d2e8a0c4b1f7e93, fingerprint a1b2c3d4, rulesVersion 100",
				"logId: DIFFERS from PagleLog's 7c0b19e4d3a2f658, so Core rebuilds it at login (LOG-R72)",
				"lastSeq: differs from PagleLog's length (1 entry)",
				"rulesVersion: 100 DIFFERS from the Ledger's 301, so Core rebuilds it at login (LED-R2, LOG-R72)",
				"world: "
					.. CATALOGUE
					.. ", fingerprint 0123456789abcdef (NOT the projection's: the lines computed below use it), 2 charted zones",
				"state: 0 Casts, 0 Catches, 0 XP (Angler Level 1, 0 into it, next step 1080), 0 Coins, 0 Species",
				"state curio items: none",
				"state trophy items: none",
				"state Uncharted: none",
				"state zones: none",
				"completion: 0% (0 of 10): Species 0 of 4, junk 0 of 1, treasure 0 of 1, trophy 0 of 2, zones 0 of 2;"
					.. " Legends 0 of 1",
				"celebrated: highest level none, 0 Coins",
				"celebrated Species: none",
				"celebrated Species × zone pairs: none",
				"celebrated zones: none",
				"celebrated Species stars: none",
				"celebrated family stars: none",
				"celebrated items: none",
				"celebrated Uncharted: none",
				"celebrated Skill Milestones: none",
			}, section(out, "== Ledger"))
		end)

		it("reads a PagleDB with no coins as no Module having reported (AceDB leaves out the empty default)", function()
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 0, no Module has reported Coins",
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
	describe("on an account after the M3 exit check's steps", function()
		local out, err, code = run(ACCOUNTS .. "M3#1", "--catalogue", CATALOGUE)

		it("exits 0 and writes nothing to stderr", function()
			assert.are.equal(0, code)
			assert.are.equal("", err)
		end)

		it("prints M3's state and celebrated set, with ranks and completion from the Ledger's logic", function()
			-- ledger.md › Data for the state and the celebrated set; LED-R4: M3's rules version, 200, isn't M4's 301. LED-R30: 4,560 XP
			-- = 1,080 + 1,160 + 1,240 to level 4, 1,080 into it, whose step costs 1,000 + 80 × 4 = 1,320. LED-R5: 6309
			-- is junk, a curio; 13901 a trophy; 999001 is in no catalogue. LED-R50, LED-R54: Duskwood (10) has no data,
			-- so it isn't charted and shows rank 0; Elwynn (12) is computed Local (3) but celebrated Expert (4), and the
			-- shown rank is the higher (LED-R52, LED-R92). LED-R70, LED-R71: Species 6291 and 6303 of 6291, 6299, 6303
			-- and 13759; junk 6309 of 6309; treasure none of 6351; trophy 13901 of 13901 and 13902; no zone at Master
			-- of 12 and 40; 4 of 10 is 40%; Legend 19803 beside it (LED-R63).
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 11, logId 3f9a2c1e7b0d4a65, fingerprint 0123456789abcdef, rulesVersion 200",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (11 entries)",
				"rulesVersion: 200 DIFFERS from the Ledger's 301, so Core rebuilds it at login (LED-R2, LOG-R72)",
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
				"completion: 40% (4 of 10): Species 2 of 4, junk 1 of 1, treasure 0 of 1, trophy 1 of 2, zones 0 of 2;"
					.. " Legends 0 of 1",
				"celebrated: highest level 4, 44 Coins",
				"celebrated Species: 2 (6291, 6303)",
				"celebrated Species × zone pairs: 3 (6291:12, 6303:12, 6303:40)",
				"celebrated zones: 3 (10 rank 0, 12 rank 4, 40 rank 1)",
				"celebrated Species stars: 3 on 2 Species (6291 ★1, 6303 ★1 ★2)",
				"celebrated family stars: 1 on 1 family (1 ★1)",
				"celebrated items: 2 (6309, 13901)",
				"celebrated Uncharted: 1 (999001)",
				"celebrated Skill Milestones: 1 (75)",
			}, section(out, "== Ledger"))
		end)

		it("reads the repo's catalogue by default, and flags one that isn't the projection's", function()
			-- DATA-R70: the generated file carries the content fingerprint the client's projections are built against.
			local file = assert(io.open("addons/Pagle/data/Catalogue.lua", "rb"))
			local fingerprint = file:read("*a"):match('fingerprint = "(%x+)"')
			file:close()
			local world = section(run(ACCOUNTS .. "M3#1"), "== Ledger")[6]
			local prefix = "world: the repo's addons/Pagle/data/Catalogue.lua, fingerprint "
				.. fingerprint
				.. " (NOT the projection's: the lines computed below use it), "
			assert.are.equal(prefix, world:sub(1, #prefix))
			assert.matches("^%d+ charted zones$", world:sub(#prefix + 1))
		end)

		it("says so and prints the stored lines alone when the catalogue can't be loaded", function()
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
		end)

		it("prints the Field report projection, its count and reporter key (REP-R25, REP-R26, REP-R36)", function()
			-- REP-R36's test vector: logId 3f9a2c1e7b0d4a65 gives f38e76b0.
			assert.are.same({
				"== Field report (PagleDB.global.projections.fieldReport): reporter key f38e76b0",
				"projection: lastSeq 11, logId 3f9a2c1e7b0d4a65, fingerprint 0123456789abcdef, rulesVersion 1",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (11 entries)",
				"count: 3 I and K rows stored",
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
			-- catch-log.md › Entry formats: P1 carries the new rank, U1 the good and the price paid. Two U1s, each listed.
			local log = section(out, "== Catch log")
			assert.are.same({
				"P1: 1 entry",
				"  rank 1, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-12 10:20:00 UTC",
				"U1: 2 entries",
				"  core.toaststyle.ripple for 150 Coins, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-12 10:21:40 UTC",
				"  core.soundset.gilded for 400 Coins, 1 Ada Brook (Player-4618-0A1B2C3D), 2026-10-12 10:23:20 UTC",
			}, { unpack(log, #log - 4) })
			assert.are.equal("entries by tag: B1 1, C1 4, P1 1, S1 1, U1 2", log[3])
			assert.are.equal("entries Core's codec can't decode: none", log[4])
		end)

		it("prints an M4 projection as current, and leaves its Legend out of the curio and trophy items", function()
			-- LED-R2: 301 = LEDGER_RULES_VERSION 3 × 100 + Core's SIZE_RULES_VERSION 1 (LOG-R68). LED-R30 at prestige
			-- rank 1, steps at half cost: 540 + 580 + 620 = 1,740 to level 4, 260 into it, whose step costs 660. LED-R5:
			-- 19803 is a Legend, neither curio nor trophy (LED-R63). LED-R70: Species 6291 and 6303 of 6291, 6299, 6303
			-- and 13759 (19803, a Legend, is outside it), junk 1 of 1, treasure 0 of 1, trophy 1 of 2, no zone at
			-- Master: 4 of 10 is 40%; Legends 1 of 1.
			local ledger = section(out, "== Ledger (PagleLedgerDB)")
			assert.are.same({
				"== Ledger (PagleLedgerDB)",
				"projection: lastSeq 9, logId 8e1d4b7a2c6f0935, fingerprint 0123456789abcdef, rulesVersion 301",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (9 entries)",
				"rulesVersion: the Ledger's, 301 (LED-R2)",
				"world: " .. CATALOGUE .. ", fingerprint 0123456789abcdef (the projection's), 2 charted zones",
				"state: 1004 Casts, 1003 Catches, 2000 XP (Angler Level 4, 260 into it, next step 660), 900 Coins,"
					.. " 2 Species",
				"state curio items: 1 (6309 ×3)",
				"state trophy items: 1 (13901 ×1)",
				"state Uncharted: none",
				"state zones: 2",
				"  12: rank 3, charted, shown 3",
				"  40: rank 1, charted, shown 1",
				"completion: 40% (4 of 10): Species 2 of 4, junk 1 of 1, treasure 0 of 1, trophy 1 of 2, zones 0 of 2;"
					.. " Legends 1 of 1",
			}, { unpack(ledger, 1, 14) })
		end)

		it("prints the climb, Catch Milestones, Legends, records and titles, and --item's records (LED-R30–R85)", function()
			-- LED-R30, LED-R35: level 4 at rank 1 (above), peak level 60 once ranked. LED-R42: the 1,000 milestone.
			-- LED-R63, LED-R80: the Legend's first Catch and its record on its items entry; 6303's record, and 6291 has
			-- none. LOG-R67: band 3 is Hefty, band 4 Whopper. LED-R75, LED-R76: computed (peak 60's seven level
			-- titles, prestige1, the Legend's, complete.junk with 6309 of 6309) plus the celebrated keys, in LED-R75's
			-- order. LED-R77: the stored key is earned, so it's the active title. LED-R90: the celebrated set's M4 keys.
			assert.are.same({
				"== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles",
				"climb: prestige rank 1, 2000 XP, computed level 4, peak level 60",
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
			}, section(out, "== Ledger M4"))
		end)

		it("prints the wallet projection, and a balance held at 0 while earned is below spent (SHOP-R11, SHOP-R12)", function()
			-- 500 earned − (150 + 400) spent is −50: the balance shows 0, held (SHOP-R12). Each good counted once, the
			-- wallet rules version 1 is Core's (wallet-and-shop.md › Data), and the projection is current (LOG-R72).
			assert.are.same({
				"== Wallet (PagleDB.global.coins.earned): balance 0, held (500 earned − 550 spent = -50, SHOP-R12)",
				"Ledger: 500",
				"projection: lastSeq 9, logId 8e1d4b7a2c6f0935, fingerprint 0123456789abcdef, rulesVersion 1",
				"logId: matches PagleLog's",
				"lastSeq: equals PagleLog's length (9 entries)",
				"rulesVersion: Core's wallet rules, 1",
				"spent: 550",
				"purchased: 2 (core.soundset.gilded, core.toaststyle.ripple)",
			}, section(out, "== Wallet"))
		end)

		it("prints each slot's equipped look, the goods cache and the length unit (SHOP-R26, SHOP-R32, LOG-R69)", function()
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
				"climb: prestige rank 1, 2000 XP, computed level 4, peak level 60",
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
			}, lines)
		end)
	end)

	it("prints an M3 Ledger's M4 lines as none yet, with the automatic title (LED-R35, LED-R77, LED-R80)", function()
		-- M3#1 has no prestige rank, milestones, Legends, records, titles or activeTitle. Level 4 (4,560 XP at rank
		-- 0) earns level1, the automatic title; 6309 of the fixture's one junk item earns complete.junk (LED-R75). 6291
		-- is a Species with no record; 6299 isn't in the state.
		local out = run(ACCOUNTS .. "M3#1", "--catalogue", CATALOGUE, "--item", "6291", "--item", "6299")
		assert.are.same({
			"== Ledger M4 (PagleLedgerDB): Prestige, Catch Milestones, Legends, records, titles",
			"climb: prestige rank 0, 4560 XP, computed level 4, peak level 4",
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
			["an --item that isn't an ID"] = { ACCOUNTS .. "M1#1", "--item", "6303a" },
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
