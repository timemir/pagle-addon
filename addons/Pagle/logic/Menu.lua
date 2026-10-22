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

--- The tooltip of Pagle's menu, the same on the minimap icon and the compartment entry (CORE-R55): "Pagle", then
--- each line that applies, in order: "3 waiting" while Cozy mode holds moments for a summary (CORE-R51, ANN-R42),
--- and "A letter for you" while the Letter shows (ONB-R13).
---@param waiting integer
---@param letterShows boolean
---@return string[]
function ns.MenuTooltipLines(waiting, letterShows)
	local lines = { ns.L.MENU_NAME }
	if waiting > 0 then
		lines[#lines + 1] = ns.L.MENU_TOOLTIP_WAITING:format(waiting)
	end
	if letterShows then
		lines[#lines + 1] = ns.L.MENU_TOOLTIP_LETTER
	end
	return lines
end

--- One button on the compartment menu.
---@class PagleMenuEntry
---@field label string
---@field onClick fun()

--- The menu's last entry, "Settings" (CORE-R50): it calls `openSettings`, which while restricted prints CORE-R33's
--- line instead (SET-R75).
---@param openSettings fun()
---@return PagleMenuEntry
function ns.SettingsMenuEntry(openSettings)
	return { label = ns.L.MENU_SETTINGS, onClick = openSettings }
end

--- The menu's Curio Shop entry (CORE-R50): "Curio Shop", the balance as `breakUpLargeNumbers` writes it (0 while
--- held, SHOP-R12), then a coin icon. `open` is Pagle.OpenShop, which prints SHOP-R41's line while restricted
--- (CORE-R33).
---@param balance Balance
---@param breakUpLargeNumbers fun(value: number): string the client's BreakUpLargeNumbers
---@param open fun()
---@return PagleMenuEntry
function ns.CurioShopMenuEntry(balance, breakUpLargeNumbers, open)
	return { label = ns.L.MENU_CURIO_SHOP:format(breakUpLargeNumbers(balance.balance)), onClick = open }
end

--- The compartment menu's entries, read now, as each opening reads them (CORE-R50, CORE-R52): for each registered
--- Module by `def.order`, its views, then its `menu` entries; then `shop` (the Curio Shop), `fieldReport` ("Help
--- chart the waters") and `last` ("Settings"). An entry whose label can't be read is left out.
---@param modules PagleModule[] by def.order, as `registry:Modules()` lists them
---@param shop PagleMenuEntry
---@param fieldReport PagleMenuEntry
---@param last PagleMenuEntry
---@param call fun(fn: function): any calls a function label; returns nil when it fails (securecallfunction)
---@return PagleMenuEntry[]
function ns.CompartmentMenu(modules, shop, fieldReport, last, call)
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
	entries[#entries + 1] = fieldReport
	entries[#entries + 1] = last
	return entries
end

--- The compartment menu as Core opens it (CORE-R50, CORE-R52), read now: the Modules' entries, then the Curio Shop
--- (Pagle.OpenShop, with Pagle.GetBalance()), "Help chart the waters" (Core's report subcommand, with
--- Pagle.GetFieldReportCount()) and "Settings" (Core's settings subcommand). Each of these prints its CORE-R33 line
--- instead while restricted. One function for Core's adapter and FakePagle.
---@param Pagle Pagle
---@param core PagleCoreSubcommands
---@param modules PagleModule[] by def.order, as `registry:Modules()` lists them
---@param breakUpLargeNumbers fun(value: number): string the client's BreakUpLargeNumbers
---@param call fun(fn: function): any calls a function label; returns nil when it fails (securecallfunction)
---@return PagleMenuEntry[]
function ns.CoreCompartmentMenu(Pagle, core, modules, breakUpLargeNumbers, call)
	local shop = ns.CurioShopMenuEntry(Pagle.GetBalance(), breakUpLargeNumbers, function()
		Pagle.OpenShop()
	end)
	local fieldReport = ns.FieldReportMenuEntry(Pagle.GetFieldReportCount(), core.report)
	return ns.CompartmentMenu(modules, shop, fieldReport, ns.SettingsMenuEntry(core.settings), call)
end
