-- The Curio crate's pool against the shop's goods (SHOP-R50, SHOP-R53): the repo check that fails when a good for sale
-- or crate only is missing from ns.CRATE_POOL, when the pool has a row that isn't one, when a pre-1.0 row's crate tier
-- isn't its good's price tier (or Curio for a crate-only good), when a row's kind isn't its slot's kind, or when the
-- pre-1.0 rows aren't in the shop's order. It loads every addon, as the client does, so every Module's goods are in
-- the registry; a new good needs one row in the pool and nothing else.

-- The kind of emblem each slot's goods have (SHOP-R50), by the last part of the slot's ID: a tracker frame slot of any
-- Module is "tracker frame".
local KIND_OF_SLOT = {
	toaststyle = "toaststyle",
	soundset = "soundset",
	crest = "crest",
	binding = "binding",
	trackerframe = "trackerframe",
}

-- The goods for sale and crate only in the registry, in the shop's order (SHOP-R53): Core's slots, then each Module's
-- by Module order, each slot's goods in registration order; as `{ id, tier, kind, slot }`, the tier "curio" for a
-- crate-only good and the kind nil for a slot of no kind.
---@param goods PagleGoods
---@return table[]
local function shopGoods(goods)
	local list = {}
	for _, slot in ipairs(goods:Slots()) do
		for _, good in ipairs(goods:GoodsOf(slot.id)) do
			if good.tier or good.crate then
				list[#list + 1] = {
					id = good.id,
					tier = good.crate and "curio" or good.tier,
					kind = KIND_OF_SLOT[slot.id:match("%.([^.]+)$")],
					slot = slot.id,
				}
			end
		end
	end
	return list
end

-- What is wrong with `pool` as the pool of `shop`'s goods, as sentences; none when it is right.
---@param pool PagleCratePoolGood[]
---@param shop table[]
---@return string[]
local function problems(pool, shop)
	local found = {}
	local function add(...)
		found[#found + 1] = string.format(...)
	end
	local goodOf, rowOf, later = {}, {}, {}
	for _, good in ipairs(shop) do
		goodOf[good.id] = good
		if not good.kind then
			add("%s's slot %s has no kind of emblem", good.id, good.slot)
		end
	end
	for _, row in ipairs(pool) do
		if rowOf[row.id] then
			add("%s is in the pool twice", row.id)
		end
		rowOf[row.id] = row
		if row.since then
			later[row.id] = true
		end
		local good = goodOf[row.id]
		if not good then
			add("%s is in the pool but is not a good for sale or crate only", row.id)
		else
			if row.kind ~= good.kind then
				add("%s's kind is %s, its slot's is %s", row.id, tostring(row.kind), tostring(good.kind))
			end
			if good.tier == "curio" and row.tier ~= "curio" then
				add("%s is crate only, so its crate tier is curio, not %s", row.id, tostring(row.tier))
			elseif row.since == nil and row.tier ~= good.tier then
				add("%s's crate tier is %s, its price tier %s", row.id, tostring(row.tier), tostring(good.tier))
			end
		end
	end
	for _, good in ipairs(shop) do
		if not rowOf[good.id] then
			add("%s is for sale or crate only but not in the pool", good.id)
		end
	end
	-- The rows from 1.0 on are in the shop's order; a good that joins later goes at the pool's end, with `since`.
	local want, have = {}, {}
	for _, good in ipairs(shop) do
		if not later[good.id] and rowOf[good.id] then
			want[#want + 1] = good.id
		end
	end
	for _, row in ipairs(pool) do
		if not row.since and goodOf[row.id] then
			have[#have + 1] = row.id
		end
	end
	for i = 1, math.max(#want, #have) do
		if want[i] ~= have[i] then
			add(
				"the pool's order differs from the shop's from row %d: %s, the shop's %s",
				i,
				tostring(have[i]),
				tostring(want[i])
			)
			break
		end
	end
	local crateOnly = 0
	for _, row in ipairs(pool) do
		crateOnly = crateOnly + (row.tier == "curio" and 1 or 0)
	end
	if crateOnly > 2 then
		add("%d goods are crate only; at most two ever are (SHOP-R53)", crateOnly)
	end
	return found
end

-- A copy of `list`, its rows copied too.
local function copy(list)
	local out = {}
	for i, row in ipairs(list) do
		out[i] = {}
		for key, value in pairs(row) do
			out[i][key] = value
		end
	end
	return out
end

describe("the Curio crate's pool", function()
	local pool, shop

	setup(function()
		local loaded = loadAddon("Pagle", foreverWith({ PagleLog = savedLog({ BUILD_ENTRY }) }), {
			also = { "Pagle_Ledger", "Pagle_Stats", "Pagle_Hunts", "Pagle_TackleBoard", "Pagle_QoL" },
		})
		enterWorld(loaded, 5)
		loaded.client.advance(20)
		local core = loaded.namespaces.Pagle
		pool, shop = core.CRATE_POOL, shopGoods(core.goods)
	end)

	it(
		"holds every good for sale and every crate-only good, each at its price tier, kind and place (SHOP-R50, SHOP-R53)",
		function()
			assert.are.same({}, problems(pool, shop))
			assert.are.equal(102, #shop)
		end
	)

	it("fails for a good for sale missing from it", function()
		local fewer = copy(pool)
		table.remove(fewer, 40)
		local found = problems(fewer, shop)
		assert.are.equal(1, #found, table.concat(found, "\n"))
		assert.matches("is for sale or crate only but not in the pool", found[1])
	end)

	it("fails for a crate-only good missing from it", function()
		local fewer = copy(pool)
		for i, row in ipairs(fewer) do
			if row.tier == "curio" then
				table.remove(fewer, i)
				break
			end
		end
		local found = problems(fewer, shop)
		assert.matches("core.toaststyle.foil is for sale or crate only but not in the pool", found[1])
	end)

	it("fails for a row that isn't a good for sale or crate only", function()
		local more = copy(pool)
		more[#more + 1] = { id = "core.toaststyle.page", tier = 1, kind = "toaststyle" } -- a default
		more[#more + 1] = { id = "core.toaststyle.sonar", tier = 4, kind = "toaststyle" } -- earned
		local found = problems(more, shop)
		assert.are.equal(2, #found, table.concat(found, "\n"))
		assert.matches("core.toaststyle.page is in the pool but is not a good for sale or crate only", found[1])
		assert.matches("core.toaststyle.sonar is in the pool but", found[2])
	end)

	it(
		"fails for a pre-1.0 row whose crate tier isn't its good's price tier, and for a crate-only good not at Curio",
		function()
			local wrong = copy(pool)
			wrong[1].tier = 2
			for _, row in ipairs(wrong) do
				if row.id == "core.toaststyle.foil" then
					row.tier = 1
				end
			end
			local found = problems(wrong, shop)
			assert.are.equal(2, #found, table.concat(found, "\n"))
			assert.matches("crate tier is 2, its price tier 1", found[1])
			assert.matches("core.toaststyle.foil is crate only, so its crate tier is curio, not 1", found[2])
		end
	)

	it("lets a row that joined later keep the crate tier it joined at (SHOP-R53)", function()
		local later = copy(pool)
		local row = table.remove(later, 1)
		row.tier, row.since = 2, 1800000000
		later[#later + 1] = row
		assert.are.same({}, problems(later, shop))
	end)

	it("fails for a row whose kind isn't its slot's", function()
		local wrong = copy(pool)
		wrong[30].kind = "binding"
		local found = problems(wrong, shop)
		assert.are.equal(1, #found, table.concat(found, "\n"))
		assert.matches("kind is binding, its slot's is", found[1])
	end)

	it("fails for a pre-1.0 pool out of the shop's order", function()
		local swapped = copy(pool)
		swapped[5], swapped[6] = swapped[6], swapped[5]
		local found = problems(swapped, shop)
		assert.are.equal(1, #found, table.concat(found, "\n"))
		assert.matches("the pool's order differs from the shop's from row 5", found[1])
	end)

	it("fails for a good in a slot of no kind, and for a third crate-only good", function()
		local odd = copy(shop)
		odd[1].kind = nil
		assert.matches("has no kind of emblem", problems(pool, odd)[1])
		local third = copy(pool)
		for i = 1, 3 do
			third[i].tier = "curio"
		end
		local found = problems(third, shop)
		assert.matches("4 goods are crate only", found[#found])
	end)
end)
