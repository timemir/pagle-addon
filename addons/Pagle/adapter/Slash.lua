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

--- Core's own subcommands (CORE-R61), for /pagle and the compartment menu (adapter/Menu.lua).
ns.coreSubcommands = ns.CoreSubcommands(Pagle)

-- Runs `/pagle <line>`: the Settings root, the Curio Shop, the Field report box, a Module's subcommand, or the help
-- list.
---@param line string what the player typed after /pagle
local function run(line)
	commands:Run(line, ns.coreSubcommands, securecallfunction, print)
end

--- `/pagle dev …` (#247): hidden dev commands, as ns.dev (logic/Wiring.lua).
ns.WireDev(ns.host, function(announcement)
	ns.lanes:Push(announcement)
end, ns.ShowGlyphProbe)

SLASH_PAGLE1 = "/pagle"
SlashCmdList.PAGLE = run
