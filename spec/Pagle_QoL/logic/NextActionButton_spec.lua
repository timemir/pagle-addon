-- The next-action button's pure logic (QOL-R70–R74): when it shows, its icon and label, its hotkey text, its tooltip
-- and its saved place.

describe("QoL's next-action button logic", function()
	local ns = loadAddon("Pagle_QoL", FOREVER_GLOBALS).ns

	local FISHING_ICON, SET_ICON, LURE_ICON, LAST_ICON, CLAM_ICON = 136245, 132932, 134335, 133001, 134432

	describe("ns.ButtonShown", function()
		-- What the button reads: the setting on, QoL not standing down, and no stretch, pole or gear step.
		---@param fields table?
		---@return PagleQoLButtonShownInput
		local function input(fields)
			local read =
				{ setting = true, standingDown = false, stretch = false, poleInHand = false, gearReady = false }
			for key, value in pairs(fields or {}) do
				read[key] = value
			end
			return read
		end

		it("shows while a stretch runs, a pole is in hand or the gear step is ready (QOL-R72)", function()
			assert.is_true(ns.ButtonShown(input({ stretch = true })))
			assert.is_true(ns.ButtonShown(input({ poleInHand = true })))
			assert.is_true(ns.ButtonShown(input({ gearReady = true })))
		end)

		it("is hidden with no stretch, no pole and no gear step (QOL-R72)", function()
			assert.is_false(ns.ButtonShown(input()))
		end)

		it("is hidden with the setting off, or while QoL stands down (QOL-R72, QOL-R82)", function()
			assert.is_false(ns.ButtonShown(input({ setting = false, poleInHand = true, stretch = true })))
			assert.is_false(ns.ButtonShown(input({ standingDown = true, poleInHand = true, gearReady = true })))
		end)
	end)

	describe("ns.ButtonLook", function()
		local icons = { fishing = FISHING_ICON, set = SET_ICON, item = LURE_ICON }

		it("shows the Fishing icon labelled Cast or Reel (QOL-R71)", function()
			assert.are.same({ icon = FISHING_ICON, label = "Cast", desaturated = false }, ns.ButtonLook("cast", icons))
			assert.are.same({ icon = FISHING_ICON, label = "Reel", desaturated = false }, ns.ButtonLook("reel", icons))
		end)

		it("shows the fishing set's icon labelled Gear, and a lure's item icon labelled Lure (QOL-R71)", function()
			assert.are.same({ icon = SET_ICON, label = "Gear", desaturated = false }, ns.ButtonLook("gear", icons))
			assert.are.same({ icon = LURE_ICON, label = "Lure", desaturated = false }, ns.ButtonLook("lure", icons))
		end)

		it("shows a clam's item icon labelled Clam (QOL-R71)", function()
			local clamIcons = { fishing = FISHING_ICON, item = CLAM_ICON }

			assert.are.same({ icon = CLAM_ICON, label = "Clam", desaturated = false }, ns.ButtonLook("clam", clamIcons))
			assert.are.equal(FISHING_ICON, ns.ButtonLook("clam", { fishing = FISHING_ICON }).icon)
		end)

		it("keeps the last icon for nothing, desaturated and with no label (QOL-R71)", function()
			assert.are.same({ icon = LAST_ICON, desaturated = true }, ns.ButtonLook("nothing", icons, LAST_ICON))
		end)

		it("shows the Fishing icon for nothing when no icon was shown yet (QOL-R71)", function()
			assert.are.same({ icon = FISHING_ICON, desaturated = true }, ns.ButtonLook("nothing", icons))
		end)

		it("falls back to the Fishing icon for a set or an item whose icon isn't known", function()
			local fishingOnly = { fishing = FISHING_ICON }
			assert.are.equal(FISHING_ICON, ns.ButtonLook("gear", fishingOnly).icon)
			assert.are.equal(FISHING_ICON, ns.ButtonLook("lure", fishingOnly).icon)
		end)
	end)

	describe("ns.ButtonHotkey", function()
		-- GetBindingText(key, true): the short form action bars use.
		local function short(key)
			return (key:gsub("SHIFT%-", "s-"))
		end

		it("is the Fishing key's first bound key in its short form (QOL-R70)", function()
			assert.are.equal("s-F", ns.ButtonHotkey("both", { "SHIFT-F", "G" }, short))
			assert.are.equal("s-F", ns.ButtonHotkey("key", { "SHIFT-F" }, short))
		end)

		it("is none under Input Double-click, or with no key bound (QOL-R70, QOL-R11)", function()
			assert.is_nil(ns.ButtonHotkey("click", { "F" }, short))
			assert.is_nil(ns.ButtonHotkey("both", {}, short))
		end)
	end)

	describe("ns.ButtonTooltip", function()
		it("names the next action: Cast, Reel in or Nothing to do (QOL-R74)", function()
			assert.are.equal("Cast", ns.ButtonTooltip("cast"))
			assert.are.equal("Reel in", ns.ButtonTooltip("reel"))
			assert.are.equal("Nothing to do", ns.ButtonTooltip("nothing"))
		end)

		it("names the fishing set and the lure (QOL-R74)", function()
			assert.are.equal("Put on Fishing", ns.ButtonTooltip("gear", "Fishing"))
			assert.are.equal("Apply Shiny Bauble", ns.ButtonTooltip("lure", "Shiny Bauble"))
		end)

		it("names the clam: Open {clam name} (QOL-R74)", function()
			assert.are.equal("Open Thick-shelled Clam", ns.ButtonTooltip("clam", "Thick-shelled Clam"))
		end)

		it("is nil while the set's or the item's name isn't known yet, so the tooltip waits (QOL-R74)", function()
			assert.is_nil(ns.ButtonTooltip("gear", nil))
			assert.is_nil(ns.ButtonTooltip("lure", nil))
			assert.is_nil(ns.ButtonTooltip("clam", nil))
		end)
	end)

	describe("the button's place", function()
		it("is 36 px, by default at the bottom centre 230 px up (QOL-R70, QOL-R73, qol.md › Tunables)", function()
			assert.are.equal(36, ns.BUTTON_SIZE)
			assert.are.same(
				{ point = "BOTTOM", relativeTo = "UIParent", relativePoint = "BOTTOM", x = 0, y = 230 },
				ns.ButtonPoint(nil)
			)
		end)

		it("is the saved point, relative to UIParent (QOL-R73, qol.md › Data)", function()
			local saved = ns.SavedButtonPoint("BOTTOMLEFT", "BOTTOMLEFT", 512.5, 300)

			assert.are.same(
				{ point = "BOTTOMLEFT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 512.5, y = 300 },
				saved
			)
			assert.are.same(saved, ns.ButtonPoint(saved))
		end)

		it("is the default for a saved point it can't read (QOL-R73)", function()
			local default = ns.ButtonPoint(nil)

			assert.are.same(default, ns.ButtonPoint({ point = "CENTER", relativePoint = "CENTER", x = "far" }))
			assert.are.same(default, ns.ButtonPoint({ relativePoint = "CENTER", x = 0, y = 0 }))
			assert.are.same(default, ns.ButtonPoint("BOTTOM"))
		end)

		it("hands out a fresh default each time, so changing one changes no other (QOL-R73)", function()
			local first = ns.ButtonPoint(nil)
			first.y = 5

			assert.are.equal(230, ns.ButtonPoint(nil).y)
		end)
	end)
end)
