-- The export window as data (paste-string.md PST-R15, PST-R20, PST-R21, PST-R50, PST-R51, PST-R60): the view for a
-- choice, the lines under a part's string, its part line, and Pagle.OpenPasteExport over its seams.

local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

local LOG_ID = "3f9a2c1e7b0d4a65"
local AS_OF = 1791735100

-- A PagleLog table with Ada and `n` Skill Readings.
local function log(n)
	local entries = {}
	for i = 1, n do
		entries[i] = ("S1|1|%d|0|%d|150|0"):format(1791735000 + i, i)
	end
	return savedLog(entries)
end

describe("ns.PasteView (PST-R20, PST-R21, PST-R15)", function()
	it("exports from 1 for Everything and for New since last export with no mark", function()
		for _, choice in ipairs({ "everything", "new" }) do
			local view = ns.PasteView(log(3), {}, choice, AS_OF)
			assert.are.equal(choice, view.choice)
			assert.is_nil(view.message)
			local export = assert(view.export)
			assert.are.equal(AS_OF, export.asOf)
			assert.are.equal(3, export.total)
			assert.are.same({ { from = 1, count = 3, anchor = "" } }, export.parts)
		end
	end)

	it("exports New since last export from one after the mark, and says Nothing new past the end", function()
		local view = ns.PasteView(log(3), { [LOG_ID] = 1 }, "new", AS_OF)
		assert.are.equal(2, assert(view.export).parts[1].from)

		local nothing = ns.PasteView(log(3), { [LOG_ID] = 3 }, "new", AS_OF)
		assert.is_nil(nothing.export)
		assert.are.equal("Nothing new since your last export.", nothing.message)
		assert.are.equal(1, assert(ns.PasteView(log(3), { [LOG_ID] = 3 }, "everything", AS_OF).export).parts[1].from)
	end)

	it("says Nothing new for an empty log on New since, and makes one empty part for Everything", function()
		assert.are.equal("Nothing new since your last export.", ns.PasteView(log(0), {}, "new", AS_OF).message)
		assert.are.same(
			{ { from = 1, count = 0, anchor = "" } },
			assert(ns.PasteView(log(0), {}, "everything", AS_OF).export).parts
		)
	end)

	it("says Pagle can't export this Catch log for a log it can't (PST-R15)", function()
		local broken = log(2)
		broken.characters[1].guid = "Player-1-zz"
		assert.are.equal("Pagle can't export this Catch log.", ns.PasteView(broken, {}, "everything", AS_OF).message)
	end)
end)

describe("The lines under a part's string (PST-R51, PST-R60)", function()
	it("give the part's entries of the total and its size in KB, rounded up, and the note with parts", function()
		local view = ns.PasteView(log(12), {}, "everything", AS_OF)
		assert(view.export).parts = {
			{ from = 1, count = 5000, anchor = "" },
			{ from = 5001, count = 7, anchor = "x" },
		}
		view.export.total = 5007

		assert.are.same(
			{ "Entries 1–5,000 of 5,007  ·  129 KB", "Paste each part on its own, in order." },
			ns.PastePartLines(view, 1, 128 * 1024 + 1, breakUpLargeNumbers)
		)
		assert.are.equal("Part 2 of 2", ns.PastePartLabel(2, 2))
		assert.is_nil(ns.PastePartLabel(1, 1))
	end)

	it("give No entries for a part with none, and no note for one part", function()
		local view = ns.PasteView(log(0), {}, "everything", AS_OF)
		assert.are.same({ "No entries  ·  1 KB" }, ns.PastePartLines(view, 1, 40, breakUpLargeNumbers))
	end)

	it("give Copy test: n KB for the copy test, one part", function()
		local view = assert(ns.PasteTestView(64))
		assert.are.equal(1, ns.PastePartCount(view))
		assert.are.same({ "Copy test: 64 KB" }, ns.PastePartLines(view, 1, 65536, breakUpLargeNumbers))
		assert.is_nil(ns.PasteTestView(0))
	end)
end)

describe("ns.OpenPasteExportFunction (PST-R50)", function()
	it("prints the after-combat line while restricted, and otherwise shows New since last export", function()
		local printed, shown, restricted = {}, {}, true
		local open = ns.OpenPasteExportFunction({
			isRestricted = function()
				return restricted
			end,
			print = function(line)
				printed[#printed + 1] = line
			end,
			view = function(choice)
				return { choice = choice }
			end,
			show = function(view)
				shown[#shown + 1] = view
			end,
		})

		open()
		assert.are.same({ "Pagle: the export window opens after combat." }, printed)
		assert.are.same({}, shown)

		restricted = false
		open()
		assert.are.same({ { choice = "new" } }, shown)
	end)
end)
