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
-- row is the root's (adapter/Settings.lua, VIEW-R30).

-- The Companion's data addons, by folder name (IGV Contracts › The addon folders).
local FOLLOWING_ADDON, ANGLERS_ADDON = ns.FOLLOWING_ADDON, ns.ANGLERS_ADDON

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
