---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Party Catches on the client (catch-log.md › Party Catches, LOG-R110–R126; from 1.6, pagle-2026j, #644): the party
-- catch message sent for each of the Angler's own caught Casts, and the groupmates' received, checked and logged, over
-- logic/PartyCatches.lua. The message rides its own prefix (ns.PARTY_CATCH_PREFIX) and the party toasts' send queue
-- (adapter/Party.lua's ns.SendPartyMessage, LOG-R112), and the receiver matches its sender as the party toasts do
-- (ns.PartyGroupmate). Loaded from the TOC after adapter/Party.lua. Its own owner on Core's
-- bus.
local OWNER = "Pagle party catches"

---@type PagleHost
local host = ns.host

--- Payload of `PartyCatch`: the Party Catch just logged, live, with the groupmate's name and source ID (LOG-R115,
--- LOG-R116).
---@alias PaglePartyCatchHandler fun(event: "PartyCatch", record: PaglePartyCatch)

-- The prefix, at each load: registration doesn't survive a /reload (LOG-R110). A Pagle before 1.6 never registers
-- it, so the client never hands it a party catch message (LOG-R124).
C_ChatInfo.RegisterAddonMessagePrefix(ns.PARTY_CATCH_PREFIX)

-- `value`, or nil if it is a secret (CORE-R31).
local function unsecret(value)
	return ns.UnlessSecret(issecretvalue, value)
end

-- Whether `sender` is the player, the client's echo of their own message (LOG-R113 item 1): by GUID where the client
-- resolves the sender's name, else by first name.
---@param sender string?
---@return boolean
local function isPlayer(sender)
	if type(sender) ~= "string" then
		return false
	end
	local guid = unsecret((UnitGUID(sender)))
	if type(guid) == "string" then
		return guid == unsecret((UnitGUID("player")))
	end
	return ns.PartySenderName(sender) == unsecret((UnitName("player")))
end

local partyCatches = ns.NewPartyCatches({
	isPlayer = isPlayer,
	-- The Party Hunts setting (LOG-R121, SET-R35): from 1.6 off until the party letter is accepted (ANN-R113).
	on = function()
		return ns.PartyHuntsOn()
	end,
	inParty = function()
		return ns.InHomeParty()
	end,
	groupmate = function(sender)
		return ns.PartyGroupmate(sender)
	end,
	catchLog = host.catchLog,
	character = host.character,
	now = host.serverTime,
	wants = function(record)
		return ns.projections:WantsPartyCatch(record)
	end,
	append = function(copy, name, sourceId)
		return ns.RecordPartyCatch(copy, name, sourceId)
	end,
	-- Ahead of the party toasts waiting, and dropped once its Cast is the max party delay old (LOG-R112).
	send = function(text, castTime)
		ns.SendPartyMessage(
			text,
			{ prefix = ns.PARTY_CATCH_PREFIX, first = true, expires = castTime + ns.PARTY_MAX_DELAY }
		)
	end,
})

--- Sends the party catch message for `cast`, one of the Angler's own Casts just appended (LOG-R111), unless
--- `synthetic` (`/pagle dev catch`). adapter/Fishing.lua calls it after each Cast it records; it never waits on, nor
--- delays, recording (LOG-R112).
---@param cast PagleCast
---@param synthetic boolean?
function ns.SharePartyCatch(cast, synthetic)
	partyCatches:Send(cast, synthetic)
end

-- What arrives on the party catch prefix (LOG-R113): read on the party channel only, the receiver's checks in order,
-- anything else dropped without a word.
Pagle.RegisterEvent(OWNER, "CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
	if unsecret(prefix) ~= ns.PARTY_CATCH_PREFIX or unsecret(channel) ~= "PARTY" then
		return
	end
	partyCatches:Receive(unsecret(text), unsecret(sender))
end)
