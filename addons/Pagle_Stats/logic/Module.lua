if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

-- What Stats registers with Core (STA-R4): pure logic, everything passed in (CORE-R7).

--- Stats' def for `Pagle.RegisterModule` (STA-R4): its one view, the Stats book, and `/pagle stats`, both toggling
--- the book (any text after the command is ignored, STA-R70). No menu entry or `settingsAction`, so its status
--- button is "Open Stats" (CORE-R44, SET-R11) and its compartment entry "Stats" (CORE-R50).
---@param toggleBook fun() opens or closes the Stats book
---@return PagleModuleDef
function ns.ModuleDef(toggleBook)
	return {
		name = "Stats",
		title = ns.L.TITLE,
		order = 30,
		-- Stats' line on the Field guide's What's in the box (ONB-R91); Stats has no guide step.
		guideBlurb = ns.L.GUIDE_BLURB,
		views = { { id = "book", label = ns.L.BOOK, open = toggleBook } },
		slash = {
			{
				name = "stats",
				fn = function()
					toggleBook()
				end,
				help = ns.L.BOOK_SLASH_HELP,
			},
		},
	}
end
