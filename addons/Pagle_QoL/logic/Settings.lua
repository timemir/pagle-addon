if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- QoL's rows on Core's Fishing page (qol.md › Settings, SET-R20): pure logic, the handle passed in (CORE-R7). Each
-- Track Q step adds its section's rows here, in the order qol.md lists them.

--- Adds QoL's rows to Core's topic pages. Call it from OnInitialize, before ModulesChanged (CORE-R42).
---@param M PagleModuleHandle QoL's handle
function ns.AddSettings(M)
	local L = ns.L
	-- QoL's first row is a header, so Core adds no "QoL" header (CORE-R42, SET-R20).
	M:AddSetting("fishing", { kind = "header", label = L.SETTINGS_CASTING })

	-- The rows below read PagleQoLDB.profile, which QoL opens before the page is built.
	local defaults = ns.DB_DEFAULTS.profile

	-- Cast with is Input, which the compartment entry and /pagle qol set too (QOL-R12, QOL-R16, QOL-R17). A change
	-- takes effect at once, or when restriction ends (QOL-R18).
	M:AddSetting("fishing", {
		kind = "dropdown",
		id = "input",
		label = L.SETTINGS_CAST_WITH,
		tooltip = L.SETTINGS_CAST_WITH_TOOLTIP,
		default = defaults.input,
		get = ns.CurrentInput,
		set = ns.SetInput,
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
			return ns.InputArmsKey(ns.CurrentInput())
		end,
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
			return ns.db.profile.lures.mode
		end,
		set = function(value)
			ns.db.profile.lures.mode = value
			ns.EvaluateFishingKey()
		end,
		options = function()
			return {
				{ value = "off", label = L.SETTINGS_LURES_OFF },
				{ value = "best", label = L.SETTINGS_LURES_BEST },
				{ value = "one", label = L.SETTINGS_LURES_ONE },
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
			return ns.db.profile.lures.item
		end,
		set = function(value)
			ns.db.profile.lures.item = value
			ns.EvaluateFishingKey()
		end,
		options = function()
			local options = {}
			for i, lure in ipairs(ns.LURES) do
				options[i] = {
					value = lure.itemID,
					label = ns.ItemName(lure.itemID) or L.SETTINGS_LURE_UNNAMED:format(lure.itemID),
				}
			end
			return options
		end,
		isEnabled = function()
			return ns.db.profile.lures.mode == "one"
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
			return ns.db.profile.audio.on
		end,
		set = function(value)
			ns.ChangeLeaseSetting(function(profile)
				profile.audio.on = value
			end)
		end,
	})
	-- qol.md gives this row no tooltip. Greyed out while the audio mix is off, keeping its value (SET-R31).
	M:AddSetting("fishing", {
		kind = "checkbox",
		parent = "audio",
		label = L.SETTINGS_BACKGROUND_SOUND,
		default = defaults.audio.background,
		get = function()
			return ns.db.profile.audio.background
		end,
		set = function(value)
			ns.ChangeLeaseSetting(function(profile)
				profile.audio.background = value
			end)
		end,
		isEnabled = function()
			return ns.db.profile.audio.on
		end,
	})
	M:AddSetting("fishing", {
		kind = "checkbox",
		label = L.SETTINGS_AUTO_LOOT,
		tooltip = L.SETTINGS_AUTO_LOOT_TOOLTIP,
		default = defaults.autoLoot,
		get = function()
			return ns.db.profile.autoLoot
		end,
		set = function(value)
			ns.ChangeLeaseSetting(function(profile)
				profile.autoLoot = value
			end)
		end,
	})
end
