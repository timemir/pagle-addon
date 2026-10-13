---@class PagleNS
local ns = select(2, ...)

-- The compartment menu as data (CORE-R50, CORE-R52). Pure logic, everything passed in (CORE-R7); adapter/Menu.lua
-- opens it as a native context menu.

--- One button on the compartment menu.
---@class PagleMenuEntry
---@field label string
---@field onClick fun()

--- The compartment menu's entries, read now, as each opening reads them (CORE-R50, CORE-R52): for each registered
--- Module by `def.order`, its views, then its `menu` entries; then `last` ("Settings"). The Curio Shop entry joins in
--- M2, "Help chart the waters" in M3. An entry whose label can't be read is left out.
---@param modules PagleModule[] by def.order, as `registry:Modules()` lists them
---@param last PagleMenuEntry
---@param call fun(fn: function): any calls a function label; returns nil when it fails (securecallfunction)
---@return PagleMenuEntry[]
function ns.CompartmentMenu(modules, last, call)
	local entries = {}
	local function add(label, onClick)
		local text = ns.ReadLabel(label, call)
		if text and type(onClick) == "function" then
			entries[#entries + 1] = { label = text, onClick = onClick }
		end
	end
	for _, module in ipairs(modules) do
		local def = module.def
		for _, view in ipairs(def.views or {}) do
			add(view.label, view.open)
		end
		for _, entry in ipairs(def.menu or {}) do
			add(entry.label, entry.onClick)
		end
	end
	entries[#entries + 1] = last
	return entries
end
