---@class PagleNS
local ns = select(2, ...)

-- What Core's own guide pages say and set (core/onboarding.md › The steps): Welcome's count of parts (ONB-R30), What's
-- in the box's rows and kicker from the registered Modules' defs (ONB-R31, ONB-R91, ONB-R102, ONB-R103), the Moments
-- presets and which one the Announcement settings match (ONB-R35), and Off you go's windows with First looks and the
-- First evening list as it will look (ONB-R38, ONB-R61). Pure logic over what it's handed (CORE-R7): the pages are
-- adapter/GuidePages.lua's. It reads only the registered Modules' def fields, never a Module (ADR 0001).

--- `n` in words, as the pages write a count: "five"; past ten, in figures.
---@param n integer
---@return string
function ns.GuideCountWord(n)
	return ns.L.GUIDE_COUNT_WORDS[n + 1] or tostring(n)
end

-- `text` with its first letter in capitals.
---@param text string
---@return string
local function capitalised(text)
	return (text:gsub("^%l", string.upper))
end

--- The third promise's line (ONB-R30): "Pagle comes in five parts. …", `n` the roster's size.
---@param n integer
---@return string
function ns.GuidePartsLine(n)
	return ns.L.GUIDE_WELCOME_PARTS:format(ns.GuideCountWord(n))
end

--- What's in the box's right kicker (ONB-R31): "Five parts, and a shop", `n` the registered Modules, in words.
---@param n integer
---@return string
function ns.GuideBoxKicker(n)
	local L = ns.L
	return capitalised((n == 1 and L.GUIDE_BOX_PART or L.GUIDE_BOX_PARTS):format(ns.GuideCountWord(n)))
end

--- Each Module's icon on What's in the box: a sprite of the guide's atlas (GuideParts), by roster name.
local BOX_ICONS =
	{ Ledger = "ic-journal", Hunts = "ic-hunts", Stats = "ic-stats", TackleBoard = "ic-board", QoL = "ic-qol" }

--- One row on What's in the box: its icon, its title and its line (a Module without a guideBlurb has none).
---@class PagleGuideBoxRow
---@field sprite string
---@field title string
---@field blurb string?

--- What's in the box's rows (ONB-R31, ONB-R91): one per registered Module in def.order, its icon, `def.title` and
--- `def.guideBlurb`, then the Curio Shop's, Core's. A Module that is off has none (ONB-R102); with every one off,
--- only the shop's (ONB-R103).
---@param modules PagleModule[] by def.order, as `registry:Modules()` lists them
---@return PagleGuideBoxRow[]
function ns.GuideBoxRows(modules)
	local rows = {}
	for _, module in ipairs(modules) do
		local def = module.def
		rows[#rows + 1] = { sprite = BOX_ICONS[def.name] or "ic-shop", title = def.title, blurb = def.guideBlurb }
	end
	rows[#rows + 1] = { sprite = "ic-shop", title = ns.L.GUIDE_BOX_SHOP, blurb = ns.L.GUIDE_BOX_SHOP_BLURB }
	return rows
end

--- One preset on the Moments step (ONB-R35): the Announcement settings it writes. A field left out is left as it is.
---@class PagleGuidePreset
---@field id "lively"|"quieter"|"cozy"
---@field cozy boolean
---@field everyCatch boolean?
---@field budget { on: boolean, count: integer, window: integer }?

--- The three presets, in the order their cards show (ONB-R35's table). Lively is the defaults (ANN-R31).
---@type PagleGuidePreset[]
ns.GUIDE_PRESETS = {
	{ id = "lively", cozy = false, everyCatch = true, budget = { on = true, count = 40, window = 300 } },
	{ id = "quieter", cozy = false, everyCatch = false, budget = { on = true, count = 10, window = 300 } },
	{ id = "cozy", cozy = true },
}

---@param id string
---@return PagleGuidePreset?
local function presetOf(id)
	for _, preset in ipairs(ns.GUIDE_PRESETS) do
		if preset.id == id then
			return preset
		end
	end
	return nil
end

--- The Announcement settings as stored (announcements.md › Data).
---@alias PagleAnnouncementSettings { cozy: boolean, everyCatch: boolean, motion: boolean, budget: { on: boolean, count: integer, window: integer } }

--- Writes preset `id` into `announcements` at once (ONB-R35): Cozy mode, Show every catch and the budget as its row
--- says, anything it leaves "(unchanged)" as it was. Animations, the toast style and the sound set are never touched.
---@param announcements PagleAnnouncementSettings PagleDB.profile.announcements
---@param id string
function ns.ApplyGuidePreset(announcements, id)
	local preset = assert(presetOf(id), "no guide preset " .. tostring(id))
	announcements.cozy = preset.cozy
	if preset.everyCatch ~= nil then
		announcements.everyCatch = preset.everyCatch
	end
	if preset.budget then
		announcements.budget.on = preset.budget.on
		announcements.budget.count = preset.budget.count
		announcements.budget.window = preset.budget.window
	end
end

--- The preset the settings match exactly (ONB-R35): Cozy whenever Cozy mode is on; else Lively or Quieter when every
--- field it writes is as it writes it; else nil, a mix of the Angler's own.
---@param announcements PagleAnnouncementSettings
---@return string?
function ns.GuidePresetOf(announcements)
	if announcements.cozy then
		return "cozy"
	end
	local budget = announcements.budget
	for _, preset in ipairs(ns.GUIDE_PRESETS) do
		local wants = preset.budget
		if
			wants
			and announcements.everyCatch == preset.everyCatch
			and budget.on == wants.on
			and budget.count == wants.count
			and budget.window == wants.window
		then
			return preset.id
		end
	end
	return nil
end

--- A preset card's pencilled line (board 6): how many pop-ups its budget allows, or Cozy's "a Legend still shows".
---@param preset PagleGuidePreset
---@return string
function ns.GuidePresetWhat(preset)
	if preset.budget then
		return ns.L.GUIDE_PRESET_POPUPS:format(preset.budget.count, preset.budget.window / 60)
	end
	return ns.L.GUIDE_PRESET_COZY_WHAT
end

--- `items` as a list in words: "a", "a and b", "a, b and c".
---@param items string[]
---@return string
function ns.GuideListOf(items)
	local L = ns.L
	if #items <= 1 then
		return items[1] or ""
	end
	return table.concat(items, L.GUIDE_LIST_COMMA, 1, #items - 1) .. L.GUIDE_LIST_AND .. items[#items]
end

--- The windows Off you go names (ONB-R38): the titles of the First looks registered (ns.firstLooks:List()), the
--- registered Modules' in def.order, each Module's as registered, then Core's (the Curio Shop's).
---@param modules PagleModule[] by def.order
---@param looks PagleLookRecord[] every registered set, with its owner
---@return string[]
function ns.GuideLookWindows(modules, looks)
	local windows = {}
	local function add(owner)
		for _, record in ipairs(looks) do
			if record.owner == owner then
				windows[#windows + 1] = record.set.title
			end
		end
	end
	for _, module in ipairs(modules) do
		add(module.def.name)
	end
	add(ns.CORE_OWNER)
	return windows
end

--- Off you go's margin-notes paragraph (ONB-R38), naming `windows`: "… The Fish Journal, Hunts, … and the Curio Shop
--- each get a short set the first time you open them."
---@param windows string[]
---@return string
function ns.GuideLooksLine(windows)
	local L = ns.L
	return (#windows == 1 and L.GUIDE_OFF_LOOKS_ONE or L.GUIDE_OFF_LOOKS):format(capitalised(ns.GuideListOf(windows)))
end

--- One line of the First evening list as Off you go draws it: its id, its text, and its hint where the list shows one.
---@class PagleGuideEveningItem
---@field id string
---@field text string
---@field hint string?

--- The First evening list's items (ONB-R61), in order, each with its owner: Core's, or the Module that must be
--- registered for it to exist.
local EVENING = {
	{ id = "cast", owner = ns.CORE_OWNER },
	{ id = "catch", owner = ns.CORE_OWNER },
	{ id = "journal", owner = "Ledger" },
	{ id = "hunts", owner = "Hunts" },
	{ id = "session", owner = ns.CORE_OWNER },
	{ id = "shop", owner = ns.CORE_OWNER },
}

--- The First evening list as it will look (ONB-R38, ONB-R61; board 9): each item whose owner is registered, in order,
--- with the hints the board shows under Make a Cast and Finish a Session; Make a Cast's names the Fishing key while
--- QoL is registered, else right-clicking the water (ONB-R101).
---@param modules PagleModule[] by def.order
---@return PagleGuideEveningItem[]
function ns.GuideEveningPreview(modules)
	local L = ns.L
	local registered = { [ns.CORE_OWNER] = true }
	for _, module in ipairs(modules) do
		registered[module.def.name] = true
	end
	local hints = {
		cast = registered.QoL and L.GUIDE_EVENING_HINTS.cast or L.GUIDE_EVENING_HINTS.castNoQoL,
		session = L.GUIDE_EVENING_HINTS.session,
	}
	local items = {}
	for _, item in ipairs(EVENING) do
		if registered[item.owner] then
			items[#items + 1] = { id = item.id, text = L.GUIDE_EVENING_ITEMS[item.id], hint = hints[item.id] }
		end
	end
	return items
end
