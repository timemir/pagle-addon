---@class PagleNS
local ns = select(2, ...)
if not Pagle then
	return
end

---@class PagleRecoveryWindow: PagleFieldWindow
---@field parts string[]
---@field labels string[]
---@field part integer
---@field paste EditBox
---@field line FontString
---@field instructions FontString
---@field previous PagleFieldBrassButton
---@field next PagleFieldBrassButton

---@type PagleRecoveryWindow?
ns.recoveryWindow = nil
---@type boolean?
ns.recoveryBlocked = nil

--- What went wrong, as the player reads it (#525). A reason logic/ raises by code (`ns.RecoveryProblem`) is Core's text
--- for it in the Language applied; anything else is a diagnostic of the package's parser or a raw Lua error, and stays
--- as it was raised, English (ADR 0019, "What stays English"). It goes into the sentence as the value of `{reason}`.
---@param err any
---@return string
local function reasonText(err)
	if type(err) == "table" and err.problem then
		local text = ns.L.RECOVERY_PROBLEMS[err.problem]
		return text and ns.RenderText(text, err.fields) or tostring(err.problem)
	end
	return tostring(err)
end

-- Recovery's data addon has no dependency on Pagle and must load before SavedVariables are opened.
---@return boolean
function ns.StartRecovery()
	local unloaded
	local ok, prepared, verifiedArchive, otherLog = pcall(function()
		local installedReason = select(5, C_AddOns.GetAddOnInfo("Pagle_Recovery"))
		if installedReason == "MISSING" then
			return nil
		end
		-- A package the client won't load (unticked, or out of date after a patch) was never read, so it is no
		-- package at all (RCV-R3): only one that loaded and failed verification stops Pagle.
		local loaded, reason = C_AddOns.LoadAddOn("Pagle_Recovery")
		if not loaded then
			unloaded = tostring(reason)
			return nil
		end
		return ns.RecoveryPrepare(_G.PagleRecoveryData, ns.PUSHED_KEYS, _G.PagleLog, _G.PagleRecovery, _G.PagleDB)
	end)
	if ok and unloaded and unloaded ~= "DISABLED" then
		print(ns.RenderText(ns.L.RECOVERY_NOT_LOADED, { reason = unloaded }))
	elseif ok and otherLog then
		print(ns.L.RECOVERY_OTHER_LOG)
	end
	if not ok then
		ns.recoveryBlocked = true
		_G.Pagle = nil
		print(ns.RenderText(ns.L.RECOVERY_STOPPED, { reason = reasonText(prepared) }))
		return false
	end
	if verifiedArchive then
		_G.PagleRecovery = verifiedArchive
	end
	if prepared then
		_G.PagleLog, _G.PagleRecovery, _G.PagleDB = prepared.log, prepared.archive, prepared.db
		print(ns.L.RECOVERY_RESTORED)
	end
	return true
end

---@param window PagleRecoveryWindow
---@param part integer
local function showPart(window, part)
	window.part = part
	window.paste:SetText(window.parts[part])
	window.paste:SetCursorPosition(0)
	window.paste:SetFocus()
	window.paste:HighlightText()
	window.line:SetText(window.labels[part])
	window.previous:SetShown(part > 1)
	window.next:SetShown(part < #window.parts)
end

---@param parts string[]
---@param labels string[]
---@param title string
---@param note string
local function windowFor(parts, labels, title, note)
	local window = ns.recoveryWindow
	if not window then
		window = ns.NewFieldWindow(
			"PagleRecoveryWindow",
			520,
			360,
			title,
			ns.L.RECOVERY_WINDOW_CAPTION,
			ns.L.PASTE_COPY_HINT
		) --[[@as PagleRecoveryWindow]]
		window.closeCorner:SetScript("OnClick", function()
			if ns.recoveryBlocked then
				window:Hide()
			else
				ns.FieldFadeClose(window)
			end
		end)
		ns.SetSprite(window.chart, "Chart", "chart")
		ns.PlaceSprite(window.chart, window, 0, 0)
		window.paste = ns.FieldTypedBox(window, "Type")
		window.paste:SetMultiLine(false)
		window.paste:SetMaxLetters(0)
		window.paste:SetSize(426, 20)
		window.paste:SetPoint("LEFT", window, "TOPLEFT", 34, -140)
		ns.FieldKeepText(window, window.paste, function()
			return window.parts[window.part]
		end)
		window.paste:SetScript("OnMouseUp", function(self)
			self:HighlightText()
		end)
		window.line = ns.FieldText(window, "Type")
		window.line:SetPoint("LEFT", window, "TOPLEFT", 34, -175)
		window.instructions = ns.FieldText(window, "Type")
		window.instructions:SetPoint("TOPLEFT", window, "TOPLEFT", 34, -205)
		window.instructions:SetWidth(426)
		window.previous = ns.FieldBrassButton(window, "arrow-prev")
		window.previous:SetPoint("LEFT", window, "TOPLEFT", 22, -324)
		window.previous:SetScript("OnClick", function()
			showPart(window, window.part - 1)
		end)
		window.next = ns.FieldBrassButton(window, "arrow-next")
		window.next:SetPoint("LEFT", window.previous, "RIGHT", 24, 0)
		window.next:SetScript("OnClick", function()
			showPart(window, window.part + 1)
		end)
		local close = ns.FieldLeatherButton(window, ns.L.PASTE_CLOSE)
		close:SetPoint("CENTER", window, "TOP", 0, -324)
		close:SetScript("OnClick", function()
			window:Hide()
		end)
		window.boxes = { window.paste }
		ns.recoveryWindow = window
	end
	window.parts, window.labels = parts, labels
	window.title:SetText(title)
	window.instructions:SetText(note)
	showPart(window, 1)
	if ns.recoveryBlocked then
		window:Show()
	else
		ns.FieldShowWindow(window)
	end
end

---@param args string?
function ns.OpenRecovery(args)
	local action, id = ns.ParseSlash(args or "")
	if action == "export" then
		local ok, snapshot = pcall(ns.RecoveryExport, _G.PagleLog)
		if not ok then
			print(ns.RenderText(ns.L.RECOVERY_EXPORT_UNAVAILABLE, { reason = reasonText(snapshot) }))
			return
		end
		local parts, labels = {}, {}
		for line in snapshot:gmatch("[^\n]+") do
			parts[#parts + 1] = line
		end
		for i = 1, #parts do
			labels[i] = ns.RenderText(ns.L.RECOVERY_SNAPSHOT_PART, { part = i, parts = #parts })
		end
		windowFor(parts, labels, ns.L.RECOVERY_SNAPSHOT_TITLE, ns.L.RECOVERY_SNAPSHOT_NOTE)
	elseif action == "archives" then
		local saved = _G.PagleRecovery
		local ids = {}
		for archiveId in pairs(saved and saved.archives or {}) do
			ids[#ids + 1] = archiveId
		end
		table.sort(ids)
		for _, archiveId in ipairs(ids) do
			print(ns.RenderText(ns.L.RECOVERY_ARCHIVE_LINE, { id = archiveId }))
		end
		if #ids == 0 then
			print(ns.L.RECOVERY_NO_BRANCHES)
		end
	elseif action == "inspect" then
		local saved = _G.PagleRecovery
		if id == "" then
			id = saved and saved.completed and saved.completed.applicationId or ""
		end
		local archive = saved and saved.archives and saved.archives[id]
		if not archive then
			print(ns.L.RECOVERY_NO_BRANCH_FOUND)
			return
		end
		-- A branch a beta Pagle kept is in format 3's entries, which this Pagle can't read records from (LOG-R18).
		local original = archive.original
		if type(original) ~= "table" or original.format ~= ns.LOG_FORMAT or type(original.blocks) ~= "table" then
			print(ns.L.RECOVERY_OLD_ARCHIVE)
			return
		end
		local parts, labels = {}, {}
		for i, staged in ipairs(archive.staged) do
			parts[i] = ns.LogBlocks.Get(original, staged.seq) or ns.L.RECOVERY_RECORD_MISSING
			-- The reason is the stable code PagleRecovery holds; a Language may word it, and a code it lacks shows as it is.
			local reason = ns.L.RECOVERY_REASONS[staged.reason] or staged.reason
			labels[i] = ns.RenderText(ns.L.RECOVERY_RECORD_LABEL, { seq = staged.seq, reason = reason })
		end
		if #parts == 0 then
			print(ns.L.RECOVERY_NO_STAGED)
			return
		end
		windowFor(parts, labels, ns.L.RECOVERY_RECORDS_TITLE, ns.RenderText(ns.L.RECOVERY_RECORDS_NOTE, { id = id }))
	else
		print(ns.L.RECOVERY_USAGE)
	end
end
