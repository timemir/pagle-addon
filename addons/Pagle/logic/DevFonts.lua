---@class PagleNS
local ns = select(2, ...)

-- `/pagle dev fonts` (#522, CORE-R9): finds out which client font files exist and which characters each draws, so the
-- per-locale font table (logic/Fonts.lua) rests on evidence rather than on remembered Blizzard filenames. It tries
-- SetFont on each known client font path, measures a sample of each script in every font that loads, saves the facts in
-- PagleDB.global.fontProbe and draws one sample row per loaded font so the dev can see boxes. Run on a client of each
-- language (#523); scripts/read-wtf.lua's Fonts section reads the result and judges it with ns.FontProbeReport below.
-- Pure logic over what it's handed (CORE-R7): the client's SetFont and GetStringWidth are the adapter's `meter`
-- (adapter/DevFonts.lua), and the globals come through the table it hands. It changes no game state.

--- The client font files the probe tries, the standard Blizzard filenames of the Latin, Cyrillic, Korean and Chinese
--- clients, in the order they are tried and shown. One table, so it is easy to extend; a path the font table
--- (ns.CLIENT_FONTS) names must be here.
---@type string[]
ns.DEV_CLIENT_FONT_PATHS = {
	"Fonts\\FRIZQT__.TTF",
	"Fonts\\FRIZQT___CYR.TTF",
	"Fonts\\ARIALN.TTF",
	"Fonts\\skurri.ttf",
	"Fonts\\MORPHEUS.TTF",
	"Fonts\\ARKai_T.ttf",
	"Fonts\\ARKai_C.ttf",
	"Fonts\\ARHei.ttf",
	"Fonts\\bHEI00M.ttf",
	"Fonts\\bHEI01B.ttf",
	"Fonts\\bKAI00M.ttf",
	"Fonts\\bLEI00D.ttf",
	"Fonts\\2002.ttf",
	"Fonts\\2002B.ttf",
	"Fonts\\K_Damage.TTF",
	"Fonts\\K_Pagetext.TTF",
}

--- The client's font globals, whose values the probe saves (and tries too, when they name a path the list lacks): what
--- the client itself draws its text, unit names and damage numbers with.
ns.DEV_FONT_GLOBALS = { "STANDARD_TEXT_FONT", "UNIT_NAME_FONT", "DAMAGE_TEXT_FONT" }

--- The size the probe sets each font at, and measures at.
ns.DEV_FONT_SIZE = 16

--- What the probe measures, by script, as code points (so no string literal holds one, spec/glyphs_spec.lua): two
--- Latin letters, two Cyrillic, two Hangul syllables and four Han characters (the fish and to fish, simplified then
--- traditional). The probe's rows draw them all in each font.
---@type { script: string, points: integer[] }[]
ns.DEV_FONT_SAMPLES = {
	{ script = "latin", points = { 0x0057, 0x00E9 } },
	{ script = "cyrillic", points = { 0x0416, 0x0449 } },
	{ script = "hangul", points = { 0xD55C, 0xAE00 } },
	{ script = "hanzi", points = { 0x9C7C, 0x9493, 0x9B5A, 0x91E3 } },
}

--- A character no client font has (U+E000, a private use code point). A font that lacks a character draws a box of its
--- own, so the probe measures this one as the box's width to tell a drawn character from a missing one.
ns.DEV_FONT_BOX_POINT = 0xE000

--- Measures a text in the font the meter last loaded: its `GetStringWidth`.
---@alias PagleFontMeasure fun(text: string): number

--- Tries SetFont on a font file: nil if the client won't load it, else the measure of a text in it.
---@alias PagleFontMeter fun(path: string): PagleFontMeasure?

--- What the probe is handed.
---@class PagleFontProbeOptions
---@field globals fun(): table         -- the client's globals (_G), where the font globals, GetLocale and GetBuildInfo are looked up
---@field global fun(): table          -- PagleDB.global, which keeps the probe
---@field meter fun(): PagleFontMeter -- a fresh meter over the client's SetFont and GetStringWidth (adapter/DevFonts.lua)
---@field serverTime fun(): number
---@field language fun(): string       -- the Pagle language applied this session, as its Locale code
---@field show fun(fonts: PagleDevGlyphFont[], probe: string) -- draws the rows
---@field print fun(line: string)      -- prints a chat line

--- One sample of a script, as UTF-8.
---@param points integer[]
---@return string
local function sample(points)
	local chars = {}
	for i, point in ipairs(points) do
		chars[i] = ns.DevUtf8(point)
	end
	return table.concat(chars)
end

--- The sample line of every script, drawn in a font that loads.
---@return string
function ns.DevFontProbeLine()
	local parts = {}
	for i, entry in ipairs(ns.DEV_FONT_SAMPLES) do
		parts[i] = sample(entry.points)
	end
	return table.concat(parts, "  ")
end

-- A value as saved: a string as it is, anything else as nothing.
---@param value any
---@return string?
local function savedPath(value)
	return type(value) == "string" and value or nil
end

--- The paths to try, in order: ns.DEV_CLIENT_FONT_PATHS, then each font global's value that the list lacks (compared
--- without regard to case, as the client does).
---@param globals table
---@return string[] paths
---@return table<string, string> fontGlobals the font globals' values as the client has them
local function pathsToTry(globals)
	local paths, seen, fontGlobals = {}, {}, {}
	for _, path in ipairs(ns.DEV_CLIENT_FONT_PATHS) do
		paths[#paths + 1] = path
		seen[path:lower()] = true
	end
	for _, name in ipairs(ns.DEV_FONT_GLOBALS) do
		local ok, value = pcall(function()
			return globals[name]
		end)
		local path = ok and savedPath(value)
		if path then
			fontGlobals[name] = path
			if not seen[path:lower()] then
				seen[path:lower()] = true
				paths[#paths + 1] = path
			end
		end
	end
	return paths, fontGlobals
end

--- The saved facts about one font that loaded: the width of the box character and, by script, the sample's width and how
--- many of its characters are wider or narrower than the box.
---@param measure PagleFontMeasure
---@return table
local function measured(measure)
	local ok, box = pcall(measure, ns.DevUtf8(ns.DEV_FONT_BOX_POINT))
	local facts = { box = ok and box or nil, scripts = {} }
	for _, entry in ipairs(ns.DEV_FONT_SAMPLES) do
		local script = { chars = #entry.points, width = 0, drawn = 0 }
		for _, point in ipairs(entry.points) do
			local good, width = pcall(measure, ns.DevUtf8(point))
			if good and type(width) == "number" then
				script.width = script.width + width
				if width ~= facts.box then
					script.drawn = script.drawn + 1
				end
			end
		end
		facts.scripts[entry.script] = script
	end
	return facts
end

--- Runs `/pagle dev fonts`: tries every path, measures every loaded font, saves the probe in `global.fontProbe`
--- (replacing the last one; `/pagle dev probe`'s `global.probe` is left alone), shows one row per loaded font and
--- prints one line per path, then the saved line. The saved shape is `time` (server time), `locale` (GetLocale()),
--- `language` (the Pagle language applied), `build`, `globals` (the font globals' values by name) and `fonts`: one
--- `{ path, ok, box, scripts }` per path tried, where `scripts[name]` is `{ chars, width, drawn }` (`chars` characters
--- of the sample, `width` their total width in a font that loaded, `drawn` of them that are not the box's width).
---@param options PagleFontProbeOptions
function ns.RunFontProbe(options)
	local L, globals = ns.L, options.globals()
	local paths, fontGlobals = pathsToTry(globals)
	local meter = options.meter()
	local located, locale = pcall(globals.GetLocale)
	local built, version, build, date, interface = pcall(globals.GetBuildInfo)
	local probe = {
		time = options.serverTime(),
		locale = located and tostring(locale) or "unknown",
		language = options.language(),
		build = built and { version = version, build = build, date = date, interface = interface } or nil,
		globals = fontGlobals,
		fonts = {},
	}
	local shown, loaded = {}, 0
	for i, path in ipairs(paths) do
		local measure = meter(path)
		local font = { path = path, ok = measure ~= nil }
		if measure then
			local found = measured(measure)
			font.box, font.scripts = found.box, found.scripts
			loaded = loaded + 1
			shown[#shown + 1] = { file = path, usedBy = ns.FontProbeSummary(font) }
		end
		probe.fonts[i] = font
	end
	options.global().fontProbe = probe
	for _, font in ipairs(probe.fonts) do
		options.print(L.DEV_FONTS_LINE:format(font.path, ns.FontProbeSummary(font)))
	end
	if #shown > 0 then
		options.show(shown, ns.DevFontProbeLine())
	end
	options.print(L.DEV_FONTS_SAVED:format(loaded, #paths, probe.locale))
end

--- A font's facts in one line: "failed" for a path that did not load, else "ok" and, by script, how many of its sample's
--- characters differ in width from the box ("latin 2/2, cyrillic 0/2, ...").
---@param font table one entry of the saved `fonts`
---@return string
function ns.FontProbeSummary(font)
	if not font.ok then
		return "failed"
	end
	local parts = {}
	for _, entry in ipairs(ns.DEV_FONT_SAMPLES) do
		local script = type(font.scripts) == "table" and font.scripts[entry.script]
		if type(script) == "table" then
			parts[#parts + 1] = ("%s %d/%d"):format(entry.script, script.drawn or 0, script.chars or #entry.points)
		end
	end
	return "ok; " .. table.concat(parts, ", ")
end

--- The probe's report for the font table: for each Pagle language that swaps (ns.CLIENT_FONTS), each role's path and
--- whether this client loaded it, and which of its scripts measured as drawn. A path the probe did not try, or that
--- failed, is a miss. Judged from a saved probe by scripts/read-wtf.lua.
---@param probe table PagleDB.global.fontProbe
---@return { language: string, role: string, path: string, loaded: boolean, summary: string }[]
function ns.FontProbeTableReport(probe)
	local byPath = {}
	for _, font in ipairs(probe.fonts or {}) do
		if type(font) == "table" and type(font.path) == "string" then
			byPath[font.path:lower()] = font
		end
	end
	local languages = {}
	for language in pairs(ns.CLIENT_FONTS) do
		languages[#languages + 1] = language
	end
	table.sort(languages)
	local roles = { "body", "heading", "hand", "mono" }
	local rows = {}
	for _, language in ipairs(languages) do
		for _, role in ipairs(roles) do
			local path = ns.CLIENT_FONTS[language][role]
			local font = byPath[path:lower()]
			rows[#rows + 1] = {
				language = language,
				role = role,
				path = path,
				loaded = font ~= nil and font.ok == true,
				summary = font and ns.FontProbeSummary(font) or "not tried",
			}
		end
	end
	return rows
end
