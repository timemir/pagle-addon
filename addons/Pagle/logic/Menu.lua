---@class PagleNS
local ns = select(2, ...)

-- The compartment menu as data (CORE-R50, CORE-R52). Pure logic, everything passed in (CORE-R7); adapter/Menu.lua
-- opens it as a native context menu.

--- The compartment entry's label (CORE-R51): "Pagle", or with moments Cozy mode holds for a summary,
--- "Pagle · 3 waiting" (ANN-R42).
---@param waiting integer
---@return string
function ns.CompartmentText(waiting)
	if waiting > 0 then
		return ns.L.COMPARTMENT_WAITING:format(waiting)
	end
	return ns.L.COMPARTMENT
end

--- One button on the compartment menu.
---@class PagleMenuEntry
---@field label string
---@field onClick fun()
---@field disabled? boolean   shown greyed, and clicking it does nothing

--- The menu's last entry, "Settings" (CORE-R50): it calls `openSettings`, which while restricted prints CORE-R33's
--- line instead (SET-R75).
---@param openSettings fun()
---@return PagleMenuEntry
function ns.SettingsMenuEntry(openSettings)
	return { label = ns.L.MENU_SETTINGS, onClick = openSettings }
end

--- The menu's Curio Shop entry (CORE-R50): "Curio Shop", the balance as `breakUpLargeNumbers` writes it (0 while
--- held, SHOP-R12), then a coin icon. Disabled until the Curio Shop exists (M4).
---@param balance Balance
---@param breakUpLargeNumbers fun(value: number): string the client's BreakUpLargeNumbers
---@return PagleMenuEntry
function ns.CurioShopMenuEntry(balance, breakUpLargeNumbers)
	return {
		label = ns.L.MENU_CURIO_SHOP:format(breakUpLargeNumbers(balance.balance)),
		onClick = function() end,
		disabled = true,
	}
end

--- The compartment menu's entries, read now, as each opening reads them (CORE-R50, CORE-R52): for each registered
--- Module by `def.order`, its views, then its `menu` entries; then `shop` (the Curio Shop), `report` ("Help chart the
--- waters") and `last` ("Settings"). An entry whose label can't be read is left out.
---@param modules PagleModule[] by def.order, as `registry:Modules()` lists them
---@param shop PagleMenuEntry
---@param report PagleMenuEntry
---@param last PagleMenuEntry
---@param call fun(fn: function): any calls a function label; returns nil when it fails (securecallfunction)
---@return PagleMenuEntry[]
function ns.CompartmentMenu(modules, shop, report, last, call)
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
	entries[#entries + 1] = shop
	entries[#entries + 1] = report
	entries[#entries + 1] = last
	return entries
end
