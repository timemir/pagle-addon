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
	-- No parent and never greyed out until Cast with arrives in Track Q step 3 (SET-R20). The key is a binding,
	-- not a value, so the page's Defaults button leaves it alone (SET-R21, SET-R60).
	M:AddSetting("fishing", {
		kind = "keybinding",
		label = L.SETTINGS_FISHING_KEY,
		tooltip = L.SETTINGS_FISHING_KEY_TOOLTIP,
		binding = "PAGLE_FISHING_KEY",
	})

	-- While you fish: what a Fishing stretch leases besides soft-interact (QOL-R62), each change taking effect at once,
	-- mid-stretch too (QOL-R65). The rows read PagleQoLDB.profile, which QoL opens before the page is built.
	local defaults = ns.DB_DEFAULTS.profile
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
