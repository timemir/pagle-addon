---@class PagleNS
local ns = select(2, ...)

-- Core's pushed-content reader (core/pushed-content.md, ADR 0013): the companion's data addon, Pagle_Content, sets
-- PagleContentData; Core reads it once at PLAYER_LOGIN, checks it over frames in a coroutine within a per-frame
-- budget (PUSH-R10–R13), and hands each Module the checked items of the kinds it asks for (PUSH-R20–R23), with the
-- companion's state (PUSH-R15, PUSH-R16). Pure logic over what it's handed (CORE-R7): logic/Wiring.lua's
-- ns.WirePushedContent hands it the client's seams, or FakePagle's. Core never writes the file, and never logs what it
-- hands out.

local floor, max, concat = math.floor, math.max, table.concat

--- The file formats Core reads (PUSH-R13, Tunables).
ns.PUSHED_FILE_VERSIONS = { [1] = true }
--- The decoded payload's size cap, in bytes (PUSH-R13, Tunables): 64 KiB.
ns.PUSHED_SIZE_CAP = 65536
--- How old, in seconds, a checked file's generatedAt is when the companion reads as not running (PUSH-R15): 24 h.
ns.PUSHED_NOT_RUNNING_AGE = 24 * 3600
--- The check's time budget per frame, in ms (PUSH-R10, Tunables).
ns.PUSHED_CHECK_BUDGET = 4

-- Bytes hashed per step: about half a millisecond of SHA-256 in stock Lua 5.1 (#292 measured 4.5 ms per 4 KiB).
local HASH_CHUNK = 512
-- Of each frame's budget, the ms the pacer leaves unplanned, for a step that runs longer than its kind has yet: the
-- collector's work lands in some step's time.
local HEADROOM = 0.5
-- The largest integer a header field holds: exact in a double.
local LARGEST = 2 ^ 53

---@alias PagleCompanionState "checking"|"missing"|"notRunning"|"connected"
---@alias PaglePushedContentReadyHandler fun(event: "PushedContentReady", state: PagleCompanionState)

local CHECKING, MISSING, NOT_RUNNING, CONNECTED = "checking", "missing", "notRunning", "connected"
local ENDED = { [MISSING] = true, [NOT_RUNNING] = true, [CONNECTED] = true }

--- Why there's no PagleContentData, as the client tells it.
---@class PaglePushedPresence
---@field installed boolean Pagle_Content is in the AddOns folder
---@field loaded boolean it loaded this session
---@field reason string? why it didn't load, as the client names it (GetAddOnInfo's reason: "DISABLED", …)

--- What the reader is fed. Every function is called when needed, never stored.
---@class PaglePushedContentOptions
---@field data fun(): any                       -- PagleContentData, read once when the check starts (PUSH-R1)
---@field presence fun(): PaglePushedPresence   -- why there's no file, read only then
---@field keys fun(): table<string, PaglePushedKey> -- the public keys by keyId (ns.PUSHED_KEYS, PUSH-R12)
---@field global fun(): table                   -- PagleDB.global, whose pushed.seq is the last accepted seq
---@field serverTime fun(): integer             -- GetServerTime()
---@field clock fun(): number                   -- a clock in ms, for the per-frame budget (debugprofilestop)
---@field nextFrame fun(step: fun())            -- runs step on the next frame
---@field fire fun(state: PagleCompanionState)  -- fires PushedContentReady(state) (PUSH-R16)
---@field report fun(message: string)           -- reports an error and carries on
---@field budget number?                        -- ms per frame; default PUSHED_CHECK_BUDGET

--- How the check ended, for Finish.
---@class PaglePushedOutcome
---@field state PagleCompanionState
---@field items table[]? the parsed items, in payload order, for "connected" and "notRunning"
---@field reason string? why the file is absent, for "missing" (PUSH-R13)

--- Core's pushed content for this login.
---@class PaglePushedContent
---@field package options PaglePushedContentOptions
---@field package state PagleCompanionState
---@field package started boolean
---@field package data any the PagleContentData read at Start
---@field package reason string? the first reason PUSH-R13 found
---@field package kept table<string, table[]>? the items handed out, by kind
---@field package dropped table<string, integer>? the items dropped, by "kind v"
---@field package frames integer frames the check ran in
---@field package longest number its longest frame, in ms
local PushedContent = {}
PushedContent.__index = PushedContent

---@param options PaglePushedContentOptions
---@return PaglePushedContent
function ns.NewPushedContent(options)
	return setmetatable(
		{ options = options, state = CHECKING, started = false, frames = 0, longest = 0 },
		PushedContent
	)
end

-- Whether `value` is a whole number a header field may hold.
---@param value any
---@return boolean
local function isInteger(value)
	return type(value) == "number" and value == floor(value) and value >= -LARGEST and value <= LARGEST
end

-- A header field's integer as the canonical string writes it: plain decimal digits (PUSH-R11).
---@param value number
---@return string
local function decimal(value)
	return value == 0 and "0" or ("%.0f"):format(value)
end

-- PUSH-R2's fields in order, with the type each holds.
local FIELDS = {
	{ "v", "integer" },
	{ "generatedAt", "integer" },
	{ "keyId", "string" },
	{ "seq", "integer" },
	{ "expires", "integer" },
	{ "payload", "string" },
	{ "sig", "string" },
}

--- Paces a coroutine's steps against the per-frame budget (PUSH-R10). Before each step the check calls pause(kind):
--- it notes how long the last step took, keeping the costliest of each kind, and yields to the next frame when this
--- frame's time so far plus the costliest step of `kind` seen yet (the whole budget for a kind not yet seen) would
--- run past the budget less HEADROOM. A frame's first step always runs, so each frame moves the check on.
---@param clock fun(): number
---@param budget number
---@return { begin: fun(), pause: fun(kind: string) }
local function newPacer(clock, budget)
	budget = budget - HEADROOM
	local costs = {} ---@type table<string, number>
	local frameStart, mark = 0, 0
	local last ---@type string?
	local pacer = {}
	function pacer.begin()
		frameStart = clock()
		mark, last = frameStart, nil
	end
	function pacer.pause(kind)
		local now = clock()
		if last then
			costs[last] = max(costs[last] or 0, now - mark)
		end
		if last and now - frameStart + (costs[kind] or budget) > budget then
			coroutine.yield()
			now = clock()
		end
		last, mark = kind, now
	end
	return pacer
end

-- The check itself (PUSH-R13), in order, as the coroutine's body: an outcome, the first failure's reason with it.
---@param self PaglePushedContent
---@param pause fun(kind: string)
---@return PaglePushedOutcome
local function check(self, pause)
	local L, options, data = ns.L, self.options, self.data
	local function absent(reason)
		return { state = MISSING, reason = reason }
	end
	-- Fields and types (PUSH-R2), each read once into `file`: what's checked is what's used, whatever writes to the
	-- global meanwhile.
	if type(data) ~= "table" then
		return absent(L.PUSHED_NOT_TABLE)
	end
	local file = {}
	for _, field in ipairs(FIELDS) do
		local name, kind = field[1], field[2]
		local value = data[name]
		if value == nil then
			return absent(L.PUSHED_MISSING_FIELD:format(name))
		elseif kind == "integer" and not isInteger(value) then
			return absent(L.PUSHED_NOT_INTEGER:format(name))
		elseif kind == "string" and type(value) ~= "string" then
			return absent(L.PUSHED_NOT_STRING:format(name))
		end
		file[name] = value
	end
	if not ns.PUSHED_FILE_VERSIONS[file.v] then
		return absent(L.PUSHED_UNKNOWN_VERSION:format(decimal(file.v)))
	end
	local key = options.keys()[file.keyId]
	if not key then
		return absent(L.PUSHED_UNKNOWN_KEY:format(file.keyId))
	end
	-- Base64, the payload in steps (PUSH-R2).
	local signature, why = ns.Base64Decode(file.sig)
	if not signature then
		return absent(L.PUSHED_NOT_BASE64:format("sig", why))
	end
	local decode = ns.Base64DecodeSteps(file.payload)
	local decoded, bytes
	repeat
		pause("base64")
		decoded, bytes = decode()
	until decoded ~= nil
	if not decoded then
		return absent(L.PUSHED_NOT_BASE64:format("payload", bytes))
	end
	---@cast bytes string
	if #bytes > ns.PUSHED_SIZE_CAP then
		return absent(L.PUSHED_OVER_CAP:format(#bytes, ns.PUSHED_SIZE_CAP))
	end
	-- The signature (PUSH-R11): SHA-256 over the canonical header and the payload's bytes, then RSA, both in steps.
	local hash ---@type PagleSha256
	do
		-- The tables in steps first, held by the preparation until the hash holds them (#292's ns.Sha256Prepare).
		local prepare = ns.Sha256Prepare()
		repeat
			pause("tables")
		until prepare()
		hash = ns.NewSha256()
	end
	hash:Update(
		concat(
			{ decimal(file.v), decimal(file.generatedAt), file.keyId, decimal(file.seq), decimal(file.expires), "" },
			"|"
		)
	)
	for at = 1, #bytes, HASH_CHUNK do
		pause("hash")
		hash:Update(bytes:sub(at, at + HASH_CHUNK - 1))
	end
	pause("hash")
	local verify = ns.RsaVerifySteps(key, signature, hash:Final())
	local verified, problem
	repeat
		pause("rsa")
		verified, problem = verify()
	until verified ~= nil
	if not verified then
		return absent(L.PUSHED_BAD_SIGNATURE:format(problem))
	end
	-- The last accepted seq, then expiry (PUSH-R13, PUSH-R92).
	local global = options.global()
	local last = type(global.pushed) == "table" and global.pushed.seq or nil
	if type(last) == "number" and file.seq < last then
		return absent(L.PUSHED_LOWER_SEQ:format(decimal(file.seq), decimal(last)))
	end
	local now = options.serverTime()
	if now >= file.expires then
		return absent(L.PUSHED_EXPIRED:format(decimal(file.expires), decimal(now)))
	end
	-- The payload (PUSH-R20).
	local items, at, reason, arg = ns.ParsePayload(bytes, function()
		pause("parse")
	end)
	if not items then
		---@cast reason string
		return absent(L.PUSHED_PARSE_ERROR:format(at, L[reason]:format(tostring(arg))))
	end
	-- Accepted: its seq is the last accepted from now on (PUSH-R13).
	if type(global.pushed) ~= "table" then
		global.pushed = {}
	end
	global.pushed.seq = file.seq
	return { state = now - file.generatedAt >= ns.PUSHED_NOT_RUNNING_AGE and NOT_RUNNING or CONNECTED, items = items }
end

-- Why there's no file at all, from the client's word on Pagle_Content.
---@param presence PaglePushedPresence
---@return string
local function noFile(presence)
	local L = ns.L
	if not presence.installed then
		return L.PUSHED_NOT_INSTALLED
	elseif presence.loaded then
		return L.PUSHED_NO_DATA
	end
	return L.PUSHED_NOT_LOADED:format(presence.reason or "?")
end

--- Login step 2, after ModulesChanged (PUSH-R10): reads PagleContentData once and checks it, from the next frame on,
--- within the budget per frame. With no file at all the check ends at once, "missing". Only the first call counts.
function PushedContent:Start()
	if self.started then
		return
	end
	self.started = true
	local options = self.options
	self.data = options.data()
	if self.data == nil then
		self:Finish({ state = MISSING, reason = noFile(options.presence()) })
		return
	end
	local budget = options.budget or ns.PUSHED_CHECK_BUDGET
	local pacer = newPacer(options.clock, budget)
	local routine = coroutine.create(function()
		return check(self, pacer.pause)
	end)
	local function frame()
		pacer.begin()
		local started = options.clock()
		local ok, outcome = coroutine.resume(routine)
		self.frames = self.frames + 1
		self.longest = max(self.longest, options.clock() - started)
		if not ok then
			-- A fault in the check reads as an absent file, never a crash (PUSH-R13), and is reported.
			options.report(("Pagle: the pushed-content check failed: %s"):format(tostring(outcome)))
			self:Finish({ state = MISSING, reason = ns.L.PUSHED_CHECK_FAILED })
		elseif coroutine.status(routine) == "dead" then
			self:Finish(outcome)
		else
			options.nextFrame(frame)
		end
	end
	options.nextFrame(frame)
end

--- Ends the check with `outcome` (PUSH-R15, PUSH-R16): the state is fixed for the login from now on, the items of the
--- kinds and versions Core passes on are kept (PUSH-R21), and PushedContentReady(state) fires, once. Does nothing
--- once the check has ended. The check calls it; FakePagle's fake.setPushedContent does too.
---@param outcome PaglePushedOutcome
function PushedContent:Finish(outcome)
	assert(ENDED[outcome.state], "a check ends missing, notRunning or connected")
	if self.state ~= CHECKING then
		return
	end
	self.state = outcome.state
	if outcome.state == MISSING then
		self.reason = outcome.reason
	else
		self.kept, self.dropped = ns.KeepPushedItems(outcome.items or {})
	end
	self.options.fire(self.state)
end

--- The companion's state (PUSH-R15): "checking" until the check ends, then "missing", "notRunning" or "connected".
---@return PagleCompanionState
function PushedContent:State()
	return self.state
end

-- A deep copy of a parsed value.
---@param value any
---@return any
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, field in pairs(value) do
		out[key] = copy(field)
	end
	return out
end

--- The checked items of `kind` (PUSH-R22): a fresh array, in payload order, each a deep copy the caller may keep.
--- Empty while checking, when missing, or for a kind with no items; a notRunning file's items are handed out.
---@param kind any
---@return table[]
function PushedContent:Items(kind)
	local out = {}
	local list = self.kept and self.kept[kind]
	if list then
		for i, item in ipairs(list) do
			out[i] = copy(item)
		end
	end
	return out
end

-- A header field as `/pagle dev content` prints it: as read, or "none".
---@param value any
---@return string
local function shown(value)
	if value == nil then
		return ns.L.DEV_CONTENT_NONE
	elseif isInteger(value) then
		return decimal(value)
	end
	return tostring(value)
end

-- "kind count, kind count" in kind order, or "none".
---@param counts table<string, integer>
---@return string
local function listed(counts)
	local names = {}
	for name in pairs(counts) do
		names[#names + 1] = name
	end
	table.sort(names)
	for i, name in ipairs(names) do
		names[i] = ns.L.DEV_CONTENT_KIND:format(name, counts[name])
	end
	return #names > 0 and concat(names, ", ") or ns.L.DEV_CONTENT_NONE
end

--- `/pagle dev content` (PUSH-R14): the state, with the first reason PUSH-R13 found for an absent file; the header
--- fields as read; the kinds handed out and dropped, with their item counts; and the check's frames. Nothing else
--- ever names a reason.
---@return string[]
function PushedContent:Report()
	local L = ns.L
	local lines = {}
	if self.state == MISSING then
		lines[1] = L.DEV_CONTENT_ABSENT:format(self.reason or L.DEV_CONTENT_NONE)
	else
		lines[1] = L.DEV_CONTENT_STATE:format(self.state)
	end
	local data = type(self.data) == "table" and self.data or {}
	if self.data ~= nil then
		lines[#lines + 1] = L.DEV_CONTENT_HEADER:format(
			shown(data.generatedAt),
			shown(data.keyId),
			shown(data.seq),
			shown(data.expires)
		)
	end
	if self.kept then
		local counts = {}
		for kind, items in pairs(self.kept) do
			counts[kind] = #items
		end
		lines[#lines + 1] = L.DEV_CONTENT_KINDS:format(listed(counts))
		if next(self.dropped) then
			lines[#lines + 1] = L.DEV_CONTENT_DROPPED:format(listed(self.dropped))
		end
	end
	if self.frames > 0 then
		lines[#lines + 1] =
			L.DEV_CONTENT_FRAMES:format(self.frames, self.longest, self.options.budget or ns.PUSHED_CHECK_BUDGET)
	end
	return lines
end
