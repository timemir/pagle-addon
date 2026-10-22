---@class PagleNS
local ns = select(2, ...)

-- Moments, the rung ladder and a Cast's Announcements (announcements.md › Moments and the ladder, › A Cast's
-- Announcements; ADR 0007): pure logic, fed moments, the projection machinery's seams and a frame
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
---@field firstNote? string      -- the Margin note shown the first time a moment of this Module and kind shows (ONB-R53)
---@field seal? integer|"waves"|"book"|"quill"|"crest" -- a banner's wax seal: a number, a mark or the Prestige crest
---@field crest? integer|string  -- with seal "crest": a crest good's icon shown in the Prestige crest's place (VAR-R25)
---@field art? PagleMomentArt    -- a texture rectangle drawn instead of `icon` where the headline shows (VAR-R25)
---@field variety? PagleNodVariety -- Core's catch Nod only: the variety its line names (VAR-R26)
---@field onClick? fun()         -- what clicking its toast or Nod does as it sends it away (ANN-R20); never stored

--- A moment's art (announcements.md › Contracts): a texture and its texel rectangle as texture coordinates, a
--- variety's art (VAR-R11). A toast's or Nod's medallion shows it cropped to the fish's head (ns.HeadCrop), a banner on
--- its seal's ribbon. Never stored: the Session summary shows `icon`.
---@class PagleMomentArt
---@field texture integer|string
---@field left number
---@field right number
---@field top number
---@field bottom number

--- The variety a catch Nod's line names (VAR-R26): its name and rarity, and the line cut either side of the name, so
--- the display draws the name as a segment of its own, in the rarity's ink after a gem in its colour. `title` keeps
--- the whole line as plain text.
---@class PagleNodVariety
---@field name string
---@field rarity "common"|"uncommon"|"rare"|"epic"
---@field before string          -- the line up to the name, trimmed ("Firefin Snapper ·")
---@field after string           -- the line after it, trimmed ("· Decent · 34.2 cm")

---@alias PagleRung "nod"|"toast.low"|"toast"|"toast.high"|"banner"|"splash"

--- Core's copy of a raised moment: the Module's fields, copied when raised so a later change to the Module's table
--- changes nothing (ANN-R3), plus who raised it (announcements.md › Data) and when.
---@class PagleRaisedMoment: PagleMoment
---@field module string          -- the raising Module's def.name
---@field moduleTitle string     -- its def.title
---@field moduleOrder integer    -- its def.order
---@field raised integer         -- 1 for the first moment Core accepted this login, and so on (ANN-R2's last tie-break)
---@field catchNod? true         -- Core's own catch Nod (ANN-R13), never a Module's

--- One Announcement (ANN-R11): what the display shows for one side of a Cast's moments (its banners and splash, or
--- its toasts and Nods), or for one moment without a Cast.
---@class PagleAnnouncement
---@field headline PagleRaisedMoment  -- the top-ranked moment
---@field rung PagleRung              -- its weight: the headline's rung
---@field cast string?                -- the Cast's entry ID, nil for a moment of its own (ANN-R12)
---@field stamps string[]             -- at most MOMENT_STAMPS texts, highest ranked first, identical ones merged
---@field more integer                -- distinct stamp texts beyond those, shown as "+N"; 0 for none
---@field coins integer               -- the sum of its moments' coins, kept apart from the stamps (ANN-R23)
---@field moments PagleRaisedMoment[] -- every moment in it, ranked (ANN-R2), the headline first
---@field fighting? PagleRaisedMoment[] -- the "While you were fighting" toast's held headlines, in order (ANN-R36)
---@field style? string                -- a sample's toast style, drawn in that, not the equipped one (ANN-R80)

--- The ladder (ANN-R1), lowest to highest.
ns.MOMENT_RUNGS = { "nod", "toast.low", "toast", "toast.high", "banner", "splash" }
--- Stamps an Announcement shows at most (ANN-R11; Tunables).
ns.MOMENT_STAMPS = 4
--- A moment's `order` when it gives none (ANN-R2).
ns.MOMENT_ORDER = 100
--- Trade_Fishing, the icon of a moment that gives none.
ns.DEFAULT_ICON = 136245

--- Each rung's height on the ladder (ANN-R1): 1 for a Nod up to 6 for a splash.
---@type table<PagleRung, integer>
ns.RUNG_HEIGHT = {}
for height, rung in ipairs(ns.MOMENT_RUNGS) do
	ns.RUNG_HEIGHT[rung] = height
end
local RUNG_HEIGHT = ns.RUNG_HEIGHT

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
	if moment.firstNote ~= nil and (type(moment.firstNote) ~= "string" or moment.firstNote == "") then
		return "RaiseMoment: a moment's firstNote is a text (ONB-R93)"
	end
	local art = moment.art
	if art ~= nil then
		local rectangle = type(art) == "table"
			and (type(art.texture) == "string" or type(art.texture) == "number")
			and type(art.left) == "number"
			and type(art.right) == "number"
			and type(art.top) == "number"
			and type(art.bottom) == "number"
		if not rectangle then
			return "RaiseMoment: a moment's art is { texture, left, right, top, bottom }"
		end
	end
	if moment.onClick ~= nil and type(moment.onClick) ~= "function" then
		return "RaiseMoment: a moment's onClick is a function (ANN-R20)"
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

-- The big side of a Cast's moments (ANN-R11): the rungs the centre shows (ANN-R20).
local BIG = { banner = true, splash = true }

--- The Announcements a Cast's moments make (ANN-R11): a big one of its banner and splash moments, then a catch one of
--- its toast and Nod moments, each made by ns.MakeAnnouncement; one when every moment is on one side. Core's catch Nod
--- is dropped when a Module raised any moment for the Cast, so it never headlines or rides as a stamp then (ANN-R13).
---@param moments PagleRaisedMoment[]
---@return PagleAnnouncement[]
function ns.MakeCastAnnouncements(moments)
	local bigger = false
	for _, moment in ipairs(moments) do
		bigger = bigger or not moment.catchNod
	end
	local big, catch = {}, {}
	for _, moment in ipairs(moments) do
		if not (bigger and moment.catchNod) then
			local side = BIG[moment.rung] and big or catch
			side[#side + 1] = moment
		end
	end
	local announcements = {}
	for _, side in ipairs({ big, catch }) do
		announcements[#announcements + 1] = ns.MakeAnnouncement(side)
	end
	return announcements
end

-- The variety a Catch's `variety` names (VAR-R4, VAR-R11), as `varieties` (Pagle.GetVarieties) lists it, or nil
-- when Core can't name it: no list for its Species, no entry at its position, or no name in lore.
---@param variety PagleVariety
---@param varieties fun(speciesID: integer): PagleVarietyEntry[]?
---@return PagleVarietyEntry?
local function lookOf(variety, varieties)
	local speciesID = tonumber(variety.id:match("^(%d+)%."))
	local list = speciesID and varieties(speciesID)
	local entry = list and list[variety.index]
	if entry and entry.id == variety.id and entry.name then
		return entry
	end
	return nil
end

--- The catch Nod of a Cast (ANN-R13), or nil for a got-away Cast or one whose every item is item 0: a silent `nod` of
--- the Cast naming its first Catch with a Simulated Size, else its first that isn't item 0, as "{item name} · {band} ·
--- {length}" in `lengthUnit`, or by name alone for an item with no size. `itemName` is the client's name, nil until it
--- has cached it ("Item {itemID}" then). `cast` may be a read-only proxy, so its items are read by index.
--- A Catch with a variety that `varieties` (Pagle.GetVarieties) names reads "{item name} · {variety name} · {band} ·
--- {length}" (VAR-R26): the moment's `variety` cuts the line about the name, and its `art` is a copy of the variety's,
--- for the medallion. Only a Catch with a size has a variety (VAR-R1). With `caughtBefore`, it names only a variety
--- caught before this Cast (VAR-R27): a first one reads as a Catch without a variety, its moment the Ledger's.
---@param cast PagleCast
---@param itemName fun(itemID: integer): string?
---@param lengthUnit PagleLengthUnit
---@param varieties (fun(speciesID: integer): PagleVarietyEntry[]?)?
---@param caughtBefore (fun(variety: PagleVariety, castId: string): boolean)?
---@return PagleMoment?
function ns.CatchNodMoment(cast, itemName, lengthUnit, varieties, caughtBefore)
	if cast.outcome ~= "caught" then
		return nil
	end
	local items, named = cast.items, nil
	local n = 1
	while items[n] do
		local item = items[n]
		if item.size then
			named = item
			break
		end
		if not named and item.itemID ~= 0 then
			named = item
		end
		n = n + 1
	end
	if not named then
		return nil
	end
	local L = ns.L
	local itemID, size = named.itemID, named.size
	local name = itemName(itemID) or L.CATCH_NOD_ITEM:format(itemID)
	local moment = { rung = "nod", kind = "catch", title = name, icon = itemID, cast = cast.id, sound = false }
	if not size then
		return moment
	end
	local band, length = ns.SIZE_BANDS[size.band].name, ns.FormatLength(size.length, lengthUnit)
	local variety = named.variety
	local look = variety
		and varieties
		and (not caughtBefore or caughtBefore(variety, cast.id))
		and lookOf(variety, varieties)
	if not look then
		moment.title = L.CATCH_NOD:format(name, band, length)
		return moment
	end
	-- A look is found only for a variety.
	---@cast variety PagleVariety
	moment.title = L.CATCH_NOD_VARIETY:format(name, look.name, band, length)
	-- The line with a mark in the name's place, cut there: "\001" is in no name.
	local before, after = L.CATCH_NOD_VARIETY:format(name, "\001", band, length):match("^(.-)%s*\001%s*(.*)$")
	moment.variety = { name = look.name, rarity = variety.rarity, before = before, after = after }
	local art = look.art
	if art then
		moment.art = { texture = art.texture, left = art.left, right = art.right, top = art.top, bottom = art.bottom }
	end
	return moment
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

-- Core's copy of a moment, with who raised it (PagleRaisedMoment): the raiser's def, a Module's or Core's own.
---@param def PagleModuleDef
---@param moment PagleMoment
---@param raised integer
---@return PagleRaisedMoment
local function copyOf(def, moment, raised)
	local copy = {}
	for key, value in pairs(moment) do
		copy[key] = value
	end
	for _, key in ipairs({ "ruler", "art" }) do
		if type(moment[key]) == "table" then
			copy[key] = {}
			for field, value in pairs(moment[key]) do
				copy[key][field] = value
			end
		end
	end
	copy.module, copy.moduleTitle, copy.moduleOrder = def.name, def.title, def.order
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
	local copy = copyOf(module.def, moment, self.raised)
	self.options.summarize(copy)
	if copy.summaryOnly then
		return
	end
	self:queue(copy)
end

-- Core itself, as the raiser of its catch Nod (ANN-R13): ahead of every Module, like "While you were fighting".
---@type PagleModuleDef
local CORE = { name = "Pagle", title = "Pagle", order = 0 }

--- Takes Core's catch Nod for a live caught Cast (ANN-R13), made by ns.CatchNodMoment: it waits for the next frame's
--- flush with the Cast's other moments, as theirs do (ANN-R10), never reaches the Session summary (ANN-R25), and is
--- dropped there if a Module raised any moment for the Cast (ns.MakeCastAnnouncements).
---@param moment PagleMoment
function Moments:RaiseCatchNod(moment)
	self.raised = self.raised + 1
	local copy = copyOf(CORE, moment, self.raised)
	copy.catchNod = true
	self:queue(copy)
end

-- Queues a moment for the next frame's flush, held with every Cast's while a projection updates (ANN-R10).
---@package
---@param copy PagleRaisedMoment
function Moments:queue(copy)
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

-- One frame's flush (ANN-R10–R12): each moment without a Cast is its own Announcement; each Cast's moments make its
-- big and catch ones, in Cast order, unless a projection is updating, when they are held for the frame after the last
-- one finishes.
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
		for _, announcement in ipairs(ns.MakeCastAnnouncements(group)) do
			self.options.show(announcement)
		end
	end
end

--- `M:RaiseMoment(moment)` over `moments` (ANN-R1), so Core's adapter and FakePagle publish one method: an error at
--- the Module's call, raising nothing, for a moment the contract refuses.
---@param registry PagleModuleRegistry
---@param moments PagleMoments
---@return fun(self: PagleModuleHandle, moment: PagleMoment)
function ns.RaiseMomentMethod(registry, moments)
	return function(self, moment)
		local module = registry:ModuleCalling(self, "RaiseMoment", "moment")
		local problem = ns.MomentProblem(moment)
		if problem then
			error(problem, 2)
		end
		moments:Raise(module, moment)
	end
end
