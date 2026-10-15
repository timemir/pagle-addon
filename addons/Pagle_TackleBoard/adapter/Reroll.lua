if not Pagle then
	return
end

---@class PagleTackleBoardNS
local ns = select(2, ...)

-- "Take it down" on the client (TKB-R55, TKB-R56): ns.CanTakeDown and ns.TakeDown (logic/Seams.lua; adapter/Pins.lua
-- shows the button and calls them), the confirm and the `reroll` record, which only this file and adapter/LiveStep.lua's
-- live step append (TKB-R80). The rules are logic/Reroll.lua's. The confirm is the board art kit's (PagleArtBoard's
-- Overlays.lua, P.Confirm): a paper pinned over the screen's middle with the question, what is lost (the progress in
-- red), a leather "Take it down" and a pencilled "Keep it". It is a plain frame, not secure, so it works in combat
-- (TKB-R193), and Esc keeps the goal (UISpecialFrames).

-- The confirm's global name, for UISpecialFrames; its paper, 360 × 166, leaning a little; its red ink.
local CONFIRM_NAME = "PagleTackleBoardConfirm"
local CONFIRM_WIDTH, CONFIRM_HEIGHT, CONFIRM_LEAN, RED = 360, 166, -0.8, "9A2A1A"

---@class TackleConfirmKeep: Button
---@field label FontString

---@class TackleConfirmFrame: Frame
---@field paper TackleSprite
---@field title FontString
---@field text FontString
---@field accept TackleButtonView
---@field keep TackleConfirmKeep
---@field goalID string?

---@type TackleConfirmFrame?
local confirm

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

-- The confirm, made at its first showing: its paper and tack, the question, what is lost, and its two answers. "Take
-- it down" takes down the goal it was shown for, if it still can be; "Keep it" and Esc only close it.
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
		local goalID = frame.goalID
		frame:Hide()
		if goalID then
			reroll(goalID)
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
	frame:SetScript("OnHide", function(self)
		self.goalID = nil
	end)
	table.insert(UISpecialFrames, CONFIRM_NAME)
	frame:Hide()
	confirm = frame
	return frame
end

--- The confirm, if it was ever shown (for its specs).
---@return TackleConfirmFrame?
function ns.TakeDownConfirm()
	return confirm
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
	local frame = confirmFrame()
	frame.title:SetText(question.title)
	local at = question.text:find(question.progress, 1, true)
	local text = question.text
	if at then
		text = question.text:sub(1, at - 1)
			.. "|cff"
			.. RED
			.. question.progress
			.. "|r"
			.. question.text:sub(at + #question.progress)
	end
	frame.text:SetText(text)
	ns.LeanSprite(frame.paper, frame, 0, 0, CONFIRM_LEAN)
	frame:Show()
	frame.goalID = goalID
end
