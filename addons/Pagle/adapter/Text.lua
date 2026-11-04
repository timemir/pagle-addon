---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The text helper (CORE-R8, logic/Text.lua): named {fields}, CLDR plurals and number separators. Here Core gives it to
-- Modules as Pagle.Text.
ns.PublishText(Pagle)

-- The case helper (CORE-R8, logic/Case.lua): upper and lower case and a search fold for UTF-8 text. Here Core gives it to
-- Modules as Pagle.Upper, Pagle.Lower and Pagle.FoldCase.
ns.PublishCase(Pagle)

-- The Language (CORE-R8, SET-R10 row 9b, ADR 0019). Core applies it first in its ADDON_LOADED (adapter/Login.lua), before
-- the Size and Variety names are published and before anything prints; a Module applies Core's choice as its files load
-- (locale/Apply.lua).

--- The Language setting's key in the account-wide `PagleDB.global` (SET-R10 row 9b).
ns.LANGUAGE_KEY = "language"
--- The setting's value for "Game default", and what a missing, unreadable or wrongly typed setting counts as.
ns.LANGUAGE_GAME_DEFAULT = "default"
-- English is the base every Locale overlays (ADR 0019); it has no registration.
local ENGLISH = "enUS"
--- A client Locale that has no Locale of its own yet and is served by another, on "Game default" only: an esMX client
--- reads esES until a separate esMX registers (ADR 0019). A registered, listed esMX wins.
local SERVED_BY = { esMX = "esES" }

--- The Locale codes a Pagle Locale can be registered under (ADR 0019: always the full client code), in the order the
--- Language dropdown lists them (SET-R10 row 9b). enUS is built in and is the dropdown's own "English" choice.
---@type string[]
ns.LANGUAGE_CODES = { "deDE", "esES", "esMX", "frFR", "itIT", "koKR", "ptBR", "ruRU", "zhCN", "zhTW" }

--- The Locales in a script the bundled faces don't cover (CORE-R9: Cyrillic, Korean and Chinese draw with the client's
--- own fonts). Until the font probe (#522) shows which fonts a client carries, each is offered on its own client only.
---@type table<string, true>
local OWN_CLIENT_ONLY = { koKR = true, ruRU = true, zhCN = true, zhTW = true }

--- Whether the current client can render the Locale `code` (SET-R10 row 9b): a Latin-script Locale always, one of
--- OWN_CLIENT_ONLY only when `clientLocale` is its own code. The one place the font probe's result changes the
--- dropdown's offer (ADR 0019, Q25).
---@param code string
---@param clientLocale any The client's `GetLocale()`.
---@return boolean
function ns.CanRenderLanguage(code, clientLocale)
	return not OWN_CLIENT_ONLY[code] or code == clientLocale
end

--- What the Language dropdown offers on a client of `clientLocale`, in its order (SET-R10 row 9b): "Game default",
--- English, then each registered Locale that is listed and that the client can render, by its own name. Always the first
--- two, with no Locale registered.
---@param clientLocale any The client's `GetLocale()`.
---@return { value: string, label: string }[]
function ns.LanguageChoices(clientLocale)
	local L = ns.L
	local choices = {
		{ value = ns.LANGUAGE_GAME_DEFAULT, label = L.SETTINGS_LANGUAGE_GAME_DEFAULT },
		{ value = ENGLISH, label = L.SETTINGS_LANGUAGE_ENGLISH },
	}
	for _, code in ipairs(ns.LANGUAGE_CODES) do
		local info = ns.LocaleInfo(code)
		if info and info.listed and ns.CanRenderLanguage(code, clientLocale) then
			choices[#choices + 1] = { value = code, label = info.name }
		end
	end
	return choices
end

--- The Settings root's Translations line (SET-R10 row 13, ADR 0019, Credits): the translators of each registered, listed
--- Locale that the client can render (ns.CanRenderLanguage), one entry for each, by the Locale's own name, in the order
--- of ns.LANGUAGE_CODES; nil when no such Locale has translators. A Locale the client cannot render is left out whole,
--- as its name and its translators' names would draw as boxes (CORE-R9).
---@param clientLocale any The client's `GetLocale()`.
---@return string?
function ns.TranslatorCredits(clientLocale)
	local L = ns.L
	local entries = {}
	for _, code in ipairs(ns.LANGUAGE_CODES) do
		local info = ns.LocaleInfo(code)
		if info and info.listed and info.translators and ns.CanRenderLanguage(code, clientLocale) then
			entries[#entries + 1] = ns.RenderText(
				L.SETTINGS_TRANSLATIONS_ENTRY,
				{ language = info.name, names = table.concat(info.translators, L.SETTINGS_TRANSLATIONS_NAMES_JOIN) }
			)
		end
	end
	if #entries == 0 then
		return nil
	end
	return ns.RenderText(L.SETTINGS_TRANSLATIONS, { credits = table.concat(entries, L.SETTINGS_TRANSLATIONS_JOIN) })
end

--- The Language setting out of the raw `_G.PagleDB`, before AceDB wraps it: `PagleDB.global.language`. Anything that is
--- not a non-empty string there, however it came to be (no `PagleDB`, not a table, no `global`, a number), is
--- "Game default" (LANGUAGE_GAME_DEFAULT). It never raises.
---@param saved any The raw PagleDB the client loaded, or nil on a first login.
---@return string
function ns.ReadLanguageSetting(saved)
	local ok, value = pcall(function()
		return rawget(rawget(saved, "global"), ns.LANGUAGE_KEY)
	end)
	if ok and type(value) == "string" and value ~= "" then
		return value
	end
	return ns.LANGUAGE_GAME_DEFAULT
end

--- Whether `code` is a registered Locale that is listed.
---@param code any
---@return boolean
local function listed(code)
	local info = ns.LocaleInfo(code)
	return info ~= nil and info.listed
end

--- The Locale to apply, as its code: "enUS" for English. A setting that names a Locale gives it when it is registered,
--- listed and renderable on this client (ns.CanRenderLanguage), else English. "Game default" gives the client's own Locale when that is registered and listed, else the one
--- that serves it (esMX: esES), else English. An unlisted Locale never applies by either road.
---@param setting string The Language setting (ReadLanguageSetting).
---@param clientLocale any The client's `GetLocale()`.
---@return string code
function ns.ResolveLanguage(setting, clientLocale)
	if setting ~= ns.LANGUAGE_GAME_DEFAULT then
		return listed(setting) and ns.CanRenderLanguage(setting, clientLocale) and setting or ENGLISH
	end
	if listed(clientLocale) then
		return clientLocale
	end
	local served = SERVED_BY[clientLocale]
	if served and listed(served) then
		return served
	end
	return ENGLISH
end

--- The Locale applied this session, as its code: "enUS" until `ApplyLanguage` has run, and when the Locale it chose
--- applied nothing.
---@type string
ns.language = ENGLISH

--- Core's first step at ADDON_LOADED (CORE-R8, LOG-R1): reads the setting from the raw `_G.PagleDB`, resolves it, overlays
--- `ns.L` with the chosen Locale (its fallback first), hands the text helper the merged record, records the code
--- `Pagle.GetLanguage` answers with and sets Core's font objects again in that language's faces (CORE-R9). A function of
--- the Locale that raises is reported through the error handler and skipped: the strings it would have written stay
--- English, and login goes on.
function ns.ApplyLanguage()
	local saved = rawget(_G, "PagleDB")
	-- The development pseudo-locale (#524, adapter/DevPseudo.lua) stands in for the Language while it is on: it pads the
	-- English, so the Language setting is not read and Pagle.GetLanguage stays "enUS".
	ns.pseudo = ns.ReadPseudoSetting(saved)
	local code = ENGLISH
	if not ns.pseudo then
		code = ns.ResolveLanguage(ns.ReadLanguageSetting(saved), GetLocale())
	end
	local record, errors = ns.ApplyLocale(code)
	for _, err in ipairs(errors) do
		geterrorhandler()(err)
	end
	---@cast record PagleTextLocale?
	ns.SetTextLocale(record)
	ns.language = record and code or ENGLISH
	if ns.pseudo then
		ns.PseudoLocalize(ns.L)
	end
	-- Core's font objects were made as its files loaded, in the bundled faces (adapter/Fonts.lua).
	ns.faces:Refit()
end

--- The Locale Core applied this session, as its code ("enUS" for English): what a Module applies from its own
--- registrations as its files load (CORE-R8, locale/Apply.lua). Right once Core's ADDON_LOADED has run, which every
--- Module's files follow (CORE-R10). Added in API version 2.
---@return string
function Pagle.GetLanguage()
	return ns.language
end
