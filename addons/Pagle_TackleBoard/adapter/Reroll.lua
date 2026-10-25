if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- "Take it down" and "Post" on the client (TKB-R55, TKB-R56, TKB-R58, TKB-R59): ns.CanTakeDown and ns.TakeDown, ns.CanPost
-- and ns.Post (logic/Seams.lua; adapter/Pins.lua shows the button and the empty pins' click and calls them), the confirm
-- and the `reroll` and `post` records, which only this file and adapter/LiveStep.lua's live step append (TKB-R80). The
-- rules are logic/Reroll.lua's. The confirm is the board art kit's (PagleArtBoard's Overlays.lua, P.Confirm): a paper
-- pinned over the screen's middle with the question, what is lost or spent (in red), a leather "Take it down" or "Post
-- it" and a pencilled "Keep it". One paper serves both: whichever opens it sets its words and what "yes" does. It is a
-- plain frame, not secure, so it works in combat (TKB-R193), and Esc keeps the goal and the Refresh (UISpecialFrames).

-- The confirm's global name, for UISpecialFrames, and the board's (adapter/Board.lua's FRAME_NAME); its paper,
-- 360 × 166, leaning a little; its red ink.
local CONFIRM_NAME, BOARD_NAME = "PagleTackleBoardConfirm", "PagleTackleBoard"
local CONFIRM_WIDTH, CONFIRM_HEIGHT, CONFIRM_LEAN, RED = 360, 166, -0.8, "9A2A1A"

---@class TackleConfirmKeep: Button
---@field label FontString

---@class TackleConfirmFrame: Frame
---@field paper TackleSprite
---@field title FontString
---@field text FontString
---@field accept TackleButtonView
---@field keep TackleConfirmKeep
---@field onAccept fun()?          -- what "yes" does for the question it is open on

---@type TackleConfirmFrame?
local confirm
-- Whether the confirm holds the board's place in UISpecialFrames now, and whether it was ever listed on its own.
local holdsBoardEsc, listedAlone = false, false

-- Renames the first `from` in UISpecialFrames to `to`; whether one was there.
---@param from string
---@param to string
---@return boolean
local function renameSpecial(from, to)
	for index, name in ipairs(UISpecialFrames) do
		if name == from then
			UISpecialFrames[index] = to -- luacheck: ignore 122 (the client's own table, renamed in place)
			return true
		end
	end
	return false
end

-- One Esc closes the confirm and leaves the board open (TKB-R56): CloseSpecialWindows hides every shown frame
-- UISpecialFrames lists, so while it shows, the confirm takes the board's place there, and gives it back as it hides.
-- The place is renamed, never added or removed, since the client walks the table with pairs, and the confirm's OnHide
-- runs during that walk (Lua allows a walk's existing fields to change). With no board listed, the confirm is listed
-- on its own, once. Renaming the client's table is no secure call, so it works in combat (TKB-R193).
local function takeBoardEsc()
	holdsBoardEsc = renameSpecial(BOARD_NAME, CONFIRM_NAME)
	if not holdsBoardEsc and not listedAlone then
		table.insert(UISpecialFrames, CONFIRM_NAME)
		listedAlone = true
	end
end

local function giveBoardEsc()
	if holdsBoardEsc then
		renameSpecial(CONFIRM_NAME, BOARD_NAME)
		holdsBoardEsc = false
	end
end

--- The goal `goalID` names if it can be taken down now (TKB-R55, TKB-R108): one ns.CanTakeDown allows, while the
--- projection isn't updating.
---@param goalID string
---@return TackleGoal?
local function takeable(goalID)
	if ns.IsUpdating() then
		return nil
	end
	return ns.TakeDownGoal(ns.State(), goalID, ns.api.pagle)
end

--- Whether a goal's "take it down" shows (TKB-R55): an open goal from an `issue` record, or a stranded re-posted
--- one. It doesn't read ns.IsUpdating(): the pins grey the button while the projection is updating (TKB-R108), and
--- ns.TakeDown refuses then.
---@param goalID string the entry ID of the record that issued it (TKB-R23)
---@return boolean
function ns.CanTakeDown(goalID)
	return ns.TakeDownGoal(ns.State(), goalID, ns.api.pagle) ~= nil
end

-- Takes the goal `goalID` names down if it can still be (TKB-R55: checked again on confirm): appends one `reroll`
-- record naming it, with a new goal of its type generated with its kind dropped (TKB-R30–R36). The projection applies
-- it live (TKB-R57): the new goal takes the old one's pin and is re-posted.
---@param goalID string
local function reroll(goalID)
	local goal = takeable(goalID)
	if goal then
		local ctx = ns.GenerationContext(ns.State(), ns.api.GetServerTime(), ns.random)
		local def = ns.GenerateGoal(ctx, goal.type, goal.kind)
		ns.Module:AppendRecord("reroll", ns.EncodeReroll(goal.id, def))
	end
end

--- Whether a Refresh can post a goal of `goalType` now (TKB-R58): ns.CanPostGoal over the board as it stands, the
--- Refreshes held and whether the projection is updating. The empty pins are clickable while it holds.
---@param goalType TackleGoalType|any
---@return boolean
function ns.CanPost(goalType)
	return ns.CanPostGoal(ns.State(), goalType, ns.RefreshesHeld(), ns.IsUpdating())
end

-- Posts a goal of `goalType` if a Refresh still can (TKB-R58: checked again on confirm): appends one `post` record
-- carrying a new goal of that type, generated by TKB-R30–R36 as the live step generates an issued one. The projection
-- applies it live (TKB-R58): the goal takes the first empty pin of its type, and Core is told one Refresh more spent.
-- The live step runs first: a reset that has passed before its timer fired (TKB-R13) owes goals that would otherwise be
-- issued after the post, past the caps; they take their pins first, and the post goes where room is left.
---@param goalType TackleGoalType
local function post(goalType)
	ns.LiveStep()
	if ns.CanPost(goalType) then
		local ctx = ns.GenerationContext(ns.State(), ns.api.GetServerTime(), ns.random)
		ns.Module:AppendRecord("post", ns.EncodePost(ns.GenerateGoal(ctx, goalType)))
	end
end

-- The confirm, made at its first showing: its paper and tack, the question, what is lost or spent, and its two answers.
-- "Yes" does what the question it was opened for set (frame.onAccept) if the thing can still be done; "Keep it" and
-- Esc only close it.
---@return TackleConfirmFrame
local function confirmFrame()
	if confirm then
		return confirm
	end
	local L = ns.L
	local frame = CreateFrame("Frame", CONFIRM_NAME, UIParent) --[[@as TackleConfirmFrame]]
	frame:SetSize(CONFIRM_WIDTH, CONFIRM_HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame.paper = ns.ArtSprite(frame, "Board", "confirm", "BACKGROUND")
	ns.PlaceSprite(ns.NewBoardTack(frame), frame, 173, -5)
	frame.title = ns.ArtText(frame, "ConfirmTitle")
	frame.title:SetJustifyH("CENTER")
	frame.title:SetPoint("TOP", 0, -28)
	frame.text = ns.ArtWrap(frame, "ConfirmText", 308, 4)
	frame.text:SetJustifyH("CENTER")
	frame.text:SetPoint("TOP", 0, -60)
	frame.accept = ns.NewBoardButton(frame, L.TAKE_DOWN_YES, 134, "ButtonSmall", function()
		local accept = frame.onAccept
		frame:Hide()
		if accept then
			accept()
		end
	end)
	frame.accept:SetPoint("TOPLEFT", 47, -112)
	frame.keep = CreateFrame("Button", nil, frame) --[[@as TackleConfirmKeep]]
	local keep = ns.ArtText(frame.keep, "ConfirmKeep")
	keep:SetPoint("TOPLEFT")
	keep:SetText(L.TAKE_DOWN_NO)
	frame.keep:SetSize(keep:GetStringWidth() + 4, 26)
	frame.keep:SetPoint("TOPLEFT", 203, -121)
	frame.keep.label = keep
	ns.BoardDots(frame.keep, keep, keep:GetStringWidth(), ns.BOARD_FONTS.ConfirmKeep[3])
	frame.keep:SetScript("OnClick", function()
		frame:Hide()
	end)
	frame:Hide()
	frame:SetScript("OnShow", takeBoardEsc)
	frame:SetScript("OnHide", function(self)
		self.onAccept = nil
		giveBoardEsc()
	end)
	confirm = frame
	return frame
end

--- The confirm, if it was ever shown (for its specs).
---@return TackleConfirmFrame?
function ns.TakeDownConfirm()
	return confirm
end

-- Asks the question on the confirm (TKB-R56, TKB-R59): `title`, then `text` with the first `inked` in it in red, and
-- `yes` on the leather button, which runs `onAccept`. "Keep it" and Esc close it and do nothing.
---@param title string
---@param text string
---@param inked string the words of `text` the confirm inks red: what is lost or spent
---@param yes string the leather button's words
---@param onAccept fun()
local function ask(title, text, inked, yes, onAccept)
	local frame = confirmFrame()
	frame.title:SetText(title)
	local at = text:find(inked, 1, true)
	if at then
		text = text:sub(1, at - 1) .. "|cff" .. RED .. inked .. "|r" .. text:sub(at + #inked)
	end
	frame.text:SetText(text)
	frame.accept.label:SetText(yes)
	ns.LeanSprite(frame.paper, frame, 0, 0, CONFIRM_LEAN)
	frame:Show()
	frame.onAccept = onAccept
end

--- Takes a goal down (TKB-R55, TKB-R56), if it can be now: at once with no displayed progress, else after "Take it
--- down" in the confirm, checking the conditions again then. "Keep it" and Esc append nothing.
---@param goalID string the entry ID of the record that issued it (TKB-R23)
function ns.TakeDown(goalID)
	local goal = takeable(goalID)
	if not goal then
		return
	end
	local question = ns.TakeDownQuestion(goal, ns.State().day, ns.api.pagle)
	if not question then
		reroll(goalID)
		return
	end
	ask(question.title, question.text, question.progress, ns.L.TAKE_DOWN_YES, function()
		reroll(goalID)
	end)
end

--- Spends a Refresh on an empty slot (TKB-R58, TKB-R59), if one can be now: always after "Post it" in the confirm, since
--- it cannot be undone, checking the conditions again then. "Keep it" and Esc append nothing.
---@param goalType TackleGoalType the type of the empty pin clicked: "n" a Notice, "e" an Expedition
function ns.Post(goalType)
	if not ns.CanPost(goalType) then
		return
	end
	local question = ns.PostQuestion(goalType)
	ask(question.title, question.text, question.cost, ns.L.POST_YES, function()
		post(goalType)
	end)
end
