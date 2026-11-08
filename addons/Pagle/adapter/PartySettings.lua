---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Party block on the Announcements page (settings.md SET-R36; announcements.md ANN-R104–R108; from 1.5.2, #640):
-- after Core's rows, under its own header, native checkboxes on proxy settings over PagleDB.profile.party, read
-- through adapter/Party.lua's ns.PartyOption and ns.PartyKindOn, since Core's defaults sit in logic/, which a patch
-- can't change: from 1.5.3 Share and Show are off until the party letter is accepted (ANN-R113), the rest on unless
-- stored off. adapter/AnnouncementSettings.lua calls it last. Loaded by adapter/Settings.xml.
local L = ns.L

-- The proxy setting variables: Core's Cozy mode (adapter/AnnouncementSettings.lua's), then the block's own.
local COZY = "Pagle_Core_cozy"
local SHARE = "Pagle_Core_partyShare"
local SHOW = "Pagle_Core_partyShow"
local SOUNDS = "Pagle_Core_partySounds"
local KIND = "Pagle_Core_partyKind_"
local HUNTS = "Pagle_Core_partyHunts"

local function notCozy()
	return not ns.db.profile.announcements.cozy
end

local function kindsLive()
	return notCozy() and ns.PartyOption("show")
end

-- A row greyed while `isLive` returns false, re-evaluated whenever Cozy mode or Show changes (SET-R31, SET-R61).
---@param initializer SettingsInitializer
---@param isLive fun(): boolean
local function greys(initializer, isLive)
	initializer:AddModifyPredicate(isLive)
	initializer:AddEvaluateStateCVar(COZY)
	initializer:AddEvaluateStateCVar(SHOW)
end

--- Builds the Party block on the Announcements page (SET-R36): the header, from 1.6 Party Hunts (SET-R35), then Share,
--- Show with a switch per kind under it, then Cheers sounds. Each reads the stored value each time the page is shown and
--- writes it at once (SET-R62); Share and Show default to off (ANN-R113), the rest to on, which the page's Defaults
--- button restores (SET-R33).
---@param page SettingsCategory
---@param layout SettingsLayout
function ns.PartySettingsRows(page, layout)
	local Boolean = Settings.VarType.Boolean
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_PARTY))

	-- Party Hunts (SET-R35, LOG-R121): PagleDB.profile.partyHunts, on by default (logic/Migrations.lua), never greyed:
	-- it governs what is shared and what counts, not what pops up.
	local hunts = Settings.RegisterProxySetting(page, HUNTS, Boolean, L.SETTINGS_PARTY_HUNTS, true, function()
		return ns.db.profile.partyHunts ~= false
	end, function(value)
		ns.db.profile.partyHunts = value == true
	end)
	Settings.CreateCheckbox(page, hunts, L.SETTINGS_PARTY_HUNTS_TOOLTIP)

	-- A row over option `key`, defaulting to `default`.
	local function option(variable, label, key, default)
		return Settings.RegisterProxySetting(page, variable, Boolean, label, default, function()
			return ns.PartyOption(key)
		end, function(value)
			ns.SetPartyOption(key, value)
		end)
	end

	Settings.CreateCheckbox(page, option(SHARE, L.SETTINGS_PARTY_SHARE, "share", false), L.SETTINGS_PARTY_SHARE_TOOLTIP)

	local show =
		Settings.CreateCheckbox(page, option(SHOW, L.SETTINGS_PARTY_SHOW, "show", false), L.SETTINGS_PARTY_SHOW_TOOLTIP)
	greys(show, notCozy)
	for _, kind in ipairs(ns.PARTY_KINDS) do
		local setting = Settings.RegisterProxySetting(
			page,
			KIND .. kind,
			Boolean,
			L.SETTINGS_PARTY_KINDS[kind],
			true,
			function()
				return ns.PartyKindOn(kind)
			end,
			function(value)
				ns.SetPartyKind(kind, value)
			end
		)
		local row = Settings.CreateCheckbox(page, setting)
		row:SetParentInitializer(show)
		greys(row, kindsLive)
	end

	local sounds = Settings.CreateCheckbox(
		page,
		option(SOUNDS, L.SETTINGS_PARTY_SOUNDS, "sounds", true),
		L.SETTINGS_PARTY_SOUNDS_TOOLTIP
	)
	greys(sounds, notCozy)
end
