-- Sets on the Hunts board (HNT-R3, HNT-R20–R22, HNT-R61, HNT-R66, HNT-R67, HNT-R69): the set ribbons, the gilt
-- breadcrumbs, the gold nameplate and the right side of a set's page, as data (logic/Sets.lua) and as drawn on the
-- board, on FakePagle over the fixture Hunt list and catalogue, with hand-made projection states.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")
---@diagnostic disable-next-line: undefined-global -- as above
local catalogue = dofile("spec/Pagle_Hunts/fixtures/Catalogue.lua")

local JAN_1 = 1767225600 -- 2026-01-01, the fixture Hunts' since
local JUN_1 = 1780272000 -- 2026-06-01, the fixture's retired date
local NOV_4 = 1793750400 -- 2026-11-04, after FakePagle's clock

--- A copy of the fixture Hunt list with `sets` and `huntDefs` appended (DATA-R93).
local function withExtra(fixture, sets, huntDefs)
	local list = { fingerprint = fixture.fingerprint, sets = {}, hunts = {}, classes = fixture.classes }
	for _, set in ipairs(fixture.sets) do
		list.sets[#list.sets + 1] = set
	end
	for _, hunt in ipairs(fixture.hunts) do
		list.hunts[#list.hunts + 1] = hunt
	end
	for _, set in ipairs(sets) do
		list.sets[#list.sets + 1] = set
	end
	for _, hunt in ipairs(huntDefs) do
		list.hunts[#list.hunts + 1] = hunt
	end
	return list
end

--- Two sets the fixture lacks: fixture_bygone, whose one Hunt was retired on 2026-06-01, and fixture_ahead, whose one
--- Hunt is shipped early (since 2026-11-04).
local function bygoneAndAhead(fixture)
	return withExtra(fixture, { { id = "fixture_bygone" }, { id = "fixture_ahead" } }, {
		{
			id = "fixture_bygone_trout",
			set = "fixture_bygone",
			kind = "natural",
			since = JAN_1,
			retired = JUN_1,
			species = 13760,
			window = "day",
			tiers = { 1 },
		},
		{
			id = "fixture_ahead_trout",
			set = "fixture_ahead",
			kind = "natural",
			since = NOV_4,
			species = 13760,
			window = "day",
			tiers = { 1 },
		},
	})
end

--- Serves `huntsProgress` (by Hunt ID) and `sets` (titles by set ID) as the projection's state, updating or not: the
--- hand-made state views read through ns.State() and ns.IsUpdating() (logic/Seams.lua).
local function useState(run, huntsProgress, sets, updating)
	run.ns.projection = {
		GetState = function()
			return { casts = 0, coins = 0, hunts = huntsProgress or {}, sets = sets or {} }
		end,
		IsUpdating = function()
			return updating == true
		end,
	}
end

--- A Hunt's progress with its first `tiers` tiers reached on realm date `date` (2026-01-01 by default).
local function reached(tiers, date)
	date = date or { year = 2026, month = 1, day = 1 }
	local progress = { count = tiers, effort = 0, sinceLast = 0, caught = tiers > 0, reached = {} }
	for k = 1, tiers do
		progress.reached[k] = { time = JAN_1, catchId = "c" .. k, itemID = 13759, zone = 0, date = date }
	end
	return progress
end

--- Hunts on a FakePagle after the first PLAYER_ENTERING_WORLD (so the groups are grouped), with `options.list` as the
--- Hunt list if given, and an empty projection state.
local function start(options)
	options = options or {}
	local fake = newFakePagle()
	fake.setCatalogue(catalogue.base())
	local loaded = hunts.load(fake, {
		prepare = function(l)
			if options.list then
				l.ns.huntList = options.list(l.ns.huntList)
			end
		end,
	})
	fake.login()
	fake.readSkill(150, 300, 0)
	fake.enterWorld()
	fake.fireGameEvent("PLAYER_ENTERING_WORLD", true, false)
	local run = { loaded = loaded, fake = fake, ns = loaded.ns }
	useState(run)
	return run
end

--- The set ribbons' set IDs, in order, the Board ribbon left out.
local function setsOf(ribbons)
	local out = {}
	for _, ribbon in ipairs(ribbons) do
		if ribbon.set then
			out[#out + 1] = ribbon.set
		end
	end
	return out
end

describe("the set ribbons (HNT-R61)", function()
	it("read Board, then each set with a current Hunt, in Hunt list order", function()
		local run = start()

		local ribbons = run.ns.BoardRibbons({ mode = "board" })

		assert.are.same({ "Board", false }, { ribbons[1].text, ribbons[1].set or false })
		assert.are.same({ "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide" }, setsOf(ribbons))
	end)

	it("leave out a set whose only Hunt is Retired and not done, and one whose only Hunt isn't out yet", function()
		local run = start({ list = bygoneAndAhead })

		local sets = setsOf(run.ns.BoardRibbons({ mode = "board" }))

		assert.are.same({ "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide" }, sets)
	end)

	it("give a set whose only Hunt is Retired its ribbon once that Hunt is done (HNT-R3)", function()
		local run = start({ list = bygoneAndAhead })
		useState(run, { fixture_bygone_trout = reached(1) })

		local sets = setsOf(run.ns.BoardRibbons({ mode = "board" }))

		assert.are.same({ "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide", "fixture_bygone" }, sets)
	end)

	it("give a set with an earned title its ribbon, though none of its Hunts is current (HNT-R20)", function()
		local run = start({ list = bygoneAndAhead })
		useState(run, {}, { fixture_ahead = { earnedAt = JAN_1, date = { year = 2026, month = 1, day = 1 } } })

		local sets = setsOf(run.ns.BoardRibbons({ mode = "board" }))

		assert.are.same({ "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide", "fixture_ahead" }, sets)
	end)

	it("show only the sets with a current Hunt while the projection is updating (HNT-R69)", function()
		local run = start({ list = bygoneAndAhead })
		useState(run, { fixture_bygone_trout = reached(1) }, {
			fixture_ahead = { earnedAt = JAN_1, date = { year = 2026, month = 1, day = 1 } },
		}, true)

		local sets = setsOf(run.ns.BoardRibbons({ mode = "board" }))

		assert.are.same({ "fixture_dusk", "fixture_wagers", "fixture_pair", "fixture_tide" }, sets)
	end)

	it("stack the last word of the set's name, and keep the full name for the tooltip", function()
		local run = start()

		local dusk = run.ns.BoardRibbons({ mode = "board" })[2]

		assert.are.same({ "Dusk", "Dusk" }, { dusk.text, dusk.name })
		assert.are.equal("Wagers", run.ns.RibbonWord("House Wagers"))
	end)

	it("choose Board on the Board, and a set's ribbon on its page and on the entries opened from it", function()
		local run = start()
		local function chosen(place)
			for _, ribbon in ipairs(run.ns.BoardRibbons(place)) do
				if ribbon.chosen then
					return ribbon.set or "board"
				end
			end
		end

		assert.are.equal("board", chosen({ mode = "board", hunt = "fixture_eel" }))
		assert.are.equal("fixture_pair", chosen({ mode = "set", set = "fixture_pair" }))
		assert.are.equal("fixture_pair", chosen({ mode = "entry", set = "fixture_pair", hunt = "fixture_eel" }))
		assert.are.equal("fixture_dusk", chosen({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" }))
	end)
end)

describe("the breadcrumbs (HNT-R61)", function()
	--- The crumbs' words and the places they go back to.
	local function crumbs(run, place)
		run.ns.board.router:Open(place)
		local out = {}
		for i, crumb in ipairs(run.ns.BoardCrumbs()) do
			out[i] = { crumb.text, crumb.place }
		end
		return out
	end

	it("read Hunts, the set, then the Hunt on an entry opened from a set's page, each going back up", function()
		local run = start()

		assert.are.same({
			{ "Hunts", { mode = "board" } },
			{ "Dusk", { mode = "set", set = "fixture_dusk" } },
			{ "Snapper Run", { mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" } },
		}, crumbs(run, { mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }))
	end)

	it("read Hunts then the set on a set's page, and Hunts then the selected Hunt on the Board", function()
		local run = start()

		assert.are.same({
			{ "Hunts", { mode = "board" } },
			{ "Wagers", { mode = "set", set = "fixture_wagers" } },
		}, crumbs(run, { mode = "set", set = "fixture_wagers" }))
		assert.are.same({
			{ "Hunts", { mode = "board" } },
			{ "Oddity Hour", { mode = "board", hunt = "fixture_oddity" } },
		}, crumbs(run, { mode = "board", hunt = "fixture_oddity" }))
	end)

	it("name a Retired Hunt's crumb on its retired entry, and fall back to IDs without lore (HNT-R1)", function()
		local run = start()

		assert.are.same({
			{ "Hunts", { mode = "board" } },
			{ "Dusk", { mode = "set", set = "fixture_dusk" } },
			{ "Old Sunscale", { mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" } },
		}, crumbs(run, { mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" }))
		assert.are.equal("fixture_rack", crumbs(run, { mode = "board", hunt = "fixture_rack" })[2][1])
	end)
end)

--- A set title as the projection keeps it (HNT-R23), earned on realm date `year`-`month`-`day`.
local function title(year, month, day)
	return { earnedAt = JAN_1, date = { year = year, month = month, day = day }, fromRetirement = false }
end

describe("the nameplate (HNT-R61)", function()
	it("reads the titles earned and the Hunts done, a done Retired Hunt counted", function()
		local run = start()
		useState(run, { fixture_snapper = reached(1), fixture_sunscale = reached(1), fixture_eel = reached(2) }, {
			fixture_pair = title(2026, 3, 12),
		})

		assert.are.equal("1 title · 3 Hunts done", run.ns.BoardNameplate().text)
	end)

	it("counts in the plural from 0 and in the singular at 1", function()
		local run = start()
		assert.are.equal("0 titles · 0 Hunts done", run.ns.BoardNameplate().text)

		useState(run, { fixture_squid = reached(1), fixture_oddity = reached(0) }, {
			fixture_dusk = title(2026, 2, 1),
			fixture_tide = title(2026, 6, 1),
		})
		assert.are.equal("2 titles · 1 Hunt done", run.ns.BoardNameplate().text)
	end)

	it("lists each earned title with its full date in its tooltip, in Hunt list order", function()
		local run = start()
		useState(run, {}, { fixture_tide = title(2026, 6, 1), fixture_dusk = title(2026, 2, 14) })

		assert.are.same(
			{ "the Duskwatcher, earned 14 Feb 2026", "fixture_tide, earned 1 Jun 2026" },
			run.ns.BoardNameplate().titles
		)
	end)

	it("reads the updating line, with no titles, while the projection is updating (HNT-R69)", function()
		local run = start()
		useState(run, { fixture_snapper = reached(1) }, { fixture_dusk = title(2026, 2, 14) }, true)

		local plate = run.ns.BoardNameplate()

		assert.are.same({ "Updating from your Catch log…", {} }, { plate.text, plate.titles })
	end)
end)

--- A checklist's lines as { name, done, when, mode of the place it opens }.
local function lines(list)
	local out = {}
	for i, line in ipairs(list) do
		out[i] = { line.name, line.done, line.when, line.place.mode }
	end
	return out
end

describe("a set's page, right side (HNT-R66)", function()
	-- FakePagle's realm clock reads 08:15 on Sunday 11 October 2026; the fixture's night is 20:00–06:00, and
	-- fixture_hefty_blackmouth's own hours 22:00–04:00, so both open later the same realm day (HNT-R51).
	it("shows the set's name, the title it earns, the line and the set's note", function()
		local run = start()

		local page = run.ns.BoardSetPage("fixture_dusk")

		assert.are.same(
			{ "Dusk", "Earns the title the Duskwatcher", "The first tier of every Hunt earns the title." },
			{
				page.name,
				page.titleLine,
				page.line,
			}
		)
		assert.are.equal("After the lamps are lit.", page.note)
		assert.is_nil(page.seal)
	end)

	it("shows Earned: {title} with a seal and the full date once the title is earned (HNT-R20)", function()
		local run = start()
		useState(run, {}, { fixture_dusk = title(2026, 3, 12) })

		local page = run.ns.BoardSetPage("fixture_dusk")

		assert.are.same({ "Earned: the Duskwatcher", "Title earned 12 Mar 2026" }, { page.titleLine, page.seal })
	end)

	it("fills the progress bar with the done current Hunts out of the current Hunts, Retired ones left out", function()
		local run = start()
		useState(run, { fixture_snapper = reached(2), fixture_sunscale = reached(1) })

		local progress = run.ns.BoardSetPage("fixture_dusk").progress

		assert.are.same({ 0.5, "1 / 2" }, { progress.fill, progress.label })
	end)

	it("lists every current Hunt with its seal date or its tracker label, whatever the filter (HNT-R82)", function()
		local run = start()
		-- fixture_snapper is finished (every tier reached), which the Board's filter would hide with "show completed"
		-- off (the default).
		useState(run, { fixture_snapper = reached(3, { year = 2026, month = 3, day = 12 }) })

		local page = run.ns.BoardSetPage("fixture_dusk")

		assert.are.same({
			{ "Snapper Run", true, "12 Mar", "entry" },
			{ "Hefty Blackmouth", false, "22:00", "entry" },
		}, lines(page.hunts))
		assert.are.same({ mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }, page.hunts[1].place)
	end)

	it("lists its done Retired Hunts under Retired, greyed, opening their retired entries (HNT-R3)", function()
		local run = start()
		useState(run, { fixture_sunscale = reached(1, { year = 2026, month = 2, day = 3 }) })

		local page = run.ns.BoardSetPage("fixture_dusk")

		assert.are.equal("Retired", page.retiredHeading)
		assert.are.same({ { "Old Sunscale", true, "3 Feb", "retired" } }, lines(page.retired))
		assert.are.same({ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" }, page.retired[1].place)
	end)

	it("leaves a Retired Hunt that isn't done off the page (HNT-R3)", function()
		local run = start()

		assert.are.same({}, run.ns.BoardSetPage("fixture_dusk").retired)
	end)

	it("reads the updating line on its progress, and nothing from the state, while updating (HNT-R69)", function()
		local run = start()
		useState(run, {
			fixture_snapper = reached(1, { year = 2026, month = 3, day = 12 }),
			fixture_sunscale = reached(1),
		}, { fixture_dusk = title(2026, 3, 12) }, true)

		local page = run.ns.BoardSetPage("fixture_dusk")

		assert.are.same({ 0, "Updating from your Catch log…" }, { page.progress.fill, page.progress.label })
		assert.are.same({ "Earns the title the Duskwatcher", nil }, { page.titleLine, page.seal })
		assert.are.same({
			{ "Snapper Run", false, "20:00", "entry" },
			{ "Hefty Blackmouth", false, "22:00", "entry" },
		}, lines(page.hunts))
		assert.are.same({}, page.retired)
	end)
end)

-- On the drawn board.

--- The texts of every shown widget under `widget`, depth first.
local function textsOf(widget, texts)
	texts = texts or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.text ~= nil and child.text ~= "" then
				texts[#texts + 1] = child.text
			end
			textsOf(child, texts)
		end
	end
	return texts
end

--- The first shown button under `widget` whose own texts include `text`, depth first.
local function buttonWith(widget, text)
	for _, child in ipairs(widget.children) do
		if child.shown then
			if child.kind == "Button" then
				for _, own in ipairs(textsOf(child)) do
					if own == text then
						return child
					end
				end
			end
			local found = buttonWith(child, text)
			if found then
				return found
			end
		end
	end
end

--- A word as a ribbon stacks it, a letter a line.
local function stacked(word)
	return (word:gsub("(.)", "%1\n"):sub(1, -2))
end

--- The board opened (HNT-R67), then turned to `place` if given.
local function opened(run, place)
	run.ns.ToggleBoard()
	if place then
		run.ns.board:Open(place)
	end
	return run.ns.board.frame
end

describe("the ribbons, crumbs and nameplate on the leather (HNT-R61)", function()
	it("hang Board and each set's ribbon, Board chosen when the board opens (HNT-R67)", function()
		local run = start()

		local ribbons = opened(run).anchors.ribbons

		assert.are.same(
			{ stacked("Board"), stacked("Dusk"), stacked("Wagers"), stacked("fixture_pair"), stacked("fixture_tide") },
			textsOf(ribbons)
		)
		assert.is_true(buttonWith(ribbons, stacked("Board")).chosen)
		assert.is_false(buttonWith(ribbons, stacked("Dusk")).chosen)
	end)

	it("open a set's page from its ribbon, and the Board from the Board ribbon (HNT-R66)", function()
		local run = start()
		local ribbons = opened(run).anchors.ribbons

		buttonWith(ribbons, stacked("Wagers")):Click()
		assert.are.same({ mode = "set", set = "fixture_wagers" }, run.ns.board.router:Place())
		assert.is_true(buttonWith(ribbons, stacked("Wagers")).chosen)

		buttonWith(ribbons, stacked("Board")):Click()
		-- the timeline then selects its Hunt on the Board (HNT-R67)
		assert.are.equal("board", run.ns.board.router:Place().mode)
	end)

	it("land on the Board ribbon whenever the board opens again (HNT-R67)", function()
		local run = start()
		opened(run, { mode = "set", set = "fixture_dusk" })
		run.ns.ToggleBoard()

		local ribbons = opened(run).anchors.ribbons

		assert.is_true(buttonWith(ribbons, stacked("Board")).chosen)
	end)

	it("show the set's full name in a ribbon's tooltip", function()
		local run = start()
		local ribbon = buttonWith(opened(run).anchors.ribbons, stacked("Dusk"))

		ribbon:GetScript("OnEnter")(ribbon)

		assert.are.same({ "Dusk" }, run.loaded.client.tooltipLines())
	end)

	it("write the crumbs Hunts › {set} › {Hunt} with a fleuron between, each going back up", function()
		local run = start()
		local crumbs = opened(run, { mode = "entry", set = "fixture_dusk", hunt = "fixture_snapper" }).anchors.crumbs

		assert.are.same({ "Hunts", "Dusk", "Snapper Run" }, textsOf(crumbs))
		local marks = 0
		for _, child in ipairs(crumbs.children) do
			if child.kind == "Texture" and child.shown and child.texture == run.ns.BOARD_TEXTURES.fleuron then
				marks = marks + 1
			end
		end
		assert.are.equal(2, marks)

		buttonWith(crumbs, "Dusk"):Click()
		assert.are.same({ mode = "set", set = "fixture_dusk" }, run.ns.board.router:Place())
		assert.are.same({ "Hunts", "Dusk" }, textsOf(crumbs))

		buttonWith(crumbs, "Hunts"):Click()
		-- the timeline then selects its Hunt on the Board (HNT-R67)
		assert.are.equal("board", run.ns.board.router:Place().mode)
	end)

	it("write the nameplate, with each earned title and its full date in its tooltip", function()
		local run = start()
		useState(run, { fixture_snapper = reached(1) }, { fixture_dusk = title(2026, 2, 14) })
		local nameplate = opened(run).anchors.nameplate

		assert.are.same({ "1 title · 1 Hunt done" }, textsOf(nameplate))
		local plate = nameplate.children[1]
		plate:GetScript("OnEnter")(plate)

		assert.are.same(
			{ "1 title · 1 Hunt done", "the Duskwatcher, earned 14 Feb 2026" },
			run.loaded.client.tooltipLines()
		)
		assert.is_true(run.loaded.env.GameTooltip.shown)
		plate:GetScript("OnLeave")(plate)
		assert.is_false(run.loaded.env.GameTooltip.shown)
	end)

	it("write the updating line on the nameplate while the projection updates, and redraw when it is done", function()
		local run = start()
		useState(run, { fixture_snapper = reached(1) }, {}, true)
		local nameplate = opened(run).anchors.nameplate
		assert.are.same({ "Updating from your Catch log…" }, textsOf(nameplate))

		useState(run, { fixture_snapper = reached(1) }, {}, false)
		run.ns.Redraw("projection")

		assert.are.same({ "0 titles · 1 Hunt done" }, textsOf(nameplate))
	end)
end)

describe("a set's page on the board (HNT-R66)", function()
	--- The set mode's right page.
	local function rightPage(run)
		return run.ns.board.pages["set:right"]
	end

	it("writes the name, the title earned with its seal, the progress, the line, the note and the checklist", function()
		local run = start()
		useState(run, {
			fixture_snapper = reached(1, { year = 2026, month = 3, day = 12 }),
			fixture_sunscale = reached(1, { year = 2026, month = 2, day = 3 }),
		}, { fixture_dusk = title(2026, 3, 12) })
		opened(run, { mode = "set", set = "fixture_dusk" })

		local texts = textsOf(rightPage(run))
		assert.are.same({
			"Title earned 12 Mar 2026",
			"Dusk",
			"Earned: the Duskwatcher",
			"1 / 2",
			"The first tier of every Hunt earns the title.",
			"After the lamps are lit.",
		}, { unpack(texts, 1, 6) })
		assert.are.same({ "Snapper Run", "12 Mar" }, textsOf(buttonWith(rightPage(run), "Snapper Run")))
		assert.are.same({ "Hefty Blackmouth", "22:00" }, textsOf(buttonWith(rightPage(run), "Hefty Blackmouth")))
		assert.are.same({ "Old Sunscale", "3 Feb" }, textsOf(buttonWith(rightPage(run), "Old Sunscale")))
		-- and the "Retired" heading, in small caps, below the current Hunts and above the Retired ones
		assert.are.equal(13, #texts)
		local heading
		for _, child in ipairs(rightPage(run).children) do
			if child.text == "RETIRED" and child.shown then
				heading = child
			end
		end
		local function top(widget)
			return widget.points[1][3]
		end
		assert.is_true(top(heading) < top(buttonWith(rightPage(run), "Hefty Blackmouth")))
		assert.is_true(top(heading) > top(buttonWith(rightPage(run), "Old Sunscale")))
	end)

	it("greys its Retired Hunts", function()
		local run = start()
		useState(run, { fixture_sunscale = reached(1) })
		opened(run, { mode = "set", set = "fixture_dusk" })

		local retired = buttonWith(rightPage(run), "Old Sunscale")
		local current = buttonWith(rightPage(run), "Snapper Run")

		assert.is_true(retired:GetAlpha() < current:GetAlpha())
	end)

	it("hides the seal until the title is earned, and fills the ink bar with the set's progress", function()
		local run = start()
		useState(run, { fixture_snapper = reached(1) })
		opened(run, { mode = "set", set = "fixture_dusk" })

		local texts = textsOf(rightPage(run))
		assert.are.same({ "Dusk", "Earns the title the Duskwatcher", "1 / 2" }, { unpack(texts, 1, 3) })
		local bar
		for _, child in ipairs(rightPage(run).children) do
			if child.SetBar then
				bar = child
			end
		end
		assert.are.equal(0.5, bar.value)
	end)

	it("opens a Hunt's entry from its line, and a Retired Hunt's retired entry (HNT-R66, HNT-R3)", function()
		local run = start()
		useState(run, { fixture_sunscale = reached(1) })
		opened(run, { mode = "set", set = "fixture_dusk" })

		buttonWith(rightPage(run), "Hefty Blackmouth"):Click()
		assert.are.same(
			{ mode = "entry", set = "fixture_dusk", hunt = "fixture_hefty_blackmouth" },
			run.ns.board.router:Place()
		)

		run.ns.board:Open({ mode = "set", set = "fixture_dusk" })
		buttonWith(rightPage(run), "Old Sunscale"):Click()
		assert.are.same(
			{ mode = "retired", set = "fixture_dusk", hunt = "fixture_sunscale" },
			run.ns.board.router:Place()
		)
	end)

	it("writes the updating line on the progress while the projection updates (HNT-R69)", function()
		local run = start()
		useState(run, { fixture_snapper = reached(1) }, {}, true)
		opened(run, { mode = "set", set = "fixture_dusk" })

		local texts = textsOf(rightPage(run))

		assert.are.equal("Updating from your Catch log…", texts[3])
	end)
end)
