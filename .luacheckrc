-- luacheck config for the lint stage of scripts/check.sh.
--
-- Every file is plain Lua 5.1 unless a files[] entry below lets more in, so a WoW global fails lint wherever it
-- isn't allowed on purpose (CORE-R7: logic/ and locale/ stay pure Lua). Only adapter/ code, which talks to the
-- client, gets the WoW stds. WoW names live in custom stds, never in a top-level read_globals: that would reach
-- every file, and scripts/api-presence.lua fails if a top-level read_globals or globals appears.

-- The inventory of WoW APIs Pagle uses; M8 re-checks it. Add each name on purpose, when adapter code needs it,
-- as a string ("CreateFrame") or with its fields (C_Weather = { fields = { "GetCurrentWeather" } }).
-- The API presence stage fails unless every name here is in the pinned forever dump (BIR_COMMIT, scripts/tools.env).
stds.wow = {
	read_globals = {},
}

-- WoW globals the client defines as plain Lua variables. The forever dump lists functions, frames, enums and
-- strings but no variables, so these can't be looked up in it: each one cites where the forever client defines it
-- instead. The API presence stage fails if one of them shows up in the dump, so it moves to stds.wow.
stds.wow_variables = {
	read_globals = {
		-- Ketho/BlizzardInterfaceResources README.md on branch forever at BIR_COMMIT:
		-- "WOW_PROJECT_ID => WOW_PROJECT_CAMELOT (18)".
		"WOW_PROJECT_ID",
		"WOW_PROJECT_CAMELOT",
	},
}

-- Globals Pagle's own addons and the vendored libraries define.
stds.pagle = {
	read_globals = { "LibStub", "Pagle" },
}

std = "lua51"
max_line_length = false -- StyLua owns line width, and it leaves long strings and comments as they are.
exclude_files = {
	"addons/*/libs/**", -- vendored, owned by scripts/update-ace3.sh
	"types/**", -- LuaLS ---@meta stubs: declarations for the types stage, never loaded
	".tools/**",
	".release/**",
}

-- CORE-R7: adapter/ is the one place an addon talks to the client. logic/ (everything passed in as arguments),
-- locale/ (string tables) and anything else keep the plain Lua 5.1 default.
files["addons/*/adapter/**"] = { std = "lua51+wow+wow_variables+pagle" }
-- Only Core's adapter creates the Pagle global.
files["addons/Pagle/adapter/**"] = { globals = { "Pagle" } }
-- Specs run under busted on plain Lua 5.1. busted's helper (.busted) defines loadAddon for them.
files["spec/**"] = { std = "lua51+busted", read_globals = { "loadAddon" } }
files["spec/support/addon.lua"] = { globals = { "loadAddon" } }
