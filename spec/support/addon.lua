-- busted's helper (.busted). It defines loadAddon, which loads an addon the way the WoW client does, so specs
-- exercise the real load order (roadmap M0 › Toolchain): every file addons/<Addon>/<Addon>.toc lists, vendored libs
-- included, in TOC order, each called with (addonName, ns) and one ns shared by all of them. A file missing from the
-- TOC, or listed after a file that needs it, fails the specs that load the addon.
--
--   local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
--   loaded.env.Pagle, loaded.ns.IsForever, loaded.printed
--
-- Each load gets its own globals table, so nothing an addon defines (LibStub, Pagle) leaks into the next load.
-- Names not in it fall back to the Lua 5.1 globals busted runs with.
--
-- It also defines the Forever fixtures, PROJECT_IDS and FOREVER_GLOBALS, so every spec agrees on them.
--
-- Globals rather than a module: the types stage checks spec/ against the WoW client's Lua, which has no require.

--- Project IDs as the clients set WOW_PROJECT_ID. Forever's is WOW_PROJECT_CAMELOT, 18 (BIR forever README at
--- BIR_COMMIT, scripts/tools.env).
PROJECT_IDS = { CAMELOT = 18, MAINLINE = 1 }

--- The globals a Forever client defines, for loadAddon. loadAddon copies them, so specs share this one table.
FOREVER_GLOBALS = { WOW_PROJECT_ID = PROJECT_IDS.CAMELOT, WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT }

---@class LoadedAddon
---@field ns table The addon's private table, shared by every file it loads.
---@field env table<string, any> The globals the files saw and set; `env.Pagle` is the Pagle global.
---@field printed string[] Each line the addon printed to chat, in order.

local function noop() end

-- A frame that accepts the calls the vendored libs make at load and does nothing with them.
local function newFrame()
	return {
		RegisterEvent = noop,
		UnregisterEvent = noop,
		UnregisterAllEvents = noop,
		SetScript = noop,
	}
end

-- The WoW API the vendored libs call while loading, answering as one fixed character on a US realm.
---@return table<string, any>
local function clientStubs()
	return {
		CreateFrame = newFrame,
		IsLoggedIn = function()
			return false
		end,
		-- The client's default handler reports an error and carries on; here it fails the spec instead.
		geterrorhandler = function()
			return function(err)
				error(err, 0)
			end
		end,
		securecallfunction = function(fn, ...)
			return fn(...)
		end,
		GetLocale = function()
			return "enUS"
		end,
		UnitFactionGroup = function()
			return "Alliance", "Alliance"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitRace = function()
			return "Human", "Human", 1
		end,
		UnitNameUnmodified = function()
			return "Angler"
		end,
		GetRealmName = function()
			return "Testrealm"
		end,
		GetCurrentRegion = function()
			return 1
		end,
		GetCurrentRegionName = function()
			return "US"
		end,
	}
end

--- The files a TOC lists, in order, as paths relative to the addon folder with forward slashes.
---@param tocPath string
---@return string[]
local function tocFiles(tocPath)
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
	local toc = assert(io.open(tocPath, "r"))
	local files = {}
	for line in toc:lines() do
		line = line:gsub("\r$", ""):match("^%s*(.-)%s*$")
		if line ~= "" and line:sub(1, 1) ~= "#" then
			files[#files + 1] = (line:gsub("\\", "/"))
		end
	end
	toc:close()
	return files
end

--- Loads addons/<name>/<name>.toc and every file it lists, in order, as the client does.
--- Raises an error naming the TOC and the file if a listed file is missing or fails while loading.
---@param name string The addon's folder under addons/, which is also its TOC's name.
---@param globals table<string, any>? Globals the client defines for this load, e.g. WOW_PROJECT_ID.
---@return LoadedAddon
function loadAddon(name, globals)
	local dir = "addons/" .. name .. "/"
	local toc = dir .. name .. ".toc"
	local printed = {}

	local env = clientStubs()
	env.print = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			parts[i] = tostring((select(i, ...)))
		end
		printed[#printed + 1] = table.concat(parts, " ")
	end
	for key, value in pairs(globals or {}) do
		env[key] = value
	end
	env._G = env
	setmetatable(env, { __index = _G })

	local ns = {}
	for _, file in ipairs(tocFiles(toc)) do
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
		local chunk, loadErr = loadfile(dir .. file)
		if not chunk then
			error(("%s lists %s, which doesn't load: %s"):format(toc, file, loadErr), 2)
		end
		setfenv(chunk, env)
		local ok, runErr = pcall(chunk, name, ns)
		if not ok then
			error(("%s: %s failed while loading: %s"):format(toc, file, tostring(runErr)), 2)
		end
	end

	return { ns = ns, env = env, printed = printed }
end
