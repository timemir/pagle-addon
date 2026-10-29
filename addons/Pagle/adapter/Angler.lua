---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The character table, Skill Readings and build entries, read from the client (LOG-R25–R27, LOG-R30–R32,
-- LOG-R36). adapter/Login.lua calls the login steps in their place (LOG-R1). Its own owner, so no other Core file's
-- registration replaces these.
local OWNER = "Pagle Angler"

-- Fishing's skill line (LOG-R30).
local FISHING_SKILL_LINE = 356

--- Payload of `SkillChanged`: the Skill Reading just appended (LOG-R32).
---@alias PagleSkillChangedHandler fun(event: "SkillChanged", reading: PagleSkillReading)

-- The logged-in character as the client describes it (LOG-R26), or nil without a GUID to key it by. `hardcore`
-- stays nil on a client without C_GameRules.IsHardcoreActive.
local function readCharacter()
	local guid = UnitGUID("player")
	if not guid or issecretvalue(guid) then
		return nil
	end
	local name, surname = UnitName("player")
	local hardcore
	if C_GameRules and C_GameRules.IsHardcoreActive then
		hardcore = C_GameRules.IsHardcoreActive()
	end
	return {
		guid = guid,
		name = name,
		surname = surname ~= "" and surname or nil,
		classID = select(3, UnitClass("player")),
		raceID = select(3, UnitRace("player")),
		faction = (UnitFactionGroup("player")),
		realmID = ns.RealmIDFromGUID(guid),
		hardcore = hardcore,
	}
end

-- The fishing skill of the profession on skill line 356 among `...`, GetProfessions()'s indices.
---@param ... integer? nil where the character has no such profession
---@return integer? rank
---@return integer? max
---@return integer? mod
local function readFishing(...)
	for i = 1, select("#", ...) do
		local index = select(i, ...)
		if index ~= nil and not issecretvalue(index) then
			local _, _, rank, max, _, _, skillLine, mod = GetProfessionInfo(index)
			if not issecretvalue(skillLine) and skillLine == FISHING_SKILL_LINE then
				return ns.UnlessSecret(issecretvalue, rank),
					ns.UnlessSecret(issecretvalue, max),
					ns.UnlessSecret(issecretvalue, mod)
			end
		end
	end
	return nil, nil, nil
end

--- Fishing's rank, max rank and modifier (LOG-R30): `GetProfessions()`, then `GetProfessionInfo` on the index whose
--- skill line is 356 (on build 70338 that's the 4th return). Each is nil while secret (CORE-R31), all three without
--- the profession. The one skill reader: Skill Readings (LOG-R31) and the conditions' skill key (LOG-R20) use it.
---@return integer? rank
---@return integer? max
---@return integer? mod
function ns.ReadFishingSkill()
	return readFishing(GetProfessions())
end

--- Login step 2 (LOG-R1): adds or updates the logged-in character (LOG-R25) and makes it the current one.
function ns.SeeCharacter()
	local character = readCharacter()
	if character then
		ns.angler:SeeCharacter(character, GetServerTime())
	end
end

--- Login step 4 (LOG-R1): appends a build entry if the client's build differs from the last one logged (LOG-R36),
--- and hands it to the projections live (LOG-R73).
function ns.LogBuild()
	local version, build = GetBuildInfo()
	local appended = ns.angler:LogBuild(tonumber(build) --[[@as integer]], version, GetServerTime())
	if appended then
		ns.projections:Live(appended) -- LOG-R73
	end
end

--- Reads fishing skill (LOG-R31): at login (LOG-R1 step 4), on SKILL_LINES_CHANGED and on CHAT_MSG_SKILL. A Skill
--- Reading appended fires `SkillChanged(reading)` (LOG-R31, LOG-R32); a reading with any part secret appends
--- nothing. Then the conditions service re-reads its skill key, firing `ConditionsChanged({"skill"})` once if rank
--- or modifier changed since its last reading (LOG-R32, LOG-R47), so the event and Pagle.GetConditions agree.
--- Neither happens before PLAYER_LOGIN, when the character is known and the service started.
function ns.ReadSkill()
	if ns.angler and ns.angler.current then
		ns.LogBuild() -- skill events can arrive before PLAYER_ENTERING_WORLD's declaration
		local rank, max, mod = ns.ReadFishingSkill()
		local reading = (rank and max and mod) and { rank = rank, max = max, mod = mod } or nil
		local appended = ns.angler:ReadSkill(reading, GetServerTime())
		if appended then
			ns.projections:Live(appended) -- before SkillChanged (LOG-R73)
			ns.Fire("SkillChanged", appended)
		end
	end
	ns.RefreshConditions("skill")
end

Pagle.RegisterEvent(OWNER, "SKILL_LINES_CHANGED", ns.ReadSkill)
Pagle.RegisterEvent(OWNER, "CHAT_MSG_SKILL", ns.ReadSkill)

--- The Angler (LOG-R27): the log's logId, its characters, the current one's index (from PLAYER_LOGIN), each
--- character's latest Skill Reading and the highest skill rank among them. Shared and immutable (CORE-R18).
---@return Angler
function Pagle.GetAngler()
	return ns.angler:Get()
end
