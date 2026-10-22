---@class PagleNS
local ns = select(2, ...)

-- The Field guide's steps and its moving between them (core/onboarding.md › The Field guide): the step registry Core's
-- own four steps and the Modules' fill with `M:RegisterGuideStep` (ONB-R21, ONB-R90, Contracts), the order they show
-- in and "{n} of {m}" (ONB-R20), where the guide opens (ONB-R22), Next, back, the skip links and the ribbons (ONB-R23,
-- ONB-R24), Off to the water and the Welcome step's skip (ONB-R26), the restriction's close and reopen (ONB-R25), the
-- Announcement hold while it is open (ONB-R70) and the tour stops' quiet showing (ONB-R84). Pure logic over what it's
-- handed (CORE-R7): the book's frames are adapter/GuideBook.lua's and adapter/Guide.lua's, and logic/Wiring.lua's
-- ns.WireGuide builds it over Core's host, so Core's adapter and FakePagle run the same guide.

--- One step of the guide, as a Module registers it (core/onboarding.md › Contracts). The fields after `onShow` are
--- Core's alone, for its own Welcome and Off you go steps (ONB-R26, ONB-R30, ONB-R38); a Module's step with one is
--- refused.
---@class PagleGuideStep
---@field id string             -- unique in the guide, [%w_]+; Core's: welcome, box, moments, off
---@field order integer         -- where it sits (ONB-R21): Core 10, 20, 50, 90; QoL 30, 40; Ledger 60; Tackle Board 70
---@field ribbon string         -- the ribbon's label (ONB-R24)
---@field skipLabel? string     -- the foot's skip link; default "Skip the rest" (ONB-R23)
---@field skipTo? "next"|"last"|"close" -- where the skip link goes: default "last"; "close" (Core's alone) closes the
--- guide and sets `skipped` (ONB-R26)
---@field build fun(left: Frame, right: Frame, nav: PagleGuideNav) -- draws the two pages once, at the step's first
--- showing (UI units from each page's top left)
---@field onShow? fun()         -- each time the step shows: re-read live state (bindings, sets, board)
---@field nextLabel? string     -- Core's alone: Next's words on this step ("Show me around »", ONB-R30)
---@field ownFoot? boolean      -- Core's alone: Core draws no foot on the right page; the step draws its own controls

--- A step as the registry keeps it: a copy of what was registered, and who registered it.
---@class PagleGuideEntry
---@field owner string          -- "Core" (ns.CORE_OWNER), or the Module's def.name
---@field step PagleGuideStep

--- Where the skip link may go, and the fields of a step only Core may set.
local SKIP_TO = { next = true, last = true }
local CORE_SKIP_TO = { close = true }
local CORE_FIELDS = { nextLabel = "string", ownFoot = "boolean" }

--- Why `step` can't join the guide for `owner`, or nil if it can (ONB-R90, Contracts): a missing or mistyped field,
--- or one of Core's own fields from a Module.
---@param owner string
---@param step any
---@return string?
function ns.GuideStepProblem(owner, step)
	if type(step) ~= "table" then
		return "RegisterGuideStep takes a step table, got " .. type(step)
	end
	local id = step.id
	if type(id) ~= "string" or not id:match("^[%w_]+$") then
		return ("RegisterGuideStep: a step's id is a string of [%%w_], got %s"):format(tostring(id))
	elseif type(step.order) ~= "number" then
		return ("RegisterGuideStep: step %s needs an order, a number"):format(id)
	elseif type(step.ribbon) ~= "string" or step.ribbon == "" then
		return ("RegisterGuideStep: step %s needs its ribbon's label"):format(id)
	elseif type(step.build) ~= "function" then
		return ("RegisterGuideStep: step %s needs build, a function"):format(id)
	elseif step.skipLabel ~= nil and type(step.skipLabel) ~= "string" then
		return ("RegisterGuideStep: step %s's skipLabel is a string"):format(id)
	elseif step.onShow ~= nil and type(step.onShow) ~= "function" then
		return ("RegisterGuideStep: step %s's onShow is a function"):format(id)
	end
	local core = owner == ns.CORE_OWNER
	local skipTo = step.skipTo
	if skipTo ~= nil and not (SKIP_TO[skipTo] or (core and CORE_SKIP_TO[skipTo])) then
		return ('RegisterGuideStep: step %s\'s skipTo is "next" or "last", got %s'):format(id, tostring(skipTo))
	end
	for field, luaType in pairs(CORE_FIELDS) do
		if step[field] ~= nil and (not core or type(step[field]) ~= luaType) then
			return ("RegisterGuideStep: step %s can't set %s"):format(id, field)
		end
	end
	return nil
end

--- The guide's steps (ONB-R21): every step registered, Core's and the Modules', until `ModulesChanged` closes the
--- registry; a later one is late (as CORE-R42). A Module that is off registers nothing, so its steps don't exist.
---@class PagleGuideSteps
---@field package entries PagleGuideEntry[]  -- in the order registered
---@field package ids table<string, true>
---@field package closed boolean
---@field package ordered PagleGuideEntry[]? -- by order, made once asked for
local Steps = {}
Steps.__index = Steps

---@return PagleGuideSteps
function ns.NewGuideSteps()
	return setmetatable({ entries = {}, ids = {}, closed = false }, Steps)
end

--- Adds `owner`'s step (ONB-R21, ONB-R90): a copy of its fields, so changing the table later changes nothing. Returns
--- why it can't, adding nothing: a malformed step (ns.GuideStepProblem), an id registered before, or a call after the
--- registry closed, when `late` is true too (the caller reports it through geterrorhandler() rather than raising).
---@param owner string "Core" or the Module's def.name
---@param step any
---@return string? problem
---@return boolean? late
function Steps:Add(owner, step)
	if self.closed then
		return ("%s's RegisterGuideStep came after ModulesChanged, so the step is dropped"):format(owner), true
	end
	local problem = ns.GuideStepProblem(owner, step)
	if problem then
		return problem
	end
	if self.ids[step.id] then
		return ("RegisterGuideStep: a step %s is registered already"):format(step.id)
	end
	local copy = {}
	for key, value in pairs(step) do
		copy[key] = value
	end
	self.ids[step.id] = true
	self.entries[#self.entries + 1] = { owner = owner, step = copy }
	self.ordered = nil
	return nil
end

--- Closes the registry at `ModulesChanged` (ONB-R21): every enabled Module has registered its steps, or failed to.
function Steps:Close()
	self.closed = true
end

---@return boolean
function Steps:IsClosed()
	return self.closed
end

--- The steps in guide order (ONB-R21): by `order`, ties by id.
---@return PagleGuideEntry[]
function Steps:List()
	if not self.ordered then
		local list = {}
		for i, entry in ipairs(self.entries) do
			list[i] = entry
		end
		table.sort(list, function(a, b)
			if a.step.order ~= b.step.order then
				return a.step.order < b.step.order
			end
			return a.step.id < b.step.id
		end)
		self.ordered = list
	end
	return self.ordered
end

--- How many steps the guide has: the "{m}" of "{n} of {m}" (ONB-R20, ONB-R21).
---@return integer
function Steps:Count()
	return #self.entries
end

--- A step's place in the guide, from 1; nil for one not registered.
---@param id string?
---@return integer?
function Steps:Index(id)
	for i, entry in ipairs(self:List()) do
		if entry.step.id == id then
			return i
		end
	end
	return nil
end

--- `owner`'s first step in guide order, where a Write-up's Show me around » opens (ONB-R82); nil for a Module with none.
---@param owner string
---@return string?
function Steps:FirstOf(owner)
	for _, entry in ipairs(self:List()) do
		if entry.owner == owner then
			return entry.step.id
		end
	end
	return nil
end

--- One ribbon under the book (ONB-R24): the current step's hangs longer and brighter, a seen one is ticked.
---@class PagleGuideRibbon
---@field id string
---@field label string
---@field current boolean
---@field seen boolean

--- What the book shows: one step, where it is in the guide, and the ribbons as they hang with it current.
---@class PagleGuidePage
---@field entry PagleGuideEntry
---@field index integer   -- the "{n}" of "{n} of {m}"
---@field count integer   -- the "{m}"
---@field first boolean   -- no « back (ONB-R23)
---@field last boolean    -- Off to the water instead of the skip link and Next (ONB-R23, ONB-R38)
---@field ribbons PagleGuideRibbon[]

--- How a page comes in: the book opening on it, or a page turn forward or back (the Stats book's turn, ONB-R23).
---@alias PagleGuideShow "open"|"forward"|"back"

--- The book on screen, which the guide drives.
---@class PagleGuideView
---@field show fun(page: PagleGuidePage, how: PagleGuideShow) -- opens the book on `page`, or turns to it
---@field close fun()                                         -- closes the book (its fade out)

--- What the guide is fed. Every function is called when needed, never stored.
---@class PagleGuideOptions
---@field steps PagleGuideSteps
---@field onboarding fun(): PagleOnboarding   -- ns.onboarding, whose state holds guideStep, stepsSeen and the rest
---@field isRestricted fun(): boolean         -- Pagle.IsRestricted() (CORE-R30)
---@field view PagleGuideView
---@field hold fun(reason: string)            -- ns.HoldAnnouncements (ANN-R38, ONB-R70)
---@field release fun(reason: string)         -- ns.ReleaseAnnouncements
---@field fire fun(event: PagleEvent, ...: any) -- fires a Core event (CORE-R20): GuideOpened, GuideClosed(stepId)
---@field call fun(fn: function, ...: any): ... -- calls fn; an error is reported, not raised (securecallfunction)
---@field print fun(line: string)

--- What a tour stop's show changed, to put back at its hide (ONB-R84, CORE-R68).
---@class PagleGuideTourBefore
---@field open boolean
---@field id string?
---@field quiet boolean

--- The Field guide (ONB-R20–R27): which step shows, and every way of moving between them.
---@class PagleGuide
---@field package options PagleGuideOptions
---@field package open boolean
---@field package index integer?          -- the step shown, in guide order, while open
---@field package quiet boolean           -- a tour stop's showing: nothing shown is marked (ONB-R84)
---@field package closedByRestriction boolean -- this login's restriction closed it: reopen when it ends (ONB-R25)
---@field package pending string?         -- the step asked for while restricted, to open at when it ends
---@field package offToTheWater (fun())?  -- Off to the water's hook (#328: the First evening list)
---@field package tourBefore PagleGuideTourBefore?
local Guide = {}
Guide.__index = Guide

--- The name Core holds Announcements under while the guide is open (ANN-R38, ONB-R70).
ns.GUIDE_HOLD = "guide"

---@param options PagleGuideOptions
---@return PagleGuide
function ns.NewGuide(options)
	return setmetatable({ options = options, open = false, quiet = false, closedByRestriction = false }, Guide)
end

--- Whether the book is open.
---@return boolean
function Guide:IsOpen()
	return self.open
end

--- The step shown while the book is open, else nil.
---@return PagleGuideEntry?
function Guide:Current()
	return self.open and self.options.steps:List()[self.index] or nil
end

--- The onboarding state's owner, or nil before login step 1 has added the state.
---@param guide PagleGuide
---@return PagleOnboarding?
local function onboardingOf(guide)
	local onboarding = guide.options.onboarding()
	return onboarding and onboarding:State() and onboarding or nil
end

-- The page for step `index`: where it is in the guide and the ribbons as they hang with it current (ONB-R24).
---@param guide PagleGuide
---@param index integer
---@return PagleGuidePage
local function pageAt(guide, index)
	local list = guide.options.steps:List()
	local onboarding = onboardingOf(guide)
	local ribbons = {}
	for i, entry in ipairs(list) do
		local id = entry.step.id
		ribbons[i] = {
			id = id,
			label = entry.step.ribbon,
			current = i == index,
			seen = onboarding ~= nil and onboarding:IsStepSeen(id),
		}
	end
	return {
		entry = list[index],
		index = index,
		count = #list,
		first = index == 1,
		last = index == #list,
		ribbons = ribbons,
	}
end

-- Shows step `index`, as `how` says (ONB-R22): marks it shown (guideStep, stepsSeen) unless the tour shows it, then
-- hands its page to the view, then calls its onShow.
---@param guide PagleGuide
---@param index integer
---@param how PagleGuideShow
local function showAt(guide, index, how)
	local entry = guide.options.steps:List()[index]
	guide.index = index
	local onboarding = onboardingOf(guide)
	if onboarding and not guide.quiet then
		onboarding:StepShown(entry.step.id)
	end
	guide.options.view.show(pageAt(guide, index), how)
	if entry.step.onShow then
		guide.options.call(entry.step.onShow)
	end
end

-- Turns to step `index` while open, forward or back by order; nothing when it shows already.
---@param guide PagleGuide
---@param index integer?
local function turnTo(guide, index)
	if not guide.open or not index or index == guide.index then
		return
	end
	showAt(guide, index, index > guide.index and "forward" or "back")
end

-- Where the guide opens (ONB-R22): `id` if it is registered, else `guideStep` if it still is, else the first step.
---@param guide PagleGuide
---@param id string?
---@return integer
local function targetOf(guide, id)
	local steps = guide.options.steps
	local onboarding = onboardingOf(guide)
	return steps:Index(id) or steps:Index(onboarding and onboarding:GuideStep()) or 1
end

--- Opens the guide (ONB-R22) at `id` if given and registered, else where it was left; open, it turns there instead.
--- While restricted it doesn't open: it says so, and opens there when the restriction ends (ONB-R25). Holds
--- Announcements for the guide while open (ONB-R70) and fires GuideOpened (CORE-R20). Nothing with no step registered.
---@param id string?
function Guide:Open(id)
	local steps = self.options.steps
	if steps:Count() == 0 then
		return
	end
	if self.open then
		turnTo(self, targetOf(self, id))
		return
	end
	if self.options.isRestricted() then
		self.pending = id
		self.closedByRestriction = true
		local onboarding = onboardingOf(self)
		if onboarding then
			onboarding:SetReopen(true)
		end
		self.options.print(ns.L.GUIDE_AFTER_COMBAT)
		return
	end
	self.open = true
	self.options.hold(ns.GUIDE_HOLD)
	showAt(self, targetOf(self, id), "open")
	self.options.fire("GuideOpened")
end

--- Opens the guide at `owner`'s first step (a Write-up's Show me around », ONB-R82). Returns whether it has one.
---@param owner string a Module's def.name
---@return boolean
function Guide:OpenModule(owner)
	local id = self.options.steps:FirstOf(owner)
	if not id then
		return false
	end
	self:Open(id)
	return true
end

--- Next » (ONB-R23): the next step, by a page turn forward; nothing on the last.
function Guide:Next()
	if self.open then
		turnTo(self, math.min(self.index + 1, self.options.steps:Count()))
	end
end

--- « back (ONB-R23): the step before, by a page turn backward; nothing on the first.
function Guide:Back()
	if self.open then
		turnTo(self, math.max(self.index - 1, 1))
	end
end

--- A ribbon (ONB-R24): turns to its step, forward or back by order.
---@param id string
function Guide:GoTo(id)
	turnTo(self, self.options.steps:Index(id))
end

--- The skip link (ONB-R23, ONB-R26): to the last step without visiting the rest, or to the next where the step says
--- `skipTo = "next"`; Core's Welcome step (`skipTo = "close"`) sets `skipped` and closes the guide.
function Guide:Skip()
	local entry = self:Current()
	if not entry then
		return
	end
	local skipTo = entry.step.skipTo
	if skipTo == "close" then
		local onboarding = onboardingOf(self)
		if onboarding and not self.quiet then
			onboarding:SkipGuide()
		end
		self:Close()
	elseif skipTo == "next" then
		self:Next()
	else
		turnTo(self, self.options.steps:Count())
	end
end

--- Closes the guide (the wax close, Esc, a restriction, ONB-R22): `guideStep` stays, so it reopens there. Releases
--- the hold, so what it held shows at once (ONB-R70), and fires GuideClosed with the step shown (CORE-R20).
function Guide:Close()
	if not self.open then
		return
	end
	local entry = self:Current()
	self.open, self.quiet = false, false
	self.options.view.close()
	self.options.release(ns.GUIDE_HOLD)
	self.options.fire("GuideClosed", entry and entry.step.id)
end

--- Sets the function Off to the water calls once the guide has closed (#328 docks the First evening list there).
---@param fn fun()
function Guide:SetOffToTheWater(fn)
	self.offToTheWater = fn
end

--- Off to the water (ONB-R26, ONB-R38): the guide is done (`guideDone`), closes, then calls its hook through `call`.
--- From a step the tour showed, it only closes.
function Guide:Finish()
	if not self.open then
		return
	end
	local quiet = self.quiet
	local onboarding = onboardingOf(self)
	if onboarding and not quiet then
		onboarding:FinishGuide()
	end
	self:Close()
	if self.offToTheWater and not quiet then
		self.options.call(self.offToTheWater)
	end
end

--- RestrictionChanged (ONB-R25): a restriction that starts while the guide is open closes it, keeping `guideStep`,
--- and sets `reopen`; when it ends, the guide reopens at that step and `reopen` clears. Only this login's close
--- reopens it: a `reopen` saved by an earlier login is cleared without opening. A step the tour showed just closes.
---@param isRestricted boolean
function Guide:RestrictionChanged(isRestricted)
	local onboarding = onboardingOf(self)
	if isRestricted then
		if self.open then
			if not self.quiet then
				self.closedByRestriction = true
				self.pending = nil
				if onboarding then
					onboarding:SetReopen(true)
				end
			end
			self:Close()
		end
		return
	end
	if onboarding and onboarding:ShouldReopen() then
		onboarding:SetReopen(false)
	end
	if self.closedByRestriction then
		self.closedByRestriction = false
		local pending = self.pending
		self.pending = nil
		self:Open(pending)
	end
end

--- A tour stop's show (ONB-R84): the guide at step `id`, opened or turned to, marking nothing it shows (never
--- `guideStep`, never `stepsSeen`) until the stop's hide.
---@param id string
function Guide:TourShow(id)
	self.tourBefore = { open = self.open, id = self.open and self:Current().step.id or nil, quiet = self.quiet }
	if self.open then
		self.quiet = true
		turnTo(self, self.options.steps:Index(id))
		return
	end
	if self.options.isRestricted() then
		return
	end
	self.open, self.quiet = true, true
	self.options.hold(ns.GUIDE_HOLD)
	showAt(self, self.options.steps:Index(id) or 1, "open")
	self.options.fire("GuideOpened")
end

--- A tour stop's hide (ONB-R84, CORE-R68): puts back what its show changed: the guide closed again, or, open before,
--- turned back to the step it showed, which marks as it did.
function Guide:TourHide()
	local before = self.tourBefore
	self.tourBefore = nil
	if not before then
		return
	end
	if not before.open then
		self:Close()
	elseif self.open then
		self.quiet = true
		turnTo(self, self.options.steps:Index(before.id))
		self.quiet = before.quiet
	end
end

--- The widgets a step's pages draw with, Core's (adapter/GuideKit.lua's; FakePagle's plain stand-ins).
---@class PagleGuideWidgets
---@field BindingField fun(parent: Frame, action: string, label: string): Frame -- ONB-R40–R44 (#324)
---@field ChoiceCard fun(parent: Frame, title: string, line: string?, tag: string?): Button
---@field Note fun(parent: Frame, text: string, x: number, y: number, w: number, target: Region?, n: integer?): Frame
---@field Part fun(parent: Frame, sprite: string): Texture

--- What a step's build gets (core/onboarding.md › Contracts): the guide's moves and Core's widgets.
---@class PagleGuideNav: PagleGuideWidgets
---@field Next fun()   -- Next » (ONB-R23)
---@field Back fun()   -- « back
---@field Close fun()  -- closes the guide, keeping guideStep (ONB-R22)
---@field Skip fun()   -- the step's skip link (ONB-R23, ONB-R26)
---@field Finish fun() -- Off to the water (ONB-R26, ONB-R38)

--- The nav a step's build gets: `guide`'s moves, each read from `guide` when called, and `widgets`' makers.
---@param guide PagleGuide
---@param widgets PagleGuideWidgets
---@return PagleGuideNav
function ns.NewGuideNav(guide, widgets)
	return {
		Next = function()
			guide:Next()
		end,
		Back = function()
			guide:Back()
		end,
		Close = function()
			guide:Close()
		end,
		Skip = function()
			guide:Skip()
		end,
		Finish = function()
			guide:Finish()
		end,
		BindingField = widgets.BindingField,
		ChoiceCard = widgets.ChoiceCard,
		Note = widgets.Note,
		Part = widgets.Part,
	}
end

--- What draws one of Core's own steps: its build and, if it re-reads live state, its onShow (#323 fills them).
---@class PagleCoreGuideStepDrawing
---@field build fun(left: Frame, right: Frame, nav: PagleGuideNav)
---@field onShow? fun()

--- Core's own four steps (ONB-R21, ONB-R30, ONB-R31, ONB-R34, ONB-R38): Welcome (10), What's in the box (20),
--- Moments (50) and Off you go (90), with their ribbons, the Welcome step's skip link "I'll find my own way" that closes
--- the guide (ONB-R26) and its "Show me around »", and Off you go drawing its own Off to the water. Each draws with
--- `drawings[id]`, looked up as it draws, so a drawing set there later (#323's pages) is the one used; nothing where
--- it has none.
---@param drawings table<string, PagleCoreGuideStepDrawing>
---@return PagleGuideStep[]
function ns.CoreGuideSteps(drawings)
	local L = ns.L
	-- One of Core's steps, `fields` with a build and an onShow that call its drawing's.
	---@param fields table
	---@return PagleGuideStep
	local function drawn(fields)
		local id = fields.id
		fields.build = function(left, right, nav)
			local drawing = drawings[id]
			if drawing then
				drawing.build(left, right, nav)
			end
		end
		fields.onShow = function()
			local drawing = drawings[id]
			if drawing and drawing.onShow then
				drawing.onShow()
			end
		end
		return fields
	end
	return {
		drawn({
			id = "welcome",
			order = 10,
			ribbon = L.GUIDE_RIBBON_WELCOME,
			skipLabel = L.GUIDE_WELCOME_SKIP,
			skipTo = "close",
			nextLabel = L.GUIDE_WELCOME_NEXT,
		}),
		drawn({ id = "box", order = 20, ribbon = L.GUIDE_RIBBON_BOX }),
		drawn({ id = "moments", order = 50, ribbon = L.GUIDE_RIBBON_MOMENTS }),
		drawn({ id = "off", order = 90, ribbon = L.GUIDE_RIBBON_OFF, ownFoot = true }),
	}
end
