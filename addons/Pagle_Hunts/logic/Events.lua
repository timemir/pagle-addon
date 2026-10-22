if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunt Events at runtime (HNT-R1, HNT-R140, HNT-R141, HNT-R156): pure logic, everything passed in (CORE-R7). The pool
-- is `ns.eventList`, which the generator emits into data/EventList.lua (DATA-R98); the adapter wraps it once, at
-- OnInitialize, as `ns.events`. Pushed definitions become the same HuntEvent through ns.NewHuntEvent when the
-- projection reads them from its `def` records (logic/Runs.lua). An event has no dates: when it counts is its runs'.

---@class HuntEventData           -- one event as the list emits it (DATA-R98), or a pushed huntEvent item's fields
---@field id string
---@field zones integer[]         -- 1–2 zone areaIDs
---@field tags string[]
---@field skill integer[]         -- { low, high }
---@field band? "low"|"mid"|"high" -- the pool's; a pushed event's follows from its skill (HNT-R156)
---@field rotation? boolean
---@field retired? integer        -- a server time (DATA-R98)
---@field name? string            -- a pushed event's lore; the pool's is in ns.L
---@field note? string
---@field hunts table[]           -- { id, species? or class?, minBand?, conditions?, tiers, name? }

---@class EventListData           -- ns.eventList (DATA-R98)
---@field fingerprint string
---@field events HuntEventData[]

--- One event Hunt at runtime (HNT-R141): always imposed, with no set, `since` or `retired`; its condition spec is its
--- own conditions with the event's zones as `areas`. Target, `minBand` and `tiers` as a Standing Hunt's.
---@class HuntEventHunt
---@field id string
---@field event string            -- its event's ID
---@field kind "imposed"
---@field species? integer
---@field class? string
---@field minBand? integer
---@field conditions table        -- its condition spec, `areas` = the event's zones
---@field tiers integer[]
---@field name? string            -- a pushed definition's name

--- One Hunt Event at runtime (HNT-R140).
---@class HuntEvent
---@field id string
---@field zones integer[]
---@field tags string[]
---@field skill integer[]
---@field band "low"|"mid"|"high"
---@field rotation boolean        -- false for a pushed event: it never enters the fallback rotation (HNT-R140)
---@field retired? integer
---@field pushed boolean
---@field name? string
---@field note? string
---@field hunts HuntEventHunt[]   -- in file order
---@field where table<string, HuntWhere>   -- by Hunt ID, worked out with the event (HNT-R30)

--- Tunables (hunts.md): the skill bands' upper ends, `low` up to 150 and `mid` up to 275 (HNT-R156, DATA-R97).
ns.BAND_LOW_MAX, ns.BAND_MID_MAX = 150, 275

--- An event's skill band from its skill range's lower end (HNT-R156).
---@param low integer
---@return "low"|"mid"|"high"
function ns.SkillBand(low)
	if low <= ns.BAND_LOW_MAX then
		return "low"
	elseif low <= ns.BAND_MID_MAX then
		return "mid"
	end
	return "high"
end

-- A deep copy of plain data.
---@param value any
---@return any
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, v in pairs(value) do
		out[key] = copy(v)
	end
	return out
end

--- One event Hunt from its event's data (HNT-R141): imposed, its conditions its own plus `areas` = the event's zones.
---@param hunt table one of the event's `hunts`
---@param event HuntEventData
---@return HuntEventHunt
function ns.NewEventHunt(hunt, event)
	local conditions = copy(hunt.conditions) or {}
	conditions.areas = copy(event.zones)
	return {
		id = hunt.id,
		event = event.id,
		kind = "imposed",
		species = hunt.species,
		class = hunt.class,
		minBand = hunt.minBand,
		conditions = conditions,
		tiers = copy(hunt.tiers),
		name = hunt.name,
	}
end

--- A Hunt Event at runtime from its data (HNT-R140): the pool's (DATA-R98) or a pushed definition already checked
--- (logic/Content.lua's ns.HuntEventProblem), with where each of its Hunts bites, worked out here once (HNT-R30).
---@param data HuntEventData
---@param pushed boolean
---@param lookups HuntsWaterLookups
---@return HuntEvent
function ns.NewHuntEvent(data, pushed, lookups)
	local hunts, where = {}, {}
	for i, hunt in ipairs(data.hunts) do
		hunts[i] = ns.NewEventHunt(hunt, data)
		where[hunt.id] = ns.EventHuntWhere(hunts[i], lookups)
	end
	return {
		id = data.id,
		zones = copy(data.zones),
		tags = copy(data.tags or {}),
		skill = copy(data.skill),
		band = data.band or ns.SkillBand(data.skill[1]),
		rotation = not pushed and data.rotation ~= false,
		retired = data.retired,
		pushed = pushed,
		name = pushed and data.name or nil,
		note = pushed and data.note or nil,
		hunts = hunts,
		where = where,
	}
end

---@class PagleHuntsNS
---@field eventList EventListData? -- set by the generated data\EventList.lua (DATA-R98), listed after HuntList.lua

---@class HuntEventList
---@field data EventListData
---@field L table
---@field list HuntEvent[]
---@field byId table<string, HuntEvent>
local EventList = {}
EventList.__index = EventList

local EMPTY = { events = {} }

--- The event pool at runtime over `data` (ns.eventList; nil reads as an empty pool), its text from `L` (Hunts' ns.L)
--- and where each event Hunt bites from `lookups` (HNT-R30), worked out here once per load.
---@param data EventListData?
---@param L table
---@param lookups HuntsWaterLookups
---@return HuntEventList
function ns.NewEventList(data, L, lookups)
	data = data or EMPTY
	local list, byId = {}, {}
	for i, event in ipairs(data.events) do
		list[i] = ns.NewHuntEvent(event, false, lookups)
		byId[event.id] = list[i]
	end
	return setmetatable({ data = data, L = L, list = list, byId = byId }, EventList)
end

--- Every event of the pool, in event-ID order (DATA-R98), retired ones included: for the rules.
---@return HuntEvent[]
function EventList:Events()
	return { unpack(self.list) }
end

--- The pool's event with this ID, or nil.
---@param id string
---@return HuntEvent?
function EventList:Event(id)
	return self.byId[id]
end

--- The pool's fingerprint (DATA-R98), or nil with no pool loaded.
---@return string?
function EventList:Fingerprint()
	return self.data.fingerprint
end

--- An event's name: a pushed definition's own, or the pool's lore (`event.<id>.name`), else its ID (HNT-R140).
---@param event HuntEvent
---@return string
function EventList:EventName(event)
	return event.name or (not event.pushed and ns.Lore(self.L, "event." .. event.id .. ".name")) or event.id
end

--- An event's note: a pushed definition's own, or the pool's lore (`event.<id>.note`), else nil (HNT-R140).
---@param event HuntEvent
---@return string?
function EventList:EventNote(event)
	if event.pushed then
		return event.note
	end
	return ns.Lore(self.L, "event." .. event.id .. ".note")
end

--- An event Hunt's name: the `name` its pushed definition carries, or `hunt.<id>.name` from the lore, else its ID
--- (HNT-R140, HNT-R141).
---@param hunt HuntEventHunt
---@return string
function EventList:HuntName(hunt)
	return hunt.name or ns.Lore(self.L, "hunt." .. hunt.id .. ".name") or hunt.id
end

---@class HuntPoolEvent           -- one event of ns.EventPool
---@field id string
---@field tags string[]
---@field skill integer[]         -- { low, high }
---@field band "low"|"mid"|"high"
---@field rotation boolean
---@field retired? integer

--- The release's event pool for Pagle's backend (#223, LOG-R79): ns.events:Events() as plain copies of each event's
--- id, tags, skill, band, rotation and retired, in event-ID order, retired ones included. The driver calls it after
--- ns.BindProjections, which makes ns.events.
---@return HuntPoolEvent[]
function ns.EventPool()
	local pool = {}
	for i, event in ipairs(ns.events:Events()) do
		pool[i] = {
			id = event.id,
			tags = copy(event.tags),
			skill = copy(event.skill),
			band = event.band,
			rotation = event.rotation,
			retired = event.retired,
		}
	end
	return pool
end
