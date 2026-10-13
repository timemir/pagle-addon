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
	read_globals = {
		-- Core's event bus and WoW event registration (CORE-R20–R23), restriction state (CORE-R30–R32).
		"CreateFrame",
		"geterrorhandler",
		"securecallfunction",
		"issecretvalue",
		"InCombatLockdown",
		C_RestrictedActions = { fields = { "GetAddOnRestrictionState" } },
		Enum = {
			fields = {
				"AddOnRestrictionType",
				AddOnRestrictionState = { fields = { "Inactive" } },
				AddOnEnableState = { fields = { "None" } }, -- CORE-R16
			},
		},
		-- Attaching a Module (CORE-R13, CORE-R16, CORE-R41).
		C_AddOns = { fields = { "GetAddOnMetadata", "GetAddOnEnableState", "GetAddOnInfo", "IsAddOnLoaded" } },
		"UnitGUID",
		-- The Catch log (LOG-R11, LOG-R15).
		"GetServerTime",
		-- The runtime area index and zone resolution (LOG-R22, LOG-R23).
		C_Map = { fields = { "GetAreaInfo" } },
		"GetRealZoneText",
		"GetSubZoneText",
		"GetInstanceInfo",
		-- QoL's Fishing key: its overrides and what it reads to choose them (QOL-R11, QOL-R20–R26).
		"GetBindingKey",
		"SetOverrideBinding",
		"SetOverrideBindingSpell",
		"ClearOverrideBindings",
		"IsKeyDown",
		"UnitChannelInfo",
		"UnitCastingInfo",
		"GetInventoryItemID",
		C_Item = { fields = { "GetItemInfoInstant" } },
		C_Spell = { fields = { "GetSpellName" } },
	},
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
-- Every Module file reads Pagle, for its CORE-R11 guard, so logic/ and locale/ may too; nothing else from Core.
files["addons/Pagle_*/**"] = { read_globals = { "Pagle" } }
-- QoL's adapter names its Bindings.xml entries for Key Bindings › AddOns (QOL-R1).
files["addons/Pagle_QoL/adapter/**"] = { globals = { "BINDING_HEADER_PAGLE", "BINDING_NAME_PAGLE_FISHING_KEY" } }
-- Specs run under busted on plain Lua 5.1. busted's helper (.busted) defines loadAddon and the Forever fixtures.
local helperGlobals = { "loadAddon", "PROJECT_IDS", "FOREVER_GLOBALS", "PLAYER_GUID", "addonFiles", "newFakePagle" }
files["spec/**"] = { std = "lua51+busted", read_globals = helperGlobals }
files["spec/support/*.lua"] = { globals = helperGlobals }
