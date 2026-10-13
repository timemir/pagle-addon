if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
local ns = select(2, ...)

-- The Ledger's one projection (LED-R2): the def it hands `M:NewProjection`, over the fold (LED-R3). Pure logic,
-- everything passed in (CORE-R7).

--- The projection's rules version (LED-R2): `LEDGER_RULES_VERSION × 100 + Pagle.SIZE_RULES_VERSION`. Core defines
--- no `SIZE_RULES_VERSION` until M4's Simulated Sizes (LOG-R68), so a missing one counts as 0: M2's is 100.
---@param sizeRulesVersion integer? Pagle.SIZE_RULES_VERSION
---@return integer
function ns.RulesVersion(sizeRulesVersion)
	return ns.LEDGER_RULES_VERSION * 100 + (sizeRulesVersion or 0)
end

--- The Ledger's projection def (LED-R2, LOG-R70), bound to `global.projection`, which it makes if missing: Core
--- owns it from here on. `apply` is the fold's, the same in every mode (LED-R3); it ignores every kind but Casts and
--- Skill Readings (Prestiges come in M4). No `extraFingerprint`, and no Sessions read. `done` comes with the
--- moments (tickets #101 and #102).
---@param global table PagleLedgerDB's global section
---@param lookups LedgerLookups Core's lookups
---@param sizeRulesVersion integer? Pagle.SIZE_RULES_VERSION
---@return PagleProjectionDef
function ns.ProjectionDef(global, lookups, sizeRulesVersion)
	if type(global.projection) ~= "table" then
		global.projection = {}
	end
	local fold = ns.NewLedgerFold(lookups)
	return {
		db = global.projection,
		rulesVersion = ns.RulesVersion(sizeRulesVersion),
		reset = fold.reset,
		apply = function(state, record, mode)
			fold.apply(state, record, mode)
		end,
	}
end
