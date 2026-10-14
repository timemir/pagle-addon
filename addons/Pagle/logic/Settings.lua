---@class PagleNS
local ns = select(2, ...)

-- Core's Settings tree as data (CORE-R40–R44, settings.md): which rows each topic page gets from `M:AddSetting`, and
-- each status-list button. Pure logic, everything passed in (CORE-R7); adapter/Settings.lua makes native rows of it.

--- The topics a Module adds rows to, in page order (CORE-R40, CORE-R42).
ns.SETTINGS_TOPICS = { "fishing", "announcements", "trackers" }

--- One row a Module adds to a topic page (core/README.md › Contracts, CORE-R42).
---@class PagleSetting
---@field kind "header"|"checkbox"|"slider"|"dropdown"|"button"|"keybinding"|"custom"|"slot"   -- "slot": Core's slot dropdown (SET-R44), never a Module's
---@field id? string               -- needed if another row names it as parent; unique among this Module's rows on this page
---@field label string
---@field tooltip? string
---@field get? fun(): any          -- value kinds: checkbox, slider, dropdown
---@field set? fun(value: any)
---@field default? any             -- what the page's Defaults button restores
---@field min? number              -- slider
---@field max? number
---@field step? number
---@field options? fun(): { value: any, label: string }[]   -- dropdown
---@field onClick? fun()           -- button
---@field binding? string          -- keybinding: the Bindings.xml name, also listed in Key Bindings › AddOns
---@field parent? string           -- id of the row it hangs under (indented), a row of the same Module on the same page
---@field isEnabled? fun(): boolean  -- greyed out when false
---@field init? fun(): table       -- custom: returns a Settings initializer (e.g. Stats' watched Dry spells)

-- What each kind needs besides its label, as field = Lua type (CORE-R42's PagleSetting).
local KINDS = {
	header = {},
	checkbox = { get = "function", set = "function" },
	slider = { get = "function", set = "function", min = "number", max = "number", step = "number" },
	dropdown = { get = "function", set = "function", options = "function" },
	button = { onClick = "function" },
	keybinding = { binding = "string" },
	custom = { init = "function" },
}

--- A row on a topic page, in page order: a Module's row, the header Core puts before a Module's rows, or a slot
--- dropdown Core ends a Module's section with.
---@class PagleSettingsEntry
---@field module PagleModule
---@field setting PagleSetting   for Core's header, `{ kind = "header", label = def.title }`; for a slot dropdown,
--- `{ kind = "slot", label = slot.label }`
---@field parent PagleSettingsEntry?   the row it hangs under (indented)
---@field slot PagleRegisteredSlot?   the slot whose dropdown (SET-R51) this row is, never indented (SET-R44)

---@class PagleSettingsSection
---@field list PagleSetting[]
---@field ids table<string, true>

--- The rows Modules add with `M:AddSetting`, until `ModulesChanged` closes it (CORE-R42).
---@class PagleSettingsRows
---@field private closed boolean
---@field private sections table<string, table<string, PagleSettingsSection>>   by Module name, then topic
local Rows = {}
Rows.__index = Rows

---@return PagleSettingsRows
function ns.NewSettingsRows()
	return setmetatable({ closed = false, sections = {} }, Rows)
end

---@param topic any
---@return boolean
local function isTopic(topic)
	for _, known in ipairs(ns.SETTINGS_TOPICS) do
		if topic == known then
			return true
		end
	end
	return false
end

-- Why a row can't be added to a section, or nil if it can (CORE-R42).
---@param section PagleSettingsSection?
---@param topic any
---@param setting any
---@return string?
local function problem(section, topic, setting)
	if not isTopic(topic) then
		return ("unknown topic %s; the topics are %s"):format(tostring(topic), table.concat(ns.SETTINGS_TOPICS, ", "))
	end
	if type(setting) ~= "table" then
		return "takes a setting table, got " .. type(setting)
	end
	local needs = KINDS[setting.kind]
	if not needs then
		return ("unknown kind %s"):format(tostring(setting.kind))
	end
	if type(setting.label) ~= "string" then
		return "a setting needs a label"
	end
	for field, luaType in pairs(needs) do
		if type(setting[field]) ~= luaType then
			return ("a %s setting needs %s, a %s"):format(setting.kind, field, luaType)
		end
	end
	if setting.id ~= nil and section and section.ids[setting.id] then
		return ("id %s is already used on %s"):format(tostring(setting.id), topic)
	end
	if setting.parent ~= nil and not (section and section.ids[setting.parent]) then
		return ("parent %s names none of this Module's earlier rows on %s"):format(tostring(setting.parent), topic)
	end
	return nil
end

--- Adds a Module's row to a topic page (CORE-R42). Returns why it can't, or nil. `late` is true when the call came
--- after `ModulesChanged`: the caller reports it through `geterrorhandler()` and drops it; any other problem the
--- caller raises.
---@param name string the Module's def.name
---@param topic any
---@param setting any
---@return string? problem
---@return boolean? late
function Rows:Add(name, topic, setting)
	if self.closed then
		return ns.L.SETTING_TOO_LATE:format(name), true
	end
	self.sections[name] = self.sections[name] or {}
	local section = self.sections[name][topic]
	local why = problem(section, topic, setting)
	if why then
		return ("%s's AddSetting: %s"):format(name, why)
	end
	if not section then
		section = { list = {}, ids = {} }
		self.sections[name][topic] = section
	end
	section.list[#section.list + 1] = setting
	if setting.id ~= nil then
		section.ids[setting.id] = true
	end
	return nil
end

--- Closes the rows at `ModulesChanged`: Core builds the pages from them, and a later call is late (CORE-R42).
function Rows:Close()
	self.closed = true
end

--- A topic page's Module rows, in page order (CORE-R42, SET-R3, SET-R44): each Module's in `modules` order, after a
--- header with its title unless its first row is a header, then the slot dropdowns `slots` gives it
--- (ns.SectionSlots), unindented. A Module with slots there but no rows gets its header and its slots. Empty when the
--- page has no rows, so it isn't registered.
---@param topic string
---@param modules PagleModule[] the On Modules, by def.order
---@param slots table<string, PagleRegisteredSlot[]>? the slots ending each Module's section, by Module name
---@return PagleSettingsEntry[]
function Rows:Page(topic, modules, slots)
	local entries = {}
	for _, module in ipairs(modules) do
		local name = module.def.name
		local section = self.sections[name] and self.sections[name][topic]
		local list = section and section.list or {}
		---@type PagleRegisteredSlot[]
		local ending = slots and slots[name] or {}
		if #list + #ending > 0 then
			if not (list[1] and list[1].kind == "header") then
				entries[#entries + 1] = { module = module, setting = { kind = "header", label = module.def.title } }
			end
			local byId = {}
			for _, setting in ipairs(list) do
				local entry = { module = module, setting = setting, parent = setting.parent and byId[setting.parent] }
				entries[#entries + 1] = entry
				if setting.id ~= nil then
					byId[setting.id] = entry
				end
			end
			for _, slot in ipairs(ending) do
				entries[#entries + 1] =
					{ module = module, setting = { kind = "slot", label = slot.label }, slot = slot }
			end
		end
	end
	return entries
end

--- Whether Core registers a topic page (SET-R1, CORE-R42): while Modules gave it rows, or while Core has rows of its
--- own there, except on Trackers, whose Core row never registers the page alone (SET-R40).
---@param topic string
---@param hasCoreRows boolean
---@param moduleRows integer how many rows Modules added to it
---@return boolean
function ns.IsPageRegistered(topic, hasCoreRows, moduleRows)
	return moduleRows > 0 or (hasCoreRows and topic ~= "trackers")
end

--- `M:AddSetting` over `registry` and `rows`, so Core's adapter and FakePagle install one method (CORE-R42). It adds
--- a row to a topic page: `"fishing"`, `"announcements"` or `"trackers"`. Call it before `ModulesChanged`, in
--- OnInitialize; Core builds the pages then, each Module's rows in `def.order` under a header with its title, left
--- out when the first row is a header. It raises an error for an unknown topic or kind, an id this Module already
--- used on the page, or a `parent` naming none of its earlier rows there. A call after `ModulesChanged` goes to
--- `report` and is dropped.
---@param registry PagleModuleRegistry
---@param rows PagleSettingsRows
---@param report fun(problem: string) reports an error and carries on (geterrorhandler())
---@return fun(self: PagleModuleHandle, topic: "fishing"|"announcements"|"trackers", setting: PagleSetting)
function ns.AddSettingMethod(registry, rows, report)
	return function(self, topic, setting)
		local module = registry:ModuleCalling(self, "AddSetting", "topic, setting")
		local why, late = rows:Add(module.def.name, topic, setting)
		if why and late then
			report(why)
		elseif why then
			error(why, 2)
		end
	end
end

--- An On Module's status-list button (CORE-R44, SET-R12), its label read now.
---@class PagleStatusButton
---@field label string
---@field onClick fun()
---@field closesPanel boolean   a Module with a view closes the panel first, since the view would open behind it

--- An On Module's button: its `def.settingsAction`, otherwise "Open {label}" for its first view; nil with neither,
--- or when its label can't be read (`ns.ReadLabel`), so a failing label costs the button and not the Module's line.
---@param def PagleModuleDef
---@param call fun(fn: function): any calls a function label; returns nil when it fails (securecallfunction)
---@return PagleStatusButton?
function ns.StatusButton(def, call)
	local view = def.views and def.views[1]
	local action = def.settingsAction
	if action then
		local label = ns.ReadLabel(action.label, call)
		return label and { label = label, onClick = action.onClick, closesPanel = view ~= nil }
	elseif view then
		local label = ns.ReadLabel(view.label, call)
		return label and { label = ns.L.OPEN_VIEW:format(label), onClick = view.open, closesPanel = true }
	end
	return nil
end
