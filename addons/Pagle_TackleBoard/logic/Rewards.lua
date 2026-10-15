if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- What a completion earns inside the Module and what keeps the Campfire burning (tackle-board.md › Completion and
-- rewards, The Campfire): pure functions over the projection's `tally`, `flies` and `fire` tables (TackleBoardState,
-- logic/Seams.lua), with the titles, the Fly Box's patterns and the milestones as data. The completions' ticket (#232)
-- calls them in TKB-R60's order; the projection (#231) starts the fire and closes days with them.

-- Titles (tackle-board.md › Data › Titles).

--- The eight title IDs in the Titles table's order, which breaks ties for "the latest title" (TKB-R106), each with
--- what earns it: `source` "tally" (that many goals done, TKB-R61), "campfire" (a Campfire of that many days,
--- TKB-R73) or "flybox" (every pattern tied, TKB-R62), and `need`, the count. The text is lore (TKB-R130): `ns.L`'s
--- `boardtitle.<id>.text`.
---@type { id: string, source: "tally"|"campfire"|"flybox", need: integer }[]
ns.TITLES = {
	{ id = "tally_25", source = "tally", need = 25 },
	{ id = "tally_100", source = "tally", need = 100 },
	{ id = "tally_500", source = "tally", need = 500 },
	{ id = "campfire_7", source = "campfire", need = 7 },
	{ id = "campfire_30", source = "campfire", need = 30 },
	{ id = "campfire_100", source = "campfire", need = 100 },
	{ id = "campfire_365", source = "campfire", need = 365 },
	{ id = "flybox", source = "flybox", need = 30 },
}

-- The tally (TKB-R61).

--- The tally titles by the combined count that earns them (tackle-board.md › Tunables: 25 / 100 / 500 goals).
local TALLY_TITLES = {}
for _, title in ipairs(ns.TITLES) do
	if title.source == "tally" then
		TALLY_TITLES[title.need] = title.id
	end
end

ns.Tally = {}

--- Counts one completed goal (TKB-R61): Notices and Expeditions separately, for life.
---@param tally { notices: integer, expeditions: integer } the projection's tally
---@param goalType TackleGoalType
---@return string? titleID the tally title the combined count just reached (25, 100 or 500 goals)
function ns.Tally.Add(tally, goalType)
	if goalType == "e" then
		tally.expeditions = tally.expeditions + 1
	else
		tally.notices = tally.notices + 1
	end
	return TALLY_TITLES[tally.notices + tally.expeditions]
end

-- The FNV-1a hash (LOG-R66 step 1), the Module's own (ADR 0001: no Core internals), on the client's `bit` library
-- (LuaBitOp, in .luacheckrc's WoW API inventory). The inline option below reaches that one line: the only client name
-- this logic/ file reads, as Core's logic/Size.lua reads it for LOG-R66.

local TWO_32 = 4294967296
local bxor, byte = bit.bxor, string.byte -- luacheck: read globals bit

--- FNV-1a 32-bit over a string's bytes (LOG-R66 step 1): `h = 2166136261`; for each byte `c`, `h = bxor(h, c) % 2^32`,
--- then `h * 16777619 mod 2^32`, split so no product passes 2^53. Every `bit` result is taken mod 2^32, as LuaBitOp's
--- are signed.
---@param text string
---@return integer h in [0, 2^32)
function ns.Fnv1a(text)
	local h = 2166136261
	for i = 1, #text do
		h = bxor(h, byte(text, i)) % TWO_32
		h = ((h % 256) * 16777216 + h * 403) % TWO_32 -- h * 16777619 mod 2^32
	end
	return h
end

-- The Fly Box (TKB-R62).

--- Interface\Icons\<name>, an in-client icon texture.
---@param name string
---@return string
local function icon(name)
	return "Interface\\Icons\\" .. name
end

--- The Fly Box's 30 patterns in pattern order (tackle-board.md › Data › Fly Box patterns): 24 common, then 6 rare.
--- Each has its lore ID (its name is `ns.L`'s `fly.<id>.name`, TKB-R130), whether it is rare (tied only by
--- Expeditions), and an in-client icon texture (M7 graph, open question 4; custom fly art comes after 1.0). The drawer
--- fills its 6 × 5 compartments in this order (TKB-R106), and changing the order changes which goal ties which pattern
--- (TKB-R81: it raises TKB_RULES_VERSION).
---@type { id: string, rare: boolean, icon: string }[]
ns.FLY_PATTERNS = {
	{ id = "murloc_nymph", rare = false, icon = icon("INV_Misc_MonsterScales_03") },
	{ id = "westfall_wheatwing", rare = false, icon = icon("INV_Feather_04") },
	{ id = "goldshire_gnat", rare = false, icon = icon("INV_Feather_01") },
	{ id = "duskwood_shadow", rare = false, icon = icon("INV_Feather_06") },
	{ id = "redridge_ember", rare = false, icon = icon("INV_Feather_05") },
	{ id = "barrens_dun", rare = false, icon = icon("INV_Feather_07") },
	{ id = "mudsnout_woolly", rare = false, icon = icon("INV_Fabric_Wool_01") },
	{ id = "gnomish_whirligig", rare = false, icon = icon("INV_Misc_Gear_01") },
	{ id = "tarnished_spoon", rare = false, icon = icon("INV_Misc_Orb_03") },
	{ id = "ashenvale_olive", rare = false, icon = icon("INV_Misc_Herb_10") },
	{ id = "kodo_hair_caddis", rare = false, icon = icon("INV_Misc_LeatherScrap_02") },
	{ id = "elwynn_royal", rare = false, icon = icon("INV_Feather_08") },
	{ id = "swamp_midge", rare = false, icon = icon("INV_Misc_Herb_07") },
	{ id = "raptor_quill", rare = false, icon = icon("INV_Feather_09") },
	{ id = "silverpine_spinner", rare = false, icon = icon("INV_Misc_Orb_01") },
	{ id = "lakeshire_coachman", rare = false, icon = icon("INV_Feather_10") },
	{ id = "bloodsail_streamer", rare = false, icon = icon("INV_Fabric_Silk_01") },
	{ id = "booty_bay_bucktail", rare = false, icon = icon("INV_Misc_Pelt_Wolf_01") },
	{ id = "desolace_drifter", rare = false, icon = icon("INV_Feather_11") },
	{ id = "grimtotem_hackle", rare = false, icon = icon("INV_Feather_12") },
	{ id = "needles_ant", rare = false, icon = icon("INV_Misc_MonsterClaw_02") },
	{ id = "feralas_fern", rare = false, icon = icon("INV_Misc_Herb_09") },
	{ id = "tanaris_sandfly", rare = false, icon = icon("INV_Misc_Dust_02") },
	{ id = "darkshore_dun", rare = false, icon = icon("INV_Feather_13") },
	{ id = "nats_golden_doctor", rare = true, icon = icon("Spell_Holy_HolyBolt") },
	{ id = "kraken_ink_streamer", rare = true, icon = icon("INV_Misc_MonsterTail_03") },
	{ id = "phoenix_hackle", rare = true, icon = icon("Spell_Fire_Incinerate") },
	{ id = "moonwell_silverwing", rare = true, icon = icon("INV_Fabric_Moonrag_01") },
	{ id = "thunderhead_tiger", rare = true, icon = icon("Spell_Nature_Lightning") },
	{ id = "deepwater_duchess", rare = true, icon = icon("INV_Misc_Gem_Pearl_03") },
}

--- The icons of the ledge and the moments that have no fly or goal kind (TKB-R86, TKB-R106; M7 graph, open question
--- 4): the Campfire's flame, the tally plate and the Fly Box.
ns.REWARD_ICONS = {
	campfire = icon("Spell_Fire_Fire"),
	tally = icon("INV_Misc_Note_01"),
	flyBox = icon("INV_Box_01"),
}

ns.FlyBox = {}

--- A copy of a completed goal for its fly's hover text ("when and by which goal", TKB-R106): everything but its
--- distinct-count keys, so pruning the goal (Data: 28 board days) or changing it later never changes the copy.
---@param goal TackleGoal
---@return TackleGoal
local function copyGoal(goal)
	local copy = {}
	for key, value in pairs(goal) do
		if key ~= "seen" then
			copy[key] = value
		end
	end
	if goal.items then
		copy.items = { unpack(goal.items) }
	end
	copy.seen = {}
	return copy
end

--- Ties a fly for a completed goal (TKB-R62): a Notice an untied common pattern; an Expedition an untied rare one, or
--- an untied common one once every rare one is tied. The pattern is `pool[(h mod #pool) + 1]`, `pool` the untied
--- candidates in pattern order and `h` the FNV-1a of the goal's ID. The pattern is recorded in `flies` (on the goal's
--- done day and time, with a copy of the goal) and the goal's `fly` set to it, so it is never tied again.
---@param flies { [string]: { day: integer, time: integer, goal: TackleGoal } } the projection's flies
---@param goal TackleGoal the goal, marked done (TKB-R60: its doneDay and doneTime set)
---@return string? patternID nil when nothing in its pool is untied
function ns.FlyBox.Tie(flies, goal)
	-- The untied patterns of one rarity, in pattern order.
	local function untied(rare)
		local pool = {}
		for _, pattern in ipairs(ns.FLY_PATTERNS) do
			if pattern.rare == rare and not flies[pattern.id] then
				pool[#pool + 1] = pattern.id
			end
		end
		return pool
	end
	local pool = untied(goal.type == "e")
	if goal.type == "e" and #pool == 0 then
		pool = untied(false)
	end
	if #pool == 0 then
		return nil
	end
	local patternID = pool[ns.Fnv1a(goal.id) % #pool + 1]
	goal.fly = patternID
	flies[patternID] = { day = goal.doneDay, time = goal.doneTime, goal = copyGoal(goal) }
	return patternID
end

--- Whether every pattern is tied: the Fly Box title, `flybox` (TKB-R60, TKB-R62).
---@param flies { [string]: table } the projection's flies
---@return boolean
function ns.FlyBox.IsFull(flies)
	for _, pattern in ipairs(ns.FLY_PATTERNS) do
		if not flies[pattern.id] then
			return false
		end
	end
	return true
end

-- Coins paid (tackle-board.md › Coins paid, Tunables): what generation stamps on a goal (TKB-R34) and what the
-- lifetime Coins sum adds up (TKB-R63).

--- A Notice's pay by tier 1 / 2 / 3 (TKB-R34).
ns.NOTICE_PAY = { 10, 15, 20 }

--- An Expedition's pay (TKB-R34); the poster's seal shows it (TKB-R102).
ns.EXPEDITION_PAY = 60

--- The Campfire milestones in order (TKB-R73): the count that reaches one, its Coins and its title.
---@type { days: integer, coins: integer, title: string }[]
ns.CAMPFIRE_MILESTONES = {
	{ days = 7, coins = 25, title = "campfire_7" },
	{ days = 30, coins = 75, title = "campfire_30" },
	{ days = 100, coins = 200, title = "campfire_100" },
	{ days = 365, coins = 500, title = "campfire_365" },
}

-- The Campfire (TKB-R70–R74) and its four-week log (TKB-R106).

--- Kindling at Start and after a fire goes out (TKB-R71, TKB-R72).
local KINDLING_START = 2
--- The Kindling cap (TKB-R70); the ledge draws this many sticks (TKB-R106).
ns.KINDLING_CAP = 3
local KINDLING_CAP = ns.KINDLING_CAP
--- Lit days of the current fire per Kindling earned (TKB-R70).
local KINDLING_EVERY = 7

---@alias TackleFire { count: integer, kindling: integer, longest: integer, milestones: { [integer]: { day: integer, cast: string? } }, log: { [integer]: TackleDayLog } }

--- Logs board day `day` in the fire's log and drops every day older than the last ns.KEPT_DAYS (TKB-R106: today and
--- the 27 before it).
---@param fire TackleFire
---@param day integer
---@param outcome TackleDayLog
local function logDay(fire, day, outcome)
	fire.log[day] = outcome
	for logged in pairs(fire.log) do
		if logged <= day - ns.KEPT_DAYS then
			fire.log[logged] = nil
		end
	end
end

ns.Campfire = {}

--- Readies the fire for a started board: 2 Kindling (TKB-R71). The `start` record's apply calls it.
---@param fire TackleFire the projection's fire
function ns.Campfire.Start(fire)
	fire.kindling = KINDLING_START
end

--- Lights board day `day` on its first completion only (TKB-R70): the count rises by 1, the longest becomes
--- `max(longest, count)`, and a count that reaches a multiple of 7 adds a Kindling (cap 3). The first time the count
--- reaches 7, 30, 100 or 365 the milestone pays its Coins with its title, once per Angler (TKB-R73): it is kept in
--- `fire.milestones` with the day and the completing Cast.
---@param fire TackleFire the projection's fire
---@param day integer the board day the goal was done on
---@param cast string? the completing Cast's entry ID, kept with a milestone it reaches
---@return { lit: boolean, milestone: { days: integer, coins: integer, title: string }? } result `lit` false when the day was already lit (nothing changed)
function ns.Campfire.Light(fire, day, cast)
	if fire.log[day] == "lit" then
		return { lit = false }
	end
	fire.count = fire.count + 1
	fire.longest = math.max(fire.longest, fire.count)
	if fire.count % KINDLING_EVERY == 0 then
		fire.kindling = math.min(KINDLING_CAP, fire.kindling + 1)
	end
	logDay(fire, day, "lit")
	local result = { lit = true }
	for _, milestone in ipairs(ns.CAMPFIRE_MILESTONES) do
		if fire.count == milestone.days and not fire.milestones[milestone.days] then
			fire.milestones[milestone.days] = { day = day, cast = cast }
			result.milestone = { days = milestone.days, coins = milestone.coins, title = milestone.title }
		end
	end
	return result
end

--- Closes board day `day` (TKB-R14) and logs it (TKB-R106). A lit day is "lit". A day that wasn't lit (TKB-R72): with
--- a count above 0, it burns a Kindling and keeps the count ("burned"), or with none left the fire goes out (count 0,
--- Kindling back to 2, "out"); with a count of 0 nothing changes ("unlit"). The longest is kept for good (TKB-R74).
---@param fire TackleFire the projection's fire
---@param day integer
---@param lit boolean whether a goal was done on it
---@return TackleDayLog outcome
function ns.Campfire.CloseDay(fire, day, lit)
	local outcome
	if lit then
		outcome = "lit"
	elseif fire.count == 0 then
		outcome = "unlit"
	elseif fire.kindling > 0 then
		fire.kindling = fire.kindling - 1
		outcome = "burned"
	else
		fire.count = 0
		fire.kindling = KINDLING_START
		outcome = "out"
	end
	logDay(fire, day, outcome)
	return outcome
end
