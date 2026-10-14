-- The fake client's core: its event system, addon list and loot window, and the WoW API stubs every load starts
-- from, answering as one fixed character. spec/support/addon.lua builds one per load and adds the other stub sets
-- (timers, settings, menu, game, popup, tooltip) to it.
--
--   loaded.client.fire("PLAYER_REGEN_DISABLED")       -- a WoW event, at each frame registered for it
--   loaded.client.addons.Pagle_QoL = { enabled = false }
--   loaded.client.loot = { fishing = true, slots = { { link = link, quantity = 1 } } }

--- The client's event system and addon list, as far as specs need them. Each stub set adds the fields it keeps.
---@class FakeClient
---@field fire fun(event: string, ...) Fires a WoW event at each frame registered for it, in creation order, calling
--- its OnEvent script with (frame, event, ...). A unit event reaches a frame only for the units it registered.
---@field addons table<string, FakeAddOn> The addons installed, by folder name ("Pagle_QoL"), as C_AddOns reports
--- them. loadAddon lists each addon it loads, with its TOC fields as metadata. One not listed is missing. Specs add
--- to it.
---@field loot FakeLoot The loot window, as the loot API reads it.
---@field areaNames table<integer, string> Each area's name, as `C_Map.GetAreaInfo` returns it. Default none.
---@field mapNames table<integer, string> Each uiMap's name, for `C_Map.GetMapInfo`. Default none.
---@field sounds string[] Each PlaySoundFile call, in order, as "<path> <channel>".
---@field errors string[] Each error the default geterrorhandler() got, in order. A spec that gets one must read
--- this list (assert it), or it fails at its end (spec/support/errors.lua).
---@field addError fun(err: any) The default geterrorhandler(): adds the error to `errors`.
---@field pressEscape fun() Presses Esc: the focused edit box's OnEscapePressed, or with none focused,
--- CloseSpecialWindows (every shown frame named in UISpecialFrames hides, and its OnHide runs).

--- The loot window the loot API reads: whether it's fishing loot (`IsFishingLoot()`) and its slots, in order.
--- Specs set both before firing LOOT_READY.
---@class FakeLoot
---@field fishing any What IsFishingLoot() returns. Default false.
---@field slots { link: any, quantity: any, currencyID: integer?, isCoin: boolean? }[] Each slot as GetLootSlotLink
--- and GetLootSlotInfo (3rd, 4th and 10th returns) read it. Default none.

--- An installed addon, as the fake client's C_AddOns reports it.
---@class FakeAddOn
---@field enabled boolean? Enabled for the player's character in the AddOns list. Default true.
---@field loaded boolean? Loaded this session. Default: whether it's enabled.
---@field metadata table<string, string>? Its TOC fields, e.g. ["X-Pagle-API"] = "1".

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local widgets = dofile("spec/support/widgets.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local newSecureCall = dofile("spec/support/securecall.lua")
---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no require
local BIT = require("bit")

---@return FakeClient
local function newClient()
	local client = {
		missingEvents = {},
		frames = {},
		addons = {},
		bindings = {},
		loot = { fishing = false, slots = {} },
		sounds = {},
		areaNames = {},
		mapNames = {},
	}
	client.addError = watchErrors(client, "errors")

	function client.fire(event, ...)
		local unit = ...
		for _, frame in ipairs({ unpack(client.frames) }) do
			local registered = frame.events[event]
			local onEvent = frame.scripts.OnEvent
			if registered and onEvent and (registered == true or registered[unit]) then
				onEvent(frame, event, ...)
			end
		end
	end

	return client
end

-- The WoW API the addons call, answering as one fixed character on a US realm, out of combat, with no addon
-- restriction active and no secret values.
---@param client FakeClient
---@return table<string, any>
local function clientStubs(client)
	local stubs
	stubs = {
		-- As the client's, a named frame is also the global of that name, and keeps its template; a template the
		-- fakes know adds its parts (widgets.applyTemplate).
		CreateFrame = function(frameType, name, parent, template)
			local frame = widgets.newFrame(client, frameType, parent)
			frame.name, frame.template = name, template
			if name then
				stubs[name] = frame
			end
			widgets.applyTemplate(client, frame, template)
			return frame
		end,
		-- A font object, keeping its name and what SetFont gave it (`font`: file, size, flags).
		CreateFont = function(name)
			local font = { name = name }
			function font:SetFont(file, size, flags)
				self.font = { file, size, flags }
				return true
			end
			font.SetTextColor = function() end
			font.SetShadowOffset = function() end
			font.SetShadowColor = function() end
			return font
		end,
		-- The frame names Esc hides (CloseSpecialWindows), as FrameXML starts it.
		UISpecialFrames = { "ItemRefTooltip", "ColorPickerFrame" },
		-- Records the call in client.sounds and reports it played, as willPlay, soundHandle.
		PlaySoundFile = function(path, channel)
			client.sounds[#client.sounds + 1] = ("%s %s"):format(path, tostring(channel))
			return true, #client.sounds
		end,
		-- The screen's root frame, which every addon frame hangs from, and the game's error text under it (both in the
		-- forever dump's Frames.lua), and the yellow FrameXML's GlobalColors defines (CreateColor(1, 1, 0, 1)). UIParent
		-- is a plain widget, so it gets no events.
		UIParent = widgets.newWidget("Frame"),
		-- The game world's frame, which the mouse is over when it's over no UI (Frames.lua in the forever dump).
		WorldFrame = widgets.newWidget("Frame"),
		YELLOW_FONT_COLOR = {
			r = 1,
			g = 1,
			b = 0,
			GetRGB = function(color)
				return color.r, color.g, color.b
			end,
		},
		IsLoggedIn = function()
			return false
		end,
		-- The client's default handler reports an error and carries on; here it keeps it in client.errors, and a spec
		-- that never reads that list fails at its end (spec/support/errors.lua). Raising here instead would lose an
		-- error AceAddon's xpcall hands it, as "error in error handling".
		geterrorhandler = function()
			return client.addError
		end,
		-- As the client's: an error goes to whatever geterrorhandler() returns at the time, and the caller carries on.
		securecallfunction = newSecureCall(function()
			return stubs.geterrorhandler()
		end),
		issecretvalue = function()
			return false
		end,
		-- The client's string extension: a UTF-8 string's length in code points, counting every byte that doesn't
		-- continue a sequence (10xxxxxx). AceDB reads it to check a saved profile key.
		strlenutf8 = function(s)
			local _, codePoints = string.gsub(s, "[^\128-\191]", "")
			return codePoints
		end,
		InCombatLockdown = function()
			return false
		end,
		C_RestrictedActions = {
			GetAddOnRestrictionState = function()
				return 0 -- Enum.AddOnRestrictionState.Inactive
			end,
		},
		-- The forever dump's LuaEnum.lua at BIR_COMMIT (scripts/tools.env).
		Enum = {
			AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4, Chat = 5 },
			AddOnRestrictionState = { Inactive = 0, Activating = 1, Active = 2 },
			AddOnEnableState = { None = 0, Some = 1, All = 2 },
		},
		-- Areas and maps have the names in client.areaNames and client.mapNames: none by default, so the area index
		-- Core builds at PLAYER_LOGIN is empty.
		C_Map = {
			GetAreaInfo = function(areaID)
				return client.areaNames[areaID]
			end,
			-- UiMapDetails, with only the name (the Ledger's continent tabs, LED-R126); nil for a map with no name.
			GetMapInfo = function(uiMapID)
				local name = client.mapNames[uiMapID]
				return name and { uiMapID = uiMapID, name = name } or nil
			end,
			GetBestMapForUnit = function()
				return nil
			end,
		},
		-- The conditions service's reads (LOG-R20, LOG-R45–R47): realm 08:15 on Sunday 11 October 2026 (a US Pacific
		-- realm, GetServerTime's 15:15 UTC), no zone text, no calendar event, no aura; Fishing is below. The lure
		-- (GetWeaponEnchantInfo, none by default) is with QoL's game side, spec/support/fake_game.lua.
		GetRealZoneText = function()
			return ""
		end,
		GetSubZoneText = function()
			return ""
		end,
		GetInstanceInfo = function()
			return "Kalimdor", "none", 0, "", 0, 0, false, 1, 0, nil, false
		end,
		GetGameTime = function()
			return 8, 15
		end,
		C_DateAndTime = {
			GetCurrentCalendarTime = function()
				return { year = 2026, month = 10, monthDay = 11, weekday = 1, hour = 8, minute = 15 }
			end,
		},
		C_Calendar = {
			OpenCalendar = function() end,
			GetMonthInfo = function()
				return { year = 2026, month = 10, numDays = 31, firstWeekday = 5 }
			end,
			GetNumDayEvents = function()
				return 0
			end,
			GetDayEvent = function()
				return nil
			end,
		},
		C_UnitAuras = {
			GetPlayerAuraBySpellID = function()
				return nil
			end,
		},
		-- The loot window (LOG-R3), from client.loot.
		IsFishingLoot = function()
			return client.loot.fishing
		end,
		GetNumLootItems = function()
			return #client.loot.slots
		end,
		GetLootSlotLink = function(slot)
			local entry = client.loot.slots[slot]
			return entry and entry.link
		end,
		-- icon, name, quantity, currencyID, quality, locked, isQuestItem, questID, isActive, isCoin
		GetLootSlotInfo = function(slot)
			local entry = client.loot.slots[slot]
			if entry then
				return 136245, "", entry.quantity, entry.currencyID, 1, false, false, nil, false, entry.isCoin == true
			end
		end,
		-- GlobalStrings/enUS.lua at BIR_COMMIT (scripts/tools.env).
		ERR_FISH_ESCAPED = "Your fish got away!",
		-- Reads client.addons. Folder names as the client takes them; an addon not listed is missing.
		C_AddOns = {
			GetAddOnInfo = function(name)
				if client.addons[name] then
					return name, name, "", true, nil
				end
				return name, nil, nil, false, "MISSING"
			end,
			-- Enum.AddOnEnableState: None 0, All 2. Enabled only for the player's own character.
			GetAddOnEnableState = function(name, character)
				local addon = client.addons[name]
				return (addon and addon.enabled ~= false and character == PLAYER_GUID) and 2 or 0
			end,
			IsAddOnLoaded = function(name)
				local addon = client.addons[name]
				local loaded = addon ~= nil and (addon.loaded or (addon.loaded == nil and addon.enabled ~= false))
				return loaded, loaded
			end,
			GetAddOnMetadata = function(name, field)
				local addon = client.addons[name]
				return addon and addon.metadata and addon.metadata[field]
			end,
		},
		UnitGUID = function(unit)
			return unit == "player" and PLAYER_GUID or nil
		end,
		GetLocale = function()
			return "enUS"
		end,
		UnitFactionGroup = function()
			return "Alliance", "Alliance"
		end,
		UnitClass = function()
			return "Warrior", "WARRIOR", 1
		end,
		UnitRace = function()
			return "Human", "Human", 1
		end,
		GetServerTime = function()
			return SERVER_TIME
		end,
		UnitNameUnmodified = function()
			return "Angler"
		end,
		-- Forever answers with the first name and the surname (probes/fishing-signals/results/2026-10-11-build70338-report.md).
		UnitName = function()
			return "Angler", "Tester"
		end,
		-- The probe's build, and a character whose one profession is Fishing (skill line 356) at 75/150.
		GetBuildInfo = function()
			return "1.60.1", "70338", "Oct  9 2026", 16001, "", " "
		end,
		GetProfessions = function()
			return nil, nil, nil, 8, nil
		end,
		GetProfessionInfo = function(index)
			if index == 8 then
				return "Fishing", 136245, 75, 150, 2, 34, 356, 0, -1, 0, "Fishing"
			end
		end,
		GetRealmName = function()
			return "Testrealm"
		end,
		GetCurrentRegion = function()
			return 1
		end,
		GetCurrentRegionName = function()
			return "US"
		end,
		-- LuaBitOp, the `bit` library the client ships (LOG-R66), from the luabitop rock scripts/tools.env pins.
		bit = BIT,
	}

	-- Presses Esc as the client does: the focused edit box takes it (OnEscapePressed); with none focused,
	-- CloseSpecialWindows hides every shown frame named in UISpecialFrames, running its OnHide.
	function client.pressEscape()
		local focus = client.focus
		local onEscape = focus and focus.scripts.OnEscapePressed
		if onEscape then
			onEscape(focus)
			return
		end
		for _, name in ipairs(stubs.UISpecialFrames) do
			for _, frame in ipairs(client.frames) do
				if frame.name == name and frame.shown then
					frame:Hide()
					local onHide = frame.scripts.OnHide
					if onHide then
						onHide(frame)
					end
				end
			end
		end
	end
	stubs.UIErrorsFrame = widgets.newWidget("MessageFrame", stubs.UIParent)
	return stubs
end

--- A fresh fake client and the WoW API stubs it answers through, before any other stub set is added.
---@return FakeClient client
---@return table<string, any> stubs
return function()
	local client = newClient()
	return client, clientStubs(client)
end
