if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleTackleBoardNS
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

-- What the Tackle Board registers with Core (TKB-R1, tackle-board.md › Contracts): pure logic (CORE-R7). Every entry
-- point reaches the seams through ns at call time (logic/Seams.lua), so the tickets that fill them never touch this.

--- The Tackle Board's def for `Pagle.RegisterModule` (TKB-R1): its one view and `/pagle board`, both toggling the
--- board (any text after the command is ignored), and its Settings status button (CORE-R44, SET-R11), "Start my
--- board" until the board is started, then "Open Tackle Board", read afresh at each showing (SET-R12). Its compartment
--- entry is the view, "Tackle Board" (CORE-R50), and its line on the Field guide's What's in the box step is its
--- guideBlurb (ONB-R91). Nothing in it stops or resets a started board (TKB-R3).
---@return PagleModuleDef
function ns.ModuleDef()
	local function toggleBoard()
		ns.ToggleBoard()
	end
	return {
		name = "TackleBoard",
		title = ns.L.TITLE,
		order = 40,
		guideBlurb = ns.L.GUIDE_BLURB,
		settingsAction = {
			label = function()
				return ns.KnownStarted() and ns.L.OPEN_BOARD or ns.L.START_MY_BOARD
			end,
			-- "Start my board" also starts the board (TKB-R5), unless the projection is updating; either one opens it.
			onClick = function()
				if not ns.IsStarted() and not ns.IsUpdating() then
					ns.Start()
				end
				ns.OpenBoard()
			end,
		},
		views = { { id = "board", label = ns.L.BOARD, open = toggleBoard } },
		slash = { { name = "board", fn = toggleBoard, help = ns.L.BOARD_SLASH_HELP } },
	}
end
