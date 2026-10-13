-- busted's helper (.busted). It defines loadAddon, which loads an addon the way the WoW client does, so specs
-- exercise the real load order (roadmap M0 › Toolchain): every file addons/<Addon>/<Addon>.toc lists, vendored libs
-- included, in TOC order, each called with (addonName, ns) and one ns shared by all of them. A file missing from the
-- TOC, or listed after a file that needs it, fails the specs that load the addon.
--
--   local loaded = loadAddon("Pagle", FOREVER_GLOBALS)
--   loaded.env.Pagle, loaded.ns.IsForever, loaded.printed
--   loaded.client.fire("PLAYER_REGEN_DISABLED")
--
-- The addon runs against a fake client: frames that keep the events they register, so loaded.client.fire reaches
-- them, and stubs for the WoW API the addon calls (clientStubs below). loadAddon fires ADDON_LOADED after the last
-- file, as the client does.
--
-- Each load gets its own globals table, so nothing an addon defines (LibStub, Pagle) leaks into the next load.
-- Names not in it fall back to the Lua 5.1 globals busted runs with.
--
-- It also defines the Forever fixtures, PROJECT_IDS and FOREVER_GLOBALS, so every spec agrees on them, and loads
-- spec/support/fake_pagle.lua, which defines newFakePagle (FakePagle, CORE-R18) for Module specs.
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
---@field client FakeClient The fake client the addon runs against.

--- The client's event system and addon list, as far as specs need them.
---@class FakeClient
---@field missingEvents table<string, true> Events this client doesn't know: registering one raises an error, as the
--- client does. Specs add to it.
---@field frames table[] Every frame CreateFrame made, in order.
---@field fire fun(event: string, ...) Fires a WoW event at each frame registered for it, in creation order, calling
--- its OnEvent script with (frame, event, ...). A unit event reaches a frame only for the units it registered.
---@field addons table<string, FakeAddOn> The other addons installed, by folder name ("Pagle_QoL"), as C_AddOns
--- reports them. One not listed is missing. Specs add to it.

--- An installed addon, as the fake client's C_AddOns reports it.
---@class FakeAddOn
---@field enabled boolean? Enabled for the player's character in the AddOns list. Default true.
---@field loaded boolean? Loaded this session. Default: whether it's enabled.
---@field metadata table<string, string>? Its TOC fields, e.g. ["X-Pagle-API"] = "1".

--- The player's character GUID, as UnitGUID("player") returns it.
PLAYER_GUID = "Player-1-00000001"

---@return FakeClient
local function newClient()
	local client = { missingEvents = {}, frames = {}, addons = {} }

	function client.fire(event, ...)
		local unit = ...
		for _, frame in ipairs({ unpack(client.frames) }) do
			local registered = frame.events[event]
			local onEvent = frame.scripts.OnEvent
			if registered and onEvent and (registered == true or registered[unit]) then
				onEvent(frame, event, ...)
			end
		end
	end

	return client
end

-- A frame that records the events it registers and its scripts, so client.fire can reach it.
---@param client FakeClient
local function newFrame(client)
	local frame = { events = {}, scripts = {} }
	local function known(event)
		if client.missingEvents[event] then
			error(('Frame:RegisterEvent(): Attempt to register unknown event "%s"'):format(event), 3)
		end
	end
	function frame:RegisterEvent(event)
		known(event)
		self.events[event] = true
	end
	function frame:RegisterUnitEvent(event, ...)
		known(event)
		local units = {}
		for i = 1, select("#", ...) do
			units[(select(i, ...))] = true
		end
		self.events[event] = units
	end
	function frame:UnregisterEvent(event)
		self.events[event] = nil
	end
	function frame:UnregisterAllEvents()
		self.events = {}
	end
	function frame:SetScript(script, fn)
		self.scripts[script] = fn
	end
	client.frames[#client.frames + 1] = frame
	return frame
end

-- The WoW API the addons call, answering as one fixed character on a US realm, out of combat, with no addon
-- restriction active and no secret values.
---@param client FakeClient
---@return table<string, any>
local function clientStubs(client)
	local stubs
	stubs = {
		CreateFrame = function()
			return newFrame(client)
		end,
		IsLoggedIn = function()
			return false
		end,
		-- The client's default handler reports an error and carries on; here it fails the spec instead.
		geterrorhandler = function()
			return function(err)
				error(err, 0)
			end
		end,
		-- As the client's: an error goes to whatever geterrorhandler() returns at the time, and the caller carries on.
		securecallfunction = function(fn, ...)
			local results = { pcall(fn, ...) }
			if not results[1] then
				stubs.geterrorhandler()(results[2])
				return
			end
			return unpack(results, 2, table.maxn(results))
		end,
		issecretvalue = function()
			return false
		end,
		InCombatLockdown = function()
			return false
		end,
		C_RestrictedActions = {
			GetAddOnRestrictionState = function()
				return 0 -- Enum.AddOnRestrictionState.Inactive
			end,
		},
		-- The forever dump's LuaEnum.lua at BIR_COMMIT (scripts/tools.env).
		Enum = {
			AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
			AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
			AddOnEnableState = { None = 0, Some = 1, All = 2 },
		},
		-- No area has a name, so the area index Core builds at PLAYER_LOGIN is empty.
		C_Map = {
			GetAreaInfo = function()
				return nil
			end,
		},
		-- Reads client.addons. Folder names as the client takes them; an addon not listed is missing.
		C_AddOns = {
			GetAddOnInfo = function(name)
				if client.addons[name] then
					return name, name, "", true, nil
				end
				return name, nil, nil, false, "MISSING"
			end,
			-- Enum.AddOnEnableState: None 0, All 2. Enabled only for the player's own character.
			GetAddOnEnableState = function(name, character)
				local addon = client.addons[name]
				return (addon and addon.enabled ~= false and character == PLAYER_GUID) and 2 or 0
			end,
			IsAddOnLoaded = function(name)
				local addon = client.addons[name]
				local loaded = addon ~= nil and (addon.loaded or (addon.loaded == nil and addon.enabled ~= false))
				return loaded, loaded
			end,
			GetAddOnMetadata = function(name, field)
				local addon = client.addons[name]
				return addon and addon.metadata and addon.metadata[field]
			end,
		},
		UnitGUID = function(unit)
			return unit == "player" and PLAYER_GUID or nil
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
	return stubs
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

--- The files addons/<name>/<name>.toc lists, in order, relative to the addon folder with forward slashes
--- ("logic/Modules.lua").
---@param name string
---@return string[]
function addonFiles(name)
	return tocFiles("addons/" .. name .. "/" .. name .. ".toc")
end

--- Loads addons/<name>/<name>.toc and every file it lists, in order, as the client does, then fires
--- ADDON_LOADED(name).
--- Raises an error naming the TOC and the file if a listed file is missing or fails while loading.
---@param name string The addon's folder under addons/, which is also its TOC's name.
---@param globals table<string, any>? Globals the client defines for this load, e.g. WOW_PROJECT_ID. They replace
--- the fake client's stubs of the same name, e.g. InCombatLockdown for a load in combat.
---@param options { holdAddonLoaded: boolean? }? holdAddonLoaded: don't fire ADDON_LOADED; the spec fires it with
--- loaded.client.fire, e.g. after adding a listener that must be there before it.
---@return LoadedAddon
function loadAddon(name, globals, options)
	local dir = "addons/" .. name .. "/"
	local toc = dir .. name .. ".toc"
	local printed = {}

	local client = newClient()
	local env = clientStubs(client)
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
	if not (options and options.holdAddonLoaded) then
		client.fire("ADDON_LOADED", name)
	end

	return { ns = ns, env = env, printed = printed, client = client }
end

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
dofile("spec/support/fake_pagle.lua")
