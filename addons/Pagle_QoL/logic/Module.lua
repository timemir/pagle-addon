if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- What QoL registers with Core (QOL-R2): pure logic, everything passed in (CORE-R7).

--- QoL's def for `Pagle.RegisterModule` (QOL-R2), with Input's compartment entry (QOL-R16) and `/pagle qol`
--- (QOL-R17).
---@param openSettings fun(topic: string) opens a Settings topic page, as `Pagle.OpenSettings` does
---@param print fun(text: string) prints a line to chat, for `/pagle qol`
---@param store PagleQoLStore where the compartment entry and `/pagle qol` read and set Input
---@return PagleModuleDef
function ns.ModuleDef(openSettings, print, store)
	return {
		name = "QoL",
		title = ns.L.TITLE,
		order = 50,
		-- QoL's line on the Field guide's What's in the box step (ONB-R91).
		guideBlurb = ns.L.GUIDE_BLURB,
		settingsAction = {
			label = ns.L.SETTINGS_ACTION,
			onClick = function()
				openSettings("fishing")
			end,
		},
		-- A function label, read each time the menu opens (CORE-R52).
		menu = {
			{
				label = function()
					return ns.InputMenuLabel(store.input())
				end,
				onClick = function()
					store.setInput(ns.NextInput(store.input()))
				end,
			},
		},
		-- Core's help line puts "/pagle qol: " before the help text (CORE-R60), so it doesn't name qol again.
		slash = {
			{
				name = "qol",
				fn = function(line)
					ns.QoLSlash(line, { setInput = store.setInput, openSettings = openSettings, print = print })
				end,
				help = ns.L.SLASH_HELP,
			},
		},
	}
end
