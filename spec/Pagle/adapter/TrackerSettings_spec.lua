-- The Trackers page's frame rows and its Defaults, driven through the fake client's Settings panel over a fixture
-- Hunts that adds a "trackers" checkbox and registers a "Trackers" slot (settings.md SET-R3, SET-R40, SET-R41,
-- SET-R44, SET-R45, SET-R51, SET-R60; CORE-R42's slot bullet; wallet-and-shop.md SHOP-R21, SHOP-R30, SHOP-R32).

-- Core with the Ledger, Hunts and Stats installed, over a saved PagleDB (`saved`, if given), before PLAYER_LOGIN.
---@param saved table?
---@return LoadedAddon
local function session(saved)
	local loaded = loadCore(nil, saved)
	loaded.client.addons.Pagle_Stats = { metadata = { ["X-Pagle-API"] = "1" } }
	return loaded
end

-- A fixture Module `name` at `order` with a "trackers" checkbox `label`, on by default, stored in the returned
-- table's `shown`; and, unless `noSlot`, a "Trackers" slot `<name>.trackerframe` with None (default) and Ink wash
-- (tier 1). Returns the handle and the stored state.
---@param loaded LoadedAddon
---@param name string
---@param order number
---@param options { label: string?, noSlot: boolean?, noRows: boolean? }?
local function trackerModule(loaded, name, order, options)
	options = options or {}
	local handle = loaded.env.Pagle.RegisterModule({ name = name, title = name, order = order })
	local state = { shown = true }
	if not options.noRows then
		handle:AddSetting("trackers", {
			kind = "checkbox",
			id = "tracker",
			label = options.label or ("Show the %s tracker"):format(name),
			get = function()
				return state.shown
			end,
			set = function(value)
				state.shown = value
			end,
			default = true,
		})
	end
	if not options.noSlot then
		local slot = name:lower() .. ".trackerframe"
		handle:RegisterSlot({ id = slot, label = name .. " tracker frame", category = "Trackers" })
		handle:RegisterGood({ id = slot .. ".none", slot = slot, name = "None", default = true })
		handle:RegisterGood({ id = slot .. ".inkwash", slot = slot, name = "Ink wash", tier = 1 })
	end
	return handle, state
end

-- A registered Settings page by name.
local function page(loaded, name)
	return assert(loaded.client.settings.category(name), "no page " .. name)
end

-- Each shown row of a page as "<name>", with "  " before an indented one.
local function names(rows)
	local out = {}
	for i, row in ipairs(rows) do
		out[i] = (row.initializer:GetParentInitializer() and "  " or "") .. row.initializer:GetName()
	end
	return out
end

-- The shown row whose label is `label`.
local function rowNamed(rows, label)
	for _, row in ipairs(rows) do
		if row.initializer:GetName() == label then
			return row
		end
	end
	error("no row " .. label)
end

-- The values of a dropdown row's options, read as the dropdown opens.
local function optionValues(row)
	local values = {}
	for i, option in ipairs(row.initializer:GetOptions()()) do
		values[i] = option.value .. "=" .. option.label
	end
	return values
end

local function showTrackers(loaded)
	return loaded.client.settings.show(page(loaded, "Trackers"))
end

describe("The Trackers page's frame row", function()
	it("ends the Module's section, unindented, after its own rows (SET-R44, SET-R41, CORE-R42)", function()
		local loaded = session()
		trackerModule(loaded, "Hunts", 20)

		enterWorld(loaded)

		assert.are.same(
			{ "Tracker position", "Hunts", "Show the Hunts tracker", "Hunts tracker frame" },
			names(showTrackers(loaded))
		)
	end)

	it("is the slot dropdown, listing only the slot's owned goods (SET-R44, SET-R51, SHOP-R30)", function()
		local loaded = session()
		trackerModule(loaded, "Hunts", 20)
		enterWorld(loaded)

		local row = rowNamed(showTrackers(loaded), "Hunts tracker frame")

		assert.are.equal("SettingsDropdownControlTemplate", row.initializer.template)
		assert.are.equal("hunts.trackerframe.none", row.frame.value)
		assert.are.same({ "hunts.trackerframe.none=None" }, optionValues(row))
		assert.are.same({ "1 more in the Curio Shop" }, loaded.client.settings.textsOf(row.frame))
		loaded.ns.goods:SetPurchased({ ["hunts.trackerframe.inkwash"] = true })
		assert.are.same({ "hunts.trackerframe.none=None", "hunts.trackerframe.inkwash=Ink wash" }, optionValues(row))
	end)

	it("isn't greyed out or hung under the checkbox while the tracker is off (SET-R44, SET-R2)", function()
		local loaded = session()
		local _, state = trackerModule(loaded, "Hunts", 20)
		state.shown = false
		enterWorld(loaded)

		local rows = showTrackers(loaded)
		local row = rowNamed(rows, "Hunts tracker frame")

		assert.is_true(row.frame.enabled)
		assert.is_nil(row.initializer:GetParentInitializer())
		rowNamed(rows, "Show the Hunts tracker").initializer:GetSetting():SetValue(true)
		assert.is_true(row.frame.enabled)
	end)

	it(
		"equips the frame picked, and Look and Feel's dropdown for the slot shows it (SET-R44, SET-R51, SHOP-R32)",
		function()
			local loaded = session()
			trackerModule(loaded, "Hunts", 20)
			enterWorld(loaded)
			loaded.ns.goods:SetPurchased({ ["hunts.trackerframe.inkwash"] = true })
			local row = rowNamed(showTrackers(loaded), "Hunts tracker frame")

			row.initializer:GetSetting():SetValue("hunts.trackerframe.inkwash")

			assert.are.equal("hunts.trackerframe.inkwash", loaded.env.Pagle.GetEquipped("hunts.trackerframe"))
			assert.are.equal("Ink wash", row.frame.valueLabel)
			local look = rowNamed(loaded.client.settings.show(page(loaded, "Look and Feel")), "Hunts tracker frame")
			assert.are.same({ "hunts.trackerframe.inkwash", "Ink wash" }, { look.frame.value, look.frame.valueLabel })
		end
	)

	it("redraws at once when the frame is picked elsewhere (SET-R51, SET-R62)", function()
		local loaded = session()
		trackerModule(loaded, "Hunts", 20)
		enterWorld(loaded)
		loaded.ns.goods:SetPurchased({ ["hunts.trackerframe.inkwash"] = true })
		local row = rowNamed(showTrackers(loaded), "Hunts tracker frame")

		loaded.env.Pagle.SetEquipped("hunts.trackerframe", "hunts.trackerframe.inkwash")

		assert.are.same({ "hunts.trackerframe.inkwash", "Ink wash" }, { row.frame.value, row.frame.valueLabel })
	end)

	it("isn't added for a Module with no Trackers slot (SET-R44)", function()
		local loaded = session()
		trackerModule(loaded, "Hunts", 20)
		trackerModule(loaded, "Stats", 30, { noSlot = true })
		enterWorld(loaded)

		assert.are.same({
			"Tracker position",
			"Hunts",
			"Show the Hunts tracker",
			"Hunts tracker frame",
			"Stats",
			"Show the Stats tracker",
		}, names(showTrackers(loaded)))
	end)

	it(
		"makes the section of a Module that added no Trackers row: its header, then its frame (SET-R44, SET-R3)",
		function()
			local loaded = session()
			trackerModule(loaded, "Stats", 30, { noRows = true })
			enterWorld(loaded)

			assert.are.same({ "Tracker position", "Stats", "Stats tracker frame" }, names(showTrackers(loaded)))
		end
	)
end)

describe("The Trackers page's Defaults", function()
	-- Core with Hunts' checkbox off and Ink wash bought and equipped, logged in, the dock Shift-dragged to (812, 640).
	-- Returns the loaded addon and Hunts' stored state.
	local function changed()
		local loaded = session({
			profiles = { Default = { appearance = { ["hunts.trackerframe"] = "hunts.trackerframe.inkwash" } } },
		})
		local hunts, state = trackerModule(loaded, "Hunts", 20)
		local frame = loaded.env.CreateFrame("Frame", nil, loaded.env.UIParent)
		frame:SetSize(200, 40)
		hunts:RegisterTracker({ id = "hunts", order = 20, frame = frame })
		state.shown = false
		enterWorld(loaded)
		loaded.ns.goods:SetPurchased({ ["hunts.trackerframe.inkwash"] = true, ["core.crest.crest1"] = true })
		loaded.env.Pagle.SetEquipped("core.crest", "core.crest.crest1")
		loaded.client.keysDown.SHIFT = true
		frame:GetScript("OnDragStart")(frame, "LeftButton")
		loaded.ns.dockFrame.screenRight, loaded.ns.dockFrame.screenTop = 812, 640
		frame:GetScript("OnDragStop")(frame)
		return loaded, state
	end
	local DROPPED = { point = "TOPRIGHT", relativeTo = "UIParent", relativePoint = "BOTTOMLEFT", x = 812, y = 640 }

	it(
		"turns the checkbox and the frame back to their defaults, and leaves the dock where it is (SET-R45, SET-R60)",
		function()
			local loaded, state = changed()
			assert.are.same(DROPPED, loaded.ns.db.profile.dock.point)
			assert.are.equal("hunts.trackerframe.inkwash", loaded.env.Pagle.GetEquipped("hunts.trackerframe"))
			showTrackers(loaded)

			loaded.client.settings.defaults(page(loaded, "Trackers"))

			assert.is_true(state.shown)
			assert.are.equal("hunts.trackerframe.none", loaded.env.Pagle.GetEquipped("hunts.trackerframe"))
			assert.is_true(loaded.env.Pagle.IsOwned("hunts.trackerframe.inkwash"))
			assert.are.same(DROPPED, loaded.ns.db.profile.dock.point)
		end
	)

	it("leaves the looks shown only on other pages alone (SET-R45, SET-R60)", function()
		local loaded = changed()

		loaded.client.settings.defaults(page(loaded, "Trackers"))

		assert.are.equal("core.crest.crest1", loaded.env.Pagle.GetEquipped("core.crest"))
	end)
end)
