---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- Pagle's native Settings rows, each on a template of Pagle's own (SET-R7; from 1.5.3): the twins of Blizzard's
-- creators that Pagle used, built through Blizzard's public creators that take a template, with the same data and
-- search tags, so each row is Blizzard's control whole (SET-R5): its look, the settings search, the page's Defaults,
-- greying by its parent and modify predicates, its tooltip and its value's text.
--
-- Blizzard's Settings list pools its row frames by template name (Blizzard_SettingsList.lua's Factory over
-- ScrollUtil.lua's ScrollBoxFactoryInitializerMixin, Pools.lua's GetPoolKey; Gethe/wow-ui-source branch forever,
-- 1.60.1 (70862)). A row Pagle built is Pagle's data, so a frame drawing it runs SettingsListElementMixin:Init as
-- Pagle's, and its callback handles keep that taint after Release. A Blizzard row drawn in that frame next, such as
-- Nameplates' "Nameplate style", then ran its Init, and the player's change through it, as Pagle's: its CVar and the
-- nameplates took the taint, and every nameplate shown after errored until /reload. On templates of Pagle's own, its
-- rows' frames come from pools of their own, which no Blizzard row draws from.
--
-- Each creator here takes the page's layout where Blizzard's takes its category, since Pagle never asks SettingsPanel
-- for a layout (SET-R6), and returns the initializer, as Blizzard's does. The Blizzard creators these replace aren't
-- in .luacheckrc's stds, so a call to one fails the lint (spec/Pagle/settings_taint_spec.lua checks them too).

local HEADER = "PagleSettingsListSectionHeaderTemplate"
local CHECKBOX = "PagleSettingsCheckboxControlTemplate"
local SLIDER = "PagleSettingsSliderControlTemplate"
local DROPDOWN = "PagleSettingsDropdownControlTemplate"
local CHECKBOX_SLIDER = "PagleSettingsCheckboxSliderControlTemplate"
local BUTTON = "PagleSettingButtonControlTemplate"
-- The element template a Pagle dropdown's options draw on in Blizzard's menu (adapter/Settings.xml).
local MENU_OPTION = "PagleMenuDropdownHighlightButtonTemplate"

--- Settings.CreateCheckbox on Pagle's template: a native checkbox row over the boolean `setting`, added to `layout`.
---@param layout SettingsLayout
---@param setting SettingsProxySetting
---@param tooltip string?
---@return SettingsInitializer
function ns.CreateCheckbox(layout, setting, tooltip)
	assert(setting:GetVariableType() == "boolean")
	return layout:AddInitializer(Settings.CreateControlInitializer(CHECKBOX, setting, nil, tooltip))
end

--- Settings.CreateSlider on Pagle's template: a native slider row over the number `setting`, added to `layout`.
---@param layout SettingsLayout
---@param setting SettingsProxySetting
---@param options SettingsSliderOptions
---@param tooltip string?
---@return SettingsInitializer
function ns.CreateSlider(layout, setting, options, tooltip)
	assert(setting:GetVariableType() == "number" and options ~= nil)
	return layout:AddInitializer(Settings.CreateControlInitializer(SLIDER, setting, options, tooltip))
end

--- Settings.CreateDropdown on Pagle's template: a native dropdown row over `setting`, its options read each time it
--- opens, added to `layout`. Its options open on Pagle's element template (PagleSettingsDropdownControlMixin).
---@param layout SettingsLayout
---@param setting SettingsProxySetting
---@param options fun(): table[]
---@param tooltip string?
---@return SettingsInitializer
function ns.CreateDropdown(layout, setting, options, tooltip)
	assert(options ~= nil)
	return layout:AddInitializer(Settings.CreateControlInitializer(DROPDOWN, setting, options, tooltip))
end

--- CreateSettingsListSectionHeaderInitializer on Pagle's template (Blizzard_SettingControls.lua's data). Not added.
---@param name string
---@param tooltip string?
---@return SettingsInitializer
function ns.CreateSettingsListSectionHeaderInitializer(name, tooltip)
	return Settings.CreateElementInitializer(HEADER, { name = name, tooltip = tooltip })
end

--- CreateSettingsButtonInitializer on Pagle's template (Blizzard_SettingControls.lua's data and search tags): a
--- native button row, its label `name` beside a button reading `buttonText` that runs `buttonClick`. Not added.
---@param name string
---@param buttonText string|fun(): string
---@param buttonClick fun()
---@param tooltip string?
---@param addSearchTags boolean
---@return SettingsInitializer
function ns.CreateSettingsButtonInitializer(name, buttonText, buttonClick, tooltip, addSearchTags)
	assert(addSearchTags ~= nil)
	local initializer = Settings.CreateElementInitializer(
		BUTTON,
		{ name = name, buttonText = buttonText, buttonClick = buttonClick, tooltip = tooltip }
	)
	if addSearchTags then
		initializer:AddSearchTags(name)
		-- Blizzard's AddSearchTags skips a caption that isn't a string (one read each time the row is drawn)
		if type(buttonText) == "string" then
			initializer:AddSearchTags(buttonText)
		end
	end
	return initializer
end

--- CreateSettingsCheckboxSliderInitializer on Pagle's template (Blizzard_SettingControls.lua's data and search tags):
--- the native checkbox with a slider beside it. Not added.
---@param cbSetting SettingsProxySetting
---@param cbLabel string
---@param cbTooltip string?
---@param sliderSetting SettingsProxySetting
---@param sliderOptions SettingsSliderOptions
---@param sliderLabel string
---@param sliderTooltip string?
---@return SettingsInitializer
function ns.CreateSettingsCheckboxSliderInitializer(
	cbSetting,
	cbLabel,
	cbTooltip,
	sliderSetting,
	sliderOptions,
	sliderLabel,
	sliderTooltip
)
	local initializer = Settings.CreateSettingInitializer(CHECKBOX_SLIDER, {
		name = cbLabel,
		tooltip = cbTooltip,
		cbSetting = cbSetting,
		cbLabel = cbLabel,
		cbTooltip = cbTooltip,
		sliderSetting = sliderSetting,
		sliderOptions = sliderOptions,
		sliderLabel = sliderLabel,
		sliderTooltip = sliderTooltip,
	})
	initializer:AddSearchTags(cbLabel, sliderLabel)
	return initializer
end

-- Each option's element factory in Blizzard's menu: Pagle's option template, with no initializer of its own, as
-- MenuTemplates.CreateHighlightRadio's factory has none (Blizzard_Menu/MenuTemplates.lua).
---@param factory fun(template: string)
local function optionFactory(factory)
	factory(MENU_OPTION)
end

--- The mixin of PagleSettingsDropdownControlTemplate (adapter/Settings.xml), which the client applies after the
--- inherited SettingsDropdownControlMixin's: the native dropdown row, whose menu Blizzard builds as for its own
--- (Settings.CreateDropdownOptionInserter, Settings.InitDropdown: its radios, the selected one, the steppers, the
--- tooltip), each option then drawn on Pagle's element template. Blizzard's menu draws every dropdown's options from
--- one shared factory pooled by template (Blizzard_Menu/Menu.lua's MenuElementFactory), so on Pagle's template a Pagle
--- option never draws in, nor adds to, the frames Blizzard's own dropdowns reuse (SET-R7).
---@class PagleSettingsDropdownControlMixin : Frame
PagleSettingsDropdownControlMixin = {}

--- SettingsDropdownControlMixin:SetupDropdownMenu, its options' element factory set to Pagle's template. Called as
--- a method of the row's frame.
---@param _ Frame the row's frame
---@param button DropdownButton the row's dropdown
---@param setting SettingsProxySetting
---@param options fun(): table[]
---@param initTooltip fun()
---@param initializer SettingsInitializer
function PagleSettingsDropdownControlMixin.SetupDropdownMenu(_, button, setting, options, initTooltip, initializer)
	local inserter = Settings.CreateDropdownOptionInserter(setting, options, initializer)
	Settings.InitDropdown(button, setting, function(menuSetting, rootDescription)
		inserter(menuSetting, rootDescription)
		for _, option in rootDescription:EnumerateElementDescriptions() do
			option:SetElementFactory(optionFactory)
		end
	end, initTooltip, initializer)
end
