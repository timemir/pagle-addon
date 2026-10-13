---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- /pagle (CORE-R60–R62). Core owns the command; Modules add subcommands with `def.slash`. Its own owner on Core's bus.
local OWNER = "Pagle slash"

local commands = ns.NewSlashCommands()

-- Every enabled Module has registered: each one's subcommands are added, by def.order, so of two that collide the
-- one with the lower order keeps the name. Each skipped entry is reported (CORE-R62).
Pagle.RegisterCallback(OWNER, "ModulesChanged", function()
	for _, module in ipairs(ns.Modules:Modules()) do
		for _, problem in ipairs(commands:Add(module.def)) do
			geterrorhandler()(problem)
		end
	end
end)

-- Runs `/pagle <line>`: the Settings root (CORE-R33's line while restricted), a Module's subcommand, or the help list.
---@param line string what the player typed after /pagle
local function run(line)
	local action, command, args = commands:Resolve(line)
	if action == "settings" then
		Pagle.OpenSettings()
	elseif command then
		securecallfunction(command.fn, args)
	else
		for _, helpLine in ipairs(commands:HelpLines()) do
			print(helpLine)
		end
	end
end

SLASH_PAGLE1 = "/pagle"
SlashCmdList.PAGLE = run
