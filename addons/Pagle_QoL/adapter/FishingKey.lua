if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The Fishing key (QOL-R10, QOL-R11): QoL reads the game, picks the next action (logic/FishingKey.lua) and points
-- a priority override binding on each key bound to PAGLE_FISHING_KEY at its target. It changes only bindings
-- (QOL-R5); what it reads, it uses only to choose (QOL-R4).

-- The owner of QoL's Core event callbacks and WoW event registrations.
local OWNER = "Pagle_QoL Fishing key"
--- Seconds between re-evaluations while armed (qol.md › Tunables, QOL-R25).
local TICK = 0.5

local frame ---@type Frame The override owner (QOL-R11); its OnUpdate runs the tick and the wait for a key to be up.
local loggedIn = false
local lootOpen = false -- QOL-R28
local channeling = false -- QOL-R22
local readChannel = true -- whether the next arm reads UnitChannelInfo, as after a load (QOL-R22)
local keys = {} ---@type string[] the Fishing key's bound keys, read at PLAYER_LOGIN and on UPDATE_BINDINGS (QOL-R25)
local current = ns.Arming({}, nil) -- the overrides set now
local waitingForKeyUp = false -- QOL-R26
local updating = false -- whether frame's OnUpdate runs
local sinceTick = 0 -- seconds since the last evaluation
local evaluate

--- QoL is armed while it is registered, isn't standing down (QOL-R82) and isn't restricted (QOL-R30).
---@return boolean
local function isArmed()
	return ns.Module ~= nil and loggedIn and not ns.IsStandingDown() and not Pagle.IsRestricted()
end

---@return boolean
local function poleInHand()
	local itemID = GetInventoryItemID("player", 16)
	if not itemID then
		return false
	end
	local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
	return ns.IsFishingPole(classID, subclassID)
end

-- The ladder's view of the game now (QOL-R20). Nothing is read while disarmed.
---@param armed boolean
---@param fishingName string?
---@return PagleQoLLadderState
local function ladderState(armed, fishingName)
	if not armed then
		return { armed = false }
	end
	if readChannel then
		readChannel = false
		channeling = fishingName ~= nil and UnitChannelInfo("player") == fishingName
	end
	return {
		armed = true,
		lootOpen = lootOpen,
		casting = UnitCastingInfo("player") ~= nil,
		channelingFishing = channeling,
		poleInHand = poleInHand(),
	}
end

-- Whether any key of either arming is held down (QOL-R26).
---@param a PagleQoLArming
---@param b PagleQoLArming
---@return boolean
local function keyHeld(a, b)
	for _, arming in ipairs({ a, b }) do
		for _, key in ipairs(arming.keys) do
			if IsKeyDown(ns.KeyWithoutModifiers(key)) then
				return true
			end
		end
	end
	return false
end

-- Clears the old overrides, then sets the new ones (QOL-R11, QOL-R98). `current` changes first: each call fires
-- UPDATE_BINDINGS, and the re-evaluation that runs must find nothing to do (QOL-R25).
---@param want PagleQoLArming
local function repoint(want)
	current = want
	ClearOverrideBindings(frame)
	local target = want.target
	if not target then
		return
	end
	for _, key in ipairs(want.keys) do
		if target.kind == "spell" then
			SetOverrideBindingSpell(frame, true, key, target.value)
		else
			SetOverrideBinding(frame, true, key, target.value)
		end
	end
end

---@param _ Frame
---@param elapsed number
local function onUpdate(_, elapsed)
	sinceTick = sinceTick + elapsed
	if waitingForKeyUp or sinceTick >= TICK then
		evaluate()
	end
end

-- The tick runs only while armed, and the per-frame check only while a re-point waits (QOL-R25, QOL-R26).
---@param armed boolean
local function setOnUpdate(armed)
	local running = armed or waitingForKeyUp
	if running ~= updating then
		updating = running
		frame:SetScript("OnUpdate", running and onUpdate or nil)
	end
end

--- Picks the next action and re-points the overrides if they differ from what is set (QOL-R20, QOL-R25).
function evaluate()
	if not loggedIn then
		return
	end
	sinceTick = 0
	local armed = isArmed()
	-- Every override change that falls due while restricted is skipped; the end of restriction re-evaluates (QOL-R32).
	if Pagle.IsRestricted() then
		waitingForKeyUp = false
		setOnUpdate(false)
		return
	end
	local fishingName = C_Spell.GetSpellName(ns.FISHING_SPELL_ID)
	local action = ns.NextAction(ladderState(armed, fishingName))
	local want = ns.Arming(keys, ns.KeyTarget(action, fishingName))
	if ns.SameArming(current, want) then
		waitingForKeyUp = false
	elseif keyHeld(current, want) then
		waitingForKeyUp = true
	else
		waitingForKeyUp = false
		repoint(want)
	end
	setOnUpdate(armed)
end

---@param event string
local function onEvent(event)
	-- The conflict check comes right before the first arm, so QoL never arms and then stands down (QOL-R33).
	if event == "PLAYER_LOGIN" then
		ns.CheckConflicts()
	end
	if event == "PLAYER_LOGIN" or event == "UPDATE_BINDINGS" then
		keys = { GetBindingKey("PAGLE_FISHING_KEY") }
		loggedIn = true
	elseif event == "LOOT_READY" then
		lootOpen = true
	elseif event == "LOOT_CLOSED" then
		lootOpen = false
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		channeling = false
	end
	evaluate()
end

local EVENTS = {
	"PLAYER_LOGIN",
	"LOOT_READY",
	"LOOT_CLOSED",
	"BAG_UPDATE_DELAYED",
	"PLAYER_EQUIPMENT_CHANGED",
	"PLAYER_MOUNT_DISPLAY_CHANGED",
	"EQUIPMENT_SETS_CHANGED",
	"UPDATE_BINDINGS",
}
local PLAYER_EVENTS = {
	"UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_START",
	"UNIT_SPELLCAST_STOP",
	"UNIT_INVENTORY_CHANGED",
}

--- Creates the override owner and listens for every re-evaluation trigger (QOL-R25). QoL's OnInitialize calls it
--- once it has registered; the first arm waits for PLAYER_LOGIN.
function ns.StartFishingKey()
	frame = CreateFrame("Frame")
	for _, event in ipairs(EVENTS) do
		Pagle.RegisterEvent(OWNER, event, onEvent)
	end
	for _, event in ipairs(PLAYER_EVENTS) do
		Pagle.RegisterUnitEvent(OWNER, event, "player", onEvent)
	end
	Pagle.RegisterCallback(OWNER, "CastStarted", function()
		channeling = true
		evaluate()
	end)
	for _, event in ipairs({ "CastEnded", "FishingStateChanged", "RestrictionChanged" }) do
		Pagle.RegisterCallback(OWNER, event, function()
			evaluate()
		end)
	end
end
