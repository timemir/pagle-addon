-- FakePagle (CORE-R18): the Core test double Module specs run against, so a Module is specced without Core's
-- adapter, the WoW client or SavedVariables. spec/support/addon.lua loads this file, so busted's helper defines
-- newFakePagle for every spec.
--
--   local fake = newFakePagle()
--   local loaded = fake.load("Pagle_QoL")                 -- the Module sees fake.globals.Pagle as its Pagle
--   fake.login()                                            -- Core's PLAYER_LOGIN: the character, ModulesChanged
--   fake.fire("RestrictionChanged", true)                   -- any Core event; tables arrive read-only
--   fake.setRestricted(true)
--   fake.playCast("caught", { { itemID = 6358, quantity = 1 } }) -- CastStarted … Catch, CastEnded (LOG-R9)
--
-- It is built on Core's real logic/: each FakePagle loads Pagle.toc's data/, locale/ and logic/ files (and the
-- CallbackHandler bus) afresh, so what it validates, computes and refuses is what Core does. Only the adapter part
-- is faked.
--
-- Records Core hands to Modules are shared and immutable (CORE-R18). FakePagle hands out read-only proxies
-- instead, which raise an error on any write, so a Module that writes to one fails its spec. Lua 5.1 can't make a
-- proxy behave fully like its record: `#proxy` is 0, and the stock pairs, ipairs, next and unpack see an empty table.
-- fake.globals replaces those four with proxy-aware ones for Module code loaded with it; a spec that walks a record
-- itself uses fake.globals.pairs and friends.
--
-- Extending it: each Core ticket that adds a Pagle call or a Module handle method adds a part (see `part` below)
-- that fakes it, specced in spec/support/fake_pagle_spec.lua against the rule Core follows.

--- A fresh Core double. Every field is the spec's to read; `addons` and `Pagle` are also the spec's to change.
---@class FakePagle
---@field Pagle table The Pagle API Core publishes. Specs may stub on it; Modules see it read-only via `globals`.
---@field globals table<string, any> Globals for `loadAddon` when it loads a Module: `Pagle` (read-only) and the
--- proxy-aware `pairs`, `ipairs`, `next` and `unpack`.
---@field ns table Core's logic/ (with `ns.L` and `ns.catalogue`), loaded for this fake alone.
---@field registry PagleModuleRegistry Core's real Module registry; `registry:ModuleOf(handle)` finds a Module.
---@field addons table<string, FakeAddOn> The roster Modules' addons by folder name, as the client reports them.
--- By default each is installed, enabled, loaded and declares `X-Pagle-API` = API_VERSION. Set one to nil to
--- uninstall it.
---@field printed string[] Each chat line Core printed, in order.
---@field fire fun(event: string, ...) Fires a Core event on the bus, each table in the payload read-only.
---@field fireGameEvent fun(event: string, ...) Calls the handlers registered with Pagle.RegisterEvent or
--- RegisterUnitEvent for a WoW event, as the client would fire it. A unit event reaches only its unit's handlers.
---@field setRestricted fun(isRestricted: boolean) Sets the restriction state; RestrictionChanged fires on a change.
---@field login fun() Does Core's PLAYER_LOGIN work: adds the character (PLAYER_GUID) to the Angler, then fires
--- ModulesChanged. Raises an error if called twice.
---@field readSkill fun(rank: integer, max: integer, mod: integer) Reads fishing skill as Core does after login: an
--- S1 when rank or max changed, then SkillChanged; then fake.conditions takes the rank and modifier, firing
--- ConditionsChanged({"skill"}) if either changed. Does nothing before login.
---@field readOnly fun(value: any): any The read-only proxy of a table (the same one each time); other values as is.
---@field moduleState fun(name: string): PagleModuleState A roster Module's state (CORE-R41).
---@field settingsPage fun(topic: string): { module: string, kind: string, label: string, indented: boolean, setting: PagleSetting }[]?
--- The rows Core would put on a topic page, in order, its header rows included; nil before login or with no rows,
--- when Core registers no page (CORE-R42).
---@field reported string[] Each error Core reported through geterrorhandler(), e.g. a late M:AddSetting.
---@field openedSettings string[] What each Pagle.OpenSettings opened: "root" or the topic (CORE-R43).
---@field load fun(name: string, options: table?): LoadedAddon Loads a Module with `loadAddon` against this fake:
--- `globals`, and of Pagle.toc only the vendored libs/ the Module reaches through LibStub (CORE-R6). Options as
--- loadAddon's. WoW events its client raises on its own (`client.fireGameEvent`) go to `fake.fireGameEvent`.
---@field catchLog PagleCatchLog The Catch log Pagle.IterateCatches reads, on Core's real codec; empty at first.
---@field setCatalogue fun(data: table) Serves the catalogue calls over `data` (shaped as ns.catalogue, DATA-R76)
--- instead of the generated catalogue.
---@field conditions ConditionsSnapshot The live conditions Pagle.GetConditions serves (without `restricted`, which
--- follows setRestricted). Read it; change it with setConditions.
---@field setConditions fun(snapshot: ConditionsSnapshot) Replaces the live conditions and fires ConditionsChanged
--- with the keys that changed, if any (LOG-R47).
---@field playCast fun(outcome: "caught"|"gotAway"|"interrupted", items: PagleLootItem[]?): PagleCast? Plays a whole
--- Cast's signals: a fishing channel, then its loot (`items`, as `{ itemID, quantity }`), LOOT_CLOSED and the
--- channel stopping; or the escaped message; or the channel stopping and the grace time passing. Returns the Cast
--- recorded (read-only), nil when interrupted or before login.
---@field channel fun(spellID: integer?) The player's channel starts (LOG-R2); Fishing (7731) by default.
---@field stopChannel fun(spellID: integer?) The player's channel stops; its grace time starts (LOG-R7).
---@field loot fun(items: PagleLootItem[]?, isFishing: boolean?) LOOT_READY with these items; fishing loot by default.
---@field closeLoot fun() LOOT_CLOSED.
---@field escape fun() The game reports the fish escaped (LOG-R6).
---@field wait fun(seconds: number) Moves the fake's clock on, running each grace timer that comes due.

-- Core's logic/ for one fake: Pagle.toc's libs (for the bus), generated data/, locale/ and logic/ files, in TOC
-- order, sharing one ns, as the client would load them. None uses WoW globals (CORE-R7), so plain Lua runs them.
---@return table ns
---@return table env
local function loadCoreLogic()
	local env = setmetatable({}, { __index = _G })
	-- LibStub keeps itself in _G.LibStub: this one stays in env, or every later load would share its libraries.
	env._G = env
	-- CallbackHandler calls each listener through this. Here a listener's error fails the spec instead.
	env.securecallfunction = function(fn, ...)
		return fn(...)
	end
	local ns = {}
	for _, file in ipairs(addonFiles("Pagle")) do
		local wanted = file:match("^logic/")
			or file:match("^locale/")
			or file:match("^data/")
			or file:match("^libs/LibStub/")
			or file:match("^libs/CallbackHandler")
		if wanted then
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no loadfile
			local chunk = assert(loadfile("addons/Pagle/" .. file))
			setfenv(chunk, env)
			chunk("Pagle", ns)
		end
	end
	return ns, env
end

-- Read-only proxies (CORE-R18). Weak both ways, so one record has one proxy and neither keeps the other alive.
local originalOf = setmetatable({}, { __mode = "k" }) -- proxy -> record
local proxyOf = setmetatable({}, { __mode = "kv" }) -- record -> proxy

---@param value any
---@return any
local function readOnly(value)
	if type(value) ~= "table" or originalOf[value] then
		return value
	end
	local proxy = proxyOf[value]
	if not proxy then
		proxy = setmetatable({}, {
			__index = function(_, key)
				return readOnly(value[key])
			end,
			__newindex = function(_, key)
				error(
					("%s written to a record Core handed out; records are shared and immutable (CORE-R18)"):format(
						tostring(key)
					),
					2
				)
			end,
			__metatable = "read-only Pagle record",
		})
		originalOf[proxy] = value
		proxyOf[value] = proxy
	end
	return proxy
end

-- next, pairs, ipairs and unpack that see through a proxy, handing out read-only values.
local function proxyNext(t, key)
	local original = originalOf[t]
	if not original then
		return next(t, key)
	end
	local nextKey, value = next(original, key)
	return nextKey, readOnly(value)
end

local function proxyPairs(t)
	return proxyNext, t, nil
end

local function proxyIpairs(t)
	local original = originalOf[t]
	if not original then
		return ipairs(t)
	end
	local function step(_, i)
		local value = original[i + 1]
		if value == nil then
			return nil
		end
		return i + 1, readOnly(value)
	end
	return step, t, 0
end

local function proxyUnpack(t, i, j)
	local original = originalOf[t]
	if not original then
		return unpack(t, i, j)
	end
	i, j = i or 1, j or #original
	local values = {}
	for k = i, j do
		values[k - i + 1] = readOnly(original[k])
	end
	return unpack(values, 1, j - i + 1)
end

--- One part of the fake: it adds a Core topic's calls to `fake.Pagle` (and fake helpers to `fake`), using Core's
--- real logic in `ns`. Parts run in order, each on a fresh fake.
---@type fun(fake: FakePagle, Pagle: table, ns: table)[]
local parts = {}

---@param build fun(fake: FakePagle, Pagle: table, ns: table)
local function part(build)
	parts[#parts + 1] = build
end

-- WoW events through Pagle (CORE-R23). One handler per owner and event; registering again replaces it.
part(function(fake, Pagle)
	local handlers = {} -- event -> owner -> { fn, unit? }
	local function register(owner, event, unit, fn)
		handlers[event] = handlers[event] or {}
		handlers[event][owner] = { fn = fn, unit = unit }
	end
	function Pagle.RegisterEvent(owner, event, fn)
		register(owner, event, nil, fn)
	end
	function Pagle.RegisterUnitEvent(owner, event, unit, fn)
		register(owner, event, unit, fn)
	end
	function Pagle.UnregisterEvent(owner, event)
		if handlers[event] then
			handlers[event][owner] = nil
		end
	end
	function fake.fireGameEvent(event, ...)
		local unit = ...
		local listening = {}
		for _, handler in pairs(handlers[event] or {}) do
			listening[#listening + 1] = handler
		end
		for _, handler in ipairs(listening) do
			if handler.unit == nil or handler.unit == unit then
				handler.fn(event, ...)
			end
		end
	end
end)

-- Restriction state (CORE-R30), on Core's real Restriction logic. setRestricted works as combat would.
part(function(fake, Pagle, ns)
	local restriction = ns.NewRestriction(false, {})
	function Pagle.IsRestricted()
		return restriction:IsRestricted()
	end
	function fake.setRestricted(isRestricted)
		if restriction:SetCombat(isRestricted) then
			fake.fire("RestrictionChanged", isRestricted)
		end
	end
end)

-- Attaching a Module (CORE-R12–R14, CORE-R19, CORE-R41), on Core's real registry.
part(function(fake, Pagle, ns)
	fake.addons = {}
	for _, name in ipairs(ns.MODULE_ROSTER) do
		fake.addons[ns.ModuleAddOn(name)] =
			{ enabled = true, loaded = true, metadata = { ["X-Pagle-API"] = tostring(Pagle.API_VERSION) } }
	end
	fake.registry = ns.NewModuleRegistry(Pagle.API_VERSION)

	local function readAPI(addon)
		local info = fake.addons[addon]
		return info and info.metadata and info.metadata["X-Pagle-API"]
	end
	function Pagle.RegisterModule(def)
		local handle, problem = fake.registry:Register(def, readAPI)
		if problem then
			error(problem, 2)
		end
		if not handle then
			fake.printed[#fake.printed + 1] = ns.L.MODULE_NEEDS_NEWER_PAGLE:format(def.title)
		end
		return handle
	end

	function fake.moduleState(name)
		local info = fake.addons[ns.ModuleAddOn(name)]
		local enabled = info ~= nil and info.enabled ~= false
		return fake.registry:State(name, {
			installed = info ~= nil,
			enabled = enabled,
			loaded = info ~= nil and (info.loaded or (info.loaded == nil and enabled)),
		})
	end

	local loggedIn = false
	function fake.login()
		assert(not loggedIn, "FakePagle: PLAYER_LOGIN happens once a session")
		loggedIn = true
		fake.fire("ModulesChanged")
	end
end)

-- Settings (CORE-R33, CORE-R42, CORE-R43), on Core's real rows logic. Pages count as registered from login.
part(function(fake, Pagle, ns)
	local rows = ns.NewSettingsRows()
	local loggedIn = false
	fake.reported = {}
	fake.openedSettings = {}

	function ns.ModuleHandle:AddSetting(topic, setting)
		local module = fake.registry:ModuleOf(self)
		if not module then
			error("AddSetting is a Module handle method: call M:AddSetting(topic, setting)", 2)
		end
		local problem, late = rows:Add(module.def.name, topic, setting)
		if late then
			fake.reported[#fake.reported + 1] = problem
		elseif problem then
			error(problem, 2)
		end
	end

	Pagle.RegisterCallback(fake, "ModulesChanged", function()
		rows:Close()
		loggedIn = true
	end)

	function fake.settingsPage(topic)
		local entries = loggedIn and rows:Page(topic, fake.registry:Modules()) or {}
		if #entries == 0 then
			return nil
		end
		local page = {}
		for i, entry in ipairs(entries) do
			local setting = entry.setting
			page[i] = {
				module = entry.module.def.name,
				kind = setting.kind,
				label = setting.label,
				indented = entry.parent ~= nil,
				setting = setting,
			}
		end
		return page
	end

	function Pagle.OpenSettings(topic)
		if Pagle.IsRestricted() then
			fake.printed[#fake.printed + 1] = ns.L.SETTINGS_AFTER_COMBAT
		elseif loggedIn then
			fake.openedSettings[#fake.openedSettings + 1] = (type(topic) == "string" and fake.settingsPage(topic))
					and topic
				or "root"
		end
	end
end)

-- Condition specs (LOG-R48): pure, so the real one.
part(function(_, Pagle, ns)
	Pagle.MatchesConditions = ns.MatchesConditions
end)

-- The Catch log (LOG-R10–R16, LOG-R42) on Core's real codec, over an empty in-memory PagleLog. A spec adds
-- characters to fake.catchLog.data.characters and entries with fake.catchLog:Append(record).
part(function(fake, Pagle, ns)
	fake.catchLog = ns.OpenCatchLog(nil, { decodeErrors = 0 }, 1791731700)
	function Pagle.IterateCatches(afterSeq)
		local iterate = fake.catchLog:Iterate(afterSeq)
		return function()
			return readOnly(iterate())
		end
	end
end)

-- The Angler (LOG-R25–R27) and Skill Readings (LOG-R31, LOG-R32), on Core's real logic over fake.catchLog. Login
-- adds the fake client's character (PLAYER_GUID) before ModulesChanged, as Core's login order does (LOG-R1).
part(function(fake, Pagle, ns)
	local now = 1791731700 -- the fake client's GetServerTime()
	local angler = ns.NewAngler(fake.catchLog)
	function Pagle.GetAngler()
		return readOnly(angler:Get())
	end

	local login = fake.login
	function fake.login()
		angler:SeeCharacter({
			guid = PLAYER_GUID,
			name = "Angler",
			surname = "Tester",
			classID = 1,
			raceID = 1,
			faction = "Alliance",
			realmID = ns.RealmIDFromGUID(PLAYER_GUID),
		}, now)
		login()
	end

	function fake.readSkill(rank, max, mod)
		if not angler.current then
			return
		end
		local appended = angler:ReadSkill({ rank = rank, max = max, mod = mod }, now)
		if appended then
			fake.fire("SkillChanged", appended)
		end
		-- The live conditions follow the reading, through the same tracker as setConditions (LOG-R32, LOG-R47).
		local conditions = {}
		for key, value in pairs(fake.conditions) do
			conditions[key] = value
		end
		conditions.skillRank, conditions.skillMod = rank, mod
		fake.setConditions(conditions)
	end
end)

-- The catalogue (LOG-R55), on Core's real accessors over the generated catalogue or a spec's own. Each record
-- they hand out is read-only (CORE-R18, DATA-R80).
part(function(fake, Pagle, ns)
	local catalogue
	function fake.setCatalogue(data)
		catalogue = ns.NewCatalogue(data)
		Pagle.CONTENT_FINGERPRINT = catalogue.CONTENT_FINGERPRINT
	end
	for _, name in ipairs({ "GetItem", "GetZones", "GetArea", "GetZoneOf", "GetZoneCatches" }) do
		Pagle[name] = function(...)
			return readOnly(catalogue[name](...))
		end
	end
	function Pagle.GetWindowSpec(windowID)
		local spec, confirmed = catalogue.GetWindowSpec(windowID)
		return readOnly(spec), confirmed
	end
	fake.setCatalogue(ns.catalogue)
end)

-- The live conditions (LOG-R45, LOG-R47). Pagle.GetConditions hands out fake.conditions, read-only, with the
-- restriction flag; fake.setConditions replaces it and fires ConditionsChanged with the keys Core's real tracker
-- finds changed.
part(function(fake, Pagle, ns)
	-- Fishing The Long Wash (148/453) at realm 08:15 on Sunday 11 October 2026, Fishing 86+25 with lure 263 on, no
	-- listed event or aura (probe report 70338).
	fake.conditions = {
		time = 1791731700,
		minute = 495,
		date = { year = 2026, month = 10, day = 11, weekday = 1 },
		uiMap = 1439,
		instance = 1,
		zone = 148,
		subzone = 453,
		skillRank = 86,
		skillMod = 25,
		lure = 263,
		events = {},
		auras = {},
	}
	local tracker = ns.NewConditionsTracker()
	tracker:Update(fake.conditions)

	function Pagle.GetConditions()
		local conditions = {}
		for key, value in pairs(fake.conditions) do
			conditions[key] = value
		end
		conditions.restricted = Pagle.IsRestricted()
		return readOnly(conditions)
	end

	function fake.setConditions(snapshot)
		fake.conditions = snapshot
		local changed = tracker:Update(snapshot)
		if #changed > 0 then
			fake.fire("ConditionsChanged", changed)
		end
	end
end)

-- Fishing (LOG-R2–R9, LOG-R43), on Core's real Cast state machine: a spec plays a Cast's signals (or a whole Cast
-- with playCast) and the Module gets Core's events, each Cast recorded to fake.catchLog first, with fake.conditions
-- as its snapshot, at the fake's server time. The fake's clock starts at 0 (server time 1791731700) and moves only
-- with fake.wait, which runs the grace timers that come due.
part(function(fake, Pagle, ns)
	local FISHING = 7731 -- Fishing (Classic Journeyman), on the generated fishing-spell list
	local clock = 0
	local timers = {} -- { due, fn }, in the order they were set
	local spells = ns.NewCatalogue(ns.catalogue)
	local recorded -- the Cast record last appended

	local fishing = ns.NewFishing({
		isFishingSpell = function(spellID)
			return spellID ~= nil and spells.IsFishingSpell(spellID)
		end,
		record = function(outcome, items)
			local char = Pagle.GetAngler().current
			if not char then
				return nil
			end
			local conditions = {}
			for key, value in pairs(fake.conditions) do
				conditions[key] = value
			end
			conditions.time, conditions.date = 1791731700 + math.floor(clock), nil
			recorded = fake.catchLog:Append({
				kind = "cast",
				char = char,
				time = conditions.time,
				outcome = outcome,
				conditions = conditions,
				items = items,
			})
			return recorded
		end,
		fire = fake.fire,
	})

	function Pagle.GetFishingState()
		return fishing:GetState()
	end

	function fake.channel(spellID)
		fishing:ChannelStarted(spellID or FISHING, clock)
	end

	function fake.stopChannel(spellID)
		local graceEnded = fishing:ChannelStopped(spellID or FISHING, clock)
		if graceEnded then
			timers[#timers + 1] = { due = clock + ns.FISHING_GRACE, fn = graceEnded }
		end
	end

	function fake.loot(items, isFishing)
		if isFishing == nil then
			isFishing = true
		end
		fishing:LootReady(isFishing, function()
			return items or {}
		end, clock)
	end

	function fake.closeLoot()
		fishing:LootClosed(clock)
	end

	function fake.escape()
		fishing:Escaped(clock)
	end

	function fake.wait(seconds)
		local target = clock + seconds
		while true do
			local nextTimer, index
			for i, timer in ipairs(timers) do
				if timer.due <= target and (not nextTimer or timer.due < nextTimer.due) then
					nextTimer, index = timer, i
				end
			end
			if not nextTimer then
				break
			end
			table.remove(timers, index)
			clock = nextTimer.due
			nextTimer.fn()
		end
		clock = target
	end

	function fake.playCast(outcome, items)
		recorded = nil
		fake.channel()
		if outcome == "caught" then
			fake.loot(items)
			fake.stopChannel()
			fake.closeLoot()
		elseif outcome == "gotAway" then
			fake.escape()
			fake.stopChannel()
		else
			fake.stopChannel()
			fake.wait(ns.FISHING_GRACE)
		end
		return readOnly(recorded)
	end
end)

--- A fresh FakePagle: no Module registered, not restricted, before PLAYER_LOGIN.
---@return FakePagle
function newFakePagle()
	local ns, env = loadCoreLogic()
	-- Pagle.API_VERSION as adapter/Core.lua sets it; fake_pagle_spec.lua checks they agree.
	local Pagle = { API_VERSION = 1 }
	local fake = { Pagle = Pagle, ns = ns, printed = {}, readOnly = readOnly }

	-- The event bus (CORE-R20–R22): Core's own CallbackHandler registry, which every part fires on.
	local bus = env.LibStub("CallbackHandler-1.0")
		:New(Pagle, "RegisterCallback", "UnregisterCallback", "UnregisterAllCallbacks")
	function fake.fire(event, ...)
		local count = select("#", ...)
		local args = { ... }
		for i = 1, count do
			args[i] = readOnly(args[i])
		end
		bus:Fire(event, unpack(args, 1, count))
	end

	for _, build in ipairs(parts) do
		build(fake, Pagle, ns)
	end
	fake.globals = {
		Pagle = readOnly(Pagle),
		pairs = proxyPairs,
		ipairs = proxyIpairs,
		next = proxyNext,
		unpack = proxyUnpack,
	}
	function fake.load(name, options)
		local loadOptions = { dependencyLibsOnly = true }
		for key, value in pairs(options or {}) do
			loadOptions[key] = value
		end
		local loaded = loadAddon(name, fake.globals, loadOptions)
		-- WoW events the game raises on its own (UPDATE_BINDINGS) reach the Module through Pagle.RegisterEvent.
		loaded.client.fireGameEvent = fake.fireGameEvent
		return loaded
	end
	return fake
end
