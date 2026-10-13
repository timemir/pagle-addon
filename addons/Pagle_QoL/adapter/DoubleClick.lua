if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- The double-click (QOL-R13–R15): QoL hears the mouse, and on a qualifying right click on the game world opens the
-- double-click window, a priority override on BUTTON2 pointing at the next action's target (logic/DoubleClick.lua
-- decides). The Fishing key's evaluation re-points it (adapter/FishingKey.lua). It changes only bindings (QOL-R5);
-- the second click's press does the action.

-- The owner of the double-click's WoW event registrations.
local OWNER = "Pagle_QoL double-click"

-- BUTTON2's override owner, separate from the Fishing key's (QOL-R13); its OnUpdate runs only while a window is open.
-- Nil until ensureFrame makes it (QOL-R33); nothing here touches a binding until then.
local frame ---@type Frame
local window = ns.NewDoubleClickWindow()
local current = ns.Arming({}, nil) -- BUTTON2's override set now
local updating = false -- whether frame's OnUpdate runs

-- The owner is made at OnInitialize or, after a /reload in combat, at the evaluation that RestrictionChanged(false)
-- runs (QOL-R33).
local function ensureFrame()
	if not frame and not Pagle.IsRestricted() then
		frame = CreateFrame("Frame")
	end
end

-- Clears BUTTON2's override, then sets the new one (QOL-R13). `current` changes first: each call fires
-- UPDATE_BINDINGS, and the re-evaluation that runs must find nothing to do (QOL-R25).
---@param want PagleQoLArming
local function repoint(want)
	current = want
	ClearOverrideBindings(frame)
	local target = want.target
	if not target then
		return
	end
	-- PagleQoLActionButton's clicks and item, and the lure it applies, as when the Fishing key arms (QOL-R27, QOL-R29).
	ns.ArmActionButton(target)
	if target.kind == "spell" then
		SetOverrideBindingSpell(frame, true, ns.DOUBLE_CLICK_KEY, target.value)
	elseif target.kind == "click" then
		SetOverrideBindingClick(frame, true, ns.DOUBLE_CLICK_KEY, target.value, "LeftButton")
	else
		SetOverrideBinding(frame, true, ns.DOUBLE_CLICK_KEY, target.value)
	end
end

local setOnUpdate

-- Closes the window and clears BUTTON2 (QOL-R13). Under lockdown the override stays, and the evaluation at the end of
-- restriction clears it (QOL-R31, QOL-R32).
local function close()
	window:Close()
	if current.target and not InCombatLockdown() and not Pagle.IsRestricted() then
		repoint(ns.Arming({}, nil))
	end
	setOnUpdate()
end

-- GetTime() holds one value through a frame, so the window sees the frames after its closing mouse-up (QOL-R13).
local function onUpdate()
	if window:Due(GetTime()) then
		close()
	end
end

-- The frame runs OnUpdate only while a window is open.
function setOnUpdate()
	local running = window:IsOpen()
	if frame and running ~= updating then
		updating = running
		frame:SetScript("OnUpdate", running and onUpdate or nil)
	end
end

--- Points an open double-click window's BUTTON2 at the double-click's target for the evaluation the Fishing key just
--- made, or closes the window when the double-click isn't live any more (QOL-R13, QOL-R14). It re-points only when
--- the target changes (QOL-R25). adapter/FishingKey.lua calls it from each evaluation while not restricted.
---@param state PagleQoLLadderState
---@param fishingName string? `C_Spell.GetSpellName(ns.FISHING_SPELL_ID)`
function ns.PointDoubleClick(state, fishingName)
	ensureFrame()
	if not frame then
		return
	end
	-- Without the gear step: its action has no BUTTON2 target (QOL-R15).
	local target = ns.ClickTarget(ns.NextAction(state), fishingName, state.lure)
	if window:IsOpen() and not ns.DoubleClickLive(ns.CurrentInput(), state, target) then
		window:Close()
	end
	local want = window:IsOpen() and ns.Arming({ ns.DOUBLE_CLICK_KEY }, target) or ns.Arming({}, nil)
	if not ns.SameArming(current, want) then
		repoint(want)
	end
	setOnUpdate()
end

--- Closes the window and clears BUTTON2's override now, and opens nothing (QOL-R31). adapter/Combat.lua calls it as
--- restriction starts, before lockdown, with the Fishing key's disarm.
function ns.DisarmDoubleClick()
	if not frame then
		return
	end
	window:Close()
	-- With nothing set there is nothing to clear, so standing down makes no binding call (QOL-R82).
	if current.target then
		repoint(ns.Arming({}, nil))
	end
	setOnUpdate()
end

---@param _ string
---@param button string
local function onMouseDown(_, button)
	window:MouseDown(button, GetTime())
end

-- A qualifying click's mouse-up opens the window when the double-click is live, pointing BUTTON2 at the next action's
-- target evaluated now (QOL-R13, QOL-R14). Restricted or disarmed, it opens nothing (QOL-R30).
---@param _ string
---@param button string
local function onMouseUp(_, button)
	local onWorld = button == "RightButton" and ns.OnGameWorld(GetMouseFoci(), WorldFrame)
	if not window:MouseUp(button, GetTime(), onWorld) or not frame or not ns.IsArmed() then
		return
	end
	window:Open(GetTime())
	ns.EvaluateFishingKey()
	-- An evaluation that set nothing found the double-click not live.
	if not current.target then
		window:Close()
	end
	setOnUpdate()
end

--- Creates BUTTON2's owner and listens to the mouse (QOL-R13, CORE-R23). QoL's OnInitialize calls it once it has
--- registered, after the Fishing key starts.
function ns.StartDoubleClick()
	ensureFrame()
	Pagle.RegisterEvent(OWNER, "GLOBAL_MOUSE_DOWN", onMouseDown)
	Pagle.RegisterEvent(OWNER, "GLOBAL_MOUSE_UP", onMouseUp)
end
