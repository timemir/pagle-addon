-- Hunts' goods on FakePagle (HNT-R120–R122, HNT-R70; SHOP-R21–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90): the two slots
-- and seven goods in Core's goods registry, their names from lore, their previews on the shop's stage, and the board's
-- leather in the equipped cover.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local COVER, FRAME = "hunts.notebookcover", "hunts.trackerframe"

-- HNT-R121's goods, in its order, with their kinds.
local GOODS = hunts.GOODS

-- A good's kind as HNT-R121's table writes it; "earned" for one with isEarned (Hunts has none, HNT-R122).
---@param good PagleRegisteredGood
---@return string
local function kindOf(good)
	if good.isEarned then
		return "earned"
	elseif good.default then
		return "default"
	end
	return "tier " .. tostring(good.tier)
end

-- Every widget under `widget`, depth first.
local function descendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		list[#list + 1] = child
		descendants(child, list)
	end
	return list
end

-- Every widget under `widget` that shows, depth first: shown, under shown parents.
local function shownDescendants(widget, list)
	list = list or {}
	for _, child in ipairs(widget.children) do
		if child.shown then
			list[#list + 1] = child
			shownDescendants(child, list)
		end
	end
	return list
end

-- The texts of every shown font string under `widget`, depth first.
local function textsOf(widget)
	local texts = {}
	for _, child in ipairs(descendants(widget)) do
		if child.kind == "FontString" and child.shown and child.text then
			texts[#texts + 1] = child.text
		end
	end
	return texts
end

-- Pagle_Hunts on a fake that has logged in.
---@param options HuntsLoadOptions?
local function loggedIn(options)
	local loaded, fake = hunts.load(nil, options)
	fake.login()
	return loaded, fake
end

describe("Hunts' goods", function()
	it(
		"register the slots hunts.notebookcover (Hunts) and hunts.trackerframe (Trackers), with HNT-R121's goods, defaults and tiers, none earned (HNT-R120, HNT-R121, HNT-R122, SHOP-R21, SHOP-R22)",
		function()
			local _, fake = loggedIn()
			local goods = fake.ns.goods

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				if slot.module == "Hunts" then
					slots[#slots + 1] = { slot.id, slot.label, slot.category }
				end
			end
			assert.are.same({
				{ COVER, "Notebook cover", "Hunts" },
				{ FRAME, "Hunts tracker frame", "Trackers" },
			}, slots)
			for slot, expected in pairs(GOODS) do
				local registered = {}
				for i, good in ipairs(goods:GoodsOf(slot)) do
					registered[i] = { good.id, kindOf(good) }
				end
				assert.are.same(expected, registered)
			end
			assert.are.same({ "hunts.notebookcover.leather", "hunts.trackerframe.none" }, {
				fake.Pagle.GetEquipped(COVER),
				fake.Pagle.GetEquipped(FRAME),
			})
		end
	)

	it("sell for 150, 400 and 900 Coins at tiers 1, 2 and 3, in the Curio Shop (HNT-R121, SHOP-R22)", function()
		local _, fake = loggedIn()
		local shop = fake.ns.ShopModel(tostring)

		local prices = {}
		for _, id in ipairs({
			"hunts.notebookcover.oilcloth",
			"hunts.notebookcover.tooled",
			"hunts.notebookcover.verdigris",
			"hunts.trackerframe.inkwash",
			"hunts.trackerframe.waxseal",
		}) do
			prices[#prices + 1] = shop:Entry(id).price
		end
		assert.are.same({ 150, 400, 900, 150, 400 }, prices)
		assert.are.same({ "Hunts", "Hunts" }, {
			fake.Pagle.GetGood("hunts.notebookcover.oilcloth").module,
			fake.Pagle.GetGood("hunts.trackerframe.none").module,
		})
	end)

	it(
		"are named by their IDs, with no description, while their lore keys have no text (HNT-R121, HNT-R130)",
		function()
			-- No fixture lore, and the shipped data/Lore.lua's goods keys taken out, as before the lore batch gave the goods their names.
			local _, fake = loggedIn({
				lore = false,
				prepare = function(loaded)
					for key in pairs(loaded.ns.L) do
						if type(key) == "string" and key:find("^huntgood%.") then
							loaded.ns.L[key] = nil
						end
					end
				end,
			})

			for _, slot in ipairs({ COVER, FRAME }) do
				for _, row in ipairs(GOODS[slot]) do
					local good = fake.Pagle.GetGood(row[1])
					assert.are.same({ row[1] }, { good.name, good.description })
				end
			end
		end
	)

	it("are named and described from their huntgood lore keys (HNT-R121, HNT-R130, SHOP-R26)", function()
		local _, fake = loggedIn()

		assert.are.same({
			{ "Oilcloth", "Black-green oilcloth that keeps the rain off the pages." },
			{ "Ink Wash", "A wash of thinned ink behind your pinned Hunts." },
		}, {
			{
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").name,
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").description,
			},
			{
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").name,
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").description,
			},
		})
	end)

	it("show each good's icon as its swatch in the Curio Shop's list (HNT-R121, SHOP-R26)", function()
		local _, fake = loggedIn()

		local icons = {}
		for _, slot in ipairs({ COVER, FRAME }) do
			for _, row in ipairs(GOODS[slot]) do
				local icon = fake.Pagle.GetGood(row[1]).icon
				assert.matches("^Interface\\Icons\\", icon)
				icons[icon] = true
			end
		end
		local distinct = 0
		for _ in pairs(icons) do
			distinct = distinct + 1
		end
		assert.are.equal(7, distinct)
	end)
end)

-- A leather view's look (adapter/BoardWidgets.lua's NewBoardLeather): its fill's file, then "tooled" and "corner" when
-- Tooled Leather's gilt rule and Verdigris's corner show, joined by "+".
---@param view BoardLeatherView
---@return string
local function lookOf(view)
	local parts = { tostring(view.fill.texture) }
	if view.tooling[1].edges[1]:IsShown() then
		parts[#parts + 1] = "tooled"
	end
	if view.corner:IsShown() then
		parts[#parts + 1] = "corner"
	end
	return table.concat(parts, "+")
end

-- Each cover's look, as lookOf reads it: the books kit v2's covers (HNT-R121).
local function coverLooks(ns)
	local leather = ns.BOOK_FILES.leather
	return {
		["hunts.notebookcover.leather"] = leather,
		["hunts.notebookcover.oilcloth"] = ns.COVER_FILES.oilcloth,
		["hunts.notebookcover.tooled"] = leather .. "+tooled",
		["hunts.notebookcover.verdigris"] = ns.COVER_FILES.verdigris .. "+corner",
	}
end

describe("the board's cover", function()
	-- The open board's leather, as lookOf reads it.
	local function leatherOf(board)
		return lookOf(board.frame.cover)
	end

	it("redraws the open board's leather in Oilcloth's look when Oilcloth is equipped (HNT-R70, SHOP-R33)", function()
		local loaded, fake = loggedIn()
		local ns = loaded.ns
		local looks = coverLooks(ns)
		ns.ToggleBoard()
		assert.are.equal(looks["hunts.notebookcover.leather"], leatherOf(ns.board)) -- the kit's leather by default

		fake.setPurchased({ ["hunts.notebookcover.oilcloth"] = true }) -- bought (SHOP-R11)
		assert.is_true(fake.Pagle.SetEquipped(COVER, "hunts.notebookcover.oilcloth"))

		assert.are.equal(looks["hunts.notebookcover.oilcloth"], leatherOf(ns.board))
		assert.is_true(ns.board.frame.cover.band:IsShown()) -- the kit's band on every cover

		assert.is_true(fake.Pagle.SetEquipped(COVER, "hunts.notebookcover.leather"))
		assert.are.equal(looks["hunts.notebookcover.leather"], leatherOf(ns.board))
	end)

	it("opens in the cover equipped at an earlier login, bought then (HNT-R70, SHOP-R32)", function()
		local fake = newFakePagle()
		fake.setPurchased({ ["hunts.notebookcover.tooled"] = true })
		fake.profile.appearance[COVER] = "hunts.notebookcover.tooled"
		local loaded = hunts.load(fake)
		fake.login()
		local ns = loaded.ns

		ns.ToggleBoard()

		assert.are.equal(coverLooks(ns)["hunts.notebookcover.tooled"], leatherOf(ns.board))
	end)

	it(
		"falls back to Leather while Hunts is disabled, keeping the pick, which comes back with Hunts (HNT-R70, SHOP-R32, SHOP-R90)",
		function()
			local _, first = loggedIn()
			first.setPurchased({ ["hunts.notebookcover.oilcloth"] = true })
			assert.is_true(first.Pagle.SetEquipped(COVER, "hunts.notebookcover.oilcloth"))

			-- The next session, Hunts disabled: it runs no code, so it registers nothing (CORE-R17).
			local off = newFakePagle()
			off.global.goods = first.global.goods
			off.profile.appearance = first.profile.appearance
			off.setPurchased({ ["hunts.notebookcover.oilcloth"] = true })
			off.login()

			assert.are.equal("hunts.notebookcover.leather", off.Pagle.GetEquipped(COVER))
			assert.are.equal("hunts.notebookcover.oilcloth", off.profile.appearance[COVER])

			-- Enabled again: Oilcloth is back on the board with no SetEquipped.
			local on = newFakePagle()
			on.global.goods = first.global.goods
			on.profile.appearance = off.profile.appearance
			on.setPurchased({ ["hunts.notebookcover.oilcloth"] = true })
			local loaded = hunts.load(on)
			on.login()
			loaded.ns.ToggleBoard()

			assert.are.equal("hunts.notebookcover.oilcloth", on.Pagle.GetEquipped(COVER))
			assert.are.equal(coverLooks(loaded.ns)["hunts.notebookcover.oilcloth"], leatherOf(loaded.ns.board))
		end
	)
end)

describe("Look and Feel", function()
	it("lists the notebook cover under Hunts and the tracker frame under Trackers (SET-R50, HNT-R120)", function()
		local _, fake = loggedIn()

		local listed = {}
		for _, section in ipairs(fake.ns.LookAndFeelSections(fake.ns.goods)) do
			for _, slot in ipairs(section.slots) do
				if slot.module == "Hunts" then
					listed[#listed + 1] = { section.category, slot.id }
				end
			end
		end
		assert.are.same({ { "Hunts", COVER }, { "Trackers", FRAME } }, listed)
		local choices = {}
		for _, choice in ipairs(fake.ns.SlotChoices(fake.ns.goods, COVER)) do
			choices[#choices + 1] = choice.value
		end
		assert.are.same({ "hunts.notebookcover.leather" }, choices) -- only what is owned (SET-R51)
	end)

	it("puts the tracker frame's dropdown in Hunts' section of the Trackers page (SET-R44, HNT-R120)", function()
		local _, fake = loggedIn()

		local slots = fake.ns.SectionSlots(fake.ns.goods, "trackers").Hunts
		assert.are.same({ FRAME }, { slots[1].id, slots[2] })
	end)
end)

describe("a notebook cover's preview", function()
	it("draws the closed notebook in that cover on the good's stage: its leather, no pages (HNT-R121)", function()
		local loaded, fake = loggedIn()
		local ns = loaded.ns
		local looks = coverLooks(ns)

		local leathers = {}
		for _, row in ipairs(GOODS[COVER]) do
			local id = row[1]
			local stage = loaded.env.CreateFrame("Frame") -- each good's own stage frame (#157)

			fake.ns.goods:Good(id).preview(stage)
			fake.ns.goods:Good(id).preview(stage) -- the shop draws it again at each selection

			assert.are.equal(1, #stage.children, id) -- one notebook, drawn afresh
			local notebook = stage.children[1]
			assert.is_true(notebook:IsShown())
			-- the board's own leather in that cover, in the kit's band
			assert.are.equal(looks[id], lookOf(notebook.cover), id)
			assert.is_true(notebook.cover.band:IsShown())
			leathers[#leathers + 1] = lookOf(notebook.cover)
			for _, widget in ipairs(descendants(notebook)) do
				assert.are_not.equal(ns.BOOK_FILES.parchment, widget.texture, id) -- closed: no parchment
			end
		end
		table.sort(leathers)
		for i = 2, #leathers do
			assert.are_not.equal(leathers[i - 1], leathers[i]) -- four different leathers
		end
	end)
end)

describe("a tracker frame's preview", function()
	it(
		'draws a sample tracker with "Night Run · in 37m" and "Rack Hour · on demand" in that frame on the good\'s stage (HNT-R121, CORE-R73)',
		function()
			local loaded, fake = loggedIn()
			local ns = loaded.ns
			assert.is_nil(ns.TRACKER_FRAMES["hunts.trackerframe.none"]) -- the plain native block

			for _, row in ipairs(GOODS[FRAME]) do
				local id = row[1]
				local stage = loaded.env.CreateFrame("Frame")

				fake.ns.goods:Good(id).preview(stage)
				fake.ns.goods:Good(id).preview(stage)

				assert.are.equal(1, #stage.children, id)
				local tracker = stage.children[1]
				assert.is_true(tracker:IsShown())
				local look, paper = ns.TRACKER_FRAMES[id], tracker.view.paper
				-- each Hunt's name at the left and its label at the right; "Hunts" in small caps on a paper
				assert.are.same(
					{ look and "HUNTS" or "Hunts", "Night Run", "in 37m", "Rack Hour", "on demand" },
					textsOf(tracker),
					id
				)
				assert.are.equal(ns.TrackerLook(id), tracker.view.look, id)
				if look then
					assert.is_true(paper:IsShown())
					assert.are.equal(ns.ATLASES[look.frame].file, paper.top.texture, id)
					assert.are.equal(look.width, tracker.width, id)
				else
					assert.is_false(paper:IsShown())
				end
			end
			assert.are_not.equal(
				ns.TRACKER_FRAMES["hunts.trackerframe.inkwash"].frame,
				ns.TRACKER_FRAMES["hunts.trackerframe.waxseal"].frame
			)
		end
	)

	it("sets the sample's words in its look's inks: dark on the papers, gold and white over the world", function()
		local loaded, fake = loggedIn()
		local ns = loaded.ns

		-- Each tracker frame drawn on one stage in turn, so the words are set afresh each time.
		local stage = loaded.env.CreateFrame("Frame")
		local colours = {}
		for _, row in ipairs(GOODS[FRAME]) do
			fake.ns.goods:Good(row[1]).preview(stage)
			local tracker = stage.children[1]
			local words = {}
			for _, widget in ipairs(shownDescendants(tracker)) do
				if widget.kind == "FontString" and widget.text ~= "" then
					local color = widget.textColor
					words[#words + 1] = { color[1], color[2], color[3] }
				end
			end
			colours[row[1]] = words
		end

		for id, words in pairs(colours) do
			local look = ns.TrackerLook(id)
			-- the header, then each Hunt's name and label
			assert.are.same({ look.header[3], look.name[3], look.label[3], look.name[3], look.label[3] }, words, id)
		end
		local wax = ns.TRACKER_FRAMES["hunts.trackerframe.waxseal"]
		assert.are_not.same(ns.TRACKER_LOOKS.native.name[3], wax.name[3]) -- parchment (its lore): dark words
	end)
end)
