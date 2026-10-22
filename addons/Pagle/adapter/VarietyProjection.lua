---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The variety projection on the client (varieties.md › Core's variety projection, VAR-R10, LOG-R78):
-- logic/VarietyProjection.lua's, bound in PagleDB.global.projections.varieties on Core's projection machinery over
-- Pagle.IterateCatches. Pagle.GetVarietiesCaught reads what it stored (VAR-R11), and ns.OnVarietiesCaught's hooks run
-- after its done and after each live Catch that adds a variety (VAR-R13).

--- ns.StartVarietyProjection, which adapter/Login.lua calls at login step 1, after the wallet's (LOG-R1, LOG-R78).
ns.WireVarietyProjection(ns.host, Pagle)
