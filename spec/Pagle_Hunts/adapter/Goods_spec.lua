-- Hunts' goods on FakePagle (HNT-R120–R123, HNT-R70; SHOP-R21–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90): the two slots
-- and their goods in Core's goods registry, their names from lore, the earned ones owned as the projection and the
-- celebrated set say, their previews on the shop's stage, and the board's leather in the equipped cover.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local COVER, FRAME = "hunts.notebookcover", "hunts.trackerframe"

-- HNT-R121's goods, in its order, with their kinds.
local GOODS = hunts.GOODS

-- A good's kind as HNT-R121's table writes it; "earned" for one with isEarned (HNT-R122).
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
		"register the slots hunts.notebookcover (Hunts) and hunts.trackerframe (Trackers), with HNT-R121's goods, defaults, tiers and earned goods (HNT-R120, HNT-R121, HNT-R122, SHOP-R21, SHOP-R22)",
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

	it(
		"sell for 150, 400, 900, 2,000 and 5,000 Coins at tiers 1 to 5, in the Curio Shop (HNT-R121, SHOP-R22)",
		function()
			local _, fake = loggedIn()
			local shop = fake.ns.ShopModel(tostring)

			local prices = {}
			for _, id in ipairs({
				"hunts.notebookcover.oilcloth",
				"hunts.notebookcover.tooled",
				"hunts.notebookcover.verdigris",
				"hunts.notebookcover.canvas",
				"hunts.notebookcover.maplinen",
				"hunts.notebookcover.bone",
				"hunts.notebookcover.scrimshaw",
				"hunts.notebookcover.trophycase",
				"hunts.trackerframe.inkwash",
				"hunts.trackerframe.waxseal",
				"hunts.trackerframe.slate",
				"hunts.trackerframe.mapscrap",
				"hunts.trackerframe.bounty",
				"hunts.trackerframe.spyglass",
			}) do
				prices[#prices + 1] = shop:Entry(id).price
			end
			assert.are.same({ 150, 400, 900, 150, 400, 900, 2000, 5000, 150, 400, 150, 150, 400, 900 }, prices)
			assert.are.same({ "Hunts", "Hunts" }, {
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").module,
				fake.Pagle.GetGood("hunts.trackerframe.none").module,
			})
		end
	)

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
			{ "Pathfinder's Calf", "Calfskin pressed with a compass rose." },
		}, {
			{
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").name,
				fake.Pagle.GetGood("hunts.notebookcover.oilcloth").description,
			},
			{
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").name,
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").description,
			},
			{
				fake.Pagle.GetGood("hunts.notebookcover.pathfinder").name,
				fake.Pagle.GetGood("hunts.notebookcover.pathfinder").description,
			},
		})
	end)

	it(
		"show each good's icon as its swatch in the Curio Shop's list: an expansion cover's its material, Hunts' own (HNT-R121, HNT-R123, SHOP-R26)",
		function()
			local loaded, fake = loggedIn()

			local icons, count = {}, 0
			for _, slot in ipairs({ COVER, FRAME }) do
				for _, row in ipairs(GOODS[slot]) do
					local icon = fake.Pagle.GetGood(row[1]).icon
					local look = loaded.ns.COVERS[row[1]]
					if look and look.tile then
						assert.are.equal(look.tile, icon, row[1])
					else
						assert.matches("^Interface\\Icons\\", icon)
					end
					icons[icon] = true
					count = count + 1
				end
			end
			local distinct = 0
			for _ in pairs(icons) do
				distinct = distinct + 1
			end
			assert.are.equal(count, distinct)
		end
	)

	it(
		"register Night Watch, earned, in Core's sound set slot, with no slot of Hunts' for it (HNT-R123, SHOP-R23)",
		function()
			local _, fake = loggedIn()

			local good = fake.ns.goods:Good("hunts.soundset.nightwatch")
			assert.are.same({ "core.soundset", "Hunts", "earned" }, { good.slot, good.module, kindOf(good) })
			assert.are.same({ "Night Watch", "Finish every Hunt set" }, { good.name, good.earnedText })
			assert.is_nil(good.preview) -- Core's slot previews it
			assert.is_string(fake.Pagle.GetGood("hunts.soundset.nightwatch").description)
		end
	)

	it("say what earns each earned good: a set, every set, ten Wager runs (HNT-R122, SHOP-R22)", function()
		local _, fake = loggedIn()

		local texts = {}
		for _, id in ipairs({
			"hunts.notebookcover.pathfinder",
			"hunts.notebookcover.fiveseal",
			"hunts.notebookcover.wagersilk",
			"hunts.trackerframe.wagerribbon",
		}) do
			texts[#texts + 1] = fake.ns.goods:Good(id).earnedText
		end
		assert.are.same({
			"Finish a Hunt set",
			"Finish every Hunt set",
			"10 Wager runs completed",
			"10 Wager runs completed",
		}, texts)
	end)

	it("ship the expansion's covers, swatches and frames as Hunts' own media (HNT-R123)", function()
		local loaded = loggedIn()
		local ns = loaded.ns

		local files = { ns.ATLASES.Covers2.file, ns.ATLASES.TrackerFrames2.file }
		for _, row in ipairs(GOODS[COVER]) do
			local look = ns.COVERS[row[1]]
			if look.tile then
				files[#files + 1] = look.tile
				assert(ns.ATLASES.Covers2.sprites[look.swatch], row[1])
			end
		end
		assert.are.equal(2 + 15, #files)
		for _, file in ipairs(files) do
			assert.matches("^Interface\\AddOns\\Pagle_Hunts\\media\\books\\", file)
			local path = file:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/") .. ".blp"
			assert.are.equal("BLP2", readFile(path):sub(1, 4), path)
		end
	end)
end)

-- A leather view's look (adapter/BoardWidgets.lua's NewBoardLeather): its fill's file, then "tooled" and "corner" when
-- Tooled Leather's gilt rule and Verdigris's corner show, "band" when the band is toned and "corners" when an
-- expansion cover's four corners show, joined by "+".
---@param view table a BoardLeatherView on the fake client, read by the fields it keeps
---@return string
local function lookOf(view)
	local parts = { tostring(view.fill.texture) }
	if view.tooling[1].edges[1]:IsShown() then
		parts[#parts + 1] = "tooled"
	end
	if view.corner:IsShown() then
		parts[#parts + 1] = "corner"
	end
	if view.bandPieces.TL:IsDesaturated() then
		parts[#parts + 1] = "band"
	end
	if view.corners[1]:IsShown() then
		parts[#parts + 1] = "corners"
	end
	return table.concat(parts, "+")
end

-- The expansion's covers with metal corners (HNT-R123, the expansion kit's goods.json).
local CORNERED = { snakeskin = true, shagreen = true, lacquer = true, scrimshaw = true, trophycase = true }
CORNERED.pathfinder, CORNERED.wagersilk = true, true

-- Each cover's look, as lookOf reads it: the books kit v2's covers (HNT-R121), then the expansion's, each its material
-- under a toned band (HNT-R123).
local function coverLooks(ns)
	local leather = ns.BOOK_FILES.leather
	local looks = {
		["hunts.notebookcover.leather"] = leather,
		["hunts.notebookcover.oilcloth"] = ns.COVER_FILES.oilcloth,
		["hunts.notebookcover.tooled"] = leather .. "+tooled",
		["hunts.notebookcover.verdigris"] = ns.COVER_FILES.verdigris .. "+corner",
	}
	for i = 5, #GOODS[COVER] do
		local id = GOODS[COVER][i][1]
		local key = id:match("[^.]+$")
		looks[id] = ns.COVER_TILES .. key .. "+band" .. (CORNERED[key] and "+corners" or "")
	end
	return looks
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

	it(
		"dresses the open board in an expansion cover: its material tiled at its repeat, the band in its tone, its corners (HNT-R70, HNT-R123)",
		function()
			local loaded, fake = loggedIn()
			local ns = loaded.ns
			ns.ToggleBoard()
			fake.setPurchased({ ["hunts.notebookcover.lacquer"] = true, ["hunts.notebookcover.canvas"] = true })

			assert.is_true(fake.Pagle.SetEquipped(COVER, "hunts.notebookcover.lacquer"))

			local view, frame = ns.board.frame.cover, ns.board.frame
			assert.are.equal(coverLooks(ns)["hunts.notebookcover.lacquer"], leatherOf(ns.board))
			-- 150 x 196 units a repeat, inside the band's 7-unit inset
			local coords = view.fill.texCoord
			assert.are.same({ 0, (frame.width - 14) / 150, 0, (frame.height - 14) / 196 }, coords)
			-- the band's art desaturated and tinted #8a1410, brightened 1.9 times, each channel at most 1
			local tone = view.bandPieces.T.vertexColor
			assert.are.same({ 1, 0x14 / 255 * 1.9, 0x10 / 255 * 1.9 }, { tone[1], tone[2], tone[3] })
			for _, corner in ipairs(view.corners) do
				assert.is_true(corner:IsShown())
				assert.is_true(corner:IsDesaturated()) -- gold: the brass corner tinted
			end

			-- Canvas has no corners; the kit's own leather after it, its band untoned.
			assert.is_true(fake.Pagle.SetEquipped(COVER, "hunts.notebookcover.canvas"))
			assert.are.equal(coverLooks(ns)["hunts.notebookcover.canvas"], leatherOf(ns.board))
			assert.is_true(fake.Pagle.SetEquipped(COVER, "hunts.notebookcover.leather"))
			assert.are.equal(coverLooks(ns)["hunts.notebookcover.leather"], leatherOf(ns.board))
			assert.are.same({ 1, 1, 1, 1 }, view.bandPieces.T.vertexColor)
		end
	)

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
	it(
		"draws the closed notebook in the books kit's covers on the good's stage: its leather, no pages (HNT-R121)",
		function()
			local loaded, fake = loggedIn()
			local ns = loaded.ns
			local looks = coverLooks(ns)

			local leathers = {}
			for i = 1, 4 do
				local id = GOODS[COVER][i][1]
				local stage = loaded.env.CreateFrame("Frame") -- each good's own stage frame (#157)

				fake.ns.goods:Good(id).preview(stage)
				fake.ns.goods:Good(id).preview(stage) -- the shop draws it again at each selection

				assert.are.equal(1, #stage.children, id) -- one notebook, drawn afresh
				local notebook = stage.children[1]
				assert.is_true(notebook:IsShown())
				assert.are.equal(false, notebook.swatch:IsShown(), id)
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
		end
	)

	it(
		"draws an expansion cover's closed notebook as its swatch in the Covers2 atlas, at the notebook's height (HNT-R121, HNT-R123)",
		function()
			local loaded, fake = loggedIn()
			local ns = loaded.ns
			local atlas = ns.ATLASES.Covers2

			local seen = {}
			-- One stage for every cover in turn: a books kit cover after a swatch shows its leather again.
			local stage = loaded.env.CreateFrame("Frame")
			for i = 5, #GOODS[COVER] do
				local id = GOODS[COVER][i][1]
				fake.ns.goods:Good(id).preview(stage)

				local notebook = stage.children[1]
				assert.are.equal(1, #stage.children, id)
				assert.are.equal(false, notebook.leather:IsShown(), id)
				local swatch = notebook.swatch
				assert.are.equal(true, swatch:IsShown(), id)
				assert.are.equal(atlas.file, swatch.texture, id)
				local sprite = atlas.sprites[ns.COVERS[id].swatch]
				assert.are.same({
					sprite.x / atlas.width,
					(sprite.x + sprite.w) / atlas.width,
					sprite.y / atlas.height,
					(sprite.y + sprite.h) / atlas.height,
				}, swatch.texCoord, id)
				assert.are.equal(140, swatch.box[4], id) -- the notebook's height
				local key = table.concat(swatch.texCoord, ",")
				assert.are.equal(nil, seen[key], id) -- a swatch of its own
				seen[key] = true
			end
			fake.ns.goods:Good("hunts.notebookcover.oilcloth").preview(stage)
			assert.is_true(stage.children[1].leather:IsShown())
			assert.is_false(stage.children[1].swatch:IsShown())
		end
	)
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
				-- each Hunt's name at the left and its label at the right; "Hunts" in small caps on the books kit's papers
				assert.are.same(
					{ look and look.caps and "HUNTS" or "Hunts", "Night Run", "in 37m", "Rack Hour", "on demand" },
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

	it(
		"draws an expansion frame as a three-slice of its TrackerFrames2 sprite, its top and foot kept, its middle stretched to the lines (HNT-R123)",
		function()
			local loaded, fake = loggedIn()
			local ns = loaded.ns
			local atlas = ns.ATLASES.TrackerFrames2

			for _, key in ipairs({ "slate", "mapscrap", "bounty", "spyglass", "wagerribbon" }) do
				local id = FRAME .. "." .. key
				local look = ns.TRACKER_FRAMES[id]
				assert.are.same({ "TrackerFrames2", "frame-" .. key, 262 }, { look.frame, look.sprite, look.width }, id)
				local stage = loaded.env.CreateFrame("Frame")
				fake.ns.goods:Good(id).preview(stage)

				local tracker = stage.children[1]
				local paper, sprite = tracker.view.paper, atlas.sprites[look.sprite]
				-- the top keeps the sprite's margin and the slice's top; the foot the slice's foot and the margin under
				local marginTop, marginFoot = sprite.box[2], sprite.h / 2 - sprite.box[2] - sprite.box[4]
				assert.are.same({ paper.top.width, paper.top.height }, { sprite.w / 2, marginTop + look.slice.top }, id)
				assert.are.equal(look.slice.foot + marginFoot, paper.bottom.height, id)
				assert.are.equal(sprite.x / atlas.width, paper.top.texCoord[1], id)
				assert.are.equal(sprite.y / atlas.height, paper.top.texCoord[3], id)
				-- two Hunts: the middle spans what the top and foot leave of the block
				local middle = paper.middles[1]
				assert.are.equal(true, middle:IsShown(), id)
				assert.are.equal(tracker.height - look.slice.top - look.slice.foot, middle.height, id)
				assert.are.equal(look.first + 2 * look.step + look.foot, tracker.height, id)
				-- the words inside the kit's text insets
				assert.are.equal(true, look.x >= 16 and look.right <= 262 - 16, id)
			end
		end
	)

	it("keeps a collapsed expansion frame no shorter than its paper's top and foot (HNT-R123, HNT-R77)", function()
		local loaded = loggedIn()
		local ns = loaded.ns

		local view = ns.NewTrackerBlock(loaded.env.CreateFrame("Frame"))
		local look = ns.TRACKER_FRAMES["hunts.trackerframe.slate"]
		ns.DrawTrackerBlock(view, look, { hunts = {}, empty = false, collapsed = true })

		assert.are.equal(look.slice.top + look.slice.foot, view.frame.height)
	end)

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

describe("Hunts' earned goods, through the projection", function()
	local C = hunts.catalogue
	local HOUR, DAY = hunts.HOUR, 86400
	local cast, append, record, runPayload, fishAt =
		hunts.cast, hunts.append, hunts.record, hunts.runPayload, hunts.fishAt
	local DARKSHORE, WESTFALL, ELWYNN = { zone = C.DARKSHORE }, { zone = C.WESTFALL }, { zone = C.ELWYNN }
	local PATHFINDER, FIVESEAL = "hunts.notebookcover.pathfinder", "hunts.notebookcover.fiveseal"
	local WAGERSILK, RIBBON = "hunts.notebookcover.wagersilk", "hunts.trackerframe.wagerribbon"
	local NIGHT_WATCH = "hunts.soundset.nightwatch"

	-- fixture_oddity done at dusk in Darkshore: fixture_wagers' first Hunt (fixture_grouper doesn't exist yet).
	local function oddity(fake)
		append(fake, { cast(2, hunts.DUSK, DARKSHORE, { C.DEVIATE }) })
	end
	-- And fixture_rack done under its aura in Westfall: fixture_wagers' title.
	local function wagersTitle(fake)
		oddity(fake)
		append(fake, { cast(3, hunts.DAY, WESTFALL, { C.UNCOMMON }, { C.RACK_AURA }) })
	end

	-- The fixture list with fixture_wagers its only set: its title is every set's.
	local function wagersOnly(loaded)
		local list, hunts_ = loaded.ns.huntList, {}
		for _, hunt in ipairs(list.hunts) do
			if hunt.set == "fixture_wagers" then
				hunts_[#hunts_ + 1] = hunt
			end
		end
		loaded.ns.huntList = {
			fingerprint = list.fingerprint,
			sets = { { id = "fixture_wagers" } },
			hunts = hunts_,
			classes = list.classes,
		}
	end

	-- `n` fixture_vale runs, each completed by one Cast in Elwynn with a Blackmouth and an uncommon item (HNT-R146).
	local function completedRuns(n)
		return function(fake)
			local records = {}
			for i = 0, n - 1 do
				local start = hunts.MARCH_1 + i * 2 * HOUR
				records[#records + 1] = record("run", runPayload("fixture_vale", start, start + HOUR), start)
				local entry = cast(0, hunts.DAY, ELWYNN, { C.BLACKMOUTH, C.UNCOMMON })
				entry.time = start + 60
				records[#records + 1] = entry
			end
			append(fake, records)
		end
	end

	-- The next login over `fake`'s log and saved Hunts DB, rebuilt: its Hunt list's fingerprint changed, then `prepare`.
	local function rebuilt(fake, loaded, prepare)
		return hunts.login(nil, {
			fake = hunts.nextLogin(fake, loaded),
			prepare = function(l)
				l.ns.huntList.fingerprint = "f1c7f1c7f1c70346"
				if prepare then
					prepare(l)
				end
			end,
		})
	end

	it("own none of them before a set title or a completed run (HNT-R122)", function()
		local _, fake = hunts.login(oddity)

		for _, id in ipairs({ PATHFINDER, FIVESEAL, WAGERSILK, RIBBON, NIGHT_WATCH }) do
			assert.are.equal(false, fake.Pagle.IsOwned(id), id)
		end
	end)

	it(
		"own Pathfinder's Calf once a live Cast earns a set title, refreshed then, and not Five-Set Seal while other sets aren't (HNT-R122, SHOP-R31)",
		function()
			local _, fake = hunts.login(oddity)
			fishAt(fake, hunts.DAY, WESTFALL, { C.RACK_AURA })

			fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fake.nextFrame()

			assert.is_true(fake.Pagle.IsOwned(PATHFINDER))
			assert.is_false(fake.Pagle.IsOwned(FIVESEAL))
		end
	)

	it("own Pathfinder's Calf from done when the title was earned before login (HNT-R122, SHOP-R31)", function()
		local _, fake = hunts.login(wagersTitle)

		assert.is_true(fake.Pagle.IsOwned(PATHFINDER))
		assert.is_false(fake.Pagle.IsOwned(FIVESEAL))
	end)

	it("own Five-Set Seal and Night Watch when every set's title is earned (HNT-R122, HNT-R123, HNT-R20)", function()
		local _, fake = hunts.login(wagersTitle, { prepare = wagersOnly })

		assert.is_true(fake.Pagle.IsOwned(FIVESEAL))
		assert.is_true(fake.Pagle.IsOwned(NIGHT_WATCH))
		assert.is_true(fake.Pagle.IsOwned(PATHFINDER))
	end)

	it(
		"let Night Watch be equipped in Core's sound set slot once earned, Core playing it (HNT-R123, SHOP-R23, SHOP-R32)",
		function()
			local _, fake = hunts.login(wagersTitle, { prepare = wagersOnly })

			assert.is_true(fake.Pagle.SetEquipped("core.soundset", NIGHT_WATCH))
			assert.are.equal(NIGHT_WATCH, fake.Pagle.GetEquipped("core.soundset"))
		end
	)

	it(
		"keep them after a rebuild whose definitions no longer earn the title: the celebrated set holds it, from registration on (HNT-R122, HNT-R90, SHOP-R31)",
		function()
			local loaded, fake = hunts.login(wagersTitle, { prepare = wagersOnly })
			assert.is_true(loaded.env.PagleHuntsDB.global.celebrated.sets.fixture_wagers) -- shown at done (HNT-R112)

			-- Before 1.0, fixture_rack now needs six Catches: the rebuild no longer finds the title.
			local next, nextFake = rebuilt(fake, loaded, function(l)
				wagersOnly(l)
				for _, hunt in ipairs(l.ns.huntList.hunts) do
					if hunt.id == "fixture_rack" then
						hunt.tiers = { 6 }
					end
				end
			end)

			assert.is_nil(next.ns.State().sets.fixture_wagers)
			assert.is_true(nextFake.Pagle.IsOwned(PATHFINDER))
			assert.is_true(nextFake.Pagle.IsOwned(FIVESEAL))
			assert.is_true(nextFake.Pagle.IsOwned(NIGHT_WATCH))
		end
	)

	it(
		"own Winner's Brocade and Winner's Ribbon at ten completed runs, from done, and after a rebuild (HNT-R122, HNT-R148)",
		function()
			local loaded, fake = hunts.login(completedRuns(10))
			assert.are.equal(10, loaded.ns.State().settled)
			assert.is_true(fake.Pagle.IsOwned(WAGERSILK))
			assert.is_true(fake.Pagle.IsOwned(RIBBON))

			local _, nextFake = rebuilt(fake, loaded)

			assert.is_true(nextFake.Pagle.IsOwned(WAGERSILK))
			assert.is_true(nextFake.Pagle.IsOwned(RIBBON))
		end
	)

	it("don't own them at nine (HNT-R122, HNT-R148)", function()
		local _, fake = hunts.login(completedRuns(9))

		assert.is_false(fake.Pagle.IsOwned(WAGERSILK))
		assert.is_false(fake.Pagle.IsOwned(RIBBON))
	end)

	it(
		"own them once a live Cast completes the tenth run, not when it merely joins one (HNT-R122, HNT-R146, SHOP-R31)",
		function()
			local _, fake = hunts.login(function(fake)
				completedRuns(9)(fake)
				append(fake, {
					record(
						"run",
						runPayload("fixture_vale", SERVER_TIME - HOUR, SERVER_TIME + DAY),
						SERVER_TIME - HOUR
					),
				})
			end)
			fishAt(fake, hunts.DAY, ELWYNN)

			-- A Blackmouth alone: the run's Haul and Named fish, not its Quality Hunt.
			fake.playCast("caught", { { itemID = C.BLACKMOUTH, quantity = 1 } })
			fake.nextFrame()
			assert.is_false(fake.Pagle.IsOwned(WAGERSILK))

			fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fake.nextFrame()
			assert.is_true(fake.Pagle.IsOwned(WAGERSILK))
			assert.is_true(fake.Pagle.IsOwned(RIBBON))
		end
	)
end)
