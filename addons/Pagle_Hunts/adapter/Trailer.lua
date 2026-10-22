if not Pagle or not Pagle.RegisterTrailerPart then
	return
end
---@class PagleHuntsNS
local ns = select(2, ...)

Pagle.RegisterTrailerPart("Hunts", function(ctx)
	local now = GetServerTime()
	-- The event pool's sample runs, never the Angler's real ones, so Pagle Wagers shows the same in every take.
	local pool = ns.events and ns.events:Events() or {}
	local sample = ns.HuntsTourSample(ns.huntList, now, pool)
	ctx.defer(function()
		if ctx.loggingOut then
			return
		end
		ns.EndSampleGrouping()
		ns.board:Hide()
		ns.Redraw("trailer-end")
	end)
	ctx.swap(ns, "db", ctx.db(ns.db))
	ctx.swap(ns, "hunts", ns.NewHuntList(sample.data, ns.L))
	ctx.swap(ns, "projection", ctx.projection(sample.state))
	ns.db.profile.pins = {}
	ns.db.profile.tracker.shown = true
	ns.db.profile.tracker.collapsed = false
	ns.HoldSampleGrouping()
	ctx.coins("Hunts", sample.state.coins)
	-- The sample doesn't fold Casts, so its Activity XP is what its tiers and runs pay (HNT-R110, HNT-R113).
	local xp = 0
	for _, progress in pairs(sample.state.hunts) do
		for k in ipairs(progress.reached) do
			xp = xp + ns.TierAmount(ns.XP_STANDING, k)
		end
	end
	for _, run in pairs(sample.state.runs) do
		for _, progress in pairs(run.hunts) do
			for k in ipairs(progress.reached) do
				xp = xp + ns.TierAmount(ns.XP_EVENT, k)
			end
		end
		if run.completedAt then
			xp = xp + ns.XP_RUN
		end
	end
	ctx.xp("Hunts", xp)
	local runs = ns.RunsShown(sample.state, now, nil, pool)
	assert(runs[1], "Pagle trailer needs a Pagle Wagers run to show")
	local nowHunt, later
	for _, row in ipairs(ns.groups:Rows({ filtered = true })) do
		if row.group == "now" and not nowHunt then
			nowHunt = row.id
		elseif (row.group == "soon" or row.group == "later") and not later then
			later = row.id
		end
	end
	for _, row in ipairs(ns.groups:Rows({ filtered = true })) do
		nowHunt = nowHunt or row.id
	end
	assert(nowHunt, "Pagle trailer needs a Hunt to show")
	return {
		actions = {
			now = function()
				ns.OpenBoard(nowHunt)
			end,
			later = function()
				ns.OpenBoard(later or nowHunt)
			end,
			pin = function()
				ns.SetPinned(nowHunt, true)
			end,
			close = function()
				ns.board:Hide()
			end,
			reopen = function()
				ns.OpenBoard(nowHunt)
			end,
			set = function()
				local hunt = assert(ns.hunts:Hunt(nowHunt))
				ns.board:Open({ mode = "set", set = hunt.set })
			end,
			run = function()
				ns.board:Open({ mode = "board", run = runs[1].key })
			end,
			wagers = function()
				ns.board:Open({ mode = "wagers" })
			end,
		},
	}
end)
