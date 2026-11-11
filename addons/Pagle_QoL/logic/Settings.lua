if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- QoL's rows on Core's Fishing page (qol.md › Settings, SET-R20): pure logic, the handle and the store passed in
-- (CORE-R7). Each Track Q step adds its section's rows here, in the order qol.md lists them.

--- The step of a Fishing audio mix channel's volume slider, in percent, as Game › Sound's (QOL-R62, qol.md › Tunables).
local AUDIO_VOLUME_STEP = 5

--- What QoL's logic reads and changes a setting through: PagleQoLDB's profile and the adapter calls a change makes
--- (CORE-R7). adapter/QoL.lua builds it. QoL's OnInitialize opens PagleQoLDB after the rows are added but before
--- anything reads one: the page, the menu and `/pagle qol` all run later.
---@class PagleQoLStore
---@field profile fun(): table `PagleQoLDB.profile` (qol.md › Data), read and changed in place
---@field input fun(): PagleQoLInput Input now (QOL-R12)
---@field setInput fun(input: PagleQoLInput) sets Input and re-evaluates at once (QOL-R18, QOL-R25)
---@field evaluate fun() re-evaluates the next action now, after a setting change (QOL-R25)
---@field changeLease fun(change: fun(profile: PagleQoLLeaseSettings)) changes a While you fish setting (QOL-R65)
---@field outputDevices fun(): string[] the client's sound output devices now, by index from 0 (QOL-R68)
---@field itemName fun(itemID: integer): string? an item's name, or nil while its data loads (QOL-R54)
---@field fishingSetChoice fun(): integer the chosen set's ID, or ns.NO_FISHING_SET (QOL-R40)
---@field chooseFishingSet fun(setID: integer) chooses a set, or None (QOL-R40, QOL-R41)
---@field fishingSetOptions fun(): { value: integer, label: string }[] None and the character's sets (QOL-R40)
---@field canEditGear fun(): boolean whether the Gear rows can change anything (QOL-R41)
---@field saveFishingSet fun(): string? saves what's worn as the fishing set, returning the line it printed if it
--- couldn't (QOL-R41, QOL-R42)
---@field resetButton fun() puts the next-action button back in its default place (QOL-R73)

--- Adds QoL's rows to Core's topic pages. Call it from OnInitialize, before ModulesChanged (CORE-R42).
---@param M PagleModuleHandle QoL's handle
---@param store PagleQoLStore what the rows read and change
function ns.AddSettings(M, store)
	local L = ns.L
	-- QoL's first row is a header, so Core adds no "QoL" header (CORE-R42, SET-R20).
	M:AddSetting("fishing", { kind = "header", label = L.SETTINGS_CASTING })

	-- The rows below read PagleQoLDB.profile through the store, and QoL opens it before the page is built.
	local defaults = ns.DB_DEFAULTS.profile

	-- Cast with is Input, which the compartment entry and /pagle qol set too (QOL-R12, QOL-R16, QOL-R17). A change
	-- takes effect at once, or when restriction ends (QOL-R18).
	M:AddSetting("fishing", {
		kind = "dropdown",
		id = "input",
		label = L.SETTINGS_CAST_WITH,
		tooltip = L.SETTINGS_CAST_WITH_TOOLTIP,
		default = defaults.input,
		get = store.input,
		set = store.setInput,
		options = function()
			return {
				{ value = "key", label = L.SETTINGS_CAST_WITH_KEY },
				{ value = "click", label = L.SETTINGS_CAST_WITH_CLICK },
				{ value = "both", label = L.SETTINGS_CAST_WITH_BOTH },
			}
		end,
	})
	-- Under Cast with, greyed out under Double right-click, where the key isn't armed (SET-R20, QOL-R12). The key is a
	-- binding, not a value, so the page's Defaults button leaves it alone (SET-R21, SET-R60).
	M:AddSetting("fishing", {
		kind = "keybinding",
		parent = "input",
		label = L.SETTINGS_FISHING_KEY,
		tooltip = L.SETTINGS_FISHING_KEY_TOOLTIP,
		binding = "PAGLE_FISHING_KEY",
		isEnabled = function()
			return ns.InputArmsKey(store.input())
		end,
	})

	-- Gear: this character's fishing set (QOL-R40–R42) and Swap gear (QOL-R46). The set and the button change nothing
	-- while restricted (QOL-R41).
	M:AddSetting("fishing", { kind = "header", label = L.SETTINGS_GEAR })
	-- No default, so the page's Defaults button leaves the fishing set alone (SET-R21): Blizzard's
	-- SettingMixin:SetValueToDefault skips a setting whose default is nil (Gethe/wow-ui-source branch forever,
	-- Blizzard_Settings_Shared/Blizzard_Setting.lua).
	M:AddSetting("fishing", {
		kind = "dropdown",
		id = "fishingSet",
		label = L.SETTINGS_FISHING_SET,
		tooltip = L.SETTINGS_FISHING_SET_TOOLTIP,
		get = function()
			return store.fishingSetChoice()
		end,
		set = function(value)
			store.chooseFishingSet(value)
		end,
		options = function()
			return store.fishingSetOptions()
		end,
		isEnabled = function()
			return store.canEditGear()
		end,
	})
	-- A button with that caption and no label; qol.md gives it no tooltip.
	M:AddSetting("fishing", {
		kind = "button",
		parent = "fishingSet",
		label = L.SETTINGS_SAVE_FISHING_SET,
		onClick = function()
			store.saveFishingSet()
		end,
		isEnabled = function()
			return store.canEditGear()
		end,
	})
	-- A binding, so Defaults leaves it alone (SET-R21). From 1.7 it works with no set chosen too (QOL-R48, QOL-R49).
	M:AddSetting("fishing", {
		kind = "keybinding",
		parent = "fishingSet",
		label = L.SETTINGS_SWAP_GEAR,
		tooltip = L.SETTINGS_SWAP_GEAR_TOOLTIP,
		binding = "PAGLE_SWAP_GEAR",
	})

	-- Lures and clams: which lure the Fishing key applies (QOL-R50, QOL-R51). A change re-points the key at once
	-- (QOL-R25).
	M:AddSetting("fishing", { kind = "header", label = L.SETTINGS_LURES_AND_CLAMS })
	M:AddSetting("fishing", {
		kind = "dropdown",
		id = "lures",
		label = L.SETTINGS_LURES,
		tooltip = L.SETTINGS_LURES_TOOLTIP,
		default = defaults.lures.mode,
		get = function()
			return store.profile().lures.mode
		end,
		set = function(value)
			store.profile().lures.mode = value
			store.evaluate()
		end,
		options = function()
			return {
				{ value = "off", label = L.SETTINGS_LURES_OFF },
				{ value = "best", label = L.SETTINGS_LURES_BEST },
				{ value = "one", label = L.SETTINGS_LURES_THIS },
			}
		end,
	})
	-- qol.md gives this row no tooltip. Live only for Only this one, keeping its value while greyed out (SET-R31).
	M:AddSetting("fishing", {
		kind = "dropdown",
		parent = "lures",
		label = L.SETTINGS_LURE,
		default = defaults.lures.item,
		get = function()
			return store.profile().lures.item
		end,
		set = function(value)
			store.profile().lures.item = value
			store.evaluate()
		end,
		options = function()
			local options = {}
			for i, lure in ipairs(ns.LURES) do
				options[i] = {
					value = lure.itemID,
					label = store.itemName(lure.itemID) or ns.Text(L.SETTINGS_LURE_UNNAMED, { item = lure.itemID }),
				}
			end
			return options
		end,
		isEnabled = function()
			return store.profile().lures.mode == "one"
		end,
	})
	-- Open clams between Casts (QOL-R56). A change re-points the key at once (QOL-R25). QOL-R100 may remove it.
	M:AddSetting("fishing", {
		kind = "checkbox",
		label = L.SETTINGS_CLAMS,
		tooltip = L.SETTINGS_CLAMS_TOOLTIP,
		default = defaults.clams,
		get = function()
			return store.profile().clams
		end,
		set = function(value)
			store.profile().clams = value
			store.evaluate()
		end,
	})

	-- While you fish: what a Fishing stretch leases besides soft-interact (QOL-R62), each change taking effect at once,
	-- mid-stretch too (QOL-R65).
	M:AddSetting("fishing", { kind = "header", label = L.SETTINGS_WHILE_YOU_FISH })
	M:AddSetting("fishing", {
		kind = "checkbox",
		id = "audio",
		label = L.SETTINGS_AUDIO_MIX,
		tooltip = L.SETTINGS_AUDIO_MIX_TOOLTIP,
		default = defaults.audio.on,
		get = function()
			return store.profile().audio.on
		end,
		set = function(value)
			store.changeLease(function(profile)
				profile.audio.on = value
			end)
		end,
	})
	-- The rows under the audio mix are greyed out while it is off, keeping their values. A channel's row can't grey
	-- (its native control reads no modify predicate), so it stays shown and live, and is never hidden (SET-R31).
	local function audioOn()
		return store.profile().audio.on
	end
	-- Each channel while you fish (QOL-R62), as Game › Sound's rows: ticked, the mix sets it to the slider's volume,
	-- 0% being Off; unticked, it is left as it is and the slider greys. Master has no Off: its slider starts at
	-- ns.AUDIO_MASTER_MIN.
	local channels = {
		{ key = "master", label = L.SETTINGS_AUDIO_MASTER, tooltip = L.SETTINGS_AUDIO_MASTER_TOOLTIP },
		{ key = "effects", label = L.SETTINGS_AUDIO_EFFECTS, canTurnOff = true },
		{ key = "music", label = L.SETTINGS_AUDIO_MUSIC, canTurnOff = true },
		{ key = "ambience", label = L.SETTINGS_AUDIO_AMBIENCE, canTurnOff = true },
		{ key = "dialog", label = L.SETTINGS_AUDIO_DIALOG, canTurnOff = true },
	}
	for _, channel in ipairs(channels) do
		local default = defaults.audio[channel.key] --[[@as PagleQoLAudioChannel]]
		M:AddSetting("fishing", {
			kind = "checkboxSlider",
			parent = "audio",
			label = channel.label,
			tooltip = channel.tooltip or L.SETTINGS_AUDIO_CHANNEL_TOOLTIP,
			default = default.on,
			get = function()
				return store.profile().audio[channel.key].on
			end,
			set = function(value)
				store.changeLease(function(profile)
					profile.audio[channel.key].on = value
				end)
			end,
			slider = {
				default = default.volume,
				min = channel.canTurnOff and 0 or ns.AUDIO_MASTER_MIN,
				max = 100,
				step = AUDIO_VOLUME_STEP,
				get = function()
					return store.profile().audio[channel.key].volume
				end,
				set = function(value)
					store.changeLease(function(profile)
						profile.audio[channel.key].volume = value
					end)
				end,
				format = function(value)
					if channel.canTurnOff and value <= 0 then
						return L.SETTINGS_AUDIO_OFF
					end
					return ns.Text(L.SETTINGS_AUDIO_LEVEL, { level = value })
				end,
			},
			isEnabled = audioOn,
		})
	end
	-- The output device while you fish (QOL-R68): Don't change, then the devices the client lists now. A device chosen
	-- that isn't there (unplugged) stays chosen and is listed as not found; no stretch leases it until it's back.
	M:AddSetting("fishing", {
		kind = "dropdown",
		parent = "audio",
		label = L.SETTINGS_AUDIO_DEVICE,
		tooltip = L.SETTINGS_AUDIO_DEVICE_TOOLTIP,
		default = defaults.audio.device,
		get = function()
			return store.profile().audio.device
		end,
		set = function(value)
			store.changeLease(function(profile)
				profile.audio.device = value
			end)
		end,
		options = function()
			local options = { { value = "", label = L.SETTINGS_AUDIO_KEEP } }
			local listed = { [""] = true }
			for _, device in ipairs(store.outputDevices()) do
				if not listed[device] then
					listed[device] = true
					options[#options + 1] = { value = device, label = device }
				end
			end
			local chosen = store.profile().audio.device
			if not listed[chosen] then
				options[#options + 1] =
					{ value = chosen, label = ns.Text(L.SETTINGS_AUDIO_DEVICE_MISSING, { device = chosen }) }
			end
			return options
		end,
		isEnabled = audioOn,
	})
	-- A short label on the native row, the whole sentence in its tooltip.
	M:AddSetting("fishing", {
		kind = "checkbox",
		parent = "audio",
		label = L.SETTINGS_BACKGROUND_SOUND,
		tooltip = L.SETTINGS_BACKGROUND_SOUND_TOOLTIP,
		default = defaults.audio.background,
		get = function()
			return store.profile().audio.background
		end,
		set = function(value)
			store.changeLease(function(profile)
				profile.audio.background = value
			end)
		end,
		isEnabled = audioOn,
	})
	M:AddSetting("fishing", {
		kind = "checkbox",
		label = L.SETTINGS_AUTO_LOOT,
		tooltip = L.SETTINGS_AUTO_LOOT_TOOLTIP,
		default = defaults.autoLoot,
		get = function()
			return store.profile().autoLoot
		end,
		set = function(value)
			store.changeLease(function(profile)
				profile.autoLoot = value
			end)
		end,
	})
	-- The next-action button (QOL-R70–R74) isn't a lease: a change re-evaluates, which shows or hides it at once
	-- (QOL-R25).
	M:AddSetting("fishing", {
		kind = "checkbox",
		id = "indicator",
		label = L.SETTINGS_SHOW_BUTTON,
		tooltip = L.SETTINGS_SHOW_BUTTON_TOOLTIP,
		default = defaults.indicator.shown,
		get = function()
			return store.profile().indicator.shown
		end,
		set = function(value)
			store.profile().indicator.shown = value
			store.evaluate()
		end,
	})
	-- The gear step alone no longer shows the button (QOL-R72); a change re-evaluates, which shows or hides it at once
	-- (QOL-R25). Greyed out while the button is off, keeping its value (SET-R31).
	M:AddSetting("fishing", {
		kind = "checkbox",
		parent = "indicator",
		label = L.SETTINGS_HIDE_UNTIL_POLE,
		tooltip = L.SETTINGS_HIDE_UNTIL_POLE_TOOLTIP,
		default = defaults.indicator.untilPole,
		get = function()
			return store.profile().indicator.untilPole
		end,
		set = function(value)
			store.profile().indicator.untilPole = value
			store.evaluate()
		end,
		isEnabled = function()
			return store.profile().indicator.shown
		end,
	})
	-- A row labelled Button position with a Reset button; qol.md gives it no tooltip. It is no value, so the page's
	-- Defaults button leaves the place alone (SET-R21). Greyed out while the button is off.
	M:AddSetting("fishing", {
		kind = "button",
		parent = "indicator",
		label = L.SETTINGS_BUTTON_POSITION,
		caption = L.SETTINGS_BUTTON_RESET,
		onClick = function()
			store.resetButton()
		end,
		isEnabled = function()
			return store.profile().indicator.shown
		end,
	})
end
