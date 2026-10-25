---@class PagleNS
local ns = select(2, ...)

-- The character table, Skill Readings, build entries and the Angler (LOG-R25–R27, LOG-R31, LOG-R32, LOG-R36): pure
-- logic over the Catch log, with what the client reports passed in (CORE-R7).

--- One character in `PagleLog.characters` (LOG-R25, LOG-R26). Characters are keyed by GUID, never by name.
---@class PagleCharacter
---@field guid string
---@field name string
---@field surname? string        -- Forever's second name (UnitName's second return)
---@field classID integer
---@field raceID integer
---@field faction string
---@field realmID integer
---@field hardcore? boolean      -- nil when the client has no C_GameRules.IsHardcoreActive
---@field firstSeen integer      -- server time
---@field lastSeen integer       -- server time

--- The player's fishing identity across every character in this PagleLog (LOG-R27). Shared and immutable
--- (CORE-R18).
---@class Angler
---@field logId string?          -- nil only on a fresh install before the first PLAYER_LOGIN
---@field characters PagleCharacter[]
---@field current integer?       -- index of the logged-in character; nil before PLAYER_LOGIN
---@field skill { [integer]: PagleSkillReading }   -- latest Skill Reading per character index
---@field bestBaseSkill integer  -- highest skill rank among all characters (0 if none)

-- The display fields PLAYER_LOGIN refreshes on a known character (LOG-R26).
local DISPLAY_FIELDS = { "name", "surname", "classID", "raceID", "faction", "realmID", "hardcore" }

--- The realm ID inside a player GUID ("Player-4618-0A1B2C3D" is 4618), or nil for any other GUID (LOG-R26).
---@param guid string
---@return integer?
function ns.RealmIDFromGUID(guid)
	return tonumber(string.match(guid, "^Player%-(%d+)%-"))
end

--- Core's view of the characters and their skill over one Catch log, for one login.
---@class PagleAnglerState
---@field catchLog PagleCatchLog
---@field current integer?
---@field skill { [integer]: PagleSkillReading }? each character's last Skill Reading, once looked up
local AnglerState = {}
AnglerState.__index = AnglerState

--- Adds the logged-in character to `PagleLog.characters` if its GUID is new, or updates `lastSeen` and the display
--- fields if not (LOG-R25), and makes it the current one. `seen` holds the display fields as the client reports
--- them (LOG-R26), kept with any line feed stripped from their text (LOG-R101); nothing else in it is kept. A log
--- without a logId gets one now (LOG-R15).
---@param seen { guid: string, name: string, surname: string?, classID: integer, raceID: integer, faction: string, realmID: integer, hardcore: boolean? }
---@param now integer server time
---@return integer index
function AnglerState:SeeCharacter(seen, now)
	local characters = self.catchLog.data.characters
	local index, character
	for i, known in ipairs(characters) do
		if known.guid == seen.guid then
			index, character = i, known
			break
		end
	end
	if not character then
		index = #characters + 1
		character = { guid = seen.guid, firstSeen = now }
		characters[index] = character
	end
	for _, field in ipairs(DISPLAY_FIELDS) do
		local value = seen[field]
		-- No line feed goes to the log, its character table included (LOG-R101).
		if type(value) == "string" then
			value = (string.gsub(value, "\n", ""))
		end
		character[field] = value
	end
	character.lastSeen = now
	self.current = index
	self.catchLog:EnsureLogId(now)
	return index
end

-- Each character's last Skill Reading, by character index: found once by walking the log back (LOG-R31), then
-- kept up to date by ReadSkill, the only writer of Skill Readings.
---@param self PagleAnglerState
---@return { [integer]: PagleSkillReading }
local function latestSkills(self)
	if not self.skill then
		local skill, missing = {}, #self.catchLog.data.characters
		for reading in self.catchLog:Reverse("skill") do
			if missing == 0 then
				break
			end
			if not skill[reading.char] then
				skill[reading.char] = reading
				missing = missing - 1
			end
		end
		self.skill = skill
	end
	return self.skill
end

--- Takes a fishing skill reading for the current character (LOG-R30): `{ rank, max, mod }`, or nil when it has no
--- Fishing. Appends a Skill Reading when the rank or max rank differs from the character's last one, or it has
--- none; a change in modifier alone appends nothing (LOG-R31). Returns the appended record, for `SkillChanged`
--- (LOG-R32). Reads nothing while no character is current.
---@param reading { rank: integer, max: integer, mod: integer }?
---@param now integer server time
---@return PagleSkillReading? appended
function AnglerState:ReadSkill(reading, now)
	local char = self.current
	if not char or not reading then
		return nil
	end
	local last = latestSkills(self)[char]
	if last and last.rank == reading.rank and last.max == reading.max then
		return nil
	end
	local appended = self.catchLog:Append({
		kind = "skill",
		char = char,
		time = now,
		rank = reading.rank,
		max = reading.max,
		mod = reading.mod,
	})
	---@cast appended PagleSkillReading
	self.skill[char] = appended
	return appended
end

--- Appends a build entry for the current character when `build` differs from the last build entry in the log
--- (LOG-R36), and returns it. The last one is cached in `PagleDB.global.lastBuild` as `{ logId, build }`; a
--- missing cache, or one of another logId, is rebuilt by walking the log back to its last build entry. Appends
--- nothing while no character is current.
---@param build integer the GetBuildInfo() build number
---@param version string e.g. "1.60.1"
---@param now integer server time
---@return PagleBuild?
function AnglerState:LogBuild(build, version, now, rules)
	rules = rules or ns.RULE_SET_ID
	local char, data, global = self.current, self.catchLog.data, self.catchLog.global
	if not char then
		return nil
	end
	local cache = global.lastBuild
	if type(cache) ~= "table" or cache.logId ~= data.logId then
		local last = self.catchLog:Reverse("build")() --[[@as PagleBuild?]]
		cache = { logId = data.logId, build = last and last.build, rules = last and last.rules }
		global.lastBuild = cache
	end
	if cache.build == build and cache.rules == rules then
		return nil
	end
	local appended = self.catchLog:Append({ kind = "build", char = char, time = now, build = build, version = version, rules = rules })
	---@cast appended PagleBuild
	global.lastBuild = { logId = data.logId, build = build, rules = rules }
	return appended
end

--- The Angler (LOG-R27): the log's logId and characters, the current character, each character's last Skill
--- Reading and the highest rank among them. Its tables are the log's own, shared and never copied (CORE-R18).
---@return Angler
function AnglerState:Get()
	local skill, best = latestSkills(self), 0
	for _, reading in pairs(skill) do
		best = math.max(best, reading.rank)
	end
	local data = self.catchLog.data
	return {
		logId = data.logId,
		characters = data.characters,
		current = self.current,
		skill = skill,
		bestBaseSkill = best,
	}
end

--- Core's Angler state over `catchLog` (LOG-R27). No character is current until `SeeCharacter`.
---@param catchLog PagleCatchLog
---@return PagleAnglerState
function ns.NewAngler(catchLog)
	return setmetatable({ catchLog = catchLog }, AnglerState)
end
