---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Party toasts and cheers on the client (announcements.md › Party toasts and cheers, ANN-R103–R109, ANN-R112; from 1.5.2,
-- #640): who in the party runs Pagle, the moments the player shares, what arrives and what is ignored, the party
-- queue behind the player's own toasts, the mug and the merged cheers, the Party block's values and /pagle dev party.
-- Live only: nothing here reaches PagleLog, the Catch log, a projection or the Session summary. Over
-- adapter/PartyMessages.lua; the party toast's frame is adapter/PartyToast.lua's and its rows adapter/PartySettings.lua's.
-- From 1.5.3 (#655) sharing and showing are off until the party letter is answered (ANN-R113, adapter/PartyLetter.lua),
-- which reads here who in the party runs Pagle and is in the player's zone (ns.PartyGroupmateHere).
-- Loaded by adapter/Settings.xml, before the lanes exist: everything it reaches of them (ns.lanes, ns.db) it looks up
-- when it runs. Its own owner on Core's bus.
local OWNER = "Pagle party"

-- Tunables (announcements.md › Tunables).
local HELLO_DELAY, HELLO_GAP = 2, 10
local SEND_BURST, SEND_EVERY, SEND_WAITING = 3, 1, 8
local LIMITS = { hello = { 2, 30 }, moment = { 3, 20 }, cheer = { 6, 5 } }
local EXPIRY = 120
local CHEER_GATHER = 3
local IDS_KEPT, IDS_FOR = 20, 600
-- Ids kept per groupmate before the list starts over (each moment id is taken once, ANN-R105).
local RECEIVED_KEPT = 100

-- The party's state, in memory only.
local state = {
	peers = {}, ---@type table<string, true> Pagle groupmates, by name (ANN-R103)
	greeted = {}, ---@type table<string, true> groupmates greeted since they joined
	limits = {}, ---@type table<string, table<string, PaglePartyLimit>> per groupmate and type (ANN-R105)
	received = {}, ---@type table<string, { count: integer, ids: table<string, true> }> moment ids taken
	shared = {}, ---@type table<string, { line: string, at: number, names: string[], cheered: table<string, true>, gathering: boolean? }>
	sharedOrder = {}, ---@type string[]
	queue = {}, ---@type { announcement: PagleAnnouncement, expires: number }[] party toasts waiting (ANN-R106)
	heldCheers = {}, ---@type table[] cheers gathered while the lanes hold, waiting to show merged (ANN-R108)
	outbox = {}, ---@type string[] messages waiting for the limiter (ANN-R103)
	helloAt = nil, ---@type number?
	rosterToken = 0,
	retrying = false,
}

local sendLimit = ns.NewPartyLimit(SEND_BURST, SEND_EVERY)
local ids = ns.NewPartyIds(ns.PartyNonce(math.random))

-- The prefix, at each load: registration doesn't survive a /reload (ANN-R103).
C_ChatInfo.RegisterAddonMessagePrefix(ns.PARTY_PREFIX)

-- `value`, or nil if it is a secret (CORE-R31).
local function unsecret(value)
	return ns.UnlessSecret(issecretvalue, value)
end

-- The Party block's values (SET-R36) in `PagleDB.profile.party`, no default sitting in logic/. From 1.5.3 (#655) the
-- party features are opt-in (ANN-R113): `share` and `show` are on only once stored true, by the party letter's Fish
-- together (adapter/PartyLetter.lua) or by hand in Settings, and nil, not asked yet, reads off. `sounds` and each kind
-- stay on unless stored false. `optIn` marks a table read under the opt-in, so a 1.5.2 table is migrated once.

-- A 1.5.2 table, the first time 1.5.3 reads it (ANN-R113): a player who stored any setting there keeps what they had,
-- each of Share, Show and Cheers sounds that was nil (on, in 1.5.2) stored true, so the letter never asks them; one
-- with nothing stored (an empty table, or empty kinds) is not asked yet.
---@param party table
local function migrate(party)
	local chose = party.share == false or party.show == false or party.sounds == false
	for _, on in pairs(type(party.kinds) == "table" and party.kinds or {}) do
		chose = chose or on == false
	end
	if chose then
		for _, key in ipairs({ "share", "show", "sounds" }) do
			if party[key] == nil then
				party[key] = true
			end
		end
	end
	party.optIn = 1
end

---@return table?
local function stored()
	local party = ns.db and ns.db.profile.party
	if type(party) ~= "table" then
		return nil
	end
	if party.optIn == nil then
		migrate(party)
	end
	return party
end

-- The table to write to, made at the first change.
---@return table
local function writable()
	local party = stored()
	if not party then
		party = { optIn = 1 }
		ns.db.profile.party = party
	end
	return party
end

--- The Party table to write to (adapter/PartyLetter.lua's answers), made at the first change and migrated as read.
---@return table
function ns.PartyStore()
	return writable()
end

--- The Party table as stored, migrated as read (ANN-R113), or nil while nothing is.
---@return table?
function ns.PartyStored()
	return stored()
end

--- Whether a Party option is on (SET-R36, ANN-R113): `share` and `show` only once stored true; `sounds` unless stored
--- false.
---@param key "share"|"show"|"sounds"
---@return boolean
function ns.PartyOption(key)
	local party = stored()
	if key == "sounds" then
		return not (party and party.sounds == false)
	end
	return party ~= nil and party[key] == true
end

--- Sets a Party option, stored as given (ANN-R113): a change of Share or Show by hand is an answer to the party
--- letter. Setting what it already is writes nothing, so the Defaults button on a player not asked yet answers
--- nothing.
---@param key "share"|"show"|"sounds"
---@param on boolean
function ns.SetPartyOption(key, on)
	if ns.PartyOption(key) ~= on then
		writable()[key] = on
	end
end

--- Whether a kind's switch is on (SET-R36): on unless stored as false.
---@param kind string
---@return boolean
function ns.PartyKindOn(kind)
	local party = stored()
	local kinds = party and party.kinds
	return not (kinds and kinds[kind] == false)
end

--- Sets a kind's switch: false is stored, on clears it.
---@param kind string
---@param on boolean
function ns.SetPartyKind(kind, on)
	if on then
		local party = stored()
		if party and party.kinds then
			party.kinds[kind] = nil
		end
	else
		local party = writable()
		party.kinds = party.kinds or {}
		party.kinds[kind] = false
	end
end

--- Plays party sound `name` (ANN-R108: "arrive", "raise" or "cheered", ns.PARTY_SOUNDS) on the SFX channel, with
--- Cheers sounds on and never in Cozy mode.
---@param name string
function ns.PlayPartySound(name)
	if not ns.PartyOption("sounds") or (ns.db and ns.db.profile.announcements.cozy) then
		return
	end
	PlaySoundFile(ns.PARTY_SOUNDS[name], "SFX")
end

-- The group (ANN-R103): a party is a group that isn't a raid.
local function inParty()
	return IsInGroup() and not IsInRaid()
end

--- A groupmate as Core keeps them (ANN-R105): `key`, their GUID (their first name only where the client gives none),
--- what Core remembers them by; `first`, their first name; and `name`, how a party toast and a cheer's Nod name them,
--- "{name} {surname}" where Forever gives a surname, as the website writes it (pagle-backend ANG-R13).
---@class PagleGroupmate
---@field key string
---@field first string
---@field name string

-- `unit`'s groupmate, or nil for none: UnitName's first return and Forever's surname, its second (CORE's Angler reads
-- the player's the same way, adapter/Angler.lua), and UnitGUID.
---@param unit string
---@return PagleGroupmate?
local function memberAt(unit)
	local first, surname = UnitName(unit)
	first, surname = unsecret(first), unsecret(surname)
	if type(first) ~= "string" or first == "" then
		return nil
	end
	local guid = unsecret((UnitGUID(unit)))
	local name = first
	if type(surname) == "string" and surname ~= "" then
		name = ns.RenderText(ns.L.PARTY_FULL_NAME, { name = first, surname = surname })
	end
	return { key = type(guid) == "string" and guid or ("name:" .. first), first = first, name = name }
end

-- The groupmates, party1 to party4.
---@return PagleGroupmate[]
local function members()
	local list = {}
	for i = 1, 4 do
		list[#list + 1] = memberAt("party" .. i)
	end
	return list
end

-- The groupmate a sender is (ANN-R105), or nil: not one, the player, or a first name two of them share. By GUID
-- where the client resolves the sender's name to a unit (a groupmate's name is a unit token), else by first name,
-- only when one groupmate has it.
---@param sender any
---@return PagleGroupmate?
local function groupmate(sender)
	sender = unsecret(sender)
	local first = ns.PartySenderName(sender)
	if not first then
		return nil
	end
	local guid = unsecret(
		(
			UnitGUID(sender --[[@as string]])
		)
	)
	if type(guid) == "string" and guid == unsecret((UnitGUID("player"))) then
		return nil
	end
	local named, count = nil, 0
	for _, member in ipairs(members()) do
		if type(guid) == "string" and member.key == guid then
			return member
		end
		if member.first == first then
			named, count = member, count + 1
		end
	end
	if type(guid) == "string" or count ~= 1 or first == unsecret((UnitName("player"))) then
		return nil
	end
	return named
end

-- Sending (ANN-R103): through the limiter, waiting out chat lockdown, and only in a party.
local pump

local function retry()
	if state.retrying then
		return
	end
	state.retrying = true
	C_Timer.After(SEND_EVERY, function()
		state.retrying = false
		pump()
	end)
end

function pump()
	while state.outbox[1] do
		if not inParty() then
			state.outbox = {}
			return
		end
		if C_ChatInfo.InChatMessagingLockdown() or not sendLimit:Take(GetTime()) then
			retry()
			return
		end
		C_ChatInfo.SendAddonMessage(ns.PARTY_PREFIX, table.remove(state.outbox, 1), "PARTY")
	end
end

---@param text string
local function send(text)
	if not inParty() or #state.outbox >= SEND_WAITING then
		return
	end
	state.outbox[#state.outbox + 1] = text
	pump()
end

---@param ask boolean
local function sayHello(ask)
	state.helloAt = GetTime()
	send(ns.PartyHelloText(ask))
end

-- The roster settled (ANN-R103): out of a party everything is forgotten; in one, a groupmate who left is, and a
-- hello greets any who joined.
local function rosterSettled()
	if not inParty() then
		state.peers, state.greeted, state.limits, state.received, state.outbox = {}, {}, {}, {}, {}
		return
	end
	local present, newcomer = {}, false
	for _, member in ipairs(members()) do
		present[member.key] = true
		if not state.greeted[member.key] then
			state.greeted[member.key] = true
			newcomer = true
		end
	end
	for _, known in ipairs({ state.greeted, state.peers, state.limits, state.received }) do
		for name in pairs(known) do
			if not present[name] then
				known[name] = nil
			end
		end
	end
	if newcomer then
		sayHello(true)
	end
	ns.CheckPartyLetter()
end

-- HELLO_DELAY after the roster last changed, or after login, a /reload or a load screen.
local function rosterChanged()
	state.rosterToken = state.rosterToken + 1
	local token = state.rosterToken
	C_Timer.After(HELLO_DELAY, function()
		if token == state.rosterToken then
			rosterSettled()
		end
	end)
end
Pagle.RegisterEvent(OWNER, "GROUP_ROSTER_UPDATE", rosterChanged)
Pagle.RegisterEvent(OWNER, "PLAYER_ENTERING_WORLD", rosterChanged)

-- What a party toast's line looks things up with (ns.PartyMomentLine).
---@return PaglePartyLookups
local function lookups()
	return {
		itemName = function(itemID)
			return unsecret((C_Item.GetItemNameByID(itemID)))
		end,
		varieties = function(species)
			return Pagle.GetVarieties and Pagle.GetVarieties(species) or nil
		end,
		formatLength = function(mm)
			return ns.FormatLength(mm, ns.LengthUnit())
		end,
		areaName = function(areaID)
			return unsecret((C_Map.GetAreaInfo(areaID)))
		end,
		-- The player's Hunts names it (its def.partyHuntName, adapter/Hunts.lua); nil without Hunts On.
		huntName = function(huntID)
			for _, module in ipairs(ns.Modules:Modules()) do
				local name = module.def.partyHuntName
				if name then
					local ok, text = pcall(name, huntID)
					return ok and type(text) == "string" and text or nil
				end
			end
			return nil
		end,
	}
end

--- The party toast for a groupmate's moment (ANN-R106): one moment, `toast.low`, Core's own, titled by the groupmate,
--- its text the moment's line, silent, expiring EXPIRY seconds on. `partyToast` marks it for the display and the mug.
---@param message PaglePartyMessage
---@param name string
---@return PagleAnnouncement
function ns.PartyToastOf(message, name)
	local icon = message.item and message.item > 0 and message.item or ns.PARTY_ART.icons[message.kind]
	local headline = {
		rung = "toast.low",
		kind = "party",
		module = "Pagle",
		moduleTitle = "Pagle",
		moduleOrder = 0,
		raised = 0,
		title = name,
		text = ns.PartyMomentLine(message, lookups()),
		icon = icon or ns.DEFAULT_ICON,
		sound = false,
		expiresAt = GetServerTime() + EXPIRY,
		partyToast = { id = message.id, sender = name, kind = message.kind },
	}
	return { headline = headline, rung = "toast.low", stamps = {}, more = 0, coins = 0, moments = { headline } }
end

-- A cheer's Nod, below (cheerNod).
local showCheers

--- Puts what waits in the party queue into the lanes, one at a time, while they hold nothing of the player's and
--- aren't held (ANN-R106); drops one that waited past its expiry. The lanes' `empty` calls it too.
function ns.PumpPartyToasts()
	local lanes = ns.lanes
	if not lanes then
		return
	end
	if not lanes:IsHeld() and state.heldCheers[1] then
		local held = state.heldCheers
		state.heldCheers = {}
		for _, entry in ipairs(held) do
			showCheers(entry)
		end
	end
	local now = GetTime()
	while state.queue[1] do
		local entry = state.queue[1]
		if now >= entry.expires then
			table.remove(state.queue, 1)
		elseif lanes:IsHeld() or not lanes:IsEmpty() then
			return
		else
			table.remove(state.queue, 1)
			lanes:Push(entry.announcement)
		end
	end
end

---@param announcement PagleAnnouncement
local function enqueue(announcement)
	state.queue[#state.queue + 1] = { announcement = announcement, expires = GetTime() + EXPIRY }
	ns.PumpPartyToasts()
end

-- A valid moment from a groupmate (ANN-R106): a party toast while Show and its kind's switch are on.
---@param message PaglePartyMessage
---@param name string
---@param dev boolean?
local function received(message, name, dev)
	if not ns.PartyOption("show") or not ns.PartyKindOn(message.kind) then
		return
	end
	local announcement = ns.PartyToastOf(message, name)
	announcement.headline.partyToast.dev = dev
	enqueue(announcement)
end

-- A cheer's Nod (ANN-R108): every groupmate who cheered the moment so far, merged, its text the moment's line.
---@param entry table
local function cheerNod(entry)
	local lanes = ns.lanes
	if not lanes then
		return
	end
	-- Held with the lanes (combat, the Field guide), where a Nod would be dropped: it shows when they let go, with
	-- every cheer gathered meanwhile.
	if lanes:IsHeld() then
		for _, held in ipairs(state.heldCheers) do
			if held == entry then
				return
			end
		end
		state.heldCheers[#state.heldCheers + 1] = entry
		return
	end
	local headline = {
		rung = "nod",
		kind = "partyCheer",
		module = "Pagle",
		moduleTitle = "Pagle",
		moduleOrder = 0,
		raised = 0,
		title = ns.PartyCheerTitle(entry.names),
		text = entry.line,
		icon = ns.PARTY_ART.mug,
		partyCheer = true,
	}
	lanes:Push({ headline = headline, rung = "nod", stamps = {}, more = 0, coins = 0, moments = { headline } })
end
showCheers = cheerNod

-- After combat's wait (ANN-R36), held cheers show at once, even while held toasts still fill the column.
Pagle.RegisterCallback(OWNER, "RestrictionChanged", function(_, isRestricted)
	if not isRestricted then
		C_Timer.After(ns.AFTER_COMBAT_SECONDS + 0.1, ns.PumpPartyToasts)
	end
end)

-- A cheer from `member` for moment `id` (ANN-R108): one of the player's kept ids, once per groupmate; the first starts
-- CHEER_GATHER seconds of gathering, then one Nod.
---@param id string
---@param member PagleGroupmate
local function cheered(id, member)
	local entry = state.shared[id]
	if not entry or GetTime() - entry.at > IDS_FOR or entry.cheered[member.key] then
		return
	end
	entry.cheered[member.key] = true
	entry.names[#entry.names + 1] = member.name
	if entry.gathering then
		return
	end
	entry.gathering = true
	C_Timer.After(CHEER_GATHER, function()
		entry.gathering = false
		cheerNod(entry)
	end)
end

-- Keeps a shared moment's id for its cheers: the last IDS_KEPT.
---@param id string
---@param line string
local function remember(id, line)
	state.shared[id] = { line = line, at = GetTime(), names = {}, cheered = {} }
	state.sharedOrder[#state.sharedOrder + 1] = id
	if #state.sharedOrder > IDS_KEPT then
		state.shared[table.remove(state.sharedOrder, 1)] = nil
	end
end

-- Whether `name`'s message of `kind` is past their limit (ANN-R105); one within it is spent.
---@param key string the groupmate's key
---@param kind string
---@return boolean
local function overLimit(key, kind)
	local limits = state.limits[key]
	if not limits then
		limits = {}
		state.limits[key] = limits
	end
	local limit = limits[kind]
	if not limit then
		limit = ns.NewPartyLimit(LIMITS[kind][1], LIMITS[kind][2])
		limits[kind] = limit
	end
	return not limit:Take(GetTime())
end

-- Whether moment `id` from `name` was taken already; notes it if not.
---@param key string the groupmate's key
---@param id string
---@return boolean
local function seen(key, id)
	local list = state.received[key]
	if not list or list.count >= RECEIVED_KEPT then
		list = { count = 0, ids = {} }
		state.received[key] = list
	end
	if list.ids[id] then
		return true
	end
	list.ids[id] = true
	list.count = list.count + 1
	return false
end

-- What arrives (ANN-R105): read only from a groupmate in a party, on Pagle's prefix and the party channel, exactly
-- a message, within the sender's limits; anything else is ignored, silently.
Pagle.RegisterEvent(OWNER, "CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
	if unsecret(prefix) ~= ns.PARTY_PREFIX or unsecret(channel) ~= "PARTY" or not inParty() then
		return
	end
	local member = groupmate(sender)
	local message = member and ns.ParsePartyText(unsecret(text))
	if not member or not message then
		return
	end
	if
		message.type == "moment" and seen(member.key, message.id --[[@as string]])
	then
		return
	end
	if overLimit(member.key, message.type) then
		return
	end
	local newPeer = not state.peers[member.key]
	state.peers[member.key] = true
	if newPeer then
		-- A groupmate found to run Pagle may be the party letter's reason (ANN-R114).
		ns.CheckPartyLetter()
	end
	if message.type == "hello" then
		if message.ask and (not state.helloAt or GetTime() - state.helloAt >= HELLO_GAP) then
			sayHello(false)
		end
	elseif message.type == "moment" then
		received(message, member.name)
	else
		cheered(message.id --[[@as string]], member)
	end
end)

--- The Pagle groupmate the party letter names (ANN-R114): the first of party1 to party4 who sent a valid message (a
--- Pagle groupmate, ANN-R103) and whom the client places on the player's own map (`C_Map.GetBestMapForUnit`), with that
--- map's ID; nil out of a party, with no Pagle groupmate, or none the client places beside the player.
---@return PagleGroupmate?
---@return integer? map
function ns.PartyGroupmateHere()
	if not inParty() or next(state.peers) == nil then
		return nil
	end
	local here = unsecret((C_Map.GetBestMapForUnit("player")))
	if type(here) ~= "number" then
		return nil
	end
	for i = 1, 4 do
		local unit = "party" .. i
		local member = memberAt(unit)
		if member and state.peers[member.key] and unsecret((C_Map.GetBestMapForUnit(unit))) == here then
			return member, here
		end
	end
	return nil
end

--- Shares the moments of `announcement` a Module marked with `party` (ANN-R104), each once, while Share is on, in a
--- party with a Pagle groupmate. adapter/Moments.lua calls it with every Announcement the collector shows, so only
--- live moments reach it.
---@param announcement PagleAnnouncement
function ns.SharePartyMoments(announcement)
	if not ns.PartyOption("share") or not inParty() or next(state.peers) == nil then
		return
	end
	for _, moment in ipairs(announcement.moments) do
		local shared = moment.party and ns.PartyShareOf(moment, Pagle.GetVarieties)
		local id = shared and ids:Next()
		local text = id and ns.PartyMomentText(id, shared --[[@as PagleSharedMoment]])
		if text then
			---@cast id string
			---@cast shared PagleSharedMoment
			local message = shared --[[@as PaglePartyMessage]]
			remember(id, ns.PartyMomentLine(message, lookups()))
			send(text)
		end
	end
end

--- Raises the mug on a party toast (ANN-R108): once per toast, its cheer sent (not for a dev toast) and the raise
--- sound played. True when it was raised now.
---@param display PagleDisplay
---@return boolean
function ns.RaisePartyMug(display)
	local toast = display.announcement.headline.partyToast
	if not toast or toast.raised then
		return false
	end
	toast.raised = true
	if not toast.dev then
		send(ns.PartyCheerText(toast.id))
	end
	ns.PlayPartySound("raise")
	return true
end

-- `/pagle dev party` (ANN-R109): what a groupmate would send, faked.
local DEV_SAMPLES = {
	legend = { kind = "legend", item = 19805 },
	colour = { kind = "colour", item = 6291, rarity = "rare", place = 8 },
	monster = { kind = "monster", item = 6303, length = 612 },
	gold = { kind = "gold", item = 6303, hunt = "mackerel_run" },
	zone = { kind = "zone", area = 357 },
	prestige = { kind = "prestige", rank = 3 },
	ledger = { kind = "ledger" },
}
-- Made-up groupmates, with Forever's surnames and one without.
local DEV_NAMES = { "Kukli Emnabi", "Arwen Tull", "Bram", "Dela Marsh" }
--- The made-up groupmate of the dev commands and the party letter's sample (ANN-R109, ANN-R116).
ns.PARTY_DEV_NAME = DEV_NAMES[1]

-- A party toast of `kind` from Kukli, through the receiving path past the party and the limits.
---@param kind string
local function devToast(kind)
	---@type table<string, any>
	local message = { type = "moment", id = ids:Next() }
	for key, value in pairs(DEV_SAMPLES[kind]) do
		message[key] = value
	end
	received(message --[[@as PaglePartyMessage]], DEV_NAMES[1], true)
	print(ns.RenderText(ns.L.DEV_PARTY_QUEUED, { name = DEV_NAMES[1], kind = kind }))
end

--- Runs `/pagle dev party <args>` (ANN-R109), behind the dev switch: a party toast of a kind, all seven, 1 to 4
--- cheers for a made-up moment of the player's, or (from 1.5.3) the party letter (ANN-R116, adapter/PartyLetter.lua).
---@param args string
function ns.RunPartyDev(args)
	local L = ns.L
	if not ns.db.global.dev then
		print(L.DEV_IS_OFF)
		return
	end
	local word, rest = ns.ParseSlash(args)
	if word == "all" then
		for _, kind in ipairs(ns.PARTY_KINDS) do
			devToast(kind)
		end
		return
	elseif word == "letter" then
		ns.RunPartyLetterDev(rest)
		return
	elseif DEV_SAMPLES[word] then
		devToast(word)
		return
	elseif word == "cheer" then
		local count = rest == "" and 1 or tonumber(rest)
		if count and count >= 1 and count <= #DEV_NAMES and count == math.floor(count) then
			local id = ids:Next()
			remember(id, ns.PartyMomentLine({ type = "moment", kind = "legend", item = 19805 }, lookups()))
			for i = 1, count do
				cheered(id, { key = "dev:" .. i, first = DEV_NAMES[i], name = DEV_NAMES[i] })
			end
			print(ns.RenderText(L.DEV_PARTY_CHEERED, { count = count }))
			return
		end
	end
	print(ns.RenderText(L.DEV_PARTY_USAGE, { kinds = table.concat(ns.PARTY_KINDS, ", ") }))
end
