-- What scripts/read-wtf.lua and scripts/make-test-log.lua share, written once: reading files, loading a
-- SavedVariables file as data, and loading Core's and the Ledger's own files (CORE-R7's plain-Lua logic/, the
-- catalogue) the way the client calls an addon's files. A script loads it in its own environment and calls it with
-- the repo root:
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

-- Loads a SavedVariables text as data and returns the globals it assigned, or nil and why not: it runs in an empty
-- environment, so it can only assign values, and a precompiled chunk is refused. `name` names it in errors.
function wtf.loadSavedVariables(text, name)
	if text:sub(1, 1) == "\27" then
		return nil, "a precompiled chunk, not data"
	end
	local chunk, loadErr = loadstring(text, "=" .. name)
	if not chunk then
		return nil, loadErr
	end
	local globals = {}
	setfenv(chunk, globals)
	local ok, runErr = pcall(chunk)
	if not ok then
		return nil, runErr
	end
	return globals
end

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
-- doesn't look in, or the one already on package.cpath (busted's). Nil when neither loads.
function wtf.luaBitOp()
	local cpath = package.cpath
	package.cpath = ROOT .. "/.tools/lua/lib/lua/5.1/?.so;" .. cpath
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
