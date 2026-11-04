---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end

-- The Settings root's Language row (SET-R10 row 9b, CORE-R8, ADR 0019), beside Clock in the Units section, and the
-- Reload now note a change asks with. The choices and the render rule are adapter/Text.lua's (ns.LanguageChoices).

-- The note's global name: UISpecialFrames takes names, and Esc hides the frames it lists. Esc is "Later".
local NOTE_NAME = "PagleReloadNote"
local NOTE_WIDTH, NOTE_HEIGHT = 440, 200

---@class PagleReloadNote: Frame
---@field boxes EditBox[] none: it takes no keyboard, but the Field window's close and fade read the list
---@field closing boolean? fading out after Later, so it takes no more clicks
---@field reload Button "Reload now", the one thing that calls ReloadUI()
---@field later Button

--- The note, made the first time it is asked for.
---@type PagleReloadNote?
ns.reloadNote = nil

-- The note: the field art kit's pinned paper at the top centre, where the game's popups show, with the question and
-- two choices on one line. A dialog of Core's own, never the game's StaticPopup (a Pagle surface draws itself, and an
-- addon's entry in StaticPopupDialogs taints the game's popups). It shows and fades as the Field report box does
-- (adapter/FieldKit.lua) and Esc closes it without reloading.
---@return PagleReloadNote
local function build()
	local L = ns.L
	local note = CreateFrame("Frame", NOTE_NAME, UIParent) --[[@as PagleReloadNote]]
	note:SetSize(NOTE_WIDTH, NOTE_HEIGHT)
	note:SetPoint("TOP", UIParent, "TOP", 0, -135)
	note:SetFrameStrata("DIALOG")
	note:SetClampedToScreen(true)
	note:EnableMouse(true)
	note.boxes = {}
	ns.PlaceSprite(ns.ArtSprite(note, "Field", "pin", "BACKGROUND"), note, 0, 0)

	local title = ns.ArtText(note, "NoteHead")
	title:SetWordWrap(true)
	title:SetJustifyH("CENTER")
	title:SetWidth(NOTE_WIDTH - 68)
	title:SetPoint("TOP", 0, -44)
	title:SetText(L.LANGUAGE_RELOAD_TEXT)

	local row = CreateFrame("Frame", nil, note)
	note.reload = ns.FieldLeatherButton(row, L.LANGUAGE_RELOAD_NOW)
	note.later = ns.FieldLeatherButton(row, L.LANGUAGE_RELOAD_LATER)
	local width = note.reload:GetWidth() + 12 + note.later:GetWidth()
	row:SetSize(width, 44)
	row:SetPoint("BOTTOM", 0, 22)
	-- A long translation still fits the paper: the row shrinks inside its edges.
	if width > NOTE_WIDTH - 36 then
		row:SetScale((NOTE_WIDTH - 36) / width)
	end
	note.reload:SetPoint("LEFT", row, "LEFT")
	note.later:SetPoint("RIGHT", row, "RIGHT")
	-- QOL-R6's rule for Core too: ReloadUI() runs only from a click on the button that says it reloads, never on its
	-- own: not at load, on an event, a timer, or a restriction change.
	note.reload:SetScript("OnClick", function()
		PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
		ReloadUI()
	end)
	note.later:SetScript("OnClick", function()
		PlaySound(ns.FIELD_SOUND_CLICK, "SFX")
		ns.FieldFadeClose(note --[[@as PagleFieldWindow]])
	end)

	-- Hidden until it first shows, before its OnHide is set, so building it plays nothing.
	note:Hide()
	note:SetScript("OnHide", function()
		if not note.closing then
			PlaySound(ns.FIELD_SOUND_CLOSE, "SFX")
		end
		note.closing = false
		ns.StopMotion(note)
		note:SetAlpha(1)
	end)
	table.insert(UISpecialFrames, NOTE_NAME)
	return note
end

--- Asks the Angler to /reload to finish a change that only a reload applies: shows the Reload now note, "Reload the
--- interface to change the language?" with Reload now and Later. Nothing reloads unless Reload now is clicked; Later
--- and Esc close it. Shown again while it is up, it stays as it is. It is in the language this session runs in: a
--- Language is applied once, at load, so nothing is in the chosen one yet.
function ns.AskForReload()
	local note = ns.reloadNote
	if not note then
		note = build()
		ns.reloadNote = note
	end
	ns.FieldShowWindow(note --[[@as PagleFieldWindow]])
end

--- The Language the setting holds now: `PagleDB.global.language`, "default" for Game default (a missing or wrongly typed
--- value counts as that, as at load).
---@return string
local function storedLanguage()
	local value = ns.db.global[ns.LANGUAGE_KEY]
	if type(value) == "string" and value ~= "" then
		return value
	end
	return ns.LANGUAGE_GAME_DEFAULT
end

--- Whether the dropdown offers `value` on this client.
---@param value string
---@return boolean
local function offered(value)
	for _, choice in ipairs(ns.LanguageChoices(GetLocale())) do
		if choice.value == value then
			return true
		end
	end
	return false
end

--- The Units section's Language row (SET-R10 row 9b): a dropdown of "Game default", English and each listed Locale the
--- client can render. A pick is saved in the account-wide `PagleDB.global.language`, Game default as none, and asks
--- for a /reload (ns.AskForReload); nothing switches live, and the row shows the stored pick meanwhile. A stored value
--- the dropdown doesn't offer on this client (a Locale that is not listed, or a non-Latin one on another client) reads
--- as Game default. It has no default, so the root's Defaults button leaves it (SET-R13), as it leaves the minimap
--- icon: a Defaults click never asks for a reload.
---@param category SettingsCategory
function ns.LanguageRow(category)
	local L = ns.L
	local language = Settings.RegisterProxySetting(
		category,
		"Pagle_Core_language",
		Settings.VarType.String,
		L.SETTINGS_LANGUAGE,
		nil,
		function()
			local stored = storedLanguage()
			return offered(stored) and stored or ns.LANGUAGE_GAME_DEFAULT
		end,
		function(value)
			local before = storedLanguage()
			ns.db.global[ns.LANGUAGE_KEY] = value ~= ns.LANGUAGE_GAME_DEFAULT and value or nil
			if value ~= before then
				ns.AskForReload()
			end
		end
	)
	Settings.CreateDropdown(category, language, function()
		local container = Settings.CreateControlTextContainer()
		for _, choice in ipairs(ns.LanguageChoices(GetLocale())) do
			container:Add(choice.value, choice.label)
		end
		return container:GetData()
	end, L.SETTINGS_LANGUAGE_TOOLTIP)
end
