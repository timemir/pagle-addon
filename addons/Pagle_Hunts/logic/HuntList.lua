if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- The Hunt list at runtime (HNT-R1–R3): pure logic, everything passed in (CORE-R7). The list itself is `ns.huntList`,
-- which the generator emits into data/HuntList.lua (DATA-R93); the adapter wraps it once, at OnInitialize, as
-- `ns.hunts`. Times are server times, as the list's `since` and `retired` are (DATA-R87).
--
-- Which lists to read:
--   - the rules (the projection, set titles, timers) read every Hunt: Hunts(), SetHunts(setID), Hunt(id), with Exists
--   - views read only Current(now) and Retired(now), so a Hunt whose `since` is still ahead is in none (HNT-R2)

---@class HuntDef                 -- one Hunt, as the list emits it (DATA-R93)
---@field id string
---@field set string              -- its set's ID
---@field kind "natural"|"imposed"
---@field since integer           -- server time it counts from (DATA-R87)
---@field retired? integer        -- server time it stops existing at
---@field species? integer        -- a Species target
---@field class? string           -- a class target, a key of the list's classes
---@field minBand? integer        -- the lowest Simulated Size band that counts (DATA-R89)
---@field window? string          -- a natural Hunt's window ID (HNT-R4)
---@field conditions? table       -- an imposed Hunt's condition spec (HNT-R5)
---@field tiers integer[]         -- ascending counts; the first is completion (DATA-R88)

---@class HuntListData            -- ns.huntList (DATA-R93)
---@field fingerprint string
---@field sets { id: string }[]
---@field hunts HuntDef[]
---@field classes table<string, table<integer, true>>

--- Whether `hunt` exists at server time `t`: from its `since` on, and before its `retired` if it has one (HNT-R2).
---@param hunt HuntDef
---@param t integer
---@return boolean
function ns.Exists(hunt, t)
	return hunt.since <= t and (hunt.retired == nil or t < hunt.retired)
end

--- Whether `hunt` is current: it exists now (HNT-R2).
---@param hunt HuntDef
---@param now integer
---@return boolean
function ns.IsCurrent(hunt, now)
	return ns.Exists(hunt, now)
end

--- Whether `hunt` is a Retired Hunt: its `retired` date has come (HNT-R3).
---@param hunt HuntDef
---@param now integer
---@return boolean
function ns.IsRetired(hunt, now)
	return hunt.retired ~= nil and hunt.retired <= now
end

---@class PagleHuntsNS
---@field huntList HuntListData? -- set by data\HuntList.lua (DATA-R93); nil until the TOC lists it

---@class HuntList
---@field data HuntListData        -- read through the methods below, never directly
---@field L table
---@field byId table<string, HuntDef>
---@field setsById table<string, { id: string }>
local HuntList = {}
HuntList.__index = HuntList

local EMPTY = { sets = {}, hunts = {}, classes = {} }

--- The Hunt list at runtime over `data` (ns.huntList; nil reads as an empty list, for an addon whose TOC doesn't list
--- data\HuntList.lua yet) and its text from `L` (Hunts' ns.L, which the generated lore fills, HNT-R130).
---@param data HuntListData?
---@param L table
---@return HuntList
function ns.NewHuntList(data, L)
	data = data or EMPTY
	local byId, setsById = {}, {}
	for _, hunt in ipairs(data.hunts) do
		byId[hunt.id] = hunt
	end
	for _, set in ipairs(data.sets) do
		setsById[set.id] = set
	end
	return setmetatable({ data = data, L = L, byId = byId, setsById = setsById }, HuntList)
end

-- The Hunts of the list, in file order, that `keep` holds for.
---@param list HuntList
---@param keep fun(hunt: HuntDef): boolean
---@return HuntDef[]
local function huntsWhere(list, keep)
	local out = {}
	for _, hunt in ipairs(list.data.hunts) do
		if keep(hunt) then
			out[#out + 1] = hunt
		end
	end
	return out
end

--- Every Hunt in file order, Retired Hunts and Hunts not yet out included: for the rules, not for views (HNT-R1).
---@return HuntDef[]
function HuntList:Hunts()
	return huntsWhere(self, function()
		return true
	end)
end

--- The Hunt with this ID, or nil.
---@param id string
---@return HuntDef?
function HuntList:Hunt(id)
	return self.byId[id]
end

--- Every set in file order, as `{ id }` (HNT-R1).
---@return { id: string }[]
function HuntList:Sets()
	return { unpack(self.data.sets) }
end

--- The set with this ID, or nil.
---@param id string
---@return { id: string }?
function HuntList:Set(id)
	return self.setsById[id]
end

--- Every Hunt of a set in file order, Retired Hunts and Hunts not yet out included: for the rules (HNT-R1).
---@param setID string
---@return HuntDef[]
function HuntList:SetHunts(setID)
	return huntsWhere(self, function(hunt)
		return hunt.set == setID
	end)
end

--- The current Hunts in file order (HNT-R2): what the board's groups and the tracker start from.
---@param now integer
---@return HuntDef[]
function HuntList:Current(now)
	return huntsWhere(self, function(hunt)
		return ns.IsCurrent(hunt, now)
	end)
end

--- The Retired Hunts in file order (HNT-R3): what a set's page lists under "Retired" when done.
---@param now integer
---@return HuntDef[]
function HuntList:Retired(now)
	return huntsWhere(self, function(hunt)
		return ns.IsRetired(hunt, now)
	end)
end

--- A class's members, `{ [itemID] = true }`, or nil for an unknown class (HNT-R12: membership comes only from here).
---@param classID string
---@return table<integer, true>?
function HuntList:Class(classID)
	return self.data.classes[classID]
end

--- The list's own fingerprint (DATA-R72), or nil with no list loaded.
---@return string?
function HuntList:Fingerprint()
	return self.data.fingerprint
end

-- A lore key's text, or nil while it has none (HNT-R130). rawget, so a missing key is never an error.
---@param list HuntList
---@param key string
---@return string?
local function lore(list, key)
	return rawget(list.L, key)
end

--- A Hunt's name, or its ID while the lore has none (HNT-R1).
---@param id string
---@return string
function HuntList:HuntName(id)
	return lore(self, "hunt." .. id .. ".name") or id
end

--- A Hunt's note, or nil while the lore has none (HNT-R1).
---@param id string
---@return string?
function HuntList:HuntNote(id)
	return lore(self, "hunt." .. id .. ".note")
end

--- A set's name, or its ID while the lore has none (HNT-R1).
---@param id string
---@return string
function HuntList:SetName(id)
	return lore(self, "set." .. id .. ".name") or id
end

--- A set's title (HNT-R20), or its ID while the lore has none (HNT-R1).
---@param id string
---@return string
function HuntList:SetTitle(id)
	return lore(self, "set." .. id .. ".title") or id
end

--- A set's note, or nil while the lore has none (HNT-R1).
---@param id string
---@return string?
function HuntList:SetNote(id)
	return lore(self, "set." .. id .. ".note")
end
