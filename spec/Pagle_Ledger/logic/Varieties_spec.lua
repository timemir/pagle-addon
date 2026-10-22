-- Fish varieties in the Ledger (VAR-R20–R25, VAR-R27, VAR-R91; core/varieties.md › In the Ledger, Data): the
-- varieties caught in the Ledger's own projection, the completion part, the `complete.varieties` title, the moments of
-- a variety's first Catch and of a fish complete, and the Write-up lines of a first build and a catch-up. Hand-made
-- records carrying Core's decoded `variety` (VAR-R4) over a fixture catalogue and a fixture Lore.lua. No Core.

-- Two Species with ten varieties each, a third with ten that is removed and never caught (LED-R12), a Species with no
-- varieties (a Species not sized, VAR-R1) and a Legend, all on Lake's list.
local FISH, FISH_2, REMOVED, PLAIN, LEGEND = 6359, 6361, 6362, 6291, 19803
-- A second item of FISH's Species (DATA-R19).
local FISH_ALT = 6360
local LAKE = 12
local T0 = SERVER_TIME - 700

local KEYS = { "a", "b", "c", "d", "e", "f", "g", "h", "i", "j" }
local RARITIES = { "common", "common", "common", "common", "uncommon", "uncommon", "uncommon", "rare", "rare", "epic" }

local ITEMS = {
	[FISH] = fishRecord(FISH, { varieties = KEYS }),
	[FISH_ALT] = fishRecord(FISH),
	[FISH_2] = fishRecord(FISH_2, { varieties = KEYS }),
	[REMOVED] = fishRecord(REMOVED, { varieties = KEYS, removed = true }),
	[PLAIN] = fishRecord(PLAIN),
	[LEGEND] = fishRecord(LEGEND, { legend = true }),
}
local getItem = itemLookup(ITEMS)

local NAMES = { [FISH] = "Firefin Snapper", [FISH_2] = "Rainbow Fin Albacore", [PLAIN] = "Brilliant Smallfish" }

-- Core's GetVarieties (VAR-R11), as the outlets read it: the Species' ten, each named "Colour {i}", with its art.
---@param speciesID integer
---@param index integer
local function variety(speciesID, index)
	return {
		id = speciesID .. "." .. KEYS[index],
		key = KEYS[index],
		index = index,
		rarity = RARITIES[index],
		name = "Colour " .. index,
		description = "A colour.",
		art = {
			texture = "Interface\\AddOns\\Pagle\\media\\varieties\\Varieties1",
			left = index / 32,
			right = 0.5,
			top = 0.25,
			bottom = 0.375,
		},
	}
end

-- The fixture's lookups (LOG-R55): Lake lists every item.
local function worldLookups()
	return {
		GetItem = getItem,
		GetZones = function()
			return { LAKE }
		end,
		GetArea = function()
			return areaRecord(0)
		end,
		GetZoneCatches = function()
			return {
				catchEntry(FISH),
				catchEntry(FISH_2),
				catchEntry(REMOVED),
				catchEntry(PLAIN),
				catchEntry(LEGEND),
			}
		end,
	}
end

-- Records the way the Catch log hands them out (LOG-R42), seq and entry IDs in order, each Catch with its variety
-- as Core decodes it (VAR-R4).
local function newLog()
	local seq = 0
	local log = {}

	--- A caught Cast in Lake at T0 + seq minutes, one Catch per { itemID, index } pair (index nil: no variety).
	---@param catches { [1]: integer, [2]: integer? }[]
	---@param char integer?
	function log.cast(catches, char)
		seq = seq + 1
		local itemIDs = {}
		for i, catch in ipairs(catches) do
			itemIDs[i] = catch[1]
		end
		local time = T0 + 60 * seq
		local record = castRecord({
			seq = seq,
			time = time,
			zone = LAKE,
			items = itemIDs,
			char = char,
			date = { year = 2026, month = 10, day = 22 },
		})
		for i, catch in ipairs(catches) do
			local index = catch[2]
			if index then
				local item = getItem(catch[1]) --[[@as table]]
				record.items[i].variety =
					{ id = item.species .. "." .. KEYS[index], index = index, rarity = RARITIES[index] }
			end
		end
		return record
	end

	return log
end

-- Casts of every variety of `species` from `from` to `to`, one Catch each.
local function casts(log, species, from, to)
	local list = {}
	for index = from, to do
		list[#list + 1] = log.cast({ { species, index } })
	end
	return list
end

describe("fish varieties in the Ledger", function()
	local loaded = loadAddon(
		"Pagle_Ledger",
		FOREVER_GLOBALS,
		{ replace = { ["data/Lore.lua"] = "spec/Pagle_Ledger/fixtures/VarietiesLore.lua" } }
	)
	local ns = loaded.ns
	local world = ns.NewWorld(worldLookups())
	local lookups = { GetItem = getItem, MatchesConditions = loaded.env.Pagle.MatchesConditions, world = world }

	local fold, log
	before_each(function()
		fold = ns.NewLedgerFold(lookups)
		log = newLog()
	end)

	-- The kinds of a list of achievements or moments, in order.
	local function kinds(list)
		local out = {}
		for i, entry in ipairs(list) do
			out[i] = entry.kind
		end
		return out
	end

	-- The kinds of the achievements of `kinds` only, in order.
	local function only(list, wanted)
		local out = {}
		for _, entry in ipairs(list) do
			if wanted[entry.kind] then
				out[#out + 1] = entry
			end
		end
		return out
	end

	describe("the projection (VAR-R20, core/varieties.md › Data)", function()
		it("is rules version 6, for the varieties caught (LED-R2, LED-R4, Tunables)", function()
			assert.are.equal(6, ns.LEDGER_RULES_VERSION)
			assert.are.equal(601, ns.RulesVersion(1))
		end)

		it("starts with no varieties caught", function()
			assert.are.same({}, fold.reset().varieties)
		end)

		it("keeps each variety's count and first Catch: entry ID, realm date, zone and character", function()
			local first = log.cast({ { FISH, 3 } }, 2)
			local state = applyLive(fold, { first, log.cast({ { FISH_ALT, 3 }, { FISH, 8 } }) })

			assert.are.same({
				[3] = {
					count = 2,
					first = { entryId = first.id, date = { year = 2026, month = 10, day = 22 }, zone = LAKE, char = 2 },
				},
				[8] = state.varieties[FISH][8],
			}, state.varieties[FISH])
			assert.are.equal(1, state.varieties[FISH][8].count)
		end)

		it("counts nothing for a Catch without a variety, nor for a Legend (VAR-R1)", function()
			local state = applyLive(fold, { log.cast({ { PLAIN }, { LEGEND }, { FISH } }) })

			assert.are.same({}, state.varieties)
		end)

		it("is the same in every mode (LED-R3)", function()
			local records = casts(log, FISH, 1, 4)
			local live = applyLive(fold, records)
			local rebuilt = applyLive(ns.NewLedgerFold(lookups), records, nil, "rebuild")

			assert.are.same(live.varieties, rebuilt.varieties)
		end)

		it("earns newVariety at each variety's first Catch, with its rarity, and no Coins or XP (VAR-R25)", function()
			local state, earned = applyLive(fold, { log.cast({ { FISH, 1 } }) })
			local xp = state.xp
			local again = log.cast({ { FISH, 1 } })
			local _, later = applyLive(fold, { again, log.cast({ { FISH, 10 } }) }, state)

			assert.are.same({
				{
					kind = "newVariety",
					cast = earned[1].cast,
					coins = 0,
					species = FISH,
					itemID = FISH,
					index = 1,
					rarity = "common",
				},
			}, only(earned, { newVariety = true }))
			local new = only(later, { newVariety = true })
			assert.are.equal(1, #new)
			assert.are.same({ 10, "epic", 0 }, { new[1].index, new[1].rarity, new[1].coins })
			-- Two more Catches' base XP only: 10 each (LED-R20), Fresh Water doubling them (LED-R22).
			assert.are.equal(xp + 40, state.xp)
		end)

		it("earns fishComplete with the tenth variety of a Species, after its newVariety (VAR-R20, VAR-R25)", function()
			local records = casts(log, FISH, 1, 9)
			local state, earned = applyLive(fold, records)
			assert.are.same({}, only(earned, { fishComplete = true }))

			local tenth = log.cast({ { FISH_ALT, 10 } })
			local _, last = applyLive(fold, { tenth }, state)
			assert.are.same(
				{ "newVariety", "fishComplete" },
				kinds(only(last, { newVariety = true, fishComplete = true }))
			)
			assert.are.same(
				{ kind = "fishComplete", cast = tenth.id, coins = 0, species = FISH, itemID = FISH_ALT },
				only(last, { fishComplete = true })[1]
			)
		end)
	end)

	describe("completion (VAR-R20, VAR-R21, LED-R70, LED-R71)", function()
		it("adds every Species with varieties, removed ones left out, done when all ten are caught", function()
			local state = applyLive(fold, casts(log, FISH, 1, 9))
			local completion = ns.LedgerCompletion(world, state)
			assert.are.same({ done = 0, total = 2 }, completion.varieties)

			applyLive(fold, { log.cast({ { FISH, 10 } }) }, state)
			completion = ns.LedgerCompletion(world, state)
			assert.are.same({ done = 1, total = 2 }, completion.varieties)
			-- Species 1 of 3 (REMOVED left out), varieties 1 of 2, Lake not mastered: 2 of 6.
			assert.are.same({ 2, 6, 33 }, { completion.done, completion.total, completion.percent })
		end)

		it("is a part of its own on the Angler page, after Species (LED-R71, LED-R146)", function()
			assert.are.same({ "species", "varieties", "junk", "treasure", "trophy", "zones" }, ns.COMPLETION_PARTS)
			assert.are.equal("Varieties", ns.L.ANGLER_PARTS.varieties)
		end)
	end)

	describe("the title complete.varieties (VAR-R22, LED-R75)", function()
		local function titleKeys(state)
			return ns.TitleKeys({ world = world, state = state, celebrated = { coins = 0 }, getItem = getItem })
		end

		local function has(keys, key)
			for _, earned in ipairs(keys) do
				if earned == key then
					return true
				end
			end
			return false
		end

		it("is earned when every variety of every Species with varieties is caught", function()
			local state = applyLive(fold, casts(log, FISH, 1, 10))
			assert.is_false(has(titleKeys(state), "title:complete.varieties"))

			applyLive(fold, casts(log, FISH_2, 1, 10), state)
			local keys = titleKeys(state)
			assert.is_true(has(keys, "title:complete.varieties"))
			-- Last of LED-R75's order, after the other complete.* titles.
			assert.are.equal("title:complete.varieties", keys[#keys])
			assert.are.same({ "complete", "varieties" }, { ns.TitleKind("title:complete.varieties") })
		end)

		it("needs a total above 0 (VAR-R22)", function()
			local bare = ns.NewWorld({
				GetItem = getItem,
				GetZones = function()
					return { LAKE }
				end,
				GetArea = function()
					return areaRecord(0)
				end,
				GetZoneCatches = function()
					return { catchEntry(PLAIN) }
				end,
			})
			local state = applyLive(fold, { log.cast({ { PLAIN } }) })
			local keys = ns.TitleKeys({ world = bare, state = state, celebrated = { coins = 0 }, getItem = getItem })

			assert.is_false(has(keys, "title:complete.varieties"))
		end)
	end)

	-- Where the moments and Write-up sections go (LedgerOutlets), noting them, over the fixture's names, Core's
	-- GetVarieties (variety) and `crests`, the fish crests Core registered by good ID (VAR-R12).
	---@param crests table<string, table>?
	local function newOutlets(crests)
		crests = crests or { [ns.FishCrestID(FISH)] = { name = "Firefin Crest", icon = "crests\\fish\\6359" } }
		local outlets = { moments = {}, writeUps = {} }
		outlets.RaiseMoment = function(moment)
			outlets.moments[#outlets.moments + 1] = moment
		end
		outlets.RaiseWriteUp = function(section)
			outlets.writeUps[#outlets.writeUps + 1] = section
		end
		outlets.ReportCoinsEarned = function() end
		outlets.SetSummaryLine = function() end
		outlets.RefreshGoods = function() end
		outlets.ItemName = function(itemID)
			return NAMES[itemID]
		end
		outlets.AreaName = function()
			return "Loch Modan"
		end
		outlets.LogId = function()
			return "log"
		end
		outlets.FormatNumber = tostring
		outlets.SizeText = function() end
		outlets.Variety = variety
		outlets.Good = function(goodID)
			return crests[goodID]
		end
		return outlets
	end

	describe("moments (VAR-R25, VAR-R27, LED-R96, LED-R97)", function()
		local state, celebrated, outlets
		before_each(function()
			state = fold.reset()
			celebrated = ns.CelebratedSet({})
			outlets = newOutlets()
		end)

		-- The moments of a Species' and its varieties' first Catches and of titles: the fixture's Lake is charted, so its
		-- Catches also earn zone ranks and stars (LED-R45, LED-R50), which this leaves out.
		local OURS = {
			newSpecies = true,
			newVariety = true,
			rareVariety = true,
			epicVariety = true,
			everyColour = true,
			completeTitle = true,
		}

		-- Applies `record` live and celebrates it (LED-R91), returning its moments of OURS.
		local function live(record)
			local earned = fold.apply(state, record, "live")
			return only(ns.Celebrate(celebrated, state, record, earned, outlets, lookups), OURS)
		end

		-- Applies and celebrates `records` one by one, returning the last one's moments.
		local function liveAll(records)
			local moments
			for _, record in ipairs(records) do
				moments = live(record)
			end
			return moments
		end

		it("gives a Common or Uncommon variety a toast.low New variety, riding on a New Species toast", function()
			local first = log.cast({ { FISH, 1 } })
			local moments = live(first)
			-- The Species' first Catch is also its first variety: Core merges them, New Species the headline.
			assert.are.same({ "newSpecies", "newVariety" }, kinds(moments))

			local second = log.cast({ { FISH_ALT, 6 } })
			assert.are.same({
				{
					rung = "toast.low",
					kind = "newVariety",
					order = 120,
					title = "New variety · Colour 6",
					stamp = "New variety",
					icon = FISH_ALT,
					art = variety(FISH, 6).art,
					cast = second.id,
				},
			}, live(second))
		end)

		it("gives a Rare variety a toast with its name and its art in the bezel", function()
			live(log.cast({ { FISH, 1 } }))
			local record = log.cast({ { FISH, 9 } })

			assert.are.same({
				{
					rung = "toast",
					kind = "rareVariety",
					order = 105,
					title = "Rare variety",
					text = "Colour 9",
					icon = FISH,
					art = variety(FISH, 9).art,
					cast = record.id,
				},
			}, live(record))
		end)

		it("gives an Epic variety a banner with its name and its art for the seal's ribbon", function()
			live(log.cast({ { FISH, 1 } }))
			local record = log.cast({ { FISH, 10 } })
			local moments = live(record)

			assert.are.same({ "banner", "epicVariety", 97, "Epic variety", "Colour 10", FISH, record.id }, {
				moments[1].rung,
				moments[1].kind,
				moments[1].order,
				moments[1].title,
				moments[1].text,
				moments[1].icon,
				moments[1].cast,
			})
			assert.are.same(variety(FISH, 10).art, moments[1].art)
			-- A copy: Core's list is shared (CORE-R18).
			assert.are_not.equal(variety(FISH, 10).art, moments[1].art)
			assert.is_nil(moments[1].coins)
		end)

		it("raises nothing for a variety caught before, and carries no Coins (VAR-R25, LED-R91)", function()
			liveAll(casts(log, FISH, 1, 3))
			assert.are.same({}, live(log.cast({ { FISH, 2 } })))
			local moments = live(log.cast({ { FISH, 4 }, { FISH_2, 8 } }))
			-- FISH_2's New Species pays its 10 (LED-R88); its varieties' moments, none.
			assert.are.same({ "newVariety", "newSpecies", "rareVariety" }, kinds(moments))
			assert.is_nil(moments[1].coins)
			assert.are.equal(10, moments[2].coins)
			assert.is_nil(moments[3].coins)
		end)

		it("gives the tenth of a Species a banner sealed with its fish crest and the crest's Earned line", function()
			liveAll(casts(log, FISH, 1, 9))
			local tenth = log.cast({ { FISH, 10 } })
			local moments = live(tenth)

			assert.are.same({ "epicVariety", "everyColour" }, kinds(moments))
			assert.are.same({
				rung = "banner",
				kind = "everyColour",
				order = 95,
				title = "Every colour of Firefin Snapper",
				text = "Earned: Firefin Crest",
				stamp = "Every colour",
				icon = FISH,
				cast = tenth.id,
				seal = "crest",
				crest = "crests\\fish\\6359",
			}, moments[2])
			assert.is_true(celebrated.fishComplete[FISH])
		end)

		it("seals it with the waves and no Earned line while Core has no crest for it", function()
			outlets = newOutlets({})
			liveAll(casts(log, FISH, 1, 9))
			local moment = live(log.cast({ { FISH, 10 } }))[2]

			assert.are.same({ "everyColour" }, { moment.kind })
			assert.is_nil(moment.seal)
			assert.is_nil(moment.crest)
			assert.is_nil(moment.text)
		end)

		it("names no variety Core doesn't list", function()
			outlets.Variety = function() end
			live(log.cast({ { FISH, 1 } }))
			local moment = live(log.cast({ { FISH, 9 } }))[1]

			assert.are.same({ ns.L.NAME_UNKNOWN }, { moment.text })
			assert.is_nil(moment.art)
		end)

		it("gives the last of all the complete.varieties title moment, as the other complete.* titles", function()
			liveAll(casts(log, FISH, 1, 10))
			liveAll(casts(log, FISH_2, 1, 9))
			local last = log.cast({ { FISH_2, 10 } })
			local moments = live(last)
			local title = moments[#moments]

			assert.are.same({
				rung = "banner",
				kind = "completeTitle",
				order = 140,
				title = "Title earned",
				text = "Keeper of Every Colour",
				stamp = "Title: Keeper of Every Colour",
				icon = "Interface\\Icons\\INV_Scroll_03",
				cast = last.id,
				seal = "quill",
			}, title)
			assert.is_true(celebrated.titles["title:complete.varieties"])
		end)
	end)

	describe("the Write-up (VAR-R91, LED-R93, LED-R94)", function()
		-- The projection's done (LED-R93) over `records`, applied in `mode` into the scratch list, with `global`.
		local function done(global, records, info, outlets, state)
			state = state or fold.reset()
			local scratch = {}
			for _, record in ipairs(records) do
				fold.apply(state, record, info.firstBuild and "rebuild" or "replay", scratch)
			end
			ns.CelebrateDone(global, state, scratch, info, outlets, lookups)
			return state
		end

		-- The lines of `lines` naming varieties or fish in every colour.
		local function varietyLines(lines)
			local out = {}
			for _, line in ipairs(lines) do
				if line:find("variet") or line:find("every colour") then
					out[#out + 1] = line
				end
			end
			return out
		end

		it("lists the varieties and the fish in every colour of a first build, raising no moment", function()
			local outlets = newOutlets()
			local records = casts(log, FISH, 1, 10)
			records[#records + 1] = log.cast({ { FISH_2, 4 } })
			local global = {}
			done(global, records, { firstBuild = true, replayed = 0 }, outlets)

			assert.are.same({}, outlets.moments)
			-- Right after the Species' line (LED-R94).
			assert.are.same({ "2 Species", "11 varieties · 1 fish in every colour" }, {
				outlets.writeUps[1].lines[2],
				outlets.writeUps[1].lines[3],
			})
			assert.is_true(global.celebrated.fishComplete[FISH])
			assert.is_true(global.celebrated.varieties[FISH_2][4])
		end)

		it("writes a catch-up's new varieties up while the Ledger was off, not as moments", function()
			local outlets = newOutlets()
			local global = { celebrated = { logId = "log" } }
			local state = fold.reset()
			-- FISH and its first variety celebrated before the Ledger was turned off.
			local first = log.cast({ { FISH, 1 } })
			local celebrated = ns.CelebratedSet(global)
			ns.Celebrate(celebrated, state, first, fold.apply(state, first, "live"), outlets, lookups)
			outlets.moments = {}

			done(global, casts(log, FISH, 2, 4), { replayed = 3 }, outlets, state)

			assert.are.same({}, outlets.moments)
			assert.are.equal("While the Ledger was off", outlets.writeUps[1].heading)
			-- After the level's line (the zone's first Catch and rank pay XP), before the Coins'.
			assert.are.same({ "3 varieties" }, varietyLines(outlets.writeUps[1].lines))
		end)

		it("counts a fish completed while the Ledger was off", function()
			local outlets = newOutlets()
			local global = { celebrated = { logId = "log" } }
			local state = fold.reset()
			local first = log.cast({ { FISH, 1 } })
			ns.Celebrate(ns.CelebratedSet(global), state, first, fold.apply(state, first, "live"), outlets, lookups)

			done(global, casts(log, FISH, 2, 10), { replayed = 9 }, outlets, state)

			assert.are.same({ "9 varieties · 1 fish in every colour" }, varietyLines(outlets.writeUps[1].lines))
		end)

		it("raises a rebuild's new varieties as summary-only moments (LED-R93, ANN-R63)", function()
			local outlets = newOutlets()
			local global = { celebrated = { logId = "log" } }
			done(global, { log.cast({ { FISH, 9 } }) }, { rebuilt = true, replayed = 0 }, outlets)

			local varieties = only(outlets.moments, { rareVariety = true })
			assert.are.same({ "rareVariety" }, kinds(varieties))
			assert.is_true(varieties[1].summaryOnly)
		end)
	end)
end)
