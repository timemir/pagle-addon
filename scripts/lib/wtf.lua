-- What scripts/read-wtf.lua, scripts/make-test-log.lua and scripts/rewrite-bindings.lua share, written once:
-- reading files, loading a SavedVariables file as data, rewriting one global in it, and loading Core's and the
-- Ledger's own files (CORE-R7's plain-Lua logic/, the catalogue) the way the client calls an addon's files. A script
-- loads it in its own environment and calls it with the repo root:
--
--   local wtf = setfenv(assert(loadfile(ROOT .. "/scripts/lib/wtf.lua")), getfenv(1))(ROOT)
--
-- so whatever the script runs in (its specs swap in their own io, os and loadfile) is what these helpers use.
-- Runs on stock Lua 5.1, as the scripts do.

local ROOT = ...

local wtf = {}

-- A file's bytes, exactly (binary mode), or nil when it can't be opened.
function wtf.readFile(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local text = file:read("*a")
	file:close()
	return text
end

-- A file's size in bytes, or nil when it can't be opened.
function wtf.fileSize(path)
	local file = io.open(path, "rb")
	if not file then
		return nil
	end
	local size = file:seek("end")
	file:close()
	return size
end

-- Writes `text` to `path` and reads it back: raises if the file doesn't hold exactly `text`.
function wtf.writeFile(path, text)
	local file = assert(io.open(path, "wb"))
	file:write(text)
	file:close()
	if wtf.readFile(path) ~= text then
		error("wrote " .. path .. " but it doesn't read back the same")
	end
end

-- A file's lines without their line ends (the client writes CRLF), or nil when it can't be opened.
function wtf.readLines(path)
	local text = wtf.readFile(path)
	if not text then
		return nil
	end
	local lines = {}
	for line in text:gmatch("([^\n]*)\n") do
		lines[#lines + 1] = (line:gsub("\r$", ""))
	end
	local last = text:match("[^\n]+$")
	if last then
		lines[#lines + 1] = (last:gsub("\r$", ""))
	end
	return lines
end

-- A path quoted for the shell.
function wtf.quote(path)
	return "'" .. path:gsub("'", "'\\''") .. "'"
end

-- The names in a folder, sorted; none when it doesn't exist.
function wtf.listFolder(path)
	local names = {}
	local ls = io.popen("ls -1 " .. wtf.quote(path) .. " 2>/dev/null")
	for name in ls:lines() do
		names[#names + 1] = name
	end
	ls:close()
	table.sort(names)
	return names
end

-- Runs a data chunk's text in the environment `env` and returns `env`, or nil, why not and whether it compiled.
local function runData(text, name, env)
	local chunk, loadErr = loadstring(text, "=" .. name)
	if not chunk then
		return nil, loadErr, false
	end
	setfenv(chunk, env)
	local ok, runErr = pcall(chunk)
	if not ok then
		return nil, runErr, true
	end
	return env
end

-- Lua 5.1 keeps at most 262,143 distinct constants in one function ("constant table overflow"), so a file whose one
-- table holds more strings, such as a PagleLog of 300,000 entries, can't load in one piece. A run of more than
-- SPLIT_RUN string items, one per line as the client writes an array of strings, is loaded apart, SPLIT_PART lines
-- a chunk. A text of more than SPLIT_LINES string items is loaded that way from the start.
local SPLIT_RUN, SPLIT_PART, SPLIT_LINES = 1000, 100000, 200000

-- Whether a line is one string item of an array as the client writes it: `"…", -- [n]` (or without the comment).
local function stringItem(line)
	return line:sub(1, 1) == '"' and (line:match('",%s*%-%-%s*%[%d+%]\r?$') or line:match('",\r?$')) ~= nil
end

-- loadSavedVariables for a text too large to load in one piece: each run of more than SPLIT_RUN string items is cut
-- out and loaded apart (each line still a data item in an empty environment), and a placeholder in its place is
-- replaced by its items once the rest has loaded. Returns the globals and how many runs were split, or nil and why.
local function loadSplit(text, name)
	local lines = {}
	for line in (text:sub(-1) == "\n" and text or text .. "\n"):gmatch("([^\n]*)\n") do
		lines[#lines + 1] = line
	end
	local kept, runs = {}, {}
	local i = 1
	while i <= #lines do
		local j = i
		while j <= #lines and stringItem(lines[j]) do
			j = j + 1
		end
		if j - i > SPLIT_RUN then
			runs[#runs + 1] = { from = i, to = j - 1 }
			kept[#kept + 1] = ("__split(%d),"):format(#runs)
			i = j
		else
			kept[#kept + 1] = lines[i]
			i = i + 1
		end
	end
	if #runs == 0 then
		return nil, "constant table overflow, with no long run of strings to load apart"
	end
	-- The placeholders: a table each, found again by identity once the rest has loaded.
	local placeholders = {}
	local env = {
		__split = function(n)
			local placeholder = {}
			placeholders[placeholder] = n
			return placeholder
		end,
	}
	local globals, err = runData(table.concat(kept, "\n"), name, env)
	if not globals then
		return nil, err
	end
	env.__split = nil
	local items = {}
	for n, run in ipairs(runs) do
		local list = {}
		for from = run.from, run.to, SPLIT_PART do
			local part = { "__part = {" }
			for line = from, math.min(from + SPLIT_PART - 1, run.to) do
				part[#part + 1] = lines[line]
			end
			part[#part + 1] = "}"
			local values, partErr = runData(table.concat(part, "\n"), name, {})
			if not values then
				return nil, partErr
			end
			for _, value in ipairs(values.__part) do
				list[#list + 1] = value
			end
		end
		items[n] = list
	end
	-- Puts each run's items where its placeholder is, in every table reachable from the globals.
	local seen = {}
	local function splice(t)
		if seen[t] then
			return
		end
		seen[t] = true
		local array, changed = {}, false
		for k = 1, #t do
			local n = placeholders[t[k]]
			if n then
				changed = true
				for _, value in ipairs(items[n]) do
					array[#array + 1] = value
				end
			else
				array[#array + 1] = t[k]
			end
		end
		if changed then
			for k = 1, math.max(#t, #array) do
				t[k] = array[k]
			end
		end
		for _, value in pairs(t) do
			if type(value) == "table" then
				splice(value)
			end
		end
	end
	splice(globals)
	return globals, #runs
end

-- Loads a SavedVariables text as data and returns the globals it assigned, or nil and why not: it runs in an empty
-- environment, so it can only assign values, and a precompiled chunk is refused. `name` names it in errors. A text
-- too large for Lua 5.1 to load in one piece ("constant table overflow") is loaded in parts (loadSplit); then the
-- third value is how many runs of strings were loaded apart.
function wtf.loadSavedVariables(text, name)
	if text:sub(1, 1) == "\27" then
		return nil, "a precompiled chunk, not data"
	end
	-- A text with more string items than SPLIT_LINES goes to loadSplit at once: Lua 5.1 raises the overflow through
	-- the enclosing xpcall's handler (busted's, which loses the message), so it's better not to raise it at all.
	local _, items = text:gsub('\n"', "")
	if items > SPLIT_LINES then
		local split, runs = loadSplit(text, name)
		if split then
			return split, nil, runs
		end
		return nil, runs
	end
	local globals, err, loaded = runData(text, name, {})
	-- Any other text too large to compile is tried in parts too; one that still fails keeps its own error.
	if not globals and not loaded and (err == nil or tostring(err):find("constant table overflow", 1, true)) then
		local split, runs = loadSplit(text, name)
		if split then
			return split, nil, runs
		end
		return nil, err or runs
	end
	return globals, err
end

-- loadSplit, for its spec: loads `text` in parts whatever its size.
wtf.loadSplit = loadSplit

-- Loads the SavedVariables file at `path` as data (loadSavedVariables): its globals, or nil and why not, "missing"
-- when there's no file.
function wtf.readSavedVariables(path)
	local text = wtf.readFile(path)
	if not text then
		return nil, "missing"
	end
	return wtf.loadSavedVariables(text, path:match("[^/\\]*$"))
end

-- The client's SavedVariables layout for one value, as lines added to `lines`: no indent, `["key"] = value,` per
-- field (numbers first, then strings, each in order), array items followed by `-- [n]`. `prefix` starts the first
-- line ("PagleLog = "), `suffix` ends the last.
function wtf.serialize(value, lines, prefix, suffix)
	local kind = type(value)
	if kind == "table" then
		lines[#lines + 1] = prefix .. "{"
		for i, item in ipairs(value) do
			wtf.serialize(item, lines, "", ", -- [" .. i .. "]")
		end
		local keys = {}
		for key in pairs(value) do
			if type(key) ~= "number" or key < 1 or key > #value or key % 1 ~= 0 then
				keys[#keys + 1] = key
			end
		end
		table.sort(keys, function(a, b)
			if type(a) ~= type(b) then
				return type(a) == "number"
			end
			return a < b
		end)
		for _, key in ipairs(keys) do
			local name = type(key) == "string" and ("[%q]"):format(key) or ("[%s]"):format(tostring(key))
			wtf.serialize(value[key], lines, name .. " = ", ",")
		end
		lines[#lines + 1] = "}" .. suffix
	elseif kind == "string" then
		lines[#lines + 1] = prefix .. ("%q"):format(value):gsub("\\\n", "\\n"):gsub("\r", "\\r") .. suffix
	elseif kind == "number" and value % 1 == 0 and math.abs(value) < 2 ^ 53 then
		lines[#lines + 1] = prefix .. ("%d"):format(value) .. suffix
	elseif kind == "number" then
		lines[#lines + 1] = prefix .. ("%.17g"):format(value) .. suffix
	else
		lines[#lines + 1] = prefix .. tostring(value) .. suffix
	end
end

-- `text`, a SavedVariables file in the client's layout, with the global `name` assigned `value` instead
-- (wtf.serialize), every other line as it was and the file's line ends kept. Nil and why when the file doesn't
-- assign `name` once at the top level.
function wtf.replaceGlobal(text, name, value)
	local eol = text:find("\r\n", 1, true) and "\r\n" or "\n"
	local trailing = text:sub(-#eol) == eol
	local lines = {}
	for line in (trailing and text or text .. eol):gmatch("(.-)" .. eol) do
		lines[#lines + 1] = line
	end
	local first, last
	for i, line in ipairs(lines) do
		local global = line:match("^([%a_][%w_]*) = ")
		if global and first and not last then
			last = i - 1
		end
		if global == name then
			if first then
				return nil, "it assigns " .. name .. " twice"
			end
			first = i
		end
	end
	if not first then
		return nil, "it has no " .. name .. " = line, so it isn't in the client's layout"
	end
	last = last or #lines
	while last > first and lines[last] == "" do
		last = last - 1
	end
	local replaced = {}
	for i = 1, first - 1 do
		replaced[#replaced + 1] = lines[i]
	end
	wtf.serialize(value, replaced, name .. " = ", "")
	for i = last + 1, #lines do
		replaced[#replaced + 1] = lines[i]
	end
	return table.concat(replaced, eol) .. (trailing and eol or "")
end

-- "1 Cast", "2 Casts"; plural defaults to noun .. "s".
function wtf.count(n, noun, plural)
	return n .. " " .. (n == 1 and noun or plural or noun .. "s")
end

-- A character's name in the Catch log's character table (LOG-R26), "Ada Brook", or "?" for one it lacks.
function wtf.characterName(log, char)
	local c = log.characters[char] or {}
	return table.concat({ tostring(c.name or "?"), c.surname and tostring(c.surname) or nil }, " ")
end

-- Runs the addon file at `path` as the client runs an addon's files, as chunk(addonName, ns), with `env` as its
-- globals. Returns true, or nil and why when the file can't be loaded or raises.
function wtf.loadInto(ns, env, path, addonName)
	local chunk, loadErr = loadfile(path)
	if not chunk then
		return nil, loadErr
	end
	setfenv(chunk, env)
	local ok, runErr = pcall(chunk, addonName, ns)
	if not ok then
		return nil, runErr
	end
	return true
end

-- LuaBitOp, the `bit` library the client ships (LOG-R66): the one setup.sh pins in .tools/, which a plain `lua`
-- doesn't look in, or the one already on package.cpath (busted's). Nil when neither loads. The .tools/ is
-- $PAGLE_TOOLS, which the scripts that run this (scripts/lib/tools.sh) set to the one they use: the main checkout's, in
-- a worktree without its own.
function wtf.luaBitOp()
	local cpath = package.cpath
	local tools = os.getenv("PAGLE_TOOLS") or ROOT .. "/.tools"
	package.cpath = tools .. "/lua/lib/lua/5.1/?.so;" .. cpath
	local ok, bit = pcall(require, "bit")
	package.cpath = cpath
	return ok and bit or nil
end

-- Core's namespace with `files` (paths under addons/Pagle/, such as "logic/CatchLog.lua"), each called with
-- ("Pagle", ns) as the client calls them, in an environment over the standard globals (logic/ and locale/ are plain
-- Lua 5.1, CORE-R7) plus LuaBitOp's `bit` for logic/Size.lua (LOG-R66). Without LuaBitOp, Size.lua still loads
-- but can't size a Catch. Raises when a file can't be loaded.
function wtf.loadCore(files)
	local ns = {}
	local env = setmetatable({ bit = wtf.luaBitOp() or {} }, { __index = _G })
	for _, file in ipairs(files) do
		assert(wtf.loadInto(ns, env, ROOT .. "/addons/Pagle/" .. file, "Pagle"))
	end
	return ns
end

-- Each line of addons/<addon>/<addon>.toc, in order, trimmed and with forward slashes: its files as paths under
-- addons/<addon>/, among its metadata and blank lines, which match no file pattern.
function wtf.tocEntries(addon)
	local entries = {}
	for _, line in ipairs(assert(wtf.readLines(ROOT .. "/addons/" .. addon .. "/" .. addon .. ".toc"))) do
		entries[#entries + 1] = (line:match("^%s*(.-)%s*$"):gsub("\\", "/"))
	end
	return entries
end

-- The Ledger's namespace with its logic: each logic/ file Pagle_Ledger.toc lists, in TOC order, called with
-- ("Pagle_Ledger", ns) as the client calls an addon's files (spec/support/addon.lua loads them the same way). Their
-- CORE-R11 guard reads the Pagle global, so it's a table here; logic/ is plain Lua 5.1 (CORE-R7) and reads nothing
-- else of Core's at load. Raises when one can't be loaded.
function wtf.loadLedgerLogic()
	local ns = {}
	local env = setmetatable({ Pagle = {} }, { __index = _G })
	local dir = ROOT .. "/addons/Pagle_Ledger/"
	for _, file in ipairs(wtf.tocEntries("Pagle_Ledger")) do
		if file:match("^logic/[^/]+%.lua$") then
			assert(wtf.loadInto(ns, env, dir .. file, "Pagle_Ledger"))
		end
	end
	return ns
end

-- Core's catalogue accessors (LOG-R55) over a Catalogue.lua in the generated file's shape (DATA-R76), the repo's
-- addons/Pagle/data/Catalogue.lua when `path` is nil: the file and Core's logic/Catalogue.lua, each called with
-- ("Pagle", ns) as the client calls them, as FakePagle builds its catalogue. Returns nil and why when the file can't
-- be loaded.
function wtf.loadCatalogue(path)
	local ns = {}
	local env = setmetatable({}, { __index = _G })
	for _, file in ipairs({
		path or ROOT .. "/addons/Pagle/data/Catalogue.lua",
		ROOT .. "/addons/Pagle/logic/Catalogue.lua",
	}) do
		local ok, err = wtf.loadInto(ns, env, file, "Pagle")
		if not ok then
			return nil, err
		end
	end
	if type(ns.catalogue) ~= "table" then
		return nil, "it sets no catalogue"
	end
	local ok, catalogue = pcall(ns.NewCatalogue, ns.catalogue)
	if not ok then
		return nil, catalogue
	end
	return catalogue
end

return wtf
