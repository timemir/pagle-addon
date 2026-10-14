---@class PagleNS
local ns = select(2, ...)

-- /pagle as data (CORE-R60–R62): which subcommand a line names, the Modules' subcommands and the help list. Pure
-- logic, everything passed in (CORE-R7); adapter/Slash.lua registers the command and acts on what this resolves.

--- Core's own subcommands, reserved for it (CORE-R61).
ns.SLASH_RESERVED = { "help", "settings", "shop", "report" }

--- Splits what follows `/pagle` into its subcommand, lowercased, and the rest of the line, trimmed (CORE-R62).
---@param line string
---@return string name "" when the line is blank
---@return string args
function ns.ParseSlash(line)
	local name, args = line:match("^%s*(%S*)%s*(.-)%s*$")
	return name:lower(), args
end

--- A Module's subcommand (CORE-R62).
---@class PagleSlashCommand
---@field name string   as the Module wrote it
---@field fn fun(args: string)
---@field help string

--- The Modules' subcommands, by lowercased name, and in the order they were added.
---@class PagleSlashCommands
---@field private reserved table<string, true>
---@field private owners table<string, string>   the def.name that added each name, by lowercased name
---@field private byName table<string, PagleSlashCommand>
---@field private list PagleSlashCommand[]
local Commands = {}
Commands.__index = Commands

---@return PagleSlashCommands
function ns.NewSlashCommands()
	local reserved = {}
	for _, name in ipairs(ns.SLASH_RESERVED) do
		reserved[name] = true
	end
	return setmetatable({ reserved = reserved, owners = {}, byName = {}, list = {} }, Commands)
end

-- Why a Module's slash entry can't be added, or nil if it can (CORE-R62).
---@private
---@param module string def.name
---@param entry any
---@return string?
function Commands:Problem(module, entry)
	local L = ns.L
	local name = type(entry) == "table" and entry.name
	if type(name) ~= "string" or not name:match("^%S+$") then
		return L.SLASH_SKIPPED_NO_NAME:format(module, tostring(name))
	elseif type(entry.fn) ~= "function" then
		return L.SLASH_SKIPPED_NO_FN:format(module, name)
	end
	local key = name:lower()
	if self.reserved[key] then
		return L.SLASH_SKIPPED_RESERVED:format(module, name, key)
	elseif self.owners[key] then
		return L.SLASH_SKIPPED_TAKEN:format(module, name, self.owners[key])
	end
	return nil
end

--- Adds a Module's `def.slash` entries (CORE-R62). An entry whose name collides with a reserved one or one added
--- before, case-insensitively, is skipped; the rest are added. Returns why, for each entry skipped.
---@param def PagleModuleDef
---@return string[] problems
function Commands:Add(def)
	local problems = {}
	for _, entry in ipairs(def.slash or {}) do
		local problem = self:Problem(def.name, entry)
		if problem then
			problems[#problems + 1] = problem
		else
			local key = entry.name:lower()
			local help = type(entry.help) == "string" and entry.help or ""
			local command = { name = entry.name, fn = entry.fn, help = help }
			self.owners[key] = def.name
			self.byName[key] = command
			self.list[#self.list + 1] = command
		end
	end
	return problems
end

--- What `/pagle <line>` does (CORE-R60–R62): `"settings"` with no argument or `settings`; `"report"` with `report`
--- (the Field report); `"module"` with the Module subcommand it names and the rest of the line, trimmed; otherwise
--- `"help"`. That covers `help`, an unknown name, and `shop` until the Curio Shop exists (M4).
---@param line string what follows /pagle
---@return "settings"|"report"|"module"|"help" action
---@return PagleSlashCommand? command
---@return string? args
function Commands:Resolve(line)
	local name, args = ns.ParseSlash(line)
	if name == "" or name == "settings" then
		return "settings"
	elseif name == "report" then
		return "report"
	end
	local command = self.byName[name]
	if command then
		return "module", command, args
	end
	return "help"
end

--- The help list (CORE-R60): its header, Core's commands, then each Module subcommand in the order added.
---@return string[]
function Commands:HelpLines()
	local L = ns.L
	local lines = { L.SLASH_HELP_HEADER }
	for _, core in ipairs(L.SLASH_CORE_HELP) do
		lines[#lines + 1] = L.SLASH_HELP_LINE:format(core.name, core.help)
	end
	for _, command in ipairs(self.list) do
		lines[#lines + 1] = L.SLASH_HELP_LINE:format(command.name, command.help)
	end
	return lines
end

--- Adds every registered Module's subcommands at `ModulesChanged`, by def.order, so of two that collide the one
--- with the lower order keeps the name; each entry skipped goes to `report` (CORE-R62).
---@param modules PagleModule[] by def.order, as `registry:Modules()` lists them
---@param report fun(problem: string) reports an error and carries on (geterrorhandler())
function Commands:AddModules(modules, report)
	for _, module in ipairs(modules) do
		for _, problem in ipairs(self:Add(module.def)) do
			report(problem)
		end
	end
end

--- What Core's own subcommands do (CORE-R61). Each prints its surface's chat line instead while restricted (CORE-R33).
---@class PagleSlashCore
---@field settings fun() opens the Settings root (Pagle.OpenSettings)
---@field report fun() opens the Field report box (Pagle.OpenFieldReport)

--- Runs `/pagle <line>` (CORE-R60–R62): one of Core's own subcommands, a Module's subcommand through `call`, or the
--- help list.
---@param line string what follows /pagle
---@param core PagleSlashCore
---@param call fun(fn: function, ...: any) calls a Module's function; an error is reported, not raised (securecallfunction)
---@param print fun(line: string) prints a chat line
function Commands:Run(line, core, call, print)
	local action, command, args = self:Resolve(line)
	if action == "settings" or action == "report" then
		core[action]()
	elseif command then
		call(command.fn, args)
	else
		for _, helpLine in ipairs(self:HelpLines()) do
			print(helpLine)
		end
	end
end
