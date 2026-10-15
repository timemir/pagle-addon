-- Stats' section on the Trackers page (stats.md › Settings; SET-R3, SET-R5, SET-R42, SET-R44, SET-R45, SET-R60;
-- CORE-R42): its rows as Core gets them on FakePagle, and the page drawn in the fake client's Settings panel by the
-- real Core, with the Watched Dry spells row on Stats' own template (SET-R5).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local stats = dofile("spec/Pagle_Stats/support.lua")

local I = stats.IDS
local DARKSHORE, AUBERDINE, NIGHTFIN, FIREFIN = I.DARKSHORE, I.AUBERDINE, I.NIGHTFIN, I.FIREFIN

local NONE = "Watch a Dry spell from any fish's page in the Stats book."
local STOP = "Stop watching"

-- The Trackers page's rows from Modules, as Core builds it, without Core's slot rows (SET-R44: Stats' frame dropdown
-- comes with its slot, adapter/Goods.lua): "<kind> <label>", with "  " before an indented one.
local function section(fake)
	local out = {}
	for _, row in ipairs(assert(fake.settingsPage("trackers"), "no Trackers page")) do
		if row.kind ~= "slot" then
			out[#out + 1] = ("%s%s %s"):format(row.indented and "  " or "", row.kind, row.label)
		end
	end
	return out
end

-- The Trackers row labelled `label`, as FakePagle lists it.
local function rowLabelled(fake, label)
	for _, row in ipairs(fake.settingsPage("trackers")) do
		if row.label == label then
			return row
		end
	end
	error("no row " .. label)
end

describe("Stats' section on Trackers, as Core gets it", function()
	it("is a Stats header, the checkbox and the indented Watched Dry spells row (SET-R42, SET-R3, CORE-R42)", function()
		local _, fake = stats.load()
		fake.login()

		assert.are.same({
			"header Stats",
			"checkbox Show the live tracker",
			"  custom Watched Dry spells",
		}, section(fake))
	end)

	it("its checkbox is off by default and holds profile.tracker, with its tooltip (SET-R42, STA-R81)", function()
		local loaded, fake = stats.load()
		fake.login()
		local checkbox = rowLabelled(fake, "Show the live tracker").setting

		assert.are.equal("tracker", checkbox.id)
		assert.is_false(checkbox.default)
		assert.is_false(checkbox.get())
		checkbox.set(true)
		assert.is_true(loaded.ns.db.profile.tracker)
		assert.is_true(checkbox.get())
		assert.are.equal(
			"Shows this Session and your watched Dry spells under the minimap. Watching a Dry spell turns it on.",
			checkbox.tooltip
		)
	end)

	it("reads the tracker a watch turned on, the next time the page draws it (STA-R62, SET-R62)", function()
		local loaded, fake = stats.load()
		fake.login()

		loaded.ns.Watch(NIGHTFIN, DARKSHORE)

		assert.is_true(rowLabelled(fake, "Show the live tracker").setting.get())
	end)

	it(
		"its Watched Dry spells row hangs under the checkbox, is never greyed out and has no default (SET-R42)",
		function()
			local _, fake = stats.load()
			fake.login()
			local row = rowLabelled(fake, "Watched Dry spells").setting

			assert.are.equal("tracker", row.parent)
			assert.is_nil(row.isEnabled)
			assert.is_nil(row.default)
			assert.are.equal("Watch or stop watching from any fish's page in the Stats book.", row.tooltip)
		end
	)

	it("is gone while Stats is inert: no rows, so no Trackers page (STA-R90, CORE-R13, CORE-R42)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_Stats.metadata["X-Pagle-API"] = "2"
		stats.load(fake)
		fake.login()

		assert.is_nil(fake.settingsPage("trackers"))
		assert.are.same({ "Pagle: Pagle Stats needs a newer Pagle." }, fake.printed)
	end)
end)

-- Core with Stats, logged in, with the names the rows read: Nightfin and Firefin, and the fixture's areas.
local function coreWithStats()
	local loaded = loadAddon("Pagle_Stats", FOREVER_GLOBALS)
	stats.nameAll(loaded, { NIGHTFIN, FIREFIN })
	loaded.client.fire("PLAYER_LOGIN")
	return loaded
end

-- The Trackers page drawn in the panel.
local function showTrackers(loaded)
	return loaded.client.settings.show(loaded.client.settings.page("Trackers"))
end

-- What a drawn row shows.
local function texts(loaded, row)
	return loaded.client.settings.textsOf(row.frame)
end

-- The "Stop watching" buttons a drawn row shows.
local function stopButtons(loaded, row)
	local buttons = {}
	for _, button in ipairs(loaded.client.settings.buttonsOf(row.frame)) do
		if button.text == "Stop watching" then
			buttons[#buttons + 1] = button
		end
	end
	return buttons
end

describe("Stats' section on the Trackers page, in the panel", function()
	it(
		"follows Core's row: a Stats header, the checkbox off, the indented row, the frame (SET-R40, SET-R42, SET-R44)",
		function()
			local loaded = coreWithStats()
			local rows = showTrackers(loaded)

			local names = {}
			for i, row in ipairs(rows) do
				names[i] = (row.initializer:GetParentInitializer() and "  " or "") .. row.initializer:GetName()
			end
			-- Core ends the section with Stats' frame dropdown, unindented (SET-R44).
			assert.are.same(
				{ "Tracker position", "Stats", "Show the live tracker", "  Watched Dry spells", "Stats tracker frame" },
				names
			)
			assert.is_false(loaded.client.settings.rowNamed(rows, "Show the live tracker").frame.value)
		end
	)

	it('reads "0 of 3" and the line for none, with no watches (SET-R42)', function()
		local loaded = coreWithStats()

		local row = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")

		assert.are.same({ "Watched Dry spells", "0 of 3", NONE }, texts(loaded, row))
		assert.are.same({}, stopButtons(loaded, row))
	end)

	it("lists each watch oldest first, by the watched area's own name, with its button (SET-R42, STA-R60)", function()
		local loaded = coreWithStats()
		loaded.ns.Watch(NIGHTFIN, DARKSHORE)
		loaded.ns.Watch(FIREFIN, AUBERDINE)

		local row = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")

		assert.are.same({
			"Watched Dry spells",
			"2 of 3",
			"Raw Nightfin Snapper, Darkshore",
			STOP,
			"Firefin Snapper, Auberdine",
			STOP,
		}, texts(loaded, row))
		assert.are.equal(2, #stopButtons(loaded, row))
	end)

	it(
		"redraws at once, within its height, when a watch is added while it shows (SET-R6, SET-R62, stats.md › Settings)",
		function()
			local loaded = coreWithStats()
			local row = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")

			loaded.ns.Watch(FIREFIN, AUBERDINE)

			assert.are.same({ "Watched Dry spells", "1 of 3", "Firefin Snapper, Auberdine", STOP }, texts(loaded, row))
		end
	)

	it('"Stop watching" removes that watch and its line, leaving the tracker on (STA-R63)', function()
		local loaded = coreWithStats()
		loaded.ns.Watch(NIGHTFIN, DARKSHORE)
		loaded.ns.Watch(FIREFIN, AUBERDINE)
		local row = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")

		stopButtons(loaded, row)[1]:Click()

		assert.are.same({ "Watched Dry spells", "1 of 3", "Firefin Snapper, Auberdine", STOP }, texts(loaded, row))
		assert.are.equal(1, #stopButtons(loaded, row))
		assert.is_false(loaded.ns.IsWatched(NIGHTFIN, DARKSHORE))
		assert.is_true(loaded.ns.db.profile.tracker)
		stopButtons(loaded, row)[1]:Click()
		assert.are.same({ "Watched Dry spells", "0 of 3", NONE }, texts(loaded, row))
		assert.is_true(loaded.ns.db.profile.tracker)
	end)

	it("is never greyed out while the checkbox is off (SET-R42, stats.md › Settings)", function()
		local loaded = coreWithStats()
		loaded.ns.Watch(NIGHTFIN, DARKSHORE)
		local rows = showTrackers(loaded)
		local checkbox = loaded.client.settings.rowNamed(rows, "Show the live tracker")

		checkbox.initializer:GetSetting():SetValue(false)

		-- Nothing to grey it by, and its buttons take clicks, drawn now and again. The fake panel greys only Blizzard's
		-- native controls, as the client does (#120).
		local row = loaded.client.settings.rowNamed(rows, "Watched Dry spells")
		assert.are.same({}, row.initializer.modifyPredicates)
		local redrawn = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")
		for _, drawn in ipairs({ row, redrawn }) do
			local buttons = stopButtons(loaded, drawn)
			assert.are.equal(1, #buttons)
			assert.is_true(buttons[1]:IsEnabled())
		end
	end)

	it("is found by Blizzard's settings search by its label (SET-R5)", function()
		local loaded = coreWithStats()

		local row = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")

		assert.are.same({ "WATCHED DRY SPELLS" }, row.initializer.searchTags)
	end)

	it("shows its tooltip on hover (stats.md › Settings)", function()
		local loaded = coreWithStats()
		local row = loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")

		row.frame:GetScript("OnEnter")(row.frame)

		local tooltip = loaded.env.GameTooltip
		assert.are.same({ row.frame, "ANCHOR_RIGHT", true }, { tooltip.owner, tooltip.anchor, tooltip.shown })
		assert.are.same(
			{ "Watched Dry spells", "Watch or stop watching from any fish's page in the Stats book." },
			loaded.client.tooltipLines()
		)
		row.frame:GetScript("OnLeave")(row.frame)
		assert.is_false(tooltip.shown)
	end)

	it("the page's Defaults turns the checkbox off and keeps the watches (SET-R45, SET-R60)", function()
		local loaded = coreWithStats()
		loaded.ns.Watch(NIGHTFIN, DARKSHORE)
		loaded.ns.Watch(FIREFIN, AUBERDINE)
		local rows = showTrackers(loaded)

		loaded.client.settings.defaults(loaded.client.settings.page("Trackers"))

		assert.is_false(loaded.ns.db.profile.tracker)
		assert.is_false(loaded.client.settings.rowNamed(rows, "Show the live tracker").frame.value)
		assert.are.same({
			"Watched Dry spells",
			"2 of 3",
			"Raw Nightfin Snapper, Darkshore",
			STOP,
			"Firefin Snapper, Auberdine",
			STOP,
		}, texts(loaded, loaded.client.settings.rowNamed(showTrackers(loaded), "Watched Dry spells")))
	end)
end)
