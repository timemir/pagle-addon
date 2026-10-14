---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Attaching a Module (CORE-R12–R19).

--- `ModulesChanged` has no payload: it fires once at PLAYER_LOGIN, when every enabled Module has registered or
--- failed to (CORE-R19). adapter/Login.lua fires it, after the character and the area index (LOG-R1).
---@alias PagleModulesChangedHandler fun(event: "ModulesChanged")

--- Core's one registry. Core's other files reach registered Modules through it: `ns.Modules:Modules()` by order,
--- `ns.Modules:ModuleCalling(self, method, args)` in a handle method.
ns.Modules = ns.NewModuleRegistry(Pagle.API_VERSION)

---@param addon string
---@return string?
local function readAPI(addon)
	return C_AddOns.GetAddOnMetadata(addon, "X-Pagle-API")
end

--- Registers a Module, once, from its AceAddon `OnInitialize` (CORE-R12). Returns its Module handle, the only way
--- to reach the calls that act for it. Returns nil, with one chat line, if its `X-Pagle-API` is missing, not a
--- number or newer than `Pagle.API_VERSION`: the Module is inert and must stop (CORE-R13). Raises an error, and
--- registers nothing, for a name not in the roster, a second registration, or a missing title or order (CORE-R14).
Pagle.RegisterModule = ns.ModuleRegistrar(ns.Modules, readAPI, print)

--- Each roster Module's state, in roster order (CORE-R41). Read when shown: enable state is read from the client
--- each time, never changed (CORE-R16).
---@return { name: string, state: PagleModuleState }[]
function ns.ModuleStates()
	local character = UnitGUID("player")
	local states = {}
	for i, name in ipairs(ns.MODULE_ROSTER) do
		local addon = ns.ModuleAddOn(name)
		local reason = select(5, C_AddOns.GetAddOnInfo(addon))
		states[i] = {
			name = name,
			state = ns.Modules:State(name, {
				installed = reason ~= "MISSING",
				enabled = C_AddOns.GetAddOnEnableState(addon, character) ~= Enum.AddOnEnableState.None,
				loaded = C_AddOns.IsAddOnLoaded(addon),
			}),
		}
	end
	return states
end
