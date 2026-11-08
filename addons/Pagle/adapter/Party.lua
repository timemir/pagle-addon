---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- Party toasts and cheers on the client (announcements.md › Party toasts and cheers, ANN-R103–R110; from 1.5.x,
-- #640): who in the party runs Pagle, the moments the player shares, what arrives and what is ignored, the party
-- queue behind the player's own toasts, the mug and the merged cheers, the Party block's values and /pagle dev party.
-- Live only: nothing here reaches PagleLog, the Catch log, a projection or the Session summary. Over
-- adapter/PartyMessages.lua; the party toast's frame is adapter/PartyToast.lua's and its rows adapter/PartySettings.lua's.
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

-- The Party block's values (SET-R35): `PagleDB.profile.party`, nil meaning on, so no default sits in logic/.

---@return table?
local function stored()
	return ns.db and ns.db.profile.party
end

-- The table to write to, made at the first change.
---@return table
local function writable()
	local profile = ns.db.profile --[[@as table]]
	profile.party = profile.party or {}
	return profile.party
end

--- Whether a Party option is on (SET-R35): `share`, `show` or `sounds`, on unless stored as false.
---@param key "share"|"show"|"sounds"
---@return boolean
function ns.PartyOption(key)
	local party = stored()
	return not (party and party[key] == false)
end

--- Sets a Party option: false is stored, on clears the key.
---@param key "share"|"show"|"sounds"
---@param on boolean
function ns.SetPartyOption(key, on)
	if on then
		local party = stored()
		if party then
			party[key] = nil
		end
	else
		writable()[key] = false
	end
end

--- Whether a kind's switch is on (SET-R35): on unless stored as false.
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

-- The groupmates' first names, party1 to party4.
---@return string[]
local function members()
	local names = {}
	for i = 1, 4 do
		local name = unsecret((UnitName("party" .. i)))
		if type(name) == "string" and name ~= "" then
			names[#names + 1] = name
		end
	end
	return names
end

-- The groupmate a sender is (ANN-R105), by name, or nil: not one, or the player.
---@param sender any
---@return string?
local function groupmate(sender)
	local name = ns.PartySenderName(unsecret(sender))
	if not name or name == unsecret((UnitName("player"))) then
		return nil
	end
	for _, member in ipairs(members()) do
		if member == name then
			return member
		end
	end
	return nil
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
	for _, name in ipairs(members()) do
		present[name] = true
		if not state.greeted[name] then
			state.greeted[name] = true
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

--- Puts what waits in the party queue into the lanes, one at a time, while they hold nothing of the player's and
--- aren't held (ANN-R106); drops one that waited past its expiry. The lanes' `empty` calls it too.
function ns.PumpPartyToasts()
	local lanes = ns.lanes
	if not lanes then
		return
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

-- A cheer from `name` for moment `id` (ANN-R108): one of the player's kept ids, once per groupmate; the first starts
-- CHEER_GATHER seconds of gathering, then one Nod.
---@param id string
---@param name string
local function cheered(id, name)
	local entry = state.shared[id]
	if not entry or GetTime() - entry.at > IDS_FOR or entry.cheered[name] then
		return
	end
	entry.cheered[name] = true
	entry.names[#entry.names + 1] = name
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
---@param name string
---@param kind string
---@return boolean
local function overLimit(name, kind)
	local limits = state.limits[name]
	if not limits then
		limits = {}
		state.limits[name] = limits
	end
	local limit = limits[kind]
	if not limit then
		limit = ns.NewPartyLimit(LIMITS[kind][1], LIMITS[kind][2])
		limits[kind] = limit
	end
	return not limit:Take(GetTime())
end

-- Whether moment `id` from `name` was taken already; notes it if not.
---@param name string
---@param id string
---@return boolean
local function seen(name, id)
	local list = state.received[name]
	if not list or list.count >= RECEIVED_KEPT then
		list = { count = 0, ids = {} }
		state.received[name] = list
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
	local name = groupmate(sender)
	local message = name and ns.ParsePartyText(unsecret(text))
	if not name or not message then
		return
	end
	if
		message.type == "moment" and seen(name, message.id --[[@as string]])
	then
		return
	end
	if overLimit(name, message.type) then
		return
	end
	state.peers[name] = true
	if message.type == "hello" then
		if message.ask and (not state.helloAt or GetTime() - state.helloAt >= HELLO_GAP) then
			sayHello(false)
		end
	elseif message.type == "moment" then
		received(message, name)
	else
		cheered(message.id --[[@as string]], name)
	end
end)

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
	gold = { kind = "gold", item = 6303 },
	zone = { kind = "zone" },
	prestige = { kind = "prestige", rank = 3 },
	ledger = { kind = "ledger" },
}
local DEV_NAMES = { "Kukli", "Arwen", "Bram", "Dela" }

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

--- Runs `/pagle dev party <args>` (ANN-R109), behind the dev switch: a party toast of a kind, all seven, or 1 to 4
--- cheers for a made-up moment of the player's.
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
	elseif DEV_SAMPLES[word] then
		devToast(word)
		return
	elseif word == "cheer" then
		local count = rest == "" and 1 or tonumber(rest)
		if count and count >= 1 and count <= #DEV_NAMES and count == math.floor(count) then
			local id = ids:Next()
			remember(id, ns.PartyMomentLine({ type = "moment", kind = "legend", item = 19805 }, lookups()))
			for i = 1, count do
				cheered(id, DEV_NAMES[i])
			end
			print(ns.RenderText(L.DEV_PARTY_CHEERED, { count = count }))
			return
		end
	end
	print(ns.RenderText(L.DEV_PARTY_USAGE, { kinds = table.concat(ns.PARTY_KINDS, ", ") }))
end
