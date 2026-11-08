---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- "Completed for the party" on the client (announcements.md › Party Catches and the party, ANN-R111; from 1.6, #646):
-- the hp message Core sends when a live moment carries a Party Catch's source Catch ID (HNT-R185), and the party toast
-- it makes when a groupmate's arrives, the catcher reading "Your catch", one Catch and Hunt's merged across the party.
-- It rides the party catch prefix, PagleCatch (catch-log.md LOG-R110), through the party toasts' one send queue
-- (adapter/Party.lua's ns.SendPartyMessage, LOG-R112). Live only, as every party toast: nothing here reaches PagleLog,
-- a projection or the Session summary. Over adapter/PartyMessages.lua (the message and its line) and
-- adapter/Party.lua (the queue, the groupmates, the party queue, the mug). Loaded by adapter/Settings.xml after them,
-- before the lanes exist: what it reaches of them it looks up when it runs. Its own owner on Core's bus.
local OWNER = "Pagle party hunts"

-- Tunables (announcements.md › Tunables): the party merge window, a party toast's expiry (ANN-R106), and the hp
-- messages taken from one groupmate, 4 at once, since one Party Catch can complete Hunts and settle a run together,
-- then one per 10 s.
local MERGE_WINDOW = 5
local EXPIRY = 120
local LIMIT_BURST, LIMIT_EVERY = 4, 10
-- The icon: Hunts' Trade_Fishing (ANN-R111).
local ICON = "Interface\\Icons\\Trade_Fishing"

-- `value`, or nil if it is a secret (CORE-R31).
local function unsecret(value)
	return ns.UnlessSecret(issecretvalue, value)
end

--- Whether Party Hunts is on (SET-R35, LOG-R121): `PagleDB.profile.partyHunts`, nil meaning on.
---@return boolean
function ns.PartyHuntsOn()
	return not (ns.db and ns.db.profile.partyHunts == false)
end

-- A party here (LOG-R110): a home group of up to 5, never a raid.
local function inHomeParty()
	return IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid()
end

--- Sends "Completed for the party" for each moment of `announcement` that carries partyCatch (ANN-R111), once, on the
--- prefix PagleCatch, while Party Hunts and Share my moments with my party are on, in a party. adapter/Moments.lua
--- calls it with every Announcement the collector shows, so only live moments reach it (ANN-R4): never a replay's or
--- a rebuild's.
---@param announcement PagleAnnouncement
function ns.SharePartyHunts(announcement)
	if not ns.PartyHuntsOn() or not ns.PartyOption("share") or not inHomeParty() then
		return
	end
	for _, moment in ipairs(announcement.moments) do
		local share = ns.PartyHuntShareOf(moment)
		local text = share and ns.PartyHuntText(share)
		if text then
			ns.SendPartyMessage(text, { prefix = ns.PARTY_CATCH_PREFIX })
		end
	end
end

--- The hp party toast (ANN-R111): one party-style toast, `toast.low`, Core's own, its kicker "Your catch" for the
--- catcher (whose GUID the source Catch ID opens with) or "Completed for the party", its line the Hunt or run and every
--- groupmate it was for, Trade_Fishing, silent, and no mug, Coins or cheer.
---@param message PaglePartyHunt
---@param names string[]
---@param expiresAt integer server time
---@return PagleAnnouncement
function ns.PartyHuntToastOf(message, names, expiresAt)
	local L = ns.L
	local mine = message.catcher == unsecret((UnitGUID("player")))
	local headline = {
		rung = "toast.low",
		kind = "party",
		module = "Pagle",
		moduleTitle = "Pagle",
		moduleOrder = 0,
		raised = 0,
		title = mine and L.PARTY_HP_MINE or L.PARTY_HP_PARTY,
		text = ns.PartyHuntLine(message, names, ns.PartyLookups()),
		icon = ICON,
		sound = false,
		expiresAt = expiresAt,
		partyToast = { id = message.source, sender = names[1], kind = ns.PARTY_HUNT_KIND },
	}
	return { headline = headline, rung = "toast.low", stamps = {}, more = 0, coins = 0, moments = { headline } }
end

-- The hp messages gathering in their merge window, by what, ID and source Catch ID.
---@type table<string, { message: PaglePartyHunt, names: string[], from: table<string, true>, at: number }>
local gathering = {}

--- A groupmate's hp (ANN-R111), already checked: taken while Party Hunts, Show my party's moments and its kind's switch
--- are on (SET-R35, SET-R36). The first of one Catch and Hunt waits the merge window for the others, each groupmate
--- once, then goes to the party queue as one toast, expiring from its arrival.
---@param message PaglePartyHunt
---@param name string the groupmate's first name, as ANN-R111's lines name them ("for Kukli and Bram")
---@param key string the groupmate's key
function ns.ReceivePartyHunt(message, name, key)
	if not ns.PartyHuntsOn() or not ns.PartyOption("show") or not ns.PartyKindOn(ns.PARTY_HUNT_KIND) then
		return
	end
	local merge = table.concat({ message.what, message.id, message.source }, "|")
	local entry = gathering[merge]
	if entry then
		if not entry.from[key] then
			entry.from[key] = true
			entry.names[#entry.names + 1] = name
		end
		return
	end
	entry = { message = message, names = { name }, from = { [key] = true }, at = GetTime() }
	gathering[merge] = entry
	local expiresAt = GetServerTime() + EXPIRY
	C_Timer.After(MERGE_WINDOW, function()
		gathering[merge] = nil
		ns.EnqueuePartyToast(ns.PartyHuntToastOf(entry.message, entry.names, expiresAt), entry.at + EXPIRY)
	end)
end

-- Each groupmate's hp limit, by their key.
---@type table<string, PaglePartyLimit>
local limits = {}

-- What arrives on the party catch prefix with kind hp (ANN-R111), checked as LOG-R113 items 1, 2 and 4 check a party
-- catch message: from a groupmate in a party unit who isn't the player (ns.PartyGroupmate, as ANN-R105 matches one),
-- with Party Hunts on, in a home party; then exactly an hp message, within the groupmate's limit. Anything else is
-- ignored without a word; adapter/PartyCatches.lua reads the party catch messages on the same prefix.
Pagle.RegisterEvent(OWNER, "CHAT_MSG_ADDON", function(_, prefix, text, channel, sender)
	text = unsecret(text)
	if unsecret(prefix) ~= ns.PARTY_CATCH_PREFIX or unsecret(channel) ~= "PARTY" or type(text) ~= "string" then
		return
	end
	if text:match("^[^|]*") ~= ns.PARTY_HUNT_KIND or not ns.PartyHuntsOn() or not inHomeParty() then
		return
	end
	local member = ns.PartyGroupmate(unsecret(sender))
	local message = member and ns.ParsePartyHuntText(text)
	if not member or not message then
		return
	end
	local limit = limits[member.key]
	if not limit then
		limit = ns.NewPartyLimit(LIMIT_BURST, LIMIT_EVERY)
		limits[member.key] = limit
	end
	if limit:Take(GetTime()) then
		ns.ReceivePartyHunt(message, member.first, member.key)
	end
end)

--- `/pagle dev party hp` (ANN-R109): a groupmate's "Completed for the party" for Mackerel Run, from `name`, through
--- the receiving path past the party and the limits; Settings still apply.
---@param name string
function ns.DevPartyHunt(name)
	ns.ReceivePartyHunt({
		what = "hunt",
		id = "mackerel_run",
		source = "Player-4701-0A1B2C3D-1791731700-0:1",
		catcher = "Player-4701-0A1B2C3D",
	}, name, "dev:" .. name)
end
