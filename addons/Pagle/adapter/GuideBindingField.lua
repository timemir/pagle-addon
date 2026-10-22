---@class PagleNS
local ns = select(2, ...)

-- Off Forever, Core.lua never created Pagle (CORE-R4).
if not Pagle then
	return
end
---@class Pagle
local Pagle = Pagle

-- The Field guide's binding field (core/onboarding.md › Key binding fields, Contracts' nav.BindingField), for one
-- binding action, PAGLE_FISHING_KEY or PAGLE_SWAP_GEAR: its label, a key cap and a note on the kit's paper (board 4;
-- PagleArtGuide's Guide.lua bindingField, whose sizes and offsets are the canvas's, in UI units from the field's top
-- left, y down). Not bound, a dashed cap; Listening after a click, the dashed cap in red, the field taking the
-- keyboard; Bound, a gilt key cap with the action's first key (ONB-R40). It takes a key through Core's key capture,
-- the Settings key rows' (adapter/KeyCapture.lua, ONB-R41): a free key, or one already on this action, binds in the
-- first slot and saves (ONB-R42); a key that already does something else turns the field into the conflict box,
-- which asks before taking it (ONB-R43). The Settings rows take a used key without asking, as Blizzard's do (SET-R20).
-- GetBindingAction reads what a key does, and FrameXML's GetBindingName its name in Key Bindings (.luacheckrc cites
-- both). It never binds while restricted, or while its step greys it; it replaces only
-- the key it shows, keeping the action's other key (ONB-R44, ONB-R25). Its own owner on Core's bus.
local OWNER = "Pagle binding fields"
local L = ns.L

local WIDTH, HEIGHT = 382, 62
-- The conflict box over the field: the kit's 76, and a line more for ONB-R43's note under its buttons.
local CONFLICT_HEIGHT = 92
-- The field's inks beyond the guide's: the key cap's words and the dashed cap's.
ns.GUIDE_INKS.keyCap = ns.Rgb("2A1A04")
ns.GUIDE_INKS.waiting = ns.Rgb("8A6A40")
-- A greyed field's alpha (ONB-R32, ONB-R100).
local GREYED_ALPHA = 0.5
-- The old action's name in the question, in the red pencil.
local RED = "|cff9a2a1a%s|r"

--- A binding field: a button over its paper, clicked to listen.
---@class PagleGuideBindingField: Button
---@field action string the binding action it binds
---@field state "unbound"|"listening"|"bound"|"conflict" what it shows now
---@field mode "rest"|"listening"|"conflict"
---@field greyed boolean whether its step greys it
---@field pending { key: string, old: string }? the key the conflict box asks about, and what it does now
---@field label FontString
---@field note FontString
---@field waitCap PagleSprite the dashed cap
---@field listenCap PagleSprite the dashed cap in red
---@field waitWords FontString
---@field keyCap PagleThreeSlice the gilt key cap
---@field keyWords FontString
---@field bound FontString
---@field conflict PagleGuideConflictBox
---@field Refresh fun(self: PagleGuideBindingField) -- draws it again from the bindings now (a step's onShow)
---@field SetGreyed fun(self: PagleGuideBindingField, greyed: boolean) -- greys it: no click binds (ONB-R32, ONB-R100)

--- The conflict box (ONB-R43).
---@class PagleGuideConflictBox: Frame
---@field keyCap PagleThreeSlice
---@field keyWords FontString
---@field question FontString
---@field use PagleGuideButton
---@field pick Button
---@field note FontString

-- Every binding field made, to redraw at UPDATE_BINDINGS and RestrictionChanged. Weak, as its page owns each.
---@type table<PagleGuideBindingField, true>
local fields = setmetatable({}, { __mode = "k" })

-- `key` as the key cap shows it: its short form, as the game's action buttons ask for it (Gethe/wow-ui-source branch
-- forever, Blizzard_ActionBar/Shared/ActionButton.lua: `GetBindingText(key, 1)`), "s-F" for SHIFT-F.
---@param key string
---@return string
local function shortText(key)
	---@diagnostic disable-next-line: param-type-mismatch -- the annotations name it a prefix string
	return GetBindingText(key, true)
end

-- Whether `field` takes a click and binds: neither greyed nor restricted.
---@param field PagleGuideBindingField
---@return boolean
local function isLive(field)
	return not field.greyed and not Pagle.IsRestricted()
end

-- Draws key cap `frame` reading `text` (the gilt one, 40 tall, or the conflict box's small one, 24 tall), at least
-- `least` wide and `pad` wider than its words, `cap` units kept at each end.
---@param frame PagleThreeSlice
---@param words FontString
---@param sprite string
---@param text string
---@param least number
---@param pad number
---@param cap number
local function setKeyCap(frame, words, sprite, text, least, pad, cap)
	words:SetText(text)
	local width = math.max(least, math.ceil(words:GetStringWidth()) + pad)
	ns.SetThreeSlice(frame, "GuideParts", sprite, width, cap, "ARTWORK")
end

-- Draws `field` as it is now: Listening, the conflict box over its paper, or at rest Bound with its action's first
-- key or Not bound; greyed unless live. A field that isn't live stops listening and closes its conflict box.
---@param field PagleGuideBindingField
local function draw(field)
	local live = isLive(field)
	if not live then
		if ns.KeyCaptureOwner() == field then
			ns.StopKeyCapture() -- draws it again, listening no more
			return
		end
		field.mode, field.pending = "rest", nil
	end
	field:SetEnabled(live)
	field:SetAlpha(live and 1 or GREYED_ALPHA)
	local key = GetBindingKey(field.action)
	local listening = field.mode == "listening"
	local waiting = listening or not key
	field.waitCap:SetShown(waiting and not listening)
	field.listenCap:SetShown(listening)
	field.waitWords:SetShown(waiting)
	field.waitWords:SetText(listening and L.GUIDE_BIND_LISTEN or L.GUIDE_BIND_CLICK)
	field.note:SetShown(waiting)
	field.note:SetText(listening and L.GUIDE_BIND_ESC or L.GUIDE_BIND_DEFAULT)
	field.keyCap:SetShown(not waiting)
	field.bound:SetShown(not waiting)
	if not waiting then
		setKeyCap(field.keyCap, field.keyWords, "key-big", shortText(key), 44, 20, 8)
	end
	local pending = field.mode == "conflict" and field.pending
	local box = field.conflict
	box:SetShown(pending and true or false)
	if pending then
		setKeyCap(box.keyCap, box.keyWords, "key", shortText(pending.key), 24, 12, 6)
		ns.GuideAt(box.question, box, 12 + box.keyCap:GetWidth() + 6, 12 + 2.25)
		box.question:SetWidth(WIDTH - 12 - (12 + box.keyCap:GetWidth() + 6))
		box.question:SetText(L.GUIDE_BIND_ASK[field.action]:format(RED:format(GetBindingName(pending.old))))
		box.use.label:SetText(L.GUIDE_BIND_USE[field.action]:format(GetBindingText(pending.key)))
		box.use:SetWidth(math.ceil(box.use.label:GetStringWidth()) + 36)
	end
	field.state = listening and "listening" or (pending and "conflict" or (key and "bound" or "unbound"))
end

local listen

-- `field` took `key` while listening (it listens no more): a free key, or one already on its action, binds in the
-- first slot and saves (ONB-R42); a key that does something else opens the conflict box (ONB-R43).
---@param field PagleGuideBindingField
---@param key string
local function taken(field, key)
	if not isLive(field) then
		return
	end
	local doing = GetBindingAction(key) or ""
	if doing == "" or doing == field.action then
		ns.BindKey(field.action, 1, key)
	else
		field.mode, field.pending = "conflict", { key = key, old = doing }
	end
	draw(field)
end

-- `field` listens for a key press through Core's key capture, the keyboard its own (ONB-R40, ONB-R41).
---@param field PagleGuideBindingField
function listen(field)
	if not isLive(field) then
		return
	end
	field.pending = nil
	field:SetPropagateKeyboardInput(false)
	ns.StartKeyCapture({
		owner = field,
		frame = field,
		onKey = function(key)
			taken(field, key)
		end,
		onStop = function()
			if field.mode == "listening" then
				field.mode = "rest"
			end
			draw(field)
		end,
	})
	field.mode = "listening"
	draw(field)
end

-- Use {key}: the key binds to the field's action, taken from the old one as the Key Bindings frame takes it, the
-- bindings are saved, and chat says what it used to do (ONB-R43).
---@param field PagleGuideBindingField
local function use(field)
	local pending = field.pending
	if not (pending and isLive(field)) then
		return
	end
	field.mode, field.pending = "rest", nil
	local oldName = GetBindingName(pending.old)
	ns.BindKey(field.action, 1, pending.key)
	print(L.GUIDE_BIND_TOLD[field.action]:format(GetBindingText(pending.key), oldName))
	draw(field)
end

-- The kit's light page button (LButton's "light" look): parchment, its words in gilt in the body's ink, brighter under
-- the mouse; `click` and `onClick`.
---@param parent Frame
---@param text string
---@param onClick fun()
---@return Button
local function lightButton(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent)
	local paper = ns.NewNineSlice(button, "GuideParts", "button-light", { 10, 8 })
	local label = ns.GuideText(button, "gilt", 15, "body", text, { justify = "CENTER" })
	label:SetPoint("CENTER", button, "CENTER", 0, 0)
	button:SetSize(math.ceil(label:GetStringWidth()) + 36, 28)
	button:SetScript("OnEnter", function()
		paper:SetVertexColor(1.08, 1.08, 1.08)
	end)
	button:SetScript("OnLeave", function()
		paper:SetVertexColor(1, 1, 1)
	end)
	button:SetScript("OnClick", function()
		ns.GuideSound("click")
		onClick()
	end)
	return button
end

-- The conflict box over `field`, hidden: the small key cap, the question, Use {key} and Pick another key, and the note
-- (ONB-R43). It takes the mouse, so a click on it never reaches the field under it.
---@param field PagleGuideBindingField
---@return PagleGuideConflictBox
local function conflictBox(field)
	local box = CreateFrame("Frame", nil, field) --[[@as PagleGuideConflictBox]]
	box:SetSize(WIDTH, CONFLICT_HEIGHT)
	ns.GuideAt(box, field, 0, 0)
	box:SetFrameLevel(field:GetFrameLevel() + 4)
	box:EnableMouse(true)
	ns.NewNineSlice(box, "GuideParts", "conf", 8)
	box.keyCap = CreateFrame("Frame", nil, box) --[[@as PagleThreeSlice]]
	box.keyWords = ns.GuideText(box.keyCap, "gilt", 14, "keyCap", "", { justify = "CENTER" })
	box.keyWords:SetPoint("CENTER", box.keyCap, "CENTER", 0, 0.5)
	ns.SetThreeSlice(box.keyCap, "GuideParts", "key", 24, 6, "ARTWORK")
	ns.GuideAt(box.keyCap, box, 12, 10)
	box.question = ns.GuideText(box, "print", 15, "title", "")
	box.use = ns.NewGuideButton(box, "", function()
		use(field)
	end, nil, 28)
	ns.GuideAt(box.use, box, 12, 38)
	box.pick = lightButton(box, L.GUIDE_BIND_PICK, function()
		listen(field)
	end)
	box.pick:SetPoint("TOPLEFT", box.use, "TOPRIGHT", 8, 0)
	box.note = ns.GuideText(box, "italic", 13, "note", L.GUIDE_BIND_KEPT)
	ns.GuideAt(box.note, box, 12, 70 + 2.275)
	box:Hide()
	return box
end

--- A binding field for `action` on `parent`, labelled `label` (Contracts' nav.BindingField): 382 by 62, its parent
--- places it. It draws from the bindings as it is made, at UPDATE_BINDINGS, and at Refresh (a step's onShow, ONB-R44);
--- SetGreyed greys it (ONB-R32's Double right-click, ONB-R100).
---@param parent Frame
---@param action string PAGLE_FISHING_KEY or PAGLE_SWAP_GEAR
---@param label string
---@return PagleGuideBindingField
function ns.NewGuideBindingField(parent, action, label)
	assert(
		L.GUIDE_BIND_ASK[action],
		"a binding field binds PAGLE_FISHING_KEY or PAGLE_SWAP_GEAR, not " .. tostring(action)
	)
	local field = CreateFrame("Button", nil, parent) --[[@as PagleGuideBindingField]]
	field:SetSize(WIDTH, HEIGHT)
	field:SetFrameLevel(parent:GetFrameLevel() + 2)
	field.action, field.mode, field.greyed = action, "rest", false
	ns.NewNineSlice(field, "GuideParts", "bind", 8)
	field.label = ns.GuideText(field, "print", 15, "body", label)
	ns.GuideAt(field.label, field, 13, 21.5 + 2)
	field.note = ns.GuideText(field, "italic", 13, "note", "", {
		wrap = true,
		width = 130,
		spacing = 4.55,
		justify = "RIGHT",
	})
	field.note:SetPoint("TOPRIGHT", field, "TOPLEFT", WIDTH - 13, -(22.3 + 2.275))
	-- the cap sits 12 right of the label
	local capX = 13 + math.ceil(field.label:GetStringWidth()) + 12
	field.waitCap = ns.ArtSprite(field, "GuideParts", "key-wait", "ARTWORK", 1)
	ns.PlaceSprite(field.waitCap, field, capX, 11)
	field.listenCap = ns.ArtSprite(field, "GuideParts", "key-listen", "ARTWORK", 1)
	ns.PlaceSprite(field.listenCap, field, capX, 11)
	field.waitWords = ns.GuideText(field, "italic", 14, "waiting", "", { justify = "CENTER" })
	field.waitWords:SetPoint("CENTER", field, "TOPLEFT", capX + 64, -31)
	field.keyCap = CreateFrame("Frame", nil, field) --[[@as PagleThreeSlice]]
	field.keyCap:SetFrameLevel(field:GetFrameLevel() + 2)
	field.keyWords = ns.GuideText(field.keyCap, "gilt", 20, "keyCap", "", { justify = "CENTER" })
	field.keyWords:SetPoint("CENTER", field.keyCap, "CENTER", 0, 1)
	ns.SetThreeSlice(field.keyCap, "GuideParts", "key-big", 44, 8, "ARTWORK")
	ns.GuideAt(field.keyCap, field, capX, 11)
	field.bound = ns.GuideText(field, "hand", 17, "green", L.GUIDE_BIND_BOUND, { justify = "RIGHT" })
	field.bound:SetPoint("TOPRIGHT", field, "TOPLEFT", WIDTH - 13, -(20 + 2.5))
	field.conflict = conflictBox(field)
	-- a left click listens; while it listens or asks, the mouse is never taken (ONB-R41)
	field:SetScript("OnClick", function(self, mouseButton)
		if mouseButton ~= "LeftButton" or self.mode ~= "rest" or not isLive(self) then
			return
		end
		ns.GuideSound("click")
		listen(self)
	end)
	-- hidden (its page turned, the guide closed), it listens and asks no more; shown, it reads the bindings again
	field:SetScript("OnHide", function(self)
		if ns.KeyCaptureOwner() == self then
			ns.StopKeyCapture()
		end
		self.mode, self.pending = "rest", nil
		draw(self)
	end)
	field:SetScript("OnShow", function(self)
		draw(self)
	end)
	function field.Refresh(self)
		draw(self)
	end
	function field.SetGreyed(self, greyed)
		self.greyed = greyed
		draw(self)
	end
	fields[field] = true
	draw(field)
	return field
end

-- A binding changed, through a field or anywhere else: each field shows its key now (ONB-R44).
Pagle.RegisterEvent(OWNER, "UPDATE_BINDINGS", function()
	for field in pairs(fields) do
		draw(field)
	end
end)

-- Combat starts or ends: a listening field stops, a conflict box closes, and the fields grey out or come back
-- (ONB-R44, ONB-R25, CORE-R32).
Pagle.RegisterCallback(OWNER, "RestrictionChanged", function()
	for field in pairs(fields) do
		draw(field)
	end
end)
