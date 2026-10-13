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
				TooltipDataType = { fields = { "Object" } }, -- LOG-R80
			},
		},
		-- Attaching a Module (CORE-R13, CORE-R16, CORE-R41); QoL's conflict check and its choices (QOL-R80, QOL-R83).
		C_AddOns = {
			fields = { "GetAddOnMetadata", "GetAddOnEnableState", "GetAddOnInfo", "IsAddOnLoaded", "DisableAddOn" },
		},
		"UnitGUID",
		-- The Settings tree (CORE-R40–R44, settings.md); the Settings table itself is in stds.wow_variables.
		"CreateSettingsListSectionHeaderInitializer",
		"CreateSettingsButtonInitializer",
		"CreateKeybindingEntryInitializer",
		C_KeyBindings = { fields = { "GetBindingIndex" } },
		"SettingsPanel",
		"HideUIPanel",
		-- The compartment menu (CORE-R50): a context menu, opened a frame after the compartment's click (C_Timer.After,
		-- in the one C_Timer entry below).
		MenuUtil = { fields = { "CreateContextMenu" } },
		-- The Catch log (LOG-R11, LOG-R15).
		"GetServerTime",
		-- The runtime area index and zone resolution (LOG-R22, LOG-R23).
		C_Map = { fields = { "GetAreaInfo", "GetBestMapForUnit" } },
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
		-- QoL's Fishing stretch and its CVar lease (QOL-R61–R64).
		"GetCVar",
		"SetCVar",
		"IsMounted",
		-- QoL's conflict popup (QOL-R81); StaticPopupDialogs itself is in stds.wow_variables.
		"StaticPopup_Show",
		-- The character table, Skill Readings and build entries (LOG-R26, LOG-R30, LOG-R36).
		"UnitName",
		"UnitClass",
		"UnitRace",
		"UnitFactionGroup",
		C_GameRules = { fields = { "IsHardcoreActive" } },
		"GetProfessions",
		"GetProfessionInfo",
		"GetBuildInfo",
		-- The conditions snapshot and service (LOG-R20, LOG-R45–R47); it reads skill as above (LOG-R30).
		"GetGameTime",
		C_DateAndTime = { fields = { "GetCurrentCalendarTime" } },
		C_Calendar = { fields = { "OpenCalendar", "GetMonthInfo", "GetNumDayEvents", "GetDayEvent" } },
		C_UnitAuras = { fields = { "GetPlayerAuraBySpellID" } },
		-- NewTicker for the conditions' polls; After for the compartment menu (CORE-R50) and the fishing grace time
		-- (LOG-R7).
		C_Timer = { fields = { "NewTicker", "After" } },
		-- Observing fishing (LOG-R2–R8): the channel, the loot window, the escaped message and the grace time.
		"GetTime",
		"IsFishingLoot",
		"GetNumLootItems",
		"GetLootSlotInfo",
		"GetLootSlotLink",
		"ERR_FISH_ESCAPED",
		-- The diagnostics buffer (LOG-R81); TooltipDataProcessor, for its hovers (LOG-R80), is in stds.wow_variables.
		"GetLocale",
		-- The projections' time budget per frame (LOG-R71, LOG-R72); their frames go through C_Timer.After.
		"debugprofilestop",
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
		-- A client function the dump doesn't list (it has only C_Item.GetWeaponEnchantInfo); the lure of LOG-R20.
		-- probes/fishing-signals/results/2026-10-11-build70338-report.md, "7. Fishing state: skill, spells, lure,
		-- buffs": GetWeaponEnchantInfo() returns true, 251777, 0, 263, … with a lure on, on build 70338.
		"GetWeaponEnchantInfo",
		-- A FrameXML table the dump doesn't list (CORE-R40). probes/fishing-signals/results/
		-- 2026-10-11-build70338-report.md, "Packaging, Settings and events": RegisterVerticalLayoutCategory,
		-- RegisterVerticalLayoutSubcategory and RegisterAddOnCategory work on build 70338. Every field: Gethe/wow-ui-source
		-- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_Settings_Shared/Blizzard_Settings.lua.
		Settings = {
			fields = {
				"VarType",
				"RegisterVerticalLayoutCategory",
				"RegisterVerticalLayoutSubcategory",
				"RegisterAddOnCategory",
				"OpenToCategory",
				"RegisterProxySetting",
				"CreateCheckbox",
				"CreateSlider",
				"CreateSliderOptions",
				"CreateDropdown",
				"CreateControlTextContainer",
				"CreateElementInitializer",
			},
		},
		-- A FrameXML table the dump doesn't list (QOL-R81). No probe has shown a popup yet; the M1 exit check (step 7)
		-- does. Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua: `StaticPopupDialogs = {}; -- Definitions`. QoL adds
		-- its one dialog to it.
		StaticPopupDialogs = { fields = { PAGLE_QOL_CONFLICT = { read_only = false } } },
		-- A FrameXML table the dump doesn't list (CORE-R60). probes/fishing-signals/results/
		-- 2026-10-11-build70338-report.md is the /pprobe report from build 70338, and /pprobe is registered with
		-- SlashCmdList.PAGLEPROBE (probes/fishing-signals/PagleProbe/Report.lua). Gethe/wow-ui-source branch forever at
		-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommandsRegistry.lua: "_G.SlashCmdList = {};".
		-- The compartment entry needs no table: Pagle.toc's AddonCompartmentFunc names a global, as the probe's did.
		SlashCmdList = { fields = { PAGLE = { read_only = false } } },
		-- A FrameXML table the dump doesn't list (LOG-R80). probes/fishing-signals/results/
		-- 2026-10-11-build70338-report.md, "Packaging, Settings and events": "Tooltip post-call hook (type Object) | ok
		-- (TooltipDataType.Object = 4); fired 31 times", and its client table shows TooltipDataProcessor with
		-- AddTooltipPostCall on build 70338. Gethe/wow-ui-source branch forever at
		-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua: "TooltipDataProcessor = {".
		TooltipDataProcessor = { fields = { "AddTooltipPostCall" } },
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
	"spec/scripts/fixtures/**", -- WTF files as the WoW client writes them: data the specs read, never our code
	".tools/**",
	".release/**",
}

-- CORE-R7: adapter/ is the one place an addon talks to the client. logic/ (everything passed in as arguments),
-- locale/ (string tables) and anything else keep the plain Lua 5.1 default.
files["addons/*/adapter/**"] = { std = "lua51+wow+wow_variables+pagle" }
-- Only Core's adapter creates the Pagle global.
files["addons/Pagle/adapter/**"] = { globals = { "Pagle" } }
-- /pagle's name, and the global Pagle.toc's AddonCompartmentFunc names (CORE-R50, CORE-R60).
files["addons/Pagle/adapter/Slash.lua"] = { globals = { "SLASH_PAGLE1" } }
files["addons/Pagle/adapter/Menu.lua"] = { globals = { "Pagle_OnAddonCompartmentClick" } }
-- A Module's adapter/ reads Pagle through stds.pagle above. Its logic/ and locale/ files read it only in their CORE-R11
-- guard, `if not Pagle then -- luacheck: read globals Pagle …`, whose inline option reaches that line alone: any other
-- use of Pagle there fails lint (CORE-R7).
-- QoL's adapter names its Bindings.xml entries for Key Bindings › AddOns (QOL-R1).
files["addons/Pagle_QoL/adapter/**"] = { globals = { "BINDING_HEADER_PAGLE", "BINDING_NAME_PAGLE_FISHING_KEY" } }
-- Specs run under busted on plain Lua 5.1. busted's helper (.busted) defines loadAddon and the Forever fixtures.
local helperGlobals = {
	"loadAddon",
	"PROJECT_IDS",
	"FOREVER_GLOBALS",
	"PLAYER_GUID",
	"SERVER_TIME",
	"addonFiles",
	"newFakePagle",
	-- spec/support/helpers.lua
	"foreverWith",
	"setCombat",
	"openedNames",
	"savedLog",
	"loadCollectingErrors",
}
files["spec/**"] = { std = "lua51+busted", read_globals = helperGlobals }
files["spec/support/*.lua"] = { globals = helperGlobals }
