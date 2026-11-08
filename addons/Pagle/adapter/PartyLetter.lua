---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The party letter (announcements.md › The party letter, ANN-R113–R116; from 1.5.3, #655, and from 1.6, #665): Party
-- Hunts, party sharing, showing party moments and cheers are off until the player accepts it (adapter/Party.lua's
-- ns.PartyHuntsOn and ns.PartyOption read the switches it sets). It goes through Core's letter service (ONB-R15–R17),
-- Core's own letter `core.party`, so it has the Letter's frame, seal, gates and "A letter for you", one letter at a
-- time. It is sent mid-session, whenever its reason holds: a Pagle groupmate in the player's zone while the player
-- fishes (ANN-R114). Its three buttons, Fish together, Not now and No thanks (ANN-R115), its words written as it shows
-- and its asking again a day after Not now are the service's own (ONB-R15, ONB-R16), which keeps its answer
-- account-wide. Loaded by adapter/Settings.xml, after adapter/Party.lua and before adapter/Letter.lua: it reaches
-- ns.letter and ns.onboarding only when it runs.
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

-- Whether a party switch was set by hand (ANN-R113): Party Hunts, Share or Show stored either way, by Settings or as a
-- 1.5.2 choice kept. That answers the letter, which then never asks.
---@return boolean
local function setByHand()
	local party = ns.PartyStored()
	return ns.db.profile.partyHunts ~= nil or (party ~= nil and (party.share ~= nil or party.show ~= nil))
end

--- Whether the party letter's reason holds now (ANN-R114): no party switch set by hand, the player cast in the last
--- 300 s, and a Pagle groupmate is in the player's party and zone. Whether it was answered, and when Not now lets it
--- ask again, is the letter service's (ONB-R16). The service asks it again as the letter is about to show (`isDue`,
--- ONB-R17), so a reason that passed while the letter waited (combat, another letter) shows nothing.
---@return boolean
function ns.PartyLetterIsDue()
	if setByHand() or not castAt or GetTime() - castAt > WINDOW then
		return false
	end
	return ns.PartyGroupmateHere() ~= nil
end

--- Sends the party letter when its reason holds (ANN-R114): called as the player casts, as a groupmate is found to
--- run Pagle, as the roster settles and as the player changes zone. The service shows it once its gates let it
--- (ONB-R10, ONB-R17): no restriction (combat), no instance, no other letter on screen, not twice in one login.
function ns.CheckPartyLetter()
	if not registered or not ns.PartyLetterIsDue() then
		return
	end
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
---@return PagleLetterWords
function ns.PartyLetterWords()
	local member, map = ns.PartyGroupmateHere()
	local zone = mapName(map) or mapName(unsecret((C_Map.GetBestMapForUnit("player")))) or SAMPLE_ZONE
	return {
		text = ns.RenderText(
			ns.L.PARTY_LETTER_LINE,
			{ name = member and member.name or ns.PARTY_DEV_NAME, zone = zone }
		),
	}
end

-- Fish together (ANN-R115), once the service has set the letter `opened`: every party feature on, as explicit
-- choices, Party Hunts too (SET-R35).
local function fishTogether()
	local party = ns.PartyStore()
	party.share, party.show, party.sounds = true, true, true
	ns.db.profile.partyHunts = true
end

-- Registered at Core's ADDON_LOADED, before PLAYER_LOGIN's ModulesChanged adds a tour stop for each letter
-- (ONB-R84). The service writes the live words as it shows (`words`); Not now keeps it `later` and asks again AGAIN
-- seconds on (`again`); No thanks declines it (`decline`, ONB-R16).
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
		decline = L.PARTY_LETTER_NO,
		onConfirm = fishTogether,
		isDue = ns.PartyLetterIsDue,
		words = ns.PartyLetterWords,
		again = AGAIN,
	}, ns.CORE_OWNER)
	if problem then
		error(problem)
	end
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
			party.share, party.show = nil, nil
		end
		ns.db.profile.partyHunts = nil
		local state = ns.onboarding:State()
		for _, key in ipairs({ "letters", "laterAt" }) do
			if type(state[key]) == "table" then
				state[key][ID] = nil
			end
		end
		print(L.DEV_PARTY_LETTER_RESET)
		return
	end
	ns.letter:ShowNow(ID)
	print(ns.RenderText(L.DEV_PARTY_LETTER, { name = ns.PARTY_DEV_NAME }))
end
