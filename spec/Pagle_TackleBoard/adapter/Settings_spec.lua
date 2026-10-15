-- The Tackle Board's section on the Trackers page (SET-R43, tackle-board.md › Settings; SET-R3, SET-R5, SET-R44,
-- SET-R45, SET-R60, SET-R61; CORE-R42): its rows as Core gets them on FakePagle, and the page drawn in the fake
-- client's Settings panel by the real Core.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local board = dofile("spec/Pagle_TackleBoard/support.lua")

local SLOT = "tackleboard.trackerframe"
local CHECKBOX = "Show goals workable here"
local FRAME = "Tackle Board tracker frame"
local TOOLTIP =
	"Lists the goals you can work on where you are. Before your board is started, use Start my board on the Pagle page."

-- The Tackle Board's rows on Trackers, as Core builds the page: "<kind> <label>", with "  " before an indented one.
local function section(fake)
	local out = {}
	for _, row in ipairs(assert(fake.settingsPage("trackers"), "no Trackers page")) do
		if row.module == "TackleBoard" then
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

-- The board loaded, logged in and in the world, its projection's first build done, with the fixture Angler's skill.
local function ready()
	local loaded, fake = board.load()
	fake.login()
	fake.enterWorld()
	board.readSkill(fake)
	return loaded, fake
end

describe("The Tackle Board's section on Trackers, as Core gets it", function()
	it(
		'is a "Tackle Board" header, "Show goals workable here", then Core\'s "Tackle Board tracker frame", unindented (SET-R43, SET-R44, SET-R3)',
		function()
			local _, fake = board.load()
			fake.login()

			assert.are.same({
				"header Tackle Board",
				"checkbox " .. CHECKBOX,
				"slot " .. FRAME,
			}, section(fake))
			assert.are.equal(SLOT, rowLabelled(fake, FRAME).slot)
		end
	)

	it("its checkbox is on by default and holds profile.tracker, with its tooltip (SET-R43, TKB-R120)", function()
		local loaded, fake = board.load()
		fake.login()
		local checkbox = rowLabelled(fake, CHECKBOX).setting

		assert.are.equal("tracker", checkbox.id)
		assert.is_true(checkbox.default)
		assert.is_true(checkbox.get())
		checkbox.set(false)
		assert.is_false(loaded.ns.db.profile.tracker)
		assert.is_false(checkbox.get())
		assert.are.equal(TOOLTIP, checkbox.tooltip)
	end)

	it("its checkbox is greyed out until the board is started, then live (SET-R43, SET-R61, TKB-R5)", function()
		local loaded, fake = ready()
		local checkbox = rowLabelled(fake, CHECKBOX).setting

		assert.is_false(checkbox.isEnabled())

		loaded.ns.Start()

		assert.is_true(loaded.ns.IsStarted())
		assert.is_true(checkbox.isEnabled())
		assert.are.equal(TOOLTIP, checkbox.tooltip) -- the same tooltip, always
	end)

	it("is gone while the Tackle Board is inert: no rows, so no Trackers page (CORE-R13, CORE-R42)", function()
		local fake = newFakePagle()
		fake.addons.Pagle_TackleBoard.metadata["X-Pagle-API"] = "2"
		board.load(fake)
		fake.login()

		assert.is_nil(fake.settingsPage("trackers"))
		assert.are.same({ "Pagle: Pagle Tackle Board needs a newer Pagle." }, fake.printed)
	end)

	it(
		"is gone while the Tackle Board is disabled, and the frame falls back to No frame, keeping the pick, which comes back with it (SHOP-R32, SHOP-R90, CORE-R17)",
		function()
			local _, first = board.load()
			first.login()
			first.setPurchased({ ["tackleboard.trackerframe.corkboard"] = true })
			assert.is_true(first.Pagle.SetEquipped(SLOT, "tackleboard.trackerframe.corkboard"))

			-- The next session, the Tackle Board disabled: it runs no code, so it registers nothing (CORE-R17).
			local off = newFakePagle()
			off.global.goods = first.global.goods
			off.goods = off.global.goods
			off.profile.appearance = first.profile.appearance
			off.setPurchased({ ["tackleboard.trackerframe.corkboard"] = true })
			off.login()

			assert.is_nil(off.settingsPage("trackers"))
			assert.are.equal("tackleboard.trackerframe.none", off.Pagle.GetEquipped(SLOT))
			assert.are.equal("tackleboard.trackerframe.corkboard", off.profile.appearance[SLOT])

			-- Enabled again: Corkboard is equipped with no SetEquipped.
			local on = newFakePagle()
			on.global.goods = first.global.goods
			on.goods = on.global.goods
			on.profile.appearance = off.profile.appearance
			on.setPurchased({ ["tackleboard.trackerframe.corkboard"] = true })
			board.load(on)
			on.login()

			assert.are.equal("tackleboard.trackerframe.corkboard", on.Pagle.GetEquipped(SLOT))
		end
	)
end)

-- The Trackers page in the panel, drawn by the real Core.
local function trackersPage(loaded)
	return assert(loaded.client.settings.category("Trackers"), "no Trackers page")
end

local function showTrackers(loaded)
	return loaded.client.settings.show(trackersPage(loaded))
end

-- Each shown row's name, with "  " before an indented one.
local function names(rows)
	local out = {}
	for i, row in ipairs(rows) do
		out[i] = (row.initializer:GetParentInitializer() and "  " or "") .. row.initializer:GetName()
	end
	return out
end

-- The drawn row named `label`.
local function rowNamed(rows, label)
	for _, row in ipairs(rows) do
		if row.initializer:GetName() == label then
			return row
		end
	end
	error("no row " .. label)
end

describe("The Tackle Board's section on the Trackers page, in the panel", function()
	it(
		"follows Core's Tracker position: the header, the checkbox, then the frame, unindented and never greyed out (SET-R40, SET-R43, SET-R44)",
		function()
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			enterWorld(loaded, 1)

			local rows = showTrackers(loaded)

			assert.are.same({ "Tracker position", "Tackle Board", CHECKBOX, FRAME }, names(rows))
			local frame = rowNamed(rows, FRAME)
			local dropdown = loaded.client.settings.dropdownOf(frame) -- Core's slot row (SET-R6, SET-R44)
			assert.is_true(dropdown:IsEnabled())
			assert.are.equal("tackleboard.trackerframe.none", dropdown.selected)
			assert.are.equal(TOOLTIP, rowNamed(rows, CHECKBOX).initializer:GetTooltip())
		end
	)

	it(
		"lists only the owned frames in its frame dropdown, No frame to start with (SET-R44, SET-R51, SHOP-R30)",
		function()
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			enterWorld(loaded, 1)

			local frame = rowNamed(showTrackers(loaded), FRAME)

			assert.are.same({ "tackleboard.trackerframe.none=No Frame" }, loaded.client.settings.optionValues(frame))
			assert.are.same({ "2 more in the Curio Shop" }, loaded.client.settings.notesOf(frame))
		end
	)

	it(
		"greys the checkbox out before Start, and draws it live the next time the page shows after Start (SET-R43, SET-R61, TKB-R5)",
		function()
			local loaded = loadAddon("Pagle_TackleBoard", FOREVER_GLOBALS)
			enterWorld(loaded, 1) -- the projection's first build has ended: not updating (LOG-R74)

			local before = rowNamed(showTrackers(loaded), CHECKBOX)
			assert.is_false(before.frame.enabled)
			assert.is_true(before.frame.value) -- greyed out, still on

			loaded.ns.Start()

			assert.is_true(loaded.ns.IsStarted())
			assert.is_true(rowNamed(showTrackers(loaded), CHECKBOX).frame.enabled)
		end
	)

	it(
		"Defaults turns the checkbox back on and the frame back to No frame while greyed out, keeping the frame owned (SET-R45, SET-R60)",
		function()
			-- Corkboard bought in the log (LOG-R39, SHOP-R11).
			local entries = history(0)
			entries[#entries + 1] = purchaseEntry(SERVER_TIME - 2000, "tackleboard.trackerframe.corkboard", 150)
			local loaded = loadAddon("Pagle_TackleBoard", foreverWith({ PagleLog = savedLog(entries) }))
			enterWorld(loaded, 3)
			assert.is_true(loaded.env.Pagle.SetEquipped(SLOT, "tackleboard.trackerframe.corkboard"))
			loaded.ns.db.profile.tracker = false -- greyed out: the board isn't started
			assert.is_false(rowNamed(showTrackers(loaded), CHECKBOX).frame.enabled)

			loaded.client.settings.defaults(trackersPage(loaded))

			assert.is_true(loaded.ns.db.profile.tracker)
			assert.are.equal("tackleboard.trackerframe.none", loaded.env.Pagle.GetEquipped(SLOT))
			assert.is_true(loaded.env.Pagle.IsOwned("tackleboard.trackerframe.corkboard"))
		end
	)
end)
