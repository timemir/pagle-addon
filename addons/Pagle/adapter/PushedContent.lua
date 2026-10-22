---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Core's pushed-content reader (core/pushed-content.md, ADR 0013): the companion's data addon, Pagle_Content, loads
-- after Pagle (its TOC's `## Dependencies: Pagle`, PUSH-R1), so its one data file has set PagleContentData by
-- PLAYER_LOGIN, where login step 2 reads it once and starts the check (adapter/Login.lua). Core never writes the
-- global or the folder, and Pagle's zip never holds it.

-- The companion's data addon, by folder name (PUSH-R1).
local CONTENT_ADDON = "Pagle_Content"

ns.WirePushedContent(ns.host, {
	data = function()
		return _G.PagleContentData
	end,
	-- Why there's no file (PUSH-R13, PUSH-R14): GetAddOnInfo's fifth return is why it can't load, "MISSING" when it
	-- isn't installed (adapter/Modules.lua reads it the same way). Under pcall, as it runs in login step 2: a client
	-- that refuses the name leaves the reason unknown, never the login's later steps undone.
	presence = function()
		local ok, _, _, _, _, reason = pcall(C_AddOns.GetAddOnInfo, CONTENT_ADDON)
		local read, loaded = pcall(C_AddOns.IsAddOnLoaded, CONTENT_ADDON)
		return {
			installed = not ok or reason ~= "MISSING",
			loaded = read and loaded == true,
			reason = ok and reason or nil,
		}
	end,
})

--- The companion's state (PUSH-R15): "checking" until this login's check ends, then "missing" (no Pagle_Content, or
--- it failed the check), "notRunning" (it passed, but was written 24 h ago or more) or "connected". Fixed for the
--- login once the check ends; PushedContentReady(state) fires then (PUSH-R16).
---@return PagleCompanionState
function Pagle.GetCompanionState()
	return ns.pushedContent:State()
end

--- The checked items of `kind` (PUSH-R21, PUSH-R22), "huntEvent" or "huntRun": a fresh array in payload order, each
--- a deep copy the caller may keep. Empty while checking, when missing, or for a kind with no items; a notRunning
--- file's items are still handed out.
---@param kind string
---@return table[]
function Pagle.GetPushedContent(kind)
	return ns.pushedContent:Items(kind)
end
