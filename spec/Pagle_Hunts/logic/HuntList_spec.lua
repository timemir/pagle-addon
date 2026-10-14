-- The Hunt list at runtime (HNT-R1, HNT-R2, HNT-R3's "retired"), over the fixture list (DATA-R93's shape).

---@diagnostic disable-next-line: undefined-global -- busted runs on stock Lua 5.1; the WoW client has no dofile
local hunts = dofile("spec/Pagle_Hunts/support.lua")

-- Server times (DATA-R87): 00:00 UTC on 2026-01-01, 2026-06-01 and 2026-11-04, the fixture's since and retired dates.
local JAN_1, JUN_1, NOV_4 = 1767225600, 1780272000, 1793750400

-- The IDs of a list of Hunts or sets, in order.
local function ids(list)
	local out = {}
	for i, entry in ipairs(list) do
		out[i] = entry.id
	end
	return out
end

describe("The Hunt list at runtime", function()
	local loaded = hunts.load()
	local ns = loaded.ns
	local list = ns.hunts

	describe("in file order (HNT-R1)", function()
		it("gives every set in the order the list has them", function()
			assert.are.same({ "fixture_dusk", "fixture_wagers" }, ids(list:Sets()))
		end)

		it("gives every Hunt in file order, not grouped by set, retired and not-yet ones too, for the rules", function()
			assert.are.same({
				"fixture_snapper",
				"fixture_oddity",
				"fixture_rack",
				"fixture_hefty_blackmouth",
				"fixture_sunscale",
				"fixture_grouper",
			}, ids(list:Hunts()))
		end)

		it("gives a set's Hunts in file order", function()
			assert.are.same(
				{ "fixture_snapper", "fixture_hefty_blackmouth", "fixture_sunscale" },
				ids(list:SetHunts("fixture_dusk"))
			)
			assert.are.same(
				{ "fixture_oddity", "fixture_rack", "fixture_grouper" },
				ids(list:SetHunts("fixture_wagers"))
			)
			assert.are.same({}, list:SetHunts("no_such_set"))
		end)

		it("finds a Hunt, a set and a class by ID, with the list's own fields (DATA-R93)", function()
			local snapper = list:Hunt("fixture_snapper")
			assert.are.same(
				{ "fixture_dusk", "natural", 13759, "night", { 1, 10, 40 } },
				{ snapper.set, snapper.kind, snapper.species, snapper.window, snapper.tiers }
			)
			assert.are.equal(3, list:Hunt("fixture_hefty_blackmouth").minBand)
			assert.are.equal("fixture_wagers", list:Set("fixture_wagers").id)
			assert.are.same({ [6522] = true, [251524] = true }, list:Class("fixed.oddity"))
			assert.is_nil(list:Hunt("no_such_hunt"))
			assert.is_nil(list:Set("no_such_set"))
			assert.is_nil(list:Class("fixed.no_such_class"))
		end)

		it(
			"gives the list's own fingerprint, which the projection passes as its extraFingerprint (DATA-R72)",
			function()
				assert.are.equal(ns.huntList.fingerprint, list:Fingerprint())
			end
		)
	end)

	describe("exists, current and retired (HNT-R2)", function()
		local snapper = list:Hunt("fixture_snapper")
		local sunscale = list:Hunt("fixture_sunscale")

		it("exists from its since on, inclusive", function()
			assert.is_false(ns.Exists(snapper, JAN_1 - 1))
			assert.is_true(ns.Exists(snapper, JAN_1))
			assert.is_true(ns.Exists(snapper, NOV_4))
		end)

		it("exists until its retired date, exclusive", function()
			assert.is_false(ns.Exists(sunscale, JAN_1 - 1))
			assert.is_true(ns.Exists(sunscale, JUN_1 - 1))
			assert.is_false(ns.Exists(sunscale, JUN_1))
		end)

		it("is current when it exists now, and retired from its retired date on (HNT-R3)", function()
			assert.is_true(ns.IsCurrent(sunscale, JUN_1 - 1))
			assert.is_false(ns.IsRetired(sunscale, JUN_1 - 1))
			assert.is_false(ns.IsCurrent(sunscale, JUN_1))
			assert.is_true(ns.IsRetired(sunscale, JUN_1))
			assert.is_false(ns.IsRetired(snapper, NOV_4))
		end)

		it("lists the current Hunts in file order", function()
			assert.are.same({
				"fixture_snapper",
				"fixture_oddity",
				"fixture_rack",
				"fixture_hefty_blackmouth",
				"fixture_sunscale",
			}, ids(list:Current(JUN_1 - 1)))
			assert.are.same(
				{ "fixture_snapper", "fixture_oddity", "fixture_rack", "fixture_hefty_blackmouth" },
				ids(list:Current(SERVER_TIME))
			)
		end)

		it("lists the Retired Hunts in file order, from their retired date on (HNT-R3)", function()
			assert.are.same({}, list:Retired(JUN_1 - 1))
			assert.are.same({ "fixture_sunscale" }, ids(list:Retired(JUN_1)))
		end)

		it("keeps a Hunt whose since is still ahead out of every list a view reads, until its since", function()
			local grouper = list:Hunt("fixture_grouper")
			assert.is_false(ns.IsCurrent(grouper, SERVER_TIME))
			assert.is_false(ns.IsRetired(grouper, SERVER_TIME))
			assert.is_nil(ids(list:Current(SERVER_TIME))[6])
			assert.are.same({ "fixture_sunscale" }, ids(list:Retired(SERVER_TIME)))

			assert.are.equal("fixture_grouper", ids(list:Current(NOV_4))[5])
		end)
	end)

	describe("text from Hunts' own ns.L (HNT-R1, DATA-R105)", function()
		it("names Hunts and sets, titles and notes sets, from the lore", function()
			assert.are.same(
				{ "Snapper Run", "Keeps late hours.", "Dusk", "the Duskwatcher", "After the lamps are lit." },
				{
					list:HuntName("fixture_snapper"),
					list:HuntNote("fixture_snapper"),
					list:SetName("fixture_dusk"),
					list:SetTitle("fixture_dusk"),
					list:SetNote("fixture_dusk"),
				}
			)
		end)

		it("falls back to the ID for a name or title with no text, and to nothing for a note", function()
			assert.are.same(
				{ "fixture_rack", "fixture_wagers" },
				{ list:HuntName("fixture_rack"), list:SetTitle("fixture_wagers") }
			)
			assert.is_nil(list:HuntNote("fixture_oddity"))
			assert.is_nil(list:SetNote("fixture_wagers"))
		end)

		it("names everything by its ID with no lore at all", function()
			local bare = hunts.load(nil, { lore = false }).ns.hunts

			assert.are.same({ "fixture_snapper", "fixture_dusk", "fixture_dusk" }, {
				bare:HuntName("fixture_snapper"),
				bare:SetName("fixture_dusk"),
				bare:SetTitle("fixture_dusk"),
			})
			assert.is_nil(bare:HuntNote("fixture_snapper"))
			assert.is_nil(bare:SetNote("fixture_dusk"))
		end)
	end)

	describe("with no Hunt list loaded", function()
		it("reads as an empty list until data\\HuntList.lua is in the TOC (HNT-R1)", function()
			local empty = ns.NewHuntList(nil, ns.L)

			assert.are.same({}, empty:Hunts())
			assert.are.same({}, empty:Sets())
			assert.are.same({}, empty:Current(SERVER_TIME))
			assert.are.same({}, empty:Retired(SERVER_TIME))
			assert.is_nil(empty:Hunt("fixture_snapper"))
			assert.is_nil(empty:Fingerprint())
		end)
	end)
end)
