---@class PagleNS
local ns = select(2, ...)

local VERIFICATION_VERSION = 2

local REASONS = {
	action_requires_review = true,
	source_invalid = true,
	conflicting_observation = true,
	source_order_incompatible = true,
	character_mapping = true,
	capacity_limit = true,
}

---@param value string
---@return string
local function hex(value)
	assert(#value == 64 and value:find("^[0-9a-f]+$"), "invalid Recovery digest")
	return value
end

---@param value any
---@param seen table?
---@return any
local function copy(value, seen)
	if type(value) ~= "table" then
		return value
	end
	seen = seen or {}
	if seen[value] then
		return seen[value]
	end
	local result = {}
	seen[value] = result
	for key, item in pairs(value) do
		result[copy(key, seen)] = copy(item, seen)
	end
	return result
end

---@param data any
---@param keys table<string, PaglePushedKey>
---@return PaglePushedKey
local function envelopeKey(data, keys)
	assert(type(data) == "table" and getmetatable(data) == nil, "invalid Recovery envelope")
	for key in pairs(data) do
		assert(key == "v" or key == "keyId" or key == "payload" or key == "sig", "unknown Recovery field")
	end
	assert(
		data.v == 1 and type(data.keyId) == "string" and #data.keyId <= 32 and data.keyId:find("^[A-Za-z0-9_%-]+$"),
		"invalid Recovery version or key ID"
	)
	local key = assert(keys[data.keyId], "unknown Recovery key")
	assert(
		type(data.payload) == "string" and #data.payload <= 4 * math.ceil(ns.RECOVERY_DATA_CAP / 3),
		"Recovery payload too large"
	)
	assert(type(data.sig) == "string" and #data.sig == 344, "invalid Recovery signature")
	return key
end

---@param data table
---@param key PaglePushedKey
---@return table
local function planFrom(data, key)
	local payload = assert(ns.Base64Decode(data.payload))
	local signature = assert(ns.Base64Decode(data.sig))
	local signed = "PGL-RECOVERY|1|" .. data.keyId .. "|" .. #payload .. "|" .. payload
	assert(ns.RsaVerify(key, signature, ns.Sha256(signed)), "Recovery signature does not match")
	local read, finish = ns.RecoveryReader(payload, "PGL-RECOVERY-DATA|1\n")
	local id = hex(read())
	local bodyAt = #"PGL-RECOVERY-DATA|1\n" + #tostring(#id) + 1 + #id + 1 + 1
	assert(ns.RecoveryDigest(payload:sub(bodyAt)) == id, "Recovery application ID does not match")
	assert(read() == "app.pagle.recovery", "wrong Recovery application")
	local plan = {
		applicationId = id,
		logId = read(),
		format = ns.RecoveryNatural(read()),
		seq = ns.RecoveryNatural(read()),
		digest = hex(read()),
		revision = ns.RecoveryNatural(read()),
		rules = read(),
		expectedDigest = hex(read()),
		resultDigest = hex(read()),
	}
	assert(
		plan.format == 3 and plan.rules ~= "" and #plan.rules <= 1024 and plan.rules:find("^[A-Za-z0-9_.%-]+$"),
		"invalid Recovery rules or format"
	)
	local replacement = read()
	assert(ns.RecoveryDigest(replacement) == plan.resultDigest, "Recovery result digest does not match")
	plan.replacement = ns.RecoveryReadSnapshot(replacement)
	assert(
		plan.replacement.logId == plan.logId and plan.replacement.format == plan.format,
		"Recovery target does not match"
	)
	assert(plan.seq <= #plan.replacement.entries, "Recovery prefix exceeds replacement")
	local checkpoint = ns.CheckpointInitial(plan.logId, plan.format)
	for seq, entry in ipairs(plan.replacement.entries) do
		assert(not ns.CanonicalRecordProblem(entry), "invalid Recovery record")
		local index = tonumber(entry:match("^[^|]+|([0-9]+)|"))
		local character = assert(plan.replacement.characters[index], "invalid Recovery character mapping")
		if seq <= plan.seq then
			checkpoint = ns.CheckpointNext(checkpoint, seq, character.guid, entry)
		end
	end
	assert(checkpoint == plan.digest, "Recovery checkpoint does not match")
	local count = ns.RecoveryNatural(read())
	assert(count <= 100000, "too many staged Recovery records")
	plan.staged = {}
	local previous = 0
	for i = 1, count do
		local seq, reason = ns.RecoveryNatural(read()), read()
		assert(seq > previous and REASONS[reason], "invalid staged Recovery record")
		plan.staged[i] = { seq = seq, reason = reason }
		previous = seq
	end
	finish()
	return plan
end

-- The receipt names the verified package by its signature, key and payload length, never its bytes: a package that
-- matches it can only be skipped, so a forged match changes nothing, while another payload can't carry the same
-- signature. Bump the receipt version if plan validation changes.
---@param archive table
---@param plan table
---@param data table
---@param key PaglePushedKey
local function rememberVerified(archive, plan, data, key)
	archive.applied = archive.applied or {}
	archive.applied[plan.applicationId] = {
		applicationId = plan.applicationId,
		resultDigest = plan.resultDigest,
		logId = plan.logId,
		verified = {
			version = VERIFICATION_VERSION,
			applicationId = plan.applicationId,
			resultDigest = plan.resultDigest,
			logId = plan.logId,
			format = plan.format,
			keyId = data.keyId,
			sig = data.sig,
			payloadLength = #data.payload,
			key = copy(key),
		},
	}
end

-- Whether `data` is a package this account already applied, to whatever log: a spent package changes nothing (RCV-R5).
---@param data table
---@param key PaglePushedKey
---@param archive any
---@return boolean
local function verifiedCompletion(data, key, archive)
	if type(archive) ~= "table" or type(archive.applied) ~= "table" then
		return false
	end
	for id, completed in pairs(archive.applied) do
		local verified = type(completed) == "table" and completed.verified
		if
			type(verified) == "table"
			and verified.version == VERIFICATION_VERSION
			and completed.applicationId == id
			and completed.applicationId == verified.applicationId
			and completed.resultDigest == verified.resultDigest
			and completed.logId == verified.logId
		then
			local knownKey = verified.key
			if
				verified.keyId == data.keyId
				and verified.sig == data.sig
				and verified.payloadLength == #data.payload
				and type(knownKey) == "table"
				and knownKey.n == key.n
				and knownKey.rr == key.rr
				and knownKey.n0inv == key.n0inv
			then
				return true
			end
		end
	end
	return false
end

-- The logId a package names, read from its first bytes and verified by nothing; nil when they don't read. It only
-- lets a package for another log be passed over without hashing it: a forged name can make a package skip itself,
-- never apply.
---@param data table
---@return string?
local function claimedLogId(data)
	local ok, logId = pcall(function()
		local read = ns.RecoveryReader(assert(ns.Base64Decode(data.payload:sub(1, 256))), "PGL-RECOVERY-DATA|1\n")
		read()
		assert(read() == "app.pagle.recovery")
		return read()
	end)
	return ok and logId or nil
end

-- Builds every published table first. No append, yield or external call occurs during publication.
---@param data any
---@param keys table<string, PaglePushedKey>
---@param log any
---@param archive any
---@param db any
---@return {log: table, archive: table, db: table}?
---@return table? verifiedArchive receipt upgrade for a completed plan, without restoring it again
---@return boolean? otherLog the package targets another Catch log (another account's, or a log since replaced)
function ns.RecoveryPrepare(data, keys, log, archive, db)
	local key = envelopeKey(data, keys)
	if verifiedCompletion(data, key, archive) then
		return nil
	end
	local logId = type(log) == "table" and log.logId or nil
	local claimed = claimedLogId(data)
	if claimed and claimed ~= logId then
		return nil, nil, true
	end
	local plan = planFrom(data, key)
	if plan.logId ~= logId then
		return nil, nil, true
	end
	assert(log.format == plan.format, "Recovery is for a different Catch log format")
	local completed = type(archive) == "table"
			and type(archive.applied) == "table"
			and archive.applied[plan.applicationId]
		or type(archive) == "table" and archive.completed
	if
		type(completed) == "table"
		and completed.applicationId == plan.applicationId
		and completed.resultDigest == plan.resultDigest
		and completed.logId == plan.logId
	then
		local saved = copy(archive)
		rememberVerified(saved, plan, data, key)
		return nil, saved
	end
	assert(
		ns.RecoveryDigest(ns.RecoverySnapshot(log)) == plan.expectedDigest,
		"Catch log changed; export a new Recovery snapshot"
	)
	for _, staged in ipairs(plan.staged) do
		assert(staged.seq <= #log.entries, "staged Recovery record is outside original log")
	end
	local saved = copy(type(archive) == "table" and archive or {})
	saved.archives = saved.archives or {}
	saved.archives[plan.applicationId] = {
		original = copy(log),
		staged = plan.staged,
		expectedDigest = plan.expectedDigest,
		resultDigest = plan.resultDigest,
		acceptedSeq = plan.seq,
		acceptedDigest = plan.digest,
		acceptedRevision = plan.revision,
		rules = plan.rules,
	}
	saved.completed = { applicationId = plan.applicationId, resultDigest = plan.resultDigest, logId = plan.logId }
	rememberVerified(saved, plan, data, key)
	local rebuilt = copy(type(db) == "table" and db or {})
	rebuilt.global = type(rebuilt.global) == "table" and rebuilt.global or {}
	local global = rebuilt.global
	for _, name in ipairs({
		"catchCounts",
		"sessionBreaks",
		"lastBuild",
		"lastEndedSession",
		"decodeErrors",
		"projections",
		"coins",
		"activityXP",
		"tickets",
		"goods",
		"summary",
		"pending",
		"cards",
		"writeUp",
		"pasteExports",
		"pasteCheckpoints",
	}) do
		global[name] = nil
	end
	global.recoveryGeneration = plan.applicationId
	return { log = plan.replacement, archive = saved, db = rebuilt }
end
