if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Locale registration (DATA-R114, ADR 0019): the first stable entry of locale/Locales.xml, ahead of the generated locale
-- files that call it. The same file in all six addons (a Module's behind the CORE-R11 guard, spec/locale_registry_spec.lua), because each
-- addon has its own `ns` and its own `ns.L`. It is plain Lua 5.1, reads no WoW global and no `ns.L` while it loads, and
-- registering only records: nothing is written into `ns.L` until `ns.ApplyLocale` runs, once per session.

local ENGLISH = "enUS"

--- The registered Locales by code, for this addon.
---@type table<string, { name: string?, listed: boolean?, translators: string[]?, fallback: string?, plural: (fun(n: number): string)?, decimal: string?, thousands: string?, whole: boolean, functions: (fun(L: table))[] }>
local entries = {}

--- Whether `value` is a string with something in it.
---@param value any
---@return boolean
local function text(value)
	return type(value) == "string" and value ~= ""
end

--- Checks the `opts` of a first registration; raises, naming the field, and records nothing.
---@param code string
---@param opts table
local function checkOptions(code, opts)
	if type(opts) ~= "table" then
		error("Locale " .. code .. ": opts is a table", 3)
	end
	if not text(opts.name) then
		error("Locale " .. code .. ": name is the language's own name, a non-empty string", 3)
	end
	if type(opts.listed) ~= "boolean" then
		error("Locale " .. code .. ": listed is true or false", 3)
	end
	if opts.translators ~= nil then
		if type(opts.translators) ~= "table" then
			error("Locale " .. code .. ": translators is an array of names", 3)
		end
		for _, translator in ipairs(opts.translators) do
			if not text(translator) then
				error("Locale " .. code .. ": translators is an array of names", 3)
			end
		end
	end
	local fallback = opts.fallback
	if fallback ~= nil and (not text(fallback) or fallback == code or fallback == ENGLISH) then
		error("Locale " .. code .. ": fallback is another Locale's code, never its own or enUS", 3)
	end
	if opts.plural ~= nil and type(opts.plural) ~= "function" then
		error("Locale " .. code .. ": plural is a function", 3)
	end
	if opts.decimal ~= nil and not text(opts.decimal) then
		error("Locale " .. code .. ": decimal is a non-empty string", 3)
	end
	if opts.thousands ~= nil and type(opts.thousands) ~= "string" then
		error("Locale " .. code .. ": thousands is a string", 3)
	end
	if fallback == nil and (opts.plural == nil or opts.decimal == nil or opts.thousands == nil) then
		error("Locale " .. code .. ": with no fallback, plural, decimal and thousands are all given", 3)
	end
end

--- Registers a Locale's text for this addon (DATA-R114). `fn(L)` writes the translated strings into `L`, which is
--- `ns.L` itself, and runs only if this Locale is chosen. A code is first registered with its `opts`; any later call
--- for the same code adds another function and takes no `opts`. A bad call raises and registers nothing.
---@param code string The full client code, "esES"; never "enUS", which is built in.
---@param fn fun(L: table) Writes this Locale's strings into `L`.
---@param opts { name: string, listed: boolean, translators: string[]?, fallback: string?, plural: (fun(n: number): string)?, decimal: string?, thousands: string? }? Required on the first call per code, refused after.
function ns.Locale(code, fn, opts)
	if not text(code) then
		error("Locale: the code is a non-empty string", 2)
	end
	if code == ENGLISH then
		error("Locale: enUS is built in and is not registered", 2)
	end
	if type(fn) ~= "function" then
		error("Locale " .. code .. ": the second argument is a function", 2)
	end
	local entry = entries[code]
	if opts ~= nil then
		if entry and entry.whole then
			error("Locale " .. code .. ": opts are given once, by the first call that has them", 2)
		end
		checkOptions(code, opts)
	end
	if not entry then
		entry = { whole = false, functions = {} }
		entries[code] = entry
	end
	entry.functions[#entry.functions + 1] = fn
	if opts ~= nil then
		entry.whole = true
		entry.name, entry.listed, entry.fallback = opts.name, opts.listed, opts.fallback
		entry.translators = opts.translators
		entry.plural, entry.decimal, entry.thousands = opts.plural, opts.decimal, opts.thousands
	end
end

--- What is registered under `code`, or nil when nothing is, or when only Lore was (no `opts` yet): a fresh table of
--- `{ code, name, listed, translators, fallback }`, with `translators` (a copy of the names, GitHub names) left out when
--- the header gave none. enUS is never registered.
---@param code any
---@return { code: string, name: string, listed: boolean, translators: string[]?, fallback: string? }?
function ns.LocaleInfo(code)
	local entry = type(code) == "string" and entries[code] or nil
	if not entry or not entry.whole then
		return nil
	end
	local translators
	if entry.translators and #entry.translators > 0 then
		translators = {}
		for index, translator in ipairs(entry.translators) do
			translators[index] = translator
		end
	end
	return {
		code = code,
		name = entry.name,
		listed = entry.listed,
		translators = translators,
		fallback = entry.fallback,
	}
end

local applied = false
---@type { plural: fun(n: number): string, decimal: string, thousands: string }?
local appliedRecord
---@type string[]
local appliedErrors = {}

--- Applies `code`'s Locale to `ns.L`, in place, once per session (the first call decides; a later one changes nothing and
--- answers as the first did). The Locale's fallback chain runs first, the root of it before the Locale itself (esES
--- before esMX); inside one Locale its functions run in registration order. A key a Locale lacks keeps what was there,
--- English. Whether the Locale is listed is for the caller to have checked (Core's ns.ResolveLanguage): this applies
--- what it is given, a fallback regardless of its own `listed`. A code that is not registered, a chain that loops, or one
--- that never gives a plural rule and both separators, applies nothing. A function that raises is skipped and its
--- message returned.
---@param code any
---@return { plural: fun(n: number): string, decimal: string, thousands: string }? record The chain's merged plural rule and separators, the Locale's over its fallback's; nil when nothing was applied.
---@return string[] errors One message for each function that raised.
function ns.ApplyLocale(code)
	if applied then
		return appliedRecord, appliedErrors
	end
	local L = ns.L
	if type(L) ~= "table" then
		return nil, {}
	end
	-- The chain, root first.
	local chain, seen, at = {}, {}, code
	while text(at) and entries[at] and entries[at].whole do
		if seen[at] then
			return nil, {}
		end
		seen[at] = true
		table.insert(chain, 1, entries[at])
		at = entries[at].fallback
	end
	if #chain == 0 then
		return nil, {}
	end
	---@type table
	local record = {}
	for _, entry in ipairs(chain) do
		record.plural = entry.plural or record.plural
		record.decimal = entry.decimal or record.decimal
		record.thousands = entry.thousands or record.thousands
	end
	if not (record.plural and record.decimal and record.thousands) then
		return nil, {}
	end
	applied, appliedRecord = true, record
	for _, entry in ipairs(chain) do
		for _, fn in ipairs(entry.functions) do
			local ok, err = pcall(fn, L)
			if not ok then
				appliedErrors[#appliedErrors + 1] = tostring(err)
			end
		end
	end
	return appliedRecord, appliedErrors
end
