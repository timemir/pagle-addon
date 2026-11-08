---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's reads of the Companion's two data addons (core/anglers-in-game.md, ADR 0001): Pagle_Following loads after
-- Pagle (its TOC's `## Dependencies: Pagle`, IGV-R42), so its data file has set PagleFollowingData by PLAYER_LOGIN,
-- where login step 2 reads it once (adapter/Login.lua); Pagle_Anglers is load-on-demand (IGV-R43), loaded at the first
-- player hover outside restriction with the tooltip setting on (VIEW-R3). Core never writes either global or folder,
-- and Pagle's zip never holds them (VIEW-R4). Then the Pagle block on a player's tooltip (VIEW-R20–R22); its Settings
-- row is the root's (adapter/Settings.lua, VIEW-R30). From 1.6, the news: Pagle.GetNews, Pagle.MarkNewsSeen and
-- Pagle.NewsWords over the client (VIEW-R42–R45).

-- The Companion's data addons, by folder name (IGV Contracts › The addon folders).
local FOLLOWING_ADDON, ANGLERS_ADDON = ns.FOLLOWING_ADDON, ns.ANGLERS_ADDON

-- Once the Language is applied (CORE-R8): the views' first reason ("not loaded yet") is read from ns.L as they are wired.
ns.AfterLanguage(function()
	ns.WireAnglerViews(ns.host, {
		following = function()
			return _G.PagleFollowingData
		end,
		-- Why there's no PagleFollowingData (IGV-R44, VIEW-R12), read as adapter/PushedContent.lua reads Pagle_Content's,
		-- under pcall: a client that refuses the name leaves the reason unknown, never login step 2's later parts undone.
		presence = function()
			local ok, _, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, FOLLOWING_ADDON)
			local read, loaded = pcall(C_AddOns.IsAddOnLoaded, FOLLOWING_ADDON)
			return {
				installed = not ok or reason ~= "MISSING",
				loaded = read and loaded == true,
				reason = ok and reason or nil,
			}
		end,
		-- VIEW-R3, once per login. Its second return names why it didn't load ("MISSING", "DISABLED", …). Under pcall, as
		-- it runs in the tooltip's post-call: an error is a failed load, never a broken tooltip.
		load = function()
			local ok, loaded, reason = pcall(C_AddOns.LoadAddOn, ANGLERS_ADDON)
			if not ok then
				return false, nil
			end
			return loaded == true, reason
		end,
		anglers = function()
			return _G.PagleAnglersData
		end,
		isSecret = function(value)
			return issecretvalue(value)
		end,
	})
end)

-- The Pagle block's colours, { r, g, b } by key (VIEW-R21); white for a line that names none.
local COLORS = {}
for key, hex in pairs(ns.ANGLER_TIP_COLORS) do
	COLORS[key] = ns.Rgb(hex)
end

-- A player unit's GUID from its tooltip's data (VIEW-R20): nil for any other unit's, and for data or a GUID that is
-- secret (CORE-R31), since its unit can't be told then. A player's GUID is `Player-<serverID>-<UID>`.
---@param data any
---@return string?
local function playerGuid(data)
	if issecretvalue(data) or type(data) ~= "table" then
		return nil
	end
	local guid = data.guid
	if issecretvalue(guid) or type(guid) ~= "string" or not guid:find("^Player%-") then
		return nil
	end
	return guid
end

-- The Pagle block (VIEW-R20, VIEW-R21), after the game's own lines, on the tooltip of any player unit with a card,
-- the player's own characters too; Core's, so it shows with every Module off. In combat and while restricted too
-- (VIEW-R22): it is only text added to the game's tooltip, and ns.anglerViews:HoverPlayer then finds Followed Anglers
-- alone. With the setting off nothing is looked up, so Pagle_Anglers never loads (VIEW-R30, VIEW-R3). A shown tooltip
-- is shown again so it fits the lines added; a hidden one, such as another addon's scanning tooltip, stays hidden.
TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
	local guid = playerGuid(data)
	if not guid or ns.db.profile.anglerTooltips ~= true then
		return
	end
	local card = ns.anglerViews:HoverPlayer(guid)
	local lines = card and ns.AnglerTooltipLines(card)
	if not lines then
		return
	end
	for _, line in ipairs(lines) do
		local left = COLORS[line.leftColor] or COLORS.white
		if line.right then
			local right = COLORS[line.rightColor] or COLORS.white
			tooltip:AddDoubleLine(line.left, line.right, left[1], left[2], left[3], right[1], right[2], right[3])
		else
			tooltip:AddLine(line.left, left[1], left[2], left[3])
		end
	end
	if tooltip:IsShown() then
		tooltip:Show()
	end
end)

--- The Followed Anglers (VIEW-R11): `{ state, anglers }`, state "ok", "none" (Pagle_Following is live with no
--- Anglers), "expired" (it's 24 h old or more) or "absent" (no file, or one IGV-R44 refuses). `anglers` is a fresh
--- array, empty unless "ok", of every Angler in the file's order, each a copy the caller may keep, with the full card's
--- fields as Pagle_Following's grammar names them. Read at the call, so an expiry mid-session shows at the next call.
---@return PagleFollowedAnglers
function Pagle.GetFollowedAnglers()
	return ns.anglerViews:FollowedAnglers()
end

--- The news (VIEW-R42): `{ state, items }`, state "ok", "none" (Pagle_Following is live with no news block: its
--- Companion predates the news), "expired" or "absent" as GetFollowedAnglers says. `items` is a fresh array, empty
--- unless "ok", of every news item in the file's order, each a copy with the news line's fields and `new`: true when, at
--- the session's first read of the news, its id wasn't seen and its time was at or after the floor; it stays new for the
--- session after it is marked. Read at the call, so an expiry mid-session shows at the next call.
---@return PagleNews
function Pagle.GetNews()
	return ns.anglerViews:News()
end

--- Marks news items seen (VIEW-R43): each id in `ids` with its item's time, or with no argument every item of
--- Pagle.GetNews(). Does nothing while the news isn't "ok". Only the news sign and the Fish Journal's news list call it.
---@param ids string[]?
function Pagle.MarkNewsSeen(ids)
	if ids ~= nil and type(ids) ~= "table" then
		error("Pagle.MarkNewsSeen: ids is a list of news item ids, or nil for every item", 2)
	end
	ns.anglerViews:MarkNewsSeen(ids)
end

-- The Species Core has a fish crest for (VAR-R12): those with varieties, read from the catalogue when first asked.
---@type table<integer, true>?
local fishCrests

-- What Pagle.NewsWords reads (VIEW-R45, SIGN-R19), from the client and Core at the call. An item name the client
-- hasn't loaded yet is asked for, so GET_ITEM_INFO_RECEIVED fires once it has it.
---@type PagleNewsLookups
local lookups = {
	itemName = function(itemID)
		local name = ns.UnlessSecret(issecretvalue, (C_Item.GetItemNameByID(itemID)))
		if name == nil then
			C_Item.RequestLoadItemDataByID(itemID)
		end
		return name
	end,
	varieties = function(species)
		return Pagle.GetVarieties(species)
	end,
	caught = function(species)
		return Pagle.GetVarietiesCaught(species)
	end,
	areaName = function(areaID)
		return ns.UnlessSecret(issecretvalue, (C_Map.GetAreaInfo(areaID)))
	end,
	formatLength = function(mm)
		return ns.FormatLength(mm, ns.LengthUnit())
	end,
	ledgerOn = function()
		for _, module in ipairs(ns.Modules:Modules()) do
			if module.def.name == "Ledger" then
				return true
			end
		end
		return false
	end,
	fishCrest = function(species)
		if not fishCrests then
			fishCrests = {}
			for _, id in ipairs(ns.Catalogue and ns.Catalogue.GetVarietySpecies() or {}) do
				fishCrests[id] = true
			end
		end
		return fishCrests[species] == true
	end,
}

--- A news item's words and emblem as the sign draws them (VIEW-R45, SIGN-R19): `{ kind, kicker, head, detail, emblem }`,
--- without the sign's more line, in the player's language. An item name the client hasn't loaded yet reads "a fish"
--- (SIGN_ITEM_UNKNOWN) at the call; drawn again once GET_ITEM_INFO_RECEIVED fires, it has its name. `item` is one of
--- Pagle.GetNews()'s items.
---@param item PagleNewsItem
---@return PagleNewsSignNews
function Pagle.NewsWords(item)
	if type(item) ~= "table" or type(item.kind) ~= "string" or not ns.L.SIGN_HEAD[item.kind] then
		error("Pagle.NewsWords: item is one of Pagle.GetNews()'s items", 2)
	end
	lookups.dropPrefix = GetLocale() == "enUS" and ns.L.FISH_CREST_DROP_PREFIX or nil
	return ns.NewsWords(item, lookups)
end
