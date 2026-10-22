if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' parts of onboarding on the client (core/onboarding.md; #333): the Hunts board's First look (ONB-R55–R58,
-- board 13 "First look · Hunts"), its "?" (ONB-R59) and, as the board opens, the First evening list's `hunts` item
-- (ONB-R61). Core draws the notes and the coach bar (ONB-R92); this file says what each note points at and when the set
-- shows, through Hunts' handle alone (ADR 0001), each call only on a Core that has it (ONB-R90). The "?" is
-- adapter/Board.lua's, in the board's wax (adapter/BoardWidgets.lua's ns.NewBoardHelp). Hunts has no guide step; its
-- line on What's in the box is def.guideBlurb (logic/Module.lua, ONB-R91).
--
-- The five notes point at the Board spread (the Board ribbon's): the first Now, Soon or Later heading on the timeline,
-- the now line, the "Natural" (or "Imposed") at the end of the entry's kicker, the entry's pin, and the Pagle Wagers
-- ribbon (HNT-R162), which now exists, so ONB-R109's dropped fifth note shows. Each target is the region itself, read
-- when Core asks, so it follows the ruler and the list wherever the wager strip pushes them (HNT-R161). Off the Board
-- spread every target is nil, so a note there drops (ONB-R56).
--
-- The set shows as the board opens on the Board spread with a Now, Soon or Later group to point at: opened on another
-- spread (a set's page, the Pagle Wagers spread), or with no Hunt out yet, the board opens without it and leaves it,
-- unseen, for a later opening. Core shows it once (looksSeen) and only with Margin notes on (ONB-R55).

local L = ns.L

--- The set's id: Hunts' own, "<module>.<window>" (ONB-R56).
ns.BOARD_LOOK_ID = "hunts.board"

-- Each note's width, the canvas's, and where it sits in the board's units from its top left (920 × 600): in the left
-- margin 85 off the leather, or the right 79 past it, as the canvas has them; down from the board's top as the canvas's
-- board, drawn at 0.92 from (297, 65), has them, beside what each points at (ONB-R58). The fifth sits in the left
-- margin under the second, not in the right as drawn: the canvas hung "Pagle's Wagers" last, at the right, and the
-- board hangs it second (HNT-R162), so its arrow stays short and crosses no other ribbon.
local LEFT_W, RIGHT_W = 196, 200
local LEFT_X, RIGHT_X = -(LEFT_W + 85), 920 + 79

-- Whether the set is registered with Core, so the board asks for it and has a "?".
local registered = false

-- The Board spread shown: the board open on the Board ribbon's spread.
---@return boolean
local function onBoard()
	return ns.board:IsShown() and ns.board.router:Place().mode == "board"
end

-- The Board spread's timeline and entry as drawn, while it shows; nil off it.
---@return TimelinePageView?
---@return EntryView?
local function boardViews()
	if not onBoard() then
		return nil, nil
	end
	local place = { mode = "board" }
	local right = ns.board:Page(place, "right") --[[@as EntryPage?]]
	return ns.TimelinePageView(ns.board:Page(place, "left")), right and right.entry
end

-- `region` while it shows, else nil.
---@param region Region?
---@return Region?
local function visible(region)
	if region and region:IsVisible() then
		return region
	end
	return nil
end

-- The first group's heading of Now, Soon and Later that shows within the list: the first note's target.
---@return FontString?
local function groupsHeading()
	local timeline = boardViews()
	if not timeline then
		return nil
	end
	for _, group in ipairs({ "now", "soon", "later" }) do
		local label = ns.TimelineHeadingLabel(timeline, group)
		if label then
			return label
		end
	end
	return nil
end

-- The region over the entry's kicker's words alone ("{set} · Natural"), made at the first ask, so the arrow from the
-- right margin lands on "Natural" (or "Imposed") at their end and not on the empty room after them.
---@type table<EntryView, Frame>
local kickerWords = setmetatable({}, { __mode = "k" })

---@param entry EntryView
---@return Frame?
local function kickerTarget(entry)
	local kicker = entry.kicker
	if not kicker:IsVisible() then
		return nil
	end
	local words = kickerWords[entry]
	if not words then
		words = CreateFrame("Frame", nil, entry.page)
		words:SetPoint("TOPLEFT", kicker, "TOPLEFT", 0, 0)
		kickerWords[entry] = words
	end
	local height = kicker:GetHeight()
	words:SetSize(math.min(kicker:GetStringWidth(), kicker:GetWidth()), height > 0 and height or 12)
	return words
end

--- The board's First look (ONB-R57's Hunts set), registered at OnInitialize (adapter/Hunts.lua); its tour stop opens
--- the board on the Board spread (ONB-R84).
---@return PagleFirstLook
function ns.BoardFirstLook()
	return {
		id = ns.BOARD_LOOK_ID,
		window = function()
			return ns.board.frame
		end,
		title = L.LOOK_TITLE,
		open = function()
			ns.OpenBoard()
		end,
		notes = {
			{
				-- the first of the Now, Soon and Later headings
				text = L.LOOK_GROUPS,
				target = groupsHeading,
				x = LEFT_X,
				y = 92,
				w = LEFT_W,
			},
			{
				-- the red now line, through the ruler and the list
				text = L.LOOK_NOW_LINE,
				target = function()
					local timeline = boardViews()
					return timeline and visible(timeline.nowLine)
				end,
				x = LEFT_X,
				y = 330,
				w = LEFT_W,
			},
			{
				-- the entry's kicker, "{set} · Natural"
				text = L.LOOK_NATURAL,
				target = function()
					local _, entry = boardViews()
					return entry and kickerTarget(entry)
				end,
				x = RIGHT_X,
				y = -49,
				w = RIGHT_W,
			},
			{
				-- the entry's pin toggle (HNT-R80)
				text = L.LOOK_PIN,
				target = function()
					local _, entry = boardViews()
					return entry and visible(entry.pin)
				end,
				x = RIGHT_X,
				y = 158,
				w = RIGHT_W,
			},
			{
				-- the Pagle Wagers ribbon (HNT-R162), hanging second under the leather
				text = L.LOOK_SETS,
				target = function()
					return onBoard() and visible(ns.BoardWagersRibbon()) or nil
				end,
				x = LEFT_X,
				y = 495,
				w = LEFT_W,
			},
		},
	}
end

--- Registers the board's First look with Core (ONB-R56) at OnInitialize, so it joins Off you go's list and the tour.
--- Nothing on a Core without First looks (ONB-R90).
---@param module PagleModuleHandle
function ns.RegisterBoardLook(module)
	if not (module.RegisterFirstLook and module.ShowFirstLook) then
		return
	end
	module:RegisterFirstLook(ns.BoardFirstLook())
	registered = true
end

--- Whether the board's First look is registered with a Core that shows it: the "?" shows only then (ONB-R90).
---@return boolean
function ns.HasBoardLook()
	local M = ns.Module
	return registered and M ~= nil and M.ShowFirstLook ~= nil
end

--- The board has opened, drawn and fitted to the screen (adapter/Board.lua's Board:Open): the First evening list's
--- `hunts` item, on any spread (ONB-R61); then, on the Board spread with a Now, Soon or Later group to point at, its
--- First look, the first time (ONB-R55: Core shows it once). Each only on a Core that has it (ONB-R90).
function ns.BoardOpened()
	local M = ns.Module
	if not M then
		return
	end
	if M.CompleteEveningItem then
		M:CompleteEveningItem("hunts")
	end
	if ns.HasBoardLook() and groupsHeading() then
		M:ShowFirstLook(ns.BOARD_LOOK_ID)
	end
end

--- The "?" pressed (ONB-R59): the set again, seen or not and with Margin notes off, the board turning to the Board
--- spread first, at once, when it shows another; pressed while the set shows, Core hides it.
function ns.ShowBoardLookAgain()
	if not ns.HasBoardLook() then
		return
	end
	if not onBoard() then
		ns.board:Open({ mode = "board" })
		ns.board:SettleTurn()
	end
	ns.Module:ShowFirstLook(ns.BOARD_LOOK_ID, true)
end
