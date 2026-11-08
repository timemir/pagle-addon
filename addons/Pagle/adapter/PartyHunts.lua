---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- "Completed for the party" on the client (announcements.md › Party Catches and the party, ANN-R111; from 1.6, #646):
-- the hp party toast Core sends when a live moment carries a Party Catch's source Catch ID (HNT-R185), and shows when a
-- groupmate's arrives, the catcher reading "Your catch", one Catch and Hunt's merged across the party. Live only, as
-- every party toast: nothing here reaches PagleLog, a projection or the Session summary. Over adapter/PartyMessages.lua
-- (the message and its line) and adapter/Party.lua (the send queue, the receiving checks, the party queue, the mug).
-- Loaded by adapter/Settings.xml after them, before the lanes exist: what it reaches of them it looks up when it runs.

-- Tunables (announcements.md › Tunables): the party merge window, and a party toast's expiry (ANN-R106).
local MERGE_WINDOW = 5
local EXPIRY = 120
-- The icon: Hunts' Trade_Fishing (ANN-R111).
local ICON = "Interface\\Icons\\Trade_Fishing"

--- Whether Party Hunts is on (SET-R35, LOG-R121): `PagleDB.profile.partyHunts`, nil meaning on.
---@return boolean
function ns.PartyHuntsOn()
	return not (ns.db and ns.db.profile.partyHunts == false)
end

-- A party is a group that isn't a raid (ANN-R103, LOG-R110).
local function inParty()
	return IsInGroup() and not IsInRaid()
end

--- Sends "Completed for the party" for each moment of `announcement` that carries partyCatch (ANN-R111), once, while
--- Party Hunts and Share my moments with my party are on, in a party. adapter/Moments.lua calls it with every
--- Announcement the collector shows, so only live moments reach it (ANN-R4): never a replay's or a rebuild's.
---@param announcement PagleAnnouncement
function ns.SharePartyHunts(announcement)
	if not ns.PartyHuntsOn() or not ns.PartyOption("share") or not inParty() then
		return
	end
	for _, moment in ipairs(announcement.moments) do
		local share = ns.PartyHuntShareOf(moment)
		local text = share and ns.PartyHuntText(share)
		if text then
			ns.SendPartyText(text)
		end
	end
end

--- The hp party toast (ANN-R111): one party-style toast, `toast.low`, Core's own, its kicker "Your catch" for the
--- catcher (whose GUID the source Catch opens with) or "Completed for the party", its line the Hunt or run and every
--- groupmate it was for, Trade_Fishing, silent, and no mug, Coins or cheer.
---@param message PaglePartyMessage
---@param names string[]
---@param expiresAt integer server time
---@return PagleAnnouncement
function ns.PartyHuntToastOf(message, names, expiresAt)
	local L = ns.L
	local mine = message.catcher == ns.PartyGuidText(ns.UnlessSecret(issecretvalue, (UnitGUID("player"))))
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
		partyToast = { id = message.catch, sender = names[1], kind = ns.PARTY_HUNT_KIND },
	}
	return { headline = headline, rung = "toast.low", stamps = {}, more = 0, coins = 0, moments = { headline } }
end

-- The hp messages gathering in their merge window, by what, ID and source Catch.
---@type table<string, { message: PaglePartyMessage, names: string[], from: table<string, true>, at: number }>
local gathering = {}

--- A groupmate's hp (ANN-R111), already checked as any party message is (ANN-R105): taken while Party Hunts, Show my
--- party's moments and its kind's switch are on (SET-R35, SET-R36). The first of one Catch and Hunt waits the merge
--- window for the others, each groupmate once, then goes to the party queue as one toast, expiring from its arrival.
---@param message PaglePartyMessage
---@param name string the groupmate's name (ANN-R105)
---@param key string the groupmate's key
function ns.ReceivePartyHunt(message, name, key)
	if not ns.PartyHuntsOn() or not ns.PartyOption("show") or not ns.PartyKindOn(ns.PARTY_HUNT_KIND) then
		return
	end
	local merge = table.concat({ message.what, message.id, message.catch }, ":")
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

--- `/pagle dev party hp` (ANN-R109): a groupmate's "Completed for the party" for Mackerel Run, from `name`, through
--- the receiving path past the party and the limits; Settings still apply.
---@param name string
function ns.DevPartyHunt(name)
	ns.ReceivePartyHunt({
		type = "hunt",
		kind = ns.PARTY_HUNT_KIND,
		what = "hunt",
		id = "mackerel_run",
		catch = "4701:0a1b2c3d:tmr110:0:1",
		catcher = "4701:0a1b2c3d",
	}, name, "dev:" .. name)
end
