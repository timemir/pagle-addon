if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- The board's First look and its "?" (ONB-R55–R59; board 15, the kit's World.lua): five numbered Margin notes beside
-- the board, Core's frames and Core's coach bar (ONB-R92). The set is registered at OnInitialize, its window the
-- board's frame once made, so it joins Off you go's list and the tour (which opens the board as the Angler does); it is
-- shown as the board opens on a started board that isn't updating, after the draw, so each note has its part of the
-- board to point at (a note whose target isn't shown drops, ONB-R56). Core shows a set once (looksSeen) and only with
-- Margin notes on. The "?" beside the close mark is the board's own: a brass pin with its mark, showing the set again
-- with M:ShowFirstLook(id, true) whether or not it was seen and whether or not Margin notes is on, or hiding it while
-- it shows (ONB-R59). Every call is guarded: on a Core without First looks there is no set and no "?" (ONB-R90).

-- The "?": beside the close mark (26 × 26 at 958, 15), 4 to its left, and its pin's size.
local HELP_X, HELP_Y, HELP_SIZE, PIN_SIZE = 928, 15, 26, 22

---@class TackleBoardHelp: Button
---@field pin TackleSprite
---@field mark FontString

-- Whether the set is registered with Core, so the board asks for it and has a "?".
local registered = false

-- What each note points at on the board's frame, read as the set shows (ONB-R56): nil while it isn't laid out.
---@type table<string, fun(frame: TackleBoardFrame): Region?>
local TARGETS = {
	-- The first Expedition's kind badge, or its empty pin.
	expedition = function(frame)
		local pins = frame.parts.pins --[[@as TacklePinsFrame]]
		local slot = pins.slots.expeditions[1] --[[@as TacklePinSlot]]
		if slot.goal and slot.goal:IsShown() then
			return slot.goal.icon
		end
		return slot.empty
	end,
	-- The first Notice's "take it down", or the first Notice's paper when none can come down.
	notice = function(frame)
		local first
		local pins = frame.parts.pins --[[@as TacklePinsFrame]]
		for _, slot in ipairs(pins.slots.notices) do
			---@cast slot TacklePinSlot
			if slot.goal and slot.goal:IsShown() then
				if slot.goal.takeDown:IsShown() then
					return slot.goal.takeDown
				end
				first = first or slot.goal
			end
		end
		return first
	end,
	-- The Campfire's fire, in whatever stage it shows.
	campfire = function(frame)
		local ledge = frame.parts.ledge --[[@as TackleLedgeFrame]]
		local fire = ledge.fire
		return fire and (fire.burning.layers["-base"] or fire.burning.layers[""]) or nil
	end,
	-- The Fly Box's name on its box.
	flybox = function(frame)
		local ledge = frame.parts.ledge --[[@as TackleLedgeFrame]]
		return ledge.box and ledge.box.title or nil
	end,
	-- The shop card.
	coins = function(frame)
		local ledge = frame.parts.ledge --[[@as TackleLedgeFrame]]
		return ledge.shop
	end,
}

-- The set's notes for M:RegisterFirstLook (core/onboarding.md › Contracts, PagleFirstLook), each target read from the
-- board's frame when Core asks: nil before the board is made.
---@return { text: string, target: fun(): Region?, x: number, y: number, w: number }[]
local function lookNotes()
	local notes = {}
	for i, note in ipairs(ns.BoardLookNotes()) do
		local find = TARGETS[note.target]
		notes[i] = {
			text = note.text,
			x = note.x,
			y = note.y,
			w = note.w,
			target = function()
				local frame = ns.board.frame
				return frame and find(frame) or nil
			end,
		}
	end
	return notes
end

--- Registers the board's First look with Core (ONB-R56) at OnInitialize, so it joins Off you go's list and the tour:
--- its window is the board's frame once made, and the tour opens the board as the Angler would. Nothing on a Core
--- without First looks (ONB-R90).
---@param module PagleModuleHandle
function ns.RegisterBoardLook(module)
	if not (module.RegisterFirstLook and module.ShowFirstLook) then
		return
	end
	module:RegisterFirstLook({
		id = ns.BOARD_LOOK_ID,
		window = function()
			return ns.board.frame
		end,
		title = ns.L.LOOK_TITLE,
		notes = lookNotes(),
		open = function()
			ns.OpenBoard()
		end,
	})
	registered = true
end

-- The "?" (ONB-R59): a brass pin with its mark, the tooltip under the mouse, and the set again on a click (Core hides
-- it if it shows).
---@param frame TackleBoardFrame
---@return TackleBoardHelp
local function newHelp(frame)
	local help = CreateFrame("Button", nil, frame) --[[@as TackleBoardHelp]]
	help:SetSize(HELP_SIZE, HELP_SIZE)
	help:SetPoint("TOPLEFT", frame, "TOPLEFT", HELP_X, -HELP_Y)
	help:SetFrameLevel(frame:GetFrameLevel() + ns.BoardLayer("close"))
	help.pin = ns.ArtSprite(help, "Board", "tack", "ARTWORK")
	ns.SizeSprite(help.pin, PIN_SIZE)
	ns.CenterSprite(help.pin, help)
	help.mark = ns.ArtText(help, "HelpMark")
	help.mark:SetJustifyH("CENTER")
	help.mark:SetPoint("CENTER", 0, 0)
	help.mark:SetText(ns.L.LOOK_AGAIN_MARK)
	help:SetScript("OnClick", function()
		ns.Module:ShowFirstLook(ns.BOARD_LOOK_ID, true)
	end)
	help:SetScript("OnEnter", function(self)
		ns.BoardHover(self, { ns.L.LOOK_AGAIN })
	end)
	help:SetScript("OnLeave", ns.BoardHoverHide)
	help:Hide()
	return help
end

--- Gives the board's frame, as it is made (adapter/Board.lua), its "?" beside the close mark (ONB-R59), hidden until a
--- started board shows: only with the set registered.
---@param frame TackleBoardFrame
function ns.AddBoardLook(frame)
	if registered then
		frame.help = newHelp(frame)
	end
end

--- After each draw of the open board (adapter/Board.lua): the "?" shows while a started board shows that isn't
--- updating, as its notes have the board's parts to point at; and as the board opens, or is started, so drawn, its
--- First look shows (Core shows it once, ONB-R55).
---@param frame TackleBoardFrame
---@param reason string the draw's reason
function ns.BoardLookDrawn(frame, reason)
	local help = frame.help
	if not help then
		return
	end
	help:SetShown(frame.settled == true)
	if frame.settled and (reason == "open" or reason == "start") then
		ns.Module:ShowFirstLook(ns.BOARD_LOOK_ID)
	end
end
