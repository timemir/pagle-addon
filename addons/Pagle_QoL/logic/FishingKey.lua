if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The Fishing key's choices: pure logic, everything passed in (CORE-R7). adapter/FishingKey.lua reads the game
-- and sets the bindings.

--- The Fishing spell whose name the cast override uses: every rank shares it (QOL-R24).
ns.FISHING_SPELL_ID = 7620

---@alias PagleQoLAction "nothing"|"reel"|"cast"

--- What the ladder reads (QOL-R20). M1 has steps 1, 2 and 6; Track Q adds gear, lures and clams.
---@class PagleQoLLadderState
---@field armed boolean? QoL is armed (QOL-R30)
---@field lootOpen boolean? a loot window is open (QOL-R28)
---@field casting boolean? the player is casting a spell with a cast time (`UnitCastingInfo`)
---@field channelingFishing boolean? the player is channeling Fishing (QOL-R22)
---@field poleInHand boolean? a fishing pole is in hand (QOL-R21); M1's ladder casts either way (QOL-R23)

--- The next action: the first step of the ladder that holds (QOL-R20), so a press is one game action.
---@param state PagleQoLLadderState
---@return PagleQoLAction
function ns.NextAction(state)
	if not state.armed or state.lootOpen or state.casting then
		return "nothing"
	end
	if state.channelingFishing then
		return "reel"
	end
	return "cast"
end

--- Whether an item of this class and subclass is a fishing pole: Weapon (2), Fishing Pole (20) (QOL-R21).
---@param classID integer?
---@param subclassID integer?
---@return boolean
function ns.IsFishingPole(classID, subclassID)
	return classID == 2 and subclassID == 20
end

--- What an override points a key at: a spell by name, or a binding command.
---@class PagleQoLKeyTarget
---@field kind "spell"|"command"
---@field value string

--- The Fishing key column of QOL-R24: cast by the Fishing spell's name, reel with soft-interact's
--- INTERACTTARGET, and no target (no override) for nothing, or for a cast while the spell's name is unknown.
---@param action PagleQoLAction
---@param fishingName string? `C_Spell.GetSpellName(ns.FISHING_SPELL_ID)`
---@return PagleQoLKeyTarget?
function ns.KeyTarget(action, fishingName)
	if action == "reel" then
		return { kind = "command", value = "INTERACTTARGET" }
	elseif action == "cast" and fishingName then
		return { kind = "spell", value = fishingName }
	end
	return nil
end

--- The Fishing key's overrides: the keys bound to it, each pointed at `target`. With no target, no key is.
---@class PagleQoLArming
---@field keys string[]
---@field target PagleQoLKeyTarget?

--- The overrides for `keys` (as `GetBindingKey` returns them, QOL-R11) and `target`. With no key or no target,
--- there is nothing to arm.
---@param keys string[]
---@param target PagleQoLKeyTarget?
---@return PagleQoLArming
function ns.Arming(keys, target)
	if #keys == 0 or not target then
		return { keys = {}, target = nil }
	end
	return { keys = keys, target = target }
end

--- Whether two armings set the same overrides, so going from one to the other needs no re-point (QOL-R25).
---@param a PagleQoLArming
---@param b PagleQoLArming
---@return boolean
function ns.SameArming(a, b)
	if #a.keys ~= #b.keys then
		return false
	end
	for i, key in ipairs(a.keys) do
		if b.keys[i] ~= key then
			return false
		end
	end
	if a.target == nil or b.target == nil then
		return a.target == b.target
	end
	return a.target.kind == b.target.kind and a.target.value == b.target.value
end

local MODIFIERS = { "ALT", "CTRL", "SHIFT", "META" }

--- A binding key without its modifiers ("SHIFT-F" → "F"), the part `IsKeyDown` takes (QOL-R26).
---@param key string
---@return string
function ns.KeyWithoutModifiers(key)
	local stripped
	repeat
		stripped = nil
		for _, modifier in ipairs(MODIFIERS) do
			stripped = stripped or key:match("^" .. modifier .. "%-(.+)$")
		end
		key = stripped or key
	until not stripped
	return key
end
