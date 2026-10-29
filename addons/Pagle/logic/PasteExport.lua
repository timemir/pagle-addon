---@class PagleNS
local ns = select(2, ...)

-- The export window as data (paste-string.md › The export window, › The copy test): what it shows for a choice, the
-- lines under the string, and Pagle.OpenPasteExport over its seams. Pure logic, everything passed in (CORE-R7);
-- adapter/PasteExport.lua draws the window and builds each part's Paste string as it is shown (PST-R33).

--- The window's two choices (PST-R51): "New since last export", which it opens on, and "Everything".
---@alias PaglePasteChoice "new"|"everything"
ns.PASTE_CHOICES = { "new", "everything" }

--- What the window shows, built when it opens and when a choice is picked (PST-R52).
---@class PaglePasteView
---@field choice PaglePasteChoice? the choice it was built for; nil for the copy test's
---@field export PaglePasteExport? the export whose parts it shows; nil with a message or the copy test
---@field message string?          PST-R15's or PST-R21's line, shown instead of a string
---@field test string?             the copy test's string (PST-R60), shown as the one part
---@field testKB integer?          its size, in KB
---@field pending thread?          client preparation, resumed between frames

--- What the window shows for `choice` over `log` (a PagleLog table) now (PST-R20, PST-R21): an export from 1 for
--- "everything", or from one after the log's last exported seq in `marks` (PagleDB.global.pasteExports) for "new",
--- with "Nothing new since your last export." when that is past the log's end, and "Pagle can't export this Catch
--- log." when Core can't (PST-R15).
---@param log table PagleLog
---@param marks table? PagleDB.global.pasteExports
---@param choice PaglePasteChoice
---@param asOf integer GetServerTime() now
---@param pause fun()?
---@param checkpoints table? PagleDB.global.pasteCheckpoints (PST-R42)
---@return PaglePasteView
function ns.PasteView(log, marks, choice, asOf, pause, checkpoints)
	local L = ns.L
	local from = 1
	if choice == "new" then
		from = ns.PasteNewFrom(marks, log.logId)
		if type(log.entries) == "table" and from > #log.entries then
			return { choice = choice, message = L.PASTE_NOTHING_NEW }
		end
	end
	local export = ns.PasteExport(log, from, asOf, nil, pause, checkpoints)
	if not export then
		return { choice = choice, message = L.PASTE_CANT_EXPORT }
	end
	return { choice = choice, export = export }
end

--- The copy test's view (PST-R60): a test string of `kb` KB as the one part, with no choice picked. Nil for a size
--- out of range.
---@param kb integer
---@return PaglePasteView?
function ns.PasteTestView(kb)
	local test = ns.PasteTestString(kb)
	if not test then
		return nil
	end
	return { test = test, testKB = kb }
end

--- How many parts `view` shows: its export's, 1 for the copy test, none with a message.
---@param view PaglePasteView
---@return integer
function ns.PastePartCount(view)
	if view.test then
		return 1
	elseif view.export then
		return #view.export.parts
	end
	return 0
end

--- "Part N of M" for part `n` of `m`, or nil when there is one part, so the part controls hide (PST-R51).
---@param n integer
---@param m integer
---@return string?
function ns.PastePartLabel(n, m)
	if m <= 1 then
		return nil
	end
	return ns.L.PASTE_PART:format(n, m)
end

--- The lines under part `n`'s string (PST-R51): "Entries 1–5,000 of 12,345 · 131 KB" ("No entries" for a part with
--- none), then "Paste each part on its own, in order." when there is more than one part. The copy test's has
--- "Copy test: 64 KB" (PST-R60).
---@param view PaglePasteView
---@param n integer
---@param length integer the part's Paste string's length, in bytes
---@param formatNumber fun(n: number): string writes a count (BreakUpLargeNumbers)
---@return string[]
function ns.PastePartLines(view, n, length, formatNumber)
	local L = ns.L
	if view.test then
		return { L.PASTE_TEST_LINE:format(view.testKB) }
	end
	local export = assert(view.export)
	local part = export.parts[n]
	local entries = L.PASTE_NO_ENTRIES
	if part.count > 0 then
		entries = L.PASTE_ENTRIES:format(
			formatNumber(part.from),
			formatNumber(part.from + part.count - 1),
			formatNumber(export.total)
		)
	end
	local lines = { L.PASTE_PART_LINE:format(entries, L.PASTE_SIZE:format(math.ceil(length / 1024))) }
	if #export.parts > 1 then
		lines[2] = L.PASTE_IN_ORDER
	end
	return lines
end

--- What Pagle.OpenPasteExport is handed: where Core runs it (adapter/PasteExport.lua).
---@class PaglePasteSeams
---@field isRestricted fun(): boolean                 -- Pagle.IsRestricted()
---@field print fun(line: string)                     -- prints a chat line
---@field view fun(choice: PaglePasteChoice): PaglePasteView -- ns.PasteView over the log and PagleDB now
---@field show fun(view: PaglePasteView)              -- opens the window at part 1 with this view

--- Pagle.OpenPasteExport (PST-R50), which every entry point calls: while restricted it prints "Pagle: the export
--- window opens after combat." and opens nothing, leaving a window already open as it is (CORE-R33); otherwise it
--- makes an export now for "New since last export", the choice the window always opens on (PST-R51), and opens the
--- window with it.
---@param seams PaglePasteSeams
---@return fun()
function ns.OpenPasteExportFunction(seams)
	return function()
		if seams.isRestricted() then
			seams.print(ns.L.PASTE_AFTER_COMBAT)
			return
		end
		seams.show(seams.view("new"))
	end
end
