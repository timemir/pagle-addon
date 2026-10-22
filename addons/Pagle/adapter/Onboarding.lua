---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Core's onboarding state on the client (core/onboarding.md): logic/Onboarding.lua's state over PagleDB.global, as
-- logic/Wiring.lua wires it over adapter/Host.lua's host. PagleDB's migration adds the state at login step 1, and
-- adapter/Login.lua calls ns.StartOnboarding at PLAYER_LOGIN, after ModulesChanged (ONB-R1–R3). /pagle guide
-- (ONB-R80) and /pagle dev onboarding (ONB-R83) reach it through adapter/Slash.lua. The Letter, the guide, Margin
-- notes, First looks and the First evening list build on ns.onboarding in their own files.
ns.WireOnboarding(ns.host)
