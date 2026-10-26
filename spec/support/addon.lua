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
-- them, and stubs for the WoW API the addon calls. loadAddon fires ADDON_LOADED after the last file, as the client
-- does. An addon's `## Dependencies` load first, into the same globals and client, so
-- loadAddon("Pagle_QoL", FOREVER_GLOBALS) runs Core and then QoL; loaded.namespaces.Pagle is Core's ns. The client's
-- Settings panel (loaded.client.settings) records the categories and rows an addon registers and can show a page, as
-- the panel would draw it.
--
-- Each load gets its own globals table, so nothing an addon defines (LibStub, Pagle) leaks into the next load.
-- Names not in it fall back to the Lua 5.1 globals busted runs with.
--
-- It also defines the fixtures PROJECT_IDS, FOREVER_GLOBALS, PLAYER_GUID and SERVER_TIME, so every spec agrees on
-- them, and loads spec/support/fake_pagle.lua, which defines newFakePagle (FakePagle, CORE-R18) for Module specs,
-- and spec/support/helpers.lua, the helpers many specs share.
--
-- The fake client is split by concern, one file each under spec/support/: client.lua (events, addons, loot and the
-- base WoW API), widgets.lua, timers.lua, settings.lua (the Settings panel), menu.lua (slash commands and context
-- menus), fake_game.lua, fake_popup.lua, fake_tooltip.lua, toc.lua (the TOC reader), and errors.lua (the error lists
-- that fail a spec which never asserts what they got).
--
-- Globals rather than a module: the types stage checks spec/ against the WoW client's Lua, which has no require.

--- Project IDs as the clients set WOW_PROJECT_ID. Forever's is WOW_PROJECT_CAMELOT, 18 (BIR forever README at
--- BIR_COMMIT, scripts/tools.env).
PROJECT_IDS = { CAMELOT = 18, MAINLINE = 1 }

--- The globals a Forever client defines, for loadAddon. loadAddon copies them, so specs share this one table.
FOREVER_GLOBALS = { WOW_PROJECT_ID = PROJECT_IDS.CAMELOT, WOW_PROJECT_CAMELOT = PROJECT_IDS.CAMELOT }

---@class LoadedAddon
---@field ns table The addon's private table, shared by every file it loads.
---@field namespaces table<string, table> The private table of each addon loaded, its dependencies too, by folder
--- name: `namespaces.Pagle` is Core's when a Module was loaded.
---@field env table<string, any> The globals the files saw and set; `env.Pagle` is the Pagle global.
---@field printed string[] Each line the addon printed to chat, in order.
---@field client FakeClient The fake client the addon runs against.

--- The player's character GUID, as UnitGUID("player") returns it.
PLAYER_GUID = "Player-1-00000001"

--- The fake client's server time, as GetServerTime() returns it, and FakePagle's at its clock's 0: 2026-10-11
--- 15:15:00 UTC, which is realm 08:15 on a US Pacific realm.
SERVER_TIME = 1791731700

-- The error lists the fake client and FakePagle keep, which fail a spec that never reads them (see the end).
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local errors = dofile("spec/support/errors.lua")
--- Puts a fresh error list at `owner[key]` and returns what adds to it (spec/support/errors.lua): the fake client's
--- `client.errors` and FakePagle's `fake.reported`.
watchErrors = errors.watch

-- A fresh fake client and its base WoW API stubs.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newClient = dofile("spec/support/client.lua")
-- The stub sets loadAddon adds to every load, in order, each as addStubs(client, stubs).
local STUB_SETS = {
	-- C_Timer and GetTime, with the client's clock.
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	dofile("spec/support/timers.lua").addStubs,
	-- The Settings API and panel.
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	dofile("spec/support/settings.lua"),
	-- Slash commands and context menus.
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	dofile("spec/support/menu.lua"),
	-- The game side QoL reads and binds: bindings, held keys, casts, the main hand, the frame loop.
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	dofile("spec/support/fake_game.lua"),
	-- Popups and addon switches, for QoL's conflict popup.
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	dofile("spec/support/fake_popup.lua"),
	-- Tooltip data hooks, for the diagnostics buffer's hovers.
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	dofile("spec/support/fake_tooltip.lua"),
}
-- Reads a TOC; also defines the global addonFiles.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local readToc = dofile("spec/support/toc.lua")

--- Loads addons/<name>/<name>.toc and every file it lists, in order, as the client does, then fires
--- ADDON_LOADED(name). Each addon its `## Dependencies` names is loaded first, the same way and into the same
--- globals and fake client, as the client loads them: `loadAddon("Pagle_QoL")` runs Core, then QoL.
--- Each addon loaded is listed in client.addons, enabled and loaded, with its TOC fields as its metadata, and the
--- bindings its Bindings.xml names are added to client.bindings.
--- Raises an error naming the TOC and the file if a listed file is missing or fails while loading.
---@param name string The addon's folder under addons/, which is also its TOC's name.
---@param globals table<string, any>? Globals the client defines for this load, e.g. WOW_PROJECT_ID. They replace
--- the fake client's stubs of the same name, e.g. InCombatLockdown for a load in combat.
---@param options { holdAddonLoaded: boolean?, dependencyLibsOnly: boolean?, replace: table<string, string>?, also: string[]?, beforeLoaded: table<string, fun(ns: table, client: FakeClient, env: table)>?, addonRoot: string? }?
--- addonRoot: folder containing the addon folders, for exercising the actual unpacked release.
--- holdAddonLoaded: don't fire ADDON_LOADED(name); the spec fires it with loaded.client.fire, e.g. after adding a
--- listener that must be there before it. dependencyLibsOnly: load only the libs/ files of each dependency, for a
--- stand-in that provides the rest (FakePagle's fake.load). replace: files of the named addon to load from another
--- path, in their TOC place, by the path the TOC lists (`{ ["data/Lore.lua"] = "spec/…/Lore.lua" }`), e.g. a
--- generated fixture in place of the committed generated file. also: more addons to load after the named one, in
--- order, into the same globals and client, each after its dependencies and with its own ADDON_LOADED, as the client
--- loads every enabled addon (`{ "Pagle_Hunts", "Pagle_QoL" }`): a spec of the whole package, every Module loaded.
--- beforeLoaded: by addon name, a function given that addon's ns once its files have run and before its ADDON_LOADED,
--- e.g. to turn off a Tunable its OnInitialize reads (`{ Pagle_Hunts = function(ns) ns.COMPANION_HINT_ON = false end }`).
---@return LoadedAddon
function loadAddon(name, globals, options)
	options = options or {}
	local printed = {}

	local client, env = newClient()
	for _, addStubs in ipairs(STUB_SETS) do
		addStubs(client, env)
	end
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

	local namespaces = {}
	-- Loads one addon after its dependencies; returns why it failed, or nil.
	local function load(addon, isDependency)
		local dir = (options.addonRoot or "addons") .. "/" .. addon .. "/"
		local toc = dir .. addon .. ".toc"
		local files, fields = readToc(toc)
		for dependency in (fields.Dependencies or ""):gmatch("[^%s,]+") do
			if not namespaces[dependency] then
				local err = load(dependency, true)
				if err then
					return err
				end
			end
		end

		client.addons[addon] = { enabled = true, loaded = true, metadata = fields }
		-- The client reads an addon's Bindings.xml by name, not from its TOC.
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
		local bindingsXml = io.open(dir .. "Bindings.xml", "r")
		if bindingsXml then
			for binding in bindingsXml:read("*a"):gsub("<!%-%-.-%-%->", ""):gmatch('<Binding%s[^>]*name="([^"]+)"') do
				client.bindings[#client.bindings + 1] = binding
			end
			bindingsXml:close()
		end
		local ns = {}
		namespaces[addon] = ns
		for _, file in ipairs(files) do
			if file:match("%.xml$") then
				-- The client builds an XML file's frames; specs need only its virtual templates, by name.
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no io
				local xml = io.open(dir .. file, "r")
				if not xml then
					return ("%s lists %s, which doesn't exist"):format(toc, file)
				end
				for attributes in xml:read("*a"):gsub("<!%-%-.-%-%->", ""):gmatch("<Frame%s([^>]*)>") do
					local template = attributes:match('name="([^"]+)"')
					if template and attributes:match('virtual="true"') then
						client.templates[template] = { mixin = attributes:match('mixin="([^"]+)"') }
					end
				end
				xml:close()
			elseif not (isDependency and options.dependencyLibsOnly) or file:match("^libs/") then
				---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
				local chunk, loadErr = loadfile((not isDependency and (options.replace or {})[file]) or dir .. file)
				if not chunk then
					return ("%s lists %s, which doesn't load: %s"):format(toc, file, loadErr)
				end
				setfenv(chunk, env)
				local ok, runErr = pcall(chunk, addon, ns)
				if not ok then
					return ("%s: %s failed while loading: %s"):format(toc, file, tostring(runErr))
				end
			end
		end
		local before = options.beforeLoaded and options.beforeLoaded[addon]
		if before then
			before(ns, client, env)
		end
		if isDependency or not options.holdAddonLoaded then
			client.fire("ADDON_LOADED", addon)
		end
		return nil
	end
	local err = load(name, false)
	if err then
		error(err, 2)
	end
	assert(not (options.also and options.dependencyLibsOnly), "also loads whole addons, not libs only")
	for _, addon in ipairs(options.also or {}) do
		if not namespaces[addon] then
			err = load(addon, true)
			if err then
				error(err, 2)
			end
		end
	end

	return { ns = namespaces[name], namespaces = namespaces, env = env, printed = printed, client = client }
end

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
dofile("spec/support/fake_pagle.lua")
-- foreverWith, setCombat, openedNames, savedLog and loadCollectingErrors, for every spec.
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
dofile("spec/support/helpers.lua")

-- busted calls what its helper returns with itself: every spec, in every file, ends by failing if an error reached
-- an error list it never read (spec/support/errors.lua), so an unexpected error can't pass unseen.
---@param busted table
---@return boolean
return function(busted)
	local running -- the spec running, to name it: busted reports a failing after_each as the suite's
	busted.subscribe({ "test", "start" }, function(element)
		running = element.name
		return nil, true
	end)
	busted.executors.after_each(function()
		local unread = errors.unasserted()
		if #unread > 0 then
			local heading = ('"%s" got errors it never asserted (read client.errors or fake.reported):\n'):format(
				tostring(running)
			)
			error(heading .. table.concat(unread, "\n"), 0)
		end
	end)
	return true
end
