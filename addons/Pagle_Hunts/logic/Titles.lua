if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Set titles (HNT-R20–R23, HNT-R197): when a set's title is earned, from a Catch or from a retirement. Pure logic over
-- the projection state (hunts.md › Projection state) and the Hunt list (`ns.hunts`, read at call time). The
-- projection (#188) calls ns.CheckTitles in `apply` after each Cast and in `done` after each catch-up or rebuild; it
-- is the only writer of `state.sets`. Titles stay inside Hunts' own views (HNT-R22): nothing here hands them on.

local SECONDS_PER_DAY = 86400

---@class HuntsSetTitle            -- state.sets[setID], once earned (HNT-R23, HNT-R87)
---@field earnedAt integer         -- the server time it was earned at (HNT-R20)
---@field date { year: integer, month: integer, day: integer }   -- the earning tier's realm date, or the retired date's UTC day
---@field fromRetirement boolean   -- a retirement completed it, not the Cast just applied (HNT-R23)

--- The proleptic Gregorian date of a count of days since 1970-01-01 (Howard Hinnant's civil_from_days).
---@param days integer
---@return { year: integer, month: integer, day: integer }
local function civilFromDays(days)
	local z = days + 719468
	local era = math.floor(z / 146097)
	local dayOfEra = z - era * 146097
	local yearOfEra = math.floor(
		(dayOfEra - math.floor(dayOfEra / 1460) + math.floor(dayOfEra / 36524) - math.floor(dayOfEra / 146096)) / 365
	)
	local dayOfYear = dayOfEra - (365 * yearOfEra + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100))
	local monthFromMarch = math.floor((5 * dayOfYear + 2) / 153)
	local day = dayOfYear - math.floor((153 * monthFromMarch + 2) / 5) + 1
	local month = monthFromMarch < 10 and monthFromMarch + 3 or monthFromMarch - 9
	return { year = yearOfEra + era * 400 + (month <= 2 and 1 or 0), month = month, day = day }
end

-- A Hunt's tier 1 in `state`, or nil while it isn't done (HNT-R17). Later tiers never count (HNT-R21).
---@param state HuntsState
---@param hunt HuntDef
---@return HuntTier?
local function tierOne(state, hunt)
	local progress = state.hunts[hunt.id]
	return progress and progress.reached[1]
end

-- Whether the set of `setHunts` is complete at `t` (HNT-R20): at least one of them exists at `t`, and every one that
-- does has tier 1 reached at or before `t`.
---@param state HuntsState
---@param setHunts HuntDef[]
---@param t integer
---@return boolean
local function completeAt(state, setHunts, t)
	local any = false
	for _, hunt in ipairs(setHunts) do
		if ns.Exists(hunt, t) then
			local tier = tierOne(state, hunt)
			if not tier or tier.time > t then
				return false
			end
			any = true
		end
	end
	return any
end

-- The set's candidate times up to `t`, ascending (HNT-R20): its Hunts' tier-1 times and `retired` dates.
---@param state HuntsState
---@param setHunts HuntDef[]
---@param t integer
---@return integer[]
local function candidates(state, setHunts, t)
	local times = {}
	for _, hunt in ipairs(setHunts) do
		local tier = tierOne(state, hunt)
		if tier and tier.time <= t then
			times[#times + 1] = tier.time
		end
		if hunt.retired and hunt.retired <= t then
			times[#times + 1] = hunt.retired
		end
	end
	table.sort(times)
	return times
end

-- The tier 1 of the set's Hunts reached at `time`, or nil if none was.
---@param state HuntsState
---@param setHunts HuntDef[]
---@param time integer
---@return HuntTier?
local function tierOneAt(state, setHunts, time)
	for _, hunt in ipairs(setHunts) do
		local tier = tierOne(state, hunt)
		if tier and tier.time == time then
			return tier
		end
	end
	return nil
end

--- Checks every set whose title isn't earned yet against HNT-R20, with candidate times up to `t` (HNT-R23), and writes
--- each newly earned one to `state.sets[setID]`. A title is from a Catch when it was earned at the tier-1 time of the
--- Cast just applied (`appliedCastTime`); otherwise a retirement completed it (HNT-R23, HNT-R197). A title already in
--- `state.sets` is never checked again, so a Hunt added to its set later never takes it away (HNT-R20).
---@param state HuntsState the projection's state; only `state.sets` is written
---@param t integer the server time checked up to: the Cast's `time` in `apply`, now in `done`
---@param appliedCastTime integer? the `time` of the Cast `apply` just applied; nil from `done`
---@return string[] earned the newly earned sets' IDs, in file order
function ns.CheckTitles(state, t, appliedCastTime)
	local earned = {}
	for _, set in ipairs(ns.hunts:Sets()) do
		if not state.sets[set.id] then
			local setHunts = ns.hunts:SetHunts(set.id)
			for _, time in ipairs(candidates(state, setHunts, t)) do
				if completeAt(state, setHunts, time) then
					local tier = tierOneAt(state, setHunts, time)
					local date = tier and tier.date or civilFromDays(math.floor(time / SECONDS_PER_DAY))
					state.sets[set.id] = {
						earnedAt = time,
						date = { year = date.year, month = date.month, day = date.day },
						fromRetirement = not (tier and time == appliedCastTime),
					}
					earned[#earned + 1] = set.id
					break
				end
			end
		end
	end
	return earned
end
