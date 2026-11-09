---@meta _
-- Blizzard's native Settings API, as far as Core uses it (CORE-R40), which Ketho's vscode-wow-api annotations
-- (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never loaded by the game, and
-- excluded from luacheck. Source: Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_Settings_Shared/ (Blizzard_Settings.lua, Blizzard_SettingControls.lua,
-- Blizzard_SettingsLayouts.lua).

---@class SettingsCategory
---@field GetID fun(self: SettingsCategory): any
---@field GetName fun(self: SettingsCategory): string

---@class SettingsLayout
---@field AddInitializer fun(self: SettingsLayout, initializer: SettingsInitializer): SettingsInitializer
--- The page's rows, in order: the list SettingsPanelMixin:DisplayLayout shows (Blizzard_SettingsLayouts.lua).
---@field GetInitializers fun(self: SettingsLayout): SettingsInitializer[]

--- A list frame from the panel's pool. Templates based on SettingsListElementTemplate have the row's label in Text.
---@class SettingsListElementFrame : Frame
---@field Text FontString?
--- A dropdown row's control, made in SettingsDropdownControlMixin:OnLoad (Blizzard_SettingControls.lua), with its
--- dropdown button; nil on other rows.
---@field Control { Dropdown: Frame }?

--- SettingsListElementInitializer: one row of a vertical layout.
---@class SettingsInitializer
---@field data table
---@field GetData fun(self: SettingsInitializer): table
---@field GetName fun(self: SettingsInitializer): string?
---@field GetSetting fun(self: SettingsInitializer): SettingsProxySetting?
---@field SetParentInitializer fun(self: SettingsInitializer, parent: SettingsInitializer, modifyPredicate?: fun(): boolean)
---@field AddModifyPredicate fun(self: SettingsInitializer, predicate: fun(): boolean)
---@field AddShownPredicate fun(self: SettingsInitializer, predicate: fun(): boolean) shown only while each returns true
--- (SettingsSearchableElementMixin, Blizzard_Settings.lua)
---@field AddSearchTags fun(self: SettingsInitializer, ...: string)
--- A setting variable (despite the name, any registered setting's) whose change re-evaluates the shown row's state.
---@field AddEvaluateStateCVar fun(self: SettingsInitializer, variable: string)

--- A registered setting. The recording command changes Cozy mode through the native setting, so its checkbox
--- and dependent controls update together (SettingMixin:SetValue in Blizzard_Settings.lua).
---@class SettingsProxySetting
---@field SetValue fun(self: SettingsProxySetting, value: any)
---@field GetName fun(self: SettingsProxySetting): string
---@field GetVariableType fun(self: SettingsProxySetting): string

--- SettingsSliderOptionsMixin.
---@class SettingsSliderOptions
---@field SetLabelFormatter fun(self: SettingsSliderOptions, labelType: integer, formatter: fun(value: number): string)

--- The slider's label types (Blizzard_SharedXML/Shared/Slider/MinimalSlider.lua).
MinimalSliderWithSteppersMixin = {}
---@type { Left: integer, Right: integer, Top: integer, Min: integer, Max: integer }
MinimalSliderWithSteppersMixin.Label = {}

---@class SettingsControlTextContainer
---@field Add fun(self: SettingsControlTextContainer, value: any, label: string, tooltip?: string): table
---@field GetData fun(self: SettingsControlTextContainer): table[]

Settings = {}

---@type { Boolean: "boolean", String: "string", Number: "number" }
Settings.VarType = {}

---@param name string
---@return SettingsCategory category
---@return SettingsLayout layout
function Settings.RegisterVerticalLayoutCategory(name) end

---@param parentCategory SettingsCategory
---@param name string
---@return SettingsCategory category
---@return SettingsLayout layout
function Settings.RegisterVerticalLayoutSubcategory(parentCategory, name) end

---@param category SettingsCategory
function Settings.RegisterAddOnCategory(category) end

---@param categoryID any
---@param scrollToElementName? string
function Settings.OpenToCategory(categoryID, scrollToElementName) end

---@param category SettingsCategory
---@param variable string
---@param variableType string
---@param name string
---@param defaultValue any
---@param getValue fun(): any
---@param setValue fun(value: any)
---@return SettingsProxySetting
function Settings.RegisterProxySetting(category, variable, variableType, name, defaultValue, getValue, setValue) end

---@param minValue number
---@param maxValue number
---@param rate number
---@return SettingsSliderOptions
function Settings.CreateSliderOptions(minValue, maxValue, rate) end

---@return SettingsControlTextContainer
function Settings.CreateControlTextContainer() end

---@param frameTemplate string
---@param data table?
---@return SettingsInitializer
function Settings.CreateElementInitializer(frameTemplate, data) end

-- From 1.5.3 (SET-R7), Pagle builds its native rows on templates of its own (adapter/SettingsControls.lua) through
-- the creators that take a template, and Blizzard's creators that name their own template (Settings.CreateCheckbox,
-- CreateSlider, CreateDropdown, CreateSettingsListSectionHeaderInitializer, CreateSettingsButtonInitializer,
-- CreateSettingsCheckboxSliderInitializer) aren't declared. Source: wow-ui-source branch forever, 1.60.1 (70862).

--- CreateSettingInitializerData's data ({ setting, name, options, tooltip }) on `frameTemplate`, tagged for search with
--- the setting's name; not added to a layout.
---@param frameTemplate string
---@param setting SettingsProxySetting
---@param options any
---@param tooltip? string
---@return SettingsInitializer
function Settings.CreateControlInitializer(frameTemplate, setting, options, tooltip) end

--- A setting row's initializer on `frameTemplate`, tagged for search with `data.setting`'s name when it has one.
---@param frameTemplate string
---@param data table
---@return SettingsInitializer
function Settings.CreateSettingInitializer(frameTemplate, data) end

--- The function that inserts a dropdown's options into its root menu description, as a highlight radio each.
---@param setting SettingsProxySetting
---@param optionsFunc fun(): table[]
---@param initializer SettingsInitializer
---@return fun(setting: SettingsProxySetting, rootDescription: table)
function Settings.CreateDropdownOptionInserter(setting, optionsFunc, initializer) end

--- Sets up a dropdown button's menu (its generator calls `elementInserter`), tooltip and enter and leave scripts.
---@param dropdown table
---@param setting SettingsProxySetting
---@param elementInserter fun(setting: SettingsProxySetting, rootDescription: table)
---@param initTooltip fun()
---@param initializer SettingsInitializer
function Settings.InitDropdown(dropdown, setting, elementInserter, initTooltip, initializer) end

--- The Settings panel (Blizzard_SettingsPanel.xml).
---@type Frame
SettingsPanel = {}
