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
-- and Pagle's zip never holds them (VIEW-R4).

-- The Companion's data addons, by folder name (IGV Contracts › The addon folders).
local FOLLOWING_ADDON, ANGLERS_ADDON = "Pagle_Following", "Pagle_Anglers"

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

--- The Followed Anglers (VIEW-R11): `{ state, anglers }`, state "ok", "none" (Pagle_Following is live with no
--- Anglers), "expired" (it's 24 h old or more) or "absent" (no file, or one IGV-R44 refuses). `anglers` is a fresh
--- array, empty unless "ok", of every Angler in the file's order, each a copy the caller may keep, with the full card's
--- fields as Pagle_Following's grammar names them. Read at the call, so an expiry mid-session shows at the next call.
---@return PagleFollowedAnglers
function Pagle.GetFollowedAnglers()
	return ns.anglerViews:FollowedAnglers()
end
