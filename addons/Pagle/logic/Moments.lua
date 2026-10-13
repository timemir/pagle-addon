---@class PagleNS
local ns = select(2, ...)

-- Moments, the rung ladder and one Announcement per Cast (announcements.md › Moments and the ladder, › One
-- Announcement per Cast; ADR 0007): pure logic, fed moments, the projection machinery's seams and a frame
-- scheduler (CORE-R7). adapter/Moments.lua puts M:RaiseMoment on the Module handle over it.

--- What a Module passes to `M:RaiseMoment` (announcements.md › Contracts).
---@class PagleMoment
---@field rung PagleRung
---@field kind string            -- the Module's own name for it, e.g. "newSpecies"
---@field order? integer         -- tie-break on the same rung, lower first (default 100)
---@field title string           -- headline text ("New Species")
---@field text? string           -- second line ("Nightfin Snapper")
---@field icon? integer|string   -- itemID, fileID or texture path
---@field stamp? string          -- text when riding as a stamp ("New!"); defaults to title
---@field cast? string           -- the Cast's entry ID (ANN-R10)
---@field coins? integer         -- ANN-R23
---@field ruler? { old: number, new: number, unit: string, label: string }   -- ANN-R22; unit "length" = millimetres
---@field sound? boolean         -- default true
---@field expiresAt? integer     -- server time (ANN-R45)
---@field pastText? string       -- shown in the summary if it expired
---@field summaryOnly? boolean   -- ANN-R63

---@alias PagleRung "nod"|"toast.low"|"toast"|"toast.high"|"banner"|"splash"

--- Core's copy of a raised moment: the Module's fields, copied when raised so a later change to the Module's table
--- changes nothing (ANN-R3), plus who raised it (announcements.md › Data) and when.
---@class PagleRaisedMoment: PagleMoment
---@field module string          -- the raising Module's def.name
---@field moduleTitle string     -- its def.title
---@field moduleOrder integer    -- its def.order
---@field raised integer         -- 1 for the first moment Core accepted this login, and so on (ANN-R2's last tie-break)

--- One Announcement (ANN-R11): what the display shows for one Cast's moments, or for one moment without a Cast.
---@class PagleAnnouncement
---@field headline PagleRaisedMoment  -- the top-ranked moment
---@field rung PagleRung              -- its weight: the headline's rung
---@field cast string?                -- the Cast's entry ID, nil for a moment of its own (ANN-R12)
---@field stamps string[]             -- at most MOMENT_STAMPS texts, highest ranked first, identical ones merged
---@field more integer                -- distinct stamp texts beyond those, shown as "+N"; 0 for none
---@field coins integer               -- the sum of every moment's coins, kept apart from the stamps (ANN-R23)
---@field moments PagleRaisedMoment[] -- every moment in it, ranked (ANN-R2), the headline first
---@field fighting? PagleRaisedMoment[] -- the "While you were fighting" toast's held headlines, in order (ANN-R36)

--- The ladder (ANN-R1), lowest to highest.
ns.MOMENT_RUNGS = { "nod", "toast.low", "toast", "toast.high", "banner", "splash" }
--- Stamps an Announcement shows at most (ANN-R11; Tunables).
ns.MOMENT_STAMPS = 4
--- A moment's `order` when it gives none (ANN-R2).
ns.MOMENT_ORDER = 100

local RUNG_HEIGHT = {}
for height, rung in ipairs(ns.MOMENT_RUNGS) do
	RUNG_HEIGHT[rung] = height
end

--- Why a Module's moment can't be raised, or nil if it can (ANN-R1, announcements.md › Contracts).
---@param moment any
---@return string?
function ns.MomentProblem(moment)
	if type(moment) ~= "table" then
		return "RaiseMoment takes a moment table, got " .. type(moment)
	end
	if not RUNG_HEIGHT[moment.rung] then
		return ("RaiseMoment: %s is not a rung; the ladder is %s"):format(
			tostring(moment.rung),
			table.concat(ns.MOMENT_RUNGS, ", ")
		)
	end
	if type(moment.kind) ~= "string" or moment.kind == "" then
		return "RaiseMoment: a moment needs a kind"
	end
	if type(moment.title) ~= "string" or moment.title == "" then
		return "RaiseMoment: a moment needs a title"
	end
	return nil
end

--- Whether moment `a` ranks above moment `b` (ANN-R2): the higher rung; on one rung the lower `order` (default
--- 100); then the raising Module's lower def.order; then the one raised first. Nothing else counts: what the
--- moment is about, such as an unconfirmed catalogue fact, is the Module's to weigh when it picks the rung (ANN-R96).
---@param a PagleRaisedMoment
---@param b PagleRaisedMoment
---@return boolean
function ns.RanksAbove(a, b)
	if a.rung ~= b.rung then
		return RUNG_HEIGHT[a.rung] > RUNG_HEIGHT[b.rung]
	end
	local orderA, orderB = a.order or ns.MOMENT_ORDER, b.order or ns.MOMENT_ORDER
	if orderA ~= orderB then
		return orderA < orderB
	end
	if a.moduleOrder ~= b.moduleOrder then
		return a.moduleOrder < b.moduleOrder
	end
	return a.raised < b.raised
end

--- The Announcement a set of moments makes (ANN-R11): the top-ranked one is the headline, the others ride as
--- stamps, and their coins are summed apart. Nil for no moments. Ticket #88's expiry calls it again on what is left.
---@param moments PagleRaisedMoment[]
---@return PagleAnnouncement?
function ns.MakeAnnouncement(moments)
	if #moments == 0 then
		return nil
	end
	local ranked = {}
	for i, moment in ipairs(moments) do
		ranked[i] = moment
	end
	table.sort(ranked, ns.RanksAbove)
	local headline = ranked[1]
	local announcement = {
		headline = headline,
		rung = headline.rung,
		cast = headline.cast,
		stamps = {},
		more = 0,
		coins = 0,
		moments = ranked,
	}
	local seen = {}
	for i, moment in ipairs(ranked) do
		announcement.coins = announcement.coins + (moment.coins or 0)
		local text = moment.stamp or moment.title
		if i > 1 and not seen[text] then
			seen[text] = true
			if #announcement.stamps < ns.MOMENT_STAMPS then
				announcement.stamps[#announcement.stamps + 1] = text
			else
				announcement.more = announcement.more + 1
			end
		end
	end
	return announcement
end

--- What the collector is fed. Every function is called when needed, never stored.
---@class PagleMomentsOptions
---@field mode fun(): PagleApplyMode|"done"|nil  -- the projection apply in progress (ns.projections:Mode())
---@field isUpdating fun(): boolean             -- any projection updating (ns.projections:IsUpdating())
---@field whenIdle fun(fn: fun())               -- runs fn once none is (ns.projections:WhenIdle)
---@field nextFrame fun(step: fun())            -- runs step on the next frame
---@field report fun(message: string)           -- reports an error and carries on (geterrorhandler())
---@field show fun(announcement: PagleAnnouncement) -- hands an Announcement to the display (ANN-R20)
---@field summarize fun(moment: PagleRaisedMoment) -- hands a moment to the Session summary (ANN-R25)

--- The collector: the moments raised and not yet flushed.
---@class PagleMoments
---@field package options PagleMomentsOptions
---@field package raised integer                 -- moments accepted so far
---@field package pending PagleRaisedMoment[]    -- waiting for the next frame, in the order raised
---@field package held PagleRaisedMoment[]       -- Cast moments held while a projection updates (ANN-R10)
---@field package stepping boolean               -- a frame step is scheduled
---@field package waiting boolean                -- Cast moments wait for the frame after the projections are idle
---@field package drops PagleReportOnce          -- Modules whose dropped moment was reported this login (ANN-R4)
local Moments = {}
Moments.__index = Moments

---@param options PagleMomentsOptions
---@return PagleMoments
function ns.NewMoments(options)
	return setmetatable({
		options = options,
		raised = 0,
		pending = {},
		held = {},
		stepping = false,
		waiting = false,
		drops = ns.NewReportOnce(),
	}, Moments)
end

-- Core's copy of a moment, with who raised it (PagleRaisedMoment).
---@param module PagleModule
---@param moment PagleMoment
---@param raised integer
---@return PagleRaisedMoment
local function copyOf(module, moment, raised)
	local copy = {}
	for key, value in pairs(moment) do
		copy[key] = value
	end
	if type(moment.ruler) == "table" then
		copy.ruler = {}
		for key, value in pairs(moment.ruler) do
			copy.ruler[key] = value
		end
	end
	copy.module, copy.moduleTitle, copy.moduleOrder = module.def.name, module.def.title, module.def.order
	copy.raised = raised
	return copy
end

--- Takes a moment a Module raised (ANN-R1, ANN-R4): dropped, and reported once per Module per login, when raised
--- during a "replay" or "rebuild" apply, or from a done unless it is summaryOnly. Otherwise every moment goes to the
--- Session summary now (ANN-R25), and one not summaryOnly waits for the next frame's flush (ANN-R10, ANN-R12). The
--- caller has checked it with ns.MomentProblem.
---@param module PagleModule the raising Module
---@param moment PagleMoment
function Moments:Raise(module, moment)
	local mode = self.options.mode()
	if mode == "replay" or mode == "rebuild" or (mode == "done" and not moment.summaryOnly) then
		if self.drops:First(module.def.name, "moment") then
			self.options.report(
				("Pagle: %s raised a moment during a projection's %s; it was dropped (ANN-R4)"):format(
					module.def.name,
					mode == "done" and "done (only summaryOnly moments are allowed there)" or (mode .. " apply")
				)
			)
		end
		return
	end
	self.raised = self.raised + 1
	local copy = copyOf(module, moment, self.raised)
	self.options.summarize(copy)
	if copy.summaryOnly then
		return
	end
	self.pending[#self.pending + 1] = copy
	if copy.cast ~= nil and self.options.isUpdating() then
		self:hold()
	end
	self:schedule()
end

-- Holds every Cast's moments until the frame after no projection is updating (ANN-R10). Noted when a Cast's moment
-- is raised during an update, so a flush that runs later in the frame the last projection finished in still holds.
---@package
function Moments:hold()
	if self.waiting then
		return
	end
	self.waiting = true
	self.options.whenIdle(function()
		self.options.nextFrame(function()
			self.waiting = false
			self:flush()
		end)
	end)
end

-- Schedules the next frame's flush, once.
---@package
function Moments:schedule()
	if not self.stepping then
		self.stepping = true
		self.options.nextFrame(function()
			self.stepping = false
			self:flush()
		end)
	end
end

-- The order of two Casts' entry IDs (<guid>-<time>-<tie>, LOG-R13): by time, then tie.
---@param id string
---@return number time
---@return number tie
local function castOrder(id)
	local time, tie = id:match("%-(%d+)%-(%d+)$")
	return tonumber(time) or math.huge, tonumber(tie) or math.huge
end

-- Each Cast's moments, in Cast order (ANN-R10).
---@param moments PagleRaisedMoment[]
---@return PagleRaisedMoment[][]
local function byCast(moments)
	local groups, index = {}, {}
	for _, moment in ipairs(moments) do
		local group = index[moment.cast]
		if not group then
			group = {}
			index[moment.cast] = group
			groups[#groups + 1] = group
		end
		group[#group + 1] = moment
	end
	table.sort(groups, function(a, b)
		local timeA, tieA = castOrder(a[1].cast)
		local timeB, tieB = castOrder(b[1].cast)
		if timeA ~= timeB then
			return timeA < timeB
		elseif tieA ~= tieB then
			return tieA < tieB
		end
		return a[1].raised < b[1].raised
	end)
	return groups
end

-- One frame's flush (ANN-R10, ANN-R12): each moment without a Cast is its own Announcement; each Cast's moments make
-- one, in Cast order, unless a projection is updating, when they are held for the frame after the last one finishes.
---@package
function Moments:flush()
	local pending = self.pending
	self.pending = {}
	for _, moment in ipairs(pending) do
		if moment.cast == nil then
			self.options.show(ns.MakeAnnouncement({ moment }) --[[@as PagleAnnouncement]])
		else
			self.held[#self.held + 1] = moment
		end
	end
	if #self.held == 0 then
		return
	end
	if self.options.isUpdating() then
		self:hold()
	end
	if self.waiting then
		return
	end
	local held = self.held
	self.held = {}
	for _, group in ipairs(byCast(held)) do
		self.options.show(ns.MakeAnnouncement(group) --[[@as PagleAnnouncement]])
	end
end

--- `M:RaiseMoment(moment)` over `moments` (ANN-R1), so Core's adapter and FakePagle publish one method: an error at
--- the Module's call, raising nothing, for a moment the contract refuses.
---@param registry PagleModuleRegistry
---@param moments PagleMoments
---@return fun(self: PagleModuleHandle, moment: PagleMoment)
function ns.RaiseMomentMethod(registry, moments)
	return function(self, moment)
		local module = registry:ModuleOf(self)
		if not module then
			error("RaiseMoment is a Module handle method: call M:RaiseMoment(moment)", 2)
		end
		local problem = ns.MomentProblem(moment)
		if problem then
			error(problem, 2)
		end
		moments:Raise(module, moment)
	end
end
