if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleLedgerNS
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

--- Core's lower case, `Pagle.Lower` (CORE-R8): `text` in lower case, UTF-8 aware.
---@param text string
---@return string
function ns.Lower(text)
	local pagle = Pagle -- luacheck: read globals Pagle (CORE-R8: the one read of Core in logic/ besides the guard)
	return pagle.Lower(text)
end

-- What the Ledger registers with Core (LED-R1): pure logic, everything passed in (CORE-R7).

--- The Ledger's def for `Pagle.RegisterModule` (LED-R1): its one view, the Fish Journal, and `/pagle journal`, both
--- toggling the Journal (any text after the command is ignored), `/pagle collection`, which opens the Collection, the
--- `collection` call that opens it on a look (LED-R166, LED-R174, CORE-R45), and its line on the Field guide's What's in
--- the box step (ONB-R91). No menu entry, `settingsAction` or settings rows, so its status button is "Open Fish Journal"
--- (CORE-R44, SET-R11).
---@param toggleJournal fun() opens or closes the Fish Journal
---@param openCollection fun(goodID: string?) opens the Fish Journal on a look's shelf with it chosen, or on the Collection
---@return PagleModuleDef
function ns.ModuleDef(toggleJournal, openCollection)
	return {
		name = "Ledger",
		title = ns.L.TITLE,
		order = 10,
		guideBlurb = ns.L.GUIDE_BLURB,
		views = { { id = "journal", label = ns.L.JOURNAL, open = toggleJournal } },
		slash = {
			{
				name = "journal",
				fn = function()
					toggleJournal()
				end,
				help = ns.L.JOURNAL_SLASH_HELP,
			},
			{
				name = "collection",
				fn = function()
					openCollection()
				end,
				help = ns.L.COLLECTION_SLASH_HELP,
			},
		},
		collection = function(goodID)
			openCollection(goodID)
		end,
	}
end
