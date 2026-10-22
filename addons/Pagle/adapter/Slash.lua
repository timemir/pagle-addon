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
	local name, rest = ns.ParseSlash(line)
	if name == "trailer" then
		ns.RunTrailer(rest)
		return
	end
	commands:Run(line, ns.coreSubcommands, securecallfunction, print)
end

--- `/pagle dev …` (#247): hidden dev commands, as ns.dev (logic/Wiring.lua). `/pagle dev tour` (CORE-R66) shoots each
--- stop with Screenshot(), which the client saves to its Screenshots folder, named by the local time.
ns.WireDev(
	ns.host,
	function(announcement)
		ns.lanes:Push(announcement)
	end,
	ns.ShowGlyphProbe,
	{
		isRestricted = function()
			return Pagle.IsRestricted()
		end,
		canScreenshot = function()
			return Screenshot ~= nil
		end,
		screenshot = function()
			Screenshot()
		end,
		clock = function()
			return date("%H:%M:%S") --[[@as string]]
		end,
	},
	-- `/pagle dev probe` (#261) looks up every API it tests by name, so only what Pagle uses is inventoried.
	function()
		return _G
	end
)

SLASH_PAGLE1 = "/pagle"
SlashCmdList.PAGLE = run
