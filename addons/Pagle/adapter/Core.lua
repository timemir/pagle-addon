local addonName = ...
---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core says so once and never creates the Pagle global, so every Module's guard stops it (CORE-R4).
if not ns.IsForever(WOW_PROJECT_ID, WOW_PROJECT_CAMELOT) then
	print(ns.L.NOT_FOREVER)
	return
end

--- Core's public API: the one object Modules reach Core through (ADR 0001).
---@class Pagle
---@field API_VERSION integer Rises by one with each addition from 1.0 on; stays 1 before 1.0 (CORE-R15).
local Pagle = {
	API_VERSION = 1,
}
-- Built as a local, then published: the types stage checks writes to a class only through a typed local.
_G.Pagle = Pagle

-- Nothing reads ns.Core yet; it exists because #46 makes Core an AceAddon, registered with AceAddon-3.0 by name.
ns.Core = LibStub("AceAddon-3.0"):NewAddon(addonName)
