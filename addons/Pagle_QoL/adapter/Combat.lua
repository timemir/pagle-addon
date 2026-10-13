if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Combat and restriction (QOL-R30–R34). As restriction starts, QoL steps aside while it still may: override
-- bindings can be cleared until combat lockdown starts, and not after (CORE-R32). Leaving restriction is each
-- feature's own re-evaluation (QOL-R32), so nothing here queues work.

-- The owner of these registrations, apart from the Fishing key's own.
local OWNER = "Pagle_QoL combat"

-- Restriction starts: PLAYER_REGEN_DISABLED runs before lockdown, and an addon restriction may come first as
-- RestrictionChanged(true). Each disarms if lockdown hasn't started; once it has, the overrides stay until
-- restriction ends (QOL-R31). Neither ever arms.
local function restrictionStarts()
	if not InCombatLockdown() then
		ns.DisarmFishingKey()
	end
end

--- Listens for restriction starting. QoL's OnInitialize calls it once it has registered.
function ns.StartCombat()
	Pagle.RegisterEvent(OWNER, "PLAYER_REGEN_DISABLED", restrictionStarts)
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
		if isRestricted then
			restrictionStarts()
		end
	end)
end
