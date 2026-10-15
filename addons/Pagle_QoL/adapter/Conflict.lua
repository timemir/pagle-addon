if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Coexisting with Angleur and Fishing Buddy (QOL-R80–R84). At PLAYER_LOGIN, before QoL first arms (QOL-R33), it
-- looks for an other fishing-key addon; if one is loaded, it asks the player which to keep and stands down for the
-- rest of the session, whatever the answer (QOL-R82, QOL-R97).

local standingDown = false

--- Whether QoL stands down this session: a conflict was found at login (QOL-R82). While it does, QoL is disarmed,
--- binds nothing, starts no Fishing stretch and leases no CVars; its settings and the leftover restore (QOL-R64)
--- carry on.
---@return boolean
function ns.IsStandingDown()
	return standingDown
end

-- The two notes' global names: UISpecialFrames takes names, and Esc hides the frames it lists.
local CONFLICT_NOTE, RELOAD_NOTE = "PagleQoLConflictNote", "PagleQoLReloadNote"

--- A note pinned with wax (qol.md › UI, the field art kit): its question, and two choices on one line, the first on
--- leather, the second outlined.
---@class PagleQoLNote: Frame
---@field Title FontString
---@field primary PagleQoLNoteButton
---@field secondary PagleQoLNoteButton

-- Shows a pinned note named `name`, asking `title` with the choices `primary` and `secondary`: a click on one hides
-- the note, then runs its `onPrimary` or `onSecondary` (none for a choice that only closes it). It is a dialog QoL
-- draws itself, at the top centre where the game's popups show, above the world; Esc hides it through
-- UISpecialFrames (CloseSpecialWindows) and chooses nothing, as no script runs on its hiding. Enter does nothing, as
-- on the game's popups with no edit box.
---@param name string
---@param title string
---@param primary string
---@param secondary string
---@param onPrimary fun()
---@param onSecondary fun()?
---@return PagleQoLNote
local function showNote(name, title, primary, secondary, onPrimary, onSecondary)
	local note = CreateFrame("Frame", name, UIParent) --[[@as PagleQoLNote]]
	note:SetSize(440, 200)
	note:SetPoint("TOP", UIParent, "TOP", 0, -135)
	note:SetFrameStrata("DIALOG")
	note:SetClampedToScreen(true)
	note:EnableMouse(true)
	ns.PlaceSprite(ns.ArtSprite(note, "Field", "pin", "BACKGROUND"), note, 0, 0)
	-- The wax on the note's top edge, half above it.
	ns.PlaceSprite(ns.ArtSprite(note, "Field", "wax"), note, 220 - 29, -28)
	note.Title = ns.ArtText(note, "NoteHead")
	note.Title:SetWordWrap(true)
	note.Title:SetJustifyH("CENTER")
	note.Title:SetWidth(440 - 68)
	note.Title:SetPoint("TOP", 0, -44)
	note.Title:SetText(title)
	local row = CreateFrame("Frame", nil, note)
	note.primary = ns.NewNoteButton(row, primary, false)
	note.secondary = ns.NewNoteButton(row, secondary, true)
	local width = note.primary:GetWidth() + 12 + note.secondary:GetWidth()
	row:SetSize(width, 44)
	row:SetPoint("BOTTOM", 0, 22)
	-- A long addon title still fits the note: the row shrinks to the paper inside its edges.
	if width > 440 - 36 then
		row:SetScale((440 - 36) / width)
	end
	note.primary:SetPoint("LEFT", row, "LEFT")
	note.secondary:SetPoint("RIGHT", row, "RIGHT")
	note.primary:SetScript("OnClick", function()
		note:Hide()
		onPrimary()
	end)
	note.secondary:SetScript("OnClick", function()
		note:Hide()
		if onSecondary then
			onSecondary()
		end
	end)
	table.insert(UISpecialFrames, name)
	note:Show()
	return note
end

--- After either choice, offers the reload that finishes it (QOL-R83): the Reload now note, in the conflict note's
--- place. Only a click on "Reload now" reloads (QOL-R6): "Later" and Esc just close it, and the chat line still says
--- /reload. This click is the one ReloadUI() the boundary spec allows.
local function offerReload()
	showNote(RELOAD_NOTE, ns.L.CONFLICT_RELOAD_TEXT, ns.L.CONFLICT_RELOAD_NOW, ns.L.CONFLICT_RELOAD_LATER, function()
		ReloadUI()
	end)
end

---@param found PagleQoLConflict[]
local function usePagle(found)
	for _, conflict in ipairs(found) do
		C_AddOns.DisableAddOn(conflict.name)
	end
	print(ns.TurnedOffMessage(found))
	offerReload()
end

local function useOther()
	C_AddOns.DisableAddOn("Pagle_QoL")
	print(ns.L.CONFLICT_TURNED_OFF_QOL)
	offerReload()
end

--- The conflict check (QOL-R80). The Fishing key's PLAYER_LOGIN handler calls it right before the first arm
--- (QOL-R33). PLAYER_LOGIN fires once per load, at a login or a /reload, so the popup returns at each (QOL-R84).
function ns.CheckConflicts()
	local found = ns.FindConflicts(function(name)
		return (C_AddOns.IsAddOnLoaded(name))
	end, function(name)
		return C_AddOns.GetAddOnMetadata(name, "Title")
	end)
	if #found == 0 then
		return
	end
	standingDown = true
	-- Each choice runs only from a click on its own button; Esc hides the note and runs neither, so it chooses nothing
	-- (QOL-R81, QOL-R84). Neither choice reloads the UI; each offers the Reload now note (QOL-R83).
	showNote(CONFLICT_NOTE, ns.L.CONFLICT_TEXT, ns.L.CONFLICT_USE_PAGLE, ns.UseOtherLabel(found), function()
		usePagle(found)
	end, useOther)
end

-- The two notes as `/pagle dev tour` shows them (CORE-R65): made the first time, inert (each choice only closes its
-- note), the Reload now note under the conflict note.
local previews ---@type PagleQoLNote[]?

--- Shows or hides the tour's samples of the conflict note and the Reload now note: the same notes, whose buttons
--- turn nothing off and reload nothing (CORE-R68).
---@param shown boolean
function ns.PreviewNotes(shown)
	if not previews then
		local nothing = function() end
		previews = {
			showNote(
				CONFLICT_NOTE .. "Preview",
				ns.L.CONFLICT_TEXT,
				ns.L.CONFLICT_USE_PAGLE,
				ns.UseOtherLabel({
					{ name = "FishingBuddy", title = "Fishing Buddy" },
				}),
				nothing
			),
			showNote(
				RELOAD_NOTE .. "Preview",
				ns.L.CONFLICT_RELOAD_TEXT,
				ns.L.CONFLICT_RELOAD_NOW,
				ns.L.CONFLICT_RELOAD_LATER,
				nothing
			),
		}
		previews[2]:SetPoint("TOP", UIParent, "TOP", 0, -375)
	end
	for _, note in ipairs(previews) do
		note:SetShown(shown)
	end
end
