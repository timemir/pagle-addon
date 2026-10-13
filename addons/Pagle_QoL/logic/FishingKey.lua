if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The Fishing key's choices: pure logic, everything passed in (CORE-R7). adapter/FishingKey.lua reads the game
-- and sets the bindings.

--- The Fishing spell whose name the cast override uses: every rank shares it (QOL-R24).
ns.FISHING_SPELL_ID = 7620

--- The secure button the Fishing key clicks to use an item (QOL-R24): one `SecureActionButtonTemplate` button,
--- never shown.
ns.ACTION_BUTTON = "PagleQoLActionButton"

--- The button the Fishing key clicks to put the fishing set on (QOL-R24): a plain `Button` whose OnClick runs the
--- swap (QOL-R44), never shown.
ns.GEAR_BUTTON = "PagleQoLGearButton"

---@alias PagleQoLAction "nothing"|"reel"|"gear"|"lure"|"cast"

--- What the ladder reads (QOL-R20). It has steps 1–4 and 6; clams (step 5) come in Track Q step 6.
---@class PagleQoLLadderState
---@field armed boolean? QoL is armed (QOL-R30)
---@field lootOpen boolean? a loot window is open (QOL-R28)
---@field casting boolean? the player is casting a spell with a cast time (`UnitCastingInfo`)
---@field channelingFishing boolean? the player is channeling Fishing (QOL-R22)
---@field poleInHand boolean? a fishing pole is in hand (QOL-R21); the cast needs none (QOL-R23)
---@field lured boolean? the pole has a lure on, or counts as lured while a lure's result is awaited (QOL-R29)
---@field lure integer? the lure QOL-R51 picks; nil while Lures is *Off* or none is available
---@field gearReady boolean? the gear step is ready (QOL-R43)
---@field skipGear boolean? the evaluation skips the gear step, as the double-click's does (QOL-R13, QOL-R15)
---@field reelMissed boolean? the reel didn't take, so the channel's next press casts again (QOL-R35)

--- The next action: the first step of the ladder that holds (QOL-R20), so a press is one game action.
---@param state PagleQoLLadderState
---@return PagleQoLAction
function ns.NextAction(state)
	if not state.armed or state.lootOpen or state.casting then
		return "nothing"
	end
	if state.channelingFishing then
		-- Unless the reel didn't take: then the press casts again, ending the old Cast (QOL-R35).
		return state.reelMissed and "cast" or "reel"
	end
	-- The fishing set goes on before a lure, which needs the pole in hand; the double-click never equips it.
	if state.gearReady and not state.skipGear then
		return "gear"
	end
	-- After the reel and before the cast, so a lure never goes on mid-channel.
	if state.poleInHand and not state.lured and state.lure then
		return "lure"
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

--- What an override points a key at: a spell by name, a binding command, or a click on a button by name, set to
--- use `item`.
---@class PagleQoLKeyTarget
---@field kind "spell"|"command"|"click"
---@field value string
---@field item integer? the item ID the button uses, for a click

--- The Fishing key column of QOL-R24: cast by the Fishing spell's name, reel with soft-interact's
--- INTERACTTARGET, a lure by clicking ns.ACTION_BUTTON set to use it (QOL-R52), and no target (no override) for
--- nothing, or for a cast while the spell's name is unknown.
---@param action PagleQoLAction
---@param fishingName string? `C_Spell.GetSpellName(ns.FISHING_SPELL_ID)`
---@param lure integer? the lure's item ID, for the lure action
---@return PagleQoLKeyTarget?
function ns.KeyTarget(action, fishingName, lure)
	if action == "reel" then
		return { kind = "command", value = "INTERACTTARGET" }
	elseif action == "lure" and lure then
		return { kind = "click", value = ns.ACTION_BUTTON, item = lure }
	elseif action == "gear" then
		return { kind = "click", value = ns.GEAR_BUTTON }
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
	return a.target.kind == b.target.kind and a.target.value == b.target.value and a.target.item == b.target.item
end

--- Whether action buttons fire on key-down: the `ActionButtonUseKeyDown` CVar is 1. A client that doesn't know the
--- CVar fires on key-up (QOL-R27).
---@param useKeyDown string? `GetCVar("ActionButtonUseKeyDown")`
---@return boolean
function ns.UsesKeyDown(useKeyDown)
	return tonumber(useKeyDown) == 1
end

--- What ns.ACTION_BUTTON registers for, so a press fires it once (QOL-R27): clicks on key-down while the
--- `ActionButtonUseKeyDown` CVar is 1, else on key-up.
---@param useKeyDown string? `GetCVar("ActionButtonUseKeyDown")`
---@return "AnyDown"|"AnyUp"
function ns.ClickRegistration(useKeyDown)
	return ns.UsesKeyDown(useKeyDown) and "AnyDown" or "AnyUp"
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

--- How long after a reel press the reel counts as not taken, in seconds (qol.md › Tunables, the reel wait, QOL-R35).
ns.REEL_WAIT = 0.5

--- The watch on the Fishing key's reel presses (QOL-R35), on `GetTime()` values: a key seen going down while the
--- reel is armed is a reel press, and the reel wait passing after it means the reel didn't take. The adapter clears
--- it when the channel stops or starts, a loot window opens or QoL is disarmed.
---@class PagleQoLReelWatch
---@field down boolean whether a bound key was down on the last frame
---@field pressedAt number? when the waiting reel press came
---@field missed boolean the reel didn't take
local ReelWatch = {}
ReelWatch.__index = ReelWatch

--- A watch with no press waiting and no key down.
---@return PagleQoLReelWatch
function ns.NewReelWatch()
	return setmetatable({ down = false, missed = false }, ReelWatch)
end

--- One frame's look at the Fishing key. Returns true on the frame the reel wait passes after a reel press, once.
---@param reelArmed boolean the Fishing key's override is the reel now
---@param down boolean a bound key is down (`IsKeyDown` on the key without its modifiers)
---@param now number
---@return boolean
function ReelWatch:Frame(reelArmed, down, now)
	if reelArmed and down and not self.down and not self.pressedAt and not self.missed then
		self.pressedAt = now
	end
	self.down = down
	if self.pressedAt and now - self.pressedAt >= ns.REEL_WAIT then
		self.pressedAt, self.missed = nil, true
		return true
	end
	return false
end

--- Whether the reel didn't take.
---@return boolean
function ReelWatch:Missed()
	return self.missed
end

--- Drops a waiting reel press and the miss.
function ReelWatch:Clear()
	self.pressedAt, self.missed = nil, false
end
