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

-- The character's fishing skill (LOG-R30): the profession on skill line 356 among GetProfessions(), or nil when it
-- has none or the client keeps any of it secret (CORE-R31).
---@param ... integer? GetProfessions()'s indices, nil where the character has no such profession
---@return { rank: integer, max: integer, mod: integer }?
local function readFishing(...)
	for i = 1, select("#", ...) do
		local index = select(i, ...)
		if index then
			local _, _, rank, max, _, _, skillLine, mod = GetProfessionInfo(index)
			if skillLine == FISHING_SKILL_LINE then
				if issecretvalue(rank) or issecretvalue(max) or issecretvalue(mod) then
					return nil
				end
				return { rank = rank, max = max, mod = mod }
			end
		end
	end
	return nil
end

--- Login step 2 (LOG-R1): adds or updates the logged-in character (LOG-R25) and makes it the current one.
function ns.SeeCharacter()
	local character = readCharacter()
	if character then
		ns.angler:SeeCharacter(character, GetServerTime())
	end
end

--- Login step 4 (LOG-R1): appends a build entry if the client's build differs from the last one logged (LOG-R36).
function ns.LogBuild()
	local version, build = GetBuildInfo()
	ns.angler:LogBuild(tonumber(build) --[[@as integer]], version, GetServerTime())
end

--- Reads fishing skill (LOG-R31): at login (LOG-R1 step 4), on SKILL_LINES_CHANGED and on CHAT_MSG_SKILL. A Skill
--- Reading appended fires `SkillChanged(reading)`; any change in rank or modifier then fires
--- `ConditionsChanged({"skill"})` (LOG-R32). Reads nothing before the character is known at PLAYER_LOGIN.
function ns.ReadSkill()
	if not (ns.angler and ns.angler.current) then
		return
	end
	local appended, changed = ns.angler:ReadSkill(readFishing(GetProfessions()), GetServerTime())
	if appended then
		ns.Fire("SkillChanged", appended)
	end
	if changed then
		ns.Fire("ConditionsChanged", { "skill" })
	end
end

Pagle.RegisterEvent(OWNER, "SKILL_LINES_CHANGED", ns.ReadSkill)
Pagle.RegisterEvent(OWNER, "CHAT_MSG_SKILL", ns.ReadSkill)

--- The Angler (LOG-R27): the log's logId, its characters, the current one's index (from PLAYER_LOGIN), each
--- character's latest Skill Reading and the highest skill rank among them. Shared and immutable (CORE-R18).
---@return Angler
function Pagle.GetAngler()
	return ns.angler:Get()
end
