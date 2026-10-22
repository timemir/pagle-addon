-- scripts/rewrite-bindings.lua: the one-off rewrite of the dev's saved data when Journal bindings and Hunts' notebook
-- covers became one Core slot, `core.binding` (ADR 0015, #351, #353). It runs over a copy of four fixture accounts
-- in one WTF folder, written the way the client writes them (CRLF, no indent):
--   - M9-Bindings#1: a PagleLog with purchases of old IDs (the old free default cover at seq 4, a Journal binding,
--     Oilcloth, a cover no longer sold (#354), at seq 7, and a cover bought again under its new ID), a Module record
--     whose payload names an old ID, a PagleDB with four profiles' picks, the goods cache, the wallet projection,
--     catchCounts and Core's projections, and Module files whose projections stand before (Hunts), inside (Stats) and
--     at the end (Ledger) of the log;
--   - M4#1: an M4 account with a Journal binding picked and cached, and no binding purchase;
--   - M1#1: an account with no old ID; M0#1: one with no Pagle.lua.
-- What the rewrite leaves is read back with Core's own codec and wallet projection, the same oracle the game uses.

local ACCOUNTS = "spec/scripts/fixtures/WTF/Account/"
local NOW = 1792000000 -- 2026-10-14 17:46:40 UTC
local STAMP = "20261014T174640Z"

local core = loadAddon("Pagle", FOREVER_GLOBALS).ns

-- busted runs on stock Lua 5.1, which has the os the WoW client lacks.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no os
local os = os
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local script = dofile("spec/support/script.lua")
local wtf = script.wtf

-- A new WTF folder holding copies of the fixture accounts `names`, in a path with a space, as
-- World of Warcraft/_classic_beta_/WTF has. Returns the WTF folder.
local function newWtf(names)
	local base = os.tmpname()
	os.remove(base)
	local folder = base .. " WTF"
	assert(os.execute(("mkdir -p %s"):format(wtf.quote(folder .. "/Account"))) == 0)
	for _, name in ipairs(names) do
		local from, to = wtf.quote(ACCOUNTS .. name), wtf.quote(folder .. "/Account/" .. name)
		assert(os.execute(("cp -R %s %s"):format(from, to)) == 0)
	end
	return folder
end

local ALL = { "M9-Bindings#1", "M4#1", "M1#1", "M0#1" }

local function run(...)
	return script.run("scripts/rewrite-bindings.lua", { ... }, { now = NOW })
end

-- Every file under a folder, by path relative to it, with its bytes.
local function snapshot(folder)
	local files = {}
	local find = io.popen("cd " .. wtf.quote(folder) .. " && find . -type f | sort")
	for path in find:lines() do
		files[path] = wtf.readFile(folder .. "/" .. path)
	end
	find:close()
	return files
end

local function globalsOf(path)
	return assert(wtf.readSavedVariables(path))
end

local function saved(folder, account, file)
	return folder .. "/Account/" .. account .. "/SavedVariables/" .. file
end

-- The log's records, read with Core's codec, and how many entries it couldn't read (LOG-R16).
local function decoded(log)
	local global = { decodeErrors = 0 }
	local records = {}
	for record in core.OpenCatchLog(log, global, NOW):Iterate() do
		records[#records + 1] = record
	end
	return records, global.decodeErrors
end

-- The wallet projection's state folded from nothing over `log`, as Core rebuilds it (SHOP-R11, LOG-R72).
local function walletOver(log)
	local def = core.WalletProjectionDef({}, function() end)
	local state = def.reset()
	for _, record in ipairs((decoded(log))) do
		def.apply(state, record, "rebuild")
	end
	return state
end

-- The lines of a text, without their CRLF line ends.
local function linesOf(text)
	local lines = {}
	for line in text:gmatch("([^\n]*)\r\n") do
		lines[#lines + 1] = line
	end
	return lines
end

describe("scripts/rewrite-bindings.lua (ADR 0015, #353)", function()
	describe("with --dry-run", function()
		local folder = newWtf(ALL)
		local before = snapshot(folder .. "/Account")
		local out, err, code = run(folder, "--dry-run")

		it("prints the plan and exits 0", function()
			assert.are.equal("", err)
			assert.are.equal(0, code)
			assert.are.equal("== M0#1", out[1])
			assert.are.equal("  nothing to rewrite: no SavedVariables/Pagle.lua", out[2])
			assert.are.equal("  nothing to rewrite: no old binding or notebook cover IDs", out[4])
			assert.are.equal("Dry run: would rewrite 4 files, each after a .bak copy. Nothing written.", out[#out])
		end)

		it("writes nothing, not even a .bak", function()
			assert.are.same(before, snapshot(folder .. "/Account"))
		end)
	end)

	describe("on a WTF folder with old IDs", function()
		local folder = newWtf(ALL)
		local before = snapshot(folder .. "/Account")
		local out, err, code = run(folder)
		local after = snapshot(folder .. "/Account")
		local pagle = saved(folder, "M9-Bindings#1", "Pagle.lua")
		local globals = globalsOf(pagle)
		local log, db = globals.PagleLog, globals.PagleDB

		it("exits 0, after a reminder that the game must be closed", function()
			assert.are.equal("", err)
			assert.are.equal(0, code)
			local reminder
			for _, line in ipairs(out) do
				reminder = reminder or line:match("^The game must be fully closed") ~= nil
			end
			assert.is_true(reminder)
		end)

		it("prints what it renamed, per account", function()
			local text = table.concat(out, "\n")
			for _, line in ipairs({
				"  PagleLog seq 4: hunts.notebookcover.leather removed (price 0), the old default",
				"  PagleLog seq 5: ledger.binding.birch -> core.binding.birch (price 150)",
				"  PagleLog seq 7: hunts.notebookcover.oilcloth removed (price 150), no longer sold",
				"  PagleLog seq 9: hunts.notebookcover.tooled -> core.binding.tooled (price 400)",
				"  looks, profile Default: ledger.binding = ledger.binding.level10, hunts.notebookcover = "
					.. "hunts.notebookcover.oilcloth -> core.binding = ledger.binding.level10",
				"  looks, profile Default: ledger.binding = ledger.binding.level10 -> core.binding = ledger.binding.level10",
			}) do
				assert.is_truthy(text:find(line, 1, true), line)
			end
		end)

		it("renames the U1 entries in place and removes the dropped covers', every other line as it was", function()
			local old, new =
				linesOf(before["./M9-Bindings#1/SavedVariables/Pagle.lua"]),
				linesOf(after["./M9-Bindings#1/SavedVariables/Pagle.lua"])
			-- Up to the entries, line for line.
			for i = 1, 13 do
				assert.are.equal(old[i], new[i])
			end
			assert.are.same({
				'"B1|1|1791800000|0|70338|1.60.1", -- [1]',
				'"S1|1|1791800000|1|150|150|25", -- [2]',
				'"C1|1|1791800060|0|c|494|1439|1|12|0|150|25||||6303x1", -- [3]',
				'"U1|1|1791800200|0|core.binding.birch|150", -- [4]',
				'"C1|1|1791800260|0|c|495|1439|1|40|0|150|25||||19803x1", -- [5]',
				'"U1|1|1791800400|0|core.toaststyle.ripple|150", -- [6]',
				'"U1|1|1791800400|1|core.binding.tooled|400", -- [7]',
				'"U1|1|1791800500|0|core.binding.tooled|400", -- [8]',
				'"C1|1|1791800560|0|g|497|1439|1|12|0|150|25||||", -- [9]',
				'"A1|1|1791800600|0|Hunts|note|U1|1|2|0|ledger.binding.birch|150", -- [10]',
				"},",
				"}",
				"PagleDB = {",
			}, { unpack(new, 14, 26) })
		end)

		it("keeps the logId and characters, and Core's codec reads every entry (LOG-R16)", function()
			local records, undecodable = decoded(log)
			assert.are.equal(0, undecodable)
			assert.are.equal(9, #records) -- the A1 is Hunts' own, not yielded to Core (LOG-R41)
			assert.are.equal("9b3e5c7a1d2f4086", log.logId)
			assert.are.equal("Player-4618-0A1B2C3D", log.characters[1].guid)
		end)

		it("leaves a wallet that owns the new IDs, both tooled purchases kept and only the first counted", function()
			local state = walletOver(log)
			assert.are.same({
				["core.binding.birch"] = true,
				["core.binding.tooled"] = true,
				["core.toaststyle.ripple"] = true,
			}, state.purchased)
			assert.are.equal(150 + 150 + 400, state.spent) -- SHOP-R11
		end)

		it("renames the stored purchased set and drops its rulesVersion, so Core rebuilds it (LOG-R72)", function()
			local wallet = db.global.projections.wallet
			assert.is_nil(wallet.rulesVersion)
			assert.are.same({
				["core.binding.birch"] = true,
				["core.binding.tooled"] = true,
				["core.toaststyle.ripple"] = true,
			}, wallet.projection.purchased)
		end)

		it("folds each profile's picks into one core.binding pick, the Journal's winning (SHOP-R32)", function()
			local looks = {}
			for name, profile in pairs(db.profiles) do
				looks[name] = profile.appearance
			end
			assert.are.same({
				Default = {
					["core.toaststyle"] = "core.toaststyle.ripple",
					["core.binding"] = "ledger.binding.level10",
				},
				Alt = { ["core.binding"] = "core.binding.field" },
				Hunter = {
					["core.binding"] = "hunts.binding.pathfinder",
					["hunts.trackerframe"] = "hunts.trackerframe.inkwash",
				},
				Keeps = { ["core.binding"] = "core.binding.birch" },
			}, looks)
			assert.are.equal("in", db.profiles.Default.lengthUnit)
		end)

		it("clears the old IDs from the goods cache, and moves the binding whose ID stays (SHOP-R26)", function()
			local ids = {}
			for id in pairs(db.global.goods) do
				ids[#ids + 1] = id
			end
			table.sort(ids)
			assert.are.same({ "core.toaststyle.ripple", "hunts.trackerframe.inkwash", "ledger.binding.level10" }, ids)
			assert.are.equal("core.binding", db.global.goods["ledger.binding.level10"].slot)
			assert.is_true(db.global.goods["ledger.binding.level10"].earned)
		end)

		it("drops catchCounts, and rebuilds the projections that had read past a removed entry", function()
			assert.is_nil(db.global.catchCounts)
			assert.is_nil(db.global.projections.varieties.rulesVersion)
			assert.are.equal(1, db.global.projections.fieldReport.rulesVersion) -- lastSeq 3, before it
			local ledger = globalsOf(saved(folder, "M9-Bindings#1", "Pagle_Ledger.lua")).PagleLedgerDB
			assert.is_nil(ledger.global.projection.rulesVersion)
			assert.are.equal(12, ledger.global.projection.lastSeq)
			assert.are.same({ prestige = 0 }, ledger.global.celebrated)
			local stats = globalsOf(saved(folder, "M9-Bindings#1", "Pagle_Stats.lua"))
			assert.is_nil(stats.PagleStatsDB.global.projection.rulesVersion)
			assert.are.same({ watch = 6303 }, stats.PagleStatsCharDB)
			assert.are.equal(
				before["./M9-Bindings#1/SavedVariables/Pagle_Hunts.lua"],
				after["./M9-Bindings#1/SavedVariables/Pagle_Hunts.lua"]
			)
		end)

		it("rewrites M4#1's pick and cache too, and leaves M1#1 as it was", function()
			local m4 = globalsOf(saved(folder, "M4#1", "Pagle.lua")).PagleDB
			assert.are.same({
				["core.toaststyle"] = "core.toaststyle.ripple",
				["core.binding"] = "ledger.binding.level10",
			}, m4.profiles.Default.appearance)
			assert.is_nil(m4.global.goods["ledger.binding.field"])
			assert.are.equal(1, m4.global.projections.wallet.rulesVersion) -- its log has no old ID
			assert.are.equal(
				before["./M4#1/SavedVariables/Pagle.lua"]:match("^(.-)PagleDB = "),
				after["./M4#1/SavedVariables/Pagle.lua"]:match("^(.-)PagleDB = ")
			)
			for path, text in pairs(before) do
				if path:match("^%./M1#1/") then
					assert.are.equal(text, after[path], path)
				end
			end
		end)

		it("keeps CRLF line ends", function()
			assert.is_nil(after["./M9-Bindings#1/SavedVariables/Pagle.lua"]:find("[^\r]\n"))
		end)

		it("keeps each changed file's old bytes in a .bak beside it, and makes no other file", function()
			local changed = {
				"./M9-Bindings#1/SavedVariables/Pagle.lua",
				"./M9-Bindings#1/SavedVariables/Pagle_Ledger.lua",
				"./M9-Bindings#1/SavedVariables/Pagle_Stats.lua",
				"./M4#1/SavedVariables/Pagle.lua",
			}
			local expected = {}
			for path in pairs(before) do
				expected[path] = true
			end
			for _, path in ipairs(changed) do
				assert.are.equal(before[path], after[path .. ".bindings-" .. STAMP .. ".bak"], path)
				assert.are_not.equal(before[path], after[path], path)
				expected[path .. ".bindings-" .. STAMP .. ".bak"] = true
			end
			local paths = {}
			for path in pairs(after) do
				paths[path] = true
			end
			assert.are.same(expected, paths)
		end)

		it("finds nothing to do on a second run, and writes nothing", function()
			local again, againErr, againCode = run(folder)
			assert.are.equal("", againErr)
			assert.are.equal(0, againCode)
			assert.are.equal("Nothing to rewrite.", again[#again])
			assert.are.same(after, snapshot(folder .. "/Account"))
		end)
	end)

	describe("refuses, writing nothing in any account", function()
		it("for an ID under the old slots that the map doesn't name", function()
			local folder = newWtf(ALL)
			local path = saved(folder, "M9-Bindings#1", "Pagle.lua")
			local text = wtf.readFile(path)
			wtf.writeFile(
				path,
				(text:gsub('ledger%.binding%.birch|150", %-%- %[5%]', 'ledger.binding.mystery|150", -- [5]'))
			)
			local before = snapshot(folder .. "/Account")
			local out, err, code = run(folder)
			assert.are.equal("", err)
			assert.are.equal(1, code)
			assert.is_truthy(
				table
					.concat(out, "\n")
					:find(
						"  REFUSED: PagleLog seq 5 buys ledger.binding.mystery, which the ID map doesn't name",
						1,
						true
					)
			)
			assert.are.same(before, snapshot(folder .. "/Account"))
		end)

		it("when PagleLog's entries aren't one string a line, as the client writes them", function()
			local folder = newWtf(ALL)
			local path = saved(folder, "M9-Bindings#1", "Pagle.lua")
			local text = wtf.readFile(path)
			wtf.writeFile(path, (text:gsub('%-%- %[4%]\r\n"U1', '"U1')))
			local before = snapshot(folder .. "/Account")
			local out, _, code = run(folder)
			assert.are.equal(1, code)
			assert.is_truthy(table.concat(out, "\n"):find("  REFUSED: Pagle.lua: PagleLog's entry", 1, true))
			assert.are.same(before, snapshot(folder .. "/Account"))
		end)
	end)

	describe("usage", function()
		it("exits 2 without a WTF folder, with an unknown option, or with no accounts", function()
			local _, err, code = run()
			assert.are.equal(2, code)
			assert.matches("no WTF folder", err)
			_, err, code = run("x", "--force")
			assert.are.equal(2, code)
			assert.matches("unknown option %-%-force", err)
			_, err, code = run(newWtf({}) .. "/nowhere")
			assert.are.equal(2, code)
			assert.matches("no accounts in", err)
		end)
	end)
end)
