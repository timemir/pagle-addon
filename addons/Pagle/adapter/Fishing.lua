---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Observing fishing (LOG-R2–R9): the client's fishing signals, fed to the Cast state machine (logic/Fishing.lua),
-- which records each Cast that ends caught or got away to the Catch log and tells Modules. Nothing here checks
-- restriction: recording goes on in combat (LOG-R93). Its own owner, so no other Core file's registration replaces
-- these.
local OWNER = "Pagle fishing"

--- Payload of `CastStarted`: none (LOG-R2).
---@alias PagleCastStartedHandler fun(event: "CastStarted")
--- Payload of `Catch`: one Catch of the Cast just recorded, in item order (LOG-R9).
---@alias PagleCatchHandler fun(event: "Catch", catch: PagleCatch)
--- Payload of `CastEnded`: how the Cast ended, and its record, as `Pagle.IterateCatches` yields it; nil when
--- interrupted, which records nothing (LOG-R7, LOG-R9, LOG-R43).
---@alias PagleCastEndedHandler fun(event: "CastEnded", outcome: "caught"|"gotAway"|"interrupted", cast: PagleCast?)
--- Payload of `FishingStateChanged`: the new state (LOG-R9).
---@alias PagleFishingStateChangedHandler fun(event: "FishingStateChanged", state: PagleFishingState)

-- Records a Cast that ended caught or got away (LOG-R9 steps 1 and 2): takes the Cast snapshot (LOG-R20), adds the
-- items, and appends the C1 entry for the current character at the snapshot's server time, then its diagnostics
-- entry (LOG-R81), and hands it to the projections live (LOG-R9 step 4). Returns the record every reader will see, or
-- nil before PLAYER_LOGIN, when no character is current.
---@param outcome "caught"|"gotAway"
---@param items PagleLootItem[]
---@param startedAt number? GetTime() when the Cast's channel started
---@param area PagleDevArea? the area a synthetic Cast (/pagle dev catch) is in instead of the current one
---@return PagleCast?
local function recordCast(outcome, items, startedAt, area)
	local char = ns.angler and ns.angler.current
	if not char then
		return nil
	end
	local snapshot, unresolved = ns.TakeSnapshot()
	if area then
		snapshot.zone, snapshot.subzone, unresolved = area.zone, area.subzone, nil
	end
	local cast = ns.catchLog:Append({
		kind = "cast",
		char = char,
		time = snapshot.time,
		outcome = outcome,
		conditions = snapshot,
		items = items,
	})
	---@cast cast PagleCast
	ns.AddCastDiagnostic(cast, unresolved, startedAt)
	ns.sessions:Cast() -- LOG-R9 step 3: SessionEnded still due, then SessionStarted
	ns.projections:Live(cast) -- LOG-R9 step 4, before Catch and CastEnded (LOG-R73)
	return cast
end

--- Core's Cast state machine, as ns.fishing: `/pagle dev catch` records through it too (logic/Wiring.lua's WireDev).
local fishing = ns.NewFishing({
	isFishingSpell = ns.IsFishingChannel,
	record = recordCast,
	fire = ns.Fire,
})
ns.fishing = fishing

-- Every offered item in the open loot window, in slot order (LOG-R3, LOG-R8).
---@return PagleLootItem[]
local function readLoot()
	local items = {}
	local count = ns.UnlessSecret(issecretvalue, GetNumLootItems()) or 0
	for slot = 1, count do
		local _, _, quantity, currencyID, _, _, _, _, _, isCoin = GetLootSlotInfo(slot)
		local item = ns.LootItem(issecretvalue, GetLootSlotLink(slot), quantity, currencyID, isCoin)
		if item then
			items[#items + 1] = item
		end
	end
	return items
end

-- The game's "fish got away" text (LOG-R6): a UI info message on Forever, a UI error or a system message as fallbacks.
---@param message any
local function escaped(message)
	if not issecretvalue(message) and message == ERR_FISH_ESCAPED then
		fishing:Escaped(GetTime())
	end
end

-- The spell Fishing's ranks share a name with (QOL-R24).
local FISHING = 7620

Pagle.RegisterUnitEvent(OWNER, "UNIT_SPELLCAST_CHANNEL_START", "player", function(_, _, _, spellID)
	spellID = ns.UnlessSecret(issecretvalue, spellID)
	fishing:ChannelStarted(spellID, GetTime())
	-- `/pagle dev probe`'s check 21 (#261, LOG-R2): while dev mode is on, each channel named as Fishing is, listed or
	-- not. After the Cast has its start, and guarded, so a client whose GetSpellName errors never loses it (LOG-R9).
	if spellID and ns.probeChannels and ns.db and ns.db.global.dev then
		local named, name = pcall(C_Spell.GetSpellName, spellID)
		local fishingNamed, fishingName = pcall(C_Spell.GetSpellName, FISHING)
		if named and fishingNamed then
			ns.probeChannels:Note(
				spellID,
				ns.UnlessSecret(issecretvalue, name),
				ns.UnlessSecret(issecretvalue, fishingName)
			)
		end
	end
end)

Pagle.RegisterUnitEvent(OWNER, "UNIT_SPELLCAST_CHANNEL_STOP", "player", function(_, _, _, spellID)
	local graceEnded = fishing:ChannelStopped(ns.UnlessSecret(issecretvalue, spellID), GetTime())
	if graceEnded then
		C_Timer.After(ns.FISHING_GRACE, graceEnded)
	end
end)

-- LOOT_OPENED is never used: it fires only with auto-loot off (LOG-R4).
Pagle.RegisterEvent(OWNER, "LOOT_READY", function()
	fishing:LootReady(ns.UnlessSecret(issecretvalue, IsFishingLoot()), readLoot, GetTime())
end)

Pagle.RegisterEvent(OWNER, "LOOT_CLOSED", function()
	fishing:LootClosed(GetTime())
end)

Pagle.RegisterEvent(OWNER, "UI_INFO_MESSAGE", function(_, _, message)
	escaped(message)
end)

Pagle.RegisterEvent(OWNER, "UI_ERROR_MESSAGE", function(_, _, message)
	escaped(message)
end)

Pagle.RegisterEvent(OWNER, "CHAT_MSG_SYSTEM", function(_, text)
	escaped(text)
end)

--- The fishing state (LOG-R2, LOG-R3): `"channeling"` from a fishing channel until its Cast ends (through the grace
--- time after the channel stops), `"looting"` from a fishing loot window's Cast until `LOOT_CLOSED`, `"idle"`
--- otherwise. `FishingStateChanged` fires whenever it changes.
---@return PagleFishingState
function Pagle.GetFishingState()
	return fishing:GetState()
end
