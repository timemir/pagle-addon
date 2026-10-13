-- luacheck config for the lint stage of scripts/check.sh.
--
-- Addon code gets Lua 5.1 plus the custom stds below. Pure-Lua paths drop back to plain Lua 5.1, so any WoW
-- global there fails lint (CORE-R7). WoW names live in custom stds, never in a top-level read_globals: a per-path
-- std replaces the std, but a top-level read_globals would reach every file. scripts/api-presence.lua fails if a
-- top-level read_globals or globals appears.

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

std = "lua51+wow+wow_variables+pagle"
max_line_length = false -- StyLua owns line width, and it leaves long strings and comments as they are.
exclude_files = {
	"addons/*/libs/**", -- vendored, owned by scripts/update-ace3.sh
	"types/**", -- LuaLS ---@meta stubs: declarations for the types stage, never loaded
	".tools/**",
	".release/**",
}

-- CORE-R7: logic/ is pure Lua, everything passed in as arguments. locale/ holds only string tables.
files["addons/*/logic/**"] = { std = "lua51" }
files["addons/*/locale/**"] = { std = "lua51" }
-- Only Core's adapter creates the Pagle global.
files["addons/Pagle/adapter/**"] = { globals = { "Pagle" } }
-- Specs run under busted on plain Lua 5.1.
files["spec/**"] = { std = "lua51+busted" }
-- The gate's own scripts run on plain Lua 5.1.
files["scripts/**"] = { std = "lua51" }
