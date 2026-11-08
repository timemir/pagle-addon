---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Morning Tide's section on the Announcements page (settings.md SET-R37; core/news-sign.md SIGN-R14, SIGN-R15,
-- SIGN-R18, SIGN-R31, Data; from 1.6): after the Party block, under its own header, native checkboxes on proxy
-- settings over PagleDB.global.newsSign, nil meaning the default, as the Party block's rows read theirs
-- (adapter/PartySettings.lua), then the look's slot dropdown. They read the switches through adapter/NewsSign.lua's
-- ns.NewsOption, ns.NewsKindOn and ns.NewsSignMuted, as the sign's decision does, and write them here. adapter/AnnouncementSettings.lua calls it after the Party
-- block. Loaded from the TOC, before adapter/AnnouncementSettings.lua.
local L = ns.L

-- The proxy setting variables: Core's Cozy mode (adapter/AnnouncementSettings.lua's), then the section's own.
local COZY = "Pagle_Core_cozy"
local SHOW = "Pagle_Core_newsShow"
local KIND = "Pagle_Core_newsKind_"
local HEADLINES = "Pagle_Core_newsHeadlines"
local MUTE = "Pagle_Core_newsMute"

-- PagleDB.global.newsSign as stored, or nil: nothing is written until a switch is turned off or the sign muted.
---@return { show: boolean?, kinds: table<string, boolean>?, headlines: boolean?, mute: boolean?, point: table? }?
local function stored()
	return ns.db.global.newsSign
end

local function writable()
	ns.db.global.newsSign = ns.db.global.newsSign or {}
	return ns.db.global.newsSign
end

-- Sets switch `key` of the sign's: false is stored, on clears the key. Turning Show news at login on from off sets the
-- floor (SIGN-R18), so it never brings the backlog that came while it was off; setting it on while on, as the page's
-- Defaults does, leaves the floor (SET-R37).
---@param key "show"|"headlines"
---@param on boolean
local function setOption(key, on)
	local was = ns.NewsOption(key)
	if on then
		local sign = stored()
		if sign then
			sign[key] = nil
		end
	else
		writable()[key] = false
	end
	if key == "show" and on and not was then
		ns.SetNewsFloor() -- logic/Wiring.lua's (VIEW-R44)
	end
end

-- Sets the switch of kind `kind`: false is stored, on clears it.
---@param kind string
---@param on boolean
local function setKind(kind, on)
	if on then
		local sign = stored()
		if sign and sign.kinds then
			sign.kinds[kind] = nil
		end
	else
		local sign = writable()
		sign.kinds = sign.kinds or {}
		sign.kinds[kind] = false
	end
end

-- Mutes the sign: true is stored, unmuted clears it (SIGN-R31).
---@param on boolean
local function setMute(on)
	if on then
		writable().mute = true
	else
		local sign = stored()
		if sign then
			sign.mute = nil
		end
	end
end

local function notCozy()
	return not ns.db.profile.announcements.cozy
end

local function kindsLive()
	return notCozy() and ns.NewsOption("show")
end

-- A row greyed while `isLive` returns false, re-evaluated whenever Cozy mode or the master changes (SET-R31, SET-R61).
---@param initializer SettingsInitializer
---@param isLive fun(): boolean
local function greys(initializer, isLive)
	initializer:AddModifyPredicate(isLive)
	initializer:AddEvaluateStateCVar(COZY)
	initializer:AddEvaluateStateCVar(SHOW)
end

--- Core's registered news sign slot (ns.NEWS_SIGN_SLOT, logic/CoreGoods.lua, SHOP-R60), or nil while it has no goods.
--- Its dropdown ends this section, not Core's rows: ns.CoreAnnouncementSlots leaves it out (SET-R30).
---@return PagleRegisteredSlot?
local function signSlot()
	return ns.goods:SlotsWithGoods(function(slot)
		return slot.id == ns.NEWS_SIGN_SLOT
	end)[1]
end

--- Builds The Morning Tide's section on the Announcements page (SET-R37): the header, Show news at login with a switch
--- per followed kind and Region headlines under it, Mute the sign, then the look's slot dropdown. Each reads the stored
--- value each time the page is shown and writes it at once (SET-R62); the page's Defaults button turns every switch
--- back on, unmutes the sign and puts the look back to Wood (SET-R33, SET-R60).
---@param page SettingsCategory
---@param layout SettingsLayout
function ns.NewsSignSettingsRows(page, layout)
	local Boolean = Settings.VarType.Boolean
	layout:AddInitializer(CreateSettingsListSectionHeaderInitializer(L.SETTINGS_NEWS))

	-- A switch over option `key`, on by default.
	local function option(variable, label, key)
		return Settings.RegisterProxySetting(page, variable, Boolean, label, true, function()
			return ns.NewsOption(key)
		end, function(value)
			setOption(key, value)
		end)
	end

	-- Greyed in Cozy mode, which holds the sign (SIGN-R14).
	local show = Settings.CreateCheckbox(page, option(SHOW, L.SETTINGS_NEWS_SHOW, "show"), L.SETTINGS_NEWS_SHOW_TOOLTIP)
	greys(show, notCozy)

	-- The followed kinds in the sign's rank (SIGN-R10, logic/NewsSign.lua's ns.NEWS_FOLLOWED_KINDS), then
	-- Region headlines, indented under the master and greyed with it.
	local function kindRow(kind)
		local setting = Settings.RegisterProxySetting(
			page,
			KIND .. kind,
			Boolean,
			L.SETTINGS_NEWS_KINDS[kind],
			true,
			function()
				return ns.NewsKindOn(kind)
			end,
			function(value)
				setKind(kind, value)
			end
		)
		local row = Settings.CreateCheckbox(page, setting)
		row:SetParentInitializer(show)
		greys(row, kindsLive)
	end
	for _, kind in ipairs(ns.NEWS_FOLLOWED_KINDS) do
		kindRow(kind)
	end
	local headlines = Settings.CreateCheckbox(
		page,
		option(HEADLINES, L.SETTINGS_NEWS_HEADLINES, "headlines"),
		L.SETTINGS_NEWS_HEADLINES_TOOLTIP
	)
	headlines:SetParentInitializer(show)
	greys(headlines, kindsLive)

	-- Mute the sign and the look are never greyed: they are kept for when the sign shows.
	local mute =
		Settings.RegisterProxySetting(page, MUTE, Boolean, L.SETTINGS_NEWS_MUTE, false, ns.NewsSignMuted, setMute)
	Settings.CreateCheckbox(page, mute, L.SETTINGS_NEWS_MUTE_TOOLTIP)

	-- The look: Core's slot dropdown, Wood and the looks owned (SET-R51), over `core.newssign`, which Core's goods
	-- register with Wood and the five looks for sale (SHOP-R60).
	local slot = signSlot()
	if slot then
		ns.SlotDropdown(page, layout, slot, "announcements")
	end
end
