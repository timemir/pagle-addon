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
		print(
			"Pagle Recovery: Pagle_Recovery didn't load ("
				.. unloaded
				.. "), so nothing was restored and your Catch log is unchanged. Remove Pagle_Recovery once Recovery is complete."
		)
	elseif ok and otherLog then
		print(
			"Pagle Recovery: Pagle_Recovery is for another Catch log, so nothing was restored here. Remove it once Recovery is complete."
		)
	end
	if not ok then
		ns.recoveryBlocked = true
		_G.Pagle = nil
		print(
			"Pagle Recovery stopped: "
				.. tostring(prepared)
				.. ". Your Catch log is unchanged. Remove Pagle_Recovery to resume, or export a new snapshot with /pagle recovery export."
		)
		return false
	end
	if verifiedArchive then
		_G.PagleRecovery = verifiedArchive
	end
	if prepared then
		_G.PagleLog, _G.PagleRecovery, _G.PagleDB = prepared.log, prepared.archive, prepared.db
		print(
			"Pagle Recovery restored the Catch log. Original records are preserved; /pagle recovery inspect shows records held for review. Upload normally, confirm Recovery on the website, then remove Pagle_Recovery."
		)
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
		window = ns.NewFieldWindow("PagleRecoveryWindow", 520, 360, title, "Catch log Recovery", ns.L.PASTE_COPY_HINT) --[[@as PagleRecoveryWindow]]
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
			print("Pagle Recovery export unavailable: " .. tostring(snapshot))
			return
		end
		local parts, labels = {}, {}
		for line in snapshot:gmatch("[^\n]+") do
			parts[#parts + 1] = line
		end
		for i = 1, #parts do
			labels[i] = "Recovery snapshot · part " .. i .. " of " .. #parts
		end
		windowFor(
			parts,
			labels,
			"Recovery snapshot",
			"Copy every numbered part. Paste them together on your Catch log's Recovery page at pagle.app. On Mac, use Cmd+C."
		)
	elseif action == "archives" then
		local saved = _G.PagleRecovery
		local ids = {}
		for archiveId in pairs(saved and saved.archives or {}) do
			ids[#ids + 1] = archiveId
		end
		table.sort(ids)
		for _, archiveId in ipairs(ids) do
			print("Pagle Recovery archive: " .. archiveId)
		end
		if #ids == 0 then
			print("Pagle Recovery: no preserved branches.")
		end
	elseif action == "inspect" then
		local saved = _G.PagleRecovery
		if id == "" then
			id = saved and saved.completed and saved.completed.applicationId or ""
		end
		local archive = saved and saved.archives and saved.archives[id]
		if not archive then
			print(
				"Pagle Recovery: no preserved branch found. Use /pagle recovery inspect <application ID> for an older archive."
			)
			return
		end
		-- A branch a beta Pagle kept is in format 3's entries, which this Pagle can't read records from (LOG-R18).
		local original = archive.original
		if type(original) ~= "table" or original.format ~= ns.LOG_FORMAT or type(original.blocks) ~= "table" then
			print(
				"Pagle Recovery: this archive was kept by an older Pagle, in a Catch log format this one can't show records from. It is still preserved."
			)
			return
		end
		local parts, labels = {}, {}
		for i, staged in ipairs(archive.staged) do
			parts[i] = ns.LogBlocks.Get(original, staged.seq) or "(this record is not in the preserved log)"
			labels[i] = "Record " .. staged.seq .. " · " .. staged.reason
		end
		if #parts == 0 then
			print("Pagle Recovery: this archive has no records held for review.")
			return
		end
		windowFor(
			parts,
			labels,
			"Recovery records",
			"Preserved original records held for review. They have not been appended to your restored Catch log. Original branch: "
				.. id
		)
	else
		print(
			"Pagle Recovery: /pagle recovery export copies a complete local snapshot; /pagle recovery inspect [application ID] shows records held for review."
		)
	end
end
