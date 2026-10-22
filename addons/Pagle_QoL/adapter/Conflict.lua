if not Pagle then
	return
end

---@class PagleQoLNS
local ns = select(2, ...)

-- Coexisting with Angleur and Fishing Buddy (QOL-R80–R84). At PLAYER_LOGIN, before QoL first arms (QOL-R33), it
-- looks for an other fishing-key addon; if one is loaded, it asks the player which to keep and stands down for the
-- rest of the session, whatever the answer (QOL-R82, QOL-R97). While it asks, Core's Letter waits (ONB-R100).

local standingDown = false
local standingFor = {} ---@type string[] the titles of the other fishing-key addons found, while QoL stands down

--- Whether QoL stands down this session: a conflict was found at login (QOL-R82). While it does, QoL is disarmed,
--- binds nothing, starts no Fishing stretch and leases no CVars; its settings and the leftover restore (QOL-R64)
--- carry on.
---@return boolean
function ns.IsStandingDown()
	return standingDown
end

--- The titles of the other fishing-key addons QoL stands down for (QOL-R81, QOL-R82), in conflict-list order: empty
--- while it doesn't. The Field guide's Casting step names them (ONB-R100).
---@return string[]
function ns.StandingDownFor()
	return standingFor
end

-- The two notes' global names: UISpecialFrames takes names, and Esc hides the frames it lists.
local CONFLICT_NOTE, RELOAD_NOTE = "PagleQoLConflictNote", "PagleQoLReloadNote"

--- A note pinned with wax (qol.md › UI, the field art kit): its question, and two choices on one line, the first on
--- leather, the second outlined.
---@class PagleQoLNote: Frame
---@field Title FontString
---@field primary PagleQoLNoteButton
---@field secondary PagleQoLNoteButton
---@field wax PagleQoLWax
---@field closing boolean? fading out after a choice, so a second click chooses nothing

--- The wax, anchored by its centre so it can be pressed on from 1.8 times its size.
---@class PagleQoLWax: PagleSprite
---@field w0 number its size at rest
---@field h0 number

-- The notes' sounds (the field art kit's SOUND.md): the client's own sound kits, by id, on the SFX channel, so the
-- player's SFX volume and mute rule them. UI foley, the same in every sound set: IG_MAINMENU_OPEN as a note appears,
-- IG_MAINMENU_CLOSE as it goes, IG_MAINMENU_OPTION for a click on either choice.
local SOUND_OPEN, SOUND_CLOSE, SOUND_CLICK = 850, 851, 852

-- Puts the wax at rest: its own size, fully drawn.
---@param note PagleQoLNote
local function settleWax(note)
	note.wax:SetSize(note.wax.w0, note.wax.h0)
	note.wax:SetAlpha(1)
end

-- A note appearing (the kit's MOTION.md and P.OpenNote): the open sound, the note fading in over 0.2 s (ease-out), and
-- its wax pressed on as it lands, 1.8 times its size to 0.95 by 0.29 s, settling at its own by 0.38 s
-- (cubic-bezier(.3, 1.5, .5, 1)), fading in with it. It moves on Core's driver, which follows the Animations setting
-- (announcements.md › Contracts): off, a note shows and goes at once, its wax already on.
---@param note PagleQoLNote
local function openNote(note)
	note.closing = false
	PlaySound(SOUND_OPEN, "SFX")
	Pagle.StopMotion(note)
	local wax = note.wax
	Pagle.Animate(note, {
		{
			dur = 0.2,
			ease = Pagle.EASE.out,
			keys = { { 0, { 0 } }, { 1, { 1 } } },
			apply = function(v)
				note:SetAlpha(v[1])
			end,
		},
		{
			dur = 0.3,
			delay = 0.08,
			ease = Pagle.Bezier(0.3, 1.5, 0.5, 1),
			keys = { { 0, { 1.8, 0 } }, { 0.7, { 0.95, 1 } }, { 1, { 1, 1 } } },
			apply = function(v)
				wax:SetSize(wax.w0 * v[1], wax.h0 * v[1])
				wax:SetAlpha(v[2])
			end,
		},
	})
end

-- A note going after a choice (the kit's P.CloseNote): the close sound, and the note fading out over 0.15 s
-- (ease-in) from where it is, then hiding, left at rest for its next showing. Its wax settles at once. Hidden with
-- the whole UI as it fades, it still ends closed: Core's driver settles the fade, which hides it.
---@param note PagleQoLNote
local function closeNote(note)
	note.closing = true
	PlaySound(SOUND_CLOSE, "SFX")
	Pagle.StopMotion(note)
	settleWax(note)
	Pagle.Animate(note, {
		{
			dur = 0.15,
			ease = Pagle.Bezier(0.42, 0, 1, 1),
			keys = { { 0, { note:GetAlpha() } }, { 1, { 0 } } },
			apply = function(v)
				note:SetAlpha(v[1])
			end,
		},
	}, function()
		note:Hide()
		note.closing = false
		note:SetAlpha(1)
	end)
end

-- A choice's button: the click sound, the note going, then the choice. While the note fades out a click chooses
-- nothing.
---@param note PagleQoLNote
---@param button PagleQoLNoteButton
---@param choose fun()?
local function onChoice(note, button, choose)
	button:SetScript("OnClick", function()
		if note.closing then
			return
		end
		PlaySound(SOUND_CLICK, "SFX")
		closeNote(note)
		if choose then
			choose()
		end
	end)
end

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
	-- The wax on the note's top edge, half above it, anchored by its centre for the press.
	local wax = ns.ArtSprite(note, "Field", "wax") --[[@as PagleQoLWax]]
	wax.w0, wax.h0 = wax:GetSize()
	wax:SetPoint("CENTER", note, "TOPLEFT", 220 - 29 - wax.box[1] + wax.w0 / 2, 28 + wax.box[2] - wax.h0 / 2)
	note.wax = wax
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
	onChoice(note, note.primary, onPrimary)
	onChoice(note, note.secondary, onSecondary)
	-- Shown again (the tour's samples), it opens again. Hidden by Esc or the tour, it goes at once, with the close
	-- sound, and is left at rest for its next showing. Hidden as a choice's fade plays (the fade's own end, or the
	-- whole UI hidden), the fade ends it (closeNote).
	note:SetScript("OnShow", openNote)
	note:SetScript("OnHide", function()
		if note.closing then
			return
		end
		PlaySound(SOUND_CLOSE, "SFX")
		Pagle.StopMotion(note)
		note:SetAlpha(1)
		settleWax(note)
	end)
	table.insert(UISpecialFrames, name)
	-- Made shown, so OnShow doesn't run this time.
	openNote(note)
	return note
end

-- The conflict note and the Reload now note in its place, once each is made: the real ones, never the tour's.
local asking = {} ---@type PagleQoLNote[]

-- Tells Core whether QoL's question is on screen (M:SetDialogOpen, ONB-R100): the Letter waits while the conflict
-- note, or the Reload now note in its place, shows, and checks again once neither does. On a Core without the call,
-- nothing.
---@param open boolean
local function tellCore(open)
	local M = ns.Module
	if M and M.SetDialogOpen then
		M:SetDialogOpen(open)
	end
end

-- A real note joins the question: Core hears it open now, and closed once it and the other have gone, however they
-- went (a choice's fade, Esc, Later). A choice on the conflict note (`answered`, its fade ending) is followed by the
-- Reload now note, so the question goes on: with Animations off its fade ends before that note is made.
---@param note PagleQoLNote
---@param answered boolean? a choice on this note brings the Reload now note
local function ask(note, answered)
	asking[#asking + 1] = note
	tellCore(true)
	note:HookScript("OnHide", function()
		if answered and note.closing then
			return
		end
		for _, other in ipairs(asking) do
			if other:IsShown() then
				return
			end
		end
		tellCore(false)
	end)
end

--- After either choice, offers the reload that finishes it (QOL-R83): the Reload now note, in the conflict note's
--- place. Only a click on "Reload now" reloads (QOL-R6): "Later" and Esc just close it, and the chat line still says
--- /reload. This click is the one ReloadUI() the boundary spec allows.
local function offerReload()
	ask(
		showNote(
			RELOAD_NOTE,
			ns.L.CONFLICT_RELOAD_TEXT,
			ns.L.CONFLICT_RELOAD_NOW,
			ns.L.CONFLICT_RELOAD_LATER,
			function()
				ReloadUI()
			end
		)
	)
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
	for i, conflict in ipairs(found) do
		standingFor[i] = conflict.title
	end
	-- Each choice runs only from a click on its own button; Esc hides the note and runs neither, so it chooses nothing
	-- (QOL-R81, QOL-R84). Neither choice reloads the UI; each offers the Reload now note (QOL-R83).
	ask(
		showNote(CONFLICT_NOTE, ns.L.CONFLICT_TEXT, ns.L.CONFLICT_USE_PAGLE, ns.UseOtherLabel(found), function()
			usePagle(found)
		end, useOther),
		true
	)
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
