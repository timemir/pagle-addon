-- The Look and Feel page and the slot dropdowns as pure logic over the goods registry: which slots show under which
-- header, a slot's owned choices and how many more the Curio Shop has (settings.md SET-R50, SET-R51, SET-R30; CORE-R42;
-- wallet-and-shop.md › UI, SHOP-R30, SHOP-R35).

describe("Look and Feel's logic", function()
	local ns = loadAddon("Pagle", FOREVER_GLOBALS).ns

	-- A registry over a fresh PagleDB with Core's three slots (as SHOP-R25 has them, in its order), the Ledger (10) and
	-- Hunts (20) On; `env.on` lists the Modules On by name and order, which a spec changes to turn one off.
	local function newGoods()
		local env = {
			db = { global = { goods = {} }, profile = { appearance = {} } },
			on = { Ledger = 10, Hunts = 20 },
		}
		env.goods = ns.NewGoods({
			db = function()
				return env.db
			end,
			modules = function()
				local list = {}
				for name, order in pairs(env.on) do
					list[#list + 1] = { def = { name = name, title = name, order = order } }
				end
				table.sort(list, function(a, b)
					return a.def.order < b.def.order
				end)
				return list
			end,
			fire = function() end,
			call = function(fn, ...)
				return fn(...)
			end,
			report = function() end,
		})
		local goods = env.goods
		goods:RegisterSlot("Core", { id = "core.toaststyle", label = "Toast style", category = "Announcements" })
		goods:RegisterGood(
			"Core",
			{ id = "core.toaststyle.page", slot = "core.toaststyle", name = "Torn Page", default = true }
		)
		goods:RegisterGood(
			"Core",
			{ id = "core.toaststyle.ripple", slot = "core.toaststyle", name = "Ripple", tier = 1 }
		)
		goods:RegisterGood(
			"Core",
			{ id = "core.toaststyle.lantern", slot = "core.toaststyle", name = "Lantern", tier = 2 }
		)
		goods:RegisterSlot("Core", { id = "core.soundset", label = "Sound set", category = "Announcements" })
		goods:RegisterGood(
			"Core",
			{ id = "core.soundset.driftwood", slot = "core.soundset", name = "Driftwood", default = true }
		)
		goods:RegisterSlot("Core", { id = "core.crest", label = "Crests", category = "Crests" })
		goods:RegisterGood("Core", { id = "core.crest.plain", slot = "core.crest", name = "Plain", default = true })
		return env
	end

	-- Registers `module`'s slot `id` in `category`, with one default good "<id>.plain".
	local function slotWithDefault(env, module, id, category)
		env.goods:RegisterSlot(module, { id = id, label = id, category = category })
		env.goods:RegisterGood(module, { id = id .. ".plain", slot = id, name = "Plain", default = true })
	end

	-- The sections as "<category>: <slot>, <slot>" lines.
	local function sectionLines(goods)
		local lines = {}
		for i, section in ipairs(ns.LookAndFeelSections(goods)) do
			local ids = {}
			for j, slot in ipairs(section.slots) do
				ids[j] = slot.id
			end
			lines[i] = section.category .. ": " .. table.concat(ids, ", ")
		end
		return lines
	end

	describe("ns.LookAndFeelSections", function()
		it("groups the live slots by category in SET-R50's order, skipping a category with none (SET-R50)", function()
			local env = newGoods()
			slotWithDefault(env, "Hunts", "hunts.frame", "Trackers")
			slotWithDefault(env, "Ledger", "ledger.binding", "Fish Journal")

			assert.are.same({
				"Announcements: core.toaststyle, core.soundset",
				"Crests: core.crest",
				"Fish Journal: ledger.binding",
				"Trackers: hunts.frame",
			}, sectionLines(env.goods))
		end)

		it("puts Core's slots first in a category, then each Module's by def.order (SET-R50)", function()
			local env = newGoods()
			slotWithDefault(env, "Hunts", "hunts.frame", "Trackers")
			slotWithDefault(env, "Ledger", "ledger.frame", "Trackers")
			slotWithDefault(env, "Core", "core.frame", "Trackers")

			assert.are.equal("Trackers: core.frame, ledger.frame, hunts.frame", sectionLines(env.goods)[3])
		end)

		it("leaves out a slot with no goods yet, which has nothing to pick (SET-R51)", function()
			local env = newGoods()
			env.goods:RegisterSlot("Hunts", { id = "hunts.cover", label = "Notebook cover", category = "Hunts" })

			assert.are.equal(2, #ns.LookAndFeelSections(env.goods))
		end)

		it("leaves out the slots of a Module that isn't On (SET-R4, SHOP-R35)", function()
			local env = newGoods()
			slotWithDefault(env, "Ledger", "ledger.binding", "Fish Journal")
			env.on.Ledger = nil

			assert.are.same(
				{ "Announcements: core.toaststyle, core.soundset", "Crests: core.crest" },
				sectionLines(env.goods)
			)
		end)
	end)

	describe("ns.CoreAnnouncementSlots", function()
		it(
			"lists Core's Announcements slots with goods, in registration order, not a Module's (CORE-R42, SET-R30)",
			function()
				local env = newGoods()
				slotWithDefault(env, "Hunts", "hunts.chime", "Announcements")
				env.goods:RegisterSlot("Core", { id = "core.empty", label = "Empty", category = "Announcements" })

				local ids = {}
				for i, slot in ipairs(ns.CoreAnnouncementSlots(env.goods)) do
					ids[i] = slot.id
				end
				assert.are.same({ "core.toaststyle", "core.soundset" }, ids)
			end
		)
	end)

	describe("ns.SectionSlots", function()
		-- Each Module's slots, as "<module>: <slot>, <slot>" lines sorted by Module name.
		local function slotLines(byModule)
			local lines = {}
			for module, slots in pairs(byModule) do
				local ids = {}
				for i, slot in ipairs(slots) do
					ids[i] = slot.id
				end
				lines[#lines + 1] = module .. ": " .. table.concat(ids, ", ")
			end
			table.sort(lines)
			return lines
		end

		it(
			"gives each On Module its Trackers slots with goods on Trackers, and Core none (SET-R44, CORE-R42)",
			function()
				local env = newGoods()
				slotWithDefault(env, "Hunts", "hunts.trackerframe", "Trackers")
				slotWithDefault(env, "Hunts", "hunts.cover", "Hunts")
				slotWithDefault(env, "Hunts", "hunts.second", "Trackers")
				slotWithDefault(env, "Ledger", "ledger.binding", "Fish Journal")
				slotWithDefault(env, "Core", "core.frame", "Trackers")
				env.goods:RegisterSlot("Ledger", { id = "ledger.empty", label = "Empty", category = "Trackers" })

				assert.are.same(
					{ "Hunts: hunts.trackerframe, hunts.second" },
					slotLines(ns.SectionSlots(env.goods, "trackers"))
				)
			end
		)

		it("gives none on another page, or for a Module that isn't On (SET-R44, SET-R4)", function()
			local env = newGoods()
			slotWithDefault(env, "Hunts", "hunts.trackerframe", "Trackers")

			assert.are.same({}, ns.SectionSlots(env.goods, "announcements"))
			env.on.Hunts = nil
			assert.are.same({}, ns.SectionSlots(env.goods, "trackers"))
		end)
	end)

	describe("ns.SlotChoices", function()
		it("lists the slot's owned goods by name in registration order (SET-R51, SHOP-R30)", function()
			local env = newGoods()
			env.goods:SetPurchased({ ["core.toaststyle.lantern"] = true })

			assert.are.same({
				{ value = "core.toaststyle.page", label = "Torn Page" },
				{ value = "core.toaststyle.lantern", label = "Lantern" },
			}, ns.SlotChoices(env.goods, "core.toaststyle"))
		end)

		it("lists an earned good once its cached isEarned() is true (SET-R51, SHOP-R30)", function()
			local env = newGoods()
			local earned = false
			env.goods:RegisterSlot(
				"Ledger",
				{ id = "ledger.binding", label = "Journal binding", category = "Fish Journal" }
			)
			env.goods:RegisterGood(
				"Ledger",
				{ id = "ledger.binding.field", slot = "ledger.binding", name = "Field", default = true }
			)
			env.goods:RegisterGood("Ledger", {
				id = "ledger.binding.hide",
				slot = "ledger.binding",
				name = "Tanned Hide",
				isEarned = function()
					return earned
				end,
				earnedText = "Angler Level 10",
			})
			assert.are.equal(1, #ns.SlotChoices(env.goods, "ledger.binding"))

			earned = true
			env.goods:Refresh("Ledger")

			assert.are.same({
				{ value = "ledger.binding.field", label = "Field" },
				{ value = "ledger.binding.hide", label = "Tanned Hide" },
			}, ns.SlotChoices(env.goods, "ledger.binding"))
		end)
	end)

	describe("ns.SlotMoreInShop", function()
		it("counts the slot's for-sale goods not owned (SET-R51)", function()
			local env = newGoods()
			assert.are.equal(2, ns.SlotMoreInShop(env.goods, "core.toaststyle"))

			env.goods:SetPurchased({ ["core.toaststyle.ripple"] = true })

			assert.are.equal(1, ns.SlotMoreInShop(env.goods, "core.toaststyle"))
			assert.are.equal(0, ns.SlotMoreInShop(env.goods, "core.soundset"))
		end)

		it("doesn't count an earned good, which isn't for sale (SET-R51, SHOP-R22)", function()
			local env = newGoods()
			env.goods:RegisterSlot(
				"Ledger",
				{ id = "ledger.binding", label = "Journal binding", category = "Fish Journal" }
			)
			env.goods:RegisterGood(
				"Ledger",
				{ id = "ledger.binding.field", slot = "ledger.binding", name = "Field", default = true }
			)
			env.goods:RegisterGood("Ledger", {
				id = "ledger.binding.hide",
				slot = "ledger.binding",
				name = "Tanned Hide",
				isEarned = function()
					return false
				end,
				earnedText = "Angler Level 10",
			})

			assert.are.equal(0, ns.SlotMoreInShop(env.goods, "ledger.binding"))
		end)
	end)
end)
