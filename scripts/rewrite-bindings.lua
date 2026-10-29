-- The one-off rewrite of the dev's saved data for ADR 0015 (#351, #353): Journal bindings and Hunts' notebook covers
-- become one Core slot, `core.binding`. 1.0 is unreleased and the addon aliases none of the old IDs, so this script
-- rewrites them in the dev's local WTF instead. It isn't shipped code.
--
-- For every account under a WTF folder (WTF/Account/<ACCT>/SavedVariables/Pagle.lua), it:
--   - renames the purchase entries (U1) in PagleLog by the ID map below, read with Core's own codec
--     (addons/Pagle/logic/CatchLog.lua) and each renamed entry read back with it. Only the good field changes: the
--     header and price stay byte for byte, and so does every other entry and line. A purchase of
--     `hunts.notebookcover.leather`, the old free default, or of `hunts.notebookcover.oilcloth`, a binding no longer
--     sold (#354), is removed. Two purchases renamed to the same good are both
--     kept: only the first counts (SHOP-R11);
--   - folds each profile's `ledger.binding` and `hunts.notebookcover` picks (PagleDB.profiles.*.appearance) into one
--     `core.binding` pick, the Journal's winning (a `core.binding` pick already there wins over both), and removes the
--     two old keys (SHOP-R32);
--   - removes the old IDs' entries from the goods cache (PagleDB.global.goods, SHOP-R26) and moves the binding goods
--     whose ID doesn't change (the earned `ledger.binding.level10` …) to the `core.binding` slot, so they stay owned
--     from the cache until the Ledger registers them again;
--   - renames the wallet projection's purchased set (PagleDB.global.projections.wallet) and drops its rulesVersion,
--     so Core rebuilds it from seq 0 over the rewritten log at the next login (LOG-R72, SHOP-R11), owning the right
--     goods meanwhile (SHOP-R34). Clearing `purchased` alone wouldn't rebuild it: Core rebuilds a projection only when
--     its stored projection, logId, lastSeq, fingerprint or rulesVersion says so, else it catches up from lastSeq;
--   - drops PagleDB.global.catchCounts when the log changed (a cache, LOG-R100);
--   - when it removed entries, every later seq moves down by one for each, so every projection that had read past
--     one (Core's in PagleDB, and each Module's in its Pagle_*.lua) loses its rulesVersion too and rebuilds from
--     seq 0.
--
-- It never changes a logId, so nothing counts as a first build and no Write-up comes of it.
--
--   lua scripts/rewrite-bindings.lua <WTF folder> [--dry-run]
--
-- Run it with the game fully closed: the client writes every SavedVariables file when it logs out, over whatever
-- this put there. scripts/rewrite-bindings.sh refuses while a WoW process runs. Before it writes a file, it copies
-- the file to `<file>.bindings-<UTC time>.bak` beside it: the client's own `<file>.bak` is its previous write, and
-- the next logout replaces it. With --dry-run it prints what it would do and writes nothing. An ID under the old
-- slots that the map doesn't name stops the run before anything is written. A second run finds nothing to do.
-- Exits 0 done (or nothing to do), 1 refused (nothing written), 2 a usage error.

local USAGE = "usage: lua scripts/rewrite-bindings.lua <WTF folder> [--dry-run]\n"

-- The repo root, from this script's path: Core's codec is read from addons/.
local ROOT = ((arg and arg[0] or ""):match("^(.*)[/\\]") or ".") .. "/.."

-- The helpers this script shares with scripts/read-wtf.lua and scripts/make-test-log.lua.
local wtf = setfenv(assert(loadfile(ROOT .. "/scripts/lib/wtf.lua")), getfenv(1))(ROOT)

-- The ID map (ADR 0015) --------------------------------------------------------------------------------------------

--- The one slot both old slots become.
local BINDING_SLOT = "core.binding"
--- The old slots, the Journal's first: its pick wins the fold.
local OLD_SLOTS = { "ledger.binding", "hunts.notebookcover" }
--- The old free default cover: its purchases are removed, and a pick of it becomes the new default.
local DEFAULT_COVER = "hunts.notebookcover.leather"
--- A cover whose binding is no longer sold (#354): dropped as the old default is.
local OILCLOTH = "hunts.notebookcover.oilcloth"

--- DROPPED[old good ID] = why: the goods whose purchases are removed and whose picks become the new default.
local DROPPED = {
	[DEFAULT_COVER] = "the old default",
	[OILCLOTH] = "no longer sold",
}

--- RENAMED[old good ID] = its new ID, for every good of the old slots; a good whose ID stays maps to itself.
local RENAMED = {
	["ledger.binding.field"] = BINDING_SLOT .. ".field",
	[DEFAULT_COVER] = BINDING_SLOT .. ".field",
	[OILCLOTH] = BINDING_SLOT .. ".field",
}
for _, key in ipairs({
	"birch",
	"buckram",
	"sharkskin",
	"chartlinen",
	"sailcloth",
	"oilskin",
	"moss",
	"driftwood",
	"eelskin",
	"kodo",
	"frosthide",
	"netcork",
	"copper",
	"velvet",
	"turtle",
	"morocco",
	"coral",
	"pearl",
}) do
	RENAMED["ledger.binding." .. key] = BINDING_SLOT .. "." .. key
end
for _, key in ipairs({
	"level10",
	"level20",
	"level30",
	"level40",
	"level50",
	"level60",
	"legend",
	"monster",
	"abyssal",
	"keeper",
	"iridescent",
}) do
	RENAMED["ledger.binding." .. key] = "ledger.binding." .. key
end
for _, key in ipairs({
	"tooled",
	"verdigris",
	"canvas",
	"kraft",
	"tartan",
	"maplinen",
	"planks",
	"snakeskin",
	"shagreen",
	"lacquer",
	"bone",
	"brasscase",
	"scrimshaw",
	"trophycase",
}) do
	RENAMED["hunts.notebookcover." .. key] = BINDING_SLOT .. "." .. key
end
for _, key in ipairs({ "pathfinder", "fiveseal", "wagersilk" }) do
	RENAMED["hunts.notebookcover." .. key] = "hunts.binding." .. key
end

-- The old slot `id` is in ("ledger.binding.birch" is in "ledger.binding"), or nil for any other.
local function oldSlotOf(id)
	if type(id) ~= "string" then
		return nil
	end
	for _, slot in ipairs(OLD_SLOTS) do
		if id:sub(1, #slot + 1) == slot .. "." then
			return slot
		end
	end
	return nil
end

local function isOldSlot(slot)
	return slot == OLD_SLOTS[1] or slot == OLD_SLOTS[2]
end

-- Helpers ------------------------------------------------------------------------------------------------------------

local function sortedKeys(t)
	local keys = {}
	for key in pairs(t) do
		keys[#keys + 1] = key
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

-- The arguments as options, or nil and what's wrong with them.
local function parseArgs(args)
	local options = {}
	for _, word in ipairs(args) do
		if word == "--dry-run" then
			options.dryRun = true
		elseif word:sub(1, 1) == "-" then
			return nil, "unknown option " .. word
		elseif options.wtf then
			return nil, "one WTF folder only"
		else
			options.wtf = word:gsub("[/\\]+$", "")
		end
	end
	if not options.wtf then
		return nil, "no WTF folder"
	end
	return options
end

-- A file's text as lines without their line ends, the line end it uses, and whether it ends with one.
local function splitLines(text)
	local eol = text:find("\r\n", 1, true) and "\r\n" or "\n"
	local trailing = text:sub(-#eol) == eol
	local lines = {}
	for line in (trailing and text or text .. eol):gmatch("(.-)" .. eol) do
		lines[#lines + 1] = line
	end
	return lines, eol, trailing
end

-- One string item of an array as the client writes it, `"…", -- [n]` or `"…",`: its literal and the rest of the
-- line; nil for any other line.
local function stringItem(line)
	if type(line) ~= "string" or line:sub(1, 1) ~= '"' then
		return nil
	end
	local literal, rest = line:match('^(".*")(,%s*%-%-%s*%[%d+%])$')
	if not literal then
		literal, rest = line:match('^(".*")(,)$')
	end
	return literal, rest
end

-- The string a literal stands for, read as data, or nil when it isn't one.
local function literalValue(literal)
	local chunk = loadstring("return " .. literal)
	if not chunk then
		return nil
	end
	local ok, value = pcall(setfenv(chunk, {}))
	return ok and type(value) == "string" and value or nil
end

-- The format of the PagleLog this one-off rewrites: 3, one string per entry on its own line, which the client wrote
-- before Core's format 4 (blocks, LOG-R103). Core starts a new log at the first login on any other format (LOG-R18),
-- so there is nothing left to rewrite in a format-4 log.
local REWRITTEN_FORMAT = 3

-- The Catch log --------------------------------------------------------------------------------------------------------

-- Core's namespace with its Catch log codec, as scripts/read-wtf.lua loads it.
local function loadCodec()
	return wtf.loadCore({ "logic/Conditions.lua", "logic/Sessions.lua", "logic/Integrity.lua", "logic/CatchLog.lua" })
end

-- The records Core's codec reads from `entries`, over the log's own characters and logId. It reads a copy, so the
-- codec's own bookkeeping (a logId it would create, the decode errors it counts) never reaches the file.
local function decodeAll(core, log, entries)
	-- Packed into the codec's blocks (LOG-R103) just to read them: the log being rewritten is a format-3 one.
	local blocks, count = core.LogBlocks.Pack(entries)
	local copy = {
		format = core.LOG_FORMAT,
		logId = log.logId,
		characters = log.characters,
		blockSize = core.LOG_BLOCK_SIZE,
		count = count,
		blocks = blocks,
	}
	local records = {}
	for record in core.OpenCatchLog(copy, { decodeErrors = 0 }, 0):Iterate(0) do
		records[#records + 1] = record
	end
	return records
end

-- `entry`, a purchase of `old`, as a purchase of `new`: only its good field changes, the header and the price stay
-- as they are. Nil unless Core's codec reads the new entry back as the same purchase of `new`.
local function renamedEntry(core, log, record, entry, new)
	local header, good, price = entry:match("^(U1|[^|]*|[^|]*|[^|]*)|([^|]*)|([^|]*)$")
	if good ~= record.good then
		return nil
	end
	local renamed = header .. "|" .. new .. "|" .. price
	local back = decodeAll(core, log, { renamed })[1]
	if
		not back
		or back.kind ~= "purchase"
		or back.good ~= new
		or back.price ~= record.price
		or back.id ~= record.id
	then
		return nil
	end
	return renamed
end

-- The changes to PagleLog's purchase entries: { seq, id, old, new (nil when removed), price, entry, renamed }, in seq
-- order. Problems go to `problems`, notes to `notes`.
local function planLog(core, log, problems, notes)
	if type(log) ~= "table" or type(log.entries) ~= "table" then
		return {}
	end
	if log.format ~= REWRITTEN_FORMAT then
		notes[#notes + 1] = ("PagleLog is in format %s, not the %s this rewrites: Core starts a new log at login, so its"):format(
			tostring(log.format),
			tostring(REWRITTEN_FORMAT)
		) .. " purchases are left as they are"
		return {}
	end
	local changes = {}
	for _, record in ipairs(decodeAll(core, log, log.entries)) do
		if record.kind == "purchase" and oldSlotOf(record.good) then
			local new = RENAMED[record.good]
			local entry = log.entries[record.seq]
			if new == nil then
				problems[#problems + 1] = ("PagleLog seq %d buys %s, which the ID map doesn't name"):format(
					record.seq,
					record.good
				)
			elseif DROPPED[record.good] then
				changes[#changes + 1] =
					{ seq = record.seq, id = record.id, old = record.good, price = record.price, entry = entry }
			elseif new ~= record.good then
				local renamed = renamedEntry(core, log, record, entry, new)
				if renamed then
					changes[#changes + 1] = {
						seq = record.seq,
						id = record.id,
						old = record.good,
						new = new,
						price = record.price,
						entry = entry,
						renamed = renamed,
					}
				else
					problems[#problems + 1] = ("PagleLog seq %d (%s) doesn't read back as a purchase of %s"):format(
						record.seq,
						entry,
						new
					)
				end
			end
		end
	end
	return changes
end

-- PagleLog's entries after `changes`.
local function changedEntries(entries, changes)
	local bySeq = {}
	for _, change in ipairs(changes) do
		bySeq[change.seq] = change
	end
	local result = {}
	for seq, entry in ipairs(entries) do
		local change = bySeq[seq]
		if not change then
			result[#result + 1] = entry
		elseif change.renamed then
			result[#result + 1] = change.renamed
		end
	end
	return result
end

-- `lines`, Pagle.lua's, with `changes` made to PagleLog's entries in place: each renamed entry's line holds the new
-- entry, a removed one's line goes, and the `-- [n]` after each later entry counts on without it. Every other line
-- stays as it was. Nil and why when the entries aren't laid out as the client writes them, one line each, matching
-- what loaded.
local function editLogLines(lines, log, changes)
	local first
	for i, line in ipairs(lines) do
		if line:match("^PagleLog = ") then
			first = i
			break
		end
	end
	if not first then
		return nil, "it has no PagleLog = line"
	end
	local open
	for i = first + 1, #lines do
		if lines[i]:match("^[%a_][%w_]* = ") then
			break
		end
		if lines[i] == '["entries"] = {' then
			open = i
			break
		end
	end
	if not open then
		return nil, 'its PagleLog has no ["entries"] = { line'
	end
	local n = #log.entries
	if stringItem(lines[open + n + 1]) then
		return nil, "PagleLog's entries run past the " .. n .. " that loaded"
	end
	local bySeq = {}
	for _, change in ipairs(changes) do
		bySeq[change.seq] = change
	end
	local edited, removed = {}, 0
	for i = 1, open do
		edited[#edited + 1] = lines[i]
	end
	for seq = 1, n do
		local line = lines[open + seq]
		local literal, rest = stringItem(line)
		if not literal then
			return nil, ("PagleLog's entry %d isn't one string on its own line"):format(seq)
		end
		local change = bySeq[seq]
		if literalValue(literal) ~= log.entries[seq] then
			return nil, ("PagleLog's entry %d on its line isn't the one that loaded"):format(seq)
		end
		if change and not change.renamed then
			removed = removed + 1
		else
			if change then
				literal = ("%q"):format(change.renamed)
			end
			if removed > 0 then
				rest = rest:gsub("%[%d+%]$", "[" .. (seq - removed) .. "]")
			end
			edited[#edited + 1] = (change or removed > 0) and literal .. rest or line
		end
	end
	for i = open + n + 1, #lines do
		edited[#edited + 1] = lines[i]
	end
	return edited
end

-- PagleDB -------------------------------------------------------------------------------------------------------------

-- Folds each profile's old picks into one `core.binding` pick (SHOP-R32). Returns whether anything changed.
local function foldLooks(db, problems, notes)
	local changed = false
	local profiles = type(db.profiles) == "table" and db.profiles or {}
	for _, name in ipairs(sortedKeys(profiles)) do
		local looks = type(profiles[name]) == "table" and profiles[name].appearance
		if type(looks) == "table" then
			local picks, mapped = {}, nil
			for _, slot in ipairs(OLD_SLOTS) do
				local pick = looks[slot]
				if pick ~= nil then
					local new = RENAMED[pick]
					if oldSlotOf(pick) ~= slot or new == nil then
						problems[#problems + 1] = ("profile %s picks %s for %s, which the ID map doesn't name"):format(
							name,
							tostring(pick),
							slot
						)
					else
						picks[#picks + 1] = slot .. " = " .. pick
						mapped = mapped or new
					end
				end
			end
			if #picks > 0 then
				local kept = looks[BINDING_SLOT]
				looks[BINDING_SLOT] = kept or mapped
				for _, slot in ipairs(OLD_SLOTS) do
					looks[slot] = nil
				end
				changed = true
				notes[#notes + 1] = ("looks, profile %s: %s -> %s = %s%s"):format(
					name,
					table.concat(picks, ", "),
					BINDING_SLOT,
					looks[BINDING_SLOT],
					kept and " (the core.binding pick already there)" or ""
				)
			end
		end
	end
	return changed
end

-- Removes the old IDs from the goods cache (SHOP-R26) and moves the binding goods whose ID stays to the new slot.
-- Returns whether anything changed.
local function clearGoods(global, problems, notes)
	local goods = type(global.goods) == "table" and global.goods or {}
	local removed, moved = {}, {}
	for _, id in ipairs(sortedKeys(goods)) do
		local good = goods[id]
		local slot = oldSlotOf(id)
		if slot then
			local new = RENAMED[id]
			if new == nil then
				problems[#problems + 1] = ("the goods cache holds %s, which the ID map doesn't name"):format(id)
			elseif new ~= id then
				goods[id] = nil
				removed[#removed + 1] = id
			elseif type(good) == "table" and isOldSlot(good.slot) then
				good.slot = BINDING_SLOT
				moved[#moved + 1] = id
			end
		elseif type(good) == "table" and isOldSlot(good.slot) then
			problems[#problems + 1] = ("the goods cache puts %s in %s, which the ID map doesn't name"):format(
				tostring(id),
				good.slot
			)
		end
	end
	if #removed > 0 then
		notes[#notes + 1] = "goods cache: removed " .. table.concat(removed, ", ")
	end
	if #moved > 0 then
		notes[#notes + 1] = "goods cache: moved to " .. BINDING_SLOT .. ": " .. table.concat(moved, ", ")
	end
	return #removed + #moved > 0
end

-- Renames the wallet projection's purchased set. Returns whether anything changed.
local function renamePurchased(wallet, problems, notes)
	local state = type(wallet) == "table" and wallet.projection
	local purchased = type(state) == "table" and state.purchased
	if type(purchased) ~= "table" then
		return false
	end
	local renamed = {}
	for _, id in ipairs(sortedKeys(purchased)) do
		if oldSlotOf(id) then
			local new = RENAMED[id]
			if new == nil then
				problems[#problems + 1] = ("the wallet projection owns %s, which the ID map doesn't name"):format(id)
			elseif DROPPED[id] then
				purchased[id] = nil
				renamed[#renamed + 1] = id .. " removed"
			elseif new ~= id then
				purchased[id] = nil
				purchased[new] = true
				renamed[#renamed + 1] = id .. " -> " .. new
			end
		end
	end
	if #renamed > 0 then
		notes[#notes + 1] = "wallet projection's purchased set: " .. table.concat(renamed, ", ")
	end
	return #renamed > 0
end

-- The projection tables (LOG-R70) under `t` that read this log past `fromSeq` and would catch up from there rather
-- than rebuild: a `projection` table, `lastSeq` at `fromSeq` or later, the log's logId and a rulesVersion. Each is
-- added to `found` with its path.
local function staleProjections(t, path, logId, fromSeq, found, seen)
	if seen[t] then
		return
	end
	seen[t] = true
	if
		type(t.projection) == "table"
		and type(t.lastSeq) == "number"
		and t.lastSeq >= fromSeq
		and t.logId == logId
		and t.rulesVersion ~= nil
	then
		found[#found + 1] = { table = t, path = path }
		return
	end
	for _, key in ipairs(sortedKeys(t)) do
		if type(t[key]) == "table" then
			staleProjections(t[key], path .. "." .. tostring(key), logId, fromSeq, found, seen)
		end
	end
end

-- Drops the rulesVersion of each projection in `t` that read past `fromSeq`, so it rebuilds from seq 0 (LOG-R72).
-- Returns how many.
local function rebuildStale(t, name, logId, fromSeq, notes)
	local found = {}
	staleProjections(t, name, logId, fromSeq, found, {})
	for _, projection in ipairs(found) do
		projection.table.rulesVersion = nil
		notes[#notes + 1] = ("%s (lastSeq %d) rebuilds from seq 0: an entry at or before it was removed"):format(
			projection.path,
			projection.table.lastSeq
		)
	end
	return #found
end

-- One account ------------------------------------------------------------------------------------------------------

-- What the rewrite does to one account: { notes, problems, files = { { path, text, rewritten } } }, the files those
-- it changes. Nil and why when there's nothing of Pagle's to rewrite.
local function planAccount(core, account)
	local saved = account .. "/SavedVariables/"
	local path = saved .. "Pagle.lua"
	local text = wtf.readFile(path)
	if not text then
		return nil, "no SavedVariables/Pagle.lua"
	end
	local plan = { notes = {}, problems = {}, files = {} }
	local globals, err = wtf.loadSavedVariables(text, "Pagle.lua")
	if not globals then
		plan.problems[1] = "Pagle.lua doesn't load: " .. tostring(err)
		return plan
	end
	local log, db = globals.PagleLog, globals.PagleDB
	local notes, problems = plan.notes, plan.problems

	local changes = planLog(core, log, problems, notes)
	local firstRemoved
	for _, change in ipairs(changes) do
		if change.renamed then
			notes[#notes + 1] = ("PagleLog seq %d: %s -> %s (price %d)"):format(
				change.seq,
				change.old,
				change.new,
				change.price
			)
		else
			firstRemoved = firstRemoved or change.seq
			notes[#notes + 1] = ("PagleLog seq %d: %s removed (price %d), %s"):format(
				change.seq,
				change.old,
				change.price,
				DROPPED[change.old]
			)
		end
	end
	if firstRemoved then
		notes[#notes + 1] = ("PagleLog: every entry after seq %d moves down by one per entry removed before it"):format(
			firstRemoved
		)
	end

	local dbChanged = false
	if type(db) == "table" then
		dbChanged = foldLooks(db, problems, notes) or dbChanged
		local global = type(db.global) == "table" and db.global or {}
		dbChanged = clearGoods(global, problems, notes) or dbChanged
		local wallet = type(global.projections) == "table" and global.projections.wallet or nil
		local purchasedChanged = renamePurchased(wallet, problems, notes)
		if (#changes > 0 or purchasedChanged) and type(wallet) == "table" then
			dbChanged = true
			if wallet.rulesVersion ~= nil then
				wallet.rulesVersion = nil
				notes[#notes + 1] = "wallet projection rebuilds from seq 0 over the rewritten log"
			end
		end
		if #changes > 0 and global.catchCounts ~= nil then
			global.catchCounts = nil
			dbChanged = true
			notes[#notes + 1] = "PagleDB.global.catchCounts dropped (a cache, LOG-R100)"
		end
		if firstRemoved and rebuildStale(db, "PagleDB", log.logId, firstRemoved, notes) > 0 then
			dbChanged = true
		end
	end
	if #problems > 0 then
		return plan
	end

	if #changes > 0 or dbChanged then
		local rewritten = text
		if #changes > 0 then
			local lines, eol, trailing = splitLines(text)
			local edited, why = editLogLines(lines, log, changes)
			if not edited then
				problems[#problems + 1] = "Pagle.lua: " .. why
				return plan
			end
			rewritten = table.concat(edited, eol) .. (trailing and eol or "")
		end
		if dbChanged then
			local replaced, why = wtf.replaceGlobal(rewritten, "PagleDB", db)
			if not replaced then
				problems[#problems + 1] = "Pagle.lua: " .. why
				return plan
			end
			rewritten = replaced
		end
		-- Read back: the entries are the ones planned, and PagleDB is the one rewritten.
		local back = wtf.loadSavedVariables(rewritten, "Pagle.lua")
		-- A log with no changes (a format-4 one, in blocks) is checked for PagleDB alone.
		local same = true
		if #changes > 0 then
			local expected = changedEntries(log.entries, changes)
			local entries = back and back.PagleLog and back.PagleLog.entries
			same = type(entries) == "table" and #entries == #expected
			for seq = 1, same and #expected or 0 do
				same = same and entries[seq] == expected[seq]
			end
		end
		if not same or (db and type(back.PagleDB) ~= "table") then
			problems[#problems + 1] = "Pagle.lua: the rewritten file doesn't read back as planned"
			return plan
		end
		plan.files[#plan.files + 1] = { path = path, text = text, rewritten = rewritten }
	end

	-- The Modules' projections, when every seq after a removed entry moved down.
	if firstRemoved then
		for _, name in ipairs(wtf.listFolder(saved)) do
			if name:match("^Pagle_[%w_]+%.lua$") then
				local moduleText = assert(wtf.readFile(saved .. name))
				local moduleGlobals, moduleErr = wtf.loadSavedVariables(moduleText, name)
				if not moduleGlobals then
					problems[#problems + 1] = name .. " doesn't load: " .. tostring(moduleErr)
					return plan
				end
				local rewritten = moduleText
				for _, global in ipairs(sortedKeys(moduleGlobals)) do
					local value = moduleGlobals[global]
					if type(value) == "table" and rebuildStale(value, global, log.logId, firstRemoved, notes) > 0 then
						local replaced, why = wtf.replaceGlobal(rewritten, global, value)
						if not replaced then
							problems[#problems + 1] = name .. ": " .. why
							return plan
						end
						rewritten = replaced
					end
				end
				if rewritten ~= moduleText then
					plan.files[#plan.files + 1] = { path = saved .. name, text = moduleText, rewritten = rewritten }
				end
			end
		end
	end
	return plan
end

-- Main ---------------------------------------------------------------------------------------------------------------

local options, usageErr = parseArgs(arg or {})
if not options then
	io.stderr:write("rewrite-bindings: " .. usageErr .. "\n" .. USAGE)
	os.exit(2)
	return
end
local accountsFolder = options.wtf .. "/Account"
local accounts = {}
for _, name in ipairs(wtf.listFolder(accountsFolder)) do
	if name ~= "SavedVariables" then
		accounts[#accounts + 1] = name
	end
end
if #accounts == 0 then
	io.stderr:write("rewrite-bindings: no accounts in " .. accountsFolder .. "\n" .. USAGE)
	os.exit(2)
	return
end

local core = loadCodec()
local plans, refused = {}, false
for _, name in ipairs(accounts) do
	local plan, skipped = planAccount(core, accountsFolder .. "/" .. name)
	print("== " .. name)
	if not plan then
		print("  nothing to rewrite: " .. skipped)
	else
		for _, note in ipairs(plan.notes) do
			print("  " .. note)
		end
		for _, problem in ipairs(plan.problems) do
			print("  REFUSED: " .. problem)
			refused = true
		end
		if #plan.problems == 0 and #plan.files == 0 then
			print("  nothing to rewrite: no old binding or notebook cover IDs")
		end
		plans[#plans + 1] = plan
	end
end

if refused then
	print("Refused: nothing written. Fix the lines marked REFUSED, or extend the ID map, then run this again.")
	os.exit(1)
	return
end
local files = {}
for _, plan in ipairs(plans) do
	for _, file in ipairs(plan.files) do
		files[#files + 1] = file
	end
end
if #files == 0 then
	print("Nothing to rewrite.")
	os.exit(0)
	return
end
if options.dryRun then
	print(("Dry run: would rewrite %s, each after a .bak copy. Nothing written."):format(wtf.count(#files, "file")))
	os.exit(0)
	return
end
print("The game must be fully closed: the client writes every SavedVariables file at logout, over this rewrite.")
local stamp = os.date("!%Y%m%dT%H%M%SZ", os.time())
for _, file in ipairs(files) do
	local backup = file.path .. ".bindings-" .. stamp .. ".bak"
	wtf.writeFile(backup, file.text)
	wtf.writeFile(file.path, file.rewritten)
	print("Wrote " .. file.path .. " (its old copy is " .. backup:match("[^/\\]*$") .. ")")
end
os.exit(0)
