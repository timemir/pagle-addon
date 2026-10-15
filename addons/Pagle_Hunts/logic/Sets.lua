if not Pagle then -- luacheck: read globals Pagle (CORE-R11: the one read of Core outside adapter/)
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Sets on the Hunts board (HNT-R3, HNT-R20–R22, HNT-R61, HNT-R66, HNT-R69): the set ribbons, the gilt breadcrumbs,
-- the gold nameplate and the right side of a set's page, as data. Pure logic, everything passed in (CORE-R7);
-- adapter/Sets.lua gathers the inputs and draws the result on the board's leather anchors and the set mode's right
-- page. Titles stay inside these views (HNT-R22): nothing here hands them on.

--- What the sets' views read: the Hunt list, the projection's state, and the time "current" is judged at.
---@class HuntsSetsInput
---@field list HuntList
---@field state HuntsState      -- ns.State()
---@field updating boolean      -- ns.IsUpdating(): nothing is drawn from the state (HNT-R69)
---@field now integer           -- the grouping's time, or now before the first grouping

--- One ribbon on the leather's right edge (HNT-R61).
---@class BoardRibbon
---@field set string?           -- the set's ID; nil for the Board ribbon
---@field text string           -- the word stacked down the ribbon
---@field name string?          -- the set's full name, for its tooltip
---@field index integer?        -- the set's place in the Hunt list, for its colour (ns.BoardRibbonColor)
---@field chosen boolean        -- the ribbon of the mode shown
---@field place BoardPlace      -- where clicking it goes

-- Whether a set has a ribbon (HNT-R61): it has a current Hunt, an earned title, or a done Retired Hunt. While the
-- projection is updating only current Hunts count, as nothing is drawn from its state (HNT-R69).
---@param input HuntsSetsInput
---@param setID string
---@return boolean
local function hasRibbon(input, setID)
	if not input.updating and input.state.sets[setID] then
		return true
	end
	for _, hunt in ipairs(input.list:SetHunts(setID)) do
		if ns.IsCurrent(hunt, input.now) then
			return true
		end
		if not input.updating and ns.IsRetired(hunt, input.now) and ns.HuntDone(input.state.hunts[hunt.id]) then
			return true
		end
	end
	return false
end

--- The word a set's ribbon stacks: the last word of its name, as variant E's ribbons show it.
---@param name string
---@return string
function ns.RibbonWord(name)
	return name:match("(%S+)%s*$") or name
end

--- The set ribbons (HNT-R61): "Board", then one per set that has a current Hunt, an earned title or a done Retired
--- Hunt, in Hunt list order. The Board ribbon is chosen on the Board; a set's on its page and the entries opened
--- from it.
---@param input HuntsSetsInput
---@param place BoardPlace where the board is
---@return BoardRibbon[]
function ns.BuildRibbons(input, place)
	local onSet = place.mode ~= "board" and place.set or nil
	local ribbons = { { text = ns.L.RIBBON_BOARD, chosen = onSet == nil, place = { mode = "board" } } }
	for index, set in ipairs(input.list:Sets()) do
		if hasRibbon(input, set.id) then
			local name = input.list:SetName(set.id)
			ribbons[#ribbons + 1] = {
				set = set.id,
				text = ns.RibbonWord(name),
				name = name,
				index = index,
				chosen = onSet == set.id,
				place = { mode = "set", set = set.id },
			}
		end
	end
	return ribbons
end

--- One gilt breadcrumb (HNT-R61): its words and the place clicking it goes back to.
---@class BoardCrumbView
---@field text string
---@field place BoardPlace

--- The breadcrumbs' words for the router's trail (logic/Board.lua's BoardCrumb): "Hunts", then the set's name, then
--- the Hunt's, each going back to its own level.
---@param trail BoardCrumb[]
---@param list HuntList
---@return BoardCrumbView[]
function ns.BuildCrumbs(trail, list)
	local crumbs = {}
	for i, crumb in ipairs(trail) do
		local text = ns.L.CRUMB_HUNTS
		if crumb.kind == "set" then
			text = list:SetName(crumb.id)
		elseif crumb.kind == "hunt" then
			text = list:HuntName(crumb.id)
		end
		crumbs[i] = { text = text, place = crumb.place }
	end
	return crumbs
end

--- The gold nameplate (HNT-R61): its words, and its tooltip's lines.
---@class BoardNameplate
---@field text string
---@field titles string[]       -- each earned title and its full date, in Hunt list order

--- The nameplate (HNT-R61): "{n} titles · {m} Hunts done", counting the titles earned and the Hunts done, Retired
--- Hunts included, with each earned title and its full date for the tooltip. While the projection is updating it
--- reads the updating line and lists none (HNT-R69).
---@param input HuntsSetsInput
---@return BoardNameplate
function ns.BuildNameplate(input)
	if input.updating then
		return { text = ns.L.UPDATING, titles = {} }
	end
	local titles = {}
	for _, set in ipairs(input.list:Sets()) do
		local earned = input.state.sets[set.id]
		if earned then
			titles[#titles + 1] =
				ns.L.NAMEPLATE_TITLE:format(input.list:SetTitle(set.id), ns.FormatFullDate(earned.date))
		end
	end
	local done = 0
	for _, hunt in ipairs(input.list:Hunts()) do
		if ns.HuntDone(input.state.hunts[hunt.id]) then
			done = done + 1
		end
	end
	local text = ns.L.NAMEPLATE:format(ns.CountText(#titles, "SUMMARY_TITLES"), ns.CountText(done, "NAMEPLATE_DONE"))
	return { text = text, titles = titles }
end

--- One line of a set's checklist (HNT-R66).
---@class SetPageLine
---@field id string
---@field name string
---@field done boolean          -- tier 1 reached (HNT-R17)
---@field when string           -- its seal date (short date) once done, its tracker label before (HNT-R51)
---@field place BoardPlace      -- its entry, or its retired entry (HNT-R3)

--- The right side of a set's page (HNT-R66).
---@class SetPage
---@field name string
---@field titleLine string      -- "Earns the title {title}", or "Earned: {title}"
---@field seal string?          -- the seal's words with the full date it was earned; nil until earned
---@field sealLines string[]?   -- the pressed seal stacked: its word, the short date and the year; nil until earned
---@field progress { fill: number, label: string }   -- done current Hunts out of current Hunts
---@field line string           -- "The first tier of every Hunt earns the title."
---@field note string?          -- the set's note
---@field hunts SetPageLine[]   -- every current Hunt, in Hunt list order, whatever the filter (HNT-R82)
---@field retiredHeading string
---@field retired SetPageLine[] -- its done Retired Hunts, in Hunt list order (HNT-R3)

--- The right side of set `setID`'s page (HNT-R66): its name, its title earned or to earn, the progress bar, the
--- line, its note, a checklist of all its current Hunts, and its done Retired Hunts under "Retired". While the
--- projection is updating nothing comes from its state (HNT-R69): the progress reads the updating line, the title
--- reads as to earn, every Hunt shows its tracker label, and no Retired Hunt is listed.
---@param input HuntsSetsInput
---@param setID string
---@param trackerLabel fun(huntID: string): string? a current Hunt's tracker label (HNT-R51), nil before the grouping
---@return SetPage
function ns.BuildSetPage(input, setID, trackerLabel)
	local L, list, state = ns.L, input.list, input.state
	local earned = not input.updating and state.sets[setID] or nil
	local page = {
		name = list:SetName(setID),
		titleLine = (earned and L.SET_PAGE_EARNED or L.SET_PAGE_EARNS):format(list:SetTitle(setID)),
		seal = earned and L.SET_SEAL:format(ns.FormatFullDate(earned.date)) or nil,
		sealLines = earned and { L.SET_SEAL_WORD, ns.FormatShortDate(earned.date), tostring(earned.date.year) } or nil,
		line = L.SET_RULE,
		note = list:SetNote(setID),
		hunts = {},
		retiredHeading = L.SET_RETIRED,
		retired = {},
	}
	for _, hunt in ipairs(list:SetHunts(setID)) do
		local tier = not input.updating and state.hunts[hunt.id] and state.hunts[hunt.id].reached[1] or nil
		local line = { id = hunt.id, name = list:HuntName(hunt.id), done = tier ~= nil }
		if ns.IsCurrent(hunt, input.now) then
			line.when = tier and ns.FormatShortDate(tier.date) or trackerLabel(hunt.id) or ""
			line.place = { mode = "entry", set = setID, hunt = hunt.id }
			page.hunts[#page.hunts + 1] = line
		elseif tier and ns.IsRetired(hunt, input.now) then
			line.when = ns.FormatShortDate(tier.date)
			line.place = { mode = "retired", set = setID, hunt = hunt.id }
			page.retired[#page.retired + 1] = line
		end
	end
	local done, current = ns.DoneOfCurrent(list, state, input.now, setID)
	if input.updating then
		page.progress = { fill = 0, label = L.UPDATING }
	else
		page.progress = { fill = current > 0 and done / current or 0, label = L.SET_PROGRESS:format(done, current) }
	end
	return page
end
