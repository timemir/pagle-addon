---@meta _
-- Blizzard's native Settings API, as far as Core uses it (CORE-R40), which Ketho's vscode-wow-api annotations
-- (WOW_API_COMMIT, scripts/tools.env) lack. Declarations for the types stage only: never loaded by the game, and
-- excluded from luacheck. Source: Gethe/wow-ui-source branch forever at 943764493e6b16d63ded3ab304150d1f05e58b57
-- ("1.60.1 (70338)"), Interface/AddOns/Blizzard_Settings_Shared/ (Blizzard_Settings.lua, Blizzard_SettingControls.lua,
-- Blizzard_Keybindings.lua, Blizzard_SettingsLayouts.lua).

---@class SettingsCategory
---@field GetID fun(self: SettingsCategory): any
---@field GetName fun(self: SettingsCategory): string

---@class SettingsLayout
---@field AddInitializer fun(self: SettingsLayout, initializer: SettingsInitializer): SettingsInitializer

--- A list frame from the panel's pool. Templates based on SettingsListElementTemplate have the row's label in Text.
---@class SettingsListElementFrame : Frame
---@field Text FontString?

--- SettingsListElementInitializer: one row of a vertical layout.
---@class SettingsInitializer
---@field data table
---@field GetData fun(self: SettingsInitializer): table
---@field GetName fun(self: SettingsInitializer): string?
---@field GetSetting fun(self: SettingsInitializer): SettingsProxySetting?
---@field SetParentInitializer fun(self: SettingsInitializer, parent: SettingsInitializer, modifyPredicate?: fun(): boolean)
---@field AddModifyPredicate fun(self: SettingsInitializer, predicate: fun(): boolean)
---@field AddSearchTags fun(self: SettingsInitializer, ...: string)
--- A setting variable (despite the name, any registered setting's) whose change re-evaluates the shown row's state.
---@field AddEvaluateStateCVar fun(self: SettingsInitializer, variable: string)
---@field InitFrame fun(self: SettingsInitializer, frame: SettingsListElementFrame)
---@field Resetter fun(self: SettingsInitializer, frame: SettingsListElementFrame)
---@field GetExtent fun(self: SettingsInitializer): number?

---@class SettingsProxySetting
---@field GetName fun(self: SettingsProxySetting): string
---@field GetVariable fun(self: SettingsProxySetting): string
---@field GetValue fun(self: SettingsProxySetting): any
---@field SetValue fun(self: SettingsProxySetting, value: any)

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

---@param category SettingsCategory
---@param setting SettingsProxySetting
---@param tooltip? string
---@return SettingsInitializer
function Settings.CreateCheckbox(category, setting, tooltip) end

---@param minValue number
---@param maxValue number
---@param rate number
---@return SettingsSliderOptions
function Settings.CreateSliderOptions(minValue, maxValue, rate) end

---@param category SettingsCategory
---@param setting SettingsProxySetting
---@param options SettingsSliderOptions
---@param tooltip? string
---@return SettingsInitializer
function Settings.CreateSlider(category, setting, options, tooltip) end

---@param category SettingsCategory
---@param setting SettingsProxySetting
---@param options fun(): table[]
---@param tooltip? string
---@return SettingsInitializer
function Settings.CreateDropdown(category, setting, options, tooltip) end

---@return SettingsControlTextContainer
function Settings.CreateControlTextContainer() end

---@param frameTemplate string
---@param data table?
---@return SettingsInitializer
function Settings.CreateElementInitializer(frameTemplate, data) end

---@param name string
---@param tooltip? string
---@return SettingsInitializer
function CreateSettingsListSectionHeaderInitializer(name, tooltip) end

---@param name string
---@param buttonText string|fun(): string a function is called each time the row is shown
--- (Blizzard_SettingControls.lua, SettingsButtonControlMixin:EvaluateName)
---@param buttonClick fun()
---@param tooltip string?
---@param addSearchTags boolean
---@return SettingsInitializer
function CreateSettingsButtonInitializer(name, buttonText, buttonClick, tooltip, addSearchTags) end

---@param bindingIndex number
---@param search boolean?
---@return SettingsInitializer
function CreateKeybindingEntryInitializer(bindingIndex, search) end

--- The Settings panel (Blizzard_SettingsPanel.xml).
---@type Frame
SettingsPanel = {}
