---@class PagleNS
local ns = select(2, ...)

-- The unsaved-Casts reminder (LOG-R86): pure logic counting the Casts recorded since load (CORE-R7). WoW writes
-- SavedVariables only on logout or /reload, so these are the Casts a crash would lose (LOG-R85); Core does nothing
-- else about it. The adapter tells it each recorded Cast and each end of restriction, and shows the line.

--- Tunable: the reminder shows a line each time this many more Casts are unsaved (LOG-R86).
ns.RELOAD_REMINDER_STEP = 50

--- What the reminder is given: whether the option is on (`PagleDB.profile.reloadReminder`), whether Pagle is
--- restricted (CORE-R30), and how a line is shown, given the number of Casts unsaved.
---@class PagleReloadReminderDeps
---@field isOn fun(): boolean
---@field isRestricted fun(): boolean
---@field show fun(count: integer)

---@class PagleReloadReminder
---@field private deps PagleReloadReminderDeps
---@field private count integer Casts recorded since load
---@field private held integer? the count of a line that fell due while restricted
local ReloadReminder = {}
ReloadReminder.__index = ReloadReminder

---@param deps PagleReloadReminderDeps
---@return PagleReloadReminder
function ns.NewReloadReminder(deps)
	return setmetatable({ deps = deps, count = 0 }, ReloadReminder)
end

--- A Cast was recorded to the Catch log (caught or got away; an interrupted Cast records nothing, LOG-R7). Each
--- step's line shows now, or, while restricted, is held for `RestrictionEnded`. Only the option's state when the line
--- falls due counts: nothing is held while it's off.
function ReloadReminder:CastRecorded()
	self.count = self.count + 1
	if self.count % ns.RELOAD_REMINDER_STEP ~= 0 or not self.deps.isOn() then
		return
	end
	if self.deps.isRestricted() then
		-- One held line for every step passed in one restriction, with the latest count.
		self.held = self.count
	else
		self.deps.show(self.count)
	end
end

--- The restriction ended: the line held through it shows once, if the option is still on.
function ReloadReminder:RestrictionEnded()
	local held = self.held
	self.held = nil
	if held and self.deps.isOn() then
		self.deps.show(held)
	end
end
