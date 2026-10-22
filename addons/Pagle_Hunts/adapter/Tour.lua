if not Pagle then
	return
end

---@class PagleHuntsNS
local ns = select(2, ...)

-- Hunts' tour stops on the client (CORE-R65, CORE-R68): each of logic/Tour.lua's stops swaps the tour's sample in at
-- its show (the Hunt list with every Hunt out, a HuntsState, three pins and a sample grouping) and shows the board on
-- its place or the tracker in the dock, in a good's look if it has one; its hide swaps the sample out and puts the
-- board, the tracker and their looks back as they were. Nothing is saved: the pins swap whole tables, and the
-- tracker's collapse is put back. Hunts makes no secure frames (HNT-R193).

-- Packs a call's results with their count, nils included.
---@return { n: integer }
local function pack(...)
	return { n = select("#", ...), ... }
end

--- What the sample replaced, or the sample itself: the values swapped in and out together.
---@class HuntsTourValues
---@field hunts HuntList
---@field projection PagleProjection?
---@field pins table<string, true>
---@field summary fun(text: string)?

-- Puts `values` in place: the Hunt list, the projection the views read, the pins and the summary line's outlet.
---@param values HuntsTourValues
local function put(values)
	ns.hunts, ns.projection, ns.db.profile.pins = values.hunts, values.projection, values.pins
	if ns.moments then
		ns.moments.client.SetSummaryLine = values.summary
	end
end

--- Swaps the tour's sample in, made now (logic/Tour.lua), and holds the grouping on it (adapter/Groups.lua): the views
--- then draw the sample, and the summary line isn't sent. A live Cast still applies to the real projection: its apply,
--- its titles and its moments run with the real list and pins put back for the call (HNT-R137). Returns the sample
--- and the function that swaps it out.
---@return HuntsTourSample
---@return fun() out
local function swapIn()
	local sample = ns.HuntsTourSample(
		ns.huntList,
		GetServerTime(),
		ns.events and ns.events:Events() or {},
		not ns.IsUpdating() and ns.State() or nil
	)
	-- What the views read of a projection (logic/Seams.lua): the sample's state, never updating.
	local sampleProjection = {
		GetState = function()
			return sample.state
		end,
		IsUpdating = function()
			return false
		end,
	}
	---@type HuntsTourValues
	local real = {
		hunts = ns.hunts,
		projection = ns.projection,
		pins = ns.db.profile.pins,
		summary = ns.moments and ns.moments.client.SetSummaryLine,
	}
	---@type HuntsTourValues
	local tour = {
		hunts = ns.NewHuntList(sample.data, ns.L),
		projection = sampleProjection --[[@as PagleProjection]],
		pins = sample.pins,
		summary = function() end,
	}
	local fns = { ns.ApplyCast, ns.CheckTitles, ns.outlets.Reached, ns.outlets.Done }
	local depth = 0
	-- `fn`, run with the real values in place; nested calls swap once.
	local function onReal(fn)
		return function(...)
			depth = depth + 1
			if depth == 1 then
				put(real)
			end
			local results = pack(fn(...))
			depth = depth - 1
			if depth == 0 then
				put(tour)
			end
			return unpack(results, 1, results.n)
		end
	end
	put(tour)
	ns.ApplyCast, ns.CheckTitles = onReal(fns[1]), onReal(fns[2])
	ns.outlets.Reached, ns.outlets.Done = onReal(fns[3]), onReal(fns[4])
	ns.HoldSampleGrouping()
	local function out()
		put(real)
		ns.ApplyCast, ns.CheckTitles, ns.outlets.Reached, ns.outlets.Done = fns[1], fns[2], fns[3], fns[4]
		ns.EndSampleGrouping()
	end
	return sample, out
end

-- A stop on the board: its show opens the board on the stop's place; its hide puts the board back on the place it was
-- on, closed if it was closed.
---@param M PagleModuleHandle
---@param stop HuntsTourStop
---@param label string
local function boardStop(M, stop, label)
	local board = ns.board
	---@type { shown: boolean, place: BoardPlace, out: fun() }?
	local saved
	M:RegisterTourStop(stop.id, label, function()
		local shown, place = board:IsShown(), board.router:Place()
		local sample, out = swapIn()
		saved = { shown = shown, place = place, out = out }
		ns.Redraw("tour")
		local now = GetServerTime()
		local rows = ns.groups:Rows({ filtered = true })
		local runs = ns.RunsShown(ns.State(), now)
		board:Open(stop.place({ sample = sample, rows = rows, runs = runs, list = ns.hunts, now = now }))
	end, function()
		if not saved then
			return
		end
		saved.out()
		board.router:Open(saved.place)
		if saved.shown then
			board:Draw()
		else
			board:Hide()
		end
		ns.Redraw("tour")
		saved = nil
	end)
end

-- A stop on the tracker: its show shows the tracker in the dock, expanded, in the stop's tracker frame if it has one;
-- its hide puts back whether it showed, its collapse and its frame.
---@param M PagleModuleHandle
---@param stop HuntsTourStop
---@param label string
local function trackerStop(M, stop, label)
	---@type { shown: boolean, collapsed: boolean, out: fun() }?
	local saved
	M:RegisterTourStop(stop.id, label, function()
		local view = ns.tracker --[[@as HuntsTrackerView]]
		local tracker = ns.db.profile.tracker
		local shown, collapsed = view.frame:IsShown(), tracker.collapsed
		local _, out = swapIn()
		saved = { shown = shown, collapsed = collapsed, out = out }
		view.wearing = stop.good
		tracker.collapsed = false
		view.frame:Show()
		ns.Redraw("tour")
	end, function()
		if not saved then
			return
		end
		local view = ns.tracker --[[@as HuntsTrackerView]]
		saved.out()
		view.wearing = nil
		ns.db.profile.tracker.collapsed = saved.collapsed
		view.frame:SetShown(saved.shown)
		ns.Redraw("tour")
		saved = nil
	end)
end

--- Registers each of Hunts' tour stops on `M` (CORE-R65), from OnInitialize once the board and the tracker are made,
--- and only when `M.RegisterTourStop` exists, so Hunts runs on a Core without it.
---@param M PagleModuleHandle
function ns.RegisterTourStops(M)
	for _, stop in ipairs(ns.HUNTS_TOUR) do
		local label = ns.L[stop.label]
		if stop.good then
			label = label:format(ns.HuntsGoodName(stop.good))
		end
		if stop.place then
			boardStop(M, stop, label)
		else
			trackerStop(M, stop, label)
		end
	end
end
