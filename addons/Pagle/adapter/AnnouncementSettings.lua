---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Core's rows on the Announcements page (SET-R30): Cozy mode, Interruption budget, and the budget's Interruptions
-- and Per. Native controls on proxy settings over `PagleDB.profile.announcements` (announcements.md › Data), built
-- when adapter/Settings.lua registers the page. Core's slots in the "Announcements" category, Toast style and Sound
-- set, end them as slot dropdowns (CORE-R42, adapter/LookAndFeel.lua).
local L = ns.L

-- The sliders' ranges (settings.md › Tunables). Per is in minutes; the budget's window is stored in seconds.
local COUNT_MIN, COUNT_MAX = 1, 10
local WINDOW_MIN, WINDOW_MAX = 1, 15
local STEP = 1
local SECONDS_PER_MINUTE = 60

-- The proxy setting variables, one per row.
local COZY = "Pagle_Core_cozy"
local BUDGET = "Pagle_Core_budget"
local COUNT = "Pagle_Core_budgetCount"
local WINDOW = "Pagle_Core_budgetWindow"

---@return { cozy: boolean, budget: { on: boolean, count: integer, window: integer } }
local function stored()
	return ns.db.profile.announcements
end

-- Greying (SET-R31): the budget while Cozy mode is on; its two sliders also while the budget is off.
local function budgetLive()
	return not stored().cozy
end
local function slidersLive()
	return not stored().cozy and stored().budget.on
end

-- A row that greys while `isLive` returns false, re-evaluated each time the page is shown and whenever any of
-- Core's values on it changes (SET-R31, SET-R61). A greyed row keeps its value.
---@param initializer SettingsInitializer
---@param isLive fun(): boolean
local function greys(initializer, isLive)
	initializer:AddModifyPredicate(isLive)
	for _, variable in ipairs({ COZY, BUDGET, COUNT, WINDOW }) do
		initializer:AddEvaluateStateCVar(variable)
	end
end

-- A slider's options, its value shown on the right through `format`.
---@param min number
---@param max number
---@param format fun(value: number): string
---@return SettingsSliderOptions
local function sliderOptions(min, max, format)
	local options = Settings.CreateSliderOptions(min, max, STEP)
	options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, format)
	return options
end

-- Builds the rows on the Announcements page in SET-R30's order. Each reads the stored value each time the page is
-- shown and writes it at once (SET-R62); `default` is what the page's Defaults button restores (SET-R33).
---@param page SettingsCategory
ns.CoreSettingsRows.announcements = function(page)
	local Boolean, Number = Settings.VarType.Boolean, Settings.VarType.Number

	local cozy = Settings.RegisterProxySetting(page, COZY, Boolean, L.SETTINGS_COZY, false, function()
		return stored().cozy
	end, function(value)
		stored().cozy = value
	end)
	Settings.CreateCheckbox(page, cozy, L.SETTINGS_COZY_TOOLTIP)

	local budgetOn = Settings.RegisterProxySetting(page, BUDGET, Boolean, L.SETTINGS_BUDGET, true, function()
		return stored().budget.on
	end, function(value)
		stored().budget.on = value
	end)
	local budget = Settings.CreateCheckbox(page, budgetOn, L.SETTINGS_BUDGET_TOOLTIP)
	greys(budget, budgetLive)

	local countSetting = Settings.RegisterProxySetting(page, COUNT, Number, L.SETTINGS_BUDGET_COUNT, 4, function()
		return stored().budget.count
	end, function(value)
		stored().budget.count = value
	end)
	local count = Settings.CreateSlider(page, countSetting, sliderOptions(COUNT_MIN, COUNT_MAX, tostring))
	count:SetParentInitializer(budget)
	greys(count, slidersLive)

	-- Shown and set in minutes, stored in seconds.
	local windowSetting = Settings.RegisterProxySetting(page, WINDOW, Number, L.SETTINGS_BUDGET_WINDOW, 5, function()
		return stored().budget.window / SECONDS_PER_MINUTE
	end, function(value)
		stored().budget.window = value * SECONDS_PER_MINUTE
	end)
	local window = Settings.CreateSlider(
		page,
		windowSetting,
		sliderOptions(WINDOW_MIN, WINDOW_MAX, function(value)
			return L.MINUTES:format(value)
		end)
	)
	window:SetParentInitializer(budget)
	greys(window, slidersLive)

	-- Toast style and Sound set: the same equipped looks as on Look and Feel, which this page's Defaults button
	-- restores too (SET-R30, SET-R33, SET-R51).
	for _, slot in ipairs(ns.CoreAnnouncementSlots(ns.goods)) do
		ns.SlotDropdown(page, slot, "Pagle_Core_announcements_" .. slot.id)
	end
end
