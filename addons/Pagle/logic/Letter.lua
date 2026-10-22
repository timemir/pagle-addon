---@class PagleNS
local ns = select(2, ...)

-- The Letter (core/onboarding.md › The Letter): when it shows, once per login, as ONB-R10's conditions hold; Open the
-- letter and Later (ONB-R12); whether it shows now, for the menu's tooltip (ONB-R13); a restriction or an instance
-- hiding it until the checks pass again (ONB-R14); the Modules' dialogs it waits for (ONB-R100, QoL's conflict note);
-- `/pagle dev onboarding letter` (ONB-R83) and its tour stop's sample (ONB-R84). Pure logic over what it's handed
-- (CORE-R7); logic/Wiring.lua's ns.WireLetter builds it over Core's host, and adapter/Letter.lua draws the frame.

--- ONB-R10's delay (Tunables): the Letter shows no sooner than this many seconds after PLAYER_ENTERING_WORLD.
ns.LETTER_DELAY = 4

--- What the Letter is fed. Every function is called when needed, never stored.
---@class PagleLetterOptions
---@field onboarding fun(): PagleOnboarding -- Core's onboarding state (ns.onboarding)
---@field isRestricted fun(): boolean       -- Pagle.IsRestricted() (CORE-R33)
---@field inInstance fun(): boolean         -- IsInInstance()
---@field cardsSettled fun(): boolean       -- the login's held Announcements and cards have shown and closed (ANN-R21)
---@field after fun(seconds: number, fn: fun()) -- runs fn `seconds` from now
---@field show fun()                        -- puts the frame on screen, rising in with the `letter` sound (ONB-R11)
---@field hide fun()                        -- takes it off screen at once
---@field openGuide fun()                   -- opens the Field guide at its first step (ONB-R12, ONB-R20)

--- Where this login's Letter is: `waiting` to show, `shown` on screen, `away` hidden by a restriction or an instance
--- to show again (ONB-R14), `done` answered, so not again this login.
---@alias PagleLetterPhase "waiting"|"shown"|"away"|"done"

--- The Letter for one login.
---@class PagleLetter
---@field package options PagleLetterOptions
---@field package phase PagleLetterPhase
---@field package ready boolean               -- LETTER_DELAY has passed since the latest PLAYER_ENTERING_WORLD
---@field package entered integer             -- each PLAYER_ENTERING_WORLD bumps it, so only the latest one's delay counts
---@field package dialogs table<string, true> -- the Modules whose dialog is open now (M:SetDialogOpen)
---@field package preview boolean             -- the tour's sample is on screen (ONB-R84)
local Letter = {}
Letter.__index = Letter

---@param options PagleLetterOptions
---@return PagleLetter
function ns.NewLetter(options)
	return setmetatable(
		{ options = options, phase = "waiting", ready = false, entered = 0, dialogs = {}, preview = false },
		Letter
	)
end

--- Whether the Letter is on screen now, the tour's sample included: the menu's tooltip then adds "A letter for you"
--- (ONB-R13, CORE-R55).
---@return boolean
function Letter:IsShowing()
	return self.phase == "shown" or self.preview
end

--- Whether a Module's dialog that the Letter waits for is open (ONB-R100).
---@return boolean
function Letter:IsDialogOpen()
	return next(self.dialogs) ~= nil
end

-- Whether a restriction or an instance keeps the Letter off screen (ONB-R10, ONB-R14).
---@param letter PagleLetter
---@return boolean
local function keptAway(letter)
	return letter.options.isRestricted() or letter.options.inInstance()
end

--- ONB-R10's checks, run at each moment the Letter may come or go: the delay's end, RestrictionChanged,
--- ZONE_CHANGED_NEW_AREA, a card closing and a Module's dialog closing. A Letter still to show this login shows once
--- `letter` is due (waiting or later), the delay has passed, no Module's dialog is open, the login's cards have shown
--- and closed, and neither a restriction nor an instance keeps it away. One on screen hides for a restriction or an
--- instance alone (ONB-R14), and shows again at a later check. While the tour's sample shows, nothing changes.
function Letter:Check()
	if self.preview or self.phase == "done" then
		return
	end
	local options = self.options
	if self.phase == "shown" then
		if keptAway(self) then
			self.phase = "away"
			options.hide()
		end
		return
	end
	if
		self.ready
		and options.onboarding():IsLetterDue()
		and not self:IsDialogOpen()
		and not keptAway(self)
		and options.cardsSettled()
	then
		self.phase = "shown"
		options.show()
	end
end

--- PLAYER_ENTERING_WORLD, at the login and at each loading screen after: the delay counts again from now (ONB-R10),
--- and a Letter on screen hides if the world is an instance.
function Letter:EnteredWorld()
	self.entered = self.entered + 1
	local entered = self.entered
	self.ready = false
	self.options.after(ns.LETTER_DELAY, function()
		if entered == self.entered then
			self.ready = true
			self:Check()
		end
	end)
	self:Check()
end

--- A Module's dialog that asks the player something opened or closed (M:SetDialogOpen, ONB-R100): the Letter waits
--- while any is open, and checks again as one closes.
---@param owner string the Module's def.name
---@param open boolean
function Letter:SetDialogOpen(owner, open)
	self.dialogs[owner] = open or nil
	if not open then
		self:Check()
	end
end

-- A button on the tour's sample: it only goes. Returns whether the sample was showing.
---@param letter PagleLetter
---@return boolean
local function endPreview(letter)
	if not letter.preview then
		return false
	end
	letter.preview = false
	letter.options.hide()
	return true
end

--- Open the letter (ONB-R12): `letter = "opened"`, the Letter goes, and the guide opens at its first step.
function Letter:Open()
	if endPreview(self) or self.phase ~= "shown" then
		return
	end
	self.phase = "done"
	self.options.onboarding():OpenLetter()
	self.options.hide()
	self.options.openGuide()
end

--- Later (ONB-R12): the Letter goes; from `waiting` it is `later`, shown once more at the next login, and from
--- `later` it is `declined`.
function Letter:Later()
	if endPreview(self) or self.phase ~= "shown" then
		return
	end
	self.phase = "done"
	self.options.onboarding():LetterLater()
	self.options.hide()
end

--- `/pagle dev onboarding letter` (ONB-R83): the Letter on screen now, whatever its state and ONB-R10's conditions,
--- its buttons acting as ever. The tour's sample on screen becomes it.
function Letter:ShowNow()
	if self.preview then
		self.preview = false
		self.phase = "shown"
		return
	end
	if self.phase ~= "shown" then
		self.phase = "shown"
		self.options.show()
	end
end

--- The tour stop `core.onboarding.letter`'s show (ONB-R84): the Letter on screen as a sample, writing nothing, its
--- buttons only closing it (CORE-R68). Nothing while the Letter itself shows.
function Letter:TourShow()
	if self:IsShowing() then
		return
	end
	self.preview = true
	self.options.show()
end

--- The tour stop's hide (CORE-R68): the sample goes, and a Letter still to show this login is checked for again.
function Letter:TourHide()
	if endPreview(self) then
		self:Check()
	end
end
