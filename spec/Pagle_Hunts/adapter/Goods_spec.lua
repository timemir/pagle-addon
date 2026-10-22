-- Hunts' goods on FakePagle (HNT-R120–R123; SHOP-R21–R23, SHOP-R26, SHOP-R30–R33, SHOP-R90; ADR 0015): its slot and
-- its goods in Core's goods registry, its earned bindings in Core's binding slot, their names from lore, the earned
-- ones owned as the projection and the celebrated set say, and the tracker frames' previews on the shop's stage.

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

local BINDING, FRAME = "core.binding", "hunts.trackerframe"

-- HNT-R121's goods, in its order, with their kinds, and Hunts' earned bindings (HNT-R122).
local GOODS, BINDINGS = hunts.GOODS, hunts.BINDINGS

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
		"register the slot hunts.trackerframe (Trackers) with HNT-R121's goods, defaults and tiers, and the three earned bindings in Core's binding slot after Core's own, with no preview (HNT-R120, HNT-R121, HNT-R122, SHOP-R21, SHOP-R22, SHOP-R23)",
		function()
			local _, fake = loggedIn()
			local goods = fake.ns.goods

			local slots = {}
			for _, slot in ipairs(goods:Slots()) do
				if slot.module == "Hunts" then
					slots[#slots + 1] = { slot.id, slot.label, slot.category }
				end
			end
			assert.are.same({ { FRAME, "Hunts tracker frame", "Trackers" } }, slots)
			local registered = {}
			for i, good in ipairs(goods:GoodsOf(FRAME)) do
				registered[i] = { good.id, kindOf(good) }
			end
			assert.are.same(GOODS[FRAME], registered)
			local bindings = {}
			for _, good in ipairs(goods:GoodsOf(BINDING)) do
				if good.module == "Hunts" then
					bindings[#bindings + 1] = { good.id, kindOf(good) }
					assert(good.preview == nil, good.id) -- Core's slot previews it
				else
					assert.are.same({ "Core", 0 }, { good.module, #bindings }, good.id) -- Core's all come first
				end
			end
			assert.are.same(BINDINGS, bindings)
			assert.are.same({ "core.binding.field", "hunts.trackerframe.none" }, {
				fake.Pagle.GetEquipped(BINDING),
				fake.Pagle.GetEquipped(FRAME),
			})
			assert.are.same({}, fake.reported)
		end
	)

	it("sell for 150, 400 and 900 Coins at tiers 1 to 3, in the Curio Shop (HNT-R121, SHOP-R22)", function()
		local _, fake = loggedIn()
		local shop = fake.ns.ShopModel(tostring)

		local prices = {}
		for _, id in ipairs({
			"hunts.trackerframe.inkwash",
			"hunts.trackerframe.waxseal",
			"hunts.trackerframe.slate",
			"hunts.trackerframe.mapscrap",
			"hunts.trackerframe.bounty",
			"hunts.trackerframe.spyglass",
		}) do
			prices[#prices + 1] = shop:Entry(id).price
		end
		assert.are.same({ 150, 400, 150, 150, 400, 900 }, prices)
		assert.are.same({ "Hunts", "Hunts" }, {
			fake.Pagle.GetGood("hunts.trackerframe.inkwash").module,
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

			for _, list in ipairs({ GOODS[FRAME], BINDINGS }) do
				for _, row in ipairs(list) do
					local good = fake.Pagle.GetGood(row[1])
					assert.are.same({ row[1] }, { good.name, good.description })
				end
			end
		end
	)

	it("are named and described from their huntgood lore keys (HNT-R121, HNT-R130, SHOP-R26)", function()
		local _, fake = loggedIn()

		assert.are.same({
			{ "Ink Wash", "A wash of thinned ink behind your pinned Hunts." },
			{ "Pathfinder's Calf", "Calfskin pressed with a compass rose." },
		}, {
			{
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").name,
				fake.Pagle.GetGood("hunts.trackerframe.inkwash").description,
			},
			{
				fake.Pagle.GetGood("hunts.binding.pathfinder").name,
				fake.Pagle.GetGood("hunts.binding.pathfinder").description,
			},
		})
	end)

	it(
		"show each good's icon as its swatch in the Curio Shop's list: an earned binding's its material, Core's (HNT-R121, HNT-R123, SHOP-R26, ADR 0015)",
		function()
			local _, fake = loggedIn()

			local icons, count = {}, 0
			for _, list in ipairs({ GOODS[FRAME], BINDINGS }) do
				for _, row in ipairs(list) do
					local icon = fake.Pagle.GetGood(row[1]).icon
					local look = fake.Pagle.GetBindingLook(row[1])
					if row[1]:find("^hunts%.binding%.") then
						assert.are.equal(look.texture, icon, row[1])
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
			"hunts.binding.pathfinder",
			"hunts.binding.fiveseal",
			"hunts.binding.wagersilk",
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

	it(
		"ship the expansion's frames as Hunts' own media, and no binding's art: Core ships it (HNT-R123, ADR 0015)",
		function()
			local loaded = loggedIn()
			local ns = loaded.ns

			assert.is_nil(ns.ATLASES.Covers2)
			local files = { ns.ATLASES.TrackerFrames2.file }
			for _, file in ipairs(files) do
				assert.matches("^Interface\\AddOns\\Pagle_Hunts\\media\\books\\", file)
				local path = file:gsub("^Interface\\AddOns\\", "addons/"):gsub("\\", "/") .. ".blp"
				assert.are.equal("BLP2", readFile(path):sub(1, 4), path)
			end
		end
	)
end)

describe("Look and Feel", function()
	it("lists the tracker frame under Trackers, and no slot of Hunts' under Books (SET-R50, HNT-R120)", function()
		local _, fake = loggedIn()

		local listed = {}
		for _, section in ipairs(fake.ns.LookAndFeelSections(fake.ns.goods)) do
			for _, slot in ipairs(section.slots) do
				if slot.module == "Hunts" then
					listed[#listed + 1] = { section.category, slot.id }
				end
			end
		end
		assert.are.same({ { "Trackers", FRAME } }, listed)
	end)

	it("puts the tracker frame's dropdown in Hunts' section of the Trackers page (SET-R44, HNT-R120)", function()
		local _, fake = loggedIn()

		local slots = fake.ns.SectionSlots(fake.ns.goods, "trackers").Hunts
		assert.are.same({ FRAME }, { slots[1].id, slots[2] })
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
	local PATHFINDER, FIVESEAL = "hunts.binding.pathfinder", "hunts.binding.fiveseal"
	local WAGERSILK, RIBBON = "hunts.binding.wagersilk", "hunts.trackerframe.wagerribbon"
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

	-- The fixture list with only the sets `ids`, in that order, and their Hunts.
	local function setsOnly(loaded, ids)
		local list, keep, sets, hunts_ = loaded.ns.huntList, {}, {}, {}
		for _, id in ipairs(ids) do
			keep[id] = true
			sets[#sets + 1] = { id = id }
		end
		for _, hunt in ipairs(list.hunts) do
			if keep[hunt.set] then
				hunts_[#hunts_ + 1] = hunt
			end
		end
		loaded.ns.huntList = { fingerprint = list.fingerprint, sets = sets, hunts = hunts_, classes = list.classes }
	end

	-- The fixture list with fixture_wagers its only set: its title is every set's.
	local function wagersOnly(loaded)
		setsOnly(loaded, { "fixture_wagers" })
	end

	-- A later release's list: fixture_pair added after fixture_wagers, its title not yet earned.
	local function pairAdded(loaded)
		setsOnly(loaded, { "fixture_wagers", "fixture_pair" })
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
		"own Pathfinder's Calf once a live Cast earns a set title, refreshed then, and not Four-Set Seal while other sets aren't (HNT-R122, SHOP-R31)",
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

	it("own Four-Set Seal and Night Watch when every set's title is earned (HNT-R122, HNT-R123, HNT-R20)", function()
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
		"keep Four-Set Seal and Night Watch, earned by a live Cast, when a release adds a set not yet titled (HNT-R122, HNT-R20)",
		function()
			local loaded, fake = hunts.login(oddity, { prepare = wagersOnly })
			fishAt(fake, hunts.DAY, WESTFALL, { C.RACK_AURA })
			fake.playCast("caught", { { itemID = C.UNCOMMON, quantity = 1 } })
			fake.nextFrame()
			assert.is_true(fake.Pagle.IsOwned(FIVESEAL))
			-- Noted the first time the rule held, on the live entry.
			local goods = loaded.env.PagleHuntsDB.global.celebrated.goods
			assert.is_true(goods[FIVESEAL])
			assert.is_true(goods[NIGHT_WATCH])
			assert.is_true(goods[PATHFINDER])

			local next, nextFake = rebuilt(fake, loaded, pairAdded)

			assert.is_nil(next.ns.State().sets.fixture_pair)
			assert.is_true(nextFake.Pagle.IsOwned(FIVESEAL))
			assert.is_true(nextFake.Pagle.IsOwned(NIGHT_WATCH))
		end
	)

	it(
		"keep Four-Set Seal and Night Watch, earned before login, when a release adds a set not yet titled (HNT-R122, HNT-R20)",
		function()
			local loaded, fake = hunts.login(wagersTitle, { prepare = wagersOnly })
			-- Noted in done, where the rule first held.
			local goods = loaded.env.PagleHuntsDB.global.celebrated.goods
			assert.is_true(goods[FIVESEAL])
			assert.is_true(goods[NIGHT_WATCH])

			local next, nextFake = rebuilt(fake, loaded, pairAdded)

			assert.is_nil(next.ns.State().sets.fixture_pair)
			assert.is_true(next.ns.State().sets.fixture_wagers ~= nil)
			assert.is_true(nextFake.Pagle.IsOwned(FIVESEAL))
			assert.is_true(nextFake.Pagle.IsOwned(NIGHT_WATCH))
		end
	)

	it("note no good while no rule holds (HNT-R122)", function()
		local loaded = hunts.login(oddity)

		assert.is_nil(loaded.env.PagleHuntsDB.global.celebrated.goods)
	end)

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
