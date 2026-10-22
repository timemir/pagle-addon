if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- What Hunts registers with Core (HNT-R135): pure logic, everything passed in (CORE-R7).

--- Hunts' def for `Pagle.RegisterModule` (HNT-R135): its one view, the Hunts board, and `/pagle hunts`, both
--- toggling the board (any text after the command is ignored). No menu entry or `settingsAction`, so its status
--- button is "Open Hunts" (CORE-R44, SET-R11).
---@param toggleBoard fun() opens or closes the Hunts board
---@return PagleModuleDef
function ns.ModuleDef(toggleBoard)
	return {
		name = "Hunts",
		title = ns.L.TITLE,
		order = 20,
		-- Hunts' line on the Field guide's What's in the box (ONB-R91); Hunts has no guide step.
		guideBlurb = ns.L.GUIDE_BLURB,
		views = { { id = "board", label = ns.L.BOARD, open = toggleBoard } },
		slash = {
			{
				name = "hunts",
				fn = function()
					toggleBoard()
				end,
				help = ns.L.BOARD_SLASH_HELP,
			},
		},
	}
end
