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
		-- The Curio Shop entry's balance (CORE-R50).
		"BreakUpLargeNumbers",
		-- The Catch log (LOG-R11, LOG-R15).
		"GetServerTime",
		-- The runtime area index and zone resolution (LOG-R22, LOG-R23); GetMapInfo: the Journal's continent tabs
		-- (LED-R126).
		C_Map = { fields = { "GetAreaInfo", "GetBestMapForUnit", "GetMapInfo" } },
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
		-- GetItemNameByID: the Ledger's item names (LED-R97, LED-R126), and RequestLoadItemDataByID for the Journal's
		-- uncached ones (LED-R126). GetItemInfo: the Field report's item names (REP-R30). GetItemIconByID: a Hunt's
		-- icon (HNT-R55) and Stats' item icons (STA-R59).
		-- GetItemQualityByID: Stats' Catches by quality for an item Core has no quality for (STA-R33).
		C_Item = {
			fields = {
				"GetItemInfoInstant",
				"GetItemNameByID",
				"RequestLoadItemDataByID",
				"GetItemInfo",
				"GetItemIconByID",
				"GetItemQualityByID",
			},
		},
		C_Spell = { fields = { "GetSpellName" } },
		-- QoL's Fishing stretch and its CVar lease (QOL-R61–R64).
		"GetCVar",
		"SetCVar",
		"IsMounted",
		-- QoL's conflict popup (QOL-R81); StaticPopupDialogs itself is in stds.wow_variables. Its Reload now button
		-- (QOL-R83): ReloadUI is unprotected on build 70338 (QOL-R102), and the QoL boundary spec allows that one call.
		"StaticPopup_Show",
		"ReloadUI",
		-- The Ledger's Prestige confirm (LED-R33), hidden when the Fish Journal closes; the Curio Shop's Buy popup,
		-- shown with StaticPopup_Show above and hidden when the shop closes (SHOP-R41).
		"StaticPopup_Hide",
		-- The character table, Skill Readings and build entries (LOG-R26, LOG-R30, LOG-R36).
		"UnitName",
		"UnitClass",
		"UnitRace",
		"UnitFactionGroup",
		C_GameRules = { fields = { "IsHardcoreActive" } },
		"GetProfessions",
		"GetProfessionInfo",
		"GetBuildInfo",
		-- The conditions snapshot and service (LOG-R20, LOG-R45–R47); it reads skill as above (LOG-R30). GetGameTime
		-- also gives the Journal its realm offset (LED-R126).
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
		-- LuaBitOp, which the client ships: the Simulated Size hash (LOG-R66), in Core's logic/Size.lua (files[] below).
		bit = { fields = { "bxor", "rshift" } },
		-- The default length unit (LOG-R69): read only through adapter/Host.lua's region, which allows for it missing.
		-- On the launch re-verification list (roadmap.md › Launch re-verification checklist, item 19).
		"GetCurrentRegion",
		-- The Announcement frames, hung from UIParent, and their sounds on the SFX channel (ANN-R73, ANN-R80); their
		-- lanes run on GetTime and C_Timer.After, and an item icon comes from C_Item.GetItemInfoInstant (above).
		"UIParent",
		"PlaySoundFile",
		-- The Fish Journal's serif and handwriting font objects (ledger.md › UI); its frame is drawn on CreateFrame and
		-- UIParent above and hides with Esc through UISpecialFrames (below).
		"CreateFont",
		-- The Curio Shop's purse: each Module's segment shows its lifetime Coins in the tooltip (wallet-and-shop.md › UI).
		-- The window is drawn on CreateFrame and UIParent above and hides with Esc through UISpecialFrames (below).
		"GameTooltip",
		-- Stats' words (STA-R59): times and dates in the player's local clock, and the game's quality names (GlobalStrings);
		-- their colours are ITEM_QUALITY_COLORS, in stds.wow_variables.
		"date",
		"ITEM_QUALITY0_DESC",
		"ITEM_QUALITY1_DESC",
		"ITEM_QUALITY2_DESC",
		"ITEM_QUALITY3_DESC",
		"ITEM_QUALITY4_DESC",
		"ITEM_QUALITY5_DESC",
		"ITEM_QUALITY6_DESC",
		"ITEM_QUALITY7_DESC",
		-- The tracker dock (CORE-R70, CORE-R71): its anchor sits under the minimap cluster by default, and a drag of a
		-- docked tracker moves it only with Shift held. Both are in the pinned forever dump: Frames.lua lists
		-- MinimapCluster and GlobalAPI.lua lists IsShiftKeyDown.
		"MinimapCluster",
		"IsShiftKeyDown",
		-- The game's red error text, where Stats refuses a 4th watched Dry spell (STA-R61). The pinned forever dump's
		-- Frames.lua lists UIErrorsFrame.
		"UIErrorsFrame",
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
		-- A FrameXML table the dump doesn't list (SET-R30: Per's "{n} min" label). Gethe/wow-ui-source branch forever at
		-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua: `MinimalSliderWithSteppersMixin.Label =
		-- EnumUtil.MakeEnum("Left", "Right", "Top", "Min", "Max");`, the label types SettingsSliderOptionsMixin's
		-- SetLabelFormatter takes (Blizzard_Settings_Shared/Blizzard_Settings.lua).
		MinimalSliderWithSteppersMixin = { fields = { Label = { fields = { "Right" } } } },
		-- A FrameXML table the dump doesn't list (QOL-R81). No probe has shown a popup yet; the M1 exit check (step 7)
		-- does. Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_StaticPopup/StaticPopup.lua: `StaticPopupDialogs = {}; -- Definitions`. QoL adds
		-- its two dialogs to it: the conflict popup and its Reload now popup (QOL-R81, QOL-R83); the Ledger adds its
		-- Prestige confirm (LED-R33); Core adds the Curio Shop's Buy popup (wallet-and-shop.md › UI: Buy).
		StaticPopupDialogs = {
			fields = {
				PAGLE_QOL_CONFLICT = { read_only = false },
				PAGLE_QOL_RELOAD = { read_only = false },
				PAGLE_LEDGER_PRESTIGE = { read_only = false },
				PAGLE_CURIO_BUY = { read_only = false },
			},
		},
		-- A FrameXML table the dump doesn't list (CORE-R60). probes/fishing-signals/results/
		-- 2026-10-11-build70338-report.md is the /pprobe report from build 70338, and /pprobe is registered with
		-- SlashCmdList.PAGLEPROBE (probes/fishing-signals/PagleProbe/Report.lua). Gethe/wow-ui-source branch forever at
		-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_ChatFrameBase/Shared/SlashCommandsRegistry.lua: "_G.SlashCmdList = {};".
		SlashCmdList = { fields = { PAGLE = { read_only = false } } },
		-- A FrameXML frame the dump doesn't list (CORE-R50, CORE-R51): Core registers its compartment entry itself, so
		-- it can change the label. Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
		-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_Minimap/Mainline/AddonCompartment.xml: `<DropdownButton
		-- name="AddonCompartmentFrame" parent="MinimapCluster" mixin="AddonCompartmentMixin">`, and
		-- AddonCompartment.lua: `function AddonCompartmentMixin:RegisterAddon(addonData)` keeps the table, whose `text`
		-- the menu generator reads each time the compartment opens (`local text = addonData.text;`).
		AddonCompartmentFrame = { fields = { "RegisterAddon" } },
		-- A FrameXML table the dump doesn't list (LOG-R80). probes/fishing-signals/results/
		-- 2026-10-11-build70338-report.md, "Packaging, Settings and events": "Tooltip post-call hook (type Object) | ok
		-- (TooltipDataType.Object = 4); fired 31 times", and its client table shows TooltipDataProcessor with
		-- AddTooltipPostCall on build 70338. Gethe/wow-ui-source branch forever at
		-- 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_SharedXMLGame/Tooltip/TooltipDataHandler.lua: "TooltipDataProcessor = {".
		TooltipDataProcessor = { fields = { "AddTooltipPostCall" } },
		-- A FrameXML table the dump doesn't list (announcements.md › UI: a card closes with Esc). Gethe/wow-ui-source
		-- branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_UIParentPanelManager/Shared/UIParentPanelManager.lua: "UISpecialFrames = {", and
		-- CloseSpecialWindows hides each frame named in it that is shown. Core adds its card frame's name.
		"UISpecialFrames",
		-- A FrameXML table the dump doesn't list (HNT-R54: a Hunt's target item loads with Item:CreateFromItemID).
		-- Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1 (70338)"),
		-- Interface/AddOns/Blizzard_ObjectAPI/Mainline/Item.lua: "Item = {};", "--[[static]] function
		-- Item:CreateFromItemID(itemID)" and "function ItemMixin:ContinueOnItemLoad(callbackFunction)"; Item.lua is
		-- listed for every game type in Blizzard_ObjectAPI.toc.
		Item = { fields = { "CreateFromItemID" } },
		-- A FrameXML table the dump doesn't list (HNT-R55: a quality class's icon tint; STA-R59: item qualities in the
		-- game's own colours). Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57 ("1.60.1
		-- (70338)"), Interface/AddOns/Blizzard_Colors/Mainline/ColorConstants.lua: "ITEM_QUALITY_COLORS = { };", and
		-- Mainline/ColorManager.lua: `ITEM_QUALITY_COLORS = {};` then, per quality, `ITEM_QUALITY_COLORS[i] = { r =
		-- color.r, g = color.g, b = color.b, hex = color:GenerateHexColorMarkup(), color = color };`.
		-- ColorManager.UpdateColorData makes a new table when the colour overrides change, so Hunts and Stats read it at
		-- each call.
		"ITEM_QUALITY_COLORS",
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
-- LOG-R66 puts the Simulated Size hash in Core's logic/, on the client's `bit` library: the one client name a logic/
-- file reads, as stds.wow inventories it.
files["addons/Pagle/logic/Size.lua"] = { read_globals = { bit = stds.wow.read_globals.bit } }
-- Only Core's adapter creates the Pagle global.
files["addons/Pagle/adapter/**"] = { globals = { "Pagle" } }
-- /pagle's name (CORE-R60).
files["addons/Pagle/adapter/Slash.lua"] = { globals = { "SLASH_PAGLE1" } }
-- The mixin of Stats' Watched Dry spells row, which adapter/Settings.xml's template names (SET-R5, SET-R42).
files["addons/Pagle_Stats/adapter/Settings.lua"] = { globals = { "PagleStatsWatchedRowMixin" } }
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
	"watchErrors",
	-- spec/support/helpers.lua
	"foreverWith",
	"setCombat",
	"openedNames",
	"savedLog",
	"loadCollectingErrors",
	"breakUpLargeNumbers",
	"OILY_BLACKMOUTH",
	"FISHING",
	"BUILD_ENTRY",
	"castEntry",
	"prestigeEntry",
	"purchaseEntry",
	"history",
	"loadCore",
	"enterWorld",
	"catchOne",
	"catchAndFlush",
	"withoutComments",
	"forbiddenIn",
	"shippedFiles",
	"readFile",
}
files["spec/**"] = { std = "lua51+busted", read_globals = helperGlobals }
files["spec/support/*.lua"] = { globals = helperGlobals }
