---@class PagleNS
local ns = select(2, ...)

-- The First evening list (core/onboarding.md › The First evening list, ONB-R60–R64): which items it has, each only
-- while its owner is registered, which are done and which is next, when it docks and when it never does, its ticks,
-- the fold after the last, the close mark and the Settings root's checkbox. Pure logic over Core's onboarding state
-- (logic/Onboarding.lua) and a view (CORE-R7); logic/Wiring.lua's ns.WireEvening builds it over Core's host, docks its
-- frame and feeds it the events, so Core's adapter (adapter/Evening.lua) and FakePagle run the same list.

--- The list's place in the tracker dock (CORE-R70): the top tracker.
ns.EVENING_ORDER = 1

--- Seconds the list waits after its last tick before it folds away (ONB-R62, Tunables).
ns.EVENING_FOLD_DELAY = 2.5

--- One item of the list (ONB-R61): its id, its owner (Core, or the Module's def.name, which marks it with
--- M:CompleteEveningItem), its text and hint as keys of ns.L. The `cast` item's hint is QoL's while QoL is registered,
--- else `hintNoQoL` (ONB-R101).
---@class PagleEveningItem
---@field id string
---@field owner string
---@field text string
---@field hint string?
---@field hintNoQoL string?

--- The items, in order (ONB-R61). No item waits on Show every catch, Cozy mode or a card.
---@type PagleEveningItem[]
ns.EVENING_ITEMS = {
	{
		id = "cast",
		owner = ns.CORE_OWNER,
		text = "EVENING_CAST",
		hint = "EVENING_CAST_HINT",
		hintNoQoL = "EVENING_CAST_HINT_NO_QOL",
	},
	{ id = "catch", owner = ns.CORE_OWNER, text = "EVENING_CATCH" },
	{ id = "journal", owner = "Ledger", text = "EVENING_JOURNAL", hint = "EVENING_JOURNAL_HINT" },
	{ id = "hunts", owner = "Hunts", text = "EVENING_HUNTS", hint = "EVENING_HUNTS_HINT" },
	{ id = "session", owner = ns.CORE_OWNER, text = "EVENING_SESSION", hint = "EVENING_SESSION_HINT" },
	{ id = "shop", owner = ns.CORE_OWNER, text = "EVENING_SHOP", hint = "EVENING_SHOP_HINT" },
}

--- The item `id`, or nil for one the list doesn't have.
---@param id any
---@return PagleEveningItem?
function ns.EveningItem(id)
	for _, item in ipairs(ns.EVENING_ITEMS) do
		if item.id == id then
			return item
		end
	end
	return nil
end

--- One line of the list as drawn: done ones ticked and struck, the first not done is `next`, with the green wash and
--- its hint under it (ONB-R62).
---@class PagleEveningLine
---@field id string
---@field text string
---@field hint string?  -- the next item's alone
---@field done boolean
---@field next boolean

--- The list as drawn: its lines, and "{done} of {total}" (ONB-R60).
---@class PagleEveningList
---@field lines PagleEveningLine[]
---@field done integer
---@field total integer

--- Where the list is drawn: adapter/Evening.lua's tracker on the client, FakePagle's record of it.
---@class PagleEveningView
---@field draw fun(list: PagleEveningList, ticked: string?) -- shows the list docked as `list`; `ticked` was just done
---@field hide fun()                -- hides it at once
---@field fold fun()                -- folds it away (MOTION.md: 0.4 s), then hides it
---@field sound fun(name: string)   -- plays `tick` or `listDone` (SOUND.md)

--- What the list is fed. Every function is called when needed, never stored.
---@class PagleEveningOptions
---@field onboarding fun(): PagleOnboarding
---@field registered fun(owner: string): boolean -- Core, or a Module registered now
---@field after fun(seconds: number, fn: fun())  -- runs fn `seconds` from now (C_Timer.After)
---@field view PagleEveningView

--- The First evening list (ONB-R60–R63).
---@class PagleEvening
---@field package options PagleEveningOptions
---@field package showing boolean   -- docked and shown now
---@field package folding table?    -- the wait before the fold under way: its token
---@field package touring boolean   -- the tour stop's sample is on screen
local Evening = {}
Evening.__index = Evening

---@param options PagleEveningOptions
---@return PagleEvening
function ns.NewEvening(options)
	return setmetatable({ options = options, showing = false, touring = false }, Evening)
end

-- The onboarding state's calls, or nil before the state exists (a PagleDB that lost it, until PLAYER_LOGIN).
---@param evening PagleEvening
---@return PagleOnboarding?
local function onboardingOf(evening)
	local onboarding = evening.options.onboarding()
	if onboarding and onboarding:State() then
		return onboarding
	end
	return nil
end

--- The list now, or with `sample` as the done items instead of the state's (the tour's): the items whose owner is
--- registered, in order (ONB-R61).
---@param sample table<string, true>?
---@return PagleEveningList
function Evening:List(sample)
	local L, options = ns.L, self.options
	local onboarding = onboardingOf(self)
	local lines, done, found = {}, 0, false
	for _, item in ipairs(ns.EVENING_ITEMS) do
		if options.registered(item.owner) then
			local isDone
			if sample then
				isDone = sample[item.id] == true
			else
				isDone = onboarding ~= nil and onboarding:IsEveningItemDone(item.id)
			end
			local line = { id = item.id, text = L[item.text], done = isDone, next = false }
			if isDone then
				done = done + 1
			elseif not found then
				found = true
				line.next = true
				local hint = item.hint
				if item.hintNoQoL and not options.registered("QoL") then
					hint = item.hintNoQoL
				end
				line.hint = hint and L[hint]
			end
			lines[#lines + 1] = line
		end
	end
	return { lines = lines, done = done, total = #lines }
end

--- "{done} of {total}": the registered items done, and all of them (ONB-R60, ONB-R81).
---@return integer done
---@return integer total
function Evening:Count()
	local list = self:List()
	return list.done, list.total
end

--- Whether every registered item is done (ONB-R62).
---@return boolean
function Evening:IsFinished()
	local done, total = self:Count()
	return done == total
end

--- Whether the list is docked and shown now.
---@return boolean
function Evening:IsShowing()
	return self.showing
end

--- Whether the Settings root offers its First evening list checkbox (ONB-R81): while an item isn't done, to an Angler
--- who isn't returning (ONB-R2).
---@return boolean
function Evening:IsOffered()
	local onboarding = onboardingOf(self)
	return onboarding ~= nil and not onboarding:IsReturning() and not self:IsFinished()
end

-- Draws the list docked, as it is now.
---@param evening PagleEvening
---@param ticked string?
local function show(evening, ticked)
	evening.showing = true
	if not evening.touring then
		evening.options.view.draw(evening:List(), ticked)
	end
end

-- Hides the list at once, and any fold waiting.
---@param evening PagleEvening
local function hide(evening)
	evening.folding = nil
	if evening.showing then
		evening.showing = false
		if not evening.touring then
			evening.options.view.hide()
		end
	end
end

-- The last item ticked (ONB-R62): listDone, and 2.5 s later the fold, which closes the list for good.
---@param evening PagleEvening
local function finish(evening)
	local options = evening.options
	options.view.sound("listDone")
	local token = {}
	evening.folding = token
	options.after(ns.EVENING_FOLD_DELAY, function()
		if evening.folding ~= token then
			return
		end
		evening.folding = nil
		local onboarding = onboardingOf(evening)
		if onboarding then
			onboarding:CloseEvening()
		end
		evening.showing = false
		if not evening.touring then
			options.view.fold()
		end
	end)
end

--- Login, once the state is there (ONB-R60): a list docked before, unclosed and unfinished, shows again. One whose
--- last item was ticked but whose fold never ran (a /reload in its 2.5 s) closes instead.
function Evening:Login()
	local onboarding = onboardingOf(self)
	if not onboarding or onboarding:IsReturning() then
		return
	end
	if not onboarding:IsEveningShown() or onboarding:IsEveningClosed() then
		return
	end
	if self:IsFinished() then
		onboarding:CloseEvening()
	else
		show(self)
	end
end

--- Off to the water (ONB-R38, ONB-R60): the list docks, setting `evening.shown`, unless the Angler is returning or
--- skipped the guide, the list was closed, or every item is done already.
function Evening:OffToTheWater()
	local onboarding = onboardingOf(self)
	if not onboarding or onboarding:IsReturning() or onboarding:IsSkipped() or onboarding:IsEveningClosed() then
		return
	end
	if self:IsFinished() then
		return
	end
	onboarding:MarkEveningShown()
	show(self)
end

--- An item is done (ONB-R61): Core's own on their events, a Module's through M:CompleteEveningItem. Kept even before
--- the list docks; ignored when it's closed or the item done, and for a returning Angler, who never has the list.
--- While the list shows, the item ticks with `tick` (ONB-R62), and the last one finishes it. Returns whether it was
--- marked now.
---@param id string
---@return boolean
function Evening:Complete(id)
	local onboarding = onboardingOf(self)
	if not onboarding or onboarding:IsReturning() or not onboarding:CompleteEveningItem(id) then
		return false
	end
	if self.showing then
		show(self, id)
		self.options.view.sound("tick")
		if self:IsFinished() then
			finish(self)
		end
	end
	return true
end

--- The close mark (ONB-R63): the list closes, `evening.closed = true`.
function Evening:Close()
	local onboarding = onboardingOf(self)
	if onboarding then
		onboarding:CloseEvening()
	end
	hide(self)
end

--- The Settings root's First evening list checkbox (ONB-R63, ONB-R81): on shows the list again, unclosed, while an
--- item isn't done; off closes it as the close mark does.
---@param shown boolean
function Evening:SetShown(shown)
	if not shown then
		self:Close()
		return
	end
	local onboarding = onboardingOf(self)
	if not onboarding or self:IsFinished() then
		return
	end
	onboarding:ReopenEvening()
	onboarding:MarkEveningShown()
	show(self)
end

--- `/pagle dev onboarding evening` (ONB-R83): docks the list now, unclosed, whoever the Angler is; a finished one
--- shows ticked and folds away again.
function Evening:Dock()
	local onboarding = onboardingOf(self)
	if not onboarding then
		return
	end
	onboarding:ReopenEvening()
	onboarding:MarkEveningShown()
	show(self)
	if self:IsFinished() then
		finish(self)
	end
end

-- The tour's sample: the canvas's scene, two items done and the Journal next (board 10).
local TOUR_SAMPLE = { cast = true, catch = true }

--- The tour stop `core.onboarding.evening` (ONB-R84): the list docked as the canvas shows it, writing nothing.
function Evening:TourShow()
	self.touring = true
	self.options.view.draw(self:List(TOUR_SAMPLE))
end

--- The stop's hide (CORE-R68): the list as it was, shown as it is now, or hidden.
function Evening:TourHide()
	if not self.touring then
		return
	end
	self.touring = false
	if self.showing then
		self.options.view.draw(self:List())
	else
		self.options.view.hide()
	end
end
