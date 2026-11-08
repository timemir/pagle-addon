---@class PagleNS
local ns = select(2, ...)

-- Party Catches (catch-log.md › Party Catches, LOG-R110–R126; from 1.6, pagle-2026j, #644): the party catch message,
-- how it is made from one of the Angler's own Casts and read back, and the receiver's checks, in order, up to the
-- append. Pure Lua over what it is handed (CORE-R7): Core's adapter (adapter/PartyCatches.lua) hands it the client's
-- party, clock and send queue; the G1 entry itself is logic/CatchLog.lua's, and the Hunts filter logic/Projections.lua's.

--- The add-on message prefix the party catch message rides (LOG-R110): its own, beside the party toasts' `Pagle`
--- (ANN-R103), so a Pagle before 1.6, which never registers it, never receives one.
ns.PARTY_CATCH_PREFIX = "PagleCatch"
--- The party catch message's kind and the one version this Core reads (LOG-R110).
ns.PARTY_CATCH_KIND = "PC"
ns.PARTY_CATCH_VERSION = "1"
--- Tunables (catch-log.md › Tunables), in seconds: how long before a groupmate's Catch the receiver's latest Cast may
--- be (the party window), how old a groupmate's Cast may be when its message is sent or received (the max party
--- delay), and how far after the receiver's clock it may be (the clock slack).
ns.PARTY_WINDOW = 300
ns.PARTY_MAX_DELAY = 60
ns.PARTY_CLOCK_SLACK = 30
--- The most bytes the client sends in one add-on message (LOG-R111, Tunables).
ns.ADDON_MESSAGE_LIMIT = 255

-- The most bytes of a groupmate's GUID (LOG-R113 item 3).
local GUID_LIMIT = 64

-- `text` split at every `|`, empty fields kept.
---@param text string
---@return string[]
local function fields(text)
	local out, from = {}, 1
	while true do
		local at = text:find("|", from, true)
		if not at then
			out[#out + 1] = text:sub(from)
			return out
		end
		out[#out + 1] = text:sub(from, at - 1)
		from = at + 1
	end
end

-- Whether `items` holds an item that isn't item 0 (LOG-R8, LOG-R111).
---@param items { itemID: integer }[]
---@return boolean
local function anyKnownItem(items)
	for _, item in ipairs(items) do
		if item.itemID ~= 0 then
			return true
		end
	end
	return false
end

--- The party catch message for one of the Angler's own Casts (LOG-R111): `PC|1|<guid>|<time>|<tie>|` and the Cast's
--- own C1 fields from minute to items, byte for byte as `entry` holds them. Nil for a Cast that isn't one to share (not
--- caught, zone 0, or every item item 0), and for a message past the addon message limit, which isn't sent at all.
---@param cast PagleCast the Cast's record
---@param entry string the Cast's C1 entry, as stored
---@param guid string the Cast's character's GUID
---@return string?
function ns.PartyCatchText(cast, entry, guid)
	if cast.kind ~= "cast" or cast.outcome ~= "caught" or cast.conditions.zone == 0 or not anyKnownItem(cast.items) then
		return nil
	end
	local f = fields(entry)
	if f[1] ~= "C1" or #f ~= 16 then
		return nil
	end
	-- Header time and tie; then minute, then zone to items (the outcome, map and instance stay home).
	local text = table.concat({
		ns.PARTY_CATCH_KIND,
		ns.PARTY_CATCH_VERSION,
		guid,
		f[3],
		f[4],
		f[6],
		table.concat(f, "|", 9, 16),
	}, "|")
	if #text > ns.ADDON_MESSAGE_LIMIT then
		return nil
	end
	return text
end

--- A party catch message read (LOG-R113 item 3): the groupmate's GUID, their Cast's time, tie and zone, the **copy**
--- (the message's fields from `<time>` to `<items>`, byte for byte, LOG-R115) and the source entry ID
--- `<guid>-<time>-<tie>` (LOG-R116).
---@class PaglePartyCatchMessage
---@field guid string
---@field time integer
---@field tie integer
---@field zone integer
---@field copy string
---@field sourceId string

--- `text` read as a party catch message, or nil for anything that isn't exactly one (LOG-R113 item 3): at most the
--- addon message limit, kind `PC`, version 1, a player GUID as UnitGUID gives it, and a copy in the grammar of a G1's
--- (the C1 fields' own, a zone that isn't 0 and an item that isn't item 0), with no line feed.
---@param text any
---@return PaglePartyCatchMessage?
function ns.ParsePartyCatch(text)
	if type(text) ~= "string" or #text > ns.ADDON_MESSAGE_LIMIT then
		return nil
	end
	local guid, copy = text:match("^PC|1|([^|]*)|(.*)$")
	if
		not guid
		or #guid > GUID_LIMIT
		or not guid:find("^Player%-%d+%-[0-9A-F]+$")
		-- The copy in the G1 grammar, under a header of its own (logic/Integrity.lua, the backend's record contract).
		or ns.CanonicalRecordProblem("G1|1|0|0|" .. copy) ~= nil
	then
		return nil
	end
	local f = fields(copy)
	local time, tie, zone = tonumber(f[1]), tonumber(f[2]), tonumber(f[4])
	---@cast time integer
	---@cast tie integer
	---@cast zone integer
	return {
		guid = guid,
		time = time,
		tie = tie,
		zone = zone,
		copy = copy,
		sourceId = guid .. "-" .. f[1] .. "-" .. f[2],
	}
end

--- What the receiver and sender read and do (adapter/PartyCatches.lua builds it over the client). Every function is
--- called when needed, never stored.
---@class PaglePartyCatchesDeps
---@field isPlayer fun(sender: string?): boolean      -- the sender is the player (the client's echo, LOG-R113 item 1)
---@field on fun(): boolean                            -- the Party Hunts setting (LOG-R121)
---@field inParty fun(): boolean                       -- a home party of up to 5, never a raid (LOG-R110)
---@field groupmate fun(sender: string?): { guid: string?, name: string }? -- the party unit the sender is, with its
--- UnitGUID (nil where the client resolves none) and its full name (LOG-R113 item 4, LOG-R116)
---@field catchLog fun(): PagleCatchLog
---@field character fun(): integer?                    -- the logged-in character's index (LOG-R25)
---@field now fun(): integer                           -- GetServerTime()
---@field wants fun(record: PaglePartyCatch): boolean  -- the Hunts filter (LOG-R114)
---@field append fun(copy: string, name: string, sourceId: string): PagleRecord? -- appends the G1 and hands it on
---@field send fun(text: string, castTime: integer)    -- puts a message in the party send queue (LOG-R112)

--- Core's party catches for one login: the receiver's memory of the Party Catches it logged lately (LOG-R113 item 8).
---@class PaglePartyCatches
---@field package deps PaglePartyCatchesDeps
---@field package recent { copy: string, at: integer }[]? the Party Catches appended lately, oldest first
---@field package recentLog table? the PagleLog `recent` was read from
local PartyCatches = {}
PartyCatches.__index = PartyCatches

---@param deps PaglePartyCatchesDeps
---@return PaglePartyCatches
function ns.NewPartyCatches(deps)
	return setmetatable({ deps = deps }, PartyCatches)
end

--- Sends the party catch message for `cast`, one of the Angler's own Casts just appended (LOG-R111): while the Party
--- Hunts setting is on, in a party, never for a synthetic Cast (`/pagle dev catch`), and only for a Cast that makes a
--- message. It goes to the send queue with the Cast's time, by which the queue drops it once too old (LOG-R112).
---@param cast PagleCast
---@param synthetic boolean? written by /pagle dev catch
function PartyCatches:Send(cast, synthetic)
	local deps = self.deps
	if synthetic or not deps.on() or not deps.inParty() then
		return
	end
	local catchLog = deps.catchLog()
	local entry = catchLog:Get(cast.seq)
	local character = catchLog.data.characters[cast.char]
	local text = entry and character and ns.PartyCatchText(cast, entry, character.guid)
	if text then
		deps.send(text, cast.time)
	end
end

-- The Party Catches appended in the last max party delay and clock slack together (LOG-R113 item 8): read back from
-- the log's end the first time (LOG-R105's TaggedBack), so a /reload remembers them, then kept as they are appended.
---@param self PaglePartyCatches
---@param now integer
---@return { copy: string, at: integer }[]
local function recent(self, now)
	local data = self.deps.catchLog().data
	local since = now - ns.PARTY_MAX_DELAY - ns.PARTY_CLOCK_SLACK
	if self.recentLog ~= data then
		local list = {}
		for _, entry in ns.LogBlocks.TaggedBack(data, "G1") do
			local at, copy = tostring(entry):match("^G1|%d+|(%d+)|%d+|(.*)$")
			at = tonumber(at)
			if not at or at < since then
				break
			end
			table.insert(list, 1, { copy = copy, at = at })
		end
		self.recent, self.recentLog = list, data
	end
	local list = self.recent --[[@as table]]
	while list[1] and list[1].at < since do
		table.remove(list, 1)
	end
	return list
end

--- Reads one message on the party catch prefix from `sender` (LOG-R113): checks it in order and, when it passes every
--- check, appends it as a Party Catch (LOG-R115). Returns the record appended, or nil and the number of the first check
--- it failed (0: not a party catch message at all, LOG-R110), so a message is dropped without a word at the first.
---@param text any
---@param sender string?
---@return PagleRecord?
---@return integer? failed
function PartyCatches:Receive(text, sender)
	local deps = self.deps
	if type(text) ~= "string" or text:match("^[^|]*") ~= ns.PARTY_CATCH_KIND then
		return nil, 0
	end
	-- 1. Not the player: the client echoes the player's own messages back.
	if deps.isPlayer(sender) then
		return nil, 1
	end
	-- 2. Party Hunts on, in a party (LOG-R110, LOG-R121).
	if not deps.on() or not deps.inParty() then
		return nil, 2
	end
	-- 3. Exactly the message, version 1.
	local message = ns.ParsePartyCatch(text)
	if not message then
		return nil, 3
	end
	-- 4. A groupmate, whose own GUID it carries.
	local member = deps.groupmate(sender)
	if not member or type(member.guid) ~= "string" or member.guid ~= message.guid then
		return nil, 4
	end
	-- 5. Not one of this Catch log's own characters (live only: the entry keeps no GUID).
	local catchLog = deps.catchLog()
	for _, character in ipairs(catchLog.data.characters) do
		if character.guid == message.guid then
			return nil, 5
		end
	end
	-- 6. In time.
	local now = deps.now()
	if message.time > now + ns.PARTY_CLOCK_SLACK or message.time < now - ns.PARTY_MAX_DELAY then
		return nil, 6
	end
	-- 7. Fishing in the same zone: the log's latest Cast is the current character's, in that zone, in the window.
	local char = deps.character()
	local last = catchLog:Last("cast") --[[@as PagleCast?]]
	if
		not char
		or not last
		or last.char ~= char
		or last.conditions.zone ~= message.zone
		or last.time < message.time - ns.PARTY_WINDOW
	then
		return nil, 7
	end
	-- 8. Not seen before: no Party Catch has the same copy.
	local seen = recent(self, now)
	for _, logged in ipairs(seen) do
		if logged.copy == message.copy then
			return nil, 8
		end
	end
	-- 9. Worth logging: the Hunts filter takes the record the entry would make.
	local draft = catchLog:Draft({ kind = "party", char = char, time = now, copy = message.copy })
	if
		not deps.wants(draft --[[@as PaglePartyCatch]])
	then
		return nil, 9
	end
	local record = deps.append(message.copy, member.name, message.sourceId)
	if record then
		seen[#seen + 1] = { copy = message.copy, at = now }
	end
	return record
end
