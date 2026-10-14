---@class PagleNS
local ns = select(2, ...)

-- The roster and the Module registry (CORE-R1, CORE-R12–R14, CORE-R41): pure logic, everything passed in (CORE-R7).

--- The roster (CORE-R1): every Module the package ships, by `def.name`, in CORE-R1 order. Each one's addon folder
--- is `ns.ModuleAddOn(name)`.
ns.MODULE_ROSTER = { "Ledger", "Hunts", "Stats", "TackleBoard", "QoL" }

--- What a Module passes to `Pagle.RegisterModule` (core/README.md › Contracts).
---@class PagleModuleDef
---@field name string            -- roster name without "Pagle_": "Ledger", "Hunts", "Stats", "TackleBoard", "QoL"
---@field title string           -- display name: "Ledger", "Hunts", "Stats", "Tackle Board", "QoL"
---@field order integer          -- menu order: Ledger 10, Hunts 20, Stats 30, TackleBoard 40, QoL 50
---@field settingsAction? { label: string|(fun():string), onClick: fun() }   -- its button in the Settings status list (CORE-R44)
---@field views? { id: string, label: string|(fun():string), open: fun() }[]   -- compartment menu views
---@field menu? { label: string|(fun():string), onClick: fun() }[]             -- extra compartment entries
---@field slash? { name: string, fn: fun(args: string), help: string }[]     -- /pagle <name>

--- A roster entry's state, as the Settings status list shows it (CORE-R41).
---@alias PagleModuleState
---| "on"              # On: enabled and registered
---| "needsNewerPagle" # Needs a newer Pagle: inert, its X-Pagle-API missing, not a number or too new (CORE-R13)
---| "failedToStart"   # Failed to start: enabled, loaded, but never registered (it errored)
---| "off"             # Off: disabled in the AddOns list
---| "notInstalled"    # Not installed: the client reports it missing

--- What the client reports about a roster Module's addon (CORE-R16, CORE-R41).
---@class PagleModuleAddOn
---@field installed boolean
---@field enabled boolean   -- for the player's character, in this session's AddOns list
---@field loaded boolean

--- The handle `Pagle.RegisterModule` returns: the only way to reach the calls that act for one Module (CORE-R12).
--- Its methods live on this table; each Core ticket adds its own (`M:AddSetting`, `M:AppendRecord`, …) and finds
--- the Module with `registry:ModuleCalling(self, method, args)`.
---@class PagleModuleHandle
ns.ModuleHandle = {}
ns.ModuleHandle.__index = ns.ModuleHandle

--- A registered Module.
---@class PagleModule
---@field def PagleModuleDef
---@field handle PagleModuleHandle

--- Which roster Modules registered, and which went inert.
---@class PagleModuleRegistry
---@field private apiVersion integer
---@field private known table<string, true>    roster names
---@field private modules table<string, PagleModule>    registered, by name
---@field private inert table<string, true>    names whose RegisterModule found an incompatible API
---@field private byHandle table<PagleModuleHandle, PagleModule>
local Registry = {}
Registry.__index = Registry

--- The addon folder of a roster Module: "Pagle_QoL" for "QoL".
---@param name string
---@return string
function ns.ModuleAddOn(name)
	return "Pagle_" .. name
end

--- A label from a Module's def (its views, `menu` entries and `settingsAction`) as Core shows it: a function label
--- is called now, through `call`, so each showing reads it afresh (CORE-R44, CORE-R52). Nil when it fails or isn't
--- text, so the one entry or button is left out and nothing else breaks.
---@param label any
---@param call fun(fn: function): any calls a function label; returns nil when it fails (securecallfunction)
---@return string?
function ns.ReadLabel(label, call)
	if type(label) == "function" then
		label = call(label)
	end
	if type(label) == "string" then
		return label
	end
	return nil
end

--- An empty registry for Core's `Pagle.API_VERSION`.
---@param apiVersion integer
---@return PagleModuleRegistry
function ns.NewModuleRegistry(apiVersion)
	local known = {}
	for _, name in ipairs(ns.MODULE_ROSTER) do
		known[name] = true
	end
	return setmetatable({ apiVersion = apiVersion, known = known, modules = {}, inert = {}, byHandle = {} }, Registry)
end

--- Whether a Module's `X-Pagle-API` lets it run with this Core: present, a number, and no greater than
--- `apiVersion` (CORE-R13).
---@param value string? the TOC field, as `C_AddOns.GetAddOnMetadata` returns it
---@param apiVersion integer
---@return boolean
function ns.IsModuleAPICompatible(value, apiVersion)
	local api = tonumber(value)
	return api ~= nil and api <= apiVersion
end

-- Why a def can't register, or nil if it can (CORE-R14).
---@private
---@param def any
---@return string?
function Registry:Problem(def)
	if type(def) ~= "table" then
		return "Pagle.RegisterModule takes a def table, got " .. type(def)
	end
	local name = def.name
	if type(name) ~= "string" or not self.known[name] then
		return ("Pagle.RegisterModule: %s is not a Pagle Module; the roster is %s"):format(
			tostring(name),
			table.concat(ns.MODULE_ROSTER, ", ")
		)
	end
	if self.modules[name] or self.inert[name] then
		return ("Pagle.RegisterModule: %s is already registered"):format(name)
	end
	if type(def.title) ~= "string" or def.title == "" then
		return ("Pagle.RegisterModule: %s's def has no title"):format(name)
	end
	if type(def.order) ~= "number" then
		return ("Pagle.RegisterModule: %s's def has no order"):format(name)
	end
	return nil
end

--- Registers a Module (CORE-R12). Returns its handle; or nil if its `X-Pagle-API` is incompatible, leaving it
--- inert (CORE-R13); or nil and why, registering nothing, for a def CORE-R14 refuses. The caller raises that.
---@param def PagleModuleDef
---@param readAPI fun(addon: string): string? reads an addon's `X-Pagle-API`; called only for a roster Module
---@return PagleModuleHandle? handle
---@return string? problem
function Registry:Register(def, readAPI)
	local why = self:Problem(def)
	if why then
		return nil, why
	end
	if not ns.IsModuleAPICompatible(readAPI(ns.ModuleAddOn(def.name)), self.apiVersion) then
		self.inert[def.name] = true
		return nil
	end
	local handle = setmetatable({}, ns.ModuleHandle)
	local module = { def = def, handle = handle }
	self.modules[def.name] = module
	self.byHandle[handle] = module
	return handle
end

--- The Module a handle belongs to, or nil for anything that isn't a handle this registry gave out.
---@param handle any
---@return PagleModule?
function Registry:ModuleOf(handle)
	return self.byHandle[handle]
end

--- The Module a handle method was called on (CORE-R12): `handle`'s Module, or an error at the Module's call, for
--- anything that isn't a handle this registry gave out, saying how to call `method` (`M:<method>(<args>)`). For a
--- handle method to call first thing, so the error is the caller's.
---@param handle any the method's self
---@param method string "RaiseMoment"
---@param args string "moment"
---@return PagleModule
function Registry:ModuleCalling(handle, method, args)
	local module = self.byHandle[handle]
	if not module then
		error(("%s is a Module handle method: call M:%s(%s)"):format(method, method, args), 3)
	end
	return module
end

--- Whether a Module sorts before another, wherever Modules are listed: by def.order, ties by def.name.
---@param orderA integer
---@param nameA string
---@param orderB integer
---@param nameB string
---@return boolean
function ns.ModuleSortsBefore(orderA, nameA, orderB, nameB)
	if orderA ~= orderB then
		return orderA < orderB
	end
	return nameA < nameB
end

--- The registered Modules, by `def.order`, ties by name.
---@return PagleModule[]
function Registry:Modules()
	local list = {}
	for _, module in pairs(self.modules) do
		list[#list + 1] = module
	end
	table.sort(list, function(a, b)
		return ns.ModuleSortsBefore(a.def.order, a.def.name, b.def.order, b.def.name)
	end)
	return list
end

--- A roster Module's state (CORE-R41), from what the client reports about its addon.
---@param name string a roster name
---@param addon PagleModuleAddOn
---@return PagleModuleState
function Registry:State(name, addon)
	if not addon.installed then
		return "notInstalled"
	elseif self.modules[name] then
		return "on"
	elseif self.inert[name] then
		return "needsNewerPagle"
	elseif addon.enabled and addon.loaded then
		return "failedToStart"
	end
	-- Disabled, or enabled in the AddOns list after this session loaded without it: either way it isn't running.
	return "off"
end

--- `Pagle.RegisterModule` over `registry` (CORE-R12–R14), so Core's adapter and FakePagle publish one function:
--- the def's handle; nil, with MODULE_NEEDS_NEWER_PAGLE's line, for an incompatible `X-Pagle-API`; an error at the
--- Module's call, registering nothing, for a def CORE-R14 refuses.
---@param registry PagleModuleRegistry
---@param readAPI fun(addon: string): string? reads an addon's `X-Pagle-API`
---@param print fun(line: string) prints a chat line
---@return fun(def: PagleModuleDef): PagleModuleHandle?
function ns.ModuleRegistrar(registry, readAPI, print)
	return function(def)
		local handle, problem = registry:Register(def, readAPI)
		if problem then
			error(problem, 2)
		end
		if not handle then
			print(ns.L.MODULE_NEEDS_NEWER_PAGLE:format(def.title))
		end
		return handle
	end
end
