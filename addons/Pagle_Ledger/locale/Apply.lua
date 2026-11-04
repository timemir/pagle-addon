if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The last stable entry of locale/Locales.xml (ADR 0019): a Module applies the Language Core has already chosen. Core's
-- files run, and its ADDON_LOADED with them, before any Module's files (CORE-R10), so by now `Pagle.GetLanguage` says
-- which Locale. The same file in all six addons (a Module's behind the CORE-R11 guard, spec/locale_registry_spec.lua). In Core's own copy
-- `Pagle` does not exist yet while its files load, and this does nothing: Core applies the Language in its
-- ADDON_LOADED (adapter/Login.lua), where it can read PagleDB. Off Forever there is no Pagle, and nothing happens.
local core = rawget(_G, "Pagle")
if type(core) == "table" and type(core.GetLanguage) == "function" then
	ns.ApplyLocale(core.GetLanguage())
	-- The development pseudo-locale (#524) pads the English this addon has, when Core has it on this session.
	if type(core.ApplyPseudoLocale) == "function" then
		core.ApplyPseudoLocale(ns.L)
	end
end
