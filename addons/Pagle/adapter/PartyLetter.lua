---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The party letter (announcements.md › The party letter, ANN-R113–R116; from 1.5.3, #655): party sharing, showing
-- party moments and cheers are off until the player answers it (adapter/Party.lua's ns.PartyOption reads the answer).
-- It goes through Core's letter service (ONB-R15–R17), Core's own letter `core.party`, so it has the Letter's frame,
-- seal, gates and "A letter for you", one letter at a time. It is sent mid-session, whenever its reason holds: a
-- Pagle groupmate in the player's zone while the player fishes (ANN-R114). Its three buttons are Fish together, Not
-- now and No thanks (ANN-R115): the service has two, so the frame's third and the words written as it shows come from
-- adapter/Letter.lua's ns.letterExtras, and the answer is kept here, in PagleDB.profile.party, beside the switches it
-- sets. Every file in logic/, the letter service's own included, is hashed, and a 1.5.x patch changes none. Loaded by
-- adapter/Settings.xml, after adapter/Party.lua and before adapter/Letter.lua: it reaches ns.letter, ns.onboarding and
-- ns.letterExtras only when it runs.
local OWNER = "Pagle party letter"

--- The party letter's id among the letters Core sends (ONB-R15): Core's own, as the onboarding Letter's is.
ns.PARTY_LETTER = "core.party"

-- Tunables (announcements.md › Tunables): how recently the player must have cast for the letter to ask, the party
-- window of LOG-R113 (ANN-R114); how long Not now keeps it from asking again (ANN-R115).
local WINDOW = 300
local AGAIN = 24 * 60 * 60

-- The zone the tour's sample and the dev command name when the client can't name the player's (ANN-R116).
local SAMPLE_ZONE = "Elwynn Forest"

local ID = ns.PARTY_LETTER

-- GetTime() of the player's latest cast this login (CastStarted), or nil before one.
local castAt

-- Whether ns.letter knows the letter yet (registered at Core's ADDON_LOADED).
local registered = false

-- `value`, or nil if it is a secret (CORE-R31).
local function unsecret(value)
	return ns.UnlessSecret(issecretvalue, value)
end

-- A uiMap's name in the client's language, or nil.
---@param map integer?
---@return string?
local function mapName(map)
	local info = type(map) == "number" and C_Map.GetMapInfo(map) or nil
	local name = info and unsecret(info.name)
	return type(name) == "string" and name ~= "" and name or nil
end

-- Whether the player has answered (ANN-R113, ANN-R115): Fish together, No thanks, a 1.5.2 choice kept, or Share or
-- Show changed by hand in Settings.
---@param party table?
---@return boolean
local function answered(party)
	return party ~= nil
		and (party.letter == "accepted" or party.letter == "declined" or party.share ~= nil or party.show ~= nil)
end

-- Whether the letter may ask now (ANN-R115): not answered, and no Not now in the last AGAIN seconds.
---@return boolean
local function mayAsk()
	local party = ns.PartyStored()
	if answered(party) then
		return false
	end
	local at = party and party.letter == "later" and party.laterAt
	return not (type(at) == "number" and GetServerTime() < at + AGAIN)
end

--- Whether the party letter's reason holds now (ANN-R114): it may ask, the player cast in the last 300 s, and a Pagle
--- groupmate is in the player's party and zone. The letter service asks it again as the letter is about to show
--- (`isDue`, ONB-R17), so a reason that passed while the letter waited (combat, another letter) shows nothing.
---@return boolean
function ns.PartyLetterIsDue()
	if not mayAsk() or not castAt or GetTime() - castAt > WINDOW then
		return false
	end
	return ns.PartyGroupmateHere() ~= nil
end

-- The letter service's state of the letter (PagleDB.global.onboarding.letters[id], ONB-R16) made fresh for an ask
-- (ANN-R115): the party letter keeps its answer in PagleDB.profile.party, so the service's own two showings before
-- `declined` never decide it. A letter already waiting or on screen keeps `waiting`.
local function freshState()
	local letters = ns.onboarding:State().letters
	if type(letters) == "table" and letters[ID] ~= "waiting" then
		letters[ID] = nil
	end
end

--- Sends the party letter when its reason holds (ANN-R114): called as the player casts, as a groupmate is found to
--- run Pagle, as the roster settles and as the player changes zone. The service shows it once its gates let it
--- (ONB-R10, ONB-R17): no restriction (combat), no instance, no other letter on screen, not twice in one login.
function ns.CheckPartyLetter()
	if not registered or not ns.PartyLetterIsDue() then
		return
	end
	freshState()
	ns.letter:Send(ID)
end

Pagle.RegisterCallback(OWNER, "CastStarted", function()
	castAt = GetTime()
	ns.CheckPartyLetter()
end)
Pagle.RegisterEvent(OWNER, "ZONE_CHANGED_NEW_AREA", function()
	ns.CheckPartyLetter()
end)

--- The party letter's words as it shows (ANN-R116): the Pagle groupmate in the player's zone and that zone, or, for the
--- tour's sample and the dev command, the made-up Kukli Emnabi in the player's zone (Elwynn Forest where the client
--- can't name it).
---@return { kicker: string, text: string, confirm: string, later: string, decline: string }
function ns.PartyLetterWords()
	local L = ns.L
	local member, map = ns.PartyGroupmateHere()
	local zone = mapName(map) or mapName(unsecret((C_Map.GetBestMapForUnit("player")))) or SAMPLE_ZONE
	return {
		kicker = L.PARTY_LETTER_KICKER,
		text = ns.RenderText(L.PARTY_LETTER_LINE, { name = member and member.name or ns.PARTY_DEV_NAME, zone = zone }),
		confirm = L.PARTY_LETTER_YES,
		later = L.PARTY_LETTER_LATER,
		decline = L.PARTY_LETTER_NO,
	}
end

-- The answers (ANN-R115), each stored in PagleDB.profile.party. Fish together: every party feature on, as explicit
-- choices (from 1.6 Party Hunts too, SET-R35).
local function fishTogether()
	local party = ns.PartyStore()
	party.share, party.show, party.sounds = true, true, true
	party.letter, party.laterAt = "accepted", nil
end

-- Not now: asked again the next time the reason holds, AGAIN seconds on at the soonest.
local function notNow()
	local party = ns.PartyStore()
	party.letter, party.laterAt = "later", GetServerTime()
end

-- No thanks: never asked again; the switches stay as they are, off unless set by hand.
local function noThanks()
	local party = ns.PartyStore()
	party.letter, party.laterAt = "declined", nil
end

-- Registered at Core's ADDON_LOADED, before PLAYER_LOGIN's ModulesChanged adds a tour stop for each letter
-- (ONB-R84): the service keeps a copy of these words, and the frame writes the live ones as it shows
-- (ns.letterExtras).
Pagle.RegisterEvent(OWNER, "ADDON_LOADED", function(_, name)
	if name ~= "Pagle" then
		return
	end
	Pagle.UnregisterEvent(OWNER, "ADDON_LOADED")
	-- The sample's words, read from nothing of the client's: the live ones are written as it shows.
	local L = ns.L
	local problem = ns.letter:Register(ID, {
		kicker = L.PARTY_LETTER_KICKER,
		text = ns.RenderText(L.PARTY_LETTER_LINE, { name = ns.PARTY_DEV_NAME, zone = SAMPLE_ZONE }),
		confirm = L.PARTY_LETTER_YES,
		later = L.PARTY_LETTER_LATER,
		onConfirm = fishTogether,
		isDue = ns.PartyLetterIsDue,
	}, ns.CORE_OWNER)
	if problem then
		error(problem)
	end
	ns.letterExtras[ID] = { words = ns.PartyLetterWords, onLater = notNow, onDecline = noThanks }
	registered = true
end)

--- `/pagle dev party letter [reset]` (ANN-R116), behind the dev switch: the party letter on screen now with the made-up
--- groupmate, whatever its answer and its reason, its buttons acting as ever (as `/pagle dev onboarding letter`,
--- ONB-R83); `reset` forgets the answer, so the player is not asked yet and every party switch reads off again.
---@param args string
function ns.RunPartyLetterDev(args)
	local L = ns.L
	if ns.ParseSlash(args) == "reset" then
		local party = ns.PartyStored()
		if party then
			party.share, party.show, party.letter, party.laterAt = nil, nil, nil, nil
		end
		local letters = ns.onboarding:State().letters
		if type(letters) == "table" then
			letters[ID] = nil
		end
		print(L.DEV_PARTY_LETTER_RESET)
		return
	end
	-- a fresh state, so each button steps it and the answer is written (adapter/Letter.lua)
	freshState()
	ns.letter:ShowNow(ID)
	print(ns.RenderText(L.DEV_PARTY_LETTER, { name = ns.PARTY_DEV_NAME }))
end
