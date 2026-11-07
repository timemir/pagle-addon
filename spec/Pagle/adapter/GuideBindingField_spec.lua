-- The Field guide's binding field on the client, through the real TOC and the fake client (core/onboarding.md › Key
-- binding fields): its states (ONB-R40), taking a key through the key-capture helper the Settings key rows share
-- (ONB-R41, SET-R20), binding a free key (ONB-R42), the conflict box (ONB-R43), and never while restricted, never the
-- other key (ONB-R44, ONB-R25).

local SOUND_CLICK = "852 SFX"
local RED = "|cff9a2a1a"

-- Core logged in, with a shown page to put fields on. Returns the client load and the page.
local function onPage()
	local loaded = loadCore({ BUILD_ENTRY })
	enterWorld(loaded)
	local page = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
	page:SetSize(442, 546)
	return loaded, page
end

-- A binding field for `action` (the Fishing key unless given) on a fresh page. Returns the client load and the field.
local function field(action, label)
	local loaded, page = onPage()
	return loaded, loaded.ns.NewGuideBindingField(page, action or "PAGLE_FISHING_KEY", label or "Fishing key")
end

-- Whether `widget` and every frame it hangs from are shown.
local function visible(widget)
	while widget do
		if not widget.shown then
			return false
		end
		widget = widget.parent
	end
	return true
end

-- The texts of the field's shown font strings, depth first in the order they were made.
local function texts(widget, into)
	into = into or {}
	for _, child in ipairs(widget.children) do
		if child.kind == "FontString" then
			if visible(child) and child.text and child.text ~= "" then
				into[#into + 1] = child.text
			end
		else
			texts(child, into)
		end
	end
	return into
end

-- The shown button holding a font string reading `text`, depth first; nil if none.
local function button(widget, text)
	for _, child in ipairs(widget.children) do
		if child.kind == "Button" and visible(child) then
			for _, region in ipairs(child.children) do
				if region.kind == "FontString" and region.text == text then
					return child
				end
			end
		end
		if child.kind ~= "FontString" and child.kind ~= "Texture" then
			local found = button(child, text)
			if found then
				return found
			end
		end
	end
	return nil
end

-- Clicks the shown button reading `text` on the field.
local function click(fieldFrame, text)
	local control = button(fieldFrame, text) or error("no shown button reading " .. text)
	control:Click()
end

describe("the binding field's words in a longer language (ONB-R40)", function()
	---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
	local bounds = dofile("spec/support/bounds.lua")

	-- Where a font string starts across the field, from its one anchor (its left, or its right less its width).
	local function leftOf(fontString)
		local point = fontString.points[1]
		if point[1]:find("RIGHT") then
			return point[4] - fontString.width
		elseif point[1] == "CENTER" or point[1] == "TOP" then
			return point[4] - fontString.width / 2
		end
		return point[4]
	end

	it("keeps its label, the dashed cap's words and the note apart, each in its own room", function()
		local loaded, page = onPage()
		local L = loaded.ns.L
		L.GUIDE_BIND_CLICK = "Щёлкните, чтобы назначить клавишу"
		L.GUIDE_BIND_DEFAULT =
			"по умолчанию: ничего не назначено, клавишу можно выбрать"
		local swap = loaded.ns.NewGuideBindingField(
			page,
			"PAGLE_SWAP_GEAR",
			"Переодеться в рыбацкую одежду"
		)

		local label, waiting, note = swap.label, swap.waitWords, swap.note
		-- the label ends 12 before the cap; the cap's words keep 8 inside its 128; the note starts 12 after it
		assert.is_true(13 + label.width <= swap.capX - 12)
		assert.are.equal(128 - 16, waiting.width)
		assert.is_true(leftOf(waiting) >= swap.capX + 8 - 0.01)
		assert.is_true(leftOf(waiting) + waiting.width <= swap.capX + 128 - 8 + 0.01)
		assert.is_true(leftOf(note) >= swap.capX + 128 + 12 - 0.01)
		assert.are.same({}, bounds.overflows(swap))
	end)

	it(
		"sets a note still over three lines at its least size on three, which the client ends with an ellipsis",
		function()
			local loaded, swap = field("PAGLE_SWAP_GEAR", "Umziehen")
			local note = swap.note
			-- five lines of words at every size, as the client measures them with no line cap; as many as the cap lets it
			-- draw with one, as it counts only the lines it draws; one line's 14 unwrapped
			local caps = {}
			note.GetStringHeight = function(self)
				caps[#caps + 1] = self:GetMaxLines()
				if self.wordWrap == false then
					return 14
				end
				return (self:GetMaxLines() > 0 and self:GetMaxLines() or 5) * 14
			end
			loaded.ns.L.GUIDE_BIND_DEFAULT = ("Standard: nichts belegt, jede Taste ist frei wählbar. "):rep(3)

			swap:Refresh()

			-- measured at every size from 13 down to the least, 10.5, each with no cap; then one line unwrapped and the
			-- words wrapped at the least size, which take more than two lines: capped at three (1.3.5)
			assert.are.same({ 0, 0, 0, 0, 0, 0, 0 }, caps)
			assert.are.equal("PagleArtFace_italic_10_5", note.fontObject.name)
			assert.are.equal(3, note:GetMaxLines())
			-- the three lines stood on the field's middle, but never nearer its top than 8
			assert.are.equal(-8, note.points[1][5])
		end
	)

	describe("the dashed cap's words in their real face (1.3.5)", function()
		---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
		local RealFont = dofile("scripts/measure-layout/realfont.lua")
		local width = RealFont.width

		-- A binding field (the Fishing key's unless `action` and `label` are given), unbound, on a client of
		-- `language`, its words measured in their real faces (a ruRU client's FRIZQT___CYR, which isn't bundled, in
		-- RealFont's stand-in), `wider` times as wide when given. Returns the field.
		local function unbound(language, wider, action, label)
			RealFont.width = function(...)
				local w, estimated = width(...)
				return w * (wider or 1), estimated
			end
			---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
			local _, stubs = dofile("spec/support/client.lua")()
			local loaded = loadCore({ BUILD_ENTRY }, { global = { language = language } }, {
				GetLocale = function()
					return language
				end,
				CreateFont = RealFont.keepNamed(stubs.CreateFont),
			})
			enterWorld(loaded)
			local ns = loaded.ns
			local GuideText = ns.GuideText
			ns.GuideText = function(...)
				return RealFont.patch(GuideText(...))
			end
			local page = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
			page:SetSize(442, 546)
			local made = ns.NewGuideBindingField(page, action or "PAGLE_FISHING_KEY", label or "Fishing key")
			assert.are.same({}, loaded.client.errors)
			return made, ns.L
		end

		-- The dashed cap's words of a Fishing key field, as `unbound` makes it.
		local function waiting(language, wider)
			return unbound(language, wider).waitWords
		end

		-- The Casting page's Fishing key field and the Fishing clothes page's Swap gear field, as `unbound` makes
		-- them, each labelled as its page labels it (SETTINGS_FISHING_KEY, SETTINGS_SWAP_GEAR: Pagle_QoL's strings).
		local FIELDS = {
			PAGLE_FISHING_KEY = {
				ruRU = "Клавиша рыбалки",
				enUS = "Fishing key",
				deDE = "Angeltaste",
				esES = "Tecla de pesca",
			},
			PAGLE_SWAP_GEAR = {
				ruRU = "Переодеться",
				enUS = "Swap gear",
				deDE = "Ausrüstung wechseln",
				esES = "Cambiar equipo",
			},
		}

		-- Where the note's top stands under the field's (its one anchor, TOPRIGHT on the field's TOPLEFT).
		local function noteTop(note)
			return -note.points[1][5]
		end

		after_each(function()
			RealFont.width = width
		end)

		it("onb_r40 sets ruRU's words smaller until they take two lines in the cap, whole", function()
			for _, wider in ipairs({ false, 1.1 }) do
				local words = waiting("ruRU", wider or nil)
				local layout = RealFont.layout(words)
				local times = ("%s times the stand-in"):format(wider or 1)

				assert(layout.cut == nil, ("%s at %s, %s"):format(tostring(layout.cut), layout.size, times))
				assert.are.equal(2, #layout.lines)
				assert(layout.size < 14 and layout.size >= 10.5, ("set at %s, %s"):format(layout.size, times))
			end
		end)

		it("onb_r40 lets ruRU's note take a third line at its least size, whole and inside the field", function()
			for action, labels in pairs(FIELDS) do
				for _, wider in ipairs({ false, 1.1 }) do
					local made = unbound("ruRU", wider or nil, action, labels.ruRU)
					local layout = RealFont.layout(made.note)
					local times = ("%s, %s times the stand-in"):format(action, wider or 1)

					assert(layout.cut == nil, ("%s at %s, %s"):format(tostring(layout.cut), layout.size, times))
					assert(#layout.lines == 3, ("%d lines, %s"):format(#layout.lines, times))
					assert.are.equal(10.5, layout.size)
					assert.are.equal(3, made.note:GetMaxLines())
					-- the three lines stand inside the field's 62, clear of its 8 edge
					local top = noteTop(made.note)
					assert(
						top >= 8 and top + layout.height <= 62 - 8,
						("%s to %s, %s"):format(top, top + layout.height, times)
					)
				end
			end
		end)

		it("onb_r40 keeps the note where it was, on at most two lines, in enUS, deDE and esES", function()
			for action, labels in pairs(FIELDS) do
				for _, language in ipairs({ "enUS", "deDE", "esES" }) do
					local made = unbound(language, nil, action, labels[language])
					local layout = RealFont.layout(made.note)
					assert(#layout.lines <= 2, ("%s %s: %d lines"):format(language, action, #layout.lines))
					assert.is_nil(layout.cut)
					assert.are.equal(2, made.note:GetMaxLines())
					assert.are.equal(22.3 + 2.275, noteTop(made.note))
				end
			end
		end)

		it("onb_r40 leaves the words at 14 on one line in enUS, deDE and esES", function()
			for _, language in ipairs({ "enUS", "deDE", "esES" }) do
				local layout = RealFont.layout(waiting(language))
				assert.are.equal(14, layout.size)
				assert.are.equal(1, #layout.lines)
				assert.is_nil(layout.cut)
			end
		end)
	end)
end)

describe("the binding field's states (ONB-R40)", function()
	it("is the field's size, and reads Not bound: its label, a dashed cap and the default", function()
		local _, fishing = field()

		assert.are.equal("unbound", fishing.state)
		assert.are.same({ 382, 62 }, { fishing:GetSize() })
		assert.are.equal("PAGLE_FISHING_KEY", fishing.action)
		assert.are.same({ "Fishing key", "default: nothing is bound", "click to bind" }, texts(fishing))
	end)

	it("reads Bound with the first of two keys, as the action bars abbreviate it", function()
		local loaded, page = onPage()
		loaded.client.boundKeys.PAGLE_FISHING_KEY = { "SHIFT-F", "G" }

		local fishing = loaded.ns.NewGuideBindingField(page, "PAGLE_FISHING_KEY", "Fishing key")

		assert.are.equal("bound", fishing.state)
		assert.are.same({ "Fishing key", "s-F", "Bound" }, texts(fishing))
	end)

	it("listens after a click: the red cap, the Esc note, and the keyboard its own", function()
		local loaded, fishing = field()
		loaded.client.sounds = {}

		fishing:Click()

		assert.are.equal("listening", fishing.state)
		assert.are.same({ "Fishing key", "Esc leaves it as it was", "press a key…" }, texts(fishing))
		assert.is_true(fishing:IsKeyboardEnabled())
		assert.is_false(fishing.propagatesKeys)
		assert.are.same({ SOUND_CLICK }, loaded.client.sounds)
	end)
end)

describe("taking a key (ONB-R41, ONB-R42)", function()
	it("binds a free key to the action, saves the bindings and reads Bound (ONB-R42)", function()
		local loaded, fishing = field()

		fishing:Click()
		loaded.client.pressKey("F")

		assert.are.same({ "F" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.are.same({ 1 }, loaded.client.savedBindings)
		assert.are.equal("bound", fishing.state)
		assert.are.same({ "Fishing key", "F", "Bound" }, texts(fishing))
		assert.is_false(fishing:IsKeyboardEnabled())
	end)

	it("binds a key already on this action without asking (ONB-R42)", function()
		local loaded, page = onPage()
		loaded.client.boundKeys.PAGLE_FISHING_KEY = { "F", "G" }
		local fishing = loaded.ns.NewGuideBindingField(page, "PAGLE_FISHING_KEY", "Fishing key")

		fishing:Click()
		loaded.client.pressKey("G")

		assert.are.equal("bound", fishing.state)
		assert.are.same({ "G" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.are.same({ 1 }, loaded.client.savedBindings)
	end)

	it("ignores a bare modifier and UNKNOWN, and takes a key with its modifiers (ONB-R41)", function()
		local loaded, fishing = field()

		fishing:Click()
		loaded.client.keysDown.SHIFT = true
		loaded.client.pressKey("LSHIFT")
		loaded.client.pressKey("UNKNOWN")
		assert.are.equal("listening", fishing.state)
		assert.are.same({}, loaded.client.savedBindings)
		loaded.client.pressKey("F")

		assert.are.same({ "SHIFT-F" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.are.same({ "Fishing key", "s-F", "Bound" }, texts(fishing))
	end)

	it("leaves the binding as it was at Esc (ONB-R41)", function()
		local loaded, page = onPage()
		loaded.client.boundKeys.PAGLE_FISHING_KEY = { "F" }
		local fishing = loaded.ns.NewGuideBindingField(page, "PAGLE_FISHING_KEY", "Fishing key")

		fishing:Click()
		loaded.client.pressKey("ESCAPE")

		assert.are.same({ "F" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.are.same({}, loaded.client.savedBindings)
		assert.are.equal("bound", fishing.state)
		assert.is_false(fishing:IsKeyboardEnabled())
	end)

	it("takes no mouse button while listening (ONB-R41)", function()
		local loaded, fishing = field()

		fishing:Click()
		fishing:Click("Button4")
		fishing:Click("RightButton")

		assert.are.equal("listening", fishing.state)
		assert.is_nil(loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.is_true(fishing:IsKeyboardEnabled())
	end)

	it("stops listening when it hides, binding nothing (ONB-R41)", function()
		local loaded, fishing = field()

		fishing:Click()
		fishing:Hide()

		assert.are.equal("unbound", fishing.state)
		assert.is_false(fishing:IsKeyboardEnabled())
		assert.are.same({}, loaded.client.savedBindings)
	end)
end)

describe("the conflict box (ONB-R43)", function()
	-- A Fishing key field listening, F on Assist Target. Returns the client load and the field, after F is pressed.
	local function conflict(action)
		local loaded, page = onPage()
		loaded.client.boundKeys.ASSISTTARGET = { "F" }
		local bindingField = loaded.ns.NewGuideBindingField(page, action or "PAGLE_FISHING_KEY", "Fishing key")
		bindingField:Click()
		loaded.client.pressKey("F")
		return loaded, bindingField
	end

	it("asks before taking a key that already does something, binding nothing yet", function()
		local loaded, fishing = conflict()

		assert.are.equal("conflict", fishing.state)
		assert.are.same({
			"F",
			"already does " .. RED .. "Assist Target|r. Use it for fishing instead?",
			"Use F for fishing",
			"Pick another key",
			"the old use is listed, never silently lost",
		}, texts(fishing.conflict))
		assert.are.same({ "F" }, loaded.client.boundKeys.ASSISTTARGET)
		assert.are.same({}, loaded.client.savedBindings)
		assert.is_false(fishing:IsKeyboardEnabled())
	end)

	it("binds the key at Use, taking it from the old action, saves, and says what it used to do", function()
		local loaded, fishing = conflict()

		click(fishing, "Use F for fishing")

		assert.are.same({ "F" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.are.same({}, loaded.client.boundKeys.ASSISTTARGET)
		assert.are.same({ 1 }, loaded.client.savedBindings)
		assert.are.same({
			"Pagle: F now casts. It used to do Assist Target; rebind that in Key Bindings if you need it.",
		}, loaded.printed)
		assert.are.equal("bound", fishing.state)
		assert.is_false(fishing.conflict:IsShown())
	end)

	it("listens again at Pick another key, binding nothing", function()
		local loaded, fishing = conflict()

		click(fishing, "Pick another key")

		assert.are.equal("listening", fishing.state)
		assert.is_false(fishing.conflict:IsShown())
		assert.is_true(fishing:IsKeyboardEnabled())
		assert.are.same({ "F" }, loaded.client.boundKeys.ASSISTTARGET)
		loaded.client.pressKey("H")
		assert.are.same({ "H" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
	end)

	it("asks and tells in Swap gear's words for PAGLE_SWAP_GEAR", function()
		local loaded, swap = conflict("PAGLE_SWAP_GEAR")

		assert.are.equal(
			"already does " .. RED .. "Assist Target|r. Use it to swap gear instead?",
			texts(swap.conflict)[2]
		)
		click(swap, "Use F to swap gear")

		assert.are.same({ "F" }, loaded.client.boundKeys.PAGLE_SWAP_GEAR)
		assert.are.same({
			"Pagle: F now swaps your gear. It used to do Assist Target; rebind that in Key Bindings if you need it.",
		}, loaded.printed)
	end)
end)

describe("never while restricted, never the other key (ONB-R44, ONB-R25)", function()
	it("takes no click while restricted, greyed, and is live again after", function()
		local loaded, fishing = field()

		setCombat(loaded, true)
		fishing:Click()

		assert.are.equal("unbound", fishing.state)
		assert.is_false(fishing:IsKeyboardEnabled())
		assert.is_false(fishing:IsEnabled())
		setCombat(loaded, false)
		assert.is_true(fishing:IsEnabled())
	end)

	it("stops listening when a restriction starts, binding nothing", function()
		local loaded, fishing = field()
		fishing:Click()

		setCombat(loaded, true)

		assert.are.equal("unbound", fishing.state)
		assert.is_false(fishing:IsKeyboardEnabled())
	end)

	it("closes the conflict box when a restriction starts, binding nothing", function()
		local loaded, page = onPage()
		loaded.client.boundKeys.ASSISTTARGET = { "F" }
		local fishing = loaded.ns.NewGuideBindingField(page, "PAGLE_FISHING_KEY", "Fishing key")
		fishing:Click()
		loaded.client.pressKey("F")

		setCombat(loaded, true)

		assert.are.equal("unbound", fishing.state)
		assert.is_false(fishing.conflict:IsShown())
		assert.are.same({ "F" }, loaded.client.boundKeys.ASSISTTARGET)
	end)

	it("replaces only the key it shows, keeping the action's other key", function()
		local loaded, page = onPage()
		loaded.client.boundKeys.PAGLE_FISHING_KEY = { "F", "G" }
		local fishing = loaded.ns.NewGuideBindingField(page, "PAGLE_FISHING_KEY", "Fishing key")

		fishing:Click()
		loaded.client.pressKey("H")

		assert.are.same({ "H", "G" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
		assert.are.same({ "Fishing key", "H", "Bound" }, texts(fishing))
	end)

	it("redraws at UPDATE_BINDINGS, and at Refresh, with a key bound elsewhere", function()
		local loaded, fishing = field()

		loaded.client.boundKeys.PAGLE_FISHING_KEY = { "J" }
		loaded.client.fire("UPDATE_BINDINGS")
		assert.are.same({ "Fishing key", "J", "Bound" }, texts(fishing))
		loaded.client.boundKeys.PAGLE_FISHING_KEY = {}
		fishing:Refresh()

		assert.are.same({ "Fishing key", "default: nothing is bound", "click to bind" }, texts(fishing))
	end)

	it("takes no click while its step greys it, and stops listening (ONB-R32, ONB-R100)", function()
		local loaded, fishing = field()
		fishing:Click()

		fishing:SetGreyed(true)
		fishing:Click()

		assert.are.equal("unbound", fishing.state)
		assert.is_false(fishing:IsKeyboardEnabled())
		assert.is_false(fishing:IsEnabled())
		fishing:SetGreyed(false)
		fishing:Click()
		assert.are.equal("listening", fishing.state)
		assert.are.same({}, loaded.client.savedBindings)
	end)
end)

describe("the binding field on a step's nav (Contracts)", function()
	it("is the widget nav.BindingField makes", function()
		local loaded = loadCore({ BUILD_ENTRY })
		loaded.client.addons.Pagle_QoL = { metadata = { ["X-Pagle-API"] = "1" } }
		local M = loaded.env.Pagle.RegisterModule({ name = "QoL", title = "QoL", order = 50 })
		local made
		M:RegisterGuideStep({
			id = "casting",
			order = 30,
			ribbon = "Casting",
			build = function(_, right, nav)
				made = nav.BindingField(right, "PAGLE_FISHING_KEY", "Fishing key")
			end,
		})
		enterWorld(loaded, 3)
		loaded.ns.db.profile.announcements.motion = false
		loaded.env.SlashCmdList.PAGLE("dev on")
		loaded.env.SlashCmdList.PAGLE("dev onboarding step casting")

		assert.are.equal("unbound", made.state)
		made:Click()
		loaded.client.pressKey("F")
		assert.are.same({ "F" }, loaded.client.boundKeys.PAGLE_FISHING_KEY)
	end)
end)
