if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleStatsNS
local ns = select(2, ...)

--- Core's text helper, `Pagle.Text` (CORE-R8): a string of ns.L with its named `{fields}` filled, a counted string by the
--- plural form `fields.count` picks in the chosen language. Every use of ns.L as a template goes through it. `Pagle` is
--- read at each call, so that logic/ holds no Core (CORE-R7) and the fold, which builds no text, never reaches it.
---@param source string|table<string, string> a string of ns.L, or a counted one
---@param fields table<string, any>?
---@return string
function ns.Text(source, fields)
	local pagle = Pagle -- luacheck: read globals Pagle (CORE-R8: the one read of Core in logic/ besides the guard)
	return pagle.Text(source, fields)
end

--- Core's search fold, `Pagle.FoldCase` (CORE-R8): `text` in lower case without the accents of Latin letters, so that a
--- plain query finds an accented name. Both the query and the name go through it; it is for matching, never for drawing.
---@param text string
---@return string
function ns.FoldCase(text)
	local pagle = Pagle -- luacheck: read globals Pagle (CORE-R8: the one read of Core in logic/ besides the guard)
	return pagle.FoldCase(text)
end

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
