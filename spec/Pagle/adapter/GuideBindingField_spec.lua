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
