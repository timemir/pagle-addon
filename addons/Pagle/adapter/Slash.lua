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

-- Every enabled Module has registered: each one's subcommands are added, by def.order (CORE-R62).
Pagle.RegisterCallback(OWNER, "ModulesChanged", function()
	commands:AddModules(ns.Modules:Modules(), function(problem)
		geterrorhandler()(problem)
	end)
end)

-- Runs `/pagle <line>`: the Settings root (CORE-R33's line while restricted), a Module's subcommand, or the help list.
---@param line string what the player typed after /pagle
local function run(line)
	commands:Run(line, function()
		Pagle.OpenSettings()
	end, securecallfunction, print)
end

SLASH_PAGLE1 = "/pagle"
SlashCmdList.PAGLE = run
