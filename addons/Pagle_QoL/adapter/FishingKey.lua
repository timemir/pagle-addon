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

-- The override owner (QOL-R11); its OnUpdate runs the tick and the wait for a key to be up. Nil until createFrame
-- makes it (QOL-R33); evaluate and ns.DisarmFishingKey do nothing until then.
local frame ---@type Frame
-- PagleQoLActionButton, the secure button a lure's override clicks (QOL-R24); made with frame (QOL-R33).
local button ---@type Button
local loggedIn = false
local lootOpen = false -- QOL-R28
local channeling = false -- QOL-R22
local readChannel = true -- whether the next arm reads UnitChannelInfo, as after a load (QOL-R22)
local keys = {} ---@type string[] the Fishing key's bound keys, read at PLAYER_LOGIN and on UPDATE_BINDINGS (QOL-R25)
local current = ns.Arming({}, nil) -- the overrides set now
local waitingForKeyUp = false -- QOL-R26
local updating = false -- whether frame's OnUpdate runs
local sinceTick = 0 -- seconds since the last evaluation
local disarming = false -- inside ns.DisarmFishingKey, whose own UPDATE_BINDINGS must not re-arm (QOL-R31)
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

-- The Fishing stretch (adapter/Stretch.lua) starts only while armed and ends when the pole comes off (QOL-R61).
ns.IsArmed, ns.PoleInHand = isArmed, poleInHand

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
	local pole = poleInHand()
	local lure, lured = ns.ReadLures(pole)
	return {
		armed = true,
		lootOpen = lootOpen,
		casting = UnitCastingInfo("player") ~= nil,
		channelingFishing = channeling,
		poleInHand = pole,
		lured = lured,
		lure = lure,
	}
end

-- Registers PagleQoLActionButton's clicks so a press fires it once (QOL-R27). Under lockdown the secure button
-- can't change; the arm after it reads the CVar again (QOL-R32).
local function registerClicks()
	if button and not InCombatLockdown() then
		button:RegisterForClicks(ns.ClickRegistration(GetCVar("ActionButtonUseKeyDown")))
	end
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
	-- Arming re-reads the click registration (QOL-R27), and tells the lures what the key applies (QOL-R29).
	registerClicks()
	ns.LureTargeted(target.item)
	if target.kind == "click" then
		-- An item use on the pole in hand: no target slot and no macro (QOL-R52, probe B4).
		button:SetAttribute("type", "item")
		button:SetAttribute("item", "item:" .. target.item)
	end
	for _, key in ipairs(want.keys) do
		if target.kind == "spell" then
			SetOverrideBindingSpell(frame, true, key, target.value)
		elseif target.kind == "click" then
			SetOverrideBindingClick(frame, true, key, target.value, "LeftButton")
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
	if not loggedIn or disarming or not frame then
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
	local state = ladderState(armed, fishingName)
	local want = ns.Arming(keys, ns.KeyTarget(ns.NextAction(state), fishingName, state.lure))
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

--- Re-evaluates the next action now (QOL-R25): for a QoL setting change, and a lure's result (QOL-R29).
ns.EvaluateFishingKey = evaluate

--- Clears the Fishing key's overrides now, held key or not, and arms nothing (QOL-R31). adapter/Combat.lua calls it
--- as restriction starts, before lockdown; the end of restriction re-evaluates (QOL-R32).
function ns.DisarmFishingKey()
	-- Before PLAYER_LOGIN nothing is armed, and nothing is touched (QOL-R33).
	if not frame or not loggedIn then
		return
	end
	waitingForKeyUp = false
	-- With nothing set there is nothing to clear, and standing down makes no binding call at all (QOL-R82).
	if not current.target then
		return
	end
	disarming = true
	repoint(ns.Arming(keys, nil))
	disarming = false
end

---@param event string
local function onEvent(event)
	-- The conflict check comes right before the first arm, so QoL never arms and then stands down (QOL-R33).
	if event == "PLAYER_LOGIN" then
		ns.CheckConflicts()
	end
	if event == "PLAYER_LOGIN" or event == "UPDATE_BINDINGS" then
		keys = { GetBindingKey("PAGLE_FISHING_KEY") }
		-- The client fires UPDATE_BINDINGS before PLAYER_LOGIN too; QoL first arms at PLAYER_LOGIN (QOL-R33).
		loggedIn = loggedIn or event == "PLAYER_LOGIN"
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

-- The override owner and PagleQoLActionButton are made at OnInitialize, or, after a /reload in combat, at
-- RestrictionChanged(false); until then QoL stays disarmed (QOL-R33). The button has no parent, size or anchor,
-- so it is never shown (QOL-R24); a click binding still clicks it.
local function createFrame()
	if not frame and not Pagle.IsRestricted() then
		frame = CreateFrame("Frame")
		button = CreateFrame("Button", ns.ACTION_BUTTON, nil, "SecureActionButtonTemplate") --[[@as Button]]
		registerClicks()
	end
end

--- Creates the override owner and listens for every re-evaluation trigger (QOL-R25). QoL's OnInitialize calls it
--- once it has registered; the first arm waits for PLAYER_LOGIN.
function ns.StartFishingKey()
	createFrame()
	for _, event in ipairs(EVENTS) do
		Pagle.RegisterEvent(OWNER, event, onEvent)
	end
	for _, event in ipairs(PLAYER_EVENTS) do
		Pagle.RegisterUnitEvent(OWNER, event, "player", onEvent)
	end
	-- ActionButtonUseKeyDown may have changed (QOL-R27). Every CVAR_UPDATE re-reads it: the payload's first value is
	-- the CVar's name on Retail but has been an event name instead, and the read is cheap either way.
	Pagle.RegisterEvent(OWNER, "CVAR_UPDATE", registerClicks)
	Pagle.RegisterCallback(OWNER, "CastStarted", function()
		channeling = true
		evaluate()
	end)
	for _, event in ipairs({ "CastEnded", "FishingStateChanged" }) do
		Pagle.RegisterCallback(OWNER, event, function()
			evaluate()
		end)
	end
	-- Leaving restriction re-evaluates and re-arms (QOL-R32); it starts in adapter/Combat.lua (QOL-R31).
	Pagle.RegisterCallback(OWNER, "RestrictionChanged", function()
		createFrame()
		evaluate()
	end)
end
