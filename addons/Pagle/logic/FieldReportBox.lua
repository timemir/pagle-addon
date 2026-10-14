---@class PagleNS
local ns = select(2, ...)

-- The Field report box and its entry points as data (field-report.md › The box and its entry points): what the box
-- shows when it opens, its part line, the compartment entry's and the Settings button's labels, and
-- Pagle.OpenFieldReport over its seams. Pure logic, everything passed in (CORE-R7); adapter/FieldReportBox.lua draws
-- the box, and FakePagle runs the same Pagle.OpenFieldReport over its fakes.

--- The issue form a Field report is pasted into (REP-R46).
ns.FIELD_REPORT_URL = "https://github.com/timemir/wow-fish/issues/new?template=field-report.yml"

--- What the report box shows, built when it opens and kept while it stays open (REP-R40–R42).
---@class PagleFieldReportView
---@field message string?   -- REP-R41's or REP-R42's line, shown instead of the text
---@field parts string[]    -- the report's parts, in order (REP-R33); none with a message
---@field url string?       -- the issue form (REP-R46); nil with a message

--- What the box shows for `rows` (ticket #121's ns.FieldReportRows(): nil while the projection is updating):
--- "Updating… try again in a moment." while it updates (REP-R42), "Nothing to report. Thanks for checking!" with
--- no row (REP-R41), and otherwise the report's parts from `text` (ns.FieldReportText) with the issue form's URL. The
--- URL goes with the text: with a message there's nothing to paste.
---@param rows table[]?
---@param text fun(rows: table[]): string[]
---@return PagleFieldReportView
function ns.FieldReportView(rows, text)
	if rows == nil then
		return { message = ns.L.REPORT_UPDATING, parts = {} }
	elseif #rows == 0 then
		return { message = ns.L.REPORT_NOTHING, parts = {} }
	end
	return { parts = text(rows), url = ns.FIELD_REPORT_URL }
end

--- "Part N of M" for part `n` of `m`, or nil when there is one part, so the part controls hide (REP-R40).
---@param n integer
---@param m integer
---@return string?
function ns.FieldReportPartLabel(n, m)
	if m <= 1 then
		return nil
	end
	return ns.L.REPORT_PART:format(n, m)
end

--- `label`, or `labelWithCount` filled with `count` while it is above 0 (CORE-R50, SET-R10).
---@param count integer
---@param label string
---@param labelWithCount string
---@return string
local function counted(count, label, labelWithCount)
	if count > 0 then
		return labelWithCount:format(count)
	end
	return label
end

--- The compartment menu's "Help chart the waters" entry, "Help chart the waters (3)" while the Field report count
--- is above 0 (CORE-R50, REP-R43). `open` is Pagle.OpenFieldReport, which prints REP-R44's line while restricted
--- (CORE-R33).
---@param count integer Pagle.GetFieldReportCount(), read as the menu opens
---@param open fun()
---@return PagleMenuEntry
function ns.FieldReportMenuEntry(count, open)
	return { label = counted(count, ns.L.MENU_FIELD_REPORT, ns.L.MENU_FIELD_REPORT_COUNT), onClick = open }
end

--- The Settings root's button caption: "Open Field report", or "Open Field report (3)" while the Field report count
--- is above 0 (SET-R10).
---@param count integer Pagle.GetFieldReportCount(), read each time the root is shown
---@return string
function ns.FieldReportButtonText(count)
	return counted(count, ns.L.SETTINGS_FIELD_REPORT_BUTTON, ns.L.SETTINGS_FIELD_REPORT_BUTTON_COUNT)
end

--- What Pagle.OpenFieldReport is handed: where Core runs it (adapter/FieldReportBox.lua, or FakePagle).
---@class PagleFieldReportSeams
---@field isRestricted fun(): boolean            -- Pagle.IsRestricted()
---@field print fun(line: string)                -- prints a chat line
---@field rows fun(): table[]?                   -- ns.FieldReportRows()
---@field text fun(rows: table[]): string[]      -- ns.FieldReportText
---@field show fun(view: PagleFieldReportView)   -- opens the box at part 1 with this view

--- Pagle.OpenFieldReport (REP-R40–R44), which every entry point calls: while restricted it prints "Pagle: the Field
--- report opens after combat." and opens nothing, leaving a box already open as it is (REP-R44, CORE-R33);
--- otherwise it builds the view now and opens the box with it.
---@param seams PagleFieldReportSeams
---@return fun()
function ns.OpenFieldReportFunction(seams)
	return function()
		if seams.isRestricted() then
			seams.print(ns.L.REPORT_AFTER_COMBAT)
			return
		end
		seams.show(ns.FieldReportView(seams.rows(), seams.text))
	end
end
